$reportsFolder = Join-Path $PSScriptRoot 'reports'
$csvFiles = Get-ChildItem -Path $reportsFolder -Filter "*.csv" -File

# Remove lines starting with the Exact marker from each report CSV.
# This is a simple cleanup script used after generating comparison reports.
foreach ($file in $csvFiles) {
    Write-Host "Cleaning file: $($file.Name)"
    $filteredLines = Get-Content $file.FullName | Where-Object { -not ($_ -like '"Exact*') }
    Set-Content -Path $file.FullName -Value $filteredLines
}
