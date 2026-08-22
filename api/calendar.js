// Serverless proxy for Google Calendar so the API key never ships to the
// browser. "Today" is always computed here (Kyle's timezone), not from
// caller-supplied params, so this endpoint can only ever return today's
// events regardless of who calls it.
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

  const todayInTz = new Date(new Date().toLocaleString("en-US", { timeZone: TIMEZONE }));
  const startOfDay = new Date(todayInTz.getFullYear(), todayInTz.getMonth(), todayInTz.getDate());
  const endOfDay = new Date(todayInTz.getFullYear(), todayInTz.getMonth(), todayInTz.getDate() + 1);

  const url = `https://www.googleapis.com/calendar/v3/calendars/${encodeURIComponent(CALENDAR_ID)}/events` +
    `?key=${apiKey}&timeMin=${startOfDay.toISOString()}&timeMax=${endOfDay.toISOString()}` +
    `&singleEvents=true&orderBy=startTime&maxResults=8`;

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
