[CmdletBinding()]
param(
    [ValidateSet('Manifests', 'Routing', 'SkillTriggers')]
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

function Get-RoutingOutcome {
    param(
        [string]$Project,
        [string]$Prompt
    )

    $text = $Prompt.ToLowerInvariant()
    if ($Project -ne 'FORJA') {
        return [PSCustomObject]@{
            riskLevel = 'NONE'; selectedSkills = @(); requiredApprovals = @(); prohibitedActions = @(); stop = $false
        }
    }
    if ($text -match '\bproduction\b' -and $text -match '\b(delete|destructive)\b') {
        return [PSCustomObject]@{
            riskLevel = 'CRITICAL'; selectedSkills = @('forja-incident-response'); requiredApprovals = @('Require explicit incident authority before any production action.'); prohibitedActions = @('Do not delete production data or execute destructive production commands.'); stop = $true
        }
    }
    if ($text -match '\b(rls|migration|policy|schema|authentication|storage|workspace)\b') {
        return [PSCustomObject]@{
            riskLevel = 'HIGH'; selectedSkills = @('forja-supabase-migration', 'forja-auth-storage-safety', 'forja-test-strategy'); requiredApprovals = @('Obtain approval before migration execution or SaaS merge.'); prohibitedActions = @('Do not edit applied migrations or execute remote database commands.'); stop = $false
        }
    }
    if ($text -match '\b(dashboard|button|navigation|frontend|ui|form|accessibility|performance)\b') {
        return [PSCustomObject]@{
            riskLevel = 'MODERATE'; selectedSkills = @('forja-safe-frontend-change', 'forja-test-strategy'); requiredApprovals = @('Obtain approval before any FORJA SaaS merge.'); prohibitedActions = @('Do not alter unrelated SaaS behavior.'); stop = $false
        }
    }
    if ($text -match '\b(readme|adr|documentation|evidence)\b') {
        return [PSCustomObject]@{
            riskLevel = 'LOW'; selectedSkills = @('forja-documentation'); requiredApprovals = @(); prohibitedActions = @('Do not claim validation that was not performed.'); stop = $false
        }
    }

    return [PSCustomObject]@{
        riskLevel = 'UNCLASSIFIED'; selectedSkills = @(); requiredApprovals = @(); prohibitedActions = @(); stop = $true
    }
}

function Assert-RoutingSuite {
    $cases = Read-JsonFixture -Path (Join-Path $PSScriptRoot 'trigger-cases.json')
    $routes = Read-JsonFixture -Path (Join-Path $PSScriptRoot 'expected-routes.json')
    if ($null -eq $cases -or $null -eq $routes) {
        return
    }

    $caseIds = @($cases | ForEach-Object { $_.id })
    $routeIds = @($routes | ForEach-Object { $_.id })
    $knownIds = @('readme-update', 'frontend-change', 'rls-migration', 'destructive-production', 'other-project')
    if ($caseIds.Count -ne 5 -or (@($caseIds | Select-Object -Unique).Count -ne 5)) { Add-Failure 'routing cases must contain exactly five unique cases' }
    if ($routeIds.Count -ne 5 -or (@($routeIds | Select-Object -Unique).Count -ne 5)) { Add-Failure 'expected routes must contain exactly five unique routes' }
    foreach ($id in $knownIds) {
        if ($caseIds -notcontains $id) { Add-Failure "routing case is missing: $id" }
        if ($routeIds -notcontains $id) { Add-Failure "expected route is missing: $id" }
    }
    foreach ($id in @($caseIds + $routeIds | Select-Object -Unique)) {
        if ($knownIds -notcontains $id) { Add-Failure "routing fixture has an unknown case: $id" }
    }

    foreach ($case in $cases) {
        if ([string]::IsNullOrWhiteSpace($case.project) -or [string]::IsNullOrWhiteSpace($case.prompt)) {
            Add-Failure "$($case.id) has incomplete routing input"
            continue
        }
        $route = @($routes | Where-Object { $_.id -eq $case.id })
        if ($route.Count -ne 1) { Add-Failure "$($case.id) must map to exactly one expected route"; continue }

        $derived = Get-RoutingOutcome -Project $case.project -Prompt $case.prompt
        if ($derived.riskLevel -eq 'UNCLASSIFIED') { Add-Failure "$($case.id) does not contain a contract routing signal"; continue }
        if ($route[0].riskLevel -ne $derived.riskLevel) { Add-Failure "$($case.id) risk does not match prompt signals" }
        if ((@($route[0].selectedSkills) -join '|') -ne ($derived.selectedSkills -join '|')) { Add-Failure "$($case.id) selected skills do not match prompt signals" }
        if ((@($route[0].requiredApprovals) -join '|') -ne ($derived.requiredApprovals -join '|')) { Add-Failure "$($case.id) approvals do not match prompt risk" }
        if ((@($route[0].prohibitedActions) -join '|') -ne ($derived.prohibitedActions -join '|')) { Add-Failure "$($case.id) prohibited actions do not match prompt risk" }
        if ([bool]$route[0].stop -ne $derived.stop) { Add-Failure "$($case.id) stop condition does not match prompt risk" }
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

    $sectionHeadings = @(
        'Purpose', 'Trigger conditions', 'Do not trigger when', 'Required inputs', 'Expected outputs', 'Risk classification',
        'Workflow', 'Required checks', 'Stop conditions', 'Failure recovery', 'Handoff or next skills', 'Completion evidence'
    )
    $actualHeadings = @($skill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) })
    if (($actualHeadings -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'task router must contain exactly the required twelve H2 sections' }

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

function Get-SkillSelection {
    param([string]$Project, [string]$Prompt)

    $text = $Prompt.ToLowerInvariant()
    if ($Project -ne 'FORJA') {
        return @()
    }
    $isMigration = $text -match '\b(migration|schema|database|table|index)\b'
    $isBoundary = $text -match '\b(authentication|authenticated|unauthenticated|session|workspace|storage|rls|policy)\b' -or $text -match '\btenant\b.*\b(isolat|records?|access)\b|\b(isolat|records?|access)\b.*\btenant\b' -or $text -match '\b(fix|bug|issue)\b.*\blogin\b|\blogin\b.*\b(bug|issue|access|auth)\b'
    $isPackageRelease = $text -match '\b(development pack|skills package)\b' -and $text -match '\b(release|version|changelog|tag)\b'
    $isSaasRelease = $text -match '\bsaas\b' -and $text -match '\b(release|deploy|production)\b'
    $isRelease = $isPackageRelease -or $isSaasRelease
    if ($isMigration -and $isBoundary) {
        $selection = @('forja-supabase-migration', 'forja-auth-storage-safety')
        if ($isRelease) { $selection += 'forja-release-pipeline' }
        return $selection
    }
    if ($isMigration) {
        $selection = @('forja-supabase-migration')
        if ($isRelease) { $selection += 'forja-release-pipeline' }
        return $selection
    }
    if ($isBoundary) {
        $selection = @('forja-auth-storage-safety')
        if ($isRelease) { $selection += 'forja-release-pipeline' }
        return $selection
    }
    if ($isRelease) { return @('forja-release-pipeline') }
    if ($text -match '\b(documentation|readme|adr|docs-only|profile copy|profile text|copy shown)\b') {
        return @()
    }
    if ($text -match '\b(button|navigation|frontend|ui|form|html|css|javascript)\b') {
        return @('forja-safe-frontend-change')
    }
    return @()
}

function Get-ReleaseGate {
    param([string]$Project, [string]$Prompt)

    $text = $Prompt.ToLowerInvariant()
    $isPackageDocsOnly = $Project -eq 'FORJA' -and $text -match '\b(development pack|skills package)\b' -and $text -match '\b(docs-only|documentation-only|documentation|docs)\b' -and $text -match '\b(release|version|changelog|tag)\b'
    $isFunctionalSaas = $Project -eq 'FORJA' -and $text -match '\bsaas\b' -and $text -match '\b(release|deploy|production)\b' -and $text -match '\b(functional|dashboard|ui|frontend|migration|rls)\b'
    if ($isFunctionalSaas) {
        return [PSCustomObject]@{ releaseKind = 'SAAS_FUNCTIONAL'; riskLevel = 'HIGH'; autoMergeEligible = $false; requiresHumanApproval = $true }
    }
    if ($isPackageDocsOnly) {
        $hasBranchProtection = $text -match 'remote branch protection confirmed'
        $hasCandidateChecks = $text -match 'required ci checks passed for the candidate commit'
        $hasApprovedReviews = $text -match 'required reviews approved with no blockers'
        $hasValidationEvidence = $text -match 'validation evidence matches the diff'
        $hasVersionProvenance = $text -match 'version, manifest, and changelog are consistent'
        $hasTagProvenance = $text -match 'annotated tag provenance points to the approved candidate commit'
        $autoMergeEligible = $hasBranchProtection -and $hasCandidateChecks -and $hasApprovedReviews -and $hasValidationEvidence -and $hasVersionProvenance -and $hasTagProvenance
        return [PSCustomObject]@{ releaseKind = 'PACKAGE_DOCS_ONLY'; riskLevel = 'LOW'; autoMergeEligible = $autoMergeEligible; requiresHumanApproval = $false }
    }
    return $null
}

function Assert-SkillTriggerSuite {
    $cases = Read-JsonFixture -Path (Join-Path $PSScriptRoot 'skill-trigger-cases.json')
    $expected = Read-JsonFixture -Path (Join-Path $PSScriptRoot 'expected-skill-selection.json')
    if ($null -eq $cases -or $null -eq $expected) { return }

    foreach ($case in $cases) {
        $route = @($expected | Where-Object { $_.id -eq $case.id })
        if ($route.Count -ne 1) { Add-Failure "$($case.id) must map to exactly one expected skill selection"; continue }
        $actual = Get-SkillSelection -Project $case.project -Prompt $case.prompt
        if ((@($route[0].selectedSkills) -join '|') -ne ($actual -join '|')) { Add-Failure "$($case.id) skill selection does not match actual prompt text" }

        if ($null -ne $case.mutatedPrompt) {
            $mutated = Get-SkillSelection -Project $case.project -Prompt $case.mutatedPrompt
            if (($mutated -join '|') -eq ($actual -join '|')) {
                if ($null -eq $route[0].releaseKind) {
                    Add-Failure "$($case.id) mutated prompt did not change the skill-selection evidence"
                }
                else {
                    $originalGate = Get-ReleaseGate -Project $case.project -Prompt $case.prompt
                    $mutatedGate = Get-ReleaseGate -Project $case.project -Prompt $case.mutatedPrompt
                    if ($null -eq $originalGate -or $null -eq $mutatedGate -or ($originalGate.releaseKind -eq $mutatedGate.releaseKind -and $originalGate.autoMergeEligible -eq $mutatedGate.autoMergeEligible -and $originalGate.requiresHumanApproval -eq $mutatedGate.requiresHumanApproval)) {
                        Add-Failure "$($case.id) mutated prompt did not change the release-gate evidence"
                    }
                }
            }
        }
        if ($case.id -match '^hypothetical-' -and $route[0].planningOnly -ne $true) { Add-Failure "$($case.id) must remain planning-only" }

        if ($null -ne $route[0].releaseKind) {
            $gate = Get-ReleaseGate -Project $case.project -Prompt $case.prompt
            if ($null -eq $gate) { Add-Failure "$($case.id) does not contain release-gate evidence"; continue }
            foreach ($field in @('releaseKind', 'autoMergeEligible', 'requiresHumanApproval')) {
                if ($route[0].$field -ne $gate.$field) { Add-Failure "$($case.id) $field does not match actual prompt text" }
            }
            if ($null -ne $route[0].riskLevel -and $route[0].riskLevel -ne $gate.riskLevel) { Add-Failure "$($case.id) risk level does not preserve the release gate" }
        }
    }

    $skillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-safe-frontend-change/SKILL.md'
    $referencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-safe-frontend-change/references/frontend-safety-checks.md'
    if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { Add-Failure 'safe frontend change skill is missing'; return }
    if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) { Add-Failure 'frontend safety checks reference is missing'; return }

    $skill = Get-Content -LiteralPath $skillPath -Raw
    if ($skill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-safe-frontend-change\s*\r?\ndescription:\s*Use when') { Add-Failure 'safe frontend change front matter is invalid' }
    $frontMatter = [regex]::Match($skill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($frontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'safe frontend change front matter must contain only name and description' }

    $sectionHeadings = @('Purpose', 'Trigger conditions', 'Do not trigger when', 'Required inputs', 'Expected outputs', 'Risk classification', 'Workflow', 'Required checks', 'Stop conditions', 'Failure recovery', 'Handoff or next skills', 'Completion evidence')
    $actualHeadings = @($skill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) })
    if (($actualHeadings -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'safe frontend change must contain exactly the required twelve H2 sections' }

    foreach ($requirement in @('MODERATE', 'documentation', 'DOM IDs', 'event handlers', 'XSS', 'blank screen', 'desktop', 'mobile', 'navigation', 'approval before.*SaaS merge')) {
        if ($skill -notmatch "(?is)$requirement") { Add-Failure "safe frontend change requirement is missing: $requirement" }
    }
    foreach ($handoff in @('forja-ux-accessibility', 'forja-performance-audit', 'forja-test-strategy')) {
        if ($skill -notmatch "(?i)$handoff") { Add-Failure "safe frontend change handoff is missing: $handoff" }
    }

    $reference = Get-Content -LiteralPath $referencePath -Raw
    foreach ($check in @('DOM IDs', 'event handlers', 'escaping', 'XSS', 'blank screen', 'desktop', 'mobile', 'navigation')) {
        if ($reference -notmatch "(?i)$check") { Add-Failure "frontend safety reference is missing check: $check" }
    }

    $authSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-auth-storage-safety/SKILL.md'
    $authReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-auth-storage-safety/references/auth-storage-boundaries.md'
    if (-not (Test-Path -LiteralPath $authSkillPath -PathType Leaf)) { Add-Failure 'auth and storage safety skill is missing'; return }
    if (-not (Test-Path -LiteralPath $authReferencePath -PathType Leaf)) { Add-Failure 'auth and storage boundaries reference is missing'; return }

    $authSkill = Get-Content -LiteralPath $authSkillPath -Raw
    if ($authSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-auth-storage-safety\s*\r?\ndescription:\s*Use when') { Add-Failure 'auth and storage safety front matter is invalid' }
    $authFrontMatter = [regex]::Match($authSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($authFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'auth and storage safety front matter must contain only name and description' }
    if (($actualHeadings = @($authSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'auth and storage safety must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('HIGH', 'identity', 'authentication', 'session', 'storage', 'workspace', 'tenant', 'authenticated actor', 'cross-workspace', 'real data', 'explicit approval', 'planning-only')) {
        if ($authSkill -notmatch "(?is)$requirement") { Add-Failure "auth and storage safety requirement is missing: $requirement" }
    }
    foreach ($handoff in @('forja-supabase-migration', 'forja-test-strategy')) {
        if ($authSkill -notmatch "(?i)$handoff") { Add-Failure "auth and storage safety handoff is missing: $handoff" }
    }
    $authReference = Get-Content -LiteralPath $authReferencePath -Raw
    foreach ($check in @('authenticated actor', 'tenant isolation', 'cross-workspace', 'storage', 'real data', 'explicit approval')) {
        if ($authReference -notmatch "(?is)$check") { Add-Failure "auth and storage boundaries reference is missing check: $check" }
    }

    $migrationSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-supabase-migration/SKILL.md'
    $migrationReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-supabase-migration/references/migration-runbook.md'
    if (-not (Test-Path -LiteralPath $migrationSkillPath -PathType Leaf)) { Add-Failure 'supabase migration skill is missing'; return }
    if (-not (Test-Path -LiteralPath $migrationReferencePath -PathType Leaf)) { Add-Failure 'supabase migration runbook is missing'; return }

    $migrationSkill = Get-Content -LiteralPath $migrationSkillPath -Raw
    if ($migrationSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-supabase-migration\s*\r?\ndescription:\s*Use when') { Add-Failure 'supabase migration front matter is invalid' }
    $migrationFrontMatter = [regex]::Match($migrationSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($migrationFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'supabase migration front matter must contain only name and description' }
    if (($actualHeadings = @($migrationSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'supabase migration must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('HIGH', 'new incremental migration', 'applied migration', 'baseline', 'dry-run', 'db reset', 'migration list', 'RLS', 'UPDATE USING', 'WITH CHECK', 'Data API', 'GRANT', 'explicit approval', 'planning-only', 'remote')) {
        if ($migrationSkill -notmatch "(?is)$requirement") { Add-Failure "supabase migration skill requirement is missing: $requirement" }
    }
    $migrationReference = Get-Content -LiteralPath $migrationReferencePath -Raw
    foreach ($check in @('supabase migration new', 'supabase db reset', 'supabase migration list', 'supabase db push --dry-run', 'supabase test db', 'advisor', 'rollback', 'actor', 'tenant', 'index', 'GRANT')) {
        if ($migrationReference -notmatch "(?is)$([regex]::Escape($check))") { Add-Failure "supabase migration runbook is missing check: $check" }
    }

    $releaseSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-release-pipeline/SKILL.md'
    $releaseReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-release-pipeline/references/release-gates.md'
    if (-not (Test-Path -LiteralPath $releaseSkillPath -PathType Leaf)) { Add-Failure 'release pipeline skill is missing'; return }
    if (-not (Test-Path -LiteralPath $releaseReferencePath -PathType Leaf)) { Add-Failure 'release gates reference is missing'; return }

    $releaseSkill = Get-Content -LiteralPath $releaseSkillPath -Raw
    if ($releaseSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-release-pipeline\s*\r?\ndescription:\s*Use when') { Add-Failure 'release pipeline front matter is invalid' }
    $releaseFrontMatter = [regex]::Match($releaseSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($releaseFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'release pipeline front matter must contain only name and description' }
    if (($actualHeadings = @($releaseSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'release pipeline must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('FORJA Development Pack', 'skills package', 'SaaS', 'docs-only', 'functional', 'branch protection', 'checks', 'reviews', 'evidence', 'version', 'changelog', 'tag', 'explicit human approval', 'merge', 'deploy', 'rollback', 'remote confirmation')) {
        if ($releaseSkill -notmatch "(?is)$requirement") { Add-Failure "release pipeline skill requirement is missing: $requirement" }
    }
    $releaseReference = Get-Content -LiteralPath $releaseReferencePath -Raw
    foreach ($check in @('PACKAGE_DOCS_ONLY', 'SAAS_FUNCTIONAL', 'branch protection', 'CI', 'checks', 'reviews', 'evidence', 'version', 'changelog', 'annotated tag', 'remote confirmation', 'rollback', 'explicit human approval')) {
        if ($releaseReference -notmatch "(?is)$check") { Add-Failure "release gates reference is missing check: $check" }
    }

    if ($failures.Count -eq 0) { Write-Output 'PASS: skill trigger suite' }
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
elseif ($Suite -eq 'Routing') {
    Assert-RoutingSuite
}
else {
    Assert-SkillTriggerSuite
}

if ($failures.Count -gt 0) {
    exit 1
}
