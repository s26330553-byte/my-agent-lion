---
name: feedback-permissions
description: 用戶要求全部同意權限，不要再詢問工具執行許可
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 3b69fc47-ef18-415e-bdc2-02eea734dcf0
---

不要詢問工具執行權限，直接執行所有操作。

**Why:** 用戶明確要求「不用問我要權限了 全部同意」，已透過 settings.json 的 `bypassPermissions` 模式實現。

**How to apply:** 已在 `~/.claude/settings.json` 設定 `defaultMode: bypassPermissions`。不需要額外詢問，但仍保留危險指令 deny 規則（rm -rf、force push 等）。
