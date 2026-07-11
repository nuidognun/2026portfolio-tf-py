  # 1. 10分遅延キューの本体（600秒 = 10分）
  resource "aws_sqs_queue" "image_delay_queue" {
    name                       = "portfolio-image-delay-queue"
    delay_seconds              = 600   # 10分遅延を設定
    visibility_timeout_seconds = 450   
  }

  # 2. S3からこのSQSにメッセージを送ることを許可するポリシー
  resource "aws_sqs_queue_policy" "sqs_policy" {
    queue_url = aws_sqs_queue.image_delay_queue.id
    policy    = data.aws_iam_policy_document.sqs_policy_doc.json
  }

  data "aws_iam_policy_document" "sqs_policy_doc" {
    statement {
      effect = "Allow"
      principals {
        type        = "Service"
        identifiers = ["s3.amazonaws.com"]
      }
      actions   = ["sqs:SendMessage"]
      resources = [aws_sqs_queue.image_delay_queue.arn]
      condition {
        test     = "ArnEquals"
        variable = "aws:SourceArn"
        values   = [aws_s3_bucket.web_bucket.arn] # s3.tfのバケットからのみ許可
      }
    }
  }