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
        if (-not [IPAddress]::TryParse($parts[0], [ref] $s)) { throw [System.ArgumentException] "Invalid start IP: $($parts[0])" }
        if (-not [IPAddress]::TryParse($parts[1], [ref] $e)) { throw [System.ArgumentException] "Invalid end IP: $($parts[1])" }
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
}

class CidrIpExpression : IpExpression {
    $Network  # IpNetwork instance from C#

    CidrIpExpression([string] $raw) : base($raw) {
        [object] $net = $null
        if (-not [IpNetwork]::TryParse($raw, [ref] $net)) {
            throw [System.ArgumentException] "Invalid CIDR: $raw"
        }
        $this.Network = $net
    }

    [bool] Contains([IPAddress] $ip) { return $this.Network.Contains($ip) }
}

class IpExpressionFactory {
    static [IpExpression] Create([string] $raw) {
        $raw = $raw.Trim()
        if ($raw -match '^\d{1,3}(\.\d{1,3}){3}/\d{1,2}$') {
            return [CidrIpExpression]::new($raw)
        } elseif ($raw -match '^\d{1,3}(\.\d{1,3}){3}-\d{1,3}(\.\d{1,3}){3}$') {
            return [RangeIpExpression]::new($raw)
        } elseif ($raw -match '^\d{1,3}(\.\d{1,3}){3}$') {
            return [SingleIpExpression]::new($raw)
        } else {
            throw [System.ArgumentException] "Unsupported expression: $raw"
        }
    }
}