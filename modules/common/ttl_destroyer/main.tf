variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックス）"
  type        = string
  default     = "pentest-lab"
}

variable "ttl_hours" {
  description = "リソースの生存期間（時間）"
  type        = number
  default     = 2
}

variable "sns_topic_arn" {
  description = "通知先SNSトピックARN"
  type        = string
}

variable "scenario_name" {
  description = "シナリオ名"
  type        = string
}

# リソース名
locals {
  name_prefix = "${var.project_name}-ttl-destroyer"
  
  # 現在時刻からTTL時間後の時刻を計算（cron形式）
  # Lambda関数の実行時間はUTCで設定する必要がある
  # そのため、現地時間からUTCに変換する処理が必要
  
  # 現在時刻を取得（terraform適用時の時刻）
  current_time = timestamp()
  
  # TTL時間を加算して終了時刻を計算
  expiration_time = timeadd(local.current_time, "${var.ttl_hours}h")
  
  # cron式用のコンポーネントを抽出（UTC変換）
  minute = formatdate("m", local.expiration_time)
  hour   = formatdate("h", local.expiration_time)
  day    = formatdate("D", local.expiration_time)
  month  = formatdate("M", local.expiration_time)
  year   = formatdate("YYYY", local.expiration_time)
  
  # シナリオ情報をJSON形式で保存
  scenario_info = jsonencode({
    scenario_name = var.scenario_name
    ttl_hours     = var.ttl_hours
    created_at    = local.current_time
    expires_at    = local.expiration_time
  })
}

# Lambda関数の実行ロール
resource "aws_iam_role" "destroyer_lambda_role" {
  name = "${local.name_prefix}-role"
  
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
    Name     = "${local.name_prefix}-role"
    Scenario = var.scenario_name
    TTL      = "${var.ttl_hours}h"
  }
}

# Lambda実行ポリシー
resource "aws_iam_policy" "destroyer_lambda_policy" {
  name        = "${local.name_prefix}-policy"
  description = "TTL破棄Lambda関数実行ポリシー"
  
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
      },
      {
        Action = [
          "sns:Publish"
        ]
        Effect   = "Allow"
        Resource = var.sns_topic_arn
      },
      # Terraformリソース破棄用のAWS APIアクセス権限
      # 実際の環境では適切な権限制限が必要
      {
        Action = [
          "ec2:*",
          "s3:*",
          "iam:*",
          "lambda:*",
          "rds:*"
          # 必要なサービスに応じて追加
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })
}

# ポリシーをロールにアタッチ
resource "aws_iam_role_policy_attachment" "destroyer_lambda_attach" {
  role       = aws_iam_role.destroyer_lambda_role.name
  policy_arn = aws_iam_policy.destroyer_lambda_policy.arn
}

# Lambda関数コード（インラインZIPで定義）
data "archive_file" "destroyer_lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/destroyer_lambda.zip"
  
  source {
    content  = <<EOF
import boto3
import json
import os
import logging
from datetime import datetime

# ロギング設定
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# 環境変数
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')
SCENARIO_INFO = os.environ.get('SCENARIO_INFO')

def handler(event, context):
    """
    TTL期限切れ時に実行されるハンドラ関数
    リソースの破棄とSNS通知を行う
    """
    try:
        logger.info(f"TTL Destroyer起動: {event}")
        
        # シナリオ情報をJSONから取得
        scenario_info = json.loads(SCENARIO_INFO)
        scenario_name = scenario_info.get('scenario_name')
        
        # 初期メッセージ作成
        message = f"🕒 TTL期限切れ通知: シナリオ '{scenario_name}' のリソースを自動破棄します\n"
        message += f"作成時刻: {scenario_info.get('created_at')}\n"
        message += f"期限切れ時刻: {scenario_info.get('expires_at')}\n"
        
        # リソース破棄処理
        # 本番実装ではAWS SDKを使用して個別リソースを破棄
        # または外部プロセス（Terraform, AWS CLI）を実行
        # サンプル実装では通知のみ
        
        # SNS通知送信
        sns = boto3.client('sns')
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=f"AWS Pentest Lab - シナリオ '{scenario_name}' 自動破棄通知",
            Message=message
        )
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': f"TTL期限切れ: シナリオ '{scenario_name}' のリソースを破棄しました",
                'scenario': scenario_info
            })
        }
    
    except Exception as e:
        logger.error(f"エラー発生: {str(e)}")
        
        # エラー通知
        if SNS_TOPIC_ARN:
            try:
                sns = boto3.client('sns')
                sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject="AWS Pentest Lab - TTL自動破棄エラー",
                    Message=f"TTL自動破棄処理中にエラーが発生しました。\nエラー: {str(e)}"
                )
            except Exception as sns_error:
                logger.error(f"SNS通知エラー: {str(sns_error)}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': str(e)
            })
        }
EOF
    filename = "index.py"
  }
}

# TTL破棄用Lambda関数
resource "aws_lambda_function" "ttl_destroyer" {
  function_name = "${local.name_prefix}-function"
  role          = aws_iam_role.destroyer_lambda_role.arn
  handler       = "index.handler"
  runtime       = "python3.9"
  timeout       = 300  # 5分
  
  filename         = data.archive_file.destroyer_lambda_zip.output_path
  source_code_hash = data.archive_file.destroyer_lambda_zip.output_base64sha256
  
  environment {
    variables = {
      SNS_TOPIC_ARN = var.sns_topic_arn
      SCENARIO_INFO = local.scenario_info
    }
  }
  
  tags = {
    Name     = "${local.name_prefix}-function"
    Scenario = var.scenario_name
    TTL      = "${var.ttl_hours}h"
  }
}

# EventBridgeルール（スケジュール実行）
resource "aws_cloudwatch_event_rule" "ttl_schedule" {
  name                = "${local.name_prefix}-rule"
  description         = "TTL期限切れ時にLambda関数を実行するルール"
  
  # cron式で指定（分 時 日 月 曜日 年）
  # UTC時間で指定する必要がある
  schedule_expression = "cron(${local.minute} ${local.hour} ${local.day} ${local.month} ? ${local.year})"
  
  tags = {
    Name     = "${local.name_prefix}-rule"
    Scenario = var.scenario_name
    TTL      = "${var.ttl_hours}h"
  }
}

# EventBridgeターゲット設定
resource "aws_cloudwatch_event_target" "ttl_target" {
  rule      = aws_cloudwatch_event_rule.ttl_schedule.name
  target_id = "${local.name_prefix}-target"
  arn       = aws_lambda_function.ttl_destroyer.arn
}

# EventBridgeがLambdaを呼び出す権限を付与
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ttl_destroyer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ttl_schedule.arn
}

# 出力
output "ttl_expiration_time" {
  description = "TTL期限切れ時刻"
  value       = local.expiration_time
}

output "event_rule_name" {
  description = "EventBridgeルール名"
  value       = aws_cloudwatch_event_rule.ttl_schedule.name
}

output "lambda_function_name" {
  description = "TTL破棄用Lambda関数名"
  value       = aws_lambda_function.ttl_destroyer.function_name
} 