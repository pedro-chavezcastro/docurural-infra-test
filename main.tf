################################################################################
# DocuRural — Entorno de Pruebas
# main.tf — Recursos principales: EC2, Security Group, Elastic IP
#
# Uso:
#   terraform init
#   terraform apply          → Crea todo el entorno
#   terraform destroy        → Elimina todo (deja de cobrar)
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ------------------------------------------------------------------------------
# Data sources
# ------------------------------------------------------------------------------

# AMI más reciente de Ubuntu 24.04 LTS en la región seleccionada
data "aws_ami" "ubuntu_24" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (cuenta oficial de Ubuntu en AWS)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Hosted zone de Route 53 (debe existir previamente en tu cuenta de AWS)
data "aws_route53_zone" "main" {
  zone_id = var.route53_zone_id
}

# ------------------------------------------------------------------------------
# Key Pair
# ------------------------------------------------------------------------------

resource "aws_key_pair" "docurural_test" {
  key_name   = "docurural-test-key"
  public_key = file(var.ssh_public_key_path)

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# Security Group
# ------------------------------------------------------------------------------

resource "aws_security_group" "docurural_test" {
  name        = "docurural-test-sg"
  description = "DocuRural entorno de pruebas"

  # HTTP — acceso público al frontend y la API a través de Nginx
  ingress {
    description = "HTTP publico"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH — solo desde la IP del administrador
  ingress {
    description = "SSH administrador"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  # PostgreSQL — solo desde la IP del equipo de QA
  # El puerto 5432 NUNCA se abre al público general
  ingress {
    description = "PostgreSQL QA"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = var.qa_ips
  }

  # Salida — todo permitido (actualizaciones de paquetes, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, { Name = "docurural-test-sg" })
}

# ------------------------------------------------------------------------------
# Instancia EC2
# ------------------------------------------------------------------------------

resource "aws_instance" "docurural_test" {
  ami                    = data.aws_ami.ubuntu_24.id
  instance_type          = var.instance_type
  key_name               = aws_key_pair.docurural_test.key_name
  vpc_security_group_ids = [aws_security_group.docurural_test.id]

  # El script user_data.sh se ejecuta automáticamente en el primer arranque.
  # Instala y configura: Java 17, PostgreSQL, Nginx, estructura de directorios,
  # archivo .env y servicio systemd de DocuRural.
  user_data = templatefile("${path.module}/user_data.sh", {
    db_password          = var.db_password
    admin_seed_email     = var.admin_seed_email
    admin_seed_password  = var.admin_seed_password
    jwt_secret           = var.jwt_secret
    domain_name          = var.domain_name
    github_pat           = var.github_pat
    github_repo          = var.github_repo
  })

  # Almacenamiento raíz: 20 GB gp3
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true # El volumen se elimina junto con la instancia en terraform destroy
  }

  tags = merge(local.common_tags, { Name = "docurural-test" })
}

# ------------------------------------------------------------------------------
# Elastic IP
# ------------------------------------------------------------------------------

resource "aws_eip" "docurural_test" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "docurural-test-eip" })
}

resource "aws_eip_association" "docurural_test" {
  instance_id   = aws_instance.docurural_test.id
  allocation_id = aws_eip.docurural_test.id
}

# ------------------------------------------------------------------------------
# Locales compartidos
# ------------------------------------------------------------------------------

locals {
  common_tags = {
    Project     = "DocuRural"
    Environment = "test"
    ManagedBy   = "Terraform"
  }
}
