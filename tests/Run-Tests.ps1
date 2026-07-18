[CmdletBinding()]
param(
    [ValidateSet('Manifests', 'Routing', 'SkillTriggers', 'SkillPack')]
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
    $isHypotheticalIncident = $text -match '\b(hypothetically|hypothetical|hipoteticamente)\b'
    $hasIncidentSignal = $text -match '\b(incident|incidente|outage|data loss|perda de dados|production error|erro de produ[cç][aã]o)\b'
    $hasProductionSignal = $text -match '\b(production|produ[cç][aã]o|prod)\b'
    $isConfirmedIncident = -not $isHypotheticalIncident -and $hasIncidentSignal -and ($hasProductionSignal -or $text -match '\b(outage|data loss|perda de dados)\b')
    $incidentSelection = if (($isHypotheticalIncident -and $hasIncidentSignal) -or $isConfirmedIncident) { @('forja-incident-response') } else { @() }
    $isDataRecovery = $text -match '\b(data recovery|restore|rollback|recover|recovery|restaura[cç][aã]o|recupera[cç][aã]o|reverter cache)\b'
    $dataRecoverySelection = if ($isDataRecovery) { @('forja-data-recovery') } else { @() }
    if ($isDataRecovery -and -not ($text -match '\b(migration|schema|table|index|rls|policy|authentication|authenticated|unauthenticated|session|workspace|tenant|permission)\b')) {
        return @($incidentSelection + $dataRecoverySelection)
    }
    $isExplicitReviewArtifact = $text -match '\b(review|audit)\b' -and $text -match '\b(pr|pull request|diff)\b'
    $isGenericChangeReviewBeforeMerge = $text -match '\b(review|audit)\b' -and $text -match '\bbefore merge\b' -and $text -match '\b(code|documentation|change)\b'
    $isIndependentReview = $isExplicitReviewArtifact -or $isGenericChangeReviewBeforeMerge
    $isMigration = $text -match '\b(migration|schema|table|index|rls|policy)\b'
    $isBoundary = $text -match '\b(authentication|authenticated|unauthenticated|session|workspace|rls|policy|permission)\b' -or $text -match '\bstorage\b.*\b(access|upload|bucket|object|permission)\b|\b(access|upload|bucket|object|permission)\b.*\bstorage\b' -or $text -match '\btenant\b.*\b(isolat|records?|access)\b|\b(isolat|records?|access)\b.*\btenant\b' -or $text -match '\b(fix|bug|issue)\b.*\blogin\b|\blogin\b.*\b(bug|issue|access|auth)\b'
    $isCacheRecovery = $isDataRecovery -and $text -match '\bcache\b'
    if ($isCacheRecovery -and -not ($text -match '\b(authentication|authenticated|unauthenticated|workspace|rls|policy|permission|tenant)\b')) { $isBoundary = $false }
    $isPackageRelease = $text -match '\b(development pack|skills package)\b' -and $text -match '\b(release|version|changelog|tag)\b'
    $isSaasRelease = $text -match '\bsaas\b' -and $text -match '\b(release|deploy|production)\b'
    $isReleaseReport = $text -match '\brelease report\b'
    $isRelease = $isPackageRelease -or $isSaasRelease -or $isReleaseReport
    $hasPerformanceMetric = $text -match '\b(html|download|size|bytes?|weight|request|call|latency|slow|slowness|faster|render|rendering|paint|performance)\b'
    $hasPerformanceIntent = $text -match '\b(measure|audit|investigate|profile|improve|reduce|optimize|make|load|render)\b'
    $isPerformanceAudit = $hasPerformanceMetric -and $hasPerformanceIntent
    $isTestStrategy = $text -match '\b(test strategy|test matrix|testing strategy|test plan)\b|estratégia de testes|estrategia de testes|matriz de testes|plano de testes|escopo de validação|escopo de validacao'
    $isDocumentation = $text -match '\b(documentation|readme|adr|docs-only|runbook)\b|\bdocumenta|\bdocs?\b|\bevidence record\b|\brelease report\b|\b(update|write|create)\b.{0,80}\bchangelog\b|\bchangelog\b.{0,80}\b(update|write|entry)\b'
    $documentationSelection = @()
    if ($isDocumentation) { $documentationSelection = @('forja-documentation') }
    if ($isMigration -and $isBoundary) {
        $selection = @('forja-supabase-migration', 'forja-auth-storage-safety')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        if ($isPerformanceAudit) { $selection += 'forja-performance-audit' }
        if ($isRelease) { $selection += 'forja-release-pipeline' }
        if ($isIndependentReview) { $selection += 'forja-independent-review' }
        return @($incidentSelection; $dataRecoverySelection; $documentationSelection; $selection)
    }
    if ($isMigration) {
        $selection = @('forja-supabase-migration')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        if ($isPerformanceAudit) { $selection += 'forja-performance-audit' }
        if ($isRelease) { $selection += 'forja-release-pipeline' }
        if ($isIndependentReview) { $selection += 'forja-independent-review' }
        return @($incidentSelection; $dataRecoverySelection; $documentationSelection; $selection)
    }
    if ($isBoundary) {
        $selection = @('forja-auth-storage-safety')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        if ($isPerformanceAudit) { $selection += 'forja-performance-audit' }
        if ($isRelease) { $selection += 'forja-release-pipeline' }
        if ($isIndependentReview) { $selection += 'forja-independent-review' }
        return @($incidentSelection; $dataRecoverySelection; $documentationSelection; $selection)
    }
    if ($isRelease) {
        $selection = @($documentationSelection + @('forja-release-pipeline'))
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        if ($isIndependentReview) { $selection += 'forja-independent-review' }
        return @($incidentSelection + $dataRecoverySelection + $selection)
    }
    if ($isIndependentReview) {
        $selection = @('forja-independent-review')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        return @($incidentSelection + $dataRecoverySelection + $selection)
    }
    if ($isDocumentation) {
        $selection = @('forja-documentation')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        return @($incidentSelection + $dataRecoverySelection + $selection)
    }
    if ($isPerformanceAudit) {
        $selection = @('forja-performance-audit')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        return @($incidentSelection + $dataRecoverySelection + $selection)
    }
    $hasObservableUiWork = $text -match '\b(observable ui|user interface|checkout|modal|dialog|button|botão|botao|form|screen|tela|viewport)\b'
    $isBackendOrApiWithoutUi = $text -match '\b(backend|api)\b' -and -not $hasObservableUiWork
    $isFullRedesign = $text -match '\bfull redesign\b'
    if ($isBackendOrApiWithoutUi -or $isFullRedesign) {
        if ($isTestStrategy) { return @($incidentSelection + $dataRecoverySelection + @('forja-test-strategy')) }
        return @($incidentSelection + $dataRecoverySelection)
    }
    $isScopedMobileOrFormAccessibility = $text -match '\b(mobile|form)\b.*\b(error|errors|label|labels|semantic|semantics|accessibility|keyboard|focus|contrast)\b|\b(error|errors|label|labels|semantic|semantics|accessibility|keyboard|focus|contrast)\b.*\b(mobile|form)\b'
    if ($isScopedMobileOrFormAccessibility -or $text -match '\b(contrast|keyboard|focus order|focus return|focus trap|modal dialog|accessibility|semantic html|touch target|reduced motion)\b') {
        $selection = @('forja-ux-accessibility')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        return @($incidentSelection + $dataRecoverySelection + $selection)
    }
    if ($text -match '\b(button|botão|botao|navigation|navegação|navegacao|frontend|ui|form|html|css|javascript)\b') {
        $selection = @('forja-safe-frontend-change')
        if ($isTestStrategy) { $selection += 'forja-test-strategy' }
        return @($incidentSelection + $dataRecoverySelection + $selection)
    }
    if ($isTestStrategy) { return @($incidentSelection + $dataRecoverySelection + @('forja-test-strategy')) }
    return @($incidentSelection + $dataRecoverySelection)
}

function Get-DataRecoveryOutcome {
    param([string]$Project, [string]$Prompt)

    if ((Get-SkillSelection -Project $Project -Prompt $Prompt) -notcontains 'forja-data-recovery') { return $null }

    $text = $Prompt.ToLowerInvariant()
    $placeholder = '(?:unknown|n/?a|now|yes|placeholder|tbd|none)'
    $hasValue = {
        param([string]$Label)
        $text -match "(?im)\b$Label\s*:\s*(?!$placeholder(?:\.|\s|;|$))[a-z0-9][a-z0-9._:/-]{3,}"
    }
    $hasImmutableSnapshot = & $hasValue 'immutable snapshot'
    $hasBackupReference = & $hasValue 'backup reference'
    $readStructuredField = {
        param([string]$Label)
        $match = [regex]::Match($Prompt, "(?im)^\s*$([regex]::Escape($Label))\s*:\s*([^\r\n]+?)\s*$")
        if (-not $match.Success) { return $null }
        $value = [regex]::Replace($match.Groups[1].Value.Trim().ToLowerInvariant(), '\s+', ' ')
        if ($value -match "^(?:$placeholder)$") { return $null }
        return $value
    }
    $requestedEnvironment = & $readStructuredField 'requested environment'
    $requestedAction = & $readStructuredField 'requested action'
    $requestedScope = & $readStructuredField 'requested scope'
    $source = & $readStructuredField 'source'
    $target = & $readStructuredField 'target'
    $minimumScopeValue = & $readStructuredField 'minimum scope'
    $authorizationEnvironment = & $readStructuredField 'authorization environment'
    $authorizationAction = & $readStructuredField 'authorization action'
    $authorizationScope = & $readStructuredField 'authorization scope'
    $hasRequestedOperation = -not [string]::IsNullOrWhiteSpace($requestedEnvironment) -and -not [string]::IsNullOrWhiteSpace($requestedAction) -and -not [string]::IsNullOrWhiteSpace($requestedScope)
    $hasDistinctSourceTarget = -not [string]::IsNullOrWhiteSpace($source) -and -not [string]::IsNullOrWhiteSpace($target) -and $source -ne $target
    $hasMinimumScope = ($text -match '\bminimum scope\s*:\s*(?!' + $placeholder + '(?:\.|\s|;|$))[^.\r\n]{3,}') -and -not ($text -match '\bminimum scope\s*:\s*(?:all data|entire\s+(?:database|table|tenant)|full\s+(?:database|table|tenant)|all\s+(?:records?|rows?|files?|objects?|cache)|\*)')
    $isBroadScope = -not [string]::IsNullOrWhiteSpace($minimumScopeValue) -and ($minimumScopeValue -match '\*|\ball data\b|\bentire\s+(?:database|table|tenant)\b|\bfull\s+(?:database|table|tenant)\b|\ball\s+(?:records?|rows?|files?|objects?|cache)\b')
    $minimumScopeBound = $hasRequestedOperation -and -not [string]::IsNullOrWhiteSpace($minimumScopeValue) -and -not $isBroadScope -and $minimumScopeValue -eq $requestedScope
    $hasBeforeCount = $text -match '(?im)\bbefore\s+(?:row\s+|object\s+|file\s+)?count\s*:\s*\d+'
    $hasAfterCount = $text -match '(?im)\bafter\s+(?:row\s+|object\s+|file\s+)?count\s*:\s*\d+'
    $hasBeforeChecksum = & $hasValue 'before checksum'
    $hasAfterChecksum = & $hasValue 'after checksum'
    $hasAuthorization = $hasRequestedOperation -and -not [string]::IsNullOrWhiteSpace($authorizationEnvironment) -and -not [string]::IsNullOrWhiteSpace($authorizationAction) -and -not [string]::IsNullOrWhiteSpace($authorizationScope) -and $authorizationEnvironment -eq $requestedEnvironment -and $authorizationAction -eq $requestedAction -and $authorizationScope -eq $requestedScope
    $isPlanningOnly = $text -match '\b(plan|planning|hypothetically|hypothetical|do not execute)\b'
    $actionText = [regex]::Replace($text, '\b(?:do not|don''t|no)\s+(?:delete|drop|truncate|purge|wipe|erase|remove|destroy)\b[^.;]*', '')
    $hasDestructiveIntent = $actionText -match '\b(delete|drop|truncate|purge|wipe|erase|remove|destroy)\b.{0,80}\b(backups?|data|files?|objects?|production|records?|rows?|tables?|database|cache)\b|\b(delete|drop|truncate|purge|wipe|erase|remove|destroy)\s+all\b'

    return [PSCustomObject]@{
        risk = 'CRITICAL'
        copyPreserved = ($text -match '\bcopy-first\b') -and $hasImmutableSnapshot -and $hasBackupReference
        simulationPassed = $text -match '\bread-only\s+dry-run\s+passed\b'
        minimumScope = $hasMinimumScope
        countsChecksums = $hasBeforeCount -and $hasAfterCount -and $hasBeforeChecksum -and $hasAfterChecksum
        authorizationSpecific = $hasAuthorization
        executionAllowed = (($text -match '\bcopy-first\b') -and $hasImmutableSnapshot -and $hasBackupReference -and $hasDistinctSourceTarget -and ($text -match '\bread-only\s+dry-run\s+passed\b') -and $minimumScopeBound -and $hasBeforeCount -and $hasAfterCount -and $hasBeforeChecksum -and $hasAfterChecksum -and $hasAuthorization -and ($text -match '\brollback-of-recovery\s*:\s*(?!' + $placeholder + '(?:\.|\s|;|$))[^.\r\n]{3,}') -and ($text -match '\bpost-verify\s*:\s*(?!' + $placeholder + '(?:\.|\s|;|$))[^.\r\n]{3,}') -and -not $isPlanningOnly -and -not $hasDestructiveIntent)
        postVerify = $text -match '\bpost-verify\s*:\s*(?!' + $placeholder + '(?:\.|\s|;|$))[^.\r\n]{3,}'
    }
}

function Get-TestStrategyOutcome {
    param([string]$Project, [string]$Prompt)

    if ((Get-SkillSelection -Project $Project -Prompt $Prompt) -notcontains 'forja-test-strategy') { return $null }

    $text = $Prompt.ToLowerInvariant()
    $hasSecuritySurface = $text -match '\b(rls|migration|policy|schema|authentication|storage|workspace|tenant)\b'
    $isSaasRelease = $text -match '\bsaas\b' -and $text -match '\b(release|deploy|production)\b'
    $isHigh = $hasSecuritySurface -or $isSaasRelease
    $hasUiSurface = $text -match '\b(dashboard|painel|button|botão|botao|navigation|navegação|navegacao|frontend|ui|form|html|css|javascript|mobile|desktop|viewport|route|rota)\b'
    $isFrontend = $hasUiSurface
    $hasStorageSurface = $text -match '\bstorage\b'
    $isProduction = $text -match '\b(production|prod)\b'
    $isProductionMutation = $isProduction -and $text -match '\b(execute|run|apply|change|mutate|write)\b'
    return [PSCustomObject]@{
        risk = if ($isHigh) { 'HIGH' } elseif ($isFrontend) { 'MODERATE' } else { 'LOW' }
        matrix = if ($hasSecuritySurface) {
            $highMatrix = @('static', 'sql', 'integration', 'local-migration', 'authenticated-actor', 'rls', 'tenant')
            if ($hasStorageSurface) { $highMatrix += 'storage' }
            if ($hasUiSurface) { $highMatrix += @('unit', 'browser', 'desktop', 'mobile', 'navigation') }
            $highMatrix -join '|'
        } elseif ($isSaasRelease -and $hasUiSurface) { 'static|content|manifest|unit|integration|browser|desktop|mobile|navigation' } elseif ($isFrontend) { 'static|content|manifest|unit|integration|browser|desktop|mobile|navigation' } else { 'static|content|manifest' }
        productionGate = if ($isProductionMutation) { 'AUTHORIZED_EXECUTION_REQUIRED' } elseif ($isProduction) { 'NON_MUTATING_OBSERVATION' } else { 'NOT_APPLICABLE' }
    }
}

function Get-PerformanceAuditOutcome {
    param([string]$Project, [string]$Prompt)

    if ((Get-SkillSelection -Project $Project -Prompt $Prompt) -notcontains 'forja-performance-audit') { return $null }
    $text = $Prompt.ToLowerInvariant()
    $hasSpecificMetric = $text -match '\b(html|download|size|bytes?|weight|request|call|latency|render|rendering|paint|storage|database|db)\b'
    $isVague = -not $hasSpecificMetric
    return [PSCustomObject]@{
        measurementRequired = $true
        baselineRequired = $true
        noClaimWithoutData = $true
        scopeRefinementRequired = $isVague
        metricSpecificity = if ($hasSpecificMetric) { 'SPECIFIC' } else { 'UNSPECIFIED' }
    }
}

function Get-IncidentResponseOutcome {
    param([string]$Project, [string]$Prompt)

    $text = $Prompt.ToLowerInvariant()
    $sequence = 'contain|preserve|classify|investigate|communicate|fix|verify|document'
    if ($Project -ne 'FORJA') {
        return [PSCustomObject]@{ incidentState = 'NOT_FORJA'; risk = 'NONE'; sequence = ''; executionAllowed = $false; evidencePreserved = $false }
    }
    $isHypothetical = $text -match '\b(hypothetically|hypothetical|hipoteticamente)\b'
    $hasIncidentSignal = $text -match '\b(incident|incidente|outage|data loss|perda de dados|production error|erro de produ[cç][aã]o)\b'
    $hasProductionSignal = $text -match '\b(production|produ[cç][aã]o|prod)\b'
    $isConfirmed = -not $isHypothetical -and $hasIncidentSignal -and ($hasProductionSignal -or $text -match '\b(outage|data loss|perda de dados)\b')
    $isoTimestamp = '20\d{2}-\d{2}-\d{2}t\d{2}:\d{2}:\d{2}z'
    $hasTimestamp = $text -match "(?im)\btimestamp\s*:\s*$isoTimestamp(?:\.|\s|$)"
    $placeholder = '(?:unknown|n/?a|now|yes|placeholder|tbd|none)'
    $hasHash = $text -match "(?im)\bhash\s*:\s*(?!$placeholder(?:\.|\s|$))[a-z0-9][a-z0-9._:/-]{3,}"
    $hasSnapshot = $text -match "(?im)\bsnapshot\s*:\s*(?!$placeholder(?:\.|\s|$))[a-z0-9][a-z0-9._:/-]{3,}"
    $hasArtifactReference = $hasHash -or $hasSnapshot
    $hasLogReference = $text -match "(?im)\blog reference\s*:\s*(?!$placeholder(?:\.|\s|$))[a-z0-9][a-z0-9._:/-]{3,}"
    $chainMatch = [regex]::Match($Prompt, '(?im)\bchain(?: of custody)?\s*:\s*([^\r\n.]+)')
    $chainValue = if ($chainMatch.Success) { $chainMatch.Groups[1].Value.Trim() } else { '' }
    $hasChainTrail = $chainValue -notmatch "(?i)^$placeholder$" -and $chainValue -match '(?i)\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\s*->\s*[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?\b'
    $ownerMatch = [regex]::Match($Prompt, '(?im)\bowner\s*:\s*([^\r\n.]+)')
    $ownerValue = if ($ownerMatch.Success) { $ownerMatch.Groups[1].Value.Trim() } else { '' }
    $hasIdentifiedOwner = $ownerValue -notmatch "(?i)^$placeholder$" -and $ownerValue -match '(?i)\b(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+|director|manager|officer|lead|commander|[A-Z]{2,}[-_]\d+)\b'
    $authorityMatch = [regex]::Match($Prompt, '(?im)\bexplicit incident authority\s*:\s*([^\r\n.]+)')
    $authorityValue = if ($authorityMatch.Success) { $authorityMatch.Groups[1].Value.Trim() } else { '' }
    $hasStructuredAuthority = $authorityValue -notmatch "(?i)^$placeholder$" -and $authorityValue -match '(?i)\b(?:[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+|director|manager|officer|owner|lead|commander|[A-Z]{2,}[-_]\d+)\b'
    $hasEvidence = $hasTimestamp -and $hasArtifactReference -and $hasLogReference -and $hasChainTrail -and $hasIdentifiedOwner
    $isAuthorizedReversibleContainment = $text -match '\bauthorized reversible containment\b'
    $actionText = [regex]::Replace($text, '\b(?:do not|don''t|no)\s+(?:delete|drop|truncate|purge|wipe|erase|remove|removal|destructive)\b[^.;]*', '')
    $hasGenericDestructiveAction = $actionText -match '\b(?:execute|run|perform|apply)\b.{0,80}\b(?:destructive|delete|drop|truncate|purge|wipe|erase|remove|removal)\b' -or $actionText -match '\b(?:delete|drop|truncate|purge|wipe|erase|remove|removal)\b.{0,80}\b(?:production|prod|data|logs?)\b' -or $actionText -match '\bdestructive\s+(?:production\s+)?action\b'
    $hasUnsafeAction = $text -match '\b(log deletion|cleanup|restart|destructive fix|production mutation)\b' -or $hasGenericDestructiveAction
    if ($isHypothetical) {
        return [PSCustomObject]@{ incidentState = 'HYPOTHETICAL'; risk = 'CRITICAL'; sequence = $sequence; executionAllowed = $false; evidencePreserved = $false }
    }
    if ($isConfirmed) {
        return [PSCustomObject]@{ incidentState = 'CONFIRMED'; risk = 'CRITICAL'; sequence = $sequence; executionAllowed = ($hasEvidence -and $hasStructuredAuthority -and $isAuthorizedReversibleContainment -and -not $hasUnsafeAction); evidencePreserved = $hasEvidence }
    }
    return [PSCustomObject]@{ incidentState = 'NOT_INCIDENT'; risk = 'NONE'; sequence = ''; executionAllowed = $false; evidencePreserved = $false }
}

function Get-IndependentReviewOutcome {
    param([string]$Project, [string]$Prompt)

    $selected = Get-SkillSelection -Project $Project -Prompt $Prompt
    if ($selected -notcontains 'forja-independent-review') { return $null }

    $text = $Prompt.ToLowerInvariant()
    $hasCriticalOrHighFinding = $text -match '\b(critical|high)\b.*\b(finding|issue)\b|\b(finding|issue)\b.*\b(critical|high)\b'
    $isReReviewed = $text -match '\bre-reviewed\b|\bre-review\b.*\b(complete|completed)\b'
    $fixedAndReReviewed = $text -match '\bfixed\b' -and $isReReviewed
    $authorityMatch = [regex]::Match($Prompt, '(?i)\bexplicit risk authority\s*:\s*([^.;\r\n]+)')
    $authorityValue = if ($authorityMatch.Success) { $authorityMatch.Groups[1].Value.Trim() } else { '' }
    $hasNamedPerson = $authorityValue -match '\b[A-Z][a-z]+(?:\s+[A-Z][a-z]+)+\b'
    $hasOrganizationalRole = $authorityValue -match '(?i)\b(director|manager|officer|owner|lead|committee|board|ciso|cto|vp|head)\b'
    $hasAuthorityId = $authorityValue -match '(?i)\b[A-Z]{2,}[-_]\d+\b'
    $hasIdentifiedRiskAuthority = $authorityMatch.Success -and ($hasNamedPerson -or $hasOrganizationalRole -or $hasAuthorityId)
    $acceptedRiskWithAuthorityAndReReview = $text -match '\baccepted risk\b' -and $hasIdentifiedRiskAuthority -and $isReReviewed
    $hasResolution = $fixedAndReReviewed -or $acceptedRiskWithAuthorityAndReReview

    return [PSCustomObject]@{
        perspectives = 'architecture|security|usability/accessibility'
        findingFields = 'severity|evidence|file/line|impact|recommended fix|status'
        requiresArtifactsAndLimitations = $true
        rubberStampProhibited = $text -match '\bapprove quickly\b'
        mergeBlocked = $hasCriticalOrHighFinding -and -not $hasResolution
    }
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

        if ($null -ne $route[0].performanceOutcome) {
            $outcome = Get-PerformanceAuditOutcome -Project $case.project -Prompt $case.prompt
            if ($null -eq $outcome) { Add-Failure "$($case.id) performance measurement gate is missing" }
            else {
                foreach ($property in @('measurementRequired', 'baselineRequired', 'noClaimWithoutData', 'scopeRefinementRequired', 'metricSpecificity')) {
                    if ($route[0].performanceOutcome.$property -ne $outcome.$property) { Add-Failure "$($case.id) performance outcome $property does not match actual prompt text" }
                }
            }
        }

        if ($null -ne $route[0].testStrategyOutcome) {
            if ($null -eq (Get-Command Get-TestStrategyOutcome -ErrorAction SilentlyContinue)) {
                Add-Failure "$($case.id) test strategy outcome gate is missing"
            }
            else {
                $outcome = Get-TestStrategyOutcome -Project $case.project -Prompt $case.prompt
                if ($null -eq $outcome) { Add-Failure "$($case.id) test strategy outcome is missing" }
                else {
                    foreach ($property in @('risk', 'matrix', 'productionGate')) {
                        if ($route[0].testStrategyOutcome.$property -ne $outcome.$property) { Add-Failure "$($case.id) test strategy outcome $property does not match actual prompt text" }
                    }
                }
            }
        }

        if ($route[0].PSObject.Properties.Name -contains 'forbiddenMatrixEntries') {
            $outcome = Get-TestStrategyOutcome -Project $case.project -Prompt $case.prompt
            foreach ($entry in @($route[0].forbiddenMatrixEntries)) {
                if (($outcome.matrix -split '\|') -contains $entry) { Add-Failure "$($case.id) matrix over-tests $entry" }
            }
        }

        if ($null -ne $route[0].reviewOutcome) {
            if ($null -eq (Get-Command Get-IndependentReviewOutcome -ErrorAction SilentlyContinue)) {
                Add-Failure "$($case.id) independent review outcome gate is missing"
            }
            else {
                $outcome = Get-IndependentReviewOutcome -Project $case.project -Prompt $case.prompt
                foreach ($property in @('perspectives', 'findingFields', 'requiresArtifactsAndLimitations', 'rubberStampProhibited', 'mergeBlocked')) {
                    if ($route[0].reviewOutcome.$property -ne $outcome.$property) { Add-Failure "$($case.id) review outcome $property does not match actual prompt text" }
                }
            }
        }

        if ($null -ne $route[0].documentationOutcome) {
            $outcome = Get-DocumentationEvidenceOutcome -Project $case.project -Prompt $case.prompt
            foreach ($property in @('evidenceCompleteness', 'confirmationScope')) {
                if ($route[0].documentationOutcome.$property -ne $outcome.$property) { Add-Failure "$($case.id) documentation outcome $property does not match actual prompt evidence" }
            }
        }

        if ($null -ne $route[0].incidentOutcome) {
            $outcome = Get-IncidentResponseOutcome -Project $case.project -Prompt $case.prompt
            foreach ($property in @('incidentState', 'risk', 'sequence', 'executionAllowed', 'evidencePreserved')) {
                if ($route[0].incidentOutcome.$property -ne $outcome.$property) { Add-Failure "$($case.id) incident outcome $property does not match actual prompt text" }
            }
        }

        if ($null -ne $route[0].dataRecoveryOutcome) {
            $outcome = Get-DataRecoveryOutcome -Project $case.project -Prompt $case.prompt
            if ($null -eq $outcome) { Add-Failure "$($case.id) data recovery outcome is missing" }
            else {
                foreach ($property in @('risk', 'copyPreserved', 'simulationPassed', 'minimumScope', 'countsChecksums', 'authorizationSpecific', 'executionAllowed', 'postVerify')) {
                    if ($route[0].dataRecoveryOutcome.$property -ne $outcome.$property) { Add-Failure "$($case.id) data recovery outcome $property does not match actual prompt text" }
                }
            }
        }

        if ($null -ne $case.mutatedPrompt) {
            $mutated = Get-SkillSelection -Project $case.project -Prompt $case.mutatedPrompt
            if (($mutated -join '|') -eq ($actual -join '|')) {
                if ($null -ne $route[0].mutatedReviewOutcome -or ($route[0].PSObject.Properties.Name -contains 'mutatedPerformanceOutcome') -or ($route[0].PSObject.Properties.Name -contains 'mutatedTestStrategyOutcome')) {
                    # The review outcome assertion below proves the meaningful prompt-derived change.
                }
                elseif ($route[0].PSObject.Properties.Name -contains 'mutatedDocumentationOutcome') {
                    # Documentation mutations intentionally preserve routing while reducing evidence completeness.
                }
                elseif ($route[0].PSObject.Properties.Name -contains 'mutatedIncidentOutcome') {
                    # Incident mutations may preserve selection while changing state, authority, or evidence gates.
                }
                elseif ($route[0].PSObject.Properties.Name -contains 'mutatedDataRecoveryOutcome') {
                    # Data recovery mutations preserve routing while changing safety gates.
                }
                elseif ($null -eq $route[0].releaseKind) {
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
            if ($null -ne $route[0].mutatedReviewOutcome -and $null -ne (Get-Command Get-IndependentReviewOutcome -ErrorAction SilentlyContinue)) {
                $mutatedOutcome = Get-IndependentReviewOutcome -Project $case.project -Prompt $case.mutatedPrompt
                foreach ($property in @('mergeBlocked')) {
                    if ($route[0].mutatedReviewOutcome.$property -ne $mutatedOutcome.$property) { Add-Failure "$($case.id) mutated review outcome $property does not match actual prompt text" }
                }
            }
            if ($route[0].PSObject.Properties.Name -contains 'mutatedPerformanceOutcome') {
                $mutatedPerformanceOutcome = Get-PerformanceAuditOutcome -Project $case.project -Prompt $case.mutatedPrompt
                if ($null -eq $route[0].mutatedPerformanceOutcome) {
                    if ($null -ne $mutatedPerformanceOutcome) { Add-Failure "$($case.id) mutated performance outcome must be eliminated by actual prompt text" }
                }
                elseif ($null -eq $mutatedPerformanceOutcome) {
                    Add-Failure "$($case.id) mutated performance outcome is missing"
                }
                else {
                    foreach ($property in @('measurementRequired', 'baselineRequired', 'noClaimWithoutData', 'scopeRefinementRequired', 'metricSpecificity')) {
                        if ($route[0].mutatedPerformanceOutcome.$property -ne $mutatedPerformanceOutcome.$property) { Add-Failure "$($case.id) mutated performance outcome $property does not match actual prompt text" }
                    }
                }
            }
            if ($route[0].PSObject.Properties.Name -contains 'mutatedTestStrategyOutcome') {
                $mutatedTestStrategyOutcome = Get-TestStrategyOutcome -Project $case.project -Prompt $case.mutatedPrompt
                if ($null -eq $mutatedTestStrategyOutcome) { Add-Failure "$($case.id) mutated test strategy outcome is missing" }
                else {
                    foreach ($property in @('risk', 'matrix', 'productionGate')) {
                        if ($route[0].mutatedTestStrategyOutcome.$property -ne $mutatedTestStrategyOutcome.$property) { Add-Failure "$($case.id) mutated test strategy outcome $property does not match actual prompt text" }
                    }
                }
            }
            if ($route[0].PSObject.Properties.Name -contains 'mutatedDocumentationOutcome') {
                $mutatedDocumentationOutcome = Get-DocumentationEvidenceOutcome -Project $case.project -Prompt $case.mutatedPrompt
                foreach ($property in @('evidenceCompleteness', 'confirmationScope')) {
                    if ($route[0].mutatedDocumentationOutcome.$property -ne $mutatedDocumentationOutcome.$property) { Add-Failure "$($case.id) mutated documentation outcome $property does not match actual prompt evidence" }
                }
            }
            if ($route[0].PSObject.Properties.Name -contains 'mutatedIncidentOutcome') {
                $mutatedIncidentOutcome = Get-IncidentResponseOutcome -Project $case.project -Prompt $case.mutatedPrompt
                foreach ($property in @('incidentState', 'risk', 'sequence', 'executionAllowed', 'evidencePreserved')) {
                    if ($route[0].mutatedIncidentOutcome.$property -ne $mutatedIncidentOutcome.$property) { Add-Failure "$($case.id) mutated incident outcome $property does not match actual prompt text" }
                }
            }
            if ($route[0].PSObject.Properties.Name -contains 'mutatedDataRecoveryOutcome') {
                $mutatedOutcome = Get-DataRecoveryOutcome -Project $case.project -Prompt $case.mutatedPrompt
                foreach ($property in @('risk', 'copyPreserved', 'simulationPassed', 'minimumScope', 'countsChecksums', 'authorizationSpecific', 'executionAllowed', 'postVerify')) {
                    if ($route[0].mutatedDataRecoveryOutcome.$property -ne $mutatedOutcome.$property) { Add-Failure "$($case.id) mutated data recovery outcome $property does not match actual prompt text" }
                }
            }
            if ($route[0].PSObject.Properties.Name -contains 'mutatedForbiddenMatrixEntries') {
                $mutatedTestStrategyOutcome = Get-TestStrategyOutcome -Project $case.project -Prompt $case.mutatedPrompt
                foreach ($entry in @($route[0].mutatedForbiddenMatrixEntries)) {
                    if (($mutatedTestStrategyOutcome.matrix -split '\|') -contains $entry) { Add-Failure "$($case.id) mutated matrix over-tests $entry" }
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

    $reviewSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-independent-review/SKILL.md'
    $reviewReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-independent-review/references/review-rubric.md'
    if (-not (Test-Path -LiteralPath $reviewSkillPath -PathType Leaf)) { Add-Failure 'independent review skill is missing'; return }
    if (-not (Test-Path -LiteralPath $reviewReferencePath -PathType Leaf)) { Add-Failure 'independent review rubric is missing'; return }

    $reviewSkill = Get-Content -LiteralPath $reviewSkillPath -Raw
    if ($reviewSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-independent-review\s*\r?\ndescription:\s*Use when') { Add-Failure 'independent review front matter is invalid' }
    $reviewFrontMatter = [regex]::Match($reviewSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($reviewFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'independent review front matter must contain only name and description' }
    if (($actualHeadings = @($reviewSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'independent review must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('architecture', 'security', 'usability', 'accessibility', 'severity', 'evidence', 'file', 'line', 'impact', 'recommended fix', 'status', 'Critical', 'High', 'merge-blocking', 'explicit risk authority', 're-reviewed', 'no findings', 'line references.*not applicable', 'do not.*invent evidence', 'approve quickly')) {
        if ($reviewSkill -notmatch "(?is)$requirement") { Add-Failure "independent review skill requirement is missing: $requirement" }
    }
    $reviewReference = Get-Content -LiteralPath $reviewReferencePath -Raw
    foreach ($check in @('Architecture', 'Security', 'Usability', 'Accessibility', 'Critical', 'High', 'severity', 'evidence', 'file', 'line', 'impact', 'recommended fix', 'status', 'Accepted risk', 're-review')) {
        if ($reviewReference -notmatch "(?is)$check") { Add-Failure "independent review rubric is missing check: $check" }
    }

    $uxSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-ux-accessibility/SKILL.md'
    $uxReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-ux-accessibility/references/accessibility-checks.md'
    if (-not (Test-Path -LiteralPath $uxSkillPath -PathType Leaf)) { Add-Failure 'UX accessibility skill is missing'; return }
    if (-not (Test-Path -LiteralPath $uxReferencePath -PathType Leaf)) { Add-Failure 'accessibility checks reference is missing'; return }

    $uxSkill = Get-Content -LiteralPath $uxSkillPath -Raw
    if ($uxSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-ux-accessibility\s*\r?\ndescription:\s*Use when') { Add-Failure 'UX accessibility front matter is invalid' }
    $uxFrontMatter = [regex]::Match($uxSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($uxFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'UX accessibility front matter must contain only name and description' }
    if (($actualHeadings = @($uxSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'UX accessibility must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('MODERATE', 'mobile', 'form', 'modal', 'keyboard', 'focus', 'contrast', 'error', 'semantic', 'accessibility', 'full redesign', 'documentation-only', 'backend-only', 'separate discovery', 'approval')) {
        if ($uxSkill -notmatch "(?is)$requirement") { Add-Failure "UX accessibility skill requirement is missing: $requirement" }
    }
    $uxReference = Get-Content -LiteralPath $uxReferencePath -Raw
    foreach ($check in @('keyboard navigation', 'focus order', 'visible focus', 'focus trap', 'focus return', 'contrast', 'error association', 'live feedback', 'semantic HTML', 'labels', 'roles', 'mobile', 'reduced motion', 'touch target')) {
        if ($uxReference -notmatch "(?is)$check") { Add-Failure "accessibility checks reference is missing check: $check" }
    }

    $performanceSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-performance-audit/SKILL.md'
    $performanceReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-performance-audit/references/performance-measurements.md'
    if (-not (Test-Path -LiteralPath $performanceSkillPath -PathType Leaf)) { Add-Failure 'performance audit skill is missing'; return }
    if (-not (Test-Path -LiteralPath $performanceReferencePath -PathType Leaf)) { Add-Failure 'performance measurements reference is missing'; return }

    $performanceSkill = Get-Content -LiteralPath $performanceSkillPath -Raw
    if ($performanceSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-performance-audit\s*\r?\ndescription:\s*Use when') { Add-Failure 'performance audit front matter is invalid' }
    $performanceFrontMatter = [regex]::Match($performanceSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($performanceFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'performance audit front matter must contain only name and description' }
    if (($actualHeadings = @($performanceSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'performance audit must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('MODERATE', 'hypothesis', 'metric', 'workload', 'environment', 'tool', 'baseline', 'same conditions', 'effect size', 'regression', 'variance', 'actual data', 'HTML', 'download size', 'requests', 'latency', 'render', 'Storage', 'database', 'rollback')) {
        if ($performanceSkill -notmatch "(?is)$requirement") { Add-Failure "performance audit skill requirement is missing: $requirement" }
    }
    $performanceReference = Get-Content -LiteralPath $performanceReferencePath -Raw
    foreach ($check in @('hypothesis', 'metric', 'workload', 'environment', 'tool', 'baseline', 'same conditions', 'effect size', 'regression', 'variance', 'HTML', 'download size', 'requests', 'latency', 'render', 'Storage', 'database', 'rollback')) {
        if ($performanceReference -notmatch "(?is)$check") { Add-Failure "performance measurements reference is missing check: $check" }
    }

    $testStrategySkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-test-strategy/SKILL.md'
    $testStrategyReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-test-strategy/references/test-matrix.md'
    if (-not (Test-Path -LiteralPath $testStrategySkillPath -PathType Leaf)) { Add-Failure 'test strategy skill is missing'; return }
    if (-not (Test-Path -LiteralPath $testStrategyReferencePath -PathType Leaf)) { Add-Failure 'test matrix reference is missing'; return }

    $testStrategySkill = Get-Content -LiteralPath $testStrategySkillPath -Raw
    if ($testStrategySkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-test-strategy\s*\r?\ndescription:\s*Use when') { Add-Failure 'test strategy front matter is invalid' }
    $testStrategyFrontMatter = [regex]::Match($testStrategySkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($testStrategyFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'test strategy front matter must contain only name and description' }
    if (($actualHeadings = @($testStrategySkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'test strategy must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('LOW', 'MODERATE', 'HIGH', 'CRITICAL', 'highest risk prevails', 'smallest-sufficient', 'static', 'content', 'manifest', 'unit', 'integration', 'browser', 'desktop', 'mobile', 'navigation', 'authenticated actor', 'RLS', 'tenant', 'Storage', 'local migration', 'offline', 'preview', 'production', 'non-mutating observation', 'authorized execution')) {
        if ($testStrategySkill -notmatch "(?is)$requirement") { Add-Failure "test strategy skill requirement is missing: $requirement" }
    }
    $testStrategyReference = Get-Content -LiteralPath $testStrategyReferencePath -Raw
    foreach ($check in @('static', 'content', 'manifest', 'unit', 'integration', 'browser', 'desktop', 'mobile', 'navigation', 'authenticated actor', 'RLS', 'tenant', 'Storage', 'local migration', 'offline', 'preview', 'production', 'non-mutating observation', 'authorized execution', 'smallest-sufficient')) {
        if ($testStrategyReference -notmatch "(?is)$check") { Add-Failure "test matrix reference is missing check: $check" }
    }

    $documentationSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-documentation/SKILL.md'
    $documentationReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-documentation/references/evidence-schema.md'
    if (-not (Test-Path -LiteralPath $documentationSkillPath -PathType Leaf)) { Add-Failure 'documentation skill is missing'; return }
    if (-not (Test-Path -LiteralPath $documentationReferencePath -PathType Leaf)) { Add-Failure 'documentation evidence schema is missing'; return }

    $documentationSkill = Get-Content -LiteralPath $documentationSkillPath -Raw
    if ($documentationSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-documentation\s*\r?\ndescription:\s*Use when') { Add-Failure 'documentation front matter is invalid' }
    $documentationFrontMatter = [regex]::Match($documentationSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($documentationFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'documentation front matter must contain only name and description' }
    if (($actualHeadings = @($documentationSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'documentation must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('LOW', 'executed', 'observed', 'planned', 'not-run', 'evidence source', 'command', 'timestamp', 'commit', 'hash', 'URL', 'Drive ID', 'size', 'modified', 'unsupported conclusions', 'secret', 'credential', 'PII', 'local artifact', 'GitHub', 'production', 'folder ID', 'file ID', 'post-upload', 'reread', 'deletion', 'overwrite', 'backup-before-update', 'pre-update', 'backup file ID', 'backup name', 'backup size', 'backup modified', 'backup confirmation', 'original file ID', 'never delete history', 'NOT_APPLICABLE')) {
        if ($documentationSkill -notmatch "(?is)$requirement") { Add-Failure "documentation skill requirement is missing: $requirement" }
    }
    $documentationReference = Get-Content -LiteralPath $documentationReferencePath -Raw
    foreach ($check in @('executed', 'observed', 'planned', 'not-run', 'evidence source', 'command', 'timestamp', 'commit', 'hash', 'URL', 'Drive ID', 'size', 'modified', 'local artifact', 'GitHub', 'production', 'folder ID', 'file ID', 'reread', 'secret', 'credential', 'PII', 'backup-before-update', 'pre-update', 'backup file ID', 'backup name', 'backup size', 'backup modified', 'backup confirmation', 'original file ID', 'never delete history', 'NOT_APPLICABLE')) {
        if ($documentationReference -notmatch "(?is)$check") { Add-Failure "documentation evidence schema is missing check: $check" }
    }

    $incidentSkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-incident-response/SKILL.md'
    $incidentReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-incident-response/references/incident-runbook.md'
    if (-not (Test-Path -LiteralPath $incidentSkillPath -PathType Leaf)) { Add-Failure 'incident response skill is missing'; return }
    if (-not (Test-Path -LiteralPath $incidentReferencePath -PathType Leaf)) { Add-Failure 'incident response runbook is missing'; return }

    $incidentSkill = Get-Content -LiteralPath $incidentSkillPath -Raw
    if ($incidentSkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-incident-response\s*\r?\ndescription:\s*Use when') { Add-Failure 'incident response front matter is invalid' }
    $incidentFrontMatter = [regex]::Match($incidentSkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($incidentFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'incident response front matter must contain only name and description' }
    if (($actualHeadings = @($incidentSkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'incident response must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('CRITICAL', 'confirmed incident', 'outage', 'data loss', 'production error', 'hypothetical', 'contain', 'preserve', 'classify', 'investigate', 'communicate', 'fix', 'verify', 'document', 'timestamp', 'hash', 'snapshot', 'log reference', 'chain', 'owner', 'explicit incident authority', 'reversible containment', 'no log deletion', 'cleanup', 'restart', 'destructive', 'production mutation', 'rollback', 'recovery', 'status', 'cadence', 'no blame', 'secret', 'PII')) {
        if ($incidentSkill -notmatch "(?is)$requirement") { Add-Failure "incident response skill requirement is missing: $requirement" }
    }
    $incidentSequence = @('contain', 'preserve', 'classify', 'investigate', 'communicate', 'fix', 'verify', 'document') -join '.*'
    if ($incidentSkill -notmatch "(?is)$incidentSequence") { Add-Failure 'incident response workflow must keep the required ordered sequence' }
    $incidentReference = Get-Content -LiteralPath $incidentReferencePath -Raw
    foreach ($check in @('timestamp', 'hash', 'snapshot', 'log reference', 'chain', 'owner', 'contain', 'preserve', 'classify', 'investigate', 'communicate', 'fix', 'verify', 'document', 'rollback', 'recovery', 'status', 'cadence', 'no blame', 'secret', 'PII')) {
        if ($incidentReference -notmatch "(?is)$check") { Add-Failure "incident response runbook is missing check: $check" }
    }

    $dataRecoverySkillPath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-data-recovery/SKILL.md'
    $dataRecoveryReferencePath = Join-Path $repoRoot 'plugins/forja-development-pack/skills/forja-data-recovery/references/recovery-runbook.md'
    if (-not (Test-Path -LiteralPath $dataRecoverySkillPath -PathType Leaf)) { Add-Failure 'data recovery skill is missing'; return }
    if (-not (Test-Path -LiteralPath $dataRecoveryReferencePath -PathType Leaf)) { Add-Failure 'data recovery runbook is missing'; return }

    $dataRecoverySkill = Get-Content -LiteralPath $dataRecoverySkillPath -Raw
    if ($dataRecoverySkill -notmatch '(?ms)\A---\s*\r?\nname:\s*forja-data-recovery\s*\r?\ndescription:\s*Use when') { Add-Failure 'data recovery front matter is invalid' }
    $dataRecoveryFrontMatter = [regex]::Match($dataRecoverySkill, '(?ms)\A---\s*\r?\n(.*?)\r?\n---').Groups[1].Value
    if ((@($dataRecoveryFrontMatter -split "`r?`n" | Where-Object { $_ -match '^[A-Za-z_][A-Za-z0-9_-]*:' }).Count) -ne 2) { Add-Failure 'data recovery front matter must contain only name and description' }
    if (($actualHeadings = @($dataRecoverySkill -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) }) -join '|') -ne ($sectionHeadings -join '|')) { Add-Failure 'data recovery must contain exactly the required twelve H2 sections' }
    foreach ($requirement in @('CRITICAL', 'copy-first', 'immutable snapshot', 'backup reference', 'source', 'target', 'read-only', 'dry-run', 'minimum scope', 'row', 'object', 'file', 'count', 'checksum', 'before', 'after', 'rollback-of-recovery', 'specific authorization', 'environment', 'action', 'scope', 'post-verify', 'planning-only', 'production')) {
        if ($dataRecoverySkill -notmatch "(?is)$requirement") { Add-Failure "data recovery skill requirement is missing: $requirement" }
    }
    $dataRecoveryReference = Get-Content -LiteralPath $dataRecoveryReferencePath -Raw
    foreach ($check in @('copy-first', 'immutable snapshot', 'backup reference', 'source', 'target', 'read-only', 'dry-run', 'minimum scope', 'row', 'object', 'file', 'count', 'checksum', 'before', 'after', 'rollback-of-recovery', 'specific authorization', 'environment', 'action', 'scope', 'post-verify', 'planning-only', 'production')) {
        if ($dataRecoveryReference -notmatch "(?is)$check") { Add-Failure "data recovery runbook is missing check: $check" }
    }

    if ($failures.Count -eq 0) { Write-Output 'PASS: skill trigger suite' }
}

function Get-DocumentationEvidenceOutcome {
    param(
        [string]$Project,
        [string]$Prompt
    )

    $text = $Prompt.ToLowerInvariant()
    if ($Project -ne 'FORJA') { return [PSCustomObject]@{ evidenceCompleteness = $false; confirmationScope = 'NOT_FORJA' } }

    $hasSource = $text -match '(evidence source:|git log|drive connector)'
    $hasCheck = $text -match '(command:|check:|reread)'
    $isoTimestamp = '20\d{2}-\d{2}-\d{2}t\d{2}:\d{2}:\d{2}z'
    $hasTimestamp = $text -match "timestamp:\s*$isoTimestamp" -and $text -notmatch 'timestamp:\s*(now|unknown|n/a)'
    $hasCommitHash = $text -match 'commit\s+[0-9a-f]{7,40}'
    $isDrive = $text -match '\bdrive\b'
    if ($isDrive) {
        $hasDriveMetadata = $text -match '(?m)^folder id:\s*(?!\.\.\.|unknown|n/a)[a-z0-9_-]+\s*(?:\.|$)' -and $text -match '(?m)^file id:\s*(?!\.\.\.|unknown|n/a)[a-z0-9_-]+\s*(?:\.|$)' -and $text -match '(?m)^size:\s*[1-9]\d*\s*bytes\s*(?:\.|$)' -and $text -match "(?m)^modified:\s*$isoTimestamp\s*(?:\.|$)" -and $text -match '(?m)^post-upload reread confirmed (metadata|content)\s*(?:\.|$)'
        $isDriveUpdate = $text -match '\b(update|overwrite|existing file)\b'
        $hasBackupEvidence = $text -match '(?m)^pre-update (metadata|content) read confirmed\s*(?:\.|$)' -and $text -match '(?m)^backup file id:\s*(?!\.\.\.|unknown|n/a)[a-z0-9_-]+\s*(?:\.|$)' -and $text -match '(?m)^backup name:\s*\S*backup-\d{4}-\d{2}-\d{2}-\d{4}\S*\s*(?:\.|$)' -and $text -match '(?m)^backup size:\s*[1-9]\d*\s*bytes\s*(?:\.|$)' -and $text -match "(?m)^backup modified:\s*$isoTimestamp\s*(?:\.|$)" -and $text -match '(?m)^backup confirmation:\s*(confirmed.*reread|reread.*confirmed).*before update\s*(?:\.|$)' -and $text -match '(?m)^preserve original file id:\s*(?!\.\.\.|unknown|n/a)[a-z0-9_-]+\s*(?:\.|$)'
        $hasNewFileBackupStatus = $text -match 'backup status:\s*not_applicable' -and $text -match 'reason:\s*.*(new[- ]file|no existing remote)'
        $backupSatisfied = if ($isDriveUpdate) { $hasBackupEvidence } else { $hasNewFileBackupStatus }
        return [PSCustomObject]@{ evidenceCompleteness = ($hasSource -and $hasCheck -and $hasTimestamp -and $hasDriveMetadata -and $backupSatisfied); confirmationScope = 'DRIVE' }
    }
    return [PSCustomObject]@{ evidenceCompleteness = ($hasSource -and $hasCheck -and $hasTimestamp -and $hasCommitHash); confirmationScope = 'LOCAL_ARTIFACT' }
}

function Get-SkillPackRouterRecord {
    param([string]$Prompt)

    $text = $Prompt.ToLowerInvariant()
    $allSkills = @(
        'forja-auth-storage-safety', 'forja-data-recovery', 'forja-documentation', 'forja-incident-response',
        'forja-independent-review', 'forja-performance-audit', 'forja-release-pipeline', 'forja-safe-frontend-change',
        'forja-supabase-migration', 'forja-task-router', 'forja-test-strategy', 'forja-ux-accessibility'
    )
    $isIncidentRecovery = $text -match '\bconfirmed\b' -and $text -match '\bproduction outage\b' -and $text -match '\b(suspected data loss|restore)\b'
    $isModalRls = $text -match '\bmodal dialog\b' -and $text -match '\b(rls|row level security)\b' -and $text -match '\bmigration\b'
    if ($isModalRls) {
        $selected = @('forja-safe-frontend-change', 'forja-ux-accessibility', 'forja-supabase-migration', 'forja-auth-storage-safety', 'forja-test-strategy')
        return [PSCustomObject]@{
            taskSummary = 'Scoped FORJA modal accessibility change plus an incremental RLS migration.'
            riskLevel = 'HIGH'
            selectedSkills = $selected
            skillsDeliberatelyNotSelected = @($allSkills | Where-Object { $_ -notin $selected })
            requiredApprovals = @('Require approval before migration execution or FORJA SaaS merge.')
            prohibitedActions = @('Do not execute remote database commands, production actions, or an unapproved SaaS merge.')
            validationPlan = @('Validate modal keyboard, focus-return, and semantic behavior; run local incremental migration plus authenticated RLS tenant-isolation tests.')
            stopConditions = @('Stop before remote database commands, production execution, or SaaS merge.')
        }
    }
    if ($isIncidentRecovery) {
        $selected = @('forja-incident-response', 'forja-data-recovery', 'forja-test-strategy', 'forja-documentation')
        return [PSCustomObject]@{
            taskSummary = 'Confirmed FORJA production outage with suspected data loss and a proposed restore.'
            riskLevel = 'CRITICAL'
            selectedSkills = $selected
            skillsDeliberatelyNotSelected = @($allSkills | Where-Object { $_ -notin $selected })
            requiredApprovals = @('Require explicit incident authority and specific recovery authorization before any production action.')
            prohibitedActions = @('Do not restore production data, delete evidence, or run destructive production commands.')
            validationPlan = @('Preserve incident evidence; simulate copy-first recovery with a read-only dry-run, counts, checksums, and post-verify plan.')
            stopConditions = @('Stop before containment, restore, or any production action.')
        }
    }
    return $null
}

function Assert-SkillPackSuite {
    $skillsRoot = Join-Path $repoRoot 'plugins/forja-development-pack/skills'
    $expectedNames = @(
        'forja-auth-storage-safety', 'forja-data-recovery', 'forja-documentation', 'forja-incident-response',
        'forja-independent-review', 'forja-performance-audit', 'forja-release-pipeline', 'forja-safe-frontend-change',
        'forja-supabase-migration', 'forja-task-router', 'forja-test-strategy', 'forja-ux-accessibility'
    )
    $requiredHeadings = @('Purpose', 'Trigger conditions', 'Do not trigger when', 'Required inputs', 'Expected outputs', 'Risk classification', 'Workflow', 'Required checks', 'Stop conditions', 'Failure recovery', 'Handoff or next skills', 'Completion evidence')
    $expectedReferences = @{
        'forja-auth-storage-safety' = 'references/auth-storage-boundaries.md'; 'forja-data-recovery' = 'references/recovery-runbook.md'
        'forja-documentation' = 'references/evidence-schema.md'; 'forja-incident-response' = 'references/incident-runbook.md'
        'forja-independent-review' = 'references/review-rubric.md'; 'forja-performance-audit' = 'references/performance-measurements.md'
        'forja-release-pipeline' = 'references/release-gates.md'; 'forja-safe-frontend-change' = 'references/frontend-safety-checks.md'
        'forja-supabase-migration' = 'references/migration-runbook.md'; 'forja-task-router' = 'references/routing-contract.md'
        'forja-test-strategy' = 'references/test-matrix.md'; 'forja-ux-accessibility' = 'references/accessibility-checks.md'
    }
    $skillDirectories = @(Get-ChildItem -LiteralPath $skillsRoot -Directory | Sort-Object Name)
    if ($skillDirectories.Count -ne 12) { Add-Failure "skill pack must contain exactly 12 immediate skill directories; found $($skillDirectories.Count)" }
    if ((@($skillDirectories.Name) -join '|') -ne ($expectedNames -join '|')) { Add-Failure 'skill pack directory names do not match the exact expected set' }

    $descriptions = @{}
    $primaryTriggers = @{}
    $proseBlocks = @{}
    foreach ($directory in $skillDirectories) {
        $skillPath = Join-Path $directory.FullName 'SKILL.md'
        if (-not (Test-Path -LiteralPath $skillPath -PathType Leaf)) { Add-Failure "$($directory.Name) is missing SKILL.md"; continue }
        $referencePath = Join-Path $directory.FullName $expectedReferences[$directory.Name]
        if (-not (Test-Path -LiteralPath $referencePath -PathType Leaf)) { Add-Failure "$($directory.Name) is missing its expected reference: $($expectedReferences[$directory.Name])" }
        $content = Get-Content -LiteralPath $skillPath -Raw
        $frontMatterMatch = [regex]::Match($content, '(?ms)\A---\s*\r?\n(.*?)\r?\n---')
        if (-not $frontMatterMatch.Success) { Add-Failure "$($directory.Name) has invalid front matter"; continue }
        $frontMatterLines = @($frontMatterMatch.Groups[1].Value -split "`r?`n" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($frontMatterLines.Count -ne 2 -or $frontMatterLines[0] -ne "name: $($directory.Name)" -or $frontMatterLines[1] -notmatch '^description:\s*Use when\s+.+') { Add-Failure "$($directory.Name) front matter must contain only its name and a meaningful Use when description"; continue }
        $description = $frontMatterLines[1].Substring('description:'.Length).Trim()
        if ($descriptions.ContainsKey($description)) { Add-Failure "$($directory.Name) description collides with $($descriptions[$description])" } else { $descriptions[$description] = $directory.Name }
        $trigger = ($description -replace '^Use when\s+', '' -split '[,;.]')[0].Trim().ToLowerInvariant()
        if ($primaryTriggers.ContainsKey($trigger)) { Add-Failure "$($directory.Name) primary trigger collides with $($primaryTriggers[$trigger])" } else { $primaryTriggers[$trigger] = $directory.Name }
        $headings = @($content -split "`r?`n" | Where-Object { $_ -match '^## ' } | ForEach-Object { $_.Substring(3) })
        if (($headings -join '|') -ne ($requiredHeadings -join '|')) { Add-Failure "$($directory.Name) must contain exactly the required twelve H2 sections" }

        foreach ($link in [regex]::Matches($content, '(?m)\[[^\]]+\]\(([^)\s#]+)(?:#[^)]+)?\)')) {
            $target = $link.Groups[1].Value
            if ($target -match '^[a-z][a-z0-9+.-]*:' -or $target.StartsWith('/')) { continue }
            $resolved = [System.IO.Path]::GetFullPath((Join-Path $directory.FullName $target))
            $rootWithSeparator = $directory.FullName.TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
            if (-not $resolved.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase) -or -not (Test-Path -LiteralPath $resolved -PathType Leaf)) { Add-Failure "$($directory.Name) has an unresolved or escaping relative markdown link: $target" }
        }

        # A duplicate is actionable only when it repeats at least 240 normalized characters and 40 words: this catches copied prose while excluding shared headings and field labels.
        $body = [regex]::Replace($content, '(?s)\A---.*?---\s*', '')
        foreach ($block in ($body -split '(?:\r?\n){2,}')) {
            if ($block -match '^## ' -or $block -match '^(?:- )?[A-Za-z ]+:\s*$') { continue }
            $normalized = ([regex]::Replace($block.ToLowerInvariant(), '[^\p{L}\p{N}]+', ' ')).Trim()
            if ($normalized.Length -ge 240 -and (@($normalized -split '\s+' | Where-Object { $_ }).Count -ge 40)) { $proseBlocks["$($directory.Name)|$normalized"] = $directory.Name }
        }
    }
    foreach ($entry in $proseBlocks.GetEnumerator()) {
        $normalized = $entry.Key.Substring($entry.Key.IndexOf('|') + 1)
        $owners = @($proseBlocks.Keys | Where-Object { $_.Substring($_.IndexOf('|') + 1) -eq $normalized } | ForEach-Object { $proseBlocks[$_] } | Select-Object -Unique)
        if ($owners.Count -gt 1) { Add-Failure "large duplicated normalized prose block across skills: $($owners -join ', ')"; break }
    }
    Write-Output 'PASS: duplicate prose threshold is 240 normalized characters and 40 words'

    $python = 'C:\Users\Pedro\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    $validator = 'C:\Users\Pedro\.codex\skills\.system\skill-creator\scripts\quick_validate.py'
    if (-not (Test-Path -LiteralPath $python -PathType Leaf) -or -not (Test-Path -LiteralPath $validator -PathType Leaf)) { Add-Failure 'official quick_validate controller prerequisites are missing' }
    else {
        foreach ($directory in $skillDirectories) {
            & $python $validator $directory.FullName
            if ($LASTEXITCODE -ne 0) { Add-Failure "official quick_validate failed for $($directory.Name)" }
        }
    }

    $cases = Read-JsonFixture -Path (Join-Path $PSScriptRoot 'skill-pack-integration-cases.json')
    if ($null -ne $cases -and @($cases).Count -eq 2) {
        foreach ($case in $cases) {
            $actual = Get-SkillPackRouterRecord -Prompt $case.prompt
            if ($null -eq $actual) { Add-Failure 'integration prompt did not derive a router record from its text'; continue }
            foreach ($field in @('taskSummary', 'riskLevel', 'selectedSkills', 'skillsDeliberatelyNotSelected', 'requiredApprovals', 'prohibitedActions', 'validationPlan', 'stopConditions')) {
                $expectedValue = @($case.expectedRecord.$field) -join '|'
                $actualValue = @($actual.$field) -join '|'
                if ($expectedValue -ne $actualValue) { Add-Failure "integration router field $field does not match prompt-derived record" }
            }
        }
    }
    else { Add-Failure 'skill pack integration fixture must contain exactly two controlled prompts' }
    if ($failures.Count -eq 0) { Write-Output 'PASS: skill pack suite' }
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
elseif ($Suite -eq 'SkillPack') {
    Assert-SkillPackSuite
}
else {
    Assert-SkillTriggerSuite
}

if ($failures.Count -gt 0) {
    exit 1
}
