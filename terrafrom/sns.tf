# 1. SNS トピック本体の作成
resource "aws_sns_topic" "portfolio_topic" {
  name = "portfolio-notification-topic"
}

# 2. メール通知の送信先設定（サブスクリプション）
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.portfolio_topic.arn
  protocol  = "email"
  endpoint  = "****（メールアドレスを記載）"