variable "project_name" {
  description = "Project name (resource name prefix)"
  type        = string
  default     = "pentest-lab"
}

variable "email_addresses" {
  description = "Notification email addresses (list)"
  type        = list(string)
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL (if set)"
  type        = string
  default     = ""
}

variable "ttl_hours" {
  description = "Resource lifetime (hours)"
  type        = number
  default     = 2
}

# リソース名
locals {
  name_prefix = "${var.project_name}-notification"
  use_slack = var.slack_webhook_url != ""
}

# SNSトピックの作成
resource "aws_sns_topic" "budget_alert" {
  name = "${local.name_prefix}-budget-alert"
  
  tags = {
    Name     = "${local.name_prefix}-budget-alert"
    TTL      = "${var.ttl_hours}h"
    Scenario = "common"
  }
}

# メール通知のSNSサブスクリプション
resource "aws_sns_topic_subscription" "email_subscription" {
  count     = length(var.email_addresses)
  topic_arn = aws_sns_topic.budget_alert.arn
  protocol  = "email"
  endpoint  = var.email_addresses[count.index]
}

# Slack通知のLambda関数（Webhook URLが指定されている場合）
resource "aws_lambda_function" "slack_notification" {
  count         = local.use_slack ? 1 : 0
  function_name = "${local.name_prefix}-slack-notification"
  role          = aws_iam_role.lambda_role[0].arn
  handler       = "index.handler"
  runtime       = "nodejs14.x"
  timeout       = 10
  
  # Lambda関数はインラインで定義（コスト節約のため）
  filename      = "${path.module}/lambda_function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda_function.zip")
  
  environment {
    variables = {
      SLACK_WEBHOOK_URL = var.slack_webhook_url
    }
  }
  
  tags = {
    Name     = "${local.name_prefix}-slack-notification"
    TTL      = "${var.ttl_hours}h"
    Scenario = "common"
  }
}

# Lambda実行用IAMロール
resource "aws_iam_role" "lambda_role" {
  count = local.use_slack ? 1 : 0
  name  = "${local.name_prefix}-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name     = "${local.name_prefix}-lambda-role"
    TTL      = "${var.ttl_hours}h"
    Scenario = "common"
  }
}

# Lambda基本実行ポリシー
resource "aws_iam_role_policy" "lambda_policy" {
  count = local.use_slack ? 1 : 0
  name  = "${local.name_prefix}-lambda-policy"
  role  = aws_iam_role.lambda_role[0].id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Slack通知用Lambda関数のSNSサブスクリプション
resource "aws_sns_topic_subscription" "slack_subscription" {
  count     = local.use_slack ? 1 : 0
  topic_arn = aws_sns_topic.budget_alert.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_notification[0].arn
}

# Lambda関数がSNSからの通知を受け取るための権限
resource "aws_lambda_permission" "sns_permission" {
  count         = local.use_slack ? 1 : 0
  statement_id  = "AllowSNSInvocation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_notification[0].function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.budget_alert.arn
}

# 自動破棄ロジック
resource "null_resource" "ttl_destroyer" {
  provisioner "local-exec" {
    # TTL時間経過後にterraform destroyを実行
    command = <<EOT
      sleep ${var.ttl_hours * 60 * 60} && \
      cd ${path.module}/../../../ && \
      terraform destroy -auto-approve -target=module.notification || echo "自動破棄に失敗しました"
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
output "sns_topic_arn" {
  description = "SNS topic ARN for budget alert notification"
  value       = aws_sns_topic.budget_alert.arn
} 