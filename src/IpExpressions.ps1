using namespace System
using namespace System.Net

class IpExpression {
    [string] $Raw
    IpExpression([string] $raw) { $this.Raw = $raw }

    [bool] Contains([IPAddress] $ip) { return $false }
    [bool] EqualsExpression([IpExpression] $other) { return $this.Raw -eq $other.Raw }
}

class SingleIpExpression : IpExpression {
    [IPAddress] $Ip
    SingleIpExpression([string] $raw) : base($raw) {
        [IPAddress] $tmp = $null
        if (-not [IPAddress]::TryParse($raw, [ref] $tmp)) {
            throw [System.ArgumentException] "Invalid IP: $raw"
        }
        $this.Ip = $tmp
    }
    [bool] Contains([IPAddress] $ip) { return $this.Ip.Equals($ip) }
}

class RangeIpExpression : IpExpression {
    [IPAddress] $Start
    [IPAddress] $End
    [uint32]    $StartInt
    [uint32]    $EndInt

    RangeIpExpression([string] $raw) : base($raw) {
        $parts = $raw -split '-', 2
        if ($parts.Count -ne 2) { throw [System.ArgumentException] "Invalid range: $raw" }

        [IPAddress] $s = $null; [IPAddress] $e = $null
        if (-not [IPAddress]::TryParse($parts[0].Trim(), [ref] $s)) { throw [System.ArgumentException] "Invalid start IP: $($parts[0])" }
        if (-not [IPAddress]::TryParse($parts[1].Trim(), [ref] $e)) { throw [System.ArgumentException] "Invalid end IP: $($parts[1])" }
        if ($s.AddressFamily -ne $e.AddressFamily) { throw [System.ArgumentException] "Start/End IP family mismatch." }
        if ($s.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { throw [System.NotSupportedException] "IPv6 not supported in this sample." }

        $this.Start    = $s
        $this.End      = $e
        $this.StartInt = [IpNetwork]::ToUInt32($s)
        $this.EndInt   = [IpNetwork]::ToUInt32($e)
        if ($this.EndInt -lt $this.StartInt) { throw [System.ArgumentException] "End IP is less than Start IP: $raw" }
    }

    [bool] Contains([IPAddress] $ip) {
        if ($ip.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $false }
        $value = [IpNetwork]::ToUInt32($ip)
        return ($value -ge $this.StartInt -and $value -le $this.EndInt)
    }

    [bool] Overlaps([RangeIpExpression] $other) {
        return ($this.StartInt -le $other.EndInt -and $other.StartInt -le $this.EndInt)
    }
}

class CidrIpExpression : IpExpression {
    [IpNetwork] $Network

    CidrIpExpression([string] $raw) : base($raw) {
        $netObj = $null
        if (-not [IpNetwork]::TryParse($raw.Trim(), [ref] $netObj)) {
            throw [System.ArgumentException] "Invalid CIDR: $raw"
        }
        $this.Network = [IpNetwork]$netObj
    }

    [bool] Contains([IPAddress] $ip) { return $this.Network.Contains($ip) }
}

function New-IpExpression {
    param([string]$Raw,[Logger]$Logger)

    # Normalize input
    $Raw = $Raw.Trim()
    $Raw = $Raw.TrimStart([char]0xFEFF)     # strip BOM if present
    $Raw = $Raw -replace '–','-'            # replace en-dash with hyphen
    $Raw = $Raw -replace '\u00A0',' '       # replace non-breaking space
    $Raw = $Raw -replace '\r',''            # strip carriage returns
    $Raw = $Raw -replace '\s+',' '          # collapse whitespace

    $Logger.Info("Attempting to parse expression: '$Raw'")

    try {
        $Logger.Info("Trying CIDR parse: '$Raw'")
        $expr = [CidrIpExpression]::new($Raw)
        $Logger.Info("Parsed CIDR $Raw → $($expr.Network.NetworkAddress)-$($expr.Network.BroadcastAddress)")
        return $expr
    } catch {
       # $Logger.Warn("CIDR parse failed for '$Raw': $_")
    }

    try {
        $Logger.Info("Trying range parse: '$Raw'")
        $expr = [RangeIpExpression]::new($Raw)
        $Logger.Info("Parsed range $Raw → $($expr.Start)-$($expr.End)")
        return $expr
    } catch {
      #  $Logger.Warn("Range parse failed for '$Raw': $_")
    }

    try {
        $Logger.Info("Trying single IP parse: '$Raw'")
        $expr = [SingleIpExpression]::new($Raw)
        $Logger.Info("Parsed single IP $Raw → $($expr.Ip)")
        return $expr
    } catch {
        $Logger.Warn("Single IP parse failed for '$Raw': $_")
    }

    $Logger.Warn("Unsupported expression: '$Raw'")
    throw [System.ArgumentException] "Unsupported expression: $Raw"
}

function Get-NormalizedRange {
    param([IpExpression]$expr, [Logger]$Logger)

    if ($null -eq $expr) { return $null }
    switch ($expr.GetType().Name) {
        'SingleIpExpression' {
            if ($null -eq $expr.Ip) { return $null }
            try {
                $val = [IpNetwork]::ToUInt32([System.Net.IPAddress]$expr.Ip)
                $Logger.Info("Normalizing single IP $($expr.Raw) → $val")
                return @{Start=$val;End=$val}
            } catch {
                $Logger.Warn("Normalization failed for single IP $($expr.Raw): $_")
                return $null
            }
        }
        'RangeIpExpression' {
            if ($null -eq $expr.StartInt -or $null -eq $expr.EndInt) { return $null }
            $Logger.Info("Normalizing range $($expr.Raw) → Start=$($expr.StartInt), End=$($expr.EndInt)")
            return @{Start=$expr.StartInt;End=$expr.EndInt}
        }
       'CidrIpExpression' {
    try {
        $netAddr   = [System.Net.IPAddress]$expr.Network.NetworkAddress
        $bcastAddr = [System.Net.IPAddress]$expr.Network.BroadcastAddress

        $start = [IpNetwork]::ToUInt32($netAddr)
        $end   = [IpNetwork]::ToUInt32($bcastAddr)

        $Logger.Info("Normalizing CIDR $($expr.Raw) → Start=$start, End=$end")
        return @{Start=$start;End=$end}
    } catch {
        $Logger.Warn("Normalization failed for CIDR $($expr.Raw): $_")
        return $null
    }
}
        default {
            $Logger.Warn("Unknown expression type: $($expr.GetType().Name)")
            return $null
        }
    }
}