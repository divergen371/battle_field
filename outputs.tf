# シナリオの出力（条件付き）

# Metasploitable2の出力
output "metasploitable2_public_ip" {
  description = "Metasploitable2 public IP"
  value       = var.scenario_name == "metasploitable2" || var.scenario_name == "all" ? try(module.metasploitable2[0].metasploitable2_public_ip, "未デプロイ") : "未選択"
}

output "metasploitable2_connection_instructions" {
  description = "Metasploitable2 connection instructions"
  value       = var.scenario_name == "metasploitable2" || var.scenario_name == "all" ? try(module.metasploitable2[0].connection_instructions, "未デプロイ") : "未選択"
}

# 他のシナリオ出力は今後追加

# TTL自動破棄の時刻
output "scheduled_destroy_time" {
  description = "Scheduled resource destroy time"
  value       = formatdate("YYYY-MM-DD HH:mm:ss", timeadd(timestamp(), "${var.ttl_hours}h"))
} 