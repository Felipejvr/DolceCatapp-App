# Restauracion de Firestore desde backup JSON local
# Uso: powershell -ExecutionPolicy Bypass -File restore_firebase.ps1 -BackupDir "backup_20260618_010315"
#
# Requiere: gcloud instalado y el archivo de service account en Downloads

param(
    [Parameter(Mandatory=$true)]
    [string]$BackupDir
)

$projectId       = "dolcecatapp-dev"
$serviceAccount  = "C:\Users\feliv\Downloads\dolcecatapp-dev-firebase-adminsdk-fbsvc-c20598e3d4.json"
$backupPath      = Join-Path $PSScriptRoot $BackupDir

if (-not (Test-Path $backupPath)) {
    Write-Error "No se encontro la carpeta: $backupPath"
    exit 1
}

# Activar service account y obtener token
Write-Host "Autenticando con service account..."
gcloud auth activate-service-account --key-file="$serviceAccount" --quiet 2>&1 | Out-Null
$token = gcloud auth print-access-token
if (-not $token) {
    Write-Error "No se pudo obtener el token de acceso."
    exit 1
}
Write-Host "OK - token obtenido"
Write-Host "-------------------------------------------"

$baseUrl    = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents"
$headers    = @{ Authorization = "Bearer $token" }
$totalDocs  = 0
$totalErrors = 0

foreach ($col in @("pedidos", "gastos", "compras")) {
    $file = Join-Path $backupPath "$col.json"
    if (-not (Test-Path $file)) {
        Write-Host "  $col - archivo no encontrado, saltando."
        continue
    }

    $docs = Get-Content $file -Raw -Encoding UTF8 | ConvertFrom-Json
    $count = ($docs.PSObject.Properties | Measure-Object).Count
    Write-Host "  Restaurando $col ($count documentos)..."

    $ok = 0
    $err = 0
    foreach ($prop in $docs.PSObject.Properties) {
        $docId = $prop.Name
        $fields = $prop.Value
        $body = (@{ fields = $fields } | ConvertTo-Json -Depth 20)
        $url  = "$baseUrl/$col/$docId"

        try {
            Invoke-RestMethod -Uri $url -Method Patch -Body $body -ContentType "application/json" -Headers $headers | Out-Null
            $ok++
        } catch {
            $err++
            Write-Host "    ERROR doc $docId`: $($_.Exception.Message)"
        }
    }

    $totalDocs   += $ok
    $totalErrors += $err
    Write-Host "    OK $ok  |  Errores $err"
}

Write-Host "-------------------------------------------"
Write-Host "Restauracion completada: $totalDocs documentos"
if ($totalErrors -gt 0) {
    Write-Host "ADVERTENCIA: $totalErrors documentos no se pudieron restaurar"
}
