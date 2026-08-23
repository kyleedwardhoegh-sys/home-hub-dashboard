; Standalone touch/hold diagnostic v3 - testing that we can tell a real
; mouse right-click apart from a touch-and-hold (which Windows converts to
; a right-click too). Without this filter, the kiosk helper was popping
; the on-screen keyboard on every ordinary mouse right-click (e.g. a File
; Explorer context menu), which is unusable on a PC that's also used for
; regular desktop/mouse work.
;
; Just double-click this file to run it directly on the normal desktop -
; no kiosk mode needed.
;   - Right-click with the MOUSE somewhere (e.g. the desktop, a file) ->
;     should say "MOUSE right-click (ignored)", no beep.
;   - Touch and hold on the touchscreen -> should say "TOUCH right-click
;     (this is the real trigger)" with a beep.
;
; Right-click the AutoHotkey tray icon (bottom-right of screen, near the
; clock) and choose "Exit" to stop this when done testing.

#Requires AutoHotkey v2.0
#SingleInstance Force

~RButton::
{
    if ((A_EventInfo & 0xFFFFFF00) = 0xFF515700) {
        ToolTip("TOUCH right-click (this is the real trigger)")
        SoundBeep(800, 300)
    } else {
        ToolTip("MOUSE right-click (ignored)")
    }
    SetTimer(() => ToolTip(), -2000)
}
