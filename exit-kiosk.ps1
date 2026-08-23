# Closes the kiosk's isolated Edge instance. Invoked by
# kiosk-nav-helper/HomeHubNav.ahk's corner tap-and-hold button - the
# touch-only path out of kiosk mode, no keyboard or Ctrl+Alt+Del required
# (that path was tried and abandoned 2026-08-23: modern osk.exe no longer
# supports sending Ctrl+Alt+Del at all, and touch-and-hold doesn't
# translate to a real held mouse button inside a touch-aware Chromium
# window anyway - see HANDOFF.md). This script just closes the kiosk
# directly instead.
#
# Closes gracefully first (WM_CLOSE via CloseMainWindow), not a forceful
# kill - gives Edge a moment to actually write its preferences to disk
# before anything is force-killed. Force-kill is still used as a fallback
# for anything left running after a couple seconds (e.g. helper processes
# with no window, or a genuine hang).
#
# Does NOT disable the watchdog task - it will relaunch the kiosk on its
# next 5-minute check, same as any other close. Pause HomeHubKioskWatchdog
# separately if you need it to stay closed for a while.

$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfile"

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
