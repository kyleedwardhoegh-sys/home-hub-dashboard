// ---- Household tools on Kyle's and Logan's boards (2026-10-19) ----
// Kyle asked for Logan's page to help with daily life. Three tools, shared between the
// kitchen screen and phones through the Training Hub's Supabase database
// (HomeHub-Web/supabase/household.sql) via HubData.rows / HubData.save:
//   - Countdowns: next trips / breaks, also shown on the home screen.
//   - Who's driving: today's and tomorrow's kid events with a one-tap Kyle / Logan.
//   - Shared lists: groceries and to-dos.
// Loaded BEFORE app.js; uses app.js helpers (escapeHtml, localDate, whoTags, ...) at runtime.

const HH = { recent: {}, drives: {}, items: [], countdowns: [], tomorrow: [], list: "groceries", cdForm: false, cdEmoji: "✈️", ok: true, loaded: false };
const CD_EMOJI = ["✈️", "🏖️", "☀️", "🎄", "🎒", "🎉", "🏀", "❤️"];
const LISTS = { groceries: "🛒 Groceries", todo: "✅ To-do" };
const hhDb = () => !!(window.HubData && HubData.rows && HubData.save);
const pad2 = (n) => String(n).padStart(2, "0");
const ymdOf = (d) => `${d.getFullYear()}-${pad2(d.getMonth() + 1)}-${pad2(d.getDate())}`;
const tomorrowYmd = () => { const d = new Date(); d.setDate(d.getDate() + 1); return ymdOf(d); };
const newId = () => (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random().toString(16).slice(2));
const driveId = (day, ev) => `${day}|${ev.summary}|${ev.timeText}`;
const isKidEvent = (ev) => !!(ev.who && (ev.who.includes("Nellie") || ev.who.includes("Nash")));
function daysUntil(ymd) {
  const [y, m, d] = String(ymd).split("-").map(Number);
  const now = new Date(); now.setHours(0, 0, 0, 0);
  return Math.round((new Date(y, m - 1, d) - now) / 864e5);
}

async function loadHousehold() {
  if (!hhDb()) { HH.ok = false; return; }
  const today = localDate(), tom = tomorrowYmd();
  const [drives, items, cds, tomEv] = await Promise.all([
    HubData.rows("drives", `select=id,driver&day=in.(${today},${tom})`),
    HubData.rows("household_items", "select=*&removed=eq.false&order=created_at.asc"),
    HubData.rows("countdowns", "select=*&removed=eq.false&order=day.asc"),
    HubData.getEvents ? HubData.getEvents(tom).catch(() => null) : null,
  ]);
  HH.ok = !!(drives && items && cds);
  HH.loaded = true;
  // A refresh can land before a just-made change has finished saving; keep changes made
  // on this screen in the last 20 s on top of what the database returned.
  const fresh = (table) => Object.values(HH.recent).filter((r) => r.table === table && Date.now() - r.at < 20000).map((r) => r.row);
  const merge = (rows, table) => {
    const by = new Map(rows.map((r) => [r.id, r]));
    fresh(table).forEach((r) => by.set(r.id, r));
    return [...by.values()].filter((r) => !r.removed);
  };
  if (drives) {
    HH.drives = {};
    merge(drives, "drives").forEach((r) => { if (r.driver) HH.drives[r.id] = r.driver; });
  }
  if (items) HH.items = merge(items, "household_items").sort((a, b) => String(a.created_at || "~").localeCompare(String(b.created_at || "~")));
  if (cds) HH.countdowns = merge(cds, "countdowns").filter((c) => daysUntil(c.day) >= 0).sort((a, b) => (a.day < b.day ? -1 : 1));
  if (tomEv) HH.tomorrow = tomEv.map((e) => ({ summary: e.title, timeText: e.time || "All day", location: e.location || "", who: e.who || null }));
  renderNextCountdown();
}

// Small "🚗 Logan" tag for kid events someone is driving to (home screen + boards).
function driveTag(ev, day) {
  const d = HH.drives[driveId(day, ev)];
  return d ? `<span class="drive drive-${d.toLowerCase()}">🚗 ${escapeHtml(d)}</span>` : "";
}

function cdText(c) {
  const n = daysUntil(c.day);
  return n === 0 ? "Today!" : n === 1 ? "Tomorrow!" : `${n} days`;
}
function renderNextCountdown() {
  const el = document.getElementById("next-countdown");
  if (!el) return;
  const c = HH.countdowns[0];
  el.hidden = !c;
  if (c) el.innerHTML = `${escapeHtml(c.emoji || "⏳")} <b>${escapeHtml(cdText(c))}</b> until ${escapeHtml(c.title)}`;
}

// ---------- the board ----------
let hhPerson = null;
function renderParentBoard(id, person, el) {
  hhPerson = person;
  el.innerHTML = `<div class="hh-board">
    <section id="hh-cd"></section>
    <section id="hh-day"></section>
    <section id="hh-drive"></section>
    <section id="hh-lists"></section>
  </div>`;
  renderAll();
  loadHousehold().then(() => { if (currentPersonView === id) renderAll(true); }).catch(() => {});
}
// While someone is typing, leave that section alone so their text isn't wiped.
const typing = (sel) => { const s = document.querySelector(sel); return !!(s && (s.contains(document.activeElement) && document.activeElement.tagName === "INPUT")); };
function renderAll(soft) {
  if (!document.getElementById("hh-day")) return;
  renderDay();
  renderDrives();
  if (!soft || !typing("#hh-cd")) renderCountdowns();
  if (!soft || !typing("#hh-lists")) renderLists();
}

function evRow(ev, day) {
  const name = escapeHtml(ev.summary || "(untitled)");
  const where = ev.location ? `<small class="where">${escapeHtml(ev.location)}</small>` : "";
  return `<div class="person-event"><span class="ev-tags">${whoTags(ev) || "📅"}</span><span class="ev-text">${name}${where}</span>${driveTag(ev, day)}<span class="time">${escapeHtml(ev.timeText)}</span></div>`;
}
function renderDay() {
  const person = hhPerson, today = localDate();
  const tagged = lastCalendarEvents.some((ev) => ev.who);
  const mine = tagged ? lastCalendarEvents.filter((ev) => ev.who && ev.who.includes(person.name)) : lastCalendarEvents;
  const rest = tagged ? lastCalendarEvents.filter((ev) => !mine.includes(ev)) : [];
  document.getElementById("hh-day").innerHTML =
    `<h3 class="ev-head">${tagged ? `${escapeHtml(person.name)}'s day` : "Today"}</h3>` +
    (mine.length ? mine.map((ev) => evRow(ev, today)).join("") : `<div class="person-empty small">Nothing just for you today.</div>`) +
    (rest.length ? `<h3 class="ev-head">Also today</h3>${rest.map((ev) => evRow(ev, today)).join("")}` : "");
}

function renderDrives() {
  const today = localDate(), tom = tomorrowYmd();
  const rows = [
    ...lastCalendarEvents.filter(isKidEvent).map((ev) => ({ ev, day: today, label: "Today" })),
    ...HH.tomorrow.filter(isKidEvent).map((ev) => ({ ev, day: tom, label: "Tomorrow" })),
  ];
  const el = document.getElementById("hh-drive");
  if (!rows.length) { el.innerHTML = ""; return; }
  el.innerHTML = `<h3 class="ev-head">Who's driving?</h3>` + rows.map(({ ev, day, label }) => {
    const id = driveId(day, ev), cur = HH.drives[id] || "";
    const btn = (p) => `<button class="drive-btn ${cur === p ? `on drive-${p.toLowerCase()}` : ""}" type="button" data-drive="${escapeHtml(id)}" data-day="${day}" data-title="${escapeHtml(ev.summary)}" data-who="${p}">${cur === p ? "🚗 " : ""}${p}</button>`;
    return `<div class="drive-row">
      <div class="drive-ev"><span class="ev-tags">${whoTags(ev)}</span><span class="ev-text">${escapeHtml(ev.summary)}<small class="where">${label} · ${escapeHtml(ev.timeText)}${ev.location ? ` · ${escapeHtml(ev.location)}` : ""}</small></span></div>
      <div class="drive-btns">${btn("Kyle")}${btn("Logan")}</div>
    </div>`;
  }).join("");
}

function renderCountdowns() {
  const el = document.getElementById("hh-cd");
  const cards = HH.countdowns.map((c) => `
    <div class="cd-card">
      <button class="cd-x" type="button" data-cd-remove="${escapeHtml(c.id)}" aria-label="Remove ${escapeHtml(c.title)}">✕</button>
      <div class="cd-emoji">${escapeHtml(c.emoji || "⏳")}</div>
      <div class="cd-num">${escapeHtml(cdText(c))}</div>
      <div class="cd-title">${escapeHtml(c.title)}</div>
    </div>`).join("");
  const form = HH.cdForm ? `
    <div class="cd-form">
      <input id="cd-title" type="text" placeholder="What are we counting down to?" maxlength="40" />
      <input id="cd-date" type="date" min="${localDate()}" />
      <div class="cd-emojis">${CD_EMOJI.map((e) => `<button type="button" class="cd-e ${e === HH.cdEmoji ? "on" : ""}" data-cd-emoji="${e}">${e}</button>`).join("")}</div>
      <div class="hh-actions"><button type="button" class="hh-ghost" data-cd-cancel>Cancel</button><button type="button" class="hh-primary" data-cd-save>Save</button></div>
    </div>` : `<button class="cd-card cd-add" type="button" data-cd-new>＋<span>Countdown</span></button>`;
  el.innerHTML = `<h3 class="ev-head">Countdowns</h3><div class="cd-row">${cards}${HH.cdForm ? "" : form}</div>${HH.cdForm ? form : ""}`;
}

function renderLists() {
  const el = document.getElementById("hh-lists");
  const items = HH.items.filter((i) => i.list === HH.list);
  const count = (l) => HH.items.filter((i) => i.list === l && !i.done).length;
  const doneN = items.filter((i) => i.done).length;
  el.innerHTML = `<h3 class="ev-head">Lists</h3>
    <div class="hh-seg">${Object.entries(LISTS).map(([k, label]) => `<button type="button" data-list="${k}" class="${HH.list === k ? "on" : ""}">${label}${count(k) ? ` <b>${count(k)}</b>` : ""}</button>`).join("")}</div>
    <form class="hh-add" data-add-form><input id="hh-new" type="text" placeholder="${HH.list === "groceries" ? "Add milk, eggs…" : "Add a to-do…"}" maxlength="80" autocomplete="off" /><button type="submit" class="hh-primary">Add</button></form>
    <div class="hh-items">${items.length ? items.map((i) => `
      <button type="button" class="hh-item ${i.done ? "done" : ""}" data-item="${escapeHtml(i.id)}">
        <span class="hh-check">${i.done ? "✓" : ""}</span><span class="hh-text">${escapeHtml(i.text)}</span>${i.added_by ? `<small>${escapeHtml(i.added_by)}</small>` : ""}
      </button>`).join("") : `<div class="person-empty small">Nothing on this list.</div>`}</div>
    ${doneN ? `<button type="button" class="hh-ghost hh-clear" data-clear>Clear ${doneN} checked</button>` : ""}
    ${HH.ok ? "" : `<div class="hh-warn">Couldn't reach the shared lists. Check the Wi-Fi.</div>`}`;
}

async function hhSave(table, rows) {
  rows.forEach((r) => { HH.recent[`${table}|${r.id}`] = { table, row: r, at: Date.now() }; });
  const ok = hhDb() && await HubData.save(table, rows);
  if (!ok) { HH.ok = false; renderLists(); }
  return ok;
}

// ---------- taps ----------
document.addEventListener("click", async (e) => {
  if (!document.querySelector(".hh-board")) return;
  const t = e.target;
  const drv = t.closest("[data-drive]");
  if (drv) {
    const id = drv.dataset.drive, who = drv.dataset.who, next = HH.drives[id] === who ? null : who;
    if (next) HH.drives[id] = next; else delete HH.drives[id];
    renderDrives(); renderDay();
    hhSave("drives", [{ id, day: drv.dataset.day, title: drv.dataset.title, driver: next }]);
    if (typeof updateCalendar === "function") setTimeout(updateCalendar, 300);
    return;
  }
  const lst = t.closest("[data-list]");
  if (lst) { HH.list = lst.dataset.list; renderLists(); return; }
  const it = t.closest("[data-item]");
  if (it) {
    const item = HH.items.find((x) => x.id === it.dataset.item);
    if (!item) return;
    item.done = !item.done;
    renderLists();
    hhSave("household_items", [item]);
    return;
  }
  if (t.closest("[data-clear]")) {
    const gone = HH.items.filter((i) => i.list === HH.list && i.done).map((i) => ({ ...i, removed: true }));
    HH.items = HH.items.filter((i) => !(i.list === HH.list && i.done));
    renderLists();
    hhSave("household_items", gone);
    return;
  }
  if (t.closest("[data-cd-new]")) { HH.cdForm = true; renderCountdowns(); document.getElementById("cd-title").focus(); return; }
  if (t.closest("[data-cd-cancel]")) { HH.cdForm = false; renderCountdowns(); return; }
  const em = t.closest("[data-cd-emoji]");
  if (em) { HH.cdEmoji = em.dataset.cdEmoji; document.querySelectorAll(".cd-e").forEach((b) => b.classList.toggle("on", b === em)); return; }
  if (t.closest("[data-cd-save]")) {
    const title = document.getElementById("cd-title").value.trim(), day = document.getElementById("cd-date").value;
    if (!title || !day) { (title ? document.getElementById("cd-date") : document.getElementById("cd-title")).focus(); return; }
    const c = { id: newId(), title, day, emoji: HH.cdEmoji, removed: false, added_by: hhPerson ? hhPerson.name : null };
    HH.countdowns = [...HH.countdowns, c].sort((a, b) => (a.day < b.day ? -1 : 1));
    HH.cdForm = false;
    renderCountdowns(); renderNextCountdown();
    hhSave("countdowns", [c]);
    return;
  }
  const rm = t.closest("[data-cd-remove]");
  if (rm) {
    const c = HH.countdowns.find((x) => x.id === rm.dataset.cdRemove);
    if (!c) return;
    HH.countdowns = HH.countdowns.filter((x) => x !== c);
    renderCountdowns(); renderNextCountdown();
    hhSave("countdowns", [{ ...c, removed: true }]);
  }
});
document.addEventListener("submit", (e) => {
  if (!e.target.matches("[data-add-form]")) return;
  e.preventDefault();
  const input = document.getElementById("hh-new"), text = input.value.trim();
  if (!text) return;
  const item = { id: newId(), list: HH.list, text, done: false, removed: false, added_by: hhPerson ? hhPerson.name : null, created_at: new Date().toISOString() };
  HH.items.push(item);
  input.value = "";
  renderLists();
  document.getElementById("hh-new").focus();
  hhSave("household_items", [item]);
});
// Typing counts as activity (the board otherwise returns to the clock when idle).
document.addEventListener("keydown", () => { if (typeof currentPersonView !== "undefined" && currentPersonView && typeof resetIdleTimer === "function") resetIdleTimer(); });
// Keep an open board fresh (another phone may have changed a list).
setInterval(() => {
  if (!document.querySelector(".hh-board")) return;
  const id = currentPersonView;
  loadHousehold().then(() => { if (currentPersonView === id) renderAll(true); }).catch(() => {});
}, 60000);
