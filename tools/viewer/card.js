// The model, in Claude, beside the call that built it: an MCP App
// (io.modelcontextprotocol/ui, spec 2026-01-26). Built into
// api/_viewer_page.js by tools/viewer/build.mjs; the relay serves it as
// ui://brickworks/model.html (api/_viewer.js).
//
// The host hands this page the call's result. Its _meta["brickworks/view"]
// carries the parts count, a few pictures (src/net/model_views.gd) and the
// model itself, packed (src/net/model_scene.gd): which part, colour, place
// and turn for every brick. Each part's geometry is the file the app loads,
// fetched from where the app fetches it (the one origin _meta.ui.csp
// declares) and kept by the browser for good, since its name is its hash.
//
// So the card draws the real model in 3D: orbit, zoom, pick a part. Its
// buttons call the app's tab back through the host (tools/call, to tools
// only the app can see): Check, Instructions, Parts and Open in Brickworks.
// A part picked is told to Claude (ui/update-model-context) and selected
// in the person's tab, so "make this blue" means it either way.
//
// Without WebGL, or a scene, or the geometry, it is the turntable of
// pictures it was before.
import { Color, Quaternion, Vector3 } from "three";
import { SCENERY, sceneShape, unpack } from "./scene.js";
import { CLAY, View, shapes, webglWorks } from "./view.js";

const PROTOCOL = "2026-01-26";
const SIDES = { corner: "Front right", "back right": "Back right", "far corner": "Back left",
  "front left": "Front left", front: "Front", back: "Back", left: "Left", right: "Right", top: "Top" };
const DOING = { submit_design: "Building it…", edit_model: "Changing it…",
  view_model: "Taking a picture…", look_at_model: "Reading the model…" };
// The app's own colours for a joint carrying half its working load and all
// of it (src/render/balance_mark.gd CLOSE and TIPS).
const CLOSE = new Color(1.0, 0.76, 0.22);
const TIPS = new Color(0.97, 0.32, 0.26);
const PICKED = 0xffd84d;
const NEW_IN_STEP = 0x3b9eff;

const $ = (id) => document.getElementById(id);
const root = document.documentElement;
const still = matchMedia("(prefers-reduced-motion: reduce)").matches;
root.dataset.theme = matchMedia("(prefers-color-scheme: light)").matches ? "light" : "dark";

// What a check can read of the card: brickworksCard (tools/web/app_host_check.mjs).
// Reading only: nothing here changes what the card shows.
const card = window.brickworksCard = { state: "waiting", timings: {}, mode: "", picked: null,
  told: [], called: [], errors: [],
  sample: () => (view ? view.sample() : null),
  angle: () => (view ? view.angle() : null),
  turning: () => Boolean(view && view.controls && view.controls.autoRotate),
  shown: () => (view ? view.instances() : 0),
  pickAt: (x, y) => (view ? view.pick(x, y) : -1),
  idOf: (i) => (data && i >= 0 ? data.ids[i] : 0),
  geometry: () => performance.getEntriesByType("resource").filter((e) => /\.lbm$/.test(e.name))
    .reduce((sum, e) => ({ files: sum.files + 1, bytes: sum.bytes + (e.encodedBodySize || e.transferSize || 0) }), { files: 0, bytes: 0 }),
};
const now = () => Math.round(performance.now());
const mark = (what) => { card.timings[what] = now(); };

// ── The host: JSON-RPC 2.0 over postMessage to this frame's parent ─────────
let sent = 0;
const waiting = new Map();
const post = (message) => window.parent.postMessage(message, "*");
const tell = (method, params) => post(params === undefined ? { jsonrpc: "2.0", method } : { jsonrpc: "2.0", method, params });
function ask(method, params, ms = 200000) {
  return new Promise((done, fail) => {
    sent += 1;
    const id = sent;
    const timer = setTimeout(() => { waiting.delete(id); fail(new Error(`${method}: no answer`)); }, ms);
    waiting.set(id, { done: (r) => { clearTimeout(timer); done(r); }, fail: (e) => { clearTimeout(timer); fail(e); } });
    post({ jsonrpc: "2.0", id, method, params });
  });
}
const host = { capabilities: {}, context: {} };
const can = (what) => Boolean(host.capabilities && host.capabilities[what]);

// A tool of the viewer's (src/net/viewer_tools.gd), called through the
// host: its structuredContent, or a thrown Error saying why not, marked
// refused when it was the host that said no rather than the tab.
async function callTool(name, args = {}) {
  card.called.push(name);
  let result;
  try {
    result = await ask("tools/call", { name, arguments: args });
  } catch (trouble) {
    throw Object.assign(trouble instanceof Error ? trouble : new Error(String(trouble)), { refused: true });
  }
  const given = result && typeof result === "object" ? result : {};
  const data = given.structuredContent && typeof given.structuredContent === "object" ? given.structuredContent : null;
  const words = (Array.isArray(given.content) ? given.content : []).filter((b) => b && b.type === "text")
    .map((b) => String(b.text)).filter((t) => !/^Tab \S+, /.test(t)).join(" ").trim();
  if (given.isError || !data) throw new Error(words || "Brickworks did not answer that.");
  if (data.busy) throw new Error(words || "Brickworks is busy with another call; try again in a moment.");
  return data;
}

// What the viewer asks the tab for: by its tool, or, from a host that will
// not call a tool its model was not given, by reading
// brickworks://viewer/<kind>, which the relay answers with the same call.
async function viewer(kind, args = {}) {
  let refused = null;
  if (can("serverTools") || !can("serverResources")) {
    try {
      const data = await callTool(`viewer_${kind}`, args);
      card.via = "tools/call";
      return data;
    } catch (trouble) {
      if (!trouble.refused) throw trouble;
      refused = trouble;
      card.errors.push(`viewer_${kind} refused: ${trouble.message}`);
    }
  }
  const uri = `brickworks://viewer/${kind}${kind === "scene" && args.views ? "?views=1" : ""}`;
  card.called.push(uri);
  const read = await ask("resources/read", { uri });
  const first = read && Array.isArray(read.contents) ? read.contents[0] : null;
  if (!first || typeof first.text !== "string") {
    throw refused || new Error("Brickworks did not answer that.");
  }
  const data = JSON.parse(first.text);
  if (data.busy) throw new Error("Brickworks is busy with another call; try again in a moment.");
  card.via = "resources/read";
  return data;
}

// Whether this frame can draw in 3D at all, asked once.
const webgl = webglWorks();
card.webgl = webgl;

function context(given) {
  const c = given && typeof given === "object" ? given : {};
  Object.assign(host.context, c);
  if (c.theme === "light" || c.theme === "dark") {
    root.dataset.theme = c.theme;
    if (view) view.themed();
  }
  const styles = c.styles && typeof c.styles === "object" ? c.styles : null;
  if (styles && styles.variables && typeof styles.variables === "object") {
    const v = styles.variables;
    const use = (ours, theirs) => { if (typeof v[theirs] === "string" && v[theirs]) root.style.setProperty(ours, v[theirs]); };
    use("--font", "--font-sans");
    use("--panel", "--color-background-primary");
    use("--panel-hi", "--color-background-secondary");
    use("--ink", "--color-text-primary");
    use("--ink-faint", "--color-text-secondary");
    use("--line", "--color-border-tertiary");
    use("--focus", "--color-ring-primary");
    use("--radius", "--border-radius-xl");
  }
  if (styles && styles.css && typeof styles.css.fonts === "string" && !document.getElementById("fonts")) {
    const sheet = document.createElement("style");
    sheet.id = "fonts";
    sheet.textContent = styles.css.fonts;
    document.head.append(sheet);
  }
  const s = c.safeAreaInsets;
  if (s && typeof s === "object") {
    document.body.style.padding = [s.top, s.right, s.bottom, s.left].map((n) => (Number(n) || 0) + "px").join(" ");
  }
  if (c.displayMode) displayed(c.displayMode);
  const modes = Array.isArray(host.context.availableDisplayModes) ? host.context.availableDisplayModes : [];
  $("full").hidden = !(modes.includes("fullscreen") && view);
  const name = c.toolInfo && c.toolInfo.tool && c.toolInfo.tool.name;
  if (typeof name === "string") tool = name;
}

// ── The answer ──────────────────────────────────────────────────────────────
let input = {};
let tool = "";
let given = {};
let scene = null;
let data = null;
let view = null;

function say(words, busy) {
  $("card").classList.toggle("waiting", Boolean(busy));
  $("card").setAttribute("aria-busy", busy ? "true" : "false");
  $("say").hidden = !words;
  $("say").firstElementChild.textContent = words || "";
}

const picture = (one) => one && /^image\/(png|webp|jpeg)$/.test(String(one.mimeType))
  && typeof one.data === "string" && one.data.length > 0 && /^[A-Za-z0-9+/]+=*$/.test(one.data);
const source = (one) => "data:" + one.mimeType + ";base64," + one.data;

function words(result) {
  const said = (Array.isArray(result.content) ? result.content : [])
    .filter((b) => b && b.type === "text" && typeof b.text === "string").map((b) => b.text.trim());
  const first = said.length > 1 && /^Tab /.test(said[0]) ? said[1] : said[0] || "";
  const line = first.split("\n")[0];
  return line.length > 180 ? line.slice(0, 177) + "…" : line;
}

let shown = false;
async function show(result) {
  shown = true;
  clearTimeout(kick);
  mark("result");
  const r = result && typeof result === "object" ? result : {};
  const meta = r._meta && typeof r._meta === "object" ? r._meta : {};
  given = meta["brickworks/view"] && typeof meta["brickworks/view"] === "object" ? meta["brickworks/view"] : {};
  const named = (typeof meta["brickworks/model"] === "string" && meta["brickworks/model"].trim())
    || (typeof input.name === "string" && input.name.trim()) || "Your model";
  $("name").textContent = named;
  card.tab = typeof meta["brickworks/tab"] === "string" ? meta["brickworks/tab"] : "";
  // The call ran past the time a call is waited for and became a job: the
  // model is still being worked on, so this card follows the job and shows
  // its answer, which is the call's own, once it ends (once only).
  const job = meta["brickworks/job"];
  if (job && typeof job === "object" && Number.isInteger(job.id) && !meta["brickworks/view"]
      && card.followed !== job.id && card.job !== job.id) {
    await followed(job.id, r);
    return;
  }
  counted(Number.isInteger(given.parts) && given.parts >= 0 ? given.parts : null);
  let found = (Array.isArray(given.views) ? given.views : []).filter(picture)
    .map((v) => ({ side: SIDES[v.from] || "", src: source(v) }));
  // A picture of its own (view_model, edit_model): the one asked for.
  const own = (Array.isArray(r.content) ? r.content : []).filter((b) => b && b.type === "image" && picture(b))
    .map((b) => ({ side: SIDES[input.from] || "", src: source(b) }));
  if (own.length) found = own;
  pictures(found);
  scene = sceneShape(given.scene);
  if (scene && scene.count > 0 && webgl) {
    card.source = "result";
    await three(scene);
  } else if (webgl || !own.length) {
    // The host handed it nothing to draw (most do not, or take _meta off),
    // or the model was too big to ride along: asked for, from the tab. In
    // a frame that cannot draw in 3D, the turntable is asked for instead.
    await fetched(r);
  }
  tools();
}

// A call that became a job (src/net/tool_jobs.gd), followed to its end as a
// session follows it, with the job tool, through the host: each call waits
// up to 10 s for the work to end. Its answer once done is the call's own,
// picture and model and all, and is shown as that. A host that will not
// let the card call it, or a tab that does not say, and the model is shown
// as it stands once the tab is no longer working on it.
const JOB_TIMES = 120;
async function followed(id, r) {
  card.job = id;
  say(`${DOING[tool] || "Working…"} It is taking a while; this shows it when your Brickworks tab is done.`, true);
  for (let n = 0; n < JOB_TIMES; n++) {
    let answer = null;
    try {
      answer = await ask("tools/call", { name: "job", arguments: { id, ...(card.tab ? { target: card.tab } : {}) } }, 60000);
    } catch (trouble) {
      card.errors.push(`job: ${trouble.message || trouble}`);
      break;
    }
    const meta = answer && typeof answer === "object" && answer._meta && typeof answer._meta === "object" ? answer._meta : {};
    const said = meta["brickworks/job"];
    if (!said || typeof said !== "object" || answer.isError) break;
    if (said.done) {
      card.followed = id;
      const asked = said.input && typeof said.input === "object" ? said.input : {};
      if (typeof asked.from === "string" && input.from === undefined) input = { ...input, from: asked.from };
      return show(answer);
    }
    await new Promise((done) => setTimeout(done, 1000));
  }
  for (let n = 0; n < JOB_TIMES; n++) {
    const now = await viewer("scene", {}).catch(() => null);
    if (!now || !now.working) break;
    await new Promise((done) => setTimeout(done, 5000));
  }
  card.followed = id;
  await fetched(r);
  tools();
}

// The model from the tab itself, through the host; where this frame cannot
// draw in 3D, its turntable.
async function fetched(r = {}) {
  if (card.fetching) return;
  card.fetching = true;
  if (!views.length) say("Getting the model from your Brickworks tab…", true);
  try {
    const answer = await viewer("scene", webgl ? {} : { views: true });
    card.source = card.via;
    if (typeof answer.model === "string" && answer.model.trim()) $("name").textContent = answer.model.trim();
    if (typeof answer.tab === "string" && answer.tab) card.tab = answer.tab;
    if (Number.isInteger(answer.parts)) counted(answer.parts);
    const found = (Array.isArray(answer.views) ? answer.views : []).filter(picture)
      .map((v) => ({ side: SIDES[v.from] || "", src: source(v) }));
    if (found.length > views.length) pictures(found);
    scene = sceneShape(answer.scene);
    if (scene && scene.count > 0 && webgl) await three(scene);
    if (!view && !views.length) {
      say(answer.parts === 0 ? "Nothing is built yet." : (words(r) || "No picture of it could be drawn."), false);
    }
  } catch (trouble) {
    card.errors.push(`scene: ${trouble.message || trouble}`);
    if (!view && !views.length) say(trouble.message || words(r) || "Brickworks did not answer.", false);
  } finally {
    card.fetching = false;
    tools();
  }
}

// A host that never sends the result (or sends it before the page is
// ready to hear it) still gets the model shown: asked for a moment after
// the page is up, unless a call is under way, and then when it has had
// all the time a call has.
let kick = 0;
function waitForResult(ms) {
  clearTimeout(kick);
  kick = setTimeout(() => { if (!shown) fetched(); }, ms);
}

function counted(parts) {
  $("parts").textContent = parts === null ? "" : parts.toLocaleString() + (parts === 1 ? " part" : " parts");
  card.parts = parts;
}

// ── Pictures: the turntable, and what is shown before the 3D is ready ──────
let views = [];
let at = 0;
let timer = 0;

function pictures(found) {
  stop();
  views = found;
  at = 0;
  say("", false);
  $("views").replaceChildren();
  $("turn").hidden = true;
  $("stage").classList.remove("turns");
  if (!views.length) { $("picture").hidden = true; return; }
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
  if (!views.length) return;
  at = ((n % views.length) + views.length) % views.length;
  const one = views[at];
  const img = $("picture");
  img.src = one.src;
  img.alt = $("name").textContent + (one.side ? ", from the " + one.side.toLowerCase() : "");
  if (!view) $("where").textContent = !one.side ? "" : views.length > 1 ? one.side : "From the " + one.side.toLowerCase();
  [...$("views").children].forEach((b, k) => b.setAttribute("aria-pressed", k === at ? "true" : "false"));
}

function play(laps) {
  stop();
  let left = laps * views.length;
  $("turn").textContent = "Stop";
  timer = setInterval(() => { left -= 1; go(at + 1); if (left <= 0) stop(); }, 1400);
}
function stop() {
  if (timer) clearInterval(timer);
  timer = 0;
  $("turn").textContent = "Turn";
}
$("turn").addEventListener("click", () => (timer ? stop() : play(1)));

// Dragged across, a quarter turn every 48 px: the pictures' own turning,
// until the 3D takes the stage.
let from = null;
$("stage").addEventListener("pointerdown", (event) => {
  if (view || views.length < 2) return;
  from = event.clientX;
  $("stage").setPointerCapture(event.pointerId);
  stop();
});
$("stage").addEventListener("pointermove", (event) => {
  if (view || from === null) return;
  const steps = Math.trunc((event.clientX - from) / 48);
  if (steps) { from += steps * 48; go(at - steps); }
});
const letGo = () => { from = null; };
$("stage").addEventListener("pointerup", letGo);
$("stage").addEventListener("pointercancel", letGo);

function note(words, ms = 0) {
  const el = $("note");
  el.textContent = words || "";
  el.hidden = !words;
  if (ms) setTimeout(() => { if (el.textContent === words) el.hidden = true; }, ms);
}

// ── The model in 3D ─────────────────────────────────────────────────────────
// The scene itself, and each part's geometry, are view.js's; what is the
// card's is where the geometry comes from: the store the scene names, or,
// once a fetch from it has failed (a host that does not let the page reach
// it), through the host, every part.
let shapeStore = null;
let shapeRoot = "";
function shapeOf(mesh) {
  if (!shapeStore || shapeRoot !== scene.root) {
    shapeRoot = scene.root;
    shapeStore = shapes(scene.root, { errors: card.errors, fallback: () => can("serverResources"),
      hosted: (one) => ask("resources/read", { uri: `brickworks://viewer/part/${one.hash}` }, 60000).then((read) => {
        const blob = read && read.contents && read.contents[0] && read.contents[0].blob;
        if (typeof blob !== "string") throw new Error("no geometry");
        const raw = atob(blob);
        const bytes = new Uint8Array(raw.length);
        for (let k = 0; k < raw.length; k++) bytes[k] = raw.charCodeAt(k);
        card.geometryThroughHost = (card.geometryThroughHost || 0) + 1;
        return bytes.buffer;
      }) });
  }
  return shapeStore(mesh);
}

// What the card gives the scene: its timings, its errors, and the touch
// shared with the conversation until it is full screen.
const viewOptions = () => ({ still, errors: card.errors, shapeOf,
  mark: (what) => { if (!card.timings[what]) mark(what); },
  touchAction: () => (root.classList.contains("full") ? "none" : "pan-y"),
  lost: (shot) => {
    if (shot) { $("picture").src = shot; $("picture").hidden = false; }
    $("stage").classList.remove("three");
  } });

async function three(s) {
  if (!s) return;
  let d;
  try {
    d = await unpack(s);
  } catch (trouble) {
    card.errors.push(`scene: ${trouble.message}`);
    return;
  }
  mark("unpacked");
  data = d;
  card.of = s.of;
  card.bricks = d.n;
  card.models = d.meshes.length;
  const next = new View($("stage"), d, viewOptions());
  try {
    next.start();
  } catch (trouble) {
    card.errors.push(`WebGL: ${trouble.message}`);
    // Pictures, then: the turntable, asked for when none came.
    if (views.length < 2) {
      try {
        const answer = await viewer("scene", { views: true });
        const found = (answer.views || []).filter(picture).map((v) => ({ side: SIDES[v.from] || "", src: source(v) }));
        if (found.length > views.length) pictures(found);
      } catch (again) { card.errors.push(`views: ${again.message || again}`); }
    }
    if (views.length) note("This browser cannot draw the model in 3D, so these are pictures of it.", 6000);
    else say("This browser cannot draw the model in 3D.", false);
    return;
  }
  if (view) view.stop(false);
  view = next;
  card.mode = "3d";
  stop();
  $("views").replaceChildren();
  $("turn").hidden = true;
  $("stage").classList.remove("turns");
  $("stage").setAttribute("aria-label", `${$("name").textContent} in 3D. Drag to turn it, scroll or pinch to zoom, `
    + "and click a part to pick it. The arrow keys turn it, plus and minus zoom, and 0 goes back.");
  $("where").textContent = "";
  const bar = $("loading");
  bar.hidden = false;
  card.state = "loading";
  await view.load((share) => {
    bar.firstElementChild.style.width = Math.round(share * 100) + "%";
    if (share >= 0.25 && !$("stage").classList.contains("three")) $("stage").classList.add("three");
  });
  mark("loaded");
  $("stage").classList.add("three");
  bar.hidden = true;
  card.state = "ready";
  say("", false);
  if (looking) looking();
  const modes = Array.isArray(host.context.availableDisplayModes) ? host.context.availableDisplayModes : [];
  $("full").hidden = !modes.includes("fullscreen");
  hint();
}

function hint() {
  if (!view || view.interacted) return;
  const coarse = matchMedia("(pointer: coarse)").matches || host.context.deviceCapabilities?.touch;
  note(coarse ? "Drag across to turn it · pinch to zoom · tap a part" : "Drag to turn · scroll to zoom · click a part", 5000);
}

// Kept drawing only while it is on screen.
let offSince = 0;
new IntersectionObserver((entries) => {
  const on = entries.some((e) => e.isIntersecting);
  if (!view) return;
  if (on) {
    offSince = 0;
    if (!view.renderer && data) {
      try { view.start(); $("stage").classList.add("three"); } catch (trouble) { card.errors.push(`WebGL again: ${trouble.message}`); }
    } else view.render();
  } else {
    offSince = performance.now();
    if (view.controls) view.controls.autoRotate = false;
  }
}).observe($("stage"));
setInterval(() => {
  if (view && view.renderer && offSince && performance.now() - offSince > 20000) {
    view.stop(true);
    if (view.still) { $("picture").src = view.still; $("picture").hidden = false; }
    $("stage").classList.remove("three");
    card.released = (card.released || 0) + 1;
  }
}, 5000);
new ResizeObserver(() => { if (view) view.size(); measure(); }).observe($("stage"));

// ── Picking a part ──────────────────────────────────────────────────────────
let down = null;
$("stage").addEventListener("pointerdown", (event) => { if (view) down = { x: event.clientX, y: event.clientY, t: performance.now() }; }, true);
$("stage").addEventListener("pointerup", (event) => {
  if (!view || !down) return;
  const moved = Math.hypot(event.clientX - down.x, event.clientY - down.y);
  const quick = performance.now() - down.t < 600;
  down = null;
  if (moved > 6 || !quick) return;
  const i = view.pick(event.clientX, event.clientY);
  if (i >= 0) pick(i, true); else unpick(true);
}, true);

function colourOf(i) { return data.colours[data.colour[i]] || { name: "", hex: "888888", code: -1 }; }
function partOf(i) { return data.meshes[data.mesh[i]] || { part: "?", name: "a part" }; }

// Where a part is in the model, as a person would say it: its middle, by
// the thirds of the model's box (the ground it stands on left out), front
// being +z and right +x as the app's own views have them.
function placeOf(i) {
  const b = view.modelBounds;
  const box = partOf(i).bounds || [];
  const middle = new Vector3(...(box.length === 6 && box.every(Number.isFinite)
    ? [(box[0] + box[3]) / 2, (box[1] + box[4]) / 2, (box[2] + box[5]) / 2] : [0, 0, 0]))
    .applyQuaternion(new Quaternion(data.turn[i * 4], data.turn[i * 4 + 1], data.turn[i * 4 + 2], data.turn[i * 4 + 3]))
    .add(new Vector3(data.position[i * 3], data.position[i * 3 + 1], data.position[i * 3 + 2]));
  const third = (v, lo, hi) => (hi - lo < 1e-6 ? 1 : Math.max(0, Math.min(2, Math.floor(((v - lo) / (hi - lo)) * 3))));
  const x = third(middle.x, b.min.x, b.max.x);
  const y = third(middle.y, b.min.y, b.max.y);
  const z = third(middle.z, b.min.z, b.max.z);
  const across = ["left", "", "right"][x];
  const deep = ["back", "", "front"][z];
  const side = deep && across ? `${deep} ${across}` : deep || across;
  const height = ["near the bottom", "half way up", "near the top"][y];
  return side ? `at the ${side}, ${height}` : `in the middle, ${height}`;
}

function pick(i, byHand) {
  if (!view || !data) return;
  card.picked = { index: i, id: data.ids[i] };
  const part = partOf(i);
  const colour = colourOf(i);
  const where = placeOf(i);
  const el = $("picked");
  el.replaceChildren();
  const swatch = document.createElement("span");
  swatch.className = "swatch";
  swatch.style.background = "#" + colour.hex;
  const text = document.createElement("span");
  const b = document.createElement("b");
  b.textContent = `#${data.ids[i]}`;
  text.append(b, ` ${part.name} · ${colour.name}`);
  const x = document.createElement("button");
  x.className = "x";
  x.type = "button";
  x.textContent = "×";
  x.setAttribute("aria-label", "Let go of this part");
  x.addEventListener("click", () => unpick(true));
  el.append(swatch, text, x);
  el.hidden = false;
  note("");
  view.outline([i], PICKED);
  if (!byHand) return;
  const id = data.ids[i];
  const what = `brick #${id}, a ${part.part} ${part.name} in ${colour.name}${colour.code >= 0 ? ` (colour ${colour.code})` : ""}, ${where}`;
  const facts = { picked: { brick: id, part: part.part, name: part.name, colour: colour.name, code: colour.code, where } };
  // Selected in the person's tab first, where Claude's selection tool reads
  // it; then Claude is told, saying whether it is.
  const asked = card.picked;
  callTool("viewer_pick", { brick: id, of: card.of || "" })
    .then((r) => r, (trouble) => { card.errors.push(`pick: ${trouble.message}`); return {}; })
    .then((r) => {
      card.selected = r;
      if (card.picked !== asked) return;
      if (r.changed) note("The model has changed since this card was made.", 5000);
      const said = `In the Brickworks viewer the person picked ${what}. It is the part they mean by "this" or "it" `
        + "until they pick another; its number is the one look_at_model prints, and edit_model takes it."
        + (r.selected ? " It is selected in their Brickworks tab too, so selection and edit_selection act on it."
          : r.changed ? " Their model has changed since this view of it was made, so check the number with look_at_model first." : "");
      tellClaude(said, facts);
    });
}

function unpick(byHand) {
  if (!card.picked) return;
  card.picked = null;
  $("picked").hidden = true;
  if (view) view.outline(panel === "steps" ? stepNew() : [], NEW_IN_STEP);
  if (byHand) {
    tellClaude("In the Brickworks viewer the person has let go of the part they picked: nothing is picked now.", { picked: null });
    callTool("viewer_pick", { brick: 0, of: card.of || "" }).catch(() => {});
  }
}

function tellClaude(text, structured) {
  card.told.push(text);
  if (!can("updateModelContext")) return;
  ask("ui/update-model-context", { content: [{ type: "text", text }], structuredContent: structured })
    .catch((trouble) => card.errors.push(`context: ${trouble.message || trouble}`));
}

// ── Keys ────────────────────────────────────────────────────────────────────
$("stage").addEventListener("keydown", (event) => {
  if (!view) {
    if (views.length < 2) return;
    if (event.key === "ArrowRight" || event.key === "ArrowLeft") {
      event.preventDefault();
      stop();
      go(at + (event.key === "ArrowRight" ? 1 : -1));
    }
    return;
  }
  const turn = Math.PI / 12;
  const keys = { ArrowLeft: () => view.orbitBy(-turn, 0), ArrowRight: () => view.orbitBy(turn, 0),
    ArrowUp: () => view.orbitBy(0, -turn / 1.5), ArrowDown: () => view.orbitBy(0, turn / 1.5),
    "+": () => view.zoomBy(0.85), "=": () => view.zoomBy(0.85), "-": () => view.zoomBy(1 / 0.85),
    "0": () => view.reset(), Home: () => view.reset(), Escape: () => unpick(true) };
  if (keys[event.key]) { event.preventDefault(); keys[event.key](); }
});

// ── Full screen ─────────────────────────────────────────────────────────────
function displayed(mode) {
  card.displayMode = mode;
  const full = mode === "fullscreen";
  root.classList.toggle("full", full);
  $("full").setAttribute("aria-label", full ? "Leave full screen" : "Full screen");
  $("full").title = full ? "Leave full screen" : "Full screen";
  $("full").firstElementChild.innerHTML = full
    ? '<path d="M9 4v5H4M15 4v5h5M9 20v-5H4M15 20v-5h5"/>'
    : '<path d="M4 9V4h5M20 9V4h-5M4 15v5h5M20 15v5h-5"/>';
  if (view) { view.touch(); setTimeout(() => view.size(), 50); }
  measure();
}
$("full").addEventListener("click", async () => {
  const want = root.classList.contains("full") ? "inline" : "fullscreen";
  card.requested = want;
  try {
    const answer = await ask("ui/request-display-mode", { mode: want }, 10000);
    displayed(answer && answer.mode ? answer.mode : host.context.displayMode || "inline");
  } catch (trouble) {
    card.errors.push(`display mode: ${trouble.message || trouble}`);
  }
});

// ── The buttons: the tab, called through the host ───────────────────────────
let panel = "";
let looking = null;
let stepAt = 0;
let checked = null;
let planned = null;
let listed = null;

function tools() {
  const through = can("serverTools") || can("serverResources");
  const drawn = Boolean(view);
  $("check").hidden = !(through && drawn);
  $("steps").hidden = !(through && drawn);
  $("list").hidden = !(through && drawn);
  $("open").hidden = !(can("openLinks") && card.tab && scene && scene.site);
  measure();
}

function press(which) {
  for (const id of ["check", "steps", "list"]) $(id).setAttribute("aria-pressed", id === which ? "true" : "false");
}

function close() {
  panel = "";
  press("");
  $("panel").hidden = true;
  $("panel").replaceChildren();
  looking = null;
  if (view) { view.look = null; view.paint(); view.outline(card.picked ? [card.picked.index] : [], PICKED); }
  measure();
}

function open(which, build) {
  if (panel === which) { close(); return false; }
  panel = which;
  press(which);
  // What the last panel showed on the model goes with it.
  looking = null;
  if (view) { view.look = null; view.paint(); view.outline(card.picked ? [card.picked.index] : [], PICKED); }
  const el = $("panel");
  el.hidden = false;
  el.replaceChildren(build());
  measure();
  return true;
}

// Children put in, leaving out the ones not there: replaceChildren writes
// a null in as the word "null".
function put(el, ...children) {
  el.replaceChildren(...children.filter((c) => c !== null && c !== undefined && c !== false));
}

function element(tag, props = {}, ...children) {
  const el = document.createElement(tag);
  for (const [k, v] of Object.entries(props)) {
    if (k === "class") el.className = v;
    else if (k.startsWith("on")) el.addEventListener(k.slice(2), v);
    else if (v !== undefined && v !== null && v !== false) el.setAttribute(k, v === true ? "" : String(v));
  }
  el.append(...children.filter((c) => c !== null && c !== undefined && c !== false));
  return el;
}
const swatchOf = (hex) => { const s = element("span", { class: "swatch" }); s.style.background = "#" + hex; return s; };
const waitingFor = (words) => element("p", { class: "faint" }, words);

// The tab's answers are about the model as it is now. When it has changed
// since this card was made, the card is brought up to date first.
async function current(answer) {
  if (!answer.of || answer.of === card.of) return true;
  note("The model has changed since this card. Showing it as it is now…");
  const fresh = await viewer("scene");
  const s = sceneShape(fresh.scene);
  if (!s) throw new Error("Brickworks did not send the model.");
  scene = s;
  if (Number.isInteger(fresh.parts)) counted(fresh.parts);
  const keep = panel;
  unpick(false);
  await three(s);
  panel = keep;
  note("Up to date: the model as it is now.", 4000);
  return true;
}

$("check").addEventListener("click", async () => {
  if (!open("check", () => waitingFor("Checking the joints and the balance in your Brickworks tab…"))) return;
  try {
    const answer = checked = await viewer("check");
    await current(answer);
    if (panel !== "check") return;
    showCheck(answer);
  } catch (trouble) {
    if (panel === "check") $("panel").replaceChildren(waitingFor(trouble.message));
  }
});

function showCheck(answer) {
  const stress = new Map((answer.stress || []).map(([id, ratio]) => [Number(id), Number(ratio)]));
  const weak = new Map((answer.weak || []).map((w) => [Number(w.id), String(w.message || "")]));
  const marked = new Set([...stress.keys(), ...weak.keys()]);
  card.tinted = { weak: weak.size, strained: stress.size,
    marked: [...marked].filter((id) => data.byId.has(id)).length };
  looking = () => {
    view.look = (i) => {
      const id = data.ids[i];
      if (data.flags[i] & SCENERY) return null;
      if (weak.has(id)) return { colour: TIPS };
      if (stress.has(id)) return { colour: CLOSE.clone().lerp(TIPS, Math.min(1, Math.max(0, (stress.get(id) - 0.5) * 2))) };
      return { colour: CLAY };
    };
    view.paint();
  };
  looking();
  const problems = [...weak.entries()].map(([id, message]) => ({ id, message, ratio: 2 }))
    .concat([...stress.entries()].filter(([id]) => !weak.has(id))
      .map(([id, ratio]) => ({ id, ratio, message: `carries ${Math.round(ratio * 100)}% of what its studs hold` })))
    .sort((a, b) => b.ratio - a.ratio);
  const items = problems.slice(0, 6).map((p) => {
    const i = data.byId.get(p.id);
    const part = i === undefined ? null : partOf(i);
    return element("li", {}, element("button", { type: "button", onclick: () => { if (i !== undefined) pick(i, true); } },
      swatchOf(p.ratio >= 1 ? "f75242" : "ffc238"),
      element("span", { class: "what" }, element("b", {}, `#${p.id}`), ` ${part ? part.name : ""} — ${p.message}`)));
  });
  const fix = problems.length && can("message") ? element("button", { class: "tool", type: "button", onclick: () => {
    const ids = problems.slice(0, 12).map((p) => `#${p.id}`).join(", ");
    ask("ui/message", { role: "user", content: [{ type: "text",
      text: `The Brickworks check found ${problems.length} weak or strained joint${problems.length === 1 ? "" : "s"} (${ids}). Please make them hold.` }] })
      .catch((trouble) => card.errors.push(`message: ${trouble.message || trouble}`));
  } }, "Ask Claude to fix them") : null;
  put($("panel"),
    element("h2", {}, marked.size ? `${marked.size} part${marked.size === 1 ? "" : "s"} to look at` : "It holds together"),
    element("p", {}, String(answer.words || "")),
    marked.size ? element("div", { class: "legend" },
      element("span", {}, swatchOf("f75242"), "weak joint, or all its studs hold"),
      element("span", {}, swatchOf("ffc238"), "half of what its studs hold"),
      element("span", {}, swatchOf("c9ced6"), "fine")) : null,
    items.length ? element("ul", { class: "issues" }, ...items) : null,
    fix ? element("div", { class: "actions" }, fix) : null);
  measure();
}

$("steps").addEventListener("click", async () => {
  if (!open("steps", () => waitingFor("Setting out the steps, as the booklet has them…"))) return;
  try {
    const answer = planned = await viewer("steps");
    await current(answer);
    if (panel !== "steps") return;
    stepAt = Math.max(0, Math.min(stepAt || 0, (answer.steps || []).length - 1));
    showSteps();
  } catch (trouble) {
    if (panel === "steps") $("panel").replaceChildren(waitingFor(trouble.message));
  }
});

let stepOf = null;
function stepNew() {
  const step = planned && planned.steps && planned.steps[stepAt];
  if (!step) return [];
  return (step.ids || []).map((id) => data.byId.get(Number(id))).filter((i) => i !== undefined);
}

function showSteps() {
  const steps = planned.steps || [];
  if (!steps.length) { $("panel").replaceChildren(waitingFor("This model has no steps yet.")); return; }
  stepOf = new Int32Array(data.n).fill(-1);
  steps.forEach((step, k) => { for (const id of step.ids || []) { const i = data.byId.get(Number(id)); if (i !== undefined) stepOf[i] = k; } });
  looking = () => {
    view.look = (i) => (!(data.flags[i] & SCENERY) && stepOf[i] > stepAt ? { hidden: true } : null);
    view.paint();
    view.outline(card.picked ? [card.picked.index] : stepNew(), card.picked ? PICKED : NEW_IN_STEP);
  };
  looking();
  const step = steps[stepAt];
  const lots = new Map();
  for (const i of stepNew()) {
    if (step.shown && step.shown.length && !step.shown.includes(data.ids[i])) continue;
    const key = `${data.mesh[i]}:${data.colour[i]}`;
    lots.set(key, (lots.get(key) || 0) + 1);
  }
  const chips = [...lots.entries()].map(([key, count]) => {
    const [m, c] = key.split(":").map(Number);
    return element("span", { class: "lot" }, swatchOf(data.colours[c]?.hex || "888888"),
      `${count}× ${data.meshes[m]?.name || data.meshes[m]?.part || "part"}`);
  });
  const about = [step.section ? step.section : "", step.assembly ? `${step.assembly}${step.times > 1 ? ` ×${step.times}` : ""}` : "",
    step.callout_steps ? `sub-assembly step ${step.callout_step || step.callout_steps} of ${step.callout_steps}` : ""].filter(Boolean).join(" · ");
  const prev = element("button", { class: "tool", type: "button", "aria-label": "Previous step", disabled: stepAt === 0,
    onclick: () => { stepAt -= 1; showSteps(); } }, "‹ Back");
  const next = element("button", { class: "tool", type: "button", "aria-label": "Next step", disabled: stepAt >= steps.length - 1,
    onclick: () => { stepAt += 1; showSteps(); } }, "Next ›");
  const at = element("div", { class: "at" }, `Step ${step.number || stepAt + 1}`,
    element("small", {}, `${stepAt + 1} of ${steps.length}${about ? " · " + about : ""}`));
  card.step = { at: stepAt + 1, of: steps.length, number: step.number, shown: view.instances() };
  put($("panel"), element("div", { class: "stepper" }, prev, at, next),
    chips.length ? element("div", { class: "lots" }, ...chips) : element("p", { class: "faint" }, "This step puts on what was built beside it."));
  const focusNext = $("panel").querySelector(document.activeElement && document.activeElement.textContent?.startsWith("‹") ? "button" : "button:last-of-type");
  if (document.activeElement && document.activeElement.closest && document.activeElement.closest("#panel")) focusNext?.focus();
  measure();
}

$("list").addEventListener("click", async () => {
  if (!open("list", () => waitingFor("Counting the parts…"))) return;
  try {
    const answer = listed = await viewer("parts");
    await current(answer);
    if (panel !== "list") return;
    showParts(false);
  } catch (trouble) {
    if (panel === "list") $("panel").replaceChildren(waitingFor(trouble.message));
  }
});

function showParts(all) {
  const lots = listed.lots || [];
  let chosen = -1;
  const rows = (all ? lots : lots.slice(0, 10)).map((lot, k) => element("li", {}, element("button", { type: "button", "aria-pressed": "false",
    onclick: (event) => {
      chosen = chosen === k ? -1 : k;
      for (const b of $("panel").querySelectorAll(".rows button")) b.setAttribute("aria-pressed", "false");
      if (chosen >= 0) event.currentTarget.setAttribute("aria-pressed", "true");
      looking = () => {
        view.look = chosen < 0 ? null : (i) => {
          const m = data.meshes[data.mesh[i]];
          const c = data.colours[data.colour[i]];
          return m && c && m.part === lots[chosen].part && c.code === lots[chosen].code ? null : (data.flags[i] & SCENERY ? null : { colour: CLAY });
        };
        view.paint();
      };
      looking();
    } },
  element("span", { class: "count" }, `${lot.count}×`), swatchOf(lot.rgb || "888888"),
  element("span", { class: "what" }, `${lot.name}, ${lot.colour}`),
  element("span", { class: "id" }, lot.element ? `${lot.part} · ${lot.element}` : lot.part))));
  const xml = listed.bricklink && listed.bricklink.text;
  const download = xml ? element("button", { class: "tool", type: "button", onclick: () => wanted(xml) }, "BrickLink wanted list") : null;
  const more = !all && lots.length > 10 ? element("button", { class: "tool quiet", type: "button", onclick: () => showParts(true) }, `All ${lots.length} lots`) : null;
  const left = listed.bricklink && listed.bricklink.left_out ? element("p", { class: "faint" }, String(listed.bricklink.left_out)) : null;
  put($("panel"),
    element("h2", {}, `${(listed.pieces || 0).toLocaleString()} piece${listed.pieces === 1 ? "" : "s"} in ${lots.length} lot${lots.length === 1 ? "" : "s"}${listed.grams ? `, about ${Math.round(listed.grams)} g` : ""}`),
    element("ul", { class: "rows" }, ...rows),
    element("div", { class: "actions" }, download, more), left);
  card.lots = lots.length;
  measure();
}

// The BrickLink wanted list: downloaded through the host where it can, or
// copied, or shown to copy.
async function wanted(xml) {
  const file = (listed && listed.file) || "brickworks-bricklink.xml";
  if (can("downloadFile")) {
    try {
      const answer = await ask("ui/download-file", { contents: [{ type: "resource",
        resource: { uri: `file:///${file}`, mimeType: "application/xml", text: xml } }] }, 60000);
      card.downloaded = file;
      if (!answer || !answer.isError) { note(`${file}: upload it at BrickLink, Want, Upload.`, 6000); return; }
    } catch (trouble) { card.errors.push(`download: ${trouble.message || trouble}`); }
  }
  try {
    await navigator.clipboard.writeText(xml);
    note("Copied. Paste it at BrickLink, Want, Upload.", 6000);
    card.copied = true;
    return;
  } catch { /* Not allowed in this frame: shown to copy instead. */ }
  const box = element("textarea", { class: "copybox", readonly: true, "aria-label": "The BrickLink wanted list, to copy" });
  box.value = xml;
  $("panel").append(element("p", { class: "faint" }, "Copy this and paste it at BrickLink, Want, Upload:"), box);
  box.focus();
  box.select();
  measure();
}

$("open").addEventListener("click", () => {
  const url = `${scene.site}/app?tab=${encodeURIComponent(card.tab)}`;
  card.opened = url;
  ask("ui/open-link", { url }, 60000).catch((trouble) => card.errors.push(`open: ${trouble.message || trouble}`));
});

// ── Size, and the conversation with the host ────────────────────────────────
let size = "";
function measure() {
  const height = Math.ceil(document.querySelector(".card").getBoundingClientRect().height
    + (parseFloat(getComputedStyle(document.body).paddingTop) || 0) + (parseFloat(getComputedStyle(document.body).paddingBottom) || 0));
  const width = Math.ceil(window.innerWidth);
  if (height > 0 && size !== width + "x" + height && !root.classList.contains("full")) {
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
      if (m.error) w.fail(Object.assign(new Error(String(m.error.message || "refused")), { code: m.error.code }));
      else w.done(m.result);
    }
    return;
  }
  if (m.id !== undefined && m.id !== null) {
    if (m.method === "ping" || m.method === "ui/resource-teardown") {
      if (m.method === "ui/resource-teardown") { stop(); if (view) view.stop(false); }
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
    if (!view) say(DOING[tool] || "Working…", true);
    if (!shown) waitForResult(250000);
  } else if (m.method === "ui/notifications/tool-result") {
    show(p).catch((trouble) => card.errors.push(`show: ${trouble.message}`));
  } else if (m.method === "ui/notifications/tool-cancelled") {
    // Stopped, or given up on by the host while the tab went on: the model
    // is whatever the tab has now, which is still worth showing.
    shown = true;
    clearTimeout(kick);
    if (!view) {
      say("Stopped before it finished. Getting the model as it stands…", true);
      fetched({ content: [{ type: "text", text: "Stopped before it finished." }] });
    }
  } else if (m.method === "ui/notifications/host-context-changed") {
    context(p);
  }
});

ask("ui/initialize", { protocolVersion: PROTOCOL, appInfo: { name: "brickworks-model", version: "2" },
  appCapabilities: { availableDisplayModes: ["inline", "fullscreen"] } }, 20000)
  .then((result) => {
    host.capabilities = (result && result.hostCapabilities) || {};
    card.host = result && result.hostInfo;
    context(result && result.hostContext);
  })
  .catch(() => {})
  .then(() => {
    tell("ui/notifications/initialized");
    measure();
    if (!shown) waitForResult(4000);
  });
