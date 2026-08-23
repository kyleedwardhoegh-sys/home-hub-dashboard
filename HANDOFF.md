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
   per Home Hub app, linking to each sibling's live Vercel deployment:
   Workouts, Practice Planner, Team Site, plus a disabled "Calendar — Coming
   Soon" tile (calendar was flagged back in `HomeHub-Web/HANDOFF.md` as the
   natural next module, then actually built — see "Calendar" section below).
   Auto-returns to the ambient view after ~25s of no touch.

## Why it's built this way

- **No local server dependency at runtime.** The kiosk launcher points the
  browser at the deployed Vercel URL, not `localhost` — so there's no
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

`start-kiosk.ps1` launches Microsoft Edge in fullscreen kiosk mode against
the live Vercel deployment, under its own isolated `--user-data-dir`
(`%LOCALAPPDATA%\HomeHubKioskProfileEdgeDev`) rather than Kyle's regular
browser profile — this PC is also used for everyday/dev work with a
regular browser open, and Chromium-based browsers only honor startup
flags like `--kiosk` when actually launching a fresh process; handing off
to an already-running instance (same profile) silently drops `--kiosk`
and just opens a normal window instead. The isolated profile guarantees a
real kiosk instance every time, and also lets tooling reliably tell the
kiosk apart from Kyle's regular browsing when checking whether it's
running. Uses `--edge-kiosk-type=fullscreen`, not the default
`public-browsing` type — the latter is built for walk-up-and-use public
terminals and resets the session via an on-screen "End session" button,
which is wrong for a persistent ambient family dashboard.

It's wired to two Task Scheduler entries (both at-logon-trigger, "Owner"
user): `HomeHubKiosk` (launches once at logon) and `HomeHubKioskWatchdog`
(runs `watchdog.ps1` every 5 minutes, relaunching the kiosk if it isn't
running — recovers from a crash or an accidental close without needing a
reboot). **The watchdog task can be paused** (`Disable-ScheduledTask
-TaskName "HomeHubKioskWatchdog"`, `Enable-ScheduledTask` to resume) when
Kyle is actively doing hands-on dev/testing on this machine and doesn't
want the kiosk popping back up every 5 minutes after he closes it — the
logon task is unaffected either way. Note this only stops the *automatic*
recheck; manually re-running `watchdog.ps1` (e.g. while testing it)
bypasses the pause and will relaunch the kiosk regardless.

### Why Edge, not Chrome

Originally built on Chrome (Kyle's general preference elsewhere). Switched
to Edge 2026-08-22 by Kyle's explicit choice — he wanted a Microsoft
product on his Windows system, not a technical requirement.

**To exit kiosk mode: Ctrl+Alt+Del → Task Manager → End Task on Edge.**
This is the reliable fallback — Edge's `--kiosk` mode deliberately
disables Alt+F4 and other in-browser exit shortcuts so a stray keypress
can't kick someone out. Ctrl+Alt+Del is an OS-level secure attention
sequence the browser has no ability to intercept. (Separately, Win+D or
Alt+Tab let you peek at other windows — e.g. to check on a Claude Code
session — without disturbing the kiosk at all; only fully closing Edge
via Task Manager stops it.) For everyday use there's also the touch-only
exit below, which doesn't need a keyboard at all.

### Universal navigation: `kiosk-extension/`

**Rearchitected 2026-08-23** after the original per-app approach (each of
the four Home Hub repos carrying its own copy of the same gesture/button
JS, plus a per-origin allowlist policy) turned out not to scale: every
new app, or any page not built for this, would need the same code
duplicated in again. Kyle's framing: "whatever gets run from our home app
doesn't need to be modified... universal, if you touch for 3 seconds
anywhere it will pop up a back or exit option." The per-app version was
fully ripped out of all four repos (see git history) and replaced with a
single browser extension, `kiosk-extension/` in this repo, loaded via
`--load-extension` in `start-kiosk.ps1`.

`kiosk-extension/content.js` is injected by the browser itself into
**every page the kiosk shows** (`"matches": ["<all_urls>"]` in
`manifest.json`) — not per-app code, so it works on any current or future
Home Hub app, or even a page never built for this. Holding the
bottom-right 70x70px corner for 3 seconds (a small semi-transparent dot
grows as feedback — deliberately unlabeled, not something Nash or Nellie
would stumble into) opens a small menu:
- **⬅ Back** — `history.back()`, works on any page, no site cooperation
  needed.
- **✕ Exit Kiosk** — navigates to the custom `homehubadmin://exit` URL
  scheme, registered machine-wide in `HKCU` (via `register-exit-handler.ps1`,
  no admin elevation needed) to run `exit-kiosk.ps1`, which closes the
  kiosk's isolated Edge process (gracefully first via `CloseMainWindow()`,
  force-killing only what's still running after 2s).

This replaced the earlier separate, per-app visible 🏠 Home button and
video ✕ close buttons too — one universal mechanism covers both what
those did and the hidden exit gesture. Kyle also noted Edge's swipe-back
gesture already works for in-kiosk back-navigation between apps, which
this complements rather than replaces.

### Why Edge Dev channel, not Stable

**This is the load-bearing decision that makes the extension work at
all.** Edge Stable permanently and undismissably disables any extension
loaded via `--load-extension` (the only way to load an unpacked one) —
confirmed via Microsoft's own support article ("Developer mode extension
notification"), not just observed behavior: *"To protect all Microsoft
Edge users from any risk of exploitation through side-loading, we don't
allow dismissing the notification... Microsoft recommends using Dev or
Canary channel for testing your extensions."* The extension's enable
toggle in `edge://extensions` is itself non-interactive on Stable — this
isn't a setting to find, there genuinely is no way to keep it enabled
there short of packaging it as a signed `.crx` and force-installing it
via policy (real, non-trivial work: Chromium's binary CRX3 format,
protobuf header, cryptographic signing — considered and rejected as more
risk than switching channels).

Kyle installed **Microsoft Edge Dev** (from
[microsoftedgeinsider.com](https://www.microsoftedgeinsider.com)) on
2026-08-23. On Dev channel, confirmed via the profile's own `Secure
Preferences` file: the extension loads with `"disable_reasons":[]` (fully
enabled) and no nag dialog at all, no manual toggle needed — this is the
finding that made the whole universal-extension redesign viable.
**Tradeoff accepted:** Dev channel updates weekly instead of Stable's
slower cadence, a modest ongoing risk for a device that should just work,
worth it to avoid the alternative (CRX-signing, or a from-scratch native
overlay app outside the browser entirely — both seriously considered,
see git history/conversation around 2026-08-23 for the full comparison).

Edge Dev is a **separate installed product** from Edge Stable, with its
own executable (`Program Files\Microsoft\Edge Dev\Application\msedge.exe`)
and — important for policy setup — its **own registry policy path**:
`HKLM\SOFTWARE\Policies\Microsoft\EdgeDev`, not `...\Edge`.

**Gotcha carried over from Stable: `--edge-kiosk-type=fullscreen` runs as
an InPrivate session** (visible in the window title as "[InPrivate]") on
Dev channel too. InPrivate forgets everything between launches by design
— including "Always allow this site to open X" checkbox choices from the
external-protocol confirmation prompt that homehubadmin:// triggers. So
checking that box does NOT make the prompt go away on future launches,
no matter how carefully it's done. The fix is the same kind of
machine-level policy pattern as the extension fix: `register-exit-policy.ps1`
sets `AutoLaunchProtocolsFromOrigins` under
`HKLM\SOFTWARE\Policies\Microsoft\EdgeDev` with `allowed_origins: ["*"]`
(a wildcard, not a per-origin list — matching the extension's own
`<all_urls>` universality; untested at time of writing whether Edge
actually honors the wildcard there, worth confirming empirically). This
is a **one-time, admin-elevated setup step** (run via `Start` → search
PowerShell → "Run as administrator", not double-click or the Explorer
right-click "Run with PowerShell" — the latter doesn't self-elevate and
silently no-ops without one). Symptom if this policy is ever missing or
cleared: the PowerShell confirmation popup reappears on every hold.

If the repo ever moves/renames, re-run both `register-exit-handler.ps1`
and `register-exit-policy.ps1` — both hardcode this repo's path.

**Status as of 2026-08-23: extension confirmed loading and enabled on
Edge Dev (verified directly via the profile's `Secure Preferences` file).
The corner-hold gesture itself has NOT yet been confirmed working via a
real touch/click** — remote mouse-simulation testing gave inconsistent,
hard-to-interpret results (likely an artifact of simulating input through
this remote session rather than a real defect in the gesture code, which
is standard `pointerdown`/`pointerup`/`setTimeout` JS with nothing
Chromium-specific about it) — **next step is a real physical test on the
actual touchscreen.** If it doesn't work, check: (1) is
`register-exit-policy.ps1` re-run for the `EdgeDev` path specifically,
(2) DevTools (F12) does open even in this kiosk mode, useful for checking
`document.querySelector('#homehub-nav-marker')` exists and for reading
`chrome.runtime.lastError`-style console output if the content script
threw.

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
- **Touch-only kiosk exit gesture is built (`kiosk-extension/`, see "Kiosk
  auto-launch" above) but not yet confirmed with a real physical touch/
  click** — only verified so far that the extension loads and is enabled.
  Needs a real test on the actual touchscreen.
