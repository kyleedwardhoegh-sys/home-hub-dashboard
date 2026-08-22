# One-time setup: registers the homehubadmin:// custom URL scheme under
# HKCU (no admin elevation needed) so the dashboard's touch-hold gesture can
# trigger exit-kiosk.ps1 via a plain link, without any keyboard involved.
#
# Re-run this after moving/renaming the repo, since the registered command
# hardcodes this file's path.

$scriptPath = Join-Path $PSScriptRoot "exit-kiosk.ps1"
$classPath = "HKCU:\Software\Classes\homehubadmin"

New-Item -Path $classPath -Force | Out-Null
Set-ItemProperty -Path $classPath -Name "(Default)" -Value "URL:HomeHub Admin Protocol"
Set-ItemProperty -Path $classPath -Name "URL Protocol" -Value ""

$commandPath = "$classPath\shell\open\command"
New-Item -Path $commandPath -Force | Out-Null
$command = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
Set-ItemProperty -Path $commandPath -Name "(Default)" -Value $command

Write-Host "Registered homehubadmin:// -> $scriptPath"
