#!/bin/bash
set -e

service mysql start

# Espera o socket aparecer
until mysqladmin ping --silent; do
  sleep 1
done

mysql -u root <<-EOSQL
  CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\`;
  CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
  GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
  FLUSH PRIVILEGES;
EOSQL

mysqladmin shutdown

exec mysqld