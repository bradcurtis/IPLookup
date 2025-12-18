# CompareIpFiles.ps1
# Utilities to compare multiple IP expression files and generate a
# CSV report describing Exact matches, Overlaps, and Missing entries.
# The functions here use the Logger to emit progress and informational
# messages and rely on the repository/normalization helpers.

function Get-IpExpressionsFromFile {
    <#
    Read an expression file into an array of objects similar to the
    repository helper. This local copy is used by the comparison
    utilities to avoid depending directly on CsvRepository.
    #>
    param([string]$Path,[Logger]$Logger)
    $results = @(); $i = 0

    foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
        $i++
        $lineNoBom = $line.TrimStart([char]0xFEFF)
        $trimmed   = $lineNoBom.Trim(" `t`r`n")
        if (-not $trimmed) { continue }

        try {
            $expr = New-IpExpression $trimmed $Logger
            $entry = [PSCustomObject]@{
                File       = $Path
                Line       = $i
                Raw        = $expr.Raw
                Expression = $expr
            }
            $results += $entry

            if ($null -eq (Get-NormalizedRange $expr $Logger)) {
                $Logger.Warn("Invalid or incomplete expression at ${Path} line ${i}: ${trimmed}")
            }
        } catch {
            $Logger.Warn("Invalid expression at ${Path} line ${i}: ${trimmed}")
        }
    }

    return $results
}

function Compare-TwoIpFiles {
    <#
    Compare two sets of expression objects and append comparison rows to
    the provided report reference. The function detects Exact matches
    (same normalized range and same raw form), Overlaps (range overlap or
    same range different form), and Missing entries.
    #>
    param($exprs1,$exprs2,[string]$File1,[string]$File2,[Logger]$Logger,[ref]$Report)

    # Build normalized lists (compute once to avoid repeated work)
    $list1 = @()
    foreach ($entry in $exprs1) {
        $norm = Get-NormalizedRange $entry.Expression $Logger
        if ($null -eq $norm) { continue }
        $list1 += [PSCustomObject]@{
            Start   = [uint32]$norm.Start
            End     = [uint32]$norm.End
            Entry   = $entry
            Matched = $false
        }
    }

    $list2 = @()
    foreach ($entry in $exprs2) {
        $norm = Get-NormalizedRange $entry.Expression $Logger
        if ($null -eq $norm) { continue }
        $list2 += [PSCustomObject]@{
            Start   = [uint32]$norm.Start
            End     = [uint32]$norm.End
            Entry   = $entry
            Matched = $false
        }
    }

    # Sort by start address to allow efficient sweep / two-pointer algorithm
    $list1 = $list1 | Sort-Object Start, End
    $list2 = $list2 | Sort-Object Start, End

    $i = 0; $j = 0
    $exactCount = 0; $overlapCount = 0; $missingCount = 0

    # Sweep through both lists to detect overlaps and exact matches.
    while ($i -lt $list1.Count -and $j -lt $list2.Count) {
        # Skip list2 items that have already been matched with earlier entries
        while ($j -lt $list2.Count -and $list2[$j].Matched) { $j++ }
        if ($j -ge $list2.Count) { break }

        $a = $list1[$i]
        $b = $list2[$j]

        if ($list1[$i].Matched) {
            $i++
            continue
        }

        if ($a.End -lt $b.Start) {
            # a finishes before b starts -> no overlap for a
            $Logger.Info("Missing in ${File2}: $($a.Entry.Expression.Raw)")
            $missingCount++
            $Report.Value += [PSCustomObject]@{
                ComparisonType = "Missing"; File1 = $File1; Line1 = $a.Entry.Line; Expression1 = $a.Entry.Expression.Raw;
                File2 = $File2; Line2 = ""; Expression2 = ""
            }
            $i++
            continue
        }

        if ($b.End -lt $a.Start) {
            if ($list2[$j].Matched) {
                $j++
                continue
            }
            # b finishes before a starts -> b does not overlap any 'a' at this position
            # so report it as missing in File1 (i.e. present in File2 only) and advance j.
            $Logger.Info("Missing in ${File1}: $($b.Entry.Expression.Raw)")
            $missingCount++
            $Report.Value += [PSCustomObject]@{
                ComparisonType = "Missing"; File1 = $File2; Line1 = $b.Entry.Line; Expression1 = $b.Entry.Expression.Raw;
                File2 = $File1; Line2 = ""; Expression2 = ""
            }
            $j++
            continue
        }

        # Overlap exists: examine all b entries that overlap with a
        $k = $j
        $foundAny = $false
        while ($k -lt $list2.Count -and $list2[$k].Start -le $a.End) {
            $b2 = $list2[$k]
            if ($b2.Matched) { $k++; continue }
            if ($a.Start -eq $b2.Start -and $a.End -eq $b2.End) {
                if ($a.Entry.Expression.Raw -eq $b2.Entry.Expression.Raw) {
                    $exactCount++
                    $list1[$i].Matched = $true
                    $b2.Matched = $true
                    $Report.Value += [PSCustomObject]@{
                        ComparisonType = "Exact"; File1 = $File1; Line1 = $a.Entry.Line; Expression1 = $a.Entry.Expression.Raw;
                        File2 = $File2; Line2 = $b2.Entry.Line; Expression2 = $b2.Entry.Expression.Raw
                    }
                } else {
                    $overlapCount++
                    $Logger.Info("Equal ranges, different forms: $($a.Entry.Expression.Raw) vs $($b2.Entry.Expression.Raw)")
                    $list1[$i].Matched = $true
                    $b2.Matched = $true
                    $Report.Value += [PSCustomObject]@{
                        ComparisonType = "Overlap"; File1 = $File1; Line1 = $a.Entry.Line; Expression1 = $a.Entry.Expression.Raw;
                        File2 = $File2; Line2 = $b2.Entry.Line; Expression2 = $b2.Entry.Expression.Raw
                    }
                }
                $foundAny = $true
            } else {
                # Partial overlap
                $overlapCount++
                $Logger.Info("Partial overlap: $($a.Entry.Expression.Raw) vs $($b2.Entry.Expression.Raw)")
                $list1[$i].Matched = $true
                $b2.Matched = $true
                $Report.Value += [PSCustomObject]@{
                    ComparisonType = "Overlap"; File1 = $File1; Line1 = $a.Entry.Line; Expression1 = $a.Entry.Expression.Raw;
                    File2 = $File2; Line2 = $b2.Entry.Line; Expression2 = $b2.Entry.Expression.Raw
                }
                $foundAny = $true
            }
            $k++
        }

        if (-not $foundAny) {
            # No overlapping b found for this a
            $Logger.Info("Missing in ${File2}: $($a.Entry.Expression.Raw)")
            $missingCount++
            $Report.Value += [PSCustomObject]@{
                ComparisonType = "Missing"; File1 = $File1; Line1 = $a.Entry.Line; Expression1 = $a.Entry.Expression.Raw;
                File2 = $File2; Line2 = ""; Expression2 = ""
            }
        }

        $i++
    }

    # Any remaining items in list1 are missing in file2
    while ($i -lt $list1.Count) {
        $a = $list1[$i]
        if (-not $a.Matched) {
            $Logger.Info("Missing in ${File2}: $($a.Entry.Expression.Raw)")
            $missingCount++
            $Report.Value += [PSCustomObject]@{
                ComparisonType = "Missing"; File1 = $File1; Line1 = $a.Entry.Line; Expression1 = $a.Entry.Expression.Raw;
                File2 = $File2; Line2 = ""; Expression2 = ""
            }
        }
        $i++
    }

    # Any remaining items in list2 are missing in file1
    while ($j -lt $list2.Count) {
        $b = $list2[$j]
        if (-not $b.Matched) {
            $Logger.Info("Missing in ${File1}: $($b.Entry.Expression.Raw)")
            $missingCount++
            $Report.Value += [PSCustomObject]@{
                ComparisonType = "Missing"; File1 = $File2; Line1 = $b.Entry.Line; Expression1 = $b.Entry.Expression.Raw;
                File2 = $File1; Line2 = ""; Expression2 = ""
            }
        }
        $j++
    }

    $Logger.Info("Summary for ${File1} vs ${File2}: Exact=$exactCount, Overlaps=$overlapCount, Missing=$missingCount")
}

function Compare-IpFiles {
    param([string[]]$Files,[Logger]$Logger,[string]$CsvPath="ComparisonReport.csv")

    $fileExprs = @{}
    foreach ($f in $Files) { $fileExprs[$f] = Get-IpExpressionsFromFile $f $Logger }

    $report = @()
    for ($i=0; $i -lt $Files.Count; $i++) {
        for ($j=$i+1; $j -lt $Files.Count; $j++) {
            $f1=$Files[$i]; $f2=$Files[$j]
            $Logger.Info("=== Comparing ${f1} vs ${f2} ===")
            Compare-TwoIpFiles $fileExprs[$f1] $fileExprs[$f2] $f1 $f2 $Logger ([ref]$report)
        }
    }

    if ($report.Count -gt 0) {
        $report | Export-Csv -Path $CsvPath -NoTypeInformation
        $Logger.Warn("CSV report written to ${CsvPath} with $($report.Count) entries")
    } else {
        $Logger.Warn("No differences found; no report generated for file ${CsvPath} .")
    }
}
