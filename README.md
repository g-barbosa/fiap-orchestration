# FIAP Orchestration

Repositório centralizado de orquestração para os projetos FIAP Cloud Games.

**Suporta duas formas de deploy:**
- **Docker Compose**: Para desenvolvimento local rápido (`docker-compose up`)
- **Kubernetes**: Para ambientes de produção e testes avançados

**Cada projeto mantém seus próprios manifestos Kubernetes em sua pasta `/k8s`. Este repositório apenas orquestra e executa todos os recursos de forma centralizada.**

## 📁 Estrutura

```
fiap-orchestration/              # Este repositório (orquestrador)
├── docker-compose.yml           # Orquestração Docker (dev local)
├── k8s/
│   ├── base/
│   │   └── namespace.yaml       # Namespace compartilhado
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
| Users API | http://localhost:8080/swagger | API de Usuários |
| Notifications API | http://localhost:8081/swagger | API de Notificações |
| Catalog API | http://localhost:8082/swagger | API de Catálogo |
| Payments API | http://localhost:8083/swagger | API de Pagamentos |
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