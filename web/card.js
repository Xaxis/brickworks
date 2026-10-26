// A shared model's card, the one every page draws (site.css .model): the
// gallery, the landing page's strip, a profile, a collection, a model's
// remixes, your account. Its picture with its marks over a corner (Tested,
// made with the assistant), its name, who made it with their avatar and a
// link to their profile, its size, what it has (how much of it your
// collection holds, what it won, what moves in it), and its numbers once
// there are any: a like, which the gallery lets you give from the card,
// the builds finished and the comments, each as an icon and a count.
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
/// [size] is "small", "", "big" or "huge"; it is decoration beside their
/// name, so hidden from a screen reader.
export function avatarHtml({ handle = "", name = "", picture = "" } = {}, { size = "", id = "" } = {}) {
  const letter = [...String(name || handle || "?").trim()][0] || "?";
  const pictured = PICTURE.test(String(picture || ""));
  const classes = ["avatar", size, `c${avatarTone(handle || name)}`, pictured ? "pictured" : ""].filter(Boolean).join(" ");
  return `<span class="${classes}"${id ? ` id="${escapeHtml(id)}"` : ""} aria-hidden="true">${pictured
    ? `<img src="${escapeHtml(picture)}" alt="" loading="lazy" decoding="async">` : escapeHtml(letter)}</span>`;
}

/// The icons there are (web/icons.svg).
export const ICONS = ["like", "save", "share", "comment", "more", "build", "search", "filter", "award", "zoom-in", "zoom-out"];

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
/// said, model?}]. "" when there is none.
export function awardsHtml(awards, { id = "" } = {}) {
  const shown = (awards || []).filter((one) => one && one.name);
  if (!shown.length) return "";
  return `<ul class="pills awards"${id ? ` id="${escapeHtml(id)}"` : ""} aria-label="Achievements">${shown.map((one) => {
    const inside = `${iconHtml("award")}${escapeHtml(one.name)}`;
    const said = one.said ? ` title="${escapeHtml(one.said)}"` : "";
    return `<li data-award="${escapeHtml(one.id)}"${one.model ? ` data-won="${escapeHtml(one.model)}"` : ""}>${one.model
      ? `<a class="pill new" href="/m/${escapeHtml(one.model)}"${said}>${inside}</a>` : `<span class="pill"${said}>${inside}</span>`}</li>`;
  }).join("")}</ul>`;
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
/// not: a page of cards is quick on a phone. "" when it has neither.
export function pictureOf(model) {
  const version = typeof model.thumb === "string" ? (model.thumb.split("?v=")[1] || "") : "";
  return model.thumb ? `/m/${model.id}.webp${/^[a-z0-9]+$/.test(version) ? `?v=${version}` : ""}`
    : model.image ? `/m/${model.id}.png` : "";
}

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
export function cardHtml(model, { earned = false, like = false } = {}) {
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
  // Its numbers as icons, each once there is one: a like (a button where
  // the page makes it one), builds finished to the last step, once per
  // device (supabase/builds.sql), and comments. Views are never shown or
  // ranked (docs/SOCIAL.md D6).
  if (!earned) {
    // Named with the model: twenty cards' "Like" in a row say which they like.
    const liked = like ? iconButtonHtml({ icon: "like", name: likeName(model.name), count: model.likes, one: "like",
      pressed: model.liked === true, small: true, attrs: `data-like="${escapeHtml(id)}"` }) : tallyHtml("like", model.likes, "like");
    const acts = liked + tallyHtml("build", model.builds, "built", "built") + tallyHtml("comment", model.comments, "comment");
    if (acts) lines.push(`<small class="acts">${acts}</small>`);
  }
  return `<article class="model" ${data.join(" ")}>`
    + `<div class="frame${picture ? "" : " none"}">${picture
      ? `<img src="${escapeHtml(picture)}" alt="${name}" width="1200" height="630" loading="lazy" decoding="async">`
      : "No picture"}${marks.length ? `<div class="marks">${marks.join("")}</div>` : ""}</div>`
    + `<div class="words"><a class="open" href="/m/${escapeHtml(id)}"><b title="${name}">${name}</b></a>`
    + `<span class="by">${who}<span class="parts">${escapeHtml(counted(model.parts, "part"))}</span></span>`
    + `${lines.join("")}</div></article>`;
}

/// The card for [model] as an element, in a browser: cardHtml's markup,
/// made this page's own. A template's content belongs to a document of its
/// own with no window, where a picture never loads and decode() refuses:
/// the landing page's strip waited on its cards' pictures before showing,
/// and stayed hidden with all seven refused (walk180, 2026-10-23).
export function modelCard(model, options) {
  const made = document.createElement("template");
  made.innerHTML = cardHtml(model, options);
  return document.importNode(made.content.firstElementChild, true);
}
