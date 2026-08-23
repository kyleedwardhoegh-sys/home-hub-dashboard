; Guided touch/mouse diagnostic. Walks through a series of specific actions
; one at a time and reports exactly what AutoHotkey detected for each - so
; we get one clean, complete picture instead of testing one variable per
; round-trip message.
;
; Just double-click this file to run it directly on the normal desktop -
; no kiosk mode needed. Click "Next" to see each instruction, perform the
; action described, then click "Next" again to see what was detected and
; move to the following step. Results accumulate in the box so you can
; scroll back through everything at the end - copy/paste the whole box's
; contents back when done.
;
; Right-click the AutoHotkey tray icon (bottom-right of screen, near the
; clock) and choose "Exit" to stop this when done testing.

#Requires AutoHotkey v2.0
#SingleInstance Force

steps := [
    "LEFT-CLICK once with your MOUSE`n(single click, release immediately)",
    "RIGHT-CLICK once with your MOUSE`n(single click, release immediately)",
    "TAP once on the touchscreen`n(quick tap, lift immediately - do not hold)",
    "TOUCH AND HOLD on the touchscreen`nKeep your finger PERFECTLY STILL for 3 full seconds, then lift",
    "TOUCH AND HOLD again on the touchscreen`nTry to hold even MORE still this time, for 3 full seconds, then lift",
    "LEFT-CLICK and HOLD with your MOUSE for 3 seconds, then release",
    "DOUBLE-TAP on the touchscreen`n(two quick taps close together)",
    "TOUCH AND HOLD for a full 5 seconds this time`n(longer duration), then lift"
]

log := []
currentStepStart := 0
stepIndex := 0

LogEvent(type) {
    global log, currentStepStart
    log.Push({time: A_TickCount - currentStepStart, type: type, eventInfo: Format("0x{:X}", A_EventInfo)})
}

~LButton::LogEvent("LEFT DOWN")
~LButton Up::LogEvent("LEFT UP")
~RButton::LogEvent("RIGHT DOWN")
~RButton Up::LogEvent("RIGHT UP")
~MButton::LogEvent("MIDDLE DOWN")

mainGui := Gui("+AlwaysOnTop", "Touch/Mouse Diagnostic")
mainGui.SetFont("s12")
mainGui.Add("Text", "w560", "Instruction:")
stepText := mainGui.Add("Text", "w560 h60 wrap cBlue", "Click 'Next' below to begin.")
mainGui.Add("Text", "w560 y+10", "Results so far (scroll to review all):")
resultText := mainGui.Add("Edit", "w560 h280 ReadOnly Multi VScroll y+5")
btnNext := mainGui.Add("Button", "w560 h50 y+10", "Next")

btnNext.OnEvent("Click", NextStep)

NextStep(*) {
    global steps, stepIndex, log, currentStepStart, stepText, resultText, btnNext

    if (stepIndex > 0) {
        summary := "=== Step " stepIndex ": " StrReplace(steps[stepIndex], "`n", " ") " ===`r`n"
        if (log.Length = 0) {
            summary .= "  NOTHING detected.`r`n`r`n"
        } else {
            for entry in log
                summary .= "  " entry.type " at +" entry.time "ms, eventInfo=" entry.eventInfo "`r`n"
            summary .= "`r`n"
        }
        resultText.Value := resultText.Value . summary
        ; scroll to bottom
        SendMessage(0x115, 7, 0, resultText.Hwnd) ; WM_VSCROLL, SB_BOTTOM
    }

    if (stepIndex >= steps.Length) {
        stepText.Value := "All done! Scroll through the results above and send them back."
        btnNext.Enabled := false
        return
    }

    log := []
    currentStepStart := A_TickCount
    stepText.Value := "Step " (stepIndex + 1) " of " steps.Length ": " steps[stepIndex + 1]
    btnNext.Text := (stepIndex = 0) ? "I did it - Next" : "I did it - Next"
    stepIndex++
}

mainGui.Show("w600 h480")
