# Launches the Home Hub Dashboard in fullscreen kiosk mode against the live
# Vercel deployment. Meant to be run by a Task Scheduler "at log on"
# trigger so the kiosk comes up automatically after signing in.
#
# Uses Chrome (Kyle's preferred browser) rather than Edge.
#
# Runs under its own --user-data-dir, NOT Kyle's regular Chrome profile.
# This PC also gets used for everyday/dev work with regular Chrome open, and
# Chrome only honors startup flags like --kiosk when actually launching a
# fresh process - if it just hands off to an already-running instance (same
# profile), --kiosk is silently ignored and you get a normal browser window
# instead. A dedicated profile guarantees a real, isolated kiosk instance
# every time, regardless of what else Chrome is doing.
#
# To exit kiosk mode: Ctrl+Alt+Del -> Task Manager -> End Task on Chrome.
# Alt+F4 does NOT work - Chrome's --kiosk mode deliberately disables it.

$url = "https://home-hub-dashboard.vercel.app/"
$profileDir = "$env:LOCALAPPDATA\HomeHubKioskProfile"
$chrome = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) {
  $chrome = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}

Start-Process -FilePath $chrome -ArgumentList @(
  "--kiosk", $url,
  "--user-data-dir=$profileDir",
  "--no-first-run",
  "--disable-pinch"
)
