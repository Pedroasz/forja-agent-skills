Set-StrictMode -Version Latest

$script:ForjaOrigin = 'https://github.com/Pedroasz/forja-agent-skills.git'
$script:ForjaPluginName = 'forja-development-pack'

function Invoke-ForjaGit {
    param([string]$RepositoryRoot, [string[]]$Arguments)
    $output = & git -C $RepositoryRoot @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') failed: $($output -join [Environment]::NewLine)" }
    return @($output)
}

function Invoke-ForjaGitClone {
    param([Parameter(Mandatory = $true)][string]$CloneRoot, [Parameter(Mandatory = $true)][string]$RepositoryRoot)
    New-Item -ItemType Directory -Path $CloneRoot -Force | Out-Null
    $output = & git clone $script:ForjaOrigin $RepositoryRoot 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git clone failed: $($output -join [Environment]::NewLine)" }
}

function Invoke-ForjaGitCheckout {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot, [Parameter(Mandatory = $true)][string]$Commit)
    & cmd.exe /d /c "git -C `"$RepositoryRoot`" checkout --detach $Commit >nul 2>nul"
    if ($LASTEXITCODE -ne 0) { throw 'git checkout failed.' }
}

function Resolve-ForjaPaths {
    param([Parameter(Mandatory = $true)][string]$CloneRoot)
    $home = if ([string]::IsNullOrWhiteSpace($env:USERPROFILE)) { [Environment]::GetFolderPath('UserProfile') } else { $env:USERPROFILE }
    if ([string]::IsNullOrWhiteSpace($home)) { throw 'Unable to resolve the current user profile.' }
    $root = [System.IO.Path]::GetFullPath($CloneRoot)
    [pscustomobject][ordered]@{
        UserHome = $home
        CodexHome = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) { Join-Path $home '.codex' } else { $env:CODEX_HOME }
        CloneRoot = $root
        AgentsRoot = Join-Path $home '.agents'
        SkillsRoot = Join-Path $home '.agents\skills'
        PluginsRoot = Join-Path $home '.agents\plugins'
        PluginPath = Join-Path $home '.agents\plugins\forja-development-pack'
        MarketplacePath = Join-Path $home '.agents\plugins\marketplace.json'
        StatePath = Join-Path $home '.forja-agent-skills\state.json'
    }
}

function Assert-ForjaOrigin {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)
    $origin = (Invoke-ForjaGit -RepositoryRoot $RepositoryRoot -Arguments @('remote', 'get-url', 'origin') | Select-Object -First 1).Trim()
    if ($origin -cne $script:ForjaOrigin) { throw "Repository origin is not allowlisted: $origin" }
    return $origin
}

function Assert-ForjaCleanTree {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)
    $changes = Invoke-ForjaGit -RepositoryRoot $RepositoryRoot -Arguments @('status', '--porcelain')
    if (@($changes | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { throw 'Repository working tree is dirty.' }
}

function Get-ForjaStableVersion {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot, [Parameter(Mandatory = $true)][string]$Version)
    if ($Version -notmatch '^v[0-9]+\.[0-9]+\.[0-9]+$') { throw "Version must be a stable SemVer tag: $Version" }
    $tags = Invoke-ForjaGit -RepositoryRoot $RepositoryRoot -Arguments @('tag', '--list', $Version)
    if (@($tags | Where-Object { $_.Trim() -ceq $Version }).Count -ne 1) { throw "Stable tag was not found: $Version" }
    $commit = (Invoke-ForjaGit -RepositoryRoot $RepositoryRoot -Arguments @('rev-list', '-n', '1', $Version) | Select-Object -First 1).Trim()
    if ($commit -notmatch '^[0-9a-f]{40}$') { throw "Stable tag did not resolve to an exact commit: $Version" }
    [pscustomobject][ordered]@{ Version = $Version; Commit = $commit }
}

function Read-ForjaState {
    param([Parameter(Mandatory = $true)][string]$StatePath)
    if (-not (Test-Path -LiteralPath $StatePath -PathType Leaf)) { return $null }
    try { return (Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json -ErrorAction Stop) }
    catch { throw "State JSON is invalid: $StatePath" }
}

function Write-ForjaJsonAtomic {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)]$Value)
    $directory = Split-Path -Parent $Path
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $temporary = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.tmp')
    $replacementBackup = Join-Path $directory ('.' + [System.IO.Path]::GetFileName($Path) + '.' + [guid]::NewGuid().ToString('N') + '.replace-backup')
    try {
        $json = if ($Value -is [string]) { $Value } else { $Value | ConvertTo-Json -Depth 12 }
        $json | ConvertFrom-Json -ErrorAction Stop | Out-Null
        [System.IO.File]::WriteAllText($temporary, $json, (New-Object System.Text.UTF8Encoding($false)))
        if (Test-Path -LiteralPath $Path -PathType Leaf) {
            [System.IO.File]::Replace($temporary, $Path, $replacementBackup)
        }
        else {
            Move-Item -LiteralPath $temporary -Destination $Path
        }
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
        if (Test-Path -LiteralPath $replacementBackup) { Remove-Item -LiteralPath $replacementBackup -Force }
    }
}

function Test-ForjaJunction {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$ExpectedTarget)
    if (-not (Test-Path -LiteralPath $Path)) { return $false }
    $item = Get-Item -LiteralPath $Path -Force
    if (-not (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and $item.PSIsContainer)) { return $false }
    $target = @($item.Target | Select-Object -First 1)[0]
    if ([string]::IsNullOrWhiteSpace($target)) { return $false }
    return [string]::Equals([IO.Path]::GetFullPath($target), [IO.Path]::GetFullPath($ExpectedTarget), [StringComparison]::OrdinalIgnoreCase)
}

function Set-ForjaJunction {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$Target)
    $fullPath = [IO.Path]::GetFullPath($Path); $fullTarget = [IO.Path]::GetFullPath($Target)
    if (-not (Test-Path -LiteralPath $fullTarget -PathType Container)) { throw "Junction target does not exist: $fullTarget" }
    if (Test-Path -LiteralPath $fullPath) {
        if (Test-ForjaJunction -Path $fullPath -ExpectedTarget $fullTarget) { return [pscustomobject]@{ Path = $fullPath; Target = $fullTarget; Changed = $false } }
        throw "Junction collision: $fullPath"
    }
    New-Item -ItemType Directory -Path (Split-Path -Parent $fullPath) -Force | Out-Null
    & cmd.exe /d /c "mklink /J `"$fullPath`" `"$fullTarget`"" | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-ForjaJunction -Path $fullPath -ExpectedTarget $fullTarget)) { throw "Could not create verified junction: $fullPath" }
    [pscustomobject]@{ Path = $fullPath; Target = $fullTarget; Changed = $true }
}

function Update-ForjaMarketplace {
    param([Parameter(Mandatory = $true)][string]$Path, [Parameter(Mandatory = $true)][string]$PluginPath)
    $raw = if (Test-Path -LiteralPath $Path -PathType Leaf) { Get-Content -LiteralPath $Path -Raw } else { '{"name":"forja-development","interface":{"displayName":"FORJA Development Pack"},"plugins":[]}' }
    try { $marketplace = $raw | ConvertFrom-Json -ErrorAction Stop } catch { throw "Marketplace JSON is invalid: $Path" }
    if ($null -eq $marketplace.plugins) { throw "Marketplace plugins array is missing: $Path" }
    if (@($marketplace.plugins | Where-Object { $_.name -eq $script:ForjaPluginName }).Count -gt 0) { return [pscustomobject]@{ Path = $Path; PluginPath = $PluginPath; Changed = $false } }
    $pluginsKey = $raw.IndexOf('"plugins"')
    $arrayStart = if ($pluginsKey -lt 0) { -1 } else { $raw.IndexOf('[', $pluginsKey) }
    $arrayEnd = -1; $depth = 0; $inString = $false; $escaped = $false
    if ($arrayStart -ge 0) {
        for ($index = $arrayStart; $index -lt $raw.Length; $index++) {
            $character = $raw[$index]
            if ($inString) {
                if ($escaped) { $escaped = $false; continue }
                if ($character -eq '\') { $escaped = $true; continue }
                if ($character -eq '"') { $inString = $false }
                continue
            }
            if ($character -eq '"') { $inString = $true; continue }
            if ($character -eq '[') { $depth++; continue }
            if ($character -eq ']') { $depth--; if ($depth -eq 0) { $arrayEnd = $index; break } }
        }
    }
    if ($arrayStart -lt 0 -or $arrayEnd -le $arrayStart) { throw "Marketplace plugins array cannot be updated safely: $Path" }
    $entryJson = '{"name":"forja-development-pack","source":{"source":"local","path":"./plugins/forja-development-pack"},"policy":{"installation":"AVAILABLE","authentication":"ON_USE"},"category":"Developer Tools"}'
    $between = $raw.Substring($arrayStart + 1, $arrayEnd - $arrayStart - 1)
    $separator = if ([string]::IsNullOrWhiteSpace($between)) { '' } else { ',' }
    $updatedRaw = $raw.Substring(0, $arrayEnd) + $separator + $entryJson + $raw.Substring($arrayEnd)
    if (Test-Path -LiteralPath $Path -PathType Leaf) { Copy-Item -LiteralPath $Path -Destination ($Path + '.backup-' + (Get-Date -Format 'yyyyMMddHHmmss')) -ErrorAction Stop }
    Write-ForjaJsonAtomic -Path $Path -Value $updatedRaw
    [pscustomobject]@{ Path = $Path; PluginPath = $PluginPath; Changed = $true }
}

function Remove-ForjaMarketplaceEntry {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return [pscustomobject]@{ Path = $Path; Changed = $false } }
    try { $marketplace = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop } catch { throw "Marketplace JSON is invalid: $Path" }
    $remaining = @($marketplace.plugins | Where-Object { $_.name -ne $script:ForjaPluginName })
    $changed = $remaining.Count -ne @($marketplace.plugins).Count
    if ($changed) { $marketplace | Add-Member -NotePropertyName plugins -NotePropertyValue $remaining -Force; Write-ForjaJsonAtomic -Path $Path -Value $marketplace }
    [pscustomobject]@{ Path = $Path; Changed = $changed }
}

function Invoke-ForjaValidation {
    param([Parameter(Mandatory = $true)][string]$RepositoryRoot)
    $skills = @(Get-ChildItem -LiteralPath (Join-Path $RepositoryRoot 'plugins\forja-development-pack\skills') -Directory -ErrorAction Stop)
    if ($skills.Count -ne 12) { throw "Expected 12 skills, found $($skills.Count)." }
    foreach ($skill in $skills) { if (-not (Test-Path -LiteralPath (Join-Path $skill.FullName 'SKILL.md') -PathType Leaf)) { throw "Skill is missing SKILL.md: $($skill.Name)" } }
    [pscustomobject]@{ RepositoryRoot = $RepositoryRoot; SkillCount = $skills.Count; Valid = $true }
}

Export-ModuleMember -Function Resolve-ForjaPaths, Assert-ForjaOrigin, Assert-ForjaCleanTree, Get-ForjaStableVersion, Read-ForjaState, Write-ForjaJsonAtomic, Test-ForjaJunction, Set-ForjaJunction, Update-ForjaMarketplace, Remove-ForjaMarketplaceEntry, Invoke-ForjaValidation, Invoke-ForjaGitClone, Invoke-ForjaGitCheckout
