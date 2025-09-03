#!/bin/bash
# filepath: /nfs/homes/gcosta-m/projetos/projetos/Inception/srcs/requirements/wordpress/setup.sh
set -e

echo "=== WordPress Setup Script ==="
echo "Diretório atual: $(pwd)"
echo "Conteúdo: $(ls -la)"

echo "Aguardando MariaDB..."
until mysql -h mariadb -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -e "SELECT 1" "$WORDPRESS_DB_NAME" >/dev/null 2>&1; do
  echo "Tentando conectar ao MariaDB..."
  sleep 2
done
echo "MariaDB conectado com sucesso!"

echo "Verificando se WordPress já está instalado..."
if [ ! -f wp-config.php ]; then
  echo "WordPress não encontrado. Baixando..."
  

  rm -rf /var/www/html/*
  
  wp core download --allow-root
  echo "WordPress baixado."
  

  echo "Criando wp-config.php..."
  wp config create \
    --dbname="$WORDPRESS_DB_NAME" \
    --dbuser="$WORDPRESS_DB_USER" \
    --dbpass="$WORDPRESS_DB_PASSWORD" \
    --dbhost="$WORDPRESS_DB_HOST" \
    --allow-root
  echo "wp-config.php criado."
  

  echo "Instalando WordPress..."
  wp core install \
    --url="$WORDPRESS_URL" \
    --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --skip-email \
    --allow-root
  echo "WordPress instalado."
  
  echo "Criando usuário adicional..."
  wp user create "$WORDPRESS_USER" "$WORDPRESS_USER_EMAIL" \
    --role=author \
    --user_pass="$WORDPRESS_USER_PASSWORD" \
    --allow-root
  echo "Usuário '$WORDPRESS_USER' criado."
  
else
  echo "WordPress já está instalado."
fi

echo "Ajustando permissões..."
chown -R www-data:www-data /var/www/html

echo "Iniciando PHP-FPM..."
exec php-fpm -F