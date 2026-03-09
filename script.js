const liveLineEl = document.getElementById("live-line");
const yearEl = document.getElementById("year");
const clockEl = document.getElementById("clock");
const specterLevelEl = document.querySelector(".status-ghost");

const frames = ["|", "/", "-", "\\"];
const runEvents = [
  {
    type: "THINKING",
    tagClass: "thinking",
    text: "Map request intent and detect nearest reusable UI blocks."
  },
  {
    type: "TOOL_CALL",
    tagClass: "call",
    text: 'exec_command { cmd: "rg --files && sed -n 1,220p index.html" }'
  },
  {
    type: "TOOL_RESULT",
    tagClass: "result",
    text: "exec_command exit_code=0; files=3; identified console mismatch."
  },
  {
    type: "EDIT",
    tagClass: "edit",
    text: "apply_patch -> rewired terminal logs to thinking/tool_result format."
  },
  {
    type: "VERIFICATION",
    tagClass: "verify",
    text: "node --check script.js pass; motion and responsive checks pass."
  },
  {
    type: "SPECTER",
    tagClass: "specter",
    text: "boo_signal=stable; haunted accents active; execution flow unchanged."
  }
];

let frameIndex = 0;
let eventIndex = 0;
let spinTimer;
let eventTimer;
let glitchTimer;
let glitchClearTimer;
let scrollHauntTimer;
let scrollHandler;
let hauntPool = [];
let activeHauntNodes = [];
let lastHauntShuffleMs = 0;

function updateClock() {
  const now = new Date();
  clockEl.textContent = now.toLocaleTimeString("en-US", { hour12: false });
}

function renderLiveLine() {
  const frame = frames[frameIndex];
  const event = runEvents[eventIndex];
  liveLineEl.innerHTML = `<span class="spinner">${frame}</span> <span class="tag ${event.tagClass}">${event.type}</span> <span class="log-text">${event.text}</span>`;
}

function startLiveFeed() {
  renderLiveLine();

  spinTimer = window.setInterval(() => {
    frameIndex = (frameIndex + 1) % frames.length;
    renderLiveLine();
  }, 130);

  eventTimer = window.setInterval(() => {
    eventIndex = (eventIndex + 1) % runEvents.length;
    renderLiveLine();
  }, 2100);
}

function startGhostGlitch() {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduceMotion) return;

  const runGlitch = () => {
    document.body.classList.add("ghost-glitch");
    if (specterLevelEl) {
      specterLevelEl.textContent = "SPECTER: TRACE++";
    }

    const burstMs = 420 + Math.floor(Math.random() * 280);
    glitchClearTimer = window.setTimeout(() => {
      document.body.classList.remove("ghost-glitch");
      if (specterLevelEl) {
        specterLevelEl.textContent = "SPECTER: LOW";
      }
    }, burstMs);

    const nextInMs = 7000 + Math.floor(Math.random() * 7000);
    glitchTimer = window.setTimeout(runGlitch, nextInMs);
  };

  const firstInMs = 1800 + Math.floor(Math.random() * 1200);
  glitchTimer = window.setTimeout(runGlitch, firstInMs);
}

function setupScrollHaunt() {
  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  if (reduceMotion) return;

  let lastScrollY = window.scrollY || 0;
  const releaseDelayMs = 170;
  hauntPool = Array.from(
    document.querySelectorAll(
      ".card, .stack-list > div, .log, .section-head h2, .kicker, .command, .flicker-core"
    )
  );

  const clearActiveHauntNodes = () => {
    activeHauntNodes.forEach((node) => node.classList.remove("haunt-active"));
    activeHauntNodes = [];
  };

  const activateRandomHauntNodes = (intensity) => {
    const now = performance.now();
    if (now - lastHauntShuffleMs < 95) return;
    lastHauntShuffleMs = now;

    clearActiveHauntNodes();
    if (!hauntPool.length) return;

    const targetCount = Math.max(2, Math.min(9, Math.round(3 + intensity * 6)));
    const used = new Set();

    while (used.size < targetCount && used.size < hauntPool.length) {
      used.add(Math.floor(Math.random() * hauntPool.length));
    }

    used.forEach((index) => {
      const node = hauntPool[index];
      node.classList.add("haunt-active");
      activeHauntNodes.push(node);
    });
  };

  const clearHaunt = () => {
    document.body.classList.remove("scroll-haunt");
    document.body.style.setProperty("--scroll-fail-shift", "0px");
    document.body.style.setProperty("--scroll-fail-cut", "0%");
    clearActiveHauntNodes();
    if (specterLevelEl && !document.body.classList.contains("ghost-glitch")) {
      specterLevelEl.textContent = "SPECTER: LOW";
    }
  };

  scrollHandler = () => {
    const currentY = window.scrollY || 0;
    const delta = Math.abs(currentY - lastScrollY);
    lastScrollY = currentY;

    const intensity = Math.min(1, delta / 52);
    const failShift = (Math.random() * 2 - 1) * (1.8 + intensity * 5.2);
    const failCut = 0.6 + intensity * 3.2;

    document.body.style.setProperty("--scroll-haunt-intensity", intensity.toFixed(2));
    document.body.style.setProperty("--scroll-fail-shift", `${failShift.toFixed(2)}px`);
    document.body.style.setProperty("--scroll-fail-cut", `${failCut.toFixed(2)}%`);
    document.body.classList.add("scroll-haunt");
    activateRandomHauntNodes(intensity);

    if (specterLevelEl && !document.body.classList.contains("ghost-glitch")) {
      specterLevelEl.textContent = "SPECTER: TRACE";
    }

    if (scrollHauntTimer) {
      window.clearTimeout(scrollHauntTimer);
    }
    scrollHauntTimer = window.setTimeout(clearHaunt, releaseDelayMs);
  };

  window.addEventListener("scroll", scrollHandler, { passive: true });
}

function setupReveal() {
  const nodes = document.querySelectorAll("[data-reveal]");
  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add("in");
        }
      });
    },
    { threshold: 0.15 }
  );

  nodes.forEach((node) => observer.observe(node));
}

function setupCopyButtons() {
  const buttons = document.querySelectorAll("[data-copy-target]");

  const fallbackCopy = (text) => {
    const textarea = document.createElement("textarea");
    textarea.value = text;
    textarea.setAttribute("readonly", "true");
    textarea.style.position = "fixed";
    textarea.style.opacity = "0";
    document.body.appendChild(textarea);
    textarea.select();
    const copied = document.execCommand("copy");
    document.body.removeChild(textarea);
    return copied;
  };

  buttons.forEach((button) => {
    button.addEventListener("click", async () => {
      const targetId = button.getAttribute("data-copy-target");
      const target = document.getElementById(targetId);
      if (!target) return;

      const commandText = target.textContent.trim();
      let copied = false;

      try {
        await navigator.clipboard.writeText(commandText);
        copied = true;
      } catch (_err) {
        copied = fallbackCopy(commandText);
      }

      if (!copied) return;

      const original = button.textContent;
      button.textContent = "✓";
      button.classList.add("copied");

      window.setTimeout(() => {
        button.textContent = original;
        button.classList.remove("copied");
      }, 1100);
    });
  });
}

function init() {
  yearEl.textContent = String(new Date().getFullYear());
  updateClock();
  window.setInterval(updateClock, 1000);
  startLiveFeed();
  startGhostGlitch();
  setupScrollHaunt();
  setupReveal();
  setupCopyButtons();
}

document.addEventListener("DOMContentLoaded", init);

window.addEventListener("beforeunload", () => {
  if (spinTimer) {
    window.clearInterval(spinTimer);
  }
  if (eventTimer) {
    window.clearInterval(eventTimer);
  }
  if (glitchTimer) {
    window.clearTimeout(glitchTimer);
  }
  if (glitchClearTimer) {
    window.clearTimeout(glitchClearTimer);
  }
  if (scrollHauntTimer) {
    window.clearTimeout(scrollHauntTimer);
  }
  if (scrollHandler) {
    window.removeEventListener("scroll", scrollHandler);
  }
});
