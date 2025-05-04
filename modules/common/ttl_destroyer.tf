variable "ttl_hours" {
  description = "Resource lifetime (hours)"
  type        = number
  default     = 2
}

variable "enable_ttl_destroyer" {
  description = "Enable TTL destroyer"
  type        = bool
  default     = true
}

variable "scenario_name" {
  description = "Scenario name to destroy"
  type        = string
}

resource "null_resource" "ttl_destroyer" {
  count = var.enable_ttl_destroyer ? 1 : 0

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

output "ttl_destroy_time" {
  description = "Scheduled resource destroy time"
  value       = null_resource.ttl_destroyer.triggers.destroy_time
} 