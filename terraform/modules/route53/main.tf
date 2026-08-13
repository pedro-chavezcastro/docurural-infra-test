################################################################################
# DocuRural — Módulo Route 53
# Registro A apuntando el dominio del entorno a la Elastic IP (spec §12)
################################################################################

resource "aws_route53_record" "app" {
  zone_id = var.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300 # 5 minutos — mantener bajo hasta que el entorno esté estable

  records = [var.elastic_ip]
}
