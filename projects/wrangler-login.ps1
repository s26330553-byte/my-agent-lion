Write-Host "Opening Cloudflare login in browser..." -ForegroundColor Cyan
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
wrangler login
Write-Host ""
Read-Host "Press Enter to close"
