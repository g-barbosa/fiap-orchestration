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

# 3. Configurar serviços e rotas Kong (ver seção Kong Setup abaixo)

# 4. Testar roteamento com curl (ver seção Kong Routing Tests abaixo)
```

### Pontos de Acesso
- **Kong Gateway**: http://localhost:8000
- **Kong Admin**: http://localhost:8001
- **Konga (Gerenciador Kong)**: http://localhost:1337
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (user: admin, password: admin)
- **RabbitMQ**: http://localhost:15672 (user: admin, password: rabbitmq123)
- **Serviços** (via Kong):
  - Users: http://localhost:8000/api/Usuarios
  - Catalog (Jogos): http://localhost:8000/api/Jogos
  - Catalog (Bibliotecas): http://localhost:8000/api/Bibliotecas
- **Métricas Diretas**:
  - Users API: http://localhost:8080/metrics
  - Catalog API: http://localhost:8082/metrics
  - Payments API: http://localhost:8083/metrics
  - Notifications API: http://localhost:8081/metrics

### Kong Setup (Passos Manuais)

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

#### ⚠️ Importante: strip_path: false

Por padrão, Kong remove o prefixo do path antes de encaminhar à API (ex: `/api/Usuarios` vira `/`). Como nossas APIs esperam o path completo (`/api/Usuarios`), **sempre use `strip_path: false`** nas rotas.

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
curl http://localhost:8000/api/Usuarios

# Verificar Kong admin
curl http://localhost:8001/status

# Listar serviços
curl http://localhost:8001/services

# Listar rotas
curl http://localhost:8001/routes

# Testar roteamento Users API
curl http://localhost:8000/api/Usuarios/health

# Testar roteamento Catalog API - Jogos
curl http://localhost:8000/api/Jogos

# Testar roteamento Catalog API - Bibliotecas
curl http://localhost:8000/api/Bibliotecas
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
│   └── mongodb/                 # NoSQL avaliações (CatalogAPI)
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
| RabbitMQ Management | http://localhost:15672 | UI do RabbitMQ (admin/rabbitmq123) |
| Redis | localhost:6379 | Cache |
| MongoDB | localhost:27017 | Avaliações (admin/mongo123) |
| SQL Server | localhost:1433 | Banco de Dados (SA/Mysql2022!) |

### ✅ Testar Redis + Mongo (CatalogAPI)

1. Abra http://localhost:8082/swagger (`fiap-catalog-api`).
2. Crie um jogo: `POST /api/Jogos`.
3. Liste duas vezes: `GET /api/Jogos`.
4. Valide o Redis no terminal:

```bash
docker exec redis redis-cli KEYS "*"
docker exec redis redis-cli HGETALL "fiap-catalog:jogos:all"
docker exec redis redis-cli TTL "fiap-catalog:jogos:all"
```

5. Crie/liste avaliações: `POST` / `GET /api/Jogos/{id}/avaliacoes` (MongoDB).

Passo a passo completo: ver README do `fiap-catalog-api` (seção **Como testar Redis e MongoDB**).

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

# 3. Deploy infraestrutura (RabbitMQ, Redis, MongoDB)
kubectl apply -f k8s/rabbitmq/
kubectl apply -f k8s/redis/
kubectl apply -f k8s/mongodb/

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
# Users API (porta 8080)
kubectl port-forward svc/users-api 8080:80 -n fiap-cloud-games
# Acesse: http://localhost:8080/swagger

# Notifications API (porta 8081)
kubectl port-forward svc/notifications-api 8081:80 -n fiap-cloud-games
# Acesse: http://localhost:8081/swagger

# Catalog API (porta 8082)
kubectl port-forward svc/catalog-api 8082:80 -n fiap-cloud-games
# Acesse: http://localhost:8082/swagger

# Payments API (porta 8083)
kubectl port-forward svc/payments-api 8083:80 -n fiap-cloud-games
# Acesse: http://localhost:8083/swagger

# RabbitMQ Management (porta 15672)
kubectl port-forward svc/rabbitmq 15672:15672 -n fiap-cloud-games
# Acesse: http://localhost:15672 (admin / rabbitmq123)
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