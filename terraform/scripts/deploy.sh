#!/bin/bash
################################################################################
# DocuRural — deploy.sh
# Helper manual de despliegue (fallback cuando el runner de CI/CD no está disponible)
#
# Uso:
#   ./deploy.sh qa|prod [--backend] [--frontend] [--both]
#
# Ejemplos:
#   ./deploy.sh qa --backend              # Sube solo el JAR a QA
#   ./deploy.sh prod --frontend           # Sube solo el frontend a PROD
#   ./deploy.sh qa --both                 # Sube JAR + frontend a QA
#
# Variables requeridas (exportar o editar aquí):
#   ENV_KEY_PATH  — ruta al .pem del entorno
#   ENV_HOST      — Elastic IP del entorno
#   JAR_PATH      — ruta local al JAR (para --backend)
#   FRONTEND_DIST — ruta local al directorio dist/browser (para --frontend)
################################################################################

set -euo pipefail

# ── Parámetros ────────────────────────────────────────────────────────────────

ENV="${1:-}"
MODE="${2:---both}"

if [ -z "$ENV" ] || ! [[ "$ENV" =~ ^(qa|prod)$ ]]; then
  echo "Uso: $0 qa|prod [--backend|--frontend|--both]"
  exit 1
fi

# ── Configuración por entorno ─────────────────────────────────────────────────

if [ "$ENV" = "qa" ]; then
  KEY_PATH="${ENV_KEY_PATH:-$HOME/.ssh/docurural-test-key.pem}"
  SSH_USER="ubuntu"
  # Obtener la IP desde los outputs de Terraform
  HOST="${ENV_HOST:-$(cd "$(dirname "$0")/../envs/qa" && terraform output -raw elastic_ip 2>/dev/null || echo '')}"
else
  KEY_PATH="${ENV_KEY_PATH:-$HOME/.ssh/docurural-prod-key.pem}"
  SSH_USER="ubuntu"
  HOST="${ENV_HOST:-$(cd "$(dirname "$0")/../envs/prod" && terraform output -raw elastic_ip 2>/dev/null || echo '')}"
fi

JAR_PATH="${JAR_PATH:-./docurural-api.jar}"
FRONTEND_DIST="${FRONTEND_DIST:-./dist/browser}"

if [ -z "$HOST" ]; then
  echo "ERROR: No se pudo obtener la IP del entorno $ENV."
  echo "  Exportar la variable ENV_HOST o asegurarse de que Terraform state esté disponible."
  exit 1
fi

SSH_CMD="ssh -i $KEY_PATH -o StrictHostKeyChecking=no $SSH_USER@$HOST"
SCP_CMD="scp -i $KEY_PATH -o StrictHostKeyChecking=no"

echo "======================================================================"
echo "DocuRural — Deploy manual | Entorno: $ENV | Host: $HOST"
echo "======================================================================"

# ── Despliegue del backend (JAR) ──────────────────────────────────────────────

deploy_backend() {
  if [ ! -f "$JAR_PATH" ]; then
    echo "ERROR: No se encontró el JAR en $JAR_PATH"
    exit 1
  fi

  echo "[Backend] Subiendo JAR..."
  $SCP_CMD "$JAR_PATH" "$SSH_USER@$HOST:/opt/docurural/backend/docurural-api.jar"

  echo "[Backend] Reiniciando servicio..."
  $SSH_CMD "sudo systemctl daemon-reload && sudo systemctl enable docurural && sudo systemctl restart docurural"

  echo "[Backend] Verificando arranque (espera 20s)..."
  sleep 20
  $SSH_CMD "sudo systemctl is-active docurural && echo 'OK' || (echo 'ERROR: Revisar logs:' && tail -30 /opt/docurural/logs/app.log)"
}

# ── Despliegue del frontend ───────────────────────────────────────────────────

deploy_frontend() {
  if [ ! -d "$FRONTEND_DIST" ]; then
    echo "ERROR: No se encontró el directorio dist en $FRONTEND_DIST"
    exit 1
  fi

  echo "[Frontend] Subiendo build compilado..."
  $SSH_CMD "rm -rf /opt/docurural/frontend/dist && mkdir -p /opt/docurural/frontend/dist/browser"
  $SCP_CMD -r "$FRONTEND_DIST/." "$SSH_USER@$HOST:/opt/docurural/frontend/dist/browser/"
  $SSH_CMD "chown -R github-runner:github-runner /opt/docurural/frontend/dist"

  echo "[Frontend] Recargando Nginx..."
  $SSH_CMD "sudo nginx -t && sudo systemctl reload nginx"
  echo "[Frontend] Desplegado correctamente."
}

# ── Ejecutar según modo ───────────────────────────────────────────────────────

case "$MODE" in
  --backend)
    deploy_backend
    ;;
  --frontend)
    deploy_frontend
    ;;
  --both|*)
    deploy_backend
    deploy_frontend
    ;;
esac

echo ""
echo "======================================================================"
echo "Deploy completado en $ENV."
echo "  URL: https://$(cd "$(dirname "$0")/../envs/$ENV" && terraform output -raw url_aplicacion 2>/dev/null | sed 's|https://||' || echo $HOST)"
echo "  Logs: $SSH_CMD 'tail -50 /opt/docurural/logs/app.log'"
echo "======================================================================"
