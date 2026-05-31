################################################################################
# DocuRural — Módulo CloudWatch
# variables.tf
################################################################################

variable "env" {
  description = "Entorno: 'test' (QA) o 'prod'"
  type        = string
}

variable "log_group_name" {
  description = "Nombre del log group de CloudWatch (ej: /docurural-test/app o /docurural/app)"
  type        = string
}

variable "budget_limit" {
  description = "Límite del presupuesto mensual en USD. QA: 15, PROD: 30."
  type        = number
}

variable "alert_email" {
  description = "Email del administrador para recibir alertas de billing al 80% del presupuesto"
  type        = string
}
