################################################################################
# DocuRural — Entorno de Pruebas
# dns.tf — Registro A en Route 53
################################################################################

resource "aws_route53_record" "docurural_test" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"
  ttl     = 300 # 5 minutos — ideal para entornos de prueba

  records = [aws_eip.docurural_test.public_ip]
}
