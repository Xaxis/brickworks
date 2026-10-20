// A shared model's card, the one every page draws (site.css .model): the
// gallery, the landing page's strip, your account. Its picture, its name,
// its parts and who made it, its numbers once there are any, and what the
// gallery adds: how much of it your collection holds, what it won, what
// moves in it, and the Tested mark.
//
// Names and credits were typed by strangers, so every word goes on the
// page as text, never as markup; the link is built from the model's id
// alone, and the caller passes only an id that is one.

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

/// The small picture when there is one, a few KB, and the big one when
/// not: a page of cards is quick on a phone. "" when it has neither.
export function pictureOf(model) {
  const version = typeof model.thumb === "string" ? (model.thumb.split("?v=")[1] || "") : "";
  return model.thumb ? `/m/${model.id}.webp${/^[a-z0-9]+$/.test(version) ? `?v=${version}` : ""}`
    : model.image ? `/m/${model.id}.png` : "";
}

/// The card for [model] (a card as /api/share and /api/people send one).
export function modelCard(model) {
  const link = document.createElement("a");
  link.className = "model";
  link.href = `/m/${model.id}`;
  link.dataset.id = model.id;
  const frame = document.createElement("div");
  frame.className = "frame";
  const picture = pictureOf(model);
  if (picture) {
    const img = document.createElement("img");
    img.src = picture;
    img.alt = String(model.name);
    img.width = 1200;
    img.height = 630;
    img.loading = "lazy";
    img.decoding = "async";
    frame.append(img);
  } else {
    frame.classList.add("none");
    frame.textContent = "No picture";
  }
  const words = document.createElement("div");
  words.className = "words";
  const name = document.createElement("b");
  name.textContent = String(model.name);
  name.title = String(model.name);
  const about = document.createElement("span");
  const parts = counted(model.parts, "part");
  about.textContent = model.author ? `${parts}, by ${model.author}` : parts;
  const numbers = document.createElement("small");
  // Like the likes, said once there is one: "0 views" on every new card
  // reads as a gallery nobody visits.
  const said = [];
  if (Number(model.views)) said.push(counted(model.views, "view"));
  if (Number(model.likes)) said.push(counted(model.likes, "like"));
  if (Number(model.remixes)) said.push(counted(model.remixes, "remix", "remixes"));
  // Built to the last step, once per device (supabase/builds.sql).
  if (Number(model.builds)) said.push(counted(model.builds, "built", "built"));
  numbers.textContent = said.join(" · ");
  link.dataset.builds = String(Number(model.builds) || 0);
  words.append(name, about, numbers);
  // Signed in with a collection: how much of it is theirs already.
  const theirs = ownedLine(model.owned);
  if (theirs) {
    const line = document.createElement("small");
    line.className = Number(model.owned.have) >= Number(model.owned.pieces) ? "owned all" : "owned";
    line.textContent = theirs;
    words.append(line);
    link.dataset.owned = `${Number(model.owned.have) || 0}/${Number(model.owned.pieces)}`;
  }
  // What it won in the monthly challenges (supabase/challenges.sql).
  for (const win of Array.isArray(model.won) ? model.won : []) {
    const line = document.createElement("small");
    line.className = "won";
    line.textContent = `Won “${String(win.title)}”${win.way === "assistant" ? ", with the assistant" : ", by hand"}`;
    words.append(line);
    link.dataset.won = "yes";
  }
  // Something to play with: what moves in it, as its app found from its
  // joints when it was published (supabase/play.sql), to be taken hold
  // of and moved on its link.
  const moves = Array.isArray(model.moves) ? model.moves.filter((word) => typeof word === "string") : [];
  if (moves.length) {
    const line = document.createElement("small");
    line.className = "moves";
    line.textContent = `Moves: ${moves.join(", ")}`;
    line.title = "Open it and drag what moves, as it was built";
    words.append(line);
    link.dataset.moves = moves.join(",");
  }
  // Marked Tested: its newest version passed the four tests the app ran
  // as it was published (api/_tested.js), said on hover.
  if (model.tested === true) {
    const mark = document.createElement("small");
    mark.className = "tested";
    mark.textContent = "✓ Tested";
    mark.title = "Stands at every step · every step reachable · every part made in its colour · nothing loose";
    words.append(mark);
    link.dataset.tested = "yes";
  }
  link.append(frame, words);
  return link;
}
