# FIAP Orchestration

Repositório centralizado de orquestração para os projetos FIAP Cloud Games.

**Suporta duas formas de deploy:**
- **Docker Compose**: Para desenvolvimento local rápido (`docker-compose up`)
- **Kubernetes**: Para ambientes de produção e testes avançados

**Cada projeto mantém seus próprios manifestos Kubernetes em sua pasta `/k8s`. Este repositório apenas orquestra e executa todos os recursos de forma centralizada.**

---

## 🚀 Início Rápido

### Local (Docker Compose)
```bash
# 1. Iniciar todos os serviços
docker-compose up -d

# 2. Aguardar Kong estar pronto (~30 segundos)
# Verificar: curl http://localhost:8001/status

# 3. Rotas + JWT: import automático (kong-config / kong/kong.yml)
#    Konga: http://localhost:1337
# 4. Testar JWT (seção abaixo) e roteamento
```

### Pontos de Acesso
- **Kong Gateway (Proxy)**: http://localhost:8000 ← **Use AQUI para requisições**
- **Kong Admin API**: http://localhost:8001 ← Apenas gerenciamento
- **Konga (Gerenciador Kong)**: http://localhost:1337
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (user: admin, password: admin)
- **RabbitMQ**: http://localhost:15672 (user: admin, password: rabbitmq123)
- **Serviços** (via Kong Gateway na porta 8000):
  - Users: http://localhost:8000/users/api/Usuarios
  - Catalog (Jogos): http://localhost:8000/catalog/api/Jogos
  - Catalog (Bibliotecas): http://localhost:8000/catalog/api/Bibliotecas
  - Payments: http://localhost:8000/api/Pagamentos
- **Métricas Diretas** (bypass Kong):
  - Users API: http://localhost:8080/metrics
  - Catalog API: http://localhost:8082/metrics
  - Payments API: http://localhost:8083/metrics
  - Notifications API: http://localhost:8081/metrics

### Kong Setup (Passos Manuais)

Rotas e **JWT** também são importados de `kong/kong.yml` no `docker compose up` (serviço `kong-config`). Os curls abaixo só são necessários se o import falhar.

**Teste JWT (Git Bash, uma linha):**

```bash
curl -i http://localhost:8000/catalog/api/Jogos
curl -i -X POST http://localhost:8000/users/api/Usuarios -H "Content-Type: application/json" -d '{"nome":"Gabriel","email":"gabriel@fiap.com","senha":"Senha@123"}'
curl -s -X POST http://localhost:8000/users/api/Usuarios/login -H "Content-Type: application/json" -d '{"email":"gabriel@fiap.com","senha":"Senha@123"}'
curl -i http://localhost:8000/catalog/api/Jogos -H "Authorization: Bearer SEU_TOKEN"
```

Sem token em `/catalog/api/Jogos` → **401**. Com o `token` do login → **200**.

```bash
# Verificar se Kong está pronto
curl http://localhost:8001/status

# Criar serviço: users-api
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "users-api",
    "url": "http://users-api:8080",
    "connect_timeout": 5000,
    "write_timeout": 30000,
    "read_timeout": 30000
  }'

# Criar rota para users-api
curl -X POST http://localhost:8001/services/users-api/routes \
  -H "Content-Type: application/json" \
  -d '{
    "paths": ["/api/Usuarios", "/api/Usuarios/*"],
    "strip_path": false
  }'

# Criar serviço: catalog-api
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "catalog-api",
    "url": "http://catalog-api:8080",
    "connect_timeout": 5000,
    "write_timeout": 30000,
    "read_timeout": 30000
  }'

# Criar rotas para catalog-api
curl -X POST http://localhost:8001/services/catalog-api/routes \
  -H "Content-Type: application/json" \
  -d '{
    "paths": ["/api/Jogos", "/api/Jogos/*", "/api/Bibliotecas", "/api/Bibliotecas/*"],
    "strip_path": false
  }'

# Criar serviço: payments-api
curl -X POST http://localhost:8001/services \
  -H "Content-Type: application/json" \
  -d '{
    "name": "payments-api",
    "url": "http://payments-api:8080",
    "connect_timeout": 5000,
    "write_timeout": 30000,
    "read_timeout": 30000
  }'

  }'

# ⚠️ Pagamentos e Notificações ainda não têm controllers implementados
# Quando implementados, adicionar suas rotas aqui
```
```

#### Prefixos `/users` e `/catalog`

O `kong.yml` versionado usa `strip_path: true` nesses prefixos. Exemplo: `GET /users/api/Usuarios` chega na UsersAPI como `/api/Usuarios`. Os curls manuais abaixo (Admin API) são o setup antigo do grupo, sem JWT.

---

## 📊 Observabilidade (Prometheus + Grafana)

### Arquitetura

```
┌──────────────────────────────────────────────────────────┐
│                   Aplicações (.NET)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐              │
│  │ Users    │  │ Catalog  │  │ Payments │              │
│  │ API      │  │ API      │  │ API      │              │
│  │ :8080    │  │ :8080    │  │ :8080    │              │
│  │/metrics  │  │/metrics  │  │/metrics  │              │
│  └──────────┘  └──────────┘  └──────────┘              │
│       ↓               ↓               ↓                  │
└──────────────────────────────────────────────────────────┘
              ↓
        ┌──────────────┐
        │  Prometheus  │
        │  :9090       │
        │ (scrapes)    │
        └──────────────┘
              ↓
        ┌──────────────┐
        │   Grafana    │
        │  :3000       │
        │ (visualiza)  │
        └──────────────┘
```

### Instrumentation nos Serviços

Todos os 4 serviços foram instrumentados com **prometheus-net.AspNetCore v8.2.1**:

1. **Users API** ✅
2. **Catalog API** ✅
3. **Payments API** ✅
4. **Notifications API** ✅

Cada serviço expõe métricas no endpoint `/metrics`:
```bash
curl http://localhost:8080/metrics      # Users
curl http://localhost:8082/metrics      # Catalog
curl http://localhost:8083/metrics      # Payments
curl http://localhost:8081/metrics      # Notifications
```

### Métricas Coletadas

**HTTP Requests:**
- `http_request_duration_seconds` - Latência de requisições
- `http_requests_total` - Total de requisições por status code

**Exemplos de Query Prometheus:**
```promql
# P95 Latência
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# Taxa de requisições (throughput)
rate(http_requests_total[5m])

# Taxa de erros 5xx
rate(http_requests_total{status=~"5.."}[5m])

# Taxa de erros 4xx
rate(http_requests_total{status=~"4.."}[5m])
```

### Grafana Dashboards

**Dashboard Pré-configurado:** `FIAP Cloud Games - Observabilidade`

**Painéis Inclusos:**
1. **Latência de Requisições HTTP (Percentis)** - P95 e P99 por serviço
2. **Taxa de Requisições (Throughput)** - Requisições/s por método
3. **Taxa de Erros HTTP** - Erros 4xx e 5xx separados
4. **Distribuição de Status HTTP** - Pizza com distribuição de status codes

**Acesso:**
- URL: http://localhost:3000
- Usuário: `admin`
- Senha: `admin`

**Importar Dashboard Customizado:**
1. Abrir Grafana (http://localhost:3000)
2. Dashboard → New → Import
3. Colar JSON ou fazer upload de `grafana/provisioning/dashboards/fiap-observabilidade.json`

### Configuração Prometheus

**Arquivo:** `prometheus.yml`

**Scrape Targets:**
- `users-api:8080/metrics` - Interval: 10s
- `catalog-api:8080/metrics` - Interval: 10s
- `payments-api:8080/metrics` - Interval: 10s
- `notifications-api:8080/metrics` - Interval: 10s
- `rabbitmq:15692/metrics` - Interval: 15s
- `kong:8001/metrics` - Interval: 15s

**Retention:** 15 dias (padrão do Prometheus)

### Logs Estruturados (Serilog)

Todos os serviços usam **Serilog** para logging estruturado:

```csharp
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .Enrich.FromLogContext()
    .CreateLogger();
```

**Sinks Configurados:**
- Console (stdout)
- File (arquivo local)

**CorrelationId:** Rastreamento de requisições distribuído automaticamente

### Alertas Futuros

Para ativar alertas no Prometheus:

1. Criar arquivo `alerting-rules.yml`:
```yaml
groups:
  - name: fiap-alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
        for: 5m
        annotations:
          summary: "Alta taxa de erros em {{ $labels.service }}"
```

2. Referenciar em `prometheus.yml`:
```yaml
rule_files:
  - /etc/prometheus/alerting-rules.yml
```

---

### Testes de Roteamento Kong
```bash
# Verificar Kong proxy - Users API
curl http://localhost:8000/users/api/Usuarios

# Verificar Kong admin
curl http://localhost:8001/status

# Listar serviços
curl http://localhost:8001/services

# Listar rotas
curl http://localhost:8001/routes

# Testar roteamento Users API
curl http://localhost:8000/users/api/Usuarios/health

# Testar roteamento Catalog API - Jogos
curl http://localhost:8000/catalog/api/Jogos

# Testar roteamento Catalog API - Bibliotecas
curl http://localhost:8000/catalog/api/Bibliotecas
```

---

## 📁 Estrutura

```
fiap-orchestration/              # Este repositório (orquestrador)
├── docker-compose.yml           # Orquestração Docker (dev local)
├── k8s/
│   ├── base/
│   │   └── namespace.yaml       # Namespace compartilhado
│   ├── kong/
│   │   ├── values.yaml          # Helm chart values para Kong
│   │   ├── configmap.yaml       # Configuração Kong K8s
│   │   └── README.md            # Guia de deploy Kong
│   ├── rabbitmq/                # Infraestrutura compartilhada
│   ├── redis/                   # Cache (CatalogAPI)
│   ├── mongodb/                 # NoSQL avaliações (CatalogAPI)
│   ├── prometheus/              # Scrape de métricas
│   ├── grafana/                 # Dashboard de observabilidade
│   └── kong/                    # API Gateway (rotas + JWT)
├── kong/
│   └── kong.yml                 # Config declarativa (compose)
├── prometheus/
│   └── prometheus.yml
├── grafana/
│   ├── dashboards/
│   └── provisioning/
└── README.md

fiap-users-api/                  # API de Usuários
├── k8s/
│   ├── configmap.yaml           # ConfigMap - configs não sensíveis
│   ├── secret.yaml              # Secret - dados sensíveis
│   ├── deployment.yaml          # Deployment - gerenciamento de Pods
│   └── service.yaml             # Service - exposição
├── src/
└── Dockerfile

fiap-notifications-api/          # API de Notificações
├── k8s/
│   ├── configmap.yaml           # ConfigMap - configs não sensíveis
│   ├── secret.yaml              # Secret - dados sensíveis
│   ├── deployment.yaml          # Deployment - gerenciamento de Pods
│   └── service.yaml             # Service - exposição
├── src/
└── Dockerfile

fiap-catalog-api/                # API de Catálogo de Jogos
├── k8s/
│   ├── configmap.yaml           # ConfigMap - configs não sensíveis
│   ├── secret.yaml              # Secret - dados sensíveis
│   ├── deployment.yaml          # Deployment - gerenciamento de Pods
│   └── service.yaml             # Service - exposição
├── src/
└── Dockerfile

fiap-payments-api/               # API de Pagamentos
├── k8s/
│   ├── configmap.yaml           # ConfigMap - configs não sensíveis
│   ├── secret.yaml              # Secret - dados sensíveis
│   ├── deployment.yaml          # Deployment - gerenciamento de Pods
│   └── service.yaml             # Service - exposição
├── src/
└── Dockerfile
```

## 🚀 Pré-requisitos

- Docker Desktop instalado
- Docker Compose (incluído no Docker Desktop)
- kubectl configurado (para deploy em Kubernetes)

---

## 🐳 Deploy com Docker Compose (Recomendado para Dev)

A forma mais rápida de subir toda a aplicação localmente:

```bash
# Subir toda a aplicação (build + run)
docker-compose up --build

# Subir em background
docker-compose up -d --build

# Ver logs
docker-compose logs -f

# Parar todos os containers
docker-compose down

# Parar e remover volumes (reset completo)
docker-compose down -v
```

### 📍 Endpoints após docker-compose up

| Serviço | URL | Descrição |
|---------|-----|-----------|
| Users API | http://localhost:8080/swagger | API de Usuários - `/api/Usuarios` |
| Notifications API | http://localhost:8081/swagger | API de Notificações (sem rotas Kong ainda) |
| Catalog API - Jogos | http://localhost:8082/swagger | API de Catálogo - `/api/Jogos` |
| Catalog API - Bibliotecas | http://localhost:8082/swagger | API de Catálogo - `/api/Bibliotecas` |
| Payments API | http://localhost:8083/swagger | API de Pagamentos (sem rotas Kong ainda) |
| **Kong (entrada pública)** | http://localhost:8000 | API Gateway (Users + Catalog) |
| Kong Admin | http://localhost:8001 | Admin API (debug; não use em produção) |
| Notifications API | http://localhost:8081/swagger | API de Notificações |
| Payments API | http://localhost:8083/swagger | API de Pagamentos |
| RabbitMQ Management | http://localhost:15672 | UI do RabbitMQ (admin/rabbitmq123) |
| Redis | localhost:6379 | Cache |
| MongoDB | localhost:27017 | Avaliações (admin/mongo123) |
| Prometheus | http://localhost:9090 | Métricas (scrape interno Users + Catalog) |
| Grafana | http://localhost:3000 | Dashboard (admin/admin) |
| SQL Server | localhost:1433 | Banco de Dados (SA/Mysql2022!) |

UsersAPI e CatalogAPI também estão em 8080/8082 (Swagger). O vídeo do TC deve usar o Kong em **8000**.

Rotas do Gateway (`strip_path: true` — prefixo `/users` ou `/catalog` é removido; a API recebe `/api/...`):

| Gateway | Upstream |
|---------|----------|
| `POST /users/api/Usuarios` | UsersAPI cadastro (sem JWT) |
| `POST /users/api/Usuarios/login` | UsersAPI login (sem JWT) |
| `GET\|PUT\|PATCH\|DELETE /users/*` | UsersAPI (JWT obrigatório) |
| `/catalog/*` | CatalogAPI (JWT obrigatório) |

### ✅ Testar Redis + Mongo (CatalogAPI)

1. Obtenha um JWT (cadastro + login via Kong) — ver seção **API Gateway**.
2. Crie um jogo: `POST http://localhost:8000/catalog/api/Jogos` com `Authorization: Bearer <token>`.
3. Liste duas vezes: `GET http://localhost:8000/catalog/api/Jogos`.
4. Valide o Redis no terminal:

```bash
docker exec redis redis-cli KEYS "*"
docker exec redis redis-cli HGETALL "fiap-catalog:jogos:all"
docker exec redis redis-cli TTL "fiap-catalog:jogos:all"
```

5. Crie/liste avaliações: `POST` / `GET /catalog/api/Jogos/{id}/avaliacoes` (MongoDB).

Passo a passo extra: README do `fiap-catalog-api` (seção **Como testar Redis e MongoDB**).

### ✅ API Gateway — Kong + JWT

Entrada única para UsersAPI e CatalogAPI. Plugin JWT usa a mesma `Jwt:Key` / `Jwt:Issuer` (`FiapCloudGames`) do UsersAPI.

**Como obter o JWT e validar**

O Kong **não gera** o token. Quem gera é o UsersAPI no `POST /users/api/Usuarios/login`. A resposta JSON tem o campo `token`. Esse valor substitui `SEU_TOKEN`.

**Passo 0 — stack no ar**

```bash
cd fiap-orchestration
docker compose up -d --build
```

Aguarde o container `kong` ficar healthy. A URL pública é `http://localhost:8000` (HTTP, não HTTPS).

**Passo 1 — confirmar que o Gateway exige token**

```bash
curl -i http://localhost:8000/catalog/api/Jogos
```

Esperado: **401 Unauthorized**. Sem `Authorization`, o Kong bloqueia o Catalog.

**Passo 2 — cadastrar um usuário (público, sem token)**

Cadastro e login são as únicas rotas `/users` liberadas (só `POST`).

No **Git Bash**, cole **uma linha só** (não use `^` nem `` ` `` — isso quebra o `-H` e gera **415**):

```bash
curl -i -X POST http://localhost:8000/users/api/Usuarios -H "Content-Type: application/json" -d '{"nome":"Gabriel","email":"gabriel@fiap.com","senha":"Senha@123"}'
```

O JSON vai entre aspas simples `'...'`. Esperado: **200** com um `id`. Se o e-mail já existir, pule para o passo 3.

**Passo 3 — fazer login e copiar o token**

```bash
curl -s -X POST http://localhost:8000/users/api/Usuarios/login -H "Content-Type: application/json" -d '{"email":"gabriel@fiap.com","senha":"Senha@123"}'
```

Resposta típica:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.xxxxx.yyyyy"
}
```

Copie **somente** o valor de `token` (a string longa que começa com `eyJ`). Não copie as aspas.

Se aparecer `"Credenciais inválidas"`, o cadastro não gravou — rode o passo 2 de novo.

Opcional, guardar o token no Git Bash:

```bash
TOKEN=$(curl -s -X POST http://localhost:8000/users/api/Usuarios/login -H "Content-Type: application/json" -d '{"email":"gabriel@fiap.com","senha":"Senha@123"}' | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
echo "$TOKEN"
```

**Passo 4 — chamar o Catalog com o Bearer**

Há um **espaço** depois de `Bearer`. Cole o JWT no lugar de `SEU_TOKEN`, ou use `$TOKEN` se rodou o atalho acima:

```bash
curl -i http://localhost:8000/catalog/api/Jogos -H "Authorization: Bearer SEU_TOKEN"
```

```bash
curl -i http://localhost:8000/catalog/api/Jogos -H "Authorization: Bearer $TOKEN"
```

Esperado: **200** e a lista de jogos (JSON).

**Erros comuns**

| Sintoma | Causa |
|---------|--------|
| 415 Unsupported Media Type | Quebrou o `curl` com `^` ou `` ` `` no Git Bash — o `Content-Type` não foi enviado |
| Credenciais inválidas | Cadastro não rodou (ou e-mail/senha diferentes) — faça o passo 2 antes |
| 401 no Catalog | Esqueceu o header, digitou `SEU_TOKEN` literal, ou colou aspas junto |
| 401 depois do login | Token expirado (~60 min) — faça login de novo |
| 404 no login | URL errada: precisa ser `/users/api/Usuarios/login` via porta **8000** |
| Connection refused | Kong não subiu — `docker compose ps` e veja o serviço `kong` |

Swagger das APIs (interno):

```bash
# Kubernetes
kubectl port-forward svc/users-api 8080:80 -n fiap-cloud-games
kubectl port-forward svc/catalog-api 8082:80 -n fiap-cloud-games
```

### ✅ Observabilidade — Opção A (Prometheus + Grafana)

Stack escolhida: **código aberto (Opção A)** do Tech Challenge Fase 3.

- **UsersAPI** e **CatalogAPI** expõem `GET /metrics` via `prometheus-net.AspNetCore`
- **Prometheus** faz scrape a cada 15s
- **Grafana** provisiona o dashboard `FIAP Cloud Games - APIs Overview` com:
  - Latência (p50 / p95)
  - Throughput (req/s por status HTTP)
  - Taxa de erros (5xx % e 4xx/s)

**Como validar**

1. `docker compose up -d --build`
2. Gere tráfego via Gateway: `GET http://localhost:8000/catalog/api/Jogos` (com JWT) e login em `POST /users/api/Usuarios/login`
3. Confira targets: http://localhost:9090/targets (users-api e catalog-api = UP)
4. Abra o Grafana: http://localhost:3000 (admin / admin) → pasta **FIAP** → dashboard overview
5. Métricas raw (rede interna): Prometheus faz scrape em `users-api:8080/metrics` e `catalog-api:8080/metrics`

### ✅ Observabilidade — Opção A (Prometheus + Grafana)

Stack escolhida: **código aberto (Opção A)** do Tech Challenge Fase 3.

- **UsersAPI** e **CatalogAPI** expõem `GET /metrics` via `prometheus-net.AspNetCore`
- **Prometheus** faz scrape a cada 15s
- **Grafana** provisiona o dashboard `FIAP Cloud Games - APIs Overview` com:
  - Latência (p50 / p95)
  - Throughput (req/s por status HTTP)
  - Taxa de erros (5xx % e 4xx/s)

**Como validar**

1. `docker compose up -d --build`
2. Gere tráfego: http://localhost:8080/swagger e http://localhost:8082/swagger
3. Confira targets: http://localhost:9090/targets (users-api e catalog-api = UP)
4. Abra o Grafana: http://localhost:3000 (admin / admin) → pasta **FIAP** → dashboard overview
5. Métricas raw: http://localhost:8080/metrics e http://localhost:8082/metrics

---

## ☸️ Deploy com Kubernetes

### Deploy manual

```bash
# 1. Build das imagens
cd ../fiap-users-api && docker build -t fiap-users-api:latest .
cd ../fiap-notifications-api && docker build -t fiap-notifications-api:latest .
cd ../fiap-catalog-api && docker build -t fiap-catalog-api:latest .
cd ../fiap-payments-api && docker build -t fiap-payments-api:latest .

# 2. Criar namespace
kubectl apply -f k8s/base/

# 3. Deploy infraestrutura (RabbitMQ, Redis, MongoDB, Prometheus, Grafana, Kong)
kubectl apply -f k8s/rabbitmq/
kubectl apply -f k8s/redis/
kubectl apply -f k8s/mongodb/
kubectl apply -f k8s/prometheus/
kubectl apply -f k8s/grafana/
kubectl apply -f k8s/kong/

# 4. Deploy dos projetos
kubectl apply -f ../fiap-users-api/k8s/
kubectl apply -f ../fiap-notifications-api/k8s/
kubectl apply -f ../fiap-catalog-api/k8s/
kubectl apply -f ../fiap-payments-api/k8s/

# 5. Verificar status
kubectl get all -n fiap-cloud-games
```

## 🔍 Verificar Status

```bash
# Listar todos os recursos
kubectl get all -n fiap-cloud-games

# Verificar logs
kubectl logs -l app=users-api -n fiap-cloud-games -f
kubectl logs -l app=notifications-api -n fiap-cloud-games -f
kubectl logs -l app=catalog-api -n fiap-cloud-games -f
kubectl logs -l app=payments-api -n fiap-cloud-games -f
kubectl logs -l app=rabbitmq -n fiap-cloud-games -f
```

## 🌐 Acessar os Serviços

```bash
# Kong (entrada pública — NodePort 30080)
kubectl port-forward svc/kong-proxy 8000:8000 -n fiap-cloud-games
# Acesse: http://localhost:8000/users/api/Usuarios e http://localhost:8000/catalog/api/Jogos

# Swagger interno (não é exposição pública)
kubectl port-forward svc/users-api 8080:80 -n fiap-cloud-games
kubectl port-forward svc/catalog-api 8082:80 -n fiap-cloud-games

# Notifications API (porta 8081)
kubectl port-forward svc/notifications-api 8081:80 -n fiap-cloud-games

# Payments API (porta 8083)
kubectl port-forward svc/payments-api 8083:80 -n fiap-cloud-games

# RabbitMQ Management (porta 15672)
kubectl port-forward svc/rabbitmq 15672:15672 -n fiap-cloud-games
# Acesse: http://localhost:15672 (admin / rabbitmq123)

# Grafana
kubectl port-forward svc/grafana 3000:3000 -n fiap-cloud-games
```

## 📝 Convenções para Novos Projetos

### Cada projeto DEVE ter sua pasta `/k8s` com:

| Arquivo | Descrição | Obrigatório |
|---------|-----------|-------------|
| `configmap.yaml` | Configurações NÃO sensíveis (URLs, nomes de filas) | ✅ |
| `secret.yaml` | Dados SENSÍVEIS (connection strings, chaves API) | ✅ |
| `deployment.yaml` | Deployment para gerenciar Pods | ✅ |
| `service.yaml` | Service para exposição | ✅ |

### Regras:

1. **Deployments**: Obrigatório para gerenciamento de Pods (não usar Pods isolados)
2. **ConfigMaps**: Para configurações não sensíveis
3. **Secrets**: Para dados sensíveis
4. **Namespace**: Usar `fiap-cloud-games`

## 📊 Projetos Orquestrados

| Projeto | Descrição | Status |
|---------|-----------|--------|
| users-api | API de Usuários e Autenticação | ✅ Configurado |
| notifications-api | API de Notificações | ✅ Configurado |
| catalog-api | API de Catálogo de Jogos | ✅ Configurado |
| payments-api | API de Pagamentos | ✅ Configurado |
| rabbitmq | Message Broker (infraestrutura) | ✅ Configurado |
| redis | Cache (CatalogAPI) | ✅ Configurado |
| mongodb | NoSQL - Avaliações (CatalogAPI) | ✅ Configurado |
| prometheus | Coleta de métricas (Users + Catalog) | ✅ Configurado |
| grafana | Dashboard de observabilidade | ✅ Configurado |
| kong | API Gateway (JWT + rotas Users/Catalog) | ✅ Configurado |
| sqlserver | Banco de Dados (via users-api) | ✅ Configurado |

## 🐰 Conexão com RabbitMQ

Os projetos podem se conectar ao RabbitMQ usando:

| Config | Valor |
|--------|-------|
| Host | `rabbitmq` |
| Port | `5672` |
| Username | `admin` |
| Password | `rabbitmq123` |
| Management UI | `http://localhost:15672` (via port-forward)