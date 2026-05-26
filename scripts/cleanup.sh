#!/bin/bash
# Script de cleanup para Linux/Mac
# Remove todos os recursos Kubernetes do projeto
# Uso: ./cleanup.sh [--force]

set -e

FORCE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOS_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Parse arguments
for arg in "$@"; do
    case $arg in
        --force)
            FORCE=true
            shift
            ;;
    esac
done

echo "========================================"
echo "  FIAP Cloud Games - Kubernetes Cleanup"
echo "========================================"
echo ""

# Verificar se kubectl está disponível
if ! command -v kubectl &> /dev/null; then
    echo "ERRO: kubectl não encontrado."
    exit 1
fi

# Confirmar ação (a menos que --force seja usado)
if [ "$FORCE" = false ]; then
    echo "ATENÇÃO: Esta ação irá remover TODOS os recursos do namespace fiap-cloud-games!"
    echo ""
    read -p "Deseja continuar? (s/N) " confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        echo "Operação cancelada."
        exit 0
    fi
fi

echo ""
echo "[1/3] Removendo recursos dos projetos..."

# fiap-users-api
USERS_API_K8S="$REPOS_DIR/fiap-users-api/k8s"
if [ -d "$USERS_API_K8S" ]; then
    echo "      Removendo fiap-users-api..."
    kubectl delete -f "$USERS_API_K8S" --ignore-not-found 2>/dev/null || true
fi

# Adicione outros projetos aqui

echo ""
echo "[2/3] Removendo namespace..."
kubectl delete -f "$SCRIPT_DIR/../k8s/base" --ignore-not-found 2>/dev/null || true

echo ""
echo "[3/3] Verificando se o namespace foi removido..."

# Aguardar namespace ser removido
timeout=60
elapsed=0
while [ $elapsed -lt $timeout ]; do
    ns=$(kubectl get namespace fiap-cloud-games --ignore-not-found -o name 2>/dev/null || true)
    if [ -z "$ns" ]; then
        echo "      Namespace removido!"
        break
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo "      Aguardando namespace ser removido... ($elapsed s)"
done

if [ $elapsed -ge $timeout ]; then
    echo "      AVISO: Timeout aguardando namespace ser removido"
fi

echo ""
echo "========================================"
echo "  Cleanup concluído!"
echo "========================================"
echo ""
