# One-time setup, run as Administrator: registers a machine-level Edge Dev
# policy that pre-authorizes ANY origin to launch the homehubadmin://
# protocol WITHOUT a confirmation prompt - "*" as the allowed_origins entry,
# so the universal kiosk-extension's exit button works on any page, not
# just a fixed list of known Home Hub apps. This is what makes the exit
# mechanism actually universal, matching the extension's own <all_urls>
# reach - a per-origin allowlist here would recreate the exact "have to
# remember to add every new app" problem the extension was built to avoid.
#
# Targets EdgeDev, not Edge: the kiosk runs Edge DEV channel (switched
# 2026-08-23 - Stable channel permanently blocks unpacked extensions, see
# HANDOFF.md), and each Edge channel (Stable/Beta/Dev/Canary) reads
# policies from its own separate registry path -
# HKLM\SOFTWARE\Policies\Microsoft\EdgeDev here, not ...\Edge.
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
# exactly this situation (AutoLaunchProtocolsFromOrigins policy). The "*"
# wildcard for allowed_origins is untested as of this writing - if Edge
# rejects it or still prompts, the fallback is enumerating specific origins
# again (see git history for the prior version of this file).

$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeDev\AutoLaunchProtocolsFromOrigins"
New-Item -Path $policyPath -Force | Out-Null

$entry = '{"protocol":"homehubadmin","allowed_origins":["*"]}'
Set-ItemProperty -Path $policyPath -Name "1" -Value $entry

# Any mandatory policy under this registry path makes Edge consider itself
# "managed by your organization" (confirmed via edge://management 2026-08-23
# - this is generic Chromium behavior for ANY local machine policy, not a
# sign of an actual external organization/Family Safety account, which was
# investigated and ruled out). One side effect: DevTools gets blocked by
# default on managed browsers. Explicitly re-allow it so debugging stays
# possible - value 1 = DeveloperToolsAvailability "Allowed" (Chromium
# policy enum: 0=default/allowed via extensions or generic, 1=allowed,
# 2=disallowed).
Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\EdgeDev" -Name "DeveloperToolsAvailability" -Value 1 -Type DWord

Write-Host "Registered: any origin may auto-launch homehubadmin:// with no prompt (Edge Dev). DevTools kept available."
