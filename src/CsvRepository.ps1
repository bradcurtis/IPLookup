# CsvRepository.ps1
# Functions for reading IP expression CSV files and returning parsed
# objects suitable for use by the LookupService. Functions use a
# `Logger` instance to emit progress and validation warnings.

function Get-IpExpressionsFromFile {
    <#
    .SYNOPSIS
    Parse an IP expression file into objects.

    .PARAMETER Path
    Path to the input file to read.

    .PARAMETER Logger
    Logger instance used to emit Info/Warning messages.

    .RETURNS
    An array of PSCustomObjects with keys: File, Line, Raw, Expression.
    #>
    param(
        [string]$Path,
        [Logger]$Logger
    )

    $results = @()
    $i = 0

    foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
        $i++
        # Remove BOM if present, then trim whitespace and control chars
        $lineNoBom = $line.TrimStart([char]0xFEFF)
        $trimmed   = $lineNoBom.Trim(" `t`r`n")
        if (-not $trimmed) { continue }

        try {
            # Create a normalized expression object from the raw text
            $exprObj = New-IpExpression $trimmed $Logger

            $entry = [PSCustomObject]@{
                File       = $Path
                Line       = $i
                Raw        = $exprObj.Raw
                Expression = $exprObj
            }
            $results += $entry

            # If normalization fails, log a warning with file/line info
            if ($null -eq (Get-NormalizedRange $exprObj)) {
                $Logger.Warn("Invalid or incomplete expression at ${Path} line ${i}: ${trimmed}")
            }
        }
        catch {
            # Record parse errors but continue processing remaining lines
            $Logger.Warn("Invalid expression at ${Path} line ${i}: ${trimmed}")
        }
    }

    return $results
}

function Get-AllExpressionsFromFiles {
    <#
    Load expressions from multiple files.

    Returns a hashtable mapping file path -> array of expression objects.
    #>
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