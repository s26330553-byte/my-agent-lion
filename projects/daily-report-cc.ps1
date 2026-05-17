# daily-report-cc.ps1 — SessionStart hook 用，讀快取輸出 systemMessage JSON
param()
$cachePath = "C:\Users\ericlin\Projects\daily-report-cache.txt"

if (Test-Path $cachePath) {
    $content  = [System.IO.File]::ReadAllText($cachePath, [System.Text.Encoding]::UTF8).Trim()
    $cacheAge = [int]((Get-Date) - (Get-Item $cachePath).LastWriteTime).TotalHours
    $ageNote  = if ($cacheAge -ge 24) { " (報告已 $cacheAge 小時前生成)" } else { "" }
    $output   = @{ systemMessage = "$content$ageNote" }
} else {
    $output = @{ systemMessage = "[每日早報] 快取尚不存在，今日 8:00 排程執行後會自動生成。" }
}

$output | ConvertTo-Json -Compress