# terraform内の 環境変数の指定
variable "domain_name" {
  type        = string
  default     = "nui-raferafe.com"
  description = "Route 53やCloudFront、ACMで使用するドメイン名"
}

variable "bucket_name" {
  type        = string
  default     = "2026portfolio-nui-bucket"
  description = "静的ウェブサイト公開用のS3バケット名"
}

variable "public_key" {
  type    = string
  default = "illustrations.html"
}

variable "template_key" {
  type    = string
  default = "illustrations_template.html"
}