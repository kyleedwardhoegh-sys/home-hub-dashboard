# One-time setup: registers a Task Scheduler entry ("HomeHubNavHelper")
# that launches kiosk-nav-helper/HomeHubNav.ahk at logon, same at-logon
# trigger pattern as HomeHubKiosk and HomeHubKioskWatchdog. Runs alongside
# the kiosk browser, watching for the corner-hold gesture at the OS level.
#
# Requires AutoHotkey v2 installed (https://www.autohotkey.com/) - this
# script auto-detects its install path.
#
# Does NOT need admin elevation - matches the other Home Hub kiosk tasks
# (runs under the "Owner" user, same as HomeHubKiosk/HomeHubKioskWatchdog).

$ahk = "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe"
if (-not (Test-Path $ahk)) {
  $ahk = "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe"
}
if (-not (Test-Path $ahk)) {
  Write-Error "AutoHotkey v2 not found. Install it from https://www.autohotkey.com/ first."
  exit 1
}

$scriptPath = Join-Path $PSScriptRoot "kiosk-nav-helper\HomeHubNav.ahk"

$action = New-ScheduledTaskAction -Execute $ahk -Argument "`"$scriptPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -User "Owner"
$principal = New-ScheduledTaskPrincipal -UserId "Owner" -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 0) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName "HomeHubNavHelper" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Registered: HomeHubNavHelper will launch HomeHubNav.ahk at logon."
Write-Host "To start it right now without waiting for a logon: Start-ScheduledTask -TaskName HomeHubNavHelper"
