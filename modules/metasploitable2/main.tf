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
  name_prefix = "${var.project_name}-metasploitable2"
}

# 可用性ゾーンの取得
data "aws_availability_zones" "available" {
  state = "available"
}

# VPCの作成
resource "aws_vpc" "this" {
  cidr_block           = "10.50.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name    = "${local.name_prefix}-vpc"
    TTL     = "${var.ttl_hours}h"
    Scenario = "metasploitable2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name    = "${local.name_prefix}-igw"
    TTL     = "${var.ttl_hours}h"
    Scenario = "metasploitable2"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.50.1.0/24"
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${local.name_prefix}-public-subnet"
    TTL     = "${var.ttl_hours}h"
    Scenario = "metasploitable2"
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
    Scenario = "metasploitable2"
  }
}

# パブリックサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# セキュリティグループの作成
resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-sg"
  description = "Metasploitable2用セキュリティグループ"
  vpc_id      = aws_vpc.this.id

  # 許可されたCIDRからの接続のみ許可
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
    description = "SSH接続"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
    description = "HTTP接続"
  }

  # 脆弱なサービスのために追加のポート
  dynamic "ingress" {
    for_each = {
      ftp       = 21
      telnet    = 23
      smb       = 445
      mysql     = 3306
      postgres  = 5432
      vnc       = 5900
      java_rmi  = 1099
      distcc    = 3632
      tomcat    = 8180
    }

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.my_ip_cidr]
      description = "Metasploitable2 - ${ingress.key}"
    }
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
    Name    = "${local.name_prefix}-sg"
    TTL     = "${var.ttl_hours}h"
    Scenario = "metasploitable2"
  }
}

# Metasploitable2のAMIデータソース（Ubuntu 16.04ベース）
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-xenial-16.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2インスタンスの起動テンプレート
resource "aws_launch_template" "metasploitable2" {
  name          = "${local.name_prefix}-template"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # ARM対応のMetasploitableがないためt3.microを使用

  vpc_security_group_ids = [aws_security_group.this.id]

  # スポットインスタンスを使用
  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price = "0.004" # 通常価格の50%程度
    }
  }

  # Metasploitable2をDockerで実行するユーザーデータ
  user_data = base64encode(<<-EOF
    #!/bin/bash
    # システムの更新
    apt-get update
    apt-get install -y docker.io

    # Dockerサービスの起動
    systemctl start docker
    systemctl enable docker

    # Metasploitable2イメージの取得と実行
    docker pull tleemcjr/metasploitable2
    docker run -d --name metasploitable2 \
      --restart always \
      -p 21:21 -p 22:22 -p 23:23 -p 25:25 -p 53:53 \
      -p 80:80 -p 111:111 -p 139:139 -p 445:445 \
      -p 512:512 -p 1099:1099 -p 1524:1524 \
      -p 2049:2049 -p 2121:2121 -p 3306:3306 \
      -p 3632:3632 -p 5432:5432 -p 5900:5900 \
      -p 6000:6000 -p 6667:6667 -p 8009:8009 \
      -p 8180:8180 tleemcjr/metasploitable2
      
    # ステータスファイルの作成
    echo "Metasploitable2 is running. Connect to any service at $(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)" > /home/ubuntu/status.txt
  EOF
  )

  # EBSボリュームの設定
  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 10
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name    = "${local.name_prefix}-instance"
      TTL     = "${var.ttl_hours}h"
      Scenario = "metasploitable2"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${local.name_prefix}-volume"
      TTL     = "${var.ttl_hours}h"
      Scenario = "metasploitable2"
    }
  }
}

# EC2インスタンスの作成
resource "aws_instance" "metasploitable2" {
  launch_template {
    id      = aws_launch_template.metasploitable2.id
    version = "$Latest"
  }

  subnet_id = aws_subnet.public.id

  tags = {
    Name    = "${local.name_prefix}-instance"
    TTL     = "${var.ttl_hours}h"
    Scenario = "metasploitable2"
  }
}

# TTL自動破棄のためのnull_resource
resource "null_resource" "ttl_destroyer" {
  # TTL時間が変更されたら再実行
  triggers = {
    ttl_hours = var.ttl_hours
  }

  # terraform destroyをバックグラウンドで予約実行
  provisioner "local-exec" {
    command = <<-EOT
      (
        # バックグラウンドで実行
        echo "TTL: ${var.ttl_hours}時間後（$(date -d "+${var.ttl_hours} hour" "+%Y-%m-%d %H:%M:%S")）に'metasploitable2'シナリオを自動破棄します"
        sleep ${var.ttl_hours * 3600}
        cd ${path.root}
        echo "TTL期限切れ: 'metasploitable2'シナリオを自動破棄します（$(date "+%Y-%m-%d %H:%M:%S")）"
        terraform destroy -auto-approve -var="scenario_name=metasploitable2"
      ) &>/tmp/ttl_destroyer_metasploitable2.log &
    EOT
  }
}

output "metasploitable2_public_ip" {
  description = "Metasploitable2のパブリックIP"
  value       = aws_instance.metasploitable2.public_ip
}

output "connection_instructions" {
  description = "接続方法"
  value       = <<-EOT
    Metasploitable2の環境が起動しました！
    
    パブリックIP: ${aws_instance.metasploitable2.public_ip}
    
    以下のサービスにアクセスできます：
    - SSH: ssh -p 22 ${aws_instance.metasploitable2.public_ip} (user: msfadmin, pass: msfadmin)
    - FTP: ftp ${aws_instance.metasploitable2.public_ip} (anonymous or msfadmin)
    - Web: http://${aws_instance.metasploitable2.public_ip}/
    - DVWA: http://${aws_instance.metasploitable2.public_ip}/dvwa/
    - Mutillidae: http://${aws_instance.metasploitable2.public_ip}/mutillidae/
    
    ${var.ttl_hours}時間後に自動的に削除されます。
  EOT
} 