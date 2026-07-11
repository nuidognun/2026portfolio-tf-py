# 1. SSL/TLS 証明書のリクエスト（必ず us-east-1 で作成）
resource "aws_acm_certificate" "cert" {
  provider          = aws.us-east # ★ポイント：providers.tfで定義したus-east-1を使用
  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

# 2. Route 53にドメインの所有権を確認するためのDNSレコードを自動登録
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id # route53.tfのデータソースを参照
}

# 3. 証明書の検証完了を待つ設定
resource "aws_acm_certificate_validation" "cert" {
  provider                = aws.us-east # ★ここもus-east-1を指定
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}