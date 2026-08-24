; Kiosk navigation. Runs alongside the kiosk browser as its own native
; process - not a browser extension, not injected into any page - so it
; works no matter what's on screen and needs zero changes to any Home Hub
; app. Draws three small always-on-top native windows (plain win32
; windows, not touch-aware, so touch on them translates to normal clicks
; reliably - see HANDOFF.md for why that distinction matters here),
; sitting above the kiosk:
;
;   - Top-right: BACK. Tap to run history.back() on the kiosk tab via
;     cdp-nav.ps1 - one real step back, same as a browser back button.
;   - Bottom-left: HOME. Tap to navigate the kiosk tab straight to the
;     dashboard's ambient clock screen (also via cdp-nav.ps1). Changed
;     2026-08-24 from relaunching the whole Edge process (start-kiosk.ps1)
;     - that worked but was needlessly heavy for something this routine,
;     and force-killing Edge on every tap was found to be losing
;     just-signed-in Google sessions before Chromium finished writing them
;     to disk. Navigating the existing tab avoids both problems.
;   - Bottom-right: EXIT. Tap to close the kiosk entirely (exit-kiosk.ps1)
;     - this one still needs the process to actually end, so it's the one
;     button left that isn't just a tab navigation.
;
; Top-right/bottom-left/bottom-right were chosen specifically to avoid the
; ambient view's own avatar tap-in chips, which live in the top-left
; corner - these are native overlay windows, not part of any page, so
; they'd otherwise visually collide with the dashboard's own UI.
;
; PLAIN TAP, not tap-and-hold (changed 2026-08-24). The original hold
; design depended on EloConfig's Touch Mode being set to "Click on
; Finger-up" + "Enable Drag" - the only mode where a stationary touch
; produces a genuinely time-tracked held button (see HANDOFF.md). That
; mode turned out to break ordinary single-clicks elsewhere on the system
; (e.g. the taskbar), so it got reverted back to Elo's default "Normal
; (emulate physical mouse)" - which is required for the rest of the PC to
; work normally, but under which a touch (tap OR hold) always resolves to
; an immediate down+up pair, indistinguishable by duration. Since a hold
; can no longer be measured at all in Normal mode, these buttons trigger
; on a plain tap instead. Accidental taps aren't a real concern - all hit
; targets are small (44px) and tucked into corners nothing else on screen
; occupies.
;
; This is the THIRD design for kiosk exit specifically (see HANDOFF.md for
; the full history) - a touch-and-hold-anywhere gesture and an
; on-screen-keyboard both foundered on Chromium owning touch input inside
; its own window.

#Requires AutoHotkey v2.0
#SingleInstance Force

BTN_SIZE := 44
MARGIN := 8
repoRoot := A_ScriptDir "\.."
psPrefix := 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'
cdpScript := A_ScriptDir "\cdp-nav.ps1"

BUTTONS := [
    { id: "back", x: A_ScreenWidth - BTN_SIZE - MARGIN, y: MARGIN,                             cmd: psPrefix cdpScript '" -Action back' },
    { id: "home", x: MARGIN,                            y: A_ScreenHeight - BTN_SIZE - MARGIN, cmd: psPrefix cdpScript '" -Action home' },
    { id: "exit", x: A_ScreenWidth - BTN_SIZE - MARGIN, y: A_ScreenHeight - BTN_SIZE - MARGIN,  cmd: psPrefix repoRoot '\exit-kiosk.ps1"' }
]

for btn in BUTTONS {
    btnGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    btnGui.BackColor := "404040"
    btnGui.Show(Format("w{1} h{1} x{2} y{3} NoActivate", BTN_SIZE, btn.x, btn.y))
    WinSetRegion(Format("0-0 W{1} H{1} R{1}-{1}", BTN_SIZE), btnGui)
    btn.hwnd := btnGui.Hwnd
}

activeButton := ""

~LButton::
{
    global activeButton, BUTTONS
    MouseGetPos(, , &winUnderMouse)
    activeButton := ""
    for btn in BUTTONS {
        if (winUnderMouse == btn.hwnd) {
            activeButton := btn
            break
        }
    }
}

~LButton Up::
{
    global activeButton
    if (activeButton)
        Run(activeButton.cmd)
    activeButton := ""
}
