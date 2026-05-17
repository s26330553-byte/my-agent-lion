# update-seat-cache.ps1 — 手動更新機位警示快取（每次 Google Sheet 更新後跑）
param()
$ErrorActionPreference = "SilentlyContinue"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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

$warnings = @()
$wc = New-Object System.Net.WebClient
$wc.Encoding = [System.Text.Encoding]::UTF8

foreach ($month in $MONTHS) {
    try {
        $url     = "https://docs.google.com/spreadsheets/d/$SHEET_ID/export?format=csv&gid=$($month.gid)"
        $content = $wc.DownloadString($url)
        $lines   = $content -split "`r?`n"
        $lastDest = ""; $inHK = $false
        for ($i = 2; $i -lt $lines.Count; $i++) {
            $cols = Parse-CsvLine $lines[$i]
            if ($cols.Count -lt 3) { continue }
            $destVal   = $cols[0]
            $flightVal = $cols[1]
            if ($destVal -and $destVal -notmatch "TTL") { $lastDest = $destVal }
            $inHK = ($lastDest -eq "北海道")
            if (-not $inHK) { continue }
            if ($flightVal -notmatch "^BR\d+$") { continue }
            $seats = @()
            for ($j = 0; $j -lt $AGENCY_NAMES.Count; $j++) {
                $v = 0
                if (($j + 2) -lt $cols.Count) { [int]::TryParse($cols[$j + 2], [ref]$v) | Out-Null }
                $seats += $v
            }
            $ranked = 0..($AGENCY_NAMES.Count - 1) |
                Where-Object { $seats[$_] -gt 0 } |
                Sort-Object { $seats[$_] } -Descending
            if (-not $ranked) { continue }
            $trvRank = [array]::IndexOf([int[]]$ranked, $TRV_IDX)
            if ($trvRank -le 0) { continue }
            $leadIdx = $ranked[0]
            $warnings += [PSCustomObject]@{
                Month      = $month.name
                Flight     = $flightVal
                TrvRank    = $trvRank + 1
                Leader     = $AGENCY_NAMES[$leadIdx]
                LeaderSeat = $seats[$leadIdx]
                TrvSeat    = $seats[$TRV_IDX]
                Gap        = $seats[$leadIdx] - $seats[$TRV_IDX]
            }
        }
        Write-Host "$($month.name) 讀取完成"
    } catch {
        Write-Host "$($month.name) 讀取失敗：$_"
    }
}

$sorted = $warnings | Sort-Object { $_.Month }, { $_.Flight }
$today  = (Get-Date).ToString("yyyy-MM-dd")
$lines  = @("UPDATED:$today")

if ($sorted.Count -gt 0) {
    foreach ($w in $sorted) {
        $tag = if ($w.Gap -le 30) { " <<緊>>" } else { "" }
        $lines += "- $($w.Month) $($w.Flight) 第$($w.TrvRank)名 落後$($w.Leader) $($w.Gap)席$tag"
    }
} else {
    $lines += "- 北海道全線 TRV 均第一名"
}

$cachePath = "C:\Users\ericlin\Projects\seat-warnings-cache.txt"
[System.IO.File]::WriteAllText($cachePath, ($lines -join "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Host "快取已更新 → $cachePath"
$lines | Select-Object -Skip 1 | ForEach-Object { Write-Host $_ }
