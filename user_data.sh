#!/bin/bash
################################################################################
# DocuRural — Entorno de Pruebas
# user_data.sh — Script de inicialización de Ubuntu
#
# Este script se ejecuta automáticamente en el PRIMER ARRANQUE de la instancia EC2.
# NO requiere conexión SSH manual. Terraform lo inyecta como user_data.
#
# Tiempo estimado de ejecución: 8-12 minutos
# Log de ejecución: /var/log/docurural-init.log
#
# Variables sustituidas por Terraform (templatefile):
#   ${db_password}         — contraseña de PostgreSQL
#   ${admin_seed_email}    — email del administrador inicial
#   ${admin_seed_password} — contraseña del administrador inicial
#   ${jwt_secret}          — clave secreta JWT
#   ${domain_name}         — dominio de Route 53 (ej: pruebas.ccplsolutions.link)
#   ${github_pat}          — PAT de GitHub para registrar el runner self-hosted
#   ${github_repo}         — Repositorio GitHub en formato owner/repo
#   ${github_repo_frontend}— Repositorio frontend en formato owner/repo
################################################################################

set -euo pipefail
exec > >(tee /var/log/docurural-init.log | logger -t docurural-init) 2>&1

echo "======================================================================"
echo "DocuRural — Inicio de configuración: $(date)"
echo "======================================================================"

# ------------------------------------------------------------------------------
# 1. Actualizar el sistema
# ------------------------------------------------------------------------------
echo "[1/11] Actualizando el sistema..."
apt-get update -y
apt-get upgrade -y
apt-get install -y curl wget unzip

# ------------------------------------------------------------------------------
# 2. Instalar Java 17 (OpenJDK), Maven y Node.js
# ------------------------------------------------------------------------------
echo "[2/11] Instalando Java 17, Maven y Node.js..."
apt-get install -y openjdk-17-jdk maven
java -version
mvn -version

# Node.js 20 LTS — requerido para el build del frontend Angular
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
node -v
npm -v

# ------------------------------------------------------------------------------
# 3. Instalar y configurar PostgreSQL
# ------------------------------------------------------------------------------
echo "[3/11] Instalando PostgreSQL..."
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
echo "[4/11] Instalando Nginx..."
apt-get install -y nginx
systemctl enable nginx
systemctl start nginx

# ------------------------------------------------------------------------------
# 5. Crear estructura de directorios
# ------------------------------------------------------------------------------
echo "[5/11] Creando estructura de directorios..."
mkdir -p /opt/docurural/{backend,frontend,uploads/documents,logs}
chown -R ubuntu:ubuntu /opt/docurural

# ------------------------------------------------------------------------------
# 6. Crear archivo .env
# ------------------------------------------------------------------------------
echo "[6/11] Creando archivo .env..."
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
DOCURURAL_STORAGE_BASE_PATH=/opt/docurural/uploads/documents

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
echo "[7/11] Creando servicio systemd..."
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
echo "[8/11] Configurando Nginx..."

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
        client_max_body_size 55M;
    }
}
NGINX

ln -sf /etc/nginx/sites-available/docurural /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

# ------------------------------------------------------------------------------
# 9. Instalar y registrar el runner self-hosted de GitHub Actions
# ------------------------------------------------------------------------------
echo "[9/11] Instalando runner de GitHub Actions..."

# Dependencias del runner
apt-get install -y jq libicu-dev

# Usuario dedicado — el runner nunca corre como root
useradd -m -s /bin/bash github-runner || true

# Ahora que el usuario existe, asignarle el directorio de despliegue
chown github-runner:github-runner /opt/docurural/backend
chown github-runner:github-runner /opt/docurural/frontend

# Permitir al usuario ubuntu escribir en el directorio (para despliegues manuales)
usermod -aG github-runner ubuntu
chmod g+w /opt/docurural/backend
chmod g+w /opt/docurural/frontend

# Directorio del runner
mkdir -p /opt/github-runner
cd /opt/github-runner

# Descargar la última versión estable del runner
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest \
  | jq -r '.tag_name' | sed 's/v//')
echo "Descargando runner v$RUNNER_VERSION..."
curl -fsSL -o actions-runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner.tar.gz
rm actions-runner.tar.gz
chown -R github-runner:github-runner /opt/github-runner

# Obtener token de registro fresco usando el PAT
# (El PAT nunca caduca; el token de registro obtenido aquí expira en 1 hora,
#  suficiente para completar este script)
echo "Obteniendo token de registro..."
REGISTRATION_TOKEN=$(curl -fsSL -X POST \
  -H "Authorization: token ${github_pat}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${github_repo}/actions/runners/registration-token" \
  | jq -r '.token')

if [ -z "$REGISTRATION_TOKEN" ] || [ "$REGISTRATION_TOKEN" = "null" ]; then
  echo "ERROR: No se pudo obtener el token de registro. Verificar el PAT y el repositorio."
  exit 1
fi

# Registrar el runner
echo "Registrando runner 'docurural-qa-runner'..."
sudo -u github-runner /opt/github-runner/config.sh \
  --url "https://github.com/${github_repo}" \
  --token "$REGISTRATION_TOKEN" \
  --name "docurural-qa-runner" \
  --labels "qa,docurural-backend" \
  --runnergroup "Default" \
  --unattended \
  --replace

# Instalar como servicio systemd y arrancar
/opt/github-runner/svc.sh install github-runner
/opt/github-runner/svc.sh start

echo "Runner registrado y activo."

# ------------------------------------------------------------------------------
# Runner para docurural-frontend (segundo runner en el mismo EC2)
# ------------------------------------------------------------------------------
echo "Instalando runner para docurural-frontend..."

mkdir -p /opt/github-runner-frontend
cd /opt/github-runner-frontend

curl -fsSL -o actions-runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v$${RUNNER_VERSION}/actions-runner-linux-x64-$${RUNNER_VERSION}.tar.gz"
tar xzf actions-runner.tar.gz
rm actions-runner.tar.gz
chown -R github-runner:github-runner /opt/github-runner-frontend

# Obtener token de registro para docurural-frontend
echo "Obteniendo token de registro para frontend..."
REGISTRATION_TOKEN_FRONTEND=$(curl -fsSL -X POST \
  -H "Authorization: token ${github_pat}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${github_repo_frontend}/actions/runners/registration-token" \
  | jq -r '.token')

if [ -z "$REGISTRATION_TOKEN_FRONTEND" ] || [ "$REGISTRATION_TOKEN_FRONTEND" = "null" ]; then
  echo "ERROR: No se pudo obtener el token de registro del frontend. Verificar el PAT y el repositorio."
  exit 1
fi

# Registrar el runner del frontend
echo "Registrando runner 'docurural-qa-runner-frontend'..."
sudo -u github-runner /opt/github-runner-frontend/config.sh \
  --url "https://github.com/${github_repo_frontend}" \
  --token "$REGISTRATION_TOKEN_FRONTEND" \
  --name "docurural-qa-runner-frontend" \
  --labels "qa,docurural-frontend" \
  --runnergroup "Default" \
  --unattended \
  --replace

# Instalar como servicio systemd y arrancar
/opt/github-runner-frontend/svc.sh install github-runner
/opt/github-runner-frontend/svc.sh start

echo "Runner frontend registrado y activo."

# Permitir al runner ejecutar únicamente comandos del servicio docurural sin contraseña
cat > /etc/sudoers.d/github-runner <<'SUDOERS'
github-runner ALL=(ALL) NOPASSWD: /usr/bin/systemctl enable docurural, /usr/bin/systemctl disable docurural, /usr/bin/systemctl start docurural, /usr/bin/systemctl stop docurural, /usr/bin/systemctl restart docurural, /usr/bin/systemctl status docurural, /usr/bin/systemctl status docurural *, /usr/bin/systemctl is-active docurural, /usr/bin/systemctl is-active docurural *, /usr/bin/systemctl daemon-reload, /usr/sbin/nginx
SUDOERS
chmod 440 /etc/sudoers.d/github-runner

# ------------------------------------------------------------------------------
# 10. Descargar el JAR más reciente de GitHub Packages y arrancar el servicio
# ------------------------------------------------------------------------------
echo "[10/11] Intentando descargar el JAR más reciente de GitHub Packages..."

# Extraer el owner del github_repo (formato owner/repo)
GITHUB_OWNER=$(echo "${github_repo}" | cut -d'/' -f1)

# Crear settings.xml temporal para autenticación en GitHub Packages
cat > /tmp/settings-download.xml <<SETTINGS
<settings>
  <servers>
    <server>
      <id>github</id>
      <username>x-access-token</username>
      <password>${github_pat}</password>
    </server>
  </servers>
</settings>
SETTINGS

# Verificar si existe alguna versión publicada en GitHub Packages
PACKAGE_EXISTS=$(curl -fsSL \
  -H "Authorization: token ${github_pat}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/users/$${GITHUB_OWNER}/packages/maven/co.edu.docurural.docurural-backend/versions" \
  2>/dev/null | jq 'length')

if [ -z "$PACKAGE_EXISTS" ] || [ "$PACKAGE_EXISTS" = "0" ]; then
  echo "ADVERTENCIA: No se encontró ningún JAR publicado en GitHub Packages."
  echo "  El servicio docurural NO se iniciará ahora."
  echo "  Se iniciará automáticamente tras el primer push a 'develop'."
else
  echo "JAR encontrado en GitHub Packages ($PACKAGE_EXISTS versión/es). Descargando via Maven..."

  # Maven resuelve y descarga el SNAPSHOT más reciente automáticamente
  sudo -u ubuntu mvn dependency:get \
    -Dartifact=co.edu.docurural:docurural-backend:0.0.1-SNAPSHOT:jar \
    -DremoteRepositories="github::default::https://maven.pkg.github.com/${github_repo}" \
    -Dmaven.repo.local=/tmp/docurural-download \
    --batch-mode --no-transfer-progress \
    -s /tmp/settings-download.xml

  # Localizar el JAR descargado
  JAR_ORIGEN=$(find /tmp/docurural-download -name "docurural-backend-*.jar" | head -1)

  if [ -n "$JAR_ORIGEN" ]; then
    cp "$JAR_ORIGEN" /opt/docurural/backend/docurural-api.jar
    chown github-runner:github-runner /opt/docurural/backend/docurural-api.jar
    echo "JAR copiado correctamente: $JAR_ORIGEN"

    # Arrancar el servicio
    systemctl enable docurural
    systemctl start docurural

    # Esperar y verificar que quedó activo
    sleep 20
    if systemctl is-active --quiet docurural; then
      echo "Servicio docurural iniciado correctamente."
    else
      echo "ADVERTENCIA: El servicio no quedó activo. Revisar logs:"
      echo "  tail -f /opt/docurural/logs/app.log"
    fi
  else
    echo "ADVERTENCIA: Maven no pudo descargar el JAR. Revisar credenciales y nombre del artefacto."
    echo "  El servicio docurural NO se iniciará ahora."
  fi
fi

# Limpiar archivos temporales
rm -f /tmp/settings-download.xml
rm -rf /tmp/docurural-download

# ------------------------------------------------------------------------------
# 11. Descargar y desplegar el frontend desde GitHub
# ------------------------------------------------------------------------------
echo "[11/11] Intentando desplegar el frontend desde GitHub..."

# Verificar si existe código en la rama develop del frontend
FRONTEND_SHA=$(curl -fsSL \
  -H "Authorization: token ${github_pat}" \
  -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/${github_repo_frontend}/commits/develop" \
  2>/dev/null | jq -r '.sha // empty')

if [ -z "$FRONTEND_SHA" ]; then
  echo "ADVERTENCIA: No se encontró código en la rama develop de docurural-frontend."
  echo "  El frontend NO se desplegará ahora."
  echo "  Se desplegará automáticamente tras el primer push a 'develop'."
else
  echo "Código encontrado en develop (commit: $FRONTEND_SHA). Clonando repositorio..."

  # Clonar solo la rama develop (sin historial completo para ahorrar espacio)
  sudo -u github-runner git clone \
    --branch develop \
    --depth 1 \
    "https://x-access-token:${github_pat}@github.com/${github_repo_frontend}.git" \
    /tmp/docurural-frontend-build

  # Instalar dependencias y construir
  echo "Instalando dependencias npm..."
  cd /tmp/docurural-frontend-build
  sudo -u github-runner npm ci

  echo "Ejecutando ng build..."
  sudo -u github-runner npm run build -- --configuration production

  # Verificar que el build generó archivos
  if [ -d "/tmp/docurural-frontend-build/dist/docurural-frontend/browser" ]; then
    # Limpiar build anterior y copiar el nuevo
    rm -rf /opt/docurural/frontend/dist
    mkdir -p /opt/docurural/frontend/dist/browser
    cp -r /tmp/docurural-frontend-build/dist/docurural-frontend/browser/. /opt/docurural/frontend/dist/browser/
    chown -R github-runner:github-runner /opt/docurural/frontend/dist
    echo "Frontend desplegado correctamente."

    # Recargar Nginx para servir el nuevo build
    nginx -s reload
    echo "Nginx recargado."
  else
    echo "ADVERTENCIA: El build no generó la carpeta dist/browser esperada."
    echo "  Verificar el angular.json del proyecto frontend."
  fi

  # Limpiar archivos temporales
  rm -rf /tmp/docurural-frontend-build
fi

# ------------------------------------------------------------------------------
# Finalización
# ------------------------------------------------------------------------------
echo "======================================================================"
echo "DocuRural — Configuración completada: $(date)"
echo ""
echo "ENTORNO APROVISIONADO:"
echo "  Java 17:     $(java -version 2>&1 | head -1)"
echo "  Maven:       $(mvn -version 2>&1 | head -1)"
echo "  PostgreSQL:  $(psql --version)"
echo "  Nginx:       $(nginx -v 2>&1)"
echo ""
echo "SERVICIOS ACTIVOS:"
echo "  PostgreSQL:  $(systemctl is-active postgresql)"
echo "  Nginx:       $(systemctl is-active nginx)"
echo "  Runner:      $(systemctl is-active actions.runner.* 2>/dev/null | head -1 || echo 'verificar manualmente')"
echo "  DocuRural:   $(systemctl is-active docurural)"
echo ""
echo "RUNNER DE GITHUB ACTIONS:"
echo "  Nombre:      docurural-qa-runner"
echo "  Labels:      qa, docurural-backend"
echo "  Repositorio: https://github.com/${github_repo}"
echo "  Estado:      https://github.com/${github_repo}/settings/actions/runners"
echo "  Runner frontend: docurural-qa-runner-frontend"
echo "  Labels frontend: qa, docurural-frontend"
echo "  Estado frontend: https://github.com/${github_repo_frontend}/settings/actions/runners"
echo ""
echo "APLICACIÓN:"
echo "  JAR:         /opt/docurural/backend/docurural-api.jar"
echo "  Config:      /opt/docurural/backend/.env"
echo "  Logs:        /opt/docurural/logs/app.log"
echo "  API:         http://${domain_name}/api/"
echo ""
echo "COMANDOS ÚTILES:"
echo "  Ver logs de la app:       tail -f /opt/docurural/logs/app.log"
echo "  Ver logs de este script:  cat /var/log/docurural-init.log"
echo "  Estado del servicio:      sudo systemctl status docurural"
echo "  Reiniciar servicio:       sudo systemctl restart docurural"
echo "  Estado del runner:        sudo systemctl status actions.runner.*.docurural-qa-runner"
echo "  Reiniciar runner:         sudo systemctl restart actions.runner.*.docurural-qa-runner"
echo "  Estado runner frontend:   sudo systemctl status actions.runner.*.docurural-qa-runner-frontend"
echo "  Logs frontend:            ls -lh /opt/docurural/frontend/dist/browser/"
echo "  Conectar a PostgreSQL:    sudo -u postgres psql -d docurural_db"
echo ""
echo "FLUJO CI/CD:"
echo "  Push a feature/* o fix/*  → CI (compilación + pruebas)"
echo "  PR aprobado → develop     → CD (build + deploy automático en este servidor)"
echo "  Paquetes publicados:      https://github.com/${github_repo}/packages"
echo ""
echo "Log completo de esta ejecución: /var/log/docurural-init.log"
echo "======================================================================"