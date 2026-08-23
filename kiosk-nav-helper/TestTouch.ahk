; Standalone touch/hold diagnostic v5 - testing the timing-gap filter
; (confirmed via DiagnosticRoutine.ahk: touch-hold's RIGHT DOWN and RIGHT
; UP land at the exact same millisecond; a real mouse click has some gap).
;
; Just double-click this file to run it directly on the normal desktop -
; no kiosk mode needed.
;   - Right-click with the MOUSE somewhere -> should say "MOUSE (ignored)"
;   - Touch and hold on the touchscreen -> should say "TOUCH (triggered!)"
;     with a beep
;
; Right-click the AutoHotkey tray icon (bottom-right of screen, near the
; clock) and choose "Exit" to stop this when done testing.

#Requires AutoHotkey v2.0
#SingleInstance Force

rightDownTime := 0

~RButton::
{
    global rightDownTime
    rightDownTime := A_TickCount
}

~RButton Up::
{
    global rightDownTime
    gap := A_TickCount - rightDownTime
    if (gap < 50) {
        ToolTip("TOUCH (triggered!) - gap was " gap "ms")
        SoundBeep(800, 300)
    } else {
        ToolTip("MOUSE (ignored) - gap was " gap "ms")
    }
    SetTimer(() => ToolTip(), -3000)
}
