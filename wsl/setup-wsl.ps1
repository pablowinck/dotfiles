<#
.SYNOPSIS
  Bootstrap do ambiente WSL para replicar o setup do Mac do Pablo.
.DESCRIPTION
  - Instala Postman Desktop e Docker Desktop via winget no Windows.
  - Habilita integracao WSL2 do Docker Desktop com Ubuntu-26.04.
  - Dispara install.sh dentro do WSL via curl.
.NOTES
  Executar como administrador (winget exige).
  Arquivo em ASCII puro para compatibilidade com PowerShell 5.x.
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

# 2. winget presente + aceitar termos das sources (evita travar em list/install)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget nao encontrado. Instale 'App Installer' na Microsoft Store."
}
Write-Ok "winget disponivel"

Write-Info "Inicializando sources do winget (reset + update)"
try {
    winget source reset --force 2>&1 | Out-Null
    winget source update --disable-interactivity 2>&1 | Out-Null
    Write-Ok "Sources do winget OK"
} catch {
    Write-Skip "Falha em winget source reset/update (vai prosseguir)"
}

function Test-WingetInstalled {
    param([string]$Id)
    $output = winget list --id $Id -e --accept-source-agreements --disable-interactivity 2>&1 | Out-String
    return ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($Id))
}

function Install-WingetPackage {
    param([string]$Id, [string]$Name)
    $output = winget install --id $Id -e --accept-package-agreements --accept-source-agreements --disable-interactivity --silent 2>&1 | Out-String
    Write-Host $output
    if ($LASTEXITCODE -ne 0 -or $output -match '0x8a15000f|Nenhum pacote foi encontrado|No package found') {
        Write-Host "winget falhou; vai tentar download direto do instalador" -ForegroundColor Yellow
        return $false
    }
    Write-Ok "$Name instalado via winget"
    return $true
}

function Install-FromUrl {
    param(
        [string]$Url,
        [string]$FileName,
        [string]$Args,
        [string]$Name
    )
    $installer = Join-Path $env:TEMP $FileName
    Write-Info "Baixando $Name de $Url"
    try {
        $progressPreference = 'silentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $installer -UseBasicParsing
    } catch {
        Write-Fail "Falha no download de $Name`: $($_.Exception.Message)"
    }
    Write-Info "Executando installer (silencioso) de $Name"
    try {
        if ($Args) {
            $proc = Start-Process -FilePath $installer -ArgumentList $Args -Wait -PassThru
        } else {
            $proc = Start-Process -FilePath $installer -Wait -PassThru
        }
        if ($proc.ExitCode -ne 0) {
            Write-Fail "$Name installer retornou exit code $($proc.ExitCode)"
        }
    } finally {
        Remove-Item $installer -Force -ErrorAction SilentlyContinue
    }
    Write-Ok "$Name instalado via download direto"
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
Write-Info "Verificando Postman Desktop"
if (Test-WingetInstalled "Postman.Postman") {
    Write-Skip "Postman ja instalado"
} elseif (Test-Path "$env:LOCALAPPDATA\Postman\Postman.exe") {
    Write-Skip "Postman ja instalado (detectado em LOCALAPPDATA)"
} else {
    Write-Info "Instalando Postman Desktop via winget"
    if (-not (Install-WingetPackage "Postman.Postman" "Postman")) {
        Install-FromUrl `
            -Url "https://dl.pstmn.io/download/latest/win64" `
            -FileName "Postman-Setup.exe" `
            -Args "/S" `
            -Name "Postman"
    }
}

# 5. Docker Desktop
Write-Info "Verificando Docker Desktop"
if (Test-WingetInstalled "Docker.DockerDesktop") {
    Write-Skip "Docker Desktop ja instalado"
    Read-Host "Confirme que Docker Desktop esta rodando com WSL Integration para Ubuntu-26.04 habilitado, e pressione Enter"
} elseif (Test-Path "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe") {
    Write-Skip "Docker Desktop ja instalado (detectado em Program Files)"
    Read-Host "Confirme que Docker Desktop esta rodando com WSL Integration para Ubuntu-26.04 habilitado, e pressione Enter"
} else {
    Write-Info "Instalando Docker Desktop via winget"
    if (-not (Install-WingetPackage "Docker.DockerDesktop" "Docker Desktop")) {
        Install-FromUrl `
            -Url "https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe" `
            -FileName "Docker-Desktop-Installer.exe" `
            -Args "install --quiet --accept-license" `
            -Name "Docker Desktop"
    }
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
