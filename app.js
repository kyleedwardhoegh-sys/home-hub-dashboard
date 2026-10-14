// ---- Config ----
const LAT = 45.0725;
const LON = -93.4557; // Maple Grove, MN
const WEATHER_REFRESH_MS = 15 * 60 * 1000; // 15 min
const IDLE_TIMEOUT_MS = 25 * 1000; // return to ambient after 25s of no touch

const CALENDAR_REFRESH_MS = 15 * 60 * 1000; // 15 min

const WORKOUT_API_BASE = "https://script.google.com/macros/s/AKfycbyyOY00079KTcqhRtuoE_W_OhRTZGlsHgfSTgryrTl3ZzsVFHwiA54bJ55hu7qChYyxGQ/exec";
const WORKOUT_POLL_MS = 60 * 1000; // 1 min - frequent enough that the celebration feels close to real-time

const PEOPLE = {
  kyle:   { name: "Kyle",   initials: "KY", kind: "parent" },
  logan:  { name: "Logan",  initials: "LO", kind: "parent" },
  nash:   { name: "Nash",   initials: "NA", kind: "kid", apiKid: "Nash" },
  nellie: { name: "Nellie", initials: "NE", kind: "kid", apiKid: "Nellie" },
};

let lastCalendarEvents = [];

// ---- Launcher tiles: which ones show, on/off per household ----
// This is what Logan actually meant by "widgets" - the options you see
// after tapping in (the launcher grid), not the ambient clock screen's own
// info (that stays as-is). Device-local preference (localStorage), not
// synced anywhere - there's only one physical screen this applies to.
// Settings itself is never in this list - it can't be hidden, or there'd
// be no way back into this screen to turn it back on.
const LAUNCHER_TILES = [
  { id: "workouts", label: "Workouts", tileId: "tile-workouts" },
  { id: "football", label: "Practice Planner", tileId: "tile-football" },
  { id: "team", label: "Team Site", tileId: "tile-team" },
  { id: "calendar", label: "Calendar", tileId: "tile-calendar" },
];

function isWidgetEnabled(id) {
  const stored = localStorage.getItem(`widget:${id}`);
  return stored === null ? true : stored === "on";
}

function setWidgetEnabled(id, enabled) {
  localStorage.setItem(`widget:${id}`, enabled ? "on" : "off");
}

function applyLauncherTileVisibility() {
  for (const t of LAUNCHER_TILES) {
    document.getElementById(t.tileId).hidden = !isWidgetEnabled(t.id);
  }
}

// WMO weather codes -> emoji + label
// https://open-meteo.com/en/docs (weather_code field)
const WEATHER_CODES = {
  0: ["☀️", "Clear"],
  1: ["🌤️", "Mostly Clear"],
  2: ["⛅", "Partly Cloudy"],
  3: ["☁️", "Cloudy"],
  45: ["🌫️", "Foggy"],
  48: ["🌫️", "Foggy"],
  51: ["🌦️", "Light Drizzle"],
  53: ["🌦️", "Drizzle"],
  55: ["🌧️", "Heavy Drizzle"],
  61: ["🌦️", "Light Rain"],
  63: ["🌧️", "Rain"],
  65: ["🌧️", "Heavy Rain"],
  66: ["🌧️", "Freezing Rain"],
  67: ["🌧️", "Freezing Rain"],
  71: ["🌨️", "Light Snow"],
  73: ["❄️", "Snow"],
  75: ["❄️", "Heavy Snow"],
  77: ["❄️", "Snow Grains"],
  80: ["🌦️", "Rain Showers"],
  81: ["🌧️", "Rain Showers"],
  82: ["⛈️", "Heavy Showers"],
  85: ["🌨️", "Snow Showers"],
  86: ["❄️", "Snow Showers"],
  95: ["⛈️", "Thunderstorm"],
  96: ["⛈️", "Thunderstorm"],
  99: ["⛈️", "Thunderstorm"],
};

// ---- Swallow the first touch after regaining visibility ----
// Dismissing something covering the kiosk (observed: the Windows lock
// screen) can deliver that same physical touch through to whatever's
// underneath - reported 2026-08-23: a single tap to unlock also opened a
// launcher tile if a finger happened to land on one. Chromium reports the
// page as hidden while the session is locked, so briefly swallowing the
// next touch after visibility returns absorbs that one without requiring
// people to tap twice under normal use.
let ignoreNextTouch = false;
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible") {
    ignoreNextTouch = true;
    setTimeout(() => { ignoreNextTouch = false; }, 400);
  }
});
document.addEventListener("pointerdown", (e) => {
  if (ignoreNextTouch) {
    ignoreNextTouch = false;
    e.stopImmediatePropagation();
    e.preventDefault();
  }
}, { capture: true });

// ---- Clock ----
function updateClock() {
  const now = new Date();
  const clockEl = document.getElementById("clock");
  const dateEl = document.getElementById("date");
  clockEl.textContent = now.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  dateEl.textContent = now.toLocaleDateString([], { weekday: "long", month: "long", day: "numeric" });
}
updateClock();
setInterval(updateClock, 10 * 1000);

// ---- Weather ----
async function updateWeather() {
  try {
    const url = `https://api.open-meteo.com/v1/forecast?latitude=${LAT}&longitude=${LON}` +
      `&current=temperature_2m,weather_code&temperature_unit=fahrenheit&timezone=auto`;
    const res = await fetch(url, { cache: "no-store" });
    const data = await res.json();
    const temp = Math.round(data.current.temperature_2m);
    const code = data.current.weather_code;
    const [icon, desc] = WEATHER_CODES[code] || ["🌡️", "—"];

    document.getElementById("weather-icon").textContent = icon;
    document.getElementById("weather-temp").textContent = `${temp}°`;
    document.getElementById("weather-desc").textContent = desc;
    document.getElementById("weather").hidden = false;
  } catch (err) {
    // Offline or API hiccup - just leave weather hidden, everything else keeps working.
    console.warn("Weather fetch failed:", err);
  }
}
updateWeather();
setInterval(updateWeather, WEATHER_REFRESH_MS);

// ---- Calendar ----
function escapeHtml(str) {
  const div = document.createElement("div");
  div.textContent = str;
  return div.innerHTML;
}

async function updateCalendar() {
  const calendarEl = document.getElementById("calendar-events");
  try {
    const res = await fetch("/api/calendar", { cache: "no-store" });
    if (!res.ok) throw new Error(`Calendar API ${res.status}`);
    const data = await res.json();
    const events = data.events || [];
    lastCalendarEvents = events;

    if (events.length === 0) {
      calendarEl.hidden = true;
      return;
    }

    calendarEl.innerHTML = events.map((ev) => {
      const name = escapeHtml(ev.summary || "(untitled)");
      const time = ev.start.dateTime
        ? new Date(ev.start.dateTime).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
        : "All day";
      return `<span class="calendar-item"><span class="calendar-name">📅 ${name}</span><span class="calendar-time">${time}</span></span>`;
    }).join("");
    calendarEl.hidden = false;
  } catch (err) {
    // Offline, API hiccup, or env var not set up yet - just leave it hidden.
    console.warn("Calendar fetch failed:", err);
    calendarEl.hidden = true;
    lastCalendarEvents = [];
  }
}
updateCalendar();
setInterval(updateCalendar, CALENDAR_REFRESH_MS);

// ---- View switching: ambient <-> launcher <-> person <-> settings ----
const ambientView = document.getElementById("ambient");
const launcherView = document.getElementById("launcher");
const personView = document.getElementById("person");
const settingsView = document.getElementById("settings");
let idleTimer = null;

function hideAllViews() {
  for (const view of [ambientView, launcherView, personView, settingsView]) {
    view.classList.remove("active");
    view.hidden = true;
  }
}

function showLauncher() {
  applyLauncherTileVisibility();
  hideAllViews();
  currentPersonView = null;
  launcherView.classList.add("active");
  launcherView.hidden = false;
  resetIdleTimer();
}

function showAmbient() {
  hideAllViews();
  currentPersonView = null;
  ambientView.classList.add("active");
  ambientView.hidden = false;
  clearTimeout(idleTimer);
}

function showPerson(id) {
  renderPersonView(id);
  hideAllViews();
  currentPersonView = id;
  personView.hidden = false;
  personView.classList.add("active");
  resetIdleTimer();
}

function showSettings() {
  renderSettings();
  hideAllViews();
  currentPersonView = null;
  settingsView.hidden = false;
  settingsView.classList.add("active");
  resetIdleTimer();
}

function resetIdleTimer() {
  clearTimeout(idleTimer);
  idleTimer = setTimeout(showAmbient, IDLE_TIMEOUT_MS);
}

ambientView.addEventListener("pointerdown", showLauncher);
launcherView.addEventListener("pointerdown", resetIdleTimer);
personView.addEventListener("pointerdown", resetIdleTimer);
settingsView.addEventListener("pointerdown", resetIdleTimer);

document.getElementById("tile-settings").addEventListener("pointerdown", (e) => {
  e.stopPropagation();
  showSettings();
});

function renderSettings() {
  const listEl = document.getElementById("settings-list");
  listEl.innerHTML = LAUNCHER_TILES.map((t) => {
    const on = isWidgetEnabled(t.id);
    return `
      <div class="settings-row">
        <div class="settings-row-label">${escapeHtml(t.label)}</div>
        <button class="toggle-switch ${on ? "on" : ""}" type="button" data-widget="${t.id}"></button>
      </div>
    `;
  }).join("");

  listEl.querySelectorAll(".toggle-switch").forEach((btn) => {
    btn.addEventListener("pointerdown", (e) => {
      e.stopPropagation();
      const id = btn.dataset.widget;
      const nowOn = !isWidgetEnabled(id);
      setWidgetEnabled(id, nowOn);
      btn.classList.toggle("on", nowOn);
    });
  });
}

// ---- Avatars: tap in to a personalized board ----
document.getElementById("avatar-row").addEventListener("pointerdown", (e) => {
  const chip = e.target.closest(".avatar-chip");
  if (!chip) return;
  e.stopPropagation(); // don't also trigger the ambient view's "open launcher" handler
  showPerson(chip.dataset.person);
});

function renderPersonView(id) {
  const person = PEOPLE[id];
  const contentEl = document.getElementById("person-content");
  document.getElementById("person-badge").textContent = person.initials;
  document.getElementById("person-greeting").textContent = `Hey, ${person.name}`;
  personView.style.setProperty("--accent", `var(--${id})`);
  personView.style.setProperty("--accent-dark", `var(--${id}-dark)`);

  if (person.kind === "kid") {
    const s = trainingByKid[person.apiKid];
    const openLink = `<a class="training-open" href="${TRAINING_URL}?p=${encodeURIComponent(person.apiKid)}&kiosk=1">Open ${escapeHtml(person.name)}'s Training →</a>`;
    if (!s) {
      contentEl.innerHTML = `<div class="person-empty">Loading training…</div>${openLink}`;
      return;
    }
    const pct = (a, b) => Math.max(0, Math.min(100, b ? (a / b) * 100 : 0));
    const weekly = s.weekly
      ? `<div class="training-week">
          <div class="training-week-top"><span>This week: ${escapeHtml(s.weekly.prize)}</span>
            <b>${s.week >= s.weekly.target ? "BOOM!" : `${s.week}/${s.weekly.target}`}</b></div>
          <div class="training-bar"><i style="width:${pct(s.week, s.weekly.target)}%"></i></div>
        </div>`
      : "";
    contentEl.innerHTML = `
      <div class="training-today"><b>${s.today}</b> achievement${s.today === 1 ? "" : "s"} today</div>
      ${weekly}
      <div class="training-pick">Tap a time of day to start:</div>
      ${s.tracks.map((t) => `
        <a class="workout-card track-link ${t.total && t.done >= t.total ? "done" : ""}"
           href="${TRAINING_URL}?p=${encodeURIComponent(person.apiKid)}&track=${encodeURIComponent(t.name.toLowerCase().replace(/\s+/g, ""))}&kiosk=1">
          <span class="workout-status">${t.total && t.done >= t.total ? "✓" : ""}</span>
          <div class="training-track">
            <div class="workout-name">${escapeHtml(t.name)}</div>
            <div class="workout-meta">${t.total ? (t.done >= t.total ? "Must-dos done!" : `${t.total - t.done} must-do sets to go`) : "Pick anything"} · ${t.pts} achievement${t.pts === 1 ? "" : "s"}</div>
            <div class="training-bar small"><i style="width:${pct(t.done, t.total)}%"></i></div>
          </div>
          <span class="track-go">›</span>
        </a>`).join("")}
      ${openLink}`;
  } else {
    if (lastCalendarEvents.length === 0) {
      contentEl.innerHTML = `<div class="person-empty">Nothing on the calendar today.</div>`;
      return;
    }
    contentEl.innerHTML = lastCalendarEvents.map((ev) => {
      const name = escapeHtml(ev.summary || "(untitled)");
      const time = ev.start.dateTime
        ? new Date(ev.start.dateTime).toLocaleTimeString([], { hour: "numeric", minute: "2-digit" })
        : "All day";
      return `<div class="person-event"><span>📅 ${name}</span><span class="time">${time}</span></div>`;
    }).join("");
  }
}

// ---- Training Hub (HomeHub-Web v2): today's progress + celebrations ----
// Reads the same Apps Script API as the Training Hub (`getHub`). Celebrates when a
// kid finishes every must-do set on a track, or when their weekly prize goes BOOM.
const TRAINING_URL = "https://home-hub-web-hoegh-home.vercel.app/";
let trainingByKid = {}; // apiKid -> summary
let seenWins = null; // null until the first poll establishes a baseline
let currentPersonView = null; // which person board is open, if any, so it can live-update

function localDate() {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

function summarizeHub(hub) {
  const tracks = (hub.player.tracks || []).map((name) => {
    const t = hub.tracks[name] || { must: [], options: [] };
    const all = t.must.concat(...t.options.map((g) => g.items));
    const setsDone = (it) => { let n = 0; for (let s = 1; s <= it.sets; s++) if (hub.done[`${name}|${it.id}|${s}`]) n++; return n; };
    return {
      name,
      total: t.must.reduce((a, it) => a + it.sets, 0),
      done: t.must.reduce((a, it) => a + setsDone(it), 0),
      pts: all.reduce((a, it) => a + setsDone(it) * it.pts, 0),
    };
  });
  return { date: hub.date, today: hub.points.today, week: hub.points.week, weekly: hub.prizes.weekly, tracks };
}

async function pollWorkouts() {
  const kids = Object.values(PEOPLE).filter((p) => p.kind === "kid");
  const wins = new Map(); // key -> {person, title, sub}
  // Both kids at once: each Apps Script call takes 2-5 s, so one after the other doubled the wait.
  await Promise.all(kids.map(async (person) => {
    try {
      const url = `${WORKOUT_API_BASE}?action=getHub&player=${encodeURIComponent(person.apiKid)}&date=${localDate()}&_t=${Date.now()}`;
      const hub = await (await fetch(url, { cache: "no-store" })).json();
      if (hub.error) throw new Error(hub.error);
      const s = summarizeHub(hub);
      trainingByKid[person.apiKid] = s;
      for (const t of s.tracks) {
        if (t.total && t.done >= t.total) wins.set(`${s.date}|${person.apiKid}|${t.name}`, { person, title: `${person.name} finished ${t.name}!`, sub: "Every must-do set done" });
      }
      if (s.weekly && s.week >= s.weekly.target) {
        wins.set(`week|${person.apiKid}|${s.weekly.prize}|${s.weekly.target}`, { person, title: `${person.name} hit BOOM!`, sub: s.weekly.prize });
      }
    } catch (err) {
      console.warn(`Training poll failed for ${person.name}:`, err);
    }
  }));

  if (seenWins === null) {
    // First poll after load: just establish the baseline, don't celebrate
    // for things that were already done before the kiosk was looking.
    seenWins = new Set(wins.keys());
  } else {
    for (const [k, w] of wins) if (!seenWins.has(k)) triggerCelebration(w);
    for (const k of wins.keys()) seenWins.add(k);
  }

  // If a kid's board happens to be open right now, refresh it live.
  if (currentPersonView && PEOPLE[currentPersonView].kind === "kid") {
    renderPersonView(currentPersonView);
  }
}
pollWorkouts();
setInterval(pollWorkouts, WORKOUT_POLL_MS);

const CELEBRATION_EMOJI = ["🔥", "🎉", "💪", "⭐"];

function triggerCelebration(win) {
  document.getElementById("celebration-emoji").textContent =
    CELEBRATION_EMOJI[Math.floor(Math.random() * CELEBRATION_EMOJI.length)];
  document.getElementById("celebration-title").textContent = win.title;
  document.getElementById("celebration-sub").textContent = win.sub;

  const celebrationEl = document.getElementById("celebration");
  celebrationEl.hidden = false;
  setTimeout(() => { celebrationEl.hidden = true; }, 4000);
}

// ---- Pick up new versions by itself ----
// The kiosk never reloads on its own, so changes to this dashboard used to need a kiosk
// restart. Every 5 minutes, check whether app.js changed on the server; if it did and
// nobody has touched the screen for 2 minutes, reload.
let codeTag = null;
let lastTouch = Date.now();
document.addEventListener("pointerdown", () => { lastTouch = Date.now(); }, true);
async function checkForUpdate() {
  try {
    const r = await fetch(`app.js?_t=${Date.now()}`, { method: "HEAD", cache: "no-store" });
    const tag = r.headers.get("etag") || r.headers.get("last-modified");
    if (!tag) return;
    if (codeTag === null) { codeTag = tag; return; }
    if (tag !== codeTag && Date.now() - lastTouch > 120000) location.reload();
  } catch (e) { /* offline: try again next time */ }
}
if (location.protocol.startsWith("http")) { checkForUpdate(); setInterval(checkForUpdate, 5 * 60000); }
