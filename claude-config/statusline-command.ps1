# Claude Code Status Line (PowerShell / Windows)
# Based on Raymond Hou Starter Kit #06 - https://cc.lifehacker.tw

# Display settings (change true/false to toggle fields)
$EMOJI_STR        = ""  # Set emoji in line below
$FILLED_BLOCK     = [char]9608      # U+2588 full block
$LIGHT_SHADE      = [char]9617      # U+2591 light shade
$BOX_VERT         = [char]9474      # U+2502 box vertical
$MEMO_ICON        = [char]::ConvertFromUtf32(0x1F4DD)   # memo emoji
$TEA_ICON         = [char]::ConvertFromUtf32(0x1F9CB)   # milk tea
$CHOCO_ICON       = [char]::ConvertFromUtf32(0x1F36B)   # chocolate
$EMOJI_STR        = $TEA_ICON + $CHOCO_ICON

$SHOW_MODEL       = $true
$SHOW_CONTEXT_BAR = $true
$SHOW_RATE_5H     = $true
$SHOW_RATE_7D     = $true
$SHOW_GIT_BRANCH  = $true
$SHOW_GIT_DIFF    = $true
$SHOW_PROJECT     = $true
$SHOW_LAST_MSG    = $true
$LAST_MSG_FILE    = "$env:USERPROFILE\.claude\last-session-msg"

# ANSI colors
$E   = [char]27
$WH  = "${E}[97m"
$GR  = "${E}[38;2;80;200;81m"
$YL  = "${E}[38;2;255;235;59m"
$OG  = "${E}[38;2;255;152;0m"
$RD  = "${E}[38;2;244;67;54m"
$MD  = "${E}[38;2;246;184;90m"
$DM  = "${E}[90m"
$RS  = "${E}[0m"
$SEP = "${DM} ${BOX_VERT} ${RS}"

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Read JSON from Claude Code stdin
$json = [Console]::In.ReadToEnd()
$data = $null
try { $data = $json | ConvertFrom-Json } catch { }

$model     = if ($data -and $data.model.display_name)                               { $data.model.display_name } else { "" }
$remaining = if ($data -and ($null -ne $data.context_window.remaining_percentage))  { $data.context_window.remaining_percentage } else { $null }
$rl5hPct   = if ($data -and ($null -ne $data.rate_limits.five_hour.used_percentage)) { $data.rate_limits.five_hour.used_percentage } else { $null }
$rl5hReset = if ($data -and ($null -ne $data.rate_limits.five_hour.resets_at))       { $data.rate_limits.five_hour.resets_at } else { $null }
$rl7dPct   = if ($data -and ($null -ne $data.rate_limits.seven_day.used_percentage)) { $data.rate_limits.seven_day.used_percentage } else { $null }
$rl7dReset = if ($data -and ($null -ne $data.rate_limits.seven_day.resets_at))       { $data.rate_limits.seven_day.resets_at } else { $null }

function Get-Countdown($epochSec) {
    if (-not $epochSec) { return "" }
    $s = $epochSec - [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($s -le 0) { return "0m" }
    $d = [math]::Floor($s / 86400)
    $h = [math]::Floor(($s % 86400) / 3600)
    $m = [math]::Floor(($s % 3600) / 60)
    if ($d -gt 0) { return "${d}D${h}H" }
    if ($h -gt 0) { return "${h}H${m}m" }
    return "${m}m"
}

function Get-RateColor($pct) {
    if ($pct -gt 75) { return $GR }
    if ($pct -gt 50) { return $YL }
    if ($pct -gt 25) { return $OG }
    return $RD
}

# LINE 1
$L1parts = @()
if ($SHOW_MODEL -and $model) { $L1parts += "${MD}${model}${RS}" }

if ($SHOW_CONTEXT_BAR -and $null -ne $remaining) {
    $pct    = [int][math]::Round($remaining)
    $used   = 100 - $pct
    $BAR_W  = 12
    $filled = [int]($used * $BAR_W / 100)
    $z1 = [int]($BAR_W / 4); $z2 = [int]($BAR_W / 2); $z3 = [int]($BAR_W * 3 / 4)
    $bar = ""
    for ($n = 0; $n -lt $BAR_W; $n++) {
        if ($n -lt $filled) {
            if      ($n -lt $z1) { $bar += "${GR}$FILLED_BLOCK" }
            elseif  ($n -lt $z2) { $bar += "${YL}$FILLED_BLOCK" }
            elseif  ($n -lt $z3) { $bar += "${OG}$FILLED_BLOCK" }
            else                  { $bar += "${RD}$FILLED_BLOCK" }
        } else { $bar += "${DM}$LIGHT_SHADE" }
    }
    $bar += $RS
    $pc = if ($used -gt 80) { $RD } else { $WH }
    $L1parts += "${bar} ${pc}${used}%${RS}"
}

if ($SHOW_RATE_5H -and $null -ne $rl5hPct) {
    $r = 100 - [int][math]::Round($rl5hPct)
    $t = Get-Countdown $rl5hReset
    $c = Get-RateColor $r
    $L1parts += "${WH}${t} ${c}${r}%${RS}"
}

if ($SHOW_RATE_7D -and $null -ne $rl7dPct) {
    $r = 100 - [int][math]::Round($rl7dPct)
    $t = Get-Countdown $rl7dReset
    $c = Get-RateColor $r
    $L1parts += "${WH}${t} ${c}${r}%${RS}"
}

$L1 = if ($L1parts.Count -gt 0) { $L1parts -join $SEP } else { "" }
if ($EMOJI_STR) { $L1 = "$EMOJI_STR $L1" }

# Git info
$br = ""; $dirty = ""; $ds = ""; $pname = ""
$hasGit = $null -ne (Get-Command git -ErrorAction SilentlyContinue)
$gitTop = if ($hasGit) { git rev-parse --show-toplevel 2>$null } else { $null }
if ($hasGit -and $LASTEXITCODE -eq 0 -and $gitTop) {
    $br = git branch --show-current 2>$null
    git diff-index --quiet HEAD -- 2>$null
    if ($LASTEXITCODE -ne 0) { $dirty = "*" }
    if (-not $dirty) {
        $untracked = git ls-files --others --exclude-standard 2>$null | Select-Object -First 1
        if ($untracked) { $dirty = "*" }
    }
    $stat = git diff --shortstat HEAD 2>$null
    if ($stat) {
        $ins = if ($stat -match '(\d+) insertion') { $Matches[1] } else { "" }
        $del = if ($stat -match '(\d+) deletion')  { $Matches[1] } else { "" }
        if ($ins -or $del) {
            if ($ins) { $ds += "${GR}+${ins}${RS}" }
            if ($ins -and $del) { $ds += "${DM}/${RS}" }
            if ($del) { $ds += "${RD}-${del}${RS}" }
        }
    }
    $pname = Split-Path $gitTop -Leaf
}

$lastMsg = ""
if ($SHOW_LAST_MSG -and (Test-Path $LAST_MSG_FILE)) {
    $lastMsg = (Get-Content $LAST_MSG_FILE -Raw -Encoding utf8 -ErrorAction SilentlyContinue)
    if ($lastMsg) { $lastMsg = $lastMsg.Trim() }
}

# LINE 2
$L2parts = @()
if ($SHOW_GIT_BRANCH -and $br)       { $L2parts += "${WH}${br}${dirty}${RS}" }
if ($SHOW_GIT_DIFF   -and $ds)       { $L2parts += $ds }
if ($SHOW_PROJECT    -and $pname)    { $L2parts += "${WH}${pname}${RS}" }
if ($SHOW_LAST_MSG   -and $lastMsg)  { $L2parts += "${DM}${MEMO_ICON} ${lastMsg}${RS}" }
$L2 = if ($L2parts.Count -gt 0) { $L2parts -join $SEP } else { "" }

# Output
Write-Host $L1
if ($L2) { Write-Host $L2 }

