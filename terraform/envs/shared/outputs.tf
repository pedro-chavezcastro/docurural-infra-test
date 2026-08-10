################################################################################
# DocuRural — Entorno SHARED — outputs.tf
################################################################################

output "webhook_relay_url" {
  description = "Payload URL a registrar en https://github.com/organizations/CCPL-Solutions/settings/hooks"
  value       = module.github_webhook_relay.function_url
}

output "webhook_relay_log_command" {
  description = "Comando para seguir los logs del relay en vivo"
  value       = "aws logs tail ${module.github_webhook_relay.log_group_name} --follow"
}
