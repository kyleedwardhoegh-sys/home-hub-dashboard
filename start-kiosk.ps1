# Launches the Home Hub Dashboard in fullscreen kiosk mode against the live
# Vercel deployment. Meant to be run by a Task Scheduler "at log on"
# trigger so the kiosk comes up automatically after signing in.
#
# Uses Chrome (Kyle's preferred browser) rather than Edge.
# To exit kiosk mode for maintenance: Alt+F4.

$url = "https://home-hub-dashboard.vercel.app/"
$chrome = "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chrome)) {
  $chrome = "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe"
}

Start-Process -FilePath $chrome -ArgumentList @(
  "--kiosk", $url,
  "--no-first-run",
  "--disable-pinch"
)
