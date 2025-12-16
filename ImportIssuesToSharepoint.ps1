$inputFolder = "C:\Development\IPLookup\reports"
$issuesPath = "$inputFolder\GroupedIssues.csv"

# Load existing issues if available
$existingIssues = @{}
if (Test-Path $issuesPath) {
    $existing = Import-Csv $issuesPath
    foreach ($item in $existing) {
        $existingIssues["$($item.Connector)|$($item.OverlapRange)"] = $item
    }
}

$newIssues = @{}

# Process all IPExpression CSV files in the folder
Get-ChildItem -Path $inputFolder -Filter "*IPExpression*.csv" | ForEach-Object {
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

        if ($existingIssues.ContainsKey($key)) {
            # Update existing issue
            $issue = $existingIssues[$key]
            $issue.LineNumbers = $lines
            $issue.FileName = $fileName
            $issue.Fixed = $false
            $issue.Connector = $connector
            $issue.ComparisonType = ($group.Group | Select-Object -First 1).ComparisonType
            $issue.AffectedIPs = $ips
            $newIssues[$key] = $issue
        } else {
            # New issue
            $newIssues[$key] = [PSCustomObject]@{
                ID           = [guid]::NewGuid().ToString()
                Connector    = $connector
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

# Mark missing issues as fixed
foreach ($key in $existingIssues.Keys) {
    if (-not $newIssues.ContainsKey($key)) {
        $issue = $existingIssues[$key]
        $issue.Fixed = $true
        $newIssues[$key] = $issue
    }
}

# Save updated issues
$newIssues.Values | Export-Csv $issuesPath -NoTypeInformation
