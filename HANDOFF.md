# Home Hub Dashboard — Handoff Doc

The always-on landing screen for the kitchen's 43" wall-mounted touchscreen.
Built 2026-08-22 as the "parent" screen for the Home Hub family of apps —
see `HomeHub-Web/HANDOFF.md` Part 1 for the reusable static-PWA pattern this
follows (no framework, no build step, GitHub Pages hosting). This repo is
simpler than its siblings: no Google Sheet, no Apps Script backend — it's
pure client-side (clock, date, weather) plus a launcher into the other apps.

## What it is

Two views, no router, toggled by touch:

1. **Ambient (default)** — big live clock, date, and current weather for
   Maple Grove, MN (via the free, keyless Open-Meteo API). Slow-drifting
   animated gradient background. This is what the screen shows almost all
   the time — designed to look good and stay glanceable from across the
   kitchen, not to be interacted with.
2. **Launcher (tap anywhere on ambient to reveal)** — a tile grid, one tile
   per Home Hub app, linking to each sibling's live GitHub Pages URL:
   Workouts, Practice Planner, Team Site, plus a disabled "Calendar — Coming
   Soon" tile (calendar was flagged back in `HomeHub-Web/HANDOFF.md` as the
   natural next module). Auto-returns to the ambient view after ~25s of no
   touch.

## Why it's built this way

- **No local server dependency at runtime.** The kiosk launcher points
  Edge at the deployed GitHub Pages URL, not `localhost` — so there's no
  background process (like the sibling repos' `serve.ps1`) that has to stay
  alive for the display to keep working after a reboot. `serve.ps1` is
  still here for local dev/testing before pushing, same as every sibling
  repo, just not part of the kiosk's actual runtime path.
- **Burn-in mitigation.** This will render the same bright content in the
  same screen position for years. `.ambient-content` has a very slow
  (8-minute cycle), few-pixel drift animation applied via CSS
  (`content-drift` keyframe in `styles.css`) as basic LCD image-persistence
  mitigation. Background "blobs" also drift continuously so nothing stays
  perfectly static.
- **GPU-cheap animation.** All motion (background blobs, content drift) is
  `transform`-only, no canvas/particle loop, so it's fine to run 24/7 on
  modest integrated graphics.
- **Weather has no key/auth.** Open-Meteo was chosen specifically because
  it needs no API key and has no CORS issues from a static site — nothing
  to rotate or configure. Coordinates for Maple Grove, MN are hardcoded in
  `app.js` (`LAT`/`LON` constants). If weather fails to load (offline, API
  hiccup), the weather line just stays hidden — everything else still
  works.

## Kiosk auto-launch

`start-kiosk.ps1` launches Chrome (Kyle's preferred browser over Edge) in
fullscreen kiosk mode against the live Pages URL. It's meant to be wired to
a Windows Task Scheduler task with an "at log on" trigger for this user, so
the kiosk comes up on its own any time the PC is signed into — the PC uses
manual sign-in (not Windows auto-login), so this still requires a
physical/remote login once, but nothing beyond that.

**To exit kiosk mode for maintenance: Alt+F4.**

Screen timeout/sleep/hibernate and the Windows screensaver were all
disabled directly via `powercfg` and the `ScreenSaveActive` registry value
on 2026-08-22 (not simulated activity/mouse-jiggling — the real settings
fix is cleaner and was confirmed to work). If the screen ever starts going
black again, check those settings first (`powercfg /query`) before assuming
this app has a bug — a Windows update or a power-plan reset can silently
revert them.

## Live URLs

- Public app: `https://kyleedwardhoegh-sys.github.io/home-hub-dashboard/`
  (live — repo is public, Pages is enabled and built)
- Local clone: `C:\Users\Owner\source\repos\home-hub-dashboard`

## Status as of 2026-08-22

- GitHub repo created (public, matching siblings), pushed, Pages enabled
  and serving (confirmed 200).
- Task Scheduler entry `HomeHubKiosk` created (at-logon trigger, runs
  `start-kiosk.ps1` hidden/bypass), and has already run successfully once.

Confirmed mounted and running in landscape on the actual kitchen display.

## Calendar (in progress)

Today's events from Kyle's primary Google Calendar show inline on the
ambient screen, below the weather pill — small pills like `📅 Practice
5:30 PM`. No dedicated Calendar tile/agenda view (the launcher tile stays
"Coming Soon"); this was a deliberate choice to keep it glanceable rather
than another screen to tap into.

Implementation: `updateCalendar()` in `app.js` calls the Google Calendar
API v3 (`events.list`) directly from the browser with an API key — no
backend, consistent with the rest of this app. This only works because
Kyle's calendar sharing is set to public ("See all event details"); the
key is restricted (Calendar API only, HTTP referrer locked to this repo's
Pages URL) so it's safe to ship in client-side code.

Config lives at the top of `app.js`: `GOOGLE_CALENDAR_API_KEY` (live key,
restricted to Calendar API + this repo's Pages URL as HTTP referrer) and
`GOOGLE_CALENDAR_ID` (defaults to Kyle's primary calendar, i.e. his email —
change if a different calendar should be shown instead). Kyle's calendar's
public access is set to "See all event details" (not just free/busy —
free/busy access returns no event titles, which was tried and corrected
2026-08-22). Refetches every 15 min, same cadence as weather. If the fetch
fails (offline, API hiccup), the calendar line just stays hidden —
everything else keeps working, same fail-quiet pattern as weather.

Event titles are truncated with an ellipsis (`.calendar-name` in
`styles.css`, `max-width: 46vw` on the pill) because some sources (e.g.
Acuity Scheduling booking confirmations) produce long auto-generated
titles like "Nash MBT Maple Grove Training Sessions (Maple Grove
Facility)" that would blow past "glanceable from across the kitchen."

## Not yet built / open questions

- Calendar tile is still a placeholder ("Coming Soon") — a fuller agenda
  view behind it hasn't been built (not requested; inline-only was the
  chosen approach as of 2026-08-22).
