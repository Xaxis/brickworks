// The docs pictures' world, written into docs-site/pictures/answers/: the
// shared test account's own models and what the site and its database
// answer about them, for tools/web/docs_shots_flow.mjs's "use". Cards are
// api/_directory.js cardOf's, rules web/card.js rulesSaid's, the Tested mark
// api/_tested.js's, so a change to their shapes is one run of this away:
//
//   node tools/web/docs_world.mjs
//
// The models are this checkout's own examples (models/*.ldr, made by
// Brickworks), never a real person's; their pictures are
// docs-site/pictures/files/<id>.webp, rendered with tools/probe.sh
// render_probe --view=hero --look=product --transparent=1.
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
const wt = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
const outDir = path.join(wt, "docs-site/pictures/answers");
const dir = await import(pathToFileURL(path.join(wt, "api/_directory.js")).href);
const cards = await import(pathToFileURL(path.join(wt, "web/card.js")).href);
const tested = await import(pathToFileURL(path.join(wt, "api/_tested.js")).href);
const fs = await import("node:fs");
const TB = "d0c5d0c5-d0c5-4d0c-8d0c-d0c5d0c5d0c5";
const BY = { handle: "test-builder", name: "Test builder" };
const EMAIL = "you@example.com";
const M = [
  ["DocsSprt01", "sports_car", "Sports car and its driver", 187, 35, "vehicle", ["car", "sports", "racing"],
    { tested: true, made_with: "hand", builds: 14, likes: 23, remixes: 2, comments: 3, moves: ["steering"],
      description: "A red two-seater with its driver, and a steering wheel that turns the front wheels. "
        + "Built to be built: each step stands on its own." }],
  ["DocsShop01", "corner_shop", "Corner shop", 797, 104, "town", ["modular", "shop", "town"],
    { tested: true, made_with: "hand", builds: 11, likes: 31, remixes: 1, comments: 4 }],
  ["DocsFire01", "station", "Fire station", 535, 120, "town", ["fire", "station", "town"],
    { tested: true, made_with: "assistant", builds: 9, likes: 19, remixes: 1, comments: 2 }],
  ["DocsOwl001", "barn_owl", "Barn owl", 1032, 130, "nature", ["owl", "bird", "animal"],
    { tested: false, made_with: "assistant", builds: 7, likes: 27, comments: 1 }],
  ["DocsRckt01", "three_core_rocket", "Three-core rocket", 353, 65, "space", ["rocket", "space"],
    { tested: true, made_with: "assistant", builds: 6, likes: 15, remixes: 1 }],
  ["DocsOrry01", "orrery", "Orrery", 520, 136, "mechanism", ["orrery", "planets", "technic"],
    { tested: false, made_with: "hand", builds: 5, likes: 12, technic: true, moves: ["crank"] }],
  ["DocsKart01", "kart", "Technic go-kart", 57, 20, "vehicle", ["technic", "kart"],
    { tested: true, made_with: "hand", builds: 8, likes: 9, technic: true, moves: ["steering"] }],
  ["DocsLite01", "lighthouse", "Lighthouse", 84, 12, "architecture", ["lighthouse", "coast"],
    { tested: true, made_with: "hand", builds: 6, likes: 8 }],
  ["DocsHous01", "house", "Little house", 71, 10, "town", ["house", "town"],
    { tested: false, made_with: "hand", builds: 5, likes: 6 }],
  ["DocsTree01", "tree", "Tree", 69, 9, "nature", ["tree"], { tested: true, made_with: "hand", builds: 4, likes: 5 }],
  ["DocsRock01", "rocket", "Rocket", 68, 10, "space", ["rocket", "space"],
    { tested: true, made_with: "hand", builds: 3, likes: 4 }],
  ["DocsBoat01", "boat", "Boat", 49, 8, "vehicle", ["boat", "water"],
    { tested: false, made_with: "hand", builds: 2, likes: 3 }],
];
const day = (n) => `2026-10-${String(30 - n).padStart(2, "0")}T10:00:00Z`;
const rows = M.map(([id, file, name, parts, steps, kind, tags, x], n) => ({
  id, name, author: BY.name, parts, has_image: true, has_thumb: true, listed_at: day(n), updated_at: day(n),
  kind, tags, licence: "cc-by-4.0", steps, own_steps: true, technic: false, views: 0, likes: 0, builds: 0,
  remixes: 0, comments: 0, by: BY, tested: false, made_with: null, moves: [], motions: [], ...x,
  description: x.description || null, _file: file }));
const byId = Object.fromEntries(rows.map((r) => [r.id, r]));
const dbRow = (r) => { const { _file, description, ...rest } = r; return rest; };
const card = (r) => {
  const c = dir.cardOf("https://brickworks.diy", dbRow(r));
  return { ...c, url: `/m/${r.id}`, image: `/m/${r.id}.png`, thumb: c.thumb.replace("https://brickworks.diy", "") };
};
const main = rows[0];
const LISTS = [
  { id: "DocsList01", name: "Cars to build", public: true, models: ["DocsSprt01", "DocsKart01", "DocsBoat01", "DocsRckt01"],
    description: "Things with wheels, and a boat.", followers: 4 },
  { id: "DocsList02", name: "Small and quick", public: true, models: ["DocsLite01", "DocsHous01", "DocsTree01", "DocsRock01"],
    description: "Under 100 parts each.", followers: 2 },
  { id: "DocsList03", name: "Town", public: true, models: ["DocsShop01", "DocsFire01", "DocsHous01"], description: null,
    followers: 1 },
  { id: "DocsList04", name: "Ideas for later", public: false, models: ["DocsOwl001"], description: null, followers: 0 },
];

// ---- what anyone is answered: the gallery, a model's page, collections, the challenge
const A = {};
for (const r of rows) A[`/m/${r.id}.webp`] = { file: `docs-site/pictures/files/${r.id}.webp` };
A[`/m/${main.id}.cutout.png`] = { file: `docs-site/pictures/files/${main.id}.cutout.png` };
A[`/m/${main.id}.png`] = { file: `docs-site/pictures/files/${main.id}.cutout.png` };
A["/api/share?op=list"] = {
  q: "", sort: "top", page: 1, per_page: 24, more: false, models: rows.map(card),
  kinds: dir.KINDS, sizes: Object.entries(dir.SIZES).map(([id, s]) => ({ id, label: s.label })),
  sorts: Object.entries(dir.SORTS).map(([id, label]) => ({ id, label })),
  windows: Object.entries(dir.WINDOWS).map(([id, one]) => ({ id, label: one.label })),
  mades: Object.entries(dir.MADES).map(([id, label]) => ({ id, label })), following: false, score: dir.SCORE };
A["/api/share?op=shelves"] = {
  pick: { chosen: false, week: { builds: 4, remixes: 1, tested: true }, model: card(main) },
  small: { models: rows.filter((r) => r.parts < 200).map(card).slice(0, 8), more: false }, score: dir.SCORE };
A["/api/plans?op=beta"] = { beta: "off" };
A["/api/plans?op=beta_spots"] = { beta: "off" };
A["/api/share?op=seen"] = { status: 204, body: {} };
A[`/api/people?op=comments&id=${main.id}`] = { model: main.id, ready: true, version: 1, newest: 1, open: true,
  replies: true, count: 0, comments: [], you: { signed_in: false, may_write: false,
    why_not: "Sign in to add a comment: we email you a code, no password.", owner: false } };
A["/api/people?op=follows&handle=test-builder"] = { handle: "test-builder", ready: true, followers: 6, following: 0,
  shows: true, you_follow: false, mine: false, may: false,
  why_not: "Sign in to follow people: we email you a code, no password.", signed_in: false };
const listCard = (l) => ({ id: l.id, name: l.name, count: l.models.length, followers: l.followers, by: BY,
  covers: l.models.slice(0, 4).map((id) => card(byId[id]).thumb) });
const shownLists = LISTS.filter((l) => l.public);
A["/api/people?op=collections"] = { ready: true, searched: true, sort: "recent", page: 1, total: shownLists.length,
  pages: 1, collections: shownLists.map(listCard) };
A["/api/people?op=list_follows"] = { follows: Object.fromEntries(shownLists.map((l) => [l.id, { id: l.id, ready: true,
  followers: l.followers, you_follow: false, mine: false, may: true, signed_in: false }])), signed_in: false };
const RULES = { most_parts: 1500, set_number: null, set_name: null, tested: true };
const entry = (id, way, at) => ({ ...card(byId[id]), way, entered_at: at, keeps: true, votes: null, winner: false, won: [] });
const CHALLENGE = { id: 7, title: "Wheels and tracks", brief: "Build something that rolls: a car, a cart, a train or a rover, in under 1,500 parts.",
  starts_on: "2026-11-01", ends_on: "2026-11-30", state: "open", test: false, settled: false,
  rules: { most_parts: 1500, set: null, tested: true }, rules_said: cards.rulesSaid(RULES),
  days_said: "1 November 2026 to 30 November 2026",
  groups: [
    { way: "hand", label: "Built by hand", entries: [entry("DocsSprt01", "hand", "2026-11-02T10:00:00Z"), entry("DocsKart01", "hand", "2026-11-03T10:00:00Z")] },
    { way: "assistant", label: "Built with the assistant", entries: [entry("DocsRckt01", "assistant", "2026-11-04T10:00:00Z")] },
  ], winners: [] };
A["/api/people?op=challenge"] = { ready: true, year: true, challenge: CHALLENGE,
  next: { id: 8, title: "Winter lights", brief: "A scene with lights in the windows: a street, a station, a cabin.", starts_on: "2026-12-01", ends_on: "2026-12-31" },
  past: [] };

// ---- what the database answers a page the server makes (/m/DocsSprt01)
const D = {};
D["rest/v1/rpc/directory_model"] = { ...dbRow(main), description: main.description, listed: true, from: [], remixes_listed: [] };
D["rest/v1/rpc/directory_models"] = rows.slice(1, 7).map(dbRow);
D[`rest/v1/share_versions?model=eq.${main.id}`] = [{ n: 1, at: day(0), note: null, parts: main.parts, steps: main.steps,
  bytes: main.parts * 117, has_image: true, changes: null, first_changed: null, remixed_from_version: null }];
D[`rest/v1/shared_models?id=eq.${main.id}`] = [{ id: main.id, owner: TB, test: false }];
D[`storage/v1/object/shared-models/${main.id}.mpd`] = { file: `models/${main._file}.ldr` };
D["rest/v1/people?"] = [{ account: TB, handle: BY.handle, name: BY.name }];
D["rest/v1/rpc/shown_publicly"] = true;
D["rest/v1/rpc/model_lists"] = [];
D["rest/v1/rpc/model_bases_of"] = [];
D["rest/v1/rpc/avatars_of"] = [];
D["rest/v1/build_photos?"] = [];
// Its Tested mark, as the app's four tests found it (api/_tested.js).
const TESTED = { n: 1, at: day(0), app: "0.3.0", parts: main.parts, steps: main.steps, passed: true, cleared_at: null,
  cleared_why: null, tests: { stands: { ok: true, why: "every step stands on what is under it" },
    steps: { ok: true, why: "each part goes on from where it is shown" },
    parts: { ok: true, why: "every part is made in its colour" }, whole: { ok: true, why: "every part holds on" } } };
D[`rest/v1/share_tests?model=eq.${main.id}`] = [TESTED];

const world = { "$comment": "The docs pictures' world: the shared test account's own models (Test builder, "
  + "you@example.com), what the site answers about them and what its database answers a page the server makes. "
  + "Pictures in docs-site/pictures/files/, from tools/probe.sh render_probe of models/*.ldr. "
  + "Written by tools/web/docs_world.mjs: change it there.", answers: A, db: D };
fs.writeFileSync(`${outDir}/test-account.json`, JSON.stringify(world, null, 1) + "\n");

// ---- signed in as the test account
const S = {};
S["/api/account"] = { enabled: true, url: "https://sign-in.example", key: "docs", assistant: "own_key", parts_url: null,
  signed_in: true, email: EMAIL, master: false, age: { ask: false, over_13: true }, beta: { tester: false, early: [] } };
S["https://sign-in.example/auth/v1/token"] = { access_token: "docs", token_type: "bearer", expires_in: 3600,
  refresh_token: "docs", user: { id: TB, email: EMAIL } };
S["/api/account?op=theme"] = { theme: "system", chosen: false, ready: true };
S["/api/people?op=feed_count"] = { count: 5, notifications: 2, feed: 3, signed_in: true, ready: true, me: BY };
S["/api/people?op=me"] = { profile: { handle: BY.handle, name: BY.name, bio: "Cars, little shops and the odd owl, each with its steps.",
  created_at: "2026-05-11T09:00:00Z" },
  collections: LISTS.map((l) => ({ id: l.id, name: l.name, public: l.public, updated_at: "2026-11-02T10:00:00Z",
    description: l.description, count: l.models.length })),
  mail: { comments: true, models: true, versions: false, photos: false, remixes: false, ready: true, kinds: true },
  follows: { ready: true, shows_follows: false },
  showcase: { ready: true, links: [], banner: main.id, pins: [], models: rows.map((r) => ({ id: r.id, name: r.name, picture: true })) },
  avatar: { ready: true, picture: null, removed: false }, likes: { ready: true, shows_likes: false } };
const levels = [["designer", 12, 3, 6, 10, 25], ["built", 80, 3, 6, 50, 100], ["builder", 0, 0, 5, 0, 1],
  ["remixed", 5, 2, 4, 5, 25], ["tested", 8, 2, 4, 5, 10], ["challenger", 2, 1, 4, 1, 3]];
S["/api/people?op=profile&handle=test-builder"] = { handle: BY.handle, name: BY.name,
  bio: "Cars, little shops and the odd owl, each with its steps.", since: "2026-05-11T09:00:00Z", models_count: rows.length,
  likes: rows.reduce((s, r) => s + r.likes, 0), followers: 6, following: 0,
  designer: { models: rows.length, builds: rows.reduce((s, r) => s + r.builds, 0), remixes: 5, comments: 10, tested: 8,
    likes: rows.reduce((s, r) => s + r.likes, 0), builders: 9, followers: 6, photos: [] },
  collections: shownLists.map((l) => ({ id: l.id, name: l.name, description: l.description, count: l.models.length })),
  built: [], url: "/u/test-builder", page: 1, per_page: 24, more: false, models: rows.map(card), liked_count: null,
  banner: main.id, pins: [],
  achievements: [
    { id: "designer", level: 3, name: "Designer · ten models", said: "Level 3 of 6: 12 models listed in the gallery" },
    { id: "built", level: 3, name: "Built · fifty times", said: "Level 3 of 6: 80 builds finished to the last step" },
    { id: "tested", level: 2, name: "Tested · five models", said: "Level 2 of 4: 8 models marked Tested" },
    { id: "remixed", level: 2, name: "Remixed · five times", said: "Level 2 of 4: 5 remixes" },
    { id: "challenger", level: 1, name: "Challenger · first challenge", said: "Level 1 of 4: 2 challenges entered" }],
  levels: levels.map(([track, n, level, of, reached, next]) => ({ track, n, level, of, reached, next })) };
S["/api/people?op=favourites"] = { page: 1, per_page: 24, more: false, models: [card(byId.DocsShop01), card(byId.DocsOwl001)] };
S["/api/people?op=following"] = { mine: true, ready: true, following: [] };
S["/api/people?op=alike"] = { handle: BY.handle, name: BY.name, designers: [], yours: true };
S["/api/people?op=follows&handle=test-builder"] = { handle: BY.handle, ready: true, followers: 6, following: 0, shows: true,
  you_follow: false, mine: true, may: false, why_not: "That is you.", signed_in: true };
S[`/api/people?op=marks&id=${main.id}`] = { liked: false, favourite: true, collections: LISTS.map((l) => ({ id: l.id,
  name: l.name, public: l.public, has: l.models.includes(main.id) })) };
S[`/api/people?op=challenge_entry&id=${main.id}`] = { mine: true, ready: true, challenge: { id: CHALLENGE.id,
  title: CHALLENGE.title, starts_on: CHALLENGE.starts_on, ends_on: CHALLENGE.ends_on,
  days_said: "1 Nov 2026 to 30 Nov 2026", rules_said: CHALLENGE.rules_said, rules: RULES },
  entry: null, entries: 0, in_gallery: true, keeps: true, broken: [] };
S[`/api/people?op=comments&id=${main.id}`] = { model: main.id, ready: true, version: 1, newest: 1, open: true,
  replies: true, count: 0, comments: [], you: { signed_in: true, may_write: true, why_not: "", owner: true } };
// The designer's own page asks what only its owner is told.
S[`/api/share?op=bases&id=${main.id}`] = { bases: [], mine: true, ready: true };
S[`/api/share?op=tested&id=${main.id}`] = { id: main.id, version: 1, tested: tested.ownerMark(TESTED) };
S[`/api/people?op=photos&id=${main.id}`] = { model: main.id, owner: true, photos: [], mine: [], left: 3 };
S["/api/orangecheck?op=status"] = { ready: true, did: false, only: false, fresh: false };
S["/api/oauth?op=connections"] = { connections: [], before: false };
S["/api/plans?op=feedback"] = { beta: false, reports: [] };
const signed = { "$comment": "Signed in as the shared test account (you@example.com), over test-account.json. "
  + "Written by tools/web/docs_world.mjs: change it there.",
  answers: S, storage: { "brickworks.session": { refresh_token: "docs", email: EMAIL, user_id: TB,
    url: "https://sign-in.example", key: "docs" } } };
fs.writeFileSync(`${outDir}/signed-in.json`, JSON.stringify(signed, null, 1) + "\n");
console.log("world:", Object.keys(A).length, "answers,", Object.keys(D).length, "db;", Object.keys(S).length, "signed in");
