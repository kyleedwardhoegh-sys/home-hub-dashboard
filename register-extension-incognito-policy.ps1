# One-time setup, run as Administrator: allows kiosk-extension/ to run
# inside InPrivate windows on Edge Dev.
#
# Why this is needed: Chromium extensions are disabled inside InPrivate
# windows by default - a SEPARATE restriction from the "developer mode"
# block that switching to Edge Dev already solved. Edge's
# --edge-kiosk-type=fullscreen runs as an InPrivate session (confirmed via
# the window title showing "[InPrivate]"), so even though kiosk-extension/
# shows as installed and enabled (confirmed via the profile's own Secure
# Preferences file - "disable_reasons":[]), its content script never
# actually injects into the kiosk page itself, because that page loads
# inside the InPrivate session and the extension isn't allowed there by
# default. This is why an unmissable full-screen diagnostic banner
# (added temporarily to content.js) never appeared even though the
# extension was confirmed loaded.
#
# The normal fix is a per-extension "Allow in InPrivate" toggle in
# edge://extensions, but per the same pattern hit earlier with the
# "Always allow" protocol checkbox, InPrivate sessions don't reliably
# persist manually-set choices - a registry POLICY is the same reliable
# fix pattern already used for AutoLaunchProtocolsFromOrigins
# (register-exit-policy.ps1): Edge reads it fresh from the machine
# registry on every launch, independent of the ephemeral InPrivate
# profile.
#
# Targets EdgeDev's own policy path (HKLM\...\Policies\Microsoft\EdgeDev),
# same as register-exit-policy.ps1 - see that script for why.
#
# The extension ID (inkipmecdkjcklabbdahbhdhfnnhgmia) is deterministically
# derived from kiosk-extension/'s absolute path and confirmed stable
# across relaunches - but if the repo ever moves/renames, re-derive it by
# checking edge://extensions or grepping the profile's Secure Preferences
# file for the ID adjacent to the kiosk-extension path, and update this
# script.

$policyPath = "HKLM:\SOFTWARE\Policies\Microsoft\EdgeDev"
New-Item -Path $policyPath -Force | Out-Null

$extensionId = "inkipmecdkjcklabbdahbhdhfnnhgmia"
$json = "{`"$extensionId`":{`"installation_mode`":`"allowed`",`"incognito_mode`":`"spanning`"}}"
Set-ItemProperty -Path $policyPath -Name "ExtensionSettings" -Value $json

Write-Host "Registered: kiosk-extension ($extensionId) allowed to run in InPrivate/kiosk sessions."
