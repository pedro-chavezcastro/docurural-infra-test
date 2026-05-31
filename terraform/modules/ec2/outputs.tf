################################################################################
# DocuRural — Módulo EC2 — outputs.tf
################################################################################

output "instance_id" {
  description = "ID de la instancia EC2"
  value       = aws_instance.this.id
}

output "instance_arn" {
  description = "ARN de la instancia EC2 (para permisos IAM granulares en EventBridge)"
  value       = aws_instance.this.arn
}

output "elastic_ip" {
  description = "Elastic IP pública y fija de la instancia"
  value       = aws_eip.this.public_ip
}

output "security_group_id" {
  description = "ID del Security Group"
  value       = aws_security_group.this.id
}
