# S3バケット本体
resource "aws_s3_bucket" "web_bucket" {
  bucket = var.bucket_name
}

# 静的ウェブサイトホスティングの設定
resource "aws_s3_bucket_website_configuration" "web_bucket" {
  bucket = aws_s3_bucket.web_bucket.id

  index_document {
    suffix = "index.html"
  }
}

# パブリックアクセスのブロック（CloudFront経由のみにするため、外からは閉じる）
resource "aws_s3_bucket_public_access_block" "web_bucket" {
  bucket = aws_s3_bucket.web_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFrontからのアクセスを許可するポリシー（後でcloudfront.tfと紐付けます）
resource "aws_s3_bucket_policy" "web_bucket" {
  bucket = aws_s3_bucket.web_bucket.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.web_bucket.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn] # 後でcloudfront.tfができると繋がります
    }
  }
} # ★ここで data ブロックが正しく閉じられます

# sqs.tfを実行後に反映（dataの外側に独立させます）
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.web_bucket.id

  queue {
    queue_arn     = aws_sqs_queue.image_delay_queue.arn # sqs.tfができると繋がります
    filter_prefix = "images/"                           # 例：images/ フォルダ内を対象にする場合
    events        = [
      "s3:ObjectCreated:*",
      "s3:ObjectRemoved:*"
    ]
  }
}