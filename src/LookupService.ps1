# LookupService.ps1
# Provides a service layer for loading and querying IP expressions.
# This file defines a simple `LookupResult` type and a `LookupService`
# class that wraps expression loading and lookup operations. It relies
# on repository functions (e.g. `Get-AllExpressionsFromFiles`) and the
# `Logger` helper for structured logging.

class LookupResult {
    # Indicates whether a matching expression was found
    [bool] $Found
    # The raw expression text that matched (when Found is true)
    [string] $Match
    # The source file where the matching expression was defined
    [string] $File

    LookupResult([bool]$found, [string]$match, [string]$file) {
        $this.Found = $found
        $this.Match = $match
        $this.File  = $file
    }
}

class LookupService {
    # Hashtable mapping file path -> array of expression objects
    [hashtable] $Expressions
    # Logger instance used for informational and warning messages
    [Logger] $Logger

    # Constructor: loads expressions from the provided file paths.
    # $paths: array of file paths to load expressions from
    # $Logger: a Logger instance used to emit progress and warnings
    LookupService([string[]] $paths, [Logger] $Logger) {
        $this.Logger = $Logger
        $Logger.Info("Initializing LookupService with $($paths.Count) files...")
        # Delegates to repository function to parse and return expressions
        $this.Expressions = Get-AllExpressionsFromFiles $paths $Logger
    }

    # Returns the expressions parsed from a single source file.
    [object[]] GetExpressionsForFile([string] $path) {
        if ($this.Expressions.ContainsKey($path)) {
            return $this.Expressions[$path]
        }
        return @()
    }

    # Returns all expressions from all loaded files as a single array.
    [object[]] GetAllExpressions() {
        $all = @()
        foreach ($kvp in $this.Expressions.GetEnumerator()) {
            $all += $kvp.Value
        }
        return $all
    }

    # Checks whether the provided IP (string) exists in any loaded expression.
    # Returns a LookupResult indicating success, the matching raw expression,
    # and the file where it was found.
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
                # The expression object is expected to expose an Expression
                # property with a Contains method and Raw text property.
                if ($entry.Expression.Contains($parsed)) {
                    return [LookupResult]::new($true, $entry.Expression.Raw, $file)
                }
            }
        }

        return [LookupResult]::new($false, "", "")
    }
}
