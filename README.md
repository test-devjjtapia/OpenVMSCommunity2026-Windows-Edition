# OpenVMS Community 2026 - Windows Edition

Repositorio profesional para la gestión, despliegue y documentación de OpenVMS Community 2026 en Windows 10 Pro. Optimizado para estabilidad y cumplimiento con estándares VSI.

## 🚀 Características
- **100% Nativo Windows**: Scripts PowerShell optimizados y sin dependencias de Linux.
- **VSI Compliant**: Configuración de hardware (Chipset ICH9, Red Intel Server, UEFI) validada.
- **Automatización Total**: Creación de VM y gestión de conexiones en un solo clic.
- **Documentación en Español**: Guías claras y solución de problemas comunes.

## 📁 Estructura del Proyecto

```
.
├── docs/                          # Documentación y guías
├── scripts/                       # Scripts PowerShell de automatización
│   ├── connection/                # Connect-OpenVMS.ps1
│   └── vm-creation/               # Create-VM.ps1
├── vm-images/                     # Imágenes de disco (excluidas en git)
├── resources/                     # Recursos adicionales (PDFs, Videos)
└── LICENSE                        # Licencia MIT
```

## 🛠️ Instalación y Uso

### 1. Preparación del Entorno
Asegúrate de tener instalado:
- **VirtualBox 7.x** (Con Extension Pack compatible).
- **PuTTY** (Recomendado) o cliente Telnet habilitado.

### 2. Crear la Máquina Virtual
Ejecuta el script de creación. Este script validará tu entorno, copiará los discos y configurará el hardware exacto recomendado por VSI.

```powershell
.\scripts\vm-creation\Create-VM.ps1
```

### 3. Conectar a OpenVMS
Usa el script de conexión para abrir una sesión serial automáticamente:

```powershell
.\scripts\connection\Connect-OpenVMS.ps1
```

## ⚠️ Solución de Problemas (Troubleshooting)

### Pantalla Negra "Eterna" (Snail Mode)
Si la VM arranca pero se queda en pantalla negra y parece no responder por minutos:
- **Causa**: Conflictos con Hyper-V o "Aislamiento del Núcleo" de Windows.
- **Solución**: Desactivar la integridad de memoria en Seguridad de Windows o ejecutar `bcdedit /set hypervisorlaunchtype off` y reiniciar.

### Error: "Only single connection supported"
VirtualBox solo permite una conexión serial a la vez.
- **Síntoma**: El script de conexión falla o se cierra inmediatamente.
- **Solución**: Asegúrate de no tener ninguna ventana de PuTTY abierta (incluso minimizada) y reintenta. Si persiste, reinicia la VM.

### Puerto de Red y Firewall
Si no puedes conectar, verifica que el **Puerto 2026** no esté bloqueado por el Firewall de Windows. El script usa este puerto para redirigir la consola serial.

## ⚠️ Nota Importante: Conflicto con WSL2

Para que esta VM funcione correctamente (sin "Snail Mode"), desactivamos Hyper-V. Esto **deshabilita WSL2** temporalmente.

### ¿Cómo alternar?

- **Modo OpenVMS (WSL2 roto, VirtualBox Rápido)**:
  Ejecutar como Admin y reiniciar:
  ```cmd
  bcdedit /set hypervisorlaunchtype off
  ```

- **Modo WSL2 (VirtualBox Lento/Pantalla Negra, WSL2 Funciona)**:
  Ejecutar como Admin y reiniciar:
  ```cmd
  bcdedit /set hypervisorlaunchtype auto
  ```

Actualmente no es posible tener ambos funcionando al 100% de rendimiento simultáneamente para este tipo de VM antigua.

## 📝 Licencia

Este proyecto está bajo la Licencia **MIT**.
Copyright (c) 2026 **Javier J. Tapia**.
