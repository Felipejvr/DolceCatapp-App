# Backup de Firestore -> archivos JSON locales
# Uso:
#   powershell -ExecutionPolicy Bypass -File backup_firebase.ps1 -Project dev
#   powershell -ExecutionPolicy Bypass -File backup_firebase.ps1 -Project prod

param(
    [ValidateSet("dev","prod")]
    [string]$Project = "dev"
)

$projectId = if ($Project -eq "prod") { "dolcecatapp" } else { "dolcecatapp-dev" }
$baseUrl   = "https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents"

function Export-Collection {
    param([string]$CollectionName)

    $docs = [ordered]@{}
    $nextPageToken = $null

    do {
        $url = "$baseUrl/$CollectionName" + "?pageSize=300"
        if ($nextPageToken) { $url = $url + "&pageToken=$nextPageToken" }

        $resp = Invoke-RestMethod -Uri $url -Method Get
        foreach ($doc in $resp.documents) {
            $id = $doc.name.Split("/")[-1]
            $docs[$id] = $doc.fields
        }
        if ($resp.PSObject.Properties["nextPageToken"]) {
            $nextPageToken = $resp.nextPageToken
        } else {
            $nextPageToken = $null
        }
    } while ($nextPageToken)

    return $docs
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$outputDir = Join-Path $PSScriptRoot "backup_${Project}_$timestamp"
New-Item -ItemType Directory -Path $outputDir | Out-Null

Write-Host "Backup $projectId"
Write-Host "Carpeta: $outputDir"
Write-Host "-------------------------------------------"

$collections = @("pedidos", "gastos", "compras")
$totalDocs   = 0

foreach ($col in $collections) {
    Write-Host "  Exportando $col ..." -NoNewline
    try {
        $data  = Export-Collection -CollectionName $col
        $count = $data.Count
        $totalDocs += $count
        $data | ConvertTo-Json -Depth 20 | Out-File -FilePath "$outputDir\$col.json" -Encoding utf8
        Write-Host " OK ($count documentos)"
    } catch {
        Write-Host " ERROR: $($_.Exception.Message)"
    }
}

Write-Host "-------------------------------------------"
Write-Host "Total: $totalDocs documentos"
Write-Host "Listo."
