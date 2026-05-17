# Sync generic settings.json and CLAUDE.md from repo to ~/.claude/
# Detects repo root via junction resolution — no hardcoded paths
$hookJunction = Get-Item $PSScriptRoot
$repoRoot = Split-Path (Split-Path $hookJunction.Target -Parent) -Parent
$claudeDir = "$env:USERPROFILE\.claude"

Copy-Item "$repoRoot\.claude\settings.json" "$claudeDir\settings.json" -Force

$content = [System.IO.File]::ReadAllText("$repoRoot\CLAUDE.md", [System.Text.Encoding]::UTF8)
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$claudeDir\CLAUDE.md", $content, $utf8NoBom)
