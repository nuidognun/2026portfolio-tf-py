# 2026portfolio-tf-py

本リポジトリは、ポートフォリオサイトのTerraformファイル、およびLambdaのpythonファイルを掲載しています。
```text
├── terraform/
│   ├── acm.tf           # SSL/TLS証明書（HTTPS化）の設定
│   ├── cloudfront.tf    # CloudFront（OAC構成・配信キャッシュ）の設定
│   ├── lambda.tf        # Lambda関数・IAMロール・トリガーの設定
│   ├── providers.tf     # AWSプロバイダーの定義
│   ├── route53.tf       # 独自ドメイン・DNSレコードの設定
│   ├── s3.tf            # 静的ファイル・イラスト格納バケット、ポリシー設定
│   ├── sns.tf           # Amazon SNS（メール通知サービス）の設定
│   ├── sqs.tf           # Amazon SQS（ディレイキュー・多重通知防止）の設定
│   └── variables.tf     # 環境に依存する固有情報の変数定義
└── lambda/
    ├── lambda_function.py # 画像一括アップロード多重通知制御プログラム（本体）
