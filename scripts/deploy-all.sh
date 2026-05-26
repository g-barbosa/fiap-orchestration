#!/bin/bash
# Script de deploy completo para Linux/Mac
# Orquestra o deploy de todos os projetos FIAP Cloud Games
# Uso: ./deploy-all.sh [--skip-build] [--wait]

set -e

SKIP_BUILD=false
WAIT_FOR_READY=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --wait)
            WAIT_FOR_READY=true
            shift
            ;;
    esac
done

echo "========================================"
echo "  FIAP Cloud Games - Kubernetes Deploy"
echo "  (Orquestrador Central)"
echo "========================================"
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "ERRO: kubectl não encontrado. Instale o kubectl e tente novamente."
    exit 1
fi

# Verificar conexão com o cluster
echo "[1/5] Verificando conexão com o cluster Kubernetes..."
if ! kubectl cluster-info &> /dev/null; then
    echo "ERRO: Não foi possível conectar ao cluster Kubernetes."
    echo "      Verifique se o Docker Desktop com Kubernetes está rodando."
    exit 1
fi
echo "      Conectado ao cluster!"

# Build das imagens Docker (se não for pulado)
if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo "[2/5] Construindo imagens Docker dos projetos..."
    
    # fiap-users-api
    USERS_API_PATH="$REPOS_DIR/fiap-users-api"
    if [ -d "$USERS_API_PATH" ]; then
        echo "      Building fiap-users-api..."
        pushd "$USERS_API_PATH" > /dev/null
        docker build -t fiap-users-api:latest .
        popd > /dev/null
        echo "      fiap-users-api:latest construída!"
    else
        echo "      AVISO: fiap-users-api não encontrado em $USERS_API_PATH"
    fi
    
    # Adicione outros projetos aqui
else
    echo ""
    echo "[2/5] Build de imagens pulado (--skip-build)"
fi

# Aplicar namespace base
echo ""
echo "[3/5] Criando namespace e recursos base..."
kubectl apply -f "$SCRIPT_DIR/../k8s/base"
echo "      Namespace criado!"

# Aplicar manifestos de cada projeto
echo ""
echo "[4/5] Aplicando manifestos de cada projeto..."

# fiap-users-api
USERS_API_K8S="$REPOS_DIR/fiap-users-api/k8s"
if [ -d "$USERS_API_K8S" ]; then
    echo "      Aplicando fiap-users-api/k8s..."
    kubectl apply -f "$USERS_API_K8S"
    echo "      fiap-users-api aplicado!"
else
    echo "      AVISO: fiap-users-api/k8s não encontrado"
fi

# Adicione outros projetos aqui:
# NOTIFICATIONS_API_K8S="$REPOS_DIR/fiap-notifications-api/k8s"
# if [ -d "$NOTIFICATIONS_API_K8S" ]; then
#     kubectl apply -f "$NOTIFICATIONS_API_K8S"
# fi

# Aguardar pods ficarem prontos
if [ "$WAIT_FOR_READY" = true ]; then
    echo ""
    echo "[5/5] Aguardando pods ficarem prontos..."
    
    echo "      Aguardando SQL Server..."
    kubectl wait --for=condition=ready pod -l app=sqlserver -n fiap-cloud-games --timeout=120s
    
    echo "      Aguardando Users API..."
    kubectl wait --for=condition=ready pod -l app=users-api -n fiap-cloud-games --timeout=120s
    
    echo "      Todos os pods estão prontos!"
else
    echo ""
    echo "[5/5] Pulando espera por pods (use --wait para aguardar)"
fi

# Mostrar status
echo ""
echo "Status dos recursos:"
echo ""
kubectl get all -n fiap-cloud-games

echo ""
echo "========================================"
echo "  Deploy concluído com sucesso!"
echo "========================================"
echo ""
echo "Para acessar a API localmente, execute:"
echo "  kubectl port-forward svc/users-api 8080:80 -n fiap-cloud-games"
echo ""
echo "Acesse: http://localhost:8080/swagger"
echo ""
