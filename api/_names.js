// What a name in the directory may not say (2026-10-13): a model's title,
// its tags, a profile's handle and name, a collection's name, and words in
// a description or a report's note.
//
// Two kinds of word. Abuse — slurs and obscenities — is refused anywhere a
// stranger's words are shown. And names that are somebody else's —
// the LEGO Group's own marks, and the licensed names of films, books and
// games their sets are made under — are refused in a title, a tag, a
// handle or a profile's name, as Rebrickable refuses them in fan models'
// names (docs/TRADEMARKS.md, "Licensed names are someone else's"): a model
// is "a wizard's tower", not the film's. A description may still say what
// inspired it.
//
// Words are compared after the usual disguises come off: case, accents,
// letters doubled, digits and symbols standing for letters (4 for a, 3 for
// e, 0 for o, $ for s), and spaces or dots between the letters of a short
// word. Whole words only, so a place or a name that contains one of them
// ("Scunthorpe", "assassin", "Dickens") is not refused for it.

// Kept as a short list, each a word that is abuse wherever it appears.
// Plural and simple forms are matched by stem (below).
const ABUSE = [
  "fuck", "fucker", "fucking", "motherfucker", "shit", "bullshit", "cunt", "twat", "wanker",
  "bitch", "bastard", "whore", "slut", "cock", "dick", "pussy", "asshole", "arsehole", "dildo",
  "porn", "porno", "nazi", "hitler", "kkk", "rape", "rapist", "pedo", "paedo", "pedophile",
  "paedophile", "nigger", "nigga", "faggot", "fag", "dyke", "tranny", "retard", "retarded",
  "spic", "chink", "gook", "kike", "wetback", "coon", "raghead", "towelhead", "beaner",
  "sieg heil", "white power", "gas the", "kill yourself", "kys",
];

// The LEGO Group's own marks a title must not use as its name, and the
// licensed names its sets are made under (the catalogue's set names carry
// them: Star Wars, Harry Potter, Disney, DC, Marvel, Jurassic World...),
// each with how it is written when a refusal names it. Not the names of
// kinds of part (Technic, minifigure): those are what a part is, as the
// LDraw library and every shop names them. Not words a model may simply
// be ("frozen", "thor"): only names that are nothing but the mark.
const OWNED = [
  ["lego", "LEGO®"], ["duplo", "DUPLO®"], ["mindstorms", "MINDSTORMS®"], ["ninjago", "NINJAGO®"],
  ["bionicle", "BIONICLE®"], ["star wars", "Star Wars"], ["jedi", "Jedi"], ["millennium falcon", "Millennium Falcon"],
  ["x wing", "X-wing"], ["tie fighter", "TIE fighter"], ["death star", "Death Star"],
  ["mandalorian", "Mandalorian"], ["harry potter", "Harry Potter"], ["hogwarts", "Hogwarts"],
  ["marvel", "Marvel"], ["avengers", "Avengers"], ["spider man", "Spider-Man"], ["spiderman", "Spider-Man"],
  ["iron man", "Iron Man"], ["batman", "Batman"], ["batmobile", "Batmobile"], ["superman", "Superman"],
  ["dc comics", "DC Comics"], ["disney", "Disney"], ["pixar", "Pixar"], ["jurassic world", "Jurassic World"],
  ["jurassic park", "Jurassic Park"], ["lord of the rings", "The Lord of the Rings"], ["hobbit", "The Hobbit"],
  ["orthanc", "Orthanc"], ["rivendell", "Rivendell"], ["minas tirith", "Minas Tirith"],
  ["minecraft", "Minecraft"], ["super mario", "Super Mario"], ["nintendo", "Nintendo"],
  ["pokemon", "Pokémon"], ["ghostbusters", "Ghostbusters"], ["wakanda", "Wakanda"],
  ["indiana jones", "Indiana Jones"], ["toy story", "Toy Story"], ["mickey mouse", "Mickey Mouse"],
  ["ferrari", "Ferrari"], ["lamborghini", "Lamborghini"], ["porsche", "Porsche"], ["mclaren", "McLaren"],
  ["bugatti", "Bugatti"],
];

// Handles that would say something that is not so: that a person is this
// site, speaks for it, or is the LEGO Group.
export const RESERVED = new Set(["admin", "administrator", "api", "app", "brickworks", "gallery",
  "help", "moderator", "mod", "official", "root", "staff", "support", "system", "team", "profile",
  "settings", "about", "contact", "takedown", "report", "security", "abuse", "legal", "privacy"]);

const LEET = { 0: "o", 1: "i", 3: "e", 4: "a", 5: "s", 7: "t", 8: "b", "@": "a", $: "s", "!": "i", "|": "i", "+": "t" };

/// The words of [text] as they are compared: lower case, accents off,
/// stand-ins for letters put back, letters run together where a short word
/// was spelt out with gaps ("f u c k", "s.h.i.t"), doubled letters single.
export function plainWords(text) {
  let said = String(text || "").toLowerCase().normalize("NFKD").replace(/[̀-ͯ]/g, "");
  said = said.replace(/[0134578@$!|+]/g, (c) => LEET[c] || c);
  // Single letters with gaps between them, three or more: one word.
  said = said.replace(/\b(?:[a-z][\s.\-_*]+){2,}[a-z]\b/g, (run) => run.replace(/[\s.\-_*]+/g, ""));
  return said.replace(/[^a-z]+/g, " ").replace(/([a-z])\1{2,}/g, "$1$1").trim();
}

function stems(word) {
  const out = new Set([word]);
  for (const end of ["ing", "ers", "er", "es", "s", "ed", "y"]) {
    if (word.length > end.length + 2 && word.endsWith(end)) out.add(word.slice(0, -end.length));
  }
  out.add(word.replace(/([a-z])\1/g, "$1"));
  return out;
}

/// Whether the words of [text] contain [phrase], whole words, each word of
/// the text also tried by its stems.
function says(text, phrase) {
  const words = text.split(" ").filter(Boolean);
  const wanted = phrase.split(" ");
  // A name run together ("starwars", "harrypotter") is the name too.
  const joined = wanted.join("");
  for (let at = 0; at < words.length; at += 1) {
    if (wanted.length > 1 && [...stems(words[at])].includes(joined)) return true;
    let all = true;
    for (let k = 0; k < wanted.length; k += 1) {
      const word = words[at + k];
      if (!word || ![...stems(word)].includes(wanted[k])) {
        all = false;
        break;
      }
    }
    if (all) return true;
  }
  return false;
}

/// What is wrong with [text] as [what], in words for the person who typed
/// it, or "" when nothing is. [kind] is "name" (a title, a tag, a handle, a
/// profile's or a collection's name), which may not use somebody else's
/// name, or "words" (a description, a note), which may.
export function nameTrouble(text, what, kind = "name") {
  const plain = plainWords(text);
  if (!plain) return "";
  for (const word of ABUSE) {
    if (says(plain, word)) return `${what} has a word in it the gallery does not show: say it another way`;
  }
  if (kind === "name") {
    for (const [word, shown] of OWNED) {
      if (says(plain, word)) {
        return `${what} uses ${shown}, a name somebody else owns: describe the model instead `
          + "(a wizard's tower, a starfighter, a red sports car), and say what inspired it in its description";
      }
    }
  }
  return "";
}

/// The same for a handle: also never one that would pass for this site's.
export function handleTrouble(handle) {
  if (RESERVED.has(handle)) return "that handle is kept for Brickworks itself: choose another";
  const plain = plainWords(handle.replace(/-/g, " "));
  for (const word of ABUSE) if (says(plain, word)) return "that handle has a word in it the gallery does not show: choose another";
  for (const [word, shown] of OWNED) {
    if (says(plain, word)) return `that handle uses ${shown}, a name somebody else owns: choose another`;
  }
  return "";
}

/// Each of [said] ({what: [text, kind]}) checked: the first trouble, or "".
export function namesTrouble(said) {
  for (const [what, [text, kind]] of Object.entries(said)) {
    if (text === null || text === undefined || text === "") continue;
    const trouble = nameTrouble(Array.isArray(text) ? text.join(", ") : String(text), what, kind);
    if (trouble) return trouble;
  }
  return "";
}
