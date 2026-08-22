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
fullscreen kiosk mode against the live Vercel deployment, under its own
isolated `--user-data-dir` (`%LOCALAPPDATA%\HomeHubKioskProfile`) rather
than Kyle's regular Chrome profile — this PC is also used for everyday/dev
work with regular Chrome open, and Chrome only honors startup flags like
`--kiosk` when actually launching a fresh process; handing off to an
already-running instance (same profile) silently drops `--kiosk` and just
opens a normal window instead. The isolated profile guarantees a real
kiosk instance every time, and also lets tooling reliably tell the kiosk
apart from Kyle's regular browsing when checking whether it's running.

It's wired to two Task Scheduler entries (both at-logon-trigger, "Owner"
user): `HomeHubKiosk` (launches once at logon) and `HomeHubKioskWatchdog`
(runs `watchdog.ps1` every 5 minutes, relaunching the kiosk if it isn't
running — recovers from a crash or an accidental close without needing a
reboot).

**To exit kiosk mode: Ctrl+Alt+Del → Task Manager → End Task on Chrome.**
This is not a workaround — Chrome's `--kiosk` mode deliberately disables
Alt+F4 and other in-browser exit shortcuts so a stray keypress can't kick
someone out. Ctrl+Alt+Del is an OS-level secure attention sequence Chrome
has no ability to intercept, so it's the reliable way in regardless of
kiosk state. (Separately, Win+D or Alt+Tab let you peek at other windows —
e.g. to check on a Claude Code session — without disturbing the kiosk at
all; only fully closing Chrome via Task Manager stops it.)

Screen timeout/sleep/hibernate and the Windows screensaver were all
disabled directly via `powercfg` and the `ScreenSaveActive` registry value
on 2026-08-22 (not simulated activity/mouse-jiggling — the real settings
fix is cleaner and was confirmed to work). If the screen ever starts going
black again, check those settings first (`powercfg /query`) before assuming
this app has a bug — a Windows update or a power-plan reset can silently
revert them.

## Live URLs

- Public app (canonical, kiosk points here): `https://home-hub-dashboard.vercel.app/`
  — Vercel project under the `hoegh-home` team, auto-deploys on push to
  `main`. Migrated from GitHub Pages 2026-08-22; Deployment Protection
  ("Vercel Authentication") is turned off so it's reachable without a
  Vercel login, same as Pages was.
- GitHub Pages (`https://kyleedwardhoegh-sys.github.io/home-hub-dashboard/`)
  is still live as a side effect of Pages being enabled on the repo, but is
  no longer the canonical URL — nothing points to it anymore.
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

Implementation (rearchitected 2026-08-22, moved server-side): `app.js`'s
`updateCalendar()` calls this project's own `/api/calendar` serverless
function (Vercel Node function, `api/calendar.js`), which in turn calls
the Google Calendar API v3 (`events.list`). The Google API key now lives
only as a Vercel **environment variable** (`GOOGLE_CALENDAR_API_KEY`,
Production scope) — it is never sent to the browser and never committed
to git. This replaced an earlier version that called Google directly from
client-side JS with an embedded, referrer-restricted key; that key is
revoked (see below) since it's permanently visible in this repo's git
history regardless.

`api/calendar.js` always computes "today" itself in `America/Chicago`
(hardcoded `TIMEZONE` const) rather than trusting caller-supplied dates —
this bounds the endpoint to only ever returning today's events no matter
who calls it, since the endpoint's URL itself isn't secret. It also only
forwards `summary`/`start` to the client, not the full Google event object
(which can carry descriptions, attendee emails, meeting links). CORS is
restricted to an `ALLOWED_ORIGINS` allowlist in that file (the four Home
Hub Vercel domains) — add a new origin there if another tool needs it.

Kyle's calendar's public sharing is still set to "See all event details"
(required for API-key access at all, regardless of where the key lives —
free/busy-only access returns no event titles, which was tried and
corrected 2026-08-22). This does **not** make the calendar show up in
Google search results — that's a separate, unrelated kind of "public."

Refetches every 15 min, same cadence as weather. If the fetch fails
(offline, API hiccup, env var not set), the calendar line just stays
hidden — everything else keeps working, same fail-quiet pattern as
weather.

**Setup dependency:** `GOOGLE_CALENDAR_API_KEY` must be set in Vercel →
this project → Settings → Environment Variables (Production). If the
calendar line never appears after a fresh clone/redeploy, check that
first.

Event titles are truncated with an ellipsis (`.calendar-name` in
`styles.css`, `max-width: 46vw` on the pill) because some sources (e.g.
Acuity Scheduling booking confirmations) produce long auto-generated
titles like "Nash MBT Maple Grove Training Sessions (Maple Grove
Facility)" that would blow past "glanceable from across the kitchen."

## Not yet built / open questions

- Calendar tile is still a placeholder ("Coming Soon") — a fuller agenda
  view behind it hasn't been built (not requested; inline-only was the
  chosen approach as of 2026-08-22).
