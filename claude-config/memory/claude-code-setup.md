---
name: claude-code-setup
description: "Claude Code configuration details for this user - status line, safety settings, permission mode"
metadata: 
  node_type: memory
  type: project
  originSessionId: 110ef9bf-40c1-4dd1-82da-7f88ab6981be
---

User has completed Raymond Hou's Starter Kit setup on Windows 11 (no WSL).

## Status Line (Starter Kit #06)
- Script: `C:\Users\ericlin\.claude\statusline-command.ps1` (PowerShell version, UTF-8 BOM)
- Hook: `C:\Users\ericlin\.claude\hooks\session-time.ps1` (Taiwan UTC+8 timezone)
- Emoji: 🧋🍫, full Raymond config (model, context bar, 5h/7d rate limits, git, last msg time)
- Settings: statusLine + UserPromptSubmit hook in `~/.claude/settings.json`

## Safety Setup (Starter Kit #07-equivalent)
- Layer 1: `rm` → `trash-cli` (npm global install v7.2.0), alias in PowerShell profile
  - Profile: `E:\Data\ericlin\Data\WindowsPowerShell\Microsoft.PowerShell_profile.ps1`
  - `rm` = trash (recycle bin), `rmi` = Remove-Item (permanent)
- Layer 2: 20-item deny list in `~/.claude/settings.json`
- Layer 3: `defaultMode: "bypassPermissions"` (user confirmed this intentionally)

**Why:** User wants maximum efficiency, understands the deny list + trash protection provides safety floor.
**How to apply:** Don't suggest adding more permission prompts; user has deliberately chosen Bypass. If suggesting file operations, note they have trash protection.
