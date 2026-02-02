<#
.SYNOPSIS
    Script de creación de VM OpenVMS Community 2026 para Windows.
    
.DESCRIPTION
    Este script automatiza la creación y configuración de una máquina virtual OpenVMS
    versión 9.2-3 (Community Edition 2026) en VirtualBox para Windows.
    Optimizado para Windows 10 Pro y Hardware Oficial VSI.

.AUTHOR
    Javier J. Tapia

.DATE
    Febrero 2026

.PARAMETER CheckOnly
    Si se especifica, solo realiza las validaciones sin realizar cambios.

.EXAMPLE
    .\Create-VM.ps1
    Crea la VM estándar.

.EXAMPLE
    .\Create-VM.ps1 -CheckOnly
    Solo verifica requisitos.
#>

[CmdletBinding()]
param (
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ============================================================================
# CONFIGURACIÓN
# ============================================================================

$VM_NAME = "OpenVMS-Community_2026"
$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = Split-Path (Split-Path $SCRIPT_DIR -Parent) -Parent

# Rutas de imágenes fuente
$VMDK_SOURCE = Join-Path $PROJECT_ROOT "vm-images\disks\X86_V923-comm-2026.vmdk"
$VMDK_FLAT_SOURCE = Join-Path $PROJECT_ROOT "vm-images\disks\X86_V923-comm-2026-flat.vmdk"

# Directorio de VirtualBox (usuario)
# Intentar detectar la ruta de VMs por defecto de VirtualBox o usar Documents
$VBoxVMsDir = "$env:USERPROFILE\VirtualBox VMs"
# Si existe una variable de entorno o registro para esto, sería ideal, pero el defecto es seguro.

$VM_DISK_DIR = Join-Path $VBoxVMsDir "$VM_NAME\Disks"
$VMDK_DEST = Join-Path $VM_DISK_DIR "X86_V923-comm-2026.vmdk"
$VMDK_FLAT_DEST = Join-Path $VM_DISK_DIR "X86_V923-comm-2026-flat.vmdk"

# Hardware
$CONTROLLER = "SATA"
$TELNET_PORT = 2026
$CPU_COUNT = 2
$MEMORY_MB = 2049
$FIRMWARE = "efi64"
$CHIPSET = "ich9"
$NIC_TYPE = "82545EM" # Intel PRO/1000 MT Server (Recomendado por VSI)

# ============================================================================
# FUNCIONES
# ============================================================================

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $Color = "White"
    
    switch ($Level) {
        "INFO" { $Color = "Cyan" }
        "SUCCESS" { $Color = "Green"; $Message = "[OK] $Message" }
        "ERROR" { $Color = "Red"; $Message = "[X] $Message" }
        "WARNING" { $Color = "Yellow"; $Message = "[!] $Message" }
    }
    
    Write-Host "$Timestamp [$Level] $Message" -ForegroundColor $Color
}

function Get-VBoxManagePath {
    # Intentar encontrar VBoxManage en PATH o rutas comunes
    if (Get-Command "VBoxManage" -ErrorAction SilentlyContinue) {
        return "VBoxManage"
    }
    
    $CommonPaths = @(
        "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe",
        "$env:ProgramFiles(x86)\Oracle\VirtualBox\VBoxManage.exe"
    )
    
    foreach ($Path in $CommonPaths) {
        if (Test-Path $Path) {
            return $Path
        }
    }
    return $null
}

# ============================================================================
# EJECUCIÓN PRINCIPAL
# ============================================================================

Clear-Host
Write-Log "=========================================="
Write-Log "OpenVMS Community 2026 - Creador de VM para Windows"
Write-Log "=========================================="
Write-Host ""

# 1. Verificar VirtualBox
$VBoxManage = Get-VBoxManagePath
if (-not $VBoxManage) {
    Write-Log "No se encontró VirtualBox (VBoxManage.exe)." "ERROR"
    Write-Log "Por favor instala VirtualBox o asegúrate de que está en el PATH." "ERROR"
    exit 1
}
Write-Log "VirtualBox encontrado: $VBoxManage" "SUCCESS"

# 2. Verificar Archivos Fuente
if (-not (Test-Path $VMDK_SOURCE) -or -not (Test-Path $VMDK_FLAT_SOURCE)) {
    Write-Log "Archivos VMDK no encontrados en el proyecto:" "ERROR"
    Write-Log "  - $VMDK_SOURCE" "ERROR"
    Write-Log "  - $VMDK_FLAT_SOURCE" "ERROR"
    exit 1
}
Write-Log "Imagenes VMDK encontradas." "SUCCESS"

# 3. Verificar si la VM existe
# Usar cmd /c para evitar problemas de parsing de argumentos complejos en invocacion directa
$VMList = & $VBoxManage list vms
if ($VMList -match "\b$VM_NAME\b") {
    Write-Log "La VM '$VM_NAME' ya existe en VirtualBox." "ERROR"
    Write-Log "Por favor eliminala manualmente antes de continuar si deseas recrearla." "ERROR"
    exit 1
}
Write-Log "Verificacion: La VM no existe (OK)." "SUCCESS"

# 4. Verificar Espacio (aproximado)
try {
    $Drive = Get-Item $VBoxVMsDir -ErrorAction SilentlyContinue
    if (-not $Drive) {
        # Si no existe el dir, verificar el drive padre
        $DriveLetter = Split-Path $VBoxVMsDir -Qualifier
        $Drive = Get-PSDrive $DriveLetter[0]
    }
    else {
        $DriveLetter = $Drive.PSDrive.Name
        $Drive = Get-PSDrive $DriveLetter
    }
    
    $FreeSpaceGB = [math]::Round($Drive.Free / 1GB, 2)
    Write-Log "Espacio libre en disco ($($Drive.Name)): $FreeSpaceGB GB" "INFO"
    if ($FreeSpaceGB -lt 10) {
        Write-Log "Advertencia: Menos de 10GB libres. Podria fallar." "WARNING"
    }
    else {
        Write-Log "Espacio suficiente." "SUCCESS"
    }
}
catch {
    Write-Log "No se pudo verificar el espacio en disco (continuando bajo riesgo)." "WARNING"
}

Write-Host ""

if ($CheckOnly) {
    Write-Log "Modo CheckOnly completado. No se realizaron cambios." "SUCCESS"
    exit 0
}

# ----------------------------------------------------------------------------
# CREACION
# ----------------------------------------------------------------------------

# Crear directorios
try {
    if (-not (Test-Path $VM_DISK_DIR)) {
        New-Item -ItemType Directory -Path $VM_DISK_DIR -Force | Out-Null
        Write-Log "Directorio creado: $VM_DISK_DIR" "SUCCESS"
    }
}
catch {
    Write-Log "Error creando directorios: $_" "ERROR"
    exit 1
}

# Copiar archivos
Write-Log "Copiando imagenes de disco (esto puede tardar unos minutos)..." "INFO"

function Copy-WithProgress {
    param($Source, $Dest)
    Write-Host "  Copiando $(Split-Path $Source -Leaf)..." -NoNewline
    Copy-Item $Source $Dest -Force
    Write-Host " OK" -ForegroundColor Green
}

Copy-WithProgress $VMDK_SOURCE $VMDK_DEST
Copy-WithProgress $VMDK_FLAT_SOURCE $VMDK_FLAT_DEST
Write-Log "Archivos copiados exitosamente." "SUCCESS"
Write-Host ""

# Crear VM
Write-Log "Creando maquina virtual..." "INFO"
& $VBoxManage createvm --ostype "Other_64" --name "$VM_NAME" --basefolder "$VBoxVMsDir" --register
if ($LASTEXITCODE -eq 0) { Write-Log "VM registrada." "SUCCESS" } else { Write-Log "Error creando VM." "ERROR"; exit 1 }

# Crear Controlador SATA
Write-Log "Configurando almacenamiento..." "INFO"
& $VBoxManage storagectl "$VM_NAME" --name "$CONTROLLER" --add SATA --bootable on --portcount 4 --controller IntelAhci --hostiocache on

# Hardware
Write-Log "Configurando hardware..." "INFO"
& $VBoxManage modifyvm "$VM_NAME" --ostype "Other_64"
& $VBoxManage modifyvm "$VM_NAME" --cpus $CPU_COUNT
& $VBoxManage modifyvm "$VM_NAME" --pae on
& $VBoxManage modifyvm "$VM_NAME" --memory $MEMORY_MB
& $VBoxManage modifyvm "$VM_NAME" --firmware $FIRMWARE
& $VBoxManage modifyvm "$VM_NAME" --chipset $CHIPSET
& $VBoxManage modifyvm "$VM_NAME" --boot1 disk
& $VBoxManage modifyvm "$VM_NAME" --ioapic on
& $VBoxManage modifyvm "$VM_NAME" --audio none

# Red y Serial
Write-Log "Configurando red y consola serial..." "INFO"
& $VBoxManage modifyvm "$VM_NAME" --uart1 0x3F8 4 --uartmode1 tcpserver $TELNET_PORT
& $VBoxManage modifyvm "$VM_NAME" --nic1 nat
& $VBoxManage modifyvm "$VM_NAME" --nictype1 $NIC_TYPE
& $VBoxManage modifyvm "$VM_NAME" --cableconnected1 on

# Montar Disco
Write-Log "Montando disco duro..." "INFO"
& $VBoxManage storageattach "$VM_NAME" --storagectl "$CONTROLLER" --port 0 --type hdd --medium "$VMDK_DEST"

Write-Host ""
Write-Log "==========================================" "SUCCESS"
Write-Log "VM Creada Exitosamente!" "SUCCESS"
Write-Log "==========================================" "SUCCESS"
Write-Host ""
Write-Log "Instrucciones:" "INFO"
Write-Log "1. Inicia la VM desde VirtualBox o con:" "INFO"
Write-Log "   & '$VBoxManage' startvm '$VM_NAME' --type headless" "INFO"
Write-Log "2. Conectate usando el script de conexion o Putty a:" "INFO"
Write-Log "   Host: 127.0.0.1, Puerto: $TELNET_PORT, Protocolo: Telnet" "INFO"
Write-Host ""
