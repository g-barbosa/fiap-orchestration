# Script de deploy completo para Windows (PowerShell)
# Orquestra o deploy de todos os projetos FIAP Cloud Games
# Uso: .\deploy-all.ps1 [-SkipBuild] [-WaitForReady]

param(
    [switch]$SkipBuild,
    [switch]$WaitForReady
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReposDir = Join-Path $ScriptDir "..\.." | Resolve-Path

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  FIAP Cloud Games - Kubernetes Deploy" -ForegroundColor Cyan
Write-Host "  (Orquestrador Central)" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se kubectl está disponível
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: kubectl não encontrado. Instale o kubectl e tente novamente." -ForegroundColor Red
    exit 1
}

# Verificar conexão com o cluster
Write-Host "[1/5] Verificando conexão com o cluster Kubernetes..." -ForegroundColor Yellow
try {
    kubectl cluster-info 2>&1 | Out-Null
    Write-Host "      Conectado ao cluster!" -ForegroundColor Green
} catch {
    Write-Host "ERRO: Não foi possível conectar ao cluster Kubernetes." -ForegroundColor Red
    Write-Host "      Verifique se o Docker Desktop com Kubernetes está rodando." -ForegroundColor Red
    exit 1
}

# Build das imagens Docker (se não for pulado)
if (-not $SkipBuild) {
    Write-Host ""
    Write-Host "[2/5] Construindo imagens Docker dos projetos..." -ForegroundColor Yellow
    
    # fiap-users-api
    $usersApiPath = Join-Path $ReposDir "fiap-users-api"
    if (Test-Path $usersApiPath) {
        Write-Host "      Building fiap-users-api..." -ForegroundColor Gray
        Push-Location $usersApiPath
        docker build -t fiap-users-api:latest .
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERRO: Falha ao construir imagem fiap-users-api" -ForegroundColor Red
            Pop-Location
            exit 1
        }
        Pop-Location
        Write-Host "      fiap-users-api:latest construída!" -ForegroundColor Green
    } else {
        Write-Host "      AVISO: fiap-users-api não encontrado em $usersApiPath" -ForegroundColor Yellow
    }

    # Adicione outros projetos aqui conforme necessário
    # $notificationsApiPath = Join-Path $ReposDir "fiap-notifications-api"
    # ...
} else {
    Write-Host ""
    Write-Host "[2/5] Build de imagens pulado (-SkipBuild)" -ForegroundColor Yellow
}

# Aplicar namespace base
Write-Host ""
Write-Host "[3/5] Criando namespace e recursos base..." -ForegroundColor Yellow
$k8sBasePath = Join-Path $ScriptDir "..\k8s\base"
kubectl apply -f $k8sBasePath
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERRO: Falha ao criar namespace" -ForegroundColor Red
    exit 1
}
Write-Host "      Namespace criado!" -ForegroundColor Green

# Aplicar manifestos de cada projeto
Write-Host ""
Write-Host "[4/5] Aplicando manifestos de cada projeto..." -ForegroundColor Yellow

# fiap-users-api
$usersApiK8s = Join-Path $ReposDir "fiap-users-api\k8s"
if (Test-Path $usersApiK8s) {
    Write-Host "      Aplicando fiap-users-api/k8s..." -ForegroundColor Gray
    kubectl apply -f $usersApiK8s
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO: Falha ao aplicar manifestos do fiap-users-api" -ForegroundColor Red
        exit 1
    }
    Write-Host "      fiap-users-api aplicado!" -ForegroundColor Green
} else {
    Write-Host "      AVISO: fiap-users-api/k8s não encontrado" -ForegroundColor Yellow
}

# Adicione outros projetos aqui:
# $notificationsApiK8s = Join-Path $ReposDir "fiap-notifications-api\k8s"
# if (Test-Path $notificationsApiK8s) {
#     Write-Host "      Aplicando fiap-notifications-api/k8s..." -ForegroundColor Gray
#     kubectl apply -f $notificationsApiK8s
# }

# Aguardar pods ficarem prontos
if ($WaitForReady) {
    Write-Host ""
    Write-Host "[5/5] Aguardando pods ficarem prontos..." -ForegroundColor Yellow
    
    Write-Host "      Aguardando SQL Server..." -ForegroundColor Gray
    kubectl wait --for=condition=ready pod -l app=sqlserver -n fiap-cloud-games --timeout=120s
    
    Write-Host "      Aguardando Users API..." -ForegroundColor Gray
    kubectl wait --for=condition=ready pod -l app=users-api -n fiap-cloud-games --timeout=120s
    
    Write-Host "      Todos os pods estão prontos!" -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "[5/5] Pulando espera por pods (use -WaitForReady para aguardar)" -ForegroundColor Yellow
}

# Mostrar status
Write-Host ""
Write-Host "[5/5] Status dos recursos:" -ForegroundColor Yellow
Write-Host ""
kubectl get all -n fiap-cloud-games

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Deploy concluído com sucesso!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Para acessar a API localmente, execute:" -ForegroundColor Yellow
Write-Host "  kubectl port-forward svc/users-api 8080:80 -n fiap-cloud-games" -ForegroundColor White
Write-Host ""
Write-Host "Acesse: http://localhost:8080/swagger" -ForegroundColor Cyan
Write-Host ""
