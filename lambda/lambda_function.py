import os
import re
import time
import boto3

s3_client = boto3.client('s3')
sns_client = boto3.client('sns')
cloudfront_client = boto3.client('cloudfront')
sqs_client = boto3.client('sqs') # ★SQSクライアントを追加

BUCKET_NAME = os.environ.get('BUCKET_NAME')
TEMPLATE_KEY = os.environ.get('TEMPLATE_KEY') 
PUBLIC_KEY = os.environ.get('PUBLIC_KEY')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
DISTRIBUTION_ID = os.environ.get('CLOUDFRONT_DISTRIBUTION_ID')

# 現在処理中のSQSキューのURLを特定するための関数
def get_queue_url_from_arn(queue_arn):
    # arn:aws:sqs:region:account-id:queue-name -> queue-name
    queue_name = queue_arn.split(':')[-1]
    account_id = queue_arn.split(':')[-2]
    # 簡易的にURLを組み立て（環境変数から取れないためARNからパース）
    region = queue_arn.split(':')[-3]
    return f"https://sqs.{region}.amazonaws.com/{account_id}/{queue_name}"

def lambda_handler(event, context):
    if not all([BUCKET_NAME, TEMPLATE_KEY, PUBLIC_KEY, SNS_TOPIC_ARN, DISTRIBUTION_ID]):
        raise ValueError("必須の環境変数（BUCKET_NAME, SNS_TOPIC_ARN, CLOUDFRONT_DISTRIBUTION_ID）が設定されていません。")

    try:
        if 'Records' in event:
            print(f"SQSから {len(event['Records'])} 件のメッセージを受信しました。HTMLの再生成を開始します。")

        # 1. S3から最新の画像一覧を取得
        response = s3_client.list_objects_v2(Bucket=BUCKET_NAME, Prefix='images/')
        
        image_files = []
        if 'Contents' in response:
            for obj in response['Contents']:
                key = obj['Key']
                if re.match(r'^images/[^/]+\.(jpg|jpeg|png)$', key, re.IGNORECASE):
                    image_files.append({
                        'key': key,
                        'filename': os.path.basename(key)
                    })
        
        image_files.sort(key=lambda x: x['filename'])
        
        # 3. HTMLパーツ生成
        gallery_html = ""
        for i in range(0, len(image_files), 2):
            gallery_html += '            <div class="group-tile">\n'
            for img in image_files[i:i+2]:
                filename = img['filename']
                name_without_ext = os.path.splitext(filename)[0]
                title = name_without_ext.split('_', 1)[1] if '_' in name_without_ext else name_without_ext
                img_url = img['key']
                
                gallery_html += f"""                <div class="img-tile gallery-tile">
                    <img src="{img_url}" alt="{title}">
                    <div class="overlay">
                        <span class="overlay-text">{title}</span>
                    </div>
                </div>\n"""
            gallery_html += '            </div>\n\n'
            
        # 4. テンプレート読み込み＆置換
        template_obj = s3_client.get_object(Bucket=BUCKET_NAME, Key=TEMPLATE_KEY)
        template_content = template_obj['Body'].read().decode('utf-8')
        
        marker_regex = r"<!-- GALLERY_START -->[\s\S]*<!-- GALLERY_END -->"
        replacement = f"<!-- GALLERY_START -->\n{gallery_html}        <!-- GALLERY_END -->"
        
        if re.search(marker_regex, template_content):
            new_html_content = re.sub(marker_regex, replacement, template_content)
        else:
            raise ValueError("テンプレートHTML内にマーカーが見つかりません。")
            
        # 6. S3上書き出力
        s3_client.put_object(
            Bucket=BUCKET_NAME,
            Key=PUBLIC_KEY,
            Body=new_html_content.encode('utf-8'),
            ContentType='text/html'
        )
        
        # 6.5 CloudFrontのキャッシュ削除
        try:
            cloudfront_client.create_invalidation(
                DistributionId=DISTRIBUTION_ID,
                InvalidationBatch={
                    'Paths': {'Quantity': 1, 'Items': [f"/{PUBLIC_KEY}"]},
                    'CallerReference': str(time.time())
                }
            )
            print("CloudFrontのキャッシュ削除要求を送信しました。")
        except Exception as cf_err:
            print(f"CloudFrontキャッシュ削除スキップ: {str(cf_err)}")
        
        # ★【ここを修正】SQSキューの中にまだ処理待ちのメッセージがあるか確認する
        should_send_email = True
        if 'Records' in event and len(event['Records']) > 0:
            try:
                queue_arn = event['Records'][0]['eventSourceARN']
                queue_url = get_queue_url_from_arn(queue_arn)
                
                # キューの状態を取得
                attrs = sqs_client.get_queue_attributes(
                    QueueUrl=queue_url,
                    AttributeNames=[
                        'ApproximateNumberOfMessages', 
                        'ApproximateNumberOfMessagesNotVisible'
                    ]
                )
                visible = int(attrs['Attributes']['ApproximateNumberOfMessages'])
                not_visible = int(attrs['Attributes']['ApproximateNumberOfMessagesNotVisible'])
                
                # 自分自身（NotVisible）以外の未処理メッセージが残っている、または次のバッチが控えている場合
                # ※ batch_sizeが10で、まだVisibleに残っているなら、次のLambdaがメールを送るべきなので自分はスキップ
                if visible > 0:
                    print(f"キューにまだメッセージが残っています (待機中: {visible})。メール送信をスキップします。")
                    should_send_email = False
            except Exception as sqs_err:
                print(f"SQS残量チェック失敗（安全のためメールは送ります）: {str(sqs_err)}")

        # 7. 最後のバッチの時だけ成功メール通知 (SNS)
        if should_send_email:
            send_sns_notification(
                subject="ポートフォリオサイトの反映が正常に完了しました。",
                message="S3の画像更新およびCloudFrontのキャッシュ削除が正常に完了しました。\n対象画面: illustrations.html"
            )
        
        return {"statusCode": 200, "body": "Success"}
        
    except Exception as e:
        error_message = f"HTMLの自動更新処理中にエラーが発生しました。\n\n【エラー内容】\n{str(e)}"
        send_sns_notification(
            subject="【アラート】ポートフォリオサイトの反映に失敗しました。",
            message=error_message
        )
        raise e

def send_sns_notification(subject, message):
    try:
        sns_client.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
    except Exception as sns_err:
        print(f"SNS送信失敗: {str(sns_err)}")