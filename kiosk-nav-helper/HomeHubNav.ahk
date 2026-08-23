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
; (2026-08-23, see TestTouch.ahk) that Windows' own "press and hold to
; right-click" touchscreen gesture intercepts a sustained touch before it
; ever reaches an app as a continuously-held left button (GetKeyState
; reported "0ms held" on a real touch-hold that visibly lasted seconds,
; while a real mouse hold worked fine - the telltale sign of this OS-level
; gesture consuming it first). So the hold-detection is already done for
; us by Windows; we just listen for the right-click it produces once
; recognition completes, rather than reimplementing hold-timing that
; competes with the OS for the same input.
;
; Deliberately brute-force simple after a custom always-on-top menu
; (Back/Exit buttons) proved hard to get rendering reliably during
; testing - this trades a fancier UI for something that just works, with
; room to make it more elegant later once the basic mechanism is confirmed
; solid on the real kiosk.

#Requires AutoHotkey v2.0
#SingleInstance Force

~RButton::Run("osk.exe")
