#Requires -Version 5.1
<#
.SYNOPSIS
  Detects the current phase of the Codex GAS development workflow.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$requiredDocs = @(
    'product-requirements.md',
    'functional-design.md',
    'architecture.md',
    'repository-structure.md',
    'development-guidelines.md',
    'glossary.md',
    'development-roadmap.md'
)

$result = [ordered]@{
    hasClaspJson          = $false
    scriptId              = $null
    hasInitialRequirements = $false
    hasAgentsMd           = $false
    docsCount             = 0
    docsFiles             = @()
    missingPermanentDocs  = @()
    steeringDirs          = @()
    isGitRepo             = $false
    suggestedPhase        = $null
    notes                 = @()
}

if (Test-Path -LiteralPath '.clasp.json') {
    $result.hasClaspJson = $true
    try {
        $config = Get-Content -LiteralPath '.clasp.json' -Raw | ConvertFrom-Json
        $result.scriptId = $config.scriptId
    } catch {
        $result.notes += 'Could not parse .clasp.json.'
    }
}

$result.hasInitialRequirements = [bool](Test-Path -LiteralPath 'docs/ideas/initial-requirements.md')
$result.hasAgentsMd = [bool](Test-Path -LiteralPath 'AGENTS.md')

if (Test-Path -LiteralPath 'docs') {
    $docs = @(Get-ChildItem -LiteralPath 'docs' -Filter '*.md' -File -Recurse)
    $result.docsCount = $docs.Count
    $result.docsFiles = @($docs | ForEach-Object {
        (Resolve-Path -LiteralPath $_.FullName -Relative)
    })
}

$result.missingPermanentDocs = @($requiredDocs | Where-Object {
    -not (Test-Path -LiteralPath (Join-Path 'docs' $_))
})

if (Test-Path -LiteralPath '.steering') {
    $result.steeringDirs = @(Get-ChildItem -LiteralPath '.steering' -Directory | ForEach-Object { $_.Name })
}

try {
    $null = Get-Command git -ErrorAction Stop
    $null = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0) { $result.isGitRepo = $true }
} catch {}

if (-not $result.hasClaspJson) {
    $result.suggestedPhase = '1-gas-clone'
} elseif (-not $result.hasInitialRequirements) {
    $result.suggestedPhase = '2-init-idea'
} elseif (-not $result.hasAgentsMd -or @($result.missingPermanentDocs).Count -gt 0) {
    $result.suggestedPhase = '3-dev-docs-init'
    if (-not $result.hasAgentsMd) { $result.notes += 'AGENTS.md is missing.' }
    if (@($result.missingPermanentDocs).Count -gt 0) {
        $result.notes += ('Missing permanent docs: ' + (@($result.missingPermanentDocs) -join ', '))
    }
} else {
    $result.suggestedPhase = '4-add-feature-or-5-gas-push'
    $result.notes += 'Documentation prerequisites are present. Use add-feature for new work or gas-push for an already implemented change.'
}

$result | ConvertTo-Json -Depth 5
exit 0
