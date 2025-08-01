# ╭────────────────────────────────────────────╮
# │ Configuración Automática de IP Estática    │
# │ Autor:CRYPTOPLAZA             │
# ╰────────────────────────────────────────────╯

$logFile = "$PSScriptRoot\ip_config_log.txt"
Start-Transcript -Path $logFile -Append

function Obtener-AdaptadorEthernet {
    $adaptadores = Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.Name -like '*Ethernet*' }
    if ($adaptadores.Count -eq 0) {
        Write-Host "No se encontró un adaptador Ethernet activo." -ForegroundColor Red
        exit 1
    }
    return $adaptadores[0]
}

function Solicitar-IP {
    do {
        $ip = Read-Host "Ingresa la IP fija que deseas asignar (ej: 50.190.105.83)"
        $valida = [System.Net.IPAddress]::TryParse($ip, [ref]$null)
        if (-not $valida) {
            Write-Host "IP inválida. Intenta de nuevo." -ForegroundColor Yellow
        }
    } while (-not $valida)
    return $ip
}

function Detectar-CarpetaDescargas {
    $idioma = (Get-Culture).Name
    $descargas = if ($idioma.StartsWith("es")) { "$env:USERPROFILE\Descargas" } else { "$env:USERPROFILE\Downloads" }
    if (-not (Test-Path $descargas)) {
        New-Item -ItemType Directory -Path $descargas | Out-Null
    }
    return $descargas
}

try {
    # Paso 1: Obtener adaptador
    $adaptador = Obtener-AdaptadorEthernet
    $nombre = $adaptador.Name
    Write-Host "`n Adaptador detectado: $nombre" -ForegroundColor Cyan

    # Paso 2: IP manual
    $ip = Solicitar-IP
    $gateway = "50.190.105.94"
    $prefixLength = 28
    $dns = @("8.8.8.8", "1.1.1.1")

    # Paso 3: Aplicar configuración
    Write-Host "`n⚙ Asignando IP $ip al adaptador $nombre ..." -ForegroundColor White
    New-NetIPAddress -InterfaceAlias $nombre -IPAddress $ip -PrefixLength $prefixLength -DefaultGateway $gateway -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $nombre -ServerAddresses $dns -ErrorAction Stop
    Write-Host "Configuración aplicada exitosamente." -ForegroundColor Green

    # Paso 4: Exportar a JSON
    $export = [PSCustomObject]@{
        Fecha     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        Adaptador = $nombre
        IP        = $ip
        Gateway   = $gateway
        Mascara   = $prefixLength
        DNS       = $dns
    }

    $carpeta = Detectar-CarpetaDescargas
    $rutaJSON = Join-Path $carpeta "config_ip.json"
    $export | ConvertTo-Json | Set-Content -Path $rutaJSON -Encoding UTF8
    Write-Host "`n📄 Archivo JSON generado en:" -NoNewline
    Write-Host " $rutaJSON" -ForegroundColor Cyan

} catch {
    Write-Host "Error aplicando configuración: $($_.Exception.Message)" -ForegroundColor Red
} finally {
    Stop-Transcript
    pause
}