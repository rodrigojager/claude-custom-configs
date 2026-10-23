<#
Installs this Claude Code setup on a Windows machine: the same plugins,
settings, status line, shortcut, MCP servers and tools. It carries no
credentials: whoever installs it signs in to Claude Code on their own.

One line:
  irm https://raw.githubusercontent.com/rodrigojager/claude-custom-configs/main/install.ps1 | iex

With options (tools and caches elsewhere, or a preview that changes nothing):
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/rodrigojager/claude-custom-configs/main/install.ps1))) -ToolsDir D:\tools -CacheDir D:\claude-cache -DryRun

Every file it replaces is copied first to ~/.claude/backups/setup-<date>.
Needs Git, Node.js and Claude Code already installed.
#>
param(
  [string]$ToolsDir = (Join-Path $HOME '.claude\tools'),
  [string]$CacheDir = (Join-Path $HOME '.claude\cache'),
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$claudeHome = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }
$repos = Join-Path $claudeHome 'repos'
$backup = Join-Path $claudeHome ("backups\setup-" + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$github = 'https://github.com/rodrigojager'
$warnings = New-Object System.Collections.Generic.List[string]

function Say([string]$text) { Write-Host "`n==> $text" -ForegroundColor Cyan }

# Runs a change, or only names it under -DryRun.
function Act([string]$what, [scriptblock]$do) {
  if ($DryRun) {
    Write-Host "    [dry run] $what" -ForegroundColor DarkGray
    return
  }
  Write-Host "    $what"
  & $do
}

function Warn([string]$text) {
  Write-Host "    ! $text" -ForegroundColor Yellow
  $warnings.Add($text)
}

function Has([string]$command) { [bool](Get-Command $command -ErrorAction SilentlyContinue) }

# Whether an MCP server is configured. Windows PowerShell stops on a native
# command's redirected stderr under 'Stop', so the check runs under 'Continue'.
function Has-Mcp([string]$name) {
  $ErrorActionPreference = 'Continue'
  claude mcp get $name *> $null
  return $LASTEXITCODE -eq 0
}

function Sync-Repo([string]$name) {
  $dir = Join-Path $repos $name
  if (Test-Path (Join-Path $dir '.git')) {
    Act "update $dir" { git -C $dir pull --ff-only | Out-Host }
  } else {
    Act "clone $github/$name into $dir" {
      New-Item -ItemType Directory -Force $repos | Out-Null
      git clone "$github/$name" $dir | Out-Host
    }
  }
  return $dir
}

Say 'Checking what is needed'
foreach ($tool in 'git', 'node', 'npm', 'claude') {
  if (-not (Has $tool)) {
    throw "$tool was not found. Install Git for Windows, Node.js and Claude Code (irm https://claude.ai/install.ps1 | iex) first."
  }
}
$hasHerdr = (Has 'herdr') -or (Test-Path (Join-Path $env:APPDATA 'herdr'))
Write-Host "    tools: $ToolsDir"
Write-Host "    caches: $CacheDir"
Write-Host "    Herdr: $(if ($hasHerdr) { 'found, its pieces are included' } else { 'not found, its pieces are left out' })"

Say "Repositories in $repos"
$configs = if ($PSScriptRoot -and (Test-Path (Join-Path $PSScriptRoot 'claude\settings.json'))) { $PSScriptRoot } else { Sync-Repo 'claude-custom-configs' }
$roles = Sync-Repo 'claude-roles'

Say "Backing up what will be replaced, to $backup"
$targets = @(
  (Join-Path $claudeHome 'settings.json'),
  (Join-Path $claudeHome 'keybindings.json'),
  (Join-Path $claudeHome 'CLAUDE.md'),
  (Join-Path $claudeHome 'plugins\claude-hud\config.json'),
  (Join-Path $claudeHome 'roles-mod\statusline.mjs'),
  (Join-Path $claudeHome 'roles-mod\statusline.cmd'),
  (Join-Path $env:APPDATA 'herdr\config.toml')
)
foreach ($file in $targets) {
  if (Test-Path $file) {
    Act "back up $file" {
      $copy = Join-Path $backup ($file.Substring([IO.Path]::GetPathRoot($file).Length))
      New-Item -ItemType Directory -Force (Split-Path $copy) | Out-Null
      Copy-Item $file $copy
    }
  }
}

Say 'Claude Code settings, shortcut and instructions'
Act 'write settings.json with this machine''s paths' {
  $argv = @(
    (Join-Path $configs 'setup\apply-settings.mjs'),
    '--template', (Join-Path $configs 'claude\settings.json'),
    '--out', (Join-Path $claudeHome 'settings.json'),
    '--home', $HOME, '--tools', $ToolsDir, '--cache', $CacheDir, '--repos', $repos
  )
  if ($hasHerdr) { $argv += '--herdr' }
  node @argv
  if ($LASTEXITCODE -ne 0) { throw 'settings.json could not be written' }
}
Act 'add Alt+R (/role) to keybindings.json, keeping existing shortcuts' {
  node (Join-Path $configs 'setup\merge-text.mjs') keybindings (Join-Path $configs 'claude\keybindings.json') (Join-Path $claudeHome 'keybindings.json')
}
Act 'add the zvec-grep instructions to CLAUDE.md, keeping the rest' {
  node (Join-Path $configs 'setup\merge-text.mjs') claude-md (Join-Path $configs 'claude\CLAUDE.md') (Join-Path $claudeHome 'CLAUDE.md')
}
Act 'claude-hud layout' {
  $to = Join-Path $claudeHome 'plugins\claude-hud\config.json'
  New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
  Copy-Item (Join-Path $configs 'claude\plugins\claude-hud\config.json') $to
}
Act 'status line wrapper (claude-hud plus the role badge)' {
  $dir = Join-Path $claudeHome 'roles-mod'
  New-Item -ItemType Directory -Force $dir | Out-Null
  Copy-Item (Join-Path $roles 'statusline\statusline.mjs') $dir
  $node = (Get-Command node).Source
  [IO.File]::WriteAllText((Join-Path $dir 'statusline.cmd'), "@echo off`r`n`"$node`" `"%~dp0statusline.mjs`"`r`n")
}
if ($hasHerdr) {
  Act 'Herdr config (agents sidebar row with model, effort and role)' {
    $to = Join-Path $env:APPDATA 'herdr\config.toml'
    New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
    Copy-Item (Join-Path $configs 'herdr\config.toml') $to
  }
  if (-not (Test-Path (Join-Path $claudeHome 'hooks\herdr-agent-state.ps1'))) {
    Warn 'Herdr''s Claude hook is missing: install Herdr''s Claude integration so its SessionStart hook has a script to run.'
  }
}

Say 'Plugins'
$marketplaces = @('jarrodwatts/claude-hud', 'veelenga/claude-mermaid', 'backnotprop/plannotator', (Join-Path $repos 'claude-roles'))
foreach ($market in $marketplaces) {
  Act "marketplace $market" { claude plugin marketplace add $market | Out-Host }
}
foreach ($plugin in 'claude-hud@claude-hud', 'claude-mermaid@claude-mermaid', 'plannotator@plannotator', 'roles@claude-roles') {
  Act "plugin $plugin" {
    claude plugin install $plugin --scope user | Out-Host
    if ($LASTEXITCODE -ne 0) { Warn "$plugin did not install; run: claude plugin install $plugin --scope user" }
  }
}

Say 'Tools'
if ((Has 'plannotator') -or (Test-Path (Join-Path $env:LOCALAPPDATA 'plannotator\plannotator.exe'))) {
  Write-Host '    plannotator CLI already installed'
} else {
  Act 'plannotator CLI (its official installer)' {
    powershell -NoProfile -ExecutionPolicy Bypass -Command 'irm https://plannotator.ai/install.ps1 | iex' | Out-Host
  }
}

if (Has 'zg') {
  Write-Host '    zvec-grep already installed'
} else {
  Act 'zvec-grep (npm install -g @zvec/zvec-grep)' { npm install -g '@zvec/zvec-grep' | Out-Host }
}

$dejaDir = Join-Path $ToolsDir 'deja-vu'
$deja = Join-Path $dejaDir 'deja.exe'
if (Test-Path $deja) {
  Write-Host "    deja-vu already in $dejaDir"
} else {
  Act "deja-vu, latest release, checksum verified, into $dejaDir" {
    $release = Invoke-RestMethod 'https://api.github.com/repos/vshulcz/deja-vu/releases/latest'
    $zip = $release.assets | Where-Object { $_.name -like '*windows_amd64.zip' } | Select-Object -First 1
    $sums = $release.assets | Where-Object { $_.name -eq 'checksums.txt' } | Select-Object -First 1
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ('deja-' + [guid]::NewGuid())
    New-Item -ItemType Directory -Force $tmp | Out-Null
    $zipFile = Join-Path $tmp $zip.name
    Invoke-WebRequest $zip.browser_download_url -OutFile $zipFile -UseBasicParsing
    Invoke-WebRequest $sums.browser_download_url -OutFile (Join-Path $tmp 'checksums.txt') -UseBasicParsing
    $expected = (Select-String -Path (Join-Path $tmp 'checksums.txt') -Pattern ([regex]::Escape($zip.name) + '$')).Line.Split(' ')[0]
    if ((Get-FileHash $zipFile -Algorithm SHA256).Hash -ne $expected.ToUpper()) { throw 'deja-vu download failed its checksum' }
    New-Item -ItemType Directory -Force $dejaDir | Out-Null
    Expand-Archive $zipFile -DestinationPath $dejaDir -Force
    Remove-Item -Recurse -Force $tmp
  }
}
Act "put $dejaDir on the user PATH" {
  $path = [Environment]::GetEnvironmentVariable('Path', 'User')
  if (($path -split ';') -notcontains $dejaDir) {
    [Environment]::SetEnvironmentVariable('Path', ($path.TrimEnd(';') + ";$dejaDir"), 'User')
  }
}

Say 'MCP servers'
Act 'zvec_grep' {
  if (-not (Has-Mcp 'zvec_grep')) { claude mcp add -s user zvec_grep -- zg server --stdio | Out-Host }
}
Act 'deja (deja install claude-code: MCP and its skill; the hooks are already in settings.json)' {
  & $deja install claude-code --no-index | Out-Host
}
$wmux = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'wmux\app-*\resources\mcp-bundle\index.js') -ErrorAction SilentlyContinue |
  Sort-Object FullName -Descending | Select-Object -First 1
if ($wmux) {
  Act "wmux ($($wmux.FullName))" {
    if (-not (Has-Mcp 'wmux')) { claude mcp add -s user wmux -- node $wmux.FullName | Out-Host }
  }
}

Say 'Done'
if ($DryRun) { Write-Host '    Dry run: nothing was changed.' }
foreach ($text in $warnings) { Write-Host "    ! $text" -ForegroundColor Yellow }
Write-Host @"
    Next:
    - Open a new terminal (PATH changed) and start Claude Code; sign in if asked.
    - Index past sessions for deja: deja index
    - /role or Alt+R picks a role; the badge shows next to the model in the status line.
"@
