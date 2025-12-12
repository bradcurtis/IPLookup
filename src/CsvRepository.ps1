# CsvRepository.ps1
# Reads IP expression CSV files and returns parsed objects
# Uses Logger for structured output

function Get-IpExpressionsFromFile {
    param(
        [string]$Path,
        [Logger]$Logger
    )

    $results = @()
    $i = 0

    foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
        $i++
        $lineNoBom = $line.TrimStart([char]0xFEFF)
        $trimmed   = $lineNoBom.Trim(" `t`r`n")
        if (-not $trimmed) { continue }

        try {
            # Use the new factory function instead of IpExpressionFactory class
            $exprObj = New-IpExpression $trimmed $Logger

            $entry = [PSCustomObject]@{
                File       = $Path
                Line       = $i
                Raw        = $exprObj.Raw
                Expression = $exprObj
            }
            $results += $entry

            # Validate normalization
            if ($null -eq (Get-NormalizedRange $exprObj)) {
                $Logger.Warn("Invalid or incomplete expression at ${Path} line ${i}: ${trimmed}")
            }
        }
        catch {
            $Logger.Warn("Invalid expression at ${Path} line ${i}: ${trimmed}")
        }
    }

    return $results
}

function Get-AllExpressionsFromFiles {
    param(
        [string[]]$Files,
        [Logger]$Logger
    )

    $fileExprs = @{}
    foreach ($f in $Files) {
        $Logger.Info("Loading expressions from $f")
        $fileExprs[$f] = Get-IpExpressionsFromFile $f $Logger
    }
    return $fileExprs
}