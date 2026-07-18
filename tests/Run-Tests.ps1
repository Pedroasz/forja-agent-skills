[CmdletBinding()]
param(
    [ValidateSet('Manifests')]
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

if ($failures.Count -gt 0) {
    exit 1
}

Write-Output 'PASS: manifest suite'
