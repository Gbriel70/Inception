#!/bin/bash

echo "⏳ Aguardando o MariaDB..."
sleep 10

wp core download --allow-root

wp config create \
	--dbname=$WORDPRESS_DB_NAME \
	--dbuser=$WORDPRESS_DB_USER \
	--dbpass=$WORDPRESS_DB_PASSWORD \
	--dbhost=mariadb:3306 \
	--allow-root

wp core install \
	--url=$WORDPRESS_URL \
	--title="$WORDPRESS_TITLE" \
	--admin_user=$WORDPRESS_ADMIN \
	--admin_password=$WORDPRESS_ADMIN_PASSWORD \
	--admin_email=$WORDPRESS_ADMIN_EMAIL \
	--skip-email \
	--allow-root

wp user create $WORDPRESS_USER $WORDPRESS_USER_EMAIL \
	--role=author \
	--user_pass=$WORDPRESS_USER_PASSWORD \
	--allow-root

php-fpm7.3 -F
