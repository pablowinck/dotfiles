<#
.SYNOPSIS
  Bootstrap do ambiente WSL para replicar o setup do Mac do Pablo.
.DESCRIPTION
  - Instala Postman Desktop e Docker Desktop via Chocolatey no Windows.
  - Habilita integracao WSL2 do Docker Desktop com Ubuntu-26.04.
  - Dispara install.sh dentro do WSL.
.NOTES
  Executar como administrador (Chocolatey exige).
  Arquivo em ASCII puro para compatibilidade com PowerShell 5.x.
  Usa Chocolatey em vez de winget porque winget tem bug recorrente
  0x8a15000f em maquinas com source corrompida.
#>

$ErrorActionPreference = 'Stop'

function Write-Info  { param($m) Write-Host "[..] $m" -ForegroundColor Cyan }
function Write-Ok    { param($m) Write-Host "[ok] $m" -ForegroundColor Green }
function Write-Skip  { param($m) Write-Host "[skip] $m" -ForegroundColor Yellow }
function Write-Fail  { param($m) Write-Host "[fail] $m" -ForegroundColor Red; exit 1 }

# 1. Admin check
$current = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Fail "Rode este script no PowerShell como Administrador."
}
Write-Ok "Executando como administrador"

# 2. Chocolatey (instala se faltar)
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Info "Instalando Chocolatey"
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    # Atualiza PATH da sessao atual sem precisar reiniciar
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Fail "Chocolatey foi instalado mas choco nao esta no PATH. Reinicie o PowerShell e re-execute."
    }
    Write-Ok "Chocolatey instalado"
} else {
    Write-Skip "Chocolatey ja instalado"
}

function Install-ChocoPackage {
    param([string]$Name)
    Write-Info "choco install $Name"
    choco install $Name -y --no-progress --limit-output
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "Falha ao instalar $Name via Chocolatey (exit code $LASTEXITCODE)"
    }
    Write-Ok "$Name instalado (ou ja existente)"
}

# 3. WSL com Ubuntu-26.04
# wsl.exe imprime em UTF-16 LE por padrao; WSL_UTF8=1 forca UTF-8 para captura limpa
$env:WSL_UTF8 = "1"
$wslList = (wsl.exe -l -v 2>&1) -join "`n"
if ($wslList -notmatch 'Ubuntu-26\.04') {
    Write-Host "Output de 'wsl -l -v' recebido:" -ForegroundColor Yellow
    Write-Host $wslList
    Write-Fail "Distro Ubuntu-26.04 nao encontrada. Instale primeiro: wsl --install -d Ubuntu-26.04"
}
Write-Ok "Distro Ubuntu-26.04 encontrada"

# 4. Postman Desktop
Install-ChocoPackage "postman"

# 5. Docker Desktop
$dockerAlreadyInstalled = (Test-Path "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe")
Install-ChocoPackage "docker-desktop"
if ($dockerAlreadyInstalled) {
    Read-Host "Confirme que Docker Desktop esta rodando com WSL Integration para Ubuntu-26.04 habilitado, e pressione Enter"
} else {
    Write-Info "Abra o Docker Desktop manualmente uma vez para inicializar o daemon."
    Write-Info "Depois habilite WSL Integration em: Settings, Resources, WSL Integration, Ubuntu-26.04 = ON"
    Read-Host "Pressione Enter quando o Docker Desktop estiver rodando e a integracao WSL habilitada"
}

# 6. Disparar install.sh dentro do WSL
Write-Info "Executando install.sh dentro do WSL Ubuntu-26.04"
$wslCmd = "set -e; if [ ! -d ~/.dotfiles ]; then git clone https://github.com/pablowinck/dotfiles.git ~/.dotfiles; fi; bash ~/.dotfiles/wsl/install.sh"
wsl.exe -d Ubuntu-26.04 bash -lc "$wslCmd"

if ($LASTEXITCODE -ne 0) {
    Write-Fail "install.sh dentro do WSL retornou erro. Veja saida acima."
}

Write-Ok "Bootstrap concluido. Abra o WSL Ubuntu-26.04 e rode 'claude login' manualmente."
