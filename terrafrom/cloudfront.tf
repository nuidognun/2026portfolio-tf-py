# CloudFrontがS3にアクセスするためのアクセス制御設定（OAC）
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "s3-portfolio-oac"
  description                       = "OAC for portfolio S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront ディストリビューション本体の設定
resource "aws_cloudfront_distribution" "s3_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = [var.domain_name] # variables.tf のドメインを適用

  # オリジン（配信元となるS3）の設定
  origin {
    domain_name              = aws_s3_bucket.web_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.web_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # キャッシュや通信プロトコルの動作設定
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.web_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https" # HTTPアクセスをHTTPSに自動リダイレクト
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # 地理的制限（制限なし）
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # SSL証明書の設定（acm.tf で作る証明書を紐付ける）
  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}