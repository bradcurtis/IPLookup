param(
    [string]$LegacyPath = "Legacy Connector flat.csv",
    [string]$ExportPrefix = "2025-12-17-Relay-fdswv30900",
    [string]$OutputFile = "LegacyMissingOn30900.csv"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir   = Split-Path -Parent $scriptDir
$exportsDir = Join-Path -Path $rootDir -ChildPath 'exports'

. (Join-Path (Join-Path $rootDir 'src') 'AllClasses.ps1')

$logger = [Logger]::new('Warn', $false, '')
$script:logger = $logger

$connectorSuffix = '-IPRangeExport'
function Get-ConnectorMetadata {
    param([string]$FilePath)

    $name = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
    if ($name -and $name.EndsWith($connectorSuffix)) {
        $name = $name.Substring(0, $name.Length - $connectorSuffix.Length)
    }

    $match = [regex]::Match($name, '^(?<date>\d{4}-\d{2}-\d{2})-Relay-[^-]+-(?<connector>.+)$')
    if ($match.Success) {
        return [PSCustomObject]@{
            Date       = $match.Groups['date'].Value
            Connector  = $match.Groups['connector'].Value
        }
    }

    return [PSCustomObject]@{ Date = 'Unknown'; Connector = 'Unknown' }
}

$legacyFullPath = Join-Path $scriptDir $LegacyPath
if (-not (Test-Path $legacyFullPath)) {
    throw "Legacy file not found: $legacyFullPath"
}

$exportFiles = Get-ChildItem -Path $exportsDir -Filter ("{0}*.csv" -f $ExportPrefix) -File |
    Where-Object { $_.Name -notmatch 'Anonymous-IPRangeExport' } |
    Sort-Object Name
if (-not $exportFiles) {
    throw "No export files found matching prefix '$ExportPrefix' in $exportsDir"
}

$exportPaths = $exportFiles.FullName
$logger.Info("Found $($exportPaths.Count) export files to compare.")

$legacyEntries = Get-IpExpressionsFromFile -Path $legacyFullPath -Logger $logger
function Get-ExpressionType {
    param([object]$Expression)

    if ($null -eq $Expression) { return 'Unknown' }

    $typeName = $Expression.GetType().Name
    switch ($typeName) {
        'SingleIpExpression' { return 'Single' }
        'RangeIpExpression'  { return 'Range' }
        'CidrIpExpression'   { return 'CIDR' }
        default              { return $typeName }
    }
}
$exportEntries = @()
foreach ($exportPath in $exportPaths) {
    $pathToLoad = $exportPath
    $firstLine = $null
    try {
        $firstLine = (Get-Content -Path $exportPath -TotalCount 1)
    } catch {
        $logger.Warn("Failed to read header from $exportPath : $_")
    }

    if ($firstLine) {
        if ($firstLine -is [Array]) { $firstLine = $firstLine[0] }
        $trimmedHeader = $firstLine.Trim().Trim('"')
        if ($trimmedHeader -eq 'Expression') {
            $tempPath = [System.IO.Path]::GetTempFileName()
            Get-Content -Path $exportPath | Select-Object -Skip 1 | Set-Content -Path $tempPath
            $pathToLoad = $tempPath
        }
    }

    $loadedEntries = Get-IpExpressionsFromFile -Path $pathToLoad -Logger $logger
    foreach ($entry in $loadedEntries) {
        $entry.File = $exportPath
    }
    $exportEntries += $loadedEntries

    if (($pathToLoad -ne $exportPath) -and (Test-Path $pathToLoad)) {
        Remove-Item -Path $pathToLoad -ErrorAction SilentlyContinue
    }
}

$normalizedExports = foreach ($entry in $exportEntries) {
    $norm = Get-NormalizedRange $entry.Expression $logger
    if ($null -ne $norm) {
        $meta = Get-ConnectorMetadata -FilePath $entry.File
        [PSCustomObject]@{
            Start      = [uint64]$norm.Start
            End        = [uint64]$norm.End
            SourceFile = $entry.File
            Raw        = $entry.Raw
            Date       = $meta.Date
            Connector  = $meta.Connector
            Line       = $entry.Line
            Type       = Get-ExpressionType -Expression $entry.Expression
        }
    }
}

$results = @()
foreach ($legacy in $legacyEntries) {
    $normLegacy = Get-NormalizedRange $legacy.Expression $logger
    if ($null -eq $normLegacy) { continue }

    $match = $normalizedExports | Where-Object {
        $_.Start -le [uint64]$normLegacy.Start -and $_.End -ge [uint64]$normLegacy.End
    } | Select-Object -First 1

    if ($match) {
        $results += [PSCustomObject]@{
            LegacyExpression = $legacy.Raw
            LegacyLine       = $legacy.Line
            LegacyFile       = $legacy.File
            LegacyType       = Get-ExpressionType -Expression $legacy.Expression
            Status           = 'Found'
            MatchExpression  = $match.Raw
            MatchLine        = $match.Line
            MatchConnector   = $match.Connector
            MatchDate        = $match.Date
            MatchFile        = $match.SourceFile
            MatchType        = $match.Type
        }
    } else {
        $results += [PSCustomObject]@{
            LegacyExpression = $legacy.Raw
            LegacyLine       = $legacy.Line
            LegacyFile       = $legacy.File
            LegacyType       = Get-ExpressionType -Expression $legacy.Expression
            Status           = 'Missing'
            MatchExpression  = ''
            MatchLine        = ''
            MatchConnector   = ''
            MatchDate        = ''
            MatchFile        = ''
            MatchType        = ''
        }
    }
}

$outputPath = Join-Path $scriptDir $OutputFile
if ($results.Count -gt 0) {
    $results | Sort-Object Status, LegacyExpression | Export-Csv -Path $outputPath -NoTypeInformation
    $missingCount = ($results | Where-Object { $_.Status -eq 'Missing' }).Count
    $foundCount   = $results.Count - $missingCount
    Write-Host "Comparison exported to $outputPath. Found=$foundCount Missing=$missingCount"
} else {
    Remove-Item -Path $outputPath -ErrorAction SilentlyContinue
    Write-Host "No legacy expressions were parsed from $LegacyPath."
}
