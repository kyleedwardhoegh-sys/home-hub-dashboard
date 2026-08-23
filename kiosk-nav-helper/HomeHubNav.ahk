; Kiosk escape hatch. Runs alongside the kiosk browser as its own native
; process - not a browser extension, not injected into any page - so it
; works no matter what's on screen and needs zero changes to any Home Hub
; app.
;
; This is the THIRD design for this problem (see HANDOFF.md for the full
; history). The first two both foundered on the same discovery: Edge/
; Chromium is a touch-aware app - it handles touch itself via Windows'
; Pointer Input messages instead of falling back to the legacy mouse-click
; translation a global AHK hook relies on. That's why "touch and hold
; anywhere" and "swipe anywhere" both looked promising outside the kiosk
; (on the plain desktop, which isn't touch-aware) but failed inside it:
;   - A touch-and-hold over the kiosk never arrived as a real held mouse
;     button - only a genuine mouse click-and-hold did (confirmed
;     2026-08-23: same script, same 3s threshold, worked on the desktop,
;     didn't inside the kiosk).
;   - A single-finger swipe over the kiosk is consumed entirely by
;     Chromium's own scroll/overscroll handling before Windows' shell-level
;     gesture recognizer ever sees it.
;   - Even if a hold DID register, modern osk.exe no longer supports
;     sending Ctrl+Alt+Del at all (a capability Microsoft removed) - so
;     that exit path was a dead end regardless.
;
; The fix: don't try to detect touch over the browser's touch-aware
; surface at all. Instead, draw a small always-on-top native window (a
; plain, non-touch-aware win32 window, same as the desktop shell) in the
; bottom-right corner, always sitting above the kiosk. Touch on THIS small
; window does translate to normal clicks reliably, same as the desktop
; testing that worked. Tap and hold it briefly to close the kiosk directly
; - no OSK, no Ctrl+Alt+Del, just exit-kiosk.ps1.

#Requires AutoHotkey v2.0
#SingleInstance Force

HOLD_MS := 1500
BTN_SIZE := 44
exitScript := A_ScriptDir "\..\exit-kiosk.ps1"

btnGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
btnGui.BackColor := "404040"
btnGui.Show(Format("w{1} h{1} x{2} y{3} NoActivate", BTN_SIZE, A_ScreenWidth - BTN_SIZE - 8, A_ScreenHeight - BTN_SIZE - 8))
WinSetRegion(Format("0-0 W{1} H{1} R{1}-{1}", BTN_SIZE), btnGui)

downTime := 0
triggered := false
inButton := false

~LButton::
{
    global downTime, triggered, inButton, btnGui
    MouseGetPos(, , &winUnderMouse)
    if (winUnderMouse != btnGui.Hwnd) {
        inButton := false
        return
    }
    inButton := true
    downTime := A_TickCount
    triggered := false
    SetTimer(CheckHold, 50)
}

CheckHold() {
    global downTime, triggered, HOLD_MS, inButton, exitScript
    if (!inButton || !GetKeyState("LButton")) {
        SetTimer(CheckHold, 0)
        return
    }
    if (!triggered && (A_TickCount - downTime) >= HOLD_MS) {
        triggered := true
        SetTimer(CheckHold, 0)
        Run('powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' exitScript '"')
    }
}

~LButton Up::
{
    global inButton
    SetTimer(CheckHold, 0)
    inButton := false
}
