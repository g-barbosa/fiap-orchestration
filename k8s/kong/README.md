# Kong API Gateway - Configuração

## Visão Geral

Kong é o API Gateway para FIAP Cloud Games - atua como ponto de entrada único para todas as requisições externas e as roteia para os microserviços apropriados.

**Konga** é a interface web de administração para gerenciar Kong de forma visual.

### Arquitetura

```
┌──────────────────┐
│   Clientes       │
└────────┬─────────┘
         │
    Porta 8000 (HTTP)
    Porta 8443 (HTTPS)
         │
    ┌────▼─────┐
    │   Kong    │ ← API Gateway
    │  Gateway  │   Admin API: Porta 8001
    └────┬─────┘   Konga UI: Porta 1337
         │
    ┌────┴───────────┬──────────────┐
    │                │              │
 Users API      Catalog API     Payments API
 (8080)         (8080)          (8080)
```

---

## Início Rápido (Desenvolvimento Local)

### 1. Iniciar Kong e Konga com Docker Compose

```bash
cd fiap-orchestration

# Iniciar todos os serviços incluindo Kong e Konga
docker-compose up -d

# Verificar se Kong está rodando
curl http://localhost:8001/status

# Acessar Konga (interface web)
# Abrir: http://localhost:1337
```

### 2. Configurar Rotas (Manual via API ou Konga UI)

**Opção 1: Via Konga (Mais Fácil)**
1. Acesse http://localhost:1337
2. Configure uma nova conexão para o Kong Admin em `http://kong:8001`
3. Use a interface para criar serviços e rotas

**Opção 2: Via Kong Admin API**

```bash
# Verificar se Kong Admin está respondendo
curl http://localhost:8001/status

# Criar serviços e rotas usando Kong Admin API
```# Veja a seção "Kong Admin API - Referência Rápida" abaixo
```

### 3. Testar Roteamento

```bash
# Testar manualmente com curl
curl http://localhost:8000/api/users/health
curl http://localhost:8000/api/catalogs/games
curl http://localhost:8000/api/payments/health

# Ou verificar via Kong Admin API
curl http://localhost:8001/services
curl http://localhost:8001/routes
```

---

## Deploy em Kubernetes

### 1. Adicionar Repositório Helm do Kong

```bash
helm repo add kong https://charts.konghq.com
helm repo update
```

### 2. Criar Namespace Kong

```bash
kubectl create namespace kong
```

### 3. Fazer Deploy do Kong com Helm

```bash
helm install kong kong/kong \
  --namespace kong \
  --values k8s/kong/values.yaml
```

### 4. Port Forward (para acesso local)

```bash
# Kong Proxy
kubectl port-forward -n kong svc/kong-kong-proxy 8000:80

# Kong Admin
kubectl port-forward -n kong svc/kong-kong-admin 8001:8001
```

---

## Serviços Registrados

Após registrar serviços via Kong Admin API (veja a seção "Kong Admin API - Referência Rápida" abaixo), os seguintes serviços estão disponíveis:

### 1. Users API
```
Caminho(s):  /api/users, /api/users/*
Upstream:    http://users-api:8080
Métodos:     GET, POST, PUT, DELETE, PATCH
```

### 2. Catalog API
```
Caminho(s):  /api/catalogs/*, /api/games, /api/games/*
Upstream:    http://catalog-api:8080
Métodos:     GET, POST, PUT, DELETE, PATCH
```

### 3. Payments API
```
Caminho(s):  /api/payments, /api/payments/*
Upstream:    http://payments-api:8080
Métodos:     POST, GET
```

### 4. Notifications API
```
Caminho(s):  /api/notifications, /api/notifications/*
Upstream:    http://notifications-api:8080
Métodos:     GET, POST
```

---

## Kong Admin API

### Operações Comuns

#### Obter Todos os Serviços
```bash
curl http://localhost:8001/services
```

#### Obter Detalhes do Serviço
```bash
curl http://localhost:8001/services/users-api
```

#### Obter Todas as Rotas
```bash
curl http://localhost:8001/routes
```

#### Obter Rotas do Serviço
```bash
curl http://localhost:8001/services/users-api/routes
```

#### Adicionar Rota ao Serviço
```bash
curl -X POST http://localhost:8001/services/users-api/routes \
  -H "Content-Type: application/json" \
  -d '{
    "paths": ["/api/users/new"],
    "methods": ["GET"]
  }'
```

#### Deletar Serviço
```bash
curl -X DELETE http://localhost:8001/services/users-api
```

---

## Verificações de Saúde

### Status do Kong
```bash
# Verificar Kong
curl http://localhost:8001/status

# Resposta esperada:
# {
#   "database": {
#     "reachable": true
#   },
#   "server": {
#     ...
#   }
# }
```

### Status do Serviço Upstream
```bash
# Testar através do Kong
curl http://localhost:8000/api/users/health
curl http://localhost:8000/api/catalogs/games
curl http://localhost:8000/api/payments/health
```

---

## Arquivos de Configuração

### Docker Compose
- **Localização**: `../docker-compose.yml`
- **Serviços**: 
  - `kong` - Kong API Gateway
  - `postgres-kong` - Kong Database

### Kubernetes
- **Helm Values**: `k8s/kong/values.yaml`
- **ConfigMap**: `k8s/kong/configmap.yaml`

---

## Resolução de Problemas

### Kong Não Inicia

```bash
# Verificar logs
docker-compose logs kong

# Verificar se postgres está rodando
docker-compose ps postgres-kong

# Garantir que a porta 8000 está disponível
lsof -i :8000
```

### Rotas Não Funcionando

```bash
# Verificar se o serviço está registrado
curl http://localhost:8001/services/users-api

# Verificar rotas do serviço
curl http://localhost:8001/services/users-api/routes

# Testar upstream diretamente (contornar Kong)
curl http://localhost:8080/health

# Verificar upstream no Kong
curl http://localhost:8001/services/users-api
# Procure pelo campo "url"
```

### Serviços Offline

```bash
# Verificar todos os serviços
docker-compose ps

# Iniciar serviço faltante
docker-compose up -d users-api

# Ver logs do serviço
docker-compose logs -f catalog-api
```

---

## Próximos Passos

- Kong API Gateway operacional
- Serviços roteados através do gateway
- Próximo: JWT Validation (centralizado no Kong)


