; Universal kiosk navigation helper. Runs alongside the kiosk browser as its
; own native process - NOT a browser extension, NOT injected into any page.
; This is deliberate: the browser-extension approach (kiosk-extension/, now
; retired) hit a wall of Chromium-specific restrictions (Stable channel
; permanently blocking unpacked extensions, InPrivate disabling extensions
; by default, machine policies not reliably applying) that consumed many
; iterations without ever getting the gesture to fire. Watching for the
; gesture at the OS level instead sidesteps all of that entirely - it
; works identically no matter what page, app, or even non-browser content
; is on screen, which is actually MORE universal than the extension could
; ever be, not a fallback compromise.
;
; Hold the bottom-right 70x70px corner of the screen for 3 seconds to open
; a small always-on-top menu: Back (Alt+Left, works in any browser) and
; Exit Kiosk (runs exit-kiosk.ps1, same script the old extension used).

#Requires AutoHotkey v2.0
#SingleInstance Force

HOLD_MS := 3000
ZONE_SIZE := 70
AUTO_DISMISS_MS := 8000

~LButton::
{
    global HOLD_MS
    MouseGetPos(&startX, &startY)
    if (!InZone(startX, startY))
        return

    startTime := A_TickCount
    while GetKeyState("LButton", "P") {
        MouseGetPos(&curX, &curY)
        if (!InZone(curX, curY))
            return
        if (A_TickCount - startTime >= HOLD_MS) {
            ShowNavMenu()
            ; Swallow the release so it doesn't also register as a click
            ; on whatever's under the cursor once the hold completes.
            while GetKeyState("LButton", "P")
                Sleep(50)
            return
        }
        Sleep(50)
    }
}

InZone(x, y) {
    global ZONE_SIZE
    return (x > A_ScreenWidth - ZONE_SIZE) && (y > A_ScreenHeight - ZONE_SIZE)
}

ShowNavMenu() {
    global AUTO_DISMISS_MS
    navGui := Gui("+AlwaysOnTop +ToolWindow -Caption +Border", "HomeHub Nav")
    navGui.BackColor := "141414"
    navGui.MarginX := 12
    navGui.MarginY := 12
    navGui.SetFont("s13 cWhite", "Segoe UI")

    btnBack := navGui.Add("Button", "w170 h48", "⬅  Back")
    btnExit := navGui.Add("Button", "w170 h48 y+8", "✕  Exit Kiosk")

    btnBack.OnEvent("Click", (*) => (navGui.Destroy(), Send("!{Left}")))
    btnExit.OnEvent("Click", (*) => (navGui.Destroy(), RunExitKiosk()))

    x := A_ScreenWidth - 200
    y := A_ScreenHeight - 220
    navGui.Show("x" x " y" y " AutoSize")

    SetTimer(() => (WinExist("ahk_id " navGui.Hwnd) ? navGui.Destroy() : ""), -AUTO_DISMISS_MS)
}

RunExitKiosk() {
    scriptDir := A_ScriptDir "\..\exit-kiosk.ps1"
    RunWait('powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "' scriptDir '"', , "Hide")
}
