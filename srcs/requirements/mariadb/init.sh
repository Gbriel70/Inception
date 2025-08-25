#!/bin/bash
set -euo pipefail

: "${MYSQL_ROOT_PASSWORD:=rootpass}"
: "${MYSQL_DATABASE:=wordpress}"
: "${MYSQL_USER:=wpuser}"
: "${MYSQL_PASSWORD:=wppass}"

# Ajusta permissões e diretórios runtime
install -d -o mysql -g mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

# Inicializa o datadir se vazio
if [ ! -d /var/lib/mysql/mysql ]; then
  echo "Inicializando datadir..."
  mariadb-install-db --user=mysql --datadir=/var/lib/mysql --skip-test-db >/dev/null
fi

# Sobe o servidor em background para configurar
echo "Iniciando mariadbd (fase de configuração)..."
mariadbd --user=mysql --datadir=/var/lib/mysql --bind-address=127.0.0.1 --socket=/run/mysqld/mysqld.sock --skip-networking=0 &
PID=$!

# Aguarda pronto
for i in $(seq 1 60); do
  if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping --silent; then
    break
  fi
  sleep 1
done

# Define senha do root, cria DB e usuário
echo "Configurando usuários e permissões..."
mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -u root <<-SQL
  ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
  CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
  CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}';
  GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%';
  FLUSH PRIVILEGES;
SQL

# Desliga a instância temporária
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -u root -p"${MYSQL_ROOT_PASSWORD}" shutdown

# Sobe em foreground (modo final, ouvindo em 0.0.0.0)
exec mariadbd --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --socket=/run/mysqld/mysqld.sock