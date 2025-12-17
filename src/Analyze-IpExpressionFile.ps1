function Analyze-IpExpressionFile {
    <#
    .SYNOPSIS
    Analyze a single IP expression file for issues and produce a CSV report.

    .DESCRIPTION
    Performs several sanity checks on an expression file: overlapping
    ranges, long runs of individual IPs that could be a range, and
    small ranges/CIDRs that may be better flattened to single IPs.

    .PARAMETER Path
    Path to the input expression file to analyze.

    .PARAMETER Logger
    Logger instance for emitting info/warn messages.

    .PARAMETER OutputFolder
    Destination folder for any generated CSV reports.
    #>
    param (
        [string]$Path,
        [Logger]$Logger,
        [string]$OutputFolder = "$PSScriptRoot\reports"
    )

    if (-not (Test-Path $OutputFolder)) {
        New-Item -ItemType Directory -Path $OutputFolder | Out-Null
    }

    $entries = Get-IpExpressionsFromFile -Path $Path -Logger $Logger
    $normalized = @()
    $report = @()
    $hasIssues = $false

    foreach ($entry in $entries) {
        $range = Get-NormalizedRange $entry.Expression $Logger
        if ($range -ne $null) {
            $normalized += [PSCustomObject]@{
                Line       = $entry.Line
                Raw        = $entry.Expression.Raw
                Start      = $range.Start
                End        = $range.End
                IsCIDR     = ($entry.Expression.Raw -like "*/*")
                IsRange    = ($entry.Expression.Raw -like "*-*")
                IsSingle   = ($range.Start -eq $range.End)
            }
        }
    }

    # Detect overlaps between normalized ranges using a sort + sweep approach
    # This reduces the complexity from O(n^2) to O(n log n) for sorting + O(n+m)
    # for scanning, where m is number of overlapping pairs.
    $Logger.Info("Checking for overlapping entries...")
    if ($normalized.Count -gt 1) {
        $sorted = $normalized | Sort-Object Start, End
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $a = $sorted[$i]
            # Compare forward only while the next item's Start is within a.End
            $j = $i + 1
            while ($j -lt $sorted.Count -and $sorted[$j].Start -le $a.End) {
                $b = $sorted[$j]
                # Overlap detected
                $Logger.Warn("Overlap between line $($a.Line) and $($b.Line): $($a.Raw) <-> $($b.Raw)")
                $report += [PSCustomObject]@{
                    ComparisonType        = "Overlap"
                    FileName              = $Path
                    LineText              = $a.Raw
                    LineNumber            = $a.Line
                    OverlappingText       = $b.Raw
                    OverlappingLineNumber = $b.Line
                    RangeBlockIssue       = ""
                }
                $hasIssues = $true
                $j++
            }
        }
    }

    # Detect >11 consecutive individual IPs which may indicate a block
    # that should be represented as a range for clarity and compactness
    $Logger.Info("Checking for >11 consecutive individual IPs...")
    $singles = $normalized | Where-Object { $_.IsSingle } | Sort-Object Start
    $group = @(); $last = $null

    foreach ($ip in $singles) {
        if ($last -ne $null -and ($ip.Start -ne ($last.Start + 1))) {
            if ($group.Count -gt 11) {
                $Logger.Warn("Found $($group.Count) consecutive IPs starting at line $($group[0].Line)")
                $ipList = ($group | ForEach-Object { $_.Raw }) -join ", "
                $report += [PSCustomObject]@{
                    ComparisonType        = "SuggestRange"
                    FileName              = $Path
                    LineText              = $group[0].Raw
                    LineNumber            = $group[0].Line
                    OverlappingText       = ""
                    OverlappingLineNumber = ""
                    RangeBlockIssue       = $ipList
                }
                $hasIssues = $true
            }
            $group = @()
        }
        $group += $ip
        $last = $ip
    }
    if ($group.Count -gt 11) {
        $Logger.Warn("Found $($group.Count) consecutive IPs starting at line $($group[0].Line)")
        $ipList = ($group | ForEach-Object { $_.Raw }) -join ", "
        $report += [PSCustomObject]@{
            ComparisonType        = "SuggestRange"
            FileName              = $Path
            LineText              = $group[0].Raw
            LineNumber            = $group[0].Line
            OverlappingText       = ""
            OverlappingLineNumber = ""
            RangeBlockIssue       = $ipList
        }
        $hasIssues = $true
    }

    # Detect small ranges or CIDRs that contain fewer than 11 IPs. These
    # may be candidates for flattening into explicit IP entries.
    $Logger.Info("Checking for small ranges or CIDRs (<11 IPs)...")
    foreach ($entry in $normalized) {
        $count = [math]::Abs([uint32]$entry.End - [uint32]$entry.Start) + 1
        if ($count -lt 11 -and -not $entry.IsSingle) {
            $type = if ($entry.IsRange) { "SmallRange" } else { "SuggestFlatten" }
            $Logger.Warn("Entry on line $($entry.Line) has only $count IPs: $($entry.Raw) [$type]")
            $report += [PSCustomObject]@{
                ComparisonType        = $type
                FileName              = $Path
                LineText              = $entry.Raw
                LineNumber            = $entry.Line
                OverlappingText       = ""
                OverlappingLineNumber = ""
                RangeBlockIssue       = ""
            }
            $hasIssues = $true
        }
    }

    # Write report (if any issues were detected)
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
    $shortName = ($baseName -replace '^\d{4}-\d{2}-\d{2}-Relay-', '')
    $timestamp = Get-Date -Format "yyyyMMdd-HHmm"
    $outPath = Join-Path $OutputFolder "$timestamp-$shortName-IPExpression.csv"

    if ($report.Count -gt 0) {
        $report | Export-Csv -Path $outPath -NoTypeInformation
        $Logger.Warn("Expression analysis report written to $outPath with $($report.Count) entries")
    } else {
        $Logger.Info("No issues found in $Path; no report generated.")
    }

    if ($hasIssues) {
        Write-Host "`n❌ Sanity check FAILED: Issues were found." -ForegroundColor Red
    } else {
        Write-Host "`n✅ Sanity check PASSED: No issues found." -ForegroundColor Green
    }
}
