################################################################################
# DocuRural — Entorno SHARED
# main.tf — Root module: provider y llamada al módulo github-webhook-relay
#
# A diferencia de develop/qa/prod, este root module NO representa un entorno
# de la aplicación: contiene infraestructura de CI/CD compartida por toda la
# organización (un solo webhook de GitHub, un solo Lambda relay). Vive en su
# propio state para no acoplar su ciclo de vida al de ningún entorno de app —
# un `terraform destroy` de prod no debe llevarse el relay.
#
# Ejecutar desde este directorio:
#   terraform init
#   terraform plan  -var-file=terraform.tfvars
#   terraform apply -var-file=terraform.tfvars
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }

  # Backend local por defecto (el .tfstate queda en este directorio, ya en .gitignore).
  # Para usar backend remoto S3 (recomendado), descomentar y completar:
  # backend "s3" {
  #   bucket         = "docurural-terraform-state"   # bucket creado manualmente
  #   key            = "docurural/shared/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "docurural-terraform-locks"   # tabla creada manualmente
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── Módulos ────────────────────────────────────────────────────────────────

module "github_webhook_relay" {
  source = "../../modules/github-webhook-relay"

  function_name         = var.function_name
  github_webhook_secret = var.github_webhook_secret
  github_dispatch_token = var.github_dispatch_token
  target_repo           = var.target_repo
}
