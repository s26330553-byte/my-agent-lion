# daily-report.ps1
param()
$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$LINE_TOKEN   = [System.Environment]::GetEnvironmentVariable("LINE_CHANNEL_ACCESS_TOKEN", "User")
if (-not $LINE_TOKEN) { $LINE_TOKEN = $env:LINE_CHANNEL_ACCESS_TOKEN }
$LINE_USER_ID = "U6a66d105ece115724eb6d9ebd3ebaf4a"
$GWS          = "C:\Users\ericlin\nodejs\node-v22.15.0-win-x64\node_modules\@googleworkspace\cli\bin\gws.exe"
$NETLIFY_URL  = "https://rad-boba-c86be3.netlify.app/"

$SHEET_ID = "1S8-cPyo0W2FTwIFZTQCnjdDwVIhCr9mMcj60DImgjiY"
$MONTHS   = @(
    [PSCustomObject]@{ name="5月";  gid=0 },
    [PSCustomObject]@{ name="6月";  gid=1589094253 },
    [PSCustomObject]@{ name="7月";  gid=687426744 },
    [PSCustomObject]@{ name="8月";  gid=1439940775 },
    [PSCustomObject]@{ name="9月";  gid=2107263843 }
)
$AGENCY_NAMES = @('AHY','DAS','CFT','LIF','SET','SIG','TRV','百威','世邦','民生','加利利','山富')
$TRV_IDX = 6

function Parse-CsvLine([string]$line) {
    $cols = @(); $cur = ""; $inQ = $false
    foreach ($ch in $line.ToCharArray()) {
        if ($ch -eq '"') { $inQ = !$inQ }
        elseif ($ch -eq ',' -and -not $inQ) { $cols += $cur.Trim(); $cur = "" }
        else { $cur += $ch }
    }
    $cols += $cur.Trim()
    return $cols
}

function Get-SeatWarningsFromCache {
    $cachePath = "C:\Users\ericlin\Projects\seat-warnings-cache.txt"
    $result = @{ Lines = @(); UpdatedDate = "" }
    if (-not (Test-Path $cachePath)) { return $result }
    $raw = Get-Content $cachePath -Encoding UTF8
    foreach ($line in $raw) {
        if ($line -match "^UPDATED:(.+)$") { $result.UpdatedDate = $Matches[1].Trim() }
        elseif ($line -match "^-\s") { $result.Lines += $line }
    }
    return $result
}

function Get-TodayEvents {
    $lines = @()
    try {
        $today    = (Get-Date).ToString("yyyy-MM-dd")
        $tomorrow = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
        $raw  = cmd /c "`"$GWS`" calendar events list --params `"{`\`"calendarId`\`":`\`"primary`\`",`\`"maxResults`\`":10,`\`"timeMin`\`":`\`"${today}T00:00:00+08:00`\`",`\`"timeMax`\`":`\`"${tomorrow}T00:00:00+08:00`\`",`\`"singleEvents`\`":true,`\`"orderBy`\`":`\`"startTime`\`"}`""
        $json = ($raw | Where-Object { $_ -notmatch "keyring" }) -join "" | ConvertFrom-Json
        foreach ($ev in $json.items) {
            $time = if ($ev.start.dateTime) { ([datetime]$ev.start.dateTime).ToString("HH:mm") } else { "整天" }
            $lines += "- $time $($ev.summary)"
        }
    } catch {}
    return $lines
}

$dateStr  = (Get-Date).ToString("yyyy-MM-dd")
$dayName  = (Get-Date).DayOfWeek.ToString().Substring(0,3)
$seatCache = Get-SeatWarningsFromCache
$calList  = Get-TodayEvents

$msg = "[早報] $dateStr ($dayName)`n`n"

$msg += "[行事曆]`n"
if ($calList.Count -gt 0) { $msg += ($calList -join "`n") + "`n" }
else { $msg += "- 今日無排定行程`n" }

$cacheLabel = if ($seatCache.UpdatedDate) { "（資料更新：$($seatCache.UpdatedDate)）" } else { "" }
$msg += "`n[長榮北海道警示]$cacheLabel`n"
if ($seatCache.Lines.Count -gt 0) {
    $msg += ($seatCache.Lines -join "`n") + "`n"
} else {
    $msg += "- 無快取資料`n"
}

$msg += "`n報表: $NETLIFY_URL"

# 存快取，供 CC SessionStart hook 讀取
$cachePath = "C:\Users\ericlin\Projects\daily-report-cache.txt"
[System.IO.File]::WriteAllText($cachePath, $msg, [System.Text.UTF8Encoding]::new($false))

$body = @{
    to       = $LINE_USER_ID
    messages = @(@{ type = "text"; text = $msg })
} | ConvertTo-Json -Depth 5

Invoke-RestMethod -Uri "https://api.line.me/v2/bot/message/push" `
    -Method Post `
    -Headers @{ Authorization = "Bearer $LINE_TOKEN"; "Content-Type" = "application/json" } `
    -Body ([System.Text.Encoding]::UTF8.GetBytes($body)) | Out-Null

Write-Output "Done $(Get-Date -Format 'HH:mm')"