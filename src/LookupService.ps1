using namespace System
using namespace System.Net

class LookupService {
    [object[]] $Expressions
    $Logger

    # Existing constructor (single repository)
    LookupService([CsvRepository] $repo, $logger) {
        $this.Logger     = $logger
        $this.Expressions = $repo.Expressions
    }

    # New constructor: accept multiple CSV paths
    LookupService([string[]] $paths, $logger) {
        $this.Logger     = $logger
        $this.Expressions = [CsvRepository]::LoadMultiple($paths, $logger)
    }

    [bool] Exists([string] $input) {
        $this.Logger.Info("Checking existence for: '$input'")
        $expr = [IpExpressionFactory]::Create($input)

        switch ($expr.GetType().Name) {
            'SingleIpExpression' {
                $ip = ([SingleIpExpression] $expr).Ip
                foreach ($item in $this.Expressions) {
                    if ($item.Contains($ip)) {
                        $this.Logger.Debug("Match found in: $($item.Raw)")
                        return $true
                    }
                }
                return $false
            }

            'RangeIpExpression' {
                $start = ([RangeIpExpression] $expr).Start
                $end   = ([RangeIpExpression] $expr).End
                $startInt = [IpNetwork]::ToUInt32($start)
                $endInt   = [IpNetwork]::ToUInt32($end)

                foreach ($item in $this.Expressions) {
                    if ($item.Contains($start) -or $item.Contains($end)) {
                        $this.Logger.Debug("Overlap found with: $($item.Raw)")
                        return $true
                    }

                    if ($item -is [RangeIpExpression]) {
                        $riStart = [IpNetwork]::ToUInt32(([RangeIpExpression] $item).Start)
                        $riEnd   = [IpNetwork]::ToUInt32(([RangeIpExpression] $item).End)
                        if (($startInt -le $riEnd) -and ($endInt -ge $riStart)) {
                            $this.Logger.Debug("Range overlap with: $($item.Raw)")
                            return $true
                        }
                    }
                    elseif ($item -is [CidrIpExpression]) {
                        $midInt = [math]::Floor(($startInt + $endInt) / 2)
                        $midIp  = [IpNetwork]::FromUInt32([uint32] $midInt)
                        if ($item.Contains($start) -or $item.Contains($midIp) -or $item.Contains($end)) {
                            $this.Logger.Debug("Range intersects CIDR: $($item.Raw)")
                            return $true
                        }
                    }
                }
                return $false
            }

            'CidrIpExpression' {
                $network = ([CidrIpExpression] $expr).Network
                foreach ($item in $this.Expressions) {
                    if ($item -is [SingleIpExpression]) {
                        if ($network.Contains(([SingleIpExpression] $item).Ip)) {
                            $this.Logger.Debug("CIDR contains single IP: $($item.Raw)")
                            return $true
                        }
                    }
                    elseif ($item -is [RangeIpExpression]) {
                        $s = ([RangeIpExpression] $item).Start
                        $e = ([RangeIpExpression] $item).End
                        if ($network.Contains($s) -or $network.Contains($e)) {
                            $this.Logger.Debug("CIDR overlaps range: $($item.Raw)")
                            return $true
                        } else {
                            $sInt = [IpNetwork]::ToUInt32($s)
                            $eInt = [IpNetwork]::ToUInt32($e)
                            $mid  = [IpNetwork]::FromUInt32([uint32] ([math]::Floor(($sInt + $eInt)/2)))
                            if ($network.Contains($mid)) {
                                $this.Logger.Debug("CIDR contains range midpoint: $($item.Raw)")
                                return $true
                            }
                        }
                    }
                    elseif ($item -is [CidrIpExpression]) {
                        $repoBase = ([CidrIpExpression] $item).Network.NetworkAddress
                        if ($network.Contains($repoBase) -or ([CidrIpExpression] $item).Network.Contains($network.NetworkAddress)) {
                            $this.Logger.Debug("CIDR overlaps CIDR: $($item.Raw)")
                            return $true
                        }
                    }
                }
                return $false
            }

            default { return $false }
        }

        return $false
    }
}