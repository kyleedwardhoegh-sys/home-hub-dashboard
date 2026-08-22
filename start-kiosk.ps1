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
# To exit kiosk mode: Ctrl+Alt+Del -> Task Manager -> End Task on Edge.
# Alt+F4 does NOT work - Edge's kiosk mode deliberately disables it, same as
# Chrome's did.

$url = "https://home-hub-dashboard.vercel.app/"
$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfileEdge"
$edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) {
  $edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
}

Start-Process -FilePath $edge -ArgumentList @(
  "--kiosk", $url,
  "--edge-kiosk-type=fullscreen",
  "--user-data-dir=$profileDir",
  "--no-first-run",
  "--disable-pinch"
)
