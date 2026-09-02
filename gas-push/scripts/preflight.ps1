#Requires -Version 5.1
<#
.SYNOPSIS
  gas-push preflight. Returns clasp auth, config, and push status as JSON.
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
    claspInstalled = $false
    loggedIn       = $false
    authUser       = $null
    hasClaspJson   = $false
    scriptId       = $null
    filesToPush    = @()
    untrackedFiles = @()
    warnings       = @()
    notes          = @()
}

if (-not (Test-CommandExists 'clasp')) {
    $result.notes += 'clasp not found. Suggest: npm install -g @google/clasp'
    $result | ConvertTo-Json -Depth 5
    exit 0
}
$result.claspInstalled = $true

$authOutput = (clasp show-authorized-user | Out-String)
if ($LASTEXITCODE -eq 0 -and $authOutput -match 'logged in as\s+(\S+)') {
    $result.loggedIn = $true
    $result.authUser = $Matches[1].TrimEnd('.')
} else {
    $result.notes += 'Not logged in to clasp. The user must run clasp login and complete browser authentication.'
}

if (-not (Test-Path -LiteralPath '.clasp.json')) {
    $result.notes += 'No .clasp.json in the current directory. This is not a cloned clasp project.'
    $result | ConvertTo-Json -Depth 5
    exit 0
}
$result.hasClaspJson = $true

try {
    $config = Get-Content -LiteralPath '.clasp.json' -Raw | ConvertFrom-Json
    $result.scriptId = $config.scriptId
} catch {
    $result.notes += 'Could not parse .clasp.json.'
}

$statusJson = (clasp status --json | Out-String)
if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($statusJson)) {
    try {
        $status = $statusJson | ConvertFrom-Json
        $result.filesToPush = @($status.filesToPush)
        $result.untrackedFiles = @($status.untrackedFiles)
    } catch {
        $result.warnings += 'Could not parse clasp status --json output.'
    }
} else {
    $result.warnings += 'clasp status failed.'
}

if (@($result.filesToPush).Count -eq 0) {
    $result.warnings += 'filesToPush is empty - nothing would be pushed.'
}

$result | ConvertTo-Json -Depth 5
exit 0
