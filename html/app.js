const root = document.getElementById("root");
const textEl = document.getElementById("text");
const hintEl = document.getElementById("hint");
const npcNameEl = document.getElementById("npcName");
const npcSubtitleEl = document.getElementById("npcSubtitle");
const menuEl = document.getElementById("menu");

let locale = null;
let loadedLang = null;

let typing = {
  active: false,
  fullText: "",
  index: 0,
  timer: null
};

// -----------------------------
// Locale
// -----------------------------
async function loadLocale(lang = "en") {
  if (loadedLang === lang && locale) return;
  loadedLang = lang;
  try {
    const res = await fetch(`../locales/${lang}.json`);
    locale = await res.json();
  } catch (e) {
    console.error("Failed to load locale:", e);
    locale = { ui: { hintEsc: "ESC to close", defaultText: "What do you need?" } };
  }
}

function t(path, fallback = "") {
  const parts = path.split(".");
  let cur = locale;
  for (const p of parts) {
    if (!cur || typeof cur !== "object" || !(p in cur)) return fallback;
    cur = cur[p];
  }
  return typeof cur === "string" ? cur : fallback;
}

// -----------------------------
// UI visibility
// -----------------------------
function showUI() {
  root.classList.remove("hidden");
}

function hideUI() {
  root.classList.add("hidden");
}

// -----------------------------
// Typewriter
// -----------------------------
function stopTyping(showFull = true) {
  if (typing.timer) {
    clearInterval(typing.timer);
    typing.timer = null;
  }
  if (showFull) textEl.textContent = typing.fullText;
  typing.active = false;
}

function typeText(text, speed = 18) {
  stopTyping(false);

  typing.active = true;
  typing.fullText = text || "";
  typing.index = 0;

  textEl.textContent = "";

  typing.timer = setInterval(() => {
    if (!typing.active) return;

    typing.index++;
    textEl.textContent = typing.fullText.slice(0, typing.index);

    if (typing.index >= typing.fullText.length) {
      stopTyping(true);
    }
  }, speed);
}

// -----------------------------
// NUI post
// -----------------------------
function post(name, data = {}) {
  fetch(`https://${GetParentResourceName()}/${name}`, {
    method: "POST",
    headers: { "Content-Type": "application/json; charset=UTF-8" },
    body: JSON.stringify(data)
  });
}

// Smart: first click finishes typing, second click performs action
function guardTypingThen(fn) {
  return () => {
    if (typing.active) {
      stopTyping(true);
      return;
    }
    fn();
  };
}

// -----------------------------
// Buttons
// -----------------------------
function clearButtons() {
  menuEl.innerHTML = "";
}

function renderButtons(buttons = []) {
  clearButtons();

  buttons.forEach((b, idx) => {
    const btn = document.createElement("button");
    btn.className = "menuItem" + (b?.variant === "danger" ? " danger" : "");
    btn.textContent = b?.label || b?.id || "button";

    btn.addEventListener(
      "click",
      guardTypingThen(() => {
        post("press", { index: idx + 1 }); // 1-based index for Lua
      })
    );

    menuEl.appendChild(btn);
  });
}

// -----------------------------
// NUI messages
// -----------------------------
window.addEventListener("message", async (e) => {
  const msg = e.data;
  if (!msg || !msg.action) return;

  if (msg.action === "open" || msg.action === "render") {
    await loadLocale(msg.locale || "en");

    hintEl.textContent = t("ui.hintEsc", "ESC to close");

    npcNameEl.textContent = msg.npcName || "";
    npcSubtitleEl.textContent = msg.npcSubtitle || "";
    npcSubtitleEl.style.display = npcSubtitleEl.textContent ? "block" : "none";

    renderButtons(msg.buttons || []);
    typeText(msg.text ?? t("ui.defaultText", "What do you need?"));

    showUI();
  }

  if (msg.action === "close") {
    hideUI();
    stopTyping(false);
    clearButtons();
  }
});

// -----------------------------
// UX helpers
// -----------------------------

// Click outside menu = finish typing only
document.addEventListener("click", (e) => {
  if (e.target.closest(".menu") || e.target.closest(".menuItem")) return;
  if (typing.active) stopTyping(true);
});

// ESC closes
document.addEventListener("keydown", (e) => {
  if (e.key === "Escape") post("close");
});
