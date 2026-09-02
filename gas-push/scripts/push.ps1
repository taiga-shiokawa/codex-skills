#Requires -Version 5.1
<#
.SYNOPSIS
  Runs clasp push with confirmation guards and returns JSON.
#>
[CmdletBinding()]
param(
    [switch]$Confirmed,
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$result = [ordered]@{
    pushed     = $false
    exitCode   = $null
    needsForce = $false
    output     = $null
    notes      = @()
}

if (-not $Confirmed) {
    $result.notes += 'Refusing to push: -Confirmed was not set. Inspect and present filesToPush first, then follow the skill confirmation rules.'
    $result | ConvertTo-Json -Depth 4
    exit 0
}

if (-not (Test-Path -LiteralPath '.clasp.json')) {
    $result.notes += 'No .clasp.json in the current directory - nothing to push.'
    $result | ConvertTo-Json -Depth 4
    exit 0
}

if ($Force) {
    $output = (clasp push -f | Out-String)
} else {
    $output = (clasp push | Out-String)
}
$result.exitCode = $LASTEXITCODE

$trimmedOutput = ''
if ($output) { $trimmedOutput = $output.Trim() }
$result.output = $trimmedOutput

if ($LASTEXITCODE -eq 0) {
    $result.pushed = $true
    if ($trimmedOutput -match 'Pushed\s+(\d+)\s+files') {
        $result.notes += ('Pushed file count: ' + $Matches[1])
    }
} else {
    if (-not $Force -and ($trimmedOutput -match 'manifest' -or [string]::IsNullOrWhiteSpace($trimmedOutput))) {
        $result.needsForce = $true
        $result.notes += 'Push did not complete. A changed manifest may require interactive confirmation. Explain the local manifest changes and obtain explicit approval before retrying with -Force.'
    } else {
        $result.notes += 'clasp push failed. Check output for syntax, access, configuration, or network errors.'
    }
}

$result | ConvertTo-Json -Depth 4
exit 0
