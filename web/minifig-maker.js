// Make a minifig (figmaker, 2026-11-24): Edit profile's maker of a minifigure
// of real parts as your avatar, beside Choose a picture. The owner: "the 'make
// your minifig' for the profile builder needs to be way more advanced, way more
// features, more 'skin tones' and far better ui/ux".
//
// The figure is live in 3D (web/minifig3d.js, from tools/viewer/minifig.js),
// drawn from the parts themselves: a drag turns it, the arrow keys too, and a
// press on a part opens its group. The groups are tabs, skin first: Skin,
// Face, Hair and hats, Torso, Arms and hands, Legs, Accessories, Pose,
// Background. Each choice is a radio tile drawn from its part
// (web/minifig/tiles, tools/web/minifig_tiles.mjs) in the colour chosen, each
// group searchable; every change is one step of Undo and Redo; Surprise me
// keeps the groups locked; a handful of figures to start from. Beside the
// figure, the picture it will be at a byline's, a card's and a profile's
// size, on a light page and a dark one, head and shoulders or whole.
//
// Save draws that picture and gives it back with its recipe (web/
// minifig-parts.js figureShape) for web/profile.js to keep as your picture
// (api/_avatars.js); Cancel or Escape keeps what you had. A figure made in
// the maker before (v 1, layers) opens as the same figure. Loaded only when
// the maker is opened; the 3D and the parts only once it is.
//
// Hair of their own (sitehair, 2026-11-25): a mould a person made in the
// studio's minifig builder, signed in, is kept on their account
// (api/_moulds.js). Hair and hats lists them first, as Your own, each drawn
// from its own triangles in the colour chosen; one worn is seated where its
// base part sits, in the figure's colour, and the picture Save draws has it.
// The list is asked once a maker is opened, and each mould's text once a
// browser (it is kept for good: an id is its text).
import { appAt, say } from "/card.js";
import { call } from "/account.js";
import {
  AVATAR_COLOURS, CLEAR, COLOURS, FACES, GRADIENTS, HAIR, HAIR_COLOURS, HELD, LEGS, NECKS, PALETTE, PLAIN, POSES, POSE_RANGE,
  REAL_SKINS, SCENES, SKIN, SKINS, STARTERS, TILE, TORSOS, backgroundOf, figureShape, fromLayers, ownMould, tileGroups, tilesHash,
} from "/minifig-parts.js";

// The slots a mould is a minifigure's hair in (api/_moulds.js HAIR_SLOTS).
const HAIR_SLOTS = ["headwear"];

/// The person's own hair, kept on their account: [{id, name, base}], none
/// when they have none or it cannot be asked.
async function ownHair() {
  const answer = await call("/api/people?op=moulds").catch(() => null);
  if (!answer || answer.status !== 200 || !Array.isArray(answer.body?.moulds)) return [];
  return answer.body.moulds.filter((one) => ownMould(one?.id) && HAIR_SLOTS.includes(one.slot))
    .map(({ id, name, base }) => ({ id, base: String(base || ""), name: shortName(String(name || id)) || id }));
}
/// The studio's first line, "<the part's name>, Custom Mould <its title>",
/// as its title; a long one shown cut, with an ellipsis (its file keeps it).
function shortName(line) {
  const title = line.replace(/^.*,\s*Custom Mould\s+/i, "").trim();
  return title.length > 60 ? `${title.slice(0, 59)}…` : title;
}

/// The text of the mould [id], as the account keeps it: once a browser.
async function mouldText(id) {
  const answer = await call(`/api/people?op=mould&id=${encodeURIComponent(id)}`);
  if (answer.status !== 200 || typeof answer.body?.text !== "string") throw new Error(`HTTP ${answer.status}`);
  return answer.body.text;
}

// Every choice's name, said to a screen reader, searched, and a tile's
// title: literal words, for the translations (tools/site_lang.py).
const NAMES = () => ({
  // Faces.
  "3626cp01": say("Classic grin"), "3626cp7g": say("Smile"), "3626cp7h": say("Smile, brown eyebrows"),
  "3626cp8c": say("Smile with lips"), "3626cp8a": say("Soft smile with lips"), "3626cp71": say("Raised eyebrow and freckles"),
  "3626cp87": say("Glasses and smile"), "3626cp88": say("Grin with beard"), "3626cp84": say("Sunglasses"),
  "3626cp8b": say("Freckles and open smile"), "3626cp7c": say("Moustache and smile"), "3626cp73": say("Big smile"),
  "3626cp05": say("Crooked smile"), "3626cp0c": say("Open smile with lashes"), "3626cp0z": say("Lopsided smile, worried"),
  "3626cp14": say("Smirk"), "3626cp18": say("Frown"), "3626cp1d": say("Orange glasses, grin and frown"),
  "3626cp1e": say("Smile with teeth, surprised"), "3626cp1f": say("Smile with wrinkles"), "3626cp1g": say("Freckles, two smiles"),
  "3626cp1h": say("Scuffed smile"), "3626cp1m": say("Glasses and full beard"), "3626cp1o": say("Curly moustache"),
  "3626cp1p": say("Lopsided grin with teeth"), "3626cp1q": say("Nervous, sweating"), "3626cp40": say("Goatee and sideburns"),
  "3626cp70": say("Smile, queasy"), "3626cp72": say("Stubble and smirk"), "3626cp74": say("Grey beard, open mouth"),
  "3626cp75": say("Angry with headset"), "3626cp76": say("Black glasses and lips"), "3626cp78": say("Big smile, sad with a tear"),
  "3626cp7a": say("Grey stubble, sad"), "3626cp7b": say("Smile, eyes closed"), "3626cp7d": say("Red glasses and red lips"),
  "3626cp7e": say("Glasses and grey stubble"), "3626cp7f": say("Light blue glasses"), "3626cp7i": say("Goatee and soot"),
  "3626cp7j": say("Freckles, smiling and scared"), "3626cp7k": say("Square glasses and moustache"),
  "3626cp7l": say("Lashes and freckles"), "3626cp7n": say("Lopsided smile with dimple"), "3626cp7o": say("Laugh lines and smile"),
  "3626cp80": say("Stern, scared"), "3626cp83": say("Round red glasses and freckles"), "3626cp86": say("Moustache and stubble"),
  "3626cp8l": say("Silver glasses and pink lips"), "3626cp8r": say("Open smile, asleep"), "3626cp8s": say("Freckles, smile and worry"),
  "3626cp8t": say("White eyebrows and goatee"), "3626cp8u": say("Glasses, laughing"), "3626cp8v": say("Sunglasses and lips"),
  "3626cp8y": say("Round glasses"), "3626cpcf4": say("Black eye and plaster"), "3626cp30": say("Beard, gold teeth and eyepatch"),
  "3626cp0d": say("Freckles, small mouth"), "3626cp8w": say("Scared, lopsided smile"), "3626cp8q": say("Pensive smile, scared"),
  "28621p0i": say("Smile with hearing aid"), "28621p0k": say("Glasses, gap-toothed grin"), "28621p0l": say("Eyes closed, smiling"),
  "28621p0m": say("Half-rim glasses, wink"), "28621p12": say("Bushy beard and sideburns"), "28621pcpc": say("Black glasses and wrinkles"),
  // Hair.
  3901: say("Short hair"), 62810: say("Tousled, side parting"), 40233: say("Short tousled"), 92081: say("Combed back"),
  99930: say("Combed, left parting"), 15500: say("Combed, right parting"), 23186: say("Swept left"), 98385: say("Spiked"),
  2631: say("Spiked up in front"), 53982: say("Long spikes"), 93563: say("Mohawk"), 27385: say("Wide mohawk"),
  30608: say("Flat top"), 12893: say("Bald on top"), 98371: say("Quiff with sideburns"), 21788: say("Short smooth"),
  88283: say("Mid-length, centre parting"), 11256: say("Short wavy"), 103748: say("Swept left with cochlear implant"),
  53981: say("Spiky short"), 40251: say("Long wavy hair"), 12890: say("Long straight"), 92083: say("Long, side parting"),
  4530: say("Shoulder length"), 1879: say("Wavy with bangs"), 23187: say("Mid-length wavy"), 62711: say("Short bob"),
  95328: say("Wide bob"), 20595: say("Long tousled"), 68508: say("Long wavy with clip"), 85974: say("Long with front lock"),
  2123: say("Long dreadlocks"), 36806: say("Long, centre parting"), 21778: say("Coiled"), 87995: say("Afro"),
  80911: say("Short curly"), 29634: say("Very curly"), 79688: say("Short coiled"), 78301: say("Coiled, parted"),
  69857: say("Curly high ponytail"), 11255: say("Long curls"), "6093a": say("Ponytail"), 62696: say("Ponytail with bangs"),
  87990: say("Ponytail with fringe"), 15427: say("Side ponytail"), 93217: say("Top knot"), 27186: say("High bun"),
  30409: say("Two buns"), 99240: say("Bun swept back"), 3625: say("Pigtails"), 41615: say("Two long braids"),
  13198: say("Braided ponytail"), 59363: say("French braid"), 35714: say("Braids in front"),
  // Hats, helmets and headgear.
  5492: say("Beanie over hair"), 35660: say("Cap with ponytail"), 65730: say("Backwards cap with hair"), 41334: say("Knit cap"),
  90541: say("Beanie"), 10164: say("Bobble hat"), 61506: say("Fedora"), 13565: say("Wide-brim fedora"), 3878: say("Top hat"),
  95674: say("Bowler hat"), 2514: say("Flat cap"), 86035: say("Cap"), 11303: say("Cap with seams"), 3629: say("Cowboy hat"),
  90386: say("Beret"), 30172: say("Pith helmet"), 57881: say("Rain hat"), 98381: say("Chef's hat"), 92814: say("Graduation cap"),
  93557: say("Sailor hat"), 6131: say("Wizard hat"), 90388: say("Sombrero"), 36933: say("Ushanka"), 85975: say("Fez"),
  2544: say("Tricorne"), 71015: say("Crown"), 3624: say("Peaked hat"), 3833: say("Hard hat"), 3834: say("Fire helmet"),
  "30124b": say("Full-face helmet"), 50665: say("Space helmet"), 46303: say("Skate helmet"), 12899: say("Sport helmet"),
  35458: say("Dirt bike helmet"), 15851: say("Open-face helmet"), 30325: say("Mining helmet"), 13792: say("Welding helmet"),
  53450: say("Viking helmet"), 3844: say("Knight's helmet"), 75717: say("Roman helmet"), 51283: say("Fishbowl helmet"),
  "4505a": say("Cowl"), 74528: say("Hood"), 30287: say("Fur-lined hood"), 3672: say("Bandana"), 99244: say("Bunny ears"),
  26045: say("Bear ears"), 11262: say("Chicken costume"), 24076: say("Shark costume"), 2523: say("Dinosaur costume"),
  29580: say("Rocket costume"), 25977: say("Banana costume"), 20695: say("Pumpkin"), 18165: say("Spiked crown"),
  // At the neck and on the back.
  4524: say("Cape"), "50231c01": say("Cloth cape"), "99464c01": say("Short cape"), "38301c01": say("Scalloped cape"),
  25376: say("Long scarf"), 30133: say("Neckerchief"), 27151: say("Bow tie"), 2524: say("Backpack"), "30158c01": say("Rucksack"),
  26073: say("Backpack with bedroll"), 3838: say("Air tanks"), 30091: say("Scuba tank"), 4736: say("Jet-pack"),
  38781: say("Life jacket"), 15428: say("Hood down"), 26066: say("Fur collar"), 99250: say("Medal"), 66913: say("Headset"),
  10183: say("Fairy wings"), 15501: say("Short beard"), 93223: say("Long beard"), 15439: say("Moustache"), 4498: say("Quiver"),
  37822: say("Baby carrier"), 85961: say("Vest"),
  // Torsos.
  973: say("Plain"), "973p13": say("Zip jacket"), "973p18": say("Suit and tie"), "973p9c": say("Knit jumper"),
  "973p1a": say("Dungarees"), "973pcf": say("Jacket and shirt"), "973p0b": say("Diagonal zip"), "973pd7f": say("Tie"),
  "973p0a": say("White diagonal zip"), "973p1u": say("Jacket with pockets"), "973p03": say("Shirt and jacket"),
  "973p7z": say("Jacket over shirt"), "973p1b": say("Blue dungarees"), "973p1c": say("Red dungarees"),
  "973p1j": say("Green dungarees"), "973p1r": say("Striped dungarees"), "973p01": say("Red and blue stripes"),
  "973p1d": say("Blue stripes"), "973p1e": say("Red stripes"), "973p2e": say("Blue and mint stripes"), "973p7j": say("Hoodie"),
  "973p0j": say("Hoodie with a star"), "973p1v": say("Hoodie with laces"), "973p0l": say("Plaid jacket"),
  "973p0n": say("Leather jacket"), "973p28": say("Biker jacket"), "973p2h": say("Palm tree"), "973p2i": say("Dolphin"),
  "973p2d": say("Windsurfer"), "973p2b": say("Tracksuit"), "973p2a": say("Chef"), "973p8t": say("Chef's jacket"),
  "973p20": say("Waiter"), "973p7w": say("Overalls"), "973p8r": say("Safety vest"), "973p7p": say("Construction jacket"),
  "973p6y": say("Plaid shirt"), "973p6z": say("Mountains"), "973p8d": say("Zigzag sweater"), "973p6n": say("Wedding dress"),
  "973p0k": say("Open jacket and necklace"), "973p73": say("Vest with pockets"), "973p70": say("Bomber jacket"),
  "973p7a": say("Parka"), "973p0o": say("Gardener's apron"), "973p1y": say("Jacket over sweater"), "973p5f": say("Wetsuit"),
  "973p1z": say("Striped top with flowers"), "973p1x": say("Halter top"), "973p2c": say("Sun top"),
  // Legs.
  "3815b": say("Plain legs"), "3815bp0v": say("Belt with buckle"), "3815bpc44": say("Studded belt"), "3815bpde": say("Lab coat"),
  "3815bp42": say("Shirttails"), shorts: say("Shorts"), "41879a": say("Short legs"), 16709: say("Short legs with stripe"),
  37364: say("Medium legs"), 36036: say("Long skirt"), 24068: say("Hooped skirt"), 24087: say("Ruffled skirt"),
  24782: say("Wavy skirt"), "600880c01": say("Straight skirt"), "14295c01": say("Fringed skirt"),
  "16820c01": say("Pointed skirt"),
  // Held.
  55295: say("Hammer"), 55298: say("Screwdriver"), 55299: say("Wrench"), 55297: say("Power drill"), 3837: say("Shovel"),
  3841: say("Pickaxe"), 18826: say("Saw"), 24085: say("Mop"), 12885: say("Paint roller"), 92585: say("Crowbar"),
  18920: say("Scissors"), "30152ap01": say("Magnifying glass"), 3899: say("Cup"), 38014: say("Coffee cup"),
  15496: say("Takeaway cup"), 68495: say("Stein"), 23986: say("Teapot"), 4528: say("Frying pan"), 4529: say("Saucepan"),
  33120: say("Ice cream cone"), 79743: say("Cupcake"), 33051: say("Apple"), 33085: say("Banana"), 33078: say("Sausage"),
  4342: say("French bread"), 33125: say("Croissant"), 10170: say("Pretzel"), 30222: say("Ice lolly"),
  "3962b": say("Walkie-talkie"), "30089b": say("Camera"), 90370: say("Microphone"), 39144: say("Megaphone"),
  "3069bp0t": say("Phone"), 27150: say("Umbrella"), 30162: say("Binoculars"), 64644: say("Telescope"), 2614: say("Fishing rod"),
  "3852b": say("Hairbrush"), "40359a": say("Key"), 35763: say("Balloon"), 35692: say("Balloon dog"), 43702: say("Ball"),
  10172: say("Trophy"), "4449-f1": say("Suitcase"), 13808: say("Saxophone"), 69947: say("Violin"), 90508: say("Maracas"),
  "6124b": say("Magic wand"), 102498: say("Wooden wand"), 3959: say("Torch"), 3596: say("Flag"), 3004: say("Brick"),
  3005: say("Small brick"),
});

// The colours' names, LDraw's.
const COLOUR_NAMES = () => ({
  0: say("Black"), 1: say("Blue"), 2: say("Green"), 3: say("Dark Turquoise"), 4: say("Red"), 5: say("Dark Pink"),
  10: say("Bright Green"), 14: say("Yellow"), 15: say("White"), 19: say("Tan"), 25: say("Orange"), 26: say("Magenta"),
  27: say("Lime"), 28: say("Dark Tan"), 29: say("Bright Pink"), 30: say("Medium Lavender"), 31: say("Lavender"),
  70: say("Reddish Brown"), 71: say("Light Bluish Grey"), 72: say("Dark Bluish Grey"), 73: say("Medium Blue"),
  78: say("Light Nougat"), 84: say("Medium Nougat"), 85: say("Medium Lilac"), 92: say("Nougat"), 191: say("Bright Light Orange"),
  212: say("Bright Light Blue"), 226: say("Bright Light Yellow"), 272: say("Dark Blue"), 288: say("Dark Green"),
  308: say("Dark Brown"), 320: say("Dark Red"), 321: say("Dark Azure"), 322: say("Medium Azure"), 323: say("Light Aqua"),
  326: say("Yellowish Green"), 330: say("Olive Green"), 353: say("Coral"), 368: say("Neon Yellow"), 370: say("Medium Brown"),
  371: say("Warm Tan"), 378: say("Sand Green"), 379: say("Sand Blue"), 402: say("Reddish Orange"), 422: say("Sienna Brown"),
  424: say("Ochre Yellow"), 430: say("Warm Pink"), 431: say("Bright Blue Violet"), 484: say("Dark Orange"),
  80: say("Metallic Silver"), 82: say("Metallic Gold"), 297: say("Pearl Gold"), 315: say("Flat Silver"), 316: say("Titanium"),
  47: say("Clear"), 43: say("Clear Light Blue"), 33: say("Clear Dark Blue"), 36: say("Clear Red"), 46: say("Clear Yellow"),
});

const STYLE_NAMES = () => ({ short: say("Short"), long: say("Long"), curly: say("Curly"), up: say("Tied up"), hat: say("Hats"),
  helmet: say("Helmets"), headwear: say("Headgear") });
const KIND_WORDS = () => ({ glasses: say("glasses"), beard: say("beard"), freckles: say("freckles"), lips: say("lips"),
  cape: say("cape"), scarf: say("scarf"), backpack: say("backpack"), tanks: say("tanks"), tool: say("tool"), drink: say("drink"),
  food: say("food"), kitchen: say("kitchen"), gadget: say("gadget"), fun: say("fun"), music: say("music"), brick: say("brick") });
const GRADIENT_NAMES = () => [say("Peach glow"), say("Morning sky"), say("Mint"), say("Candy"), say("Sunrise"), say("Deep sea"),
  say("Spring"), say("Night"), say("Apricot"), say("Twilight")];
const SCENE_NAMES = () => ({ sky: say("Sky"), sunset: say("Sunset"), space: say("Space"), studio: say("Studio"), grass: say("Grass"),
  beach: say("Beach"), snow: say("Snow"), city: say("City") });
const AVATAR_NAMES = () => [say("Red"), say("Blue"), say("Green"), say("Purple"), say("Amber"), say("Teal"), say("Berry"), say("Grey")];
const POSE_NAMES = () => ({ stand: say("Standing"), wave: say("Waving"), cheer: say("Cheering"), thinking: say("Thinking"),
  sitting: say("Sitting"), walking: say("Walking"), point: say("Pointing") });
const STARTER_NAMES = () => ({ builder: say("Builder"), chef: say("Chef"), explorer: say("Explorer"), artist: say("Artist"),
  scientist: say("Scientist"), astronaut: say("Astronaut"), skater: say("Skater"), wizard: say("Wizard") });

// The tabs, in the order a figure is made: [key, words].
const TABS = () => [["skin", say("Skin")], ["face", say("Face")], ["hair", say("Hair and hats")], ["torso", say("Torso")],
  ["arms", say("Arms and hands")], ["legs", say("Legs")], ["extras", say("Accessories")], ["pose", say("Pose")],
  ["ground", say("Background")]];
// Which recipe keys each tab holds: what its lock keeps when surprised.
const HOLDS = { skin: ["sk"], face: ["fa", "fb"], hair: ["hd", "hc"], torso: ["to", "tc"], arms: ["ar", "al", "hr", "hl"],
  legs: ["lg", "hp", "rr", "ll"], extras: ["nk", "nc", "ir", "ic", "il", "jc"], pose: ["po"], ground: ["bg", "fr"] };
// A part pressed on the figure: the tab it is in.
const SLOT_TAB = { face: "face", hair: "hair", neck: "extras", torso: "torso", armR: "arms", armL: "arms", handR: "arms",
  handL: "arms", hips: "legs", legR: "legs", legL: "legs", skirt: "legs", heldR: "extras", heldL: "extras" };

const HATS = new Set(["hat", "helmet", "headwear"]);
const ARM_JOINTS = new Set([1, 2]);
const hex = (code) => `#${String(COLOURS[code] || "969696").slice(0, 6)}`;
const esc = (text) => String(text).replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const pick = (list) => list[Math.floor(Math.random() * list.length)];
const SIDE = 400;

// ---------------------------------------------------------------------------
// The backgrounds, painted: the same for the stage and the picture kept.

// A seeded random, so a scene's stars and windows are the same every time.
function seeded(seed) {
  let s = seed >>> 0;
  return () => {
    s = (Math.imul(s ^ (s >>> 15), 0x2c1b3c6d) + 0x9e3779b9) >>> 0;
    return (s & 0xffffff) / 0x1000000;
  };
}

/// [code]'s background on a canvas [side] pixels square.
export function paintGround(code, side) {
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = side;
  const c = canvas.getContext("2d");
  const shape = backgroundOf(code) || { kind: "a", at: 2 };
  const linear = (stops, x0 = 0, y0 = 0, x1 = 0, y1 = side) => {
    const g = c.createLinearGradient(x0, y0, x1, y1);
    stops.forEach(([at, colour]) => g.addColorStop(at, colour));
    return g;
  };
  const fill = (style, x = 0, y = 0, w = side, h = side) => { c.fillStyle = style; c.fillRect(x, y, w, h); };
  if (shape.kind === "a") fill(AVATAR_COLOURS[shape.at - 1]);
  else if (shape.kind === "c") fill(hex(shape.at));
  else if (shape.kind === "g") {
    const [from, to] = GRADIENTS[shape.at - 1];
    fill(linear([[0, from], [1, to]], 0, 0, side, side));
  } else {
    const scene = SCENES[shape.at - 1];
    const random = seeded(shape.at * 7919);
    const u = side / 100;
    const cloud = (x, y, r) => {
      c.fillStyle = "rgba(255,255,255,0.9)";
      for (const [dx, dy, k] of [[0, 0, 1], [r * 0.9, r * 0.15, 0.8], [-r * 0.9, r * 0.2, 0.7], [r * 0.3, -r * 0.45, 0.75]]) {
        c.beginPath();
        c.arc(x + dx, y + dy, r * k, 0, Math.PI * 2);
        c.fill();
      }
    };
    if (scene === "sky") {
      fill(linear([[0, "#5aa7e8"], [1, "#d8efff"]]));
      cloud(22 * u, 24 * u, 7 * u);
      cloud(76 * u, 38 * u, 9 * u);
      cloud(48 * u, 78 * u, 6 * u);
    } else if (scene === "sunset") {
      fill(linear([[0, "#3b1d5e"], [0.45, "#d0466b"], [0.8, "#f9a04b"], [1, "#ffd27a"]]));
      c.fillStyle = "rgba(255,228,150,0.95)";
      c.beginPath();
      c.arc(70 * u, 74 * u, 14 * u, 0, Math.PI * 2);
      c.fill();
    } else if (scene === "space") {
      const g = c.createRadialGradient(30 * u, 30 * u, 0, 50 * u, 50 * u, 75 * u);
      g.addColorStop(0, "#27306b");
      g.addColorStop(1, "#060814");
      fill(g);
      for (let k = 0; k < 90; k++) {
        c.fillStyle = `rgba(255,255,255,${0.35 + random() * 0.65})`;
        c.fillRect(random() * side, random() * side, (0.3 + random() * 0.6) * u, (0.3 + random() * 0.6) * u);
      }
      const planet = c.createRadialGradient(80 * u, 22 * u, 1 * u, 82 * u, 24 * u, 11 * u);
      planet.addColorStop(0, "#ffb36b");
      planet.addColorStop(1, "#b2452b");
      c.fillStyle = planet;
      c.beginPath();
      c.arc(82 * u, 24 * u, 10 * u, 0, Math.PI * 2);
      c.fill();
    } else if (scene === "studio") {
      const g = c.createRadialGradient(50 * u, 40 * u, 5 * u, 50 * u, 55 * u, 80 * u);
      g.addColorStop(0, "#fbfbfb");
      g.addColorStop(1, "#b9bec7");
      fill(g);
    } else if (scene === "grass" || scene === "beach" || scene === "snow" || scene === "city") {
      const sky = { grass: ["#6fb6f0", "#d9f0ff"], beach: ["#58b8ee", "#e2f6ff"], snow: ["#9fb7d4", "#eef4fb"],
        city: ["#22305a", "#f3a26a"] }[scene];
      fill(linear([[0, sky[0]], [1, sky[1]]]));
      if (scene === "city") {
        for (let x = -2; x < 100; x += 9 + random() * 7) {
          const w = (8 + random() * 8) * u;
          const h = (22 + random() * 38) * u;
          c.fillStyle = "#1a2140";
          c.fillRect(x * u, 82 * u - h, w, h + 20 * u);
          c.fillStyle = "rgba(255,214,120,0.85)";
          for (let wy = 82 * u - h + 3 * u; wy < 78 * u; wy += 5 * u) {
            for (let wx = x * u + 2 * u; wx < x * u + w - 2 * u; wx += 4 * u) if (random() < 0.45) c.fillRect(wx, wy, 1.6 * u, 2 * u);
          }
        }
        fill("#2c2f3a", 0, 82 * u, side, 18 * u);
      } else if (scene === "beach") {
        fill(linear([[0, "#2b8fc9"], [1, "#59c2e8"]], 0, 62 * u, 0, 74 * u), 0, 62 * u, side, 12 * u);
        fill(linear([[0, "#f1d9a0"], [1, "#e2bf7a"]], 0, 74 * u, 0, side), 0, 74 * u, side, 26 * u);
        cloud(24 * u, 22 * u, 6 * u);
      } else if (scene === "snow") {
        fill(linear([[0, "#ffffff"], [1, "#dfe9f5"]], 0, 72 * u, 0, side), 0, 72 * u, side, 28 * u);
        c.fillStyle = "rgba(255,255,255,0.9)";
        for (let k = 0; k < 60; k++) {
          c.beginPath();
          c.arc(random() * side, random() * 72 * u, (0.4 + random() * 0.8) * u, 0, Math.PI * 2);
          c.fill();
        }
      } else {
        cloud(26 * u, 24 * u, 6 * u);
        cloud(78 * u, 16 * u, 5 * u);
        fill(linear([[0, "#6cbf4a"], [1, "#3f8f2f"]], 0, 72 * u, 0, side), 0, 72 * u, side, 28 * u);
      }
    }
  }
  return canvas;
}

// ---------------------------------------------------------------------------
// The tiles.

/// The style of one tile's picture: cell [at] of [group]'s pictures.
function sheetStyle(group, at, count) {
  const columns = TILE.columns;
  const cols = Math.min(columns, count);
  const rows = Math.ceil(count / columns);
  const x = at % columns;
  const y = Math.floor(at / columns);
  const position = `${cols > 1 ? (x / (cols - 1)) * 100 : 0}% ${rows > 1 ? (y / (rows - 1)) * 100 : 0}%`;
  return `--size:${cols * 100}% ${rows * 100}%;--at:${position}`;
}

const sheets = () => Object.fromEntries(Object.entries(tileGroups()).map(([group, list]) =>
  [group, { list, base: `/minifig/tiles/${group}-${tilesHash(list)}-b.webp`, print: `/minifig/tiles/${group}-${tilesHash(list)}-p.webp` }]));

// ---------------------------------------------------------------------------
// The maker.

/// The maker in [dialog] (web/profile.html #minifig-dialog), starting from
/// [start] (a recipe of either version): resolves {recipe, blob} once Save
/// has drawn it, or null when it is closed without saving.
export function makeMinifig(dialog, start) {
  const $ = (id) => dialog.querySelector(`#${id}`);
  const names = NAMES();
  const colourNames = COLOUR_NAMES();
  const styleNames = STYLE_NAMES();
  const kindWords = KIND_WORDS();
  const tabs = TABS();
  const groups = sheets();
  // The person's own hair, once the account has said (ownHair).
  let own = [];
  const ownOf = (id) => own.find((one) => one.id === id);
  const nameOf = (id) => names[id] || ownOf(id)?.name || (ownMould(id) ? say("Your own hair") : id);
  const colourName = (code) => (code === SKIN ? say("Skin") : colourNames[code] || String(code));
  let recipe = figureShape(fromLayers(start)) || { ...PLAIN };
  let tab = "skin";
  let extras = "neck";
  const locks = new Set();
  const history = [recipe];
  let at = 0;
  let figure = null;
  const eachArm = { arms: recipe.ar !== recipe.al, legs: recipe.rr !== recipe.ll };

  const body = $("minifig-body");
  body.innerHTML = `<div class="mf-maker">
    <section class="mf-look" aria-label="${esc(say("Your minifig"))}">
      <div class="mf-stage" id="mf-stage" tabindex="0" role="img" aria-describedby="mf-stage-help">
        <p class="mf-wait" id="mf-wait">${esc(say("Drawing your minifig…"))}</p>
      </div>
      <p class="visually-hidden" id="mf-stage-help">${esc(say("Drag it, or use the arrow keys, to turn it; Home turns it back. Press a part to change it."))}</p>
      <div class="mf-tools" role="toolbar" aria-label="${esc(say("Your minifig"))}">
        <button type="button" class="cta ghost small" id="mf-undo" aria-keyshortcuts="Control+Z" disabled>${esc(say("Undo"))}</button>
        <button type="button" class="cta ghost small" id="mf-redo" aria-keyshortcuts="Control+Shift+Z" disabled>${esc(say("Redo"))}</button>
        <button type="button" class="cta ghost small" id="mf-turn">${esc(say("Turn back"))}</button>
        <button type="button" class="cta ghost small" id="minifig-surprise">${esc(say("Surprise me"))}</button>
        <details class="more-menu end" id="mf-starters">
          <summary class="cta ghost small">${esc(say("Start from…"))}</summary>
          <div class="menu-list">${Object.entries(STARTER_NAMES()).map(([key, words]) =>
            `<button type="button" data-starter="${key}">${esc(words)}</button>`).join("")}</div>
        </details>
      </div>
      <div class="mf-sizes" role="img" id="mf-sizes" aria-label="${esc(say("Your minifig at its sizes, on a light page and a dark one"))}">
        <div class="minifig-on light" id="minifig-light"></div>
        <div class="minifig-on dark" id="minifig-dark"></div>
      </div>
    </section>
    <section class="mf-edit">
      <div class="tabs scroller inset mf-tabs" role="tablist" aria-label="${esc(say("Parts"))}">${tabs.map(([key, words]) =>
        `<button type="button" role="tab" id="mf-tab-${key}" data-tab="${key}" aria-controls="mf-panel" aria-selected="false" tabindex="-1">${esc(words)}</button>`).join("")}</div>
      <div class="mf-panel" id="mf-panel" role="tabpanel" tabindex="-1"></div>
    </section>
  </div>`;
  const stage = $("mf-stage");
  const panel = $("mf-panel");

  // -- the figure's words, for a screen reader --------------------------------
  const described = () => {
    const r = recipe;
    const legs = LEGS.find(([id]) => id === r.lg);
    const parts = [say("{skin} skin", { skin: colourName(r.sk) }), nameOf(r.fa),
      r.hd ? `${nameOf(r.hd)} (${colourName(r.hc)})` : say("no hair"), `${nameOf(r.to)} (${colourName(r.tc)})`,
      `${nameOf(legs[0])} (${colourName(r.hp)})`];
    if (r.nk) parts.push(`${nameOf(r.nk)} (${colourName(r.nc)})`);
    if (r.ir) parts.push(say("holding {thing}", { thing: nameOf(r.ir) }));
    if (r.il) parts.push(say("holding {thing}", { thing: nameOf(r.il) }));
    return say("Your minifig: {parts}", { parts: parts.join(", ") });
  };

  // -- the panels -------------------------------------------------------------
  const tileHtml = (group, list, value, name, chosen, extra = "") => {
    const sheet = groups[group];
    const k = sheet.list.indexOf(value);
    const style = k < 0 ? "" : sheetStyle(group, k, sheet.list.length);
    const words = `${name} ${extra}`.toLowerCase();
    return `<label class="mf-tile" title="${esc(name)}" data-words="${esc(words)}"><input type="radio" name="mf-${list}" value="${esc(value)}"${chosen ? " checked" : ""}>`
      + `<span class="pic" style="${style}"><span class="b" style="background-image:url(${sheet.base});-webkit-mask-image:url(${sheet.base});mask-image:url(${sheet.base})"></span>`
      + `<span class="p" style="background-image:url(${sheet.print})"></span></span><span class="visually-hidden">${esc(name)}</span></label>`;
  };
  const noneTile = (list, chosen, words) => `<label class="mf-tile none" title="${esc(words)}" data-words="${esc(words.toLowerCase())}">`
    + `<input type="radio" name="mf-${list}" value=""${chosen ? " checked" : ""}><span class="pic"></span><span class="visually-hidden">${esc(words)}</span></label>`;
  const swatches = (list, codes, chosen, legend, { skin = false } = {}) => `<fieldset class="mf-group mf-colours" data-list="${list}">`
    + `<legend>${esc(legend)} <span class="mf-chosen">${esc(colourName(chosen))}</span></legend><div class="mf-swatches">`
    + `${skin ? `<label class="mf-swatch skin" title="${esc(say("Skin"))}" data-words="${esc(say("Skin").toLowerCase())}"><input type="radio" name="mf-${list}" value="${SKIN}"${chosen === SKIN ? " checked" : ""}><span style="--c:${hex(recipe.sk)}"></span><span class="visually-hidden">${esc(say("Skin"))}</span></label>` : ""}`
    + codes.map((code) => `<label class="mf-swatch${CLEAR.includes(code) ? " clear" : ""}${/m$/.test(COLOURS[code]) ? " metal" : ""}" title="${esc(colourName(code))}" data-words="${esc(colourName(code).toLowerCase())}">`
      + `<input type="radio" name="mf-${list}" value="${code}"${code === chosen ? " checked" : ""}><span style="--c:${hex(code)}"></span>`
      + `<span class="visually-hidden">${esc(colourName(code))}</span></label>`).join("") + "</div></fieldset>";
  const search = (words) => `<label class="search mf-search"><svg class="icon" aria-hidden="true" focusable="false"><use href="/icons.svg#search"></use></svg>`
    + `<span class="visually-hidden">${esc(words)}</span><input type="search" id="mf-q" autocomplete="off" enterkeyhint="search" placeholder="${esc(words)}"></label>`;
  const head = (key, words) => `<div class="mf-panel-head">${search(words)}<button type="button" class="cta ghost small mf-lock" id="mf-lock" aria-pressed="${locks.has(key)}">`
    + `<svg class="icon" aria-hidden="true" focusable="false"><use href="/icons.svg#lock"></use></svg><span class="words">${esc(say("Keep when surprised"))}</span></button></div>`;
  const filters = (choices) => `<div class="pills scroller inset mf-filters" role="group" aria-label="${esc(say("Show"))}">`
    + choices.map(([key, words], k) => `<button type="button" class="pill" data-filter="${key}" aria-pressed="${k === 0}">${esc(words)}</button>`).join("") + "</div>";
  const group = (legend, list, inner, chosenName) => `<fieldset class="mf-group" data-list="${list}"><legend>${esc(legend)} <span class="mf-chosen">${esc(chosenName)}</span></legend>`
    + `<div class="mf-tiles">${inner}</div></fieldset>`;
  const empty = `<p class="note mf-none" id="mf-none" hidden>${esc(say("Nothing here is called that."))}</p>`;

  const panels = {
    skin: () => `${head("skin", say("Search the skin tones"))}`
      + `<fieldset class="mf-group" data-list="sk"><legend>${esc(say("LEGO® skin tones"))} <span class="mf-chosen">${esc(colourName(recipe.sk))}</span></legend><div class="mf-tiles">`
      + SKINS.slice(0, REAL_SKINS).map((code) => skinTile(code)).join("") + "</div></fieldset>"
      + `<fieldset class="mf-group" data-list="sk"><legend>${esc(say("Fantasy"))}</legend><div class="mf-tiles">`
      + SKINS.slice(REAL_SKINS).map((code) => skinTile(code)).join("") + `</div></fieldset>${empty}`,
    face: () => `${head("face", say("Search the faces"))}${filters([["all", say("All")], ["glasses", say("Glasses")],
      ["beard", say("Beards")], ["freckles", say("Freckles")], ["two", say("Two faces")]])}`
      + `<label class="choice mf-check"><input type="checkbox" id="mf-fb"${recipe.fb ? " checked" : ""}> ${esc(say("Show the other face"))}</label>`
      + group(say("Face"), "fa", FACES.map(([id, two, kinds]) => tileHtml("faces", "fa", id, nameOf(id), id === recipe.fa,
        `${kinds.split(" ").filter(Boolean).map((k) => kindWords[k]).join(" ")} ${two ? "two" : ""}`).replace("<label class=\"mf-tile\"",
        `<label class="mf-tile" data-kinds="${kinds}${two ? " two" : ""}"`)).join(""), nameOf(recipe.fa)) + empty,
    hair: () => `${head("hair", say("Search hair and hats"))}${filters([["all", say("All")],
      ...(own.length ? [["own", say("Your own")]] : []), ...Object.entries(styleNames)])}`
      + (own.length ? group(say("Your own"), "hd", own.map((one) => ownTile(one)).join(""),
        ownOf(recipe.hd) ? nameOf(recipe.hd) : "")
        : `<p class="note mf-own-none">${esc(say("Shape hair of your own in the studio's minifig builder (Headgear, Make a mould…), signed in: it is here the moment you save it."))} `
          + `<a href="${esc(appAt())}">${esc(say("Open the studio"))}</a></p>`)
      + group(say("Hair and hats"), "hd", noneTile("hd", !recipe.hd, say("No hair")) + HAIR.map(([id, style]) =>
        tileHtml("hair", "hd", id, nameOf(id), id === recipe.hd, styleNames[style]).replace("<label class=\"mf-tile\"",
          `<label class="mf-tile" data-kinds="${style}"`)).join(""),
        !recipe.hd ? say("No hair") : ownMould(recipe.hd) ? "" : nameOf(recipe.hd))
      + swatches("hc", hairColours(), recipe.hc, say("Its colour")) + empty,
    torso: () => `${head("torso", say("Search the torsos"))}`
      + group(say("Torso"), "to", TORSOS.map(([id]) => tileHtml("torsos", "to", id, nameOf(id), id === recipe.to)).join(""), nameOf(recipe.to))
      + swatches("tc", PALETTE, recipe.tc, say("Torso colour")) + empty,
    arms: () => `${head("arms", say("Search the colours"))}`
      + `<label class="choice mf-check"><input type="checkbox" id="mf-each-arm"${eachArm.arms ? " checked" : ""}> ${esc(say("Each arm its own colour"))}</label>`
      + (eachArm.arms ? swatches("ar", PALETTE, recipe.ar, say("Right arm"), { skin: true }) + swatches("al", PALETTE, recipe.al, say("Left arm"), { skin: true })
        : swatches("ar", PALETTE, recipe.ar, say("Arms"), { skin: true }))
      + swatches("hr", PALETTE, recipe.hr, say("Hands"), { skin: true }) + empty,
    legs: () => {
      const kind = LEGS.find(([id]) => id === recipe.lg)?.[1];
      return `${head("legs", say("Search the legs"))}`
        + group(say("Legs"), "lg", LEGS.map(([id]) => tileHtml("legs", "lg", id, nameOf(id), id === recipe.lg)).join(""), nameOf(recipe.lg))
        + swatches("hp", PALETTE, recipe.hp, kind === "one" ? say("Colour") : kind === "over" ? say("Skirt and hips") : say("Hips"))
        + (kind === "one" ? "" : `<label class="choice mf-check"><input type="checkbox" id="mf-each-leg"${eachArm.legs ? " checked" : ""}> ${esc(say("Each leg its own colour"))}</label>`
          + (eachArm.legs ? swatches("rr", PALETTE, recipe.rr, say("Right leg")) + swatches("ll", PALETTE, recipe.ll, say("Left leg"))
            : swatches("rr", PALETTE, recipe.rr, say("Legs"))))
        + empty;
    },
    extras: () => {
      const which = { neck: ["nk", "nc", NECKS, "necks", say("Neck and back"), say("Nothing")],
        right: ["ir", "ic", HELD, "held", say("Right hand holds"), say("Nothing")],
        left: ["il", "jc", HELD, "held", say("Left hand holds"), say("Nothing")] }[extras];
      const [list, colourKey, items, sheet, legend, none] = which;
      return `${head("extras", say("Search the accessories"))}`
        + `<div class="segmented mf-extras" role="group" aria-label="${esc(say("Accessories"))}">${[["neck", say("Neck and back")],
          ["right", say("Right hand")], ["left", say("Left hand")]].map(([key, words]) =>
          `<button type="button" data-extras="${key}" aria-pressed="${key === extras}">${esc(words)}</button>`).join("")}</div>`
        + group(legend, list, noneTile(list, !recipe[list], none) + items.map(([id, , kind]) =>
          tileHtml(sheet, list, id, nameOf(id), id === recipe[list], kindWords[kind] || "")).join(""), recipe[list] ? nameOf(recipe[list]) : none)
        + (recipe[list] ? swatches(colourKey, [...PALETTE, ...CLEAR], recipe[colourKey], say("Its colour")) : "") + empty;
    },
    pose: () => {
      const poseNames = POSE_NAMES();
      const sliders = [[0, say("Head turned")], [1, say("Right arm raised")], [2, say("Left arm raised")], [3, say("Right hand turned")],
        [4, say("Left hand turned")]];
      return `${head("pose", say("Search the poses"))}`
        + `<fieldset class="mf-group" data-list="preset"><legend>${esc(say("Poses"))}</legend><div class="mf-tiles poses">`
        + Object.entries(POSES).map(([key]) => `<button type="button" class="mf-pose" data-pose="${key}" data-words="${esc(poseNames[key].toLowerCase())}"`
          + ` aria-pressed="${String(recipe.po) === String(POSES[key])}"><img alt="" width="64" height="64" hidden><span>${esc(poseNames[key])}</span></button>`).join("")
        + "</div></fieldset>"
        + `<fieldset class="mf-group mf-joints"><legend>${esc(say("Each joint"))}</legend>`
        // An arm's slider runs from down to up: a raised arm is a
        // negative angle (forward and up), so its slider shows it turned.
        + sliders.map(([k, words]) => {
          const [low, high] = ARM_JOINTS.has(k) ? [-POSE_RANGE[k][1], -POSE_RANGE[k][0]] : POSE_RANGE[k];
          const value = ARM_JOINTS.has(k) ? -recipe.po[k] : recipe.po[k];
          return `<label class="mf-joint" data-words="${esc(words.toLowerCase())}"><span>${esc(words)}</span>`
            + `<input type="range" min="${low}" max="${high}" step="5" value="${value}" data-joint="${k}">`
            + `<output>${value}°</output></label>`;
        }).join("")
        + `<div class="segmented mf-stance" role="group" aria-label="${esc(say("Legs"))}">${[[0, say("Standing")], [1, say("Walking")], [2, say("Sitting")]]
          .map(([k, words]) => `<button type="button" data-stance="${k}" data-words="${esc(words.toLowerCase())}" aria-pressed="${recipe.po[5] === k}">${esc(words)}</button>`).join("")}</div>`
        + `</fieldset>${empty}`;
    },
    ground: () => {
      const avatarNames = AVATAR_NAMES();
      const gradientNames = GRADIENT_NAMES();
      const sceneNames = SCENE_NAMES();
      const ground = (code, words, style) => `<label class="mf-swatch ground" title="${esc(words)}" data-words="${esc(words.toLowerCase())}">`
        + `<input type="radio" name="mf-bg" value="${code}"${code === recipe.bg ? " checked" : ""}><span style="${style}"></span>`
        + `<span class="visually-hidden">${esc(words)}</span></label>`;
      return `${head("ground", say("Search the backgrounds"))}`
        + `<fieldset class="mf-group"><legend>${esc(say("Your picture shows"))}</legend><div class="segmented mf-frame" role="group" aria-label="${esc(say("Your picture shows"))}">`
        + [[0, say("Head and shoulders")], [1, say("Whole figure")]].map(([k, words]) =>
          `<button type="button" data-frame="${k}" aria-pressed="${recipe.fr === k}">${esc(words)}</button>`).join("") + "</div></fieldset>"
        + `<fieldset class="mf-group" data-list="bg"><legend>${esc(say("Scenes"))}</legend><div class="mf-swatches scenes">`
        + SCENES.map((scene, k) => ground(`s${k + 1}`, sceneNames[scene], `background-image:url(${sceneThumb(k + 1)})`)).join("") + "</div></fieldset>"
        + `<fieldset class="mf-group" data-list="bg"><legend>${esc(say("Gradients"))}</legend><div class="mf-swatches">`
        + GRADIENTS.map(([from, to], k) => ground(`g${k + 1}`, gradientNames[k], `background:linear-gradient(135deg,${from},${to})`)).join("") + "</div></fieldset>"
        + `<fieldset class="mf-group" data-list="bg"><legend>${esc(say("The site's colours"))}</legend><div class="mf-swatches">`
        + AVATAR_COLOURS.map((colour, k) => ground(`a${k + 1}`, avatarNames[k], `background:${colour}`)).join("") + "</div></fieldset>"
        + `<fieldset class="mf-group" data-list="bg"><legend>${esc(say("Colours"))}</legend><div class="mf-swatches">`
        + PALETTE.map((code) => ground(`c${code}`, colourName(code), `background:${hex(code)}`)).join("") + `</div></fieldset>${empty}`;
    },
  };
  function skinTile(code) {
    const sheet = groups.skin;
    return `<label class="mf-tile skin" title="${esc(colourName(code))}" data-words="${esc(colourName(code).toLowerCase())}">`
      + `<input type="radio" name="mf-sk" value="${code}"${code === recipe.sk ? " checked" : ""}>`
      + `<span class="pic" style="${sheetStyle("skin", 0, 1)};--tint:${hex(code)}"><span class="b" style="background-image:url(${sheet.base});-webkit-mask-image:url(${sheet.base});mask-image:url(${sheet.base})"></span></span>`
      + `<span class="visually-hidden">${esc(colourName(code))}</span></label>`;
  }
  // A hair of their own: its picture drawn from its triangles once the
  // figure is in 3D (drawOwn), in the colour chosen.
  function ownTile(one) {
    return `<label class="mf-tile own" title="${esc(one.name)}" data-kinds="own" data-words="${esc(`${one.name} ${say("Your own")}`.toLowerCase())}">`
      + `<input type="radio" name="mf-hd" value="${esc(one.id)}"${one.id === recipe.hd ? " checked" : ""}>`
      + `<span class="pic"><img alt="" width="96" height="96" data-own="${esc(one.id)}" hidden></span>`
      + `<span class="visually-hidden">${esc(one.name)}</span></label>`;
  }
  const ownDrawn = new Map();
  async function drawOwn() {
    if (!figure || tab !== "hair") return;
    const colour = recipe.hd && !ownMould(recipe.hd) && HATS.has(HAIR.find(([id]) => id === recipe.hd)?.[1]) ? 70 : recipe.hc;
    for (const img of panel.querySelectorAll("img[data-own]")) {
      const key = `${img.dataset.own}:${colour}`;
      if (!ownDrawn.has(key)) {
        const drawn = await figure.part(img.dataset.own, colour, 96).catch(() => null);
        ownDrawn.set(key, drawn ? drawn.toDataURL("image/png") : "");
      }
      if (tab !== "hair" || !img.isConnected) return;
      if (ownDrawn.get(key)) {
        img.src = ownDrawn.get(key);
        img.hidden = false;
      }
    }
  }
  // The part a hair of their own was shaped from: its style and first colour.
  const baseOf = (id) => HAIR.find(([one]) => one === (ownOf(id)?.base ?? id));
  const hairColours = () => {
    const style = baseOf(recipe.hd)?.[1];
    return style && HATS.has(style) ? [...PALETTE, ...CLEAR] : [...HAIR_COLOURS, ...PALETTE.filter((code) => !HAIR_COLOURS.includes(code))];
  };
  const scenesDrawn = new Map();
  function sceneThumb(at) {
    if (!scenesDrawn.has(at)) scenesDrawn.set(at, paintGround(`s${at}`, 96).toDataURL("image/png"));
    return scenesDrawn.get(at);
  }

  // The tint each tile of the open panel is drawn in, and which is chosen.
  const tint = () => {
    const r = recipe;
    // An empty slot's parts in a light grey, not the black its colour is
    // while nothing is in it.
    const tints = { fa: r.sk, hd: r.hd ? r.hc : 71, to: r.tc, lg: r.hp, nk: r.nk ? r.nc : 71, ir: r.ir ? r.ic : 71, il: r.il ? r.jc : 71 };
    for (const fieldset of panel.querySelectorAll("fieldset[data-list]")) {
      const list = fieldset.dataset.list;
      if (tints[list] !== undefined) fieldset.style.setProperty("--tint", hex(tints[list]));
    }
    for (const swatch of panel.querySelectorAll(".mf-swatch.skin span[style]")) swatch.style.setProperty("--c", hex(r.sk));
  };
  const lockButton = () => {
    const lock = $("mf-lock");
    if (lock) lock.setAttribute("aria-pressed", String(locks.has(tab)));
  };

  function open(key, { focus = false } = {}) {
    tab = key;
    for (const button of dialog.querySelectorAll("[role=tab]")) {
      const on = button.dataset.tab === key;
      button.setAttribute("aria-selected", String(on));
      button.tabIndex = on ? 0 : -1;
      if (on && focus) button.focus();
      if (on) button.scrollIntoView({ block: "nearest", inline: "nearest" });
    }
    panel.setAttribute("aria-labelledby", `mf-tab-${key}`);
    panel.innerHTML = panels[key]();
    panel.scrollTop = 0;
    tint();
    if (key === "pose") sketchPoses();
    if (key === "hair") drawOwn();
  }

  // The poses' tiles: this figure in each, drawn small once it is in 3D.
  // Kept while the figure but its pose is the same, so a pose chosen
  // does not draw them all again.
  let sketching = 0;
  const sketches = new Map();
  async function sketchPoses() {
    if (!figure) return;
    const mine = ++sketching;
    const { po, fr, bg, ...rest } = recipe;
    const same = JSON.stringify(rest);
    for (const button of panel.querySelectorAll("[data-pose]")) {
      const key = `${same}|${button.dataset.pose}`;
      if (!sketches.has(key)) {
        // Empty-handed, so a flag or a balloon never shrinks the pose.
        const drawn = await figure.sketch({ ...recipe, po: [...POSES[button.dataset.pose]], ir: "", il: "", fr: 1 }, 128);
        sketches.set(key, drawn.toDataURL("image/png"));
      }
      if (mine !== sketching || tab !== "pose") return;
      const img = button.querySelector("img");
      img.src = sketches.get(key);
      img.hidden = false;
    }
  }

  // -- changes, undo and redo -------------------------------------------------
  let drawing = Promise.resolve();
  const drawFigure = () => {
    stage.setAttribute("aria-label", described());
    // What it is made of now, for a check to read (tools/web/minifig_flow.mjs).
    dialog.dataset.recipe = JSON.stringify(recipe);
    stage.style.backgroundImage = `url(${paintGround(recipe.bg, 360).toDataURL("image/png")})`;
    if (!figure) return drawing;
    const want = recipe;
    drawing = drawing.then(() => (want === recipe ? figure.set(want) : null)).then(() => { if (want === recipe) sizes(); })
      .catch(() => { $("minifig-note").textContent = say("Some parts would not load just now: try again."); });
    return drawing;
  };
  const tools = () => {
    $("mf-undo").disabled = at === 0;
    $("mf-redo").disabled = at === history.length - 1;
    for (const button of dialog.querySelectorAll("[data-frame]")) button.setAttribute("aria-pressed", String(Number(button.dataset.frame) === recipe.fr));
  };
  /// [next] made the figure: one step of undo, unless [coalesce] (a
  /// slider still moving) says it is the same step as the last.
  function change(next, { coalesce = false, redraw = true } = {}) {
    const shaped = figureShape(next);
    if (!shaped) return;
    recipe = shaped;
    if (coalesce && at > 0 && history[at].__live) history[at] = Object.assign({ ...recipe }, { __live: true });
    else {
      history.splice(at + 1);
      history.push(coalesce ? Object.assign({ ...recipe }, { __live: true }) : recipe);
      at = history.length - 1;
    }
    if (!coalesce && history[at].__live) history[at] = recipe;
    tools();
    drawFigure();
    if (redraw) refresh();
  }
  const travel = (step) => {
    const to = at + step;
    if (to < 0 || to >= history.length) return;
    at = to;
    const { __live, ...kept } = history[at];
    recipe = kept;
    eachArm.arms = recipe.ar !== recipe.al;
    eachArm.legs = recipe.rr !== recipe.ll;
    tools();
    drawFigure();
    open(tab);
  };
  // The open panel, as the figure is now: its choices and tints, its words.
  const refresh = () => {
    const keep = panel.scrollTop;
    const focused = document.activeElement && panel.contains(document.activeElement) ? document.activeElement : null;
    const focusName = focused?.name;
    const focusValue = focused?.value;
    const query = $("mf-q")?.value || "";
    const pressed = panel.querySelector("[data-filter][aria-pressed=true]")?.dataset.filter;
    open(tab);
    panel.scrollTop = keep;
    if (query) { $("mf-q").value = query; filter(); }
    if (pressed && pressed !== "all") panel.querySelector(`[data-filter="${pressed}"]`)?.click();
    if (focusName) {
      const again = [...panel.querySelectorAll(`input[name="${CSS.escape(focusName)}"]`)].find((one) => one.value === focusValue)
        || panel.querySelector(`input[name="${CSS.escape(focusName)}"]:checked`);
      again?.focus({ preventScroll: true });
    } else if (focused?.id) panel.querySelector(`#${CSS.escape(focused.id)}`)?.focus({ preventScroll: true });
  };

  // -- the sizes it will be shown at -----------------------------------------
  let sized = 0;
  const sizes = () => {
    if (!figure) return;
    clearTimeout(sized);
    sized = setTimeout(() => {
      if (!figure) return;
      const picture = figure.picture(256, recipe.fr ? "whole" : "portrait", paintGround(recipe.bg, 256)).toDataURL("image/png");
      const row = ["small", "", "big"].map((size) => `<span class="${["avatar", size, "pictured"].filter(Boolean).join(" ")}"><img src="${picture}" alt="" width="112" height="112"></span>`).join("");
      $("minifig-light").innerHTML = row;
      $("minifig-dark").innerHTML = row;
    }, 120);
  };

  // -- what a person does -----------------------------------------------------
  function filter() {
    const query = ($("mf-q")?.value || "").trim().toLowerCase();
    const pressed = panel.querySelector("[data-filter][aria-pressed=true]")?.dataset.filter || "all";
    let shown = 0;
    // A tab's parts are what is searched; its colours stay to be chosen,
    // unless colours are all it has (Skin, Arms and hands, Background).
    const items = [...panel.querySelectorAll("[data-words]")];
    const parts = items.filter((one) => !one.closest(".mf-colours"));
    for (const one of parts.length ? parts : items) {
      const kinds = one.dataset.kinds || "";
      const hit = (!query || one.dataset.words.includes(query)) && (pressed === "all" || kinds.split(" ").includes(pressed));
      one.hidden = !hit;
      if (hit) shown += 1;
    }
    for (const fieldset of panel.querySelectorAll("fieldset")) {
      const items = fieldset.querySelectorAll("[data-words]");
      fieldset.hidden = items.length > 0 && [...items].every((one) => one.hidden);
    }
    const none = $("mf-none");
    if (none) none.hidden = shown > 0;
  }
  const changed = (event) => {
    const input = event.target;
    if (input.id === "mf-fb") return change({ ...recipe, fb: input.checked ? 1 : 0 });
    if (input.id === "mf-each-arm") {
      eachArm.arms = input.checked;
      return change(input.checked ? recipe : { ...recipe, al: recipe.ar });
    }
    if (input.id === "mf-each-leg") {
      eachArm.legs = input.checked;
      return change(input.checked ? recipe : { ...recipe, ll: recipe.rr });
    }
    if (input.dataset.joint !== undefined && event.type === "change") return poseFrom(input, false);
    if (!input.name?.startsWith("mf-") || input.type !== "radio") return;
    const key = input.name.slice(3);
    const text = ["fa", "hd", "to", "lg", "nk", "ir", "il", "bg"].includes(key);
    const value = text ? input.value : Number(input.value);
    const next = { ...recipe, [key]: value };
    // Both arms and both legs, unless each has its own.
    if (key === "ar" && !eachArm.arms) next.al = value;
    if (key === "hr") next.hl = value;
    if (key === "rr" && !eachArm.legs) next.ll = value;
    // A new part comes in its own colour; hair keeps the colour it had.
    const own = (list, id) => list.find(([one]) => one === id)?.[list === HAIR ? 2 : 1];
    if (key === "hd" && value) {
      // A hair of their own as the part it was shaped from.
      const style = baseOf(value)?.[1];
      const was = baseOf(recipe.hd)?.[1];
      if (HATS.has(style) || !was || HATS.has(was)) next.hc = baseOf(value)?.[2] ?? 70;
    }
    if (key === "nk" && value) next.nc = own(NECKS, value);
    if (key === "ir" && value) next.ic = own(HELD, value);
    if (key === "il" && value) next.jc = own(HELD, value);
    if (key === "fa" && !FACES.find(([id]) => id === value)?.[1]) next.fb = 0;
    if (key === "fr") return change(next, { redraw: false });
    change(next);
  };
  const poseFrom = (input, live) => {
    const k = Number(input.dataset.joint);
    const shown = Number(input.value);
    const value = ARM_JOINTS.has(k) ? -shown : shown;
    input.nextElementSibling.textContent = `${shown}°`;
    change({ ...recipe, po: recipe.po.map((n, j) => (j === k ? value : n)) }, { coalesce: live, redraw: !live });
  };
  const inputted = (event) => {
    if (event.target.id === "mf-q") return filter();
    if (event.target.dataset.joint !== undefined) poseFrom(event.target, true);
  };
  const clicked = (event) => {
    const filterButton = event.target.closest("[data-filter]");
    if (filterButton) {
      for (const one of panel.querySelectorAll("[data-filter]")) one.setAttribute("aria-pressed", String(one === filterButton));
      return filter();
    }
    const extrasButton = event.target.closest("[data-extras]");
    if (extrasButton) {
      extras = extrasButton.dataset.extras;
      open("extras");
      panel.querySelector(`[data-extras="${extras}"]`)?.focus();
      return;
    }
    const poseButton = event.target.closest("[data-pose]");
    if (poseButton) return change({ ...recipe, po: [...POSES[poseButton.dataset.pose]] });
    const frameButton = event.target.closest("[data-frame]");
    if (frameButton) return change({ ...recipe, fr: Number(frameButton.dataset.frame) }, { redraw: false });
    const stance = event.target.closest("[data-stance]");
    if (stance) return change({ ...recipe, po: recipe.po.map((n, k) => (k === 5 ? Number(stance.dataset.stance) : n)) });
    if (event.target.closest("#mf-lock")) {
      if (locks.has(tab)) locks.delete(tab); else locks.add(tab);
      lockButton();
      dialog.querySelector(`#mf-tab-${tab}`).classList.toggle("locked", locks.has(tab));
    }
  };
  const tabbed = (event) => {
    const button = event.target.closest("[role=tab]");
    if (button) open(button.dataset.tab);
  };
  const tabKeys = (event) => {
    const button = event.target.closest("[role=tab]");
    if (!button) return;
    const all = [...dialog.querySelectorAll("[role=tab]")];
    const k = all.indexOf(button);
    const to = { ArrowRight: k + 1, ArrowLeft: k - 1, Home: 0, End: all.length - 1 }[event.key];
    if (to === undefined) return;
    event.preventDefault();
    open(all[(to + all.length) % all.length].dataset.tab, { focus: true });
  };
  const keys = (event) => {
    const mod = event.ctrlKey || event.metaKey;
    if (mod && event.key.toLowerCase() === "z" && !event.target.matches?.("input[type=search]")) {
      event.preventDefault();
      travel(event.shiftKey ? 1 : -1);
    } else if (mod && event.key.toLowerCase() === "y") {
      event.preventDefault();
      travel(1);
    }
  };
  const stageKeys = (event) => {
    if (!figure) return;
    const turn = { ArrowLeft: [-15, 0], ArrowRight: [15, 0], ArrowUp: [0, -8], ArrowDown: [0, 8] }[event.key];
    if (turn) {
      event.preventDefault();
      figure.turn(turn[0], turn[1]);
    } else if (event.key === "Home") {
      event.preventDefault();
      figure.reset();
    }
  };
  const surprised = () => {
    const kept = (key) => Object.entries(HOLDS).some(([tabKey, holds]) => locks.has(tabKey) && holds.includes(key));
    const hair = pick(HAIR);
    const neck = Math.random() < 0.35 ? pick(NECKS) : ["", 0];
    const right = Math.random() < 0.5 ? pick(HELD) : ["", 0];
    const left = Math.random() < 0.2 ? pick(HELD) : ["", 0];
    const arms = Math.random() < 0.15 ? SKIN : pick(PALETTE);
    const legs = pick(LEGS)[0];
    const hips = pick(PALETTE);
    const face = pick(FACES)[0];
    const grounds = [...SCENES.map((_, k) => `s${k + 1}`), ...GRADIENTS.map((_, k) => `g${k + 1}`), ...AVATAR_COLOURS.map((_, k) => `a${k + 1}`)];
    const torsoColour = pick(PALETTE);
    const random = { sk: pick(SKINS.slice(0, REAL_SKINS)), fa: face, fb: 0, hd: hair[0],
      hc: HATS.has(hair[1]) ? hair[2] : pick(HAIR_COLOURS), nk: neck[0], nc: neck[1], to: pick(TORSOS)[0], tc: torsoColour,
      ar: arms === SKIN ? SKIN : torsoColour, al: arms === SKIN ? SKIN : torsoColour, hr: SKIN, hl: SKIN, lg: legs, hp: hips,
      rr: hips, ll: hips, ir: right[0], ic: right[1], il: left[0], jc: left[1],
      po: [...pick(Object.values(POSES))], bg: pick(grounds) };
    const next = { ...recipe };
    for (const [key, value] of Object.entries(random)) if (!kept(key)) next[key] = value;
    eachArm.arms = next.ar !== next.al;
    eachArm.legs = next.rr !== next.ll;
    change(next);
  };
  // Start from…'s list is placed by the window, over everything: inside the
  // row of buttons that scrolls on a phone, and the column that scrolls
  // beside the parts, it was cut off, open with none of it to press. Under
  // its button where there is room, over it where there is not.
  const placeStarters = () => {
    const menu = $("mf-starters");
    const list = menu.querySelector(".menu-list");
    list.removeAttribute("style");
    if (!menu.open) return;
    const button = menu.querySelector("summary").getBoundingClientRect();
    const tall = Math.min(list.offsetHeight, innerHeight - 16);
    const wide = list.offsetWidth;
    const top = innerHeight - button.bottom - 16 >= tall ? button.bottom + 8 : Math.max(8, button.top - 8 - tall);
    const left = Math.max(8, Math.min(button.right - wide, innerWidth - wide - 8));
    Object.assign(list.style, { position: "fixed", top: `${top}px`, left: `${left}px`, right: "auto",
      maxHeight: `${innerHeight - 16}px`, overflowY: "auto" });
  };
  const starter = (event) => {
    const button = event.target.closest("[data-starter]");
    if (!button) return;
    $("mf-starters").open = false;
    const next = { ...STARTERS[button.dataset.starter] };
    eachArm.arms = next.ar !== next.al;
    eachArm.legs = next.rr !== next.ll;
    change(next);
  };

  // -- the 3D figure, once its code and parts are here ----------------------
  const started = performance.now();
  const shown = (async () => {
    try {
      const [module, facts, config, theirs] = await Promise.all([import("/minifig3d.js"),
        fetch("/minifig/figure.json").then((answer) => (answer.ok ? answer.json() : Promise.reject(new Error(`figure.json: ${answer.status}`)))),
        fetch("/api/account").then((answer) => answer.json()).catch(() => ({})), ownHair()]);
      if (!module.webglWorks()) throw new Error("no 3D");
      own = theirs;
      if (own.length) {
        dialog.dataset.own = String(own.length);
        if (tab === "hair") refresh();
      }
      const root = String(config.parts_url || "/parts/").replace(/\/?$/, "/");
      figure = await module.minifig3d(stage, { root, meshes: facts.meshes, colours: facts.colours, recipe, own: mouldText,
        pick: (slot) => {
          const key = SLOT_TAB[slot];
          if (!key) return;
          if (slot === "heldR") extras = "right";
          else if (slot === "heldL") extras = "left";
          else if (slot === "neck") extras = "neck";
          open(key);
        }, turned: () => sizes() });
      $("mf-wait").hidden = true;
      dialog.dataset.figure = "ready";
      dialog.dataset.firstFrame = String(Math.round(performance.now() - started));
      if (figure.errors.length) $("minifig-note").textContent = say("Some parts would not load just now: try again.");
      drawFigure();
      if (tab === "pose") sketchPoses();
      if (tab === "hair") drawOwn();
    } catch (trouble) {
      $("mf-wait").textContent = String(trouble?.message) === "no 3D"
        ? say("This browser cannot draw in 3D, so it cannot make a minifig. Choose a picture of your own instead.")
        : say("Your minifig would not draw just now: try again in a minute.");
      $("minifig-save").disabled = true;
      dialog.dataset.figure = "failed";
    }
  })();

  open("skin");
  tools();
  drawFigure();
  $("minifig-note").textContent = "";
  $("minifig-save").disabled = false;

  return new Promise((resolve) => {
    let saving = false;
    const cancel = () => dialog.close();
    const turnBack = () => figure?.reset();
    const undo = () => travel(-1);
    const redo = () => travel(1);
    const save = async () => {
      if (saving) return;
      saving = true;
      $("minifig-save").disabled = true;
      $("minifig-note").textContent = say("Drawing your minifig…");
      try {
        await shown;
        await drawing;
        if (!figure) throw new Error(say("That minifig would not draw: try again."));
        const canvas = figure.picture(SIDE, recipe.fr ? "whole" : "portrait", paintGround(recipe.bg, SIDE));
        const blob = await new Promise((done) => canvas.toBlob(done, "image/png"));
        if (!blob) throw new Error(say("That minifig would not draw: try again."));
        end({ recipe, blob });
      } catch (trouble) {
        $("minifig-note").textContent = String(trouble?.message || say("That minifig would not draw: try again."));
      } finally {
        saving = false;
        $("minifig-save").disabled = false;
      }
    };
    let made = null;
    const closed = () => end(made);
    const listeners = [[panel, "change", changed], [panel, "input", inputted], [panel, "click", clicked],
      [dialog.querySelector("[role=tablist]"), "click", tabbed], [dialog.querySelector("[role=tablist]"), "keydown", tabKeys],
      [dialog, "keydown", keys], [stage, "keydown", stageKeys], [$("minifig-surprise"), "click", surprised],
      [$("mf-starters"), "click", starter], [$("mf-starters"), "toggle", placeStarters], [$("mf-turn"), "click", turnBack],
      [$("mf-undo"), "click", undo], [$("mf-redo"), "click", redo], [$("minifig-cancel"), "click", cancel], [$("minifig-save"), "click", save]];
    function end(result) {
      made = result;
      for (const [target, type, listener] of listeners) target.removeEventListener(type, listener);
      dialog.removeEventListener("close", closed);
      if (dialog.open) dialog.close();
      shown.then(() => { figure?.dispose(); figure = null; });
      delete dialog.dataset.figure;
      resolve(result);
    }
    for (const [target, type, listener] of listeners) target.addEventListener(type, listener);
    dialog.addEventListener("close", closed);
    dialog.showModal();
    dialog.querySelector("[role=tab][aria-selected=true]")?.focus();
  });
}
