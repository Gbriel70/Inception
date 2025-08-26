#!/bin/bash
set -euo pipefail

: "${MYSQL_ROOT_PASSWORD:=rootpass}"
: "${MYSQL_DATABASE:=wordpress}"
: "${MYSQL_USER:=wpuser}"
: "${MYSQL_PASSWORD:=wppass}"

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

# Aguarda pronto
for i in $(seq 1 60); do
  if mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock ping --silent; then
    break
  fi
  sleep 1
done

# Helper: executa SQL como root (tenta sem senha, depois com senha)
sql_root() {
  mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -N -B -e "$1" \
  || mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "$1"
}

echo "Configurando root/DB/usuário..."
# Define senha do root se ainda não tiver; ignora erro se já estiver com senha/plugin
sql_root "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'" || true
# Cria DB e usuário (idempotente)
sql_root "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"
sql_root "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'"
sql_root "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%'"
sql_root "FLUSH PRIVILEGES"

# Desliga instância temporária
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown \
|| mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot shutdown

# Sobe definitivo
exec mariadbd --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --socket=/run/mysqld/mysqld.sock