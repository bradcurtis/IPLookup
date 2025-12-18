# ExportSource.ps1
# Abstract and concrete implementations for fetching IP range exports from either local or SharePoint.

# Abstract base class
class ExportSource {
    [string] $Type
    [string] $Path
    
    ExportSource([string]$type, [string]$path) {
        $this.Type = $type
        $this.Path = $path
    }
    
    [object[]] GetExportFiles() {
        throw "GetExportFiles must be implemented by derived class"
    }
    
    [void] DownloadExports([string]$destFolder) {
        throw "DownloadExports must be implemented by derived class"
    }
}

# Local file system implementation
class LocalExportSource : ExportSource {
    LocalExportSource([string]$path) : base("Local", $path) {}
    
    [object[]] GetExportFiles() {
        if (-not (Test-Path $this.Path)) {
            Write-Warning "Local export path does not exist: $($this.Path)"
            return @()
        }
        return Get-ChildItem -Path $this.Path -Filter "*-IPRangeExport.csv" -File
    }
    
    [void] DownloadExports([string]$destFolder) {
        # No-op for local source; files are already local
        Write-Host "LocalExportSource: files already at $($this.Path), no download needed"
    }
}

# SharePoint document library implementation
class SharePointExportSource : ExportSource {
    [string] $LibraryName
    [string] $SiteUrl
    [string] $LibrarySubFolder
    [string] $Tenant
    [object] $Connection
    
    SharePointExportSource([string]$siteUrl, [string]$libraryName, [string]$librarySubFolder = "", [string]$tenant = "") : base("SharePoint", $siteUrl) {
        $this.SiteUrl = $siteUrl
        $this.LibraryName = $libraryName
        $this.LibrarySubFolder = $librarySubFolder
        $this.Tenant = $tenant
        $this.Connection = $null
    }
    
    [void] Connect() {
        try {
            # Ensure PnP.PowerShell module is available
            if (-not (Get-Module PnP.PowerShell -ErrorAction SilentlyContinue)) {
                Write-Host "Installing PnP.PowerShell module..."
                Install-Module PnP.PowerShell -Force -Scope CurrentUser
            }
            
            $tenantSuffix = $(if ($this.Tenant -and $this.Tenant.Trim() -ne "") { " (Tenant: $($this.Tenant))" } else { "" })
            Write-Host "Connecting to SharePoint: $($this.SiteUrl)$tenantSuffix"
            # Interactive authentication (user will be prompted)
            if ($this.Tenant -and $this.Tenant.Trim() -ne "") {
                $this.Connection = Connect-PnPOnline -Url $this.SiteUrl -Interactive -Tenant $this.Tenant -ReturnConnection
            } else {
                $this.Connection = Connect-PnPOnline -Url $this.SiteUrl -Interactive -ReturnConnection
            }
        } catch {
            throw "Failed to connect to SharePoint: $_"
        }
    }
    
    [object[]] GetExportFiles() {
        if (-not $this.Connection) { $this.Connect() }
        
        try {
            $items = $null
            $serverRelativeSite = (New-Object System.Uri($this.SiteUrl)).AbsolutePath.TrimEnd('/')
            $folderServerRelative = "$serverRelativeSite/$($this.LibraryName)"
            if ($this.LibrarySubFolder -and $this.LibrarySubFolder.Trim() -ne "") {
                $subPath = $this.LibrarySubFolder -replace "\\", "/"
                $subPath = $subPath.Trim('/')
                $folderServerRelative = "$folderServerRelative/$subPath"
                $items = Get-PnPListItem -List $this.LibraryName -FolderServerRelativeUrl $folderServerRelative -Connection $this.Connection
            } else {
                $items = Get-PnPListItem -List $this.LibraryName -Connection $this.Connection
            }
            if (-not $items) { return @() }
            $files = $items | Where-Object { $_.FieldValues.FileLeafRef -like "*-IPRangeExport.csv" }
            return $files
        } catch {
            Write-Warning "Failed to fetch files from SharePoint library '$($this.LibraryName)': $_"
            return @()
        }
    }
    
    [void] DownloadExports([string]$destFolder) {
        if (-not (Test-Path $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder | Out-Null
        }
        
        if (-not $this.Connection) { $this.Connect() }
        
        try {
            $files = $this.GetExportFiles()
            if ($files.Count -eq 0) {
                Write-Host "No export files found in SharePoint library '$($this.LibraryName)'"
                return
            }
            
            Write-Host "Downloading $($files.Count) file(s) from SharePoint to $destFolder"
            foreach ($file in $files) {
                $fileName = $file.FieldValues.FileLeafRef
                $destPath = Join-Path $destFolder $fileName
                
                Write-Host "  Downloading: $fileName"
                Get-PnPFile -ServerRelativeUrl $file.FieldValues.FileRef -Path $destFolder -Filename $fileName -Force -Connection $this.Connection
            }
        } catch {
            throw "Failed to download exports from SharePoint: $_"
        }
    }
}

# SharePoint REST API implementation (no SDK required)
class SharePointRestExportSource : ExportSource {
    [string] $LibraryName
    [string] $SiteUrl
    [string] $LibrarySubFolder
    [object] $Connection

    SharePointRestExportSource([string]$siteUrl, [string]$libraryName, [string]$librarySubFolder = "") : base("SharePoint-REST", $siteUrl) {
        $this.SiteUrl = $siteUrl
        $this.LibraryName = $libraryName
        $this.LibrarySubFolder = $librarySubFolder
        $this.Connection = $null
    }

    [void] Connect() {
        try {
            # Ensure PnP.PowerShell module is available
            if (-not (Get-Module PnP.PowerShell -ErrorAction SilentlyContinue)) {
                Write-Host "Installing PnP.PowerShell module..."
                Install-Module PnP.PowerShell -Force -Scope CurrentUser -AllowClobber
            }
            
            Write-Host "Connecting to SharePoint via browser..."
            # Interactive auth (opens browser)
            Connect-PnPOnline -Url $this.SiteUrl -Interactive -ReturnConnection -ErrorAction Stop | Out-Null
            Write-Host "Authentication successful"
        } catch {
            throw "Failed to authenticate: $_"
        }
    }

    [object[]] GetExportFiles() {
        $this.Connect()
        try {
            $folderPath = if ($this.LibrarySubFolder) { 
                $this.LibraryName + '/' + ($this.LibrarySubFolder -replace '\\', '/')
            } else { 
                $this.LibraryName 
            }
            
            $items = Get-PnPListItem -List $this.LibraryName -FolderServerRelativeUrl $folderPath -ErrorAction Stop
            
            $files = @()
            if ($items) {
                foreach ($item in $items) {
                    if ($item.FieldValues.FileLeafRef -like "*-IPRangeExport.csv") {
                        $files += [PSCustomObject]@{ 
                            Name = $item.FieldValues.FileLeafRef
                            ServerRelativeUrl = $item.FieldValues.FileRef
                        }
                    }
                }
            }
            return $files
        } catch {
            Write-Warning "Failed to fetch files from SharePoint library '$($this.LibraryName)': $_"
            return @()
        }
    }

    [void] DownloadExports([string]$destFolder) {
        if (-not (Test-Path $destFolder)) {
            New-Item -ItemType Directory -Path $destFolder | Out-Null
        }

        $this.Connect()
        try {
            $files = $this.GetExportFiles()
            if ($files.Count -eq 0) {
                Write-Host "No export files found in library '$($this.LibraryName)'"
                return
            }
            Write-Host "Downloading $($files.Count) file(s) from SharePoint to $destFolder"
            
            foreach ($file in $files) {
                $destPath = Join-Path $destFolder $file.Name
                Write-Host "  Downloading: $($file.Name)"
                Get-PnPFile -ServerRelativeUrl $file.ServerRelativeUrl -Path $destFolder -Filename $file.Name -Force -ErrorAction Stop
            }
        } catch {
            throw "Failed to download exports from SharePoint: $_"
        }
    }
}

# Factory function
function New-ExportSource {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config
    )
    
    $sourceType = $Config['ExportSourceType']
    
    if ($sourceType -eq "SharePoint") {
        if (-not $Config['SharePointUrl'] -or -not $Config['LibraryName']) {
            throw "SharePoint configuration requires SharePointUrl and LibraryName"
        }
        $subFolder = $Config['LibrarySubFolder']
        $suffix = if ($subFolder) { "/$subFolder" } else { "" }
        $tenant = $Config['SharePointTenant']
        $tenantSuffix = if ($tenant) { " (Tenant: $tenant)" } else { "" }
        $provider = $Config['SharePointProvider']
        if ($null -eq $provider -or $provider -eq "") { $provider = "REST" }
        if ($provider -ieq "REST") {
            Write-Host "Creating SharePoint REST export source: $($Config['SharePointUrl'])/$($Config['LibraryName'])$suffix"
            return [SharePointRestExportSource]::new($Config['SharePointUrl'], $Config['LibraryName'], $subFolder)
        } elseif ($provider -ieq "PnP") {
            Write-Host "Creating SharePoint (PnP) export source: $($Config['SharePointUrl'])/$($Config['LibraryName'])$suffix$tenantSuffix"
            return [SharePointExportSource]::new($Config['SharePointUrl'], $Config['LibraryName'], $subFolder, $tenant)
        } else {
            throw "Unknown SharePointProvider: $provider (use REST or PnP)"
        }
    } else {
        if ($null -eq $Config['ExportPath'] -or $Config['ExportPath'] -eq "") {
            $path = 'exports'
        } else {
            $path = $Config['ExportPath']
        }
        Write-Host "Creating Local export source: $path"
        return [LocalExportSource]::new($path)
    }
}
