; Kiosk escape hatch. Runs alongside the kiosk browser as its own native
; process - not a browser extension, not injected into any page - so it
; works no matter what's on screen. Touch and hold anywhere on the
; touchscreen for 3 seconds to open Windows' built-in accessibility
; On-Screen Keyboard (osk.exe), which - unlike most virtual/touch
; keyboards - is specifically trusted by Windows to send a real
; Ctrl+Alt+Del (the Secure Attention Sequence), giving a touch-only path to
; the same "Ctrl+Alt+Del -> Task Manager -> End Task" exit already
; documented in HANDOFF.md.
;
; Two device-level settings (not part of this script, done once on this PC,
; see HANDOFF.md) are REQUIRED for a touch-and-hold to arrive here as a
; genuinely-timed held-down left button instead of an instant click:
;   1. Windows Settings -> Bluetooth & devices -> Touch -> Additional touch
;      settings -> "Enable press and hold to perform a right-click
;      equivalent" -> Off. Without this, Windows' own gesture recognizer
;      intercepts a sustained touch and turns it into an instantly
;      synthesized right-click (confirmed via DiagnosticRoutine.ahk: the
;      RIGHT DOWN/RIGHT UP pair landed at the same millisecond no matter
;      how long the physical hold was).
;   2. EloConfig -> Touch Settings -> Touch Mode -> "Click on Finger-up"
;      with "Enable Drag" checked (not the default "Normal (emulate
;      physical mouse)"). Per Elo's own manual (section 3.4.7): this is
;      the documented way to let a stationary touch-and-hold activate a
;      genuine Windows button-down event without needing the finger to
;      wiggle. Without this, even with setting 1 above done, a touch
;      still resolved to an instant LEFT DOWN+UP pair (confirmed: gap
;      always 0ms in TestHoldTimer.ahk regardless of physical hold time).
;
; With both set, a real touch-and-hold now behaves like a genuinely-held
; left mouse button, so this only needs a plain hold-timer - no more
; right-click timing-gap heuristics, and RButton is untouched entirely, so
; real mouse right-clicks (e.g. a File Explorer context menu during
; everyday dev work) are completely unaffected.

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
        SetTimer(CheckHold, 0)
        Run("osk.exe")
    }
}

~LButton Up::
{
    SetTimer(CheckHold, 0)
}
