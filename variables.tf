################################################################################
# DocuRural — Entorno de Pruebas
# variables.tf — Definición de variables
#
# Los valores concretos van en terraform.tfvars (NO subir a Git).
################################################################################

variable "aws_region" {
  description = "Región de AWS donde se despliega el entorno de pruebas"
  type        = string
  default     = "us-east-1" # N. Virginia — la más económica, latencia aceptable desde Colombia
}

variable "instance_type" {
  description = "Tipo de instancia EC2. t3.small es el mínimo recomendado para Spring Boot + PostgreSQL simultáneos"
  type        = string
  default     = "t3.small"

  validation {
    condition     = contains(["t3.small", "t3.medium"], var.instance_type)
    error_message = "Usar t3.small (recomendado) o t3.medium. No usar t3.micro: se queda sin memoria con Spring Boot + PostgreSQL."
  }
}

variable "ssh_public_key_path" {
  description = "Ruta al archivo de clave pública SSH (.pub) para acceso a la instancia"
  type        = string
  default     = "~/.ssh/docurural-test-key.pub"
}

variable "admin_ip" {
  description = "IP del administrador con acceso SSH (formato CIDR, ej: 190.x.x.x/32)"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_ip, 0))
    error_message = "Debe ser una dirección IP válida en formato CIDR (ej: 190.x.x.x/32)."
  }
}

variable "qa_ips" {
  description = "Lista de IPs del equipo de QA con acceso a PostgreSQL (formato CIDR, ej: [\"190.x.x.x/32\"])"
  type        = list(string)
  default     = []

  validation {
    condition     = length(var.qa_ips) > 0
    error_message = "Debe especificar al menos una IP de QA para acceso a PostgreSQL."
  }
}

variable "route53_zone_id" {
  description = "ID de la Hosted Zone de Route 53 donde se crea el registro DNS (ej: Z0XXXXXXXXXXXXXXXXX)"
  type        = string
}

variable "domain_name" {
  description = "Nombre de dominio completo para el entorno de pruebas (ej: pruebas.ccplsolutions.link)"
  type        = string
  default     = "pruebas.ccplsolutions.link"
}

variable "db_password" {
  description = "Contraseña del usuario docurural_user en PostgreSQL"
  type        = string
  sensitive   = true # Terraform oculta este valor en los logs y en el plan

  validation {
    condition     = length(var.db_password) >= 12
    error_message = "La contraseña de la base de datos debe tener al menos 12 caracteres."
  }
}

variable "admin_seed_email" {
  description = "Correo del usuario administrador inicial que crea Flyway en el primer arranque"
  type        = string
  default     = "admin@test.docurural.co"
}

variable "admin_seed_password" {
  description = "Contraseña del usuario administrador inicial"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.admin_seed_password) >= 8
    error_message = "La contraseña del administrador debe tener al menos 8 caracteres."
  }
}

variable "jwt_secret" {
  description = "Clave secreta para firma de tokens JWT (mínimo 32 caracteres)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.jwt_secret) >= 32
    error_message = "El JWT secret debe tener al menos 32 caracteres para ser seguro."
  }
}

variable "github_pat" {
  description = "PAT de GitHub para registrar el runner self-hosted"
  type        = string
  sensitive   = true
}

variable "github_repo" {
  description = "Repositorio en formato owner/repo (ej: miusuario/docurural-backend)"
  type        = string
  default     = "miusuario/docurural-backend"
}

variable "github_repo_frontend" {
  description = "Repositorio frontend GitHub en formato owner/repo"
  type        = string
  default     = "pedro-chavezcastro/docurural-frontend"
}
