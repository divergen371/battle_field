variable "ttl_hours" {
  description = "リソースの生存期間（時間）"
  type        = number
  default     = 2
}

variable "enabled" {
  description = "TTL破棄機能を有効にするか"
  type        = bool
  default     = true
}

variable "scenario_name" {
  description = "破棄対象のシナリオ名"
  type        = string
}

resource "null_resource" "ttl_destroyer" {
  count = var.enabled ? 1 : 0

  # TTL時間が変更されたら再実行
  triggers = {
    ttl_hours = var.ttl_hours
  }

  # terraform destroyをバックグラウンドで予約実行
  provisioner "local-exec" {
    command = <<-EOT
      (
        # バックグラウンドで実行
        echo "TTL: ${var.ttl_hours}時間後（$(date -d "+${var.ttl_hours} hour" "+%Y-%m-%d %H:%M:%S")）に'${var.scenario_name}'シナリオを自動破棄します"
        sleep ${var.ttl_hours * 3600}
        cd ${path.root}
        echo "TTL期限切れ: '${var.scenario_name}'シナリオを自動破棄します（$(date "+%Y-%m-%d %H:%M:%S")）"
        terraform destroy -auto-approve -var="scenario_name=${var.scenario_name}"
      ) &>/tmp/ttl_destroyer_${var.scenario_name}.log &
    EOT
  }
}

output "destruction_time" {
  description = "リソース自動破棄予定時刻"
  value       = var.enabled ? formatdate("YYYY-MM-DD HH:mm:ss", timeadd(timestamp(), "${var.ttl_hours}h")) : "無効"
} 