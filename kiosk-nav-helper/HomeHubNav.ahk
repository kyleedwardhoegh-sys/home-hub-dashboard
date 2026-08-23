; Kiosk escape hatch. Runs alongside the kiosk browser as its own native
; process - not a browser extension, not injected into any page - so it
; works no matter what's on screen. Hold anywhere on the touchscreen for 3
; seconds to open Windows' built-in accessibility On-Screen Keyboard
; (osk.exe), which - unlike most virtual/touch keyboards - is specifically
; trusted by Windows to send a real Ctrl+Alt+Del (the Secure Attention
; Sequence), giving a touch-only path to the same "Ctrl+Alt+Del -> Task
; Manager -> End Task" exit already documented in HANDOFF.md.
;
; Deliberately brute-force simple (2026-08-23) after a custom always-on-top
; menu (Back/Exit buttons) proved hard to get rendering reliably during
; testing - this trades a fancier UI for something that just works, with
; room to make it more elegant later once the basic mechanism is confirmed
; solid on the real touchscreen.

#Requires AutoHotkey v2.0
#SingleInstance Force

HOLD_MS := 3000

~LButton::
{
    global HOLD_MS
    startTime := A_TickCount
    while GetKeyState("LButton") {
        if (A_TickCount - startTime >= HOLD_MS) {
            Run("osk.exe")
            while GetKeyState("LButton")
                Sleep(50)
            return
        }
        Sleep(50)
    }
}
