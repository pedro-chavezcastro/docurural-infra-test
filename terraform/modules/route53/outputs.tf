################################################################################
# DocuRural — Módulo Route 53 — outputs.tf
################################################################################

output "fqdn" {
  description = "FQDN completo del registro DNS creado"
  value       = aws_route53_record.app.fqdn
}
