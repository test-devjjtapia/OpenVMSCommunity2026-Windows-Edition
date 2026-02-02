<#
.SYNOPSIS
    Script de conexión a OpenVMS Community 2026 para Windows.
    
.DESCRIPTION
    Proporciona un menú interactivo para conectarse a la VM OpenVMS
    usando el cliente Telnet de Windows o PuTTY.
    Incluye detección automática de herramientas y estado de VM.

.AUTHOR
    Javier J. Tapia

.DATE
    Febrero 2026
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue" # Permitir errores controlados para comprobaciones

# Configuración
$HOST_IP = "127.0.0.1"
$PORT = 2026
$VM_NAME = "OpenVMS-Community_2026"

# ============================================================================
# FUNCIONES
# ============================================================================

function Write-Header {
    Clear-Host
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "OpenVMS Community 2026 - Conector Windows" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Info { param([string]$msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-ErrorMsg { param([string]$msg) Write-Host "[X] $msg" -ForegroundColor Red }
function Write-Warn { param([string]$msg) Write-Host "[!] $msg" -ForegroundColor Yellow }

function Get-CommandPath {
    param($Name)
    if (Get-Command $Name -ErrorAction SilentlyContinue) { return $true }
    return $false
}

function Get-PuttyPath {
    if (Get-Command "putty" -ErrorAction SilentlyContinue) { return "putty" }
    
    $CommonPaths = @(
        "$env:ProgramFiles\PuTTY\putty.exe",
        "$env:ProgramFiles(x86)\PuTTY\putty.exe"
    )
    foreach ($Path in $CommonPaths) {
        if (Test-Path $Path) { return $Path }
    }
    return $null
}

function Check-VM-Running {
    $VBox = Get-Command "VBoxManage" -ErrorAction SilentlyContinue
    if (-not $VBox) { 
        # Intentar ruta común
        $Path = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
        if (Test-Path $Path) { $VBox = $Path }
    }

    if ($VBox) {
        $Running = & $VBox list runningvms
        if ($Running -match $VM_NAME) {
            Write-Info "VM OpenVMS está corriendo."
            return $true
        }
        else {
            Write-ErrorMsg "VM OpenVMS NO está corriendo."
            return $false
        }
    }
    else {
        Write-Warn "No se pudo verificar el estado de la VM (VBoxManage no encontrado)."
        return $true # Asumir true para permitir intentar conexión
    }
}

function Enable-TelnetClient {
    Write-Host "Intentando habilitar Cliente Telnet (requiere Admin)..." -ForegroundColor Yellow
    Start-Process -FilePath "dism.exe" -ArgumentList "/online /Enable-Feature /FeatureName:TelnetClient" -Verb RunAs -Wait
    Write-Host "Por favor reinicia este script tras la instalación." -ForegroundColor Cyan
    Pause
}

# ============================================================================
# MENÚ
# ============================================================================

Write-Header
Write-Host "Verificando herramientas..." -ForegroundColor Gray

$TelnetAvailable = Get-CommandPath "telnet"
$PuttyPath = Get-PuttyPath

if ($TelnetAvailable) { Write-Info "Cliente Telnet nativo disponible." }
else { Write-Warn "Cliente Telnet NO instalado." }

if ($PuttyPath) { Write-Info "PuTTY disponible en: $PuttyPath" }
else { Write-Warn "PuTTY no encontrado (se recomienda instalarlo)." }

$VMSStatus = Check-VM-Running

Write-Host ""
Write-Host "OPCIONES DE CONEXION:" -ForegroundColor Cyan
$OptIndex = 1

if ($TelnetAvailable) {
    Write-Host "  $OptIndex) Telnet (Consola actual)"
    $OptTelnet = $OptIndex; $OptIndex++
}

if ($PuttyAvailable) {
    Write-Host "  $OptIndex) PuTTY (Nueva ventana)"
    $OptPutty = $OptIndex; $OptIndex++
}

Write-Host "  $OptIndex) Instalar Cliente Telnet de Windows"
$OptInstall = $OptIndex; $OptIndex++

Write-Host "  $OptIndex) Ver Info de Conexion"
$OptInfo = $OptIndex; $OptIndex++

Write-Host "  Q) Salir"

Write-Host ""
$Selection = Read-Host "Selecciona una opcion"

switch ($Selection) {
    { $TelnetAvailable -and $_ -eq $OptTelnet } {
        Write-Host "Conectando via Telnet... (Ctrl+] y luego 'quit' para salir)" -ForegroundColor Cyan
        telnet $HOST_IP $PORT
    }
    { $PuttyAvailable -and $_ -eq $OptPutty } {
        Write-Host "Lanzando PuTTY..." -ForegroundColor Cyan
        Start-Process putty -ArgumentList "-telnet $HOST_IP $PORT"
    }
    $OptInstall {
        Enable-TelnetClient
    }
    $OptInfo {
        Write-Host ""
        Write-Host "INFO CONEXION" -ForegroundColor Cyan
        Write-Host "Host: $HOST_IP"
        Write-Host "Puerto: $PORT"
        Write-Host "Usuario: SYSTEM"
        Write-Host "Password: (el que hayas configurado o MANAGER)"
        Write-Host ""
        Pause
    }
    "Q" { exit }
    "q" { exit }
    Default { Write-Host "Opcion no valida." -ForegroundColor Red }
}
