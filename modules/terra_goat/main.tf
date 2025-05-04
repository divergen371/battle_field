variable "project_name" {
  description = "Project name (resource name prefix)"
  type        = string
  default     = "pentest-lab"
}

variable "my_ip_cidr" {
  description = "Allowed IP address (CIDR format)"
  type        = string
}

variable "ttl_hours" {
  description = "Resource lifetime (hours)"
  type        = number
  default     = 2
}

# リソース名
locals {
  name_prefix = "${var.project_name}-terragoat"
}

# 可用性ゾーンの取得
data "aws_availability_zones" "available" {
  state = "available"
}

# VPCの作成 - 意図的に脆弱な構成
resource "aws_vpc" "this" {
  cidr_block           = "10.60.0.0/16"
  enable_dns_hostnames = true
  # 脆弱: デフォルトタグがない
  tags = {
    Name    = "${local.name_prefix}-vpc"
    TTL     = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = "${local.name_prefix}-igw"
    TTL     = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.60.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true  # 脆弱: すべてのインスタンスにパブリックIPを自動付与

  tags = {
    Name    = "${local.name_prefix}-public-subnet"
    TTL     = "${var.ttl_hours}h"
    Scenario = "terragoat"
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
    Name    = "${local.name_prefix}-public-rt"
    TTL     = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# パブリックサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# 脆弱: すべてのトラフィックを許可するセキュリティグループ
resource "aws_security_group" "vulnerable_sg" {
  name        = "${local.name_prefix}-vulnerable-sg"
  description = "Intentionally vulnerable security group (allow all traffic)"
  vpc_id      = aws_vpc.this.id

  # 脆弱: すべてのインバウンドトラフィックを許可
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All inbound traffic (vulnerable setting)"
  }

  # 脆弱: すべてのアウトバウンドトラフィックを許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name     = "${local.name_prefix}-vulnerable-sg"
    TTL      = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# 脆弱なS3バケット
resource "aws_s3_bucket" "vulnerable_bucket" {
  bucket = "${lower(var.project_name)}-terragoat-${random_string.suffix.result}"
  
  # 脆弱: バージョニングなし、暗号化なし

  tags = {
    Name     = "${local.name_prefix}-vulnerable-bucket"
    TTL      = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# 脆弱: パブリックアクセス許可
resource "aws_s3_bucket_public_access_block" "vulnerable_bucket" {
  bucket = aws_s3_bucket.vulnerable_bucket.id

  block_public_acls   = false
  block_public_policy = false
  ignore_public_acls  = false
  restrict_public_buckets = false
}

# 脆弱: パブリック読み取りポリシー
resource "aws_s3_bucket_policy" "vulnerable_policy" {
  bucket = aws_s3_bucket.vulnerable_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.vulnerable_bucket.arn}/*"
      }
    ]
  })
}

# 脆弱: サーバーサイド暗号化なし
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.vulnerable_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # 最低限のSSE-S3暗号化（デフォルトでは暗号化なし）
    }
  }
}

# 脆弱: IAMロール（過剰な権限）
resource "aws_iam_role" "vulnerable_role" {
  name = "${local.name_prefix}-vulnerable-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })

  tags = {
    Name     = "${local.name_prefix}-vulnerable-role"
    TTL      = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# 脆弱: 過剰な権限ポリシー（管理者アクセス）
resource "aws_iam_role_policy" "vulnerable_policy" {
  name = "${local.name_prefix}-vulnerable-policy"
  role = aws_iam_role.vulnerable_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "*",
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

# 脆弱: パブリックにアクセス可能なRDSインスタンス
resource "aws_db_subnet_group" "this" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.public2.id]  # 同じサブネットを2回使用

  tags = {
    Name     = "${local.name_prefix}-db-subnet-group"
    TTL      = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# 2つ目のサブネット（RDS用）
resource "aws_subnet" "public2" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.60.2.0/24"
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true

  tags = {
    Name     = "${local.name_prefix}-public-subnet2"
    TTL      = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# ランダムなサフィックス
resource "random_string" "suffix" {
  length  = 8
  special = false
  lower   = true
  upper   = false
}

# 脆弱: 暗号化なしDBインスタンス
resource "aws_db_instance" "vulnerable_db" {
  identifier             = "${local.name_prefix}-db"
  engine                 = "mysql"
  engine_version         = "5.7"  # 古いバージョン
  instance_class         = "db.t3.micro"
  allocated_storage      = 5
  db_name                = "terragoat"
  username               = "admin"
  password               = "Password123!"  # 脆弱: ハードコードされたパスワード
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.vulnerable_sg.id]
  publicly_accessible    = true  # 脆弱: パブリックにアクセス可能
  skip_final_snapshot    = true
  storage_encrypted      = false  # 脆弱: 暗号化なし

  tags = {
    Name     = "${local.name_prefix}-vulnerable-db"
    TTL      = "${var.ttl_hours}h"
    Scenario = "terragoat"
  }
}

# 自動破棄ロジック
resource "null_resource" "ttl_destroyer" {
  provisioner "local-exec" {
    # TTL時間経過後にterraform destroyを実行
    command = <<EOT
      sleep ${var.ttl_hours * 60 * 60} && \
      cd ${path.module}/../../ && \
      terraform destroy -auto-approve -var="scenario_name=terra_goat" || echo "自動破棄に失敗しました"
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
output "terragoat_bucket_name" {
  description = "Vulnerable S3 bucket name"
  value       = aws_s3_bucket.vulnerable_bucket.bucket
}

output "terragoat_db_endpoint" {
  description = "Vulnerable RDS endpoint"
  value       = aws_db_instance.vulnerable_db.endpoint
}

output "terragoat_connection_instructions" {
  description = "Connection instructions"
  value       = <<EOT
TerraGoat vulnerable environment connection info:

S3 bucket: aws s3 ls s3://${aws_s3_bucket.vulnerable_bucket.bucket}
(Note: Vulnerable bucket with public access)

RDS database:
Endpoint: ${aws_db_instance.vulnerable_db.endpoint}
Username: admin
Password: Password123!
(Note: Vulnerable database with public access)

Check vulnerable IaC configuration:
terraform state show aws_s3_bucket.vulnerable_bucket
terraform state show aws_security_group.vulnerable_sg
terraform state show aws_db_instance.vulnerable_db
terraform state show aws_iam_role_policy.vulnerable_policy

Note: This environment is for learning purposes only and will be automatically deleted after ${var.ttl_hours} hours.
EOT
} 