# 1. Lambdaの実行用IAMロール（Lambdaが各種サービスと喋るための身分証）
resource "aws_iam_role" "lambda_role" {
  name = "portfolio-lambda-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# 2. LambdaにS3へのインラインポリシーを追加（S3の特定バケットへのフルアクセス）
resource "aws_iam_role_policy" "lambda_s3_inline_policy" {
  name = "portfolio-lambda-s3-inline-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          "${aws_s3_bucket.web_bucket.arn}",
          "${aws_s3_bucket.web_bucket.arn}/*"
        ]
      }
    ]
  })
}

# 3. IAMロールに各種管理ポリシーを合体（SQS読み取り、SNSパブリッシュ、ログ出力）
resource "aws_iam_role_policy_attachment" "lambda_sqs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaSQSQueueExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_sns" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# 4. CloudFrontのキャッシュ削除（インバリデーション）の権限
resource "aws_iam_policy" "lambda_cloudfront_policy" {
  name        = "portfolio-lambda-cloudfront-policy"
  description = "Allow Lambda to create CloudFront invalidation"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cloudfront:CreateInvalidation"]
      Resource = ["*"]
    }]
  })
}

# ★【ここを修正しました】ダブルクォーテーションを外し、正しい記述に直しました
resource "aws_iam_role_policy_attachment" "lambda_cloudfront" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_cloudfront_policy.arn
}

# 5. 同階層にある lambda_function.py を自動でZIP化する設定
data "archive_file" "lambda_dummy" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

# 6. Lambda関数本体の設定
resource "aws_lambda_function" "html_updater" {
  filename         = data.archive_file.lambda_dummy.output_path
  function_name    = "portfolio-html-updater"
  role             = aws_iam_role.lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  timeout          = 120
  source_code_hash = data.archive_file.lambda_dummy.output_base64sha256

  # 最大同時実行数を「2」に制限（予約済同時実行数）
  # reserved_concurrent_executions = 2

  # 画像の環境変数を自動マッピング！
  environment {
    variables = {
      BUCKET_NAME                = aws_s3_bucket.web_bucket.id
      CLOUDFRONT_DISTRIBUTION_ID = aws_cloudfront_distribution.s3_distribution.id
      SNS_TOPIC_ARN              = aws_sns_topic.portfolio_topic.arn
      PUBLIC_KEY                 = var.public_key
      TEMPLATE_KEY               = var.template_key
    }
  }
}

# 7. SQSとの紐付け（10分遅延トリガーの起動設定）
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.image_delay_queue.arn
  function_name    = aws_lambda_function.html_updater.arn
  enabled          = true
  batch_size       = 10

  # ★【追加】メッセージが届いてから最大5分間（300秒）Lambdaの起動を待って、イベントを限界まで集約する
  maximum_batching_window_in_seconds = 300
}