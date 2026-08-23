; Kiosk escape hatch. Runs alongside the kiosk browser as its own native
; process - not a browser extension, not injected into any page - so it
; works no matter what's on screen. Touch and hold anywhere on the
; touchscreen to open Windows' built-in accessibility On-Screen Keyboard
; (osk.exe), which - unlike most virtual/touch keyboards - is specifically
; trusted by Windows to send a real Ctrl+Alt+Del (the Secure Attention
; Sequence), giving a touch-only path to the same "Ctrl+Alt+Del -> Task
; Manager -> End Task" exit already documented in HANDOFF.md.
;
; Triggers on RIGHT-CLICK, not a custom hold timer - confirmed by testing
; (2026-08-23, see DiagnosticRoutine.ahk results) that Windows' own "press
; and hold to right-click" touchscreen gesture intercepts a sustained touch
; before it ever reaches an app as a continuously-held left button. So the
; hold-detection is already done for us by Windows; we listen for the
; right-click it produces once recognition completes.
;
; MUST filter to touch-originated right-clicks only - this PC also gets
; used for everyday/dev work with a real mouse, and a genuine mouse
; right-click (e.g. a File Explorer context menu) is otherwise
; indistinguishable from our trigger. An earlier version tried to filter
; using A_EventInfo's touch/pen signature bits - confirmed via
; DiagnosticRoutine.ahk that A_EventInfo is always 0x0 on this hardware,
; so that check silently blocked everything, touch included (this is why
; "touch and hold did nothing" after that change).
;
; The filter that actually works, confirmed against real logged data: a
; touch-and-hold's RIGHT DOWN and RIGHT UP arrive at the exact same
; millisecond (Windows delivers the synthesized click as one atomic pair
; once its internal hold-recognition timer completes), while even a quick
; real mouse click has some human-scale gap between press and release. So
; we time the gap between RIGHT DOWN and RIGHT UP and only trigger if it's
; near-instant.
;
; Deliberately brute-force simple after a custom always-on-top menu
; (Back/Exit buttons) proved hard to get rendering reliably during
; testing - this trades a fancier UI for something that just works, with
; room to make it more elegant later once the basic mechanism is confirmed
; solid on the real kiosk.

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
    if (A_TickCount - rightDownTime < 50)
        Run("osk.exe")
}
