; Standalone hold-timer diagnostic - tests whether disabling Windows' system
; "press and hold to right-click" gesture lets a genuine touch-and-hold
; arrive here as a real, continuously-held LEFT mouse button, instead of
; getting hijacked into an instant synthesized right-click (which is what
; DiagnosticRoutine.ahk proved was happening before).
;
; Before running this: disable the Windows setting first via Control Panel
; -> "Pen and Touch" -> Touch tab -> uncheck "Enable press and hold for
; right-clicking" (or Settings -> Bluetooth & devices -> Touch -> Press and
; hold, if present). Without that, this script will behave like the old
; broken hold-timer attempt (0ms holds).
;
; Just double-click this file to run it directly on the normal desktop - no
; kiosk mode needed.
;   - Touch and hold for 3+ seconds -> should show "HELD 3s+ - triggered!"
;     with a beep
;   - Quick tap -> should show "released early at Xms"
;   - Normal mouse click/drag -> should behave the same as touch, since
;     this only watches the left button, not touch-vs-mouse origin
;
; Right-click the AutoHotkey tray icon (bottom-right of screen, near the
; clock) and choose "Exit" to stop this when done testing.

#Requires AutoHotkey v2.0
#SingleInstance Force

HOLD_MS := 3000
downTime := 0
triggered := false

~LButton::
{
    global downTime, triggered
    downTime := A_TickCount
    triggered := false
    SetTimer(CheckHold, 50)
}

CheckHold() {
    global downTime, triggered, HOLD_MS
    if (!GetKeyState("LButton")) {
        SetTimer(CheckHold, 0)
        return
    }
    if (!triggered && (A_TickCount - downTime) >= HOLD_MS) {
        triggered := true
        ToolTip("HELD " HOLD_MS/1000 "s+ - triggered!")
        SoundBeep(800, 300)
        SetTimer(CheckHold, 0)
        SetTimer(() => ToolTip(), -3000)
    }
}

~LButton Up::
{
    global downTime, triggered
    SetTimer(CheckHold, 0)
    if (!triggered) {
        gap := A_TickCount - downTime
        ToolTip("released early at " gap "ms")
        SetTimer(() => ToolTip(), -3000)
    }
}
