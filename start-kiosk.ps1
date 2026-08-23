# Launches the Home Hub Dashboard in fullscreen kiosk mode against the live
# Vercel deployment. Meant to be run by a Task Scheduler "at log on"
# trigger so the kiosk comes up automatically after signing in.
#
# Uses Microsoft Edge (switched from Chrome 2026-08-22 - Kyle's deliberate
# choice to run a Microsoft product on Windows, not a technical requirement;
# Edge's kiosk mode isn't meaningfully better for this single-site use case).
# Back on Edge STABLE (reverted 2026-08-23) - the Dev channel switch and
# --load-extension below were only ever needed for kiosk-extension/, which
# has been replaced by kiosk-nav-helper/HomeHubNav.ahk, a native AutoHotkey
# process that runs alongside the browser instead of inside it (see
# HANDOFF.md). Stable no longer has anything blocking it now that there's
# no unpacked extension to load.
#
# Runs under its own --user-data-dir, NOT Kyle's regular Edge/Chrome profile.
# This PC also gets used for everyday/dev work with a regular browser open,
# and Chromium-based browsers only honor startup flags like --kiosk when
# actually launching a fresh process - if it just hands off to an
# already-running instance (same profile), --kiosk is silently ignored and
# you get a normal browser window instead. A dedicated profile guarantees a
# real, isolated kiosk instance every time, regardless of what else is
# running.
#
# --edge-kiosk-type=fullscreen (not the default "public-browsing" type):
# public-browsing is built for walk-up-and-use public terminals and resets
# the session on an on-screen "End session" button - fine for a library PC,
# wrong for a persistent ambient family dashboard. fullscreen just shows the
# one site with no browser UI, same behavior as the old Chrome setup.
#
# To exit kiosk mode: touch and hold anywhere on the touchscreen for 3
# seconds (kiosk-nav-helper/HomeHubNav.ahk, running independently of the
# browser - see HANDOFF.md) to open the On-Screen Keyboard, then
# Ctrl+Alt+Del -> Task Manager -> End Task on Edge. Alt+F4 does NOT work -
# Edge's kiosk mode deliberately disables it.

$url = "https://home-hub-dashboard.vercel.app/"
$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfile"
$edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) {
  $edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
}

# Always kill any existing kiosk instance first. Without this, re-running
# this script while the kiosk is still open just hands off to that already-
# running process (same profile) - Chromium silently drops EVERY flag on
# this command line when that happens, including --load-extension, so the
# "relaunch" would keep running whatever extension code (or none) was
# loaded at the very first launch, no matter how many times this script
# runs afterward. This bit us directly during kiosk-extension development.
Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
  Where-Object { $_.CommandLine -like "*--user-data-dir=$profileDir*" } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

Start-Process -FilePath $edge -ArgumentList @(
  "--kiosk", $url,
  "--edge-kiosk-type=fullscreen",
  "--user-data-dir=$profileDir",
  "--no-first-run",
  "--disable-pinch"
)
