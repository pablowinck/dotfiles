<#
.SYNOPSIS
  Bootstrap do ambiente WSL para replicar o setup do Mac do Pablo.
.DESCRIPTION
  - Instala Postman Desktop e Docker Desktop via winget no Windows.
  - Habilita integração WSL2 do Docker Desktop com Ubuntu-26.04.
  - Dispara install.sh dentro do WSL via curl.
.NOTES
  Executar como administrador (winget exige).
#>

$ErrorActionPreference = 'Stop'

function Write-Info  { param($m) Write-Host "▶ $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "✓ $m" -ForegroundColor Green }
function Write-Skip  { param($m) Write-Host "↷ $m" -ForegroundColor Yellow }
function Write-Fail  { param($m) Write-Host "✗ $m" -ForegroundColor Red; exit 1 }

# 1. Admin check
$current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Rode este script no PowerShell como Administrador."
}
Write-Ok "Executando como administrador"

# 2. winget presente
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget não encontrado. Instale 'App Installer' na Microsoft Store."
}
Write-Ok "winget disponível"

# 3. WSL com Ubuntu-26.04
$wslList = wsl.exe -l -v
if ($wslList -notmatch 'Ubuntu-26\.04') {
    Write-Fail "Distro Ubuntu-26.04 não encontrada. Instale primeiro: wsl --install -d Ubuntu-26.04"
}
Write-Ok "Distro Ubuntu-26.04 encontrada"

# 4. Postman Desktop
Write-Info "Verificando Postman Desktop"
$postman = winget list --id Postman.Postman -e 2>$null
if ($LASTEXITCODE -eq 0 -and $postman -match 'Postman') {
    Write-Skip "Postman já instalado"
} else {
    Write-Info "Instalando Postman Desktop via winget"
    winget install --id Postman.Postman -e --accept-package-agreements --accept-source-agreements --silent
    Write-Ok "Postman instalado"
}

# 5. Docker Desktop
Write-Info "Verificando Docker Desktop"
$docker = winget list --id Docker.DockerDesktop -e 2>$null
if ($LASTEXITCODE -eq 0 -and $docker -match 'Docker Desktop') {
    Write-Skip "Docker Desktop já instalado"
    Read-Host "Confirme que Docker Desktop está rodando com WSL Integration para Ubuntu-26.04 habilitado, e pressione Enter"
} else {
    Write-Info "Instalando Docker Desktop via winget"
    winget install --id Docker.DockerDesktop -e --accept-package-agreements --accept-source-agreements --silent
    Write-Ok "Docker Desktop instalado"
    Write-Info "Abra o Docker Desktop manualmente uma vez para inicializar o daemon."
    Write-Info "Depois habilite WSL Integration: Settings > Resources > WSL Integration > Ubuntu-26.04 = ON"
    Read-Host "Pressione Enter quando o Docker Desktop estiver rodando e a integração WSL habilitada"
}

# 6. Disparar install.sh dentro do WSL
Write-Info "Executando install.sh dentro do WSL Ubuntu-26.04"
$wslCmd = "set -e; if [ ! -d ~/.dotfiles ]; then git clone https://github.com/pablowinck/dotfiles.git ~/.dotfiles; fi; bash ~/.dotfiles/wsl/install.sh"
wsl.exe -d Ubuntu-26.04 bash -lc "$wslCmd"

if ($LASTEXITCODE -ne 0) {
    Write-Fail "install.sh dentro do WSL retornou erro. Veja saída acima."
}

Write-Ok "Bootstrap concluído. Abra o WSL Ubuntu-26.04 e rode 'claude login' manualmente."
