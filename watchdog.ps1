# Meant to run on a recurring Task Scheduler trigger (e.g. every 5 minutes).
# Checks whether the kiosk's isolated Edge instance is running, and
# relaunches it via start-kiosk.ps1 if not - recovers from a crash, an
# accidental close, or anything else that closed it.
#
# Detection matches the dedicated --user-data-dir from start-kiosk.ps1, not
# just "--kiosk" or "any msedge.exe": this PC also runs a regular browser for
# everyday/dev use, so the kiosk needs to be identified as its own isolated
# instance rather than confused with (or masked by) that other usage.

$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfile"
$kioskRunning = Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
  Where-Object { $_.CommandLine -like "*--user-data-dir=$profileDir*" }

if (-not $kioskRunning) {
  & "$PSScriptRoot\start-kiosk.ps1"
}
