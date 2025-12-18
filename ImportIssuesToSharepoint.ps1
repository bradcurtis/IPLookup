$reportsRoot = "C:\Development\IPLookup\reports"

# Find report subfolders (dates). If none exist, process the reports root itself.
$reportDirs = Get-ChildItem -Path $reportsRoot -Directory -ErrorAction SilentlyContinue
if (-not $reportDirs -or $reportDirs.Count -eq 0) { $reportDirs = @(Get-Item $reportsRoot) }

foreach ($dir in $reportDirs) {
    $inputFolder = $dir.FullName
    $issuesPath = Join-Path $inputFolder 'GroupedIssues.csv'

    # Load existing issues for this folder if available
    $existingIssues = @{}
    if (Test-Path $issuesPath) {
        $existing = Import-Csv $issuesPath
        foreach ($item in $existing) {
            $existingIssues["$($item.Connector)|$($item.OverlapRange)"] = $item
        }
    }

    $newIssues = @{}

    # Process IPExpression CSV files inside this report folder
    Get-ChildItem -Path $inputFolder -Filter "*IPExpression*.csv" -File | ForEach-Object {
        $file = $_.FullName
        $base = $_.BaseName

        # Extract connector name from filename
        if ($base -match "\d{8}-\d{4}-(.+)-IPRangeExport-IPExpression") {
            $connector = $matches[1]
        } else {
            $connector = "Unknown"
        }

        # Import the CSV (comma-delimited)
        $rows = Import-Csv -Path $file

        # Group by OverlappingText
        $grouped = $rows | Group-Object OverlappingText

        foreach ($group in $grouped) {
            $overlapRange = $group.Name
            $key = "$connector|$overlapRange"

            $ips = ($group.Group | ForEach-Object { $_.LineText }) -join ", "
            $lines = ($group.Group | ForEach-Object { $_.LineNumber }) -join ", "
            $fileName = ($group.Group | Select-Object -First 1).FileName

            # Determine date for this issue from the export filename (YYYY-MM-DD)
            $dateFromFile = $null
            if ($fileName -and ($fileName -match '(\d{4}-\d{2}-\d{2})')) {
                $dateFromFile = $matches[1]
            } elseif ($dir.Name -and ($dir.Name -match '(\d{4}-\d{2}-\d{2})')) {
                $dateFromFile = $dir.Name
            } else {
                $dateFromFile = 'Unknown'
            }

            # Extract server name from the exported filename (e.g. Relay-fdswv09481-TLS -> fdswv09481)
            $servername = $null
            if ($fileName) {
                # Try pattern: -Relay-<servername>- (common export naming)
                if ($fileName -match '-Relay-([^-\\/]+)-') {
                    $servername = $matches[1]
                } elseif ($fileName -match '-(fdswv\d+)-') {
                    $servername = $matches[1]
                } else {
                    # Generic fallback: look for token that looks like letters+digits (e.g. fdswv09481 or fdswv30900)
                    $m = [regex]::Match($fileName, '([a-z]{2,}\d{3,})', 'IgnoreCase')
                    if ($m.Success) { $servername = $m.Groups[1].Value }
                }
            }
            if (-not $servername) { $servername = 'Unknown' }

            if ($existingIssues.ContainsKey($key)) {
                # Update existing issue
                $issue = $existingIssues[$key]
                $issue.LineNumbers = $lines
                $issue.FileName = $fileName
                $issue.ServerName = $servername
                $issue.Fixed = $false
                $issue.Connector = $connector
                $issue.ComparisonType = ($group.Group | Select-Object -First 1).ComparisonType
                $issue.AffectedIPs = $ips
                
                # Add Date property safely (may not exist on deserialized object)
                if ($issue | Get-Member -Name Date -ErrorAction SilentlyContinue) {
                    $issue.Date = $dateFromFile
                } else {
                    $issue | Add-Member -NotePropertyName Date -NotePropertyValue $dateFromFile -Force
                }
                
                $newIssues[$key] = $issue
            } else {
                # New issue
                $newIssues[$key] = [PSCustomObject]@{
                    ID           = [guid]::NewGuid().ToString()
                    Connector    = $connector
                    ServerName   = $servername
                    Date         = $dateFromFile
                    ComparisonType = ($group.Group | Select-Object -First 1).ComparisonType
                    OverlapRange = $overlapRange
                    AffectedIPs  = $ips
                    LineNumbers  = $lines
                    FileName     = $fileName
                    Fixed        = $false
                    Comments     = ""
                }
            }
        }
    }

    # Mark missing issues as fixed for this folder
    foreach ($key in $existingIssues.Keys) {
        if (-not $newIssues.ContainsKey($key)) {
            $issue = $existingIssues[$key]
            $issue.Fixed = $true
            $newIssues[$key] = $issue
        }
    }

    # Save updated issues for this folder
    $newIssues.Values | Export-Csv $issuesPath -NoTypeInformation
}
