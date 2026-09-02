#Requires -Version 5.1
<#
.SYNOPSIS
  gas-clone preflight. Returns clasp/auth/directory state as JSON.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

function Test-CommandExists {
    param([string]$Name)
    try { $null = Get-Command $Name -ErrorAction Stop; return $true } catch { return $false }
}

$result = [ordered]@{
    claspInstalled   = $false
    claspVersion     = $null
    loggedIn         = $false
    authUser         = $null
    hasClaspJson     = $false
    existingScriptId = $null
    dirEntryCount    = 0
    dirEntries       = @()
    isGitRepo        = $false
    notes            = @()
}

if (-not (Test-CommandExists 'clasp')) {
    $result.notes += 'clasp not found. Suggest: npm install -g @google/clasp'
} else {
    $result.claspInstalled = $true
    $versionOutput = clasp --version
    if ($LASTEXITCODE -eq 0 -and $versionOutput) {
        $result.claspVersion = ("$versionOutput").Trim()
    }

    $authOutput = (clasp show-authorized-user | Out-String)
    if ($LASTEXITCODE -eq 0 -and $authOutput -match 'logged in as\s+(\S+)') {
        $result.loggedIn = $true
        $result.authUser = $Matches[1].TrimEnd('.')
    } else {
        $result.notes += 'Not logged in to clasp. The user must run clasp login and complete browser authentication.'
    }
}

if (Test-Path -LiteralPath '.clasp.json') {
    $result.hasClaspJson = $true
    try {
        $config = Get-Content -LiteralPath '.clasp.json' -Raw | ConvertFrom-Json
        $result.existingScriptId = $config.scriptId
    } catch {
        $result.notes += 'Could not parse .clasp.json.'
    }
}

$entries = @(Get-ChildItem -Force | Where-Object { $_.Name -notin @('.claude', '.codex', '.git') })
$result.dirEntryCount = $entries.Count
$result.dirEntries = @($entries | Select-Object -First 10 | ForEach-Object { $_.Name })

if (Test-CommandExists 'git') {
    $null = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -eq 0) { $result.isGitRepo = $true }
}

$result | ConvertTo-Json -Depth 4
exit 0
