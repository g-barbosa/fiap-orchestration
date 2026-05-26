# FIAP Orchestration

Repositório centralizado de orquestração Kubernetes para os projetos FIAP Cloud Games.

**Cada projeto mantém seus próprios manifestos Kubernetes em sua pasta `/k8s`. Este repositório apenas orquestra e executa todos os recursos de forma centralizada.**

## 📁 Estrutura

```
fiap-orchestration/              # Este repositório (orquestrador)
├── k8s/
│   ├── base/
│   │   └── namespace.yaml       # Namespace compartilhado
│   └── kustomization.yaml       # Referencia manifestos de outros projetos
├── scripts/
│   ├── deploy-all.ps1           # Deploy completo (Windows)
│   ├── deploy-all.sh            # Deploy completo (Linux/Mac)
│   ├── cleanup.ps1              # Cleanup (Windows)
│   └── cleanup.sh               # Cleanup (Linux/Mac)
└── README.md

fiap-users-api/                  # Projeto da API (repositório separado)
├── k8s/
│   ├── configmap.yaml           # ConfigMap - configs não sensíveis
│   ├── secret.yaml              # Secret - dados sensíveis
│   ├── deployment.yaml          # Deployment - gerenciamento de Pods
│   └── service.yaml             # Service - exposição
├── src/
└── Dockerfile

fiap-notifications-api/          # Outro projeto (exemplo futuro)
├── k8s/
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── deployment.yaml
│   └── service.yaml
└── ...
```

## 🚀 Pré-requisitos

- Docker Desktop com Kubernetes habilitado
- kubectl configurado
- Imagens Docker buildadas localmente

## 📦 Build das Imagens Docker

Antes de fazer o deploy, construa as imagens necessárias:

```bash
# Build da fiap-users-api
cd ../fiap-users-api
docker build -t fiap-users-api:latest .
```

## 🎯 Deploy

### Usando os scripts (Recomendado)

**Windows (PowerShell):**
```powershell
.\scripts\deploy-all.ps1
```

**Linux/Mac:**
```bash
chmod +x scripts/deploy-all.sh
./scripts/deploy-all.sh
```

### Deploy manual

```bash
# 1. Criar namespace
kubectl apply -f k8s/base/

# 2. Aplicar manifestos de cada projeto
kubectl apply -f ../fiap-users-api/k8s/

# 3. Verificar status
kubectl get all -n fiap-cloud-games
```

## 🔍 Verificar Status

```bash
# Listar todos os recursos
kubectl get all -n fiap-cloud-games

# Verificar logs da API
kubectl logs -l app=users-api -n fiap-cloud-games -f

# Verificar logs do SQL Server
kubectl logs -l app=sqlserver -n fiap-cloud-games -f
```

## 🌐 Acessar a API

```bash
# Port-forward para a API
kubectl port-forward svc/users-api 8080:80 -n fiap-cloud-games

# Acessar em: http://localhost:8080
# Swagger: http://localhost:8080/swagger
```

## 🧹 Cleanup

**Windows:**
```powershell
.\scripts\cleanup.ps1
```

**Linux/Mac:**
```bash
./scripts/cleanup.sh
```

**Ou manualmente:**
```bash
kubectl delete -f ../fiap-users-api/k8s/
kubectl delete -f k8s/base/
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

## 🔧 Adicionando Novos Projetos

1. No novo projeto, criar pasta `/k8s` com os manifestos
2. Editar `k8s/kustomization.yaml` neste repositório:

```yaml
resources:
  - base/namespace.yaml
  
  # fiap-users-api
  - ../../fiap-users-api/k8s/configmap.yaml
  - ../../fiap-users-api/k8s/secret.yaml
  - ../../fiap-users-api/k8s/deployment.yaml
  - ../../fiap-users-api/k8s/service.yaml

  # NOVO PROJETO - adicionar aqui
  - ../../novo-projeto/k8s/configmap.yaml
  - ../../novo-projeto/k8s/secret.yaml
  - ../../novo-projeto/k8s/deployment.yaml
  - ../../novo-projeto/k8s/service.yaml
```

## 📊 Projetos Orquestrados

| Projeto | Repositório | Status |
|---------|-------------|--------|
| users-api | `fiap-users-api/k8s/` | ✅ Configurado |
| notifications-api | `fiap-notifications-api/k8s/` | 🔜 Próximo |