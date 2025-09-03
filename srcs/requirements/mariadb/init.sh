#!/bin/bash
set -euo pipefail

: "${MYSQL_ROOT_PASSWORD:=rootpass}"
: "${MYSQL_DATABASE:=wordpress}"
: "${MYSQL_USER:=wpuser}"
: "${MYSQL_PASSWORD:=wppass}"

echo "=== MariaDB Init Script - Variáveis ==="
echo "MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD:+set}"
echo "MYSQL_DATABASE: $MYSQL_DATABASE"
echo "MYSQL_USER: $MYSQL_USER"
echo "MYSQL_PASSWORD: ${MYSQL_PASSWORD:+set}"

install -d -o mysql -g mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

if [ ! -d /var/lib/mysql/mysql ]; then
  echo "Inicializando datadir..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db >/dev/null
fi

echo "Iniciando mariadbd (fase de configuração)..."
mariadbd --user=mysql --datadir=/var/lib/mysql \
  --bind-address=127.0.0.1 --socket=/run/mysqld/mysqld.sock --skip-networking=0 &
PID=$!

echo "Aguardando MariaDB ficar pronto..."
READY=0
for i in $(seq 1 60); do
  if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping --silent; then
    READY=1
    echo "MariaDB pronto após $i tentativas."
    break
  fi
  sleep 1
done

if [ "$READY" -ne 1 ]; then
  echo "ERRO: MariaDB não ficou pronto."
  exit 1
fi

echo "=== Configurando root/DB/usuário ==="

echo "Executando configuração SQL..."
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot <<-SQL
  -- Define senha do root
  SET PASSWORD FOR 'root'@'localhost' = PASSWORD('${MYSQL_ROOT_PASSWORD}');
  
  -- Cria database
  CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
  
  -- Cria usuário
  CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
  
  -- Concede privilégios
  GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
  
  -- Flush privileges
  FLUSH PRIVILEGES;
  
  -- Verifica criação
  SHOW DATABASES LIKE '${MYSQL_DATABASE}';
  SELECT User, Host FROM mysql.user WHERE User='${MYSQL_USER}';
SQL

echo "Configuração SQL concluída."

echo "Desligando instância temporária..."
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown

echo "Iniciando MariaDB em modo definitivo..."
exec mariadbd --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --socket=/run/mysqld/mysqld.sock