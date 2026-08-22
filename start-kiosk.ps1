# Launches the Home Hub Dashboard in fullscreen kiosk mode against the live
# GitHub Pages deployment. Meant to be run by a Task Scheduler "at log on"
# trigger so the kiosk comes up automatically after signing in.
#
# To exit kiosk mode for maintenance: Alt+F4.

$url = "https://kyleedwardhoegh-sys.github.io/home-hub-dashboard/"
$edge = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $edge)) {
  $edge = "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
}

Start-Process -FilePath $edge -ArgumentList @(
  "--kiosk", $url,
  "--edge-kiosk-type=fullscreen",
  "--no-first-run",
  "--disable-pinch"
)
