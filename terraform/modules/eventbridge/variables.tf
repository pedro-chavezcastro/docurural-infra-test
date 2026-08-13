################################################################################
# DocuRural — Módulo EventBridge Scheduler
# variables.tf
# ⚠  Solo instanciar en envs/prod — no aplica en QA.
################################################################################

variable "instance_id" {
  description = "ID de la instancia EC2 de producción que se controlará (ej: i-0abcdef1234567890)"
  type        = string
}

variable "instance_arn" {
  description = "ARN de la instancia EC2 de producción (ej: arn:aws:ec2:us-east-1:123456789012:instance/i-0abcdef)"
  type        = string
}

variable "aws_region" {
  description = "Región AWS"
  type        = string
}
