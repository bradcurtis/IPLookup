class IpExpressionFactory {
    # Simple factory wrapper around New-IpExpression useful for tests or
    # contexts where creating a Logger instance inline is convenient.
    static [IpExpression] Create([string] $raw) {
        $logger = [Logger]::new("Test", $false, "")
        return New-IpExpression $raw $logger
    }
}
