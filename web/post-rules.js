// What each place a model is posted to takes, and a kit for it checked
// against that (unit postkit, docs/MASTERPLAN.md row 9 and "The best of
// each side"). The people are elsewhere: r/lego, r/legomoc, Instagram,
// LEGO® Ideas, Rebrickable and Flickr's LEGO® Pool each have rules a post
// must meet, and a post that breaks them is taken down, or never seen.
// Brickworks posts nothing to any of them: its designer's browser makes
// the kit (web/post-kit.js) and they post it, from their own account.
//
// Pure, with nothing run as it loads, so a check reads it under node
// (tests/test_post_kit.py): what each kit draws (planOf), its words
// (wordsOf), each rule it is checked by, the rule's page and whether the
// kit keeps it (checksOf), and its files as one zip (zipOf).
//
// Each rule's page is where the rule was read (docs/MASTERPLAN.md's
// sources, 22 and 23 November 2026). Reddit, LEGO® Ideas and Rebrickable
// refuse a read from this machine, so their pages are named as the lead
// read them, through the Wayback Machine; Instagram's sizes are a guide's,
// Instagram having no page of its own that says them.
import { counted, number, say } from "./card.js";

export const PAGES = {
  legomoc: "https://www.reddit.com/r/legomoc/",
  lego: "https://www.reddit.com/r/lego/wiki/rules_policies_and_expected_behaviour",
  hashtags: "https://www.socialmediatoday.com/news/instagram-implements-new-limits-on-hashtag-use/808309/",
  instagram: "https://buffer.com/library/instagram-image-size",
  ideas: "https://ideas.lego.com/guidelines",
  rebrickableParts: "https://rebrickable.com/help/importing-parts/",
  rebrickableSteps: "https://rebrickable.com/help/types-of-moc-building-instructions/",
  flickr: "https://www.flickr.com/groups/lego/",
};

/// Where each kit's post is made: the place's own page for a new post.
export const OPEN = {
  legomoc: "https://www.reddit.com/r/legomoc/submit",
  lego: "https://www.reddit.com/r/lego/submit",
  instagram: "https://www.instagram.com/",
  ideas: "https://ideas.lego.com/",
  rebrickable: "https://rebrickable.com/mocs/",
  flickr: "https://www.flickr.com/photos/upload/",
};

export const LIMITS = {
  // A Reddit post of pictures: one at least, and a gallery holds 20.
  redditImages: [1, 20],
  // Instagram since December 2025.
  hashtags: 5,
  // Instagram's portrait post and its full-screen turn, and how long the
  // turn may be (the brief's bound: a Reel may be longer).
  cover: [1080, 1350],
  turn: [1080, 1920],
  turnSeconds: 15,
  // LEGO® Ideas: 200 to 5,000 pieces, 15 pictures at most.
  ideasPieces: [200, 5000],
  ideasImages: 15,
  // Flickr: the largest picture Brickworks draws, on its long side.
  flickrSide: 2560,
  // One zip, at most.
  zipBytes: 50 * 1024 * 1024,
};

/// The places, in the order the sheet offers them.
export const PLACES = ["legomoc", "lego", "instagram", "ideas", "rebrickable", "flickr"];

// The model from round it, a sixth of a turn apart, after the picture its
// designer chose, and once from higher: seven pictures.
const ROUND = [1, 2, 3, 4, 5].map((k) => ({ key: `turn-${k}`, width: 1600, height: 1200, turn: k / 6 }));
const HIGHER = { key: "high", width: 1600, height: 1200, turn: 1 / 12, high: true };

/// What a kit for [place] draws: {picture} (the page's own picture leads,
/// where it has one), [stills] (each {key, width, height, turn, high,
/// wordmark}, drawn from the 3D view, web/post-kit.js) and [turn] (a clip's
/// shape, or null).
export function planOf(place, { hasPicture = true } = {}) {
  const first = hasPicture ? [] : [{ key: "turn-0", width: 1600, height: 1200, turn: 0 }];
  if (place === "instagram") {
    const [width, height] = LIMITS.cover;
    const [tw, th] = LIMITS.turn;
    return { picture: false, stills: [{ key: "cover", width, height, turn: 0, wordmark: true }],
      turn: { width: tw, height: th, fps: 24, frames: 96, maxBytes: 12 * 1024 * 1024, bitrate: 6_000_000 } };
  }
  if (place === "flickr") {
    return { picture: false, stills: [{ key: "largest", width: LIMITS.flickrSide, height: (LIMITS.flickrSide * 3) / 4, turn: 0 }],
      turn: null };
  }
  return { picture: hasPicture, stills: [...first, ...ROUND, HIGHER], turn: null };
}

// ---------------------------------------------------------------------------
// Its words.

/// The credits that make [facts] somebody else's design: a remix of
/// another person's model, one somebody else modelled, or one changed from
/// another's. Inspired by, and an alternate build of a set, are the
/// designer's own.
export function othersDesign(facts) {
  const mine = String(facts.by || "").trim().toLowerCase();
  return (facts.credits || []).filter((one) => ["remix", "modelled", "changed"].includes(one.how)
    && !(one.how === "remix" && one.by && one.by.trim().toLowerCase() === mine));
}

/// A credit as a line: "Designed by Robin Castell: <link>", "Inspired by
/// set 6080-1 King's Castle".
function creditLine(one) {
  const named = one.name ? `“${one.name}”` : say("a model shared by link");
  if (one.how === "remix" || one.how === "changed" || one.how === "modelled") {
    const by = one.by ? say("Designed by {name}", { name: one.by }) : say("Changed from {model}", { model: named });
    return `${by}${one.by && one.name ? ` (${named})` : ""}${one.url ? `: ${one.url}` : ""}`;
  }
  const what = one.set ? say("set {set}", { set: one.name }) : `${named}${one.by ? ` ${say("by {name}", { name: one.by })}` : ""}`;
  const line = one.how === "alternate" ? say("An alternate build of {model}", { model: what }) : say("Inspired by {model}", { model: what });
  return `${line}${one.url ? `: ${one.url}` : ""}`;
}

/// How it was made, as a post says it.
const madeWords = (facts) => (facts.made === "assistant" ? say("designed with the Brickworks assistant") : say("designed in Brickworks"));

/// A word as a hashtag: lower case, letters and digits alone; "" for one
/// that is no word, or that names the LEGO Group's mark, which is said only
/// as an adjective with its ® (docs/TRADEMARKS.md), as no hashtag can be.
function tagOf(word) {
  const tag = String(word || "").toLowerCase().normalize("NFKD").replace(/[^a-z0-9]/g, "");
  return tag.length >= 2 && tag.length <= 30 && !tag.includes("lego") ? tag : "";
}

/// The hashtags in [text], in order.
export const hashtagsIn = (text) => [...String(text).matchAll(/(^|\s)#([\p{L}\p{N}_]+)/gu)].map((m) => m[2]);

/// Its hashtags: the builders' own, then its kind and its tags, 5 at most.
function hashtagsOf(facts) {
  const out = [];
  for (const word of ["moc", "afol", facts.kind, ...(facts.tags || []), "bricks", "brickbuilding"]) {
    const tag = tagOf(word);
    if (tag && !out.includes(tag)) out.push(tag);
  }
  return out.slice(0, LIMITS.hashtags);
}

/// The words of a kit for [place]: {title, flair, credit, words}, each ""
/// where the place has none; [words] is what is pasted under the post (a
/// Reddit comment, Instagram's caption, a description), and carries the
/// model's link.
export function wordsOf(place, facts) {
  const pieces = counted(facts.pieces, "piece", "pieces");
  const others = othersDesign(facts);
  const credits = (facts.credits || []).map(creditLine);
  const link = say("Turn it in 3D, build it step by step and get its parts list, free: {link}", { link: facts.url });
  const head = `${facts.name}: ${pieces}, ${madeWords(facts)}.`;
  if (place === "legomoc" || place === "lego") {
    const flair = others.length ? "SEC" : "MOC";
    return { title: `[${flair}] ${facts.name}, ${pieces}`, flair, credit: credits.join("\n"),
      words: [head, ...credits, link].join("\n\n") };
  }
  if (place === "instagram") {
    const tags = hashtagsOf(facts).map((tag) => `#${tag}`).join(" ");
    return { title: "", flair: "", credit: credits.join("\n"),
      words: [`${head}${credits.length ? ` ${credits.join(" · ")}` : ""}`, link, tags].join("\n\n") };
  }
  if (place === "ideas") {
    return { title: facts.name, flair: "", credit: credits.join("\n"),
      words: [facts.about || head, credits.length ? credits.join("\n") : "", link].filter(Boolean).join("\n\n") };
  }
  if (place === "rebrickable") {
    return { title: facts.name, flair: "", credit: credits.join("\n"),
      words: [facts.about || head, ...credits, link].filter(Boolean).join("\n\n") };
  }
  // Flickr: a title, its words and its tags (Flickr's tags have no #).
  return { title: facts.name, flair: "", credit: credits.join("\n"),
    words: [head, ...credits, link].join("\n\n"), tags: hashtagsOf(facts).join(" ") };
}

// ---------------------------------------------------------------------------
// Its rules.

/// A rule as checked: [rule] what it says, [page] where it is said, [how]
/// "keeps" (the kit keeps it), "fails" (it does not, [said] why) or
/// "yours" (one only the person who posts can keep, said once).
const rule = (id, page, how, words, said = "") => ({ id, page, how, rule: words, said });

/// [place]'s rules, each checked against the kit [made] for [facts]:
/// [made] is {images: [{name, width, height, drawn}], clip: {kind, ms,
/// width, height} or null, words (wordsOf), csv, bytes}.
export function checksOf(place, facts, made) {
  const images = made.images || [];
  const out = [];
  const link = String(made.words?.words || "").includes(facts.url);
  if (place === "legomoc" || place === "lego") {
    const page = PAGES[place];
    const [least, most] = LIMITS.redditImages;
    out.push(rule("images", page, images.length >= least && images.length <= most ? "keeps" : "fails",
      say("A post of its pictures: 1 to 20"), say("This kit has {n}", { n: images.length })));
    const others = othersDesign(facts);
    const flair = made.words?.flair;
    out.push(rule("flair", page, flair === (others.length ? "SEC" : "MOC") ? "keeps" : "fails",
      others.length ? say("SEC: somebody else's design, its designer credited") : say("MOC: your own design"),
      say("The flair is {flair}", { flair: String(flair) })));
    if (others.length) {
      const credited = others.every((one) => !one.by || String(made.words?.words).includes(one.by));
      out.push(rule("credit", page, credited ? "keeps" : "fails", say("Somebody else's design names its designer"),
        say("The words do not name {name}", { name: others.map((one) => one.by).join(", ") })));
    }
    if (place === "legomoc") {
      out.push(rule("ai", page, facts.made === "assistant" ? "fails" : "keeps", say("No posts of AI-made models"),
        say("r/legomoc does not take posts of models made with AI, and this one was made with the assistant. "
          + "This kit is not for r/legomoc.")));
    } else {
      out.push(rule("one-in-ten", page, "yours", say("At most one post in ten of yours may be one that can earn you money")));
    }
    out.push(rule("link", page, link ? "keeps" : "fails", say("The words carry its link")));
    return out;
  }
  if (place === "instagram") {
    const [cw, ch] = LIMITS.cover;
    const [tw, th] = LIMITS.turn;
    const cover = images[0];
    const clip = made.clip;
    const tags = hashtagsIn(made.words?.words || "");
    out.push(rule("cover", PAGES.instagram, cover && cover.width === cw && cover.height === ch ? "keeps" : "fails",
      say("A portrait picture, 1080 × 1350"), cover ? `${cover.width} × ${cover.height}` : say("None was drawn")));
    out.push(rule("turn", PAGES.instagram, clip && clip.width === tw && clip.height === th && clip.ms <= LIMITS.turnSeconds * 1000
      && clip.kind === "mp4" ? "keeps" : "fails",
    say("A full-screen turn, 1080 × 1920, 15 s or less, as an MP4"), !clip ? say("This browser could not record a turn")
      : clip.kind !== "mp4" ? say("This browser records WebM, which Instagram does not take: make the kit in Chrome, Edge or Safari")
        : `${clip.width} × ${clip.height}, ${clip.ms / 1000} s`));
    out.push(rule("hashtags", PAGES.hashtags, tags.length <= LIMITS.hashtags ? "keeps" : "fails", say("5 hashtags at most"),
      say("The caption has {n}", { n: tags.length })));
    out.push(rule("link", PAGES.instagram, link ? "keeps" : "fails", say("The caption carries its link")));
    return out;
  }
  if (place === "ideas") {
    const page = PAGES.ideas;
    const [least, most] = LIMITS.ideasPieces;
    const main = images[0];
    out.push(rule("pieces", page, facts.pieces >= least && facts.pieces <= most ? "keeps" : "fails",
      say("200 to 5,000 pieces"), say("This has {pieces}", { pieces: counted(facts.pieces, "piece", "pieces") })));
    out.push(rule("images", page, images.length >= 1 && images.length <= LIMITS.ideasImages ? "keeps" : "fails",
      say("15 pictures at most"), say("This kit has {n}", { n: images.length })));
    // What Brickworks drew on it, read from its drawing (web/turntable-clip.js
    // easel), not from the picture.
    const text = main ? main.drawn?.text || [] : [];
    out.push(rule("no-text", page, main && main.drawn && text.length === 0 ? "keeps" : "fails", say("No text on the main picture"),
      main ? say("It has {words} on it", { words: text.join(", ") || "?" }) : say("None was drawn")));
    const plain = main && main.drawn && main.drawn.layers.every((layer) => ["backdrop", "model"].includes(layer));
    out.push(rule("no-box-art", page, plain ? "keeps" : "fails", say("No box art: the model itself, on a plain ground"),
      say("Its main picture has more than the model on it")));
    out.push(rule("renders", page, "keeps", say("Pictures drawn from a digital model are taken")));
    const others = othersDesign(facts);
    out.push(rule("own", page, others.length ? "fails" : "keeps", say("Your own idea"),
      say("It is somebody else's design: {credit}", { credit: others.map(creditLine).join("; ") })));
    out.push(rule("link", page, link ? "keeps" : "fails", say("The words carry its link")));
    return out;
  }
  if (place === "rebrickable") {
    const csv = String(made.csv || "");
    const lines = csv.trim().split("\n");
    out.push(rule("parts", PAGES.rebrickableParts, lines[0].toLowerCase() === "part,color,quantity" && lines.length > 1 ? "keeps" : "fails",
      say("Its parts as a CSV Rebrickable imports"), say("No parts list came")));
    out.push(rule("instructions", PAGES.rebrickableSteps, "yours", say("Building instructions: pictures, a PDF or the model's file"),
      say("Brickworks keeps no PDF of its booklet: open it in the viewer and save it as a PDF")));
    out.push(rule("images", PAGES.rebrickableSteps, images.length >= 1 ? "keeps" : "fails", say("Pictures of it"),
      say("This kit has {n}", { n: images.length })));
    out.push(rule("link", PAGES.rebrickableSteps, link ? "keeps" : "fails", say("The words carry its link")));
    return out;
  }
  const largest = images[0];
  out.push(rule("largest", PAGES.flickr, largest && Math.max(largest.width, largest.height) >= LIMITS.flickrSide ? "keeps" : "fails",
    say("Its largest picture"), largest ? `${largest.width} × ${largest.height}` : say("None was drawn")));
  out.push(rule("pool", PAGES.flickr, "yours", say("Add it to the LEGO® Pool from its page on Flickr")));
  out.push(rule("link", PAGES.flickr, link ? "keeps" : "fails", say("The words carry its link")));
  return out;
}

/// Whether a kit keeps every rule it can.
export const keepsAll = (checks) => checks.every((one) => one.how !== "fails");

/// The kit's words and rules as a text file (post.txt in its zip), every
/// rule with its page.
export function postText(place, facts, words, checks, name) {
  const mark = { keeps: "✓", fails: "✗", yours: "·" };
  return [
    say("A kit to post {name} on {place}", { name: facts.name, place: name }),
    "",
    ...(words.title ? [`${say("Title")}: ${words.title}`] : []),
    ...(words.flair ? [`${say("Flair")}: ${words.flair}`] : []),
    ...(words.tags ? [`${say("Tags")}: ${words.tags}`] : []),
    "",
    words.words,
    "",
    say("Its rules"),
    ...checks.map((one) => `${mark[one.how]} ${one.rule}${one.how === "fails" && one.said ? `: ${one.said}` : ""} (${one.page})`),
    "",
    say("Brickworks posts nothing: you post this yourself, from your own account."),
    ...(place === "ideas" ? [say("Brickworks is not the LEGO Group. LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this site.")] : []),
    "",
  ].join("\n");
}

/// A file's name as a kit names it: lower case, words joined by a dash.
export const slugOf = (name) => String(name || "model").toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "-")
  .replace(/^-+|-+$/g, "").slice(0, 60) || "model";

/// How big a kit is, as said: "12.4 MB".
export const sizeSaid = (bytes) => (bytes >= 1048576 ? `${number(Math.round((bytes / 1048576) * 10) / 10)} MB`
  : `${number(Math.max(1, Math.round(bytes / 1024)))} KB`);

// ---------------------------------------------------------------------------
// One zip, its files stored as they are: pictures and clips are made
// smaller by nothing a zip does.

let table = null;
function crc32(bytes) {
  if (!table) {
    table = new Uint32Array(256);
    for (let n = 0; n < 256; n++) {
      let c = n;
      for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      table[n] = c >>> 0;
    }
  }
  let crc = 0xffffffff;
  for (let i = 0; i < bytes.length; i++) crc = table[(crc ^ bytes[i]) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

/// [files] ({name, bytes}) as one zip, in pieces to put in a Blob (or join):
/// {parts, size}. Each name in UTF-8, each file stored, dated [when].
export function zipOf(files, when = new Date()) {
  const encoder = new TextEncoder();
  const time = ((when.getHours() << 11) | (when.getMinutes() << 5) | Math.floor(when.getSeconds() / 2)) & 0xffff;
  const date = (((when.getFullYear() - 1980) << 9) | ((when.getMonth() + 1) << 5) | when.getDate()) & 0xffff;
  const parts = [];
  const central = [];
  let at = 0;
  for (const file of files) {
    const name = encoder.encode(file.name);
    const crc = crc32(file.bytes);
    const size = file.bytes.length;
    const head = new DataView(new ArrayBuffer(30));
    head.setUint32(0, 0x04034b50, true);
    head.setUint16(4, 20, true);
    head.setUint16(6, 0x0800, true);
    head.setUint16(8, 0, true);
    head.setUint16(10, time, true);
    head.setUint16(12, date, true);
    head.setUint32(14, crc, true);
    head.setUint32(18, size, true);
    head.setUint32(22, size, true);
    head.setUint16(26, name.length, true);
    head.setUint16(28, 0, true);
    parts.push(new Uint8Array(head.buffer), name, file.bytes);
    const entry = new DataView(new ArrayBuffer(46));
    entry.setUint32(0, 0x02014b50, true);
    entry.setUint16(4, 20, true);
    entry.setUint16(6, 20, true);
    entry.setUint16(8, 0x0800, true);
    entry.setUint16(10, 0, true);
    entry.setUint16(12, time, true);
    entry.setUint16(14, date, true);
    entry.setUint32(16, crc, true);
    entry.setUint32(20, size, true);
    entry.setUint32(24, size, true);
    entry.setUint16(28, name.length, true);
    entry.setUint32(42, at, true);
    central.push(new Uint8Array(entry.buffer), name);
    at += 30 + name.length + size;
  }
  const directory = central.reduce((n, part) => n + part.length, 0);
  const end = new DataView(new ArrayBuffer(22));
  end.setUint32(0, 0x06054b50, true);
  end.setUint16(8, files.length, true);
  end.setUint16(10, files.length, true);
  end.setUint32(12, directory, true);
  end.setUint32(16, at, true);
  parts.push(...central, new Uint8Array(end.buffer));
  return { parts, size: at + directory + 22 };
}
