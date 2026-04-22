#!/bin/bash
set -euo pipefail

echo "=== Iniciando MariaDB com Secrets ==="

# Ler e validar secrets
for secret in mysql_root_password mysql_database mysql_user mysql_password; do
  if [ ! -f "/run/secrets/${secret}" ]; then
    echo "❌ ERRO: /run/secrets/${secret} não encontrado"
    exit 1
  fi
done

MYSQL_ROOT_PASSWORD=$(cat /run/secrets/mysql_root_password)
MYSQL_DATABASE=$(cat /run/secrets/mysql_database)
MYSQL_USER=$(cat /run/secrets/mysql_user)
MYSQL_PASSWORD=$(cat /run/secrets/mysql_password)

echo "✓ Todos os secrets carregados"

install -d -o mysql -g mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
  echo "Inicializando datadir..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db >/dev/null
fi

echo "Iniciando mariadbd..."
mariadbd --user=mysql --datadir=/var/lib/mysql \
  --bind-address=127.0.0.1 --socket=/run/mysqld/mysqld.sock --skip-networking=0 &
PID=$!

echo "Aguardando MariaDB ficar pronto..."
for i in $(seq 1 60); do
  if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" ping --silent 2>/dev/null; then
    echo "✓ MariaDB pronto!"
    break
  fi
  sleep 1
done

echo "Configurando banco de dados..."
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-SQL
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
  DELETE FROM mysql.user WHERE User='';
  DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
  CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
  GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
  FLUSH PRIVILEGES;
SQL

echo "✓ Banco configurado"
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown >/dev/null 2>&1 || true

sleep 2

echo "Iniciando MariaDB em modo definitivo..."
exec mariadbd --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --socket=/run/mysqld/mysqld.sock