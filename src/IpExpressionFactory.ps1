class IpExpressionFactory {
    static [IpExpression] Create([string] $raw) {
        $logger = [Logger]::new("Test", $false, "")
        return New-IpExpression $raw $logger
    }
}
