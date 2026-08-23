; Standalone touch/hold diagnostic v2 - testing whether a touch-and-hold
; is actually arriving as a RIGHT-CLICK instead of a sustained left-button
; hold. Windows has a built-in "press and hold to right-click" gesture for
; touchscreens that can intercept a hold before it ever reaches an app as
; a continuously-held left button - the first version of this test showed
; "Released after 0ms" on a real touch-hold (vs. working fine with a real
; mouse hold), which is the telltale sign of exactly this.
;
; Just double-click this file to run it directly on the normal desktop -
; no kiosk mode needed. Touch and hold anywhere. If the theory is right,
; you should see "RIGHT-CLICK detected!" appear (and hear a beep) once
; Windows finishes recognizing the hold gesture, WITHOUT needing our own
; 3-second timer at all.
;
; Right-click the AutoHotkey tray icon (bottom-right of screen, near the
; clock) and choose "Exit" to stop this when done testing.

#Requires AutoHotkey v2.0
#SingleInstance Force

~LButton::
{
    ToolTip("LEFT button event seen")
    SetTimer(() => ToolTip(), -1500)
}

~RButton::
{
    ToolTip("RIGHT-CLICK detected! (this is what a touch-hold likely becomes)")
    SoundBeep(800, 300)
    SetTimer(() => ToolTip(), -3000)
}
