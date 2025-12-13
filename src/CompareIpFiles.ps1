# CompareIpFiles.ps1
# Utility functions to compare multiple IP expression CSV files
# Reports exact matches, missing entries, and partial overlaps with line numbers and file names
# Uses Logger for structured output
# Builds a CSV report of Missing, Overlap, and Exact entries

function Get-IpExpressionsFromFile {
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
    param($exprs1,$exprs2,[string]$File1,[string]$File2,[Logger]$Logger,[ref]$Report)

    $exactCount = 0; $overlapCount = 0; $missingCount = 0

    foreach ($entry in $exprs1) {
        $norm1 = Get-NormalizedRange $entry.Expression $Logger
        if ($null -eq $norm1) { continue }
        $status = "Missing"

        foreach ($other in $exprs2) {
            $norm2 = Get-NormalizedRange $other.Expression $Logger
            if ($null -eq $norm2) { continue }

            if ($norm1.Start -eq $norm2.Start -and $norm1.End -eq $norm2.End) {
                if ($entry.Expression.Raw -eq $other.Expression.Raw) {
                    $status = "Exact"; $exactCount++
                    if ($Logger.ShouldLog("Info")) {
                        $Report.Value += [PSCustomObject]@{
                            ComparisonType="Exact"; File1=$File1; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                            File2=$File2; Line2=$other.Line; Expression2=$other.Expression.Raw
                        }
                    }
                } else {
                    $status = "Overlap"; $overlapCount++
                    $Logger.Info("Equal ranges, different forms: $($entry.Expression.Raw) vs $($other.Expression.Raw)")
                    $Report.Value += [PSCustomObject]@{
                        ComparisonType="Overlap"; File1=$File1; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                        File2=$File2; Line2=$other.Line; Expression2=$other.Expression.Raw
                    }
                }
                break
            }
            elseif ($norm1.Start -le $norm2.End -and $norm2.Start -le $norm1.End) {
                $status = "Overlap"; $overlapCount++
                $Logger.Info("Partial overlap: $($entry.Expression.Raw) vs $($other.Expression.Raw)")
                $Report.Value += [PSCustomObject]@{
                    ComparisonType="Overlap"; File1=$File1; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                    File2=$File2; Line2=$other.Line; Expression2=$other.Expression.Raw
                }
                break
            }
        }

        if ($status -eq "Missing") {
            $Logger.Info("Missing in ${File2}: $($entry.Expression.Raw)")
            $missingCount++
            $Report.Value += [PSCustomObject]@{
                ComparisonType="Missing"; File1=$File1; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                File2=$File2; Line2=""; Expression2=""
            }
        }
    }

    foreach ($entry in $exprs2) {
        $norm2 = Get-NormalizedRange $entry.Expression $Logger
        if ($null -eq $norm2) { continue }
        $status = "Missing"

        foreach ($other in $exprs1) {
            $norm1 = Get-NormalizedRange $other.Expression $Logger
            if ($null -eq $norm1) { continue }

            if ($norm1.Start -eq $norm2.Start -and $norm1.End -eq $norm2.End) {
                if ($entry.Expression.Raw -eq $other.Expression.Raw) {
                    $status = "Exact"; $exactCount++
                    if ($Logger.ShouldLog("Info")) {
                        $Report.Value += [PSCustomObject]@{
                            ComparisonType="Exact"; File1=$File2; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                            File2=$File1; Line2=$other.Line; Expression2=$other.Expression.Raw
                        }
                    }
                } else {
                    $status = "Overlap"; $overlapCount++
                    $Logger.Info("Equal ranges, different forms: $($entry.Expression.Raw) vs $($other.Expression.Raw)")
                    $Report.Value += [PSCustomObject]@{
                        ComparisonType="Overlap"; File1=$File2; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                        File2=$File1; Line2=$other.Line; Expression2=$other.Expression.Raw
                    }
                }
                break
            }
            elseif ($norm1.Start -le $norm2.End -and $norm2.Start -le $norm1.End) {
                $status = "Overlap"; $overlapCount++
                $Logger.Info("Partial overlap: $($entry.Expression.Raw) vs $($other.Expression.Raw)")
                $Report.Value += [PSCustomObject]@{
                    ComparisonType="Overlap"; File1=$File2; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                    File2=$File1; Line2=$other.Line; Expression2=$other.Expression.Raw
                }
                break
            }
        }

        if ($status -eq "Missing") {
            $Logger.Info("Missing in ${File1}: $($entry.Expression.Raw)")
            $missingCount++
            $Report.Value += [PSCustomObject]@{
                ComparisonType="Missing"; File1=$File2; Line1=$entry.Line; Expression1=$entry.Expression.Raw;
                File2=$File1; Line2=""; Expression2=""
            }
        }
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
