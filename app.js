// ---- Config ----
const LAT = 45.0725;
const LON = -93.4557; // Maple Grove, MN
const WEATHER_REFRESH_MS = 15 * 60 * 1000; // 15 min
const IDLE_TIMEOUT_MS = 25 * 1000; // return to ambient after 25s of no touch

// Google Calendar (primary calendar's sharing must be set to public — see HANDOFF.md)
const GOOGLE_CALENDAR_API_KEY = "AIzaSyCRKm-YpuBu0TkzRIJrpbm0bxd5EwPr1zE";
const GOOGLE_CALENDAR_ID = "kyleedwardhoegh@gmail.com";
const CALENDAR_REFRESH_MS = 15 * 60 * 1000; // 15 min

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
  if (!GOOGLE_CALENDAR_API_KEY || GOOGLE_CALENDAR_API_KEY.startsWith("PASTE_")) return;
  const calendarEl = document.getElementById("calendar-events");
  try {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
    const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(GOOGLE_CALENDAR_ID)}/events` +
      `?key=${GOOGLE_CALENDAR_API_KEY}&timeMin=${startOfDay.toISOString()}&timeMax=${endOfDay.toISOString()}` +
      `&singleEvents=true&orderBy=startTime&maxResults=8`;
    const res = await fetch(url, { cache: "no-store" });
    if (!res.ok) throw new Error(`Calendar API ${res.status}`);
    const data = await res.json();
    const events = data.items || [];

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
    // Offline, API hiccup, or key not set up yet - just leave it hidden.
    console.warn("Calendar fetch failed:", err);
    calendarEl.hidden = true;
  }
}
updateCalendar();
setInterval(updateCalendar, CALENDAR_REFRESH_MS);

// ---- View switching: ambient <-> launcher ----
const ambientView = document.getElementById("ambient");
const launcherView = document.getElementById("launcher");
let idleTimer = null;

function showLauncher() {
  ambientView.classList.remove("active");
  ambientView.hidden = true;
  launcherView.classList.add("active");
  launcherView.hidden = false;
  resetIdleTimer();
}

function showAmbient() {
  launcherView.classList.remove("active");
  launcherView.hidden = true;
  ambientView.classList.add("active");
  ambientView.hidden = false;
  clearTimeout(idleTimer);
}

function resetIdleTimer() {
  clearTimeout(idleTimer);
  idleTimer = setTimeout(showAmbient, IDLE_TIMEOUT_MS);
}

ambientView.addEventListener("pointerdown", showLauncher);
launcherView.addEventListener("pointerdown", resetIdleTimer);
