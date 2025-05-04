variable "aws_region" {
  description = "AWS実行リージョン"
  type        = string
  default     = "ap-northeast-1"
}

variable "ttl_hours" {
  description = "リソースの生存期間（時間）。この時間後に自動破棄されます"
  type        = number
  default     = 2
}

variable "my_ip_cidr" {
  description = "アクセスを許可するIPアドレス（CIDR形式）"
  type        = string
  # デフォルト値は実際の使用時に上書きする
  default     = "0.0.0.0/0"
  validation {
    condition     = can(cidrnetmask(var.my_ip_cidr))
    error_message = "my_ip_cidrは有効なCIDR形式（例：1.2.3.4/32）で指定してください"
  }
}

variable "scenario_name" {
  description = "実行するシナリオ名"
  type        = string
  default     = "all"
  validation {
    condition     = contains(["all", "metasploitable2", "juice_shop", "terra_goat", "iam_vulnerable", "cloudgoat_min", "awsgoat_min"], var.scenario_name)
    error_message = "シナリオ名は定義済みのものから選択してください"
  }
}

variable "project_name" {
  description = "プロジェクト名（リソース名のプレフィックス）"
  type        = string
  default     = "pentest-lab"
}

variable "notification_emails" {
  description = "予算超過通知を送信するメールアドレスのリスト"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack通知用のWebhook URL（設定しない場合は空文字）"
  type        = string
  default     = ""
} 