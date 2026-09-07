[CmdletBinding()]
param(
    [string]$Project = (Get-Location).Path,
    [string]$Prompt = '',
    [switch]$InstallOnly,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$skillRoot = Split-Path -Parent $PSScriptRoot
$projectItem = Get-Item -LiteralPath $Project -ErrorAction Stop
if (-not $projectItem.PSIsContainer) { throw 'Project must be a directory.' }
$projectRoot = $projectItem.FullName
$taskCodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$taskCodexHome = [IO.Path]::GetFullPath($taskCodexHome)
$agentDirectory = Join-Path $taskCodexHome 'agents'
$agentNames = @('dev-orch-luna', 'dev-orch-terra', 'dev-orch-sol', 'dev-orch-astra')
$pendingCopies = @()

# Validate all assets and conflicts before making any changes.
foreach ($agentName in $agentNames) {
    $source = Join-Path $skillRoot "assets/agents/$agentName.toml"
    $target = Join-Path $agentDirectory "$agentName.toml"
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing agent asset: $source" }
    if (Test-Path -LiteralPath $target) {
        if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Agent path is not a file: $target" }
        if ((Get-FileHash -LiteralPath $source).Hash -ne (Get-FileHash -LiteralPath $target).Hash) {
            throw "Existing agent differs; review it before replacing: $target"
        }
    } else {
        $pendingCopies += [pscustomobject]@{ Source = $source; Target = $target }
    }
}

$initialPrompt = 'Use $dev-orchestrator for this session. Read its SKILL.md at: ' +
    (Join-Path $skillRoot 'SKILL.md') +
    '. Delegate bounded work to the configured model-specific subagents and keep orchestration in the parent. For questions use Luna, implementation Terra, documents/design Sol, and unresolved Sol problems Astra as specified in the skill.'
if ($Prompt) { $initialPrompt += "`n`nUser task:`n" + $Prompt }
else { $initialPrompt += ' No development task has been supplied yet; load the skill and wait for my task.' }

$codexArguments = @(
    '-C', $projectRoot,
    '-m', 'gpt-5.6-luna',
    '-c', 'model_reasoning_effort="medium"',
    '-c', 'agents.enabled=true',
    '-c', 'agents.max_concurrent_threads_per_session=2',
    '-c', 'agents.default_subagent_model="gpt-5.6-luna"',
    '-c', 'agents.default_subagent_reasoning_effort="medium"',
    $initialPrompt
)

if ($DryRun) {
    [pscustomobject]@{
        Project = $projectRoot
        ParentModel = 'gpt-5.6-luna'
        AgentDirectory = $agentDirectory
        AgentsToInstall = @($pendingCopies | ForEach-Object { $_.Target })
        Arguments = $codexArguments
        InstallOnly = [bool]$InstallOnly
    }
    return
}

if (-not $InstallOnly) {
    # Use PowerShell's npm shim or a native executable, never a command string.
    $codexCommand = Get-Command codex.ps1, codex.exe -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $codexCommand) { throw 'Codex CLI was not found. Install Codex CLI and sign in first.' }
}

if ($pendingCopies.Count -gt 0) {
    New-Item -ItemType Directory -Path $agentDirectory -Force | Out-Null
    foreach ($copy in $pendingCopies) {
        # File.Copy fails if a competing process created the target in the meantime.
        [IO.File]::Copy($copy.Source, $copy.Target, $false)
    }
}

if ($InstallOnly) {
    Write-Output "Model-specific agents are installed in: $agentDirectory"
    return
}

& $codexCommand.Source @codexArguments
if ($LASTEXITCODE -ne 0) { throw "Codex exited with code $LASTEXITCODE" }
