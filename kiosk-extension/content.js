// Universal kiosk navigation overlay. Injected by the browser itself into
// every page the kiosk shows (see manifest.json's "matches": ["<all_urls>"])
// - no per-app code needed, works on any current or future Home Hub app,
// or even a page we never built. Holding the bottom-right corner for 3s
// shows a small menu: "Back" (history.back(), works on any page) and
// "Exit Kiosk" (closes the kiosk browser via the homehubadmin:// protocol -
// see home-hub-dashboard's HANDOFF.md and register-exit-handler.ps1 /
// exit-kiosk.ps1 for the machine-level setup this depends on).

(function () {
  const HOLD_MS = 3000;
  const ZONE_SIZE = 70; // px, bottom-right square

  const style = document.createElement("style");
  style.textContent = `
    #homehub-nav-marker {
      position: fixed;
      right: 8px;
      bottom: 8px;
      width: 14px;
      height: 14px;
      border-radius: 50%;
      background: rgba(128, 128, 128, 0.35);
      z-index: 2147483647;
      pointer-events: none;
      transition: transform 0.15s ease;
    }
    #homehub-nav-marker.holding {
      transform: scale(1.6);
      background: rgba(128, 128, 128, 0.6);
    }
    #homehub-nav-menu {
      position: fixed;
      right: 8px;
      bottom: 30px;
      z-index: 2147483647;
      display: none;
      flex-direction: column;
      gap: 8px;
      background: rgba(20, 20, 20, 0.92);
      border-radius: 14px;
      padding: 10px;
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.35);
    }
    #homehub-nav-menu.open { display: flex; }
    #homehub-nav-menu button {
      font: inherit;
      font-size: 16px;
      font-family: -apple-system, "Segoe UI", Roboto, system-ui, sans-serif;
      padding: 12px 20px;
      border-radius: 10px;
      border: none;
      background: rgba(255, 255, 255, 0.12);
      color: #fff;
      white-space: nowrap;
    }
    #homehub-nav-menu button:active { background: rgba(255, 255, 255, 0.25); }
  `;

  const marker = document.createElement("div");
  marker.id = "homehub-nav-marker";

  const menu = document.createElement("div");
  menu.id = "homehub-nav-menu";
  menu.innerHTML = `
    <button id="homehub-nav-back">⬅ Back</button>
    <button id="homehub-nav-exit">✕ Exit Kiosk</button>
  `;

  // DIAGNOSTIC MODE (2026-08-23): unmissable full-screen banner + menu
  // forced always-open, to determine whether the content script runs on
  // this page AT ALL. Remove this whole block plus the "menu.classList.add"
  // line below once confirmed working.
  const diagBanner = document.createElement("div");
  diagBanner.textContent = "KIOSK EXTENSION IS RUNNING";
  diagBanner.style.cssText = `
    position: fixed; top: 0; left: 0; right: 0;
    background: red; color: white; font-size: 24px; font-weight: bold;
    text-align: center; padding: 16px; z-index: 2147483647;
  `;

  function mount() {
    document.documentElement.appendChild(style);
    document.body.appendChild(diagBanner); // DIAGNOSTIC
    document.body.appendChild(marker);
    document.body.appendChild(menu);
    menu.classList.add("open"); // DIAGNOSTIC: force always-visible

    menu.querySelector("#homehub-nav-back").addEventListener("click", () => {
      closeMenu();
      history.back();
    });
    menu.querySelector("#homehub-nav-exit").addEventListener("click", () => {
      closeMenu();
      window.location.href = "homehubadmin://exit";
    });
  }

  if (document.body) {
    mount();
  } else {
    document.addEventListener("DOMContentLoaded", mount);
  }

  function openMenu() {
    menu.classList.add("open");
  }
  function closeMenu() {
    menu.classList.remove("open");
  }

  function inZone(x, y) {
    return x > window.innerWidth - ZONE_SIZE && y > window.innerHeight - ZONE_SIZE;
  }

  let holdTimer = null;

  function startHold(e) {
    if (menu.classList.contains("open")) {
      return; // DIAGNOSTIC: don't auto-close while forced open, see mount()
    }
    if (!inZone(e.clientX, e.clientY)) return;
    marker.classList.add("holding");
    holdTimer = setTimeout(() => {
      marker.classList.remove("holding");
      openMenu();
    }, HOLD_MS);
  }

  function cancelHold() {
    clearTimeout(holdTimer);
    holdTimer = null;
    marker.classList.remove("holding");
  }

  document.addEventListener("pointerdown", startHold, true);
  document.addEventListener("pointerup", cancelHold, true);
  document.addEventListener("pointercancel", cancelHold, true);
  document.addEventListener("pointermove", (e) => {
    if (holdTimer && !inZone(e.clientX, e.clientY)) cancelHold();
  }, true);
})();
