// The model, shown in Claude beside the call that built it: MCP Apps.
//
// Since 2026-01-26 a server can show its own page inline in a Claude
// conversation, on the web, the desktop and the phone (the MCP Apps
// extension, io.modelcontextprotocol/ui; spec 2026-01-26,
// github.com/modelcontextprotocol/ext-apps, specification/2026-01-26/apps.mdx).
// The page is a ui:// resource of mimeType text/html;profile=mcp-app, read
// with resources/read, and a tool names it in its _meta (ui.resourceUri,
// and the older flat "ui/resourceUri" that hosts still read). The host
// draws it in a sandboxed frame and hands it the call's whole result over
// postMessage (ui/notifications/tool-result).
//
// This is that page: a small viewer of the session's model, from the
// pictures the tab already draws. No WebGL and no engine: a turntable of
// four corners, or the picture the answer carries, and the parts count.
//
// What it is given rides in the answer's _meta ("brickworks/view", from
// src/net/model_views.gd), which no client hands the model, and only on a
// session whose client said it shows such pages. Not in structuredContent:
// Claude Code gives the model a result's structuredContent in place of its
// text (claude.com/docs/connectors/building/mcp-apps/quickstart), so a design
// session there would lose every answer's words. Every other client sees
// exactly what it saw before; the tab draws nothing more for it.
//
// Pictures are inline data: the spec's default policy for the frame is
// img-src 'self' data:, and nothing is fetched, so the page declares no
// domains at all.

export const EXTENSION = "io.modelcontextprotocol/ui";
export const VIEWER_URI = "ui://brickworks/model.html";
export const VIEWER_MIME = "text/html;profile=mcp-app";
// The tools whose answer is the model as it now stands (ModelViews.TOOLS).
export const VIEWER_TOOLS = ["submit_design", "look_at_model", "view_model", "edit_model"];
// What a call carries to the tab to ask for the viewer's share of its answer.
export const ASK_VIEWS = "brickworks/views";

// The tool as tools/list gives it, naming the viewer when it is one of its.
export function withViewer(tool) {
  if (!tool || !VIEWER_TOOLS.includes(tool.name)) return tool;
  const meta = tool._meta && typeof tool._meta === "object" ? tool._meta : {};
  const ui = meta.ui && typeof meta.ui === "object" ? meta.ui : {};
  return { ...tool, _meta: { ...meta, ui: { ...ui, resourceUri: VIEWER_URI }, "ui/resourceUri": VIEWER_URI } };
}

// Whether a client shows such pages: said in its capabilities at
// initialize, or, from protocol 2026-07-28, in every request's _meta.
export function showsApps(message) {
  const params = message && typeof message.params === "object" && message.params ? message.params : {};
  const said = message && message.method === "initialize" ? params.capabilities
    : params._meta && params._meta["io.modelcontextprotocol/clientCapabilities"];
  const ui = said && said.extensions && said.extensions[EXTENSION];
  return Boolean(ui && (!Array.isArray(ui.mimeTypes) || ui.mimeTypes.includes(VIEWER_MIME)));
}

// The session id handed out at initialize says which kind of client it was
// given to, so the relay, which keeps no connection, knows on every call
// after: 32 characters for one that does not show pages, "app" and 32 for
// one that does.
export function sessionFor(shows, random) {
  return shows ? `app${random}` : random;
}
export function sessionShows(session) {
  return typeof session === "string" && session.length === 35 && session.startsWith("app");
}

const RESOURCE_META = {
  ui: {
    // Nothing is fetched: the pictures come inline, in the result.
    csp: { connectDomains: [], resourceDomains: [] },
    // The page draws its own card.
    prefersBorder: false,
  },
};

export function viewerListed() {
  return {
    uri: VIEWER_URI,
    name: "model",
    title: "The model",
    description: "The Brickworks model as it now stands: a turntable of views and its parts count.",
    mimeType: VIEWER_MIME,
    _meta: RESOURCE_META,
  };
}

// resources/read's answer, or null for an address that is not the viewer's.
export function viewerRead(uri) {
  if (uri !== VIEWER_URI) return null;
  return { contents: [{ uri: VIEWER_URI, mimeType: VIEWER_MIME, text: VIEWER_HTML, _meta: RESOURCE_META }] };
}

// The page. web/site.css's colours, the system's own fonts, the mark from
// web/icon.svg; nothing loaded from anywhere.
export const VIEWER_HTML = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="dark light">
<title>Brickworks: the model</title>
<style>
:root{--panel:#181c22;--panel-hi:#1f242c;--line:rgba(255,255,255,.1);--ink:#eef0f4;--ink-faint:#8d939d;
--yellow:#f2cd37;--on-accent:#17130a;--focus:#7cb8ff;--ground:#edf0f5;--ground-ink:#424954;color-scheme:dark}
:root[data-theme=light]{--panel:#fff;--panel-hi:#f7f8fa;--line:rgba(15,20,28,.12);--ink:#12161c;
--ink-faint:#5b626d;--focus:#1f5fbf;color-scheme:light}
*,*::before,*::after{box-sizing:border-box}
html,body{margin:0;background:transparent}
body{font:400 14px/1.5 ui-sans-serif,system-ui,-apple-system,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
color:var(--ink);-webkit-font-smoothing:antialiased}
[hidden]{display:none!important}
.card{background:var(--panel);border:1px solid var(--line);border-radius:14px;overflow:hidden}
.head{display:flex;align-items:center;gap:10px;padding:12px 14px}
.mark{width:22px;height:22px;flex:none}
.name{flex:1;min-width:0;font-weight:650;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.parts{flex:none;font-size:12px;font-weight:650;line-height:1;padding:7px 10px;border-radius:999px;
background:var(--yellow);color:var(--on-accent);font-variant-numeric:tabular-nums}
.parts:empty{display:none}
.stage{position:relative;display:grid;place-items:center;width:100%;aspect-ratio:4/3;max-height:420px;
background:var(--ground);overflow:hidden;touch-action:pan-y;outline:none}
.stage.turns{cursor:grab}
.stage.turns:active{cursor:grabbing}
.stage:focus-visible::after{content:"";position:absolute;inset:0;box-shadow:inset 0 0 0 3px var(--focus);
pointer-events:none}
.stage img{position:absolute;inset:0;width:100%;height:100%;object-fit:contain;display:block;
user-select:none;-webkit-user-drag:none}
.say{margin:0;padding:24px;max-width:46ch;text-align:center;color:var(--ground-ink)}
.foot{display:flex;align-items:center;gap:10px;padding:10px 12px;min-height:20px}
.foot:has(.views:empty):has(.where:empty):has(.turn[hidden]){display:none}
.views{display:flex;gap:6px}
.views:empty{display:none}
.views button{width:44px;height:44px;padding:0;border:1px solid var(--line);border-radius:10px;
background:var(--ground);overflow:hidden;cursor:pointer}
.views button img{width:100%;height:100%;object-fit:cover;display:block}
.views button[aria-pressed=true]{border-color:var(--yellow);box-shadow:0 0 0 1px var(--yellow)}
.where{flex:1;min-width:0;font-size:13px;color:var(--ink-faint);white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.turn{flex:none;margin-left:auto;height:36px;padding:0 14px;border:1px solid var(--line);border-radius:999px;
background:var(--panel-hi);color:var(--ink);font:inherit;font-weight:600;cursor:pointer}
@media (max-width:420px){.views:not(:empty)~.where{display:none}}
button:focus-visible{outline:3px solid var(--focus);outline-offset:2px}
.waiting .stage{background:linear-gradient(90deg,var(--panel-hi) 25%,var(--panel) 50%,var(--panel-hi) 75%);
background-size:200% 100%;animation:shimmer 1.4s linear infinite}
.waiting .say{color:var(--ink-faint)}
@keyframes shimmer{to{background-position:-200% 0}}
@media (prefers-reduced-motion:reduce){.waiting .stage{animation:none}}
</style>
</head>
<body>
<main class="card waiting" id="card" aria-busy="true">
<div class="head">
<svg class="mark" viewBox="0 0 64 64" aria-hidden="true">
<path d="M32 4L56.25 18L44.125 25L32 18L19.875 25L7.75 18Z" fill="#f2cd37"/>
<path d="M7.75 18L19.875 25V39L32 46V60L7.75 46Z" fill="#d0332f"/>
<path d="M56.25 18L44.125 25V39L32 46V60L56.25 46Z" fill="#2a6fc4"/>
<path d="M32 46L44.125 39L32 32L19.875 39Z" fill="#c29d22"/>
<path d="M44.125 25L32 18V32L44.125 39Z" fill="#94211e"/>
<path d="M19.875 25L32 18V32L19.875 39Z" fill="#1c4b88"/>
</svg>
<div class="name" id="name">Brickworks</div>
<div class="parts" id="parts"></div>
</div>
<div class="stage" id="stage" tabindex="0" aria-label="The model">
<img id="picture" alt="" hidden draggable="false">
<p class="say" id="say">Waiting for the model…</p>
</div>
<div class="foot">
<div class="views" id="views" role="group" aria-label="Views round the model"></div>
<div class="where" id="where" aria-live="polite"></div>
<button class="turn" id="turn" type="button" hidden>Turn</button>
</div>
</main>
<script>
(() => {
  "use strict";
  const PROTOCOL = "2026-01-26";
  const SIDES = { corner: "Front right", "back right": "Back right", "far corner": "Back left",
    "front left": "Front left", front: "Front", back: "Back", left: "Left", right: "Right", top: "Top" };
  const DOING = { submit_design: "Building it…", edit_model: "Changing it…",
    view_model: "Taking a picture…", look_at_model: "Reading the model…" };
  const $ = (id) => document.getElementById(id);
  const root = document.documentElement;
  const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
  root.dataset.theme = matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";

  // JSON-RPC 2.0 to the host, which is this frame's parent.
  let sent = 0;
  const waiting = new Map();
  const post = (message) => window.parent.postMessage(message, "*");
  const tell = (method, params) => post(params === undefined ? { jsonrpc: "2.0", method } : { jsonrpc: "2.0", method, params });
  const ask = (method, params) => new Promise((done, fail) => {
    sent += 1;
    waiting.set(sent, { done, fail });
    post({ jsonrpc: "2.0", id: sent, method, params });
  });

  let input = {};
  let tool = "";
  let views = [];
  let at = 0;
  let timer = 0;

  function context(given) {
    const c = given && typeof given === "object" ? given : {};
    if (c.theme === "light" || c.theme === "dark") root.dataset.theme = c.theme;
    const name = c.toolInfo && c.toolInfo.tool && c.toolInfo.tool.name;
    if (typeof name === "string") tool = name;
    const s = c.safeAreaInsets;
    if (s && typeof s === "object") {
      document.body.style.padding = [s.top, s.right, s.bottom, s.left].map((n) => (Number(n) || 0) + "px").join(" ");
    }
  }

  function say(words, busy) {
    stop();
    views = [];
    $("card").classList.toggle("waiting", Boolean(busy));
    $("card").setAttribute("aria-busy", busy ? "true" : "false");
    $("picture").hidden = true;
    $("say").hidden = false;
    $("say").textContent = words;
    $("views").replaceChildren();
    $("where").textContent = "";
    $("turn").hidden = true;
    $("stage").classList.remove("turns");
  }

  // A picture is shown only as what it says it is.
  const picture = (one) => one && /^image\\/(png|webp|jpeg)$/.test(String(one.mimeType))
    && typeof one.data === "string" && one.data.length > 0 && /^[A-Za-z0-9+/]+=*$/.test(one.data);
  const source = (one) => "data:" + one.mimeType + ";base64," + one.data;

  // What the answer said, when there is no picture to show: its first
  // words after the line naming the tab.
  function words(result) {
    const said = (Array.isArray(result.content) ? result.content : [])
      .filter((b) => b && b.type === "text" && typeof b.text === "string").map((b) => b.text.trim());
    const first = said.length > 1 && /^Tab /.test(said[0]) ? said[1] : said[0] || "";
    const line = first.split("\\n")[0];
    return line.length > 180 ? line.slice(0, 177) + "…" : line;
  }

  function show(result) {
    const r = result && typeof result === "object" ? result : {};
    const meta = r._meta && typeof r._meta === "object" ? r._meta : {};
    const given = meta["brickworks/view"] && typeof meta["brickworks/view"] === "object" ? meta["brickworks/view"] : {};
    const named = (typeof meta["brickworks/model"] === "string" && meta["brickworks/model"].trim())
      || (typeof input.name === "string" && input.name.trim()) || "Your model";
    $("name").textContent = named;
    const parts = Number.isInteger(given.parts) && given.parts >= 0 ? given.parts : null;
    $("parts").textContent = parts === null ? "" : parts.toLocaleString() + (parts === 1 ? " part" : " parts");
    let found = (Array.isArray(given.views) ? given.views : []).filter(picture)
      .map((v) => ({ side: SIDES[v.from] || "", src: source(v) }));
    // Else the picture the answer carries, as view_model's and edit_model's do.
    if (!found.length) {
      found = (Array.isArray(r.content) ? r.content : []).filter((b) => b && b.type === "image" && picture(b))
        .map((b) => ({ side: SIDES[input.from] || "", src: source(b) }));
    }
    if (!found.length) {
      return say(parts === 0 ? "Nothing is built yet." : (words(r) || "No picture came with this answer."), false);
    }
    say("", false);
    views = found;
    at = 0;
    $("say").hidden = true;
    $("picture").hidden = false;
    if (views.length > 1) {
      $("views").replaceChildren(...views.map((one, n) => {
        const b = document.createElement("button");
        b.type = "button";
        b.setAttribute("aria-label", one.side || "View " + (n + 1));
        const i = document.createElement("img");
        i.src = one.src;
        i.alt = "";
        b.append(i);
        b.addEventListener("click", () => { stop(); go(n); });
        return b;
      }));
      $("turn").hidden = false;
      $("stage").classList.add("turns");
      $("stage").setAttribute("aria-label", "The model. Drag across it, or press the arrow keys, to turn it.");
      if (!still) play(2);
    }
    go(0);
  }

  function go(n) {
    at = ((n % views.length) + views.length) % views.length;
    const one = views[at];
    const img = $("picture");
    img.src = one.src;
    img.alt = $("name").textContent + (one.side ? ", from the " + one.side.toLowerCase() : "");
    $("where").textContent = !one.side ? "" : views.length > 1 ? one.side : "From the " + one.side.toLowerCase();
    [...$("views").children].forEach((b, k) => b.setAttribute("aria-pressed", k === at ? "true" : "false"));
  }

  // Round [laps] times, then still: a page in a conversation does not move for ever.
  function play(laps) {
    stop();
    let left = laps * views.length;
    $("turn").textContent = "Stop";
    timer = setInterval(() => {
      left -= 1;
      go(at + 1);
      if (left <= 0) stop();
    }, 1400);
  }
  function stop() {
    if (timer) clearInterval(timer);
    timer = 0;
    $("turn").textContent = "Turn";
  }
  $("turn").addEventListener("click", () => (timer ? stop() : play(1)));
  $("stage").addEventListener("keydown", (event) => {
    if (views.length < 2) return;
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      event.preventDefault();
      stop();
      go(at + (event.key === "ArrowRight" ? 1 : -1));
    }
  });
  // Dragged across, a quarter turn every 48 px.
  let from = null;
  $("stage").addEventListener("pointerdown", (event) => {
    if (views.length < 2) return;
    from = event.clientX;
    $("stage").setPointerCapture(event.pointerId);
    stop();
  });
  $("stage").addEventListener("pointermove", (event) => {
    if (from === null) return;
    const steps = Math.trunc((event.clientX - from) / 48);
    if (steps) {
      from += steps * 48;
      go(at - steps);
    }
  });
  const letGo = () => { from = null; };
  $("stage").addEventListener("pointerup", letGo);
  $("stage").addEventListener("pointercancel", letGo);

  // The host sizes the frame to the page.
  let size = "";
  function measure() {
    const height = Math.ceil(document.body.getBoundingClientRect().height);
    const width = Math.ceil(window.innerWidth);
    if (height > 0 && size !== width + "x" + height) {
      size = width + "x" + height;
      tell("ui/notifications/size-changed", { width, height });
    }
  }
  new ResizeObserver(measure).observe(document.body);

  window.addEventListener("message", (event) => {
    if (event.source !== window.parent) return;
    const m = event.data;
    if (!m || typeof m !== "object" || m.jsonrpc !== "2.0") return;
    if (m.method === undefined) {
      const w = waiting.get(m.id);
      if (w) {
        waiting.delete(m.id);
        if (m.error) w.fail(m.error); else w.done(m.result);
      }
      return;
    }
    if (m.id !== undefined && m.id !== null) {
      if (m.method === "ping" || m.method === "ui/resource-teardown") {
        if (m.method === "ui/resource-teardown") stop();
        post({ jsonrpc: "2.0", id: m.id, result: {} });
      } else {
        post({ jsonrpc: "2.0", id: m.id, error: { code: -32601, message: "not handled here: " + m.method } });
      }
      return;
    }
    const p = m.params && typeof m.params === "object" ? m.params : {};
    if (m.method === "ui/notifications/tool-input") {
      input = p.arguments && typeof p.arguments === "object" ? p.arguments : {};
      if (typeof input.name === "string" && input.name.trim()) $("name").textContent = input.name.trim();
      say(DOING[tool] || "Working…", true);
    } else if (m.method === "ui/notifications/tool-result") {
      show(p);
    } else if (m.method === "ui/notifications/tool-cancelled") {
      say("Stopped before it finished.", false);
    } else if (m.method === "ui/notifications/host-context-changed") {
      context(p);
    }
  });

  ask("ui/initialize", { protocolVersion: PROTOCOL, appInfo: { name: "brickworks-model", version: "1" },
    appCapabilities: { availableDisplayModes: ["inline"] } })
    .then((result) => context(result && result.hostContext))
    .catch(() => {})
    .then(() => { tell("ui/notifications/initialized"); measure(); });
})();
</script>
</body>
</html>
`;
