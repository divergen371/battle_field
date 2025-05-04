variable "vpc_id" {
  description = "セキュリティグループを作成するVPC ID"
  type        = string
}

variable "allowed_cidr" {
  description = "接続を許可するCIDR"
  type        = string
  default     = "0.0.0.0/0"
}

variable "name_prefix" {
  description = "セキュリティグループ名のプレフィックス"
  type        = string
}

variable "description" {
  description = "セキュリティグループの説明"
  type        = string
  default     = "脆弱環境アクセス用セキュリティグループ"
}

# 基本的なInbound/Outboundルールを持つセキュリティグループ
resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-sg"
  description = var.description
  vpc_id      = var.vpc_id

  # 許可されたCIDRからの接続のみ許可
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "許可されたCIDRからのSSH接続"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "許可されたCIDRからのHTTP接続"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "許可されたCIDRからのHTTPS接続"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "許可されたCIDRからのJuice Shop接続"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "許可されたCIDRからのアプリケーション接続"
  }

  # 全ての外向き通信を許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "全ての外向き通信"
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

output "security_group_id" {
  description = "作成されたセキュリティグループのID"
  value       = aws_security_group.this.id
} 