# 🐳 Inception - WordPress em Docker

> Uma solução completa de infraestrutura containerizada para WordPress com cache Redis, segurança em camadas e performance otimizada.

<div align="center">

[![Docker](https://img.shields.io/badge/Docker-2496ED?style=for-the-badge&logo=docker&logoColor=white)](https://www.docker.com/)
[![WordPress](https://img.shields.io/badge/WordPress-21759B?style=for-the-badge&logo=wordpress&logoColor=white)](https://wordpress.org/)
[![Nginx](https://img.shields.io/badge/Nginx-009639?style=for-the-badge&logo=nginx&logoColor=white)](https://nginx.org/)
[![Redis](https://img.shields.io/badge/Redis-DC382D?style=for-the-badge&logo=redis&logoColor=white)](https://redis.io/)
[![MariaDB](https://img.shields.io/badge/MariaDB-003545?style=for-the-badge&logo=mariadb&logoColor=white)](https://mariadb.org/)

[🚀 Quick Start](#-quick-start) • [🏗️ Arquitetura](#-arquitetura) • [📚 Documentação](#-documentação-completa) • [❓ FAQ](#-faq)

</div>

---

## 🎯 Sobre o Projeto

**Inception** é um ambiente completo de WordPress em Docker com:

✅ **Nginx** - Reverse proxy com SSL/TLS  
✅ **WordPress** - PHP-FPM com múltiplos workers  
✅ **Redis** - Cache inteligente (70x mais rápido)  
✅ **MariaDB** - Banco de dados persistente  
✅ **Segurança** - Network isolada, secrets, sem root  

---

## 🚀 Quick Start

### 1️⃣ Pré-requisitos

```bash
# Verificar Docker
docker --version     # 20.10+
docker compose version  # 2.0+

# Ubuntu/Debian
sudo apt-get install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
newgrp docker
```

### 2️⃣ Clonar & Criar Estrutura

```bash
git clone https://github.com/Gbriel70/Inception.git
cd Inception/srcs

# Criar diretórios
cd srcs
mkdir -p secrets/{mysql,wordpress,redis}
cd $HOME
mkdir -p ~/data/{wordpress,mariadb,redis}
```

### 3️⃣ Criar Secrets

#### **MySQL Secrets**
```bash
# Gerar senhas
openssl rand -base64 32 > secrets/mysql/mysql_root_password.txt
openssl rand -base64 32 > secrets/mysql/mysql_password.txt

# Configurações
echo "wordpress" > secrets/mysql/mysql_database.txt
echo "wordpress_user" > secrets/mysql/mysql_user.txt
```

#### **WordPress Secrets**
```bash
# Admin
openssl rand -base64 32 > secrets/wordpress/wordpress_admin_password.txt
echo "https://localhost" > secrets/wordpress/wordpress_url.txt
echo "admin" > secrets/wordpress/wordpress_admin_user.txt
echo "admin@example.com" > secrets/wordpress/wordpress_admin_email.txt

# Usuário adicional (opcional)
openssl rand -base64 32 > secrets/wordpress/wordpress_user_password.txt
echo "editor" > secrets/wordpress/wordpress_user.txt
echo "editor@example.com" > secrets/wordpress/wordpress_user_email.txt
```

#### **Redis Secrets**
```bash
openssl rand -base64 32 > secrets/redis/redis_password.txt
```

### 4️⃣ Deploy

```bash
# Build das imagens
docker compose build --no-cache

# Iniciar containers
docker compose up -d

# Aguardar ~45 segundos
sleep 45

# Verificar status
docker compose ps

# Acessar
# https://Inception/wp-admin
# Username: admin
# Password: cat secrets/wordpress/wordpress_admin_password.txt
```

### 5️⃣ Parar/Remover

```bash
docker compose down        # Stop sem deletar dados
docker compose down -v     # Stop + deletar volumes
```

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────┐
│              🌐 INTERNET (HTTPS)                │
└───────────────────────┬─────────────────────────┘
                        │
        ┌───────────────▼───────────────┐
        │     🔶 NGINX (80, 443)        │
        │   Reverse Proxy + SSL/TLS     │
        └───────────────┬───────────────┘
                        │ FastCGI :9000
        ┌───────────────▼───────────────┐
        │  🟢 WORDPRESS (PHP-FPM)       │
        │  - Max 20 workers             │
        │  - Processa requisições       │
        └───────┬───────────────┬───────┘
                │               │
    ┌───────────▼───┐   ┌───────▼────────┐
    │  🔵 REDIS     │   │  🟠 MARIADB    │
    │  Cache 1ms    │   │  Database 50ms │
    │  256MB RAM    │   │  Persistente   │
    └───────────────┘   └────────────────┘
```

---

## 🔧 Serviços Explicados

### 🔶 **NGINX** - Reverse Proxy

**O que faz:**
- Recebe requisições HTTPS (porta 443)
- Redireciona HTTP → HTTPS (porta 80)
- Passa requisições para PHP-FPM via FastCGI
- Armazena assets estáticos em cache

**Configuração:**
- SSL/TLS 1.2 e 1.3
- Certificado auto-assinado (localhost)
- Compressão gzip
- Cache de 1 ano para assets (`.js`, `.css`, `.png`)

---

### 🟢 **WORDPRESS** - PHP-FPM

**O que faz:**
- Executa código PHP do WordPress
- Gerencia múltiplos processos (0 a 20 workers)
- Acessa Redis (cache) e MariaDB (dados)
- Roda como usuário `www-data` (não-root)

**Inicialização:**
1. Aguarda MariaDB estar pronto
2. Download WordPress core (primeira vez)
3. Cria `wp-config.php` com credenciais
4. Executa `wp core install`
5. Instala plugin redis-cache
6. Inicia PHP-FPM

---

### 🔵 **REDIS** - Cache Layer

**O que faz:**
- Armazena cache em **memória RAM** (muito rápido)
- Reduz queries ao MariaDB (~60% menos)
- Melhora performance ~70x

**Como funciona:**
```
Primeira requisição (MISS):
  Nginx → PHP → Redis (não encontra) → MariaDB (50ms) → armazena em Redis

Próximas requisições (HIT):
  Nginx → PHP → Redis (encontra) → resposta (1ms)
```

**Dados armazenados:**
- Posts em cache
- Configurações (siteurl, blogname)
- Sessões de usuário
- Metadados customizados

**Segurança:**
- Autenticação por senha (32 chars)
- Rede isolada (não acessível externamente)
- Max 256MB memória (auto-eviction LRU)

---

### 🟠 **MARIADB** - Database

**O que faz:**
- Armazena dados **persistentes** (disco)
- Posts, páginas, usuários, comentários
- Suporta queries complexas
- Segurança: usuário dedicado `wordpress_user`

**Tabelas principais:**
- `wp_posts` - artigos/páginas
- `wp_users` - usuários do site
- `wp_options` - configurações
- `wp_postmeta` - metadados de posts

---

## 📚 Documentação Completa

Para detalhes mais detalhes, veja:

- **[SERVICE-OVERVIEW.md](./docs/SERVICE-OVERVIEW.md)** - Arquitetura detalhada

---

## 🛠️ Comandos Úteis

```bash
# Status
docker compose ps

# Logs (follow)
docker compose logs -f wordpress

# Executar comandos
docker compose exec wordpress wp plugin list --allow-root
docker compose exec redis redis-cli -a $(cat secrets/redis/redis_password.txt) ping
docker compose exec mariadb mysql -u wordpress -p$(cat secrets/mysql/mysql_password.txt) -e "SELECT 1;"

# Entrar no container
docker compose exec wordpress bash

# Restart um serviço
docker compose restart wordpress
```

---

## 🔐 Segurança

| Aspecto | Implementado |
|---------|--------------|
| **SSL/TLS** | ✅ HTTPS obrigatório |
| **Secrets** | ✅ Senhas em arquivos, não em env |
| **Network** | ✅ Bridge isolada, não exposta |
| **Permissions** | ✅ Sem root, usuário www-data |
| **Database** | ✅ Usuário dedicado com permissões limitadas |
| **Redis** | ✅ Autenticação + rede privada |

---

## ❓ FAQ

### P: Por que Redis?
**R:** Oferece cache ultra-rápido (1ms vs 50ms MariaDB), reduzindo carga do banco em ~60% e melhorando performance 70x em requisições comuns.

### P: Como backup de dados?
```bash
# MySQL
docker compose exec mariadb mysqldump -u wordpress -p$(cat secrets/mysql/mysql_password.txt) wordpress > backup.sql

# Arquivos WordPress
tar -czf wordpress-backup.tar.gz ~/data/wordpress/
```

---

## 📁 Estrutura do Projeto

```
Inception/
├── srcs/
│   ├── docker-compose.yml
│   ├── requirements/
│   │   ├── nginx/
│   │   │   ├── dockerfile
│   │   │   └── default.conf
│   │   ├── wordpress/
│   │   │   ├── dockerfile
│   │   │   └── setup.sh
│   │   ├── mariadb/
│   │   │   ├── dockerfile
│   │   │   └── init.sh
│   │   └── redis/
│   │       ├── dockerfile
│   │       ├── redis.conf
│   │       └── set.sh
│   └── secrets/
│       ├── mysql/
│       ├── wordpress/
│       └── redis/
├── docs/
│   ├── ARCHITECTURE.md
│   ├── REDIS-DETAILED.md
│   ├── SERVICES-EXPLAINED.md
│   └── DEPLOYMENT.md
└── README.md
```

---



## 👨‍💻 Autor

**Gabriel Costa** -> 42 São Paulo

