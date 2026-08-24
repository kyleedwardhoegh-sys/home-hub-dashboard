// Serverless proxy for Google Calendar so the API key never ships to the
// browser. The window always starts "today" as computed here (Kyle's
// timezone), not from a caller-supplied start date - a caller can widen
// how many days ahead it sees (?days=N, for the agenda view) but can't
// point this endpoint at an arbitrary date.
const MAX_DAYS = 14;
const CALENDAR_ID = "kyleedwardhoegh@gmail.com";
const TIMEZONE = "America/Chicago";
const ALLOWED_ORIGINS = new Set([
  "https://home-hub-dashboard.vercel.app",
  "https://home-hub-web-hoegh-home.vercel.app",
  "https://football-practice-planner-hoegh-home.vercel.app",
  "https://maple-grove-crimson.vercel.app",
]);

export default async function handler(req, res) {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.has(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
  }
  res.setHeader("Cache-Control", "no-store");

  const apiKey = process.env.GOOGLE_CALENDAR_API_KEY;
  if (!apiKey) {
    res.status(500).json({ error: "Calendar not configured" });
    return;
  }

  // "Today" boundaries in TIMEZONE, computed without assuming anything
  // about the serverless runtime's own local timezone (Vercel doesn't
  // guarantee one). Comparing the same instant formatted in TIMEZONE vs.
  // UTC gives the real current offset (DST-aware), and that same
  // systematic shift cancels out of both round-trips - so this is correct
  // regardless of what timezone this function happens to execute in. The
  // previous version re-parsed a TIMEZONE-formatted string directly and
  // only produced the right date when the runtime's local zone was UTC -
  // fragile, and wrong right around midnight otherwise (reported
  // 2026-08-24 as the calendar showing "yesterday").
  const now = new Date();
  const offsetMs =
    new Date(now.toLocaleString("en-US", { timeZone: TIMEZONE })).getTime() -
    new Date(now.toLocaleString("en-US", { timeZone: "UTC" })).getTime();
  const zonedNow = new Date(now.getTime() + offsetMs);
  const y = zonedNow.getUTCFullYear();
  const m = zonedNow.getUTCMonth();
  const d = zonedNow.getUTCDate();
  const requestedDays = parseInt(req.query?.days, 10);
  const days = Number.isFinite(requestedDays) ? Math.min(Math.max(requestedDays, 1), MAX_DAYS) : 1;

  const startOfDay = new Date(Date.UTC(y, m, d) - offsetMs);
  const endOfDay = new Date(Date.UTC(y, m, d + days) - offsetMs);

  const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(CALENDAR_ID)}/events` +
    `?key=${apiKey}&timeMin=${startOfDay.toISOString()}&timeMax=${endOfDay.toISOString()}` +
    `&singleEvents=true&orderBy=startTime&maxResults=${days > 1 ? 40 : 8}`;

  try {
    const googleRes = await fetch(url);
    if (!googleRes.ok) {
      res.status(502).json({ error: "Calendar API error" });
      return;
    }
    const data = await googleRes.json();
    // Only forward the fields the UI needs - not the full event (which can
    // include descriptions, attendee emails, meeting links, etc).
    const events = (data.items || []).map((ev) => ({
      summary: ev.summary || null,
      start: ev.start,
    }));
    res.status(200).json({ events });
  } catch (err) {
    res.status(502).json({ error: "Calendar fetch failed" });
  }
}
