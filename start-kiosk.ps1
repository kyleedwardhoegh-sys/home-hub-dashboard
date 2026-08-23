# Launches the Home Hub Dashboard in fullscreen kiosk mode against the live
# Vercel deployment. Meant to be run by a Task Scheduler "at log on"
# trigger so the kiosk comes up automatically after signing in.
#
# Uses Microsoft Edge (switched from Chrome 2026-08-22 - Kyle's deliberate
# choice to run a Microsoft product on Windows, not a technical requirement;
# Edge's kiosk mode isn't meaningfully better for this single-site use case).
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
# To exit kiosk mode: hold the bottom-right corner of the screen for 3s
# (works on any page - see kiosk-extension/, loaded below via
# --load-extension) and tap "Exit Kiosk". Ctrl+Alt+Del -> Task Manager ->
# End Task on Edge also still works as a fallback. Alt+F4 does NOT work -
# Edge's kiosk mode deliberately disables it.
#
# --load-extension loads kiosk-extension/ (an unpacked extension, not from
# the Store) which injects the hold-to-navigate overlay into every page the
# kiosk shows, regardless of which Home Hub app or even a page never built
# for this - see that folder's content.js and this repo's HANDOFF.md for
# the full design rationale.
#
# Uses Edge DEV channel, not Stable (switched 2026-08-23). Stable Edge
# force-disables any unpacked/--load-extension extension with a permanent,
# undismissable "developer mode" warning - confirmed via Microsoft's own
# support docs, not just observed behavior: "we don't allow dismissing the
# notification... Microsoft recommends using Dev or Canary channel for
# testing your extensions." Dev channel doesn't carry this restriction.
# Tradeoff: Dev channel updates weekly instead of Stable's slower cadence -
# accepted as the price for the extension actually working reliably. See
# HANDOFF.md for the full investigation that led here.

$url = "https://home-hub-dashboard.vercel.app/"
$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfileEdgeDev"
$extensionDir = Join-Path $PSScriptRoot "kiosk-extension"
$edge = "$env:ProgramFiles\Microsoft\Edge Dev\Application\msedge.exe"
if (-not (Test-Path $edge)) {
  $edge = "${env:ProgramFiles(x86)}\Microsoft\Edge Dev\Application\msedge.exe"
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
  "--load-extension=$extensionDir",
  "--no-first-run",
  "--disable-pinch"
)
