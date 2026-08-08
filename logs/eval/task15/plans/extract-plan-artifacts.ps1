param(
    [string]$PlansDir = (Join-Path $PSScriptRoot '.')
)

$ErrorActionPreference = 'Stop'
$nsUri = 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'

function Get-ShowPlanXml {
    param([string]$RawPath)
    $raw = Get-Content -LiteralPath $RawPath -Raw
    $match = [regex]::Match($raw, '(?s)<ShowPlanXML.*</ShowPlanXML>')
    if (-not $match.Success) {
        throw "No ShowPlanXML block found in $RawPath"
    }
    return $match.Value
}

function Get-PlanSummary {
    param(
        [string]$XmlText,
        [string]$Phase,
        [string]$QueryId
    )
    $stmtMatches = [regex]::Matches($XmlText, '(?s)<StmtSimple[^>]*StatementType="SELECT"[^>]*StatementSubTreeCost="(?<cost>[^"]+)"[^>]*StatementEstRows="(?<rows>[^"]+)"[^>]*QueryHash="(?<qhash>[^"]+)"[^>]*QueryPlanHash="(?<phash>[^"]+)"[^>]*>.*?</StmtSimple>')
    if ($stmtMatches.Count -eq 0) {
        throw "Unable to locate SELECT statement metadata for $QueryId $Phase"
    }
    $stmtText = $stmtMatches[$stmtMatches.Count - 1].Value
    $stmtHeader = $stmtMatches[$stmtMatches.Count - 1].Groups
    $rootMatch = [regex]::Match($stmtText, '(?s)<RelOp NodeId="0" PhysicalOp="(?<physical>[^"]+)" LogicalOp="(?<logical>[^"]+)"[^>]*EstimateRows="(?<rows>[^"]+)"')
    if (-not $rootMatch.Success) {
        throw "Unable to locate root RelOp for $QueryId $Phase"
    }
    $ops = @{}
    foreach ($op in [regex]::Matches($stmtText, 'PhysicalOp="([^"]+)"')) {
        $name = $op.Groups[1].Value
        if (-not $ops.ContainsKey($name)) { $ops[$name] = 0 }
        $ops[$name]++
    }
    $opList = ($ops.GetEnumerator() | Sort-Object Name | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
    $hasKeyLookup = [bool]([regex]::IsMatch($stmtText, 'PhysicalOp="Key Lookup"'))
    $hasSort = [bool]([regex]::IsMatch($stmtText, 'PhysicalOp="Sort"'))
    $hasHash = [bool]([regex]::IsMatch($stmtText, 'PhysicalOp="Hash Match"'))
    $hasSeek = [bool]([regex]::IsMatch($stmtText, 'PhysicalOp="[^"]*Seek[^"]*"'))
    $hasScan = [bool]([regex]::IsMatch($stmtText, 'PhysicalOp="[^"]*Scan[^"]*"'))

    [pscustomobject]@{
        QueryId          = $QueryId
        Phase            = $Phase
        QueryHash        = $stmtHeader['qhash'].Value
        PlanHash         = $stmtHeader['phash'].Value
        StatementCost    = $stmtHeader['cost'].Value
        EstimatedRows    = $rootMatch.Groups['rows'].Value
        RootPhysicalOp   = $rootMatch.Groups['physical'].Value
        RootLogicalOp    = $rootMatch.Groups['logical'].Value
        HasSeek          = $hasSeek
        HasScan          = $hasScan
        HasSort          = $hasSort
        HasHash          = $hasHash
        HasKeyLookup     = $hasKeyLookup
        Operators        = $opList
    }
}

$map = @(
    @{ QueryId = 'Q1'; Phase = 'before'; Raw = 'q1-before.raw.txt'; SqlPlan = 'q1-before.sqlplan' },
    @{ QueryId = 'Q2'; Phase = 'before'; Raw = 'q2-before.raw.txt'; SqlPlan = 'q2-before.sqlplan' },
    @{ QueryId = 'Q3'; Phase = 'before'; Raw = 'q3-before.raw.txt'; SqlPlan = 'q3-before.sqlplan' },
    @{ QueryId = 'Q5'; Phase = 'before'; Raw = 'q5-before.raw.txt'; SqlPlan = 'q5-before.sqlplan' },
    @{ QueryId = 'Q1'; Phase = 'after';  Raw = 'q1-after.raw.txt';  SqlPlan = 'q1-after.sqlplan' },
    @{ QueryId = 'Q2'; Phase = 'after';  Raw = 'q2-after.raw.txt';  SqlPlan = 'q2-after.sqlplan' },
    @{ QueryId = 'Q3'; Phase = 'after';  Raw = 'q3-after.raw.txt';  SqlPlan = 'q3-after.sqlplan' },
    @{ QueryId = 'Q5'; Phase = 'after';  Raw = 'q5-after.raw.txt';  SqlPlan = 'q5-after.sqlplan' }
)

$summaries = New-Object System.Collections.Generic.List[object]
foreach ($item in $map) {
    $rawPath = Join-Path $PlansDir $item.Raw
    $sqlPlanPath = Join-Path $PlansDir $item.SqlPlan
    if (-not (Test-Path $rawPath)) {
        throw "Missing raw file: $rawPath"
    }
    $xmlText = Get-ShowPlanXml -RawPath $rawPath
    [System.IO.File]::WriteAllText($sqlPlanPath, $xmlText, [System.Text.UTF8Encoding]::new($false))
    $summaries.Add((Get-PlanSummary -XmlText $xmlText -Phase $item.Phase -QueryId $item.QueryId))
}

$summaryPath = Join-Path $PlansDir 'plan-summary.md'
$lines = @()
$lines += '# Task 15 Plan Summary'
$lines += ''
$lines += '| Query | Phase | Plan hash | Root op | Cost | Est rows | Seek | Scan | Sort | Hash | Key lookup | Operators |'
$lines += '|---|---|---|---|---:|---:|---|---|---|---|---|---|'
foreach ($row in $summaries | Sort-Object QueryId, Phase) {
    $lines += "| $($row.QueryId) | $($row.Phase) | $($row.PlanHash) | $($row.RootPhysicalOp) / $($row.RootLogicalOp) | $([string]::Format('{0:0.000000}', [double]$row.StatementCost)) | $([string]::Format('{0:0.####}', [double]$row.EstimatedRows)) | $($row.HasSeek) | $($row.HasScan) | $($row.HasSort) | $($row.HasHash) | $($row.HasKeyLookup) | $($row.Operators) |"
}
[System.IO.File]::WriteAllLines($summaryPath, $lines, [System.Text.UTF8Encoding]::new($false))

Write-Output "Wrote 8 .sqlplan files and $summaryPath"
