using namespace System

class CsvRepository {
    [string] $Path
    $Expressions

    CsvRepository([string] $path) {
        $this.Path = $path
        if (-not (Test-Path $path)) {
            throw [System.IO.FileNotFoundException] "CSV not found at '$path'"
        }
    }

    [void] Load($logger) {
        $logger.Info("Loading CSV: $($this.Path)")
        $rows = Import-Csv -Path $this.Path
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($row in $rows) {
            $expr = $row.Expression
            if ([string]::IsNullOrWhiteSpace($expr)) {
                $logger.Warn("Skipping empty expression row")
                continue
            }
            try {
                $obj = [IpExpressionFactory]::Create($expr)
                $list.Add($obj)
                $logger.Debug("Parsed expression: '$expr' -> $($obj.GetType().Name)")
            } catch {
                $logger.Warn("Invalid expression '$expr': $($_.Exception.Message)")
            }
        }
        $this.Expressions = $list.ToArray()
        $logger.Info("Loaded $($this.Expressions.Count) expressions.")
    }

    static [object[]] LoadMultiple([string[]] $paths, $logger) {
        $all = New-Object System.Collections.Generic.List[object]
        foreach ($path in $paths) {
            if (-not (Test-Path $path)) {
                $logger.Warn("CSV not found at '$path' - skipping")
                continue
            }
            $repo = [CsvRepository]::new($path)
            $repo.Load($logger)
            foreach ($expr in $repo.Expressions) {
                $all.Add($expr)
            }
        }
        $logger.Info("Merged $($all.Count) expressions from $($paths.Count) files.")
        return $all.ToArray()
    }
}