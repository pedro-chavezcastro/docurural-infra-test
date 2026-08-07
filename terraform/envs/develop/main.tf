################################################################################
# DocuRural — Entorno DEVELOP
# main.tf — Root module: provider, data sources y llamadas a módulos
#
# Diferencias clave respecto a QA:
#   - Instancia t3.micro (vs t3.small), EBS 10 GB (vs 20 GB) — entorno liviano
#   - Presupuesto mensual $10 USD (vs $15 QA)
#   - Dominio dev.ccplsolutions.link (vs pruebas.ccplsolutions.link)
#   - Sin EventBridge (igual que QA — se apaga manualmente para control de costos)
#
# Ejecutar desde este directorio:
#   terraform init
#   terraform plan -var-file=terraform.tfvars
#   terraform apply -var-file=terraform.tfvars
#   terraform destroy -var-file=terraform.tfvars   (elimina todos los recursos)
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
  # Para usar backend remoto S3 (recomendado en equipo o CI), descomentar y completar:
  # backend "s3" {
  #   bucket         = "docurural-terraform-state"   # bucket creado manualmente
  #   key            = "docurural/develop/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "docurural-terraform-locks"   # tabla creada manualmente
  # }
}

provider "aws" {
  region = var.aws_region
}

# ── Data sources ──────────────────────────────────────────────────────────────

# AMI más reciente de Ubuntu 24.04 LTS (Canonical)
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

# Hosted Zone existente en Route 53 (debe existir previamente)
data "aws_route53_zone" "main" {
  zone_id = var.route53_zone_id
}

# ── Módulos (en orden de dependencia) ────────────────────────────────────────

# 1. S3 — documentos (sin versioning en DEVELOP) + backups + scripts
module "s3" {
  source = "../../modules/s3"

  env                 = "develop"
  bucket_docs_name    = var.bucket_docs_name
  bucket_backups_name = var.bucket_backups_name
  enable_versioning   = false # Solo PROD activa versioning (spec §6.1)
}

# 2. IAM — role con permisos mínimos para el EC2
module "iam" {
  source = "../../modules/iam"

  env                = "develop"
  aws_region         = var.aws_region
  bucket_docs_arn    = module.s3.docs_bucket_arn
  bucket_backups_arn = module.s3.backups_bucket_arn
  bucket_scripts_arn = module.s3.scripts_bucket_arn
  log_group_name     = var.cloudwatch_log_group
}

# 3. SSM Parameter Store — 5 parámetros /docurural/develop/*
module "ssm" {
  source = "../../modules/ssm"

  env                 = "develop"
  aws_region          = var.aws_region
  db_password         = var.db_password
  jwt_secret          = var.jwt_secret
  bucket_docs_name    = module.s3.docs_bucket_name
  bucket_backups_name = module.s3.backups_bucket_name
}

# 4. CloudWatch — log group + billing budget $10 USD
module "cloudwatch" {
  source = "../../modules/cloudwatch"

  env            = "develop"
  log_group_name = var.cloudwatch_log_group
  budget_limit   = var.budget_limit
  alert_email    = var.alert_email
}

# 5. EC2 — instancia + SG + key pair + EIP
module "ec2" {
  source = "../../modules/ec2"

  env                    = "develop"
  aws_region             = var.aws_region
  instance_type          = var.instance_type
  ebs_size               = 10 # DEVELOP: 10 GB — entorno liviano
  key_name               = "docurural-develop-key"
  ssh_public_key_path    = var.ssh_public_key_path
  admin_ip               = var.admin_ip
  qa_ips                 = var.qa_ips # Puerto 5432 abierto para acceso remoto (PgAdmin)
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
  spring_profile         = "develop" # DEVELOP usa perfil develop
  jwt_expiration_ms      = 1800000   # 30 min (igual que QA)
  bucket_docs_name       = module.s3.docs_bucket_name
  bucket_backups_name    = module.s3.backups_bucket_name
  pg_remote_access       = true # DEVELOP expone 5432 para PgAdmin
  runner_name_backend    = "docurural-develop-runner"
  runner_name_frontend   = "docurural-develop-runner-frontend"
  runner_labels_backend  = "develop,docurural-backend"
  runner_labels_frontend = "develop,docurural-frontend"
}

# 6. Route 53 — registro A apuntando a la EIP
module "route53" {
  source = "../../modules/route53"

  env         = "develop"
  zone_id     = data.aws_route53_zone.main.zone_id
  domain_name = var.domain_name
  elastic_ip  = module.ec2.elastic_ip
}

# EventBridge NO se usa en DEVELOP — la instancia se apaga manualmente para control de costos
