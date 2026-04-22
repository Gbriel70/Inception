# 🎛️ Overview dos Serviços

> Entender rapidamente o que cada serviço faz

---

## 🔶 NGINX - Reverse Proxy

### Função Básica
```
Cliente HTTPS
      ↓
  [NGINX Port 443]
      ↓
  Valida SSL
  Redireciona HTTP → HTTPS
  Passa para PHP-FPM
      ↓
  PHP-FPM
```

### Configurado Para
- ✅ Escutar HTTPS (porta 443)
- ✅ Redirecionar HTTP (porta 80) para HTTPS
- ✅ Passar requisições PHP para upstream `php:9000`
- ✅ Armazenar assets em cache (1 ano)
- ✅ Comprimir com gzip

### Arquivo de Configuração
- `requirements/nginx/default.conf`
- Certificado auto-assinado: `localhost.crt`

---

## 🟢 WORDPRESS - PHP-FPM

### Função Básica
```
Requisição FastCGI (Nginx)
        ↓
  [PHP-FPM Worker]
        ↓
  Executa WordPress
  Consulta Redis/MariaDB
        ↓
  HTML Response
```

### Configurado Para
- ✅ Escutar em `0.0.0.0:9000` (para Nginx)
- ✅ Pool dinâmico: 3-20 workers (escala automática)
- ✅ Executar como usuário `www-data` (não-root)
- ✅ Timeout: 300s (para uploads)

### Inicialização (setup.sh)
```bash
1. Aguarda MariaDB pronto
2. Aguarda Redis pronto
3. Download WordPress (primeira vez)
4. Criar wp-config.php com secrets
5. wp core install (criar tabelas + admin)
6. Instalar plugin redis-cache
7. Iniciar PHP-FPM
```

### Extensões PHP Instaladas
- `php-mysql` - Conectar MariaDB
- `php-redis` - Conectar Redis
- `php-dom` - XML parsing
- `php-json` - JSON

---

## 🔵 REDIS - Cache

### Função Básica
```
WordPress Query
      ↓
Redis tem cache? ─→ SIM → Retorna (1ms) ⚡
      ↓
      NÃO
      ↓
Query MariaDB (50ms) ⏳
      ↓
Armazena em Redis
      ↓
Retorna dados
```

### Configurado Para
- ✅ Autenticação por senha (32 chars)
- ✅ Persistência: AOF (Append-Only File)
- ✅ Max memory: 256MB com LRU eviction
- ✅ Escutar `6379` (porta padrão)

### Dados Armazenados
```
post:1              → Post com ID 1
post:list           → Lista de posts
option:siteurl      → URL do site
session:abc123      → Sessão de usuário
transient:xyz       → Cache temporário
```

### Por Que Redis?
| Métrica | MariaDB | Redis |
|---------|---------|-------|
| Latência | 50ms | 1ms |
| Aceleração | - | 50x |
| Carga BD | 100% | 40% |

---

## 🟠 MARIADB - Database

### Função Básica
```
WordPress precisa de dados
        ↓
  [MariaDB Banco]
        ↓
  Query SQL
  Busca em disco
        ↓
  Retorna dados (50ms)
```

### Configurado Para
- ✅ Banco: `wordpress`
- ✅ Usuário: `wordpress_user` (permissões limitadas)
- ✅ Charset: `utf8mb4` (suporta emoji)
- ✅ Engine: `InnoDB` (transações ACID)
- ✅ Escutar `3306` (porta padrão)

### Tabelas Principais
```
wp_posts      → Artigos/Páginas
wp_users      → Usuários do site
wp_options    → Configurações
wp_postmeta   → Metadados customizados
wp_comments   → Comentários
```

### Inicialização (init.sh)
```bash
1. Criar banco "wordpress"
2. Criar usuário "wordpress_user"
3. Conceder permissões
4. Flush privileges
```

---

## 📊 Fluxo Completo de uma Requisição

```
┌─────────────────────────────────────────────────────┐
│  Cliente: GET https://localhost/blog/post-1/        │
└──────────────────┬──────────────────────────────────┘
                   │ HTTPS
                   ↓
         ┌─────────────────────┐
         │  🔶 NGINX Port 443  │
         │                     │
         │ ✓ SSL Handshake     │
         │ ✓ Parse request     │
         │ ✓ Check cache?      │
         │                     │
         │ - Static? Return    │
         │ - PHP? Pass to FPM  │
         └────────────┬────────┘
                      │ FastCGI
                      ↓
         ┌─────────────────────┐
         │ 🟢 PHP-FPM Worker   │
         │                     │
         │ wp-load.php         │
         │ Execute hooks       │
         │ Query Redis cache?  │
         └──────┬──────┬───────┘
                │      │
         ┌──────▼──┐   │
         │ REDIS   │   │
         │ Cache?  │   │
         │  YES→   │   │ NO
         │ Return  │   │
         │ (1ms)   │   │
         └────┬────┘   │
              │        ↓
              │    ┌──────────────┐
              │    │ 🟠 MariaDB   │
              │    │              │
              │    │ Query DB     │
              │    │ (50ms)       │
              │    └────────┬─────┘
              │             │
              ├─────────────┤
              │             │
              │ WordPress   │
              │ renders HTML│
              │             │
              └──────┬──────┘
                     │
         ┌───────────▼──────────┐
         │ 🔶 NGINX             │
         │                      │
         │ - Compress gzip      │
         │ - Add cache headers  │
         │ - Send response      │
         └────────────┬─────────┘
                      │ HTTPS
                      ↓
              ┌────────────────┐
              │ Browser HTML   │
              └────────────────┘
```

---

## 🔐 Segurança Entre Serviços

```
┌──────────────────────────────────────────────────┐
│    Docker Bridge Network: inception (privada)    │
│                                                  │
│  Nginx        WordPress      Redis      MariaDB  │
│   ↔────────────  ↔─────────────  ↔──────────     │
│        FastCGI   Redis CLI   MySQL Protocol      │
│                                                  │
│ Tudo via DNS interno (wordpress:9000, etc)       │
│ Nada exposto para internet                       │
│                                                  │
└──────────────────────────────────────────────────┘

Secrets (senhas):
├─ MariaDB: /run/secrets/mysql_password
├─ Redis: /run/secrets/redis_password
└─ WordPress: /run/secrets/wordpress_admin_password

Volumes (dados persistentes):
├─ ~/data/wordpress → /var/www/html
├─ ~/data/mariadb → /var/lib/mysql
└─ ~/data/redis → /data
```

---

## ⚙️ Como São Iniciados

```
1. Docker Compose inicia ordem de dependência
   
   ↓ Inicia MariaDB
   ├─ Aguarda healthcheck (mysqladmin ping)
   ├─ Cria banco "wordpress"
   ├─ Cria usuário wordpress_user
   └─ ✓ MariaDB pronto
   
   ↓ Inicia Redis
   ├─ Aguarda healthcheck (redis-cli ping)
   ├─ Carrega redis.conf
   ├─ Ativa autenticação
   └─ ✓ Redis pronto
   
   ↓ Inicia WordPress
   ├─ Aguarda MariaDB pronto
   ├─ Aguarda Redis pronto
   ├─ Executa setup.sh
   ├─ Download WordPress (primeira vez)
   ├─ Cria wp-config.php
   ├─ wp core install (só primeira vez)
   ├─ Instala plugin redis-cache
   ├─ Aguarda healthcheck (wp-config.php existe?)
   └─ ✓ WordPress pronto
   
   ↓ Inicia Nginx
   ├─ Aguarda WordPress pronto
   ├─ Carrega configuração SSL
   ├─ Define upstream php
   ├─ Aguarda healthcheck (curl https://localhost/)
   └─ ✓ Nginx pronto

Total: ~45-60 segundos para tudo estar pronto
```

---

## 📊 Comparação: Com vs Sem Cache

```
Cenário: 100 requisições/segundo para mesma página

┌─────────────────────────────────────────────┐
│        SEM REDIS (só MariaDB)               │
├─────────────────────────────────────────────┤
│ Query: 50ms × 100 = 5000ms (5 seg!)         │
│ CPU BD: 100%                                │
│ Timeout: frequente                          │
│ Usuários felizes: NÃO ❌                    │
└─────────────────────────────────────────────┘

                    ↓↓↓ Implementar Redis ↓↓↓

┌─────────────────────────────────────────────┐
│        COM REDIS (cache inteligente)        │
├─────────────────────────────────────────────┤
│ Primeira: 50ms                              │
│ Próximas: 1ms × 99 = 99ms                   │
│ Total: ~150ms (99.7% mais rápido!) ⚡       │
│ CPU BD: 10%                                 │
│ Timeout: nunca                              │
│ Usuários felizes: SIM ✅                    │
└─────────────────────────────────────────────┘
```

---

## 🔄 Ciclo de Vida de uma Página Cacheada

```
Visita 1 (MISS):
━━━━━━━━━━━━━━━━
  Nginx → PHP → Redis (não encontra)
                  ↓
              MariaDB Query
                  ↓
              Processa dados
                  ↓
              Armazena em Redis
                  ↓
              Retorna para cliente
              ⏱️ 55ms

Visita 2-1000 (HIT):
━━━━━━━━━━━━━━━━━
  Nginx → PHP → Redis (encontra!)
                  ↓
              Retorna direto
              ⏱️ 2ms (27x mais rápido!)

Cache expira ou invalida:
━━━━━━━━━━━━━━━━━━━━━━
  Volta ao ciclo de MISS
  (automático após 1 hora ou quando post é editado)
```

---

## 🎯 Resumo

| Serviço | Porta | Função | Latência |
|---------|-------|--------|----------|
| **Nginx** | 80, 443 | Reverse proxy + HTTPS | - |
| **WordPress** | 9000 (int.) | Processa PHP | 30ms |
| **Redis** | 6379 (int.) | Cache | 1ms |
| **MariaDB** | 3306 (int.) | Banco de dados | 50ms |

**Stack completo:** Nginx → PHP-FPM → Redis/MariaDB → Browser

**Benefício:** Performance 70x com Redis + Segurança multi-camada
