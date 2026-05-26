# Script de cleanup para Windows (PowerShell)
# Remove todos os recursos Kubernetes do projeto
# Uso: .\cleanup.ps1 [-Force]

param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReposDir = Join-Path $ScriptDir "..\.." | Resolve-Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FIAP Cloud Games - Kubernetes Cleanup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se kubectl está disponível
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: kubectl não encontrado." -ForegroundColor Red
    exit 1
}

# Confirmar ação (a menos que -Force seja usado)
if (-not $Force) {
    Write-Host "ATENÇÃO: Esta ação irá remover TODOS os recursos do namespace fiap-cloud-games!" -ForegroundColor Yellow
    Write-Host ""
    $confirm = Read-Host "Deseja continuar? (s/N)"
    if ($confirm -ne "s" -and $confirm -ne "S") {
        Write-Host "Operação cancelada." -ForegroundColor Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "[1/3] Removendo recursos dos projetos..." -ForegroundColor Yellow

# fiap-users-api
$usersApiK8s = Join-Path $ReposDir "fiap-users-api\k8s"
if (Test-Path $usersApiK8s) {
    Write-Host "      Removendo fiap-users-api..." -ForegroundColor Gray
    kubectl delete -f $usersApiK8s --ignore-not-found 2>$null
}

# Adicione outros projetos aqui conforme necessário

Write-Host ""
Write-Host "[2/3] Removendo namespace..." -ForegroundColor Yellow
$k8sBasePath = Join-Path $ScriptDir "..\k8s\base"
kubectl delete -f $k8sBasePath --ignore-not-found 2>$null

Write-Host ""
Write-Host "[3/3] Verificando se o namespace foi removido..." -ForegroundColor Yellow

# Aguardar namespace ser removido
$timeout = 60
$elapsed = 0
while ($elapsed -lt $timeout) {
    $ns = kubectl get namespace fiap-cloud-games --ignore-not-found -o name 2>$null
    if (-not $ns) {
        Write-Host "      Namespace removido!" -ForegroundColor Green
        break
    }
    Start-Sleep -Seconds 2
    $elapsed += 2
    Write-Host "      Aguardando namespace ser removido... ($elapsed s)" -ForegroundColor Gray
}

if ($elapsed -ge $timeout) {
    Write-Host "      AVISO: Timeout aguardando namespace ser removido" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Cleanup concluído!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
