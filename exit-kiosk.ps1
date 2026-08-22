# Kills the kiosk's isolated Edge instance. Invoked via the custom
# homehubadmin:// URL scheme (registered in HKCU by register-exit-handler.ps1),
# which the dashboard's touch-hold gesture navigates to - this is the
# touch-only path out of kiosk mode, no keyboard required.
#
# Does NOT disable the watchdog task - it will relaunch the kiosk on its
# next 5-minute check, same as any other close. Pause HomeHubKioskWatchdog
# separately if you need it to stay closed for a while.

$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfileEdge"
Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
  Where-Object { $_.CommandLine -like "*--user-data-dir=$profileDir*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
