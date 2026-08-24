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

param(
  [Parameter(Mandatory = $true)]
  [ValidateSet("home", "back")]
  [string]$Action
)

$DASHBOARD_URL = "https://home-hub-dashboard.vercel.app/"
$expression = if ($Action -eq "home") { "location.href = '$DASHBOARD_URL'" } else { "history.back()" }

try {
  $targets = Invoke-RestMethod -Uri "http://127.0.0.1:9222/json" -TimeoutSec 3
  $page = $targets | Where-Object { $_.type -eq "page" } | Select-Object -First 1
  if (-not $page) { exit 1 }

  $ws = New-Object System.Net.WebSockets.ClientWebSocket
  $cts = New-Object System.Threading.CancellationTokenSource
  $cts.CancelAfter(3000)
  $ws.ConnectAsync([Uri]$page.webSocketDebuggerUrl, $cts.Token).Wait()

  $payload = @{ id = 1; method = "Runtime.evaluate"; params = @{ expression = $expression } } | ConvertTo-Json -Compress
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
  $segment = New-Object System.ArraySegment[byte] (, $bytes)
  $ws.SendAsync($segment, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, $cts.Token).Wait()

  Start-Sleep -Milliseconds 200
  $ws.CloseAsync([System.Net.WebSockets.WebSocketCloseStatus]::NormalClosure, "", $cts.Token).Wait()
} catch {
  exit 1
}
