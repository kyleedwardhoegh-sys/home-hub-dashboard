# Closes the kiosk's isolated Edge instance. Invoked via the custom
# homehubadmin:// URL scheme (registered in HKCU by register-exit-handler.ps1),
# which the dashboard's touch-hold gesture navigates to - this is the
# touch-only path out of kiosk mode, no keyboard required.
#
# Closes gracefully first (WM_CLOSE via CloseMainWindow), not a forceful
# kill - Edge needs a moment to actually write its preferences to disk,
# including the "Always allow this site to open PowerShell" checkbox from
# the confirmation dialog that led here. A forceful kill immediately after
# that checkbox is confirmed can race the write and lose it, meaning the
# confirmation dialog would reappear on every single use instead of the one
# time it's supposed to. Force-kill is still used as a fallback for
# anything left running after a couple seconds (e.g. helper processes with
# no window, or a genuine hang).
#
# Does NOT disable the watchdog task - it will relaunch the kiosk on its
# next 5-minute check, same as any other close. Pause HomeHubKioskWatchdog
# separately if you need it to stay closed for a while.

$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfileEdge"

$kioskProcs = Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
  Where-Object { $_.CommandLine -like "*--user-data-dir=$profileDir*" }

foreach ($p in $kioskProcs) {
  try {
    $proc = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
    if ($proc -and $proc.MainWindowHandle -ne 0) {
      $proc.CloseMainWindow() | Out-Null
    }
  } catch {}
}

Start-Sleep -Seconds 2

Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
  Where-Object { $_.CommandLine -like "*--user-data-dir=$profileDir*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
