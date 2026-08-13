################################################################################
# DocuRural — Entorno PROD
# main.tf — Root module: provider, data sources y llamadas a módulos
#
# Diferencias clave respecto a QA:
#   - EBS 30 GB, S3 Versioning habilitado, puerto 5432 cerrado
#   - Spring profile 'prod', JWT expiration 8h (vs 30min QA)
#   - EventBridge: apagado 10 PM / encendido 6 AM (L–V, hora Colombia)
#   - Budget alarm $30 USD (vs $15 QA)
#   - Admin seed con email/pass institucional
#
# Ejecutar desde este directorio:
#   terraform init
#   terraform plan -var-file=terraform.tfvars
#   terraform apply -var-file=terraform.tfvars
#   terraform destroy -var-file=terraform.tfvars   (⚠ destruye todos los recursos)
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend local por defecto (el .tfstate queda en este directorio, ya en .gitignore).
  # Para usar backend remoto S3 (recomendado para PROD), descomentar y completar:
  # backend "s3" {
  #   bucket         = "docurural-terraform-state"   # bucket creado manualmente
  #   key            = "docurural/prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "docurural-terraform-locks"   # tabla creada manualmente
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── Data sources ──────────────────────────────────────────────────────────────

data "aws_ami" "ubuntu_24" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_route53_zone" "main" {
  zone_id = var.route53_zone_id
}

# ── Módulos (en orden de dependencia) ────────────────────────────────────────

# 1. S3 — documentos (+versioning PROD) + backups + scripts
module "s3" {
  source = "../../modules/s3"

  env                 = "prod"
  bucket_docs_name    = var.bucket_docs_name
  bucket_backups_name = var.bucket_backups_name
  enable_versioning   = true # PROD: versioning para recuperar documentos borrados (spec §14.1.1)
}

# 2. IAM — role con permisos mínimos para el EC2
module "iam" {
  source = "../../modules/iam"

  env                = "prod"
  aws_region         = var.aws_region
  bucket_docs_arn    = module.s3.docs_bucket_arn
  bucket_backups_arn = module.s3.backups_bucket_arn
  bucket_scripts_arn = module.s3.scripts_bucket_arn
  log_group_name     = var.cloudwatch_log_group
}

# 3. SSM Parameter Store — 5 parámetros /docurural/prod/*
module "ssm" {
  source = "../../modules/ssm"

  env                 = "prod"
  aws_region          = var.aws_region
  db_password         = var.db_password
  jwt_secret          = var.jwt_secret
  bucket_docs_name    = module.s3.docs_bucket_name
  bucket_backups_name = module.s3.backups_bucket_name
}

# 4. CloudWatch — log group + billing budget $30 USD
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  env            = "prod"
  log_group_name = var.cloudwatch_log_group
  budget_limit   = var.budget_limit
  alert_email    = var.alert_email
}

# 5. EC2 — instancia + SG + key pair + EIP
module "ec2" {
  source = "../../modules/ec2"

  env                    = "prod"
  aws_region             = var.aws_region
  instance_type          = var.instance_type
  ebs_size               = 30 # PROD: 30 GB (spec §2.1)
  key_name               = "docurural-prod-key"
  ssh_public_key_path    = var.ssh_public_key_path
  admin_ip               = var.admin_ip
  qa_ips                 = [] # PROD: lista vacía → puerto 5432 CERRADO (spec §3.1)
  iam_instance_profile   = module.iam.instance_profile_name
  scripts_bucket_id      = module.s3.scripts_bucket_id
  scripts_bucket_name    = module.s3.scripts_bucket_name
  ami_id                 = data.aws_ami.ubuntu_24.id
  domain_name            = var.domain_name
  certbot_email          = var.certbot_email
  db_password            = var.db_password
  admin_seed_email       = var.admin_seed_email
  admin_seed_password    = var.admin_seed_password
  github_pat             = var.github_pat
  github_repo            = var.github_repo
  github_repo_frontend   = var.github_repo_frontend
  cloudwatch_log_group   = var.cloudwatch_log_group
  spring_profile         = "prod"   # PROD usa perfil prod
  jwt_expiration_ms      = 28800000 # 8 horas (spec §1.2)
  bucket_docs_name       = module.s3.docs_bucket_name
  bucket_backups_name    = module.s3.backups_bucket_name
  pg_remote_access       = false # PROD: PostgreSQL solo en localhost (spec §3.1)
  runner_name_backend    = "docurural-prod-runner"
  runner_name_frontend   = "docurural-prod-runner-frontend"
  runner_labels_backend  = "prod,docurural-backend"
  runner_labels_frontend = "prod,docurural-frontend"
}

# 6. Route 53 — registro A apuntando a la EIP
module "route53" {
  source = "../../modules/route53"

  env         = "prod"
  zone_id     = data.aws_route53_zone.main.zone_id
  domain_name = var.domain_name
  elastic_ip  = module.ec2.elastic_ip
}

# 7. EventBridge — apagado/encendido automático (solo PROD, spec §4.3 / §15)
# ✅ Completamente gratuito (~60 invocaciones/mes; límite gratuito: 14 millones)
module "eventbridge" {
  source = "../../modules/eventbridge"

  instance_id  = module.ec2.instance_id
  instance_arn = module.ec2.instance_arn
  aws_region   = var.aws_region
}
