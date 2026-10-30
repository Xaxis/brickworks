// A whole Brickworks, with no deployment behind it, for the site's design
// check (tools/web/design_flow.mjs), which visits every page signed out and
// signed in.
//
// Three things, from one set of fixtures:
//
// - apiAnswer: a request a page's script makes, to ORIGIN/api/... or to the
//   sign-in service at DB/auth/v1/..., answered as the deployment answers
//   it, so every page draws all of its controls. The flow routes the
//   browser's requests here and fulfils them with what comes back; null is
//   "not mine" (a picture, or something unknown), which the flow serves
//   itself.
// - serverPage: a page the server makes (/m/<id>, /m/<id>/v/<n>,
//   /m/<id>/embed, /u/<handle>, /c/<id>), made by the real api/share.js and
//   api/people.js of whichever api/ directory the flow names, in this
//   process, called as tools/web/relay_server.mjs calls them. Their
//   database is reached by fetch, so fetch is wrapped once: PostgREST
//   (DB/rest/v1/...) and storage (DB/storage/v1/...) are answered from the
//   fixtures, and anything else goes out as before.
// - signedInStorage: what the browser keeps when it is signed in as EMAIL.
//
// And serveSite, all three put together in a browser context: the site as
// deploy.sh serves it, for design_flow.mjs and theme_flow.mjs.
//
//   import { ORIGIN, apiAnswer, serverPage, signedInStorage } from "./design_stand_in.mjs";
//   const said = apiAnswer({ url: new URL(request.url()), method, body, state });
//   const { status, html } = await serverPage(`${checkout}/api`, "/m/DesignAbc1");
//
// Who is who. EMAIL is Sam Okafor (@sam-builds): two models of their own,
// two collections, favourites and a feed. HANDLE is Robin Castell, a
// designer with four models in the gallery; MODEL_ID is Robin's, this
// week's pick, with two versions, comments and photos of builds. Sam is not
// its owner, so its page offers Sam the comment box, the photo form and
// Follow. state.admin makes Sam the site's owner, for /admin.
//
// The model on its page is the one on the gallery's card, its comments are
// the ones its script lists, and a designer's numbers add up to their
// cards'. Dates and counts are fixed, so two runs draw the same pages. A
// POST answers as if it went, and nothing is kept: the next read is as
// before.
//
// The connector's sign-in page (/oauth/authorize) is checked as the
// deployment checks it: response_type=code, code_challenge_method=S256 and
// a code_challenge of 43 base64url characters, or it shows its refusal.

import { existsSync, readFileSync } from "node:fs";
import path, { join } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
// What a notification says and how they are grouped (docs/SOCIAL.md U7):
// pure, so the stand-in answers as the API does.
import { noticeGroups } from "../../api/_notifications.js";
// Designers to follow, read from Top builds' cards as the API reads them
// (docs/SOCIAL.md U9): pure too.
import { LATEST, designersFrom } from "../../api/_follows.js";
// What a handle may not be, as the API says it (a new account's First steps).
import { handleTrouble } from "../../api/_names.js";
// What a featured model's card says (gallery362).
import { featuredSaid } from "../../api/_featured.js";
// The interest form on /plans, checked as the API checks it, and its words.
import { GONE, KEPT, entryOf } from "../../api/plans.js";
import { Refusal as BetaRefusal, applicationOf } from "../../api/_beta.js";
// What a person earned (docs/SOCIAL.md U13), worked out as the server works it out.
import { achievementsOf } from "../../api/people.js";
// Whose picture is beside their name (supabase/avatars.sql), given as the
// API gives it; and the pictures themselves, made here.
import { facesOn, pictureAt } from "../../api/_faces.js";
import { encode as encodeJpeg } from "../../api/_jpeg.js";
// What a model is based on (supabase/model_bases.sql): a designer's list
// checked, and said, as the API checks and says it.
import { basesAsked, basesSaid } from "../../api/_bases.js";
// Who a comment names (@handle), read as the API reads it.
import { mentionsIn } from "../../web/card.js";

export const ORIGIN = "http://design.test";
export const DB = "https://stub.supabase.test";
export const MODEL_ID = "DesignAbc1";
export const HANDLE = "design-tester";
export const LIST_ID = "ListAbcde1";
export const EMAIL = "designer@example.com";

// The keys the pages and the handlers are given: nothing checks them.
const PUBLISHABLE = "stub-publishable";
const SECRET = "stub";
// 2100-01-01, as seconds and as milliseconds: a sign-in that never ends.
const FOREVER = 4102444800;

// ---------------------------------------------------------------------------
// The people.

const ROBIN = "11111111-1111-4111-8111-111111111111";
const SAM = "22222222-2222-4222-8222-222222222222";
const JO = "33333333-3333-4333-8333-333333333333";
const MIKA = "44444444-4444-4444-8444-444444444444";
const PRIYA = "55555555-5555-4555-8555-555555555555";
// An account with no profile, and one the site's owner took out.
const NOBODY = "66666666-6666-4666-8666-666666666666";
const SPAMMER = "77777777-7777-4777-8777-777777777777";
// Who is signed in.
const ME = SAM;

const PEOPLE = [
  { account: ROBIN, handle: HANDLE, name: "Robin Castell", email: "robin@example.com",
    bio: "I design castles and small mechanisms, built to be built. Every model here passed the app's tests before it went up.",
    created_at: "2026-03-02T10:00:00Z", last_sign_in: "2026-10-18T20:41:00Z" },
  { account: SAM, handle: "sam-builds", name: "Sam Okafor", email: EMAIL,
    bio: "Weekend builder: trams, trains and the town around them.",
    created_at: "2026-05-11T09:00:00Z", last_sign_in: "2026-10-19T08:12:00Z" },
  { account: JO, handle: "jo-bricks", name: "Jo Lindqvist", email: "jo@example.com",
    bio: "Mostly other people's castles, built in my own colours.", created_at: "2026-06-20T18:30:00Z",
    last_sign_in: "2026-10-17T21:05:00Z" },
  { account: MIKA, handle: "mika-mocs", name: "Mika Tanaka", email: "mika@example.com",
    bio: "Small mechs and starter sets.", created_at: "2026-04-08T12:00:00Z", last_sign_in: "2026-10-16T07:55:00Z" },
  { account: PRIYA, handle: "priya-plays", name: "Priya Raman", email: "priya@example.com",
    bio: "Space, rovers and anything with a turntable.", created_at: "2026-07-01T15:20:00Z",
    last_sign_in: "2026-10-18T11:30:00Z" },
];
const NO_PROFILE = [
  { account: NOBODY, email: "new-builder@example.com", created_at: "2026-10-12T10:00:00Z", last_sign_in: "2026-10-12T10:02:00Z" },
  { account: SPAMMER, email: "cheap-bricks@example.com", created_at: "2026-09-30T03:00:00Z", last_sign_in: "2026-10-01T03:10:00Z" },
];
// Who follows whom, and who shows whom they follow.
const FOLLOWS = [
  { follower: JO, followed: ROBIN, at: "2026-09-01T10:00:00Z" },
  { follower: PRIYA, followed: ROBIN, at: "2026-09-14T10:00:00Z" },
  { follower: MIKA, followed: ROBIN, at: "2026-10-02T10:00:00Z" },
  { follower: ROBIN, followed: MIKA, at: "2026-08-11T10:00:00Z" },
  { follower: ROBIN, followed: PRIYA, at: "2026-09-20T10:00:00Z" },
  { follower: SAM, followed: MIKA, at: "2026-09-12T10:00:00Z" },
  { follower: SAM, followed: PRIYA, at: "2026-10-01T10:00:00Z" },
  { follower: JO, followed: SAM, at: "2026-10-03T10:00:00Z" },
];
const SHOWS_FOLLOWS = new Set([ROBIN]);
// Who follows which collection (supabase/collection_follows.sql): Sam, Jo
// and Priya follow Robin's castles.
const LIST_FOLLOWS = [
  { follower: SAM, collection: "ListAbcde1", at: "2026-10-12T10:00:00Z" },
  { follower: JO, collection: "ListAbcde1", at: "2026-10-13T10:00:00Z" },
  { follower: PRIYA, collection: "ListAbcde1", at: "2026-10-14T09:00:00Z" },
];

// ---------------------------------------------------------------------------
// The models. Each as shared_models keeps it, with what is left out filled
// in: listed, published, a picture and a small one, CC BY.

function model(row) {
  return { has_image: true, has_thumb: true, published: true, listed: true, barred: false, test: false,
    remixed_from: null, description: null, tags: [], licence: "cc-by-4.0", kind: null, own_steps: true,
    technic: false, bytes: row.parts * 117, created_at: row.listed_at || row.updated_at, listed_at: null, ...row };
}

const MODELS = [
  model({ id: MODEL_ID, owner: ROBIN, name: "Riverside Watchtower", author: "Robin Castell", parts: 412, steps: 6,
    kind: "castle", tags: ["castle", "tower", "medieval"], remixed_from: "DesignPar1",
    listed_at: "2026-09-28T09:05:00Z", updated_at: "2026-10-15T18:20:00Z",
    description: "A three-storey watchtower on a riverbank, with a portcullis that opens and a banner on top.\n\n"
      + "Built to be built: every step stands on its own, and the walls go up in the order you would lay them. "
      + "About an evening's build." }),
  model({ id: "DesignGea1", owner: ROBIN, name: "Two-Speed Gearbox", author: "Robin Castell", parts: 88, steps: 12,
    kind: "mechanism", technic: true, tags: ["gearbox", "technic", "mechanism"], licence: "cc-by-sa-4.0",
    listed_at: "2026-08-20T16:00:00Z", updated_at: "2026-08-22T09:30:00Z",
    description: "A compact two-speed gearbox you shift by hand, with a clutch gear between." }),
  model({ id: "DesignFox1", owner: ROBIN, name: "Little Red Fox", author: "Robin Castell", parts: 64, steps: 8,
    kind: "nature", tags: ["animal", "fox"], own_steps: false, has_thumb: false,
    listed_at: "2026-07-14T12:00:00Z", updated_at: "2026-07-14T12:00:00Z" }),
  model({ id: "DesignBrg1", owner: ROBIN, name: "Stone Footbridge", author: "Robin Castell", parts: 230, steps: 10,
    kind: "architecture", tags: ["bridge", "stone", "modular"], licence: "all-rights-reserved",
    has_image: false, has_thumb: false, listed_at: "2026-06-30T08:00:00Z", updated_at: "2026-06-30T08:00:00Z" }),
  model({ id: "GoneModel1", owner: ROBIN, name: "Old Keep", author: "Robin Castell", parts: 300, steps: 9,
    kind: "castle", published: false, listed: false, listed_at: "2026-04-01T10:00:00Z", updated_at: "2026-05-01T10:00:00Z" }),
  model({ id: "DesignPar1", owner: MIKA, name: "Gatehouse Starter", author: "Mika Tanaka", parts: 156, steps: 7,
    kind: "castle", tags: ["castle", "gate", "starter"], remixed_from: "MikaDraft1",
    listed_at: "2026-05-03T10:00:00Z", updated_at: "2026-05-03T10:00:00Z",
    description: "A small gatehouse to start a castle from." }),
  model({ id: "MikaDraft1", owner: MIKA, name: "Gatehouse sketch", author: "Mika Tanaka", parts: 120, steps: 5,
    kind: "castle", listed: false, updated_at: "2026-04-20T10:00:00Z" }),
  model({ id: "MikaRobot1", owner: MIKA, name: "Pocket Mech", author: "Mika Tanaka", parts: 120, steps: 9,
    kind: "robot", tags: ["mech", "robot"], listed_at: "2026-10-01T17:00:00Z", updated_at: "2026-10-01T17:00:00Z" }),
  model({ id: "MikaTram01", owner: MIKA, name: "Night Tram", author: "Mika Tanaka", parts: 352, steps: 14,
    kind: "vehicle", tags: ["tram", "night"], remixed_from: "SamModel01",
    listed_at: "2026-10-13T12:00:00Z", updated_at: "2026-10-13T12:00:00Z" }),
  model({ id: "DesignRmx1", owner: JO, name: "Watchtower at Dusk", author: "Jo Lindqvist", parts: 430, steps: 6,
    kind: "castle", tags: ["castle", "night"], remixed_from: MODEL_ID,
    listed_at: "2026-10-10T19:00:00Z", updated_at: "2026-10-10T19:00:00Z",
    description: "The watchtower in dark stone, with lamps lit." }),
  model({ id: "JoDraft001", owner: JO, name: "Watchtower, winter", author: "Jo Lindqvist", parts: 418, steps: 6,
    kind: "castle", listed: false, remixed_from: MODEL_ID, updated_at: "2026-10-11T19:00:00Z" }),
  model({ id: "PriyaDrft1", owner: PRIYA, name: "Tower test", author: null, parts: 405, steps: 6,
    kind: "castle", listed: false, remixed_from: MODEL_ID, updated_at: "2026-10-12T19:00:00Z" }),
  model({ id: "PriyaSpc01", owner: PRIYA, name: "Lunar Rover", author: "Priya Raman", parts: 1240, steps: 32,
    kind: "space", technic: true, tags: ["space", "rover", "moon"], listed_at: "2026-10-16T07:00:00Z",
    updated_at: "2026-10-16T07:00:00Z", description: "Six-wheeled, with a turntable mast and working suspension." }),
  model({ id: "SamModel01", owner: SAM, name: "Harbour Tram", author: "Sam Okafor", parts: 340, steps: 14,
    kind: "vehicle", tags: ["tram", "train", "town"], listed_at: "2026-09-12T10:00:00Z",
    updated_at: "2026-09-12T10:00:00Z", description: "A two-car harbour tram with a pantograph." }),
  model({ id: "SamModel02", owner: SAM, name: "Corner Bakery", author: null, parts: 610, steps: 22, kind: "town",
    tags: ["town", "modular"], listed: false, updated_at: "2026-10-08T10:00:00Z" }),
];

// [views, likes, builds], as model_stats counts them.
const STATS = {
  [MODEL_ID]: [1284, 96, 37], DesignGea1: [640, 51, 22], DesignFox1: [410, 33, 14], DesignBrg1: [220, 12, 4],
  DesignPar1: [890, 70, 41], MikaDraft1: [12, 0, 0], MikaRobot1: [300, 25, 11], MikaTram01: [80, 6, 1],
  DesignRmx1: [150, 18, 3], JoDraft001: [9, 0, 0], PriyaDrft1: [4, 0, 0], PriyaSpc01: [760, 88, 12],
  SamModel01: [512, 40, 9], SamModel02: [34, 0, 0],
};
// Whose newest version passed the app's four tests.
const TESTED = new Set([MODEL_ID, "DesignGea1", "DesignPar1", "PriyaSpc01", "SamModel01"]);

// A profile's page (api/people.js profilePage, supabase/profile_shows.sql):
// what Robin chose to show (two links, the watchtower across the top, three
// models pinned); Alex, new, with nothing yet; the house account,
// credited "Brickworks" as the live
// gallery's seven models are, which chose nothing; and Ines, with 60 models,
// every one of which her page reaches. The house's and Ines's are test
// models, which only a page asked with tests=1 shows: the gallery here is
// as it was.
const HOUSE = "88888888-8888-4888-8888-888888888888";
const INES = "99999999-9999-4999-8999-999999999999";
const ALEX = "aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa";
PEOPLE.push(
  { account: ALEX, handle: "new-here", name: "Alex Moreau", email: "alex@example.com", bio: null,
    created_at: "2026-10-21T09:00:00Z", last_sign_in: "2026-10-21T09:05:00Z" },
  { account: HOUSE, handle: "brickworks", name: "Brickworks", email: "house@example.com", bio: null,
    created_at: "2026-10-11T09:00:00Z", last_sign_in: "2026-10-13T09:00:00Z" },
  { account: INES, handle: "ines-many", name: "Ines Ferreira", email: "ines@example.com",
    bio: "Sixty small builds, one a week, each under a hundred parts.", created_at: "2025-11-02T09:00:00Z",
    last_sign_in: "2026-10-19T09:00:00Z" });
for (const [at, [name, kind, parts]] of [["Wizard's Tower", "castle", 9541], ["Sports Car", "vehicle", 412],
  ["Harbour Crane", "mechanism", 980], ["Lighthouse", "architecture", 640], ["Market Stall", "town", 210],
  ["Space Shuttle", "space", 1320], ["Steam Train", "vehicle", 760]].entries()) {
  MODELS.push(model({ id: `HouseMod0${at + 1}`, owner: HOUSE, name, author: "Brickworks", parts, steps: 12 + at, kind,
    tags: ["ai-designed"], test: true, listed_at: `2026-10-1${at}T10:00:00Z`, updated_at: `2026-10-1${at}T10:00:00Z`,
    description: "Designed with the assistant." }));
}
for (let at = 1; at <= 60; at++) {
  const day = new Date(Date.UTC(2025, 10, 2) + at * 7 * 864e5).toISOString();
  MODELS.push(model({ id: `InesMod${String(at).padStart(3, "0")}`, owner: INES, name: `Small build ${at}`,
    author: "Ines Ferreira", parts: 20 + at, steps: 4, kind: "nature", test: true, has_thumb: at % 2 === 0,
    listed_at: day, updated_at: day }));
}
const SHOWS = [
  { account: ROBIN, links: ["https://robin-castell.example/castles", "https://www.flickr.com/photos/robin-castell"],
    banner: MODEL_ID, pins: ["DesignGea1", MODEL_ID, "DesignFox1"], updated_at: "2026-10-20T10:00:00Z" },
  { account: INES, links: [], banner: null, pins: ["InesMod003", "InesMod059"], updated_at: "2026-10-20T10:00:00Z" },
];

// The watchtower's two versions; every other model is its version 1.
const VERSIONS = [
  { model: MODEL_ID, n: 2, at: "2026-10-15T18:20:00Z", note: "A portcullis that opens, and a sixth step for the banner.",
    parts: 412, steps: 6, bytes: 48204, has_image: true, first_changed: 5, remixed_from_version: 1,
    changes: { added: [{ part: "3001", colour: 71, count: 8 }, { part: "2453b", colour: 72, count: 6 },
      { part: "4589", colour: 4, count: 2 }], removed: [{ part: "3004", colour: 71, count: 2 }],
    added_count: 16, removed_count: 2, added_in: [5, 6], removed_from: [5], steps_added: [6], steps_removed: [],
    steps_changed: [5], first: 5, compared: true, parts: 412, steps: 6 } },
  { model: MODEL_ID, n: 1, at: "2026-09-28T09:05:00Z", note: null, parts: 398, steps: 5, bytes: 46566,
    has_image: true, first_changed: null, remixed_from_version: 1, changes: null },
];

// Photos of real builds.
const PHOTOS = [
  { id: "PhotoAaa01", model: MODEL_ID, account: JO, words: "Built it with my own bricks, one swap in step 4.",
    width: 1200, height: 900, at: "2026-10-12T17:30:00Z" },
  { id: "PhotoBbb02", model: MODEL_ID, account: PRIYA, words: "Two evenings, and the portcullis really opens.",
    width: 1080, height: 1080, at: "2026-10-16T20:10:00Z" },
  { id: "PhotoCcc03", model: "DesignGea1", account: SAM, words: "Geared down one more step, for a slower crank.",
    width: 1200, height: 800, at: "2026-10-09T15:00:00Z" },
  { id: "PhotoDdd04", model: "PriyaSpc01", account: ROBIN, words: "The rover, with its wheels in tan.",
    width: 1200, height: 900, at: "2026-10-17T10:00:00Z" },
  { id: "PhotoEee05", model: "SamModel01", account: JO, words: "Ran it round the whole layout.",
    width: 1200, height: 675, at: "2026-10-14T19:10:00Z" },
].map((photo) => ({ hidden_at: null, removed_at: null, ...photo }));

// Comments, as model_comments keeps them.
const COMMENTS = [
  { id: 101, model: MODEL_ID, version: 1, step: 3, author: JO, at: "2026-10-02T14:12:00Z",
    body: "The arch in step 3 is lovely. I used a dark tan plate under it and it still lines up." },
  { id: 102, model: MODEL_ID, version: 2, step: null, author: ROBIN, at: "2026-10-15T19:02:00Z",
    body: "Thank you all. Version 2 adds the portcullis; step 6 is new, and step 5 moved two bricks." },
  { id: 103, model: MODEL_ID, version: 2, step: 5, author: PRIYA, at: "2026-10-17T08:40:00Z", edited_at: "2026-10-17T08:52:00Z",
    body: "Step 5 had me stuck for a minute: the hinge goes under the wall, not over. Lovely once it clicks." },
  { id: 104, model: "DesignGea1", version: 1, step: 2, author: JO, at: "2026-09-03T11:00:00Z",
    body: "Runs smoothly with the 8-tooth gear swapped for a 12. @sam-builds, your tram's bogies could use the same.",
    mentions: [SAM] },
  { id: 105, model: "SamModel01", version: 1, step: 2, author: PRIYA, at: "2026-10-16T09:30:00Z",
    body: "The pantograph is a clever trick." },
  { id: 106, model: "DesignRmx1", version: 1, step: null, author: NOBODY, at: "2026-10-18T02:00:00Z",
    body: "Cheap bricks, best prices, link in my profile" },
  { id: 107, model: MODEL_ID, version: 2, step: null, author: SPAMMER, at: "2026-10-16T03:00:00Z",
    body: "Buy bricks here", removed_at: "2026-10-16T09:00:00Z", removed_by: "admin" },
  // Replies (supabase/replies.sql): on their comment's version and step.
  { id: 108, model: MODEL_ID, version: 1, step: 3, author: ROBIN, at: "2026-10-03T08:20:00Z", parent: 101,
    body: "Dark tan under it is a good idea: I may put it in the next version." },
  { id: 109, model: MODEL_ID, version: 2, step: 5, author: ROBIN, at: "2026-10-17T09:05:00Z", parent: 103,
    body: "Thank you, Priya. I will add an arrow to step 5's page so nobody else gets stuck." },
  { id: 110, model: MODEL_ID, version: 2, step: 5, author: JO, at: "2026-10-17T12:30:00Z", parent: 103,
    body: "Same here, @priya-plays. Under, then it clicks.", mentions: [PRIYA] },
].map((comment) => ({ edited_at: null, hidden_at: null, removed_at: null, removed_by: null, parent: null, ...comment }));

// Collections, newest first, each with its models in the order they were added (newest first).
const LISTS = [
  { id: LIST_ID, owner: ROBIN, name: "Castles worth a weekend", public: true, updated_at: "2026-10-14T10:00:00Z",
    description: "Castles that take an evening or two, each tested to its last step.",
    models: [MODEL_ID, "DesignRmx1", "DesignPar1"] },
  { id: "ListSmall1", owner: ROBIN, name: "Small and quick", public: true, updated_at: "2026-10-01T10:00:00Z",
    description: null, models: ["DesignFox1", "MikaRobot1"] },
  { id: "SamListAa1", owner: SAM, name: "Castles to build", public: true, updated_at: "2026-10-17T10:00:00Z",
    description: "For the winter.", models: [MODEL_ID, "DesignBrg1", "DesignPar1"] },
  { id: "SamListBb2", owner: SAM, name: "Ideas for later", public: false, updated_at: "2026-10-10T10:00:00Z",
    description: null, models: ["PriyaSpc01", "MikaTram01"] },
];
const LIKES = [[SAM, "DesignGea1"], [SAM, "PriyaSpc01"], [JO, MODEL_ID], [PRIYA, MODEL_ID],
  // Robin shows on their profile which models they liked (CHOICES).
  [ROBIN, "PriyaSpc01"], [ROBIN, "MikaRobot1"], [ROBIN, "DesignPar1"]];
// When each was liked, newest last: the Likes tab is newest first.
const LIKED_AT = (at) => `2026-10-${String(10 + at).padStart(2, "0")}T12:00:00Z`;

// Pictures of their own as their avatars (supabase/avatars.sql): Robin and
// Priya chose one; everybody else's is made from their handle. Each a JPEG
// made here, a face-sized pattern of its own.
const AVATARS = [
  { account: ROBIN, id: "FaceRobin1", side: 200, colours: [[196, 78, 42], [242, 205, 55]] },
  { account: PRIYA, id: "FacePriya1", side: 200, colours: [[24, 96, 160], [87, 201, 126]] },
].map((one) => ({ ...one, bytes: Buffer.from(avatarPicture(one.side, one.colours)), was: "jpeg",
  at: "2026-10-20T10:00:00Z", removed_at: null, removed_why: null }));
// Who chose to show the models they liked.
const CHOICES = [{ account: ROBIN, shows_likes: true, updated_at: "2026-10-20T10:00:00Z" }];

/// A round head on a ground of two colours: what a person's picture of
/// themselves looks like at 24 px, enough to tell from the tile.
function avatarPicture(side, [ground, face]) {
  const data = new Uint8Array(side * side * 4);
  for (let y = 0; y < side; y++) {
    for (let x = 0; x < side; x++) {
      const at = (y * side + x) * 4;
      const head = Math.hypot(x - side / 2, y - side * 0.42) < side * 0.2;
      const shoulders = y > side * 0.68 && Math.hypot(x - side / 2, y - side * 1.05) < side * 0.42;
      const shade = 0.75 + 0.25 * (y / side);
      const [r, g, b] = head || shoulders ? face : ground.map((c) => Math.round(c * shade));
      data.set([r, g, b, 255], at);
    }
  }
  return encodeJpeg({ data, width: side, height: side }, 90).data;
}
/// A picture somebody might choose for their avatar: wider than it is tall,
/// a person a little off its middle, for the circle to be placed on.
export const PORTRAIT = (() => {
  const [w, h] = [720, 540];
  const data = new Uint8Array(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const head = Math.hypot(x - w * 0.58, y - h * 0.4) < h * 0.17;
      const body = y > h * 0.62 && Math.hypot(x - w * 0.58, y - h * 1.08) < h * 0.4;
      const sky = [70 + (x / w) * 60, 120 + (y / h) * 60, 190];
      data.set([...(head ? [233, 190, 160] : body ? [40, 60, 90] : sky.map(Math.round)), 255], (y * w + x) * 4);
    }
  }
  return Buffer.from(encodeJpeg({ data, width: w, height: h }, 90).data);
})();

/// handle -> avatar id, of those shown in public.
const facesNow = () => new Map(AVATARS.filter((one) => !one.removed_at && !ADMIN.barred.some((b) => b.account === one.account))
  .map((one) => [personOf(one.account)?.handle, one.id]).filter(([handle]) => handle));
const FAVOURITES = [[SAM, MODEL_ID], [SAM, "DesignGea1"], [SAM, "PriyaSpc01"]];

// What Sam's collection holds of each model, part for part ("Build with what
// I own"), and the collection itself.
const OWNED = { [MODEL_ID]: 301, DesignGea1: 70, DesignFox1: 64, DesignBrg1: 120, DesignPar1: 0, MikaRobot1: 120,
  MikaTram01: 330, DesignRmx1: 290, PriyaSpc01: 410, SamModel01: 340 };
const POOL = { lots: 214, pieces: 3120, unknown: 1 };
// What the stand-in's account owns (api/collection.js GET), which POOL counts.
const OWNED_SETS = { sets: [{ set: "10305-1", qty: 1, spares: 0 }, { set: "42115-1", qty: 1, spares: 0 }, { set: "60337-1", qty: 2, spares: 0 }],
  parts: [{ part: "3001", colour: 4, qty: 24 }], updated_at: "2026-10-17T09:30:00Z" };
// Its Claude connections (api/oauth.js ?op=connections).
const CONNECTIONS = [{ id: "5f0c7a52-8d0e-4f53-9b7e-2d1f3c4b5a69", client: "Claude", since: "2026-10-12T18:04:00Z",
  last_used: "2026-10-19T21:40:00Z" }];

// This week's pick, worked out (not chosen) from the past seven days.
const PICK = { model: MODEL_ID, week: { builds: 9, remixes: 1, tested: true, score: 34 } };
// Today's featured model on the gallery's front (gallery362).
const FEATURED = "DesignPar1";
const WEEK = [
  { model: MODEL_ID, week: { builds: 9, remixes: 1, tested: true, score: 34 } },
  { model: "PriyaSpc01", week: { builds: 5, remixes: 0, tested: true, score: 20 } },
  { model: "DesignPar1", week: { builds: 4, remixes: 0, tested: true, score: 17 } },
  { model: "SamModel01", week: { builds: 2, remixes: 1, tested: true, score: 13 } },
  { model: "MikaRobot1", week: { builds: 3, remixes: 0, tested: false, score: 9 } },
];

// The past 30 days, as Top over this month weighs them: the week's, and
// what was built or remixed earlier in the month.
const MONTH = [
  ...WEEK,
  { model: "DesignGea1", week: { builds: 6, remixes: 0, tested: true, score: 23 } },
  { model: "DesignRmx1", week: { builds: 2, remixes: 0, tested: false, score: 6 } },
];

// A crowd of plain models behind the fixtures' (crowd(N), for
// gallery_flow.mjs): enough for the gallery to page and page again. None
// unless asked, so every other check draws the pages it always did.
let CROWD = [];
const CROWD_OWNERS = [ROBIN, MIKA, JO, PRIYA];
const CROWD_KINDS = ["castle", "space", "vehicle", "town", "robot", "nature"];
export function crowd(n) {
  CROWD = Array.from({ length: n }, (_, at) => model({ id: `Crowd${String(at + 1).padStart(5, "0")}`,
    owner: CROWD_OWNERS[at % CROWD_OWNERS.length], name: `Crowd model ${at + 1}`,
    author: personOf(CROWD_OWNERS[at % CROWD_OWNERS.length]).name, parts: 40 + at * 7, steps: 4,
    kind: CROWD_KINDS[at % CROWD_KINDS.length], tags: at % 5 === 0 ? ["ai-designed"] : [],
    listed_at: new Date(Date.parse("2026-06-01T12:00:00Z") - at * 3600 * 1000).toISOString(),
    updated_at: "2026-06-01T12:00:00Z" }));
}

// Whether supabase/gallery_tabs.sql is applied (applied(false): as before
// it is): gallery_models answers, and the list offers Top's windows, Made
// and Following.
let APPLIED = true;
export function applied(yes) {
  APPLIED = Boolean(yes);
}

// The gallery as brickworks.diy had it on 2026-10-22, with the house's
// profile as supabase/house.sql writes it, held here and nowhere else
// (liveCommunity(true), for first_steps_flow.mjs): the studio's seven
// models, credited Brickworks and described as live, and nobody else's;
// no likes, builds or photos yet. None unless asked.
let LIVE = false;
const LIVE_MODELS = [
  ["o3dLMc5A3Z", "A sports car, and its driver", "vehicle", ["car", "racing", "minifigure"], 187, 5, "2026-10-13T13:37:34Z",
    "A red sports car with white racing stripes and a black rear wing, and beside it its driver with a trophy and a nameplate. Designed by Claude."],
  ["cGHqpHnEFZ", "A small modular corner shop", "town", ["modular", "shop", "street", "minifigures"], 774, 57, "2026-10-13T13:37:37Z",
    "A corner building with a shop under a striped awning, a flat above and a cornice round the roof. Designed by Claude."],
  ["B6FhDpMowd", "A three-core heavy-lift rocket", "space", ["rocket", "launch pad", "minifigure"], 350, 9, "2026-10-13T13:37:39Z",
    "A heavy-lift rocket of three cores side by side on its launch mount, with the strongback tower beside it. Designed by Claude."],
  ["uoRqCfPWYJ", "A barn owl", "nature", ["owl", "bird", "sculpture"], 1037, 3, "2026-10-13T13:37:41Z",
    "A barn owl perched on a post, its white face and tan wings shaped in layers of bricks and slopes. Designed by Claude."],
  ["kfpYMjke5U", "A castle, from one sentence", "castle", ["castle", "medieval", "moat"], 2438, 72, "2026-10-13T13:37:44Z",
    "A stone castle with four corner towers, a gatehouse and a paved courtyard, ringed by a moat. Claude designed it from a single sentence."],
  ["EzEXhtXE2C", "Wizard's Tower", "castle", ["tower", "wizard", "minifigures", "display"], 9541, 1324, "2026-10-13T13:37:46Z",
    "A black tower of four clustered piers, banded in grey and crowned with curved horns, with furnished rooms inside. Claude designed it from one paragraph."],
  ["8eb6GRvnSV", "Orrery of the Sun and eight planets", "mechanism", ["orrery", "gears", "planets", "crank"], 494, 27, "2026-10-14T06:27:39Z",
    "A working orrery: one crank turns all eight planets round the Sun, each through a gear train of its own. A Claude session built it in Brickworks."],
].map(([id, name, kind, tags, parts, steps, at, description]) => model({ id, owner: HOUSE, name, author: "Brickworks", parts, steps,
  // house.sql's step 2: ai-designed on the end of each one's tags.
  kind, tags: [...tags, "ai-designed"], listed_at: at, updated_at: at, description }));
const LIVE_IDS = new Set(LIVE_MODELS.map((one) => one.id));
// What supabase/house.sql gives the house: its words, the castle across
// the top, three pinned; and each of the seven tagged ai-designed.
const HOUSE_SAYS = { bio: "The Brickworks studio's own account. Every model here was designed with the assistant, "
  + "Claude working in the app, and each one's description says how. Open one to build it step by step, or remix it as your own.",
banner: "kfpYMjke5U", pins: ["EzEXhtXE2C", "8eb6GRvnSV", "cGHqpHnEFZ"] };
export function liveCommunity(yes) {
  LIVE = Boolean(yes);
  const house = personOf(HOUSE);
  house.bio = LIVE ? HOUSE_SAYS.bio : null;
  for (let at = MODELS.length - 1; at >= 0; at -= 1) if (LIVE_IDS.has(MODELS[at].id)) MODELS.splice(at, 1);
  for (let at = SHOWS.length - 1; at >= 0; at -= 1) if (SHOWS[at].account === HOUSE) SHOWS.splice(at, 1);
  if (LIVE) {
    MODELS.push(...LIVE_MODELS);
    SHOWS.push({ account: HOUSE, links: [], banner: HOUSE_SAYS.banner, pins: HOUSE_SAYS.pins, updated_at: "2026-10-22T10:00:00Z" });
  }
}

// Sam's feed, as feed_of keeps its rows, newest first, and when it was last opened.
const FEED = [
  { kind: "comment", at: "2026-10-16T09:30:00Z", by: PRIYA, model: "SamModel01", name: "Harbour Tram", step: 2,
    comment: 105, said: "The pantograph is a clever trick." },
  { kind: "photo", at: "2026-10-16T20:10:00Z", by: PRIYA, model: MODEL_ID, name: "Riverside Watchtower", photo: "PhotoBbb02",
    words: "Two evenings, and the portcullis really opens.", yours: false },
  { kind: "model", at: "2026-10-16T07:00:00Z", by: PRIYA, model: "PriyaSpc01", name: "Lunar Rover" },
  { kind: "challenge", at: "2026-10-15T08:00:00Z", by: PRIYA, model: "PriyaSpc01", name: "Lunar Rover",
    title: "Off-world October", way: "assistant" },
  { kind: "photo", at: "2026-10-14T19:10:00Z", by: JO, model: "SamModel01", name: "Harbour Tram", photo: "PhotoEee05",
    words: "Ran it round the whole layout.", yours: true },
  // Put in a collection Sam follows (supabase/collection_follows.sql list_rows).
  { kind: "collection", at: "2026-10-14T10:00:00Z", by: ROBIN, model: "DesignPar1", name: "Gatehouse Starter",
    collection: LIST_ID, list_name: "Castles worth a weekend" },
  { kind: "remix", at: "2026-10-13T12:00:00Z", by: MIKA, model: "MikaTram01", name: "Night Tram", of_name: "Harbour Tram" },
  { kind: "version", at: "2026-10-05T16:00:00Z", by: MIKA, model: "DesignPar1", name: "Gatehouse Starter", version: 1,
    note: "Stronger hinges on the gate." },
  { kind: "model", at: "2026-10-01T17:00:00Z", by: MIKA, model: "MikaRobot1", name: "Pocket Mech" },
];
const FEED_SEEN = "2026-10-14T00:00:00Z";

// Sam's notifications (supabase/notifications.sql notification_list): what
// happened to the tram and the bakery, newest first; the tram's group
// opened since its photo, so only its newer rows are unread. And a level
// reached (supabase/achievements.sql), its group not opened yet; and the
// challenges (supabase/challenge_notices.sql): who won September's, which
// Sam voted in, read, and October's opening, not opened yet.
const NOTICES = [
  { kind: "achievement", at: "2026-10-16T12:00:00Z", on: null, track: "designer", level: 2, of: 6, reached: 3, next: 10,
    read: false },
  { kind: "likes", at: "2026-10-16T11:40:00Z", on: "SamModel01", model: "SamModel01", name: "Harbour Tram", likes: 12,
    day: "2026-10-16" },
  { kind: "comment", at: "2026-10-16T09:30:00Z", on: "SamModel01", by: PRIYA, model: "SamModel01", name: "Harbour Tram",
    step: 2, comment: 105, said: "The pantograph is a clever trick." },
  { kind: "mention", at: "2026-10-15T08:00:00Z", on: "DesignGea1", by: JO, model: "DesignGea1", name: "Two-Speed Gearbox",
    step: 2, parent: null, comment: 104,
    said: "Runs smoothly with the 8-tooth gear swapped for a 12. @sam-builds, your tram's bogies could use the same." },
  { kind: "photo", at: "2026-10-14T19:10:00Z", on: "SamModel01", by: JO, model: "SamModel01", name: "Harbour Tram",
    photo: "PhotoEee05", words: "Ran it round the whole layout.", yours: true },
  { kind: "remix", at: "2026-10-13T12:00:00Z", on: "SamModel01", by: MIKA, model: "MikaTram01", name: "Night Tram",
    of: "SamModel01", of_name: "Harbour Tram" },
  { kind: "result", at: "2026-10-02T09:00:00Z", on: "SamModel02", model: "SamModel02", name: "Corner Bakery", challenge: 3,
    title: "Main Street September", way: "hand", won: true, votes: 9 },
  { kind: "likes", at: "2026-10-01T20:15:00Z", on: "SamModel02", model: "SamModel02", name: "Corner Bakery", likes: 1,
    day: "2026-10-01" },
  { kind: "challenge_won", at: "2026-10-01T09:00:00Z", on: null, challenge: 2, title: "Castle September", ends_on: "2026-09-30",
    test: false, picked: false, read: true },
  { kind: "challenge_open", at: "2026-10-01T00:00:00Z", on: null, challenge: 3, title: "Off-world October", ends_on: "2026-10-31",
    test: false, read: false },
];

// This month's challenge (supabase/challenges.sql), open, two entries in
// each group. Sam voted for the rover with the assistant, so /challenge
// shows Vote for it, Your vote and You voted in this group; Sam's tram is
// not in it, so its page offers Sam the entry and its dialog.
const CHALLENGE = { id: 3, title: "Off-world October", brief: "Build something that goes where there are no roads, in under 1,500 parts.",
  starts_on: "2026-10-01", ends_on: "2026-10-31", state: "open", test: false, settled: false,
  rules: { most_parts: 1500, set: null, tested: true },
  entries: [[MODEL_ID, "hand"], ["MikaRobot1", "hand"], ["PriyaSpc01", "assistant"], ["DesignGea1", "assistant"]],
  you: { voted: { hand: null, assistant: "PriyaSpc01" }, entries: [] } };
// Between months (supabase/challenge_year.sql): what ran before, September's
// won by Robin's watchtower by hand, August's that nobody entered, and
// November's theme, told a month ahead from the owner's year of themes.
const PAST = [
  { id: 2, title: "Castle September", starts_on: "2026-09-01", ends_on: "2026-09-30", entries: 5,
    winners: [[MODEL_ID, "hand", 7]], rules: { most_parts: null, set_number: "6080-1", set_name: "King's Castle", tested: false },
    brief: "Build a castle from the parts of one set: King's Castle, 6080." },
  { id: 1, title: "Small and quick", starts_on: "2026-08-01", ends_on: "2026-08-31", entries: 0, winners: [],
    rules: { most_parts: 200, set_number: null, set_name: null, tested: false }, brief: "Anything at all, in 200 parts or fewer." },
];
const NEXT = { id: 4, title: "Winter village", brief: "A street of houses under snow: a bakery, a station, lights in the windows.",
  starts_on: "2026-11-01", ends_on: "2026-11-30", announced_at: "2026-10-01T00:00:00Z" };
const CHALLENGES_LISTED = [
  { id: NEXT.id, title: NEXT.title, test: false, starts_on: NEXT.starts_on, ends_on: NEXT.ends_on, announced_at: NEXT.announced_at,
    state: "upcoming", settled: false, rules: { most_parts: null, set_number: null, set_name: null, tested: false },
    entries: { hand: 0, assistant: 0 }, votes: { hand: 0, assistant: 0 }, winners: [] },
  { id: 5, title: "Ships and harbours", test: false, starts_on: "2026-12-01", ends_on: "2026-12-31",
    announced_at: "2026-10-31T00:00:00Z", state: "upcoming", settled: false,
    rules: { most_parts: null, set_number: null, set_name: null, tested: false },
    entries: { hand: 0, assistant: 0 }, votes: { hand: 0, assistant: 0 }, winners: [] },
  { id: 3, title: CHALLENGE.title, test: false, starts_on: CHALLENGE.starts_on, ends_on: CHALLENGE.ends_on, state: "open",
    settled: false, rules: { most_parts: 1500, set_number: null, set_name: null, tested: true },
    entries: { hand: 2, assistant: 2 }, votes: { hand: 5, assistant: 3 }, winners: [] },
  { id: 2, title: "Castle September", test: false, starts_on: "2026-09-01", ends_on: "2026-09-30", state: "ended",
    settled: true, rules: { most_parts: null, set_number: "6080-1", set_name: "King's Castle", tested: false },
    entries: { hand: 4, assistant: 1 }, votes: { hand: 11, assistant: 2 },
    winners: [{ way: "hand", model: MODEL_ID, name: "Riverside Watchtower", votes: 7 }] },
];

// How Sam's own models did in the last 30 days, for their eyes only
// (designer_mine). What is in all is read from the rest of the world.
const DESIGNS = { days: 30, since: "2026-09-20", counted_from: "2026-10-19",
  recent: { SamModel01: { opens: 128, builds: 4, remixes: 1, comments: 1 }, SamModel02: { opens: 6, builds: 0, remixes: 0, comments: 0 } } };

// The site's owner's page: what only /admin shows.
const ADMIN = {
  accounts: 128, signed_in_this_week: 41, connectors: 17,
  connectors_of: { [ROBIN]: [2, "2026-10-18T20:44:00Z"], [SAM]: [1, "2026-10-19T08:15:00Z"] },
  reports: [
    { id: 41, model: "DesignBrg1", reason: "copied", at: "2026-10-18T21:14:00Z", contact: "set-owner@example.com",
      note: "This looks like the bridge from a set I own; the steps are copied page for page." },
    { id: 42, model: "DesignRmx1", comment: 106, reason: "spam", at: "2026-10-18T06:30:00Z", note: null, contact: null },
    { id: 43, model: MODEL_ID, photo: "PhotoBbb02", reason: "personal", at: "2026-10-17T12:00:00Z",
      note: "There is a name on a box in the background.", contact: null },
    { id: 44, handle: "mika-mocs", reason: "trademark", at: "2026-10-16T09:00:00Z", note: "The bio names a company's mark.", contact: null },
    { id: 45, collection: "ListSmall1", reason: "spam", at: "2026-10-15T09:00:00Z", note: null, contact: null },
  ],
  barred: [{ account: SPAMMER, at: "2026-10-02T10:00:00Z", reason: "Spam listings, three times" }],
  choices: [{ pick: 7, model: "SamModel02", chosen_at: "2026-10-18T10:00:00Z", until: "2026-10-25T10:00:00Z", test: false }],
};

// ---------------------------------------------------------------------------
// Reading the world, as the database's functions read it.

// supabase/achievements.sql's ladders, in its order.
const LADDERS = [["designer", [1, 3, 10, 25, 50, 100]], ["built", [1, 10, 50, 100, 500, 1000]],
  ["builder", [1, 5, 10, 25, 50]], ["remixed", [1, 5, 25, 100]], ["tested", [1, 5, 10, 25]], ["challenger", [1, 3, 6, 12]]];

const ID = /^[A-Za-z0-9]{10}$/;
const personOf = (account) => PEOPLE.find((one) => one.account === account) || null;
/// Whom [text], written by [writer], names among the stand-in's people, as
/// comment_mention keeps them: profiles, not its writer, at most three.
const namedIn = (text, writer) => mentionsIn(text).map((handle) => PEOPLE.find((one) => one.handle === handle))
  .filter((one) => one && one.account !== writer).slice(0, 3).map((one) => one.account);
const personNamed = (handle) => PEOPLE.find((one) => one.handle === String(handle || "").toLowerCase()) || null;
const modelOf = (id) => MODELS.find((one) => one.id === id) || CROWD.find((one) => one.id === id) || null;
const shownModel = (id) => {
  const found = modelOf(id);
  return found && found.published && !found.barred ? found : null;
};
const emailOf = (account) => [...PEOPLE, ...NO_PROFILE].find((one) => one.account === account)?.email || null;
const named = (account) => {
  const one = personOf(account);
  return one ? { handle: one.handle, name: one.name } : null;
};
const remixesOf = (id) => MODELS.filter((one) => one.remixed_from === id && one.published);
const statsOf = (id) => STATS[id] || [0, 0, 0];
const newestOf = (id) => Math.max(1, ...VERSIONS.filter((one) => one.model === id).map((one) => one.n));
const scoreOf = (m) => statsOf(m.id)[2] * 3 + remixesOf(m.id).length * 2 + (TESTED.has(m.id) ? 5 : 0);
const likedBy = (account, id) => LIKES.some(([who, what]) => who === account && what === id);
/// The models [account] liked that the gallery shows, newest like first.
const likedOf = (account, tests = false) => LIKES.map(([who, id], at) => ({ who, m: modelOf(id), at: LIKED_AT(at) }))
  .filter(({ who, m }) => who === account && m && m.published && m.listed && !m.barred && (tests || !m.test))
  .sort(byTime("at")).map(({ m }) => m);
const keptBy = (account, id) => FAVOURITES.some(([who, what]) => who === account && what === id);
const listOf = (id) => LISTS.find((one) => one.id === id) || null;
const byTime = (key) => (a, b) => String(b[key]).localeCompare(String(a[key]));

/// directory_card: a model as every list gives it.
function card(m) {
  const [views, likes, builds] = statsOf(m.id);
  const owner = personOf(m.owner);
  return { id: m.id, name: m.name, author: m.author, parts: m.parts, has_image: m.has_image, has_thumb: m.has_thumb,
    listed_at: m.listed_at, updated_at: m.updated_at, kind: m.kind, tags: m.tags, licence: m.licence,
    steps: m.steps, own_steps: m.own_steps, technic: m.technic, views, likes, builds,
    remixes: remixesOf(m.id).length, by: m.author !== null && owner ? { handle: owner.handle, name: owner.name } : null,
    tested: TESTED.has(m.id), ...(APPLIED ? { comments: commentsOn(m.id) } : {}),
    ...(m.made_with !== undefined ? { made_with: m.made_with } : {}) };
}

/// How many comments a visitor may read on [id]'s page (gallery_tabs.sql
/// directory_card): not removed, not hidden, by nobody taken out.
const commentsOn = (id) => COMMENTS.filter((one) => one.model === id && !one.removed_at && !one.hidden_at
  && !ADMIN.barred.some((barred) => barred.account === one.author)).length;

/// How a model was made: as its app said (made_with.sql), else as its tags
/// say (web/card.js madeOf).
const madeOf = (m) => (m.made_with ? (m.made_with === "hand" ? "hand" : "assistant")
  : (m.tags || []).some((tag) => tag === "ai-designed" || tag === "brickify") ? "assistant" : "hand");

/// directory_model: a model's page, with the line it came from and its listed remixes.
function modelPage(id) {
  const m = modelOf(id);
  if (!m || !m.published) return null;
  const from = [];
  for (let up = modelOf(m.remixed_from); up && up.published && from.length < 8; up = modelOf(up.remixed_from)) {
    from.push(up.listed && !up.barred ? { id: up.id, name: up.name, author: up.author } : { id: null, by_link: true });
  }
  const remixes = remixesOf(id).filter((one) => one.listed && !one.barred).sort(byTime("listed_at"));
  return { ...card(m), description: m.description, listed: m.listed, from, remixes_listed: remixes.map(card) };
}

/// What a search's words find: each word the start of one of the model's.
function wordsMatch(m, words) {
  const own = `${m.name} ${m.author || ""} ${(m.tags || []).join(" ")} ${m.description || ""}`.toLowerCase()
    .split(/[^\p{L}\p{N}]+/u);
  return words.every((word) => own.some((one) => one.startsWith(word)));
}

/// directory_models: a page of cards, as the query asks (api/_directory.js listQuery).
function listModels(query = {}) {
  const hidden = query.private === true;
  let rows;
  if (query.collection) rows = (listOf(query.collection)?.models || []).map(modelOf);
  else if (query.favourites) rows = FAVOURITES.filter(([who]) => who === query.favourites).map(([, id]) => modelOf(id));
  else rows = [...MODELS, ...CROWD].filter((one) => !query.owner || (one.owner === query.owner && one.author !== null));
  rows = rows.filter((one) => one && one.published && !one.barred && (one.listed || hidden) && (!one.test || query.tests)
    && (!LIVE || LIVE_IDS.has(one.id)));
  const words = String(query.words || "").split("&").map((one) => one.trim().replace(/:\*$/, "")).filter(Boolean);
  if (words.length) rows = rows.filter((one) => wordsMatch(one, words));
  if (query.kind) rows = rows.filter((one) => one.kind === query.kind);
  if (query.least) rows = rows.filter((one) => one.parts >= query.least);
  if (query.most) rows = rows.filter((one) => one.parts <= query.most);
  if (query.own_steps) rows = rows.filter((one) => one.own_steps);
  if (query.technic) rows = rows.filter((one) => one.technic);
  if (query.tested) rows = rows.filter((one) => TESTED.has(one.id));
  if (query.tag) rows = rows.filter((one) => (one.tags || []).includes(query.tag));
  const owned = (one) => ({ pieces: one.parts, have: Math.min(OWNED[one.id] || 0, one.parts) });
  if (query.buildable) rows = rows.filter((one) => owned(one).have >= one.parts);
  if (query.made) rows = rows.filter((one) => madeOf(one) === query.made);
  if (query.following) {
    const followed = new Set(FOLLOWS.filter((one) => one.follower === query.following).map((one) => one.followed));
    rows = rows.filter((one) => followed.has(one.owner) && one.author !== null);
  }
  const sort = query.sort || "newest";
  // Top over a time: what the week's or the month's builds and remixes
  // say, the rest left out (gallery_tabs.sql gallery_models).
  if (query.days && sort === "top") {
    const span = new Map((query.days <= 7 ? WEEK : MONTH).map((one) => [one.model, one.week.score]));
    rows = rows.filter((one) => span.has(one.id)).sort((a, b) => span.get(b.id) - span.get(a.id));
    const skip = Number(query.skip) || 0;
    return rows.slice(skip, skip + (Number(query.size) || 25)).map((one) => ({ ...card(one), ...(query.pool ? { owned: owned(one) } : {}) }));
  }
  const counted = { views: 0, likes: 1, builds: 2 };
  if (sort === "newest") rows.sort(byTime("listed_at"));
  else if (sort in counted) rows.sort((a, b) => statsOf(b.id)[counted[sort]] - statsOf(a.id)[counted[sort]]);
  else if (sort === "remixes") rows.sort((a, b) => remixesOf(b.id).length - remixesOf(a.id).length);
  else if (sort === "top") rows.sort((a, b) => scoreOf(b) - scoreOf(a) || String(b.listed_at).localeCompare(String(a.listed_at)));
  else if (sort === "owned") rows.sort((a, b) => owned(b).have / b.parts - owned(a).have / a.parts);
  const skip = Number(query.skip) || 0;
  const size = Number(query.size) || 25;
  return rows.slice(skip, skip + size).map((one) => ({ ...card(one), ...(query.pool ? { owned: owned(one) } : {}) }));
}

function collectionCount(id, hidden) {
  return (listOf(id)?.models || []).map(modelOf)
    .filter((one) => one && one.published && !one.barred && (one.listed || hidden) && !one.test).length;
}

/// collection_page: a list, and who made it.
function collectionPage(id) {
  const list = listOf(id);
  if (!list) return null;
  return { id: list.id, name: list.name, description: list.description, public: list.public, owner: list.owner,
    updated_at: list.updated_at, by: named(list.owner), count: collectionCount(id, false), all: collectionCount(id, true) };
}

/// profile_page: a profile's counts and its public lists.
function profilePage(handle, tests = false) {
  const person = personNamed(handle);
  if (!person) return null;
  const theirs = listModels({ owner: person.account, size: 1000, tests });
  return { handle: person.handle, name: person.name, bio: person.bio, since: person.created_at,
    models: theirs.length, likes: theirs.reduce((sum, one) => sum + one.likes, 0),
    collections: LISTS.filter((list) => list.owner === person.account && list.public).sort(byTime("updated_at"))
      .map((list) => ({ id: list.id, name: list.name, description: list.description, count: collectionCount(list.id, false) })) };
}

/// The photos that may be shown, newest first.
const photosWhere = (test) => PHOTOS.filter((one) => !one.removed_at && !one.hidden_at && !LIVE && test(one)).sort(byTime("at"));

/// achievement_levels: [account]'s number and level on each track, as
/// designer_page counts them; challenges entered are this month's and
/// those whose winner is theirs. [] for nobody and one taken out.
function achievementLevels(account, tests = false) {
  const person = personOf(account);
  if (!person || ADMIN.barred.some((one) => one.account === account)) return [];
  const earned = designerPage(person.handle, tests);
  const entered = new Set([...CHALLENGE.entries.filter(([model]) => modelOf(model)?.owner === account).map(() => CHALLENGE.id),
    ...PAST.filter((one) => one.winners.some(([model]) => modelOf(model)?.owner === account)).map((one) => one.id)]);
  const numbers = { designer: earned.models, built: earned.builds, remixed: earned.remixes, tested: earned.tested,
    builder: photosWhere((one) => one.account === account && shownModel(one.model)?.listed).length, challenger: entered.size };
  return LADDERS.map(([track, steps]) => {
    const n = numbers[track];
    const level = steps.filter((step) => step <= n).length;
    return { track, n, level, of: steps.length, reached: level ? steps[level - 1] : null, next: steps[level] ?? null };
  });
}

/// designer_page: what a designer's models earned, for anybody.
function designerPage(handle, tests = false) {
  const person = personNamed(handle);
  if (!person) return null;
  const theirs = listModels({ owner: person.account, size: 1000, tests });
  const ids = new Set(theirs.map((one) => one.id));
  const comments = COMMENTS.filter((one) => ids.has(one.model) && !one.removed_at && !one.hidden_at && one.author !== person.account);
  const photos = photosWhere((one) => ids.has(one.model) && one.account !== person.account);
  const cards = {};
  for (const one of comments) cards[one.model] = { comments: (cards[one.model]?.comments || 0) + 1 };
  return { models: theirs.length, builds: theirs.reduce((sum, one) => sum + one.builds, 0),
    remixes: theirs.reduce((sum, one) => sum + one.remixes, 0), comments: comments.length,
    tested: theirs.filter((one) => one.tested).length, likes: theirs.reduce((sum, one) => sum + one.likes, 0),
    builders: new Set(photos.map((one) => one.account)).size, cards,
    photos: photos.slice(0, 12).map((one) => ({ id: one.id, model: one.model, model_name: modelOf(one.model).name,
      words: one.words, width: one.width, height: one.height, at: one.at, by: named(one.account) })) };
}

/// follow_state: a profile's follows, as [asker] sees them. [askAge]: the
/// asker has not answered the age question yet.
function followState(asker, handle, askAge = false) {
  const person = personNamed(handle);
  if (!person) return null;
  const mine = asker === person.account;
  const trouble = !asker ? "sign_in" : mine ? "yourself" : askAge ? "ask_first" : null;
  return { handle: person.handle, followers: FOLLOWS.filter((one) => one.followed === person.account).length,
    following: FOLLOWS.filter((one) => one.follower === person.account).length, shows: SHOWS_FOLLOWS.has(person.account),
    you_follow: Boolean(asker) && FOLLOWS.some((one) => one.follower === asker && one.followed === person.account),
    mine, trouble };
}

/// list_follow_state: a public collection's follows, as [asker] sees them.
function listFollowState(asker, id, askAge = false) {
  const list = listOf(id);
  if (!list || !list.public) return null;
  const mine = asker === list.owner;
  const trouble = !asker ? "sign_in" : mine ? "yourself" : askAge ? "ask_first" : null;
  return { id: list.id, followers: LIST_FOLLOWS.filter((one) => one.collection === id).length,
    you_follow: Boolean(asker) && LIST_FOLLOWS.some((one) => one.follower === asker && one.collection === id), mine, trouble };
}

/// collection_directory (supabase/collection_directory.sql): a page of the
/// public collections with a model in the gallery, the one updated last
/// first (its models' times are not kept here), or the most followed.
function collectionDirectory({ sort = "recent", page = 1, size = 24 } = {}) {
  const shown = LISTS.filter((list) => list.public && collectionCount(list.id, false) > 0)
    .map((list) => ({ id: list.id, name: list.name, description: list.description, count: collectionCount(list.id, false),
      followers: LIST_FOLLOWS.filter((one) => one.collection === list.id).length, added: list.updated_at, by: named(list.owner) }))
    .sort((a, b) => (sort === "followed" ? b.followers - a.followers : 0) || String(b.added).localeCompare(String(a.added)));
  const size_ = Math.min(Math.max(Number(size) || 24, 1), 48);
  const page_ = Math.max(Number(page) || 1, 1);
  return { sort: sort === "followed" ? "followed" : "recent", page: page_, size: size_, total: shown.length,
    rows: shown.slice((page_ - 1) * size_, page_ * size_) };
}

/// model_lists: the public collections a model in the gallery is in, the
/// one it was put in last first (the newest-updated list, here).
function modelLists(id, most = 12) {
  const m = shownModel(id);
  const lists = m && m.listed ? LISTS.filter((list) => list.public && list.models.includes(id)).sort(byTime("updated_at")) : [];
  return { count: lists.length, lists: lists.slice(0, most).map((list) => ({ id: list.id, name: list.name,
    count: collectionCount(list.id, false), by: named(list.owner) })) };
}

/// follow_list: whom a profile follows, when it chose to show it.
function followList(handle) {
  const person = personNamed(handle);
  if (!person) return null;
  const shows = SHOWS_FOLLOWS.has(person.account);
  return { shows, people: shows ? FOLLOWS.filter((one) => one.follower === person.account).sort(byTime("at"))
    .map((one) => named(one.followed)).filter(Boolean) : [] };
}

/// share_tests: the mark each tested model's newest version passed.
function testRows() {
  return [...TESTED].map((id) => {
    const m = modelOf(id);
    const newest = newestOf(id);
    const version = VERSIONS.find((one) => one.model === id && one.n === newest);
    return { model: id, n: newest, at: version?.at || m.updated_at, app: "0.9.4", parts: version?.parts || m.parts,
      steps: version?.steps || m.steps, passed: true, cleared_at: null, cleared_why: null,
      tests: { stands: { ok: true, why: "every step stands on the ground plate" },
        steps: { ok: true, why: "each step can be reached from the one before" },
        parts: { ok: true, why: "every part is made in the colour it is placed in" },
        whole: { ok: true, why: "every part touches the model" } } };
  });
}

// ---------------------------------------------------------------------------
// The database, as PostgREST answers the handlers (server side).

const TABLES = {
  shared_models: () => MODELS,
  people: () => PEOPLE.map(({ email, last_sign_in, ...row }) => row),
  share_versions: () => VERSIONS,
  share_tests: testRows,
  build_photos: () => PHOTOS,
  model_stats: () => Object.entries(STATS).map(([id, [views, likes, builds]]) => ({ model: id, views, likes, builds })),
  model_collections: () => LISTS.map(({ models, ...row }) => row),
  model_collection_items: () => LISTS.flatMap((list) => list.models.map((id) => ({ collection: list.id, model: id }))),
  model_likes: () => LIKES.map(([account, id]) => ({ account, model: id })),
  model_favourites: () => FAVOURITES.map(([account, id]) => ({ account, model: id })),
  model_comments: () => COMMENTS,
  follows: () => FOLLOWS,
  barred_models: () => [],
  barred_accounts: () => ADMIN.barred,
  profile_shows: () => SHOWS,
  profile_avatars: () => AVATARS.map(({ bytes: file, colours, ...row }) => ({ ...row, bytes: file.length })),
  profile_choices: () => CHOICES,
};

// What the watchtower is based on (supabase/model_bases.sql): a set built
// from, and work elsewhere changed, under its remix line. A list its
// designer saves here is kept until the stand-in stops, as the table
// keeps it, so the page the server makes says it after.
const BASES = [
  { model: MODEL_ID, n: 1, how: "alternate", set_number: "6080-1", url: null, title: null, author: null, licence: null },
  { model: MODEL_ID, n: 2, how: "changed", set_number: null, url: "https://example.org/river-tower",
    title: "A river tower, with its water gate", author: "Mira Holm", licence: "CC BY 4.0" },
];

// The functions the handlers call (rpc/<name>), each with what it was sent.
const RPC = {
  // supabase/model_bases.sql
  model_bases_of: ({ model_ids }) => BASES.filter((row) => (model_ids || []).includes(row.model)),
  set_based: ({ set_number }) => [...new Set(BASES.filter((row) => String(row.set_number).toLowerCase()
    === String(set_number).toLowerCase()).map((row) => row.model))].map((id) => ({ ...card(modelOf(id)),
    based: BASES.find((row) => row.model === id).how })),
  directory_model: ({ model_id }) => modelPage(model_id),
  directory_models: ({ query }) => listModels(query || {}),
  gallery_models: ({ query }) => listModels(query || {}),
  profile_page: ({ wanted, tests }) => profilePage(wanted, tests === true),
  collection_page: ({ list }) => collectionPage(list),
  collection_count: ({ list, private: hidden }) => collectionCount(list, hidden === true),
  designer_page: ({ wanted, tests }) => designerPage(wanted, tests === true),
  // supabase/achievements.sql: nothing new is reached here, so none is told.
  achievement_levels: ({ account, tests }) => achievementLevels(account, tests === true),
  achievement_mark: () => 0,
  achievement_read: () => ({ read: 0 }),
  // supabase/challenge_notices.sql
  challenge_read: () => ({ read: true }),
  follow_state: ({ asker, wanted }) => followState(asker || null, wanted),
  follow_list: ({ wanted }) => followList(wanted),
  // supabase/collection_follows.sql
  list_follow_state: ({ asker, list }) => listFollowState(asker || null, list),
  // supabase/collection_directory.sql
  collection_directory: (query) => collectionDirectory(query || {}),
  model_lists: ({ model, most }) => modelLists(model, most || 12),
  follow_choice: ({ account }) => ({ shows_follows: SHOWS_FOLLOWS.has(account) }),
  shown_publicly: ({ account }) => !ADMIN.barred.some((one) => one.account === account),
  is_barred: ({ account }) => ADMIN.barred.some((one) => one.account === account),
  model_tested: ({ model_id }) => TESTED.has(model_id),
  // supabase/avatars.sql
  avatars_of: ({ handles }) => [...facesNow()].filter(([handle]) => (handles || []).includes(handle))
    .map(([handle, avatar]) => ({ handle, avatar })),
  profile_likes: ({ whose, size = 25, skip = 0, tests = false }) => likedOf(whose, tests).slice(skip, skip + size).map(card),
  profile_likes_count: ({ whose, tests = false }) => likedOf(whose, tests).length,
  age_of: () => ({ ask: false, over_13: true, asked_at: "2026-10-18T10:00:00Z" }),
  may_act: () => true,
  may_publish: () => true,
  may_list: () => true,
  count_view: () => true,
  gallery_pick: () => ({ pick: null, chosen: false, until: null, week: PICK.week, card: card(modelOf(PICK.model)) }),
  // Last month's winner (CHALLENGES_LISTED), on its card and its designer's page.
  challenge_wins: ({ owner, models }) => (owner === ROBIN || (models || []).includes(MODEL_ID)
    ? [{ challenge: 2, title: "Castle September", ends_on: "2026-09-30", way: "hand", model: MODEL_ID,
      name: "Riverside Watchtower", votes: 7 }] : []),
};

/// A JSON answer, as fetch gives it.
const reply = (status, value) => new Response(value === undefined ? null : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });

// What was asked that is not here: said once each, as the database says it
// of a table or a function that is not there (404), which the handlers read
// as a file not applied yet.
const unknown = new Set();
function notHere(what) {
  if (!unknown.has(what)) {
    unknown.add(what);
    console.warn(`design stand-in: nothing holds ${what}; answered 404, as for a table not there`);
  }
  return reply(404, { code: "PGRST205", message: `Could not find ${what}` });
}

/// One PostgREST filter (eq., in., is., gte., not.is. ...) on one value.
function passes(value, filter) {
  if (filter.startsWith("not.")) return !passes(value, filter.slice(4));
  const at = filter.indexOf(".");
  const op = filter.slice(0, at);
  const arg = filter.slice(at + 1);
  const text = value === null || value === undefined ? null : String(value);
  const compare = () => (Number.isFinite(Number(value)) && Number.isFinite(Number(arg))
    ? Number(value) - Number(arg) : String(text).localeCompare(arg));
  if (op === "eq") return text === arg;
  if (op === "neq") return text !== arg;
  if (op === "in") return arg.replace(/^\(|\)$/g, "").split(",").map((one) => one.replace(/^"|"$/g, "")).includes(text);
  if (op === "is") return arg === "null" ? text === null : text === arg;
  if (op === "gt") return text !== null && compare() > 0;
  if (op === "gte") return text !== null && compare() >= 0;
  if (op === "lt") return text !== null && compare() < 0;
  if (op === "lte") return text !== null && compare() <= 0;
  return true;
}

/// Rows of a table as a query string asks for them: filtered, ordered, cut
/// short and only the columns named. An embedded table (name(columns)) is
/// left out.
function chosen(rows, params) {
  const words = new Set(["select", "order", "limit", "offset", "on_conflict"]);
  let out = rows.filter((row) => [...params].every(([key, filter]) => words.has(key) || passes(row[key], filter)));
  const order = params.get("order");
  if (order) {
    const keys = order.split(",").map((one) => one.split("."));
    out = [...out].sort((a, b) => {
      for (const [key, way] of keys) {
        const diff = typeof a[key] === "number" && typeof b[key] === "number" ? a[key] - b[key]
          : String(a[key] ?? "").localeCompare(String(b[key] ?? ""));
        if (diff) return way === "desc" ? -diff : diff;
      }
      return 0;
    });
  }
  const offset = Number(params.get("offset")) || 0;
  out = out.slice(offset, params.has("limit") ? offset + Number(params.get("limit")) : undefined);
  const select = params.get("select");
  if (!select || select === "*") return out;
  const columns = [];
  let depth = 0;
  let word = "";
  for (const c of `${select},`) {
    if (c === "(") depth += 1;
    if (c === ")") depth -= 1;
    if (c === "," && depth === 0) {
      if (!word.includes("(")) columns.push(word.trim());
      word = "";
    } else {
      word += c;
    }
  }
  return out.map((row) => Object.fromEntries(columns.map((key) => [key, row[key] ?? null])));
}

function rest(where, init) {
  const path = where.pathname.slice("/rest/v1/".length);
  const method = String(init.method || "GET").toUpperCase();
  if (path.startsWith("rpc/")) {
    const run = RPC[path.slice(4)];
    if (!run || (path === "rpc/gallery_models" && !APPLIED)) return notHere(path);
    let body = {};
    try {
      body = init.body ? JSON.parse(init.body) : {};
    } catch {
      body = {};
    }
    const said = run(body || {});
    return reply(200, said === undefined ? null : said);
  }
  const table = TABLES[path];
  if (!table) return notHere(path);
  if (method === "GET" || method === "HEAD") {
    // A visitor's read (the publishable key alone): row security shows only
    // what is published.
    const visitor = !new Headers(init.headers || {}).get("authorization");
    const rows = table().filter((row) => !(visitor && path === "shared_models" && !row.published));
    return reply(200, chosen(rows, where.searchParams));
  }
  // A write: taken as done, and kept nowhere.
  const asked = String(new Headers(init.headers || {}).get("prefer") || "");
  if (method === "POST") return reply(201, asked.includes("return=representation") ? [JSON.parse(init.body || "{}")] : undefined);
  return new Response(null, { status: 204 });
}

// The pictures and the files the buckets hold: a pixel of each kind, and a
// model of three bricks, for any model that has them.
const PIXEL_PNG = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";
const PIXEL_WEBP = "UklGRiQAAABXRUJQVlA4IBgAAAAwAQCdASoBAAEAAwA0JaQAA3AA/vuUAAA=";
export const BRICKS = "0 FILE model.ldr\n0 Author: Brickworks\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n"
  + "1 14 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n0 STEP\n1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat\n0 STEP\n";

function storage(where, init) {
  const method = String(init.method || "GET").toUpperCase();
  const face = /^\/storage\/v1\/object\/avatars\/([A-Za-z0-9]{10})\.jpg$/.exec(where.pathname);
  if (face) {
    const one = AVATARS.find((row) => row.id === face[1] && !row.removed_at);
    return method === "GET" && one ? new Response(one.bytes, { status: 200, headers: { "content-type": "image/jpeg" } })
      : reply(400, { error: "not_found", message: "Object not found" });
  }
  const found = /^\/storage\/v1\/object\/([a-z-]+)\/([A-Za-z0-9]{10})(?:\.v\d+)?\.(png|webp|mpd)$/.exec(where.pathname);
  if (method !== "GET" || !found || !modelOf(found[2])?.published) return reply(400, { error: "not_found", message: "Object not found" });
  const [, , id, kind] = found;
  const m = modelOf(id);
  if ((kind === "png" && !m.has_image) || (kind === "webp" && !m.has_thumb)) return reply(400, { error: "not_found" });
  const bytes = kind === "mpd" ? Buffer.from(BRICKS) : Buffer.from(kind === "png" ? PIXEL_PNG : PIXEL_WEBP, "base64");
  return new Response(bytes, { status: 200, headers: { "content-type": { png: "image/png", webp: "image/webp", mpd: "text/plain" }[kind] } });
}

let realFetch = null;

/// The database answered from here, for this process, once.
function standIn() {
  if (realFetch) return;
  realFetch = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const asked = typeof input === "string" || input instanceof URL ? String(input) : input.url;
    if (asked.startsWith(`${DB}/rest/v1/`)) return rest(new URL(asked), init);
    if (asked.startsWith(`${DB}/storage/v1/`)) return storage(new URL(asked), init);
    return realFetch(input, init);
  };
}

// ---------------------------------------------------------------------------
// The pages the server makes.

// As relay_server.mjs's MAPPED, which is as deploy.sh writes them for Vercel.
const PAGES = [
  [/^\/m\/([A-Za-z0-9]{10})\/?$/, "share", "page"],
  [/^\/m\/([A-Za-z0-9]{10})[.]png$/, "share", "image"],
  [/^\/m\/([A-Za-z0-9]{10})[.]cutout[.]png$/, "share", "cutout"],
  [/^\/m\/([A-Za-z0-9]{10})[.]webp$/, "share", "thumb"],
  [/^\/m\/([A-Za-z0-9]{10})\/embed\/?$/, "share", "embed"],
  [/^\/oembed\/?$/, "share", "oembed"],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})\/?$/, "share", "page"],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})[.]png$/, "share", "image"],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})[.]cutout[.]png$/, "share", "cutout"],
  [/^\/m\/([A-Za-z0-9]{10})[.]mpd$/, "share", "file"],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})[.]mpd$/, "share", "file"],
  [/^\/m\/([A-Za-z0-9]{10})()\/parts[.](json|xml|csv)$/, "share", "parts"],
  [/^\/m\/([A-Za-z0-9]{10})\/v\/([1-9][0-9]{0,5})\/parts[.](json|xml|csv)$/, "share", "parts"],
  [/^\/u\/([a-z0-9-]{3,24})\/?$/, "people", "page"],
  [/^\/c\/([A-Za-z0-9]{10})\/?$/, "people", "list_page"],
  [/^\/collections\/?$/, "people", "collections_page"],
  // A LEGO® set's page (api/_sets.js), from this checkout's catalogue.
  [/^\/library\/set\/([A-Za-z0-9][A-Za-z0-9.-]{0,29})\/?$/, "share", "catalog_set"],
];

/// Which handler makes [pathname], and what it is asked. A path under /m/,
/// /u/ or /c/ that is not one goes to the same handler with what it has,
/// for its own page saying there is nothing there.
function routeOf(pathname) {
  for (const [pattern, name, op] of PAGES) {
    const found = pattern.exec(pathname);
    if (!found) continue;
    if (op === "catalog_set") return { name, query: { op, set: found[1] } };
    if (name === "share") {
      return { name, query: { op, ...(found[1] ? { id: found[1] } : {}), ...(found[2] ? { v: found[2] } : {}),
        ...(found[3] ? { as: found[3] } : {}) } };
    }
    return { name, query: op === "page" ? { op, handle: found[1] } : { op, id: found[1] } };
  }
  const [, place, rest = ""] = /^\/([muc])\/([^/]*)/.exec(pathname) || [];
  if (place === "m") return { name: "share", query: { op: "page", id: rest } };
  if (place === "u") return { name: "people", query: { op: "page", handle: rest } };
  if (place === "c") return { name: "people", query: { op: "list_page", id: rest } };
  return null;
}

const handlers = new Map();

/// The two handlers of [apiDir], imported once each.
function handlersOf(apiDir) {
  if (!handlers.has(apiDir)) {
    const load = async (name) => (await import(pathToFileURL(join(apiDir, `${name}.js`)).href)).default;
    handlers.set(apiDir, Promise.all([load("share"), load("people")]).then(([share, people]) => ({ share, people })));
  }
  return handlers.get(apiDir);
}

/// A page the server makes, by [apiDir]'s own handlers: {status, html,
/// headers}, and for a picture its bytes.
export async function serverPage(apiDir, pathname) {
  const [path, search = ""] = String(pathname).split("?");
  const route = routeOf(path);
  if (!route) return { status: 404, html: "", headers: {} };
  // Its question too (a profile's ?tab= and ?page=, tests=1), as the
  // deployment passes it on; never over what the path says.
  return serverAsk(apiDir, { ...route, query: { ...Object.fromEntries(new URLSearchParams(search)), ...route.query } });
}

/// What [apiDir]'s handler [name] ("share" or "people") answers [query]
/// with, asked as a page is: {status, html, headers}, html the body.
export async function serverAsk(apiDir, { name, query }) {
  // What the handlers read to call themselves configured (api/_db.js
  // dbConfigured, api/_auth.js authConfigured, api/share.js's reads as a
  // visitor), set before they are imported.
  process.env.SUPABASE_URL = DB;
  process.env.SUPABASE_SECRET_KEY = SECRET;
  process.env.SUPABASE_PUBLISHABLE_KEY = PUBLISHABLE;
  standIn();
  const handler = (await handlersOf(apiDir))[name];
  const site = new URL(ORIGIN);
  const request = { method: "GET", query, body: undefined,
    headers: { host: site.host, "x-forwarded-proto": site.protocol.replace(":", ""), accept: "text/html",
      "user-agent": "Mozilla/5.0 (X11; Linux x86_64) Brickworks design check" } };
  const response = {
    statusCode: 200,
    headers: {},
    body: "",
    status(code) { this.statusCode = code; return this; },
    setHeader(name, value) { this.headers[String(name).toLowerCase()] = value; return this; },
    json(value) { this.headers["content-type"] = "application/json"; this.body = JSON.stringify(value); return this; },
    end(text) { this.body = text ?? ""; return this; },
  };
  try {
    await handler(request, response);
  } catch (trouble) {
    // As the relay answers a handler that throws.
    return { status: 500, html: String(trouble?.stack || trouble), headers: {} };
  }
  const bytes = Buffer.isBuffer(response.body) ? response.body : null;
  return { status: response.statusCode, html: bytes ? "" : String(response.body), headers: response.headers,
    ...(bytes ? { bytes } : {}) };
}

// ---------------------------------------------------------------------------
// Signed in, in the browser.

const b64url = (value) => Buffer.from(JSON.stringify(value)).toString("base64url");
// Shaped like Supabase's (a JWT for the project), and never checked here.
const ACCESS = `${b64url({ alg: "ES256", typ: "JWT", kid: "design-stand-in" })}.${b64url({ sub: ME, email: EMAIL,
  aud: "authenticated", role: "authenticated", iss: `${DB}/auth/v1`, exp: FOREVER })}.c3RhbmQtaW4`;
const REFRESH = "design-stand-in-refresh";

/// What localStorage "brickworks.session" and sessionStorage
/// "brickworks.access" hold when this browser is signed in as EMAIL
/// (web/account.js keep()), the access token good until 2100.
export function signedInStorage() {
  return {
    session: { refresh_token: REFRESH, email: EMAIL, user_id: ME, url: DB, key: PUBLISHABLE },
    access: { token: ACCESS, until: FOREVER * 1000, email: EMAIL },
  };
}

/// A session, as Supabase gives one for a code or a refresh token.
const session = () => ({ access_token: ACCESS, token_type: "bearer", expires_in: 3600, expires_at: FOREVER,
  refresh_token: REFRESH, user: { id: ME, aud: "authenticated", role: "authenticated", email: EMAIL,
    email_confirmed_at: "2026-05-11T09:00:00Z", created_at: "2026-05-11T09:00:00Z" } });

// ---------------------------------------------------------------------------
// The browser's requests, answered as the API answers them.

const KINDS = [
  { id: "castle", label: "Castles and fantasy" }, { id: "space", label: "Space" }, { id: "vehicle", label: "Vehicles" },
  { id: "town", label: "Town and buildings" }, { id: "architecture", label: "Architecture" },
  { id: "mechanism", label: "Mechanisms" }, { id: "robot", label: "Robots and machines" },
  { id: "nature", label: "Animals and nature" }, { id: "figure", label: "Figures and characters" },
  { id: "art", label: "Art and mosaics" }, { id: "other", label: "Something else" },
];
const SIZES = { small: { most: 199, label: "Small, under 200 parts" },
  medium: { least: 200, most: 999, label: "Medium, 200 to 999 parts" }, large: { least: 1000, label: "Large, 1,000 parts or more" } };
const SORTS = { newest: "Newest", views: "Most viewed", likes: "Most liked", remixes: "Most remixed", builds: "Most built",
  top: "Top builds" };
const MINE_SORTS = { owned: "Parts I own" };
const WINDOWS = { week: { days: 7, label: "This week" }, month: { days: 30, label: "This month" } };
const MADES = { hand: "Hand-built", assistant: "With the assistant" };
const SCORE = { builds: 3, remixes: 2, tested: 5 };
const SHELF = 8;
const PER_PAGE = 24;
const TESTS_SAID = ["Stands at every step", "every step reachable", "every part made in its colour", "nothing loose"];

// What the API says when it refuses, in its words.
const SIGN_IN = "sign in to Brickworks first";
const ASK_FIRST = "Brickworks asks everyone one question first. Sign in again, in the app or on brickworks.diy, to answer it, then ";
const COMMENT_WORDS = { sign_in: "Sign in to add a comment: we email you a code, no password. Anyone can read them.",
  ask_first: `${ASK_FIRST}add your comment.` };
const FOLLOW_WORDS = { sign_in: "Sign in to follow people: we email you a code, no password.", yourself: "That is you.",
  ask_first: `${ASK_FIRST}follow.` };
const LIST_WORDS = { sign_in: "Sign in to follow collections: we email you a code, no password.",
  yourself: "That is your own collection.", ask_first: `${ASK_FIRST}follow.` };

const answer = (status, json) => ({ status, json });
const YES = new Set(["1", "true", "yes", "on"]);
const asked = (value) => YES.has(String(value ?? "").toLowerCase());

/// POST ?op=bases {model, bases}: checked as api/_bases.js checks it, and
/// kept for the model's designer alone, the whole list.
function putBases(body, who) {
  if (!who) return answer(401, { error: SIGN_IN });
  const m = shownModel(String(body?.model || ""));
  if (!m) return answer(404, { error: "There is no shared model at that link." });
  if (m.owner !== who) return answer(403, { error: "Only its designer says what it is based on." });
  let kept;
  try {
    kept = basesAsked(body?.bases);
  } catch (trouble) {
    return answer(trouble.status || 400, { error: trouble.message });
  }
  BASES.splice(0, BASES.length, ...BASES.filter((row) => row.model !== m.id), ...kept.map((one, at) => ({ model: m.id,
    n: at + 1, how: one.how, set_number: one.set || null, url: one.url || null, title: one.title || null,
    author: one.author || null, licence: one.licence || null })));
  return answer(200, { bases: basesSaid(RPC.model_bases_of({ model_ids: [m.id] })) });
}

/// cardOf: a card as a client is given it, with the asker's share of its
/// parts when the list was asked with theirs.
function apiCard(row) {
  const url = `${ORIGIN}/m/${row.id}`;
  const version = (Date.parse(row.updated_at || "") || 0).toString(36);
  return { id: row.id, name: row.name, author: row.author, parts: row.parts, listed_at: row.listed_at, kind: row.kind ?? null,
    tags: row.tags || [], licence: row.licence ?? null, steps: row.steps ?? null, own_steps: row.own_steps === true,
    technic: row.technic === true, tested: row.tested === true, views: row.views, likes: row.likes, remixes: row.remixes,
    builds: row.builds, comments: Number(row.comments) || 0, by: row.by, url, image: row.has_image ? `${url}.png` : null,
    thumb: row.has_thumb ? `${url}.webp?v=${version}` : null,
    ...(row.owned ? { owned: { ...row.owned, share: row.owned.pieces ? row.owned.have / row.owned.pieces : null } } : {}) };
}

/// A page of cards, as api/people.js models() gives one.
function cardPage(query, page = 1) {
  const rows = listModels({ ...query, size: PER_PAGE + 1, skip: (page - 1) * PER_PAGE });
  return { page, per_page: PER_PAGE, more: rows.length > PER_PAGE, models: rows.slice(0, PER_PAGE).map(apiCard) };
}

/// photoSaid: a photo as anybody is told of it.
function photoSaid(photo) {
  return { id: photo.id, model: photo.model, words: photo.words ?? null, width: photo.width, height: photo.height, at: photo.at,
    by: named(photo.account), url: `${ORIGIN}/api/people?op=photo_file&id=${photo.id}`,
    page: `${ORIGIN}/m/${photo.model}#photo-${photo.id}` };
}

/// The versions comments are placed by: [{n, steps, first_changed}], newest first.
function commentVersions(id) {
  const rows = VERSIONS.filter((one) => one.model === id).sort((a, b) => b.n - a.n);
  return rows.length ? rows.map((one) => ({ n: one.n, steps: one.steps, first_changed: one.first_changed }))
    : [{ n: 1, steps: null, first_changed: null }];
}

/// api/_comments.js commentSaid: a comment shown on version [shown].
function commentSaid(comment, shown, versions, asker) {
  const newest = versions[0].n;
  let onStep = comment.step;
  if (onStep !== null) {
    const known = new Map(versions.map((one) => [one.n, one]));
    for (let n = Math.min(comment.version, shown) + 1; n <= Math.max(comment.version, shown); n += 1) {
      const one = known.get(n);
      if (!one || (one.first_changed !== null && one.first_changed <= comment.step)) onStep = null;
    }
    if (known.get(shown)?.steps && comment.step > known.get(shown).steps) onStep = null;
  }
  const where = comment.step ? `on step ${comment.step} of version ${comment.version}` : `on version ${comment.version}`;
  const author = personOf(comment.author);
  // Who it names (supabase/comment_mentions.sql), as api/_comments.js says it.
  const mentions = (comment.mentions || []).map(personOf).filter(Boolean).map((one) => ({ handle: one.handle, name: one.name }));
  return { ...(mentions.length ? { mentions } : {}), id: comment.id, version: comment.version, step: comment.step, on_step: onStep,
    body: comment.body, at: comment.at,
    edited_at: comment.edited_at, by: author?.name ?? null, handle: author?.handle ?? null,
    by_owner: comment.author === modelOf(comment.model)?.owner, mine: Boolean(asker) && comment.author === asker,
    hidden: Boolean(comment.hidden_at), older: comment.version < newest,
    said: comment.version < newest ? `${where}, an older version` : where, parent: comment.parent };
}

/// /api/people?op=comments&id=X&v=N.
function comments(params, who, state) {
  const id = params.get("id") || "";
  if (!ID.test(id)) return answer(400, { error: "name a link: ?id=<ten characters>" });
  const m = modelOf(id);
  if (!m || !m.published) return answer(404, { error: "There is no shared model at that link." });
  const versions = commentVersions(id);
  const shown = params.get("v") ? Number(params.get("v")) : versions[0].n;
  if (!versions.some((one) => one.n === shown)) return answer(404, { error: "That model has no such version." });
  const owner = who === m.owner;
  const list = COMMENTS.filter((one) => one.model === id && !one.removed_at
    && (!one.hidden_at || (who && (one.author === who || owner)))).sort((a, b) => String(a.at).localeCompare(String(b.at)) || a.id - b.id)
    .map((one) => commentSaid(one, shown, versions, who));
  const trouble = !who ? "sign_in" : state.askAge ? "ask_first" : null;
  return answer(200, { model: id, ready: true, version: shown, newest: versions[0].n, open: true, replies: true, count: list.length,
    comments: list, you: { signed_in: Boolean(who), may_write: !trouble, why_not: trouble ? COMMENT_WORDS[trouble] : "", owner } });
}

/// api/_follows.js feedSaid: a feed row as a person reads it.
function feedRow(row) {
  const by = personOf(row.by);
  const base = { kind: row.kind, at: row.at, who: by ? by.name : "A builder",
    by: by ? { handle: by.handle, name: by.name, url: `${ORIGIN}/u/${by.handle}` } : null, name: row.name, said: "",
    model: row.model, new: Date.parse(row.at) > Date.parse(FEED_SEEN) };
  if (row.kind === "model") return { ...base, did: "shared a new model", link: `${ORIGIN}/m/${row.model}` };
  if (row.kind === "version") {
    return { ...base, did: `shared version ${row.version} of`, said: row.note, link: `${ORIGIN}/m/${row.model}/v/${row.version}` };
  }
  if (row.kind === "photo") {
    return { ...base, did: row.yours ? "posted a photo of their build of your model" : "posted a photo of their build of",
      said: row.words, link: `${ORIGIN}/m/${row.model}#photo-${row.photo}` };
  }
  if (row.kind === "comment") {
    return { ...base, did: `commented on ${row.step ? `step ${row.step} of your model` : "your model"}`, said: row.said,
      link: `${ORIGIN}/m/${row.model}#comment-${row.comment}` };
  }
  if (row.kind === "challenge") {
    return { ...base, did: "entered", after: `in the challenge “${row.title}”, built ${row.way === "assistant"
      ? "with the assistant" : "by hand"}`, link: `${ORIGIN}/m/${row.model}` };
  }
  if (row.kind === "collection") {
    return { ...base, did: "added", link: `${ORIGIN}/m/${row.model}`,
      list: { id: row.collection, name: row.list_name, link: `${ORIGIN}/c/${row.collection}` } };
  }
  return { ...base, did: `remixed your model “${row.of_name}” as`, link: `${ORIGIN}/m/${row.model}` };
}

const CHALLENGE_RULES = ["At most 1,500 parts", "Marked Tested: it stands at every step, and every step can be built"];

/// "1 to 30 September 2026", as api/_challenges.js daysSaid says it.
const monthDays = (from, to) => `${Number(from.slice(8, 10))} to ${Number(to.slice(8, 10))} ${new Intl.DateTimeFormat("en-GB",
  { month: "long", year: "numeric", timeZone: "UTC" }).format(new Date(`${to}T00:00:00Z`))}`;

/// /api/people?op=challenge (api/_challenges.js challenge): the challenge,
/// its entries the gallery's cards in their two groups, and [who]'s votes;
/// the next one told and the ones that ran. With [asked], that one alone.
function challengePage(who, asked = null) {
  const cardFor = (id) => apiCard(listModels({ size: 1000 }).find((one) => one.id === id));
  if (asked) {
    const past = PAST.find((one) => one.id === Number(asked));
    if (!past) return answer(404, { error: "There is no challenge at that number to show." });
    const entries = past.winners.map(([id, way, votes]) => ({ ...cardFor(id), way, entered_at: `${past.starts_on}T10:00:00Z`,
      keeps: true, votes, winner: true, won: [] }));
    return answer(200, { ready: true, challenge: { id: past.id, title: past.title, brief: past.brief, starts_on: past.starts_on,
      ends_on: past.ends_on, state: "ended", test: false, settled: true, rules: past.rules,
      rules_said: past.rules.most_parts ? [`At most ${past.rules.most_parts} parts`]
        : [`Only parts of set ${past.rules.set_number}, ${past.rules.set_name}: no more of each, in its colour, than the set has`],
      days_said: monthDays(past.starts_on, past.ends_on),
      groups: [["hand", "Built by hand"], ["assistant", "Built with the assistant"]].map(([way, label]) => ({ way, label,
        entries: entries.filter((one) => one.way === way) })),
      winners: past.winners.map(([model, way, votes]) => ({ way, label: way === "hand" ? "Built by hand" : "Built with the assistant",
        model, votes })) }, ...(who ? { you: { signed_in: true, voted: { hand: null, assistant: null }, entries: [],
      may_vote: false, why_not: "Voting has closed." } } : {}) });
  }
  const c = CHALLENGE;
  const entryOf = ([id, way], at) => ({ ...cardFor(id), way,
    entered_at: `2026-10-0${at + 2}T10:00:00Z`, keeps: true, votes: null, winner: false, won: [] });
  const challenge = { id: c.id, title: c.title, brief: c.brief, starts_on: c.starts_on, ends_on: c.ends_on, state: c.state,
    test: c.test, settled: c.settled, rules: c.rules, rules_said: CHALLENGE_RULES, days_said: "1 Oct 2026 to 31 Oct 2026",
    groups: [["hand", "Built by hand"], ["assistant", "Built with the assistant"]].map(([way, label]) => ({ way, label,
      entries: c.entries.map(entryOf).filter((one) => one.way === way) })), winners: [] };
  const past = PAST.map((one) => ({ id: one.id, title: one.title, starts_on: one.starts_on, ends_on: one.ends_on, test: false,
    entries: one.entries, days_said: monthDays(one.starts_on, one.ends_on),
    winners: one.winners.map(([id, way, votes]) => ({ ...cardFor(id), way, votes,
      label: way === "hand" ? "Built by hand" : "Built with the assistant" })) }));
  return answer(200, { ready: true, challenge, year: true,
    next: { id: NEXT.id, title: NEXT.title, brief: NEXT.brief, starts_on: NEXT.starts_on, ends_on: NEXT.ends_on, test: false,
      days_said: monthDays(NEXT.starts_on, NEXT.ends_on) }, past,
    ...(who ? { you: { signed_in: true, ...c.you, may_vote: true, why_not: null } } : {}) });
}

/// /api/people?op=designs: the signed-in person's own models' numbers.
function designs(params) {
  const me = personOf(ME);
  if (params.has("handle") && params.get("handle").toLowerCase() !== me.handle) return answer(200, { mine: false });
  const models = MODELS.filter((one) => one.owner === ME && one.published && !one.barred).map((m) => {
    const recent = DESIGNS.recent[m.id] || { opens: 0, builds: 0, remixes: 0, comments: 0 };
    const [views, , builds] = statsOf(m.id);
    const photos = photosWhere((one) => one.model === m.id && one.account !== ME);
    const url = `${ORIGIN}/m/${m.id}`;
    return { id: m.id, name: m.name, listed: m.listed, credited: m.author !== null, test: m.test, parts: m.parts,
      tested: TESTED.has(m.id), url, image: m.has_image ? `${url}.png` : null,
      thumb: m.has_thumb ? `${url}.webp?v=${(Date.parse(m.updated_at) || 0).toString(36)}` : null,
      opens: recent.opens, opens_ever: views, builds: recent.builds, builds_ever: builds, remixes: recent.remixes,
      remixes_ever: remixesOf(m.id).length, comments: recent.comments,
      comments_ever: COMMENTS.filter((one) => one.model === m.id && !one.removed_at && one.author !== ME).length,
      photos_count: photos.length, builders: new Set(photos.map((one) => one.account)).size,
      photos: photos.slice(0, 6).map((one) => ({ ...photoSaid(one), model: m.id })) };
  });
  const totals = {};
  for (const kind of ["opens", "builds", "remixes", "comments"]) {
    totals[kind] = models.reduce((sum, one) => sum + one[kind], 0);
    totals[`${kind}_ever`] = models.reduce((sum, one) => sum + one[`${kind}_ever`], 0);
  }
  return answer(200, { mine: true, ready: true, handle: me.handle, days: DESIGNS.days, since: DESIGNS.since,
    counted_from: DESIGNS.counted_from, totals, models });
}

/// /api/people?op=follows&handle=X, as the asker sees it.
function follows(handle, who, state, on = null) {
  const found = followState(who, handle, state.askAge);
  if (!found) return answer(404, { error: "Nobody here has that handle." });
  const youFollow = on === null ? found.you_follow : on;
  const followers = found.followers + (youFollow && !found.you_follow ? 1 : 0) - (!youFollow && found.you_follow ? 1 : 0);
  return answer(200, { handle: found.handle, ready: true, followers, following: found.following, shows: found.shows,
    you_follow: youFollow, mine: found.mine, may: !found.trouble, why_not: found.trouble ? FOLLOW_WORDS[found.trouble] : "",
    signed_in: Boolean(who) });
}

/// /api/people?op=list_follows&id=X, as the asker sees it; with [on], as a
/// follow or a letting go leaves it.
function listFollows(id, who, state, on = null) {
  const found = listFollowState(who, id, state.askAge);
  if (!found) return answer(404, { error: "There is no public collection here to follow." });
  const youFollow = on === null ? found.you_follow : on;
  const followers = found.followers + (youFollow && !found.you_follow ? 1 : 0) - (!youFollow && found.you_follow ? 1 : 0);
  return answer(200, { id: found.id, ready: true, followers, you_follow: youFollow, mine: found.mine, may: !found.trouble,
    why_not: found.trouble ? LIST_WORDS[found.trouble] : "", signed_in: Boolean(who) });
}

/// /api/people?op=profile&handle=X: a profile as anybody sees it, as JSON.
function profile(handle, page = 1, tests = false) {
  const person = personNamed(handle);
  if (!person) return answer(404, { error: "nobody has that handle" });
  const about = profilePage(person.handle, tests);
  const earned = designerPage(person.handle, tests);
  const state = followState(null, person.handle);
  const cards = cardPage({ owner: person.account, sort: "top", tests }, page);
  const built = photosWhere((one) => one.account === person.account && shownModel(one.model)?.listed)
    .map((one) => ({ ...photoSaid(one), model_name: modelOf(one.model).name }));
  return answer(200, { handle: person.handle, name: person.name, bio: person.bio, since: person.created_at,
    models_count: about.models, likes: about.likes, followers: state.followers, following: state.following,
    designer: earned.models ? { models: earned.models, builds: earned.builds, remixes: earned.remixes, comments: earned.comments,
      tested: earned.tested, likes: earned.likes, builders: earned.builders, followers: state.followers,
      photos: earned.photos.map((one) => ({ ...one, url: `${ORIGIN}/api/people?op=photo_file&id=${one.id}`,
        page: `${ORIGIN}/m/${one.model}#photo-${one.id}` })) } : null,
    collections: about.collections, built, url: `${ORIGIN}/u/${person.handle}`, ...cards,
    liked_count: CHOICES.some((one) => one.account === person.account && one.shows_likes) ? likedOf(person.account, tests).length : null,
    achievements: achievementsOf({ about, earned: earned.models ? earned : null, built,
      wins: RPC.challenge_wins({ owner: person.account }), levels: achievementLevels(person.account, tests) }),
    levels: achievementLevels(person.account, tests),
    models: cards.models.map((one) => ({ ...one, comments: earned.cards[one.id]?.comments ?? 0 })) });
}

/// What [account] is told of their own picture (api/_avatars.js avatarSaid).
function avatarSaid(account) {
  const one = AVATARS.find((row) => row.account === account);
  return { ready: true, picture: one && !one.removed_at ? pictureAt(one.id) : null, removed: Boolean(one?.removed_at) };
}

/// A list as the asker may see it: public, or theirs.
function collection(id, who, page) {
  const list = collectionPage(id);
  if (!list || (!list.public && list.owner !== who)) return answer(404, { error: "there is no list at that id" });
  const mine = list.owner === who;
  return answer(200, { id, name: list.name, description: list.description, public: list.public, by: list.by,
    count: mine ? list.all : list.count, mine, url: `${ORIGIN}/c/${id}`,
    ...cardPage({ collection: id, private: mine, sort: "added" }, page) });
}

const MAIL = { comments: true, models: true, versions: false, photos: true, remixes: false };

/// Whether Sam likes [id]: as the fixtures say, or as a like pressed in
/// this browser left it (state.likes, a Map a flow gives to keep them).
const likes = (state, id) => (state.likes?.has(id) ? state.likes.get(id) : likedBy(ME, id));
/// [id]'s likes, counting what was pressed here.
const likeCount = (state, id) => statsOf(id)[1] + (likes(state, id) === likedBy(ME, id) ? 0 : likes(state, id) ? 1 : -1);

/// /api/people.
function people(method, params, body, who, state) {
  const op = params.get("op") || "";
  const page = Number(params.get("page") || 1);
  const id = params.get("id") || "";
  // What anybody may ask; everything else needs the session.
  const open = method === "GET" ? ["profile", "collection", "comments", "photos", "photo_file", "follows", "following",
    "feed_count", "page", "list_page", "challenge", "latest", "likes", "avatar", "list_follows"] : ["report", "digest"];
  if (!who && !open.includes(op)) {
    return answer(401, { error: op === "feed" ? "Sign in to see your feed: we email you a code, no password."
      : ["follow", "follow_choice"].includes(op) ? FOLLOW_WORDS.sign_in : op === "list_follow" ? LIST_WORDS.sign_in : SIGN_IN });
  }
  if (who && state.fresh) {
    const said = freshPeople(method, op, params, body, state.fresh);
    if (said) return said;
  }
  if (method === "GET") {
    // A picture, and the pages the server makes (serverPage): not JSON.
    if (["photo_file", "avatar", "page", "list_page"].includes(op)) return null;
    if (op === "me") {
      const me = personOf(ME);
      return answer(200, { profile: { handle: me.handle, name: me.name, bio: me.bio, created_at: me.created_at },
        collections: LISTS.filter((list) => list.owner === ME).sort(byTime("updated_at")).map(({ models, owner, ...list }) =>
          ({ ...list, count: collectionCount(list.id, true) })),
        mail: { ...MAIL, ready: true, kinds: true }, follows: { ready: true, shows_follows: SHOWS_FOLLOWS.has(ME) },
        // What their profile shows (supabase/profile_shows.sql): nothing chosen
        // yet, and the models they may choose from.
        showcase: { ready: true, links: [], banner: null, pins: [],
          models: listModels({ owner: ME, size: 200 }).map((one) => ({ id: one.id, name: one.name, picture: one.has_image })) },
        // Their own picture (none yet: the avatar made from the handle), and
        // whether they show the models they liked (supabase/avatars.sql).
        avatar: avatarSaid(ME), likes: { ready: true, shows_likes: CHOICES.some((one) => one.account === ME && one.shows_likes) } });
    }
    if (op === "profile") return profile(params.get("handle"), page, asked(params.get("tests")));
    if (op === "likes") {
      const person = personNamed(params.get("handle"));
      const tests = asked(params.get("tests"));
      if (!person) return answer(404, { error: "nobody has that handle" });
      if (!CHOICES.some((one) => one.account === person.account && one.shows_likes)) {
        return answer(404, { error: "they do not show the models they liked" });
      }
      const all = likedOf(person.account, tests);
      return answer(200, { handle: person.handle, page, per_page: PER_PAGE, more: all.length > page * PER_PAGE,
        models: all.slice((page - 1) * PER_PAGE, page * PER_PAGE).map((m) => apiCard(card(m))) });
    }
    if (op === "marks") {
      if (!ID.test(id)) return answer(400, { error: "name a link: ?id=<ten characters>" });
      return answer(200, { liked: likes(state, id), favourite: keptBy(ME, id),
        collections: LISTS.filter((list) => list.owner === ME).sort(byTime("updated_at"))
          .map((list) => ({ id: list.id, name: list.name, public: list.public, has: list.models.includes(id) })) });
    }
    if (op === "favourites") return answer(200, cardPage({ favourites: ME, private: true, sort: "added" }, page));
    if (op === "collection") return collection(id, who, page);
    if (op === "comments") return comments(params, who, state);
    if (op === "photos") {
      const m = shownModel(id);
      if (!m) return answer(404, { error: "there is no shared model at that link" });
      const mine = PHOTOS.filter((one) => one.model === id && one.account === who && !one.removed_at).map(photoSaid);
      return answer(200, { model: id, owner: who === m.owner, photos: photosWhere((one) => one.model === id).map(photoSaid),
        mine, left: who ? Math.max(0, 3 - mine.length) : null });
    }
    if (op === "follows") return follows(params.get("handle"), who, state);
    // A page of cards' Follow at once (/collections): each one's, as the API
    // gives them; a collection nobody may follow left out.
    if (op === "list_follows" && params.get("ids") !== null) {
      const follows = {};
      for (const one of String(params.get("ids")).split(",")) {
        const said = listFollows(one, who, state);
        if (said.status === 200) follows[one] = said.json;
      }
      return answer(200, { follows, signed_in: Boolean(who) });
    }
    if (op === "list_follows") return listFollows(id, who, state);
    if (op === "following" && !params.get("handle")) {
      // Your own, for you alone (your account page), whatever you show.
      if (!who) return answer(401, { error: FOLLOW_WORDS.sign_in });
      return answer(200, { mine: true, ready: true, following: FOLLOWS.filter((one) => one.follower === who).sort(byTime("at"))
        .map((one) => named(one.followed)).filter(Boolean) });
    }
    if (op === "following") {
      const said = followList(params.get("handle"));
      return said ? answer(200, { handle: params.get("handle"), following: said.people }) : answer(404, { error: "Nobody here has that handle." });
    }
    if (op === "feed") {
      // One page, of what the people Sam follows made (follow_page), each
      // with its card and a photo's picture: asked again for an older one,
      // there is none. state.nobody: Sam follows nobody.
      const followed = state.nobody ? [] : FOLLOWS.filter((one) => one.follower === ME);
      const rows = params.get("before") || state.nobody ? [] : FEED
        .filter((row) => ["model", "version", "challenge", "collection"].includes(row.kind) || (row.kind === "photo" && !row.yours))
        .map((row) => {
          const photo = row.kind === "photo" ? PHOTOS.find((one) => one.id === row.photo) : null;
          return { ...feedRow(row), card: apiCard(card(modelOf(row.model))),
            ...(photo ? { photo: { id: photo.id, url: `${ORIGIN}/api/people?op=photo_file&id=${photo.id}`,
              width: photo.width, height: photo.height } } : {}) };
        });
      return answer(200, { ready: true, rows, more: false, seen_at: FEED_SEEN,
        ...(params.get("before") ? {} : { following: followed.map((one) => personOf(one.followed)?.handle).filter(Boolean) }) });
    }
    if (op === "latest") {
      // api/_follows.js latest: the newest models, the newest photos of
      // builds of models in the gallery, designers by Top builds.
      const tests = asked(params.get("tests"));
      const photos = photosWhere((one) => shownModel(one.model)?.listed && (tests || !modelOf(one.model).test))
        .slice(0, LATEST.photos).map((one) => ({ ...photoSaid(one), model_name: modelOf(one.model).name }));
      return answer(200, { models: listModels({ sort: "newest", size: LATEST.models, tests }).map(apiCard), photos,
        designers: designersFrom(listModels({ sort: "top", size: 49, tests }).map(apiCard)) });
    }
    if (op === "feed_count") {
      if (!who) return answer(200, { count: 0, signed_in: false });
      const fresh = (rows) => rows.filter((row) => Date.parse(row.at) > Date.parse(FEED_SEEN)).length;
      const feed = fresh(FEED.filter((row) => !["comment", "remix"].includes(row.kind) && !row.yours));
      const me = personOf(ME);
      return answer(200, { count: fresh(NOTICES) + feed, notifications: fresh(NOTICES), feed, signed_in: true, ready: true,
        me: { handle: me.handle, name: me.name } });
    }
    if (op === "notifications") {
      const rows = NOTICES.map((row) => {
        const by = row.by ? personOf(row.by) : null;
        return { ...row, by: by ? { handle: by.handle, name: by.name } : null };
      });
      const models = Object.fromEntries([...new Set(NOTICES.map((row) => row.on))].map((id) => {
        const m = MODELS.find((one) => one.id === id) || {};
        return [id, { name: m.name, has_image: m.has_image === true, has_thumb: m.has_thumb === true, updated_at: m.updated_at }];
      }));
      return answer(200, { ready: true, kept: true, seen_at: FEED_SEEN, ...noticeGroups({ rows, models, seen_at: FEED_SEEN,
        read_at: null, reads: { SamModel01: "2026-10-15T00:00:00Z", SamModel02: "2026-10-03T00:00:00Z" } }) });
    }
    if (op === "designs") return designs(params);
    if (op === "challenge") return challengePage(who, params.get("id"));
    if (op === "challenge_entry") {
      // api/_challenges.js challengeEntry: the tram's designer, Sam, may enter it.
      if (id !== "SamModel01" || who !== ME) return answer(200, { mine: false });
      return answer(200, { mine: true, ready: true, challenge: { id: CHALLENGE.id, title: CHALLENGE.title,
        starts_on: CHALLENGE.starts_on, ends_on: CHALLENGE.ends_on, days_said: "1 Oct 2026 to 31 Oct 2026",
        rules_said: CHALLENGE_RULES }, entry: null, entries: 0, in_gallery: true, keeps: true, broken: [] });
    }
    return answer(400, { error: `unknown op ${op}` });
  }
  // A like, kept in state.likes when the flow gave one, as api/people.js
  // answers it: liked or not, and the count.
  if (op === "like") {
    if (!ID.test(id) || !shownModel(id)) return answer(404, { error: "there is no shared model at that link" });
    if (typeof body?.on !== "boolean") return answer(400, { error: "say on: true or on: false" });
    state.likes?.set(id, body.on);
    return answer(200, { id, liked: body.on, likes: state.likes ? likeCount(state, id) : statsOf(id)[1] });
  }
  // A reply (supabase/replies.sql): on its comment's version and step, as
  // the API answers it; kept nowhere, as every write here.
  if (op === "reply") {
    const to = COMMENTS.find((one) => one.id === Number(body?.id) && !one.removed_at && !one.hidden_at);
    if (!to) return answer(404, { error: "That comment is not there any more, so it cannot be answered." });
    const thread = to.parent ? COMMENTS.find((one) => one.id === to.parent) : to;
    const made = { ...thread, id: 900, author: who, at: "2026-10-18T12:00:00Z", body: String(body?.body || ""),
      parent: thread.id, edited_at: null, hidden_at: null, mentions: namedIn(String(body?.body || ""), who) };
    return answer(201, { comment: commentSaid(made, thread.version, commentVersions(thread.model), who) });
  }
  // Following a collection: as it would stand, kept nowhere.
  if (op === "list_follow") {
    if (typeof body?.on !== "boolean") return answer(400, { error: "say on: true or on: false" });
    return listFollows(String(body?.id || ""), who, state, body.on);
  }
  // Any other write: the check presses nothing that writes, so it went.
  return answer(200, { ok: true });
}

/// A new account, signed in for the first time (state.fresh, which the
/// flow gives and this keeps: {aged, profile, follows}): no profile until
/// it makes one, following nobody until it follows, and its feed what the
/// people it follows listed. What else it asks is answered as for Sam.
function freshPeople(method, op, params, body, fresh) {
  const mine = () => (fresh.profile ? { handle: fresh.profile.handle, name: fresh.profile.name } : null);
  const theirs = () => [...fresh.follows].map(personNamed).filter(Boolean);
  if (method === "GET" && op === "me") {
    return answer(200, { profile: fresh.profile, collections: [], mail: { ...MAIL, ready: true, kinds: true },
      follows: { ready: true, shows_follows: false }, showcase: { ready: true, links: [], banner: null, pins: [], models: [] },
      avatar: { ready: true, picture: null, removed: false }, likes: { ready: true, shows_likes: false } });
  }
  if (method === "GET" && op === "feed_count") {
    return answer(200, { count: 0, notifications: 0, feed: 0, signed_in: true, ready: true, me: mine() });
  }
  if (method === "GET" && op === "following" && !params.get("handle")) {
    return answer(200, { mine: true, ready: true, following: theirs().map((one) => ({ handle: one.handle, name: one.name })) });
  }
  if (method === "GET" && op === "follows") {
    const found = followState(null, params.get("handle"));
    if (!found) return answer(404, { error: "Nobody here has that handle." });
    const on = fresh.follows.has(found.handle);
    return answer(200, { handle: found.handle, ready: true, followers: found.followers + (on ? 1 : 0), following: found.following,
      shows: found.shows, you_follow: on, mine: false, may: true, why_not: "", signed_in: true });
  }
  if (method === "GET" && op === "feed") {
    // follow_page: what the people it follows listed, newest first.
    const rows = params.get("before") ? [] : theirs()
      .flatMap((one) => listModels({ owner: one.account, size: 100, tests: true }).map((m) => ({ m, by: one.account })))
      .sort((a, b) => String(b.m.listed_at).localeCompare(String(a.m.listed_at)))
      .map(({ m, by }) => ({ ...feedRow({ kind: "model", at: m.listed_at, by, model: m.id, name: m.name }), new: true,
        card: apiCard(m) }));
    return answer(200, { ready: true, rows, more: false, seen_at: null,
      ...(params.get("before") ? {} : { following: theirs().map((one) => one.handle) }) });
  }
  if (method === "POST" && op === "follow") {
    const person = personNamed(body?.handle);
    if (!person) return answer(404, { error: "Nobody here has that handle." });
    if (body?.on) fresh.follows.add(person.handle);
    else fresh.follows.delete(person.handle);
    return freshPeople("GET", "follows", new URLSearchParams({ handle: person.handle }), null, fresh);
  }
  if (method === "POST" && op === "profile") {
    // api/people.js saveProfile's refusals, in its words.
    const handle = String(body?.handle ?? "").trim().toLowerCase();
    if (!/^[a-z0-9][a-z0-9-]{1,22}[a-z0-9]$/.test(handle) || handle.includes("--")) {
      return answer(400, { error: "a handle is 3 to 24 letters, digits and single hyphens, starting and ending with a letter or a digit" });
    }
    const trouble = handleTrouble(handle);
    if (trouble) return answer(409, { error: trouble });
    if (personNamed(handle)) return answer(409, { error: "somebody already has that handle: choose another" });
    const name = String(body?.name ?? "").trim().slice(0, 40);
    if (!name) return answer(400, { error: "give the name to show on your profile: whatever you like to be called here" });
    fresh.profile = { handle, name, bio: null, created_at: "2026-10-22T12:00:00Z" };
    return answer(200, { handle, name, bio: null, url: `${ORIGIN}/u/${handle}` });
  }
  return null;
}

/// The gallery's question, checked as api/_directory.js listQuery checks
/// it: {asked, said}, or the refusal.
function galleryQuery(params, mine, who) {
  const page = Number(params.get("page") ?? 1);
  if (!Number.isInteger(page) || page < 1 || page > 400) return { refused: answer(400, { error: "page is a whole number from 1 to 400" }) };
  const said = { page };
  const query = { size: PER_PAGE + 1, skip: (page - 1) * PER_PAGE };
  const q = String(params.get("q") ?? "").trim();
  if (q) {
    said.q = q;
    query.words = (q.toLowerCase().match(/[\p{L}\p{N}]+/gu) || []).filter((word) => word.length >= 2)
      .map((word) => (word.length > 3 && /s$/.test(word) && !/ss$/.test(word) ? word.slice(0, -1) : word)).join(" & ");
  }
  const kind = params.get("kind") || "";
  if (kind) {
    if (!KINDS.some((one) => one.id === kind)) return { refused: answer(400, { error: `kind is one of ${KINDS.map((one) => one.id).join(", ")}` }) };
    said.kind = query.kind = kind;
  }
  const size = params.get("size") || "";
  if (size) {
    if (!SIZES[size]) return { refused: answer(400, { error: "size is one of small, medium, large" }) };
    said.size = size;
    Object.assign(query, SIZES[size].least ? { least: SIZES[size].least } : {}, SIZES[size].most ? { most: SIZES[size].most } : {});
  }
  for (const [name, column] of [["instructions", "own_steps"], ["technic", "technic"], ["tested", "tested"]]) {
    if (asked(params.get(name))) said[name] = query[column] = true;
  }
  const tag = String(params.get("tag") ?? "").toLowerCase().trim();
  if (tag) said.tag = query.tag = tag;
  const made = params.get("made") || "";
  if (made) {
    if (!["hand", "assistant"].includes(made)) return { refused: answer(400, { error: "made is one of hand, assistant" }) };
    said.made = query.made = made;
  }
  if (asked(params.get("following"))) {
    if (!who || !mine) return { refused: answer(401, { error: "sign in, and ask with mine=1, to see the models of the people you follow" }) };
    said.following = true;
    query.following = who;
  }
  const sort = params.get("sort") || "newest";
  if (!(sort in SORTS) && !(mine && sort in MINE_SORTS)) {
    return { refused: sort in MINE_SORTS ? answer(401, { error: "sign in, and ask with mine=1, to sort by what you own" })
      : answer(400, { error: `sort is one of ${Object.keys(SORTS).join(", ")}` }) };
  }
  said.sort = query.sort = sort;
  const span = params.get("window") || "";
  if (span) {
    if (!WINDOWS[span]) return { refused: answer(400, { error: "window is one of week, month" }) };
    if (sort !== "top") return { refused: answer(400, { error: "a window is Top's: ask it with sort=top" }) };
    said.window = span;
    query.days = WINDOWS[span].days;
  }
  if (asked(params.get("ready"))) {
    if (!mine) return { refused: answer(401, { error: "sign in, and ask with mine=1, to see what you can build now" }) };
    said.ready = query.buildable = true;
  }
  if (asked(params.get("tests"))) said.tests = query.tests = true;
  if (mine) query.pool = ME;
  return { query, said };
}

/// /api/share: the gallery's list and front, and a model's own page's asks.
function share(method, params, who, state = {}, body = undefined) {
  const op = params.get("op") || "";
  const id = params.get("id") || "";
  const mine = asked(params.get("mine"));
  if (mine && !who) return answer(401, { error: SIGN_IN });
  // What a model is based on (api/_bases.js): its page's lines, and its
  // designer's list taken as kept, which nothing here keeps.
  if (op === "bases") {
    if (method === "POST") return putBases(body, who);
    const m = shownModel(id);
    if (!m) return answer(404, { error: "There is no shared model at that link." });
    return answer(200, { bases: basesSaid(RPC.model_bases_of({ model_ids: [id] })), mine: who === m.owner, ready: true });
  }
  if (op === "set_based") {
    return answer(200, { set: params.get("set"), models: state.empty ? [] : RPC.set_based({ set_number: params.get("set") })
      .map((row) => ({ ...apiCard(row), based: row.based })) });
  }
  // A view counted, a build finished: it went.
  if (method === "POST") return answer(200, { counted: true });
  const pool = mine ? { mine: POOL } : {};
  if (op === "list") {
    const { query, said, refused } = galleryQuery(params, mine, who);
    if (refused) return refused;
    // Before gallery_tabs.sql: none of its words (api/share.js gallery).
    if (!APPLIED && (query.days || query.made || query.following)) {
      return answer(400, { error: "Following, Made and Top's time windows are not here yet: they come with the gallery's next update." });
    }
    // A gallery with nothing in it yet (state.empty): the cold start.
    const rows = state.empty ? [] : listModels(query);
    const models = rows.slice(0, PER_PAGE).map(apiCard)
      .map((one) => (mine ? { ...one, liked: likes(state, one.id), likes: likeCount(state, one.id) } : one));
    return answer(200, { ...said, per_page: PER_PAGE, more: rows.length > PER_PAGE, models,
      kinds: KINDS, sizes: Object.entries(SIZES).map(([key, one]) => ({ id: key, label: one.label })),
      sorts: Object.entries({ ...SORTS, ...(mine ? MINE_SORTS : {}) }).map(([key, label]) => ({ id: key, label })),
      ...(APPLIED ? { windows: Object.entries(WINDOWS).map(([id, one]) => ({ id, label: one.label })),
        mades: Object.entries(MADES).map(([id, label]) => ({ id, label })), following: Boolean(mine) } : {}),
      score: SCORE, ...pool });
  }
  if (op === "shelves") {
    const own = mine ? { pool: ME } : {};
    // Signed in, whether Sam likes each, as on the list.
    const shown = (row) => (mine ? { ...apiCard(row), liked: likes(state, row.id), likes: likeCount(state, row.id) } : apiCard(row));
    const small = state.empty ? [] : listModels({ most: SIZES.small.most, sort: "top", size: SHELF + 1, ...own });
    const ready = mine && !state.empty ? listModels({ pool: ME, buildable: true, sort: "top", size: SHELF + 1 }) : [];
    return answer(200, { ...(mine ? { ...pool, ready: { models: ready.slice(0, SHELF).map(shown), more: ready.length > SHELF } } : {}),
      // No pick in a quiet week: the live gallery's (liveCommunity).
      pick: state.empty || LIVE ? null : { chosen: false, until: null, week: PICK.week,
        model: shown(listModels({ size: 1000, ...own }).find((one) => one.id === PICK.model)) },
      small: { size: "small", label: SIZES.small.label, most: SIZES.small.most, models: small.slice(0, SHELF).map(shown),
        more: small.length > SHELF }, score: SCORE,
      // Today in the gallery, as the daily cron keeps it (api/_featured.js):
      // Gatehouse Starter, listed in May and Tested, with nothing done with
      // it in the past 30 days; and a set of the LDraw library, which no one
      // likes from a card.
      ...(state.empty || LIVE ? {} : (() => {
        const day = new Date().toISOString().slice(0, 10);
        const why = { likes: 0, builds: 0, comments: 0, remixes: 0, tested: true };
        const featured = listModels({ size: 1000, ...own }).find((one) => one.id === FEATURED);
        return {
          featured: featured ? { day, why, said: featuredSaid(why, featured.listed_at, day), model: shown(featured) } : null,
          library: { day, why: { theme: "Castle", decade: "1980s" }, model: { id: "omr-6080-1", name: "King's Castle",
            parts: 674, licence: "cc-by-2.0", modelled_by: { name: "Stefan Frenz", page: "https://library.ldraw.org/omr/sets/9" },
            library: { set: "6080-1", theme: "Castle", year: 1984 } } },
        };
      })()),
      challenge: { id: CHALLENGE.id, title: CHALLENGE.title, state: CHALLENGE.state, starts_on: CHALLENGE.starts_on,
        ends_on: CHALLENGE.ends_on } });
  }
  if (op === "tested") {
    if (!who) return answer(401, { error: SIGN_IN });
    const m = shownModel(id);
    if (!m) return answer(404, { error: "there is no shared model at that link" });
    if (m.owner !== who) return answer(200, { id, mine: false, tested: null });
    const row = testRows().find((one) => one.model === id);
    return answer(200, { id, version: newestOf(id), tested: row ? { passed: true, by: "app", app: row.app, at: row.at,
      steps: row.steps, parts: row.parts, n: row.n, cleared: false, cleared_why: null,
      tests: Object.fromEntries(Object.entries(row.tests).map(([name, one], at) => [name, { ...one, said: TESTS_SAID[at] }])) } : null });
  }
  // The viewer's own request (?id=X), its pictures and the rest are the app's.
  return null;
}

/// The beta (api/_beta.js): open, 37 of its 100 spots given; the form
/// checked as the server checks it, and kept, which nothing here keeps.
const BETA_POOL = { pool: "beta", cap: 100, given: 37, left: 63 };
const BETA_AT = "2026-10-29T18:00:00Z";
function beta(method, body, who) {
  if (method === "GET") {
    return answer(200, { beta: "open", signed_in: Boolean(who), pool: BETA_POOL, early: false, test: false, application: null });
  }
  if (!who) return answer(401, { error: "Sign in to apply." });
  try {
    applicationOf(body);
  } catch (trouble) {
    if (trouble instanceof BetaRefusal) return answer(trouble.status, { error: trouble.message });
    throw trouble;
  }
  return answer(200, { beta: "open", signed_in: true, pool: BETA_POOL, early: false, test: false, mail: "dry",
    application: { status: "new", pool: "beta", early: false, spot: null, comp: "none", applied_at: BETA_AT,
      decided_at: null, month_starts_at: null, month_ends_at: null, may_apply_again_at: null } });
}

/// The owner's queue of the beta (api/admin.js ?op=beta): one new, with
/// what was read of it, and one approved, its month waiting for Pro.
function betaQueue() {
  const facts = { confirmed: true, made_at: BETA_AT, age_days: 12, models_kept: 3, models_shared: 1, same_inbox: 0,
    same_inbox_applied: 0 };
  const one = (account, email, status, more) => ({ account, email, status, early: false, spot: null,
    build: "A working crane with a slewing ring and a two-speed winch, then a harbour around it.", ai: "claude",
    background: "lego", background_line: "Ten years of Technic", link: "https://rebrickable.com/users/ada/mocs/",
    terms: "2026-10-29", signals: { domain: "example.com", disposable: false, quality: { words: 16, issues: [] } },
    applied_at: BETA_AT, decided_at: null, decided_by: null, note: null, comp: "none", comp_said: null,
    month_starts_at: null, month_ends_at: null, facts, decisions: [], ...more });
  return { beta: "open", tests: false, months: { billing: "off", live: "when Pro launches", test: "when billing is test" },
    pool: BETA_POOL, counts: { new: 1, waitlist: 0, approved: 1, declined: 0, early: 0, pending: 1 },
    applications: [one("00000000-0000-4000-8000-0000000000b1", "ada@example.com", "new", {}),
      one("00000000-0000-4000-8000-0000000000b2", "bo@example.com", "approved", { spot: 1, comp: "pending",
        comp_said: "Starts when Pro launches.", decided_at: BETA_AT, decided_by: "owner@example.com",
        decisions: [{ decision: "approved", note: "Good crane", by: "owner@example.com", at: BETA_AT }] })] };
}

/// /api/admin: the site's owner's page.
function admin(method, params, who, state) {
  if (!who) return answer(401, { error: SIGN_IN });
  if (!state.admin) return answer(404, { error: "not found" });
  const op = params.get("op") || "";
  if (method === "GET" && op === "beta") return answer(200, betaQueue());
  if (method === "POST") return answer(200, { ok: true });
  // A reported photo, to look at: a picture, which the flow serves.
  if (op === "photo") return null;
  const commentOf = (one) => one && { id: one.id, model: one.model, name: modelOf(one.model)?.name ?? null, version: one.version,
    step: one.step, body: one.body, at: one.at, edited_at: one.edited_at, hidden: Boolean(one.hidden_at),
    removed: Boolean(one.removed_at), removed_by: one.removed_by, handle: personOf(one.author)?.handle ?? null, email: emailOf(one.author) };
  const small = (m) => m && { id: m.id, name: m.name, parts: m.parts, builds: statsOf(m.id)[2], remixes: remixesOf(m.id).length,
    tested: TESTED.has(m.id) };
  const everyone = [...PEOPLE, ...NO_PROFILE];
  return answer(200, {
    accounts: ADMIN.accounts, signed_in_this_week: ADMIN.signed_in_this_week, connectors: ADMIN.connectors,
    email: { sender: "Brickworks <noreply@brickworks.diy>", borrowing: null },
    people: everyone.map((one) => ({ id: one.account, email: one.email, joined: one.created_at, last_sign_in: one.last_sign_in,
      connectors: ADMIN.connectors_of[one.account]?.[0] || 0, connector_seen: ADMIN.connectors_of[one.account]?.[1] || null }))
      .sort(byTime("last_sign_in")),
    gallery: MODELS.filter((one) => one.listed && one.published).sort(byTime("listed_at")).map((one) => ({ id: one.id, name: one.name,
      author: one.author, parts: one.parts, listed_at: one.listed_at, email: emailOf(one.owner) })),
    reports: ADMIN.reports.map((one) => {
      const about = modelOf(one.model);
      const photo = PHOTOS.find((p) => p.id === one.photo);
      return { id: one.id, model: one.model ?? null, handle: one.handle ?? null, collection: one.collection ?? null, reason: one.reason,
        note: one.note, contact: one.contact, at: one.at, name: about?.name ?? null, listed: about?.listed ?? null,
        email: about ? emailOf(about.owner) : null, comment: one.comment ? commentOf(COMMENTS.find((c) => c.id === one.comment)) : null,
        photo: photo ? { id: photo.id, words: photo.words, at: photo.at, hidden: false, removed: false, email: emailOf(photo.account) } : null };
    }),
    comments: [...COMMENTS].sort(byTime("at")).map(commentOf),
    barred: ADMIN.barred.map((one) => ({ ...one, email: emailOf(one.account) })),
    tested: testRows().map(({ model: id, n, at, app, parts, steps }) => ({ model: id, n, at, app, parts, steps, name: modelOf(id).name }))
      .sort(byTime("at")),
    picks: { now: { pick: null, chosen: false, until: null, week: PICK.week, model: small(modelOf(PICK.model)) },
      choices: ADMIN.choices.map((one) => ({ ...one, name: modelOf(one.model).name, shown: Boolean(shownModel(one.model)?.listed) })),
      week: WEEK.map((one) => ({ week: one.week, model: small(modelOf(one.model)) })) },
    challenges: CHALLENGES_LISTED,
    year: true,
  });
}

/// /api/oauth: what the connector's sign-in page asks (web/authorize.js).
function oauth(method, params, body, who) {
  const op = params.get("op") || "";
  // Your Claude connections, on your account page, and ending one.
  if (op === "connections") {
    return who ? answer(200, { connections: CONNECTIONS, before: true }) : answer(401, { error: SIGN_IN });
  }
  if (op === "disconnect") return who ? answer(200, { disconnected: 1 }) : answer(401, { error: SIGN_IN });
  const given = method === "GET" ? Object.fromEntries(params) : { ...(body && typeof body === "object" ? body : {}) };
  delete given.op;
  if (!given.client_id) return answer(400, { refuse: "Brickworks does not know the app that sent you here. Go back to it and add Brickworks again." });
  let to;
  try {
    to = new URL(given.redirect_uri || "https://claude.ai/api/mcp/auth_callback");
  } catch {
    return answer(400, { refuse: "The app that sent you here asked to be answered at an address it did not declare, so Brickworks will not send you there." });
  }
  const back = (query) => {
    const url = new URL(to);
    for (const [key, value] of Object.entries({ ...query, state: given.state || "", iss: ORIGIN })) url.searchParams.set(key, value);
    return url.href;
  };
  const refused = given.response_type !== "code" ? back({ error: "unsupported_response_type", error_description: "only response_type=code" })
    : !/^[A-Za-z0-9_-]{43}$/.test(given.code_challenge || "") || given.code_challenge_method !== "S256"
      ? back({ error: "invalid_request", error_description: "PKCE is required: code_challenge with code_challenge_method=S256" }) : null;
  const loopback = to.protocol === "http:" && ["127.0.0.1", "localhost", "[::1]"].includes(to.hostname);
  if (op === "check") {
    if (refused) return answer(200, { back: refused });
    const client = /(^|\.)claude\.(ai|com)$/.test(to.host) ? "Claude" : loopback ? "Claude Code" : "An MCP client";
    return answer(200, { client, client_name: client === "An MCP client" ? null : client,
      return_to: loopback ? `${to.hostname}:${to.port || "80"}` : to.host || to.protocol, loopback });
  }
  if (method !== "POST") return answer(400, { error: "invalid_request", error_description: `unknown op ${op}` });
  if (op === "remembered") return who ? answer(200, { ask: true }) : answer(401, { error: SIGN_IN });

  return answer(400, { error: "invalid_request", error_description: `unknown op ${op}` });
}

/// /api/account: where to sign in, and who is signed in.
function account(method, params, body, who, state) {
  // The account deleted, with its address typed again.
  if (method === "POST" && params.get("op") === "delete") {
    if (!who) return answer(401, { error: SIGN_IN });
    return String(body?.confirm || "").toLowerCase() === EMAIL ? answer(200, { deleted: true, photos: 0 })
      : answer(422, { error: "Type your email address exactly as you sign in with it to delete this account." });
  }
  // The age question answered: it went, 13 or over.
  if (method === "POST" && params.get("op") === "age") {
    if (!who) return answer(401, { error: SIGN_IN });
    if (state.fresh) state.fresh.aged = true;
    return answer(200, { age: { ask: false, over_13: true } });
  }
  // The theme on the account (supabase/theme.sql): state.theme, or never
  // chosen; one sent is kept (state.theme is the caller's to change).
  if (params.get("op") === "theme") {
    if (!who) return answer(401, { error: SIGN_IN });
    if (method === "POST") return answer(200, { theme: body?.theme, kept: true });
    return answer(200, { theme: state.theme || "system", chosen: Boolean(state.theme), ready: true });
  }
  if (method !== "GET") return answer(405, { error: "GET, or POST ?op=age" });
  const base = { enabled: true, url: DB, key: PUBLISHABLE, assistant: "own_key", parts_url: null };
  if (!who) return answer(200, { ...base, signed_in: false });
  // A new account (state.fresh) is asked until it answers.
  const ask = state.askAge === true || Boolean(state.fresh && !state.fresh.aged);
  return answer(200, { ...base, signed_in: true, email: EMAIL, master: state.admin === true,
    age: { ask, over_13: ask ? null : true } });
}

/// The sign-in service (DB/auth/v1/...): a session for EMAIL for any code
/// or refresh token (the owner's page renews its own on every load).
function supabase(url, method) {
  if (method === "POST" && ["/auth/v1/token", "/auth/v1/verify"].includes(url.pathname)) return answer(200, session());
  return null;
}

/// One browser request, answered as the deployment would: {status, json},
/// or null for what is not answered here (a picture, a page, the app's own).
export function apiAnswer(asked) {
  const said = answered(asked);
  // Each person in it with their own picture, as api/_faces.js gives it.
  if (said && said.json && typeof said.json === "object") facesOn(said.json, facesNow());
  return said;
}

function answered({ url, method = "GET", body, state = {} }) {
  const where = url instanceof URL ? url : new URL(String(url));
  const verb = String(method || "GET").toUpperCase();
  if (where.origin === DB) return supabase(where, verb, body);
  if (where.origin !== new URL(ORIGIN).origin) return null;
  const found = /^\/api\/([a-z]+)\/?$/.exec(where.pathname);
  if (!found) return null;
  const who = state.signedIn ? ME : null;
  const params = where.searchParams;
  if (verb === "OPTIONS") return answer(204, null);
  switch (found[1]) {
    case "account": return account(verb, params, body, who, state);
    case "otp": {
      const email = String(body?.email || "").trim();
      if (verb !== "POST") return answer(405, { error: "POST only" });
      return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) ? answer(200, { ok: true, expires_in_minutes: 10 })
        : answer(422, { error: "That is not an email address." });
    }
    case "people": return people(verb, params, body, who, state);
    case "share": return share(verb, params, who, state, body);
    case "admin": return admin(verb, params, who, state);
    case "oauth": return oauth(verb, params, body, who);
    // What you own (api/collection.js): the sets and loose parts.
    case "collection": return who ? answer(200, OWNED_SETS) : answer(401, { error: SIGN_IN });
    // The interest form (api/plans.js): its refusals in its words, and
    // anything it takes answered as kept, which nothing here keeps.
    case "plans": {
      if (params.get("op") === "beta") return beta(verb, body, who, state);
      if (verb !== "POST") return answer(405, { error: "POST {email, plan, billing, note} or {email, forget: true}" });
      try {
        return answer(200, { said: entryOf(body).forget ? GONE : KEPT });
      } catch (trouble) {
        return answer(422, { error: trouble.message });
      }
    }
    default: return null;
  }
}

// ---------------------------------------------------------------------------
// The site in a browser, as deploy.sh serves it.

const TYPES = { ".html": "text/html; charset=utf-8", ".css": "text/css", ".js": "text/javascript",
  ".json": "application/json", ".png": "image/png", ".webp": "image/webp", ".svg": "image/svg+xml",
  ".xml": "application/xml", ".txt": "text/plain", ".webmanifest": "application/manifest+json" };
const PICTURE = readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), "../../web/share.png"));

/// A file of [web] at the address deploy.sh serves it: bare names, / for
/// the landing page, /oauth/authorize for the connector's sign-in, and the
/// 404 page for anything else.
function staticFile(web, pathname) {
  const named = { "/": "index.html", "/oauth/authorize": "authorize.html" }[pathname.replace(/\/$/, "") || "/"];
  const candidates = named ? [named] : [pathname.slice(1), `${pathname.slice(1).replace(/\/$/, "")}.html`];
  for (const name of candidates) {
    if (!name || name.includes("..")) continue;
    const file = path.join(web, name);
    if (existsSync(file) && !file.endsWith(path.sep)) {
      try {
        return { status: 200, body: readFileSync(file), type: TYPES[path.extname(file)] || "application/octet-stream" };
      } catch { /* a directory: the next one */ }
    }
  }
  return { status: 404, body: readFileSync(path.join(web, "404.html")), type: TYPES[".html"] };
}

/// A person's own picture (api/people.js ?op=avatar): its bytes, null for
/// one that may not be shown, undefined for a request that is not one.
function avatarFile(url) {
  if (url.pathname !== "/api/people" || url.searchParams.get("op") !== "avatar") return undefined;
  const id = url.searchParams.get("id");
  return [...facesNow().values()].includes(id) ? AVATARS.find((one) => one.id === id).bytes : null;
}

const isPicture = (url) => /^\/m\/[A-Za-z0-9]{10}(\/v\/\d+)?\.(png|webp)$/.test(url.pathname)
  || (url.pathname === "/api/people" && url.searchParams.get("op") === "photo_file");

/// Every request of [context] answered as a deployment of [web] and [api]
/// would: their files, the server's pages made by [api]'s handlers (with
/// the security policy they send), every API call by apiAnswer with
/// [state], and the sign-in service. With [remote] the pages are that
/// deployment's ([headers] sent with each) and only the API is answered
/// here, as its Supabase project [remoteDb] where the page asks that.
export async function serveSite(context, { web, api, remote = "", headers = {}, remoteDb = "", state = {} }) {
  const asProject = (text) => (remoteDb ? text.split(DB).join(remoteDb) : text);
  await context.route(/.*/, async (route) => {
    const request = route.request();
    const url = new URL(request.url());
    // A deployment's pages may reach only its own Supabase project (their
    // policy), so there the stand-in answers as that project.
    const db = url.origin === DB || url.origin === remoteDb;
    const ours = url.origin === ORIGIN || db || (remote && url.origin === new URL(remote).origin);
    // Anything else to whatever else answers it (browser.mjs quiets the
    // visit counter); nothing else is fetched from here.
    if (!ours) return route.fallback();
    if (isPicture(url)) return route.fulfill({ status: 200, contentType: "image/png", body: PICTURE });
    // A part's geometry, which a model's Parts list draws each lot from
    // (web/part-pictures.js): a deployment's from its own store, here from
    // this checkout's catalogue, as the store serves it.
    const mesh = db && /^\/storage\/v1\/object\/public\/parts\/([0-9a-f]{8,64})\.lbm$/.exec(url.pathname);
    if (mesh) {
      if (remote) return route.fallback();
      const file = path.join(web, "..", "assets", "generated", "parts", `${mesh[1]}.lbm`);
      return existsSync(file)
        ? route.fulfill({ status: 200, contentType: "application/octet-stream", body: readFileSync(file),
          headers: { "access-control-allow-origin": "*", "cache-control": "public, max-age=31536000, immutable" } })
        : route.fulfill({ status: 400, contentType: "application/json", body: '{"error":"not_found"}',
          headers: { "access-control-allow-origin": "*" } });
    }
    const face = avatarFile(url);
    if (face !== undefined) {
      return face ? route.fulfill({ status: 200, contentType: "image/jpeg", body: face })
        : route.fulfill({ status: 404, contentType: "text/plain", body: "" });
    }
    if (db || url.pathname.startsWith("/api/")) {
      let body;
      try {
        body = request.postData() ? JSON.parse(request.postData()) : undefined;
      } catch {
        body = undefined;
      }
      const signedIn = Boolean(request.headers().authorization);
      // Asked as of the stand-in's own site and project, whichever answered.
      const asked = new URL(url.pathname + url.search, db ? DB : ORIGIN);
      const said = apiAnswer({ url: asked, method: request.method(), body, state: { ...state, signedIn } });
      if (!said) return route.fulfill({ status: 404, contentType: "application/json", body: "{}" });
      return route.fulfill({ status: said.status, contentType: "application/json", body: asProject(JSON.stringify(said.json)) });
    }
    if (remote) return route.continue({ headers: { ...request.headers(), ...headers } });
    if (/^\/(m|u|c|library\/set)\//.test(url.pathname) || /^\/(collections|oembed)\/?$/.test(url.pathname)) {
      const made = await serverPage(api, url.pathname + url.search);
      // With the security policy the server sends with it. A picture the
      // server makes (/m/X.cutout.png) as the bytes and type it answered:
      // sent as an empty page, every cut-out failed to draw, and a model's
      // page and a profile's banner said "No picture".
      // A model's file and its parts lists (/m/X.mpd, /m/X/parts.json)
      // as their own type, named as they download.
      const policy = made.headers?.["content-security-policy"];
      const named = made.headers?.["content-disposition"];
      return route.fulfill({ status: made.status, body: made.bytes ?? made.html,
        contentType: made.headers?.["content-type"] || "text/html; charset=utf-8",
        headers: { ...(policy ? { "content-security-policy": policy } : {}), ...(named ? { "content-disposition": named } : {}) } });
    }
    const file = staticFile(web, url.pathname);
    return route.fulfill({ status: file.status, contentType: file.type, body: file.body });
  });
}
