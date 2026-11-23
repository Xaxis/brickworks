// Ask the builders, from the studio (2026-11-23, unit askhelp; docs/PLAN.md
// row 3, docs/SOCIAL.md section 12, supabase/talk_asks.sql). api/_talk.js
// answers the requests with these:
//
//   POST ?op=talk_ask       (session) {model, version?, step?, parts?, title,
//                           body}: a Help thread in Talk about the open step
//                           of one of the caller's shared models: the
//                           version (its newest if none), the step (null:
//                           the whole model) and the parts picked, at most
//                           12, each found in that version's own file and
//                           kept as a pin keeps its part
//   POST ?op=talk_reply     with part {part, colour, at, turn?}: in an ask's
//                           thread, the reply is on that part of the asked
//                           version, found in its file as a pin is
//   GET  ?op=talk_asks&model=X   (session, the model's owner) its asks and
//                           their answers on parts, as the owner may see
//                           them, for the studio, which asks again every
//                           ASK_EVERY_S while the model is open
//
// A thread's page (GET ?op=talk_page&thread=N, ?op=talk_thread) carries its
// ask and each post's part, and draws the model in 3D at the asked step
// (/m/X/v/N/scene.json?step=S, api/_parts.js stepParts), the asked parts
// lit, each answer numbered on its part. Talk's rules are Talk's own: every
// write goes through talk_start and talk_reply (talk_asks.sql).
//
// Until talk_asks.sql is applied asksReady() is false: nothing reads the
// columns, an ask is refused in words and a part sent with a reply too.

import { db } from "./_db.js";
import { escapeHtml, Unacceptable, asText } from "./_directory.js";
import { cleanPart, pinFrom, pinShown, placesFor, versionsOf } from "./_comments.js";
import { langAt, number, partSaid, say } from "./_card.js";
import { COLOUR_NAMES } from "./_colours.js";

const NOT_THERE = /: 404$/;
const READY_MS = 5 * 60 * 1000;
export const MOST_PARTS = 12;
/// How often the studio asks for answers while a model with an ask is open.
export const ASK_EVERY_S = 20;
export const NOT_YET = "Asking the builders is not open on Brickworks yet: start a thread in Help and paste your model's link.";

// What talk_asks.sql's own refusals say (Talk's are api/_talk.js WORDS).
export const ASK_WORDS = {
  model: [403, "You can ask about one of your own shared models: publish it first."],
  no_version: [404, "That version of the model is not there any more."],
  step: [400, "step is a step's number, from 1, or none for the whole model."],
  parts: [400, "Pick at most 12 parts to ask about."],
  no_part: [409, "That part is not in that version of the model: publish it again and ask."],
  not_ask: [409, "Answers on a part are for a thread asked from the studio."],
  pin: [400, "Press a part of the model in 3D to answer on it."],
};

export function askRefused(code) {
  const [status, words] = ASK_WORDS[code] || [400, "That could not be done."];
  return new Unacceptable(words, status);
}

let readiness = { at: -Infinity, yes: false };

/// Whether supabase/talk_asks.sql is applied here: its functions answer.
/// Asked once in READY_MS by each function; the database unreachable is
/// asked again in half a minute.
export async function asksReady(now = Date.now()) {
  if (now - readiness.at < READY_MS) return readiness.yes;
  let yes = false;
  let kept = now;
  try {
    await db("rpc/talk_asks_of", { method: "POST", body: { thread_ids: [] }, seconds: 5 });
    yes = true;
  } catch (trouble) {
    if (!NOT_THERE.test(String(trouble?.message || ""))) kept = now - READY_MS + 30000;
  }
  readiness = { at: kept, yes };
  return yes;
}

/// For tests: forget what was found.
export function forgetReadiness() {
  readiness = { at: -Infinity, yes: false };
}

/// A kept part as a page gets it: pinShown's, with the name it was asked
/// or answered on (the catalogue's, kept with it). Null for none.
export function partShown(kept) {
  const shown = pinShown(kept);
  if (!shown) return null;
  const name = typeof kept.name === "string" ? kept.name.replace(/[\u0000-\u001f\u007f]+/g, " ").trim().slice(0, 120) : "";
  return name ? { ...shown, name } : shown;
}

/// An ask as a page gets it (talk_ask_as's), read at this edge: {model,
/// version, step, parts, name, has_image, newest}, or null.
export function askShown(given) {
  if (!given || typeof given !== "object" || !Number.isInteger(Number(given.version))) return null;
  const model = /^[A-Za-z0-9]{10}$/.test(String(given.model || "")) ? String(given.model) : null;
  const step = Number.isInteger(given.step) && given.step > 0 ? given.step : null;
  return { model, version: Number(given.version), step, name: model ? String(given.name || "") : "",
    has_image: given.has_image === true, newest: Number.isInteger(given.newest) ? given.newest : null,
    parts: (Array.isArray(given.parts) ? given.parts : []).map(partShown).filter(Boolean).slice(0, MOST_PARTS) };
}

/// The name of part [part] in the catalogue, "" for one it does not know.
async function nameOf(part) {
  const { partsTable } = await import("./_parts.js");
  const row = partsTable()?.parts?.[part];
  return Array.isArray(row) && typeof row[0] === "string" ? row[0].slice(0, 120) : "";
}

/// The parts [given] says were pressed on version [version] of [model],
/// each found in that version's file (api/_comments.js pinFrom) and named:
/// [place] or a refusal. [given] null or empty: none.
export async function placesAsked(model, version, given) {
  if (given === undefined || given === null) return [];
  if (!Array.isArray(given) || given.length > MOST_PARTS) throw askRefused("parts");
  if (!given.length) return [];
  const cleaned = given.map((one) => cleanPart(one));
  const wrong = cleaned.find((one) => one.trouble);
  if (wrong) throw new Unacceptable(wrong.trouble);
  const versions = await versionsOf(model);
  let places = await placesFor(model, version, versions[0].n);
  if (places === null) {
    const again = await versionsOf(model);
    places = again.some((one) => one.n === version) ? await placesFor(model, version, again[0].n) : null;
  }
  if (places === null) throw askRefused("no_version");
  const out = [];
  for (const { part } of cleaned) {
    const pin = pinFrom(places, part);
    if (!pin) throw askRefused("no_part");
    out.push({ ...pin, name: await nameOf(pin.part) });
  }
  return out;
}

/// The ask of thread [id] (talk_asks_of's), or null: none, or the file not
/// applied.
export async function askOf(id) {
  if (!(await asksReady())) return null;
  const rows = await db("rpc/talk_asks_of", { method: "POST", body: { thread_ids: [id] } });
  const row = (Array.isArray(rows) ? rows : []).find((one) => Number(one?.thread) === Number(id));
  return row ? askShown(row.ask) : null;
}

/// [page] (talk_thread_page's) with its thread's ask and each post's part,
/// in place; as it was before talk_asks.sql, or when they cannot be read
/// (the page is drawn without them, never refused).
export async function withAsks(page) {
  if (!page?.thread || !(await asksReady())) return page;
  try {
    const posts = page.posts || [];
    const [asks, pins] = await Promise.all([
      db("rpc/talk_asks_of", { method: "POST", body: { thread_ids: [Number(page.thread.id)] } }),
      posts.length ? db("rpc/talk_pins_of", { method: "POST", body: { post_ids: posts.map((one) => Number(one.id)) } }) : [],
    ]);
    const ask = (Array.isArray(asks) ? asks : []).find((one) => Number(one?.thread) === Number(page.thread.id));
    if (ask) page.thread.ask = askShown(ask.ask);
    const onPart = new Map((Array.isArray(pins) ? pins : []).map((one) => [Number(one.post), partShown(one.pin)]));
    for (const post of posts) {
      const pin = onPart.get(Number(post.id));
      if (pin) post.pin = pin;
    }
  } catch (trouble) {
    console.error(`asks: ${String(trouble?.message || trouble).slice(0, 160)}`);
  }
  return page;
}

/// The asks of model [model] and their answers on parts, as [viewer] (its
/// owner) may see them: [{thread, title, at, last_at, locked, path, ask,
/// answers: [{id, body, at, by, handle, pin}]}], or null for somebody
/// else's model.
export async function asksOn(model, viewer) {
  const rows = await db("rpc/talk_asks_on", { method: "POST", body: { p_model: model, viewer } });
  if (rows === null) return null;
  return (Array.isArray(rows) ? rows : []).map((one) => ({
    thread: Number(one.thread), title: String(one.title || ""), at: one.at, last_at: one.last_at, locked: one.locked === true,
    path: `/talk/t/${Number(one.thread)}`, ask: askShown(one.ask),
    answers: (Array.isArray(one.answers) ? one.answers : []).map((post) => ({
      id: Number(post.id), body: String(post.body || ""), at: post.at, edited_at: post.edited_at ?? null,
      by: post.by || null, handle: post.handle || null, mine: post.mine === true, by_starter: post.by_starter === true,
      pin: partShown(post.pin) })).filter((post) => post.pin),
  }));
}

/// The address of [ask]'s scene: the asked version at the asked step.
export function askScene(ask) {
  if (!ask?.model) return "";
  const at = ask.newest && ask.version === ask.newest ? `/m/${ask.model}` : `/m/${ask.model}/v/${ask.version}`;
  return `${at}/scene.json${ask.step ? `?step=${ask.step}` : ""}`;
}

/// A part as a thread says it: "2 × 4 brick" (web/card.js partSaid), ""
/// for a part not named.
export const partWords = (part) => partSaid(part?.name ?? "");
// An asked part's chip: its colour too, as LDraw names it, so two parts of
// one shape (a white and a blue 2 x 2 brick) read apart.
const chipWords = (part) => {
  const colour = Number(part?.colour) === 16 ? "" : COLOUR_NAMES[Number(part?.colour)] || "";
  const words = partWords(part);
  return words ? `${colour} ${words}`.trim() : say("a part");
};

/// The asked model's own picture, as the app drew it when it published that
/// version (its newest's, or the asked older version's): the ask's poster
/// and its thread's link preview. "" when it has none: then a plain frame,
/// never the site's share card.
export function askPicture(ask) {
  if (!ask?.model || !ask.has_image) return "";
  return ask.newest && ask.version !== ask.newest ? `/m/${ask.model}/v/${ask.version}.png` : `/m/${ask.model}.png`;
}

/// The ask at the top of its thread: the model in 3D at the asked step (its
/// picture first, the 3D view on a press, web/talk.js), what was asked
/// about, and the way into the viewer at that step. "" for none.
export function askHtml(ask) {
  if (!ask) return "";
  const at = langAt();
  if (!ask.model) {
    return `<section class="talk-ask gone" data-ask><p class="note">${asText(say("This was asked about a model that is not shared any more."))}</p></section>`;
  }
  const page = `${at}/m/${ask.model}${ask.newest && ask.version !== ask.newest ? `/v/${ask.version}` : ""}`;
  const picture = askPicture(ask);
  const viewer = `/app?view=${ask.model}${ask.step ? `&step=${ask.step}` : ""}`;
  const where = ask.step ? say("Step {step} of {name}, version {version}", { step: number(ask.step), name: ask.name, version: number(ask.version) })
    : say("{name}, version {version}", { name: ask.name, version: number(ask.version) });
  const parts = ask.parts.map((part, i) => `<li><button type="button" class="pill" data-ask-part="${i}">`
    + `${escapeHtml(chipWords(part))}</button></li>`).join("");
  return `<section class="talk-ask" data-ask data-model="${ask.model}" data-version="${ask.version}"${ask.step ? ` data-step="${ask.step}"` : ""}>
<div class="talk-ask-frame"><a class="picture" href="${viewer}" data-scene="${escapeHtml(askScene(ask))}" aria-label="${asText(say("View {name} in 3D", { name: ask.name }))}">`
    + `${picture ? `<img src="${escapeHtml(picture)}" alt="" width="1200" height="630">` : ""}`
    + `<span class="go">${asText(ask.step ? say("See step {step} in 3D", { step: number(ask.step) }) : say("See it in 3D"))}</span></a></div>
<div class="talk-ask-about"><p class="talk-ask-where"><small>${asText(say("Asked from the studio"))}</small> <a href="${page}">${escapeHtml(where)}</a></p>
${parts ? `<p class="note">${asText(say("The parts asked about, lit in 3D:"))}</p><ul class="talk-ask-parts">${parts}</ul>` : ""}
<p class="note">${asText(say("Answer on a part: open the 3D, then right-click a part, or touch and hold it."))}</p>
<p><a class="cta ghost small" href="${viewer}">${asText(ask.step ? say("Open step {step} in the viewer", { step: number(ask.step) }) : say("Open it in the viewer"))}</a></p></div>
</section>`;
}

/// The line over an answer on a part: "On the 2 × 4 brick", a button that
/// turns the thread's 3D to it. "" for a post on no part.
export function pinLineHtml(post) {
  if (!post?.pin) return "";
  const part = partWords(post.pin);
  return `<p class="talk-on-part"><button type="button" class="link" data-act="show-part" data-pin="${Number(post.id)}">`
    + `<span class="view3d-pin" aria-hidden="true"></span>${asText(part ? say("On the {part}", { part }) : say("On a part"))}</button></p>`;
}
