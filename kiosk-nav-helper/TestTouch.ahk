; Standalone touch/hold diagnostic - NOT part of the kiosk setup, doesn't
; need Task Scheduler or kiosk mode running. Just double-click this file to
; run it directly on the normal desktop, then touch and hold anywhere on
; the screen. Gives live feedback so we can see exactly what's happening:
;   - "TOUCH DOWN detected" the instant a press registers at all
;   - a running "Holding... Xms" counter while held
;   - a beep + "HELD 3 SECONDS" message if the hold completes
;   - a "Released after Xms" message if it's let go early
;
; Right-click the AutoHotkey tray icon (bottom-right of screen, near the
; clock) and choose "Exit" to stop this when done testing.

#Requires AutoHotkey v2.0
#SingleInstance Force

~LButton::
{
    ToolTip("TOUCH DOWN detected!")
    startTime := A_TickCount
    while GetKeyState("LButton") {
        elapsed := A_TickCount - startTime
        ToolTip("Holding... " elapsed "ms")
        if (elapsed >= 3000) {
            ToolTip("HELD 3 SECONDS - gesture works!")
            SoundBeep(800, 300)
            while GetKeyState("LButton")
                Sleep(50)
            SetTimer(() => ToolTip(), -3000)
            return
        }
        Sleep(50)
    }
    ToolTip("Released after " (A_TickCount - startTime) "ms (didn't reach 3000ms)")
    SetTimer(() => ToolTip(), -3000)
}
