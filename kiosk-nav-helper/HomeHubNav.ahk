; Kiosk navigation. Runs alongside the kiosk browser as its own native
; process - not a browser extension, not injected into any page - so it
; works no matter what's on screen and needs zero changes to any Home Hub
; app. Draws three small always-on-top native windows (plain win32
; windows, not touch-aware, so touch on them translates to normal clicks
; reliably - see HANDOFF.md for why that distinction matters here),
; sitting above the kiosk:
;
;   - Top-right: BACK. Tap to run history.back() on the kiosk tab via
;     cdp-nav.ps1 - one real step back, same as a browser back button.
;   - Bottom-left: HOME. Tap to navigate the kiosk tab straight to the
;     dashboard's ambient clock screen (also via cdp-nav.ps1). Changed
;     2026-08-24 from relaunching the whole Edge process (start-kiosk.ps1)
;     - that worked but was needlessly heavy for something this routine,
;     and force-killing Edge on every tap was found to be losing
;     just-signed-in Google sessions before Chromium finished writing them
;     to disk. Navigating the existing tab avoids both problems.
;   - Bottom-right: EXIT. Tap to close the kiosk entirely (exit-kiosk.ps1)
;     - this one still needs the process to actually end, so it's the one
;     button left that isn't just a tab navigation.
;
; Top-right/bottom-left/bottom-right were chosen specifically to avoid the
; ambient view's own avatar tap-in chips, which live in the top-left
; corner - these are native overlay windows, not part of any page, so
; they'd otherwise visually collide with the dashboard's own UI.
;
; PLAIN TAP, not tap-and-hold (changed 2026-08-24). The original hold
; design depended on EloConfig's Touch Mode being set to "Click on
; Finger-up" + "Enable Drag" - the only mode where a stationary touch
; produces a genuinely time-tracked held button (see HANDOFF.md). That
; mode turned out to break ordinary single-clicks elsewhere on the system
; (e.g. the taskbar), so it got reverted back to Elo's default "Normal
; (emulate physical mouse)" - which is required for the rest of the PC to
; work normally, but under which a touch (tap OR hold) always resolves to
; an immediate down+up pair, indistinguishable by duration. Since a hold
; can no longer be measured at all in Normal mode, these buttons trigger
; on a plain tap instead. Accidental taps aren't a real concern - all hit
; targets are small (44px) and tucked into corners nothing else on screen
; occupies.
;
; This is the THIRD design for kiosk exit specifically (see HANDOFF.md for
; the full history) - a touch-and-hold-anywhere gesture and an
; on-screen-keyboard both foundered on Chromium owning touch input inside
; its own window.

#Requires AutoHotkey v2.0
#SingleInstance Force

; Labeled pills (changed 2026-10-13 at Kyle's request: "always have back / home /
; exit buttons on every page"). The original 44px unlabeled gray dots were too easy
; to miss. Glyphs are built with Chr() so this file stays plain ASCII.
BTN_W := 156
BTN_H := 60
MARGIN := 8
repoRoot := A_ScriptDir "\.."
psPrefix := 'powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "'
cdpScript := A_ScriptDir "\cdp-nav.ps1"

BUTTONS := [
    { id: "back", label: Chr(0x2190) " Back", x: A_ScreenWidth - BTN_W - MARGIN, y: MARGIN,                          cmd: psPrefix cdpScript '" -Action back' },
    { id: "home", label: Chr(0x2302) " Home", x: MARGIN,                         y: A_ScreenHeight - BTN_H - MARGIN, cmd: psPrefix cdpScript '" -Action home' },
    { id: "exit", label: Chr(0x2715) " Exit", x: A_ScreenWidth - BTN_W - MARGIN, y: A_ScreenHeight - BTN_H - MARGIN, cmd: psPrefix repoRoot '\exit-kiosk.ps1"' }
]

for btn in BUTTONS {
    btnGui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x08000000 -DPIScale")  ; sizes below are real pixels (the PC runs at 150% scaling)
    btnGui.BackColor := "222222"
    btnGui.MarginX := 0, btnGui.MarginY := 0
    btnGui.SetFont("s13 bold cFFFFFF", "Segoe UI Symbol")
    ; 0x200 = SS_CENTERIMAGE (vertically centered). A static control passes clicks
    ; through to its parent window, so the hwnd match below still works.
    btnGui.Add("Text", Format("x0 y0 w{1} h{2} Center +0x200 BackgroundTrans", BTN_W, BTN_H), btn.label)
    btnGui.Show(Format("w{1} h{2} x{3} y{4} NoActivate", BTN_W, BTN_H, btn.x, btn.y))
    WinSetRegion(Format("0-0 W{1} H{2} R{2}-{2}", BTN_W, BTN_H), btnGui)
    WinSetTransparent(225, btnGui)
    btnGui.Hide()  ; Tick() shows them only while the kiosk is in front
    btn.gui := btnGui
    btn.hwnd := btnGui.Hwnd
}

; ---- Show the pills ONLY while the kiosk is the window in front (fixed 2026-10-14) ----
; Before this, the pills were drawn all the time: over VS Code and the desktop when
; the kiosk wasn't running (Back sat on top of other apps' close buttons), and the
; full-screen kiosk window could still cover them. Now every 500 ms: if the active
; window belongs to the kiosk's own Edge (its command line uses the kiosk profile,
; so Kyle's regular Edge never counts), show the pills and push them back to the top
; of the z-order without taking focus; otherwise hide them.
KIOSK_PROFILE := "HomeHubKioskProfile"
kioskPids := Map()  ; pid -> is it the kiosk's Edge? (cached; WMI lookups are slow)

IsKioskPid(pid) {
    global kioskPids, KIOSK_PROFILE
    if kioskPids.Has(pid)
        return kioskPids[pid]
    isKiosk := false
    try {
        for proc in ComObjGet("winmgmts:").ExecQuery("SELECT CommandLine FROM Win32_Process WHERE ProcessId=" pid)
            isKiosk := InStr(proc.CommandLine, KIOSK_PROFILE) > 0
    }
    kioskPids[pid] := isKiosk
    return isKiosk
}

KioskInFront() {
    try {
        hwnd := WinExist("A")
        if !hwnd || WinGetProcessName(hwnd) != "msedge.exe"
            return false
        return IsKioskPid(WinGetPID(hwnd))
    } catch {
        return false
    }
}

Tick() {
    global BUTTONS
    show := KioskInFront()
    for btn in BUTTONS {
        visible := DllCall("IsWindowVisible", "ptr", btn.hwnd)
        if show {
            if !visible
                btn.gui.Show("NoActivate")
            ; HWND_TOPMOST (-1), SWP_NOSIZE|SWP_NOMOVE|SWP_NOACTIVATE (0x13): back on top, no focus steal
            DllCall("SetWindowPos", "ptr", btn.hwnd, "ptr", -1, "int", 0, "int", 0, "int", 0, "int", 0, "uint", 0x13)
        } else if visible {
            btn.gui.Hide()
        }
    }
}
SetTimer(Tick, 500)
SetTimer(() => kioskPids.Clear(), 300000)  ; forget cached pids now and then (pids get reused)

activeButton := ""

~LButton::
{
    global activeButton, BUTTONS
    MouseGetPos(, , &winUnderMouse)
    activeButton := ""
    for btn in BUTTONS {
        if (winUnderMouse == btn.hwnd) {
            activeButton := btn
            break
        }
    }
}

~LButton Up::
{
    global activeButton
    if (activeButton)
        Run(activeButton.cmd)
    activeButton := ""
}
