; Kiosk navigation. Runs alongside the kiosk browser as its own native
; process - not a browser extension, not injected into any page - so it
; works no matter what's on screen and needs zero changes to any Home Hub
; app. Draws two small always-on-top native windows (plain win32 windows,
; not touch-aware, so touch on them translates to normal clicks reliably -
; see HANDOFF.md for why that distinction matters here) in the bottom
; corners of the screen, sitting above the kiosk:
;
;   - Bottom-right: EXIT. Tap and hold ~1.5s to close the kiosk entirely
;     (runs exit-kiosk.ps1).
;   - Bottom-left: HOME. Tap and hold ~1.5s to return to the dashboard's
;     ambient clock screen (runs start-kiosk.ps1, which already kills any
;     running kiosk instance and relaunches fresh - the simplest possible
;     way to guarantee landing back on the ambient view, and the same
;     script already used by the desktop shortcut and at-logon task).
;
; Bottom-left was chosen for Home (not top-left) specifically to avoid
; sitting under the dashboard's own avatar tap-in chips, which live in the
; ambient view's top-left corner.
;
; This is the THIRD design for kiosk exit specifically (see HANDOFF.md for
; the full history) - a touch-and-hold-anywhere gesture and an
; on-screen-keyboard both foundered on Chromium owning touch input inside
; its own window. Home is new as of 2026-08-23, added alongside disabling
; Edge's swipe-back gesture entirely (--overscroll-history-navigation=0 in
; start-kiosk.ps1): swipe-back could run off the edge of history into
; Edge's own internal UI, which sat in front of these buttons since it's
; Edge's chrome rather than the kiosk page. Home is the intended
; replacement for "swipe back to the dashboard from a sibling app", not
; just a kiosk-exit affordance.

#Requires AutoHotkey v2.0
#SingleInstance Force

HOLD_MS := 1500
BTN_SIZE := 44
repoRoot := A_ScriptDir "\.."

BUTTONS := [
    { id: "exit", x: A_ScreenWidth - BTN_SIZE - 8, script: repoRoot "\exit-kiosk.ps1" },
    { id: "home", x: 8,                            script: repoRoot "\start-kiosk.ps1" }
]

for btn in BUTTONS {
    btnGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000")
    btnGui.BackColor := "404040"
    btnGui.Show(Format("w{1} h{1} x{2} y{3} NoActivate", BTN_SIZE, btn.x, A_ScreenHeight - BTN_SIZE - 8))
    WinSetRegion(Format("0-0 W{1} H{1} R{1}-{1}", BTN_SIZE), btnGui)
    btn.hwnd := btnGui.Hwnd
}

downTime := 0
triggered := false
activeButton := ""

~LButton::
{
    global downTime, triggered, activeButton, BUTTONS
    MouseGetPos(, , &winUnderMouse)
    activeButton := ""
    for btn in BUTTONS {
        if (winUnderMouse == btn.hwnd) {
            activeButton := btn
            break
        }
    }
    if (!activeButton)
        return
    downTime := A_TickCount
    triggered := false
    SetTimer(CheckHold, 50)
}

CheckHold() {
    global downTime, triggered, HOLD_MS, activeButton
    if (!activeButton || !GetKeyState("LButton")) {
        SetTimer(CheckHold, 0)
        return
    }
    if (!triggered && (A_TickCount - downTime) >= HOLD_MS) {
        triggered := true
        SetTimer(CheckHold, 0)
        Run('powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' activeButton.script '"')
    }
}

~LButton Up::
{
    global activeButton
    SetTimer(CheckHold, 0)
    activeButton := ""
}
