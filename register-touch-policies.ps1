# One-time setup, run as Administrator (added 2026-11-23):
#   Right-click Start > Terminal (Admin), then:
#   & "C:\Users\Owner\source\repos\home-hub-dashboard\register-touch-policies.ps1"
# Then restart the PC once.
#
# 1. Turns OFF Windows' own edge swipes on the touchscreen (left edge = Widgets,
#    right edge = Notifications, bottom = taskbar/Start, top = app title bar).
#    They were stealing the Home Hub gesture kit's swipes: Kyle's first test on the
#    Elo opened Widgets on a left-edge swipe and the taskbar on swipe-up.
#    Policy: "Allow edge swipe" = Disabled (Windows Components > Edge UI).
#    Undo: delete the AllowEdgeSwipe value and restart.
# 2. Lets any page in the kiosk (stable Edge, which the kiosk runs now) open the
#    homehubadmin:// exit link with no "Open PowerShell?" prompt, so the Control
#    Center's hold-to-exit tile works. Same as register-exit-policy.ps1 does for Edge Dev.

$edgeUi = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\EdgeUI"
New-Item -Path $edgeUi -Force | Out-Null
Set-ItemProperty -Path $edgeUi -Name "AllowEdgeSwipe" -Value 0 -Type DWord

$proto = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\AutoLaunchProtocolsFromOrigins"
New-Item -Path $proto -Force | Out-Null
Set-ItemProperty -Path $proto -Name "1" -Value '{"protocol":"homehubadmin","allowed_origins":["*"]}'

# 3. (2026-11-27) Lets the hosted hub reach the kitchen-PC helper on localhost (close the kiosk) without
#    Edge's "wants to access other apps and services on this device" prompt (Local Network Access).
$lna = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\LocalNetworkAccessAllowedForUrls"
New-Item -Path $lna -Force | Out-Null
Set-ItemProperty -Path $lna -Name "1" -Value "https://home-hub-web-hoegh-home.vercel.app"
Write-Host "Done: Windows edge swipes off; homehubadmin:// allowed in Edge. Restart the PC once."
