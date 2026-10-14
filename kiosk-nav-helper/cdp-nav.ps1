# Tells the already-running kiosk tab to navigate, without closing or
# relaunching the Edge process. Called by HomeHubNav.ahk's Home and Back
# corner buttons - replaces the earlier approach of fully relaunching Edge
# for Home (start-kiosk.ps1, heavy - closes and reopens the whole browser)
# and sending an Alt+Left keystroke for Back (never confirmed reliable
# against kiosk mode's own shortcut filtering).
#
# Uses Chrome DevTools Protocol over the --remote-debugging-port=9222 flag
# added to start-kiosk.ps1's launch args. Chromium binds that port to
# 127.0.0.1 only (not exposed off this machine). This is a real capability
# increase - any local process can now drive the kiosk tab via this port -
# accepted since Kyle already has full local access to this PC for dev
# work; nothing new is exposed to anyone else.
#
# "home" navigates via location.href (a real page load, same as typing the
# URL) rather than history.forward()/back() - guarantees landing on the
# dashboard's ambient view regardless of how deep Back would otherwise
# have to walk. "back" runs history.back() - one real step, same as a
# browser back button would do.

#
# "open" (added 2026-10-13) navigates to -Url; used by the HomeHubNellieMorning
# scheduled task to put Nellie's Morning track on screen at 5:00 AM. If the
# kiosk isn't running, "open" launches it first (start-kiosk.ps1) and waits for
# the debugging port to come up.

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("home", "back", "open")]
  [string]$Action,
  [string]$Url
)

$DASHBOARD_URL = "https://home-hub-dashboard.vercel.app/"
$expression = switch ($Action) {
  "home" { "location.href = '$DASHBOARD_URL'" }
  "open" { if (-not $Url) { exit 1 }; "location.href = '" + $Url.Replace("'", "%27") + "'" }
  default { "history.back()" }
}

function Get-KioskPage {
  try {
    $targets = Invoke-RestMethod -Uri "http://127.0.0.1:9222/json" -TimeoutSec 3
    # Windows PowerShell 5.1 passes a JSON array down the pipeline as ONE object;
    # ForEach-Object { $_ } unrolls it so Where-Object sees each target.
    return $targets | ForEach-Object { $_ } | Where-Object { $_.type -eq "page" } | Select-Object -First 1
  } catch { return $null }
}

try {
  $page = Get-KioskPage
  if (-not $page -and $Action -eq "open") {
    & (Join-Path $PSScriptRoot "..\start-kiosk.ps1")
    for ($i = 0; $i -lt 15 -and -not $page; $i++) { Start-Sleep -Seconds 2; $page = Get-KioskPage }
  }
  if (-not $page) { exit 1 }

  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $cts = New-Object System.Threading.CancellationTokenSource
  $cts.CancelAfter(3000)
  $ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $cts.Token).Wait()

  $payload = @{ id = 1; method = "Runtime.evaluate"; params = @{ expression = $expression } } | ConvertTo-Json -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  $segment = New-Object System.ArraySegment[byte] (, $bytes)
  $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()
  $sent = $true

  Start-Sleep -Milliseconds 200
  $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", $cts.Token).Wait()
} catch {
  # Navigating away often drops the socket before the polite close finishes;
  # once the command was sent, that still counts as success.
  if ($sent) { exit 0 }
  exit 1
}
