terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# メインプロバイダ（東京リージョン）
provider "aws" {
  region = "ap-northeast-1"
}

# ACM用のサブプロバイダ（バージニア北部リージョン）
provider "aws" {
  alias  = "us-east"
  region = "us-east-1"
}