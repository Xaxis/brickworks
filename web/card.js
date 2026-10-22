// A shared model's card, the one every page draws (site.css .model): the
// gallery, the landing page's strip, a profile, a collection, a model's
// remixes, your account. Its picture, its name, its parts and who made it,
// its numbers once there are any, and what it has: how much of it your
// collection holds, what it won, what moves in it, the Tested mark.
//
// One renderer for the server and the browser: cardHtml is a pure string
// function, so api/people.js and api/share.js put it in the pages they
// make and modelCard parses the same string here. There were three that
// differed (docs/SOCIAL.md, section 1); tools/web/card_check.mjs proves a
// server-made card and a browser-made one are the same markup.
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

// What the Tested mark means, said on hover.
const TESTED_SAYS = "Stands at every step · every step reachable · every part made in its colour · nothing loose";

/// The card for [model] (a card as /api/share and /api/people send one),
/// as HTML.
///
/// [earned]: a designer's page's card (supabase/designers.sql), which leads
/// with what the model earned, builds finished and remixes, then comments
/// and likes, and never its views.
export function cardHtml(model, { earned = false } = {}) {
  const id = String(model.id);
  const name = escapeHtml(model.name);
  const picture = pictureOf(model);
  const parts = counted(model.parts, "part");
  // Said once there is one: "0 views" on every new card reads as a gallery
  // nobody visits.
  const said = [];
  const say = (n, one, many) => { if (Number(n)) said.push(counted(n, one, many)); };
  if (earned) {
    say(model.builds, "built", "built");
    say(model.remixes, "remix", "remixes");
    say(model.comments, "comment");
    say(model.likes, "like");
  } else {
    say(model.views, "view");
    say(model.likes, "like");
    say(model.remixes, "remix", "remixes");
    // Built to the last step, once per device (supabase/builds.sql).
    say(model.builds, "built", "built");
  }
  const data = [`data-id="${escapeHtml(id)}"`, `data-builds="${Number(model.builds) || 0}"`];
  if (earned) data.push(`data-remixes="${Number(model.remixes) || 0}"`, `data-comments="${Number(model.comments) || 0}"`);
  const lines = [];
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
  // Marked Tested: its newest version passed the four tests the app ran
  // as it was published (api/_tested.js), said on hover.
  if (model.tested === true) {
    lines.push(`<small class="pill good tested" title="${escapeHtml(TESTED_SAYS)}">✓ Tested</small>`);
    data.push('data-tested="yes"');
  }
  return `<a class="model" href="/m/${escapeHtml(id)}" ${data.join(" ")}>`
    + `<div class="frame${picture ? "" : " none"}">${picture
      ? `<img src="${escapeHtml(picture)}" alt="${name}" width="1200" height="630" loading="lazy" decoding="async">`
      : "No picture"}</div>`
    + `<div class="words"><b title="${name}">${name}</b>`
    + `<span>${escapeHtml(model.author ? `${parts}, by ${model.author}` : parts)}</span>`
    + `<small>${escapeHtml(said.join(" · "))}</small>${lines.join("")}</div></a>`;
}

/// The card for [model] as an element, in a browser: cardHtml's markup.
export function modelCard(model, options) {
  const made = document.createElement("template");
  made.innerHTML = cardHtml(model, options);
  return made.content.firstElementChild;
}
