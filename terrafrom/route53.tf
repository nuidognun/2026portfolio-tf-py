# 1. 既存のRoute 53ホストゾーンの情報を読み込む
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# 2. ドメイン（nui-raferafe.com）を新しいCloudFrontに向けるAレコード設定
resource "aws_route53_record" "apex_a" {
  zone_id         = data.aws_route53_zone.main.zone_id
  name            = var.domain_name
  type            = "A"
  allow_overwrite = true # 手動の古いレコードを上書きできるように設定

  # CloudFrontを宛先にするための「エイリアス（Alias）」設定
  alias {
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}