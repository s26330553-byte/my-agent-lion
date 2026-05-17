# my-agent-lion — Eric 的 CC 完整備份

備份日期：2026-05-17

## 目錄結構

| 資料夾 | 內容 |
|--------|------|
| `claude-config/` | `~/.claude/` 設定檔：CLAUDE.md、settings.json、statusline 腳本、memory |
| `my-agent/` | `Documents/my-agent/` 全部：agent 知識庫、templates、skills、memory |
| `projects/` | `C:\Users\ericlin\Projects\` 腳本：daily-report、update-seat-cache 等 |

## 排除項目（含敏感資訊，不備份）

- `.credentials.json`（Anthropic API key）
- `settings.local.json`
- `projects/*.jsonl`（對話記錄）
- `cache/`、`paste-cache/`、`shell-snapshots/` 等暫存目錄
