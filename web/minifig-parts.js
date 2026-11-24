// The parts a minifigure is made of in Edit profile's maker (figmaker,
// 2026-11-24; the owner: "the 'make your minifig' for the profile builder
// needs to be way more advanced, way more features, more 'skin tones' and
// far better ui/ux"). Every choice is a real part of the LDraw library (CC
// BY), named by its LDraw number, in a colour named by its LDraw code, so a
// figure says exactly what it is made of and could be built. Generic parts
// only: no licensed character's print or likeness, no trademarked logo
// (docs/TRADEMARKS.md).
//
// One file for the three that need the lists: the maker in the browser
// (web/minifig-maker.js) and its 3D figure (tools/viewer/minifig.js, built
// into web/minifig3d.js), the tiles drawn from the parts
// (tools/web/minifig_tiles.mjs), and the API, which holds what a request
// says to these lists before it keeps it (api/_minifig_parts.js passes this
// file through; tools/package_api.sh copies it beside the functions). So it
// imports nothing. Each list's order is its tiles' order in their picture
// (minifig_tiles.mjs), so a choice is only ever appended.
//
// A figure's recipe (v 2) is kept with the picture drawn of it
// (supabase/avatar_minifig.sql, at most 400 bytes as the database writes
// it): short keys, part numbers and colour codes. A v 1 recipe (avatarkit's
// layers, web/card.js MINIFIG) opens as the same figure (fromLayers).

// The skin tones: the LEGO® figures' own, yellow first and then light nougat to dark
// brown, as the figures of the last twenty years are made; then a few for
// a robot, a ghost or an alien.
export const SKINS = [14, 78, 92, 371, 84, 422, 370, 70, 308, 15, 71, 378, 27, 322, 31, 29];
export const REAL_SKINS = 9;
// A colour that is the figure's skin: hands and arms may be "skin" and
// follow it.
export const SKIN = -1;

// Faces, on the classic head (3626c) or the vented one (28621): [part, its
// second face on the back (a two-sided head), and what it shows, for the
// search: "glasses", "beard", "freckles", "lips"].
export const FACES = [
  ["3626cp01", 0, ""], ["3626cp7g", 0, ""], ["3626cp7h", 0, ""], ["3626cp8c", 0, "lips"], ["3626cp8a", 0, "lips"],
  ["3626cp71", 0, "freckles"], ["3626cp87", 0, "glasses"], ["3626cp88", 0, "beard"], ["3626cp84", 0, "glasses"],
  ["3626cp8b", 0, "freckles"], ["3626cp7c", 0, "beard"], ["3626cp73", 0, ""], ["3626cp05", 0, ""],
  ["3626cp0c", 0, "lips"], ["3626cp0z", 1, "lips"], ["3626cp14", 0, ""], ["3626cp18", 0, ""], ["3626cp1d", 1, "glasses lips"],
  ["3626cp1e", 1, ""], ["3626cp1f", 0, ""], ["3626cp1g", 1, "freckles lips"], ["3626cp1h", 0, ""], ["3626cp1m", 0, "glasses beard"],
  ["3626cp1o", 0, "beard"], ["3626cp1p", 0, "lips"], ["3626cp1q", 0, ""], ["3626cp40", 0, "beard"], ["3626cp70", 1, ""],
  ["3626cp72", 0, "beard"], ["3626cp74", 0, "beard"], ["3626cp75", 0, ""], ["3626cp76", 0, "glasses lips"], ["3626cp78", 1, ""],
  ["3626cp7a", 0, "beard"], ["3626cp7b", 1, "lips"], ["3626cp7d", 0, "glasses lips"], ["3626cp7e", 0, "glasses beard"],
  ["3626cp7f", 0, "glasses lips"], ["3626cp7i", 0, "beard"], ["3626cp7j", 1, "freckles"], ["3626cp7k", 0, "glasses beard"],
  ["3626cp7l", 0, "freckles"], ["3626cp7n", 0, ""], ["3626cp7o", 0, "lips"], ["3626cp80", 1, ""], ["3626cp83", 0, "glasses freckles"],
  ["3626cp86", 0, "beard"], ["3626cp8l", 0, "glasses lips"], ["3626cp8r", 1, "lips"], ["3626cp8s", 1, "freckles"],
  ["3626cp8t", 1, "beard"], ["3626cp8u", 1, "glasses lips"], ["3626cp8v", 0, "glasses lips"], ["3626cp8y", 0, "glasses"],
  ["3626cpcf4", 0, ""], ["3626cp30", 0, "beard"], ["3626cp0d", 0, "freckles"], ["3626cp8w", 1, ""], ["3626cp8q", 1, "lips"],
  ["28621p0i", 0, "lips"], ["28621p0k", 1, "glasses"], ["28621p0l", 1, ""], ["28621p0m", 1, "glasses"], ["28621p12", 1, "beard"],
  ["28621pcpc", 1, "glasses lips"],
];

// Hair, by style, and hats, helmets and headgear: [part, style, its colour
// as it first comes]. One of them on the head, or none ("").
export const HAIR = [
  ["3901", "short", 70], ["62810", "short", 308], ["40233", "short", 0], ["92081", "short", 70], ["99930", "short", 308],
  ["15500", "short", 0], ["23186", "short", 70], ["98385", "short", 0], ["2631", "short", 191], ["53982", "short", 0],
  ["93563", "short", 0], ["27385", "short", 29], ["30608", "short", 0], ["12893", "short", 71], ["98371", "short", 0],
  ["21788", "short", 308], ["88283", "short", 70], ["11256", "short", 19], ["103748", "short", 308], ["53981", "short", 191],
  ["40251", "long", 70], ["12890", "long", 0], ["92083", "long", 308], ["4530", "long", 19], ["1879", "long", 70],
  ["23187", "long", 484], ["62711", "long", 0], ["95328", "long", 308], ["20595", "long", 19], ["68508", "long", 70],
  ["85974", "long", 0], ["2123", "long", 0], ["36806", "long", 308],
  ["21778", "curly", 0], ["87995", "curly", 0], ["80911", "curly", 308], ["29634", "curly", 70], ["79688", "curly", 0],
  ["78301", "curly", 308], ["69857", "curly", 0], ["11255", "curly", 15],
  ["6093a", "up", 70], ["62696", "up", 308], ["87990", "up", 0], ["15427", "up", 19], ["93217", "up", 0], ["27186", "up", 308],
  ["30409", "up", 70], ["99240", "up", 71], ["3625", "up", 484], ["41615", "up", 70], ["13198", "up", 0], ["59363", "up", 308],
  ["35714", "up", 0],
  ["5492", "hat", 4], ["35660", "hat", 1], ["65730", "hat", 72],
  ["41334", "hat", 4], ["90541", "hat", 1], ["10164", "hat", 4], ["61506", "hat", 70], ["13565", "hat", 28], ["3878", "hat", 0],
  ["95674", "hat", 0], ["2514", "hat", 72], ["86035", "hat", 1], ["11303", "hat", 4], ["3629", "hat", 70], ["90386", "hat", 320],
  ["30172", "hat", 19], ["57881", "hat", 14], ["98381", "hat", 15], ["92814", "hat", 0], ["93557", "hat", 15], ["6131", "hat", 1],
  ["90388", "hat", 25], ["36933", "hat", 4], ["85975", "hat", 4], ["2544", "hat", 0], ["71015", "hat", 82], ["3624", "hat", 0],
  ["3833", "helmet", 14], ["3834", "helmet", 4], ["30124b", "helmet", 15], ["50665", "helmet", 15], ["46303", "helmet", 4],
  ["12899", "helmet", 1], ["35458", "helmet", 0], ["15851", "helmet", 4], ["30325", "helmet", 14], ["13792", "helmet", 72],
  ["53450", "helmet", 72], ["3844", "helmet", 71], ["75717", "helmet", 71], ["51283", "helmet", 47],
  ["4505a", "headwear", 70], ["74528", "headwear", 0], ["30287", "headwear", 4], ["3672", "headwear", 4],
  ["99244", "headwear", 15], ["26045", "headwear", 70], ["11262", "headwear", 15], ["24076", "headwear", 71], ["2523", "headwear", 2],
  ["29580", "headwear", 15], ["25977", "headwear", 14], ["20695", "headwear", 25], ["18165", "headwear", 82],
];

// What is worn at the neck or on the back: [part, colour as it first
// comes, what it is for the search].
export const NECKS = [
  ["4524", 4, "cape"], ["50231c01", 4, "cape"], ["99464c01", 1, "cape"], ["38301c01", 0, "cape"], ["25376", 4, "scarf"],
  ["30133", 4, "scarf"], ["27151", 0, "tie"], ["2524", 70, "backpack"], ["30158c01", 2, "backpack"], ["26073", 28, "backpack"],
  ["3838", 71, "tanks"], ["30091", 14, "tanks"], ["4736", 72, "tanks"], ["38781", 25, "vest"], ["15428", 72, "hood"],
  ["26066", 15, "collar"], ["99250", 82, "medal"], ["66913", 0, "headset"], ["10183", 43, "wings"], ["15501", 70, "beard"],
  ["93223", 15, "beard"], ["15439", 70, "beard"], ["4498", 70, "quiver"], ["37822", 1, "carrier"], ["85961", 72, "vest"],
];

// Torsos: plain (973), or a print over the torso's colour: [part, the
// colour its print shows skin in (taken as the figure's skin), or 0].
export const TORSOS = [
  ["973", 0], ["973p13", 0], ["973p18", 0], ["973p9c", 0], ["973p1a", 0], ["973pcf", 0], ["973p0b", 0], ["973pd7f", 0],
  ["973p0a", 0], ["973p1u", 0], ["973p03", 0], ["973p7z", 0], ["973p1b", 0], ["973p1c", 0], ["973p1j", 0], ["973p1r", 0],
  ["973p01", 0], ["973p1d", 0], ["973p1e", 0], ["973p2e", 0], ["973p7j", 0], ["973p0j", 0], ["973p1v", 0], ["973p0l", 0],
  ["973p0n", 0], ["973p28", 0], ["973p2h", 0], ["973p2i", 0], ["973p2d", 0], ["973p2b", 0], ["973p2a", 0], ["973p8t", 0],
  ["973p20", 0], ["973p7w", 0], ["973p8r", 0], ["973p7p", 0], ["973p6y", 0], ["973p6z", 0], ["973p8d", 0], ["973p6n", 0],
  ["973p0k", 0], ["973p73", 0], ["973p70", 0], ["973p7a", 0], ["973p0o", 0], ["973p1y", 0], ["973p5f", 0], ["973p1z", 0],
  ["973p1x", 14], ["973p2c", 14],
];

// Legs: [choice, kind, its parts]. "legs": hips and two legs, each its own
// colour (hips, right leg, left leg); "one": hips and legs in one part, or
// hips and a skirt, in the hips' colour; "over": a skirt worn over hips and
// legs. A leg whose print shows skin (shorts) is the figure's skin there.
export const LEGS = [
  ["3815b", "legs", ["3815b", "3816c", "3817c"]],
  ["3815bp0v", "legs", ["3815bp0v", "3816c", "3817c"]],
  ["3815bpc44", "legs", ["3815bpc44", "3816c", "3817c"]],
  ["3815bpde", "legs", ["3815bpde", "3816c", "3817c"]],
  ["3815bp42", "legs", ["3815bp42", "3816c", "3817c"]],
  ["shorts", "legs", ["3815b", "20461bp04", "20460bp04"], 14],
  ["41879a", "one", ["41879a"]],
  ["16709", "one", ["16709"]],
  ["37364", "one", ["37364"]],
  ["36036", "one", ["36036"]],
  ["24068", "one", ["24068"]],
  ["24087", "over", ["3815b", "3816c", "3817c", "24087"]],
  ["24782", "over", ["3815b", "3816c", "3817c", "24782"]],
  ["600880c01", "over", ["3815b", "3816c", "3817c", "600880c01"]],
  ["14295c01", "over", ["3815b", "3816c", "3817c", "14295c01"]],
  ["16820c01", "over", ["3815b", "3816c", "3817c", "16820c01"]],
];

// What a hand may hold: [part, colour as it first comes, what it is for
// the search]. Either hand, as real figures hold them (src/minifig/
// minifig.gd in_hand: its bar along the hand's grip; GRIPS beside).
export const HELD = [
  ["55295", 72, "tool"], ["55298", 72, "tool"], ["55299", 72, "tool"], ["55297", 0, "tool"], ["3837", 70, "tool"],
  ["3841", 72, "tool"], ["18826", 71, "tool"], ["24085", 70, "tool"], ["12885", 0, "tool"], ["92585", 4, "tool"],
  ["18920", 72, "tool"], ["30152ap01", 0, "tool"], ["3899", 15, "drink"], ["38014", 15, "drink"], ["15496", 15, "drink"],
  ["68495", 19, "drink"], ["23986", 15, "drink"], ["4528", 0, "kitchen"], ["4529", 71, "kitchen"], ["33120", 19, "food"],
  ["79743", 29, "food"], ["33051", 4, "food"], ["33085", 14, "food"], ["33078", 70, "food"], ["4342", 19, "food"],
  ["33125", 191, "food"], ["10170", 84, "food"], ["30222", 4, "food"], ["3962b", 0, "gadget"], ["30089b", 0, "gadget"],
  ["90370", 0, "gadget"], ["39144", 15, "gadget"], ["3069bp0t", 0, "gadget"], ["27150", 0, "fun"], ["30162", 0, "gadget"],
  ["64644", 82, "gadget"], ["2614", 0, "fun"], ["3852b", 29, "fun"], ["40359a", 82, "fun"], ["35763", 4, "fun"],
  ["35692", 29, "fun"], ["43702", 25, "fun"], ["10172", 82, "fun"], ["4449-f1", 70, "fun"], ["13808", 82, "music"],
  ["69947", 70, "music"], ["90508", 25, "music"], ["6124b", 0, "fun"], ["102498", 70, "fun"], ["3959", 70, "fun"],
  ["3596", 4, "fun"], ["3004", 4, "brick"], ["3005", 1, "brick"],
];

// Where a held part's bar is, in its LDraw frame (minifig_data.gd GRIPS:
// [x, y, z, along x, y, z]); a part not named holds at its origin along Y.
// The ones the library has no grip for are measured off their own shape:
// a cup or a can by its side, a brick by its middle as a hand carries one.
export const GRIPS = {
  55295: [0, -12, 0, 0, -1, 0], 55298: [0, 9, 0, 0, 1, 0], 55299: [0, 9, 0, 0, 1, 0], 18826: [0, 6.9, 0, 0, 1, 0],
  24085: [0, 1.25, 0, 0, -1, 0], 12885: [0, -10.5, 0, 0, 1, 0], 92585: [0, 27.9, 0, 0, -1, 0], 3841: [0, 0, 0, 0, -1, 0],
  3899: [0, 11, 20, 0, -1, 0], 38014: [0, -10.709, 16, 0, -1, 0], 68495: [16, -21.504, 0, 0, -1, 0],
  23986: [-20, 8.5, 0, 0, -1, 0], 4528: [0, 4, 22.1, 0, 0, 1], 4529: [0, 6, 21.1, 0, 0, 1], 79743: [0, 2, 0, 0, -1, 0],
  33085: [-4, 0, 0, 1, 0, 0], 33125: [0, -8.5, 0, 0, 1, 0], "30089b": [-5.2, 0, 3.6, 0, 1, 0], 90370: [0, 7, 0, 0, 1, 0],
  39144: [0, 13.5, 0, 0, 1, 0], 27150: [0, 0, 0, 0, -1, 0], 30162: [6, 0, -1, 0, 0, 1], 64644: [0, 10, 0, 0, -1, 0],
  "40359a": [0, 0, 0, 0, -1, 0], 35692: [0, 0, 0, 0, 0, 1], 10172: [0, -14.75, 0, 0, 1, 0], "4449-f1": [0, 0, 0, 1, 0, 0],
  13808: [0, -7.311, 0, 0, 1, 0], 69947: [0, -27.1, 0, 0, -1, 0], "6124b": [0, -8, 0, 0, 1, 0], 102498: [0, -9.2, 0, 0, 1, 0],
  3959: [0, 8, 0, 0, 1, 0], "3962b": [0, 0, 0, 0, 1, 0],
  15496: [0, 14, 12, 0, 1, 0], 33054: [0, -12, 14, 0, -1, 0], 33051: [0, 10, 0, 0, 1, 0], 33078: [0, 0, 0, 1, 0, 0],
  4342: [0, 7, 0, 1, 0, 0], 10170: [0, 0, 0, 1, 0, 0], 3596: [0, 40, 0, 0, 1, 0], "3069bp0t": [0, -4, 0, 1, 0, 0],
  3004: [0, -10, 0, 1, 0, 0], 3005: [0, -10, 0, 1, 0, 0], 43702: [0, 0, 0, 1, 0, 0], 35763: [0, 4, 0, 0, 1, 0],
};

// How far a part round the neck lifts the head by its collar
// (minifig_data.gd NECK_LIFT), and the one worn turned (the quiver).
export const NECK_LIFT = { 4524: 2, "50231c01": 1, 25376: 2, 27151: 3, 2524: 2, "30158c01": 2, 26073: 3, 3838: 3,
  30091: 4, 4736: 2, 38781: 3, 15428: 3, 26066: 3, 99250: 3, 66913: 6, 10183: 3, 15501: 3, 15439: 3, 4498: 3,
  37822: 3, 85961: 5 };
export const NECK_TURNED = { 4498: 180 };

// The colours every part may be: the LEGO® palette of today, solid, then
// metallic and pearl. Hair's natural colours first in its row.
export const PALETTE = [0, 72, 71, 15, 4, 320, 25, 484, 191, 14, 226, 368, 27, 10, 2, 288, 330, 378, 3, 323, 322, 321, 73,
  1, 272, 212, 379, 431, 85, 30, 31, 26, 5, 29, 430, 353, 402, 424, 19, 28, 371, 84, 92, 78, 422, 370, 70, 308, 326, 82, 80,
  297, 315, 316];
export const HAIR_COLOURS = [0, 308, 70, 370, 84, 28, 19, 371, 191, 484, 402, 71, 15];
// See-through ones, for a helmet's bowl or a wing.
export const CLEAR = [47, 43, 33, 36, 46];

// Each colour as LDraw has it (assets/generated/colors.json): its RGB, and
// "m" where it is metallic or pearl, "t" where it is see-through.
export const COLOURS = {
  0: "1b2a34", 1: "1e5aa8", 2: "00852b", 3: "069d9f", 4: "b40000", 5: "d3359d", 10: "58ab41", 14: "fac80a", 15: "f4f4f4",
  19: "d7ba8c", 25: "d67923", 26: "901f76", 27: "a5ca18", 28: "897d62", 29: "ff9ecd", 30: "a06eb9", 31: "cda4de",
  70: "5f3109", 71: "969696", 72: "646464", 73: "7396c8", 78: "ffc995", 84: "aa7d55", 85: "441a91", 92: "bb805a",
  191: "fcac00", 212: "9dc3f7", 226: "ffec6c", 272: "19325a", 288: "00451a", 308: "352100", 320: "720012", 321: "469bc3",
  322: "68c3e2", 323: "d3f2ea", 326: "e2f99a", 330: "77774e", 353: "ff6d77", 368: "edff21", 370: "755945", 371: "cca373",
  378: "708e7c", 379: "70819a", 402: "ca4c0b", 422: "915c3c", 424: "dd9e47", 430: "f79b9b", 431: "665ea7", 484: "91501c",
  80: "767676m", 82: "dbac34m", 297: "aa7f2em", 315: "8c8c8cm", 316: "3e3c39m",
  47: "fcfcfct", 43: "aee9eft", 33: "0020a0t", 36: "c91a09t", 46: "f5cd2ft",
};

// The backgrounds: the site's avatar colours (site.css --avatar-1..8, "a1"
// to "a8"), a colour of the palette ("c" and its code), a gradient ("g"
// and its number) or a simple scene ("s" and its number), each drawn
// behind the figure the same in the maker and in the picture it keeps.
export const AVATAR_COLOURS = ["#b42318", "#1f5fbf", "#1f7a3d", "#7a3fb0", "#9a4a00", "#0e6f8a", "#a3175a", "#4b5563"];
export const GRADIENTS = [["#ff9a8b", "#ff6a88"], ["#a1c4fd", "#c2e9fb"], ["#84fab0", "#8fd3f4"], ["#fbc2eb", "#a6c1ee"],
  ["#f6d365", "#fda085"], ["#30cfd0", "#330867"], ["#43e97b", "#38f9d7"], ["#434343", "#000000"], ["#ffecd2", "#fcb69f"],
  ["#667eea", "#764ba2"]];
export const SCENES = ["sky", "sunset", "space", "studio", "grass", "beach", "snow", "city"];

// How a figure is posed: the head turned, each arm raised, each hand
// turned (degrees), and the legs: standing, walking or sitting.
export const STANCES = ["stand", "walk", "sit"];
export const POSES = {
  stand: [0, 0, 0, 0, 0, 0],
  wave: [-12, 0, -150, 0, 30, 0],
  cheer: [0, -160, -160, 0, 0, 0],
  thinking: [20, -70, 0, -40, 0, 0],
  sitting: [0, -40, -40, 0, 0, 2],
  walking: [-8, 28, -28, 0, 0, 1],
  point: [-20, 0, -90, 0, 0, 0],
};
// How far each may go: the head and hands all the way round, an arm all
// the way up and a little back.
export const POSE_RANGE = [[-180, 180], [-180, 45], [-180, 45], [-180, 180], [-180, 180], [0, 2]];

const ids = (list) => list.map(([id]) => id);

// The tiles' pictures (tools/web/minifig_tiles.mjs): a cell [size] pixels
// square a part, [columns] to a row, in each group's list's order.
export const TILE = { size: 96, columns: 10 };

/// Each group's tiles, the parts of each in order: {group: [choice]}.
export const tileGroups = () => ({ skin: ["3626c"], faces: ids(FACES), hair: ids(HAIR), necks: ids(NECKS),
  torsos: ids(TORSOS), legs: ids(LEGS), held: ids(HELD) });

/// A list's hash, in the name of its tiles' pictures: a list that changed
/// asks for pictures drawn of it.
export function tilesHash(list) {
  let hash = 0x811c9dc5;
  for (const c of list.join(",")) {
    hash ^= c.codePointAt(0);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash.toString(16).padStart(8, "0");
}
const has = (list, value) => list.includes(value);
const colour = (code) => Number.isInteger(code) && Object.hasOwn(COLOURS, code);
const id = (value) => typeof value === "string" && /^[0-9a-z-]{0,16}$/.test(value);

/// The background [code] stands for: {kind: "a" | "c" | "g" | "s", at}, or
/// null where it is none of them.
export function backgroundOf(code) {
  const found = /^([acgs])(\d{1,3})$/.exec(String(code || ""));
  if (!found) return null;
  const [, kind, number] = found;
  const at = Number(number);
  const ok = kind === "a" ? at >= 1 && at <= AVATAR_COLOURS.length : kind === "c" ? colour(at) && !CLEAR.includes(at)
    : kind === "g" ? at >= 1 && at <= GRADIENTS.length : at >= 1 && at <= SCENES.length;
  return ok ? { kind, at } : null;
}

/// [recipe] as the maker makes one (v 2), or null for anything else: what a
/// request's body says is held to the lists, never kept as it came.
export function figureShape(recipe) {
  if (!recipe || typeof recipe !== "object" || Array.isArray(recipe) || recipe.v !== 2) return null;
  const r = recipe;
  const part = (value, list) => value === "" || has(ids(list), value);
  const body = (value) => value === SKIN || colour(value);
  const ok = has(SKINS, r.sk) && has(ids(FACES), r.fa) && (r.fb === 0 || r.fb === 1)
    && part(r.hd, HAIR) && colour(r.hc) && part(r.nk, NECKS) && colour(r.nc)
    && has(ids(TORSOS), r.to) && colour(r.tc) && body(r.ar) && body(r.al) && body(r.hr) && body(r.hl)
    && has(ids(LEGS), r.lg) && colour(r.hp) && colour(r.rr) && colour(r.ll)
    && part(r.ir, HELD) && colour(r.ic) && part(r.il, HELD) && colour(r.jc)
    && Array.isArray(r.po) && r.po.length === POSE_RANGE.length
    && r.po.every((n, at) => Number.isInteger(n) && n >= POSE_RANGE[at][0] && n <= POSE_RANGE[at][1])
    && backgroundOf(r.bg) !== null && (r.fr === 0 || r.fr === 1) && [r.hd, r.nk, r.ir, r.il].every(id);
  if (!ok) return null;
  return { v: 2, sk: r.sk, fa: r.fa, fb: r.fb, hd: r.hd, hc: r.hc, nk: r.nk, nc: r.nc, to: r.to, tc: r.tc, ar: r.ar,
    al: r.al, hr: r.hr, hl: r.hl, lg: r.lg, hp: r.hp, rr: r.rr, ll: r.ll, ir: r.ir, ic: r.ic, il: r.il, jc: r.jc,
    po: [...r.po], bg: r.bg, fr: r.fr };
}

// A v 1 recipe's hats, in their own colour (web/card.js MINIFIG.hats).
const V1_HATS = { 41334: 4, 3833: 14, 61506: 70, 3878: 0, 3624: 0, 2514: 72 };

/// A v 1 recipe (avatarkit's layers: face, hair or hat and its colour,
/// print, torso and legs colours, background 1-8) as the same figure in v
/// 2: the yellow skin, the arms in the torso's colour, yellow hands, hips
/// and legs in one colour, standing, head and shoulders on the avatar
/// colour it had. Anything else as it is.
export function fromLayers(recipe) {
  if (!recipe || recipe.v !== 1) return recipe;
  const hair = String(recipe.hair || "");
  return { v: 2, sk: 14, fa: recipe.face, fb: 0, hd: hair, hc: V1_HATS[hair] ?? recipe.hairColour, nk: "", nc: 0,
    to: recipe.print || "973", tc: recipe.torso, ar: recipe.torso, al: recipe.torso, hr: SKIN, hl: SKIN, lg: "3815b",
    hp: recipe.legs, rr: recipe.legs, ll: recipe.legs, ir: "", ic: 0, il: "", jc: 0, po: [...POSES.stand],
    bg: `a${recipe.background}`, fr: 0 };
}

/// The colour a body part of [recipe] is drawn in: its own, or the skin's.
export const bodyColour = (recipe, code) => (code === SKIN ? recipe.sk : code);

/// Every part [recipe] is made of: [{slot, part, colour, skinFrom}], the
/// slot being the maker's group a press on it opens. skinFrom: a colour of
/// the part's print that is skin, drawn in the figure's skin.
export function figureParts(recipe) {
  const r = recipe;
  const parts = [];
  const put = (slot, part, code, skinFrom = 0) => { if (part) parts.push({ slot, part, colour: code, skinFrom }); };
  put("face", r.fa, r.sk);
  put("hair", r.hd, r.hc);
  put("neck", r.nk, r.nc);
  const torso = TORSOS.find(([one]) => one === r.to);
  put("torso", r.to, r.tc, torso?.[1] || 0);
  put("armR", "3818", bodyColour(r, r.ar));
  put("armL", "3819", bodyColour(r, r.al));
  put("handR", "3820", bodyColour(r, r.hr));
  put("handL", "3820", bodyColour(r, r.hl));
  const legs = LEGS.find(([one]) => one === r.lg) || LEGS[0];
  const [, kind, pieces, skinFrom = 0] = legs;
  if (kind === "one") put("hips", pieces[0], r.hp);
  else {
    put("hips", pieces[0], r.hp);
    put("legR", pieces[1], r.rr, skinFrom);
    put("legL", pieces[2], r.ll, skinFrom);
    if (kind === "over") put("skirt", pieces[3], r.hp);
  }
  put("heldR", r.ir, r.ic);
  put("heldL", r.il, r.jc);
  return parts;
}

/// The figure every list starts on: what a new maker opens with when there
/// is nothing else to start from.
export const PLAIN = { v: 2, sk: 14, fa: "3626cp01", fb: 0, hd: "3901", hc: 70, nk: "", nc: 0, to: "973", tc: 4, ar: 4,
  al: 4, hr: SKIN, hl: SKIN, lg: "3815b", hp: 1, rr: 1, ll: 1, ir: "", ic: 0, il: "", jc: 0, po: [0, 0, 0, 0, 0, 0], bg: "a2",
  fr: 0 };

// A handful of figures to start from, each of the lists' own parts.
export const STARTERS = {
  builder: { ...PLAIN, sk: 92, fa: "3626cp7c", hd: "3833", hc: 14, nk: "", to: "973p7p", tc: 1, ar: 1, al: 1, lg: "3815b",
    hp: 0, rr: 0, ll: 0, ir: "55295", ic: 72, po: [0, -40, 0, 0, 0, 0], bg: "s5" },
  chef: { ...PLAIN, sk: 78, fa: "3626cp0c", hd: "98381", hc: 15, to: "973p8t", tc: 15, ar: 15, al: 15, hp: 0, rr: 0, ll: 0,
    ir: "4528", ic: 0, po: [0, -45, 0, 0, 0, 0], bg: "s4" },
  explorer: { ...PLAIN, sk: 84, fa: "3626cp72", hd: "30172", hc: 19, nk: "2524", nc: 70, to: "973p73", tc: 28, ar: 28, al: 28,
    hp: 70, rr: 70, ll: 70, ir: "30162", ic: 0, po: [-10, -60, 0, 0, 0, 1], bg: "s1" },
  artist: { ...PLAIN, sk: 370, fa: "3626cp8u", hd: "90386", hc: 320, to: "973p6z", tc: 15, ar: 15, al: 15, hp: 272, rr: 272,
    ll: 272, ir: "12885", ic: 0, bg: "g4" },
  scientist: { ...PLAIN, sk: 308, fa: "3626cp1m", hd: "21778", hc: 0, to: "973p03", tc: 15, ar: 15, al: 15, lg: "3815bpde",
    hp: 15, rr: 72, ll: 72, ir: "30152ap01", ic: 0, po: [14, -100, 0, -40, 0, 0], bg: "g2" },
  astronaut: { ...PLAIN, sk: 422, fa: "28621p0i", hd: "50665", hc: 15, nk: "3838", nc: 71, to: "973", tc: 15, ar: 15, al: 15,
    hr: 15, hl: 15, hp: 15, rr: 15, ll: 15, po: [0, 0, -150, 0, 30, 0], bg: "s3" },
  skater: { ...PLAIN, sk: 371, fa: "3626cp1g", hd: "65730", hc: 4, to: "973p7j", tc: 26, ar: 26, al: 26, lg: "shorts",
    hp: 272, rr: 272, ll: 272, il: "3069bp0t", jc: 0, po: [-16, 0, -60, 0, 0, 1], bg: "s8" },
  wizard: { ...PLAIN, sk: 78, fa: "3626cp8t", hd: "6131", hc: 1, nk: "50231c01", nc: 272, to: "973", tc: 1, ar: 1, al: 1,
    lg: "36036", hp: 1, ir: "6124b", ic: 0, po: [0, -120, 0, 0, 0, 0], bg: "g6" },
};
