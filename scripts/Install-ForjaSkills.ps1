[CmdletBinding()]
param(
    [string]$CloneRoot = (Join-Path ([Environment]::GetFolderPath('UserProfile')) '.forja-agent-skills\clone'),
    [string]$Version,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'ForjaSkills.Common.psm1') -Force

try {
    if ($NonInteractive) { $env:GIT_TERMINAL_PROMPT = '0'; Write-Verbose 'NonInteractive: prompts are disabled and any required interaction fails.' }
    $paths = Resolve-ForjaPaths -CloneRoot $CloneRoot
    $repository = if (Test-Path -LiteralPath (Join-Path $paths.CloneRoot '.git') -PathType Container) { $paths.CloneRoot } else { Join-Path $paths.CloneRoot 'forja-agent-skills' }
    if (-not (Get-Command git -CommandType Application -ErrorAction SilentlyContinue)) { throw 'Git is required for installation.' }
    if (-not (Test-Path -LiteralPath $repository -PathType Container)) {
        Invoke-ForjaGitClone -CloneRoot $paths.CloneRoot -RepositoryRoot $repository
    }
    Assert-ForjaOrigin -RepositoryRoot $repository | Out-Null
    Assert-ForjaCleanTree -RepositoryRoot $repository
    if ([string]::IsNullOrWhiteSpace($Version)) { $Version = 'v' + (Get-Content -LiteralPath (Join-Path $repository 'VERSION') -Raw).Trim() }
    $release = Get-ForjaStableVersion -RepositoryRoot $repository -Version $Version
    Invoke-ForjaGitCheckout -RepositoryRoot $repository -Commit $release.Commit
    Invoke-ForjaValidation -RepositoryRoot $repository | Out-Null

    $skillSourceRoot = Join-Path $repository 'plugins\forja-development-pack\skills'
    $skillNames = @(Get-ChildItem -LiteralPath $skillSourceRoot -Directory | Select-Object -ExpandProperty Name)
    foreach ($name in $skillNames) { $destination = Join-Path $paths.SkillsRoot $name; if ((Test-Path -LiteralPath $destination) -and -not (Test-ForjaJunction -Path $destination -ExpectedTarget (Join-Path $skillSourceRoot $name))) { throw "Junction collision: $destination" } }
    if ((Test-Path -LiteralPath $paths.PluginPath) -and -not (Test-ForjaJunction -Path $paths.PluginPath -ExpectedTarget (Join-Path $repository 'plugins\forja-development-pack'))) { throw "Junction collision: $($paths.PluginPath)" }
    foreach ($name in $skillNames) { Set-ForjaJunction -Path (Join-Path $paths.SkillsRoot $name) -Target (Join-Path $skillSourceRoot $name) | Out-Null }
    Set-ForjaJunction -Path $paths.PluginPath -Target (Join-Path $repository 'plugins\forja-development-pack') | Out-Null
    Update-ForjaMarketplace -Path $paths.MarketplacePath -PluginPath $paths.PluginPath | Out-Null
    $previous = Read-ForjaState -StatePath $paths.StatePath
    $state = [pscustomobject][ordered]@{ origin = 'https://github.com/Pedroasz/forja-agent-skills.git'; clone = $repository; version = $release.Version; commit = $release.Commit; previousVersion = if ($null -eq $previous) { $null } else { $previous.version }; previousCommit = if ($null -eq $previous) { $null } else { $previous.commit }; installedAt = (Get-Date).ToUniversalTime().ToString('o'); skillsRoot = $paths.SkillsRoot; pluginJunction = $paths.PluginPath; skillJunctions = @($skillNames | ForEach-Object { Join-Path $paths.SkillsRoot $_ }) }
    Write-ForjaJsonAtomic -Path $paths.StatePath -Value $state
    Write-Output "Installed FORJA skills $($release.Version). Restart Codex or start a new session to discover them."
    exit 0
}
catch { Write-Error $_.Exception.ToString(); exit 1 }
