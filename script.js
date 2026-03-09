const liveLineEl = document.getElementById("live-line");
const yearEl = document.getElementById("year");
const clockEl = document.getElementById("clock");

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
  }
];

let frameIndex = 0;
let eventIndex = 0;
let spinTimer;
let eventTimer;

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

function init() {
  yearEl.textContent = String(new Date().getFullYear());
  updateClock();
  window.setInterval(updateClock, 1000);
  startLiveFeed();
  setupReveal();
}

document.addEventListener("DOMContentLoaded", init);

window.addEventListener("beforeunload", () => {
  if (spinTimer) {
    window.clearInterval(spinTimer);
  }
  if (eventTimer) {
    window.clearInterval(eventTimer);
  }
});
