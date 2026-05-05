################################################################################
# DocuRural — Entorno de Pruebas
# outputs.tf — Valores que Terraform muestra al terminar el apply
################################################################################

output "elastic_ip" {
  description = "IP pública fija de la instancia (usar esta IP para PgAdmin, NO el dominio)"
  value       = aws_eip.docurural_test.public_ip
}

output "url_aplicacion" {
  description = "URL de acceso al sistema DocuRural (disponible ~3 minutos después del apply)"
  value       = "http://${var.domain_name}"
}

output "ssh_command" {
  description = "Comando SSH para conectarse a la instancia"
  value       = "ssh -i ~/.ssh/docurural-test-key.pem ubuntu@${aws_eip.docurural_test.public_ip}"
}

output "pgadmin_host" {
  description = "Host para configurar la conexión en PgAdmin (usar la IP, no el dominio)"
  value       = aws_eip.docurural_test.public_ip
}

output "instance_id" {
  description = "ID de la instancia EC2 (útil para encender/apagar desde la CLI de AWS)"
  value       = aws_instance.docurural_test.id
}

output "nota_costos" {
  description = "Recordatorio de control de costos"
  value       = "IMPORTANTE: Ejecutar 'terraform destroy' al terminar las pruebas para evitar cargos. El EBS (~$1.60/mes) se cobra aunque la instancia esté apagada."
}
