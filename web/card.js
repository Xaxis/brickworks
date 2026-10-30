// A shared model's card, the one every page draws (site.css .model): the
// gallery, the landing page's strip, a profile, a collection, a model's
// remixes, your account. Its picture with its marks over a corner (Tested,
// made with the assistant: one row of them, and none that nearly every
// card shown carries) and, in the gallery, its like button over the other;
// its name; who made it with their avatar and a link to their profile, its
// size and its numbers once there are any (likes, builds finished,
// comments, each an icon and a count), all on one line; then what it has
// (how much of it your collection holds, what it won, what moves in it).
// It ended in a row holding only an empty heart, a fifth of its height
// (site273).
//
// One renderer for the server and the browser: cardHtml is a pure string
// function, so api/people.js and api/share.js put it in the pages they
// make and modelCard parses the same string here. There were three that
// differed (docs/SOCIAL.md, section 1); tools/web/card_check.mjs proves a
// server-made card and a browser-made one are the same markup. A
// deployment copies this file alone beside its functions (tools/deploy.sh),
// so it imports nothing: the kit's avatar and icons are made here, and
// web/kit.js passes them on.
//
// The card is an article, not a link: its name is the link to the model's
// page, stretched over the whole card (site.css), so the designer's name
// and the like button inside it can be links and buttons of their own.
//
// A mark is said when it tells a card apart. When 90% or more of the
// cards on a page carry one (every model in the gallery was Tested and
// made with the assistant, site273), <body data-quiet> names it and
// site.css leaves it off: the server's pages say so as they are made
// (quietMarks), and in a browser it is said again, before the page is
// drawn, whenever cards made by modelCard come onto it.
//
// Names and credits were typed by strangers, so every word is escaped;
// the link is built from the model's id alone, and the caller passes only
// an id that is one.

/// Text as HTML text or an attribute's value.
export const escapeHtml = (text) => String(text).replace(/[&<>"']/g, (c) => ({
  "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
})[c]);

/// "1 part", "1,234 parts".
export function counted(n, one, many) {
  const value = Number(n) || 0;
  return `${value.toLocaleString("en-US")} ${value === 1 ? one : many || `${one}s`}`;
}

/// Which of the eight avatar tiles a handle has (1-8): the same every time
/// and on every page, spread evenly (FNV-1a of the handle).
export function avatarTone(handle) {
  let hash = 0x811c9dc5;
  for (const c of String(handle || "").toLowerCase()) {
    hash ^= c.codePointAt(0);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return (hash % 8) + 1;
}

// Where a person's own picture is (api/_faces.js pictureAt): this site's,
// never an address from anywhere else.
const PICTURE = /^\/api\/people\?op=avatar&id=[A-Za-z0-9]{10}$/;

/// A person's avatar: their picture when they have one (supabase/avatars.sql),
/// else a tile in their handle's colour with the first letter of their
/// name. Never a figure's likeness (docs/TRADEMARKS.md, docs/SOCIAL.md D11).
/// Given none of the three, somebody not known yet (your own in the header
/// before the server has said who you are, or an orangecheck account's with
/// no profile): the circle blank, no letter or colour that might not be
/// theirs. [size] is "small", "", "big" or "huge"; it is decoration beside
/// their name, so hidden from a screen reader.
export function avatarHtml({ handle = "", name = "", picture = "" } = {}, { size = "", id = "" } = {}) {
  const pictured = PICTURE.test(String(picture || ""));
  const known = Boolean(handle || name || pictured);
  const letter = known ? [...String(name || handle || "?").trim()][0] || "?" : "";
  const classes = ["avatar", size, known ? `c${avatarTone(handle || name)}` : "unknown", pictured ? "pictured" : ""]
    .filter(Boolean).join(" ");
  return `<span class="${classes}"${id ? ` id="${escapeHtml(id)}"` : ""} aria-hidden="true">${pictured
    ? `<img src="${escapeHtml(picture)}" alt="" width="112" height="112" loading="lazy" decoding="async">` : escapeHtml(letter)}</span>`;
}

/// The icons there are (web/icons.svg).
export const ICONS = ["like", "save", "share", "comment", "more", "build", "search", "filter", "award", "zoom-in", "zoom-out",
  "stand", "gear", "move", "file", "book", "people", "devices", "camera", "spark", "eye", "monitor", "globe", "library",
  "download", "check", "back", "next"];

/// An icon from the sprite, in the words' colour.
export function iconHtml(name) {
  if (!ICONS.includes(name)) throw new Error(`no icon named ${name}`);
  return `<svg class="icon" aria-hidden="true" focusable="false"><use href="/icons.svg#${name}"></use></svg>`;
}

/// An icon button: its icon and its count beside it once there is one,
/// its name and count its label ("Like, 12 likes"; "Like" at none). A
/// toggle ([pressed] true or false) is aria-pressed. [labelled] shows a
/// word for it between the two, [word] (its name unless said), which is
/// in its label.
export function iconButtonHtml({ icon, name, count = 0, one = "", many = "", pressed = null, small = false, labelled = false,
  word = name, attrs = "" }) {
  const n = Number(count) || 0;
  const said = n ? `${name}, ${n.toLocaleString("en-US")} ${n === 1 ? one : many || `${one}s`}` : name;
  return `<button type="button" class="icon-btn${small ? " small" : ""}${labelled ? " labelled" : ""}" aria-label="${escapeHtml(said)}"`
    + `${pressed === null ? "" : ` aria-pressed="${pressed ? "true" : "false"}"`}${attrs ? ` ${attrs}` : ""}>`
    + `${iconHtml(icon)}${labelled ? `<span class="word">${escapeHtml(word)}</span>` : ""}`
    + `${n ? `<span class="n" aria-hidden="true">${escapeHtml(n.toLocaleString("en-US"))}</span>` : ""}</button>`;
}

/// What a person earned, as the row of pills under their numbers on their
/// page and on yours (docs/SOCIAL.md U13): each the award icon and its
/// name, what it means on hover; a challenge won is a link to the model that
/// won it. [awards] as api/people.js achievementsOf makes them: [{id, name,
/// said, model?, level?}]. "" when there is none.
export function awardsHtml(awards, { id = "" } = {}) {
  const shown = (awards || []).filter((one) => one && one.name);
  if (!shown.length) return "";
  return `<ul class="pills awards"${id ? ` id="${escapeHtml(id)}"` : ""} aria-label="Achievements">${shown.map((one) => {
    const inside = `${iconHtml("award")}${escapeHtml(one.name)}`;
    const said = one.said ? ` title="${escapeHtml(one.said)}"` : "";
    const level = Number(one.level) > 0 ? ` data-level="${Number(one.level)}"` : "";
    return `<li data-award="${escapeHtml(one.id)}"${level}${one.model ? ` data-won="${escapeHtml(one.model)}"` : ""}>${one.model
      ? `<a class="pill new" href="/m/${escapeHtml(one.model)}"${said}>${inside}</a>` : `<span class="pill"${said}>${inside}</span>`}</li>`;
  }).join("")}</ul>`;
}

/// The tracks of achievements (supabase/achievements.sql, docs/SOCIAL.md
/// section 7), in its order: each its name, what a level's number counts
/// ([one, many]: "Designer · 10 models"), what the number is, and the way
/// to the next level, with a page that helps.
export const TRACKS = {
  designer: { name: "Designer", unit: ["model", "models"], what: ["model listed in the gallery", "models listed in the gallery"],
    how: "Share a model from the app and list it in the gallery.", href: "/docs/sharing#share" },
  built: { name: "Built", unit: ["time", "times"], what: ["build finished to the last step", "builds finished to the last step"],
    how: "Each build of one of your models that somebody finishes counts.", href: "" },
  builder: { name: "Builder", unit: ["build", "builds"], what: ["photo of a real build", "photos of real builds"],
    how: "Build a model from the gallery and post a photo of it on its page.", href: "/gallery" },
  remixed: { name: "Remixed", unit: ["time", "times"], what: ["remix", "remixes"],
    how: "Each remix of one of your models counts.", href: "" },
  tested: { name: "Tested", unit: ["model", "models"], what: ["model marked Tested", "models marked Tested"],
    how: "A model is marked Tested when it stands at every step as it is shared.", href: "/docs/sharing#tested" },
  challenger: { name: "Challenger", unit: ["challenge", "challenges"], what: ["challenge entered", "challenges entered"],
    how: "Enter this month's building challenge.", href: "/challenge" },
};

/// A level as its pill says it: "Designer · 10 models", "Designer · first
/// model", "Built · once".
export function levelName(track, n) {
  const one = TRACKS[track];
  if (!one) return "";
  const value = Number(n) || 0;
  const first = one.unit[0] === "time" ? "once" : `first ${one.unit[0]}`;
  return `${one.name} · ${value === 1 ? first : counted(value, ...one.unit)}`;
}

/// The levels a person reached, as awardsHtml's pills, the highest first
/// (the tracks' order between equals). [levels] as achievement_levels gives
/// them: [{track, n, level, of, reached, next}].
export function levelAwards(levels) {
  return (Array.isArray(levels) ? levels : [])
    .filter((one) => one && TRACKS[one.track] && Number(one.level) > 0)
    .sort((a, b) => Number(b.level) - Number(a.level))
    .map((one) => ({ id: one.track, level: Number(one.level), name: levelName(one.track, one.reached),
      said: `Level ${Number(one.level)} of ${Number(one.of)}: ${counted(one.n, ...TRACKS[one.track].what)}` }));
}

/// Where Share's sheet posts a page (docs/SOCIAL.md section 7), as
/// Sketchfab's and Mecabricks' do: each network's own page for sharing a
/// link, opened in a tab of its own, so nothing of theirs loads here and
/// nothing goes to them until somebody chooses one (D13). [text] is what
/// the post says; Pinterest pins a picture, so it is offered only with one.
export function shareTargets({ url, text, image = "" }) {
  const u = encodeURIComponent(url);
  const t = encodeURIComponent(text);
  return [
    ["reddit", "Reddit", `https://www.reddit.com/submit?url=${u}&title=${t}`],
    ["bluesky", "Bluesky", `https://bsky.app/intent/compose?text=${encodeURIComponent(`${text} ${url}`)}`],
    image ? ["pinterest", "Pinterest", `https://www.pinterest.com/pin/create/button/?url=${u}`
      + `&media=${encodeURIComponent(image)}&description=${t}`] : null,
    ["x", "X", `https://x.com/intent/tweet?url=${u}&text=${t}`],
    ["facebook", "Facebook", `https://www.facebook.com/sharer/sharer.php?u=${u}`],
    ["email", "Email", `mailto:?subject=${t}&body=${u}`],
  ].filter(Boolean);
}

/// Share's sheet, every page's (docs/SOCIAL.md U14 and section 7): the
/// site's dialog with the page's link and Copy, the networks to post it to
/// (shareTargets), the code that embeds it where it has one ([embed]), and
/// a way to the phone's own share sheet, which web/share-sheet.js shows
/// where the browser has one. [name] heads it, [about] says what the link
/// opens, [text] is what a post says. Closed, and inert with no script.
export function shareSheetHtml({ url, name, about = "", text = name, image = "", embed = "" }) {
  const to = shareTargets({ url, text, image }).map(([key, label, href]) => `<a class="cta ghost small" data-to="${key}" `
    + `href="${escapeHtml(href)}"${key === "email" ? "" : ' target="_blank" rel="noopener noreferrer"'}>${label}`
    + `${key === "email" ? "" : '<span class="visually-hidden"> (opens in a new tab)</span>'}</a>`).join("");
  return `<dialog class="share-sheet" id="share-sheet" aria-labelledby="share-h" data-title="${escapeHtml(text)}">`
    + `<h2 id="share-h">Share ${escapeHtml(name)}</h2>`
    + (about ? `<p>${escapeHtml(about)}</p>` : "")
    + `<form method="dialog">`
    + `<div class="copy-row"><label>Its link<input id="share-link" value="${escapeHtml(url)}" readonly spellcheck="false"></label>`
    + `<button type="button" class="cta" data-copy="share-link">Copy link</button></div>`
    + `<div class="share-to" role="group" aria-labelledby="share-to-h"><p id="share-to-h">Post it to</p>${to}</div>`
    + (embed ? `<div class="copy-row"><label>Embed it in a page <small>Its picture and name, opening it here, `
      + `light or dark to suit whoever looks at it</small>`
      + `<textarea id="share-embed" rows="4" readonly spellcheck="false">${escapeHtml(embed)}</textarea></label>`
      + `<button type="button" class="cta ghost" data-copy="share-embed">Copy code</button></div>` : "")
    + `<p class="said" role="status"></p>`
    + `<div class="actions"><button type="button" class="cta ghost" data-share-app hidden>Share with another app</button>`
    + `<button class="cta ghost" value="close">Close</button></div>`
    + `</form></dialog>`;
}

/// A card's like, as a screen reader says it: "Like Watchtower".
export const likeName = (name) => `Like ${String(name || "").trim() || "it"}`;

/// A count as a card shows it: its icon and its number, with its words for
/// a screen reader and on hover ("4 built"); "" at none, never "0".
function tallyHtml(icon, n, one, many) {
  const value = Number(n) || 0;
  if (!value) return "";
  const words = counted(value, one, many);
  return `<span class="tally" title="${escapeHtml(words)}">${iconHtml(icon)}`
    + `<span class="n">${escapeHtml(value.toLocaleString("en-US"))}</span>`
    + `<span class="visually-hidden">${escapeHtml(words.slice(words.indexOf(" ")))}</span></span>`;
}

/// What the asker's collection holds of a card's model, in a line, or "".
export function ownedLine(owned) {
  if (!owned || owned.pieces === null || owned.pieces === undefined || !Number(owned.pieces)) return "";
  const have = Number(owned.have) || 0;
  const pieces = Number(owned.pieces);
  if (have >= pieces) return "✓ You have every part";
  if (have === 0) return "You have none of its parts";
  return `You have ${have.toLocaleString("en-US")} of its ${pieces.toLocaleString("en-US")} parts · ${Math.floor((100 * have) / pieces)}%`;
}

/// A model's motions as a card says them: "open the dome, extend the
/// telescope", each begun in lower case when it begins with a plain word
/// (not "R2" or "LED"), [most] at most and how many more (api/_directory.js
/// movesWords says them so on its page).
export function motionWords(names, most = 3) {
  const shown = names.slice(0, most).map((name) => (/^[A-Z][a-z]*\b/.test(name) ? name[0].toLowerCase() + name.slice(1) : name));
  return shown.join(", ") + (names.length > most ? ` and ${names.length - most} more` : "");
}

/// The small picture when there is one, a few KB, and the big one when
/// not: a page of cards is quick on a phone. "" when it has neither. A set
/// of the LDraw library (api/_library.js) has its cover, drawn by the app.
export function pictureOf(model) {
  // A set of the whole catalogue (api/_sets.js catalogCard) names its own:
  // its LDraw model's cover, the one drawn of its parts, or none.
  if (isSet(model) && typeof model.library.picture === "string") {
    return /^\/library\/[A-Za-z0-9._/-]+$/.test(model.library.picture) ? model.library.picture : "";
  }
  if (isSet(model)) return `/library/${model.id}.webp`;
  const version = typeof model.thumb === "string" ? (model.thumb.split("?v=")[1] || "") : "";
  return model.thumb ? `/m/${model.id}.webp${/^[a-z0-9]+$/.test(version) ? `?v=${version}` : ""}`
    : model.image ? `/m/${model.id}.png` : "";
}

/// Whether a card is a set of the LDraw library (api/_library.js setCard):
/// its page is /library/<id>, and it says which set it is.
const isSet = (model) => Boolean(model.library) && typeof model.library === "object";

/// A set's page: a set of the catalogue's own (api/_sets.js catalogCard,
/// /library/set/<number>), else its LDraw model's, /library/<id>.
const setPageOf = (model, id) => (typeof model.library.page === "string"
  && /^\/library\/set\/[A-Za-z0-9][A-Za-z0-9.-]{0,29}$/.test(model.library.page) ? model.library.page : `/library/${id}`);

/// The tags that say a model was made with the assistant or Brickify, as
/// the guidelines ask a designer to tag it (web/guidelines.html), read for
/// a model whose app did not say (docs/SOCIAL.md D7). The gallery's "With
/// the assistant" filter reads the same two (api/_directory.js,
/// supabase/made_with.sql gallery_models).
export const ASSISTANT_TAGS = ["ai-designed", "brickify"];

/// Who laid a model's parts, as its app says as it publishes (2026-10-24,
/// docs/SOCIAL.md U16, supabase/made_with.sql): by hand, Claude, Brickify.
export const MADE_WITH = ["hand", "assistant", "brickify"];

/// How [model] was made, and who says so: {way, by, said}. way is
/// "assistant" for one made with the assistant or Brickify and "hand" for
/// every other; by is "brickify" for Brickify's alone; said is "app" when
/// its app said it as it was published, else "tags". The app is believed
/// over the tags: a hand-built model tagged ai-designed is hand-built.
export function madeOf(model) {
  if (MADE_WITH.includes(model.made_with)) {
    return { way: model.made_with === "hand" ? "hand" : "assistant", by: model.made_with, said: "app" };
  }
  const tags = Array.isArray(model.tags) ? model.tags : [];
  const brickify = tags.includes("brickify") && !tags.includes("ai-designed");
  return { way: tags.some((tag) => ASSISTANT_TAGS.includes(tag)) ? "assistant" : "hand",
    by: brickify ? "brickify" : tags.includes("ai-designed") ? "assistant" : "hand", said: "tags" };
}

/// The marks a card for [model] carries over its picture: "tested", and
/// "made" (with the assistant or Brickify).
export function marksOf(model) {
  return [model.tested === true ? "tested" : "", madeOf(model).way === "assistant" ? "made" : ""].filter(Boolean);
}

/// The marks that tell none of a page's cards apart, as <body data-quiet>
/// says them ("tested made", or ""): each carried by 90% or more of the
/// cards, [carried] being each card's marks (marksOf). Under four cards
/// each card says its own.
export function quietMarks(carried) {
  const all = [...carried];
  if (all.length < 4) return "";
  return ["tested", "made"].filter((mark) => all.filter((marks) => marks.includes(mark)).length >= 0.9 * all.length).join(" ");
}

/// Says on <body> which marks the cards on this page now leave off.
export function quietPage() {
  const cards = [...document.querySelectorAll(".model")].map((card) => [
    card.dataset.tested === "yes" ? "tested" : "", card.dataset.made === "assistant" ? "made" : ""].filter(Boolean));
  const quiet = quietMarks(cards);
  if (quiet) document.body.dataset.quiet = quiet;
  else delete document.body.dataset.quiet;
}

// What the Tested mark means, said on hover.
const TESTED_SAYS = "Stands at every step · every step reachable · every part made in its colour · nothing loose";
// A handle, as api/people.js keeps one: only such a one makes a link.
const HANDLE = /^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/;

/// The card for [model] (a card as /api/share and /api/people send one),
/// as HTML.
///
/// [earned]: a designer's page's card (supabase/designers.sql), which leads
/// with what the model earned, builds finished and remixes, then comments
/// and likes, in words, and never its views.
/// [like]: its like is a button (data-like, the model's id), pressed when
/// model.liked; the gallery's script makes it work. Elsewhere it is a count.
/// [eager]: one of the first screen's cards, whose picture is asked for at
/// once and first (fetchpriority) rather than when the browser finds it in
/// view: a lazy picture in the first screen came last (site273).
export function cardHtml(model, { earned = false, like = false, eager = false } = {}) {
  const id = String(model.id);
  const name = escapeHtml(model.name);
  const picture = pictureOf(model);
  const data = [`data-id="${escapeHtml(id)}"`, `data-builds="${Number(model.builds) || 0}"`];
  if (earned) data.push(`data-remixes="${Number(model.remixes) || 0}"`, `data-comments="${Number(model.comments) || 0}"`);
  // Over the picture's corner: the Tested mark, and how it was made.
  const marks = [];
  // Marked Tested: its newest version passed the four tests the app ran
  // as it was published (api/_tested.js), said on hover.
  if (model.tested === true) {
    marks.push(`<span class="pill good tested" title="${escapeHtml(TESTED_SAYS)}">✓ Tested</span>`);
    data.push('data-tested="yes"');
  }
  const made = madeOf(model);
  if (made.way === "assistant") {
    const brickified = made.by === "brickify";
    const how = made.said === "app" ? "as the app said when it was published" : "as its designer tagged it";
    marks.push(`<span class="pill made" title="${brickified ? `Made from a 3D model with Brickify, ${how}`
      : `Designed with the assistant, ${how}`}">${brickified ? "Brickify" : "Assistant"}</span>`);
    data.push('data-made="assistant"');
  }
  // A set of the LDraw library: its number, its theme and its year, each
  // where the index knows it.
  const set = isSet(model) ? model.library : null;
  // A set of the catalogue LDraw has a 3D model of (sets364).
  if (set && set.model3d === true) {
    marks.push('<span class="pill good model3d" title="LDraw has a 3D model of it, to build in Brickworks">3D</span>');
    data.push('data-model3d="yes"');
  }
  // Who made it: whoever modelled it, when that is not who shares it (the
  // app's Library's model it is: supabase/modelled_by.sql), as words that
  // wrap on a phone's narrow card rather than end in "…"; else their avatar and name, a link to their profile, when they
  // have one shown in public (supabase directory_card's by); else the name
  // they credited it to, as words; else nobody.
  const by = model.by && typeof model.by === "object" && HANDLE.test(String(model.by.handle || "")) ? model.by : null;
  const modeller = model.modelled_by && typeof model.modelled_by === "object" && typeof model.modelled_by.name === "string"
    ? model.modelled_by.name : "";
  const who = modeller
    ? `<span class="who" data-modelled-by>${escapeHtml(`Modelled by ${modeller}`)}</span>`
    : by
    ? `<a class="who" href="/u/${escapeHtml(by.handle)}">${avatarHtml({ handle: by.handle, name: by.name || by.handle,
      picture: by.picture }, { size: "small" })}`
      + `<span>${escapeHtml(by.name || by.handle)}</span></a>`
    : model.author ? `<span class="who">${escapeHtml(model.author)}</span>` : "";
  const lines = [];
  if (set) {
    const said = [set.set, set.theme, Number(set.year) ? String(Number(set.year)) : ""].filter(Boolean).join(" · ");
    if (said) lines.push(`<small class="set">${escapeHtml(said)}</small>`);
  }
  if (earned) {
    // Said once there is one, in words: the designer's page counts them.
    const said = [];
    const say = (n, one, many) => { if (Number(n)) said.push(counted(n, one, many)); };
    say(model.builds, "built", "built");
    say(model.remixes, "remix", "remixes");
    say(model.comments, "comment");
    say(model.likes, "like");
    lines.push(`<small>${escapeHtml(said.join(" · "))}</small>`);
  }
  // Signed in with a collection: how much of it is theirs already.
  const theirs = ownedLine(model.owned);
  if (theirs) {
    const all = Number(model.owned.have) >= Number(model.owned.pieces);
    lines.push(`<small class="${all ? "owned all" : "owned"}">${escapeHtml(theirs)}</small>`);
    data.push(`data-owned="${Number(model.owned.have) || 0}/${Number(model.owned.pieces)}"`);
  }
  // What it won in the monthly challenges (supabase/challenges.sql).
  const won = Array.isArray(model.won) ? model.won : [];
  for (const win of won) {
    lines.push(`<small class="won">${escapeHtml(`Won “${String(win.title)}”${win.way === "assistant" ? ", with the assistant" : ", by hand"}`)}</small>`);
  }
  if (won.length) data.push('data-won="yes"');
  // Something to play with: its own motions by name, read from its file
  // as it was published (supabase/motions.sql), played by a button each on
  // its link; else what moves in it, as its app found from its joints
  // (supabase/play.sql), to be taken hold of and moved there.
  const moves = Array.isArray(model.moves) ? model.moves.filter((word) => typeof word === "string") : [];
  const motions = Array.isArray(model.motions) ? model.motions.filter((one) => typeof one === "string" && one) : [];
  if (motions.length || moves.length) {
    const title = motions.length ? `Open it and play ${motions.length === 1 ? "it" : "them"}: ${motions.join(" · ")}`
      : "Open it and drag what moves, as it was built";
    lines.push(`<small class="moves" title="${escapeHtml(title)}">${escapeHtml(`Moves: ${motions.length ? motionWords(motions, 3) : moves.join(", ")}`)}</small>`);
    data.push(`data-moves="${escapeHtml(moves.join(","))}"`);
    if (motions.length) data.push(`data-motions="${escapeHtml(motions.join("|"))}"`);
  }
  // Its numbers as icons, each once there is one, on the designer's line:
  // likes (where the like is not a button), builds finished to the last
  // step, once per device (supabase/builds.sql), and comments. Views are
  // never shown or ranked (docs/SOCIAL.md D6).
  const tallies = earned ? "" : (like ? "" : tallyHtml("like", model.likes, "like"))
    + tallyHtml("build", model.builds, "built", "built") + tallyHtml("comment", model.comments, "comment");
  // The like, where the page makes it a button: over the picture's other
  // corner, its count beside its heart. Named with the model: twenty
  // cards' "Like" in a row say which they like.
  const liked = like && !earned ? iconButtonHtml({ icon: "like", name: likeName(model.name), count: model.likes, one: "like",
    pressed: model.liked === true, small: true, attrs: `data-like="${escapeHtml(id)}"` }) : "";
  return `<article class="model" ${data.join(" ")}>`
    + `<div class="frame${picture ? "" : " none"}">${picture
      ? `<img src="${escapeHtml(picture)}" alt="${name}" width="1200" height="630" ${eager
        ? 'loading="eager" fetchpriority="high"' : 'loading="lazy"'} decoding="async">`
      : "No picture"}${marks.length ? `<div class="marks">${marks.join("")}</div>` : ""}${liked}</div>`
    + `<div class="words"><a class="open" href="${escapeHtml(set ? setPageOf(model, id) : `/m/${id}`)}"><b title="${name}">${name}</b></a>`
    + `<span class="by">${who}<span class="parts">${escapeHtml(counted(model.parts, "part"))}</span>`
    + `${tallies ? `<small class="acts">${tallies}</small>` : ""}</span>`
    + `${lines.join("")}</div></article>`;
}

/// How many of a list's cards are its first screen's, drawn [eager]: two
/// rows of six on a wide window, two of five and more at 1280, six rows of
/// two on a phone (site277's grid: 2 to 6 a row). The gallery counts the
/// places on its own first screen instead (18 at 1920, three rows of six).
export const FIRST_SCREEN = 12;

/// A card's skeleton (site.css .skeleton-card): the card's frame and its
/// words as bars, in a card's place until the list it stands for comes.
/// Not a .model: nothing that counts the cards counts it. The pages hold
/// it in their HTML (gallery, index, profile and feed), each copy this
/// markup: tools/web/card_check.mjs fails one that is not.
export function skeletonHtml() {
  return '<div class="skeleton-card skeleton" aria-hidden="true"><div class="frame"></div><div class="words">'
    + '<span class="bone wide"></span><span class="bone"></span><span class="bone short"></span><span class="bone tiny"></span></div></div>';
}

/// The card for [model] as an element, in a browser: cardHtml's markup,
/// made this page's own. A template's content belongs to a document of its
/// own with no window, where a picture never loads and decode() refuses:
/// the landing page's strip waited on its cards' pictures before showing,
/// and stayed hidden with all seven refused (walk180, 2026-10-23).
///
/// Once a card is made here, the page's quiet marks are said again
/// whenever cards come onto the page, before it is drawn (quietPage): the
/// landing page's strip puts its cards in only once their pictures have
/// decoded, frames after they were made.
export function modelCard(model, options) {
  const made = document.createElement("template");
  made.innerHTML = cardHtml(model, options);
  if (!watching) {
    watching = true;
    new MutationObserver((changes) => {
      if (changes.some((change) => [...change.addedNodes].some((node) => node.nodeType === 1
        && (node.matches(".model") || node.querySelector(".model"))))) quietPage();
    }).observe(document.body, { childList: true, subtree: true });
  }
  return document.importNode(made.content.firstElementChild, true);
}
let watching = false;

// ---------------------------------------------------------------------------
// What a model is based on (api/_bases.js, docs/SOCIAL.md section 7, item 5).

/// How a model is based on something, as its line begins.
export const HOWS = { alternate: "An alternate build of", changed: "Changed from", inspired: "Inspired by" };

/// A model's lines under its remix line, one a thing it is based on: "An
/// alternate build of set 6080-1 King's Castle", "Changed from “A castle”
/// by Someone (CC BY 4.0)". "" for none. Every word escaped.
export function basedHtml(said) {
  if (!said.length) return "";
  const line = (one) => (one.set
    ? `${HOWS[one.how]} <a href="${escapeHtml(one.href)}">set ${escapeHtml(one.name ? `${one.set} ${one.name}` : one.set)}</a>`
    : `${HOWS[one.how]} <a href="${escapeHtml(one.href)}" rel="nofollow ugc noopener">“${escapeHtml(one.name)}”</a>`
      + `${one.author ? ` by ${escapeHtml(one.author)}` : ""}${one.licence ? ` (${escapeHtml(one.licence)})` : ""}`);
  return `<ul class="from based-on" id="based-on" aria-label="What it is based on">`
    + `${said.map((one) => `<li data-how="${one.how}">${line(one)}</li>`).join("")}</ul>`;
}
