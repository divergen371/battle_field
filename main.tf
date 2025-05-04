terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  # ローカルバックエンド設定（コスト最適化のためS3は使用しない）
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Environment = "pentest-lab"
      Terraform   = "true"
      TTL         = "${var.ttl_hours}h"
      Owner       = "security-training"
    }
  }
} 
