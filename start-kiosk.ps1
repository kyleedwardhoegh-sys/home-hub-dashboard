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
# --disable-features=OverscrollHistoryNavigation disables Edge's touch
# swipe-back/forward gesture entirely (the older --overscroll-history-
# navigation=0 switch this started as no longer has any effect on this
# Chromium version - confirmed 2026-08-23, swipe-back kept working with it
# set; this is the modern per-feature equivalent). Discovered 2026-08-23:
# swiping back while the dashboard was the first/only history entry ran
# Chromium out of history and fell
# through to Edge's own internal "InPrivate" landing page - which, being
# Edge's own chrome rather than kiosk-nav-helper's always-on-top corner
# buttons, could sit in front of them. A same-page history-padding trick
# (briefly tried in app.js, since removed) didn't reliably stop it either -
# the swipe gesture's preview appears to peek at a layer beneath what JS
# history can influence. Disabling the gesture outright closes this for
# good, at the cost of losing swipe-back as a way to return from a sibling
# app to the dashboard - kiosk-nav-helper's Home corner button (bottom-left)
# is the intended replacement for that, not just for kiosk exit.
#
# Exit, Home, and Back are all plain-tap native corner buttons drawn by
# kiosk-nav-helper/HomeHubNav.ahk, running independently of the browser -
# see HANDOFF.md. Bottom-right closes the kiosk; bottom-left relaunches it
# fresh at the dashboard's ambient clock screen; top-right sends a browser
# back-navigation (Alt+Left) so returning from a sibling app doesn't need
# a full relaunch. None of them need a keyboard or Ctrl+Alt+Del.

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
#
# Close gracefully first (WM_CLOSE via CloseMainWindow), not a forceful
# kill - same reasoning as exit-kiosk.ps1: an immediate Stop-Process -Force
# can race Chromium's own write of recent session state (cookies, sign-ins)
# to disk. This matters more now that the Home corner button calls this
# script on every use, not just at logon - a forceful kill here was
# confirmed 2026-08-24 to be losing a just-completed Google sign-in on the
# very next relaunch. Force-kill remains the fallback for anything still
# running after a couple seconds.
$existing = Get-CimInstance Win32_Process -Filter "Name = 'msedge.exe'" |
  Where-Object { $_.CommandLine -like "*--user-data-dir=$profileDir*" }
foreach ($p in $existing) {
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

Start-Process -FilePath $edge -ArgumentList @(
  "--kiosk", $url,
  "--edge-kiosk-type=fullscreen",
  "--user-data-dir=$profileDir",
  "--no-first-run",
  "--disable-pinch",
  "--disable-features=OverscrollHistoryNavigation"
)
