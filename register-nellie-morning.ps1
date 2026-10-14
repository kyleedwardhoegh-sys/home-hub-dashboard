# Registers the "HomeHubNellieMorning" scheduled task: every day at 5:00 AM it puts
# Nellie's Training (Morning track) on the kitchen kiosk, launching the kiosk first
# if it isn't running. Uses kiosk-nav-helper/cdp-nav.ps1 -Action open.
# Re-run this (no admin needed) if the task is ever deleted or the repo moves.
#
# StartWhenAvailable is deliberately off: if the PC was off at 5 AM, this should
# NOT fire later in the day and yank the screen to Nellie's morning list.

$script = Join-Path $PSScriptRoot "kiosk-nav-helper\cdp-nav.ps1"
$url = "https://home-hub-web-hoegh-home.vercel.app/?p=Nellie&track=morning&kiosk=1"

$action = New-ScheduledTaskAction -Execute "powershell.exe" `
  -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Action open -Url `"$url`""
$trigger = New-ScheduledTaskTrigger -Daily -At "5:00AM"
$settings = New-ScheduledTaskSettingsSet -WakeToRun -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
  -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

Register-ScheduledTask -TaskName "HomeHubNellieMorning" `
  -Description "5:00 AM daily: put Nellie's Training (Morning track) on the kitchen kiosk. See home-hub-dashboard HANDOFF.md." `
  -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force | Out-Null

Write-Host "HomeHubNellieMorning registered. Next run:" (Get-ScheduledTaskInfo -TaskName HomeHubNellieMorning).NextRunTime
