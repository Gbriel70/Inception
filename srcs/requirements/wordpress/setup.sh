#!/bin/bash
# filepath: /nfs/homes/gcosta-m/projetos/projetos/Inception/srcs/requirements/wordpress/setup.sh
set -e

echo "Aguardando MariaDB..."
until mysql -h mariadb -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" -e "SELECT 1" "$WORDPRESS_DB_NAME" >/dev/null 2>&1; do
  sleep 2
done

echo "Baixando WordPress..."
if [ ! -f wp-config.php ]; then
  wp core download --allow-root
  wp config create \
    --dbname="$WORDPRESS_DB_NAME" \
    --dbuser="$WORDPRESS_DB_USER" \
    --dbpass="$WORDPRESS_DB_PASSWORD" \
    --dbhost="$WORDPRESS_DB_HOST" \
    --allow-root

  wp core install \
    --url="$WORDPRESS_URL" \
    --title="$WORDPRESS_TITLE" \
    --admin_user="$WORDPRESS_ADMIN" \
    --admin_password="$WORDPRESS_ADMIN_PASSWORD" \
    --admin_email="$WORDPRESS_ADMIN_EMAIL" \
    --allow-root

  wp user create "$WORDPRESS_USER" "$WORDPRESS_USER_EMAIL" \
    --role=author \
    --user_pass="$WORDPRESS_USER_PASSWORD" \
    --allow-root
fi

chown -R www-data:www-data /var/www/html
exec php-fpm -F