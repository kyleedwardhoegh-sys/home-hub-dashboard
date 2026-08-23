; Standalone touch/hold diagnostic v4 - the touch-vs-mouse signature check
; (A_EventInfo & 0xFFFFFF00) = 0xFF515700) turned out to filter out the
; touch-hold too, not just real mouse clicks - so that exact magic number
; isn't right for this hardware/driver. This version shows the RAW
; A_EventInfo value (in hex) for every right-click, mouse or touch, so we
; can see the actual numbers instead of guessing.
;
; Just double-click this file to run it directly on the normal desktop -
; no kiosk mode needed.
;   - Right-click with the MOUSE somewhere -> note the hex value shown.
;   - Touch and hold on the touchscreen -> note the hex value shown.
; Compare the two - whatever's different between them is what we filter on.
;
; Right-click the AutoHotkey tray icon (bottom-right of screen, near the
; clock) and choose "Exit" to stop this when done testing.

#Requires AutoHotkey v2.0
#SingleInstance Force

~RButton::
{
    ToolTip("RIGHT-CLICK, A_EventInfo = 0x" Format("{:X}", A_EventInfo))
    SoundBeep(600, 150)
    SetTimer(() => ToolTip(), -4000)
}
