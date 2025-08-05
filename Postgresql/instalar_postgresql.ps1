param()

function Solicitar-Entrada($mensaje, $defecto) {
    $input = Read-Host "$mensaje [$defecto]"
    if ([string]::IsNullOrWhiteSpace($input)) { return $defecto }
    return $input
}

Write-Host "`n🛠️ Instalador Automático de PostgreSQL" -ForegroundColor Cyan

# 1. Solicitar nombre del instalador
$nombreInstalador = Read-Host "Ingresa el nombre del archivo .exe (en tu carpeta Descargas)"
$carpetaDescargas = "$env:USERPROFILE\Downloads"
$rutaInstalador = Join-Path $carpetaDescargas $nombreInstalador

if (!(Test-Path $rutaInstalador)) {
    Write-Host "❌ No se encontró el archivo: $rutaInstalador" -ForegroundColor Red
    exit 1
}

# 2. Ruta de instalación
$rutaInstalacion = Solicitar-Entrada "Ruta de instalación" "C:\Program Files\PostgreSQL15"

# 3. Contraseña del superusuario postgres
$superPassword = Read-Host "Contraseña para el superusuario postgres"

# 4. Datos personalizados de la base de datos
$dbName = Solicitar-Entrada "Nombre de la base de datos" "mi_basedatos"
$dbUser = Solicitar-Entrada "Usuario de la base de datos" "mi_usuario"
$dbPassword = Read-Host "Contraseña del usuario de base de datos"

# 5. Ejecutar instalación
Write-Host "`n▶ Instalando PostgreSQL, espera un momento..." -ForegroundColor Yellow

Start-Process -FilePath $rutaInstalador -ArgumentList "--mode unattended --unattendedmodeui minimal --prefix `"$rutaInstalacion`" --superpassword $superPassword --servicename postgresql --serviceaccount postgres --servicepassword $superPassword --enable-components server,psql --datadir `"$rutaInstalacion\data`" --install_runtimes 0" -Wait

# 6. Agregar al PATH
$pgBin = Join-Path $rutaInstalacion "bin"
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$pgBin", [System.EnvironmentVariableTarget]::Machine)

# 7. Generar DATABASE_URL
$databaseUrl = "postgresql://$dbUser:$dbPassword@localhost/$dbName"

# 8. Crear JSON en escritorio
$info = [ordered]@{
    instalador       = $nombreInstalador
    ruta_instalacion = $rutaInstalacion
    fecha_instalacion = (Get-Date).ToString("s")
    usuario_windows  = $env:USERNAME
    nombre_maquina   = $env:COMPUTERNAME
    superuser_postgres = "postgres"
    base_de_datos    = $dbName
    usuario_db       = $dbUser
    database_url     = $databaseUrl
}

$escritorio = [Environment]::GetFolderPath("Desktop")
$jsonPath = Join-Path $escritorio "instalacion_postgresql.json"
$info | ConvertTo-Json -Depth 3 | Out-File -FilePath $jsonPath -Encoding UTF8

Write-Host "`n✅ Instalación completada. Archivo generado en:`n$jsonPath" -ForegroundColor Green
