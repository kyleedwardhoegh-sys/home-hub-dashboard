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

// ---- View switching: ambient <-> launcher <-> person ----
const ambientView = document.getElementById("ambient");
const launcherView = document.getElementById("launcher");
const personView = document.getElementById("person");
let idleTimer = null;

function hideAllViews() {
  for (const view of [ambientView, launcherView, personView]) {
    view.classList.remove("active");
    view.hidden = true;
  }
}

function showLauncher() {
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

function resetIdleTimer() {
  clearTimeout(idleTimer);
  idleTimer = setTimeout(showAmbient, IDLE_TIMEOUT_MS);
}

ambientView.addEventListener("pointerdown", showLauncher);
launcherView.addEventListener("pointerdown", resetIdleTimer);
personView.addEventListener("pointerdown", resetIdleTimer);

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
    const assignments = (workoutsByKid[person.apiKid] || []);
    if (assignments.length === 0) {
      contentEl.innerHTML = `<div class="person-empty">No workout assigned today. Enjoy the rest!</div>`;
      return;
    }
    contentEl.innerHTML = assignments.map((a) => `
      <div class="workout-card ${a.done ? "done" : ""}">
        <span class="workout-status">${a.done ? "✓" : ""}</span>
        <div>
          <div class="workout-name">${escapeHtml(a.exercise)}</div>
          <div class="workout-meta">${escapeHtml(String(a.sets))} × ${escapeHtml(String(a.reps))}</div>
        </div>
      </div>
    `).join("");
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

// ---- Workouts: today's assignments + completion celebration ----
let workoutsByKid = {}; // apiKid -> assignment[]
let seenDoneKeys = null; // null until first poll establishes a baseline
let currentPersonView = null; // which person board is open, if any, so it can live-update

function assignmentKey(a) {
  return `${a.date}|${a.kid}|${a.exercise}`;
}

async function pollWorkouts() {
  try {
    const res = await fetch(`${WORKOUT_API_BASE}?action=getAssignments&_t=${Date.now()}`, { cache: "no-store" });
    const data = await res.json();
    const assignments = Array.isArray(data) ? data : (data.assignments || []);

    const byKid = {};
    for (const a of assignments) {
      (byKid[a.kid] = byKid[a.kid] || []).push(a);
    }
    workoutsByKid = byKid;

    const doneNow = new Set(assignments.filter((a) => a.done).map(assignmentKey));

    if (seenDoneKeys === null) {
      // First poll after load: just establish the baseline, don't celebrate
      // for things that were already done before the kiosk was looking.
      seenDoneKeys = doneNow;
    } else {
      for (const a of assignments) {
        if (a.done && !seenDoneKeys.has(assignmentKey(a))) {
          triggerCelebration(a);
        }
      }
      seenDoneKeys = doneNow;
    }

    // If a kid's board happens to be open right now, refresh it live.
    if (currentPersonView && PEOPLE[currentPersonView].kind === "kid") {
      renderPersonView(currentPersonView);
    }
  } catch (err) {
    console.warn("Workout poll failed:", err);
  }
}
pollWorkouts();
setInterval(pollWorkouts, WORKOUT_POLL_MS);

const CELEBRATION_EMOJI = ["🔥", "🎉", "💪", "⭐"];

function triggerCelebration(assignment) {
  const person = Object.values(PEOPLE).find((p) => p.apiKid === assignment.kid);
  if (!person) return;

  document.getElementById("celebration-emoji").textContent =
    CELEBRATION_EMOJI[Math.floor(Math.random() * CELEBRATION_EMOJI.length)];
  document.getElementById("celebration-title").textContent = `${person.name} finished a workout!`;
  document.getElementById("celebration-sub").textContent = assignment.exercise;

  const celebrationEl = document.getElementById("celebration");
  celebrationEl.hidden = false;
  setTimeout(() => { celebrationEl.hidden = true; }, 4000);
}
