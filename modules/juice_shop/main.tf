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
  name_prefix = "${var.project_name}-juice-shop"
}

# 可用性ゾーンの取得
data "aws_availability_zones" "available" {
  state = "available"
}

# VPCの作成
resource "aws_vpc" "this" {
  cidr_block           = "10.60.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name     = "${local.name_prefix}-vpc"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name     = "${local.name_prefix}-igw"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }
}

# パブリックサブネット
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = "10.60.${count.index}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  map_public_ip_on_launch = true

  tags = {
    Name     = "${local.name_prefix}-public-${count.index + 1}"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
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
    Scenario = "juice_shop"
  }
}

# パブリックサブネットとルートテーブルの関連付け
resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# セキュリティグループの作成
resource "aws_security_group" "this" {
  name        = "${local.name_prefix}-sg"
  description = "OWASP Juice Shop用セキュリティグループ"
  vpc_id      = aws_vpc.this.id

  # 許可されたCIDRからのJuice Shop接続(3000番ポート)
  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_cidr]
    description = "Juice Shop Web UI"
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
    Name     = "${local.name_prefix}-sg"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "this" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled" # コスト削減のためInsightsを無効化
  }

  tags = {
    Name     = "${local.name_prefix}-cluster"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.name_prefix}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name     = "${local.name_prefix}-task-execution-role"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }
}

# ECS Task Execution Role Policy Attachment
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Juice Shop Task Definition
resource "aws_ecs_task_definition" "juice_shop" {
  family                   = "${local.name_prefix}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" # 0.25 vCPU
  memory                   = "512" # 0.5 GB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "juice-shop"
      image     = "bkimminich/juice-shop:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.juice_shop.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "juice-shop"
        }
      }
    }
  ])

  tags = {
    Name     = "${local.name_prefix}-task"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "juice_shop" {
  name              = "/ecs/${local.name_prefix}"
  retention_in_days = 1 # コスト削減のため保持期間を最小化

  tags = {
    Name     = "${local.name_prefix}-logs"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }
}

# 現在のリージョンを取得
data "aws_region" "current" {}

# ECS Service
resource "aws_ecs_service" "juice_shop" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.juice_shop.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  
  # Spot Fargateを利用（コスト削減）
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 100
  }

  network_configuration {
    subnets          = aws_subnet.public[*].id
    security_groups  = [aws_security_group.this.id]
    assign_public_ip = true
  }

  tags = {
    Name     = "${local.name_prefix}-service"
    TTL      = "${var.ttl_hours}h"
    Scenario = "juice_shop"
  }

  depends_on = [aws_iam_role_policy_attachment.ecs_task_execution_role_policy]
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
        echo "TTL: ${var.ttl_hours}時間後（$(date -d "+${var.ttl_hours} hour" "+%Y-%m-%d %H:%M:%S")）に'juice_shop'シナリオを自動破棄します"
        sleep ${var.ttl_hours * 3600}
        cd ${path.root}
        echo "TTL期限切れ: 'juice_shop'シナリオを自動破棄します（$(date "+%Y-%m-%d %H:%M:%S")）"
        terraform destroy -auto-approve -var="scenario_name=juice_shop"
      ) &>/tmp/ttl_destroyer_juice_shop.log &
    EOT
  }
}

# Juice Shop の URL を出力
output "juice_shop_url" {
  description = "OWASP Juice Shop URL"
  value       = "http://${aws_ecs_service.juice_shop.network_configuration[0].assign_public_ip ? "Public IP (check AWS Console)" : "Not accessible"}"
}

# 取得方法の説明を出力
output "connection_instructions" {
  description = "接続方法"
  value       = <<-EOT
    OWASP Juice Shop 環境が起動しました！
    
    ※ ECS Fargateは直接IPを取得できないため、AWSコンソールの以下の手順で確認してください：
    
    1. ECSコンソールを開く
    2. クラスタ "${local.name_prefix}-cluster" をクリック
    3. サービス "${local.name_prefix}-service" をクリック
    4. 「Tasks」タブをクリック
    5. 実行中のタスクをクリック
    6. 「Public IP」をメモする
    
    ブラウザで以下のURLにアクセス：
    http://[上記で確認したIP]:3000
    
    ${var.ttl_hours}時間後に自動的に削除されます。
  EOT
} 