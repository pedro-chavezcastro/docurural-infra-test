################################################################################
# DocuRural — Módulo Route 53
# variables.tf
################################################################################

variable "env" {
  description = "Entorno: 'test' (QA) o 'prod'"
  type        = string
}

variable "zone_id" {
  description = "ID de la Hosted Zone de Route 53 (ej: Z0XXXXXXXXXXXXXXXXX)"
  type        = string
}

variable "domain_name" {
  description = "FQDN completo del entorno (ej: pruebas.ccplsolutions.link)"
  type        = string
}

variable "elastic_ip" {
  description = "Dirección IP pública fija (Elastic IP) a la que apunta el registro A"
  type        = string
}
