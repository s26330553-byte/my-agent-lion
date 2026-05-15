# Session Time Hook (Taiwan UTC+8)
# Writes last-message timestamp for statusline-command.ps1
$tz = [TimeZoneInfo]::FindSystemTimeZoneById('Taipei Standard Time')
$ts = [TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $tz)
$ts.ToString('yyyy-MM-dd HH:mm') | Set-Content "$env:USERPROFILE\.claude\last-session-msg" -NoNewline -Encoding utf8
