################################################################################
# DocuRural — Módulo EventBridge — outputs.tf
################################################################################

output "apagado_schedule_arn" {
  description = "ARN del schedule de apagado nocturno (10 PM Colombia, L–V)"
  value       = aws_scheduler_schedule.apagado_nocturno.arn
}

output "encendido_schedule_arn" {
  description = "ARN del schedule de encendido matutino (6 AM Colombia, L–V)"
  value       = aws_scheduler_schedule.encendido_matutino.arn
}
