$reportsFolder = Join-Path $PSScriptRoot 'reports'
$csvFiles = Get-ChildItem -Path $reportsFolder -Filter "*.csv" -File

foreach ($file in $csvFiles) {
    Write-Host "Cleaning file: $($file.Name)"
    $filteredLines = Get-Content $file.FullName | Where-Object { -not ($_ -like '"Exact*') }
    Set-Content -Path $file.FullName -Value $filteredLines
}
