#!/bin/bash
################################################################################
# DocuRural — Entorno de Pruebas
# user_data.sh — Script de inicialización de Ubuntu
#
# Este script se ejecuta automáticamente en el PRIMER ARRANQUE de la instancia EC2.
# NO requiere conexión SSH manual. Terraform lo inyecta como user_data.
#
# Tiempo estimado de ejecución: 4-6 minutos
# Log de ejecución: /var/log/docurural-init.log
#
# Variables sustituidas por Terraform (templatefile):
#   ${db_password}         — contraseña de PostgreSQL
#   ${admin_seed_email}    — email del administrador inicial
#   ${admin_seed_password} — contraseña del administrador inicial
#   ${jwt_secret}          — clave secreta JWT
#   ${domain_name}         — dominio de Route 53 (ej: pruebas.ccplsolutions.link)
################################################################################

set -euo pipefail
exec > >(tee /var/log/docurural-init.log | logger -t docurural-init) 2>&1

echo "======================================================================"
echo "DocuRural — Inicio de configuración: $(date)"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Actualizar el sistema
# ------------------------------------------------------------------------------
echo "[1/8] Actualizando el sistema..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget unzip

# ------------------------------------------------------------------------------
# 2. Instalar Java 17
# ------------------------------------------------------------------------------
echo "[2/8] Instalando Java 17..."
apt-get install -y openjdk-17-jdk
java -version

# ------------------------------------------------------------------------------
# 3. Instalar y configurar PostgreSQL
# ------------------------------------------------------------------------------
echo "[3/8] Instalando PostgreSQL..."
apt-get install -y postgresql postgresql-contrib
systemctl enable postgresql
systemctl start postgresql

# Crear usuario y base de datos
sudo -u postgres psql <<EOF
CREATE USER docurural_user WITH PASSWORD '${db_password}';
CREATE DATABASE docurural_db OWNER docurural_user;
GRANT ALL PRIVILEGES ON DATABASE docurural_db TO docurural_user;
EOF

# Exponer PostgreSQL para acceso remoto del QA
# (Solo en el entorno de pruebas — NUNCA en producción)
PG_VERSION=$(psql --version | grep -oP '\d+' | head -1)
PG_CONF="/etc/postgresql/$PG_VERSION/main/postgresql.conf"
PG_HBA="/etc/postgresql/$PG_VERSION/main/pg_hba.conf"

# Habilitar escucha en todas las interfaces
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" "$PG_CONF"

# Autorizar conexión remota del QA con autenticación segura
echo "# Acceso remoto QA — DocuRural entorno de pruebas" >> "$PG_HBA"
echo "host    docurural_db    docurural_user    0.0.0.0/0    scram-sha-256" >> "$PG_HBA"

systemctl restart postgresql

# Verificar que PostgreSQL escucha en todas las interfaces
echo "Verificando PostgreSQL..."
ss -tlnp | grep 5432

# ------------------------------------------------------------------------------
# 4. Instalar Nginx
# ------------------------------------------------------------------------------
echo "[4/8] Instalando Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# ------------------------------------------------------------------------------
# 5. Crear estructura de directorios
# ------------------------------------------------------------------------------
echo "[5/8] Creando estructura de directorios..."
mkdir -p /opt/docurural/{backend,frontend,uploads/documents,logs}
chown -R ubuntu:ubuntu /opt/docurural

# ------------------------------------------------------------------------------
# 6. Crear archivo .env
# ------------------------------------------------------------------------------
echo "[6/8] Creando archivo .env..."
cat > /opt/docurural/backend/.env <<ENV
# Base de datos
DB_HOST=localhost
DB_PORT=5432
DB_NAME=docurural_db
DB_USER=docurural_user
DB_PASSWORD=${db_password}

# JWT
JWT_SECRET=${jwt_secret}
JWT_EXPIRATION_MS=1800000
JWT_ISSUER=docurural

# Almacenamiento
UPLOAD_PATH=/opt/docurural/uploads/documents

# Admin inicial (solo se usa en el primer arranque via Flyway seed)
ADMIN_SEED_EMAIL=${admin_seed_email}
ADMIN_SEED_PASSWORD=${admin_seed_password}

# CORS
CORS_ORIGINS=http://${domain_name}

# Perfil Spring
SPRING_PROFILES_ACTIVE=dev
ENV

chmod 600 /opt/docurural/backend/.env
chown ubuntu:ubuntu /opt/docurural/backend/.env

# ------------------------------------------------------------------------------
# 7. Crear servicio systemd
# ------------------------------------------------------------------------------
echo "[7/8] Creando servicio systemd..."
cat > /etc/systemd/system/docurural.service <<SERVICE
[Unit]
Description=DocuRural API - Spring Boot (Test)
After=network.target postgresql.service
Requires=postgresql.service

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/opt/docurural/backend
EnvironmentFile=/opt/docurural/backend/.env
ExecStart=/usr/bin/java -jar /opt/docurural/backend/docurural-api.jar
Restart=on-failure
RestartSec=10
StandardOutput=append:/opt/docurural/logs/app.log
StandardError=append:/opt/docurural/logs/app.log

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
# No se habilita aún: el JAR debe desplegarse antes del primer arranque

# ------------------------------------------------------------------------------
# 8. Configurar Nginx
# ------------------------------------------------------------------------------
echo "[8/8] Configurando Nginx..."

cat > /etc/nginx/sites-available/docurural <<NGINX
server {
    listen 80;
    server_name ${domain_name};

    # Frontend Angular
    root /opt/docurural/frontend/dist/browser;
    index index.html;

    location / {
        try_files \$uri \$uri/ /index.html;
    }

    # API Backend
    location /api/ {
        proxy_pass http://localhost:8080/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_connect_timeout 60s;
        proxy_read_timeout 60s;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/docurural /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# ------------------------------------------------------------------------------
# Finalización
# ------------------------------------------------------------------------------
echo "======================================================================"
echo "DocuRural — Configuración completada: $(date)"
echo ""
echo "PRÓXIMOS PASOS (manuales, una sola vez):"
echo "  1. Copiar el JAR del backend a: /opt/docurural/backend/docurural-api.jar"
echo "  2. Copiar el build de Angular a: /opt/docurural/frontend/dist/browser/"
echo "  3. Habilitar y arrancar el servicio:"
echo "     sudo systemctl enable docurural"
echo "     sudo systemctl start docurural"
echo ""
echo "Log completo de esta ejecución: /var/log/docurural-init.log"
echo "======================================================================"
