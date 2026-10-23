# Restores these configs into this machine's Claude Code and Herdr folders.
# Every file it replaces is kept beside itself as <name>.bak-<timestamp>.
# Run with -WhatIf first to see what it would copy.
param([switch]$WhatIf)

$ErrorActionPreference = 'Stop'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$claude = if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $HOME '.claude' }

$files = @(
  @('claude\settings.json', (Join-Path $claude 'settings.json')),
  @('claude\keybindings.json', (Join-Path $claude 'keybindings.json')),
  @('claude\CLAUDE.md', (Join-Path $claude 'CLAUDE.md')),
  @('claude\plugins\claude-hud\config.json', (Join-Path $claude 'plugins\claude-hud\config.json')),
  @('herdr\config.toml', (Join-Path $env:APPDATA 'herdr\config.toml'))
)

foreach ($file in $files) {
  $from = Join-Path $PSScriptRoot $file[0]
  $to = $file[1]
  if ($WhatIf) {
    "would copy $from -> $to"
    continue
  }
  New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
  if (Test-Path $to) { Copy-Item $to "$to.bak-$stamp" }
  Copy-Item $from $to
  "restored $to"
}

'MCP servers are not copied: add them with the commands in README.md.'
