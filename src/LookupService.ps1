# LookupService.ps1
# Provides a service layer for loading and querying IP expressions
# Uses CsvRepository functions and Logger for structured output

class LookupService {
    [hashtable] $Expressions

    LookupService([string[]] $paths, [Logger] $Logger) {
        # Load all expressions from the given file paths
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
}