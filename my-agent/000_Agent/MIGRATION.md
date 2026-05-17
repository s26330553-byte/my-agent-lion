# MIGRATION.md — AI 分身跨裝置遷移手冊

> 建立日期：2026-05-15｜pro-kit 07

## 這份文件的用途

當你要在**新電腦**重新建起這整套 AI 分身時，照這裡的步驟做。

---

## 前置需求

| 工具 | 安裝指令 |
|:---|:---|
| Git | `winget install Git.Git` |
| Node.js (LTS) | `winget install OpenJS.NodeJS.LTS` |
| Claude Code CLI | `npm install -g @anthropic-ai/claude-code` |

---

## 步驟 1：Clone GitHub repo

```powershell
git clone https://github.com/<你的帳號>/my-agent.git "E:\Data\ericlin\Data\my-agent"
```

> 路徑可以依新機器的實際情況調整，但要同步更新下面所有路徑。

---

## 步驟 2：建立 Junction / Symlink

```powershell
# hooks/ junction（不需管理員）
cmd /c "mklink /J `"C:\Users\<新帳號>\.claude\hooks`" `"E:\Data\ericlin\Data\my-agent\.claude\hooks`""

# skills/ junction（不需管理員）
cmd /c "mklink /J `"C:\Users\<新帳號>\.claude\skills`" `"E:\Data\ericlin\Data\my-agent\000_Agent\skills`""
```

---

## 步驟 3：同步 settings.json

```powershell
Copy-Item "E:\Data\ericlin\Data\my-agent\.claude\settings.json" "C:\Users\<新帳號>\.claude\settings.json"
```

---

## 步驟 4：重新安裝 MCP 工具

在 `~/.claude.json` 加回 mcpServers 區塊（參考原機器的備份或 README）。

需要的 API 金鑰：
- Firecrawl API Key（重新申請或從 1Password 取得）
- Google OAuth client secret（從 Google Cloud Console 重新下載）

---

## 步驟 5：驗證

```powershell
cd "E:\Data\ericlin\Data\my-agent"
.\000_Agent\scripts\sync-health.ps1
```

全部顯示綠色 OK = 完成。

---

## 每週維護（每週五）

```powershell
cd "E:\Data\ericlin\Data\my-agent"
.\000_Agent\scripts\sync-health.ps1 -AutoCommit
git push
```

---

## 架構速覽

```
C:\Users\ericlin\.claude\
  ├── settings.json          ← 本機複本（my-agent/.claude/settings.json 的同步版）
  ├── hooks/                 ← Junction → my-agent/.claude/hooks/
  ├── skills/                ← Junction → my-agent/000_Agent/skills/
  └── settings.local.json    ← 本機專屬（不進 git）

E:\Data\ericlin\Data\my-agent\
  ├── CLAUDE.md              ← AI 分身核心規則
  ├── .gitignore
  ├── .claude/
  │   ├── settings.json      ← 正本（進 git）
  │   └── hooks/             ← Hook 腳本（進 git）
  ├── 000_Agent/
  │   ├── memory/            ← 記憶系統
  │   ├── skills/            ← Skills（被 ~/.claude/skills junction 指向）
  │   ├── scripts/           ← sync-health.ps1 等維護腳本
  │   └── MIGRATION.md       ← 本文件
  ├── 100_Todo/              ← 草稿、專案、封存
  ├── 200_Reference/         ← 寫作範本、競業資料、模板
  └── 300_Journal/           ← 每日反思日記
```
