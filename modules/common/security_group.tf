variable "vpc_id" {
  description = "VPC ID to create security group"
  type        = string
}

variable "allowed_cidr" {
  description = "CIDR to allow connections"
  type        = string
  default     = "0.0.0.0/0"
}

variable "name_prefix" {
  description = "Security group name prefix"
  type        = string
}

variable "description" {
  description = "Security group description"
  type        = string
  default     = "Security group for vulnerable environment access"
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
    description = "SSH access from allowed CIDR"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "HTTP access from allowed CIDR"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "HTTPS access from allowed CIDR"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "Juice Shop access from allowed CIDR"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
    description = "Application access from allowed CIDR"
  }

  # 全ての外向き通信を許可
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic"
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

output "security_group_id" {
  description = "ID of created security group"
  value       = aws_security_group.this.id
} 