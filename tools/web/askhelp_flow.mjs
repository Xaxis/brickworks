// Ask the builders (docs/PLAN.md row 3, docs/SOCIAL.md section 12,
// supabase/talk_asks.sql, api/_asks.js, web/talk.js), in real browsers and
// through the API, with throwaway accounts at Resend test addresses, deleted
// at the end with their model: Ann asks about step 2 of her model, Bea
// answers on a part, Dee is blocked, Kit said under 13.
//
// The studio's half (Ask in Talk in the Share panel, answers lit in the
// open studio) is src/dev/askhelp_probe.gd; this is the server and the
// thread's page, and the studio's ask for answers (op=talk_asks) as Ann's
// studio sends it.
//
// On this machine, over Talk's stand-in (tools/web/talk_stand_in.mjs says how):
//
//   node --env-file=$SCRATCH/relay.env tools/web/askhelp_flow.mjs --url=http://127.0.0.1:11770 --out=DIR
//
// On a preview once talk_asks.sql is applied:
//
//   BW_BYPASS=$VERCEL_BYPASS node --env-file=$SCRATCH/flow.env tools/web/askhelp_flow.mjs --url=<preview> --out=DIR
//
//   1. Ann shares a three-step model (its steps carried, as the app writes
//      them) and asks about step 2 with two parts picked: a Help thread; a
//      part not in the model, somebody else's model and Kit (under 13) are
//      refused in words.
//   2. Signed out, at 1280 and 390: the thread shows the ask, its 3D opens
//      at step 2 (4 of the 6 parts, the scene says drawn at that step) with
//      the two asked parts lit; nothing goes sideways.
//   3. Bea, signed in, opens the 3D, right-clicks a part, chooses Answer on
//      this part: the reply box says which part; posted, the post says "On
//      the …" and its dot is on the part.
//   4. Ann's studio asks for answers (op=talk_asks): Bea's is there on its
//      part, seconds after it was posted (the bar: within 60 s).
//   5. Blocks and reports hold: Ann blocks Dee, whose answer on a part is
//      refused; Ann blocks Bea, whose answer leaves Ann's studio's list;
//      Cy's report of a pinned answer is taken.
//
// Prints "askhelp: all ok".
import { launch } from "./browser.mjs";
import { answerAge, deleteAccount, mintSession, STORAGE_KEY } from "./session.mjs";
import { mkdirSync, readFileSync } from "node:fs";
import { createHash, randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { fingerprint } from "../../api/_versions.js";

const args = Object.fromEntries(process.argv.slice(2).map((a) => {
  const [k, ...rest] = a.replace(/^--/, "").split("=");
  return [k, rest.join("=") || true];
}));
if (!args.url) {
  console.error("askhelp_flow: --url=<deployment>");
  process.exit(2);
}
const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, "../..");
const site = String(args.url).replace(/\/+$/, "").replace(/\/app$/, "");
if (/^(?:www\.)?brickworks\.diy$/.test(new URL(site).host)) {
  console.error("askhelp_flow: never on brickworks.diy");
  process.exit(2);
}
const out = path.resolve(String(args.out || "shots/askhelp"));
mkdirSync(out, { recursive: true });
const bypass = process.env.BW_BYPASS || "";
const headers = bypass ? { "x-vercel-protection-bypass": bypass, "x-vercel-skip-toolbar": "1" } : {};
const rand = randomBytes(4).toString("hex");
const WHO = ["ann", "bea", "cy", "dee", "kit"];
const emails = Object.fromEntries(WHO.map((who) => [who, `delivered+bw-ask-${who}-${rand}@resend.dev`]));
const handles = Object.fromEntries(WHO.map((who) => [who, `ak-${who}-${rand}`]));
const names = { ann: "Ann Ask", bea: "Bea Ask", cy: "Cy Ask", dee: "Dee Ask", kit: "Kit Ask" };

let failed = 0;
const check = (what, ok) => {
  console.log(`  ${ok ? "ok  " : "FAIL"}  ${what}`);
  if (!ok) failed += 1;
  return ok;
};
const errors = [];
const picture = readFileSync(path.join(root, "web/share.png")).toString("base64");

// Three steps of two bricks, with the steps the app carries (SharedPages):
// its head names this very text and the parts in the order they go down.
const BRICKS = [
  ["3001", 4, 0, 0, 0], ["3001", 4, 0, 0, 40],
  ["3003", 15, -20, -24, 0], ["3003", 1, 20, -24, 40],
  ["3004", 14, 0, -48, 0], ["3004", 2, 0, -48, 40],
];
const lines = [`0 Ask windmill ${rand}`, "0 Name: ask.ldr"];
BRICKS.forEach(([part, colour, x, y, z], i) => {
  lines.push(`1 ${colour} ${x} ${y} ${z} 1 0 0 0 1 0 0 0 1 ${part}.dat`);
  if (i % 2 === 1) lines.push("0 STEP");
});
const bare = `${lines.join("\r\n")}\r\n`;
const order = createHash("sha256").update(BRICKS.map(([part, colour]) => `${part}:${colour}`).join("|"), "utf8").digest("hex");
const ldraw = `${bare}0 !BRICKWORKS PAGES ${JSON.stringify({ v: 1, model: fingerprint(bare), order, parts: 6, mode: 0, steps: 3 })}\r\n`
  + [0, 1, 2].map((i) => `0 !BRICKWORKS PAGE ${JSON.stringify({ i, n: i + 1, b: [i * 2, i * 2 + 1] })}`).join("\r\n") + "\r\n";
const at = (i) => ({ part: BRICKS[i][0], colour: BRICKS[i][1], at: BRICKS[i].slice(2) });

async function api(pathname, { method = "GET", token, body } = {}) {
  const sent = { ...headers };
  if (token) sent.authorization = `Bearer ${token}`;
  if (body !== undefined) sent["content-type"] = "application/json";
  const reply = await fetch(`${site}${pathname}`, { method, headers: sent, body: body === undefined ? undefined : JSON.stringify(body) });
  const text = await reply.text();
  let parsed = {};
  try {
    parsed = JSON.parse(text);
  } catch {
    parsed = {};
  }
  return { status: reply.status, body: parsed, text };
}

const browser = await launch({ signedOut: true });
const shot = (page, name) => page.screenshot({ path: path.join(out, name), timeout: 90000 })
  .catch((trouble) => console.log(`  --    no picture ${name}: ${String(trouble).split("\n")[0]}`));
const sideways = (page) => page.evaluate(() => document.documentElement.scrollWidth > document.documentElement.clientWidth + 1);

async function open(pathname, { who = null, phone = false } = {}) {
  const context = await browser.newContext({ viewport: phone ? { width: 390, height: 844 } : { width: 1280, height: 800 },
    extraHTTPHeaders: headers, ...(phone ? { deviceScaleFactor: 2, isMobile: true, hasTouch: true } : {}) });
  if (who) {
    await context.addInitScript(([name, value]) => {
      try { if (!localStorage.getItem(name)) localStorage.setItem(name, value); } catch {}
    }, [STORAGE_KEY, JSON.stringify(who.kept)]);
  }
  const page = await context.newPage();
  page.on("pageerror", (e) => errors.push(`${pathname}: ${String(e).slice(0, 200)}`));
  page.on("console", (m) => {
    if (/SCRIPT ERROR|Content Security Policy|Refused to/.test(m.text())) errors.push(`${pathname}: ${m.text().slice(0, 220)}`);
  });
  await page.goto(`${site}${pathname}`, { waitUntil: "domcontentloaded", timeout: 120000 });
  return page;
}

async function until(page, test, what, seconds = 30, arg = null) {
  const end = Date.now() + seconds * 1000;
  for (;;) {
    const value = await page.evaluate(test, arg).catch(() => null);
    if (value) return value;
    if (Date.now() > end) throw new Error(`${what}: not within ${seconds} s`);
    await page.waitForTimeout(300);
  }
}

/// The thread's 3D opened by a press on its picture, every part in.
async function open3d(page, phone) {
  await page.evaluate(() => document.querySelector(".talk-ask .picture").scrollIntoView({ block: "center" }));
  if (phone) await page.tap(".talk-ask .picture");
  else await page.click(".talk-ask .picture");
  return until(page, () => (window.brickworks3d?.state === "ready" && window.brickworks3d.view && window.brickworks3d.pins
    && Array.isArray(window.brickworks3d.pins.asked)
    ? { n: window.brickworks3d.view.d.n, asked: window.brickworks3d.pins.asked.length, dots: window.brickworks3d.pins.dots.length,
      lit: [...new Set(window.brickworks3d.pins.asked)].map((i) => {
        const d = window.brickworks3d.view.d;
        return `${d.meshes[d.mesh[i]].part}:${d.colours[d.colour[i]].code}`;
      }).sort().join(" ") } : null),
  "the ask's 3D", 180);
}

const people = {};
let modelId = "";
let threadId = 0;
let threadPath = "";
try {
  console.log("1. Ann shares a three-step model and asks about step 2");
  for (const who of WHO) {
    people[who] = await mintSession(emails[who], { age: who !== "kit" });
    if (who === "kit") {
      await answerAge(people.kit.kept.user_id, emails.kit, false);
      continue;
    }
    const profile = await api("/api/people?op=profile", { method: "POST", token: people[who].access_token,
      body: { handle: handles[who], name: names[who] } });
    check(`${names[who]} @${handles[who]}: ${profile.status}`, profile.status === 200);
  }
  const shared = await api("/api/share", { method: "POST", token: people.ann.access_token,
    body: { name: `Ask windmill ${rand}`, author: names.ann, model: ldraw, image: picture, listed: false } });
  modelId = shared.body.id || "";
  check(`Ann's windmill /m/${modelId}, shared by its link: ${shared.status}`, shared.status === 201 && /^[A-Za-z0-9]{10}$/.test(modelId));
  const whole = await api(`/m/${modelId}/scene.json`);
  const step2 = await api(`/m/${modelId}/scene.json?step=2`);
  check(`its scene at step 2 is the parts built by then: ${step2.body.count} of ${whole.body.count}, drawn at the step ${JSON.stringify(step2.body.at_step)}`,
    whole.body.count === 6 && step2.body.count === 4 && step2.body.at_step?.drawn === true);
  const asked = await api("/api/people?op=talk_ask&tests=1", { method: "POST", token: people.ann.access_token,
    body: { model: modelId, step: 2, parts: [at(2), at(3)], title: "How do I brace the sails at step 2?",
      body: `The two 2 x 2 bricks at step 2 wobble. How would you brace them? (askhelp flow ${rand})` } });
  threadId = Number(asked.body.thread?.id) || 0;
  threadPath = asked.body.path || "";
  check(`asked: ${asked.status}, a Help thread ${threadPath}, version ${asked.body.ask?.version}, step ${asked.body.ask?.step}, `
    + `${asked.body.ask?.parts?.length} parts named "${asked.body.ask?.parts?.map((one) => one.name).join(", ")}"`,
  asked.status === 201 && threadId > 0 && asked.body.thread?.board === "help" && asked.body.ask?.step === 2
    && asked.body.ask?.parts?.length === 2 && asked.body.ask.parts.every((one) => /Brick\s+2\s*x\s*2/i.test(one.name || "")));
  const notThere = await api("/api/people?op=talk_ask&tests=1", { method: "POST", token: people.ann.access_token,
    body: { model: modelId, step: 2, parts: [{ part: "3001", colour: 4, at: [500, 0, 0] }], title: "Not there", body: "A part nowhere" } });
  check(`a part not in the model is refused: ${notThere.status} "${notThere.body.error}"`, notThere.status === 409 && /not in that version/.test(notThere.body.error || ""));
  const notHers = await api("/api/people?op=talk_ask&tests=1", { method: "POST", token: people.bea.access_token,
    body: { model: modelId, step: 2, title: "Not my model", body: "Asked about Ann's" } });
  check(`Bea cannot ask about Ann's model: ${notHers.status} "${notHers.body.error}"`, notHers.status === 403 && /your own shared models/.test(notHers.body.error || ""));
  const kit = await api("/api/people?op=talk_ask&tests=1", { method: "POST", token: people.kit.access_token,
    body: { model: modelId, step: 2, title: "Under thirteen", body: "Kit asks" } });
  check(`Kit, who said under 13, cannot: ${kit.status} "${kit.body.error}"`, kit.status === 422 && /13 and over/.test(kit.body.error || ""));

  console.log("2. Signed out, the thread shows the ask, and its 3D opens at step 2 with the asked parts lit");
  for (const phone of [false, true]) {
    const size = phone ? "390" : "1280";
    const visitor = await open(`${threadPath}?tests=1`, { phone });
    const card = await until(visitor, () => {
      const ask = document.querySelector(".talk-ask");
      return ask ? { go: ask.querySelector(".go")?.textContent.trim(), parts: [...ask.querySelectorAll("[data-ask-part]")].map((one) => one.textContent.trim()).join(", "),
        where: ask.querySelector(".talk-ask-where a")?.textContent.trim() } : null;
    }, "the ask on its thread", 30);
    check(`${size}: "${card.go}", "${card.where}", the parts "${card.parts}"`, /step 2/i.test(card.go)
      && card.parts === "White 2 × 2 brick, Blue 2 × 2 brick" && /Step 2/.test(card.where));
    const still = await until(visitor, () => {
      const img = document.querySelector(".talk-ask .picture img");
      return img && img.complete && img.naturalWidth > 0;
    }, "its picture", 20).catch(() => false);
    check(`${size}: its picture shows before the 3D`, still);
    await visitor.evaluate(() => scrollTo(0, 0));
    await shot(visitor, `thread_${size}.png`);
    const view = await open3d(visitor, phone);
    check(`${size}: the 3D at step 2: ${view.n} parts drawn, the asked parts lit: ${view.lit}`, view.n === 4 && view.lit === "3003:1 3003:15");
    // Its first view: every corner of every part of the step in the frame,
    // about 8% clear on each side (0.84 of the frame's half each way).
    const framed = await visitor.evaluate(() => {
      const v = window.brickworks3d.view;
      const at = v.camera.position.clone();
      let most = 0;
      for (let i = 0; i < v.corners.length; i += 3) {
        at.set(v.corners[i], v.corners[i + 1], v.corners[i + 2]).project(v.camera);
        most = Math.max(most, Math.abs(at.x), Math.abs(at.y));
      }
      return { most: Math.round(most * 1000) / 1000, corners: v.corners.length / 3 };
    });
    check(`${size}: its first view holds the whole step, ${(((1 - framed.most) / 2) * 100).toFixed(1)}% clear at the nearest edge`
      + ` (${framed.corners} corners)`, framed.corners === 32 && framed.most <= 0.85 && framed.most >= 0.6);
    await visitor.waitForTimeout(600);
    await shot(visitor, `thread_3d_${size}.png`);
    check(`${size}: nothing goes sideways`, !(await sideways(visitor)));
    await visitor.context().close();
  }

  console.log("3. Bea answers on a part from the 3D");
  const bea = await open(`${threadPath}?tests=1`, { who: people.bea });
  await until(bea, () => document.querySelector("[data-reply-form]") && !document.querySelector("[data-reply-form]").hidden, "Bea's reply box", 45);
  await open3d(bea, false);
  // The white 2 x 2 brick of step 2 (index 2 of the scene, as the file lays it).
  const aim = await bea.evaluate(() => {
    const s = window.brickworks3d;
    const v = s.view;
    const d = v.d;
    for (let i = 0; i < d.n; i++) {
      const at = v.onPage(v.centreOf(i));
      if (!at || document.elementFromPoint(at.x, at.y)?.localName !== "canvas") continue;
      const j = s.pickAt(at.x, at.y);
      if (j >= 0 && d.meshes[d.mesh[j]].part === "3003" && d.colours[d.colour[j]].code === 15) return { x: at.x, y: at.y };
    }
    return null;
  });
  check(`the white 2 x 2 brick is on the screen to press: ${JSON.stringify(aim)}`, Boolean(aim));
  if (aim) {
    await bea.mouse.move(aim.x, aim.y);
    await bea.mouse.down({ button: "right" });
    await bea.mouse.up({ button: "right" });
    const menu = await until(bea, () => (window.brickworks3d.pins.menu === "open"
      ? document.querySelector(".view3d-menu [role=menuitem]")?.textContent.trim() : null), "the part's menu", 5).catch(() => "");
    check(`its menu says "${menu}"`, menu === "Answer on this part");
    await bea.click(".view3d-menu [role=menuitem]");
    const chip = await until(bea, () => {
      const line = document.querySelector("[data-on-part]");
      return line && !line.hidden ? line.querySelector("span").textContent : null;
    }, "the reply box on the part", 10).catch(() => "");
    check(`the reply box says "${chip}"`, /2 × 2 brick/.test(chip));
    await bea.fill("#talk-reply-words", `Put a 1 x 2 plate under it, across both. (askhelp flow ${rand})`);
    await shot(bea, "answer_on_part_1280.png");
    const posted = Date.now();
    await bea.click("[data-reply-form] button[type=submit]");
    const line = await until(bea, () => [...document.querySelectorAll("#talk-posts .talk-post.on-part .talk-on-part")]
      .map((one) => one.textContent.trim())[0] || null, "Bea's answer on its part", 30).catch(() => "");
    check(`her answer says "${line}"`, /On the 2 × 2 brick/.test(line));
    const dots = await until(bea, () => (window.brickworks3d.pins.dots.length ? window.brickworks3d.pins.dots.length : null), "its dot", 10).catch(() => 0);
    check(`its dot is on the part in the 3D: ${dots}`, dots === 1);
    await bea.evaluate(() => document.querySelector(".talk-ask").scrollIntoView({ block: "start" }));
    await shot(bea, "answered_1280.png");

    console.log("4. Ann's studio asks for answers: Bea's is there on its part");
    const studio = await api(`/api/people?op=talk_asks&model=${modelId}`, { token: people.ann.access_token });
    const seen = (Date.now() - posted) / 1000;
    const answer = studio.body.asks?.[0]?.answers?.[0];
    check(`talk_asks: ${studio.status}, every ${studio.body.every} s, ${studio.body.asks?.length} ask, its answer by ${answer?.by} on ${answer?.pin?.part}`
      + ` colour ${answer?.pin?.colour}, ${seen.toFixed(1)} s after it was posted`, studio.status === 200 && studio.body.every <= 30
      && answer?.pin?.part === "3003" && answer.pin.colour === 15 && seen + Number(studio.body.every) <= 60);
    const others = await api(`/api/people?op=talk_asks&model=${modelId}`, { token: people.bea.access_token });
    check(`Bea cannot read Ann's studio's list: ${others.status}`, others.status === 403);
  }
  await bea.context().close();

  console.log("5. Blocks and reports hold");
  const blocked = await api("/api/people?op=block", { method: "POST", token: people.ann.access_token, body: { handle: handles.dee, on: true } });
  check(`Ann blocks Dee: ${blocked.status}`, blocked.status === 200);
  const deeSays = await api("/api/people?op=talk_reply&tests=1", { method: "POST", token: people.dee.access_token,
    body: { thread: threadId, body: "Blocked answer", part: at(2) } });
  check(`Dee's answer on a part is refused: ${deeSays.status} "${deeSays.body.error}"`, deeSays.status === 403 && /cannot post here/.test(deeSays.body.error || ""));
  const posts = (await api(`/api/people?op=talk_thread&id=${threadId}&tests=1`)).body.posts || [];
  const pinned = posts.find((one) => one.pin);
  const report = await api("/api/people?op=report", { method: "POST", token: people.cy.access_token,
    body: { post: Number(pinned?.id), reason: "spam" } });
  check(`Cy reports Bea's answer on a part: ${report.status}`, report.status === 200 || report.status === 201);
  await api("/api/people?op=block", { method: "POST", token: people.ann.access_token, body: { handle: handles.bea, on: true } });
  const after = await api(`/api/people?op=talk_asks&model=${modelId}`, { token: people.ann.access_token });
  check(`Ann blocks Bea: her answer leaves Ann's studio's list (${after.body.asks?.[0]?.answers?.length} left)`,
    after.status === 200 && after.body.asks?.[0]?.answers?.length === 0);
} catch (trouble) {
  check(`ran to the end: ${String(trouble?.message || trouble).split("\n")[0]}`, false);
} finally {
  await browser.close().catch(() => {});
  if (modelId && people.ann) await api(`/api/share?op=unpublish&id=${modelId}`, { method: "POST", token: people.ann.access_token }).catch(() => {});
  for (const email of Object.values(emails)) await deleteAccount(email).catch(() => {});
}
for (const error of errors) console.log(`  page: ${error}`);
check("no page errors", errors.length === 0);
console.log(failed ? `${failed} FAILED` : "askhelp: all ok");
process.exit(failed ? 1 : 0);
