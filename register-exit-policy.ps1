# One-time setup, run as Administrator: registers a machine-level Edge
# policy that pre-authorizes all four Home Hub apps to launch the
# homehubadmin:// protocol WITHOUT a confirmation prompt. The exit gesture
# (hold bottom-right corner 3s) exists on all four now, not just the
# dashboard, so all four origins need to be listed here.
#
# Why this is needed instead of just checking "Always allow" in the popup:
# Edge's --edge-kiosk-type=fullscreen runs as an InPrivate session under the
# hood (confirmed via window title: "Home Hub - [InPrivate] - Microsoft
# Edge"). InPrivate is designed to forget everything between launches,
# including "always allow this site to open X" choices - so no amount of
# checking that box ever makes it stick; it's not a bug, it's how InPrivate
# is supposed to work. A registry POLICY is different: Edge reads it fresh
# from the machine registry on every launch, independent of the ephemeral
# InPrivate profile, so it applies every time without ever prompting.
#
# This is the standard mechanism Chromium-based kiosk deployments use for
# exactly this situation (AutoLaunchProtocolsFromOrigins policy).

$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\Edge\AutoLaunchProtocolsFromOrigins"
New-Item -Path $policyPath -Force | Out-Null

$entry = '{"protocol":"homehubadmin","allowed_origins":["https://home-hub-dashboard.vercel.app","https://home-hub-web-hoegh-home.vercel.app","https://football-practice-planner-hoegh-home.vercel.app","https://maple-grove-crimson.vercel.app"]}'
Set-ItemProperty -Path $policyPath -Name "1" -Value $entry

Write-Host "Registered: all four Home Hub apps may auto-launch homehubadmin:// with no prompt."
