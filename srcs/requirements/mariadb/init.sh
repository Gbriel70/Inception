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

# Helper: executa SQL como root com debug
sql_root() {
  echo "Executando SQL: $1"
  if mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -N -B -e "$1" 2>/dev/null; then
    echo "SQL executado com sucesso (sem senha)"
    return 0
  elif mysql --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" -N -B -e "$1" 2>/dev/null; then
    echo "SQL executado com sucesso (com senha)"
    return 0
  else
    echo "ERRO: Falha ao executar SQL: $1"
    return 1
  fi
}

echo "=== Configurando root/DB/usuário ==="

# Define senha do root
echo "1. Configurando senha do root..."
sql_root "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}'" || echo "Aviso: Falha ao alterar senha do root (pode já estar configurada)"

# Cria DB
echo "2. Criando database..."
if sql_root "CREATE DATABASE IF NOT EXISTS \`${MYSQL_DATABASE}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci"; then
  echo "Database criada/já existe."
else
  echo "ERRO: Falha ao criar database"
  exit 1
fi

# Cria usuário
echo "3. Criando usuário..."
if sql_root "CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${MYSQL_PASSWORD}'"; then
  echo "Usuário criado/já existe."
else
  echo "ERRO: Falha ao criar usuário"
  exit 1
fi

# Concede privilégios
echo "4. Concedendo privilégios..."
if sql_root "GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO '${MYSQL_USER}'@'%'"; then
  echo "Privilégios concedidos."
else
  echo "ERRO: Falha ao conceder privilégios"
  exit 1
fi

# Flush privileges
echo "5. Flush privileges..."
if sql_root "FLUSH PRIVILEGES"; then
  echo "Privileges flushed."
else
  echo "ERRO: Falha no flush privileges"
  exit 1
fi

# Verifica se foi criado
echo "=== Verificando criação ==="
sql_root "SHOW DATABASES LIKE '${MYSQL_DATABASE}'" || echo "ERRO: Database não encontrada"
sql_root "SELECT User,Host FROM mysql.user WHERE User='${MYSQL_USER}'" || echo "ERRO: Usuário não encontrado"

echo "Desligando instância temporária..."
mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" shutdown \
|| mysqladmin --protocol=socket --socket=/run/mysqld/mysqld.sock -uroot shutdown

echo "Iniciando MariaDB em modo definitivo..."
exec mariadbd --user=mysql --datadir=/var/lib/mysql --bind-address=0.0.0.0 --socket=/run/mysqld/mysqld.sock