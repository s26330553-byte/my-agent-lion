# sync-health.ps1 — AI 分身週健康檢查腳本 (pro-kit 07)
# 每週五執行一次：cd E:\Data\ericlin\Data\my-agent; .\000_Agent\scripts\sync-health.ps1

param(
    [switch]$AutoCommit  # 加 -AutoCommit 參數可自動 commit 變更
)

$ErrorActionPreference = "Continue"
$myAgentDir = "E:\Data\ericlin\Data\my-agent"
$claudeDir   = "C:\Users\ericlin\.claude"
$issues = @()
$ok     = @()

Write-Host ""
Write-Host "======================================================"
Write-Host "  AI 分身 sync-health 週健康檢查"
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
Write-Host "======================================================"
Write-Host ""

# ── 1. junction 檢查 ──────────────────────────────────────────
Write-Host "[1] Junction / 連結狀態"

$junctions = @(
    @{ path = "$claudeDir\hooks";      target = "$myAgentDir\.claude\hooks";      label = "hooks/" },
    @{ path = "$claudeDir\skills";     target = "$myAgentDir\000_Agent\skills";   label = "skills/" }
)

foreach ($j in $junctions) {
    if (Test-Path $j.path) {
        $item = Get-Item $j.path -Force
        if ($item.Attributes -match "ReparsePoint") {
            Write-Host "  OK  $($j.label) junction 正常" -ForegroundColor Green
            $ok += $j.label
        } else {
            Write-Host "  !!  $($j.label) 存在但不是 junction（請手動檢查）" -ForegroundColor Yellow
            $issues += "$($j.label) 不是 junction"
        }
    } else {
        Write-Host "  XX  $($j.label) junction 不存在！" -ForegroundColor Red
        $issues += "$($j.label) junction 遺失"
    }
}

# ── 2. settings.json 同步檢查 ──────────────────────────────────
Write-Host ""
Write-Host "[2] settings.json 同步狀態"

$src  = "$claudeDir\settings.json"
$dest = "$myAgentDir\.claude\settings.json"

if ((Test-Path $src) -and (Test-Path $dest)) {
    $srcHash  = (Get-FileHash $src  -Algorithm MD5).Hash
    $destHash = (Get-FileHash $dest -Algorithm MD5).Hash
    if ($srcHash -eq $destHash) {
        Write-Host "  OK  settings.json 兩份一致" -ForegroundColor Green
        $ok += "settings.json"
    } else {
        Write-Host "  !!  settings.json 不同步，正在複製..." -ForegroundColor Yellow
        Copy-Item $src $dest -Force
        Write-Host "      已從 ~/.claude/ 更新至 my-agent/.claude/" -ForegroundColor Cyan
        $issues += "settings.json 已重新同步"
    }
} elseif (-not (Test-Path $src)) {
    Write-Host "  XX  ~/.claude/settings.json 不存在！" -ForegroundColor Red
    $issues += "~/.claude/settings.json 遺失"
} else {
    Write-Host "  !!  my-agent/.claude/settings.json 不存在，正在複製..." -ForegroundColor Yellow
    Copy-Item $src $dest -Force
    $issues += "settings.json 已初始同步"
}

# ── 3. Git 狀態 ───────────────────────────────────────────────
Write-Host ""
Write-Host "[3] Git 狀態"

$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
Set-Location $myAgentDir

$gitStatus = git status --porcelain 2>&1
if ($gitStatus) {
    $changedCount = ($gitStatus | Measure-Object).Count
    Write-Host "  !!  $changedCount 個未提交的變更" -ForegroundColor Yellow
    $gitStatus | ForEach-Object { Write-Host "      $_" }

    if ($AutoCommit) {
        git add .
        git commit -m "chore: weekly sync $(Get-Date -Format 'yyyy-MM-dd')"
        Write-Host "  OK  已自動 commit" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "      提示：執行 'git add . ; git commit' 或用 -AutoCommit 參數" -ForegroundColor DarkCyan
    }
    $issues += "$changedCount 個未提交變更"
} else {
    Write-Host "  OK  工作目錄乾淨（nothing to commit）" -ForegroundColor Green
    $ok += "git clean"
}

$remoteUrl = git remote get-url origin 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "  OK  Remote：$remoteUrl" -ForegroundColor Green
} else {
    Write-Host "  !!  尚未設定 GitHub remote（git remote add origin <url>）" -ForegroundColor Yellow
    $issues += "未設定 git remote"
}

# ── 4. 結果摘要 ──────────────────────────────────────────────
Write-Host ""
Write-Host "======================================================"
Write-Host "  結果摘要"
Write-Host "======================================================"
Write-Host "  通過：$($ok.Count) 項" -ForegroundColor Green
if ($issues.Count -gt 0) {
    Write-Host "  待處理：$($issues.Count) 項" -ForegroundColor Yellow
    $issues | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
} else {
    Write-Host "  一切正常！" -ForegroundColor Green
}
Write-Host ""
