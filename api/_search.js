// The site's search (search, 2026-10-30): what a builder types, matched as
// they mean it and ranked by how well it matches. The owner found the
// library's search "doesn't work very well at all": "death star" put Death
// Trooper first, "deathstar" and "milenium falcon" found nothing, "castle"
// came newest first, and books and key chains ranked with real sets. The
// library (api/_sets.js searchCatalog) and the gallery's question
// (api/_directory.js searchWords) both read their words here.
//
// A search is read word by word, each word a slot that a set must fill:
//   - the word itself, plural or not ("castles" is castle), accents and
//     apostrophes not minded ("pokemon" is Pokémon, "kings" is King's);
//   - the start of a word while it is still being typed ("hogw");
//   - a word misspelt, one letter off for a word of four to seven, two for a
//     longer one ("milenium", "catsle"), when the word as typed is unknown
//     or rare beside the word it is nearly;
//   - two words written as one ("deathstar", "xwing", "r2d2"), as written
//     apart in a name, and one word written as two ("fire truck" finds
//     Firetruck), and a word that is half of a compound ("ship" finds
//     Spaceship);
//   - an abbreviation builders use (UCS, LOTR);
//   - a set's number, whole or its start ("10188", "10188-1", "7519");
//   - a year ("castle 1978").
// Small words (the, of, LEGO, set) need not match.
//
// Ranked (rank), best first: a set's number asked; then a set whose whole
// name was typed; then every word in its name; then every word anywhere
// (name, theme, number or year). A query that names a theme ("harry
// potter", "modular") counts the theme's sets as named. Books, gear, key
// chains, magnets, posters and promotions go after real sets unless the
// query asks for them. Within each, exact words before corrected ones, more
// of the name typed first, and then the bigger set (its own parts, not the
// sets packed in it) and the newer. When no set has every word, the sets
// with the most of them are answered instead (near).

/// Words a query may hold that a set need not: they narrow nothing.
export const SMALL = new Set(["the", "a", "an", "of", "and", "lego", "set", "with", "for", "in", "on", "by", "to", "kit"]);

/// What a word is short for: its words, each to be found somewhere in a
/// set's name or theme.
const SHORT_FOR = {
  ucs: "ultimate collector series",
  lotr: "lord of the rings",
  hp: "harry potter",
  sw: "star wars",
  tmnt: "teenage mutant ninja turtles",
  bdp: "bricklink designer program",
  cmf: "collectible minifigures",
  lambo: "lamborghini",
  vw: "volkswagen",
};

/// Words that ask for what is not a set to build: a query with one of these
/// ranks books, gear and promotions as it ranks sets.
const ASKS_FOR_GEAR = new Set(["book", "gear", "keychain", "key", "chain", "magnet", "poster", "charm", "promo",
  "promotional", "mug", "shirt", "watch", "clock", "bag", "pen", "pencil", "plush", "game", "puzzle", "sticker",
  "sweepstake", "magazine", "costume", "tag", "print", "art", "notebook", "backpack", "lamp"]);
/// Words in a name that say it is not a set to build.
const GEAR_NAME = /\b(key ?chains?|magnets?|bag charms?|posters?|promo|promotional|sweepstakes?)\b/i;
/// Top themes that are not sets to build.
const GEAR_THEMES = new Set(["Gear", "Books", "Promotional"]);

/// How good a slot's match is, by what matched.
const EXACT = 1;
// A compound written either way is the word: "treehouse" is Tree House.
const JOINED = EXACT;
const SPLIT = EXACT;
const PART = 0.75;
const PREFIX = 0.7;
const NEAR_1 = 0.6;
const NEAR_2 = 0.45;
/// A theme's words count for less than the name's.
const THEME = 0.6;

/// Lower case, accents off, apostrophes out ("King's" is kings), "&" as and.
export function fold(text) {
  return String(text || "").normalize("NFKD").replace(/[̀-ͯ]/g, "").toLowerCase()
    .replace(/['’‘`´]/g, "").replace(/&/g, " and ");
}

/// The words of [text], folded: letters and digits.
export const wordsOf = (text) => fold(text).match(/[\p{L}\p{N}]+/gu) || [];

/// A word as one of a kind: "castles" is castle, "batteries" battery,
/// "boxes" box. Both a set's words and a query's are taken so, alike.
export function stem(word) {
  if (word.length > 4 && word.endsWith("ies")) return `${word.slice(0, -3)}y`;
  if (word.length > 4 && /(ss|x|z|ch|sh)es$/.test(word)) return word.slice(0, -2);
  if (word.length > 3 && word.endsWith("s") && !/(ss|us|is)$/.test(word)) return word.slice(0, -1);
  return word;
}

/// The edit distance between [a] and [b], a swap of two letters one edit,
/// or more than [most] as soon as it must be.
export function distance(a, b, most = 2) {
  if (Math.abs(a.length - b.length) > most) return most + 1;
  let before = null;
  let last = Array.from({ length: b.length + 1 }, (_, j) => j);
  for (let i = 1; i <= a.length; i += 1) {
    const row = [i];
    let least = i;
    for (let j = 1; j <= b.length; j += 1) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      let d = Math.min(last[j] + 1, row[j - 1] + 1, last[j - 1] + cost);
      if (before && i > 1 && j > 1 && a[i - 1] === b[j - 2] && a[i - 2] === b[j - 1]) d = Math.min(d, before[j - 2] + 1);
      row.push(d);
      least = Math.min(least, d);
    }
    if (least > most) return most + 1;
    before = last;
    last = row;
  }
  return last[b.length];
}

/// How far off a word of [length] letters may be typed.
const slack = (length) => (length >= 8 ? 2 : length >= 4 ? 1 : 0);

/// What a set's number may be typed as: "10188-1", "375-2", "k4852".
const NUMBER = /^[a-z0-9]+(?:[.-][a-z0-9]+)*$/;

// ---------------------------------------------------------------------------
// The index: every word of every name and theme, once.

const indexes = new WeakMap();

/// The words of [items] as a search reads them, kept while [items] is the
/// same list: each item's name's words in order and its themes', every word
/// there is with how many items' names hold it, and each item's own parts.
/// An item is {name, theme: [names, outermost first], set?, year?, parts?,
/// inside?}, as api/_sets.js useCatalog makes a set.
export function indexOf(items) {
  if (indexes.has(items)) return indexes.get(items);
  const ids = new Map();
  const words = [];
  const count = [];
  // As typed, for a word's start: each word's own spelling, to its stem.
  const spelt = new Map();
  const idOf = (word) => {
    let id = spelt.get(word);
    if (id !== undefined) return id;
    const key = stem(word);
    id = ids.get(key);
    if (id === undefined) {
      id = words.length;
      ids.set(key, id);
      words.push(key);
      count.push(0);
    }
    spelt.set(word, id);
    return id;
  };
  const themes = new Map();
  const themeList = [];
  const themeOf = (name) => {
    if (!themes.has(name)) {
      const of = wordsOf(name);
      themes.set(name, themeList.length);
      themeList.push({ name, words: Int32Array.from(of.map(idOf)), big: of.filter((one) => !SMALL.has(one)).length });
    }
    return themes.get(name);
  };
  const partsOf = new Map(items.map((item) => [String(item.set || "").toLowerCase(), Number(item.parts) || 0]));
  // Which item last counted each word, so an item counts a word once.
  const counted = [];
  const rows = items.map((item, at) => {
    const said = wordsOf(item.name);
    const name = new Int32Array(said.length);
    // The words of its name that matter, a bit each: all but the small ones.
    let bits = 0;
    said.forEach((one, i) => {
      name[i] = idOf(one);
      if (!SMALL.has(one) && i <= 30) bits |= 2 ** i;
    });
    const set = String(item.set || "").toLowerCase();
    const theme = (item.theme || []).map(themeOf);
    // How many items have each word, in their name or their theme's.
    while (counted.length < words.length) counted.push(-1);
    for (const id of name) if (counted[id] !== at) count[id] += (counted[id] = at, 1);
    for (const t of theme) for (const id of themeList[t].words) if (counted[id] !== at) count[id] += (counted[id] = at, 1);
    // The sets packed in it are not its own: a pack of ten is not big.
    let packed = 0;
    for (const [other, n] of item.inside || []) packed += (partsOf.get(String(other).toLowerCase()) || 0) * (Number(n) || 1);
    const gear = GEAR_THEMES.has((item.theme || [])[0]) || GEAR_NAME.test(item.name) || (item.set && !(Number(item.parts) > 0));
    return { name, bits, theme: Int32Array.from(theme), set, base: set.split("-")[0],
      year: Number(item.year) || 0, own: Math.max(0, (Number(item.parts) || 0) - packed), gear };
  });
  // A word that is two others ("spaceship"): each half, four letters or
  // more, finds it too.
  const halves = new Map();
  for (const [word, id] of spelt) {
    for (let at = 4; at <= word.length - 4; at += 1) {
      const head = word.slice(0, at);
      const tail = word.slice(at);
      if (!spelt.has(head) || !spelt.has(tail)) continue;
      for (const half of [spelt.get(head), spelt.get(tail)]) {
        if (!halves.has(half)) halves.set(half, []);
        halves.get(half).push(id);
      }
    }
  }
  const index = { ids, words, count, spelt, themes: themeList, rows, halves };
  indexes.set(items, index);
  return index;
}

// ---------------------------------------------------------------------------
// A query, read.

/// [q] as slots, each a word the sets must have one way or another:
/// {said (as typed), small, single (word id -> how good), runs (words in a
/// row, from a word typed as one or with a hyphen), bags (every word
/// somewhere, from an abbreviation), number, year, and what it may have been
/// meant as: meant (an abbreviation's words), nearly (the word it is nearly),
/// apart ({ids, said}: the words it runs together, when it is no word the
/// sets have), and split (the same, whether or not it is, unless it is a
/// word still being typed)}; and joins, two slots one word ("fire truck").
export function readQuery(index, q) {
  const typed = fold(q).split(/\s+/).map((one) => one.replace(/^[^\p{L}\p{N}]+|[^\p{L}\p{N}]+$/gu, "")).filter(Boolean);
  const known = (word) => index.ids.get(stem(word));
  const slots = typed.map((token, at) => {
    const parts = token.match(/[\p{L}\p{N}]+/gu) || [];
    const slot = { said: token, small: parts.length === 1 && SMALL.has(parts[0]), single: new Map(), runs: [], bags: [],
      number: /\d/.test(token) && NUMBER.test(token) ? token : "", year: 0, meant: "" };
    const add = (id, good) => {
      if (id !== undefined && !(slot.single.get(id) >= good)) slot.single.set(id, good);
    };
    if (/^(19[4-9]\d|20[0-4]\d)$/.test(token)) slot.year = Number(token);
    if (parts.length > 1) {
      const run = parts.map(known);
      if (run.every((id) => id !== undefined)) slot.runs.push({ ids: run, good: EXACT });
      return slot;
    }
    const word = parts[0];
    const id = known(word);
    add(id, EXACT);
    const last = at === typed.length - 1;
    const seen = id === undefined ? 0 : index.count[id];
    const digits = /\d/.test(word);
    // Its start, while it is typed, or when it is no word at all.
    let typing = false;
    if ((last || id === undefined) && word.length >= 2) {
      for (const [spelling, other] of index.spelt) {
        if (spelling.length > word.length && spelling.startsWith(word)) {
          add(other, PREFIX);
          typing = true;
        }
      }
    }
    // Half a compound.
    for (const other of (id === undefined ? [] : index.halves.get(id) || [])) add(other, PART);
    // Two words written as one: "deathstar", "xwing", "r2d2". A word the
    // sets have is split only into words of three letters or more:
    // "castles" is not castle s.
    let split = null;
    const least = seen ? 3 : 1;
    for (let cut = least; cut <= word.length - least && word.length >= 4 && !/^\d+$/.test(word); cut += 1) {
      const head = known(word.slice(0, cut));
      const tail = known(word.slice(cut));
      if (head === undefined || tail === undefined) continue;
      slot.runs.push({ ids: [head, tail], good: SPLIT });
      const weight = Math.min(index.count[head], index.count[tail]);
      if (!split || weight > split.weight) split = { weight, ids: [head, tail], said: `${word.slice(0, cut)} ${word.slice(cut)}` };
    }
    // Misspelt: unknown, or rare beside a word one or two letters off. A
    // number is never misspelt: 1979 is not 1970.
    const most = digits ? 0 : slack(word.length);
    let best = null;
    if (most && seen < 3) {
      const key = stem(word);
      for (let other = 0; other < index.words.length; other += 1) {
        const spelling = index.words[other];
        if (other === id || index.count[other] < Math.max(1, seen * 10)) continue;
        const d = distance(key, spelling, most);
        if (d > most) continue;
        add(other, d === 1 ? NEAR_1 : NEAR_2);
        // The likeliest: a common word two letters off before a rare one
        // one letter off ("milenium" is millennium, not a mug's millenium).
        const likely = Math.log(index.count[other] + 1) - 1.5 * d;
        if (!best || likely > best.likely) best = { likely, id: other };
      }
    }
    const short = SHORT_FOR[word] ? wordsOf(SHORT_FOR[word]).filter((one) => !SMALL.has(one)).map(known) : [];
    if (short.length && short.every((one) => one !== undefined)) slot.bags.push({ ids: short, good: EXACT });
    // What it may have been meant as, for "Showing sets for …": only a word
    // the sets do not have (or barely), and not one still being typed.
    // search takes the one its best find has.
    slot.split = seen || !typing ? split : null;
    if (seen === 0 && slot.bags.length) slot.meant = SHORT_FOR[word];
    else if (!typing) {
      if (seen < 3 && best) slot.nearly = spellingOf(index, best.id, word);
      if (seen === 0 && split) slot.apart = split;
    }
    return slot;
  });
  // One word written as two: "fire truck" is Firetruck.
  const joins = [];
  for (let at = 0; at + 1 < slots.length; at += 1) {
    const id = index.ids.get(stem(`${slots[at].said}${slots[at + 1].said}`));
    if (id !== undefined && /^[\p{L}\p{N}]+$/u.test(`${slots[at].said}${slots[at + 1].said}`)) joins.push({ at, id });
  }
  // Small words matter only in a query of nothing else.
  if (slots.every((slot) => slot.small)) for (const slot of slots) slot.small = false;
  const asksGear = slots.some((slot) => ASKS_FOR_GEAR.has(stem(slot.said)) || ASKS_FOR_GEAR.has(slot.said));
  return { slots, joins, asksGear };
}

/// What [query] was taken to mean, as its best find [row] has it: each word
/// corrected as written apart where the find's name has it so ("deathstar"
/// is death star), else as the word it nearly is ("catsle" is castle); ""
/// when every word is as typed.
function meantBy(query, row) {
  const said = query.slots.map((slot) => {
    if (slot.meant) return slot.meant;
    const apart = slot.apart && row && [...row.name].some((id, i) => id === slot.apart.ids[0] && row.name[i + 1] === slot.apart.ids[1]);
    return apart ? slot.apart.said : slot.nearly || (slot.apart ? slot.apart.said : "");
  });
  return said.some(Boolean) ? said.map((one, i) => one || query.slots[i].said).join(" ") : "";
}

/// A word id as a person would read it: the spelling the sets have that
/// stems to it, nearest [typed]'s length.
function spellingOf(index, id, typed) {
  let best = index.words[id];
  for (const [spelling, other] of index.spelt) {
    if (other === id && Math.abs(spelling.length - typed.length) < Math.abs(best.length - typed.length)) best = spelling;
  }
  return best;
}

// ---------------------------------------------------------------------------
// Each item, against a query.

/// How well [ids] (a name's or a theme's words) fills [slot]: {good, at
/// (the words it covers, a bit each)}.
function fill(slot, ids) {
  let good = 0;
  let at = 0;
  for (let i = 0; i < ids.length; i += 1) {
    const one = slot.single.get(ids[i]);
    if (one > good) {
      good = one;
      at = 2 ** Math.min(i, 30);
    }
  }
  for (const run of slot.runs) {
    if (run.good <= good) continue;
    for (let i = 0; i + run.ids.length <= ids.length; i += 1) {
      if (run.ids.every((id, k) => ids[i + k] === id)) {
        good = run.good;
        at = run.ids.reduce((bits, _, k) => bits | 2 ** Math.min(i + k, 30), 0);
        break;
      }
    }
  }
  for (const bag of slot.bags) {
    if (bag.good <= good) continue;
    const where = bag.ids.map((id) => ids.indexOf(id));
    if (where.every((i) => i >= 0)) {
      good = bag.good;
      at = where.reduce((bits, i) => bits | 2 ** Math.min(i, 30), 0);
    }
  }
  return { good, at };
}

/// How each theme fills the query's slots: per theme, per slot, how good;
/// and whether the query names it (every slot in its name, and half of its
/// name's words or more), how much of it.
function themesFilled(index, query) {
  return index.themes.map((theme) => {
    const goods = query.slots.map((slot) => fill(slot, theme.words));
    for (const join of query.joins) {
      if (theme.words.includes(join.id)) goods[join.at] = goods[join.at + 1] = { good: JOINED, at: goods[join.at].at };
    }
    let named = 0;
    // A year or a number narrows a theme's sets, it does not name another.
    const big = query.slots.filter((slot) => !slot.small && !slot.year && !(slot.number && !slot.single.size));
    if (big.length && big.every((slot) => goods[query.slots.indexOf(slot)].good >= PREFIX)) {
      const covered = goods.reduce((bits, one) => bits | one.at, 0);
      let n = 0;
      for (let bits = covered; bits; bits &= bits - 1) n += 1;
      named = theme.big ? Math.min(1, n / theme.big) : 0;
      if (named < 0.5) named = 0;
    }
    return { goods: goods.map((one) => one.good), named };
  });
}

/// Every item [keep] keeps that [q] finds, each {item, key} with key the
/// order best match puts it in (lower first: compare with byKey), and
/// whether they are the nearest (near: none has every word) and what the
/// query was taken to mean (meant, "" when as typed).
export function search(items, q, keep = () => true) {
  const index = indexOf(items);
  const query = readQuery(index, q);
  const slots = query.slots;
  const needed = slots.filter((slot) => !slot.small).length;
  const themes = themesFilled(index, query);
  const found = [];
  let full = false;
  for (let i = 0; i < items.length; i += 1) {
    if (!keep(items[i])) continue;
    const row = index.rows[i];
    let matched = 0;
    let inName = 0;
    let sum = 0;
    let covered = 0;
    let named = 0;
    let numbered = false;
    const goods = new Array(slots.length);
    for (let s = 0; s < slots.length; s += 1) {
      const slot = slots[s];
      const own = fill(slot, row.name);
      let good = own.good;
      let where = good ? 1 : 0;
      covered |= own.at;
      for (let t = 0; t < row.theme.length; t += 1) {
        const there = themes[row.theme[t]];
        const g = there.goods[s] * (there.named ? 1 : THEME);
        if (g > good) {
          good = g;
          where = there.named ? 1 : 2;
        }
        named = Math.max(named, there.named);
      }
      if (slot.number) {
        if (row.set === slot.number || row.base === slot.number) {
          good = EXACT;
          where = 1;
          numbered = true;
        } else if (slot.number.length >= 3 && row.base.startsWith(slot.number) && good < NEAR_1) {
          good = NEAR_1;
          where = 1;
        }
      }
      if (slot.year && row.year === slot.year && good < EXACT) {
        good = EXACT;
        where = 3;
      }
      goods[s] = { good, where };
    }
    for (const join of query.joins) {
      if (row.name.includes(join.id)) {
        goods[join.at] = { good: JOINED, where: 1 };
        goods[join.at + 1] = { good: JOINED, where: 1 };
        covered |= 2 ** Math.min(row.name.indexOf(join.id), 30);
      }
    }
    for (let s = 0; s < slots.length; s += 1) {
      if (slots[s].small) continue;
      if (goods[s].good > 0) {
        matched += 1;
        sum += goods[s].good;
        if (goods[s].where !== 2) inName += 1;
      }
    }
    if (!matched) continue;
    const every = matched === needed;
    full ||= every;
    // How much of its name was typed: a name typed whole ranks first unless
    // another is ten times its size ("The Batmobile" before the 1989
    // Batmobile, which is before a 23-piece X-Wing).
    const bits = row.bits;
    let n = 0;
    for (let b = covered & bits; b; b &= b - 1) n += 1;
    let big = 0;
    for (let b = bits; b; b &= b - 1) big += 1;
    // A theme the query names counts as half its name typed: "castle" is
    // the sets named castle first, the Castle theme's after.
    const cover = Math.max(big ? n / big : 0, named / 2);
    const tier = numbered && every ? 0 : every && inName === needed ? 1 : every ? 2 : 3;
    const gear = row.gear && !query.asksGear ? 1 : 0;
    const quality = Math.round((sum / Math.max(1, needed)) * 20) / 20;
    const soft = 0.5 * cover + Math.log10(row.own + 1) / 4 + (row.year ? (row.year - 1950) / 2000 : 0);
    found.push({ item: items[i], at: i, matched, numbered: numbered && every, key: [gear, tier, -quality, -soft] });
  }
  // Every word in some, so only those; else the ones with the most.
  const kept = full ? found.filter((one) => one.matched === needed) : found;
  if (!full) for (const one of kept) one.key.unshift(-one.matched);
  const best = kept.reduce((top, one) => (!top || byKey(one, top) < 0 ? one : top), null);
  return { found: kept, near: !full && kept.length > 0, meant: best ? meantBy(query, index.rows[best.at]) : "" };
}

/// Two of search's finds in best-match order.
export function byKey(a, b) {
  for (let i = 0; i < a.key.length; i += 1) {
    if (a.key[i] !== b.key[i]) return a.key[i] - b.key[i];
  }
  return 0;
}
