---
name: feedback-persistence
description: 所有設定、工具、token 都必須寫入永久檔案，重啟 CC 後仍然存在
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ea36e7ae-2a1c-455c-9a02-d22d9b444a8e
---

任何設定完的東西都必須確保寫入永久檔案，重啟 CC 後仍然有效。

**Why:** 使用者明確要求：「以後我做的任何事重啟後輸入 CC 都要在」

**How to apply:**
- Token、環境變數 → 寫入 `~/.claude/settings.json` 的 `env` 區塊
- 工具使用說明、路徑、userId → 寫入 `~/.claude/CLAUDE.md`
- MCP server 設定 → 寫入 `~/.claude.json` 的 `mcpServers`
- 規則、偏好 → 寫入 `~/.claude/CLAUDE.md` 的對應區塊
- 完成設定後主動告知使用者「已寫入永久設定，重啟後仍有效」
- 不能只是在對話裡說明步驟，要實際把設定寫入檔案
