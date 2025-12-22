# Run-ServerWideComparisons.ps1
# Perform cross-connector comparisons for each server by aggregating
# all connector exports for that server on a given date and running the
# Compare-IpFiles sweep across the entire server set.

# Load consolidated helpers and export source factory
. (Join-Path $PSScriptRoot 'src\AllClasses.ps1')
. (Join-Path $PSScriptRoot 'src\ExportSource.ps1')

# Bootstrap logger (console only) for config loading
$bootstrapLogger = [Logger]::new('Info', $false, '')
$configPath = Join-Path $PSScriptRoot 'project.properties'
$projectConfig = [ProjectConfig]::new($configPath, $bootstrapLogger)

function Resolve-PathRelativeToRoot {
    param(
        [string]$Root,
        [string]$Path
    )
    if ([IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $Root $Path)
}

$inputFolderPath  = if ($projectConfig.ExportPath   -and $projectConfig.ExportPath.Trim()   -ne '') { $projectConfig.ExportPath }   else { 'exports' }
$outputFolderPath = if ($projectConfig.OutputFolder -and $projectConfig.OutputFolder.Trim() -ne '') { $projectConfig.OutputFolder } else { 'reports' }
$logFolderPath    = if ($projectConfig.LogFolder    -and $projectConfig.LogFolder.Trim()    -ne '') { $projectConfig.LogFolder }    else { 'logs' }

$inputFolder  = Resolve-PathRelativeToRoot -Root $PSScriptRoot -Path $inputFolderPath
$outputFolder = Resolve-PathRelativeToRoot -Root $PSScriptRoot -Path $outputFolderPath
$logFolder    = Resolve-PathRelativeToRoot -Root $PSScriptRoot -Path $logFolderPath

if (-not (Test-Path $logFolder))    { New-Item -ItemType Directory -Path $logFolder | Out-Null }
if (-not (Test-Path $outputFolder)) { New-Item -ItemType Directory -Path $outputFolder | Out-Null }
if (-not (Test-Path $inputFolder))  { New-Item -ItemType Directory -Path $inputFolder  | Out-Null }

# File-based logger for batch run
$logPath = Join-Path $logFolder "serverwide-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$logger = [Logger]::new($projectConfig.LogLevel, $true, $logPath)

# Prepare export source (SharePoint or Local) and download exports if needed
$exportSourceConfig = @{
    ExportSourceType   = $projectConfig.ExportSourceType
    ExportPath         = $inputFolder
    SharePointUrl      = $projectConfig.SharePointUrl
    LibraryName        = $projectConfig.LibraryName
    LibrarySubFolder   = $projectConfig.LibrarySubFolder
    SharePointTenant   = $projectConfig.SharePointTenant
    SharePointProvider = $projectConfig.SharePointProvider
}
$exportSource = New-ExportSource -Config $exportSourceConfig
Write-Host "Using export source: $($exportSource.Type)"
$exportSource.DownloadExports($inputFolder)

# Helper: translate normalized ranges into expression metadata
function Get-ExpressionType {
    param([object]$Expression)

    if ($null -eq $Expression) { return 'Unknown' }

    switch ($Expression.GetType().Name) {
        'SingleIpExpression' { 'Single' }
        'RangeIpExpression'  { 'Range' }
        'CidrIpExpression'   { 'CIDR' }
        Default              { 'Unknown' }
    }
}

# Helper: convert numeric IPv4 to dotted string
function ConvertTo-IPv4 {
    param([uint32]$Value)
    $bytes = [System.BitConverter]::GetBytes($Value)
    if ([System.BitConverter]::IsLittleEndian) { [Array]::Reverse($bytes) }
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

# Helper: parse server and connector name from export filename
function Get-ServerConnectorInfo {
    param([string]$FileName)

    $name = [IO.Path]::GetFileName($FileName)
    # Expect: YYYY-MM-DD-Relay-<server>-<connector>-IPRangeExport.csv (connector may contain dashes or be empty)
    # Special case: YYYY-MM-DD-Relay-<server>-IPRangeExport.csv (no connector, just base file)
    
    $server = ''
    $connector = ''
    
    # Try pattern with connector
    $patternWithConnector = '^([0-9]{4}-[0-9]{2}-[0-9]{2})-Relay-([^-]+)-(.*)-IPRangeExport\.csv$'
    if ($name -match $patternWithConnector) {
        $server = $matches[2]
        $connector = $matches[3]
    } else {
        # Try pattern without connector (base file)
        $patternBaseFile = '^([0-9]{4}-[0-9]{2}-[0-9]{2})-Relay-([^-]+)-IPRangeExport\.csv$'
        if ($name -match $patternBaseFile) {
            $server = $matches[2]
            $connector = 'IPRangeExport'
        } else {
            # fallback: try to recover from parts
            $parts = $name -split '-'
            if ($parts.Count -ge 4) {
                $server = $parts[3]  # After 'Relay-' token
                $connector = ($parts[4..($parts.Count-2)] -join '-')
                if ([string]::IsNullOrWhiteSpace($connector)) {
                    $connector = 'IPRangeExport'
                }
            }
        }
    }

    return [PSCustomObject]@{
        Server    = $server
        Connector = $connector
    }
}

function Compare-EntriesForServer {
    param(
        [object[]]$Entries,
        [int]$ConsecutiveThreshold = 11,
        [switch]$IncludeShortRuns
    )

    $sorted = $Entries | Sort-Object Start, End, Connector, Line
    $results = @()

    for ($i = 0; $i -lt $sorted.Count; $i++) {
        $a = $sorted[$i]
        $j = $i + 1
        while ($j -lt $sorted.Count -and $sorted[$j].Start -le $a.End + $ConsecutiveThreshold + 1) {
            $b = $sorted[$j]

            $overlaps = $b.Start -le $a.End
            $gap = if ($overlaps) { 0 } else { $b.Start - $a.End - 1 }
            if ($gap -gt $ConsecutiveThreshold) {
                $j++
                continue
            }

            # Skip consecutive gap detections for ranges (only report overlaps)
            if (-not $overlaps) {
                $j++
                continue
            }

            $relation = $null
            $overlapStart = $null
            $overlapEnd = $null

            if ($a.Start -eq $b.Start -and $a.End -eq $b.End) {
                if ($a.Raw -eq $b.Raw) {
                    $relation = 'ExactDuplicate'
                } else {
                    $relation = 'EqualRangeDifferentExpression'
                }
            } elseif ($a.Start -ge $b.Start -and $a.End -le $b.End) {
                $relation = 'PrimaryContainedInSecondary'
            } elseif ($b.Start -ge $a.Start -and $b.End -le $a.End) {
                $relation = 'SecondaryContainedInPrimary'
            } else {
                $relation = 'PartialOverlap'
            }

            $overlapStart = [uint32]([System.Math]::Max([uint64]$a.Start, [uint64]$b.Start))
            $overlapEnd   = [uint32]([System.Math]::Min([uint64]$a.End,   [uint64]$b.End))
            
            # Calculate IP counts for both primary and secondary
            $primaryCount = [uint64]$a.End - [uint64]$a.Start + 1
            $secondaryCount = [uint64]$b.End - [uint64]$b.Start + 1

            $results += [PSCustomObject]@{
                Relation             = $relation
                PrimaryConnector     = $a.Connector
                PrimaryFile          = $a.File
                PrimaryLine          = $a.Line
                PrimaryExpression    = $a.Raw
                PrimaryType          = $a.Type
                PrimaryIPCount       = $primaryCount
                SecondaryConnector   = $b.Connector
                SecondaryFile        = $b.File
                SecondaryLine        = $b.Line
                SecondaryExpression  = $b.Raw
                SecondaryType        = $b.Type
                SecondaryIPCount     = $secondaryCount
                Gap                  = $null
                OverlapStart         = if ($null -ne $overlapStart) { ConvertTo-IPv4 $overlapStart } else { $null }
                OverlapEnd           = if ($null -ne $overlapStart) { ConvertTo-IPv4 $overlapEnd } else { $null }
            }

            $j++
        }
    }

    # Detect runs of consecutive single IPs within each connector
    $connectorGroups = $sorted | Group-Object Connector
    foreach ($group in $connectorGroups) {
        $entriesByConnector = $group.Group | Sort-Object Start, End, Line
        $runStartIndex = 0
        for ($k = 1; $k -lt $entriesByConnector.Count; $k++) {
            $prev = $entriesByConnector[$k - 1]
            $curr = $entriesByConnector[$k]

            $isPrevSingle = $prev.Start -eq $prev.End
            $isCurrSingle = $curr.Start -eq $curr.End
            $isConsecutive = $isPrevSingle -and $isCurrSingle -and ($curr.Start -eq ($prev.End + 1))

            if (-not $isConsecutive) {
                $runLength = $k - $runStartIndex
                if ($runLength -ge $ConsecutiveThreshold) {
                    $first = $entriesByConnector[$runStartIndex]
                    $last  = $entriesByConnector[$k - 1]
                    $results += [PSCustomObject]@{
                        Relation             = "ConsecutiveSingles-RunLength$runLength"
                        PrimaryConnector     = $first.Connector
                        PrimaryFile          = $first.File
                        PrimaryLine          = $first.Line
                        PrimaryExpression    = $first.Raw
                        PrimaryType          = $first.Type
                        PrimaryIPCount       = 1
                        SecondaryConnector   = $last.Connector
                        SecondaryFile        = $last.File
                        SecondaryLine        = $last.Line
                        SecondaryExpression  = $last.Raw
                        SecondaryType        = $last.Type
                        SecondaryIPCount     = 1
                        Gap                  = 0
                        OverlapStart         = $null
                        OverlapEnd           = $null
                    }
                }
                $runStartIndex = $k
            }
        }

        $finalRunLength = $entriesByConnector.Count - $runStartIndex
        if ($finalRunLength -ge $ConsecutiveThreshold) {
            $first = $entriesByConnector[$runStartIndex]
            $last  = $entriesByConnector[$entriesByConnector.Count - 1]
            $results += [PSCustomObject]@{
                Relation             = "ConsecutiveSingles-RunLength$finalRunLength"
                PrimaryConnector     = $first.Connector
                PrimaryFile          = $first.File
                PrimaryLine          = $first.Line
                PrimaryExpression    = $first.Raw
                PrimaryType          = $first.Type
                PrimaryIPCount       = 1
                SecondaryConnector   = $last.Connector
                SecondaryFile        = $last.File
                SecondaryLine        = $last.Line
                SecondaryExpression  = $last.Raw
                SecondaryType        = $last.Type
                SecondaryIPCount     = 1
                Gap                  = 0
                OverlapStart         = $null
                OverlapEnd           = $null
            }
        }
    }

    return $results
}

# Normalize quotes in all IPRangeExport CSVs (in-place) for consistency
$allExports = Get-ChildItem -Path $inputFolder -Filter '*-IPRangeExport.csv' -File |
    Where-Object { $_.Name -notmatch 'Anonymous' }

if ($allExports.Count -eq 0) {
    Write-Warning "No IPRangeExport files found in $inputFolder"
    return
}

foreach ($file in $allExports) {
    $cleanedLines = Get-Content $file.FullName | ForEach-Object { $_.Trim('"') }
    Set-Content -Path $file.FullName -Value $cleanedLines
}

# Group files by date (YYYY-MM-DD) first
$dateGroups = $allExports | Group-Object {
    $base = $_.BaseName
    if ($base -match '^([0-9]{4}-[0-9]{2}-[0-9]{2})') { $matches[1] } else { 'Unknown' }
}

Write-Host "Found $($dateGroups.Count) date group(s)."

foreach ($dg in $dateGroups) {
    $date = $dg.Name
    Write-Host "\n=== Processing date: $date ($($dg.Count) files) ==="

    $dateFolder = Join-Path $outputFolder $date
    if (-not (Test-Path $dateFolder)) { New-Item -ItemType Directory -Path $dateFolder | Out-Null }

    foreach ($f in $dg.Group) {
        $dest = Join-Path $dateFolder $f.Name
        Copy-Item -Path $f.FullName -Destination $dest -Force
    }

    # Build metadata map for quick lookup
    $fileMetadata = @{ }
    foreach ($file in $dg.Group) {
        $fileMetadata[$file.FullName] = Get-ServerConnectorInfo -FileName $file.Name
    }

    # Group entries by server
    $serverGroups = $dg.Group | Group-Object {
        ($fileMetadata[$_.FullName]).Server
    }

    foreach ($serverGroup in $serverGroups) {
        $server = $serverGroup.Name
        Write-Host "  • Aggregating server $server (${date}) across $($serverGroup.Count) file(s)..."

        $entries = @()
        foreach ($file in $serverGroup.Group) {
            $meta = $fileMetadata[$file.FullName]
            $expressions = Get-IpExpressionsFromFile -Path $file.FullName -Logger $logger

            foreach ($expr in $expressions) {
                $range = Get-NormalizedRange $expr.Expression $logger
                if ($null -eq $range) { continue }

                $entries += [PSCustomObject]@{
                    Start     = [uint32]$range.Start
                    End       = [uint32]$range.End
                    Raw       = $expr.Expression.Raw
                    Line      = $expr.Line
                    File      = $file.FullName
                    Connector = $meta.Connector
                    Server    = $meta.Server
                    Type      = Get-ExpressionType -Expression $expr.Expression
                }
            }
        }

        if ($entries.Count -eq 0) {
            Write-Host "    ↳ No expressions found for server $server on $date." -ForegroundColor Yellow
            continue
        }

        $comparisonRows = Compare-EntriesForServer -Entries $entries -ConsecutiveThreshold 11 -IncludeShortRuns

        if ($comparisonRows.Count -gt 0) {
            $csvPath = Join-Path $dateFolder ("{0}-ServerWide-Aggregated.csv" -f $server)
            $comparisonRows | Export-Csv -Path $csvPath -NoTypeInformation
            Write-Host "    ↳ Overlap report saved to $csvPath" -ForegroundColor Green
        } else {
            Write-Host "    ↳ No overlaps or duplicates detected for server $server." -ForegroundColor Green
        }
    }
}

Write-Host "\n✅ Server-wide aggregation complete. Log saved to: $logPath"
        $comparisonRows = Compare-EntriesForServer -Entries $entries -ConsecutiveThreshold 11