
param(
    [string]$UsuarioSSH = "node-02",
    [string]$NombreMiniPC = "MiniPC"
)



$logFile = "$PSScriptRoot\ssh_setup_log.txt"
Start-Transcript -Path $logFile -Append

Write-Host "===============================" -ForegroundColor Cyan
Write-Host " Ejecutando configuración automática de SSH..." -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan

try {
    # ------------------------
    # Paso 1: Habilitar WSL y Plataforma
    # ------------------------
    Write-Host "Habilitando subsistema de Windows para Linux (WSL)..."
    dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart

    Write-Host "Habilitando plataforma de máquina virtual..."
    dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

    # ------------------------
    # Paso 2: Instalar OpenSSH Server
    # ------------------------
    Write-Host "Instalando OpenSSH Server..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0 -ErrorAction Stop

    # ------------------------
    # Paso 3: Generar contraseña segura manualmente
    # ------------------------
    function Generar-PasswordSegura {
        $length = 12
        $chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNOPQRSTUVWXYZ0123456789!@#$%^&*()-_=+[]{}'
        -join ((1..$length) | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    }

    $Password = Generar-PasswordSegura
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force

    # Crear usuario local si no existe
    if (-not (Get-LocalUser -Name $UsuarioSSH -ErrorAction SilentlyContinue)) {
        Write-Host "Creando usuario local '$UsuarioSSH'..."
        New-LocalUser -Name $UsuarioSSH -Password $SecurePassword -FullName $UsuarioSSH -Description "Usuario SSH creado por script" -ErrorAction Stop
    } else {
        Write-Host "El usuario '$UsuarioSSH' ya existe." -ForegroundColor Yellow
    }

    # Obtener el grupo de administradores local y añadir el usuario si no es miembro
    $administratorsGroup = (Get-LocalGroup | Where-Object { $_.SID -eq 'S-1-5-32-544' }).Name
    if ($administratorsGroup) {
        $members = Get-LocalGroupMember -Group $administratorsGroup
        if ($members.Name -notcontains $UsuarioSSH) {
            Write-Host "Añadiendo usuario '$UsuarioSSH' al grupo '$administratorsGroup'..."
            Add-LocalGroupMember -Group $administratorsGroup -Member $UsuarioSSH -ErrorAction Stop
        } else {
            Write-Host "El usuario '$UsuarioSSH' ya es miembro del grupo '$administratorsGroup'." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No se pudo encontrar el grupo de administradores. Omitiendo la adición del usuario al grupo." -ForegroundColor Yellow
    }

    # Configurar Firewall
    Write-Host "Configurando Firewall para permitir SSH..."
    $ruleName = "OpenSSH-Server-In-TCP"
    if (-not (Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name $ruleName -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction Stop
    } else {
        Write-Host "La regla de firewall '$ruleName' ya existe." -ForegroundColor Yellow
    }

    # Guardar credenciales
    $cred = @{ Usuario = $UsuarioSSH; Password = $Password; Hostname = $NombreMiniPC }
    $path = "$PSScriptRoot\credenciales_ssh_${UsuarioSSH}.txt"
    $cred | ConvertTo-Json | Out-File -Encoding UTF8 -FilePath $path

    Write-Host "`nCredenciales guardadas en: $path" -ForegroundColor Green
    Write-Host "`nSSH habilitado correctamente. Datos de acceso:"
    Write-Host "  Usuario: $UsuarioSSH"
    Write-Host "  Contraseña: $Password"
    Write-Host "  Nombre del equipo: $NombreMiniPC"

} catch {
    Write-Host "`nError en la ejecución del script: $_" -ForegroundColor Red
    "Error en la ejecución del script: $_" | Out-File -FilePath $logFile -Append
} finally {
    Stop-Transcript
}
