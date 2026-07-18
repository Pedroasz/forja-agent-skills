[CmdletBinding()]
param(
    [ValidateSet('Manifests', 'Routing')]
    [string]$Suite = 'Manifests'
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)

    $script:failures.Add($Message)
    Write-Output "FAIL: $Message"
}

function Assert-JsonManifest {
    param(
        [string]$Path,
        [string]$MissingMessage,
        [string]$InvalidMessage
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Failure $MissingMessage
        return
    }

    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop | Out-Null
        Write-Output "PASS: $(Split-Path -Leaf $Path) parses as JSON"
    }
    catch {
        Add-Failure $InvalidMessage
    }
}

function Assert-InvalidFixture {
    param(
        [string]$Path,
        [scriptblock]$Validator,
        [string]$ExpectedReason
    )

    $fixture = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    try {
        & $Validator $fixture
        Add-Failure "$(Split-Path -Leaf $Path) was accepted"
    }
    catch {
        if ($_.Exception.Message -eq $ExpectedReason) {
            Write-Output "PASS: $(Split-Path -Leaf $Path) rejected: $ExpectedReason"
        }
        else {
            Add-Failure "$(Split-Path -Leaf $Path) rejected for an unexpected reason: $($_.Exception.Message)"
        }
    }
}

function Read-JsonFixture {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Add-Failure "routing fixture is missing: $(Split-Path -Leaf $Path)"
        return $null
    }

    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Add-Failure "routing fixture is not valid JSON: $(Split-Path -Leaf $Path)"
        return $null
    }
}

function Assert-RoutingSuite {
    $cases = Read-JsonFixture -Path (Join-Path $PSScriptRoot 'trigger-cases.json')
    $routes = Read-JsonFixture -Path (Join-Path $PSScriptRoot 'expected-routes.json')
    if ($null -eq $cases -or $null -eq $routes) {
        return
    }

    $expected = @{
        'readme-update' = @{ risk = 'LOW'; selected = @('forja-documentation'); stop = $false }
        'frontend-change' = @{ risk = 'MODERATE'; selected = @('forja-safe-frontend-change', 'forja-test-strategy'); stop = $false }
        'rls-migration' = @{ risk = 'HIGH'; selected = @('forja-supabase-migration', 'forja-auth-storage-safety', 'forja-test-strategy'); stop = $false }
        'destructive-production' = @{ risk = 'CRITICAL'; selected = @('forja-incident-response'); stop = $true }
        'other-project' = @{ risk = 'NONE'; selected = @(); stop = $false }
    }

    $caseIds = @($cases | ForEach-Object { $_.id })
    $routeIds = @($routes | ForEach-Object { $_.id })
    foreach ($id in $expected.Keys) {
        if ($caseIds -notcontains $id) { Add-Failure "routing case is missing: $id" }
        if ($routeIds -notcontains $id) { Add-Failure "expected route is missing: $id" }
    }

    foreach ($route in $routes) {
        if (-not $expected.ContainsKey($route.id)) {
            Add-Failure "unexpected expected route: $($route.id)"
            continue
        }

        $rule = $expected[$route.id]
        if ($route.riskLevel -ne $rule.risk) { Add-Failure "$($route.id) has incorrect risk level" }
        if ([bool]$route.stop -ne $rule.stop) { Add-Failure "$($route.id) has incorrect stop condition" }
        if ((@($route.selectedSkills) -join '|') -ne ($rule.selected -join '|')) { Add-Failure "$($route.id) has incorrect selected skills" }
        if ($null -eq $route.requiredApprovals -or $null -eq $route.prohibitedActions) { Add-Failure "$($route.id) is missing approval or prohibition data" }
    }

    $skillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-task-router/SKILL.md'
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) {
        Add-Failure 'task router skill is missing'
        return
    }

    $skill = Get-Content -LiteralPath $skillPath -Raw
    if ($skill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-task-router\s*\r?\ndescription:\s*Use when classifying FORJA tasks') {
        Add-Failure 'task router front matter is invalid or lacks the FORJA classification trigger'
    }

    $fields = @(
        'Task summary',
        'Risk level',
        'Selected skills',
        'Skills deliberately not selected',
        'Required approvals',
        'Prohibited actions',
        'Validation plan',
        'Stop conditions'
    )
    foreach ($field in $fields) {
        if ($skill -notmatch "(?m)^- $([regex]::Escape($field)):") {
            Add-Failure "task router output field is missing: $field"
        }
    }

    $referencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-task-router/references/routing-contract.md'
    if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) {
        Add-Failure 'task router routing contract is missing'
        return
    }

    $reference = Get-Content -LiteralPath $referencePath -Raw
    foreach ($risk in @('LOW', 'MODERATE', 'HIGH', 'CRITICAL')) {
        if ($reference -notmatch "(?m)^.*\b$risk\b") { Add-Failure "routing contract is missing risk level: $risk" }
    }
    if ($reference -notmatch '(?i)highest risk prevails') {
        Add-Failure 'routing contract does not state that the highest risk prevails'
    }

    if ($failures.Count -eq 0) { Write-Output 'PASS: routing suite' }
}

if ($Suite -eq 'Manifests') {
    Assert-JsonManifest `
        -Path (Join-Path $repoRoot 'plugins/forja-development-pack/.codex-plugin/plugin.json') `
        -MissingMessage 'plugin manifest is missing' `
        -InvalidMessage 'plugin manifest is not valid JSON'

    Assert-JsonManifest `
        -Path (Join-Path $repoRoot '.agents/plugins/marketplace.json') `
        -MissingMessage 'marketplace is missing' `
        -InvalidMessage 'marketplace is not valid JSON'

    Assert-InvalidFixture `
        -Path (Join-Path $PSScriptRoot 'fixtures/invalid-plugin.json') `
        -ExpectedReason 'plugin name must use lowercase kebab-case' `
        -Validator {
            param($manifest)
            if ($manifest.name -notmatch '^[a-z0-9]+(?:-[a-z0-9]+)*$') {
                throw 'plugin name must use lowercase kebab-case'
            }
        }

    Assert-InvalidFixture `
        -Path (Join-Path $PSScriptRoot 'fixtures/invalid-marketplace.json') `
        -ExpectedReason 'marketplace must declare at least one plugin' `
        -Validator {
            param($marketplace)
            if ($marketplace.plugins.Count -lt 1) {
                throw 'marketplace must declare at least one plugin'
            }
        }

    if ($failures.Count -eq 0) { Write-Output 'PASS: manifest suite' }
}
else {
    Assert-RoutingSuite
}

if ($failures.Count -gt 0) {
    exit 1
}
