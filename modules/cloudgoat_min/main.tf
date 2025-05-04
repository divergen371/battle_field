variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックス）"
  type        = string
  default     = "pentest-lab"
}

variable "my_ip_cidr" {
  description = "アクセスを許可するIPアドレス（CIDR形式）"
  type        = string
}

variable "ttl_hours" {
  description = "リソースの生存期間（時間）"
  type        = number
  default     = 2
}

# リソース名
locals {
  name_prefix = "${var.project_name}-cloudgoat"
}

# ランダムサフィックス生成
resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}

# 可用性ゾーンの取得
data "aws_availability_zones" "available" {
  state = "available"
}

# VPCの作成
resource "aws_vpc" "this" {
  cidr_block           = "10.40.0.0/16"
  enable_dns_hostnames = true
  
  tags = {
    Name     = "${local.name_prefix}-vpc"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name     = "${local.name_prefix}-igw"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.40.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true  # インスタンスにパブリックIPを自動付与

  tags = {
    Name     = "${local.name_prefix}-public-subnet"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# パブリックルートテーブル
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name     = "${local.name_prefix}-public-rt"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# パブリックサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# プライベートサブネット
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.40.2.0/24"
  availability_zone = data.aws_availability_zones.available.names[0]

  tags = {
    Name     = "${local.name_prefix}-private-subnet"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# SSHアクセス用セキュリティグループ
resource "aws_security_group" "ssh_access" {
  name        = "${local.name_prefix}-ssh-access"
  description = "Allow SSH from specific IP"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
    description = "SSH from my IP"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name     = "${local.name_prefix}-ssh-access"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# 内部通信用セキュリティグループ
resource "aws_security_group" "internal" {
  name        = "${local.name_prefix}-internal"
  description = "Allow internal communication"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
    description = "Allow all internal traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name     = "${local.name_prefix}-internal"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# 脆弱なS3バケット
resource "aws_s3_bucket" "data_bucket" {
  bucket = "${lower(var.project_name)}-cloudgoat-${random_string.suffix.result}"
  
  tags = {
    Name     = "${local.name_prefix}-data-bucket"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# 脆弱: サーバーサイド暗号化なし
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.data_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # 最低限のSSE-S3暗号化
    }
  }
}

# 脆弱なバケットACL
resource "aws_s3_bucket_public_access_block" "data_bucket" {
  bucket = aws_s3_bucket.data_bucket.id

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

# 機密データをアップロード
resource "aws_s3_object" "secret_data" {
  bucket  = aws_s3_bucket.data_bucket.id
  key     = "secret/credentials.txt"
  content = "このファイルには機密データが含まれています。CloudGoat演習の一部です。"
  
  tags = {
    Name     = "${local.name_prefix}-secret-data"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# CloudGoatアプリケーションユーザー
resource "aws_iam_user" "app_user" {
  name = "${local.name_prefix}-app-user"
  
  tags = {
    Name     = "${local.name_prefix}-app-user"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# 脆弱なポリシー：特定のバケットへの完全なアクセス
resource "aws_iam_user_policy" "app_policy" {
  name = "${local.name_prefix}-app-policy"
  user = aws_iam_user.app_user.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:*"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      }
    ]
  })
}

# アクセスキー作成
resource "aws_iam_access_key" "app_user_key" {
  user = aws_iam_user.app_user.name
}

# EC2インスタンスロール
resource "aws_iam_role" "ec2_role" {
  name = "${local.name_prefix}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name     = "${local.name_prefix}-ec2-role"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# EC2インスタンスプロファイル
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${local.name_prefix}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# 脆弱な権限ポリシー
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${local.name_prefix}-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Effect   = "Allow"
        Resource = [
          aws_s3_bucket.data_bucket.arn,
          "${aws_s3_bucket.data_bucket.arn}/*"
        ]
      }
    ]
  })
}

# EC2インスタンス
resource "aws_instance" "vulnerable_instance" {
  ami                    = "ami-0d979355d03fa2522" # Amazon Linux 2
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.ssh_access.id, aws_security_group.internal.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name
  
  user_data = <<-EOF
    #!/bin/bash
    echo "CloudGoat Mini 脆弱性演習環境" > /home/ec2-user/README.txt
    echo "アクセスキーID: ${aws_iam_access_key.app_user_key.id}" > /home/ec2-user/app_credentials.txt
    echo "シークレットキー: ${aws_iam_access_key.app_user_key.secret}" >> /home/ec2-user/app_credentials.txt
    chmod 644 /home/ec2-user/app_credentials.txt
  EOF
  
  tags = {
    Name     = "${local.name_prefix}-vulnerable-instance"
    TTL      = "${var.ttl_hours}h"
    Scenario = "cloudgoat_min"
  }
}

# 自動破棄ロジック
resource "null_resource" "ttl_destroyer" {
  provisioner "local-exec" {
    # TTL時間経過後にterraform destroyを実行
    command = <<EOT
      sleep ${var.ttl_hours * 60 * 60} && \
      cd ${path.module}/../../../ && \
      terraform destroy -auto-approve -target=module.cloudgoat_min || echo "自動破棄に失敗しました"
    EOT
    
    # バックグラウンドで実行
    on_failure = continue
    interpreter = ["/bin/bash", "-c"]
  }

  # リソース更新時は既存のものを破棄して新しく作り直し
  triggers = {
    always_run = "${timestamp()}"
  }
}

# 出力
output "cloudgoat_instance_ip" {
  description = "CloudGoat EC2インスタンスのパブリックIP"
  value       = aws_instance.vulnerable_instance.public_ip
}

output "cloudgoat_bucket_name" {
  description = "CloudGoat S3バケット名"
  value       = aws_s3_bucket.data_bucket.bucket
}

output "cloudgoat_app_user" {
  description = "CloudGoatアプリケーションユーザー名"
  value       = aws_iam_user.app_user.name
}

output "cloudgoat_access_key_id" {
  description = "CloudGoatアプリケーションユーザーのアクセスキーID"
  value       = aws_iam_access_key.app_user_key.id
  sensitive   = true
}

output "cloudgoat_secret_access_key" {
  description = "CloudGoatアプリケーションユーザーのシークレットアクセスキー"
  value       = aws_iam_access_key.app_user_key.secret
  sensitive   = true
}

output "cloudgoat_connection_instructions" {
  description = "CloudGoat環境への接続手順"
  value       = <<EOF
    CloudGoat演習環境へのアクセス手順:

    1. SSHでEC2インスタンスに接続:
       ssh ec2-user@${aws_instance.vulnerable_instance.public_ip}

    2. EC2インスタンス内にあるアプリユーザーの認証情報を確認:
       cat /home/ec2-user/app_credentials.txt

    3. S3バケットを確認:
       aws s3 ls s3://${aws_s3_bucket.data_bucket.bucket} --recursive

    4. CloudGoat演習を開始...
  EOF
} 