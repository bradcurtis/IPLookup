# LookupService.ps1
# Provides a service layer for loading and querying IP expressions
# Uses CsvRepository functions and Logger for structured output

class LookupResult {
    [bool] $Found
    [string] $Match
    [string] $File

    LookupResult([bool]$found, [string]$match, [string]$file) {
        $this.Found = $found
        $this.Match = $match
        $this.File  = $file
    }
}

class LookupService {
    [hashtable] $Expressions
    [Logger] $Logger

    LookupService([string[]] $paths, [Logger] $Logger) {
        $this.Logger = $Logger
        $Logger.Info("Initializing LookupService with $($paths.Count) files...")
        $this.Expressions = Get-AllExpressionsFromFiles $paths $Logger
    }

    [object[]] GetExpressionsForFile([string] $path) {
        if ($this.Expressions.ContainsKey($path)) {
            return $this.Expressions[$path]
        }
        return @()
    }

    [object[]] GetAllExpressions() {
        $all = @()
        foreach ($kvp in $this.Expressions.GetEnumerator()) {
            $all += $kvp.Value
        }
        return $all
    }

    [LookupResult] Exists([string] $ip) {
        try {
            $parsed = [System.Net.IPAddress]::Parse($ip)
        } catch {
            $this.Logger.Warn("Invalid IP format: $ip")
            return [LookupResult]::new($false, "", "")
        }

        foreach ($kvp in $this.Expressions.GetEnumerator()) {
            $file = $kvp.Key
            foreach ($entry in $kvp.Value) {
                if ($entry.Expression.Contains($parsed)) {
                    return [LookupResult]::new($true, $entry.Expression.Raw, $file)
                }
            }
        }

        return [LookupResult]::new($false, "", "")
    }
}
