variable "aws_region" {
  description = "AWS region to use"
  type        = string
  default     = "ap-northeast-1"
}

variable "ttl_hours" {
  description = "Resource lifetime (hours). Resources will be automatically destroyed after this time."
  type        = number
  default     = 2
}

variable "my_ip_cidr" {
  description = "IP address to allow access (CIDR format)"
  type        = string
  # デフォルト値は実際の使用時に上書きする
  default     = "0.0.0.0/0"
  validation {
    condition     = can(cidrnetmask(var.my_ip_cidr))
    error_message = "my_ip_cidr must be a valid CIDR format (e.g., 1.2.3.4/32)"
  }
}

variable "scenario_name" {
  description = "Scenario name to execute"
  type        = string
  default     = "all"
  validation {
    condition     = contains(["all", "metasploitable2", "juice_shop", "terra_goat", "iam_vulnerable", "cloudgoat_min", "awsgoat_min"], var.scenario_name)
    error_message = "scenario_name must be one of the defined scenarios"
  }
}

variable "project_name" {
  description = "Project name (resource name prefix)"
  type        = string
  default     = "pentest-lab"
}

variable "notification_emails" {
  description = "List of email addresses to send budget overage notifications"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack Webhook URL for notifications (empty string if not set)"
  type        = string
  default     = ""
} 