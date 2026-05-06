################################################################################
# DocuRural — Entorno de Pruebas
# main.tf — Recursos principales: EC2, Security Group, Elastic IP, S3, IAM
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
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
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
# Random suffix — garantiza nombre único para el bucket S3
# ------------------------------------------------------------------------------

resource "random_id" "suffix" {
  byte_length = 4
}

# ------------------------------------------------------------------------------
# S3 — Bucket para almacenar el script de inicialización
#
# El user_data de EC2 tiene un límite de 16 KB. El user_data.sh de DocuRural
# supera ese límite, por lo que se sube a S3 y el user_data solo lo descarga
# y ejecuta. El bucket es privado y la instancia accede mediante un rol IAM.
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "scripts" {
  bucket = "docurural-scripts-${random_id.suffix.hex}"

  tags = merge(local.common_tags, { Name = "docurural-scripts" })
}

resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Renderiza el user_data.sh con templatefile y lo sube al bucket
resource "aws_s3_object" "user_data_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "user_data.sh"

  content = templatefile("${path.module}/user_data.sh", {
    db_password          = var.db_password
    admin_seed_email     = var.admin_seed_email
    admin_seed_password  = var.admin_seed_password
    jwt_secret           = var.jwt_secret
    domain_name          = var.domain_name
    github_pat           = var.github_pat
    github_repo          = var.github_repo
    github_repo_frontend = var.github_repo_frontend
  })

  # Forzar re-subida si el contenido del script cambia
  etag = md5(templatefile("${path.module}/user_data.sh", {
    db_password          = var.db_password
    admin_seed_email     = var.admin_seed_email
    admin_seed_password  = var.admin_seed_password
    jwt_secret           = var.jwt_secret
    domain_name          = var.domain_name
    github_pat           = var.github_pat
    github_repo          = var.github_repo
    github_repo_frontend = var.github_repo_frontend
  }))

  tags = merge(local.common_tags, { Name = "docurural-user-data-script" })
}

# ------------------------------------------------------------------------------
# IAM — Rol para que el EC2 pueda leer el script desde S3
# ------------------------------------------------------------------------------

resource "aws_iam_role" "ec2_role" {
  name = "docurural-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(local.common_tags, { Name = "docurural-ec2-role" })
}

# Política mínima: solo permite leer objetos del bucket de scripts
resource "aws_iam_role_policy" "s3_read_scripts" {
  name = "docurural-s3-read-scripts"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "${aws_s3_bucket.scripts.arn}/*"
    }]
  })
}

# Instance profile — vincula el rol IAM a la instancia EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "docurural-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(local.common_tags, { Name = "docurural-ec2-profile" })
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

  # Salida — todo permitido (actualizaciones de paquetes, descarga de S3, etc.)
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
  iam_instance_profile   = aws_iam_instance_profile.ec2_profile.name

  # El user_data ahora es un bootstrap mínimo (~5 líneas) que descarga el
  # user_data.sh completo desde S3 y lo ejecuta. Esto evita el límite de 16 KB
  # que impone AWS para el campo user_data.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    apt-get update -y
    apt-get install -y curl unzip
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install
    rm -rf /tmp/awscliv2.zip /tmp/aws
    aws s3 cp s3://${aws_s3_bucket.scripts.bucket}/user_data.sh /tmp/user_data.sh
    chmod +x /tmp/user_data.sh
    bash /tmp/user_data.sh
  EOF

  # Forzar recreación de la instancia si el script en S3 cambia
  user_data_replace_on_change = false

  # Almacenamiento raíz: 20 GB gp3
  root_block_device {
    volume_type           = "gp3"
    volume_size           = 20
    delete_on_termination = true # El volumen se elimina junto con la instancia en terraform destroy
  }

  # La instancia depende del script en S3 — debe existir antes de arrancar
  depends_on = [aws_s3_object.user_data_script]

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
