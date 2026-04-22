#!/bin/bash
set -euo pipefail

# Função para logging
log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

log "=== Iniciando WordPress ==="

# Ler secrets 
read_secret() {
  if [ -f "/run/secrets/$1" ]; then
    cat "/run/secrets/$1"
  else
    log "❌ ERRO: Secret $1 não encontrado"
    exit 1
  fi
}

DB_HOST="mariadb"
DB_NAME=$(read_secret "mysql_database")
DB_USER=$(read_secret "mysql_user")
DB_PASSWORD=$(read_secret "mysql_password")
WP_URL=$(read_secret "wordpress_url")
WP_TITLE=$(read_secret "wordpress_title")
WP_ADMIN=$(read_secret "wordpress_admin_user")
WP_ADMIN_PASS=$(read_secret "wordpress_admin_password")
WP_ADMIN_EMAIL=$(read_secret "wordpress_admin_email")
WP_USER=$(read_secret "wordpress_user")
WP_USER_EMAIL=$(read_secret "wordpress_user_email")
WP_USER_PASS=$(read_secret "wordpress_user_password")
REDIS_HOST=$(read_secret "redis_host")
REDIS_PORT=$(read_secret "redis_port")
REDIS_PASSWORD=$(read_secret "redis_password")

log "✓ Todos os secrets carregados"

# Validar secrets obrigatórios
for var in DB_NAME DB_USER DB_PASSWORD WP_URL WP_ADMIN WP_ADMIN_PASS WP_ADMIN_EMAIL; do
  if [ -z "${!var}" ]; then
    log "❌ ERRO: Variável $var está vazia"
    exit 1
  fi
done

# Aguardar MariaDB
log "Aguardando MariaDB..."
for i in $(seq 1 60); do
  if mysql -h "${DB_HOST}" -u"${DB_USER}" -p"${DB_PASSWORD}" -e "SELECT 1" "${DB_NAME}" >/dev/null 2>&1; then
    log "✓ MariaDB pronto!"
    break
  fi
  if [ $i -eq 60 ]; then
    log "❌ ERRO: MariaDB não respondeu após 60 segundos"
    exit 1
  fi
  sleep 1
done

# Verificar se WordPress já está instalado
if [ ! -f /var/www/html/wp-config.php ]; then
  log "WordPress não encontrado. Instalando..."
  
  # Limpar diretório
  rm -rf /var/www/html/*
  
  # Baixar WordPress
  log "Baixando WordPress..."
  wp core download --allow-root --quiet || {
    log "❌ ERRO ao baixar WordPress"
    exit 1
  }
  
  # Criar wp-config.php
  log "Criando wp-config.php..."
  wp config create \
    --dbname="${DB_NAME}" \
    --dbuser="${DB_USER}" \
    --dbpass="${DB_PASSWORD}" \
    --dbhost="${DB_HOST}" \
    --allow-root --quiet || {
    log "❌ ERRO ao criar wp-config.php"
    exit 1
  }
  
  # Instalar WordPress
  log "Instalando WordPress..."
  wp core install \
    --url="${WP_URL}" \
    --title="${WP_TITLE}" \
    --admin_user="${WP_ADMIN}" \
    --admin_password="${WP_ADMIN_PASS}" \
    --admin_email="${WP_ADMIN_EMAIL}" \
    --skip-email \
    --allow-root --quiet || {
    log "❌ ERRO ao instalar WordPress"
    exit 1
  }
  
  # Criar usuário adicional (opcional)
  if [ -n "${WP_USER}" ] && [ -n "${WP_USER_EMAIL}" ] && [ -n "${WP_USER_PASS}" ]; then
    log "Criando usuário ${WP_USER}..."
    wp user create "${WP_USER}" "${WP_USER_EMAIL}" \
      --role=author \
      --user_pass="${WP_USER_PASS}" \
      --allow-root --quiet || {
      log "⚠ Aviso: Erro ao criar usuário ${WP_USER}"
    }
  fi
  
  log "✓ WordPress instalado com sucesso"
else
  log "✓ WordPress já está instalado"
fi

# Configurar Redis no wp-config.php (sempre, caso o volume tenha sido recriado)
log "Configurando Redis..."
wp config set WP_REDIS_HOST "${REDIS_HOST}" --allow-root 2>/dev/null || true
wp config set WP_REDIS_PORT "${REDIS_PORT}" --raw --allow-root 2>/dev/null || true
wp config set WP_REDIS_PASSWORD "${REDIS_PASSWORD}" --allow-root 2>/dev/null || true

# Instalar plugin redis-cache se ainda não estiver instalado
if ! wp plugin is-installed redis-cache --allow-root 2>/dev/null; then
  log "Instalando plugin redis-cache..."
  wp plugin install /tmp/redis-cache.zip --activate --allow-root --quiet || {
    log "❌ ERRO ao instalar plugin redis-cache"
    exit 1
  }
  log "✓ Plugin redis-cache instalado e ativado"
else
  wp plugin activate redis-cache --allow-root --quiet 2>/dev/null || true
  log "✓ Plugin redis-cache já instalado"
fi

# Habilitar o object cache
wp redis enable --allow-root 2>/dev/null || true

# Ajustar permissões (segurança)
log "Ajustando permissões..."
chown -R www-data:www-data /var/www/html
chmod 755 /var/www/html
chmod 644 /var/www/html/wp-config.php
chmod 755 /var/www/html/wp-content

# Remover histórico de bash para não deixar rastreamento de senhas
history -c 2>/dev/null || true
set +x

log "✓ Iniciando PHP-FPM..."
exec php-fpm -F