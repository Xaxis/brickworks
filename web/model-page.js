// A shared model's page, /m/<id> (the directory, 2026-10-13): its action
// bar (2026-10-22, docs/SOCIAL.md U4): Like, Save (Saved and your lists:
// web/keep.js's, the card's, lists2a), Share, Comment, I built it and More,
// Like and Save asking to sign in first when this browser is not
// (web/account.js), each a call to /api/people. What the page shows
// without it — the counts, the way into the viewer — needs none of this.
//
// Every name shown here (a list's, a person's) is put on the page as text.
//
// And its comments (2026-10-18, api/_comments.js), as threads (2026-10-22,
// docs/SOCIAL.md U8): the newest comment first and its replies under it,
// oldest first; each with its writer's avatar, Designer on the model's
// owner's, and its step as a pill that opens the viewer there (an older
// version's step, that version's viewer). The box is everybody's, with a
// step picker: a visitor signs in as they send, and what they wrote is
// kept; somebody who may not write is told why, politely. Reply under each
// comment, Report on each, Remove on one's own, Hide and Show on each and
// comments off or on for the model's owner, replies as comments. What a
// stranger wrote is set as text, never as markup, and a link in it stays
// words; an @handle the server told (docs/SOCIAL.md section 7, item 6) is
// a link to that profile, and typing @ in a box offers the people on the
// page (pickMentions).
//
// And comments on a part (partpins, 2026-11-23, supabase/comment_pins.sql):
// where the comments say pins can be written, a part pressed in the 3D view
// (its menu's Comment on this part) puts "On the 2 × 4 brick" over the box,
// with Cancel, and the comment sent is a pin on it. Each pin says the part
// and step it is on as a button that opens the 3D view and turns it there,
// numbered oldest first, as its dot and the studio's list number it; on
// this version where the 3D view placed it (web/card.js pinPlace), "moved
// since" where its part moved, and "on version N", pressable no more, where
// it is on no part of this one. A pin its designer resolved is folded away
// under Resolved; its designer may resolve one here too.
import { askToSignIn, call, email, nameFirst, signedIn } from "/account.js";
import { openReport } from "/report.js";
import { blockPerson } from "/block.js";
import { ask, avatarHtml } from "/kit.js";
import { makeComposer, wireComposer } from "/composer.js";
import { HOWS, basedHtml, brokenSaid, counted, langAt, mentionPieces, number, photoSrc, pinPart, pinSaid, rulesSaid, say, setPhoto,
  sharpPhotos, themeSaid, told } from "/card.js";
import { copy, wireShare } from "/share-sheet.js";
// Save and your lists, as on every card (api/share.js actionBar, lists2a).
import "/keep.js";
import { start3d } from "/start3d.js";
import { guardPhoneOpens } from "/phone-warn.js";
import { startTabs } from "/tabs.js";

// A date as the page's language writes one: "30 October 2026".
const LOCALE = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? globalThis.brickworksLang.code : "en-GB";

/// [said], a sentence in the page's language (web/card.js say), into
/// [into]: each {name} in it [parts]'s element or words.
function sayInto(into, said, parts) {
  for (const piece of said.split(/(\{\w+\})/)) {
    const name = /^\{(\w+)\}$/.exec(piece)?.[1];
    if (piece) into.append(name && name in parts ? parts[name] : piece);
  }
}

// The comments' own loader, once they are listed (startComments), for
// Comment in the action bar to list them again after signing in.
let commentsLoaded = null;
const marks = document.getElementById("marks");
const id = marks && marks.dataset.id;
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "")) start();
// A set of the LDraw library (/library/<id>, api/_library.js): its bar is
// Share and More alone, there being nothing of it to like, save or build.
else if (marks && /^[a-z]{2,8}-[A-Za-z0-9_-]{1,120}$/.test(id || "")) {
  const sheet = document.getElementById("share-sheet");
  const share = marks.querySelector("[data-share]");
  if (sheet && share) wireShare(share, sheet);
}
// This month's challenge (supabase/challenges.sql), for the model's own
// designer: Enter this month's challenge, or that it is in.
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "") && signedIn()) challengeEntry();
// Post it elsewhere (unit postkit, web/post-kit.js), for the model's own
// designer, known from the answer basesOwn has: Share's sheet offers a kit
// for each place it is posted to, made in this browser. Nobody else loads
// any of it.
let kitsShown = false;
function postKitsOwn() {
  const sheet = document.getElementById("share-sheet");
  const facts = document.getElementById("post-facts");
  if (kitsShown || !sheet || !facts || !sheet.querySelector("#post-kits")) return;
  kitsShown = true;
  let read = null;
  try {
    read = JSON.parse(facts.textContent);
  } catch {
    return;
  }
  // How it was made, as its app said, which the page itself says only
  // where its designer chose to (api/share.js ?op=made): the designer's own
  // kit still knows, so a place that takes no AI-made models is said so.
  call(`/api/share?op=made&id=${id}`).then((answer) => {
    if (answer.status === 200 && answer.body.way) Object.assign(read, { made: answer.body.way, maker: answer.body.by });
  }, () => {});
  import("/post-kit.js").then((kit) => {
    kit.startPostKits(sheet, { facts: read, parts: pageParts ? () => pageParts() : null });
    document.documentElement.dataset.postKits = "shown";
  }, () => { kitsShown = false; });
}

// What it is based on (api/_bases.js), for the model's own designer: Say
// what it is based on, or Change it, in a dialog of at most three; the
// page's lines drawn again from what was kept. <html data-bases> says how
// many its designer's page shows, "not-open" before model_bases.sql
// (tools/web/based_on_flow.mjs reads it).
if (marks && /^[A-Za-z0-9]{10}$/.test(id || "") && signedIn()) basesOwn();
// Signed in on the page (signinux): drawn for them, where they are.
else if (marks && /^[A-Za-z0-9]{10}$/.test(id || "")) addEventListener("brickworks:signed-in-done", () => basesOwn(), { once: true });
// Comments on a part (partpins): the comments and the model in 3D, each
// told of the other through this. The comments say which pins there are,
// numbered (pins), and whether a part may be commented on (open); the 3D
// view says where each is on this version (placed), which part was asked
// for (wanted) and which dot was pressed (pressed). [view] is start3d's.
const pinBridge = { pins: [], open: false, view: null, wanted: null, placed: null, pressed: null, name: null };
const pinHooks = {
  pins: () => pinBridge.pins,
  mayPin: () => pinBridge.open,
  pinWanted: (part) => pinBridge.wanted?.(part),
  placed: (list) => pinBridge.placed?.(list),
  pinPressed: (id) => pinBridge.pressed?.(id) || "",
  partName: (part, colour) => pinBridge.name?.(part, colour) || "",
};
// The Parts list's lots, for a pin's part's name: asked for by the list
// (startParts), whose one request this shares.
let partLots = null;
// The page's tabs (api/share.js pageTabs, web/tabs.js): each switches its
// panel in place, and the address says which. Started before the comments,
// whose link (#comment-12) opens their tab once they are listed.
const pageTabs = startTabs(document.getElementById("page-tabs"));
const comments = document.getElementById("comments");
if (comments && /^[A-Za-z0-9]{10}$/.test(comments.dataset.id || "")) startComments(comments);
// Its photos of real builds, the whole one where a copy would be drawn
// larger than it is (web/card.js sharpPhotos).
sharpPhotos(document);

// A page a probe opened with ?tests=1: the people @ offers include test
// accounts, which nobody else is offered.
const TESTS = new URLSearchParams(location.search).get("tests") === "1";
// Where the picture's frame is not the picture's own shape (directory.css):
// a phone's square, a laptop's 4:3 (sitepolish, 2026-11-23).
const FITTED = matchMedia("(width < 600px), (width >= 900px)");
// Its picture: the frame says it is coming until it is drawn, and one that
// fails is asked for again, twice, before the frame says there is none.
const frame = document.querySelector(".model-page .picture");
if (frame) startPicture(frame);
// Its model in 3D, in the picture's frame (viewer369): View in 3D, a click
// on the picture or the first drag across it (web/start3d.js, as the embed
// has it). Drawn by /viewer3d.js (tools/viewer/inline.js), asked for only
// then.
const in3d = frame && frame.dataset.scene ? start3d(frame, pinHooks) : null;
const close3d = in3d ? in3d.close : null;
pinBridge.view = in3d;
// A remix's "See what changed in 3D", under its credit (api/_remix.js): the
// 3D view, opened with What changed on, and the page brought to it.
const seeChanges = document.querySelector(".model-page .remix-changes .what-changed");
if (seeChanges && in3d && frame.dataset.changes) {
  seeChanges.addEventListener("click", (event) => {
    frame.scrollIntoView({ block: "nearest", behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    in3d.open(event.pointerType === "touch" ? "touch" : event.detail === 0 ? "key" : "mouse", true);
  });
} else if (seeChanges) {
  seeChanges.hidden = true;
}
// A model too big for a phone said so before the studio opens it (phonetruth).
guardPhoneOpens();
// Open in Brickworks' second choice, With your Claude (claudelink).
const claudePanel = document.getElementById("claude-panel");
if (claudePanel && /^[A-Za-z0-9]{10}$/.test(claudePanel.dataset.id || "")) startClaude(claudePanel);
// In your room (APP_UX5 #13, arview): where this browser can place a model
// in a room through the camera (AR Quick Look on an iPhone or iPad, WebXR's
// immersive AR on an Android phone or a headset), a button on the picture's
// foot, opposite View in 3D, that places its model there at its real size
// (web/room.js, with <model-viewer>, both asked for only on the tap). Never
// on a computer, which has no camera on a room.
if (frame && frame.dataset.scene) roomWay().then((how) => { if (how) offerRoom(frame, how); });

// The strip of its pictures (api/share.js mediaStrip): the one chosen is
// shown in the picture's place, whole, and edged in the strip. The picture
// is still the way into the viewer.
const strip = document.getElementById("pictures");
if (strip) startPictures(strip);
// Its parts (api/share.js partsSection): the list asked for as it nears the
// screen, so a visit that never gets there asks for nothing.
const partsPart = document.getElementById("parts");
// The page's parts list once it is asked for (startParts): a promise of
// parts.json, or of null.
let pageParts = null;
if (partsPart && partsPart.dataset.parts) startParts(partsPart);
// Its clip (unit turntable): the model turning once round, which its link's
// preview plays in Discord, Slack and X (api/share.js, og:video). Recorded
// on its designer's own visit to its newest version's page, once for each
// version, in a worker off this page's thread (tools/viewer/clip_worker.js,
// built as web/turntable-worker.js: ttreview F6), from that very version's
// scene (F2), then sent to be kept: a model shared from the studio, the
// desktop app or the site gets one alike. Signed in on the page, the same.
// <html data-clip> says how it went (tools/web/turntable_flow.mjs reads it).
let clipAsked = false;
// Its newest version's page: one no older version's note is on (each
// version's scene is named by its number, api/share.js sceneAt).
const newestScene = marks && /^[A-Za-z0-9]{10}$/.test(id || "") && Boolean(frame?.dataset.scene?.startsWith(`/m/${id}/`))
  && !document.querySelector(".model-page .old-version");
if (newestScene && signedIn()) clipOwn();
else if (newestScene) addEventListener("brickworks:signed-in-done", () => clipOwn(), { once: true });

/// The longest ask a message carries, in characters: a sentence or three.
/// Longer is refused with words, never cut (self_attack, Text).
const ASK_MOST = 500;
/// Where the message waits while the person connects Claude: read by the
/// connect pages (web/docs.js), and given back to this model's box.
const ASK_KEPT = "brickworks.claude.ask";

/// What the person typed, as one line: Unicode spaces as spaces, the
/// zero-width ones gone, runs of space and line breaks one space.
function askOf(text) {
  return String(text || "").replace(/[\u200B-\u200D\u2060\uFEFF]/g, "")
    .replace(/[\s\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+/g, " ").trim();
}

/// The message for the person's own Claude (claudelink): the model by its
/// name, designer and link, the one call that opens a copy of it in their
/// models, what to change or to ask them, and that the copy is credited to
/// it once they publish it. In the page's language; the call as it is
/// named.
function claudeMessage(panel, ask) {
  const { id: link, name, by, url } = panel.dataset;
  const model = by ? say("“{name}” by {by}", { name, by }) : say("“{name}”", { name });
  return [say("Please change a LEGO® model on Brickworks for me: {model}, {url}", { model, url }),
    `${say("With the Brickworks connector, call open_model with link={link}: it opens a copy in my models, and the original stays as it is.", { link })} `
      + (ask ? say("Then change the copy: {ask}", { ask }) : say("Then ask me what to change.")),
    say("When it is done, show me how it looks. I will publish the copy, and its page will credit the original.")].join("\n\n");
}

/// With your Claude: the second half of Open in Brickworks shown and made
/// to open [panel], whose Copy for Claude copies the message (and, where
/// the copy is refused, shows it to select), whose Share to Claude hands it
/// to a phone's share sheet, and whose Connect Claude keeps it for the
/// connect page. Escape closes the panel, back on the button that opened it.
/// <html data-claude> says what happened last: open, copied, shared, kept,
/// refused (too long), failed.
function startClaude(panel) {
  const opener = document.querySelector("[data-open-claude]");
  const form = panel.querySelector(".claude-ask");
  const field = panel.querySelector("#claude-ask");
  const said = panel.querySelector(".claude-said");
  const shown = panel.querySelector(".claude-message");
  const share = panel.querySelector("[data-claude-share]");
  if (!opener || !form || !field) return;
  const mark = (what) => { document.documentElement.dataset.claude = what; };
  // Its words back when the person comes back from connecting Claude.
  try {
    const kept = JSON.parse(localStorage.getItem(ASK_KEPT) || "null");
    if (kept && kept.id === panel.dataset.id && typeof kept.ask === "string") field.value = kept.ask;
  } catch {
    // Nothing kept, or storage refused: an empty box.
  }
  const show = (open) => {
    panel.hidden = !open;
    opener.setAttribute("aria-expanded", String(open));
    if (open) {
      mark("open");
      field.focus();
    }
  };
  opener.hidden = false;
  opener.addEventListener("click", () => show(panel.hidden));
  panel.addEventListener("keydown", (event) => {
    if (event.key !== "Escape" || panel.hidden) return;
    event.preventDefault();
    show(false);
    opener.focus();
  });
  // The message, or null with the reason said: an ask over the most.
  const message = () => {
    const ask = askOf(field.value);
    if (ask.length > ASK_MOST) {
      said.textContent = say("That is {n} characters: a message for Claude takes {most} at most. Say it shorter, or say the rest to Claude in the chat.",
        { n: number(ask.length), most: number(ASK_MOST) });
      mark("refused");
      field.focus();
      return null;
    }
    return claudeMessage(panel, ask);
  };
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const text = message();
    if (text === null) return;
    shown.value = text;
    if (await copy(text)) {
      shown.hidden = true;
      said.textContent = say("Copied. Paste it into a chat with your Claude, with the Brickworks connector on.");
      mark("copied");
      return;
    }
    shown.hidden = false;
    shown.focus();
    shown.select();
    said.textContent = say("It did not copy just now: select it and copy it yourself");
    mark("failed");
  });
  // A phone's own share sheet, where the browser has one: Claude's app is
  // one of the places it offers.
  share.hidden = !(typeof navigator.share === "function" && matchMedia("(pointer: coarse)").matches
    && (!navigator.canShare || navigator.canShare({ text: "Brickworks" })));
  share.addEventListener("click", async () => {
    const text = message();
    if (text === null) return;
    try {
      await navigator.share({ text });
      said.textContent = "";
      mark("shared");
    } catch (trouble) {
      // Closed without sharing: nothing to say.
      if (trouble && trouble.name !== "AbortError") {
        said.textContent = say("That did not open just now: use Copy for Claude instead");
        mark("failed");
      }
    }
  });
  // Connect Claude first: the message waits on the connect page, and is on
  // the clipboard too where the browser allows.
  panel.querySelector("[data-claude-connect]")?.addEventListener("click", (event) => {
    const text = message();
    if (text === null) {
      event.preventDefault();
      return;
    }
    try {
      localStorage.setItem(ASK_KEPT, JSON.stringify({ id: panel.dataset.id, name: panel.dataset.name, url: location.href,
        ask: askOf(field.value), text, at: Date.now() }));
      mark("kept");
    } catch {
      // Storage refused: the clipboard still has it.
    }
    copy(text);
  });
}

/// What this browser remembers of this model's clip for the account
/// signed in here (localStorage): {mine: false} where it is somebody
/// else's, so their visits ask nothing (ttreview N3); {at, how} where
/// recording the version made at [at] failed here, so it is not tried
/// again on every visit (F6). [given] writes it.
function clipMemo(given) {
  const key = `brickworks.clip:${email()}:${id}`;
  try {
    if (given) localStorage.setItem(key, JSON.stringify(given));
    return JSON.parse(localStorage.getItem(key) || "null") || {};
  } catch {
    return {};
  }
}

/// The designer's own visit: its clip recorded and sent where it has none
/// of the newest version, or only a WebM where this browser records MP4
/// (X, iMessage and Safari play MP4 alone), once the page has settled and
/// only while it is shown. Said on <html data-clip>: kept (nothing to do),
/// not-open (no clips on this deployment yet), cannot (no WebCodecs encoder
/// here), save-data, tried-<how> (it failed here before, for this version),
/// recording, cannot-draw (no WebGL 2 in a worker here, past the clip's
/// budget, or a part that did not come), slow (past its time), stale (the
/// scene came of another version), failed, made, or refused-<status>.
/// Anybody else's visit asks once whether it is theirs, and then never.
async function clipOwn() {
  if (clipAsked) return;
  clipAsked = true;
  const said = (how) => { document.documentElement.dataset.clip = how; };
  // A clip of its newest version its page names already: an MP4 is the
  // best there is, for its designer or anybody.
  const named = document.querySelector('meta[property="og:video:type"]')?.getAttribute("content") || "";
  if (named === "video/mp4") return said("kept");
  const memo = clipMemo();
  if (memo.mine === false) return;
  const { clipKind } = await import("/turntable-clip.js");
  const kind = await clipKind();
  if (named === "video/webm" && kind !== "mp4") return said("kept");
  const answer = await call(`/api/share?op=clip_need&id=${id}`).catch(() => null);
  if (!answer || answer.status !== 200) return;
  if (!answer.body.mine) {
    clipMemo({ mine: false });
    return;
  }
  if (!answer.body.ready) return said("not-open");
  const { version, at } = answer.body;
  const has = answer.body.clip;
  if (has && !(has.kind === "webm" && kind === "mp4")) return said("kept");
  if (!kind) return said("cannot");
  // The parts' geometry is data a person on a metered connection asked to save.
  if (navigator.connection && navigator.connection.saveData) return said("save-data");
  if (memo.at === at && memo.how) return said(`tried-${memo.how}`);
  const failed = (how) => {
    clipMemo({ at, how });
    said(how);
  };
  if (typeof Worker !== "function" || typeof OffscreenCanvas !== "function") return failed("cannot-draw");
  await new Promise((settled) => {
    const idle = () => (window.requestIdleCallback ? requestIdleCallback(() => settled(), { timeout: 4000 }) : setTimeout(settled, 1500));
    if (document.readyState === "complete") idle();
    else addEventListener("load", idle, { once: true });
  });
  await shown();
  said("recording");
  const made = await new Promise((done) => {
    const worker = new Worker("/turntable-worker.js");
    // It draws only while the page is shown.
    const seen = () => worker.postMessage({ visible: document.visibilityState === "visible" });
    const end = (answer) => {
      document.removeEventListener("visibilitychange", seen);
      worker.terminate();
      done(answer && typeof answer.how === "string" ? answer : { how: "failed" });
    };
    worker.addEventListener("message", (event) => end(event.data));
    worker.addEventListener("error", () => end(null));
    document.addEventListener("visibilitychange", seen);
    seen();
    // That version's scene, at an address no CDN has kept for an earlier
    // version of the same number, and which must say it is that version.
    worker.postMessage({ scene: `/m/${id}/scene.json?v=${version}&at=${encodeURIComponent(at)}`, of: `m:${id}:${version}`,
      kind, coarse: matchMedia("(pointer: coarse)").matches });
  });
  // The version the scene it drew said it was (<html data-clip-of>, which
  // tools/web/turntable_flow.mjs holds to the version sent).
  if (made.of) document.documentElement.dataset.clipOf = String(made.of);
  if (made.how === "stale") return said("stale");
  if (made.how !== "recorded") return failed(made.how);
  const sent = await call(`/api/share?op=clip&id=${id}`, { method: "POST", body: { version, at, clip: made.clip } })
    .catch(() => ({ status: 0 }));
  if (sent.status === 200) return said("made");
  return failed(`refused-${sent.status}`);
}

/// Once the page is shown (now, where it is).
function shown() {
  return new Promise((done) => {
    if (document.visibilityState === "visible") return done();
    const look = () => {
      if (document.visibilityState !== "visible") return;
      document.removeEventListener("visibilitychange", look);
      done();
    };
    document.addEventListener("visibilitychange", look);
  });
}

/// How this browser places a model in a room, as <model-viewer> judges it
/// (its IS_AR_QUICKLOOK_CANDIDATE and IS_WEBXR_AR_CANDIDATE): "quick-look"
/// on an iPhone or iPad (an iPad says it is a Mac with a touch screen),
/// where Safari, or a browser on it, opens AR Quick Look (not the Google
/// app's, which does not); "webxr" where WebXR has immersive AR with hit
/// tests; else "".
function roomWay() {
  const agent = navigator.userAgent;
  if (/iPad|iPhone|iPod/.test(agent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)) {
    if (/GSA\//.test(agent)) return Promise.resolve("");
    if (/CriOS\/|EdgiOS\/|FxiOS\/|DuckDuckGo\//.test(agent)) return Promise.resolve("quick-look");
    const link = document.createElement("a");
    return Promise.resolve(link.relList && link.relList.supports && link.relList.supports("ar") ? "quick-look" : "");
  }
  if (!navigator.xr || !navigator.xr.isSessionSupported || !globalThis.XRSession || !XRSession.prototype.requestHitTestSource) {
    return Promise.resolve("");
  }
  return navigator.xr.isSessionSupported("immersive-ar").then((yes) => (yes ? "webxr" : ""), () => "");
}

/// In your room on [big], the picture: a button on its foot that opens the
/// model in a room over it (web/room.js), and opens it again as it was.
function offerRoom(big, how) {
  const name = big.querySelector("img")?.getAttribute("alt") || document.querySelector(".model-page h1")?.textContent || "";
  const over = document.createElement("div");
  over.className = "room-over";
  // A brick on a floor before its words.
  over.innerHTML = '<button type="button" class="room-go"><svg class="icon" viewBox="0 0 24 24" aria-hidden="true" focusable="false">'
    + '<path d="M12 4 18 7 12 10 6 7zM6 7v6.5l6 3V10M18 7v6.5l-6 3M3 20.5h18"/></svg><span></span></button>';
  const go = over.querySelector(".room-go");
  go.querySelector("span").textContent = say("In your room");
  go.setAttribute("aria-label", say("Place {name} in your room, at its real size", { name }));
  go.dataset.how = how;
  big.after(over);
  let room = null;
  go.addEventListener("click", () => {
    if (close3d) close3d();
    if (!room) {
      // Not even the code came: asked again on the next tap.
      room = import("/room.js").then((made) => made.openRoom(big, { name })).catch(() => { room = null; return null; });
    } else room.then((one) => one && one.open());
  });
}

function startPicture(big) {
  const img = big.querySelector("img");
  const sign = big.querySelector(".waiting");
  if (!img || !sign) return;
  let tries = 0;
  const drawn = () => {
    sign.hidden = true;
    img.style.visibility = "";
    fitPicture(big, img);
  };
  const failed = () => {
    // Not the browser's broken picture over the words while it is asked again.
    img.style.visibility = "hidden";
    sign.hidden = false;
    if (tries >= 2) {
      sign.textContent = say("No picture");
      return;
    }
    tries += 1;
    const src = img.getAttribute("src").replace(/[?&]again=\d+$/, "");
    setTimeout(() => { img.src = `${src}${src.includes("?") ? "&" : "?"}again=${tries}`; }, 1500 * tries);
  };
  img.addEventListener("load", drawn);
  img.addEventListener("error", failed);
  if (img.complete) (img.naturalWidth > 0 ? drawn : failed)();
  // Drawn again as the frame changes shape: a window made wider or narrower.
  let width = 0;
  new ResizeObserver(() => {
    if (Math.abs(big.clientWidth - width) < 1) return;
    width = big.clientWidth;
    if (img.complete && img.naturalWidth > 0) fitPicture(big, img);
  }).observe(big);
}


/// Where the picture's frame is taller than the picture (a phone's square,
/// a laptop's 4:3), its model is drawn as large as the model's width lets
/// it: the 1200 x 630 picture cropped round the model when the model is no
/// wider than the frame, else scaled until all of it is in, on the frame's
/// ground (a picture with nothing behind the model), or with the ground an
/// older picture carries (--render-top, --render-foot) carried on above and
/// below it. Never smaller than the whole picture across the frame, as it
/// was: 186 px tall at 390, a fifth of the screen (site273), and 380 of a
/// 1280 window's 800 beside a column 560 tall (sitepolish). By its own
/// scale and translate alone (a pointer's zoom is its transform, applied
/// after them), which move nothing else, so the page never shifts as it
/// does; never a custom property made in the page (the design system's
/// tokens are :root's). A photo is shown whole
/// (.photo); a tablet's frame is the picture's own shape.
function fitPicture(big, img) {
  img.style.objectFit = "";
  img.style.removeProperty("scale");
  img.style.removeProperty("translate");
  big.style.background = "";
  if (!FITTED.matches || big.classList.contains("photo") || !img.naturalWidth || !big.clientHeight) return;
  // The frame's shape against the picture's: a square is 1, 4:3 is 1.33.
  const aspect = img.naturalWidth / img.naturalHeight;
  const frame = big.clientWidth / big.clientHeight;
  if (frame >= aspect - 0.02) return;
  // The model's columns, read from a small copy: those drawn on, in a
  // picture with nothing behind the model; else those that differ from its
  // ground, a gradient from top to bottom read at the corners.
  const w = 120;
  const h = Math.max(1, Math.round((w * img.naturalHeight) / img.naturalWidth));
  const pen = Object.assign(document.createElement("canvas"), { width: w, height: h }).getContext("2d", { willReadFrequently: true });
  let px;
  try {
    pen.drawImage(img, 0, 0, w, h);
    px = pen.getImageData(0, 0, w, h).data;
  } catch {
    return;
  }
  const colour = (x, y) => [0, 1, 2].map((c) => px[(y * w + x) * 4 + c]);
  const alpha = (x, y) => px[(y * w + x) * 4 + 3];
  const clear = [alpha(0, 0), alpha(w - 1, 0), alpha(0, h - 1), alpha(w - 1, h - 1)].every((a) => a < 16);
  const mix = (a, b) => a.map((v, c) => (v + b[c]) / 2);
  const top = mix(colour(0, 0), colour(w - 1, 0));
  const foot = mix(colour(0, h - 1), colour(w - 1, h - 1));
  const hits = new Array(w).fill(0);
  for (let y = 0; y < h; y += 1) {
    const ground = top.map((v, c) => v + ((foot[c] - v) * y) / Math.max(1, h - 1));
    for (let x = 0; x < w; x += 1) {
      const here = colour(x, y);
      if (clear ? alpha(x, y) > 16
        : Math.abs(here[0] - ground[0]) + Math.abs(here[1] - ground[1]) + Math.abs(here[2] - ground[2]) > 40) hits[x] += 1;
    }
  }
  const first = hits.findIndex((n) => n >= 2);
  const last = w - 1 - [...hits].reverse().findIndex((n) => n >= 2);
  if (first < 0) return;
  // The share of the picture's width shown: the model's and a margin, and
  // no less than the frame's, which crops it to the frame's height.
  const shown = Math.min(1, Math.max(frame / aspect, (last - first + 1) / w + 0.06));
  const middle = Math.min(1 - shown / 2, Math.max(shown / 2, (first + last + 1) / 2 / w));
  // Drawn whole across the frame (contain), then enlarged round the model.
  img.style.objectFit = "contain";
  // scale(1 / shown) translateX(t) is translate(t / shown) then the scale.
  img.style.scale = (1 / shown).toFixed(4);
  img.style.translate = `${(((0.5 - middle) * 100) / shown).toFixed(2)}% 0`;
  // An older picture's own ground above and below it, where it is shorter
  // than the frame; one with nothing behind the model is on the frame's.
  const band = Math.max(0, (1 - frame / (shown * aspect)) / 2) * 100;
  if (band > 0.5 && !clear) {
    big.style.background = `linear-gradient(180deg, var(--render-top) ${band.toFixed(1)}%, var(--render-foot) ${(100 - band).toFixed(1)}%)`;
  }
}

function startPictures(row) {
  const big = document.querySelector(".model-page .picture");
  const img = big && big.querySelector("img");
  if (!img) return;
  row.addEventListener("click", (event) => {
    const thumb = event.target.closest("a.thumb[data-picture]");
    if (!thumb) return;
    event.preventDefault();
    if (close3d) close3d();
    img.src = thumb.dataset.picture;
    img.alt = thumb.querySelector("img")?.alt || img.alt;
    // The published picture fills its frame; a photo is shown whole.
    big.classList.toggle("photo", thumb.getAttribute("href").startsWith("#"));
    for (const one of row.querySelectorAll("a.thumb")) one.removeAttribute("aria-current");
    thumb.setAttribute("aria-current", "true");
  });
}

// How many rows the list shows before Show all, as api/share.js LOTS_SHOWN
// keeps their space.
const LOTS_SHOWN = 12;
const SVG = "http://www.w3.org/2000/svg";

/// The Parts list (site278): /m/X/parts.json, asked for once the section is
/// a screen away (or its tab is chosen), drawn a row a colour or a kind
/// (Colour, Kind) with its lots under it in the app's order, the first
/// LOTS_SHOWN rows until Show all. Each lot is its picture, its name, its
/// number and colour, and how many. Its picture is its colour's swatch until
/// the part itself is drawn over it, in its colour, from its geometry
/// (web/part-pictures.js, site304), as the row nears the screen; one that
/// cannot be drawn keeps the swatch. Its words in the page's language (a
/// set's page at /de/library/set/<n>); the parts', colours' and kinds'
/// names in the visitor's, as the app says them (?lang=de: api/share.js
/// partsAnswer), on a page with no copy in it (a model's) too, and LDraw's
/// where the app has no words for one, each marked with its language.
///
/// A model's list, to somebody signed in (ownedparts): how much of it they
/// have, counted as the gallery's cards count it, and All · Missing · Have
/// all, the list less what they own, those they have every one of, each lot
/// with its count; with Missing chosen, the shops' lists are of only those
/// (api/share.js op=parts_missing, startMine).
function startParts(section) {
  const list = section.querySelector(".lot-list");
  const reserved = list?.style.minHeight || "";
  const all = section.querySelector("[data-all]");
  const choices = [...section.querySelectorAll("[data-group]")];
  // The model and version this list is of; a set's page's is not one (it
  // says what is owned of it itself, web/set-page.js).
  const ofModel = /^\/m\/([A-Za-z0-9]{10})(?:\/v\/([1-9][0-9]{0,5}))?\/parts\.json$/.exec(section.dataset.parts || "");
  // What they are missing (startMine's answer) and which lots are shown:
  // "all", "missing" or "whole".
  let mine = null;
  let show = "all";
  // Its row, kept from the start for somebody signed in (holdMine).
  let held = null;
  // What draws the lots' pictures (web/part-pictures.js): undefined until
  // it is here, false where there is none.
  let pictures;
  const lotOf = new WeakMap();
  let lots = null;
  let asked = null;
  let group = "colour";
  let open = false;
  const site = globalThis.brickworksLang;
  const page = site?.code || "en";
  const lang = page !== "en" ? page : site?.chosen() || "en";
  // [element] marked as in [code] where the page is not.
  const inLang = (element, code) => {
    if (code !== page) element.lang = code;
    return element;
  };
  const nameOf = (lot) => lot.said || lot.name;
  list.setAttribute("aria-busy", "true");
  const swatch = (hex) => {
    const svg = document.createElementNS(SVG, "svg");
    svg.setAttribute("class", "swatch");
    svg.setAttribute("viewBox", "0 0 14 14");
    svg.setAttribute("aria-hidden", "true");
    const square = document.createElementNS(SVG, "rect");
    for (const [name, value] of [["width", 14], ["height", 14], ["rx", 3], ["fill", `#${hex}`],
      ["stroke", "currentColor"], ["stroke-opacity", "0.25"]]) square.setAttribute(name, String(value));
    svg.append(square);
    return svg;
  };
  const row = (lot) => {
    const item = document.createElement("li");
    item.className = "lot";
    item.dataset.part = lot.part;
    item.dataset.colour = String(lot.colour);
    const pic = document.createElement("span");
    pic.className = "pic";
    pic.append(swatch(lot.hex));
    lotOf.set(pic, lot);
    if (pictures) pictures.want(pic, lot);
    else if (pictures === false) pic.dataset.picture = "none";
    const what = document.createElement("span");
    what.className = "what";
    const name = inLang(document.createElement("span"), lot.said ? lang : "en");
    name.className = "name";
    name.textContent = nameOf(lot);
    // LDraw's own name under the one said, as the app's tile tooltip has it.
    name.title = lot.said ? `${lot.said}\n${lot.name}` : lot.name;
    const meta = document.createElement("span");
    meta.className = "meta";
    const colour = inLang(document.createElement("span"), lot.colour_said ? lang : "en");
    colour.textContent = lot.colour_said || lot.colour_name;
    meta.append(`${lot.part}${lot.element ? ` · ${lot.element}` : ""} ·`, swatch(lot.hex), colour);
    meta.title = `${lot.part}${lot.element ? `, ${say("element {element}", { element: lot.element })}` : ""}, ${colour.textContent}`;
    what.append(name, meta);
    const qty = document.createElement("span");
    qty.className = "qty";
    qty.textContent = `× ${number(lot.count)}`;
    qty.setAttribute("aria-label", say("{n} of them", { n: number(lot.count) }));
    // Short of it: how many more, and how many of it they have.
    if (show === "missing" && Number.isInteger(lot.need)) {
      qty.setAttribute("aria-label", say("{n} more needed", { n: number(lot.count) }));
      if (lot.have > 0) {
        const had = document.createElement("span");
        had.className = "had";
        had.textContent = `· ${say("you have {have} of {need}", { have: number(lot.have), need: number(lot.need) })}`;
        meta.append(had);
      }
    }
    item.append(pic, what, qty);
    return item;
  };
  // The lots shown: every one, those they are short of (with how many
  // short), or those they have every one of.
  const shownLots = () => {
    if (!mine || show === "all") return lots;
    if (show === "missing") return mine.missing;
    return lots.filter((lot) => !mine.short.has(`${lot.part}/${lot.colour}`));
  };
  const heading = (words, n, hex, code) => {
    const item = document.createElement("li");
    item.className = "group";
    if (hex) item.append(swatch(hex));
    const said = inLang(document.createElement("span"), code);
    said.textContent = words;
    const count = document.createElement("span");
    count.className = "n";
    count.textContent = counted(n, "part");
    item.append(said, count);
    return item;
  };
  const draw = () => {
    if (pictures) pictures.forget();
    // Each colour (or kind) with the most of its parts first, its lots
    // under it.
    const groups = new Map();
    for (const lot of shownLots()) {
      const key = group === "colour" ? `c${lot.colour}` : `k${lot.category || ""}`;
      const said = group === "colour" ? lot.colour_said : lot.category_said;
      const words = said || (group === "colour" ? lot.colour_name : lot.category);
      if (!groups.has(key)) groups.set(key, { lots: [], n: 0, words: words || say("Other"),
        code: said ? lang : words ? "en" : page, hex: group === "colour" ? lot.hex : "" });
      const one = groups.get(key);
      one.lots.push(lot);
      one.n += lot.count;
    }
    // In a colour, the most of a part first; in a kind, the app's order,
    // which keeps a part's colours together.
    const most = (a, b) => b.count - a.count || (nameOf(a) < nameOf(b) ? -1 : nameOf(a) > nameOf(b) ? 1 : 0);
    const rows = [];
    for (const one of [...groups.values()].sort((a, b) => b.n - a.n || (a.words < b.words ? -1 : 1))) {
      rows.push(heading(one.words, one.n, one.hex, one.code), ...(group === "colour" ? [...one.lots].sort(most) : one.lots).map(row));
    }
    rows.forEach((item, at) => { item.hidden = !open && at >= LOTS_SHOWN; });
    list.replaceChildren(...rows);
    list.removeAttribute("aria-busy");
    // The room kept for the whole list before it came (api/share.js
    // partsSection), kept for it alone: Missing or Have all, chosen, take
    // what they hold, so no empty space under a short one.
    list.style.minHeight = show === "all" ? reserved : "";
    if (all) all.hidden = open || rows.length <= LOTS_SHOWN;
  };
  const load = () => {
    if (asked) return asked;
    // What draws the pictures, asked for beside the list and only with it,
    // so a visit that never comes near the list loads neither.
    const drawer = import("/part-pictures.js").catch(() => null);
    const from = new URL(section.dataset.parts, location.href);
    if (lang !== "en") from.searchParams.set("lang", lang);
    asked = fetch(from).then((answer) => (answer.ok ? answer.json() : null)).catch(() => null)
      .then((body) => {
        if (!body || !Array.isArray(body.lots)) {
          list.removeAttribute("aria-busy");
          if (all) all.hidden = true;
          const item = document.createElement("li");
          item.className = "group";
          item.textContent = say("The list did not come. Reload the page to ask for it again.");
          list.replaceChildren(item);
          asked = null;
          return null;
        }
        lots = body.lots;
        draw();
        document.documentElement.dataset.parts = "drawn";
        // The list never waits for its pictures: they come over the
        // swatches once what draws them is here.
        drawer.then((made) => {
          try {
            pictures = (made && body.root && made.partPictures(body.root, body.colours, body.lot_pictures)) || false;
          } catch {
            pictures = false;
          }
          for (const pic of list.querySelectorAll(".lot .pic")) {
            if (pictures) pictures.want(pic, lotOf.get(pic));
            else pic.dataset.picture = "none";
          }
        });
        return body;
      });
    // What they are missing, asked beside the list.
    if (ofModel && signedIn()) startMine(asked);
    return asked;
  };
  partLots = () => Promise.resolve(load()).then(() => lots);
  // The same list, for a kit to post it elsewhere (web/post-kit.js).
  pageParts = load;
  for (const choice of choices) {
    choice.addEventListener("click", () => {
      group = choice.dataset.group;
      for (const one of choices) one.setAttribute("aria-pressed", String(one === choice));
      if (lots) draw();
      else load();
    });
  }
  if (all) {
    all.addEventListener("click", () => {
      open = true;
      // In the page before the list comes: pressed then, the list comes whole.
      if (lots) draw();
      else load();
      // The next row in reach of the keyboard, where Show all was.
      list.querySelectorAll("li")[LOTS_SHOWN]?.setAttribute("tabindex", "-1");
      list.querySelectorAll("li")[LOTS_SHOWN]?.focus({ preventScroll: true });
    });
  }
  /// What they have of it, said over the list once the list is here, and
  /// All · Missing · Have all to choose between: the list's own row, kept
  /// for it from the start (holdMine), so nothing under it moves.
  let started = false;
  async function startMine(listed) {
    if (started || !ofModel) return;
    started = true;
    const row = held || (held = holdMine());
    const said = row.querySelector(".parts-have");
    const version = ofModel[2] ? `&v=${ofModel[2]}` : "";
    const [answer] = await Promise.all([
      call(`/api/share?op=parts_missing&id=${ofModel[1]}${version}${lang !== "en" ? `&lang=${lang}` : ""}`).catch(() => null),
      listed]);
    const body = answer?.body;
    // The list did not come: it says so, and this is asked again with it.
    if (!lots) {
      started = false;
      said.textContent = "";
      return;
    }
    if (!answer || answer.status !== 200 || !body || typeof body !== "object") {
      said.textContent = answer?.status === 401 ? say("Sign in again to see what you are missing.")
        : say("What you own could not be read just now. Reload the page to ask again.");
      document.documentElement.dataset.missing = "broken";
      started = answer?.status === 401 ? false : started;
      return;
    }
    const pieces = Number(body.pieces) || 0;
    const have = Math.min(Number(body.have) || 0, pieces);
    if (!body.collection) {
      said.textContent = say("Mark the sets you own (Own, on a set's page) or add your parts in the app, "
        + "and this says what you are missing.");
      document.documentElement.dataset.missing = "none";
      return;
    }
    const missing = (Array.isArray(body.missing) ? body.missing : []).filter((lot) => lot && typeof lot.part === "string");
    // Those they are short of, and those nobody owns on their own: neither
    // is one they have every one of.
    mine = { missing, short: new Set([...missing.map((lot) => `${lot.part}/${lot.colour}`),
      ...(Array.isArray(body.left?.keys) ? body.left.keys.map(String) : [])]), body };
    const whole = Number(body.whole) || 0;
    const shortBy = missing.reduce((n, lot) => n + (Number(lot.count) || 0), 0);
    if (!missing.length) {
      said.textContent = `✓ ${say("Have all {n} of its parts.", { n: number(pieces) })}`;
      said.classList.add("all");
    } else {
      const share = (Math.floor((100 * have) / Math.max(pieces, 1)) / 100)
        .toLocaleString(globalThis.brickworksLang?.locale || "en-US", { style: "percent", maximumFractionDigits: 0 });
      said.textContent = say("You have {have} of its {pieces} parts ({share}): {short} missing, in {lots}.",
        { have: number(have), pieces: number(pieces), share, short: number(shortBy), lots: counted(missing.length, "lot") });
    }
    if (Number(body.unknown) > 0) {
      const sets = counted(Number(body.unknown), "set");
      said.textContent += " " + (Number(body.unknown) === 1
        ? say("{sets} of yours has no parts list here, so what is in it is not counted.", { sets })
        : say("{sets} of yours have no parts list here, so what is in them is not counted.", { sets }));
    }
    document.documentElement.dataset.missing = `${have}/${pieces}/${missing.length}`;
    if (!missing.length) return;
    // All · Missing · Have all, each with how many lots.
    const shows = row.querySelector(".segmented");
    const counts = { all: lots.length, missing: missing.length, whole };
    for (const button of shows.querySelectorAll("[data-show]")) {
      const n = counts[button.dataset.show];
      button.querySelector(".n").textContent = number(n);
      button.setAttribute("aria-label", `${button.dataset.label}: ${counted(n, "lot")}`);
      button.addEventListener("click", () => choose(button.dataset.show));
    }
    shows.hidden = false;
    mineShops(body);
  }

  /// The row that says what they have, made at once (before what it says
  /// is known) between the count and Colour · Kind, so the list does not
  /// move when it comes; and All · Missing · Have all, hidden until then.
  function holdMine() {
    const row = document.createElement("div");
    row.className = "parts-mine";
    const said = document.createElement("p");
    said.className = "parts-have";
    said.setAttribute("role", "status");
    said.textContent = say("Counting what you have of it…");
    const shows = document.createElement("div");
    shows.className = "segmented";
    shows.setAttribute("role", "group");
    shows.setAttribute("aria-label", say("Show"));
    shows.hidden = true;
    for (const [value, words] of [["all", say("All")], ["missing", say("Missing")], ["whole", say("Have all")]]) {
      const button = document.createElement("button");
      button.type = "button";
      button.dataset.show = value;
      button.dataset.label = value === "missing" ? say("What you're missing") : value === "whole" ? say("Have all") : say("Every lot");
      button.setAttribute("aria-pressed", String(value === show));
      const word = document.createElement("span");
      word.textContent = words;
      const n = document.createElement("span");
      n.className = "n";
      button.append(word, " ", n);
      shows.append(button);
    }
    row.append(said, shows);
    (section.querySelector(".parts-bar") || list).before(row);
    return row;
  }

  /// Which lots are shown, and the shops' lists of them: only the missing
  /// ones' while Missing is chosen, the whole model's otherwise.
  function choose(value) {
    show = value;
    for (const button of section.querySelectorAll(".parts-mine [data-show]")) {
      button.setAttribute("aria-pressed", String(button.dataset.show === value));
    }
    const missing = value === "missing";
    for (const whole of section.querySelectorAll(".parts-shops:not(.missing), .pab-note:not(.missing)")) whole.hidden = missing;
    for (const only of section.querySelectorAll(".parts-shops.missing, .pab-note.missing")) only.hidden = !missing;
    if (lots) draw();
    document.documentElement.dataset.partsShown = value;
  }

  /// The shops' lists of only what they are missing, beside the whole
  /// model's and in their place while Missing is chosen: BrickLink XML,
  /// Rebrickable CSV and LEGO® Pick a Brick CSV (a file of 400 elements
  /// each), made here from the answer, so one click downloads each; and
  /// what Pick a Brick leaves off, said under them.
  function mineShops(body) {
    const files = body.files || {};
    const base = String(body.name || ofModel[1]).replace(/[^A-Za-z0-9 ._-]+/g, "").trim() || ofModel[1];
    const shops = document.createElement("div");
    shops.className = "parts-shops missing";
    shops.hidden = show !== "missing";
    const download = (words, text, type, name, title = "") => {
      if (typeof text !== "string" || !text) return;
      const button = document.createElement("button");
      button.type = "button";
      button.className = "cta ghost small";
      button.textContent = words;
      button.dataset.missing = name;
      if (title) button.title = title;
      button.addEventListener("click", () => {
        const link = document.createElement("a");
        link.href = URL.createObjectURL(new Blob([text], { type }));
        link.download = name;
        document.body.append(link);
        link.click();
        link.remove();
        setTimeout(() => URL.revokeObjectURL(link.href), 1000);
      });
      shops.append(button);
    };
    download("BrickLink XML", files.bricklink, "application/xml", `${base}-missing-bricklink.xml`);
    download("Rebrickable CSV", files.rebrickable, "text/csv", `${base}-missing-rebrickable.csv`);
    const pab = Array.isArray(files.pickabrick) ? files.pickabrick : [];
    const what = say("A list of LEGO® element numbers to upload at LEGO® Pick a Brick");
    pab.forEach((text, n) => download(pab.length > 1
      ? say("LEGO® Pick a Brick CSV, {n} of {all}", { n: number(n + 1), all: number(pab.length) }) : say("LEGO® Pick a Brick CSV"),
    text, "text/csv", `${base}-missing-pickabrick${pab.length > 1 ? `-${n + 1}` : ""}.csv`, what));
    const whole = section.querySelector(".parts-shops:not(.missing)");
    if (whole) whole.after(shops);
    else section.querySelector(".parts-bar")?.append(shops);
    // What the lists leave off: what nobody owns on its own is in no count;
    // a lot with no LEGO® element number known is not on Pick a Brick's.
    const notes = [];
    const left = Number(body.left_out?.pickabrick) || 0;
    if (left) {
      notes.push(say("Not on the Pick a Brick list, with no LEGO® element number known: {lots} ({parts}).", {
        lots: counted(left, "lot"), parts: counted(Number(body.pickabrick?.left_out_pieces) || 0, "part") }));
    }
    if (Number(body.left?.lots) > 0) {
      notes.push(say("Not counted, as nobody owns them on their own (stickers, made parts): {parts}.",
        { parts: counted(Number(body.left.pieces) || 0, "part") }));
    }
    if (notes.length) {
      const note = document.createElement("p");
      note.className = "note pab-note missing";
      note.hidden = show !== "missing";
      note.textContent = notes.join(" ");
      (section.querySelector(".pab-note:not(.missing)") || section.querySelector(".parts-bar"))?.after(note);
    }
  }
  // Signed in on this page after the list came (the header's Sign in).
  addEventListener("brickworks:signed-in-done", () => { if (lots && ofModel && signedIn()) startMine(asked); });
  if (ofModel && signedIn()) held = holdMine();

  document.querySelector('#page-tabs a[data-tab="parts"]')?.addEventListener("click", load);
  // Watched once the page has loaded, its picture first: the list never
  // competes with what is on the first screen.
  const watch = () => {
    if (!("IntersectionObserver" in window)) return load();
    const near = new IntersectionObserver((seen) => {
      if (!seen.some((one) => one.isIntersecting)) return;
      near.disconnect();
      load();
    }, { rootMargin: "800px 0px" });
    near.observe(section);
  };
  if (document.readyState === "complete") watch();
  else addEventListener("load", watch, { once: true });
}

function startComments(section) {
  const model = section.dataset.id;
  const version = Number(section.dataset.version) || 1;
  const newest = Number(section.dataset.newest) || version;
  const list = section.querySelector(".comment-list");
  const form = section.querySelector("form.comment-new");
  const step = form.querySelector("#comment-step");
  const box = form.querySelector("#comment-body");
  const send = form.querySelector('button[type="submit"]');
  const why = section.querySelector(".comment-why");
  const said = section.querySelector(".comments-said");
  let state = null;
  // Comments on a part: the part pressed in 3D that the box is on ({part,
  // colour, at, turn, name}, the 3D view's), each pin's number, where the 3D
  // view placed each (id -> {index, moved}, or null for on no part here;
  // none until it has), and the Parts list's lots for their names.
  let aiming = null;
  let pinNumber = new Map();
  let placed = new Map();
  let lots = null;
  let lotsAsked = false;
  const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches;
  const chip = document.createElement("p");
  chip.className = "comment-part";
  chip.hidden = true;
  chip.setAttribute("aria-live", "polite");
  form.querySelector(".comment-on")?.after(chip);
  // Resolved pins, folded away under the list.
  const fold = document.createElement("details");
  fold.className = "comments-resolved";
  fold.hidden = true;
  const foldSaid = document.createElement("summary");
  foldSaid.className = "pill";
  const foldList = document.createElement("ol");
  foldList.className = "comment-list";
  fold.append(foldSaid, foldList);
  list.after(fold);
  // The thread whose reply box is open, and what was typed in it, kept
  // across a sign-in and a redraw.
  let replying = null;
  const DAY = new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" });
  // Where a comment was said, as api/_comments.js saidWhere says it.
  const whereSaid = (one) => {
    const where = one.step ? say("on step {step} of version {version}", { step: one.step, version: one.version })
      : say("on version {version}", { version: one.version });
    return one.older ? say("{where}, an older version", { where }) : where;
  };
  const tell = (text) => { said.textContent = text; };

  async function load() {
    const path = `/api/people?op=comments&id=${model}&v=${version}`;
    let answer;
    if (signedIn()) {
      answer = await call(path);
    } else {
      const reply = await fetch(path, { headers: { accept: "application/json" } });
      answer = { status: reply.status, body: await reply.json().catch(() => ({})) };
    }
    // The skeleton holding its place (api/share.js commentsSection) goes in
    // the frame it is drawn in.
    const hold = document.getElementById("comments-hold");
    const body = section.querySelector(".comments-body");
    if (answer.status !== 200) {
      // Its tab says why, where the comments would be.
      hold?.remove();
      return tell(told(answer.body.error, say("The comments did not load just now.")));
    }
    state = answer.body;
    // A page the CDN kept from before a newer version was published (a
    // model's page is kept 30 s, and 30 more while it is asked again): its
    // picture, 3D and pins are the version before's. The comments are never
    // kept and say which is newest, so the newest's page is asked anew,
    // once, under an address the CDN has not kept. Right after a publish a
    // visitor saw every pin where it had been (partpins, rel-m325's preview).
    const fresh = new URL(location.href);
    if (Number(state.newest) > newest && version === newest && !/\/v\/\d+\/?$/.test(fresh.pathname)
      && Number(fresh.searchParams.get("newest") || 0) < Number(state.newest)) {
      fresh.searchParams.set("newest", String(Number(state.newest)));
      location.replace(fresh);
      return;
    }
    // Drawn anew: its address as it is shared, without the asking.
    if (fresh.searchParams.has("newest")) {
      fresh.searchParams.delete("newest");
      history.replaceState(history.state, "", fresh);
    }
    // Not open on this deployment yet (comments.sql): nothing to show, and
    // no tab (commentsSaid).
    hold?.remove();
    body.hidden = state.ready === false;
    pinsOf();
    draw();
    // The 3D view, if open, places them again.
    pinBridge.view?.pinsChanged();
    commentsSaid(state, setOpen);
    talkAbout(state.you?.owner === true);
    finishFor(state.you?.owner === true);
  }
  commentsLoaded = { reload: load };

  function button(words, run, kind = "link") {
    const made = document.createElement("button");
    made.type = "button";
    made.className = kind;
    made.textContent = words;
    made.addEventListener("click", run);
    return made;
  }

  /// Its Show and tell thread in Talk (api/_talk.js talkModel), under the
  /// comments' words: the way to it, or for its builder the way to start
  /// one; nothing for anybody else while it has none. Asked once.
  let talkAsked = false;
  async function talkAbout(owner) {
    const place = document.getElementById("talk-about");
    if (!place || talkAsked) return;
    talkAsked = true;
    const reply = await fetch(`/api/people?op=talk_model&id=${model}${TESTS ? "&tests=1" : ""}`).catch(() => null);
    const body = reply && reply.ok ? await reply.json().catch(() => null) : null;
    if (!body) return;
    const link = document.createElement("a");
    if (body.thread?.path) {
      link.href = `${langAt()}${body.thread.path}${TESTS ? "?tests=1" : ""}`;
      link.textContent = body.thread.title;
      const replies = Number(body.thread.replies) || 0;
      place.append(say("Talked about in Show and tell:"), " ", link, " ",
        `(${counted(replies, "reply", "replies")})`);
    } else if (owner) {
      link.href = `${langAt()}/talk/new?model=${model}${TESTS ? "&tests=1" : ""}`;
      link.textContent = say("Start a Show and tell thread about it");
      place.append(link, " ", say("in Talk, the builders’ forum."));
    } else {
      return;
    }
    place.hidden = false;
  }

  /// Mark it finished, on a work in progress's Log, for its designer alone
  /// (api/_wip.js finish, buildlog): its newest version is the finished
  /// one, told in its Talk thread and to their followers, and from then it
  /// ranks in the gallery as any model does. Anybody else never sees it.
  let finishWired = false;
  function finishFor(owner) {
    const button = document.querySelector("[data-finish]");
    const said = document.querySelector(".finish-said");
    if (!button || !said || !owner || finishWired) return;
    finishWired = true;
    button.hidden = false;
    button.addEventListener("click", async () => {
      button.disabled = true;
      said.hidden = false;
      said.textContent = say("Marking it finished…");
      const answer = await call("/api/share?op=finish", { method: "POST", body: { id: model } }).catch(() => null);
      if (!answer || answer.status !== 200) {
        button.disabled = false;
        said.textContent = told(answer?.body?.error, say("It could not be marked finished just now. Try again in a minute."));
        return;
      }
      const n = Number(answer.body.version) || 1;
      document.querySelectorAll(".pill.wip").forEach((pill) => pill.closest("li:not(.log-entry)")?.remove());
      button.closest(".wip-line")?.remove();
      const posted = answer.body.talk?.url ? " " + say("It is said in its Talk thread too.") : "";
      said.textContent = say("Finished: version {n} is the finished one, and your followers are told.", { n }) + posted;
      document.documentElement.dataset.finished = String(n);
    });
  }

  /// The viewer at [at], a step of version [of]: Build it, opened there.
  // On a copy, in its language, as web/theme.js carries it into the links
  // drawn with the page.
  const lang = /^(?:de|fr|es)$/.test(globalThis.brickworksLang?.code || "") ? `&lang=${globalThis.brickworksLang.code}` : "";
  const viewerAt = (of, at) => `/app?view=${model}${of === newest ? "" : `&v=${of}`}&step=${at}${lang}`;

  /// Who a comment may name here: the designer, then everybody who said
  /// something on the page, newest first, each once; {handle, name}.
  function people() {
    const found = new Map();
    const designer = document.querySelector(".shared-by a.who");
    const handle = /^(?:\/(?:de|fr|es))?\/u\/([a-z0-9-]{3,24})$/.exec(designer?.getAttribute("href") || "");
    if (handle) found.set(handle[1], { handle: handle[1], name: designer.querySelector(".names b")?.textContent || handle[1] });
    for (const one of [...(state?.comments || [])].reverse()) {
      if (one.handle && !found.has(one.handle)) found.set(one.handle, { handle: one.handle, name: one.by || one.handle });
      for (const named of one.mentions || []) if (!found.has(named.handle)) found.set(named.handle, named);
    }
    return [...found.values()];
  }
  pickMentions(box, people);

  /// Somebody signed out may say something: the box is everybody's, and
  /// sending signs them in first. Whether they may then is the server's.
  const mayTry = () => state.you?.may_write || (!state.you?.signed_in && state.open);

  /// The pins in the answer, numbered oldest first, resolved ones too, as
  /// the studio numbers them (src/ui/part_pins.gd), for the 3D view; and,
  /// once the page has loaded, their parts' names asked for.
  function pinsOf() {
    const order = (a, b) => (Date.parse(a.at) - Date.parse(b.at)) || (a.id - b.id);
    const pinned = state.pins === true ? (state.comments || []).filter((one) => one.pin && !one.parent).sort(order) : [];
    pinNumber = new Map(pinned.map((one, k) => [one.id, k + 1]));
    pinBridge.pins = pinned.map((one) => ({ id: one.id, n: pinNumber.get(one.id), pin: one.pin, resolved: Boolean(one.resolved),
      version: one.version }));
    pinBridge.open = state.pins === true && Boolean(state.open) && Boolean(mayTry());
    if (pinned.length && !lotsAsked && partLots) {
      lotsAsked = true;
      const ask = () => partLots().then((got) => {
        lots = Array.isArray(got) ? got : null;
        if (lots) draw();
      });
      if (document.readyState === "complete") ask();
      else addEventListener("load", ask, { once: true });
    }
  }

  /// A part's name in the page's language, from the Parts list: of its
  /// number in its colour, else in any; "" while it is not known.
  function nameOf(part, colour) {
    if (!lots) return "";
    const want = pinPart(part);
    const found = lots.find((lot) => pinPart(lot.part) === want && Number(lot.colour) === Number(colour))
      || lots.find((lot) => pinPart(lot.part) === want);
    return found ? found.said || found.name || "" : "";
  }
  const capital = (words) => words.charAt(0).toLocaleUpperCase(globalThis.brickworksLang?.code || "en") + words.slice(1);

  /// A part pressed in 3D (its menu's Comment on this part): the box is on
  /// it, said over it, and in reach.
  function aim(part) {
    if (!pinBridge.open) return;
    aiming = part;
    drawChip();
    form.hidden = false;
    form.scrollIntoView({ block: "center", behavior: reduced ? "auto" : "smooth" });
    box.focus({ preventScroll: true });
  }
  function unaim(focus) {
    aiming = null;
    drawChip();
    pinBridge.view?.light(-1);
    if (focus) box.focus();
  }
  function drawChip() {
    chip.replaceChildren();
    chip.hidden = !aiming;
    if (!aiming) return;
    const tag = document.createElement("span");
    tag.className = "pill pin";
    tag.textContent = capital(pinSaid(nameOf(aiming.part, aiming.colour) || aiming.name || "", null));
    const cancel = button(say("Cancel"), () => unaim(true));
    cancel.setAttribute("aria-label", say("Cancel: comment on the whole model"));
    chip.append(tag, " ", cancel);
  }
  pinBridge.wanted = aim;
  pinBridge.name = nameOf;
  pinBridge.placed = (where) => {
    placed = new Map(where.map((one) => [one.id, one.index >= 0 ? { index: one.index, moved: one.moved } : null]));
    draw();
  };
  // A dot pressed in 3D: its comment marked, and a line of it for the view
  // to show.
  pinBridge.pressed = (id) => {
    for (const marked of section.querySelectorAll("li.comment.asked")) marked.classList.remove("asked");
    document.getElementById(`comment-${id}`)?.classList.add("asked");
    const one = (state?.comments || []).find((comment) => comment.id === id);
    if (!one) return "";
    const letters = [...one.body];
    return `${number(pinNumber.get(id) || 0)}. ${one.by || say("A builder")}: ${letters.length > 90 ? `${letters.slice(0, 90).join("")}…` : one.body}`;
  };

  /// A pin's line: its number, and the part and step it is on, as the 3D
  /// view placed it on this version (before it has, on its own version as
  /// it was made); pressed, the 3D view turned to it. Words alone where it
  /// is on no part of this one, or there is no 3D view.
  function pinLine(one) {
    const line = document.createElement("p");
    line.className = "comment-pin";
    const n = pinNumber.get(one.id) || 0;
    const badge = document.createElement("span");
    badge.className = "pin-n";
    badge.setAttribute("aria-hidden", "true");
    badge.textContent = number(n);
    const here = one.version === version;
    const where = placed.get(one.id);
    const name = nameOf(one.pin.part, one.pin.colour);
    const words = where || (where === undefined && here)
      ? `${pinSaid(name, here ? one.step : one.on_step ?? null)}${where?.moved ? ` ${say("(moved since)")}` : ""}`
      : say("{where}, on version {version}", { where: pinSaid(name, one.step), version: number(one.version) });
    if (where === null || !pinBridge.view) {
      const plain = document.createElement("span");
      plain.textContent = words;
      line.classList.toggle("gone", where === null);
      line.append(badge, plain);
      return line;
    }
    const go = button(words, (event) => {
      frame?.scrollIntoView({ block: "center", behavior: reduced ? "auto" : "smooth" });
      pinBridge.view.showPin(one.id, event.detail === 0 ? "key" : event.pointerType || "mouse");
    }, "link pin-go");
    go.setAttribute("aria-label", say("Pin {n}, {where}: show it in 3D", { n: number(n), where: words }));
    line.append(badge, go);
    return line;
  }

  async function resolve(one) {
    const answer = await call("/api/people?op=pin_resolve", { method: "POST", body: { id: one.id, resolved: !one.resolved } });
    if (answer.status !== 200) return tell(told(answer.body.error, say("That did not work just now.")));
    tell(one.resolved ? say("Open again.") : say("Resolved: folded away under Resolved."));
    await load();
  }

  /// One comment or reply: the avatar, who (a link to their page), the
  /// Designer pill on the model's owner's, the step as a pill that opens
  /// the viewer there, when, the words, and what the reader may do.
  function item(one, reply, replies) {
    const made = document.createElement("li");
    made.className = `comment${reply ? " reply" : ""}${one.hidden ? " hidden-one" : ""}${one.by_owner ? " by-owner" : ""}`;
    made.id = `comment-${one.id}`;
    made.dataset.step = one.step ?? "";
    const face = document.createElement("template");
    face.innerHTML = avatarHtml({ handle: one.handle || "", name: one.by || "A builder", picture: one.picture },
      { size: reply ? "small" : "" });
    const main = document.createElement("div");
    main.className = "comment-main";
    const head = document.createElement("p");
    head.className = "comment-head";
    const who = one.handle ? document.createElement("a") : document.createElement("b");
    if (one.handle) who.href = `${langAt()}/u/${encodeURIComponent(one.handle)}`;
    who.textContent = one.by || "A builder";
    head.append(who);
    if (one.by_owner) {
      const tag = document.createElement("span");
      tag.className = "pill designer";
      tag.textContent = say("Designer");
      head.append(" ", tag);
    }
    const pinned = Boolean(one.pin) && !reply && pinNumber.has(one.id);
    if (pinned && one.resolved) {
      const tag = document.createElement("span");
      tag.className = "pill resolved";
      tag.textContent = say("Resolved");
      head.append(" ", tag);
    }
    // A reply is on its comment's step: said once, on the comment; a
    // pin's, on its line.
    if (one.step && !reply && !pinned) {
      const pill = document.createElement("a");
      pill.className = "pill step";
      const here = one.on_step !== null && one.on_step !== undefined;
      pill.href = here ? viewerAt(version, one.on_step) : viewerAt(one.version, one.step);
      pill.textContent = here ? say("Step {n}", { n: one.on_step }) : say("Step {n} of version {version}", { n: one.step, version: one.version });
      pill.title = say("Open it at this step: said {where}", { where: whereSaid(one) });
      head.append(" ", pill);
    }
    const time = document.createElement("time");
    const at = Date.parse(one.at || "");
    if (Number.isFinite(at)) {
      time.dateTime = new Date(at).toISOString();
      time.textContent = `${DAY.format(at)}${one.edited_at ? ` · ${say("edited")}` : ""}`;
    }
    head.append(" ", time);
    // Said on an older version than the one shown, and not by its step.
    if (!reply && one.older && !(one.step && one.on_step === null)) {
      const where = document.createElement("span");
      where.className = "where";
      where.textContent = ` · ${whereSaid(one)}`;
      head.append(where);
    }
    const words = document.createElement("p");
    words.className = "comment-body";
    // Words as text; each @handle its writer named, a link to them.
    for (const piece of mentionPieces(one.body, one.mentions)) {
      if (typeof piece === "string") {
        words.append(piece);
        continue;
      }
      const link = document.createElement("a");
      link.className = "mention";
      link.href = `${langAt()}/u/${encodeURIComponent(piece.handle)}`;
      link.title = piece.name;
      link.textContent = piece.at;
      words.append(link);
    }
    main.append(head);
    if (pinned) main.append(pinLine(one));
    main.append(words);
    if (one.hidden) {
      const note = document.createElement("p");
      note.className = "note";
      const owner = state.you?.owner;
      note.textContent = reply ? (owner ? say("Hidden: only you and its author see this reply.")
        : say("Its designer hid this reply: only you and they see it."))
        : replies.length ? (owner ? say("Hidden: only you and its author see this comment and its replies.")
          : say("Its designer hid this comment and its replies: only you and they see it."))
        : owner ? say("Hidden: only you and its author see this comment.")
        : say("Its designer hid this comment: only you and they see it.");
      main.append(note);
    }
    const acts = document.createElement("p");
    acts.className = "comment-acts";
    if (!reply && state.replies && state.open && !one.hidden && mayTry()) {
      const answer = button(say("Reply"), () => openReply(one.id));
      answer.dataset.reply = String(one.id);
      // Whose, for a screen reader's list of buttons: six "Reply" say nothing.
      answer.setAttribute("aria-label", one.by ? say("Reply to {name}", { name: one.by }) : say("Reply to a builder"));
      acts.append(answer);
    }
    if (state.you?.owner && pinned) acts.append(button(one.resolved ? say("Open it again") : say("Resolve"), () => resolve(one)));
    if (state.you?.owner) {
      acts.append(button(one.hidden ? say("Show it") : say("Hide it"), () => change(one, one.hidden ? "show" : "hide")));
    }
    if (one.mine) {
      const asked = { title: reply ? say("Remove your reply?") : say("Remove your comment?"),
        body: !reply && replies.length ? say("Its replies go with it.") : "", yes: say("Remove it"), danger: true };
      acts.append(button(say("Remove it"), async () => (await ask(asked)) && change(one, "remove")));
    }
    if (!one.mine) acts.append(button(say("Report it"), () => openReport({ comment: one.id }, reply ? say("this reply") : say("this comment"))));
    // Block its writer (web/block.js): asked first in one line; their
    // comments then leave the page as the server says.
    if (!one.mine && one.handle && state.you?.signed_in) {
      const name = one.by || one.handle;
      const block = button(say("Block"), async () => {
        block.disabled = true;
        const done = await blockPerson(one.handle, name, true);
        block.disabled = false;
        if (done.ok) await load();
        if (done.said) tell(done.said);
      });
      block.dataset.blockComment = one.handle;
      block.setAttribute("aria-label", say("Block {name}", { name }));
      acts.append(block);
    }
    main.append(acts);
    if (!reply) {
      const under = document.createElement("ol");
      under.className = "replies";
      under.hidden = replies.length === 0;
      for (const answer of replies) under.append(item(answer, true, []));
      main.append(under);
    }
    made.append(face.content.firstElementChild, main);
    return made;
  }

  function draw() {
    // Each thread a comment and its replies: the newest thread first, its
    // replies oldest first, as the conversation went.
    const all = state.comments || [];
    const under = new Map();
    for (const one of all) {
      if (one.parent) under.set(one.parent, [...(under.get(one.parent) || []), one]);
    }
    const order = (a, b) => (Date.parse(a.at) - Date.parse(b.at)) || (a.id - b.id);
    const threads = all.filter((one) => !one.parent).sort((a, b) => order(b, a));
    // A person on the keyboard pressed something in a comment (Hide it,
    // Show it): the same comment's button keeps the focus once it is drawn
    // again, else the comment, else the list's heading, never the body.
    const within = (element) => list.contains(element) || fold.contains(element);
    const at = within(document.activeElement) && document.activeElement !== foldSaid ? document.activeElement : null;
    const where = at && { comment: at.closest("li.comment")?.id, words: at.localName === "button" ? at.textContent : "" };
    // A pin its designer resolved, folded away under Resolved.
    const done = (one) => Boolean(one.pin && one.resolved && pinNumber.has(one.id));
    const folded = threads.filter(done);
    list.replaceChildren(...threads.filter((one) => !done(one)).map((one) => item(one, false, (under.get(one.id) || []).sort(order))));
    foldList.replaceChildren(...folded.map((one) => item(one, false, (under.get(one.id) || []).sort(order))));
    foldSaid.textContent = say("Resolved ({n})", { n: number(folded.length) });
    fold.hidden = folded.length === 0;
    if (where && !within(document.activeElement) && !document.querySelector("form.reply-new")) {
      const again = where.comment && document.getElementById(where.comment);
      const pressed = again && [...again.querySelectorAll(":scope > .comment-main > .comment-acts button")]
        .find((one) => one.textContent === where.words);
      const heading = document.getElementById("comments-h");
      const to = pressed || again || heading;
      if (to && to.tabIndex < 0 && to.localName !== "button") to.tabIndex = -1;
      to?.focus({ preventScroll: true });
    }
    // None yet: one line, and the box under it.
    const empty = threads.length === 0;
    section.querySelector(".comments-lede").hidden = empty;
    if (empty) {
      const none = document.createElement("li");
      none.className = "note none";
      none.textContent = state.open ? say("Nobody has commented yet.") : say("No comments.");
      list.append(none);
    }
    const you = state.you || {};
    form.hidden = !mayTry();
    why.replaceChildren();
    why.hidden = !you.signed_in || Boolean(you.may_write);
    if (you.signed_in && !you.may_write) {
      const words = document.createElement("p");
      words.className = "note";
      words.textContent = told(you.why_not);
      why.append(words);
    }
    if (!you.signed_in && !state.open) {
      const words = document.createElement("p");
      words.className = "note";
      words.textContent = say("Comments are off for this model.");
      why.hidden = false;
      why.append(words);
    }
    if (you.owner) {
      const line = document.createElement("p");
      line.className = "note owner-line";
      line.append(`${state.open ? say("Comments are on for this model.") : say("Comments are off for this model.")} `,
        button(state.open ? say("Turn them off") : say("Turn them on"), () => setOpen(!state.open)));
      why.hidden = false;
      why.append(line);
    }
    if (replying) openReply(replying.id, replying.text, false);
    // Opened at a comment (an email's link, a notification's, the admin
    // page's): marked.
    const named = /^#comment-\d+$/.test(location.hash) ? document.getElementById(location.hash.slice(1)) : null;
    if (named && !draw.shown) {
      draw.shown = true;
      if (fold.contains(named)) fold.open = true;
      named.classList.add("asked");
      pageTabs?.show("comments", { push: false });
      named.scrollIntoView({ block: "center" });
    }
  }

  /// The reply box under thread [to], with [text] in it.
  function openReply(to, text = "", focus = true) {
    const thread = document.getElementById(`comment-${to}`);
    if (!thread || thread.classList.contains("reply")) {
      replying = null;
      return;
    }
    for (const open of list.querySelectorAll("form.reply-new")) if (open.dataset.to !== String(to)) open.remove();
    let made = thread.querySelector("form.reply-new");
    if (!made) {
      // The composer, as everywhere (web/composer.js): Ctrl+Enter or Post
      // sends it, Enter is a new line, Cancel or Escape takes it away, the
      // focus back on Reply; signed out, Post signs them in first.
      made = makeComposer({ id: `reply-${to}`, label: say("Your reply"),
        placeholder: say("Reply to {name}", { name: thread.querySelector(".comment-head a, .comment-head b")?.textContent || say("them") }) });
      made.classList.add("reply-new");
      made.dataset.to = String(to);
      const field = made.querySelector("textarea");
      const cancel = () => {
        replying = null;
        made.remove();
        thread.querySelector(`[data-reply="${to}"]`)?.focus();
      };
      wireComposer(made, {
        said,
        signIn: "Sign in to add your reply: we email you a code, no password. What you wrote is kept.",
        ready: async () => {
          await load();
          return state.you?.may_write ? "" : told(state.you?.why_not, say("That did not go just now. Try again in a minute."));
        },
        send: async (words) => {
          const answer = await call("/api/people?op=reply", { method: "POST", body: { id: to, body: words } });
          return answer.status === 201 ? { ok: true, made: answer.body.comment } : { ok: false, error: told(answer.body?.error) };
        },
        close: cancel,
        done: async (comment) => {
          replying = null;
          tell(say("Posted."));
          await load();
          // The reply, read out where it now is; else its comment's Reply.
          const there = document.getElementById(`comment-${comment?.id}`);
          if (there) {
            there.tabIndex = -1;
            there.focus({ preventScroll: true });
            there.scrollIntoView({ block: "nearest" });
          } else document.querySelector(`[data-reply="${to}"]`)?.focus();
        },
      });
      field.addEventListener("input", () => {
        replying = { id: to, text: field.value };
      });
      pickMentions(field, people);
      thread.querySelector(".comment-main").append(made);
    }
    const field = made.querySelector("textarea");
    if (text && !field.value) field.value = text;
    replying = { id: to, text: field.value };
    if (focus) field.focus();
  }

  async function change(one, what) {
    const answer = await call("/api/people?op=comment_change", { method: "POST", body: { id: one.id, what } });
    if (answer.status !== 200) return tell(told(answer.body.error, say("That did not work just now.")));
    tell(what === "remove" ? say("Removed.") : what === "hide" ? say("Hidden from everybody but you and its author.") : say("Shown again."));
    await load();
  }

  async function setOpen(open) {
    const answer = await call(`/api/people?op=comments_open&id=${model}`, { method: "POST", body: { open } });
    if (answer.status !== 200) return tell(told(answer.body.error, say("That did not work just now.")));
    tell(open ? say("Comments are on.") : say("Comments are off: what was said stays, and nobody can add more."));
    await load();
  }

  // The page's own box, the composer as everywhere (web/composer.js).
  wireComposer(form, {
    field: box,
    button: send,
    said,
    signIn: "Sign in to add your comment: we email you a code, no password. What you wrote is kept.",
    ready: async () => {
      await load();
      return state.you?.may_write ? "" : told(state.you?.why_not, say("That did not go just now. Try again in a minute."));
    },
    send: async (words) => {
      const at = step.value === "" ? null : Number(step.value);
      // On the part pressed in 3D: a pin, the part as the 3D view had it.
      const part = aiming && { part: aiming.part, colour: aiming.colour, at: aiming.at, turn: aiming.turn };
      const answer = await call(part ? "/api/people?op=pin" : "/api/people?op=comment", { method: "POST",
        body: { model, version, step: at, body: words, ...(part ? { part } : {}) } });
      return answer.status === 201 ? { ok: true, made: { at, part } } : { ok: false, error: told(answer.body?.error) };
    },
    done: async ({ at, part }) => {
      if (part) unaim(false);
      tell(at ? say("Posted, on step {n}.", { n: at }) : say("Posted."));
      await load();
    },
  });

  load();
  // Signed in from the header (signinux): drawn for them, where they are.
  addEventListener("brickworks:signed-in-done", () => load());
}

// What the app found of this model as it was published, for its owner
// alone: a model that failed one of the four tests says which, plainly, as
// a note to its designer. api/share.js ?op=tested answers only the model's
// own account, so nobody else is ever shown a failure.
const note = document.getElementById("tested-note");
if (note && /^[A-Za-z0-9]{10}$/.test(note.dataset.id || "") && signedIn()) noteForOwner(note);

// "I built it" (supabase/builds.sql): a photo of a real build, with a line,
// for somebody signed in; and for the model's owner, a way to hide a photo
// on it and to show it again. The photo goes from this page straight to
// storage, to an address the server signed for it (a function takes no
// body over 4.5 MB, and a phone's photo can be 8), and the server then
// makes it safe and keeps it (api/_photo.js): nothing of the file but its
// pixels is ever shown.
const builds = document.getElementById("add-build");
if (builds && /^[A-Za-z0-9]{10}$/.test(builds.dataset.id || "")) buildPhotos(builds);

function buildPhotos(box) {
  const model = box.dataset.id;
  const open = box.querySelector("[data-add-build]");
  const form = box.querySelector("form.build-form");
  const file = form.querySelector('input[type="file"]');
  const words = form.querySelector('input[name="words"]');
  const said = form.querySelector(".said");
  const buildSaid = box.querySelector(".build-said");
  const strip = () => document.querySelector("#builds .build-strip");
  const pictures = document.getElementById("pictures");
  const addPicture = pictures && pictures.querySelector("[data-add-picture]");
  const MOST = 8 * 1024 * 1024;
  let state = null;
  box.hidden = false;
  // The owner's own pictures go the same way, from the strip's last tile.
  addPicture?.addEventListener("click", () => {
    pageTabs?.show("builds");
    document.getElementById("builds")?.scrollIntoView({ block: "start" });
    open.click();
  });

  const tell = (text) => { said.textContent = text; };

  /// The photos as the caller may act on them: their own, and as the
  /// model's owner, every one with Hide (or Show again).
  async function load() {
    if (!signedIn()) return;
    const answer = await call(`/api/people?op=photos&id=${model}`);
    if (answer.status !== 200) return;
    state = answer.body;
    if (state.left === 0) open.textContent = say("You have added three photos: the most");
    else if (state.owner) open.textContent = say("Add a picture of it");
    open.disabled = state.left === 0;
    if (state.owner) ownerTools(state.photos || []);
    // Its owner adds pictures of their own under the picture: they lead
    // the strip (api/share.js mediaStrip). With no strip yet, Add a picture
    // is over the picture's corner, where its coming moves nothing: the
    // strip shown for it alone pushed the page down (site275).
    if (state.owner && addPicture) {
      if (pictures.hidden) {
        addPicture.className = "cta ghost small on-picture";
        pictures.before(addPicture);
      }
      addPicture.hidden = false;
      addPicture.disabled = state.left === 0;
      addPicture.textContent = state.left === 0 ? say("Three added") : say("Add a picture");
    }
    document.documentElement.dataset.buildPhotos = state.owner ? "owner" : "ready";
  }

  /// The model's owner's: Hide on each photo shown, and the hidden ones in
  /// a list of their own with Show again.
  function ownerTools(photos) {
    for (const old of document.querySelectorAll("#builds .owner-only")) old.remove();
    const hidden = document.createElement("div");
    hidden.className = "owner-only hidden-builds";
    for (const photo of photos) {
      const figure = document.getElementById(`photo-${photo.id}`);
      if (!photo.hidden && figure) {
        const hide = document.createElement("button");
        hide.type = "button";
        hide.className = "link owner-only";
        hide.dataset.hide = photo.id;
        hide.textContent = say("Hide");
        hide.addEventListener("click", () => setHidden(photo.id, true, hide));
        figure.querySelector("figcaption").append(" ", hide);
      } else if (photo.hidden) {
        const row = document.createElement("p");
        row.className = "note";
        row.dataset.hidden = photo.id;
        row.textContent = `${photo.by ? say("Hidden by you: a photo by {name}", { name: photo.by.name })
          : say("Hidden by you: a photo by a builder")}${photo.words ? `, “${photo.words}”` : ""}. `;
        const show = document.createElement("button");
        show.type = "button";
        show.className = "link";
        show.dataset.show = photo.id;
        show.textContent = say("Show it again");
        show.addEventListener("click", () => setHidden(photo.id, false, show));
        row.append(show);
        hidden.append(row);
      }
    }
    if (hidden.childElementCount) box.after(hidden);
  }

  async function setHidden(photo, on, button) {
    button.disabled = true;
    const answer = await call("/api/people?op=photo_hide", { method: "POST", body: { photo, on } });
    button.disabled = false;
    if (answer.status !== 200) {
      buildSaid.textContent = told(answer.body.error, say("That did not work just now."));
      return;
    }
    if (on) document.getElementById(`photo-${photo}`)?.remove();
    buildSaid.textContent = on ? say("Hidden: nobody else sees it now.") : say("Shown again: reload to see it in the strip.");
    await load();
    document.documentElement.dataset.buildHidden = on ? photo : "";
  }

  open.addEventListener("click", async () => {
    if (!signedIn() && !(await askToSignIn("Sign in to add a photo of your build: we email you a code, no password."))) return;
    await load();
    if (state && state.left === 0) return;
    form.hidden = false;
    open.hidden = true;
    file.focus();
  });
  form.querySelector("[data-cancel]").addEventListener("click", () => {
    form.hidden = true;
    open.hidden = false;
    tell("");
  });

  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const photo = file.files && file.files[0];
    if (!photo) return tell(say("Choose a photo of your build first."));
    if (!["image/jpeg", "image/png", "image/webp"].includes(photo.type)) {
      return tell(say("That is not a JPEG, a PNG or a WebP photo."));
    }
    if (photo.size > MOST) {
      const size = Number((photo.size / 1048576).toFixed(1)).toLocaleString(LOCALE, { minimumFractionDigits: 1 });
      return tell(say("That photo is {size} MB: at most 8 MB, please.", { size }));
    }
    const send = form.querySelector('button[type="submit"]');
    send.disabled = true;
    try {
      // A name first, once, as before a comment (web/account.js nameFirst):
      // the photo shows under it; made or skipped, it then goes.
      await nameFirst();
      tell(say("Sending the photo…"));
      const start = await call("/api/people?op=photo_start", { method: "POST",
        body: { model, type: photo.type, size: photo.size } });
      if (start.status !== 200) return tell(told(start.body.error, say("That did not work just now.")));
      const headers = { "content-type": photo.type, "x-upsert": "false" };
      if (start.body.key) headers.apikey = start.body.key;
      const sent = await fetch(start.body.upload, { method: "PUT", headers, body: photo });
      if (!sent.ok) return tell(say("The photo did not go: try again in a minute."));
      tell(say("Making it safe to show: taking out where and when it was taken…"));
      const kept = await call("/api/people?op=photo", { method: "POST",
        body: { model, ticket: start.body.ticket, words: words.value } });
      if (kept.status !== 201) return tell(told(kept.body.error, say("That did not work just now.")));
      shown(kept.body);
      form.reset();
      form.hidden = true;
      open.hidden = false;
      tell("");
      buildSaid.textContent = say("Added. Thank you for building it.");
      await load();
      document.documentElement.dataset.buildPhoto = kept.body.id;
    } finally {
      send.disabled = false;
    }
  });

  /// A photo just added, at the front of the strip, made of text and its
  /// address only.
  function shown(photo) {
    let row = strip();
    if (!row) {
      row = document.createElement("div");
      row.className = "build-strip scroller";
      row.setAttribute("role", "group");
      row.setAttribute("aria-labelledby", "builds-h");
      document.querySelector("#builds .no-builds")?.replaceWith(row);
    }
    const figure = document.createElement("figure");
    figure.className = "build";
    figure.id = `photo-${photo.id}`;
    figure.dataset.photo = photo.id;
    const img = document.createElement("img");
    img.alt = say("Your build");
    img.width = photo.width;
    img.height = photo.height;
    setPhoto(img, photo, "strip");
    const caption = document.createElement("figcaption");
    if (photo.words) {
      const line = document.createElement("q");
      line.textContent = photo.words;
      caption.append(line);
    }
    const by = document.createElement("span");
    by.className = "by";
    by.textContent = photo.by ? `by ${photo.by.name} · just now` : "by you · just now";
    caption.append(by);
    figure.append(img, caption);
    row.prepend(figure);
    sharpPhotos(figure);
    // And in the strip under the picture: the owner's with theirs, first.
    if (pictures) {
      const thumb = document.createElement("a");
      thumb.className = "thumb";
      thumb.href = `#photo-${photo.id}`;
      // The picture's place shows it whole; the thumb, its card's copy.
      thumb.dataset.picture = photoSrc(photo.id);
      if (state?.owner) thumb.dataset.own = "";
      const small = document.createElement("img");
      small.alt = state?.owner ? say("Your picture of it") : say("Your build");
      setPhoto(small, photo, "thumb");
      thumb.append(small);
      const own = pictures.querySelectorAll("a.thumb[data-own]");
      const after = state?.owner ? pictures.querySelector("a.thumb:not([href^='#'])") : own[own.length - 1]
        || pictures.querySelector("a.thumb:not([href^='#'])");
      if (after) after.after(thumb);
      else pictures.prepend(thumb);
      pictures.hidden = false;
      sharpPhotos(thumb);
    }
  }

  load();
  // Signed in from the header (signinux): drawn for them, where they are.
  addEventListener("brickworks:signed-in-done", () => load());
}

async function noteForOwner(note) {
  const version = /^[1-9][0-9]{0,5}$/.test(note.dataset.version || "") ? `&v=${note.dataset.version}` : "";
  const answer = await call(`/api/share?op=tested&id=${note.dataset.id}${version}`);
  const tested = answer.status === 200 && answer.body ? answer.body.tested : null;
  if (!tested || tested.passed) return;
  const names = await namesSaid();
  const head = document.createElement("b");
  head.textContent = tested.cleared ? say("Not marked Tested: Brickworks cleared its mark.") : say("Not marked Tested.");
  note.replaceChildren(head, ` ${say("Only you see this.")} `);
  for (const name of ["stands", "steps", "parts", "whole"]) {
    const one = tested.tests && tested.tests[name];
    if (!one || one.ok) continue;
    const line = document.createElement("span");
    line.dataset.failed = name;
    line.append(`${say(one.said)}${stop(":")}`);
    whySaid(one.why, names).forEach(([words, said], at) => {
      if (at) line.append(stop(";"));
      // A piece it has no words for, as the app wrote it, is English, and
      // so is a name in a piece said that the catalogue has no words for.
      if (!said) line.append(Object.assign(document.createElement("span"), { lang: "en", textContent: words }));
      else {
        (at ? words : afterColon(words)).split(/\u0001(.*?)\u0002/).forEach((text, odd) => {
          if (odd % 2) line.append(Object.assign(document.createElement("span"), { lang: "en", textContent: text }));
          else if (text) line.append(text);
        });
      }
    });
    line.append(". ");
    note.append(line);
  }
  note.hidden = false;
  document.documentElement.dataset.testedNote = "shown";
}

/// The model's parts and colours as its parts list names them in the
/// page's language (api/_parts.js namesOf): {parts, colours}, each a Map
/// from the name the app writes (src/assembly/tested.gd _named, the
/// catalogue's colour name) to the name said; null on an English page.
async function namesSaid() {
  const code = globalThis.brickworksLang?.code || "en";
  const list = document.getElementById("parts")?.dataset.parts;
  if (code === "en") return null;
  const names = { parts: new Map(), colours: new Map() };
  if (!list) return names;
  const from = new URL(list, location.href);
  from.searchParams.set("lang", code);
  const body = await fetch(from).then((answer) => (answer.ok ? answer.json() : null)).catch(() => null);
  for (const lot of Array.isArray(body?.lots) ? body.lots : []) {
    let named = String(lot.name || "").replace(/^~/, "");
    if (lot.custom) named = named.replace(/ \(custom element\)$/, "");
    if (lot.said) names.parts.set(named, lot.said);
    if (lot.colour_said) names.colours.set(lot.colour_name, lot.colour_said);
  }
  return names;
}

/// A part or colour [name] the app wrote, as [said] (a Map of namesSaid)
/// says it; one it has no words for stays as the app wrote it, marked
/// English between U+0001 and U+0002 (noteForOwner).
const nameSaid = (name, said) => (said ? said.get(name) || `\u0001${name}\u0002` : name);

/// A colon or semicolon and the space after it, as the page's language
/// sets them: French with a narrow space before, as its own words have it.
const stop = (sign) => (globalThis.brickworksLang?.code === "fr" ? `\u202f${sign} ` : `${sign} `);

/// [said], a whole sentence after a colon, opened as the page's language
/// opens one: German with a capital letter, French and Spanish as it is.
const afterColon = (said) => (globalThis.brickworksLang?.code === "de"
  ? said.replace(/^(\u0001?)(\p{Ll})/u, (all, mark, letter) => mark + letter.toUpperCase()) : said);

/// Why a model failed a test, as the app wrote it (src/assembly/tested.gd:
/// its pieces "; " apart), in the page's language a piece at a time:
/// [[words, said]], [said] false for a piece left as the app wrote it (one
/// cut short at the site's 300 characters, or words this has no entry
/// for). Its parts and colours are as [names] (namesSaid) says them.
function whySaid(why, names = null) {
  return String(why || "").split("; ").map((piece) => {
    const said = pieceSaid(piece, names);
    return said ? [said, true] : [piece, false];
  });
}

const whole = (text) => Number(String(text).replace(/,/g, "")) || 0;

/// One piece of a why (whySaid), said, or "" where it is not one the app
/// says.
function pieceSaid(piece, names) {
  const part = (name) => nameSaid(name, names?.parts);
  let m;
  if (/^Nothing in it stands on anything to weigh$/.test(piece)) return say("Nothing in it stands on anything to weigh");
  if ((m = /^Not finished: built to step ([\d,]+) of ([\d,]+) in the time a share takes(, standing at each|, each part on what was built, in sight)?$/.exec(piece))) {
    const at = { n: number(whole(m[1])), of: number(whole(m[2])) };
    if (m[3] === ", standing at each") return say("Not finished: built to step {n} of {of} in the time a share takes, standing at each", at);
    if (m[3]) return say("Not finished: built to step {n} of {of} in the time a share takes, each part on what was built, in sight", at);
    return say("Not finished: built to step {n} of {of} in the time a share takes", at);
  }
  if ((m = /^and ([\d,]+) more (parts?|steps?|kinds?|pairs?|pieces?)$/.exec(piece))) {
    const one = whole(m[1]) === 1;
    const things = { part: () => (one ? say("part") : say("parts")), step: () => (one ? say("step") : say("steps")),
      kind: () => (one ? say("kind") : say("kinds")), pair: () => (one ? say("pair") : say("pairs")),
      piece: () => (one ? say("piece") : say("pieces")) }[m[2].replace(/s$/, "")];
    return say("and {n} more {things}", { n: number(whole(m[1])), things: things() });
  }
  if ((m = /^At step ([\d,]+) (.+)$/.exec(piece))) {
    const what = tipSaid(m[2], part);
    return what && say("At step {n}: {what}", { n: number(whole(m[1])), what: afterColon(what) });
  }
  if ((m = /^it does not come to rest within ([\d,]+) falls$/.exec(piece))) {
    return say("it does not come to rest within {falls}", { falls: counted(whole(m[1]), "fall") });
  }
  if ((m = /^Step ([\d,]+): (.+) is put down in the air$/.exec(piece))) {
    return say("Step {n}: {part} is put down in the air", { n: number(whole(m[1])), part: part(m[2]) });
  }
  if ((m = /^Step ([\d,]+): (.+) is hidden behind what is already built$/.exec(piece))) {
    return say("Step {n}: {part} is hidden behind what is already built", { n: number(whole(m[1])), part: part(m[2]) });
  }
  if ((m = /^(.+?)( \((\d+)\))? (in a colour typed in, not one parts are made in|made here, not a real element|never made in (.+))$/.exec(piece))) {
    const lot = m[3] ? `${part(m[1])} (${number(whole(m[3]))})` : part(m[1]);
    if (m[5]) return say("{part} never made in {colour}", { part: lot, colour: nameSaid(m[5], names?.colours) });
    return m[4].startsWith("made") ? say("{part} made here, not a real element", { part: lot })
      : say("{part} in a colour typed in, not one parts are made in", { part: lot });
  }
  if ((m = /^([\d,]+) pairs? of parts pass(?:es)? into each other: (.+)$/.exec(piece))) {
    const what = pieceSaid(m[2], names);
    const n = whole(m[1]);
    return what && say(n === 1 ? "{n} pair of parts passes into each other: {what}" : "{n} pairs of parts pass into each other: {what}",
      { n: number(n), what });
  }
  if ((m = /^(and )?([\d,]+) pieces? (?:is|are) held by nothing, and comes? away when the model is lifted: (.+)$/.exec(piece))) {
    const what = pieceSaid(m[3], names);
    const n = whole(m[2]);
    const said = what && say(n === 1 ? "{n} piece is held by nothing, and comes away when the model is lifted: {what}"
      : "{n} pieces are held by nothing, and come away when the model is lifted: {what}", { n: number(n), what });
    return said && m[1] ? say("and {what}", { what: said }) : said;
  }
  if ((m = /^(.+) into (.+) by ([\d.]+) LDU$/.exec(piece))) {
    return say("{part} into {other} by {ldu} LDU", { part: part(m[1]), other: part(m[2]), ldu: number(Number(m[3])) });
  }
  if ((m = /^(.+?)(?: and ([\d,]+) parts? with it)? (stands against (.+)|leans on the rest to stand|stands on (.+) where it has no stud|rests on (.+)|rests where it is|falls off (.+)|falls)$/.exec(piece))) {
    const who = m[2] ? say("{part} and {parts} with it", { part: part(m[1]), parts: counted(whole(m[2]), "part") }) : part(m[1]);
    const how = m[3];
    if (m[4]) return say("{who} stands against {part}", { who, part: part(m[4]) });
    if (m[5]) return say("{who} stands on {part} where it has no stud", { who, part: part(m[5]) });
    if (m[6]) return say("{who} rests on {part}", { who, part: part(m[6]) });
    if (m[7]) return say("{who} falls off {part}", { who, part: part(m[7]) });
    if (how === "leans on the rest to stand") return say("{who} leans on the rest to stand", { who });
    if (how === "rests where it is") return say("{who} rests where it is", { who });
    return say("{who} falls", { who });
  }
  return "";
}

/// How a build tipped at a step, as src/assembly/topple.gd words and
/// tested.gd's weighing say it, said, its parts as [part] says them; ""
/// where it is not.
function tipSaid(tip, part) {
  let m;
  if ((m = /^(?:it (tipped over .+), and )?(.+?) (hangs from|is held by) (.+) on ([\d,]+) studs? past where it lets go$/.exec(tip))) {
    const at = { part: part(m[2]), other: part(m[4]), studs: counted(whole(m[5]), "stud") };
    const held = m[3] === "hangs from" ? say("{part} hangs from {other} on {studs} past where it lets go", at)
      : say("{part} is held by {other} on {studs} past where it lets go", at);
    if (!m[1]) return held;
    const fell = fellSaid(m[1]);
    return fell && say("{fell}, and {what}", { fell, what: held });
  }
  if ((m = /^it (tipped over .+)$/.exec(tip))) return fellSaid(m[1]);
  return "";
}

/// "tipped over to the left and lies on its side (it fell 2 times, 40° to
/// the left, 90° to the front)" (Topple.words), said: "" where it is not.
function fellSaid(fell) {
  const m = /^tipped over to the ([a-z-]+) and (.+?)(?: \(it fell ([\d,]+) times, (.+)\))?$/.exec(fell);
  const way = m && waySaid(m[1]);
  const lies = m && liesSaid(m[2]);
  if (!way || !lies) return "";
  const said = say("it tipped over {way} and {lies}", { way, lies });
  if (!m[3]) return said;
  const falls = m[4].split(", ").map((one) => {
    const fall = /^(\d+)° to the ([a-z-]+)$/.exec(one);
    const to = fall && waySaid(fall[2]);
    return to ? say("{degrees}° {way}", { degrees: number(whole(fall[1])), way: to }) : "";
  });
  if (falls.some((one) => !one)) return "";
  return `${said} ${say("(it fell {n} times: {falls})", { n: number(whole(m[3])), falls: falls.join(", ") })}`;
}

/// Which way a build tipped (Balance.edge_name), said; "" for none of them.
function waySaid(way) {
  return ({ right: () => say("to the right"), "front-right": () => say("to the front right"), front: () => say("to the front"),
    "front-left": () => say("to the front left"), left: () => say("to the left"), "back-left": () => say("to the back left"),
    back: () => say("to the back"), "back-right": () => say("to the back right"),
    nearest: () => say("to the nearest edge") })[way]?.() || "";
}

/// How a build lies once it has fallen (Topple.words), said.
function liesSaid(lies) {
  const m = /^rests leaning (\d+)°, its far end on the floor$/.exec(lies);
  if (m) return say("rests leaning {degrees}°, its far end on the floor", { degrees: number(whole(m[1])) });
  return ({ "comes to rest still upright": () => say("comes to rest still upright"), "lies upside down": () => say("lies upside down"),
    "lies on its front": () => say("lies on its front"), "lies on its back": () => say("lies on its back"),
    "lies on its side": () => say("lies on its side") })[lies]?.() || "";
}

/// An icon button's count, and its name and count as its label ("Like, 12
/// likes"; "Like" at none), as web/kit.js iconButtonHtml draws them: a
/// count of none is not shown.
function setCount(button, n, name, one, many = `${one}s`) {
  if (!button) return;
  const value = Number(n) || 0;
  let shown = button.querySelector(".n");
  if (value && !shown) {
    shown = document.createElement("span");
    shown.className = "n";
    shown.setAttribute("aria-hidden", "true");
    button.append(shown);
  }
  if (shown && !value) shown.remove();
  else if (shown) shown.textContent = number(value);
  button.setAttribute("aria-label", value ? `${name}, ${counted(value, one, many)}` : name);
}

/// A tab's count (api/share.js pageTabs), never one of none.
function tabCount(tab, n) {
  const value = Number(n) || 0;
  let shown = tab.querySelector(".n");
  if (!value) return shown?.remove();
  if (!shown) {
    shown = document.createElement("span");
    shown.className = "n";
    tab.append(" ", shown);
  }
  shown.textContent = number(value);
}

/// The action bar (api/share.js actionBar): Like; Save and its lists,
/// which are a card's (web/keep.js: Save at a tap, the arrow beside it the
/// panel of your lists, lists2a); Share, which opens its sheet
/// (web/share-sheet.js); and More: Download, Report it, Takedown requests,
/// and the owner's own. Like asks to sign in first when this browser is
/// not, as Save does. Comments and builds are their tabs'.
function start() {
  const like = marks.querySelector('[data-mark="like"]');
  const share = marks.querySelector("[data-share]");
  const said = document.querySelector(".marks-said");
  let state = null;

  const tell = (text) => { said.textContent = text; };

  function draw() {
    like.setAttribute("aria-pressed", String(Boolean(state && state.liked)));
  }

  // Each read of how it stands, and each like made here, counted: a read asked before the latest of them answers what
  // was, and is dropped (sifix, 2026-11-15: a read still out when Like was
  // pressed drew it unpressed after it went through).
  let asked = 0;
  async function load() {
    if (!signedIn()) return;
    const mine = ++asked;
    const answer = await call(`/api/people?op=marks&id=${id}`);
    if (mine !== asked) return;
    if (answer.status === 200) {
      state = answer.body;
      draw();
    }
  }

  /// Signed in first, if this browser is not.
  async function ready(why) {
    if (signedIn() && state) return true;
    if (!signedIn() && !(await askToSignIn(why))) return false;
    await load();
    return Boolean(state);
  }

  // Drawn at once, as a card's like is, then as the server counts it; back
  // as it was, and why, if it refuses. Waiting on it took 420-470 ms (site273).
  like.addEventListener("click", async () => {
    if (!(await ready("Sign in to like it: we email you a code, no password."))) return;
    asked += 1;
    const was = Boolean(state.liked);
    const count = Number(like.querySelector(".n")?.textContent.replace(/\D/g, "")) || 0;
    state.liked = !was;
    setCount(like, Math.max(0, count + (was ? -1 : 1)), say("Like"), "like");
    tell("");
    draw();
    like.disabled = true;
    const answer = await call(`/api/people?op=like&id=${id}`, { method: "POST", body: { on: !was } })
      .catch(() => ({ status: 0, body: {} }));
    like.disabled = false;
    if (answer.status !== 200) {
      state.liked = was;
      setCount(like, count, say("Like"), "like");
      draw();
      return tell(told(answer.body.error, say("That did not work just now. Try again.")));
    }
    state.liked = answer.body.liked;
    setCount(like, answer.body.likes, say("Like"), "like");
    draw();
  });

  const sheet = document.getElementById("share-sheet");
  if (sheet) wireShare(share, sheet);

  load();
  // Signed in from the header (signinux): drawn for them, where they are.
  addEventListener("brickworks:signed-in-done", () => load());
}

/// What the comments, once listed, change: the Comments tab's count (the
/// ones everybody sees), the tab gone where comments are not open on this
/// deployment, and for the model's owner their own in More: comments off
/// or on, and their models' numbers, in place of Report it.
function commentsSaid(state, setOpen) {
  // What everybody sees: not hidden, and not under a comment that is.
  const hidden = new Set((state.comments || []).filter((one) => one.hidden).map((one) => one.id));
  const shown = (state.comments || []).filter((one) => !one.hidden && !hidden.has(one.parent)).length;
  const tab = document.querySelector('#page-tabs a[data-tab="comments"]');
  if (tab) {
    tab.hidden = state.ready === false;
    tabCount(tab, shown);
    // Opened on a tab that is not there: the first.
    if (tab.hidden && tab.getAttribute("aria-selected") === "true") pageTabs?.show("overview", { push: false });
  }
  if (!marks) return;
  const menu = marks.querySelector("#more .menu-list");
  for (const old of menu.querySelectorAll(".owner-only")) old.remove();
  if (!state.you?.owner) return;
  menu.querySelector("[data-report]")?.setAttribute("hidden", "");
  const turn = document.createElement("button");
  turn.type = "button";
  turn.className = "owner-only";
  turn.textContent = state.open ? say("Turn comments off") : say("Turn comments on");
  turn.addEventListener("click", () => {
    marks.querySelector("#more").open = false;
    setOpen(!state.open);
  });
  const numbers = document.createElement("a");
  numbers.className = "owner-only";
  numbers.href = `${langAt()}/profile#designs`;
  numbers.textContent = say("How your models are doing");
  menu.prepend(turn, numbers);
  document.documentElement.dataset.modelOwner = "yes";
  madeChoice(menu);
}

/// The owner's say in whether this page tells how it was made (api/share.js
/// ?op=made, supabase/made_with_shown.sql): for a model made with the
/// assistant or Brickify, one item in More, Say it was made with the
/// assistant (or Brickify) while nothing says so, and Stop saying it once
/// something does. Nothing for one built by hand, or before the column is
/// there to keep it. The fact among the page's own is put in or taken out
/// at once; everybody else's copy of the page says it within the minute.
async function madeChoice(menu) {
  const answer = await call(`/api/share?op=made&id=${id}`);
  const made = answer.status === 200 ? answer.body : null;
  if (!made || !made.ready || made.way !== "assistant") return;
  menu.querySelector("[data-made-choice]")?.remove();
  const brickify = made.by === "brickify";
  const item = document.createElement("button");
  item.type = "button";
  item.className = "owner-only";
  item.dataset.madeChoice = "";
  let shown = made.made_with_shown === true;
  const name = () => {
    item.textContent = shown
      ? say(brickify ? "Stop saying it was made with Brickify" : "Stop saying it was made with the assistant")
      : say(brickify ? "Say it was made with Brickify" : "Say it was made with the assistant");
    item.dataset.madeChoice = shown ? "shown" : "quiet";
  };
  name();
  item.addEventListener("click", async () => {
    marks.querySelector("#more").open = false;
    item.disabled = true;
    const sent = await call(`/api/share?op=made&id=${id}`, { method: "POST", body: { shown: !shown } });
    item.disabled = false;
    const said = document.querySelector(".marks-said");
    if (sent.status !== 200) {
      if (said) said.textContent = told(sent.body.error, say("That did not work just now."));
      return;
    }
    shown = sent.body.made_with_shown === true;
    name();
    madeFact(shown, brickify);
    if (said) {
      said.textContent = shown
        ? say(brickify ? "Its page now says it was made with Brickify." : "Its page now says it was made with the assistant.")
        : say("Its page no longer says how it was made.");
    }
  });
  menu.prepend(item);
}

/// The page's fact of how it was made (api/share.js madeFact), put in or
/// taken out as its owner chooses.
function madeFact(shown, brickify) {
  const facts = document.querySelector("ul.facts.pills");
  if (!facts) return;
  facts.querySelector("li.pill.made")?.remove();
  if (!shown) return;
  const fact = document.createElement("li");
  fact.className = "pill made";
  fact.title = say(brickify ? "Made from a 3D model with Brickify, {how}" : "Designed with the assistant, {how}",
    { how: say("as the app said when it was published") });
  fact.textContent = brickify ? "Brickify" : say("With the assistant");
  facts.append(fact);
}

// ---------------------------------------------------------------------------
// This month's challenge (api/_challenges.js): asked only with the sign-in,
// and answered only to the model's own designer, so nobody else is shown
// anything here. A line under Like and Save: Enter this month's
// challenge, which opens a dialog with its rules and a choice of how it was
// built; or that it is in, with Take it out.
async function challengeEntry() {
  const answer = await call(`/api/people?op=challenge_entry&id=${id}`);
  if (answer.status !== 200 || !answer.body.mine || !answer.body.challenge) return;
  const said = answer.body;
  let box = document.getElementById("challenge-entry");
  if (!box) {
    box = document.createElement("div");
    box.id = "challenge-entry";
    box.className = "challenge-entry";
    (document.querySelector(".marks-said") || marks).after(box);
  }
  box.replaceChildren();
  const line = document.createElement("p");
  line.className = "note";
  const named = document.createElement("a");
  named.href = `${langAt()}/challenge`;
  named.textContent = said.challenge.title;
  if (said.entry) {
    sayInto(line, said.entry.way === "assistant" ? say("In this month’s challenge, {challenge}, built with the assistant.")
      : say("In this month’s challenge, {challenge}, built by hand."), { challenge: named });
    line.append(" ");
    const out = document.createElement("button");
    out.type = "button";
    out.className = "link";
    out.textContent = say("Take it out");
    out.addEventListener("click", async () => {
      if (!(await ask({ title: say("Take it out of the challenge?"), body: say("Its votes go with it."), yes: say("Take it out"),
        danger: true }))) return;
      out.disabled = true;
      const gone = await call("/api/people?op=withdraw", { method: "POST", body: { model: id } });
      if (gone.status !== 200) {
        out.disabled = false;
        line.append(` ${told(gone.body.error, say("That did not work just now."))}`);
        return;
      }
      await challengeEntry();
    });
    line.append(out);
    box.append(line);
  } else {
    const ends = Date.parse(said.challenge.ends_on || "");
    sayInto(line, say("This month’s challenge is {challenge}, open until {day}."), { challenge: named,
      day: LOCALE !== "en-GB" && Number.isFinite(ends)
        ? new Intl.DateTimeFormat(LOCALE, { day: "numeric", month: "long", timeZone: "UTC" }).format(ends)
        : said.challenge.days_said.split(" to ")[1] });
    line.append(" ");
    const go = document.createElement("button");
    go.type = "button";
    go.className = "cta ghost small";
    go.dataset.enter = String(said.challenge.id);
    go.textContent = say("Enter this month’s challenge");
    go.addEventListener("click", () => enterDialog(said));
    box.append(line, go);
  }
  document.documentElement.dataset.challengeEntry = said.entry ? "entered" : "open";
}

/// The dialog: the rules, how it was built, and Enter it. The server checks
/// the rules on the model as it is stored and says which it breaks.
function enterDialog(said) {
  const dialog = document.createElement("dialog");
  dialog.className = "sign-in report enter";
  const title = document.createElement("h2");
  title.textContent = say("Enter “{title}”", { title: said.challenge.title });
  title.id = "enter-title";
  dialog.setAttribute("aria-labelledby", title.id);
  const lede = document.createElement("p");
  // Its rules said here, in the page's language, from the rules themselves
  // (a server before them said them in English: each its entry, told).
  const ruled = said.challenge.rules ? rulesSaid(said.challenge.rules) : (said.challenge.rules_said || []).map((one) => told(one));
  lede.textContent = ruled.length ? say("Brickworks checks its rules on this model as you shared it:") : say("It has no rules but its brief.");
  const rules = document.createElement("ul");
  for (const text of ruled) {
    const item = document.createElement("li");
    item.textContent = text;
    rules.append(item);
  }
  const form = document.createElement("form");
  const choices = document.createElement("fieldset");
  const legend = document.createElement("legend");
  legend.textContent = say("How did you build it? The two are judged apart.");
  choices.append(legend);
  for (const [value, words] of [["hand", say("By hand")], ["assistant", say("With the assistant")]]) {
    const row = document.createElement("label");
    row.className = "choice";
    const pick = document.createElement("input");
    pick.type = "radio";
    pick.name = "way";
    pick.value = value;
    pick.required = true;
    row.append(pick, document.createTextNode(` ${words}`));
    choices.append(row);
  }
  const status = document.createElement("div");
  status.className = "said";
  status.setAttribute("role", "status");
  const send = document.createElement("button");
  send.className = "cta";
  send.type = "submit";
  send.textContent = say("Enter it");
  const close = document.createElement("button");
  close.className = "cta ghost";
  close.type = "button";
  close.textContent = say("Cancel");
  const row = document.createElement("div");
  row.className = "actions";
  row.append(send, close);
  form.append(choices, row, status);
  dialog.append(title, lede, rules, form);
  document.body.append(dialog);
  const end = () => {
    dialog.close();
    dialog.remove();
  };
  close.addEventListener("click", end);
  dialog.addEventListener("cancel", end);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const way = (form.querySelector('input[name="way"]:checked') || {}).value;
    if (!way) return;
    send.disabled = true;
    status.textContent = say("Checking it against the rules…");
    const answer = await call("/api/people?op=enter", { method: "POST", body: { model: id, way } });
    send.disabled = false;
    if (answer.status !== 201) {
      status.replaceChildren();
      const broken = answer.body.check ? brokenSaid(answer.body.check)
        : (answer.body.broken || []).map((one) => ({ ...one, said: told(one.said) }));
      if (broken.length) {
        status.append(say("It does not keep the rules yet:"));
        const list = document.createElement("ul");
        for (const one of broken) {
          const item = document.createElement("li");
          item.dataset.rule = one.rule;
          item.textContent = one.said;
          list.append(item);
        }
        status.append(list);
      } else {
        status.textContent = told(answer.body.error, say("That did not go just now. Try again in a minute."));
      }
      document.documentElement.dataset.challengeRefused = answer.body.refused || "error";
      return;
    }
    form.replaceChildren();
    rules.remove();
    lede.textContent = way === "assistant" ? say("It is in, built with the assistant. People signed in vote until the challenge ends.")
      : say("It is in, built by hand. People signed in vote until the challenge ends.");
    const done = document.createElement("button");
    done.className = "cta";
    done.type = "button";
    done.textContent = say("Close");
    done.addEventListener("click", end);
    dialog.append(done);
    done.focus();
    await challengeEntry();
  });
  dialog.showModal();
}

// ---------------------------------------------------------------------------
// What it is based on (api/_bases.js, docs/SOCIAL.md section 7, item 5).

/// For the model's own designer alone (the answer's mine): a line under
/// what the page says it is based on, Say what it is based on or Change
/// what it is based on, which opens the dialog.
async function basesOwn() {
  const answer = await call(`/api/share?op=bases&id=${id}`);
  if (answer.status !== 200 || !answer.body.mine) return;
  postKitsOwn();
  // Before supabase/model_bases.sql there is nowhere to keep a list.
  if (!answer.body.ready) {
    document.documentElement.dataset.bases = "not-open";
    return;
  }
  let line = document.getElementById("bases-own");
  if (!line) {
    line = document.createElement("p");
    line.id = "bases-own";
    line.className = "from bases-own";
    const edit = document.createElement("button");
    edit.type = "button";
    edit.className = "link";
    edit.addEventListener("click", () => basesDialog(line.bases || []));
    line.append(edit);
    const side = document.querySelector(".model-page .side");
    const after = document.getElementById("based-on") || side?.querySelector(":scope > p.from:not(.modelled-by)")
      || side?.querySelector(":scope > .facts");
    if (!after) return;
    after.after(line);
  }
  showBases(line, answer.body.bases || []);
}

/// The page's lines for [said], and its designer's line to change them.
function showBases(line, said) {
  line.bases = said;
  document.getElementById("based-on")?.remove();
  if (said.length) {
    const made = document.createElement("template");
    made.innerHTML = basedHtml(said);
    line.before(made.content.firstElementChild);
  }
  line.querySelector("button").textContent = said.length ? say("Change what it is based on") : say("Say what it is based on");
  document.documentElement.dataset.bases = String(said.length);
}

/// The dialog: at most three, each how it is based on it, then a set (its
/// name or number typed, the set picked from what it may be) or a link, and
/// for a link its title, author and licence. The server checks the set
/// against the catalogue and says what is wrong in words.
function basesDialog(current) {
  const dialog = document.createElement("dialog");
  dialog.className = "sign-in report bases-dialog";
  const title = document.createElement("h2");
  title.textContent = say("What it is based on");
  title.id = "bases-title";
  dialog.setAttribute("aria-labelledby", title.id);
  const lede = document.createElement("p");
  lede.textContent = say("A LEGO® set you built it from or changed, or work elsewhere you changed or took ideas from. "
    + "Its page credits each, at most three.");
  const form = document.createElement("form");
  form.noValidate = true;
  const list = document.createElement("ol");
  list.className = "bases-rows";
  const add = document.createElement("button");
  add.type = "button";
  add.className = "link";
  add.textContent = say("Add another");
  const field = (labelText, input) => {
    const label = document.createElement("label");
    label.className = "field";
    label.append(document.createTextNode(labelText), input);
    return label;
  };
  const text = (name, most, hint = "") => {
    const input = document.createElement("input");
    input.type = "text";
    input.name = name;
    input.maxLength = most;
    input.autocomplete = "off";
    if (hint) input.placeholder = hint;
    return input;
  };
  const counted = () => {
    [...list.children].forEach((row, at) => { row.querySelector("legend").textContent = say("Based on, {n} of {all}", { n: at + 1, all: list.children.length }); });
    add.hidden = list.children.length >= 3;
  };
  const addRow = (one = {}) => {
    const row = document.createElement("li");
    const box = document.createElement("fieldset");
    const legend = document.createElement("legend");
    legend.className = "visually-hidden";
    const how = document.createElement("select");
    how.name = "how";
    for (const [value, words] of [["alternate", say("An alternate build of a set")], ["changed", HOWS.changed],
      ["inspired", HOWS.inspired]]) {
      const option = document.createElement("option");
      option.value = value;
      option.textContent = words;
      how.append(option);
    }
    how.value = one.how && HOWS[one.how] ? one.how : "alternate";
    const what = text("what", 300, say("Its name or number, or https://…"));
    what.id = `bases-what-${++basesRows}`;
    what.value = one.set || one.url || "";
    // The set picked, by its name, under the box.
    const chosen = document.createElement("p");
    chosen.className = "set-chosen";
    chosen.id = `${what.id}-set`;
    chosen.hidden = true;
    if (one.set && one.name) {
      chosen.textContent = `${one.set} ${one.name}`;
      chosen.hidden = false;
    }
    const linked = document.createElement("div");
    linked.className = "link-fields";
    const named = text("title", 120);
    named.value = one.url ? one.name || "" : "";
    const author = text("author", 80);
    author.value = one.author || "";
    const licence = text("licence", 60, "CC BY 4.0");
    licence.value = one.licence || "";
    linked.append(field(say("Its title"), named), field(say("Its author"), author), field(say("Its licence"), licence));
    const shown = () => { linked.hidden = !/^\s*https?:/i.test(what.value); };
    what.addEventListener("input", shown);
    shown();
    const remove = document.createElement("button");
    remove.type = "button";
    remove.className = "link";
    remove.textContent = say("Remove");
    remove.addEventListener("click", () => {
      row.remove();
      counted();
      add.focus();
    });
    const asked = field(say("A set, or a link"), what);
    box.append(legend, field(say("How"), how), asked, chosen, linked, remove);
    pickSet(what, chosen);
    row.append(box);
    list.append(row);
    counted();
    return row;
  };
  for (const one of current.slice(0, 3)) addRow(one);
  if (!current.length) addRow();
  add.addEventListener("click", () => addRow().querySelector("select").focus());
  const status = document.createElement("div");
  status.className = "said";
  status.setAttribute("role", "status");
  const send = document.createElement("button");
  send.className = "cta";
  send.type = "submit";
  send.textContent = say("Save");
  const close = document.createElement("button");
  close.className = "cta ghost";
  close.type = "button";
  close.textContent = say("Cancel");
  const actions = document.createElement("div");
  actions.className = "actions";
  actions.append(send, close);
  form.append(list, add, actions, status);
  dialog.append(title, lede, form);
  document.body.append(dialog);
  const end = () => {
    dialog.close();
    dialog.remove();
    document.querySelector("#bases-own button")?.focus();
  };
  close.addEventListener("click", end);
  dialog.addEventListener("cancel", end);
  form.addEventListener("submit", async (event) => {
    event.preventDefault();
    const bases = [...list.querySelectorAll("fieldset")].map((box) => {
      const value = (name) => box.querySelector(`[name="${name}"]`).value.trim();
      const what = value("what");
      if (!what) return null;
      return /^https?:/i.test(what)
        ? { how: value("how"), url: what, title: value("title"), author: value("author"), licence: value("licence") }
        : { how: value("how"), set: what };
    }).filter(Boolean);
    send.disabled = true;
    status.textContent = say("Saving…");
    const answer = await call("/api/share?op=bases", { method: "POST", body: { model: id, bases } });
    send.disabled = false;
    if (answer.status !== 200) {
      status.textContent = told(answer.body.error, say("That did not go just now. Try again in a minute."));
      document.documentElement.dataset.basesRefused = String(answer.status);
      return;
    }
    const line = document.getElementById("bases-own");
    if (line) showBases(line, answer.body.bases || []);
    end();
  });
  dialog.showModal();
  list.querySelector("select")?.focus();
}

let basesRows = 0;

/// The sets the dialog's box [field] may mean as a set's name or number is
/// typed in it (api/_bases.js setsFound, ?op=set_find), in a list under
/// it: each its picture, number, name, year, parts and theme. Up and Down
/// move, Enter or a click puts its number in the box and its name in
/// [chosen] under it; Escape closes the list (and only it). A link typed
/// asks nothing. The box is a combobox, its list a listbox, the one marked
/// its active descendant, and a status says how many there are.
function pickSet(field, chosen) {
  const list = document.createElement("ul");
  list.className = "pick-list set-pick";
  list.id = `${field.id}-sets`;
  list.setAttribute("role", "listbox");
  list.setAttribute("aria-label", say("Sets it may be"));
  list.hidden = true;
  const said = document.createElement("span");
  said.className = "visually-hidden";
  said.setAttribute("role", "status");
  chosen.before(list, said);
  field.setAttribute("role", "combobox");
  field.setAttribute("aria-autocomplete", "list");
  field.setAttribute("aria-expanded", "false");
  field.setAttribute("aria-controls", list.id);
  field.setAttribute("aria-describedby", chosen.id);
  const SET = /^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/;
  const found = new Map();
  let shown = [];
  let at = 0;
  let waiting = 0;

  const close = () => {
    list.hidden = true;
    shown = [];
    said.textContent = "";
    field.setAttribute("aria-expanded", "false");
    field.removeAttribute("aria-activedescendant");
  };
  const mark = (to) => {
    at = (to + shown.length) % shown.length;
    [...list.children].forEach((item, n) => item.setAttribute("aria-selected", String(n === at)));
    field.setAttribute("aria-activedescendant", list.children[at].id);
    list.children[at].scrollIntoView({ block: "nearest" });
  };
  const choose = (n) => {
    const one = shown[n];
    if (!one) return;
    field.value = one.set;
    chosen.textContent = `${one.set} ${one.name}${one.year ? `, ${one.year}` : ""}`;
    chosen.hidden = false;
    chosen.dataset.set = one.set;
    close();
  };
  const draw = (sets) => {
    shown = sets;
    if (!shown.length || document.activeElement !== field) return close();
    list.replaceChildren(...shown.map((one, n) => {
      const item = document.createElement("li");
      item.id = `${list.id}-${n}`;
      item.setAttribute("role", "option");
      item.dataset.set = one.set;
      // Its picture on its ground, shown once it has come; a set with no
      // picture, or one that does not come, keeps the ground alone.
      const ground = document.createElement("span");
      ground.className = "set-picture";
      if (one.picture) {
        const picture = document.createElement("img");
        picture.alt = "";
        picture.width = 48;
        picture.height = 36;
        picture.decoding = "async";
        picture.addEventListener("load", () => picture.classList.add("came"));
        picture.addEventListener("error", () => picture.remove());
        picture.src = one.picture;
        ground.append(picture);
      }
      const words = document.createElement("span");
      const name = document.createElement("b");
      name.textContent = `${one.set} ${one.name}`;
      const facts = document.createElement("small");
      facts.textContent = [one.year ? String(one.year) : "", one.parts ? counted(one.parts, "part") : "",
        one.theme ? themeSaid(one.theme) : ""].filter(Boolean).join(" · ");
      words.append(name, facts);
      item.append(ground, words);
      // Chosen without the box losing its focus.
      item.addEventListener("mousedown", (event) => {
        event.preventDefault();
        choose(n);
      });
      return item;
    }));
    list.hidden = false;
    field.setAttribute("aria-expanded", "true");
    const words = shown.length === 1 ? say("1 set it may be: up and down to choose, Enter to put it in")
      : say("{n} sets it may be: up and down to choose, Enter to put one in", { n: number(shown.length) });
    if (said.textContent !== words) said.textContent = words;
    mark(0);
  };
  const look = () => {
    clearTimeout(waiting);
    const typed = field.value.trim();
    if (chosen.dataset.set !== typed) {
      chosen.hidden = true;
      delete chosen.dataset.set;
    }
    if (/^https?:/i.test(typed) || typed.replace(/[^\p{L}\p{N}]/gu, "").length < 2) return close();
    if (found.has(typed)) return draw(found.get(typed));
    // Asked once typing pauses; the answer is the CDN's, the same for everybody.
    waiting = setTimeout(async () => {
      const reply = await fetch(`/api/share?op=set_find&q=${encodeURIComponent(typed)}`, { headers: { accept: "application/json" } })
        .catch(() => null);
      const body = reply && reply.ok ? await reply.json().catch(() => null) : null;
      const sets = (Array.isArray(body?.sets) ? body.sets : []).filter((one) => one && SET.test(String(one.set))
        && typeof one.name === "string" && (!one.picture || /^\/library\/set\/[A-Za-z0-9.-]+\.(webp|jpg)$/.test(String(one.picture))));
      found.set(typed, sets);
      if (field.value.trim() === typed) draw(sets);
    }, 180);
  };
  field.addEventListener("input", look);
  field.addEventListener("blur", close);
  field.addEventListener("keydown", (event) => {
    if (list.hidden) return;
    if (event.key === "ArrowDown" || event.key === "ArrowUp") mark(at + (event.key === "ArrowDown" ? 1 : -1));
    else if (event.key === "Enter") choose(at);
    else if (event.key === "Escape") close();
    else return;
    event.preventDefault();
    event.stopPropagation();
  });
}

/// @ in [field] offers [people]() whose handle or name starts with what
/// follows it, at most six, under the field: Up and Down move, Enter or
/// Tab puts the one marked in as @handle, Escape closes it (and only it).
/// The field stays a box of several lines to a screen reader (a combobox
/// is one line), its list a listbox it controls, the one marked its active
/// descendant, and a status says when the list is there. The people on
/// the page first, then anybody whose profile may be named whose handle or
/// name starts with it (api/people.js peopleFound, ?op=people_find), asked
/// once typing pauses.
function pickMentions(field, people) {
  const list = document.createElement("ul");
  list.className = "pick-list mention-pick";
  list.id = `${field.id || "box"}-people`;
  list.setAttribute("role", "listbox");
  list.setAttribute("aria-label", say("People to name"));
  list.hidden = true;
  const said = document.createElement("span");
  said.className = "visually-hidden";
  said.setAttribute("role", "status");
  field.after(list, said);
  field.setAttribute("aria-autocomplete", "list");
  field.setAttribute("aria-controls", list.id);
  let shown = [];
  let at = 0;
  let typed = null;
  let waiting = 0;
  // Who each prefix found beyond the page, asked once each.
  const found = new Map();
  const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;

  const close = () => {
    clearTimeout(waiting);
    list.hidden = true;
    shown = [];
    typed = null;
    said.textContent = "";
    field.removeAttribute("aria-activedescendant");
  };
  const mark = (to) => {
    at = (to + shown.length) % shown.length;
    [...list.children].forEach((item, n) => item.setAttribute("aria-selected", String(n === at)));
    field.setAttribute("aria-activedescendant", list.children[at].id);
  };
  const choose = (n) => {
    const one = shown[n];
    if (!one || !typed) return;
    const before = field.value.slice(0, typed.start);
    const after = field.value.slice(field.selectionStart);
    const put = `@${one.handle}${/^\s/.test(after) ? "" : " "}`;
    field.value = `${before}${put}${after}`;
    // After the space that ends it, so the list does not open again on it.
    const caret = before.length + put.length + (/^\s/.test(after) ? 1 : 0);
    field.setSelectionRange(caret, caret);
    close();
    field.dispatchEvent(new Event("input", { bubbles: true }));
  };
  /// What follows the @ before the caret, or null when the caret is not in one.
  const atCaret = () => {
    const upto = field.value.slice(0, field.selectionStart);
    const hit = /(^|[^A-Za-z0-9_.@/-])@([A-Za-z0-9-]{0,23})$/.exec(upto);
    if (!hit || field.selectionStart !== field.selectionEnd) return null;
    return { asked: hit[2].toLowerCase(), start: upto.length - hit[2].length - 1 };
  };
  const look = () => {
    const now = atCaret();
    if (!now) return close();
    const { asked } = now;
    const here = people().filter((one) => one.handle.startsWith(asked) || one.name.toLowerCase().startsWith(asked));
    const there = (found.get(asked) || []).filter((one) => !here.some((own) => own.handle === one.handle));
    draw([...here, ...there].slice(0, 6), now);
    clearTimeout(waiting);
    // From two letters (api/people.js peopleFind), signed in, each asked once.
    if (asked.length < 2 || found.has(asked) || here.length >= 6) return;
    waiting = setTimeout(async () => {
      const reply = await call(`/api/people?op=people_find&q=${encodeURIComponent(asked)}${TESTS ? "&tests=1" : ""}`).catch(() => null);
      const body = reply && reply.status === 200 ? reply.body : null;
      found.set(asked, (Array.isArray(body?.people) ? body.people : [])
        .filter((one) => one && HANDLE.test(String(one.handle)) && typeof one.name === "string"));
      // Still where it was asked: drawn again with them.
      if (atCaret()?.asked === asked && document.activeElement === field) look();
    }, 150);
  };
  const draw = (who, now) => {
    shown = who;
    if (!shown.length) {
      list.hidden = true;
      said.textContent = "";
      field.removeAttribute("aria-activedescendant");
      typed = null;
      return;
    }
    typed = { start: now.start };
    list.replaceChildren(...shown.map((one, n) => {
      const item = document.createElement("li");
      item.id = `${list.id}-${n}`;
      item.setAttribute("role", "option");
      const name = document.createElement("b");
      name.textContent = one.name;
      const handle = document.createElement("small");
      handle.textContent = `@${one.handle}`;
      item.append(name, " ", handle);
      // Chosen without the field losing its focus.
      item.addEventListener("mousedown", (event) => {
        event.preventDefault();
        choose(n);
      });
      return item;
    }));
    list.hidden = false;
    const words = shown.length === 1 ? say("1 person to name: up and down to choose, Enter to put one in")
      : say("{n} people to name: up and down to choose, Enter to put one in", { n: number(shown.length) });
    if (said.textContent !== words) said.textContent = words;
    mark(0);
  };
  field.addEventListener("input", look);
  field.addEventListener("click", look);
  field.addEventListener("blur", close);
  field.addEventListener("keydown", (event) => {
    if (list.hidden) return;
    if (event.key === "ArrowDown" || event.key === "ArrowUp") mark(at + (event.key === "ArrowDown" ? 1 : -1));
    else if (event.key === "Enter" || event.key === "Tab") choose(at);
    else if (event.key === "Escape") close();
    else return;
    event.preventDefault();
    event.stopPropagation();
  });
}

// ---------------------------------------------------------------------------
// Mute this model (inbox, 2026-11-23; supabase/notification_prefs.sql): in
// More, signed in, for anybody's model: its comments, replies and mentions
// on it, photos, remixes, likes and challenge results stop being counted,
// listed, pushed or emailed, until Unmute (here, or in Settings ›
// Notifications). What it says is asked the first time More opens.
function muteItem() {
  const more = marks && marks.querySelector("#more");
  const menu = more && more.querySelector(".menu-list");
  if (!menu || !ID_OK.test(String(id || ""))) return;
  let asked = null;
  const drawn = async () => {
    if (!signedIn()) {
      menu.querySelector("[data-mute]")?.remove();
      return;
    }
    asked ||= call("/api/people?op=notification_prefs").catch(() => null);
    const answer = await asked;
    if (!answer || answer.status !== 200 || answer.body.ready !== true) return;
    let button = menu.querySelector("[data-mute]");
    if (!button) {
      button = document.createElement("button");
      button.type = "button";
      button.dataset.mute = "";
      // Before Takedown requests, the menu's last.
      const last = menu.querySelector('a[href*="takedown"]');
      if (last) last.before(button);
      else menu.append(button);
      button.addEventListener("click", async () => {
        const on = button.dataset.mute !== "on";
        button.disabled = true;
        const done = await call("/api/people?op=notification_mute", { method: "POST", body: { model: id, on } }).catch(() => null);
        button.disabled = false;
        more.open = false;
        const said = document.querySelector(".marks-said");
        if (!done || done.status !== 200) {
          if (said) said.textContent = told(done?.body?.error, say("That did not work just now."));
          return;
        }
        button.dataset.mute = done.body.muted ? "on" : "";
        button.textContent = done.body.muted ? say("Unmute notifications") : say("Mute notifications");
        if (said) {
          said.textContent = done.body.muted
            ? say("Muted: nothing about this model reaches you until you unmute it, here or in Settings.")
            : say("Unmuted: you hear of this model again.");
        }
        asked = null;
      });
    }
    const muted = (answer.body.muted || []).some((one) => one.model === id);
    button.dataset.mute = muted ? "on" : "";
    button.textContent = muted ? say("Unmute notifications") : say("Mute notifications");
  };
  more.addEventListener("toggle", () => {
    if (more.open) drawn().catch(() => null);
  });
  addEventListener("brickworks:signed-in-done", () => {
    asked = null;
  });
}
const ID_OK = /^[A-Za-z0-9]{10}$/;
muteItem();
