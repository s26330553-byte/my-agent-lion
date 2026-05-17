$node = "C:\Users\ericlin\nodejs\node-v22.15.0-win-x64\node.exe"
$runjs = "C:\Users\ericlin\nodejs\node-v22.15.0-win-x64\node_modules\@googleworkspace\cli\run.js"
$scopes = "openid,https://www.googleapis.com/auth/userinfo.email,https://www.googleapis.com/auth/userinfo.profile,https://www.googleapis.com/auth/gmail.modify,https://www.googleapis.com/auth/calendar,https://www.googleapis.com/auth/drive,https://www.googleapis.com/auth/spreadsheets"

Write-Host "Starting Google Workspace authentication..." -ForegroundColor Cyan
Write-Host "Browser will open automatically." -ForegroundColor Cyan
Write-Host ""

$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = $node
$pinfo.Arguments = "`"$runjs`" auth login --scopes `"$scopes`""
$pinfo.RedirectStandardOutput = $true
$pinfo.RedirectStandardError = $true
$pinfo.UseShellExecute = $false
$pinfo.CreateNoWindow = $true

$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
$p.Start() | Out-Null

$urlOpened = $false

while (-not $p.HasExited) {
    $line = $p.StandardError.ReadLine()
    if ($null -eq $line) { break }
    Write-Host $line
    if ($line -match "https://accounts.google.com" -and -not $urlOpened) {
        $url = $line.Trim()
        Start-Process $url
        $urlOpened = $true
        Write-Host ""
        Write-Host "Browser opened! Please authorize in the browser window." -ForegroundColor Green
        Write-Host "Waiting for authorization..." -ForegroundColor Yellow
    }
}

$stdout = $p.StandardOutput.ReadToEnd()
if ($stdout) { Write-Host $stdout }

$p.WaitForExit()
Write-Host ""
if ($p.ExitCode -eq 0) {
    Write-Host "Authentication completed!" -ForegroundColor Green
} else {
    Write-Host "Authentication failed (exit code $($p.ExitCode))" -ForegroundColor Red
}
Read-Host "Press Enter to close"
