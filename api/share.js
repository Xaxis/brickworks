// Sharing a model by link (2026-10-12).
//
// Someone signed in publishes the model they have open, from File ›
// Share… in the app, and gets https://brickworks.diy/m/<id>. Anyone may
// open that link without an account: the app in a read-only mode
// (/app?view=<id>) with the model, its steps, its booklet and its parts
// list, and Open in Brickworks to copy it into their own account.
//
//   GET  ?id=X               the model, as the viewer loads it: name,
//                            author, part count and the .mpd itself, which
//                            version it is and what each version changed;
//                            with v=N, version N's .mpd
//   GET  ?op=page&id=X       /m/X: the link's own page — a title and a
//                            picture for anything that previews links,
//                            and then the viewer; with v=N, /m/X/v/N, an
//                            older version's, marked as older; with
//                            lang=de (fr, es), /de/m/X, its copy in German
//   GET  ?op=image&id=X      /m/X.png: that picture, rendered by the app
//                            when it published; with v=N, /m/X/v/N.png
//   GET  ?op=cutout&id=X     /m/X.cutout.png: the same with nothing behind
//                            the model, which its page shows on the theme's
//                            own ground; the picture itself for a model
//                            published before there was one; with v=N,
//                            /m/X/v/N.cutout.png
//   GET  ?op=embed&id=X      /m/X/embed: a card for a blog or a forum to
//                            put in an iframe
//   GET  ?op=oembed&url=L    /oembed: oEmbed's answer for a model's link
//                            L (its card's iframe, name, credit and
//                            picture), which /m/X's head names for
//                            WordPress, a forum or Iframely to find
//   GET  ?op=file&id=X       /m/X.mpd: the model's file, as it is stored,
//                            to download (with v=N, /m/X/v/N.mpd, version
//                            N's), named for the model
//   GET  ?op=parts&id=X      /m/X/parts.json: its parts list, as the app's
//                            parts list counts it (api/_parts.js); as=xml
//                            (/m/X/parts.xml) a BrickLink wanted list,
//                            as=csv (/m/X/parts.csv) a Rebrickable parts
//                            list, as=pab (/m/X/parts-pab.csv; past 400
//                            elements as=pab-2, /m/X/parts-pab-2.csv, and
//                            on) a LEGO® Pick a Brick list, each to
//                            download; with v=N, version N's
//   GET  ?op=parts_missing&id=X  with the session: what the person is
//                            missing of that list, and the three shops'
//                            lists of only those (the Parts tab's What
//                            you're missing, ownedparts); with v=N, of
//                            version N's; never kept by the CDN
//   GET  ?op=scene&id=X      /m/X/scene.json: the model packed for its page's
//                            3D view (api/_parts.js sceneOf), every part's
//                            place, turn and colour, its geometry in the
//                            store; with v=N, version N's
//   GET  ?op=room&id=X       /m/X/room.json: what its page writes the GLB the
//                            app's Export writes of it from, to place it in
//                            a room (api/_parts.js roomOf, web/room.js);
//                            with v=N, version N's
//   GET  ?op=thumb&id=X      /m/X.webp: the small picture the gallery's
//                            cards show, made by the app beside the big one
//   GET  ?op=clip&id=X&as=K  /m/X.mp4 (K mp4) or /m/X.webm (K webm): the
//                            model turning once round, 4 s or less, which
//                            /m/X's head names in og:video and a
//                            twitter:card player, so a link pasted into
//                            Discord, Slack or X turns (supabase/
//                            model_clips.sql); with v=N only while it is
//                            of version N, and then kept longer by the CDN
//   GET  ?op=clip_need&id=X  the owner's own: which version is newest and
//                            what clip it has, so their visit to its page
//                            records one where it has none of that version
//                            (web/model-page.js, web/turntable-clip.js)
//   POST ?op=clip&id=X       the owner's browser sends that clip: {version,
//                            clip (base64)}, read here before it is kept
//                            (api/_clip.js readClip)
//   GET  ?op=list&page=N     /gallery's models: the listed ones, a page at
//                            a time, searched (q), filtered (kind, size,
//                            instructions, technic, tested, tag, made:
//                            hand or assistant) and sorted (sort: newest,
//                            views, likes, remixes, builds, top; window:
//                            week or month, Top's); with tests=1, test
//                            models too, which nobody else is shown
//   GET  ?op=shelves         /gallery's front: this week's pick and the small
//                            builds' shelf (supabase/discovery.sql); tests=1
//                            as the list
//   GET  ?op=list&mine=1     the list, with the session: each card's share of
//   GET  ?op=shelves&mine=1  its parts the person owns (owned) and whether
//                            they like it (liked), the sort owned (Parts I
//                            own), ready=1 (only what they can build now)
//                            and following=1 (the models of the people they
//                            follow) on the list, and the shelf of what
//                            they can build now on the front; never kept
//                            by the CDN
//   GET  ?op=tested&id=X     the owner's own: what the app found of the
//                            newest version, every test and why, passed
//                            or not (with v=N, version N's)
//   POST                     publish, with the session: {name, author?,
//                            model, image?, cutout?, thumb?, id?, listed?,
//                            remixed_from?, remixed_from_version?,
//                            description?, tags?, kind?, licence?, note?,
//                            tested?, made_with?, made_with_shown?, wip?}.
//                            tested is what the app found of the model as it
//                            published it (api/_tested.js); made_with who
//                            laid its parts, as the app knows it: hand,
//                            assistant or brickify (supabase/made_with.sql),
//                            kept for its owner; made_with_shown whether
//                            its owner chose to say so on its page, which
//                            nothing public says otherwise
//                            (supabase/made_with_shown.sql)
//   GET  ?op=made&id=X       the owner's own: {made_with, made_with_shown,
//                            ready}, for its page's More
//   POST ?op=made&id=X       the owner says whether it is shown: {shown}
//                            With an id, the owner's own link gets its
//                            next version, and the one before is kept.
//                            listed puts it in the gallery; remixed_from
//                            is the link it was copied from (Open in
//                            Brickworks), and remixed_from_version which
//                            version of it, which its page names; note is
//                            what its owner says changed. What it says
//                            about itself is kept on a republish that does
//                            not say it again. wip true shares the version
//                            as work in progress (api/_wip.js): marked so,
//                            in Talk and the feed, out of Top and the pick
//                            until a version is published without it,
//                            which finishes it.
//   POST ?op=finish          (session) {id}: the owner's work in progress
//                            called finished, its newest version the
//                            finished one (api/_wip.js)
//   GET  ?op=library         /library's sets: every set in the catalogue
//                            (api/_sets.js, sets364), those LDraw has a 3D
//                            model of marked, a page at a time: searched
//                            (q), filtered (theme, decade, year, size,
//                            model, figs) and sorted (sort); the LDraw
//                            shelf alone (api/_library.js) where this
//                            deployment has no catalogue
//   GET  ?op=catalog_set&set=N  /library/set/N: the set's page (&lang=de,
//                            /de/library/set/N, in German, fr and es too); with
//                            op=catalog_parts (/library/set/N/parts.json,
//                            .xml, .csv) its parts, op=catalog_photo
//                            (/library/set/N.webp, its card's, and
//                            N.page.webp, its page's, as=card|page) its own
//                            picture, Rebrickable's, from our storage,
//                            op=catalog_picture (/library/set/N.jpg) its
//                            picture drawn from its parts (api/_flatlay.js)
//                            where it has none, op=catalog_owned how much
//                            of it the person signed in owns
//   GET  ?op=sitemap_index   /sitemaps/index.xml: /sitemap.xml and the
//                            sets' own (op=sitemap_sets&n=K,
//                            /sitemaps/sets-K.xml), and the models' copies
//                            in each language (op=sitemap_models&lang=de,
//                            /sitemaps/models-de.xml)
//   GET  ?op=set&id=X        /library/X: a set's page, made as a model's
//                            page is; op=set_cover (/library/X.webp) its
//                            card's picture, with as=cutout
//                            (/library/X.cutout.webp) its page's, and
//                            as=cover (/library/X.cover.webp) the app's
//                            cover; op=set_file (/library/X.mpd) its file,
//                            op=set_parts (/library/X/parts.json, .xml,
//                            .csv) its parts, op=set_scene
//                            (/library/X/scene.json) its model for the
//                            page's 3D view, op=set_room
//                            (/library/X/room.json) for In your room
//   GET  ?op=bases&id=X      what X is based on, and whether the caller may
//                            change it; POST ?op=bases {model, bases} its
//                            designer's list; GET ?op=set_based&set=N the
//                            models based on set N (api/_bases.js) and the
//                            public lists it is in (api/_lists.js)
//   POST ?op=seen&id=X       its page was looked at: counted once a day per
//                            visitor, and never for a robot
//   POST ?op=built&id=X      {device, v?}: built to its last step, in the
//                            step player or the viewer: counted once per
//                            device, never for a robot (api/_builds.js)
//   POST ?op=unpublish&id=X  the owner takes it down, every version of it
//   POST ?op=pictures&id=X   {version, image, cutout?, thumb?}: the pictures
//                            of the version its owner has just published
//                            without any, put on it with no publish counted
//                            (the site's Share from a file draws its
//                            pictures once the server has the model)
//   GET  ?op=mine            the session's own links
//   GET  ?op=sweep           the daily clean-up (Vercel's cron, with
//                            CRON_SECRET): files no published row owns,
//                            and photos' files whose photo is gone; never
//                            more than a quarter of either unasked (held,
//                            and said: api/_cron.js sweepHeld)
//   GET  ?op=feature         the daily choice of the gallery's front (Vercel's
//                            cron, with CRON_SECRET): this week's pick,
//                            today's featured model and today's set from the
//                            LDraw library (api/_featured.js)
//   GET  ?op=omr             the weekly look at LDraw's Official Model
//                            Repository for what the library has not got
//                            (Vercel's cron, with CRON_SECRET; dry=1 says
//                            what it would write and writes nothing:
//                            api/_omr_watch.js)
//
// Where it is kept and who may touch it is in supabase/shared_models.sql.
// In short: a visitor's read asks for a published row and its public
// columns alone (the key a page holds reaches nothing in the database
// since supabase/no_client_access.sql), and the files are read only after
// that. Every write is here, after the session has been verified and the
// row found to be the caller's.
//
// The upload is checked at this edge, before anything is stored: LDraw
// text only (every line one of LDraw's six kinds, well formed, at least
// one part), at most 2 MB, a PNG picture of at most 600 KB, and a name.
// The part count is the server's own, counted here, not the client's.
//
// The gallery (2026-10-13, supabase/gallery.sql) shows what a person
// chose to list, and so names and pictures strangers chose: a name is one
// printable line of at most 80 characters, escaped wherever a page shows
// it; listing is counted (may_list) on top of publishing; and the site's
// owner can take any model out of it for good (api/admin.js).
//
// A test account's models (one signed in at a Resend test address, as
// every probe is: api/_auth.js isTestAccount) are marked a test when they
// are published, and no public list shows them (supabase/test_models.sql):
// the probes ran against the live site and their models were in its
// gallery, newest first, while they ran (2026-10-17). A probe asks with
// tests=1 to see them; such an answer is never kept by the CDN.
//
// Versions (2026-10-18, supabase/versions.sql, api/_versions.js): a
// republish is the link's next version, and the one before it is kept,
// its files renamed for its number (<id>.v<n>.mpd and .png) as the new one
// takes the link's own. What changed is worked out here from the two
// files: the parts by part and colour, the steps by number, and the first
// step that differs, which keeps a builder's place on the new one
// (src/assembly/build_steps.gd). A version is counted as a publish.
//
// The Tested mark (2026-10-18, supabase/tested.sql, api/_tested.js): the
// app tests a model as it publishes it — it stands at every step, every
// step can be reached, every part is made in its colour, nothing is loose —
// and sends what it found. It is kept with the version, as the app's own
// finding and the app version's, once it is found to be of this very file
// and the steps the file carries; this server cannot run the tests. A pass
// is shown on the page, the card and the viewer; a failure only to its
// owner; the site's owner can clear either (api/admin.js ?op=untest).
//
// The directory (2026-10-13, supabase/directory.sql, api/_directory.js)
// searches, filters and sorts the gallery, and gives each model a page of
// its own at /m/X: what its owner wrote about it, its tags, its kind and
// its licence, how many have looked, liked and remixed it, and its remix
// tree. The facts the filters use that are about the file — its steps,
// whether they are its builder's own, whether it is Technic — are counted
// here from the file, like the part count. Nothing a page does writes per
// request: a view is a beacon the page sends once a day (?op=seen), and
// counted once per visitor per day, never for a robot.
//
// The ground rules (2026-10-18, supabase/trust.sql, api/_trust.js): listing
// anything new needs the age question answered 13 or over. Accounts are for
// 13 and over (2026-11-03), so an account whose row still says under 13
// shares nothing new, by link or in the gallery, refused in words here and
// anything public again by the database.
//
// Real builds (2026-10-18, supabase/builds.sql, api/_builds.js): a model
// built to its last step is counted once per device (?op=built), "12 built"
// on its page and its card, and the gallery sorts by it; and its page has a
// strip of photos of people's real builds of it, with the way to add one
// (web/model-page.js), which api/people.js keeps.
//
// Discovery (2026-10-19, supabase/discovery.sql): the gallery sorts by Top
// builds, a score of builds finished, remixes and the Tested mark
// (_directory.js SCORE), and its front has this week's pick, worked out
// from the past seven days unless the site's owner chose one (api/admin.js),
// and a shelf of small builds, the Size filter's Small by Top builds
// (?op=shelves). Build with what I own (api/_owned.js): what a model needs,
// by part and colour, is counted from its file as it is published and
// kept (model_needs), so that a signed-in person's share of every model in
// the gallery is one join in the database (&mine=1).
//
// A front that changes by itself (gallery362, 2026-10-29,
// supabase/gallery_crons.sql): once a day the cron chooses this week's pick
// (on a week's first run), today's featured model and today's set from the
// LDraw library, from what people did (api/_featured.js), and keeps them;
// ?op=shelves reads what was kept. The owner's own pick still wins, and a
// list asked with tests keeps the pick worked out from the week, as the
// probes expect it.

import { noted } from "./_noted.js";
import { afterAnswer } from "./_after.js";
import { randomBytes } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { AuthError, bearer, isTestAccount, verify } from "./_auth.js";
import { cronNoted, isCron, sweepHeld } from "./_cron.js";
import { db, dbConfigured, orUnknown, reach } from "./_db.js";
import { raise } from "./_notify.js";
import { scopeOf } from "./_settings.js";
import { originOf } from "./_oauth.js";
import {
  ASSISTANT_TAGS, KINDS, LICENCES, MADES, MINE_SORTS, MOVES, NOTICE, SCORE, SHELF, SIZES, SORTS, TESTS_CACHE, Unacceptable, WINDOWS, cardOf,
  cleanDescription, cleanKind, cleanLicence, cleanTags, count, escapeHtml, isTechnic, kindLabel,
  LDRAW_FROM, listQuery, looksLikePerson, modelHash, modelledByOf, motionsIn, movesWords, partFacts,
  inLanguage, SITE_LANGS, asText, sayHtml, siteChrome, siteWords, summary, testsAsked, visitorKey,
} from "./_directory.js";
import { namesTrouble } from "./_names.js";
import { withoutPrivateLines } from "./_private_lines.js";
import { libraryCredit, storeBytes, storeFile, storeRoot } from "./_omr_credit.js";
// What the front leads with, chosen once a day; and the weekly look at the OMR.
import { featuredSaid, runFeatures } from "./_featured.js";
import { runOmrWatch } from "./_omr_watch.js";
// The LDraw library's sets, each a page made as a model's is (library333).
import {
  FROM as SET_FROM, PER_PAGE as SET_PER_PAGE, SET_ID, SET_SORTS, askOf, authorsIn, decades, fileSteps, librarySet,
  librarySets, searchSets, setCard, setModel, setTitle, themeOf, themes,
} from "./_library.js";
// A model's parts list from its file, as the app's (site278).
import { PICK_A_BRICK_LINES, PICK_A_BRICK_MOST, inventoryOf, inventoryOfLots, namesOf, paletteOf, partNames, partsTable,
  pickABrick, placedOf, rebrickableCsv, roomOf, sceneOf, wantedList } from "./_parts.js";
import { afterFields, keyOf, sectionKey } from "./_subfiles.js";
import { checkTested, markOf, ownerMark, publicMark } from "./_tested.js";
import { changedOf, changesBetween, lotSaid, readChanges, saidOf } from "./_versions.js";
// What a remix changed from the model it was copied from (supabase/remix_changes.sql).
import { changedLineHtml, changesAnswer, countAfter, ownChanges, treeHtml, treeOf, treeWithout } from "./_remix.js";
import { NOT_YET as WIP_NOT_YET, SHOWN as WIP_SHOWN, finish as finishWip, isWip, postVersion, wipReady } from "./_wip.js";
import { countSaid, sideSaid, stepCount, stepsSaid } from "./_steps.js";
import { publicTrouble, shownPublicly } from "./_trust.js";
import { freshPool, heldOf, keyed, missingOf, ownedKey, poolOf, readShard, shardOf } from "./_owned.js";
// Every set in the catalogue, a page each (sets364), and the picture drawn
// of one LDraw has no model of.
import {
  CREDIT as SETS_CREDIT, PER_PAGE as CATALOG_PER_PAGE, SETS_SORTS, askSets, catalogCard, catalogSet, modelsBySet, ownedOf,
  searchCatalog, setCatalog, setPage as catalogPage, setsBeside as catalogBeside, sitemapSets, themeTree, titleOf,
  yearsOf,
} from "./_sets.js";
import { drawModel, flatLayJpeg, pngOf } from "./_flatlay.js";
import { parseLbm } from "./_lbm.js";
import { heightOf, promptNow, promptOnPublish, runPrompts } from "./_prompts.js";
import { indexOf as searchIndex } from "./_search.js";
import { challengeLine, withWins } from "./_challenges.js";
// What a model is based on (docs/SOCIAL.md section 7, item 5).
import { bases, basesOf, basesPut, setBased, setFind } from "./_bases.js";
import { altRowsOf, altSaid, keepAlts } from "./_alts.js";
// The one model card, the browser's too (web/card.js): a model's remixes,
// more by its designer and similar models.
import { MADE_WITH, altHtml, basedHtml, cardHtml, counted, keepHtml, langAt, madeOf, madePublic, marksOf, number, photoAttrs, photoSrc, quietMarks,
  say, themeSaid } from "./_card.js";
// The kit, made in the card's file: the designer's avatar and the action
// bar's buttons.
import { avatarHtml, iconButtonHtml, iconHtml, shareSheetHtml } from "./_card.js";
// Whose picture to show beside their name (supabase/avatars.sql).
import { withFaces } from "./_faces.js";
import { blockedHandles, blockedModels, refuseFor, standingBetween, withoutBlocked } from "./_blocks.js";
// The public collections a model is in, each a card with its cover
// (supabase/collection_follows.sql).
import { coversOf, listCardHtml, listsOf } from "./_lists.js";
// A model's clip, read before it is kept (unit turntable).
import { CLIP_TYPES, MAX_CLIP_BYTES, readClip } from "./_clip.js";
import {
  BuildRefusal, UPLOADS, buildsOf, countBuild, deleteFiles as deleteBuildFiles, fromTheApp, photosWhere,
  sweepPhotos, uploadsLeft,
} from "./_builds.js";

export const MAX_MODEL_BYTES = 2 * 1024 * 1024;
export const MAX_IMAGE_BYTES = 600 * 1024;
export const MAX_THUMB_BYTES = 64 * 1024;
const MAX_NAME = 80;
const MAX_AUTHOR = 60;
// What changed, as its owner says it: a line or two (supabase/versions.sql).
const MAX_NOTE = 280;
// How many of a link's versions an answer names, newest first: a builder
// further back than this is told the model changed from step 1.
const VERSIONS_SHOWN = 100;
const VERSION = /^[1-9][0-9]{0,5}$/;
const BUCKET = "shared-models";
// The gallery's small pictures, in a bucket of their own
// (supabase/directory.sql): shared-models takes only its two kinds of file.
const THUMBS = "shared-thumbs";
// The clips, <id>.mp4 or <id>.webm, in theirs (supabase/model_clips.sql).
const CLIPS = "shared-clips";
/// Which bucket a file is in: the small pictures in theirs, the clips in
/// theirs. Before supabase/model_clips.sql storage lists the clips' as
/// empty and deletes nothing from it, 200 both (measured 2026-11-22).
const bucketOf = (name) => (name.endsWith(".webp") ? THUMBS : /[.](mp4|webm)$/.test(name) ? CLIPS : BUCKET);
const ID = /^[A-Za-z0-9]{10}$/;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
// What a visitor's key may read: the columns supabase/shared_models.sql
// and supabase/gallery.sql grant, which are all of them but the owner,
// barred and test.
const PUBLIC = "id,name,author,parts,bytes,has_image,published,updated_at,listed,remixed_from,"
  + "description,tags,licence,kind,has_thumb,modelled_by";
export const PER_PAGE = 24;
const MOST_PAGES = 400;
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const RIFF = Buffer.from("RIFF");
const WEBP = Buffer.from("WEBP");

function project() {
  return String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
}

/// Ten characters from an alphabet without the ones people misread
/// (0/O, 1/l/I): about 58 bits, so a link cannot be guessed.
function newId() {
  const bytes = randomBytes(10);
  let id = "";
  for (const byte of bytes) id += ALPHABET[byte % ALPHABET.length];
  return id;
}

// ---------------------------------------------------------------------------
// The model's text, checked.

const NUMBER = /^[-+]?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?$/;
const COLOUR = /^(\d+|0x[0-9A-Fa-f]{7})$/;
// How many numbers follow the line type and colour for each kind of line.
const COORDS = { 2: 6, 3: 9, 4: 12, 5: 12 };

// The pieces a hose, a tube, a flexible axle or a string is laid from
// along a bend, by the kind they are of (Flex.KINDS, src/assembly/flex.gd).
// A submodel of nothing but one kind's pieces is the one part a shop sells,
// as the app's parts list counts it (Inventory.of): a ribbed hose is two
// ends and thirty rings in the file and one hose to buy. A chain is its
// links, which are what is sold, and they count as themselves.
const FLEX_PIECES = new Map([
  ["71944k01", "ribbed_hose"], ["71944k02", "ribbed_hose"],
  ["71533k02", "pneumatic_tube"], ["71533k03", "pneumatic_tube"],
  ["u9053", "flex_hose"], ["77", "flex_hose"],
  ["u9010", "flex_axle"], ["u9011", "flex_axle"], ["u9012", "flex_axle"],
  ["71149k01", "string"], ["71149k02", "string"],
]);

/// Whether a file's parts are all one flexible part's pieces.
function laidFlexible(placed) {
  const kinds = new Set(placed.map((ref) => FLEX_PIECES.get(ref.replace(/\.dat$/, ""))));
  return placed.length > 0 && kinds.size === 1 && !kinds.has(undefined);
}

export class Refusal extends Error {
  constructor(message, status = 400) {
    super(message);
    this.status = status;
  }
}

/// Whether [text] is an LDraw model, and how many parts it has.
///
/// Every line must be one of LDraw's six kinds: 0 a comment or meta
/// command, 1 a part or submodel placed with a colour and a matrix, 2 to 5
/// lines and faces. That is what an .ldr, a .dat and an .mpd are, prints,
/// stickers and custom parts included — those travel inside the .mpd as
/// `0 FILE` sections and `0 !DATA` blocks, which are type 0 lines. A JSON
/// file, a picture or a script fails on its first line.
///
/// Parts are counted through the model's own submodels: a submodel
/// placed three times is its parts three times. A `0 FILE` whose name
/// ends .dat is a part (LDraw's own convention, and how the app writes a
/// custom part), so it counts once wherever it is placed; so does a
/// submodel that is a hose laid along a bend (FLEX_PIECES).
///
/// And what the gallery filters on, read from the same lines: whether its
/// steps are its builder's (LdrModel.steps_are_authored: steps there, not
/// marked worked out, and either marked so by Brickworks or written by
/// another tool), and how many of its parts are Technic and how many make
/// it move (partFacts), counted through its submodels as its parts are.
/// And its steps, every page the step player turns to (stepCount, the
/// steps it carries), which a comment is on: null when it carries none;
/// and [count], the steps as a person is told of them (api/_steps.js).
export function checkModel(text) {
  if (typeof text !== "string" || text.trim() === "") {
    throw new Refusal("there is no model to share");
  }
  const bytes = Buffer.byteLength(text, "utf8");
  if (bytes > MAX_MODEL_BYTES) {
    throw new Refusal(`that model is ${(bytes / 1048576).toFixed(1)} MB, and a shared model can be at most 2 MB`, 413);
  }
  // Control characters other than tab, line feed and carriage return
  // have no place in LDraw, and NUL is how a binary file gives itself away.
  if (/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(text)) {
    throw new Refusal("that is not LDraw text: it has binary in it", 415);
  }

  const files = new Map();
  const order = [];
  let current = { name: "", placed: [], colours: [], isPart: false, steps: 0, open: false, author: "" };
  let inData = false;
  let lineNo = 0;
  let stepped = false;
  let markedAuthored = false;
  let markedWorked = false;
  // A file is known once it has a name or places something: an .ldr
  // has no 0 FILE line, and an .mpd starts with one.
  const keep = () => {
    if (!files.has(current.name)) {
      files.set(current.name, current);
      order.push(current.name);
    }
  };
  // Each file keyed as the app keys it (sectionKey): its first block the
  // one a reference means, as LDView reads a file (keep), and the model's own
  // by a key no reference gives, so a later block of its name is that one,
  // not the model placing itself (ofcheck F4).
  const blocks = new Map();
  const start = (name) => {
    current = { name: sectionKey(name, blocks), placed: [], colours: [], isPart: /\.dat$/i.test(name), steps: 0,
      open: false, author: "" };
    keep();
  };

  for (const raw of text.replace(/^﻿/, "").split(/\r?\n/)) {
    lineNo += 1;
    const line = raw.trim();
    if (line === "") continue;
    const tokens = line.split(/\s+/);
    const kind = tokens[0];
    if (!/^[0-5]$/.test(kind)) {
      throw new Refusal(`that is not LDraw text: line ${lineNo} does not start with an LDraw line type`, 415);
    }
    if (kind === "0") {
      const meta = (tokens[1] || "").toUpperCase();
      if (meta === "FILE") {
        start(afterFields(raw, 2));
        inData = false;
      } else if (meta === "!DATA") {
        // An embedded picture: base64 in `0 !:` lines, not a model.
        inData = true;
        current = { name: "", placed: [], colours: [], isPart: true };
      } else if (meta === "NOFILE") {
        inData = false;
      } else if (meta === "!LDRAW_ORG" && /part|shortcut|primitive|subpart/i.test(tokens[2] || "")) {
        current.isPart = true;
      } else if (meta === "STEP" || meta === "ROTSTEP") {
        // A step ends with its parts: a STEP with none since the last is
        // not one, as a file's closing 0 STEP is not.
        stepped = true;
        if (current.open) current.steps += 1;
        current.open = false;
      } else if (meta === "AUTHOR:" && !current.author) {
        current.author = line.replace(/^0\s+Author:\s*/i, "").trim();
      } else if (meta === "!BRICKWORKS" && (tokens[2] || "").toUpperCase() === "AUTHORED_STEPS") {
        markedAuthored = true;
      } else if (meta === "!BRICKWORKS" && (tokens[2] || "").toUpperCase() === "WORKED_STEPS") {
        markedWorked = true;
      }
      continue;
    }
    if (inData) {
      throw new Refusal(`that is not LDraw text: line ${lineNo} is inside a 0 !DATA block`, 415);
    }
    if (kind === "1") {
      if (tokens.length < 15 || !COLOUR.test(tokens[1]) || !tokens.slice(2, 14).every((t) => NUMBER.test(t))) {
        throw new Refusal(`that is not LDraw text: line ${lineNo} is not a well-formed part line`, 415);
      }
      keep();
      current.placed.push(keyOf(afterFields(raw, 14)));
      current.colours.push(tokens[1]);
      current.open = true;
    } else {
      const need = COORDS[kind];
      if (tokens.length !== need + 2 || !COLOUR.test(tokens[1]) || !tokens.slice(2).every((t) => NUMBER.test(t))) {
        throw new Refusal(`that is not LDraw text: line ${lineNo} is not a well-formed type ${kind} line`, 415);
      }
    }
  }

  // The first file is the model; the rest are what it places. Each file
  // counts as [parts, Technic parts, parts that move].
  const facts = partFacts();
  const kindOf = (ref) => {
    const id = ref.replace(/\.dat$/, "");
    return [1, facts.technic.has(id) ? 1 : 0, facts.mechanism.has(id) ? 1 : 0];
  };
  const counted = new Map();
  const visiting = new Set();
  const tally = (name) => {
    const file = files.get(name);
    if (!file) return kindOf(name);
    if (file.isPart || laidFlexible(file.placed)) return [1, 0, 0];
    if (counted.has(name)) return counted.get(name);
    if (visiting.has(name)) throw new Refusal("that model places itself inside itself", 415);
    visiting.add(name);
    const total = [0, 0, 0];
    for (const ref of file.placed) {
      const one = files.has(ref) ? tally(ref) : kindOf(ref);
      for (let k = 0; k < 3; k += 1) total[k] += one[k];
    }
    visiting.delete(name);
    counted.set(name, total);
    return total;
  };
  const main = order.find((name) => !files.get(name).isPart);
  const [parts, technicParts, movingParts] = main === undefined ? [0, 0, 0] : tally(main);
  if (parts < 1) throw new Refusal("that model has no parts in it", 415);
  if (parts > 200000) throw new Refusal("that model has more parts than a shared model can have", 413);
  const top = files.get(main);
  const ownSteps = stepped && !markedWorked && (markedAuthored || top.author !== "Brickworks");
  const oneModel = top.placed.every((ref) => !files.has(ref) || files.get(ref).isPart);
  const stepsCount = stepCount(text, { own: ownSteps, oneModel, steps: top.steps + (top.open ? 1 : 0) });
  const steps = stepsCount?.pages ?? null;
  // What it needs, by part and colour, for Build with what I own
  // (api/_owned.js): every part line the tally counts, through its
  // sub-models in the colour each is placed in (16 is that colour). A
  // flexible part laid as segments is one part nobody owns by that name,
  // and is left out, as the app leaves out what is not a part.
  const memo = new Map();
  const needsOf = (name, colour) => {
    const key = `${name}\n${colour}`;
    if (memo.has(key)) return memo.get(key);
    const file = files.get(name);
    const out = new Map();
    const add = (lot, n) => out.set(lot, (out.get(lot) || 0) + n);
    file.placed.forEach((ref, at) => {
      const own = file.colours[at];
      const placedIn = own === "16" ? colour : own;
      const sub = files.get(ref);
      if (sub && !sub.isPart) {
        if (laidFlexible(sub.placed)) return;
        for (const [lot, n] of needsOf(ref, placedIn)) add(lot, n);
      } else {
        add(`${ref.replace(/\.dat$/, "")}\n${placedIn}`, 1);
      }
    });
    memo.set(key, out);
    return out;
  };
  const needs = [...needsOf(main, "16")].map(([lot, qty]) => {
    const [part, colour] = lot.split("\n");
    return [part, Number(colour), qty];
  });
  return { parts, bytes, steps, count: stepsCount, ownSteps, technic: isTechnic(parts, technicParts, movingParts), needs };
}

/// The picture, from the base64 the app sends, or null for none: [what]
/// names it in a refusal.
export function checkImage(given, what = "the picture") {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string" || !/^[A-Za-z0-9+/]+=*$/.test(given)) {
    throw new Refusal(`${what} is not readable`, 415);
  }
  const bytes = Buffer.from(given, "base64");
  if (bytes.length > MAX_IMAGE_BYTES) throw new Refusal(`${what} is too large`, 413);
  if (bytes.length < PNG.length || !bytes.subarray(0, PNG.length).equals(PNG)) {
    throw new Refusal(`${what} is not a PNG`, 415);
  }
  return bytes;
}

/// Who laid a model's parts, as its app says (supabase/made_with.sql,
/// web/card.js MADE_WITH): undefined when it does not say, which a
/// republish keeps as it was.
export function checkMadeWith(given) {
  if (given === undefined || given === null) return undefined;
  if (!MADE_WITH.includes(given)) throw new Refusal(`made_with is one of ${MADE_WITH.join(", ")}`);
  return given;
}

/// Whether its owner says on its page how it was made
/// (supabase/made_with_shown.sql): undefined when the app does not say,
/// which a republish keeps as it was.
export function checkMadeShown(given) {
  if (given === undefined || given === null) return undefined;
  if (typeof given !== "boolean") throw new Refusal("made_with_shown is true or false");
  return given;
}

/// The small picture for the gallery's cards, from the base64 the app
/// sends, or null for none: a WebP of at most 64 KB.
export function checkThumb(given) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string" || !/^[A-Za-z0-9+/]+=*$/.test(given)) {
    throw new Refusal("the small picture is not readable", 415);
  }
  const bytes = Buffer.from(given, "base64");
  if (bytes.length > MAX_THUMB_BYTES) throw new Refusal("the small picture is too large", 413);
  if (bytes.length < 16 || !bytes.subarray(0, 4).equals(RIFF) || !bytes.subarray(8, 12).equals(WEBP)) {
    throw new Refusal("the small picture is not a WebP", 415);
  }
  return bytes;
}

/// A name for a link: one line, printable, trimmed to its limit.
function cleanText(given, limit) {
  if (typeof given !== "string") return "";
  return given.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, limit).trim();
}

// ---------------------------------------------------------------------------
// The database and the bucket.

/// A published row, as a visitor may see it: only while it is published,
/// and only the columns anybody may read. Asked as the server: the key a
/// page holds reaches nothing in the database (supabase/no_client_access.sql,
/// 2026-10-24), where row security used to say what was published.
async function publishedRow(id) {
  if (!ID.test(id || "")) return null;
  const at = (select) => db(`shared_models?id=eq.${id}&published=is.true&select=${select}`);
  // Whether its owner shows how it was made (supabase/made_with_shown.sql);
  // before that is applied the column is refused, and the row is read
  // without it: shown by nobody.
  const rows = await at(`${PUBLIC},made_with_shown`).catch(() => at(PUBLIC));
  return rows[0] || null;
}

/// Whether a link that is not published ever was: "taken down" and "no
/// such link" are different things to tell somebody.
async function wasShared(id) {
  if (!ID.test(id || "")) return false;
  const rows = await db(`shared_models?id=eq.${id}&select=id`);
  return rows.length > 0;
}

async function ownRow(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`shared_models?id=eq.${id}&select=id,owner,published,listed,listed_at,barred,remixed_from,`
    + "description,tags,kind,licence,author,parts,steps,bytes,has_image,has_thumb,updated_at");
  return rows[0] || null;
}

/// The link a model says it was copied from, as {id, owner, licence}: null
/// for none, or for one that is not there any more (it went with its
/// account). An id that is not one is refused, like anything else
/// malformed at this edge.
async function remixOf(given, self) {
  if (given === undefined || given === null || given === "") return null;
  if (typeof given !== "string" || !ID.test(given)) throw new Refusal("remixed_from is not a link");
  if (given === self) return null;
  const rows = await db(`shared_models?id=eq.${given}&select=id,owner,licence`);
  return rows[0] || null;
}

function storageHeaders(extra = {}) {
  const key = process.env.SUPABASE_SECRET_KEY;
  return { apikey: key, authorization: `Bearer ${key}`, ...extra };
}

async function putFile(name, body, type) {
  const what = `storage POST ${name.split(".").pop()}`;
  const answer = await reach(what, 20, `${project()}/storage/v1/object/${bucketOf(name)}/${name}`, {
    method: "POST",
    headers: storageHeaders({ "content-type": type, "x-upsert": "true", "cache-control": "no-store" }),
    body,
  });
  if (!answer.ok) throw new Error(`${what}: ${answer.status}`);
}

async function getFile(name) {
  const what = `storage GET ${name.split(".").pop()}`;
  const answer = await reach(what, 20, `${project()}/storage/v1/object/${bucketOf(name)}/${name}`, {
    headers: storageHeaders(),
  });
  if (answer.status === 400 || answer.status === 404) return null;
  if (!answer.ok) throw new Error(`${what}: ${answer.status}`);
  return Buffer.from(await answer.arrayBuffer());
}

async function deleteFiles(names) {
  for (const bucket of [BUCKET, THUMBS, CLIPS]) {
    const these = names.filter((name) => bucketOf(name) === bucket);
    if (these.length === 0) continue;
    const answer = await reach(`storage DELETE ${bucket}`, 20, `${project()}/storage/v1/object/${bucket}`, {
      method: "DELETE",
      headers: storageHeaders({ "content-type": "application/json" }),
      body: JSON.stringify({ prefixes: these }),
    });
    if (!answer.ok) throw new Error(`storage DELETE ${bucket}: ${answer.status}`);
  }
}

/// Every file in the three buckets, a page at a time: [{name, updated_at}].
async function listFiles() {
  const files = [];
  for (const bucket of [BUCKET, THUMBS, CLIPS]) {
    for (let offset = 0; ; offset += 1000) {
      const answer = await reach(`storage list ${bucket}`, 20, `${project()}/storage/v1/object/list/${bucket}`, {
        method: "POST",
        headers: storageHeaders({ "content-type": "application/json" }),
        body: JSON.stringify({ prefix: "", limit: 1000, offset, sortBy: { column: "name", order: "asc" } }),
      });
      if (!answer.ok) throw new Error(`storage list ${bucket}: ${answer.status}`);
      const page = await answer.json();
      files.push(...page.filter((file) => file.id !== null));
      if (page.length < 1000) break;
    }
  }
  return files;
}

async function mayPublish(owner) {
  const allowed = await db("rpc/may_publish", { method: "POST", body: { account: owner } });
  return allowed === true;
}

async function barred(owner) {
  return (await db("rpc/is_barred", { method: "POST", body: { account: owner } })) === true;
}

async function barredFile(text) {
  const rows = await db(`barred_models?hash=eq.${modelHash(text)}&select=hash`);
  return rows.length > 0;
}

async function mayList(owner) {
  const allowed = await db("rpc/may_list", { method: "POST", body: { account: owner } });
  return allowed === true;
}

/// A publish that lists, counted as one of each or as neither
/// (supabase/publish_listed.sql): "ok", "listings" or "publishes". Before
/// that file is applied, the two counted one after the other, as they were.
async function mayPublishListed(owner) {
  try {
    const said = await db("rpc/may_publish_listed", { method: "POST", body: { account: owner } });
    if (said === "ok" || said === "listings" || said === "publishes") return said;
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) throw trouble;
  }
  if (!(await mayList(owner))) return "listings";
  return (await mayPublish(owner)) ? "ok" : "publishes";
}

// ---------------------------------------------------------------------------
// Versions (supabase/versions.sql).

/// A link's versions, newest first, as [{n, at, note, parts, steps, bytes,
/// has_image, changes, first, from_version}]: read with the secret key, so
/// only for a row already read as published, or for its owner. A link with
/// none (published before its versions were kept, and not since) is its
/// version 1, as the row says it is.
async function versionsOf(id, row = null, limit = VERSIONS_SHOWN) {
  // And, from supabase/wip.sql, whether each was work in progress, called
  // finished, and kept its small picture.
  const wipped = await wipReady();
  const rows = await db(`share_versions?model=eq.${id}&select=n,at,note,parts,steps,bytes,has_image,changes,`
    + `first_changed,remixed_from_version${wipped ? ",wip,finished_at,has_thumb,talk_post" : ""}&order=n.desc&limit=${limit}`);
  const versions = rows.map((one) => ({ n: one.n, at: one.at, note: one.note ?? null, parts: one.parts,
    steps: one.steps ?? null, bytes: one.bytes, has_image: one.has_image === true,
    changes: readChanges(one.changes), first: one.first_changed ?? null,
    from_version: one.remixed_from_version ?? null, wip: one.wip === true, finished_at: one.finished_at ?? null,
    has_thumb: one.has_thumb === true, talk_post: one.talk_post ?? null }));
  if (versions.length === 0 && row) {
    versions.push({ n: 1, at: row.updated_at, note: null, parts: row.parts, steps: row.steps ?? null,
      bytes: row.bytes, has_image: row.has_image === true, changes: null, first: null, from_version: null,
      wip: false, finished_at: null, has_thumb: false, talk_post: null, implied: true });
  }
  return versions;
}

/// Where version [n] of link [id] keeps its model or its picture: the
/// newest at the link's own name, as every link always has, and an older
/// one under its number beside it.
const versionFile = (id, n, newest, kind) => (n === newest ? `${id}.${kind}` : `${id}.v${n}.${kind}`);

/// The version a request asks for (?v=N), or null for the newest. A v that
/// is not a version number is refused at this edge.
function askedVersion(request) {
  const given = request.query?.v;
  if (given === undefined || given === null || given === "") return null;
  if (!VERSION.test(String(given))) throw new Refusal("v is a version's number, from 1");
  return Number(given);
}

/// Which version of the model it was remixed from its copy was made of:
/// said when the copy was first shared and kept by each version after.
const remixVersion = (versions) => versions.find((one) => one.from_version)?.from_version ?? null;

/// A version as an answer says it.
function versionSaid(origin, id, one, newest) {
  return { n: one.n, at: one.at, note: one.note, said: saidOf(one.n, one.changes),
    first_changed: one.first, parts: one.parts, steps: one.steps, newest: one.n === newest,
    wip: one.wip === true, finished: Boolean(one.finished_at),
    url: one.n === newest ? `${origin}/m/${id}` : `${origin}/m/${id}/v/${one.n}` };
}

// ---------------------------------------------------------------------------
// What a link answers.

function links(origin, id) {
  // A set of the LDraw library (api/_library.js): its page under /library/,
  // its cover for a picture, and the app opening it as the app's own
  // Library does, in a tab of its own (TabSession.open_another). No embed.
  if (SET_ID.test(id)) {
    const url = `${origin}/library/${id}`;
    return { url, image: `${url}.cover.webp`, viewer: `${origin}/app?new=1&library=${id}`, embed: "" };
  }
  const url = `${origin}/m/${id}`;
  // Its card in the language of the page that gives the code (/de/m/X/embed),
  // named in it for a screen reader.
  const at = langAt();
  return {
    url,
    image: `${url}.png`,
    viewer: `${origin}/app?view=${id}`,
    embed: `<iframe src="${origin}${at}/m/${id}/embed" width="560" height="420" style="border:0;max-width:100%" `
      + `title="${asText(say("A Brickworks model"))}" loading="lazy" allowfullscreen></iframe>`,
  };
}

/// Whom a model credits, by name, wherever it is said: its designer's
/// profile as it is named now, as Studio and Mecabricks credit your
/// username, when they have one shown in public (a page's by, or a row's
/// looked up by profileOf); else the name given as it was published; null
/// when it credits nobody. The page's head said the profile while its
/// licence credited a name the app had made from the address its designer
/// signs in with (walk180, 2026-10-23). A model its sharer did not make
/// credits whoever modelled it, as its file says (modelled_by: the shelf
/// from LDraw's library), whoever shares it.
export const creditName = (model) => modelledByOf(model.modelled_by)?.name
  || (model.author ? (model.by && model.by.name) || model.author : null);

/// The profile a published model's credit names, for an answer made from
/// its row alone: its owner's, while shown in public (supabase/follows.sql
/// feed_who), and only when it credits anybody. null when there is none,
/// or before follows.sql; a read that fails throws, for its caller to take
/// as unknown (orUnknown).
async function profileOf(id, author) {
  if (!author) return null;
  try {
    const rows = await db(`shared_models?id=eq.${id}&select=owner`);
    return rows[0] ? await db("rpc/feed_who", { method: "POST", body: { account: rows[0].owner } }) : null;
  } catch (trouble) {
    if (/: 404$/.test(String(trouble?.message || ""))) return null;
    throw trouble;
  }
}

/// Whether a credit is made from the address [email] signs in with: the
/// letters and digits of the part before its @, as an app before m157
/// offered it ("Delivered+walk 180 Web"), or the address in it. An address
/// is never shown, nor any part of one.
export function madeFromAddress(credit, email) {
  const plain = (text) => String(text || "").toLowerCase().replace(/[^\p{L}\p{N}]/gu, "");
  const local = String(email || "").split("@")[0].toLowerCase();
  const said = String(credit || "").toLowerCase();
  return Boolean(local) && (plain(said) === plain(local) || said.includes(local) || said.includes("@"));
}

function describe(row) {
  const parts = counted(row.parts, "part");
  const by = creditName(row);
  return by ? say("{parts}, by {name}", { parts, name: by }) : parts;
}

/// What a link preview reads: the title, a sentence, the picture; [url]
/// the page's own address, and [alternates] its copies in each language.
/// With a [clip] (clipShown), the model turning as well: og:video for
/// Discord, Slack, Facebook and the rest, and beside X's large picture card
/// the player's tags, its player the embed playing it (?autoplay=1,
/// web/embed.js). The card stays summary_large_image: X shows a player card
/// only on a domain it has allowed, and anywhere else the link would lose
/// its picture (ttreview F5). The picture stays, as the video's poster.
function pageHead(origin, row, id, title, { about = "", canonical = "", url = links(origin, id).url, alternates = "",
  clip = null } = {}) {
  const link = links(origin, id);
  const description = about || (row
    ? `${describe(row)}. ${say("Turn it in 3D, step through the build, and get its booklet and parts list.")}`
    : say("A model built in Brickworks, the CAD app for LEGO® bricks in your browser."));
  const image = row && row.has_image ? link.image : `${origin}/share.png`;
  const video = clip ? `<meta property="og:video" content="${escapeHtml(clip.url)}">
<meta property="og:video:secure_url" content="${escapeHtml(clip.url)}">
<meta property="og:video:type" content="${escapeHtml(clip.type)}">
<meta property="og:video:width" content="${Number(clip.width)}">
<meta property="og:video:height" content="${Number(clip.height)}">
` : "";
  // The player is the embed's card, at the size its code gives (links):
  // read by X once it shows player cards here, and by nothing else.
  const player = clip ? `<meta name="twitter:player" content="${escapeHtml(clip.player)}">
<meta name="twitter:player:width" content="560">
<meta name="twitter:player:height" content="420">
<meta name="twitter:player:stream" content="${escapeHtml(clip.url)}">
<meta name="twitter:player:stream:content_type" content="${escapeHtml(clip.type)}">
` : "";
  return `<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>${escapeHtml(title)}</title>
<meta name="description" content="${escapeHtml(description)}">
${canonical ? `<link rel="canonical" href="${escapeHtml(canonical)}">\n` : ""}${alternates ? `${alternates}\n` : ""}<meta property="og:type" content="${clip ? "video.other" : "website"}">
<meta property="og:site_name" content="Brickworks">
<meta property="og:title" content="${escapeHtml(title)}">
<meta property="og:description" content="${escapeHtml(description)}">
<meta property="og:url" content="${escapeHtml(url)}">
<meta property="og:image" content="${escapeHtml(image)}">
<meta property="og:image:width" content="1200">
<meta property="og:image:height" content="630">
${video}<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="${escapeHtml(title)}">
<meta name="twitter:description" content="${escapeHtml(description)}">
<meta name="twitter:image" content="${escapeHtml(image)}">
${player}${link.embed ? `<link rel="alternate" type="application/json+oembed" href="${escapeHtml(`${origin}/oembed?url=${encodeURIComponent(link.url)}&format=json`)}" title="${escapeHtml(row ? row.name : title)}">\n` : ""}<link rel="icon" href="/icon.svg" type="image/svg+xml">
<link rel="icon" href="/favicon-32.png" sizes="32x32" type="image/png">`;
}

// A day as the page's language writes it: "17 October 2026", "17. Oktober 2026".
const DAYS = new Map();
const when = (iso) => {
  const at = Date.parse(iso || "");
  const locale = globalThis.brickworksLang?.locale || "en-GB";
  if (!DAYS.has(locale)) DAYS.set(locale, new Intl.DateTimeFormat(locale, { day: "numeric", month: "long", year: "numeric", timeZone: "UTC" }));
  return Number.isFinite(at) ? `<time datetime="${escapeHtml(new Date(at).toISOString())}">${DAYS.get(locale).format(at)}</time>` : "";
};

/// Who to credit, as a page says it: their profile's name and handle, a
/// link to it, or the name the owner gave; the link itself when they gave
/// none.
function creditOf(model, nobody = asText(say("this page’s link"))) {
  const modeller = modelledByOf(model.modelled_by);
  if (modeller) {
    return sayHtml("{name}, who modelled it for {ldraw}", { name: escapeHtml(modeller.name),
      ldraw: `<a href="${escapeHtml(modeller.page)}">${escapeHtml(say(LDRAW_FROM))}</a>` })
      + (modeller.changed ? sayHtml(", and say {name} changed it", { name: escapeHtml(sharerOf(model)) }) : "");
  }
  if (!model.author) return nobody;
  if (!model.by) return escapeHtml(model.author);
  const handle = escapeHtml(model.by.handle);
  return `${escapeHtml(model.by.name)} (<a href="${langAt()}/u/${handle}">@${handle}</a>)`;
}

/// The licence, said for a person: what they may do, whom to credit, and
/// the licence itself.
function licenceWords(model) {
  const licence = LICENCES[model.licence];
  if (!licence) {
    return `<p><b>${asText(say("No licence chosen."))}</b> `
      + `${asText(say("It was shared before Brickworks asked for one: ask whoever shared it before you use it anywhere else."))}</p>`;
  }
  const deed = licence.url ? ` <a href="${licence.url}" rel="license">${asText(say("The licence"))}</a>.` : "";
  if (model.licence === "all-rights-reserved") {
    return `<p><b>${asText(say("All rights reserved"))}.</b> `
      + `${sayHtml("Look at it and build it for yourself; ask {credit} before you share a copy or a version of it.",
        { credit: creditOf(model, asText(say("whoever shared it"))) })}</p>`;
  }
  if (model.licence === "cc-by-sa-4.0") {
    return `<p><b>${licence.name}.</b> ${sayHtml("Anyone may share it, change it and build on it, as long as they credit "
      + "{credit}, link to this page, and share what they make under the same licence.", { credit: creditOf(model) })}${deed}</p>`;
  }
  // A set of the LDraw library: its modellers and LDraw, whose page of it
  // the credit links to; this page is not its source.
  return `<p><b>${licence.name}.</b> ${sayHtml(model.library
    ? "Anyone may share it, change it and build on it, for any purpose, as long as they credit {credit}."
    : "Anyone may share it, change it and build on it, for any purpose, as long as they credit {credit} and link to this page.",
  { credit: creditOf(model) })}${deed}</p>`;
}

/// A set's facts, as a model's page says a model's (sharePage): its parts,
/// the steps its file lays out, its number, theme and year (each a way to
/// more of the shelf), that it is another build of its set, and its box's
/// count where the model's is not the same count (ModelLibrary.agrees).
function setFacts(set, parts) {
  const decade = set.year ? `${Math.floor(set.year / 10) * 10}s` : "";
  const at = langAt();
  const box = Number(set.box) || 0;
  return [
    `<li class="pill">${escapeHtml(counted(parts, "part"))}</li>`,
    box && Math.abs(parts - box) > 0.02 * box ? `<li class="pill">${escapeHtml(say("Its box: {parts}", { parts: counted(box, "part") }))}</li>` : "",
    set.steps ? `<li class="pill" data-steps="${Number(set.steps)}">${escapeHtml(say("{steps}, laid out by its modeller",
      { steps: counted(set.steps, "step") }))}</li>` : "",
    // Its set's own page (sets364): every part, and what of it you own.
    set.set ? (catalogSet(set.set) ? `<li><a class="pill" data-set="${escapeHtml(set.set)}" href="${at}/library/set/${escapeHtml(catalogSet(set.set).set)}">${escapeHtml(say("Set {set}", { set: set.set }))}</a></li>`
      : `<li class="pill" data-set="${escapeHtml(set.set)}">${escapeHtml(say("Set {set}", { set: set.set }))}</li>`) : "",
    set.alternate_of ? `<li class="pill">${escapeHtml(say("Another build of {set}", { set: set.alternate_of }))}</li>` : "",
    set.theme ? `<li><a class="pill" href="${at}/library?theme=${encodeURIComponent(set.theme)}">${escapeHtml(themeSaid(set.theme))}</a></li>` : "",
    decade ? `<li><a class="pill" href="${at}/library?decade=${decade}">${Number(set.year)}</a></li>` : "",
  ].join("");
}

/// What a search engine reads of the model: schema.org's CreativeWork,
/// with its maker as credited, its licence, and what it was remixed from.
/// A data block, never run, so the page's policy has nothing to allow; its
/// "<" written as \u003c, so nothing typed can end the block.
function structured(origin, id, model) {
  const url = links(origin, id).url;
  const parent = (model.from || [])[0];
  // The model it remixes, and what else it credits (api/_bases.js).
  const basedOn = [...(parent && parent.id ? [`${origin}/m/${parent.id}`] : []),
    ...(model.based || []).map((one) => (one.set ? `${origin}${one.href}` : one.href))];
  const data = {
    "@context": "https://schema.org", "@type": "CreativeWork", name: model.name, url,
    description: model.description || describe(model), image: model.has_image ? links(origin, id).image : undefined,
    author: creditName(model) ? { "@type": "Person", name: creditName(model),
      url: modelledByOf(model.modelled_by)?.page || (model.by ? `${origin}/u/${model.by.handle}` : undefined) } : undefined,
    license: LICENCES[model.licence]?.url || undefined, dateCreated: model.listed_at || undefined,
    keywords: (model.tags || []).join(", ") || undefined,
    isBasedOn: basedOn.length ? basedOn : undefined,
    interactionStatistic: [
      { "@type": "InteractionCounter", interactionType: "https://schema.org/ViewAction", userInteractionCount: Number(model.views) || 0 },
      { "@type": "InteractionCounter", interactionType: "https://schema.org/LikeAction", userInteractionCount: Number(model.likes) || 0 },
    ],
  };
  return `<script type="application/ld+json">${JSON.stringify(data).replace(/</g, "\\u003c")}</script>`;
}

/// /sitemap.xml: the site's own pages (web/sitemap.xml, beside this file
/// as _sitemap.xml in a deployment) and every page of the directory a
/// search engine may find — each listed model, each profile with a model in
/// the gallery, each public collection (sitemap_pages, which leaves out
/// whatever was barred). Kept by the CDN for an hour.
async function sitemap(response, origin) {
  let site = "";
  for (const where of ["./_sitemap.xml", "../web/sitemap.xml"]) {
    const url = new URL(where, import.meta.url);
    if (existsSync(url)) {
      site = readFileSync(url, "utf8");
      break;
    }
  }
  const [pages, sets] = await Promise.all([db("rpc/sitemap_pages", { method: "POST", body: {} }).then((said) => said || {}),
    librarySets().catch(() => [])]);
  const entry = sitemapEntry;
  const ours = [...site.matchAll(/<url>[\s\S]*?<\/url>/g)].map((m) => `  ${m[0]}`);
  const rows = [
    ...ours,
    ...(pages.models || []).map((m) => entry(`${origin}/m/${m.id}`, m.updated_at, "weekly", "0.6")),
    ...(pages.people || []).map((p) => entry(`${origin}/u/${p.handle}`, p.updated_at, "weekly", "0.4")),
    ...(pages.collections || []).map((c) => entry(`${origin}/c/${c.id}`, c.updated_at, "weekly", "0.3")),
    // The LDraw library's sets (api/_library.js), each a page of its own.
    ...sets.map((one) => entry(`${origin}/library/${one.id}`, "", "monthly", "0.4")),
  ];
  response.setHeader("Content-Type", "application/xml; charset=utf-8");
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=3600, stale-while-revalidate=600");
  return response.status(200).end(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${rows.join("\n")}
</urlset>
`);
}

/// A sitemap's row: a page, when it last changed, how often it does, and
/// how it ranks among the site's.
function sitemapEntry(loc, when, often, rank) {
  return `  <url><loc>${escapeHtml(loc)}</loc>${when ? `<lastmod>${String(when).slice(0, 10)}</lastmod>` : ""}`
    + `<changefreq>${often}</changefreq><priority>${rank}</priority></url>`;
}

/// /sitemaps/models-de.xml: the copy in [lang] of each model /sitemap.xml
/// lists (sharePage, /de/m/X). Kept by the CDN for an hour, as that is.
async function sitemapOfModels(response, origin, lang) {
  if (!SITE_LANGS.includes(lang)) return response.status(404).setHeader("Cache-Control", "no-store").end("");
  const pages = await db("rpc/sitemap_pages", { method: "POST", body: {} }).then((said) => said || {});
  const rows = (pages.models || []).map((m) => sitemapEntry(`${origin}/${lang}/m/${m.id}`, m.updated_at, "weekly", "0.5"));
  response.setHeader("Content-Type", "application/xml; charset=utf-8");
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=3600, stale-while-revalidate=600");
  return response.status(200).end(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${rows.join("\n")}
</urlset>
`);
}

/// The Tested mark, for a version that passed (api/_tested.js publicMark):
/// small, the four results on hover (its title) and on a tap (it opens),
/// and whose finding it is. Nothing for any other version.
function testedMark(mark, steps = null) {
  if (!mark) return "";
  // Each test as the site says it passed (api/_tested.js SAID).
  const said = mark.said.map((one) => say(one));
  return `<details class="tested-mark" data-tested="yes"><summary class="pill good" title="${escapeHtml(said.join(" · "))}">`
    + `<span aria-hidden="true">✓</span> ${asText(say("Tested"))}</summary><div class="tested-says">`
    + `<ul>${said.map((one) => `<li>${escapeHtml(one)}</li>`).join("")}</ul>`
    + `<p class="note">${escapeHtml(say("Worked out by the Brickworks app {app} as it was published, building it by its own {steps}.",
      { app: mark.app, steps: steps ? countSaid(steps) : counted(mark.steps, "step") }))}</p></div></details>`;
}

/// Who made it, at the head of its page: their avatar, name and handle, a
/// link to their profile, and Follow beside it (web/follow.js shows it once
/// it knows who is asking). A credit with no profile behind it is the name
/// alone, with an avatar made from it; a model shared with no credit, none.
function designerRow(model) {
  if (model.by) {
    const handle = escapeHtml(model.by.handle);
    return `<div class="shared-by"><a class="who" href="${langAt()}/u/${handle}">${avatarHtml(model.by)}`
      + `<span class="names"><b>${escapeHtml(model.by.name)}</b><small>@${handle}</small></span></a>`
      + `<button type="button" class="cta ghost small follow" data-follow="${handle}" hidden>${asText(say("Follow"))}</button>`
      + `<span class="said" role="status"></span></div>`;
  }
  if (!model.author) return "";
  return `<div class="shared-by"><span class="who">${avatarHtml({ name: model.author })}`
    + `<span class="names"><b>${escapeHtml(model.author)}</b></span></span></div>`;
}

/// Who shares a model, by name, as its page heads it.
const sharerOf = (model) => (model.by && model.by.name) || model.author || say("whoever shares it");

/// Who modelled it, under who shares it, when that is somebody else: the
/// person the app's Library credits, the page LDraw keeps of it, and, when
/// its sharer changed it, that they did. "" for a model its sharer made.
/// What was counted of [page]'s model ([kept]: api/_alts.js altRowsOf's)
/// said on it (altbuilds): page.alt, the line under its credit (altSaid,
/// each set named from the catalogue and linking its page under [at]); or,
/// where its designer says it is an alternate build of that same set, its
/// share on that line instead, so the page says it once. A version of a set
/// (its own LDraw model, published: sethub) says which set, linking the
/// set's page, where its Versions of this set lists it.
export function altLine(page, kept, at = "") {
  page.alt = null;
  const said = kept ? altSaid(kept.sets, kept.pieces) : null;
  if (!said) {
    const own = Array.isArray(kept?.sets) ? kept.sets.find((row) => row.role === "own") : null;
    const entry = own ? catalogSet(own.set) : null;
    if (entry && kept.pieces > 0) {
      page.alt = { how: "version", pieces: kept.pieces, sets: [{ set: entry.set, name: entry.name, have: own.have,
        href: `${at}/library/set/${encodeURIComponent(entry.set)}#versions` }] };
    }
    return page;
  }
  const sets = said.sets.map((one) => {
    const entry = catalogSet(one.set);
    return entry ? { ...one, set: entry.set, name: entry.name, href: `${at}/library/set/${encodeURIComponent(entry.set)}` } : null;
  });
  if (sets.some((one) => !one)) return page;
  const declared = (page.based || []).filter((one) => one.how === "alternate" && one.set);
  if (said.how !== "group" && declared.some((one) => one.set.toLowerCase() === sets[0].set.toLowerCase())) {
    page.based = page.based.map((one) => (one.how === "alternate" && one.set && one.set.toLowerCase() === sets[0].set.toLowerCase()
      ? { ...one, share: { have: sets[0].have, pieces: said.pieces } } : one));
    return page;
  }
  page.alt = { ...said, sets };
  return page;
}

function modelledLine(model) {
  const modeller = modelledByOf(model.modelled_by);
  return modeller ? `<p class="from modelled-by">${sayHtml("Modelled by {name} for {ldraw}", { name: `<b>${escapeHtml(modeller.name)}</b>`,
    ldraw: `<a href="${escapeHtml(modeller.page)}">${escapeHtml(say(LDRAW_FROM))}</a>` })}`
    + `${modeller.changed ? escapeHtml(say(", changed by {name}", { name: sharerOf(model) })) : ""}</p>` : "";
}

/// What a model's page leads on to (docs/SOCIAL.md D4, D12, D13): at most
/// NEXT_MOST cards a row, and a row only once it has NEXT_LEAST, since a
/// row of one or two reads as a gallery nobody uses.
export const NEXT_MOST = 6;
export const NEXT_LEAST = 3;

/// The cards a model's page ends with: more by its designer, their other
/// models in the gallery by Top builds; and similar models, of its kind or
/// sharing its tags, the most tags shared first, then its kind, then Top
/// builds; or, with neither, the gallery's Top. Never from who looked at
/// what (D13). A card the page shows
/// already (the model, its remixes, a card in More by) is not shown again.
/// Read through gallery_models (rankedRows), as the gallery's Top is, so a
/// model taken out or still being built (supabase/wip.sql) is never offered; a test model's own page, which only a probe has the
/// link to, offers test models too, as it lists its test remixes
/// (supabase/test_models.sql). The database not answering is no rows: the
/// page is drawn without them, never refused.
async function nextOf(origin, id, model, own) {
  const none = { by: [], like: [], gallery: [] };
  if (!own) return none;
  const ask = (query) => orUnknown("share", rankedRows({ sort: "top", tests: own.test === true, ...query }));
  // What it is of, not how it was made (api/_alike.js subjectsOf): two
  // models made with the assistant are not alike for it, and a model whose
  // owner did not say so is never ranked by it.
  const tags = (model.tags || []).filter((tag) => !ASSISTANT_TAGS.includes(tag));
  const [theirs, kin, ...tagged] = await Promise.all([
    model.by ? ask({ owner: own.owner, size: NEXT_MOST + 1 }) : [],
    model.kind ? ask({ kind: model.kind, size: 24 }) : [],
    ...tags.slice(0, 3).map((tag) => ask({ tag, size: 12 })),
  ]);
  const by = (theirs || []).filter((row) => row && row.id !== id).slice(0, NEXT_MOST);
  const shown = new Set([id, ...(model.remixes_listed || []).map((row) => row.id),
    ...(by.length >= NEXT_LEAST ? by.map((row) => row.id) : [])]);
  const top = (row) => SCORE.builds * (Number(row.builds) || 0) + SCORE.remixes * (Number(row.remixes) || 0)
    + (row.tested === true ? SCORE.tested : 0);
  const near = (row) => 2 * (row.tags || []).filter((tag) => tags.includes(tag)).length
    + (model.kind && row.kind === model.kind ? 1 : 0);
  const found = new Map();
  for (const row of [...(kin || []), ...tagged.flat()]) {
    if (row && !shown.has(row.id) && !found.has(row.id)) found.set(row.id, row);
  }
  const like = [...found.values()].sort((a, b) => near(b) - near(a) || top(b) - top(a)
    || String(b.listed_at || "").localeCompare(String(a.listed_at || ""))).slice(0, NEXT_MOST);
  const cards = (rows) => (rows.length >= NEXT_LEAST ? rows.map((row) => cardOf(origin, row)) : []);
  const next = { by: cards(by), like: cards(like), gallery: [] };
  // Neither row: the gallery's own Top, so the page's last screen always
  // has another model to open (docs/SOCIAL.md U4), however few there are.
  if (!next.by.length && !next.like.length) {
    const top = await ask({ size: NEXT_MOST + shown.size });
    next.gallery = (top || []).filter((row) => row && !shown.has(row.id)).slice(0, NEXT_MOST)
      .map((row) => cardOf(origin, row));
  }
  return next;
}

/// A row of cards the page ends with, or nothing for none; [all], the
/// list it is the start of, is See all beside its name.
function nextRow(key, title, cards, all = "") {
  if (!cards.length) return "";
  return `<section class="next" id="${key}" aria-labelledby="${key}-h"><div class="scroller-head"><h2 id="${key}-h">${title}</h2>`
    + `${all ? `<a href="${escapeHtml(all)}">${asText(say("See all"))}</a>` : ""}</div>`
    + `<div class="models scroller" role="group" aria-labelledby="${key}-h">${cards.map((card) => cardHtml(card)).join("")}</div></section>`;
}

/// The action bar: Like, Save, Share, Comment, I built it and More, each an
/// icon button that says its name and count (web/kit.js), never a count of
/// none. web/model-page.js makes them work, asking to sign in first where
/// one must be; it counts the comments as it lists them. Save is the one a
/// card has (web/card.js keepHtml, lists2a): Save at a tap, and its arrow
/// the panel of your lists (web/keep.js), one panel and one request for a
/// model wherever it is saved. [url] is the page's own address, an older
/// version's its own.
/// Open in Brickworks' second choice, With your Claude (claudelink,
/// docs/MASTERPLAN.md "What only Brickworks can do" 6): the other half of
/// the one control, which opens claudePanel under the row. Drawn hidden, and
/// shown by web/model-page.js, which is what makes it work. Not a .cta: a
/// half with square corners on its start is the control's, not a button of
/// its own (design_flow compares every .cta's corners).
function claudeButton() {
  const name = asText(say("Change it with your Claude"));
  return `<button type="button" class="open-claude" data-open-claude aria-expanded="false" aria-controls="claude-panel" `
    + `aria-label="${name}" title="${asText(say("Or have your own Claude open a copy and change it as you ask"))}" hidden>`
    + `${iconHtml("spark")}<span class="word wide" aria-hidden="true">${asText(say("With your Claude"))}</span>`
    + `<span class="word narrow" aria-hidden="true">Claude</span>${iconHtml("down")}</button>`;
}

/// Change it with your Claude: what should it change (optional), and Copy
/// for Claude, a message naming the model's link and the one call that opens
/// a copy of it (open_model link=), to paste into the person's own Claude
/// with the Brickworks connector; on a phone, its share sheet too; and the
/// way to connect Claude first, the message kept for after. Published, the
/// copy's page says what it was remixed from (ModelStore.remixed_from), as
/// Open in Brickworks' copy does. The message is made in the browser
/// (web/model-page.js startClaude), from what this panel carries.
function claudePanel(origin, id, model) {
  // Whom its page credits (designerRow): the profile's name, else the credit typed.
  const by = model.author ? model.by?.name || model.author : "";
  return `<div class="claude-panel" id="claude-panel" role="group" aria-labelledby="claude-head" data-id="${id}" `
    + `data-name="${escapeHtml(model.name)}" data-by="${escapeHtml(by)}" data-url="${escapeHtml(links(origin, id).url)}" hidden>`
    + `<p class="claude-head" id="claude-head">${asText(say("Change it with your Claude"))}</p>`
    + `<p class="claude-about">${asText(say("Your own Claude, with the Brickworks connector, opens a copy in your models and changes it as you ask. "
      + "Publish the copy, and its page says it was remixed from this one."))}</p>`
    + `<form class="claude-ask" novalidate><label for="claude-ask">${asText(say("What should it change?"))} <small>${asText(say("Optional"))}</small></label>`
    + `<input id="claude-ask" name="ask" autocomplete="off" enterkeyhint="done" `
      + `placeholder="${asText(say("Make the roof blue, or add a stand with a nameplate"))}">`
    + `<div class="claude-do"><button class="cta" type="submit">${asText(say("Copy for Claude"))}</button>`
    + `<button class="cta ghost" type="button" data-claude-share hidden>${asText(say("Share to Claude"))}</button></div></form>`
    + `<p class="note claude-connect">${sayHtml("No connector yet? {connect}, and your message waits for you there.",
      { connect: `<a href="/docs/connect#with-your-claude" data-claude-connect>${asText(say("Connect Claude"))}</a>` })}</p>`
    + `<textarea class="claude-message" readonly rows="5" aria-label="${asText(say("Your message for Claude"))}" hidden></textarea>`
    + `<p class="said claude-said" role="status"></p></div>`;
}

function actionBar(origin, id, model, url = links(origin, id).url, file = "") {
  // A set of the LDraw library has no row to like, save, comment on or say
  // was built: Share and More alone.
  const more = asText(say("More"));
  if (model.library) {
    return `<div class="action-bar" id="marks" data-id="${id}" role="group" aria-label="${asText(say("What you can do with it"))}">`
      + iconButtonHtml({ icon: "share", name: say("Share"),
        attrs: `data-share aria-haspopup="dialog" aria-controls="share-sheet" title="${asText(say("Share it: its link"))}"` })
      + `<details class="more-menu end" id="more"><summary class="icon-btn" aria-label="${more}" title="${more}">`
      + `${iconHtml("more")}</summary><div class="menu-list"><a href="${langAt()}/takedown">${asText(say("Takedown requests"))}</a></div></details>`
      + `</div>` + shareSheet(origin, id, model, url);
  }
  return `<div class="action-bar" id="marks" data-id="${id}" role="group" aria-label="${asText(say("What you can do with it"))}">`
    + iconButtonHtml({ icon: "like", name: say("Like"), count: model.likes, one: "like", many: "likes", pressed: false,
      labelled: true, attrs: `data-mark="like" title="${asText(say("Like it"))}"` })
    + keepHtml(`model:${id}`, model.name)
    + iconButtonHtml({ icon: "share", name: say("Share"),
      attrs: `data-share aria-haspopup="dialog" aria-controls="share-sheet" title="${asText(say("Share it: its link, and the code to embed it"))}"` })
    + iconButtonHtml({ icon: "comment", name: say("Comment"), attrs: `data-mark="comment" title="${asText(say("Comments on it and its steps"))}"` })
    + iconButtonHtml({ icon: "build", name: say("I built it"), count: model.builds, one: "build", many: "builds", labelled: true,
      word: say("Built"), attrs: `data-mark="built" title="${asText(say("I built it: add a photo of your build"))}"` })
    + `<details class="more-menu end" id="more"><summary class="icon-btn" aria-label="${more}" title="${more}">`
      + `${iconHtml("more")}</summary><div class="menu-list">`
      // Download, More's on a phone, where Open in Brickworks and With your
      // Claude fill the row it shared (web/directory.css .menu-download).
      + (file ? `<a class="menu-download" href="${escapeHtml(file)}" download>${asText(say("Download"))}</a>` : "")
      + `<button type="button" data-report="${asText(say("this model"))}" data-report-model="${id}" hidden>${asText(say("Report it"))}</button>`
      + `<a href="${langAt()}/takedown">${asText(say("Takedown requests"))}</a></div></details>`
    + `</div>`
    + `<p class="said marks-said" role="status"></p>`
    + shareSheet(origin, id, model, url);
}

/// Share's sheet (docs/SOCIAL.md U14 and section 7), web/card.js's, the
/// same on every page with Share: the page's link, the networks to post it
/// to, and the code that embeds its card (/m/X/embed) in somebody else's
/// page. A set has no embed.
function shareSheet(origin, id, model, url) {
  const link = links(origin, id);
  return shareSheetHtml({ url, name: model.name, text: say("{name} on Brickworks", { name: model.name }),
    about: say("Its link opens this page, where anybody can turn it in 3D and build it, with no account."),
    image: model.has_image || model.library ? link.image : "", embed: link.embed, post: !model.library });
}

/// What a kit to post it elsewhere is made from (unit postkit,
/// web/post-kit.js), for its designer's browser: what its page says of it
/// already, as data, so the kit's words and credits are the page's. Its
/// newest version's page alone has it. [about] is the page's summary of
/// its words. Every word in it was typed by somebody, so nothing in it can
/// end the script it is in.
function postFacts(origin, id, model, about) {
  const made = madeOf(model);
  const modeller = modelledByOf(model.modelled_by);
  const parent = (model.from || [])[0];
  const absolute = (href) => (typeof href === "string" && href.startsWith("/") ? `${origin}${href}` : String(href || ""));
  const credits = [
    ...(parent ? [{ how: "remix", name: parent.name || "", by: parent.author || "", url: parent.id ? `${origin}/m/${parent.id}` : "" }] : []),
    ...(modeller ? [{ how: "modelled", name: model.name, by: modeller.name, url: modeller.page || "", changed: Boolean(modeller.changed) }] : []),
    ...(model.based || []).map((one) => ({ how: one.how, set: Boolean(one.set),
      name: one.set ? `${one.set}${one.name ? ` ${one.name}` : ""}` : one.name || "", by: one.author || "", url: absolute(one.href) })),
  ];
  const facts = { id, name: model.name, url: links(origin, id).url, by: (model.by && model.by.name) || model.author || "",
    pieces: Number(model.parts) || 0, made: made.way, maker: made.by, kind: model.kind || "", tags: model.tags || [],
    licence: LICENCES[model.licence]?.name || "", about, credits, scene: `/m/${id}/scene.json`, parts: `/m/${id}/parts.json`,
    viewer: `/app?view=${id}` };
  const json = JSON.stringify(facts).replace(/[<>&\u2028\u2029]/g, (c) => `\\u${c.charCodeAt(0).toString(16).padStart(4, "0")}`);
  return `<script type="application/json" id="post-facts">${json}</script>`;
}

/// How [model] was made, as a fact of its page when it was made with the
/// assistant or Brickify, and who says so on hover (web/card.js madeOf);
/// "" for one built by hand.
function madeFact(model) {
  const made = madeOf(model);
  if (made.way !== "assistant") return "";
  const how = say(made.said === "app" ? "as the app said when it was published" : "as its designer tagged it");
  return made.by === "brickify"
    ? `<li class="pill made" title="${escapeHtml(say("Made from a 3D model with Brickify, {how}", { how }))}">Brickify</li>`
    : `<li class="pill made" title="${escapeHtml(say("Designed with the assistant, {how}", { how }))}">${asText(say("With the assistant"))}</li>`;
}

/// /m/X: the model's own page. Its picture first, with the strip of its
/// other pictures, and beside it on a laptop (under it on a phone) what it
/// is, who made it, the way into the viewer and the app, and the action
/// bar; then its tabs, About (what its owner said, its tags and licence),
/// Comments, Builds, Remixes and Versions, each a part of the page; and at
/// the end more by its designer and similar models, or, with neither, the
/// gallery's. Every word an owner typed is escaped.
/// web/share-page.js counts the view, and if a reload finds the viewer was
/// here (it keeps the link in the address bar), goes back to it.
/// [counted] is the shown version's steps, counted from its file as it is
/// read (api/_steps.js), or null where they are not known; [parts] its
/// parts list (partsOf), or null.
///
/// A set of the LDraw library (api/_library.js setModel, model.library) has
/// its page made here too (library333): its picture, who modelled it for
/// LDraw and on what terms, the app opening it, Share, its parts and more
/// of its theme. None of what is a shared model's row (versions, marks,
/// likes, comments, builds, remixes, collections), and its number, theme
/// and year where a model has its kind.
///
/// A shared model's page is in German, French and Spanish too, at
/// /de/m/X (and /de/m/X/v/N), as a set's is (api/_sets.js setPage): made
/// inside api/_directory.js inLanguage in [lang], with [words] the copy's
/// for the page's own scripts, the gallery copy's header and footer, every
/// date as the language writes it and every link to a page with a copy in
/// the language. What its builder wrote stays as they wrote it: its name,
/// description, tags, notes and comments. Each page names the others
/// (hreflang) and is its own canonical.
function sharePage(origin, id, model, versions = [], shown = null, mark = null, photos = [], next = { by: [], like: [] },
  stepsCounted = null, lists = { count: 0, lists: [], covers: new Map() }, parts = null, lang = "en", words = null, clip = null) {
  const set = model.library || null;
  const newest = versions[0]?.n ?? 1;
  const version = shown ?? versions[0] ?? { n: 1, has_image: model.has_image };
  // An older version: its own page, marked as older, its own picture and
  // counts, its viewer, and the newest a click away. Never indexed: the
  // link is what a search should find.
  const old = version.n !== newest;
  const at = lang === "en" ? "" : `/${lang}`;
  const title = set ? say("{name}, LEGO® set {set} — from the LDraw library", { name: model.name, set: set.set })
    : old ? say("{name}, version {n} — a Brickworks model", { name: model.name, n: version.n })
    : say("{name} — a Brickworks model", { name: model.name });
  // A set is looked at in the app itself, opened as the app's Library opens
  // one; there is no copy to make of it, so Open in Brickworks is the same.
  const viewer = set ? `/app?new=1&library=${id}` : `/app?view=${id}${old ? `&v=${version.n}` : ""}`;
  const copyLink = set ? viewer : `/app?copy=${id}${old ? `&v=${version.n}` : ""}`;
  // Its parts as the app counts them, where its file was read: the count
  // the Parts list under it says.
  const shownModel = { ...model, parts: parts ? parts.pieces : old ? version.parts : model.parts };
  const fileAt = set ? `/library/${id}` : `/m/${id}${old ? `/v/${version.n}` : ""}`;
  // Its picture with nothing behind the model, on the theme's own ground
  // (?op=cutout: the picture itself for a model published before there were
  // cut-outs). In the strip, whose frames are four to three, the cards'
  // picture, which is too since 2026-10-24.
  const picture = set ? `/library/${id}.cutout.webp` : old ? (version.has_image ? `/m/${id}/v/${version.n}.cutout.png` : "")
    : (model.has_image ? `/m/${id}.cutout.png` : "");
  const small = set ? `/library/${id}.webp` : !old && model.has_thumb
    ? `/m/${id}.webp?v=${(Date.parse(model.updated_at || "") || 0).toString(36)}` : picture;
  const { head, header, footer } = siteChrome(lang);
  const kind = say(kindLabel(model.kind));
  const about = model.description ? summary(model.description) : "";
  // The one it came from, while it is listed; one shared only by link is
  // not named. And which version of it the copy was made of, when its app
  // said: that version's page, which is the newest's while it is newest.
  const parent = (model.from || [])[0];
  const fromVersion = remixVersion(versions);
  const fromLine = !parent ? "" : parent.id
    ? `<p class="from">${sayHtml("Remixed from {model}", { model: `<a href="${at}/m/${parent.id}">${escapeHtml(parent.name)}</a>` })}`
      + `${fromVersion ? `, <a class="from-version" href="${at}/m/${parent.id}/v/${fromVersion}">${asText(say("version {n}", { n: fromVersion }))}</a>` : ""}`
      + `${parent.author ? escapeHtml(say(", by {name}", { name: parent.author })) : ""}</p>`
    : `<p class="from">${asText(say("Remixed from a model shared by link"))}</p>`;
  // What it changed from that version, counted as it was published
  // (api/_remix.js): said under the credit on the newest version's page,
  // and lit in its 3D view (/m/X/changes.json).
  const changed = !set && !old && parent?.id ? ownChanges(model.tree, version.n, parent.id) : null;
  const changedLine = changed ? changedLineHtml(changed, at, parent.id, fromVersion) : "";
  // What it is, as pills, each said once there is one. Its steps are the
  // ones its step player and booklet number, counted from the file shown;
  // a file that carries none has them worked out as it opens, and they are
  // not said. What is built on the side is said apart: the orrery's 87
  // steps, and its 12 sub-assemblies' 64.
  const side = stepsCounted ? sideSaid(stepsCounted) : "";
  const facts = set ? setFacts(set, shownModel.parts) : [
    `<li class="pill">${escapeHtml(counted(shownModel.parts, "part"))}</li>`,
    stepsCounted ? `<li class="pill" data-steps="${stepsCounted.steps}">${model.own_steps
      ? asText(say("{steps}, laid out by its builder", { steps: stepsSaid(stepsCounted) })) : stepsSaid(stepsCounted)}</li>` : "",
    side ? `<li class="pill" data-side="${stepsCounted.side}">${side}</li>` : "",
    model.technic ? `<li class="pill">${asText(say("Technic or a mechanism"))}</li>` : "",
    // How it was made, when not by hand: said here, never on its card
    // (web/card.js).
    madeFact(model),
    // What it does: its own motions' names, else what its app found moves.
    movesWords(model) ? `<li class="pill">${escapeHtml(`${say("Moves:")} ${movesWords(model)}`)}</li>` : "",
    Number(model.views) ? `<li class="pill"><span data-count="views">${counted(model.views, "view")}</span></li>` : "",
    `<li class="pill">${model.listed ? sayHtml("In the gallery since {when}", { when: when(model.listed_at) })
      : asText(say("Shared by link"))}</li>`,
    newest > 1 ? `<li><a class="pill version-line" href="#versions">${asText(old ? say("Version {n} of {newest}", { n: version.n, newest })
      : say("Version {n}", { n: version.n }))}</a></li>` : "",
    // Still being built (supabase/wip.sql): its Log has each version.
    isWip(versions) ? `<li><a class="pill wip" href="#versions">${asText(say("Work in progress"))}</a></li>` : "",
    Number(model.remixes) ? `<li><a class="pill" href="#remixes">${counted(model.remixes, "remix", "remixes")}</a></li>` : "",
    // In the public lists it is in (docs/SOCIAL.md U11), each a card under
    // Lists.
    Number(lists?.count) ? `<li><a class="pill" href="#collections" data-lists="${Number(lists.count)}">`
      + `${asText(say("In {lists}", { lists: counted(lists.count, "list") }))}</a></li>` : "",
  ].join("");
  const tags = (model.tags || []).map((tag) =>
    `<li><a class="pill tag" href="${at}/gallery?tag=${encodeURIComponent(tag)}">${escapeHtml(tag)}</a></li>`).join("");
  const line = (model.from || []).map((one) => one.id
    ? `<li><a href="${at}/m/${one.id}">${escapeHtml(one.name)}</a>${one.author ? escapeHtml(say(", by {name}", { name: one.author })) : ""}</li>`
    : `<li>${asText(say("a model shared by link"))}</li>`).join("");
  const listedRemixes = model.remixes_listed || [];
  const unlisted = Math.max(0, (Number(model.remixes) || 0) - listedRemixes.length);
  // The tree both ways, each with what it changed (api/_remix.js treeHtml):
  // where remix_tree answered and there is a model either way; else the
  // line and the cards, as before it.
  const drawnTree = set ? "" : treeHtml(origin, at, model.tree, { id, name: model.name, author: creditName(model) || model.author,
    has_image: model.has_image, has_thumb: model.has_thumb, updated_at: model.updated_at });
  // The marks nearly every card on the page carries, left off (web/card.js).
  const quiet = quietMarks([...listedRemixes.map((row) => cardOf(origin, row)), ...(model.by ? next.by : []), ...next.like,
    ...(next.gallery || [])].map(marksOf));
  // A shared model's page in each language, each naming the others; English
  // for any other. Its own address is its canonical, an older version's
  // the newest's in its language.
  const page = set ? `/library/${id}` : `/m/${id}${old ? `/v/${version.n}` : ""}`;
  const alternates = [["en", ""], ...SITE_LANGS.map((code) => [code, `/${code}`]), ["x-default", ""]]
    .map(([code, where]) => `<link rel="alternate" hreflang="${code}" href="${escapeHtml(`${origin}${where}${page}`)}">`).join("\n");
  const own = at ? `${origin}${at}${set ? `/library/${id}` : `/m/${id}`}` : links(origin, id).url;
  // The copy's words, for what the page's own scripts say (web/card.js say).
  const scriptWords = words ? `<script type="application/json" id="site-words">${JSON.stringify(words).replace(/</g, "\\u003c")}</script>\n` : "";
  return `<!doctype html>
<html lang="${lang}">
<head>
${pageHead(origin, model, id, title, { about, canonical: own, url: own, alternates, clip: old ? null : clip })}
${old ? '<meta name="robots" content="noindex">\n' : ""}${scriptWords}${head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<link rel="stylesheet" href="/view3d.css">
<script src="/share-page.js" defer></script>
<script src="/model-page.js" type="module"></script>
<script src="/report.js" type="module"></script>
<script src="/follow.js" type="module"></script>
${structured(origin, id, model)}
</head>
<body data-viewer="${escapeHtml(viewer)}" data-id="${id}" data-version="${version.n}" data-newest="${newest}"${quiet ? ` data-quiet="${quiet}"` : ""}>
<a class="skip" href="#main">${asText(say("Skip to content"))}</a>
${header}
<main id="main">
<article class="wrap wide model-page">
  <nav class="crumbs" aria-label="${asText(say("Where it is"))}">${set ? `<a href="${at}/gallery">${asText(say("Gallery"))}</a>`
    + ` <span aria-hidden="true">›</span> <a href="${at}/library">${asText(say("Sets"))}</a>${set.theme
    ? ` <span aria-hidden="true">›</span> <a href="${at}/library?theme=${encodeURIComponent(set.theme)}">${escapeHtml(themeSaid(set.theme))}</a>` : ""}`
    : `<a href="${at}/gallery">${asText(say("Gallery"))}</a>${model.kind
    ? ` <span aria-hidden="true">›</span> <a href="${at}/gallery?kind=${encodeURIComponent(model.kind)}">${escapeHtml(kind)}</a>` : ""}`}</nav>
  ${old ? `<p class="old-version" role="note"><b>${asText(say("An older version."))}</b> ${sayHtml("This is version {n} of {newest}, "
    + "published {when}.", { n: version.n, newest, when: when(version.at) })} <a href="${at}/m/${id}">${asText(say("See the newest, "
    + "version {newest}", { newest }))}</a></p>` : ""}
  <div class="top">
    <div class="media">
    <a class="picture" id="model-picture" href="${escapeHtml(viewer)}" aria-label="${escapeHtml(say("View {name} in 3D", { name: model.name }))}"
      data-scene="${fileAt}/scene.json"${changed?.drawn ? ` data-changes="/m/${id}/changes.json?n=${changed.n}"` : ""} data-parts="${Number(shownModel.parts) || 0}">${picture
      ? `<span class="waiting" aria-hidden="true">${asText(say("Loading its picture…"))}</span><img src="${picture}" alt="${escapeHtml(model.name)}" width="1200" height="630" fetchpriority="high">`
      : `<span class="none">${asText(say("No picture"))}</span>`}<span class="go" aria-hidden="true">${asText(say("View in 3D"))}</span></a>
    ${mediaStrip(model, picture, photos, small)}
    </div>
    <div class="side">
      <h1>${escapeHtml(model.name)}</h1>
      ${designerRow(model)}
      ${modelledLine(model)}
      ${altHtml(model.alt)}
      <div class="actions">
        ${set ? `<a class="cta" href="${escapeHtml(viewer)}" title="${asText(say("Open it in Brickworks in a tab of its own: turn it in 3D, step through its build, change it and save it as yours"))}">${asText(say("Open in Brickworks"))}</a>`
    : `<a class="cta" href="${escapeHtml(`${viewer}&build`)}" title="${asText(say("Build it with real bricks, one step at a time from step 1: no account needed"))}">${asText(say("Build it"))}</a>
        <span class="open-split"><a class="cta ghost" href="${escapeHtml(copyLink)}" title="${asText(say("Copy it into your own models, to change and make yours"))}">${asText(say("Open in Brickworks"))}</a>${claudeButton()}</span>`}
        <a class="cta ghost" href="${fileAt}.mpd" download>${asText(say("Download"))}</a>
      </div>
      ${set ? "" : claudePanel(origin, id, model)}
      ${actionBar(origin, id, model, old ? `${origin}${at}/m/${id}/v/${version.n}` : at ? own : links(origin, id).url, `${fileAt}.mpd`)}
      ${set || old ? "" : postFacts(origin, id, shownModel, about)}
      <ul class="facts pills">${mark ? `<li class="tested">${testedMark(mark, stepsCounted)}</li>` : ""}${facts}</ul>
      ${fromLine}
      ${changedLine}
      ${basedHtml(model.based || [])}
      <p class="tested-note" id="tested-note" data-id="${id}" data-version="${version.n}" role="note" hidden></p>
    </div>
    <div class="rest">
  ${pageTabs(model, newest, lists?.count, parts, logged(versions))}
  <section class="words" id="about" aria-labelledby="about-h"><h2 id="about-h">${asText(say("About it"))}</h2>
    ${model.description ? `<p class="description">${escapeHtml(model.description)}</p>` : ""}
    ${tags ? `<ul class="tags pills" aria-label="${asText(say("Tags"))}">${tags}</ul>` : ""}
    <div class="licence"><h3 id="licence-h">${asText(say("Licence"))}</h3>${licenceWords(model)}</div></section>
  ${partsSection(fileAt, parts)}
  ${set ? "" : `${commentsSection(id, version.n, newest, stepsCounted ? stepsCounted.pages : null)}
  ${buildsSection(id, model, photos)}
  <section class="tree" id="remixes" aria-labelledby="tree-h"><h2 id="tree-h">${asText(say("Remixes"))}</h2>
    ${drawnTree ? `${drawnTree}${unlisted ? `<p class="note">${asText(say(listedRemixes.length
      ? "And {remixes} shared by link, not in the gallery." : "{remixes} shared by link, not in the gallery.",
    { remixes: counted(unlisted, "remix", "remixes") }))}</p>` : ""}` : `${line ? `<h3>${asText(say("It came from"))}</h3><ol class="line">${line}</ol>` : ""}
    ${listedRemixes.length || unlisted
      ? `<h3>${asText(say("Made from it"))}</h3>${listedRemixes.length
        ? `<div class="models compact">${listedRemixes.map((row) => cardHtml(cardOf(origin, row))).join("")}</div>` : ""}`
        + (unlisted ? `<p class="note">${asText(say(listedRemixes.length ? "And {remixes} shared by link, not in the gallery."
          : "{remixes} shared by link, not in the gallery.", { remixes: counted(unlisted, "remix", "remixes") }))}</p>` : "")
      : `<p class="note none">${sayHtml("Nobody has remixed it yet. {open} to make a copy of your own to change; share that, "
        + "and it shows here.", { open: `<a href="${escapeHtml(copyLink)}">${asText(say("Open it in Brickworks"))}</a>` })}</p>`}`}
  </section>`}
  ${listsSection(lists)}
  ${versionsSection(id, versions, version, at, model)}
    </div>
  </div>
  ${model.by ? nextRow("more-by", sayHtml("More by {name}", { name: `<a href="${langAt()}/u/${escapeHtml(model.by.handle)}">${escapeHtml(model.by.name)}</a>` }),
    next.by, `${langAt()}/u/${model.by.handle}`) : ""}
  ${nextRow("similar", set ? escapeHtml(set.theme ? say("More {theme} from the LDraw library", { theme: set.theme })
    : say("More sets from the LDraw library")) : asText(say("Similar models")), next.like,
  set?.theme ? `${at}/library?theme=${encodeURIComponent(set.theme)}` : "")}
  ${nextRow("from-gallery", asText(say("More in the gallery")), next.gallery || [], `${at}/gallery`)}
</article>
</main>
${footer}
</body>
</html>`;
}

/// The strip under the picture (docs/SOCIAL.md U4): the picture it was
/// published with, then its owner's own photos, then the photos of real
/// builds, each a link to its place under Builds; web/model-page.js shows
/// the one chosen in the picture's place. With no photo it is drawn hidden,
/// for its owner to add the first: model-page.js shows it to them alone.
/// [small] is the published picture as the strip shows it.
function mediaStrip(model, picture, photos, small = picture) {
  // Right under the picture, so in the first screen: its first five asked at once.
  let shown = 0;
  const thumb = (source, alt, attrs) => `<a class="thumb" ${attrs}><img ${source(shown >= 5)} alt="${escapeHtml(alt)}" `
    + `width="96" height="72" loading="${shown++ < 5 ? "eager" : "lazy"}" decoding="async"></a>`;
  // A thumb its card's copy where that is enough, the picture's place the whole photo.
  const file = (photo) => escapeHtml(photoSrc(photo.id));
  return `<div class="media-strip scroller" id="pictures" role="group" aria-label="${asText(say("Its pictures"))}"${photos?.length ? "" : " hidden"}>`
    + (picture ? thumb(() => `src="${small}"`, say("{name}, as it was published", { name: model.name }),
      `href="${picture}" data-picture="${picture}" aria-current="true"`) : "")
    + (photos || []).map((photo) => thumb((lazy) => photoAttrs(photo, "thumb", { lazy }), photo.own ? say("{name}, a photo by its designer", { name: model.name })
      : photo.by ? say("A real build of {name}, by {builder}", { name: model.name, builder: photo.by.name })
      : say("A real build of {name}", { name: model.name }),
    `href="#photo-${escapeHtml(photo.id)}" data-picture="${file(photo)}"${photo.own ? " data-own" : ""}`)).join("")
    + `<button type="button" class="thumb add" data-add-picture hidden>${asText(say("Add a picture"))}</button></div>`;
}

/// The page's tabs (docs/SOCIAL.md U4): a link to each part below, with its
/// count once there is one, kept on screen as the page scrolls; the one
/// being read is marked by web/model-page.js, which also counts the
/// comments as it lists them. Versions only once there are two.
function pageTabs(model, newest, inLists = 0, parts = null, log = newest > 1) {
  const tab = (key, name, n = 0) => `<a href="#${key}" data-tab="${key}">${asText(name)}`
    + (Number(n) ? ` <span class="n">${number(n)}</span>` : "") + "</a>";
  return `<nav class="tabs page-tabs" id="page-tabs" aria-label="${asText(say("On this page"))}">${tab("about", say("About"))}`
    + `${parts ? tab("parts", say("Parts"), parts.pieces) : ""}`
    + `${model.library ? "" : `${tab("comments", say("Comments"))}${tab("builds", say("Builds"), model.builds)}${tab("remixes", say("Remixes"), model.remixes)}`}`
    + `${Number(inLists) ? tab("collections", say("Lists"), inLists) : ""}`
    + `${log ? tab("versions", say("Log"), newest) : ""}</nav>`;
}

/// How many rows the Parts list shows before Show all, and each row's
/// height, which web/directory.css gives every row: the space the list will
/// take is kept for it before it comes, so nothing under it moves.
export const LOTS_SHOWN = 12;
export const LOT_ROW = 60;

/// Its parts (site278, docs/SOCIAL.md U4): how many in how many lots, the
/// three shops' lists to download, and the list itself, which
/// web/model-page.js asks for (/m/X/parts.json) as the section nears the
/// screen, a row a lot under a row a colour, or a kind. Nothing where
/// this deployment cannot list them. [at] is /m/X, or /m/X/v/N for an older
/// version.
function partsSection(at, parts) {
  if (!parts || !parts.lots.length) return "";
  const colours = new Set(parts.lots.map((lot) => lot.colour)).size;
  const rows = Math.min(LOTS_SHOWN, parts.lots.length + colours);
  const pab = pickABrick(parts);
  // Lean: every byte here is in the page's first bytes, and the list is not.
  return `<section class="parts" id="parts" aria-labelledby="parts-h" data-parts="${at}/parts.json">`
    + `<h2 id="parts-h">${asText(say("Parts"))}</h2><p class="note">${escapeHtml(say("{parts} in {lots}",
      { parts: counted(parts.pieces, "part"), lots: counted(parts.lots.length, "lot") }))}</p>`
    + `<div class="parts-bar"><div class="segmented" role="group" aria-label="${asText(say("Group them by"))}">`
    + `<button type="button" data-group="colour" aria-pressed="true">${asText(say("Colour"))}</button>`
    + `<button type="button" data-group="kind" aria-pressed="false">${asText(say("Kind"))}</button></div>`
    // The shops' lists together: beside Colour and Kind where they fit, on
    // a row of their own where not, so a phone's rows read shop by shop.
    + `<div class="parts-shops"><a class="cta ghost small" href="${at}/parts.xml" download>BrickLink XML</a>`
    + `<a class="cta ghost small" href="${at}/parts.csv" download>Rebrickable CSV</a>${pickABrickLinks(at, pab)}</div></div>`
    + pickABrickNote(pab)
    + `<ul class="lot-list" style="min-height:${rows * LOT_ROW}px"></ul>`
    + (parts.lots.length + colours > LOTS_SHOWN ? `<button type="button" class="cta ghost small" data-all hidden>`
      + `${escapeHtml(say("Show all {lots}", { lots: counted(parts.lots.length, "lot") }))}</button>` : "")
    + `</section>`;
}

/// The parts' LEGO® Pick a Brick list ([made]: api/_parts.js pickABrick),
/// beside the other two shops': /m/X/parts-pab.csv, and past
/// PICK_A_BRICK_LINES elements a file each, as Pick a Brick's upload takes
/// them (/m/X/parts-pab-2.csv, …), each saying which it is. None where no
/// part has an element number known.
function pickABrickLinks(at, made) {
  const all = made.files.length;
  const what = say("A list of LEGO® element numbers to upload at LEGO® Pick a Brick");
  const why = all > 1 ? `. ${say("Pick a Brick takes {lines} elements a file.", { lines: number(PICK_A_BRICK_LINES) })}` : "";
  return made.files.map((file, n) => `<a class="cta ghost small" href="${at}/parts-pab${n ? `-${n + 1}` : ""}.csv" download`
    + ` title="${asText(`${what}${why}`)}">${asText(all > 1
      ? say("LEGO® Pick a Brick CSV, {n} of {all}", { n: number(n + 1), all: number(all) })
      : say("LEGO® Pick a Brick CSV"))}</a>`).join("");
}

/// What the Pick a Brick list ([made]) leaves for a person to find
/// elsewhere, under the shops' buttons: the lots with no LEGO® element
/// number known (a made part among them), counted, never guessed; and each
/// element wanted more times than Pick a Brick takes, the rest to add by
/// hand. Nothing where it leaves nothing.
function pickABrickNote(made) {
  const said = [];
  if (made.missing.length) {
    said.push(say("Not on the Pick a Brick list, with no LEGO® element number known: {lots} ({parts}).", {
      lots: counted(made.missing.length, "lot"),
      parts: counted(made.missing.reduce((n, lot) => n + lot.count, 0), "part") }));
  }
  const over = Object.entries(made.over);
  if (over.length) {
    said.push(say("Pick a Brick takes {most} of an element: add by hand {more}.", { most: number(PICK_A_BRICK_MOST),
      more: over.map(([element, more]) => say("{n} more of {element}", { n: number(more), element })).join(", ") }));
  }
  return said.length ? `<p class="note pab-note">${said.map((one) => escapeHtml(one)).join(" ")}</p>` : "";
}

/// The public lists it is in (docs/SOCIAL.md U11, [PR-C]), each a card
/// with its cover and whose it is, the one it was put in last first; only
/// once it is in one, since a part that says nothing is a dead end.
function listsSection(lists) {
  if (!lists || !Number(lists.count) || !lists.lists.length) return "";
  const more = Number(lists.count) - lists.lists.length;
  return `<section class="in-lists" id="collections" aria-labelledby="lists-h"><h2 id="lists-h">${asText(say("In lists"))}</h2>`
    + `<p class="note">${asText(say("People put it in {lists}.", { lists: counted(lists.count, "public list") }))}</p>`
    + `<div class="list-cards">${lists.lists.map((list) => listCardHtml(list, lists.covers, { by: true })).join("")}</div>`
    + (more > 0 ? `<p class="note">${asText(say("And {lists} more.", { lists: counted(more, "list") }))}</p>` : "")
    + `</section>`;
}

/// One photo of a real build, as the strip shows it: the photo, the line
/// its builder wrote, who (their profile, if they made one) and when, and
/// a way to report it. Every word is theirs, escaped.
function buildFigure(model, photo) {
  const by = photo.by ? sayHtml("by {name}", { name: `<a href="${langAt()}/u/${escapeHtml(photo.by.handle)}">${escapeHtml(photo.by.name)}</a>` })
    : asText(say("by a builder"));
  return `<figure class="build" id="photo-${photo.id}" data-photo="${photo.id}">`
    + `<img ${photoAttrs(photo, "strip")} alt="${escapeHtml(say("A real build of {name}", { name: model.name }))}" `
    + `width="${photo.width}" height="${photo.height}" loading="lazy" decoding="async">`
    + `<figcaption>${photo.words ? `<q>${escapeHtml(photo.words)}</q>` : ""}`
    + `<span class="by">${by} · ${when(photo.at)}</span>`
    + ` <button type="button" class="link" data-report="${asText(say("this photo"))}" data-report-photo="${photo.id}" hidden>${asText(say("Report it"))}</button>`
    + `</figcaption></figure>`;
}

/// Built by people: how many have built it to the last step, the strip of
/// photos of their real builds, and the way to add one (web/model-page.js
/// shows the form to somebody signed in, and to the model's owner the
/// photos they hid, with a way to hide each). Nobody yet is one line and
/// the way in, never a count of none; photos that could not be read (null)
/// are not said to be none.
function buildsSection(id, model, photos) {
  const builds = Number(model.builds) || 0;
  return `<section class="builds" id="builds" aria-labelledby="builds-h" data-id="${id}">
    <h2 id="builds-h">${asText(say("Built by people"))}</h2>
    ${builds ? `<p class="built-line">${asText(builds === 1 ? say("Built to the last step once, by people following its steps in Brickworks.")
      : say("Built to the last step {times}, by people following its steps in Brickworks.", { times: counted(builds, "time") }))}</p>` : ""}
    ${photos?.length ? `<div class="build-strip scroller" role="group" aria-labelledby="builds-h">${photos.map((photo) => buildFigure(model, photo)).join("")}</div>`
      : !photos ? `<p class="note no-builds" hidden></p>` : `<p class="note no-builds">${asText(builds ? say("No photos of a real build yet. Built it? Add yours.")
        : say("Nobody has built it yet. Built it? Add a photo of yours."))}</p>`}
    <div class="add-build" id="add-build" data-id="${id}">
      <button type="button" class="cta ghost" data-add-build>${asText(say("I built it: add a photo"))}</button>
      <form class="build-form" hidden>
        <label>${asText(say("A photo of your build"))} <small>${asText(say("JPEG, PNG or WebP, up to 8 MB"))}</small>
          <input type="file" name="photo" accept="image/jpeg,image/png,image/webp" required></label>
        <label>${asText(say("A line about it"))} <small>${asText(say("optional"))}</small>
          <input type="text" name="words" maxlength="140" placeholder="${asText(say("Built it with my own bricks, one swap in step 4"))}"></label>
        <p class="note">${asText(say("Photos show the build, not people: no faces, and nobody's name or address."))}</p>
        <div class="actions"><button class="cta" type="submit">${asText(say("Add the photo"))}</button>
          <button class="cta ghost" type="button" data-cancel>${asText(say("Cancel"))}</button></div>
        <p class="said" role="status"></p>
      </form>
      <p class="said build-said" role="status"></p>
    </div>
  </section>`;
}

/// Where the comments go: drawn by web/model-page.js from
/// /api/people?op=comments (api/_comments.js) as threads, so the page
/// itself is the same for everybody and kept by the CDN. The step picker has the steps of
/// the version shown; a model of more than a thousand has a number to type.
function commentsSection(id, shown, newest, steps) {
  // Steps not known: any step, by number.
  const many = !steps || Number(steps) > 1000;
  const options = !steps || many ? "" : Array.from({ length: Number(steps) },
    (_, at) => `<option value="${at + 1}">${asText(say("step {n}", { n: at + 1 }))}</option>`).join("");
  const whole = asText(say("the whole model"));
  const picker = many
    ? `<input id="comment-step" type="number" min="1"${steps ? ` max="${Number(steps)}"` : ""} inputmode="numeric" placeholder="${whole}">`
    : `<select id="comment-step"><option value="">${whole}</option>${options}</select>`;
  // Shown once asked (web/model-page.js); until then a skeleton holds its
  // place at the size most are drawn at (none yet, and the box), so its
  // coming moves nothing under it: it pushed Builds down the screen (site275).
  return `<div class="comments-hold skeleton" id="comments-hold" aria-hidden="true"><span class="bone short title"></span>
    <span class="bone line"></span><span class="bone line short"></span><span class="bone box"></span><span class="bone button"></span></div>
  <section class="comments" id="comments" aria-labelledby="comments-h" data-id="${id}"
    data-version="${shown}" data-newest="${newest}" hidden>
    <h2 id="comments-h">${asText(say("Comments"))}</h2>
    <p class="note comments-lede">${sayHtml("What builders said about it and its steps, the newest first, with the replies under each. "
      + "Plain words only; {guidelines} say what is welcome.", { guidelines: `<a href="${langAt()}/guidelines">${asText(say("the guidelines"))}</a>` })}</p>
    <p class="note talk-about" id="talk-about" hidden></p>
    <ol class="comment-list"></ol>
    <form class="comment-new" hidden>
      <div class="comment-on"><label for="comment-step">${asText(say("On"))}</label> ${picker}
        <span class="note">${asText(shown < newest ? say("of version {n}, an older one", { n: shown }) : say("of version {n}", { n: shown }))}</span></div>
      <label class="visually-hidden" for="comment-body">${asText(say("Your comment"))}</label>
      <textarea id="comment-body" maxlength="1000" rows="3"
        placeholder="${asText(say("Say something about it, or about a step: this part goes under, not over"))}"></textarea>
      <div class="actions"><button class="cta small" type="submit">${asText(say("Add the comment"))}</button>
        <span class="note comment-count" aria-live="polite"></span></div>
    </form>
    <div class="comment-why" hidden><p class="note"></p></div>
    <p class="said comments-said" role="status"></p>
  </section>`;
}

/// Whether a model's page keeps a Log: once it has two versions, or one
/// shared as work in progress. Pure.
const logged = (versions) => (versions[0]?.n ?? 1) > 1 || versions.some((one) => one.wip);

/// The page's Log (buildlog, 2026-11-23), once it keeps one: the version
/// shown, what changed in it (worked out from the files, and part by part
/// on request) and what its owner said, how far a builder of the one before
/// can carry on; while it is work in progress, that it is, and for its
/// designer Mark it finished (web/model-page.js shows it to them alone);
/// then every version, newest first, each with its small picture (the one
/// kept with it, /m/X/v/N.webp), its date, what changed and its note, work
/// in progress and the finished one marked, each opening its own page.
function versionsSection(id, versions, shown, at = "", model = {}) {
  const newest = versions[0]?.n ?? 1;
  if (!logged(versions) || !shown) return "";
  const said = saidOf(shown.n, shown.changes);
  const changes = shown.changes;
  // Each lot's colour as the parts list names it in the page's language.
  const colours = at ? partNames(at.slice(1))?.colours : null;
  const lots = changes ? [...changes.added.map((lot) => `<li>${escapeHtml(say("Added {lot}", { lot: lotSaid(lot, colours) }))}</li>`),
    ...changes.removed.map((lot) => `<li>${escapeHtml(say("Removed {lot}", { lot: lotSaid(lot, colours) }))}</li>`)].join("") : "";
  const kept = shown.n > 1 && shown.first > 1
    ? `<p class="kept">${asText(shown.first === 2
      ? say("Step 1 is as they were in version {n}: a builder who got that far can carry on.", { n: shown.n - 1 })
      : say("Steps 1–{last} are as they were in version {n}: a builder who got that far can carry on.",
        { last: shown.first - 1, n: shown.n - 1 }))}</p>` : "";
  const building = isWip(versions)
    ? `<p class="wip-line" role="note"><span class="pill wip">${asText(say("Work in progress"))}</span> `
      + `${asText(say("Its designer is still building it: each new version comes here, to their followers and to its Talk thread."))} `
      + `<button type="button" class="cta ghost small" data-finish="${id}" hidden>${asText(say("Mark it finished"))}</button></p>`
      + `<p class="said finish-said" role="status" hidden></p>` : "";
  const entries = versions.map((one) => {
    // Each at its own address for good: the newest's stays right once a
    // later one comes, as a Talk post's link to it does.
    const href = `${at}/m/${id}/v/${one.n}`;
    const words = changedOf(one.n, one.changes);
    const pictured = one.has_thumb || one.has_image || (one.n === newest && model?.has_thumb);
    // Its time in the address: a version's picture is that version's for good.
    const stamp = (Date.parse(one.at || "") || 0).toString(36);
    const marks = [one.wip ? `<span class="pill wip">${asText(say("Work in progress"))}</span>` : "",
      one.finished_at ? `<span class="pill finished">${asText(say("Finished"))}</span>` : ""].filter(Boolean).join(" ");
    const here = one.n === shown.n;
    return `<li class="log-entry${one.wip ? " wip" : ""}"${here ? ' aria-current="true"' : ""}>`
      + `<a class="log-picture" href="${href}" tabindex="-1" aria-hidden="true">${pictured
        ? `<img src="/m/${id}/v/${one.n}.webp?at=${stamp}" alt="" width="160" height="120" loading="lazy" decoding="async">` : ""}</a>`
      + `<div class="log-main"><p class="log-head"><a href="${href}">${asText(say("Version {n}", { n: one.n }))}</a>`
      + `${one.n === newest ? asText(say(", the newest")) : ""}${here && one.n !== newest ? asText(say(", this one")) : ""}`
      + ` <span class="when">${when(one.at)}</span>${marks ? ` ${marks}` : ""}</p>`
      + `${words ? `<p class="log-changed">${escapeHtml(words)}</p>`
        : one.n === 1 ? `<p class="log-changed">${asText(say("The first version."))}</p>` : ""}`
      + `${one.note ? `<p class="log-note"><q>${escapeHtml(one.note)}</q></p>` : ""}</div></li>`;
  }).join("");
  return `<section class="versions" id="versions" aria-labelledby="versions-h"><h2 id="versions-h">${asText(say("Log"))}</h2>
    ${building}
    <p class="changed" data-version="${shown.n}">${said ? escapeHtml(said) : asText(say("Version {n}, the first.", { n: shown.n }))}
      <span class="when">${when(shown.at)}</span></p>
    ${shown.note ? `<blockquote class="version-note"><p>${escapeHtml(shown.note)}</p></blockquote>` : ""}
    ${kept}
    ${lots ? `<details class="lots"><summary class="cta ghost small">${asText(say("Part by part"))}</summary><ul>${lots}</ul></details>` : ""}
    <h3>${asText(say("Every version, the newest first"))}</h3><ol class="earlier log">${entries}</ol>
  </section>`;
}

/// /m/X/v/N for a version the model does not have.
function noVersionPage(origin, id, model, asked, newest, lang = "en") {
  const at = lang === "en" ? "" : `/${lang}`;
  const title = say("There is no version {n} of this model", { n: asked });
  const { head, header, footer } = siteChrome(lang);
  return `<!doctype html>
<html lang="${lang}">
<head>
${pageHead(origin, model, id, title)}
<meta name="robots" content="noindex">
${head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/follow.js" type="module"></script>
</head>
<body>
<a class="skip" href="#main">${asText(say("Skip to content"))}</a>
${header}
<main id="main">
  <div class="wrap gone">
    <h1>${escapeHtml(title)}</h1>
    <p class="lede">${escapeHtml(say("{name} has {versions}.", { name: model.name, versions: counted(newest, "version") }))}</p>
    <div class="actions"><a class="cta" href="${at}/m/${id}">${asText(say("See the newest"))}</a>
      <a class="cta ghost" href="${at}/gallery">${asText(say("See the gallery"))}</a></div>
  </div>
</main>
${footer || `<footer><small>${NOTICE}</small></footer>`}
</body>
</html>`;
}

/// The model a link names for oEmbed: its id from /m/X, /m/X/, /m/X/embed
/// or an older version's /m/X/v/N, on this site (any of its addresses, a
/// preview's too) or brickworks.diy; null for any other link.
export function oembedId(link, origin) {
  let url;
  try {
    url = new URL(String(link || ""));
  } catch {
    return null;
  }
  const ours = [new URL(origin).host, "brickworks.diy", "www.brickworks.diy"];
  if (!/^https?:$/.test(url.protocol) || !ours.includes(url.host)) return null;
  const found = url.pathname.match(/^\/m\/([A-Za-z0-9]{10})(?:\/v\/[1-9][0-9]{0,5}|\/embed)?\/?$/);
  return found ? found[1] : null;
}

/// The embed's size for oEmbed: 560 x 420, four to three, made smaller to
/// fit within [maxwidth] and [maxheight] when a consumer asks.
export function oembedSize(maxwidth, maxheight) {
  let width = 560;
  let height = 420;
  const most = (value) => (Number.isFinite(Number(value)) && Number(value) >= 1 ? Math.floor(Number(value)) : Infinity);
  if (most(maxwidth) < width) [width, height] = [most(maxwidth), Math.round((most(maxwidth) * 3) / 4)];
  if (most(maxheight) < height) [width, height] = [Math.round((most(maxheight) * 4) / 3), most(maxheight)];
  return { width, height };
}

/// /oembed?url=<a model's link> (docs/SOCIAL.md section 7, oembed.com): what
/// WordPress, Ghost, Notion, a Discourse forum or Iframely asks to put a
/// model's card in a page from its bare link, as Sketchfab's /oembed is
/// asked for its viewer ([SK-O]). A rich answer, the card's iframe
/// (/m/X/embed) at four to three, its name, whom it credits, its picture;
/// JSON only (501 for format=xml, as the spec says), 404 for a link that
/// is not a model shared here, and only what its page says to anybody.
async function oembed(request, response, origin) {
  const format = String(request.query?.format || "json");
  if (format !== "json") return response.status(501).json({ error: "JSON only: format=json" });
  const id = oembedId(request.query?.url, origin);
  if (!id) return response.status(404).json({ error: "name a model's link: url=https://brickworks.diy/m/<id>" });
  // Read as its page is (directory_model): whom it credits, as the page does.
  const model = await modelPage(id);
  if (!model) return response.status(404).json({ error: "There is no model shared at that link." });
  const link = links(origin, id);
  const { width, height } = oembedSize(request.query?.maxwidth, request.query?.maxheight);
  const credit = creditName(model);
  response.setHeader("Cache-Control", SHARED_CACHE);
  return response.status(200).json({
    version: "1.0",
    type: "rich",
    provider_name: "Brickworks",
    provider_url: origin,
    title: model.name,
    ...(credit ? { author_name: credit } : {}),
    ...(model.by && model.by.handle && !modelledByOf(model.modelled_by) ? { author_url: `${origin}/u/${model.by.handle}` } : {}),
    html: `<iframe src="${escapeHtml(`${link.url}/embed`)}" width="${width}" height="${height}" style="border:0;max-width:100%" `
      + `title="${escapeHtml(`${model.name}, a Brickworks model`)}" loading="lazy" allowfullscreen></iframe>`,
    width,
    height,
    thumbnail_url: model.has_image ? link.image : `${origin}/share.png`,
    thumbnail_width: 1200,
    thumbnail_height: 630,
    cache_age: 3600,
  });
}

/// /m/X/embed: a card sized for an iframe. Its picture is the model in 3D
/// as its page's is (docs/SOCIAL.md section 7, item 4): View in 3D on it,
/// a click on it or the first drag across it turns it there, in the frame
/// (web/start3d.js, web/embed.js); none of the 3D code comes until then,
/// and a model past what the device turns smoothly asks first, as on the
/// page. The app itself cannot run in somebody else's page — its threaded
/// engine needs the page to be cross-origin isolated, which only the top
/// window can ask for — so Build it (the guided build at step 1, as the
/// page's Build it is) and Open in the app open it in a tab of its own, as
/// every link here does (<base target>, the 3D view's own links too). Its
/// name opens the model's page.
///
/// In the theme whoever looks at it chose (docs/SOCIAL.md U14): web/theme.js,
/// as on every page, sets the one they chose on brickworks.diy where their
/// browser lets the frame read it; where it keeps a frame's storage apart
/// from the site's own (most do, inside somebody else's page), their
/// device's light or dark. data-embed: it never asks their account.
///
/// In German, French or Spanish at /de/m/X/embed (and /fr, /es), the code a
/// copy of its page gives (links): its words, its 3D view's too ([words],
/// as on the page), and its links to the page's copy and into the app in
/// the language. It names no other copy, so it stays in the one its code
/// asked for, whatever the browser around it reads.
///
/// [blind] (?blind=1, a challenge's vote two at a time, web/challenge.js,
/// unit challengestudio): the model alone, nobody's name anywhere in it,
/// nor its bar, whose name, page link and Build it the vote's page says
/// for itself; [row] is given it without its maker (embedAnswer).
function embedCard(origin, id, row, lang = "en", words = null, clip = null, blind = false) {
  const link = links(origin, id);
  const poster = row.has_image ? `/m/${id}.png` : "/share.png";
  const at = lang === "en" ? "" : `/${lang}`;
  const page = at ? `${origin}${at}/m/${id}` : link.url;
  const viewer = at ? `${link.viewer}&lang=${lang}` : link.viewer;
  const away = `<span class="visually-hidden"> ${asText(say("(opens in a new tab)"))}</span>`;
  const scriptWords = words ? `<script type="application/json" id="site-words">${JSON.stringify(words).replace(/</g, "\\u003c")}</script>\n` : "";
  return `<!doctype html>
<html lang="${lang}" data-embed>
<head>
${pageHead(origin, row, id, say("{name} — a Brickworks model", { name: row.name }), { url: page })}
${scriptWords}${siteChrome().head}
<base target="_blank">
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/view3d.css">
<script src="/embed.js" type="module"></script>
<style>
  /* The site's colours, type and corners (site.css); the 3D view's
     (view3d.css); only the card's layout here. */
  body { background: var(--panel); }
  main { display: flex; flex-direction: column; height: 100vh; }
  /* The model on the theme's studio ground, as a card's frame has it, and
     the 3D view over it, edge to edge. A finger up or down it scrolls the
     page around the frame; across it turns the model. */
  .media { flex: 1; min-height: 0; position: relative; }
  a.picture { display: block; height: 100%; background: var(--picture-ground); touch-action: pan-y pinch-zoom; }
  a.picture img, a.picture video { display: block; width: 100%; height: 100%; object-fit: cover; }
  .embed .view3d { inset: 0; width: auto; aspect-ratio: auto; border: 0; border-radius: 0; }
  /* Its clip's Pause and Play, a corner of the picture's own. */
  .media > [data-clip-toggle] { position: absolute; top: var(--s-2); right: var(--s-2); background: var(--panel); }
  .embed-bar { display: flex; align-items: center; gap: var(--s-3); padding: 10px 14px; border-top: 1px solid var(--line); }
  .embed-bar .words { flex: 1; min-width: 0; display: grid; color: inherit; text-decoration: none; }
  .embed-bar .words:hover b { text-decoration: underline; }
  .embed-bar b { overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .embed-bar small { color: var(--ink-soft); font-size: var(--t-small); }
  main[data-blind] .media > [data-clip-toggle] { top: auto; bottom: var(--s-2); }
</style>
</head>
<body>
<main class="embed"${blind ? " data-blind" : ""}>
<div class="media">
<a class="picture" href="${escapeHtml(viewer)}" rel="noopener" aria-label="${escapeHtml(say("View {name} in 3D", { name: row.name }))}"
  data-scene="/m/${id}/scene.json">${clip
    ? `<video src="${escapeHtml(clip.path)}" poster="${escapeHtml(poster)}" muted loop playsinline preload="metadata" disablepictureinpicture aria-hidden="true"></video>`
    : `<img src="${escapeHtml(poster)}" alt="">`}<span class="go" aria-hidden="true">${asText(say("View in 3D"))}</span></a>
${clip ? iconButtonHtml({ icon: "pause", name: say("Pause"), small: true, attrs: 'data-clip-toggle hidden' }) : ""}
</div>
${blind ? "" : `<div class="embed-bar">
  <a class="words" href="${escapeHtml(page)}" rel="noopener"><b>${escapeHtml(row.name)}</b><small>${escapeHtml(describe(row))} · Brickworks</small>${away}</a>
  <a class="cta small" href="${escapeHtml(`${viewer}&build`)}" rel="noopener" title="${asText(say("Build it with real bricks, one step at a time from step 1: no account needed"))}">${asText(say("Build it"))}${away}</a>
</div>
`}</main>
</body>
</html>`;
}

function gonePage(origin, id, existed, lang = "en") {
  const at = lang === "en" ? "" : `/${lang}`;
  const title = existed ? say("This model is no longer shared") : say("There is no model at this link");
  const said = existed
    ? say("Whoever shared it has taken it down. If they share it again, this link will work again.")
    : say("The link may be mistyped, or cut short.");
  const { head, header, footer } = siteChrome(lang);
  return `<!doctype html>
<html lang="${lang}">
<head>
${pageHead(origin, null, id, title)}
<meta name="robots" content="noindex">
${head}
<link rel="stylesheet" href="/site.css">
<link rel="stylesheet" href="/directory.css">
<script src="/follow.js" type="module"></script>
</head>
<body>
<a class="skip" href="#main">${asText(say("Skip to content"))}</a>
${header}
<main id="main">
  <div class="wrap gone">
    <h1>${escapeHtml(title)}</h1>
    <p class="lede">${escapeHtml(said)}</p>
    <div class="actions"><a class="cta" href="${at}/gallery">${asText(say("See the gallery"))}</a>
      <a class="cta ghost" href="${at || "/"}">${asText(say("Go to Brickworks"))}</a></div>
  </div>
</main>
${footer || `<footer><small>${NOTICE}</small></footer>`}
</body>
</html>`;
}

// What the pages may load and where they may send anything: themselves,
// and the sign-in service. The site's stylesheet and the page's own; the
// page's scripts (web/share-page.js counts a view on this same origin,
// web/model-page.js likes and keeps it for somebody signed in).
/// Its policy, with the sign-in service (SUPABASE_URL) beside itself for
/// a person who likes it, keeps it or puts it in a list (web/account.js),
/// and the parts store (PARTS_URL, today the same place), whose geometry
/// the Parts list draws each lot's picture from (web/part-pictures.js).
/// Pictures from itself alone, and those the page made (blob:): the lots'
/// are drawn on a canvas, not loaded.
function pageCsp() {
  const origin = (url) => {
    try {
      return new URL(url || "").origin;
    } catch {
      return "";
    }
  };
  const others = [...new Set([origin(process.env.SUPABASE_URL), origin(storeRoot())])].filter(Boolean);
  // blob: the GLB In your room writes in the page (web/room.js), which
  // <model-viewer> fetches by its blob: address; and the pictures and the
  // turn a kit to post it elsewhere draws (web/post-kit.js), shown before
  // they are saved: each made by the page itself, never another's.
  return "default-src 'none'; script-src 'self'; img-src 'self' blob:; media-src blob:; style-src 'self' 'unsafe-inline'; "
    + `connect-src 'self'${others.map((one) => ` ${one}`).join("")} blob:; base-uri 'none'; form-action 'none'; frame-ancestors 'none'`;
}
/// The embed's: the site's stylesheets ('self'), so the card is drawn in
/// the site's colours; its theme's script (web/theme.js), so in the colours
/// its viewer chose; the 3D view's (web/embed.js, /viewer3d.js), its model
/// from here and each part's geometry from the parts store, as the page's
/// 3D view has them. Framed by anybody.
function embedCsp() {
  let store = "";
  try {
    store = new URL(storeRoot()).origin;
  } catch { /* none: the 3D view says it cannot draw it */ }
  // media-src: its clip, from here, where its address asks it to play.
  return "default-src 'none'; script-src 'self'; img-src 'self'; media-src 'self'; style-src 'self' 'unsafe-inline'; "
    + `connect-src 'self'${store ? ` ${store}` : ""}; base-uri 'none'; form-action 'none'; frame-ancestors *`;
}

/// What the CDN may keep, and for how long: what every visitor is shown
/// (the list, a page, a picture) for half a minute, and given while it
/// asks again for half a minute more, so a page shared widely is one
/// function call a minute rather than one a visit. A browser asks the CDN
/// each time. The cost is that a model taken down, unlisted or taken out
/// leaves within a minute rather than at once (2026-10-13; it was no-cache
/// before the directory, when the probe found a picture outliving its
/// model by a minute at max-age=60).
export const SHARED_CACHE = "public, max-age=0, s-maxage=30, stale-while-revalidate=30";

function html(response, status, body, { embed = false, cache = SHARED_CACHE } = {}) {
  response.setHeader("Content-Type", "text/html; charset=utf-8");
  response.setHeader("Content-Security-Policy", embed ? embedCsp() : pageCsp());
  response.setHeader("X-Content-Type-Options", "nosniff");
  response.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  response.setHeader("Cache-Control", cache);
  return response.status(status).end(body);
}

/// A link that does not answer with a model: taken down (410) or never
/// there (404).
async function missing(id) {
  const existed = await wasShared(id);
  return existed
    ? { status: 410, error: "This model is no longer shared: whoever shared it has taken it down.", unpublished: true }
    : { status: 404, error: "There is no model at this link.", unpublished: false };
}

/// A model's page, read as the server: directory_model says for itself
/// that it is published, and names only what a visitor may know.
/// The steps of the model in the bucket's file [name], counted as it is
/// read (checkModel's count): what was counted when it was published was
/// the 0 STEP lines of its first model until steps206, and is not shown.
/// Null for none known, or no file. And [parts], its parts list as the app
/// counts it (partsOf), or null.
async function countedOf(name) {
  const file = await getFile(name).catch(() => null);
  if (!file) return { counted: null, parts: null };
  let counted = null;
  try {
    counted = checkModel(file.toString("utf8")).count;
  } catch {
    counted = null;
  }
  return { counted, parts: partsOf(name, file) };
}

// The parts lists worked out by this instance, by file: a version's file is
// never written again (a republish is the next version's), so each is worked
// out once while the instance lives, for its page and its exports.
const PARTS_KEPT = 40;
const partsKept = new Map();

/// The parts list of the bucket's file [name] ([file] its bytes), as the
/// app's parts list counts it (api/_parts.js inventoryOf), or null where
/// this deployment has no parts table or the file cannot be read. The
/// current version's file takes the next version's name when it is
/// republished, so it is kept by its bytes' length and ends too.
function partsOf(name, file) {
  const key = `${name}/${file.length}/${file.subarray(0, 64).toString("hex")}/${file.subarray(-64).toString("hex")}`;
  if (partsKept.has(key)) return partsKept.get(key);
  let found = null;
  try {
    const table = partsTable();
    found = table ? inventoryOf(file.toString("utf8"), table) : null;
  } catch {
    found = null;
  }
  partsKept.set(key, found);
  if (partsKept.size > PARTS_KEPT) partsKept.delete(partsKept.keys().next().value);
  return found;
}

/// How many parts a builder would buy for the model [text], as its page
/// and the app's parts list count them (inventoryOf: sub-models expanded,
/// a sticker counted, a hose once): what a publish keeps for its card.
/// [otherwise] (checkModel's count) where this deployment has no parts
/// table, or the list cannot be made or has nothing in it (no part the
/// catalogue knows), which a count kept may not be.
export function piecesIn(text, otherwise) {
  try {
    const table = partsTable();
    const pieces = table ? inventoryOf(text, table).pieces : 0;
    return pieces >= 1 ? pieces : otherwise;
  } catch {
    return otherwise;
  }
}

/// A file name for [name]: its words in lower case, joined by hyphens, their
/// letters and numbers in any script with their accents, as the app's own
/// names keep them (SubmodelFile.titled); nothing a file system minds;
/// [fallback] where none are left. At most 60 characters, cut between two
/// as a reader sees them, so no accent is cut off its letter. It kept a to z
/// and 0 to 9 alone, and named a Japanese title "model" and an Arabic one
/// "1" (se4check). A Windows device's name is the whole file's to say
/// ([attachment]).
export function fileName(name, fallback) {
  const words = String(name || "").normalize("NFKC").toLowerCase()
    .replace(/['’]/g, "").replace(/[^\p{L}\p{M}\p{N}]+/gu, "-").replace(/^[-\p{M}]+|-+$/gu, "");
  let cut = "";
  for (const { segment } of new Intl.Segmenter(undefined, { granularity: "grapheme" }).segment(words)) {
    if (cut.length + segment.length > 60) break;
    cut += segment;
  }
  return cut.replace(/-+$/, "") || fallback;
}

/// The Content-Disposition of a download named [file] ("castle-v2.mpd"):
/// its name as it is in filename* (RFC 6266, which every browser reads),
/// and in filename, for one that reads only that, the same in ASCII ("café"
/// as "cafe", a name of no Latin letter "model"). A name all ASCII has
/// filename alone, as it always had. A Windows device's name ("con.mpd" is
/// the console there) given a "_", looked for in the whole name as Windows
/// does: con-v2.mpd and con-bricklink.xml are no device's, and were
/// con_-v2.mpd (se4check), the app's rule the same (SubmodelFile.titled).
export function attachment(file) {
  const named = undeviced(file);
  const ascii = undeviced(named.normalize("NFKD").replace(/\p{M}/gu, "").replace(/[^\x21-\x7e]+/g, "-")
    .replace(/["\\;%]/g, "-").replace(/^-+(?=\.)/, "model").replace(/^-+/, "model-").replace(/-{2,}/g, "-")
    .replace(/-+(?=\.[^.]*$)/, ""));
  if (named === ascii) return `attachment; filename="${ascii}"`;
  const encoded = encodeURIComponent(named).replace(/['()*]/g, (c) => `%${c.charCodeAt(0).toString(16).toUpperCase()}`);
  return `attachment; filename="${ascii}"; filename*=UTF-8''${encoded}`;
}

/// [file] with a "_" after a Windows device's name that starts it, whatever
/// follows its first dot: con.mpd is con_.mpd, as the app has it.
function undeviced(file) {
  const device = file.split(".")[0].replace(/ +$/, "");
  return /^(con|conin\$|conout\$|prn|aux|nul|com[0-9¹²³]|lpt[0-9¹²³])$/i.test(device)
    ? `${device}_${file.slice(device.length)}` : file;
}

/// /m/X.mpd, /m/X/parts.json, .xml and .csv: the file as it is stored, or
/// its parts, of the version asked for (the newest unless one is). Read as a
/// visitor, signed out: what its page offers anybody. Kept by the CDN as the
/// page is, so a model taken down goes with its page.
async function download(response, op, id, asked, as, lang = "en") {
  const fail = (status, error) => response.status(status).setHeader("Cache-Control", "no-store").json({ error });
  const row = await publishedRow(id);
  if (!row) {
    const gone = await missing(id);
    return fail(gone.status, gone.error);
  }
  const versions = await versionsOf(id, row);
  const newest = versions[0].n;
  const shown = asked === null ? versions[0] : versions.find((one) => one.n === asked);
  if (!shown) return fail(404, `There is no version ${asked} of this model: it has ${count(newest, "version")}.`);
  const stored = versionFile(id, shown.n, newest, "mpd");
  const file = await getFile(stored);
  if (!file) return fail(410, "This model is no longer shared.");
  const base = `${fileName(row.name, id)}${shown.n === newest ? "" : `-v${shown.n}`}`;
  const named = (ext) => attachment(`${base}.${ext}`);
  response.setHeader("Cache-Control", SHARED_CACHE);
  response.setHeader("X-Content-Type-Options", "nosniff");
  if (op === "file") {
    response.setHeader("Content-Type", "application/x-ldraw");
    response.setHeader("Content-Disposition", named("mpd"));
    return response.status(200).end(file);
  }
  if (op === "scene" || op === "room") return sceneAnswer(response, stored, file, `m:${id}:${shown.n}`, op);
  return partsAnswer(response, partsOf(stored, file), base, as, { id, version: shown.n, newest }, lang);
}

/// A parts list as /m/X/parts.json, .xml and .csv answer it, and a set's
/// (/library/X/parts.json): [parts] the list (partsOf), [base] what its
/// files are named, [said] what the JSON says first. With [lang] one of
/// the site's languages (?lang=de), each lot's JSON also says its part,
/// colour and category as the app says them in it (said, colour_said,
/// category_said: api/_parts.js partNames), where it has words for them;
/// the shops' lists keep the names the shops know.
function partsAnswer(response, parts, base, as, said, lang = "en") {
  const fail = (status, error) => response.status(status).setHeader("Cache-Control", "no-store").json({ error });
  if (!parts) return fail(503, "This site cannot list a model's parts just now.");
  if (as === "xml") {
    response.setHeader("Content-Type", "application/xml; charset=utf-8");
    response.setHeader("Content-Disposition", attachment(`${base}-bricklink.xml`));
    return response.status(200).end(wantedList(parts).text);
  }
  if (as === "csv") {
    response.setHeader("Content-Type", "text/csv; charset=utf-8");
    response.setHeader("Content-Disposition", attachment(`${base}-rebrickable.csv`));
    return response.status(200).end(rebrickableCsv(parts).text);
  }
  // The LEGO® Pick a Brick list (pickABrick), a file of PICK_A_BRICK_LINES
  // elements at most: pab the first, pab-2 the second, as the page links
  // them; named as the app names them, -pickabrick.csv, or -pickabrick-N.csv
  // each where there are more.
  const asked = /^pab(?:-([1-9][0-9]{0,2}))?$/.exec(as);
  if (asked) {
    const { files } = pickABrick(parts);
    const n = Number(asked[1] || 1);
    if (!files.length) return fail(404, "No LEGO® element number is known for any part of this, so there is nothing for Pick a Brick.");
    if (n > files.length) return fail(404, `Its Pick a Brick list is ${count(files.length, "file")}.`);
    response.setHeader("Content-Type", "text/csv; charset=utf-8");
    response.setHeader("Content-Disposition", attachment(`${base}-pickabrick${files.length > 1 ? `-${n}` : ""}.csv`));
    return response.status(200).end(files[n - 1]);
  }
  if (as !== "json") return fail(400, `a parts list is json, xml, csv or pab, not ${as}`);
  // Each lot's picture is drawn by the page (web/part-pictures.js) from its
  // part's geometry (mesh), fetched from the store (root), in its colours.
  const root = storeRoot();
  const words = SITE_LANGS.includes(lang) ? partNames(lang) : null;
  const pab = pickABrick(parts);
  const rebrickable = rebrickableCsv(parts);
  return response.status(200).json({
    ...said, ...(words ? { lang } : {}), pieces: parts.pieces,
    lots: parts.lots.map((lot) => ({ part: lot.part, name: lot.name, category: lot.category, colour: lot.colour,
      colour_name: lot.colour_name, hex: lot.hex, count: lot.count, element: lot.element || null, custom: lot.custom,
      mesh: (root && lot.mesh) || null, ...namesOf(lot, words) })),
    root: root || null, colours: root ? paletteOf() : {},
    // What each shop's list leaves off: a made part, or a colour it has no
    // number for (Pick a Brick's: a lot with no element number known); and
    // the direct colours each lists in the nearest colour still made
    // ("#FF0000 as Reddish Orange"), as no shop sells them.
    left_out: { bricklink: wantedList(parts).left_out, rebrickable: rebrickable.left_out,
      pickabrick: pab.missing.length },
    // Rebrickable's parts-list import, as /m/X/parts.csv gives it, for the
    // kit its designer takes there (web/post-kit.js): made from this list,
    // so the kit fetches nothing the page has not.
    rebrickable_csv: rebrickable.text,
    stand_ins: wantedList(parts).stand_ins,
    // The Pick a Brick list: its files, its lines (an element each) and the
    // pieces on it, the pieces of the lots it left off, and each element
    // past what it takes, with how many more to add by hand.
    pickabrick: { files: pab.files.length, lines: pab.lines, pieces: pab.pieces,
      left_out_pieces: pab.missing.reduce((n, lot) => n + lot.count, 0), over: pab.over },
  });
}

/// /m/X/scene.json (with v=N, /m/X/v/N/scene.json) and a set's
/// /library/X/scene.json: the model packed for its page's 3D view
/// (api/_parts.js sceneOf; tools/viewer/inline.js draws it), each part's
/// geometry in the store the Parts list draws from. Asked only when a
/// visitor opens the 3D view, and kept by the CDN as the page is. As
/// [kind] "room" (/m/X/room.json, /library/X/room.json), what the page
/// writes the GLB Export writes of it from, for In your room (api/_parts.js
/// roomOf, web/room.js): asked only when a visitor taps it.
function sceneAnswer(response, name, file, of, kind = "scene") {
  const root = storeRoot();
  const key = `${kind}/${name}/${file.length}/${file.subarray(0, 64).toString("hex")}/${file.subarray(-64).toString("hex")}`;
  let scene = scenesKept.get(key);
  if (scene === undefined && root) {
    try {
      scene = (kind === "room" ? roomOf : sceneOf)(file.toString("utf8"), root, of);
    } catch {
      scene = null;
    }
    scenesKept.set(key, scene);
    if (scenesKept.size > SCENES_KEPT) scenesKept.delete(scenesKept.keys().next().value);
  }
  if (!scene) return response.status(503).setHeader("Cache-Control", "no-store").json({ error: "This site cannot draw a model in 3D just now." });
  return response.status(200).json(scene);
}
const scenesKept = new Map();
const SCENES_KEPT = 16;

/// The remixes, collections and models beside it on a model's page that
/// were made by somebody its owner blocked, left off it for everybody, as
/// their comments are (docs/SOCIAL.md section 9), and out of its counts.
/// The page is the same for everybody, so this is the owner's blocks.
async function leaveOffBlocked(own, page, next, lists) {
  if (!own?.owner) return;
  const handles = await orUnknown("share", blockedHandles(own.owner));
  if (!handles?.size) return;
  const remixes = page.remixes_listed || [];
  const beside = [...next.like, ...next.gallery];
  const tree = page.tree?.down || [];
  const gone = await orUnknown("share", blockedModels(own.owner, [...remixes, ...beside, ...tree].map((one) => one?.id)))
    || new Set();
  const kept = withoutBlocked(remixes, gone, handles);
  page.remixes = Math.max(0, (Number(page.remixes) || 0) - (remixes.length - kept.length));
  page.remixes_listed = kept;
  page.tree = treeWithout(page.tree, gone, handles);
  for (const key of ["like", "gallery"]) next[key] = withoutBlocked(next[key], gone, handles);
  if (lists) {
    const shown = lists.lists.filter((list) => !handles.has(String(list?.by?.handle || "")));
    lists.count = Math.max(0, lists.count - (lists.lists.length - shown.length));
    lists.lists = shown;
  }
}

async function modelPage(id) {
  if (!ID.test(id || "")) return null;
  const page = await db("rpc/directory_model", { method: "POST", body: { model_id: id } });
  // How it was made, only where its owner chose to say (web/card.js
  // madePublic): its fact, its tags, its keywords and what it is like.
  return page && typeof page === "object" ? madePublic(page) : null;
}

// ---------------------------------------------------------------------------

async function read(request, response) {
  const op = String(request.query?.op || "");
  const id = String(request.query?.id || "");
  const origin = originOf(request);

  if (op === "mine") return mine(request, response, origin);
  if (op === "made") return madeShown(request, response);
  if (op === "tested") return testedOwn(request, response);
  if (op === "clip_need") return clipNeed(request, response);
  if (op === "sweep") return sweep(request, response);
  if (op === "feature") return feature(request, response);
  if (op === "prompts") return prompts(request, response);
  if (op === "omr") return omrWatch(request, response);
  if (op === "list") return gallery(request, response, origin);
  if (op === "shelves") return shelves(request, response, origin);
  if (op === "sitemap") return sitemap(response, origin);
  if (op === "oembed") return oembed(request, response, origin);
  if (op === "bases") return bases(request, response);
  if (op === "set_based") return setBased(request, response, origin);
  if (op === "set_find") return setFind(request, response);
  // The LDraw library's sets (api/_library.js): /library's list, and each
  // set's page, cover, file and parts.
  // With tests=1, the OMR's arrivals staged for the lead to let out too
  // (tools/library_import.py), which nobody else is shown.
  if (op === "library") return library(request, response);
  if (op === "catalog_set") {
    return catalogSetPage(response, origin, String(request.query?.set || ""), String(request.query?.lang || "en"));
  }
  if (op === "catalog_parts") {
    return catalogParts(response, origin, String(request.query?.set || ""), String(request.query?.as || "json"),
      String(request.query?.lang || "en"));
  }
  if (op === "catalog_picture") return catalogPicture(response, origin, String(request.query?.set || ""));
  if (op === "catalog_photo") return catalogPhoto(response, String(request.query?.set || ""), String(request.query?.as || "card"));
  if (op === "catalog_owned") return catalogOwned(request, response, origin, String(request.query?.set || ""));
  if (op === "parts_missing") return partsMissing(request, response, origin, id);
  if (op === "sitemap_index") return sitemapIndex(response, origin);
  if (op === "sitemap_models") return sitemapOfModels(response, origin, String(request.query?.lang || ""));
  if (op === "sitemap_sets") return sitemapOfSets(response, origin, String(request.query?.n || ""), String(request.query?.lang || "en"));
  if (op === "set") return setPage(response, origin, id, testsAsked(request.query || {}), String(request.query?.lang || "en"));
  if (op === "set_cover") return setCover(response, id, String(request.query?.as || "card"), testsAsked(request.query || {}));
  if (op === "set_file") return setFile(response, id, testsAsked(request.query || {}));
  if (op === "set_parts") {
    return setParts(response, id, String(request.query?.as || "json"), testsAsked(request.query || {}), String(request.query?.lang || "en"));
  }
  if (op === "set_scene" || op === "set_room") return setScene(response, id, testsAsked(request.query || {}), op === "set_room" ? "room" : "scene");

  // A version asked for, where there can be one: the page, its picture and
  // the model. The gallery's small picture says which upload it is with a
  // v of its own (cardOf), which is not a version.
  const asked = ["page", "image", "cutout", "file", "parts", "scene", "room", ""].includes(op) ? askedVersion(request) : null;

  if (op === "file" || op === "parts" || op === "scene" || op === "room") {
    return download(response, op, id, asked, String(request.query?.as || "json"), String(request.query?.lang || "en"));
  }

  if (op === "page") {
    // In German, French or Spanish (/de/m/X); a language the site has no
    // words in is no page.
    const lang = String(request.query?.lang || "en");
    const words = lang === "en" ? null : siteWords(lang);
    if (lang !== "en" && !words) return html(response, 404, gonePage(origin, id, false));
    const speak = (draw) => inLanguage(lang, words, draw);
    const page = await modelPage(id);
    if (!page) {
      const gone = await missing(id);
      return html(response, gone.status, speak(() => gonePage(origin, id, gone.unpublished, lang)));
    }
    const versions = await versionsOf(id, page);
    const shown = asked === null ? versions[0] : versions.find((one) => one.n === asked);
    if (!shown) return html(response, 404, speak(() => noVersionPage(origin, id, page, asked, versions[0].n, lang)));
    // Whose it is: their own pictures lead its strip, and the page leads on
    // to the rest of their work. The database not answering is no owner.
    const own = await orUnknown("share", db(`shared_models?id=eq.${id}&select=owner,test`).then((rows) => rows[0] || null));
    // The collections it is in, with their covers: a test model's own page
    // counts a test account's too, as it offers test models. Each of these
    // is beside the model, not it: one not read is null (orUnknown), and
    // the page says nothing of it.
    const tests = own?.test === true;
    // Its clip (unit turntable): the model turning in its link's preview,
    // named only on the newest version's page and while it is of that
    // version; none read is none, and the picture card it always had.
    const [mark, photos, next, { counted, parts }, lists, based, clip, tree, alts] = await Promise.all([
      orUnknown("share", markOf(db, id, shown.n)),
      orUnknown("share", photosWhere(`model=eq.${id}`, shownPublicly)), nextOf(origin, id, page, own),
      countedOf(versionFile(id, shown.n, versions[0].n, "mpd")),
      listsOf(id, tests).then(async (found) => found && ({ ...found,
        covers: found.lists.length ? await coversOf(found.lists, tests).catch(() => new Map()) : new Map() })),
      orUnknown("share", basesOf(id)),
      shown.n === versions[0].n && !page.library ? orUnknown("share", clipOf(id)) : null,
      // Where it came from and what was remixed from it, with what each
      // changed (supabase/remix_changes.sql): null before that, and the
      // page is as it was.
      page.library ? null : orUnknown("share", treeOf(id)),
      orUnknown("share", altRowsOf([id]))]);
    // What it is based on, under its remix line and in its structured data.
    page.based = based || [];
    page.tree = tree;
    // And the real set (or the few) its parts all come from, counted when
    // it was published (api/_alts.js): a line under its credit, or the
    // share on its designer's own line for that set.
    altLine(page, alts?.get(id) || null, lang === "en" ? "" : `/${lang}`);
    await leaveOffBlocked(own, page, next, lists);
    // The owner's own photos first, as its pictures (docs/SOCIAL.md U4),
    // then the builds of everybody else, newest first.
    const ordered = photos && photos.map((photo) => ({ ...photo, own: Boolean(own && photo.account === own.owner) }))
      .sort((a, b) => Number(b.own) - Number(a.own));
    // Each person on it with their own picture, where they have one.
    await withFaces([page, ordered, next]);
    return html(response, 200, speak(() => sharePage(origin, id, page, versions, shown, publicMark(mark), ordered, next, counted,
      lists, parts, lang, words, clipShown(origin, id, clip, versions[0], lang === "en" ? "" : `/${lang}`))));
  }

  const row = await publishedRow(id);

  if (op === "clip") return clipAnswer(request, response, row, id);
  // What a remix's 3D view lights and draws as ghosts (api/_remix.js).
  if (op === "changes") return changesAnswer(response, row, storeRoot(), SHARED_CACHE);

  if (op === "embed") {
    // In the language of the page its code was taken from (/de/m/X/embed).
    const lang = String(request.query?.lang || "en");
    const words = lang === "en" ? null : siteWords(lang);
    if (lang !== "en" && !words) return html(response, 404, gonePage(origin, id, false), { embed: true });
    const speak = (draw) => inLanguage(lang, words, draw);
    if (!row) {
      const gone = await missing(id);
      return html(response, gone.status, speak(() => gonePage(origin, id, gone.unpublished, lang)), { embed: true });
    }
    // Its clip, which it plays muted in its picture's place when its
    // address asks (?autoplay=1, X's player for it: web/embed.js), while it
    // is of the newest version; without, the picture, as it always was, and
    // nothing of the clip read.
    const autoplay = request.query?.autoplay === "1";
    // Blind (?blind=1, a challenge's vote two at a time): its maker neither
    // asked nor given it, so their name is nowhere in what it draws.
    const blind = request.query?.blind === "1";
    const [by, clip, versions] = await Promise.all([blind ? null : orUnknown("share", profileOf(id, row.author)),
      autoplay ? orUnknown("share", clipOf(id)) : null, autoplay ? orUnknown("share", versionsOf(id, row, 1)) : null]);
    const playing = versions ? clipShown(origin, id, clip, versions[0]) : null;
    const shown = blind ? { ...row, author: null, by: null, modelled_by: null } : { ...row, by };
    // Framed by the challenge's page, which is cross-origin isolated (deploy.sh's
    // headers for every page): a frame in it must say it is too, or the
    // browser shows nothing in its place.
    if (blind) {
      response.setHeader("Cross-Origin-Embedder-Policy", "require-corp");
      response.setHeader("Cross-Origin-Resource-Policy", "same-origin");
    }
    return html(response, 200, speak(() => embedCard(origin, id, shown, lang, words, playing, blind)), { embed: true });
  }

  if (op === "image" || op === "cutout" || op === "thumb") {
    let name = op === "thumb" ? `${id}.webp` : `${id}.png`;
    let has = row && (op === "thumb" ? row.has_thumb : row.has_image);
    let type = op === "thumb" ? "image/webp" : "image/png";
    // An older version's own picture, kept with it.
    if (row && op !== "thumb" && asked !== null) {
      const versions = await versionsOf(id, row);
      const one = versions.find((version) => version.n === asked);
      has = Boolean(one && one.has_image);
      if (one) name = versionFile(id, one.n, versions[0].n, "png");
    }
    // A version's small picture (/m/X/v/N.webp, the page's Log and Talk's
    // cards): the one kept with it (supabase/wip.sql has_thumb), else its
    // big picture, for a version kept before small ones were.
    const small = op === "thumb" && request.query?.n !== undefined ? Number(request.query.n) : null;
    if (row && small !== null) {
      const versions = Number.isSafeInteger(small) && small >= 1 ? await versionsOf(id, row) : [];
      const one = versions.find((version) => version.n === small);
      const newest = versions[0]?.n;
      const kept = one && (one.n === newest ? row.has_thumb : one.has_thumb);
      has = Boolean(one && (kept || one.has_image));
      if (one) name = versionFile(id, one.n, newest, kept ? "webp" : "png");
      if (one && !kept) type = "image/png";
    }
    // The cut-out its page shows, where its app made one, and the picture
    // itself for a model published before there were any.
    const cut = has && op === "cutout" ? await getFile(name.replace(/[.]png$/, ".cutout.png")) : null;
    const picture = cut || (has ? await getFile(name) : null);
    if (!picture) return response.status(404).setHeader("Cache-Control", "no-store").end("");
    response.setHeader("Content-Type", type);
    // A link preview on any site may show it.
    response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
    // Kept as briefly as the pages (SHARED_CACHE). The small picture's
    // address says which version it is (?v=), so a browser keeps it a few
    // minutes too; a republish is a new address.
    // A version's, at an address that says when it was published (?at=), is
    // that version's for good: kept long, so the Log costs storage little.
    response.setHeader("Cache-Control", small !== null && request.query?.at ? "public, max-age=86400, s-maxage=2592000, immutable"
      : op === "thumb" && request.query?.v ? "public, max-age=300, s-maxage=600" : SHARED_CACHE);
    return response.status(200).end(picture);
  }

  if (op !== "") return response.status(400).json({ error: `unknown op ${op}` });

  // The viewer's one request: what the model is, and the model.
  response.setHeader("Cache-Control", "no-store");
  if (!row) {
    const gone = await missing(id);
    return response.status(gone.status).json({ error: gone.error, unpublished: gone.unpublished });
  }
  // What it was remixed from, while that is listed: read as a visitor
  // reads it, so a link taken down, or only ever sent to some people, is
  // not named.
  const parent = row.remixed_from ? await orUnknown("share", publishedRow(row.remixed_from)) : null;
  const from = parent && parent.listed ? parent : null;
  // Which version: the newest unless one is asked for, and each version's
  // first changed step, for a builder's place (BuildSteps.changed_since).
  const versions = await versionsOf(id, row);
  const newest = versions[0].n;
  const shown = asked === null ? versions[0] : versions.find((one) => one.n === asked);
  if (!shown) {
    return response.status(404).json({ error: `There is no version ${asked} of this model: `
      + `it has ${count(newest, "version")}.`, unpublished: false, newest });
  }
  const model = await getFile(versionFile(id, shown.n, newest, "mpd"));
  if (!model) return response.status(410).json({ error: "This model is no longer shared.", unpublished: true });
  // The mark this version passed, for the viewer's bar; a failure is its
  // owner's alone (?op=tested), so here it is no mark at all. Each of these
  // is beside the model: one not read is null, unknown (orUnknown), and the
  // model still goes out.
  const [mark, builds, by, based] = await Promise.all([orUnknown("share", markOf(db, id, shown.n)),
    orUnknown("share", buildsOf(id)), orUnknown("share", profileOf(id, row.author)), orUnknown("share", basesOf(id))]);
  const tested = publicMark(mark);
  return response.status(200).json({
    tested,
    // How many have built it to the last step (supabase/builds.sql); null
    // when that could not be read.
    builds,
    id,
    name: row.name,
    // Whom it credits, as its page says it: the viewer's "by".
    author: creditName({ ...row, by }),
    // Who modelled it, when its sharer did not: the Library's model it is.
    modelled_by: modelledByOf(row.modelled_by),
    parts: shown.n === newest ? row.parts : shown.parts,
    updated_at: row.updated_at,
    version: shown.n,
    newest,
    versions: versions.map((one) => versionSaid(origin, id, one, newest)),
    listed: row.listed === true,
    licence: row.licence ?? null,
    // What its owner said about it, for a session reading it as a
    // reference (src/net/gallery_tool.gd) as for its page.
    description: row.description ?? null,
    // As its page says them: the two that say how it was made only where
    // its owner chose to (web/card.js madePublic).
    tags: madePublic(row).tags || [],
    kind: row.kind ?? null,
    remixed_from: from ? { id: from.id, name: from.name, url: `${origin}/m/${from.id}`,
      version: remixVersion(versions) } : null,
    // What else it credits (api/_bases.js): a set built from or changed, a
    // work elsewhere; a set's href its page here. null when that could not
    // be read, or before model_bases.sql: unknown, not "nothing".
    based_on: based && based.map((one) => ({ ...one, href: one.set ? `${origin}${one.href}` : one.href })),
    ...links(origin, id),
    model: model.toString("utf8"),
  });
}

// ---------------------------------------------------------------------------
// The LDraw library (library333): /library's sets a page at a time, and each
// set's page, cover, file and parts, from the app's own index and files in
// the parts store (api/_library.js). Nothing here reads the database but a
// list asked with tests, for the OMR's arrivals staged (gallery362).

/// The library's sets as a list asked with [tests] shows them: the store's
/// index, which an arrival joins when the lead lets it out
/// (tools/library_import.py publish), and for tests the OMR's arrivals
/// staged too. Only a list asked with tests reads the database; before
/// supabase/gallery_crons.sql is applied, it gets the index alone.
const libraryOf = (tests = false) => (tests ? { arrivals: () => db("rpc/library_arrival_entries", {
  method: "POST", body: { tests: true } }).catch(() => []) } : {});

/// What the CDN keeps of the shelf and a set's page: the store's index
/// changes a few times a year, so an hour, given while it asks again for a
/// day. A cover a week: it is drawn again only when the index is built again.
const SET_CACHE = "public, max-age=300, s-maxage=3600, stale-while-revalidate=86400";
/// A set's page, its parts and its 3D scene: each is made from the set's
/// whole file (up to 36 MB) read from Supabase Storage, every read paid as
/// egress, so the CDN keeps them a week and serves the old one a month while
/// it asks again. Kept an hour, crawlers walking every set in every language
/// read 10-25 GB a day and ran the organization past its quota (2026-11-12).
const SET_PAGE_CACHE = "public, max-age=300, s-maxage=604800, stale-while-revalidate=2592000";
const COVER_CACHE = "public, max-age=86400, s-maxage=604800, stale-while-revalidate=604800";

/// /library's sets (web/library.js), as askOf reads the query: {models (the
/// cards, web/card.js), total, page, pages, per_page, of (every set), asked,
/// themes [{name, n}], decades, sizes, sorts}.
async function library(request, response) {
  const tests = testsAsked(request.query || {});
  const every = await librarySets(libraryOf(tests));
  const catalogue = setCatalog();
  if (catalogue) return catalogList(request, response, catalogue, every, tests);
  if (!every.length) {
    return response.status(503).setHeader("Cache-Control", "no-store")
      .json({ error: "The LDraw library cannot be read just now. Try again in a minute." });
  }
  const asked = askOf(request.query || {});
  const found = searchSets(every, asked);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : SET_CACHE);
  return response.status(200).json({ ...found, models: found.models.map(setCard), per_page: SET_PER_PAGE,
    of: every.length, asked, themes: themes(every), decades: decades(every),
    sizes: Object.fromEntries(Object.entries(SIZES).map(([key, size]) => [key, size.label])), sorts: SET_SORTS });
}

/// The sets a set's page ends with: its theme's, the nearest in years
/// first, at most NEXT_MOST, and none fewer than NEXT_LEAST.
function setsBeside(every, entry) {
  const theme = themeOf(entry);
  const kin = theme ? every.filter((one) => one.id !== entry.id && themeOf(one) === theme)
    .sort((a, b) => Math.abs(a.year - entry.year) - Math.abs(b.year - entry.year)
      || a.name.localeCompare(b.name, "en", { numeric: true })).slice(0, NEXT_MOST) : [];
  return kin.length >= NEXT_LEAST ? kin.map(setCard) : [];
}

/// /library/X: a set's page, made as a model's is (sharePage), its parts and
/// steps and every modeller read from its own file; in German, French or
/// Spanish at /de/library/X (and /fr, /es), as a model's page is.
async function setPage(response, origin, id, tests = false, lang = "en") {
  const words = lang === "en" ? null : siteWords(lang);
  if (lang !== "en" && !words) return html(response, 404, gonePage(origin, id, false));
  const speak = (draw) => inLanguage(lang, words, draw);
  const entry = await librarySet(id, libraryOf(tests));
  if (!entry) return html(response, 404, speak(() => gonePage(origin, id, false, lang)));
  const text = await storeFile(entry).catch(() => null);
  const parts = text ? partsOf(entry.file, Buffer.from(text)) : null;
  const next = { by: [], like: setsBeside(await librarySets(libraryOf(tests)), entry), gallery: [] };
  return html(response, 200, speak(() => sharePage(origin, id, setModel(entry, { authors: authorsIn(text), steps: fileSteps(text) }),
    [], null, null, [], next, null, undefined, parts, lang, words)), { cache: tests ? TESTS_CACHE : SET_PAGE_CACHE });
}

/// A set's pictures, each drawn by the app's own renderer
/// (src/dev/library_covers.gd), from this site's origin, which is where the
/// pages take pictures from: /library/X.webp its card's, and
/// /library/X.cutout.webp its page's, each with nothing behind the model
/// (tools/library_build.py pictures), as a shared model's are; and
/// /library/X.cover.webp the cover the app's Library shows, on its own
/// ground, for a link's preview elsewhere. A set whose clear pictures are
/// not drawn yet has its cover in their place, kept briefly, so the new
/// picture shows within the hour once it is up.
const SET_PICTURES = { card: "cards", cutout: "pages", cover: "" };

async function setCover(response, id, as = "card", tests = false) {
  const entry = await librarySet(id, libraryOf(tests));
  const root = storeRoot();
  const read = async (path) => {
    const bytes = await storeBytes(path);
    return bytes && bytes.subarray(0, 4).equals(RIFF) && bytes.subarray(8, 12).equals(WEBP) ? bytes : null;
  };
  const folder = SET_PICTURES[as];
  const drawn = entry && root && folder ? await read(`library/${folder}/${entry.id}.webp`) : null;
  const bytes = drawn || (entry && root && folder !== undefined ? await read(entry.cover) : null);
  if (!bytes) return response.status(404).setHeader("Cache-Control", "no-store").end("");
  response.setHeader("Content-Type", "image/webp");
  response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  response.setHeader("Cache-Control", drawn || !folder ? COVER_CACHE : SET_CACHE);
  return response.status(200).end(bytes);
}

/// /library/X.mpd: its file, as LDraw has it, from the store itself: the
/// largest is 36 MB, past what a function may answer with.
async function setFile(response, id, tests = false) {
  const entry = await librarySet(id, libraryOf(tests));
  const root = storeRoot();
  if (!entry || !root) {
    return response.status(404).setHeader("Cache-Control", "no-store").json({ error: "The LDraw library has no such set." });
  }
  response.setHeader("Cache-Control", SET_CACHE);
  response.setHeader("Location", `${root}${entry.file}`);
  return response.status(302).end("");
}

/// /library/X/parts.json, .xml and .csv: its parts, as a model's are.
async function setParts(response, id, as, tests = false, lang = "en") {
  const entry = await librarySet(id, libraryOf(tests));
  if (!entry) {
    return response.status(404).setHeader("Cache-Control", "no-store").json({ error: "The LDraw library has no such set." });
  }
  const text = await storeFile(entry).catch(() => null);
  response.setHeader("Cache-Control", SET_PAGE_CACHE);
  response.setHeader("X-Content-Type-Options", "nosniff");
  return partsAnswer(response, text ? partsOf(entry.file, Buffer.from(text)) : null,
    fileName(setTitle(entry), entry.id), as, { id, version: 1, newest: 1 }, lang);
}

/// /library/X/scene.json: its model packed for its page's 3D view, as a
/// model's is (sceneAnswer); as [kind] "room", /library/X/room.json.
async function setScene(response, id, tests = false, kind = "scene") {
  const entry = await librarySet(id, libraryOf(tests));
  if (!entry) {
    return response.status(404).setHeader("Cache-Control", "no-store").json({ error: "The LDraw library has no such set." });
  }
  const text = await storeFile(entry).catch(() => null);
  if (!text) return response.status(503).setHeader("Cache-Control", "no-store").json({ error: "Its file could not be read just now." });
  response.setHeader("Cache-Control", SET_PAGE_CACHE);
  response.setHeader("X-Content-Type-Options", "nosniff");
  return sceneAnswer(response, entry.file, Buffer.from(text), `library:${entry.id}`, kind);
}

// ---------------------------------------------------------------------------
// Every set in the catalogue (sets364): /library's list, and each set's page
// at /library/set/N, its parts, its picture and what of it a person owns
// (api/_sets.js). The catalogue is beside this function and its parts lists
// are the deployment's /sets/ shards: nothing here asks Rebrickable.

/// What the CDN keeps of a set's page and parts: a day, given while it asks
/// again for a week; the catalogue changes when a deploy brings a newer
/// copy. Its picture a year: what it is drawn from changes only with that.
const CATALOG_CACHE = "public, max-age=3600, s-maxage=86400, stale-while-revalidate=604800";
const PICTURE_CACHE = "public, max-age=604800, s-maxage=31536000, stale-while-revalidate=31536000";

/// /library's sets from the catalogue, LDraw's models of them marked:
/// {models (the cards, web/card.js), total, page, pages, per_page, of,
/// asked, themes [{name, n, sub}], decades, years, sizes, sorts}.
function catalogList(request, response, catalogue, models, tests) {
  const asked = askSets(request.query || {});
  const by = modelsBySet(models);
  const found = searchCatalog(catalogue.sets, asked, by);
  const { decades: decadesThere, years } = yearsOf(catalogue.sets);
  response.setHeader("Cache-Control", tests ? TESTS_CACHE : SET_CACHE);
  return response.status(200).json({
    models: found.sets.map((entry) => catalogCard(entry, by)), total: found.total, page: found.page, pages: found.pages,
    near: found.near, meant: found.meant,
    per_page: CATALOG_PER_PAGE, of: catalogue.sets.length, with_3d: [...by.values()].filter((one) => one.main).length,
    asked, themes: themeTree(catalogue.sets), decades: decadesThere, years,
    sizes: Object.fromEntries(Object.entries(SIZES).map(([key, size]) => [key, size.label])), sorts: SETS_SORTS,
    credit: SETS_CREDIT,
  });
}

/// A set's inventory from its shard: [[part, colour, qty]], or null when
/// the shard cannot be read.
async function catalogRows(entry, origin) {
  const shard = await readShard(shardOf(entry.set), origin).catch(() => null);
  if (!shard) return null;
  return shard.sets?.[entry.set.toLowerCase()]?.p || [];
}

/// Its parts list in the lots a model's list has (api/_parts.js).
function catalogLots(rows) {
  const table = partsTable();
  return table && rows ? inventoryOfLots(rows, table) : null;
}

/// /library/set/N: the set's page.
async function catalogSetPage(response, origin, number, lang = "en") {
  const entry = catalogSet(number);
  // A language the site has no words in is not a page.
  const words = lang === "en" ? null : siteWords(lang);
  if (!entry || (lang !== "en" && !words)) return html(response, 404, gonePage(origin, number.slice(0, 40), false));
  const catalogue = setCatalog();
  // LDraw's shelf and the set's shard, each a fetch, asked at once.
  const [models, rows] = await Promise.all([librarySets().catch(() => []), entry.lots ? catalogRows(entry, origin) : null]);
  const by = modelsBySet(models);
  const lots = entry.lots ? catalogLots(rows) : null;
  const inside = entry.inside.map(([one, n]) => [catalogSet(one), n]).filter(([one]) => one);
  const next = catalogBeside(catalogue.sets, entry).map((one) => catalogCard(one, by));
  return html(response, 200, inLanguage(lang, words, () => catalogPage({ origin, entry, chrome: siteChrome(lang),
    held: by.get(entry.set.toLowerCase()) || null, inside, next, lots: lots ? lots.lots : [], cardHtml, lang, words })),
  { cache: CATALOG_CACHE });
}

/// /library/set/N/parts.json, .xml and .csv: its parts, as a model's are.
async function catalogParts(response, origin, number, as, lang = "en") {
  const entry = catalogSet(number);
  if (!entry) {
    return response.status(404).setHeader("Cache-Control", "no-store").json({ error: "There is no such set in the catalogue." });
  }
  const rows = await catalogRows(entry, origin);
  response.setHeader("Cache-Control", rows ? CATALOG_CACHE : "no-store");
  response.setHeader("X-Content-Type-Options", "nosniff");
  return partsAnswer(response, catalogLots(rows), fileName(titleOf(entry), entry.set), as,
    { set: entry.set, name: entry.name, credit: SETS_CREDIT }, lang);
}

/// /library/set/N.webp and N.page.webp: the set's own picture, Rebrickable's,
/// as tools/set_pictures.py fetched it once and put it in the parts bucket
/// (sets/card/, sets/page/), so a visitor's browser never asks them; kept
/// by the CDN a year, as the picture of its parts is. 404 for a set the
/// store has no picture of: its pages name this only for those it has
/// (api/_sets.js pictureOf).
const SET_PHOTOS = { card: "card", page: "page" };

async function catalogPhoto(response, number, as) {
  const entry = catalogSet(number);
  const root = storeRoot();
  const folder = SET_PHOTOS[as];
  const none = () => response.status(404).setHeader("Cache-Control", "no-store").end("");
  if (!entry || !root || !folder) return none();
  const bytes = await storeBytes(`sets/${folder}/${encodeURIComponent(entry.set)}.webp`);
  if (!bytes || !bytes.subarray(0, 4).equals(RIFF) || !bytes.subarray(8, 12).equals(WEBP)) return none();
  response.setHeader("Content-Type", "image/webp");
  response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  response.setHeader("Cache-Control", PICTURE_CACHE);
  return response.status(200).end(bytes);
}

/// /library/set/N.jpg: its most distinctive parts laid out and drawn from
/// their own geometry (api/_flatlay.js), for a set with no picture of its
/// own. 404 for a set with none to draw, or a store that will not give
/// their geometry.
async function catalogPicture(response, origin, number) {
  const entry = catalogSet(number);
  const table = partsTable();
  const root = storeRoot();
  const none = () => response.status(404).setHeader("Cache-Control", "no-store").end("");
  if (!entry || !entry.picks.length || !table || !root) return none();
  const parts = (await Promise.all(entry.picks.map(async (pick) => {
    const [part, colour] = pick.split("/");
    const mesh = table.parts[part]?.[6];
    if (!mesh || !/^[0-9a-f]{8,64}$/.test(mesh)) return null;
    const bytes = await storeBytes(`${mesh}.lbm`);
    if (!bytes) return null;
    return { mesh: bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length), hex: table.colours[colour]?.[1] || "a0a5a9" };
  }))).filter(Boolean);
  if (!parts.length) return none();
  response.setHeader("Content-Type", "image/jpeg");
  response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  response.setHeader("Cache-Control", parts.length === entry.picks.length ? PICTURE_CACHE : SET_CACHE);
  return response.status(200).end(flatLayJpeg(parts, paletteOf(table)));
}

/// How much of set N the person signed in owns, as the app's collection
/// counts it: {set, pieces, have, missing (lots), unknown (their sets no
/// inventory has), wanted: {bricklink, rebrickable, pickabrick: [file]}
/// (what they are missing, as each shop's list), left_out}. No collection
/// is {pieces, have: 0, collection: false}. Never kept by anything between.
async function catalogOwned(request, response, origin, number) {
  response.setHeader("Cache-Control", "no-store");
  const entry = catalogSet(number);
  if (!entry) return response.status(404).json({ error: "There is no such set in the catalogue." });
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    return response.status(trouble?.status || 401).json({ error: trouble?.message || "Sign in to see what you own." });
  }
  const rows = await catalogRows(entry, origin);
  if (!rows) return response.status(503).json({ error: "This set's parts cannot be read just now." });
  const found = await db(`collections?owner=eq.${claims.sub}&select=sets,parts`).catch(() => null);
  const collection = found && found[0];
  const one = (lot) => keyed([lot])[0] || null;
  if (!collection || (!(collection.sets || []).length && !(collection.parts || []).length)) {
    const { pieces } = ownedOf(rows, [], one);
    return response.status(200).json({ set: entry.set, pieces, have: 0, collection: false });
  }
  const pool = await poolOf(collection, (n) => readShard(n, origin));
  const owned = ownedOf(rows, pool.lots, one);
  const short = catalogLots(owned.missing) || { pieces: 0, lots: [] };
  const bricklink = wantedList(short);
  const rebrickable = rebrickableCsv(short);
  // And as LEGO® Pick a Brick's upload takes them (ownedparts), a file of
  // PICK_A_BRICK_LINES elements each.
  const pab = pickABrick(short);
  return response.status(200).json({ set: entry.set, pieces: owned.pieces, have: owned.have, collection: true,
    missing: short.lots.length, unknown: pool.unknown.length,
    wanted: { bricklink: bricklink.text, rebrickable: rebrickable.text, pickabrick: pab.files },
    left_out: { bricklink: bricklink.left_out, rebrickable: rebrickable.left_out, pickabrick: pab.missing.length } });
}

/// What the person signed in is missing of a model's parts list
/// (ownedparts): its Parts tab's What you're missing, the list
/// /m/X/parts.json answers less what their collection holds, counted as the
/// gallery counts their share of it (api/_owned.js heldOf, missingOf), and
/// the shops' lists of only those lots, in the formats the tab downloads for
/// the whole model, named for it (name, as its downloads are): {id,
/// version, newest, name, collection, pieces, have, lots, whole,
/// missing: [lots as parts.json's, count the number short, need, have],
/// left: {lots, pieces} nobody owns on their own, unknown (their sets no
/// inventory has), files: {bricklink, rebrickable, pickabrick: [file]},
/// left_out, stand_ins, pickabrick}. No collection is {collection: false}
/// with the list's size. The version as /m/X/parts.json reads it (v=N, the
/// newest unless one is), and what a visitor may read of it. Never kept by
/// anything between.
async function partsMissing(request, response, origin, id) {
  response.setHeader("Cache-Control", "no-store");
  const fail = (status, error) => response.status(status).json({ error });
  if (!ID.test(id)) return fail(400, "id is a model's link, ten letters and digits");
  const asked = askedVersion(request);
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    return fail(trouble?.status || 401, trouble?.message || "Sign in to see what you are missing.");
  }
  const row = await publishedRow(id);
  if (!row) {
    const gone = await missing(id);
    return fail(gone.status, gone.error);
  }
  const versions = await versionsOf(id, row);
  const newest = versions[0].n;
  const shown = asked === null ? versions[0] : versions.find((one) => one.n === asked);
  if (!shown) return fail(404, `There is no version ${asked} of this model: it has ${count(newest, "version")}.`);
  const parts = await versionParts(id, shown.n, newest);
  if (parts === undefined) return fail(410, "This model is no longer shared.");
  if (!parts) return fail(503, "This site cannot list a model's parts just now.");
  const keys = parts.lots.map((lot) => ownedKey(lot.part, lot.colour));
  const held = await heldOf(claims.sub, origin, keys.filter(Boolean).map((key) => key.slice(0, key.lastIndexOf("/"))));
  const said = { id, version: shown.n, newest, name: `${fileName(row.name, id)}${shown.n === newest ? "" : `-v${shown.n}`}` };
  if (!held) {
    const none = missingOf(parts, new Map());
    return response.status(200).json({ ...said, collection: false, pieces: none.pieces, have: 0, lots: none.lots });
  }
  return response.status(200).json(missingAnswer(parts, held, said, String(request.query?.lang || "en")));
}

/// op=parts_missing's answer when they have a collection: model [parts]
/// (partsOf) less what [held] holds ({held, unknown}: heldOf), [said] its
/// id, versions and name first; in [lang] as /m/X/parts.json is. Its own
/// so the documentation's pictures show the very answer
/// (tools/web/docs_world.mjs).
export function missingAnswer(parts, held, said, lang = "en") {
  const short = missingOf(parts, held.held);
  const lots = { pieces: short.missing.reduce((n, lot) => n + lot.count, 0), lots: short.missing };
  const bricklink = wantedList(lots);
  const rebrickable = rebrickableCsv(lots);
  const pab = pickABrick(lots);
  const words = SITE_LANGS.includes(lang) ? partNames(lang) : null;
  const root = storeRoot();
  return {
    ...said, ...(words ? { lang } : {}), collection: true, pieces: short.pieces, have: short.have, lots: short.lots,
    whole: short.whole, left: short.left, unknown: held.unknown,
    missing: short.missing.map((lot) => ({ part: lot.part, name: lot.name, category: lot.category, colour: lot.colour,
      colour_name: lot.colour_name, hex: lot.hex, count: lot.count, need: lot.need, have: lot.have,
      element: lot.element || null, custom: lot.custom, mesh: (root && lot.mesh) || null, ...namesOf(lot, words) })),
    files: { bricklink: bricklink.text, rebrickable: rebrickable.text, pickabrick: pab.files },
    left_out: { bricklink: bricklink.left_out, rebrickable: rebrickable.left_out, pickabrick: pab.missing.length },
    stand_ins: bricklink.stand_ins,
    pickabrick: { files: pab.files.length, lines: pab.lines, pieces: pab.pieces,
      left_out_pieces: pab.missing.reduce((n, lot) => n + lot.count, 0), over: pab.over },
  };
}

/// Version [n] of model [id]'s parts list (partsOf), the newest being
/// [newest]: kept here by version, which is never written again once made
/// (a new one is a new number), so a person's What you're missing reads the
/// model's file from storage once an instance, not once an ask (Supabase's
/// egress cap was reached on 2026-11-12). Undefined when the file is
/// gone, null when this deployment cannot list it.
async function versionParts(id, n, newest) {
  const key = `${id}/${n}`;
  if (versionsKept.has(key)) return versionsKept.get(key);
  const stored = versionFile(id, n, newest, "mpd");
  const file = await getFile(stored);
  if (!file) return undefined;
  const parts = partsOf(stored, file);
  versionsKept.set(key, parts);
  if (versionsKept.size > PARTS_KEPT) versionsKept.delete(versionsKept.keys().next().value);
  return parts;
}
const versionsKept = new Map();

/// /sitemaps/index.xml: the sitemaps there are, the site's own
/// (/sitemap.xml), the sets' pages', a few thousand to a file, and the
/// models' copies in each language.
function sitemapIndex(response, origin) {
  const catalogue = setCatalog();
  const files = catalogue ? sitemapSets(catalogue.sets, origin).length : 0;
  // The sets' pages in English, then in each language the site has
  // (/sitemaps/sets-de-1.xml...).
  const named = ["", ...SITE_LANGS.map((code) => `${code}-`)]
    .flatMap((lang) => Array.from({ length: files }, (_, k) => `${origin}/sitemaps/sets-${lang}${k + 1}.xml`));
  const models = SITE_LANGS.map((code) => `${origin}/sitemaps/models-${code}.xml`);
  const rows = [`${origin}/sitemap.xml`, ...named, ...models].map((loc) => `  <sitemap><loc>${escapeHtml(loc)}</loc></sitemap>`);
  response.setHeader("Content-Type", "application/xml; charset=utf-8");
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=86400, stale-while-revalidate=3600");
  return response.status(200).end(`<?xml version="1.0" encoding="UTF-8"?>
<sitemapindex xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${rows.join("\n")}
</sitemapindex>
`);
}

/// /sitemaps/sets-K.xml: the K-th file of the sets' pages; with [lang]
/// (/sitemaps/sets-de-K.xml), of their copies in it.
function sitemapOfSets(response, origin, n, lang = "en") {
  if (lang !== "en" && !SITE_LANGS.includes(lang)) return response.status(404).setHeader("Cache-Control", "no-store").end("");
  const catalogue = setCatalog();
  const files = catalogue ? sitemapSets(catalogue.sets, origin, lang) : [];
  const k = /^[1-9][0-9]{0,2}$/.test(n) ? Number(n) : 0;
  if (!k || k > files.length) return response.status(404).setHeader("Cache-Control", "no-store").end("");
  response.setHeader("Content-Type", "application/xml; charset=utf-8");
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=86400, stale-while-revalidate=3600");
  return response.status(200).end(`<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${files[k - 1].map((loc) => `  <url><loc>${escapeHtml(loc)}</loc><changefreq>monthly</changefreq><priority>0.3</priority></url>`).join("\n")}
</urlset>
`);
}

/// /gallery's models, a page at a time: the listed ones a query asks for
/// (api/_directory.js listQuery), through gallery_models, which says for
/// itself what a visitor may see. With the kinds, sizes, sorts, Top's
/// windows and how a model was made, so a client can ask in its words;
/// signed in, whether they like each, and Following.
///
/// Until supabase/gallery_tabs.sql is applied there is no gallery_models:
/// the list is asked of directory_models, as before, and says nothing of
/// windows, Made or Following, so the page offers none of them; a question
/// that asks one is refused in words (400), never a 500.
async function gallery(request, response, origin) {
  const mine = await whoseOwn(request, origin);
  let asked;
  let said;
  try {
    // The catalogue's words make the search forgiving, as the library's is.
    const catalogue = request.query?.q ? setCatalog() : null;
    ({ asked, said } = listQuery(request.query || {}, PER_PAGE, MOST_PAGES, { mine: Boolean(mine?.pool),
      signedIn: Boolean(mine), vocabulary: catalogue ? searchIndex(catalogue.sets) : null }));
  } catch (trouble) {
    // Signed in, with nothing in their collection to sort or filter by.
    if (mine && trouble instanceof Unacceptable && trouble.status === 401) {
      throw new Unacceptable("There is nothing in your collection yet: add what you own in the app "
        + "(Build › My collection…) and the gallery can say what you can build.", 422);
    }
    throw trouble;
  }
  // Their shares only once there is something to share of.
  if (mine?.pool) asked.pool = mine.account;
  if (asked.following) asked.following = mine.account;
  // Built from a set (altbuilds): a gallery_models older than
  // supabase/alt_builds.sql would pass over both and list everything.
  if ((asked.alt || asked.one_set) && (await altRowsOf(["-"]).catch(() => null)) === null) {
    throw new Unacceptable("Models built from a set are not counted here yet.", 503);
  }
  let rows;
  let tabs = true;
  try {
    rows = await db("rpc/gallery_models", { method: "POST", body: { query: asked } });
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) throw trouble;
    if (asked.following || asked.days || asked.made) {
      throw new Unacceptable("Following, Made and Top's time windows are not here yet: they come with "
        + "the gallery's next update.");
    }
    tabs = false;
    rows = await db("rpc/directory_models", { method: "POST", body: { query: asked } });
  }
  // With the assistant: only a model its owner chose to say so of, which
  // gallery_models asks itself once supabase/made_with_shown.sql is
  // applied. Before, its rows say nothing shown, and none is listed.
  if (asked.made === "assistant") rows = rows.filter((row) => row.made_with_shown === true);
  // Signed in: nothing of anybody they blocked (supabase/block.sql). A
  // page may then hold fewer; the next is where it was.
  const models = await withoutTheirBlocked(mine,
    await withWins(rows.slice(0, PER_PAGE).map((row) => ownedCard(origin, row)), Boolean(said.tests)));
  if (mine) await withLiked(models, mine.account);
  await withFaces(models);
  // Kept briefly by the CDN, like the pages: the same question asked by
  // a hundred phones is one call to the database. Never with test models,
  // nor anybody's own shares.
  response.setHeader("Cache-Control", said.tests || mine ? TESTS_CACHE : SHARED_CACHE);
  return response.status(200).json({
    ...said,
    per_page: PER_PAGE,
    more: rows.length > PER_PAGE,
    // What each won in the monthly challenges (supabase/challenges.sql).
    models,
    kinds: KINDS,
    sizes: Object.entries(SIZES).map(([id, size]) => ({ id, label: size.label })),
    sorts: Object.entries({ ...SORTS, ...(mine?.pool ? MINE_SORTS : {}) }).map(([id, label]) => ({ id, label })),
    ...(tabs ? {
      windows: Object.entries(WINDOWS).map(([id, one]) => ({ id, label: one.label })),
      mades: Object.entries(MADES).map(([id, label]) => ({ id, label })),
      following: Boolean(mine),
    } : {}),
    score: SCORE,
    ...(mine ? { mine: mine.pool } : {}),
  });
}

/// [cards] without the models of anybody [mine] (the person asking, signed
/// in) blocked, nor any credited to one: the same cards for nobody signed
/// in, or before supabase/block.sql. Asked of the models only once somebody
/// is blocked: a block needs a profile, so nobody blocked is no handle.
async function withoutTheirBlocked(mine, cards) {
  if (!mine?.account || !cards.length) return cards;
  const handles = await blockedHandles(mine.account);
  if (!handles.size) return cards;
  return withoutBlocked(cards, await blockedModels(mine.account, cards.map((one) => one.id)), handles);
}

/// Which of [cards] [account] likes, said on each (liked), for the hearts
/// on the cards: their own, so only in an answer never kept by the CDN.
/// Left unsaid when it cannot be read.
async function withLiked(cards, account) {
  const ids = cards.map((one) => String(one.id)).filter((id) => ID.test(id));
  if (!ids.length) return cards;
  try {
    const liked = new Set((await db(`model_likes?account=eq.${account}&model=in.(${[...new Set(ids)].join(",")})&select=model`))
      .map((row) => row.model));
    for (const one of cards) one.liked = liked.has(one.id);
  } catch {
    // Unsaid: the hearts are drawn as not pressed.
  }
  return cards;
}

/// The person asking with &mine=1, and what their collection holds as the
/// gallery counts it (api/_owned.js freshPool: lots, pieces, how many of
/// their sets no inventory has), or null for a list asked without it.
/// Asked with it and not signed in is refused (401): their own shares are
/// only ever theirs.
async function whoseOwn(request, origin) {
  const value = String(request.query?.mine ?? "").toLowerCase();
  if (!value || value === "0" || value === "false") return null;
  if (!["1", "true", "yes", "on"].includes(value)) throw new Unacceptable("mine is 1 or left out");
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    throw new Unacceptable(trouble?.message || "sign in to see what you own", trouble?.status || 401);
  }
  const pool = await freshPool(claims.sub, origin);
  return { account: claims.sub, pool: pool && typeof pool === "object"
    ? { lots: Number(pool.lots) || 0, pieces: Number(pool.pieces) || 0,
      unknown: Array.isArray(pool.unknown) ? pool.unknown.length : 0 } : null };
}

/// A card, and the asker's share of its parts when it was asked for theirs:
/// {pieces, have, share}, pieces null for a model not counted yet.
function ownedCard(origin, row) {
  const card = cardOf(origin, row);
  if (row.owned && typeof row.owned === "object") {
    const pieces = row.owned.pieces === null || row.owned.pieces === undefined ? null : Number(row.owned.pieces);
    const have = pieces === null ? null : Math.min(Number(row.owned.have) || 0, pieces);
    card.owned = { pieces, have, share: pieces ? have / pieces : null };
  }
  return card;
}

/// What a model needs kept (supabase/discovery.sql owned_keep_needs), in
/// the one spelling a collection is compared by. Never throws.
/// What moves in the model, as its app found from the model's joints
/// (src/assembly/playable.gd): each of MOVES at most once, in its order.
/// Undefined when not said (an app from before), which leaves what a model
/// had as it was.
export function checkMoves(given) {
  if (given === undefined || given === null) return undefined;
  if (!Array.isArray(given) || given.length > MOVES.length) {
    throw new Refusal(`moves is a list of what moves: ${MOVES.join(", ")}`);
  }
  for (const word of given) {
    if (typeof word !== "string" || !MOVES.includes(word)) {
      throw new Refusal(`moves is a list of what moves: ${MOVES.join(", ")}`);
    }
  }
  return MOVES.filter((word) => given.includes(word));
}

/// What moves, kept with the model's row: the app's words (supabase/play.sql)
/// and its motions' names, read from the text published (supabase/motions.sql).
/// {moves, motions}, each as kept or null. Never stops the publish: before
/// motions.sql there is nowhere to keep the names, and the words are kept
/// alone; before play.sql, neither.
async function keepMoves(id, owner, moves, motions) {
  const row = `shared_models?id=eq.${id}&owner=eq.${owner}`;
  try {
    await db(row, { method: "PATCH", body: moves === undefined ? { motions } : { moves, motions } });
    return { moves: moves ?? null, motions };
  } catch {
    if (moves === undefined) return { moves: null, motions: null };
  }
  try {
    await db(row, { method: "PATCH", body: { moves } });
    return { moves, motions: null };
  } catch {
    return { moves: null, motions: null };
  }
}

/// Who laid its parts, as its app said, kept with its row: the card's
/// Hand-built or With the assistant mark, and the gallery's filter, read it
/// before the tags (supabase/made_with.sql). Not said, it stays as it was.
/// What was kept, or null for nothing. Never stops the publish: before
/// made_with.sql there is nowhere to keep it, and the card goes on reading
/// the tags.
async function keepMadeWith(id, owner, madeWith) {
  if (madeWith === undefined) return null;
  try {
    await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: { made_with: madeWith } });
    return madeWith;
  } catch {
    return null;
  }
}

/// Whether its owner shows how it was made, kept with its row: its page's
/// fact, its two tags and the gallery's With the assistant read it
/// (supabase/made_with_shown.sql). Not said, it stays as it was. What was
/// kept, or null for nothing: never stops the publish, and before that
/// file there is nowhere to keep it, and nothing is shown.
async function keepMadeShown(id, owner, shown) {
  if (shown === undefined) return null;
  try {
    await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: { made_with_shown: shown } });
    return shown;
  } catch {
    return null;
  }
}

/// ?op=made: the owner's own say in whether its page tells how it was made
/// (supabase/made_with_shown.sql). GET {made_with, made_with_shown, ready}:
/// who laid its parts, as its app said, and whether that is shown; ready
/// false before that file is applied, when it cannot be kept. POST {shown}
/// keeps it, and answers the same. Nobody else is answered anything of it.
async function madeShown(request, response) {
  const owner = await signedIn(request);
  const id = String(request.query?.id || request.body?.id || "");
  if (!ID.test(id)) throw new Refusal("there is no shared model at that link", 404);
  const row = await ownRow(id);
  if (!row || !row.published) throw new Refusal("there is no shared model at that link", 404);
  if (row.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  response.setHeader("Cache-Control", "no-store");
  if (request.method === "POST") {
    const shown = checkMadeShown(request.body?.shown);
    if (shown === undefined) throw new Refusal("shown is true or false");
    try {
      await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: { made_with_shown: shown } });
    } catch {
      throw new Refusal("Brickworks cannot keep that yet: try again after its next update", 503);
    }
  }
  const at = (select) => db(`shared_models?id=eq.${id}&owner=eq.${owner}&select=${select}`);
  const kept = await at("made_with,tags,made_with_shown").then((rows) => ({ ...rows[0], ready: true }))
    .catch(async () => ({ ...(await at("made_with,tags"))[0], made_with_shown: false, ready: false }));
  const made = madeOf(kept);
  return response.status(200).json({ id, made_with: MADE_WITH.includes(kept.made_with) ? kept.made_with : null,
    way: made.way, by: made.by, made_with_shown: kept.made_with_shown === true, ready: kept.ready });
}

/// Who modelled it, as the app's Library has it (api/_omr_credit.js), kept
/// with its row: its card and page say "Modelled by" them, and its licence
/// words credit them (supabase/modelled_by.sql; changed, once
/// modelled_by_changed.sql allows it). A republish that is no library
/// model puts it back to null. What was kept, or null. Never stops the
/// publish: a row that will not take it credits whoever shares it.
async function keepModelledBy(id, owner, modelledBy, republished) {
  if (!modelledBy && !republished) return null;
  try {
    await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: { modelled_by: modelledBy } });
    return modelledBy;
  } catch {
    return null;
  }
}

async function keepNeeds(id, needs) {
  try {
    await db("rpc/owned_keep_needs", { method: "POST", body: { model_id: id, needs: keyed(needs || []) } });
    return true;
  } catch {
    return false;
  }
}

/// What a featured model's choice weighed, as the page says it.
const featuredWhy = (why) => ({ likes: Number(why?.likes) || 0, builds: Number(why?.builds) || 0,
  comments: Number(why?.comments) || 0, remixes: Number(why?.remixes) || 0, tested: why?.tested === true });

/// The week's numbers of a pick, as the page says them.
const weekOf = (week) => ({ builds: Number(week?.builds) || 0, remixes: Number(week?.remixes) || 0,
  tested: week?.tested === true, score: Number(week?.score) || 0 });

/// /gallery's front: this week's pick (gallery_pick: the owner's choice
/// while it is open and in the gallery, or the best of the past seven days)
/// and the small builds' shelf (the Size filter's Small, by Top builds).
/// Before supabase/discovery.sql is applied there is no pick, and the shelf
/// is the newest small models. Kept briefly by the CDN, as the list.
/// The gallery's list asked [query] where it ranks (a shelf, More by, Like
/// this): gallery_models, which keeps work in progress out of every ranked
/// sort (supabase/wip.sql), or directory_models before gallery_tabs.sql.
async function rankedRows(query) {
  try {
    return await db("rpc/gallery_models", { method: "POST", body: { query } });
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) throw trouble;
    return db("rpc/directory_models", { method: "POST", body: { query } });
  }
}

async function shelves(request, response, origin) {
  const tests = testsAsked(request.query || {});
  const mine = await whoseOwn(request, origin);
  const notYet = (trouble) => (/: 404$/.test(String(trouble?.message || "")) ? null : Promise.reject(trouble));
  const [pick, small, ready, challenge, kept, week] = await Promise.all([
    db("rpc/gallery_pick", { method: "POST", body: { tests } }).catch(notYet),
    rankedRows({ most: SIZES.small.most, sort: "top", size: SHELF + 1, ...(tests ? { tests: true } : {}),
      ...(mine?.pool ? { pool: mine.account } : {}) }),
    // What they can build now, every piece in their collection: by Top builds.
    mine?.pool ? rankedRows({ pool: mine.account, buildable: true, sort: "top", size: SHELF + 1,
      ...(tests ? { tests: true } : {}) }) : null,
    // The monthly challenge open now, or the next (supabase/challenges.sql).
    challengeLine(tests),
    // What the cron chose (supabase/gallery_crons.sql): none before it is applied.
    db("rpc/gallery_features_now", { method: "POST", body: { tests } }).catch(notYet),
    // This week's quick build (api/_prompts.js), for the home's line under the month's.
    promptNow(origin, tests).catch(() => null),
  ]);
  const shown = (card) => Boolean(card && ID.test(String(card.id || "")));
  // The week's pick the cron kept, unless the owner chose one; a list asked
  // with tests keeps the pick worked out from its own week.
  const keptPick = !tests && pick?.chosen !== true && shown(kept?.pick?.card) ? kept.pick : null;
  const thePick = keptPick || (pick && shown(pick.card) ? pick : null);
  const featured = shown(kept?.featured?.card) && kept.featured.card.id !== thePick?.card?.id ? kept.featured : null;
  const set = kept?.library?.item ? await librarySet(kept.library.item) : null;
  const cards = {
    ready: (ready || []).slice(0, SHELF).map((row) => ownedCard(origin, row)),
    pick: thePick ? cardOf(origin, thePick.card) : null,
    featured: featured ? cardOf(origin, featured.card) : null,
    small: await withWins((small || []).slice(0, SHELF).map((row) => ownedCard(origin, row)), tests),
  };
  // Signed in: nothing of anybody they blocked, on any shelf.
  if (mine) {
    const kept = new Set((await withoutTheirBlocked(mine, [...cards.ready, ...cards.small, cards.pick, cards.featured]
      .filter(Boolean))).map((one) => one.id));
    cards.ready = cards.ready.filter((one) => kept.has(one.id));
    cards.small = cards.small.filter((one) => kept.has(one.id));
    if (cards.pick && !kept.has(cards.pick.id)) cards.pick = null;
    if (cards.featured && !kept.has(cards.featured.id)) cards.featured = null;
  }
  const lead = [cards.pick, cards.featured].filter(Boolean);
  if (mine) await withLiked([...cards.ready, ...lead, ...cards.small], mine.account);
  await withFaces(cards);
  response.setHeader("Cache-Control", tests || mine ? TESTS_CACHE : SHARED_CACHE);
  return response.status(200).json({
    ...(mine ? { mine: mine.pool, ready: { models: cards.ready, more: (ready || []).length > SHELF } } : {}),
    pick: cards.pick ? {
      chosen: thePick.chosen === true, until: thePick.chosen === true ? thePick.until ?? null : null,
      week: weekOf(thePick.week), model: cards.pick, ...(keptPick ? { kept: keptPick.day } : {}),
    } : null,
    // Today's featured model and today's set from the LDraw library, as the
    // cron kept them (api/_featured.js): what people did, and which theme.
    featured: cards.featured ? { day: featured.day, why: featuredWhy(featured.why),
      said: featuredSaid(featured.why, featured.card.listed_at, featured.day), model: cards.featured } : null,
    library: set ? { day: kept.library.day, why: { theme: themeOf(set), decade: set.year ? `${Math.floor(set.year / 10) * 10}s` : "" },
      model: setCard(set) } : null,
    small: { size: "small", label: SIZES.small.label, most: SIZES.small.most, models: cards.small,
      more: (small || []).length > SHELF },
    challenge,
    prompt_now: week,
    score: SCORE,
  });
}

/// A view of a model's page, sent by the page (web/share-page.js) once a
/// day: counted once per visitor per day, and only for what looks like a
/// person in a browser on this site. The answer says whether it was, and
/// never who.
async function seen(request, response) {
  const id = String(request.query?.id || "");
  if (!ID.test(id)) return response.status(400).json({ error: "name a link: ?id=<ten characters>" });
  if (!looksLikePerson(request)) return response.status(200).json({ counted: false });
  const counted = await db("rpc/count_view", { method: "POST",
    body: { model_id: id, visitor_key: visitorKey(request, id) } });
  return response.status(200).json({ counted: counted === true });
}

/// A build finished on some device, sent by the app once it reaches the
/// last step from the step before (src/main.gd): counted once per device,
/// and only for a person in a browser on this site or the desktop app. The
/// answer says whether it was, and how many now, and never who.
async function built(request, response) {
  const id = String(request.query?.id || "");
  const device = String(request.body?.device || "");
  const person = looksLikePerson(request) || fromTheApp(request);
  return response.status(200).json(await countBuild(id, device, person));
}

async function signedIn(request) {
  const claims = await verify(bearer(request), request);
  return claims.sub;
}

async function mine(request, response, origin) {
  response.setHeader("Cache-Control", "private, no-store");
  const owner = await signedIn(request);
  // And whether each is work in progress (supabase/wip.sql): the studio's
  // Share progress then publishes its next version, and Publish finishes it.
  const wipped = await wipReady();
  const [rows, profile] = await Promise.all([
    db(`shared_models?owner=eq.${owner}&select=${PUBLIC},barred${wipped ? ",wip_at" : ""}&order=updated_at.desc`),
    db("rpc/feed_who", { method: "POST", body: { account: owner } }).catch(() => null),
  ]);
  const marks = await newestMarks(rows.filter((row) => row.published).map((row) => row.id));
  return response.status(200).json({
    shared: rows.map(({ wip_at: wipAt, ...row }) => ({ ...row, wip: Boolean(wipAt), ...links(origin, row.id),
      tested: ownerMark(marks.get(row.id)) })),
    // Whom Show who made it credits (src/ui/share_panel.gd): their profile
    // shown in public, {name, handle}, or null with none.
    credit: profile && profile.name ? { name: profile.name, handle: profile.handle } : null,
  });
}

/// The mark of each link's newest version, for its owner: id -> row. A
/// newest version with none is untested, whatever an older one passed.
async function newestMarks(ids) {
  const out = new Map();
  for (let at = 0; at < ids.length; at += 100) {
    const some = ids.slice(at, at + 100).join(",");
    if (!some) continue;
    try {
      const [versions, marks] = await Promise.all([
        db(`share_versions?model=in.(${some})&select=model,n&order=n.desc`),
        db(`share_tests?model=in.(${some})&select=model,n,at,app,parts,steps,tests,passed,cleared_at,cleared_why`
          + "&order=n.desc"),
      ]);
      const newest = new Map();
      for (const one of versions) if (!newest.has(one.model)) newest.set(one.model, one.n);
      for (const one of marks) {
        if (!out.has(one.model) && one.n === (newest.get(one.model) ?? 1)) out.set(one.model, one);
      }
    } catch (trouble) {
      // Before tested.sql: nothing is tested. Else these marks are unknown
      // beside the models asked for, and said in the log by name.
      if (!/: 404$/.test(String(trouble?.message || ""))) console.error(`share: ${String(trouble?.message || trouble).slice(0, 160)}`);
    }
  }
  return out;
}

/// ?op=tested&id=X: what the app found of the owner's own model, every
/// test and why — the note to its designer a failing mark is. Nobody else's.
async function testedOwn(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const owner = await signedIn(request);
  const id = String(request.query?.id || "");
  const row = await ownRow(id);
  if (!row || !row.published) throw new Refusal("there is no shared model at that link", 404);
  // Somebody else's model: nothing to tell them, and nothing refused, since
  // every signed-in visitor's page asks (web/model-page.js) and a 403 was a
  // refused request in their console on every model not theirs.
  if (row.owner !== owner) return response.status(200).json({ id, mine: false, tested: null });
  const asked = askedVersion(request);
  const n = asked ?? (await versionsOf(id, row, 1))[0].n;
  return response.status(200).json({ id, version: n, tested: ownerMark(await markOf(db, id, n)) });
}

/// What the owner says about the model, checked at this edge: undefined
/// for anything not said, which a republish keeps as it was.
function saidAbout(body) {
  try {
    return {
      description: cleanDescription(body.description),
      tags: cleanTags(body.tags),
      kind: cleanKind(body.kind),
      licence: cleanLicence(body.licence),
    };
  } catch (trouble) {
    if (trouble instanceof Unacceptable) throw new Refusal(trouble.message, trouble.status);
    throw trouble;
  }
}

async function publish(request, response) {
  const claims = await verify(bearer(request), request);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const { status, answer } = await publishModel(claims, body, request);
  return response.status(status).json(answer);
}

/// A publish by [claims]' account of [body] (the POST's, above), [request]
/// the one it came in on (its origin and scope): {status, answer}. The
/// house publishes through it too (api/_prompts.js, its own claims), and
/// says which pool its model is in ([test]).
export async function publishModel(claims, body, request, { test = isTestAccount(claims) } = {}) {
  const owner = claims.sub;
  // What a file says of its builder without their asking (an Author line
  // with an email address, a place on their computer: web/private-lines.js)
  // is left out of what is kept, from the app, the connector or the site's
  // Share from a file alike: anyone with the link can download the file.
  const model = withoutPrivateLines(body.model).text;

  // Everything about the upload is checked before anything is counted
  // or stored, so a refused upload costs nobody a publish.
  const { parts: lines, bytes, steps, ownSteps, technic, needs } = checkModel(model);
  // Kept as its page and the app's parts list count it, so its card says
  // what its page does (web295).
  const parts = piecesIn(model, lines);
  // Who modelled it, when it is a model of the app's own Library: found
  // there and held to its file, never taken from what this file says of
  // itself (api/_omr_credit.js). Its licence is then the library model's.
  const library = await libraryCredit(model, needs, { needsOf: (text) => checkModel(text).needs });
  const modelledBy = library
    ? { name: library.name, page: library.page, ...(library.changed ? { changed: true } : {}) } : null;
  const picture = checkImage(body.image);
  // The same with nothing behind the model, for its page in either theme.
  const cutout = checkImage(body.cutout, "the picture for its page");
  const thumb = checkThumb(body.thumb);
  const madeWith = checkMadeWith(body.made_with);
  const shownAsked = checkMadeShown(body.made_with_shown);
  // What the app found, checked against this very file as the app sent it
  // (api/_tested.js), which it hashed before anything was left out.
  const finding = checkTested(body.tested, body.model);
  // And what moves in it, from its joints (supabase/play.sql), and its own
  // motions' names, from the text itself (supabase/motions.sql).
  const moves = checkMoves(body.moves);
  const motions = motionsIn(model);
  const name = cleanText(body.name, MAX_NAME);
  if (!name) throw new Refusal("give the model a name to share it under");
  // A credit is the person's profile, by its name, when they have one shown
  // in public, whatever name came with it: as Studio and Mecabricks credit
  // your username, and as the model's page heads it. Without one, the name
  // given, but never one made from the address they sign in with, which an
  // app before m157 offered (walk180, 2026-10-23).
  let author = cleanText(body.author, MAX_AUTHOR) || null;
  if (author) {
    const profile = await db("rpc/feed_who", { method: "POST", body: { account: owner } });
    if (profile && profile.name) author = profile.name;
    else if (madeFromAddress(author, claims.email)) {
      throw new Refusal("that name to credit is made from the address you sign in with, which Brickworks never "
        + "shows: make a profile at brickworks.diy/profile to be credited by its name, or give another", 422);
    }
  }
  if (body.listed !== undefined && typeof body.listed !== "boolean") {
    throw new Refusal("listed is true or false");
  }
  const listed = body.listed === true;
  if (body.wip !== undefined && typeof body.wip !== "boolean") throw new Refusal("wip is true or false");
  const wip = body.wip === true;
  // Whether supabase/wip.sql is here: before it, nothing of work in
  // progress is read or written, and a publish asking for it is refused.
  const wipHere = await wipReady();
  if (wip && !wipHere) throw new Refusal(WIP_NOT_YET, 503);
  // Work in progress goes to the followers' feeds and a Talk thread by its
  // designer's name, so a link shared with only a few, or a model they chose
  // not to put their name on, is never shown there.
  if (wip && !(listed && author)) {
    throw new Refusal(WIP_SHOWN, 422);
  }
  const about = saidAbout(body);
  // What its owner says changed in this version, if anything.
  const note = cleanText(body.note, MAX_NOTE) || null;
  const fromVersion = body.remixed_from_version;
  if (fromVersion !== undefined && fromVersion !== null
      && !(Number.isInteger(fromVersion) && fromVersion >= 1 && fromVersion <= 100000)) {
    throw new Refusal("remixed_from_version is a version's number, from 1");
  }
  // What a stranger may not be shown, in a name or anywhere it is said
  // (api/_names.js): before anything is counted or stored.
  const said = namesTrouble({ "The name": [name, "name"], "The credit": [author, "name"],
    "A tag": [about.tags, "name"], "The description": [about.description, "words"],
    "What changed": [note, "words"] });
  if (said) throw new Refusal(said);

  let id = body.id === undefined || body.id === null || body.id === "" ? "" : String(body.id);
  let existing = null;
  if (id) {
    existing = await ownRow(id);
    if (!existing) throw new Refusal("there is no shared model at that link to update", 404);
    if (existing.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
    if (wipHere) existing.wip_at = (await db(`shared_models?id=eq.${id}&select=wip_at`))[0]?.wip_at ?? null;
  }
  // 409, not 403: the app answers a 403 (somebody else's link) by
  // publishing at a new link, which here would list it again.
  if (listed && existing && existing.barred) {
    throw new Refusal("Brickworks took this model out of the gallery. It is still shared at its link: "
      + "publish it without listing it.", 409);
  }
  // Said once and kept: a republish from a copy that no longer carries it
  // does not forget where the model came from.
  const parent = await remixOf(body.remixed_from, id);
  // A new remix link across a block, either way, is refused before any file
  // is written (supabase/block.sql's trigger holds it whatever writes): it
  // would sit on the other's page. A link the model already had stays.
  if (parent && parent.id !== existing?.remixed_from) refuseFor(await standingBetween(owner, parent.owner), "remix");
  const remixedFrom = parent?.id ?? existing?.remixed_from ?? null;
  const description = about.description !== undefined ? about.description : existing?.description ?? null;
  const tags = about.tags !== undefined ? about.tags : existing?.tags ?? [];
  const kind = about.kind !== undefined ? about.kind : existing?.kind ?? null;
  // Somebody else's CC BY work stays under its own licence, whatever was
  // chosen: it cannot be licensed again (supabase/modelled_by.sql).
  const licence = library ? library.licence
    : about.licence !== undefined ? about.licence : existing?.licence ?? null;
  // What the model it came from allows. 422, never 403 (above).
  const from = parent ?? (remixedFrom ? await remixOf(remixedFrom, id) : null);
  if (from && from.owner !== owner && from.licence === "cc-by-sa-4.0" && licence !== "cc-by-sa-4.0") {
    throw new Refusal("the model this was copied from is shared under CC BY-SA 4.0, so a version of it "
      + "has to be too: choose CC BY-SA 4.0 as its licence", 422);
  }
  if (from && from.owner !== owner && from.licence === "all-rights-reserved" && listed) {
    throw new Refusal("the model this was copied from is all rights reserved, so its builder has not "
      + "let versions of it into the gallery: share it by link without listing it, or ask them", 422);
  }
  // Taken out of the gallery for good, by the site's owner: the account,
  // or this very file at any link (api/admin.js). 409, never 403 (above).
  if (listed && (await barred(owner))) {
    throw new Refusal("Brickworks took your models out of the gallery, so this one cannot be listed. "
      + "It can still be shared by link: publish it without listing it.", 409);
  }
  if (listed && (await barredFile(model))) {
    throw new Refusal("Brickworks took this model out of the gallery, so it cannot be listed again, "
      + "at this link or another. It can still be shared by link: publish it without listing it.", 409);
  }
  // Into the gallery, as against staying in it: only that is counted.
  const newlyListed = listed && !(existing && existing.published && existing.listed);
  // The age rule (api/_trust.js): a listing needs 13 or over, and nothing is
  // shared at all by an account whose row says under 13. 422, never 403
  // (above).
  const young = await publicTrouble(owner, { account: "kept", listing: newlyListed ? true : listed ? "kept" : false,
    credit: Boolean(author) && author !== (existing?.author ?? null) });
  if (young) throw new Refusal(young, 422);

  // Counted as one of each or as neither (supabase/publish_listed.sql): a
  // listed publish refused for the hour's publishes costs no listing.
  const allowed = newlyListed ? await mayPublishListed(owner) : (await mayPublish(owner)) ? "ok" : "publishes";
  if (allowed === "listings") {
    throw new Refusal("you have listed a lot in the gallery in a short time: try again in an hour, "
      + "or publish it without listing it", 429);
  }
  if (allowed !== "ok") {
    throw new Refusal("you have published a lot in a short time: try again in an hour", 429);
  }

  if (!id) id = newId();
  // A new link whose row is never written leaves no files behind: they go
  // as the publish fails, rather than wait a day for the sweep.
  const dropNew = (trouble) => {
    if (!existing) {
      return deleteFiles([`${id}.mpd`, `${id}.png`, `${id}.cutout.png`, `${id}.webp`]).catch(() => {})
        .then(() => { throw trouble; });
    }
    throw trouble;
  };

  // Its next version, and the one before kept: the newest's files are
  // renamed for its number before the new one takes the link's own, and
  // what changed is worked out from the two models. A link taken down has
  // no versions left (unpublish), and shared again it starts at 1; any a
  // takedown before versions were kept left behind go first.
  const republish = Boolean(existing && existing.published);
  let earlier = [];
  let changes = null;
  if (republish) {
    earlier = await versionsOf(id, existing, 1);
    const last = earlier[0];
    if (last.implied) {
      // Shared before its versions were kept, and not since: its version 1
      // is written down now, as it is.
      await db("share_versions", { method: "POST", body: { model: id, n: 1, at: last.at, parts: last.parts,
        steps: last.steps, bytes: last.bytes, has_image: last.has_image } });
    }
    const before = await getFile(`${id}.mpd`);
    if (before) {
      await putFile(`${id}.v${last.n}.mpd`, before, "text/plain");
      // Read as the app reads them: a library's shortcut is its part.
      const table = partsTable();
      changes = changesBetween(before.toString("utf8"), model,
        (id) => Boolean(table && Object.prototype.hasOwnProperty.call(table.parts, id)));
    }
    const picturedBefore = last.has_image ? await getFile(`${id}.png`) : null;
    if (picturedBefore) await putFile(`${id}.v${last.n}.png`, picturedBefore, "image/png");
    const cutBefore = picturedBefore ? await getFile(`${id}.cutout.png`) : null;
    if (cutBefore) await putFile(`${id}.v${last.n}.cutout.png`, cutBefore, "image/png");
    // And its small picture, the card's, for the page's Log and Talk's
    // cards (supabase/wip.sql has_thumb): kept from wip.sql on.
    const thumbBefore = wipHere && existing.has_thumb ? await getFile(`${id}.webp`) : null;
    if (thumbBefore) {
      await putFile(`${id}.v${last.n}.webp`, thumbBefore, "image/webp");
      if (!last.implied) {
        await db(`share_versions?model=eq.${id}&n=eq.${last.n}`, { method: "PATCH", body: { has_thumb: true } });
      }
    }
  } else if (existing) {
    // Its versions start again from 1: a clip an unpublish failed to take
    // goes first, as it would have gone there (dropClip).
    await dropClip(id);
    await db(`share_versions?model=eq.${id}`, { method: "DELETE" });
  }
  const n = republish ? earlier[0].n + 1 : 1;
  // Which version of the model it was copied from, when it is a copy and
  // its app said: one that model has, or none. Kept by a republish that
  // does not say it again, as remixed_from is.
  let remixedFromVersion = null;
  if (parent && fromVersion) {
    const parentNewest = (await versionsOf(parent.id, null, 1))[0]?.n ?? 1;
    remixedFromVersion = fromVersion <= parentNewest ? fromVersion : null;
  } else if (remixedFrom && republish) {
    remixedFromVersion = earlier[0].from_version ?? null;
  }

  await putFile(`${id}.mpd`, model, "text/plain").catch(dropNew);
  if (picture) await putFile(`${id}.png`, picture, "image/png").catch(dropNew);
  else if (existing) await deleteFiles([`${id}.png`]).catch(() => {});
  // An app before cut-outs leaves none, and the picture is shown in its place.
  if (cutout && picture) await putFile(`${id}.cutout.png`, cutout, "image/png").catch(dropNew);
  else if (existing) await deleteFiles([`${id}.cutout.png`]).catch(() => {});
  if (thumb) await putFile(`${id}.webp`, thumb, "image/webp").catch(dropNew);
  else if (existing) await deleteFiles([`${id}.webp`]).catch(() => {});

  const now = new Date().toISOString();
  const row = { name, author, parts, bytes, has_image: Boolean(picture), has_thumb: Boolean(thumb),
    published: true, updated_at: now, listed, listed_at: listed ? (newlyListed ? now : existing.listed_at) : null,
    remixed_from: remixedFrom, description, tags, kind, licence, steps, own_steps: ownSteps, technic,
    test };
  // Work in progress since its first WIP version, until one is published
  // without it: that one finishes it (supabase/wip.sql).
  const wasWip = republish && Boolean(existing?.wip_at);
  const finished = wasWip && !wip;
  if (wipHere) row.wip_at = wip ? (wasWip ? existing.wip_at : now) : null;
  if (existing) {
    await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: row });
  } else {
    await db("shared_models", { method: "POST", body: { id, owner, ...row } }).catch(dropNew);
  }
  // The version itself, after its model's row (it is that row's).
  const first = n === 1 ? null : changes ? changes.first : 1;
  await db("share_versions", { method: "POST", body: { model: id, n, at: now, note, parts, steps, bytes,
    has_image: Boolean(picture), changes, first_changed: first, remixed_from_version: remixedFromVersion,
    ...(wipHere ? { wip, finished_at: finished ? now : null, has_thumb: Boolean(thumb) } : {}) } });
  // What the app found of this version, kept with it as the app's finding.
  // One that cannot be kept, or a table not there yet, never stops the
  // publish: the version is then untested, and the answer says why.
  let kept = null;
  if (finding?.row) {
    try {
      await db("share_tests", { method: "POST", body: { model: id, n, at: now, ...finding.row } });
      kept = { kept: true, passed: finding.row.passed, by: "app", app: finding.row.app,
        tests: ownerMark({ ...finding.row, n, at: now }).tests };
    } catch {
      kept = { kept: false, why: "Brickworks could not keep what it found just now" };
    }
  } else if (finding?.refused) {
    kept = { kept: false, why: finding.refused };
  }
  // What it needs, by part and colour, in place of what it needed: the
  // gallery's Build with what I own. Never stops the publish; before
  // supabase/discovery.sql there is nowhere to keep it.
  const needsKept = await keepNeeds(id, needs);
  // And which real set builds it, or which few sets do (api/_alts.js),
  // counted from those needs against every set's inventory: after the
  // answer, so the publish never waits on it.
  if (needsKept) afterAnswer(() => keepAlts(id, keyed(needs || []), { library }), "share: alternate builds");
  const movesKept = await keepMoves(id, owner, moves, motions);
  const madeKept = await keepMadeWith(id, owner, madeWith);
  const shownKept = await keepMadeShown(id, owner, shownAsked);
  const modelledKept = await keepModelledBy(id, owner, modelledBy, Boolean(existing));
  // A person's first model told to the owner (api/_notify.js): no other
  // link of theirs made before this one wrote its row (one row at most, by
  // the owner's index), and once by its owner's key, so two published at
  // once tell of one. After the answer (api/_after.js): never in the way
  // of the publish.
  if (!existing) {
    const scope = scopeOf(request);
    afterAnswer(async () => {
      const other = await db(`shared_models?owner=eq.${owner}&id=neq.${id}&created_at=lt.${now}&select=id&limit=1`, { seconds: 5 });
      if (Array.isArray(other) && other.length === 0) {
        await raise("first_model", { scope, test: row.test, key: owner, account: owner,
          detail: { id, name, parts, listed: Boolean(listed) } });
      }
    }, "share: first model");
  }

  const origin = originOf(request);
  // A copy of the template of this week's quick build, published in the
  // gallery, enters it; prompt_out (the dialog's one tap) keeps it out
  // (api/_prompts.js). Never in the way of the publish.
  const prompt = await promptOnPublish(origin, owner, id, remixedFrom, body.prompt_out === true);
  // A work in progress, or its finish, is one post in the model's Talk
  // thread, as its designer (api/_wip.js): never in the way of the publish.
  let talk = null;
  if (wipHere && (wip || (finished && listed && author))) {
    const profile = await db("rpc/feed_who", { method: "POST", body: { account: owner } }).catch(() => null);
    talk = await postVersion(owner, { id, name }, { n, note, changes, kind: wip ? "wip" : "finished", origin, profile });
  }
  // What a remix changed from the version of the model it was copied from,
  // counted once and kept with it (api/_remix.js): begun only once the
  // answer is written (countAfter waits a turn past this code and the
  // caller's await on it), so the publish waits on neither the original's
  // file nor the count. Last before the answer: an await after it would
  // let the count start first.
  if (remixedFrom) {
    countAfter({ id, n, text: model, from: remixedFrom, said: remixedFromVersion, since: existing ? null : now, getFile });
  }
  return { status: existing ? 200 : 201, answer: {
    id, name, author, parts, bytes, published: true, updated: Boolean(existing),
    wip, finished, talk,
    listed, remixed_from: remixedFrom, remixed_from_version: remixedFromVersion, gallery: `${origin}/gallery`,
    description, tags, kind, licence, steps, own_steps: ownSteps, technic,
    version: n, note, changes: readChanges(changes), said: saidOf(n, changes), first_changed: first,
    version_url: `${origin}/m/${id}/v/${n}`, tested: kept, moves: movesKept.moves, motions: movesKept.motions,
    made_with: madeKept, made_with_shown: shownKept, modelled_by: modelledKept, ...(prompt ? { prompt } : {}), ...links(origin, id),
  } };
}

/// How long after its publish a version may still be given its pictures.
export const PICTURES_WINDOW_MS = 15 * 60 * 1000;

/// ?op=pictures&id=X: the pictures of a version its owner published a
/// moment ago without any (byfix, 2026-11-21). The site's Share from a file
/// (web/share-model.js) can draw a model only once the server has it (its
/// 3D view reads /m/X/scene.json), so it publishes the file, draws it, and
/// puts the pictures on here: one publish counted, as the app's Share is,
/// and the link never taken down to do it. Only the owner's link, only its
/// newest version (the one named, when one is), only within
/// PICTURES_WINDOW_MS of its publish, and only while it has no picture:
/// a version that has one is answered as done, with nothing written. Each
/// picture checked as a publish checks it.
async function pictures(request, response) {
  const owner = await signedIn(request);
  const id = String(request.query?.id || request.body?.id || "");
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const picture = checkImage(body.image);
  const cutout = checkImage(body.cutout, "the picture for its page");
  const thumb = checkThumb(body.thumb);
  if (!picture) throw new Refusal("there is no picture to put on it");
  const version = body.version;
  if (version !== undefined && version !== null && !(Number.isInteger(version) && version >= 1)) {
    throw new Refusal("version is a version's number, from 1");
  }
  const row = await ownRow(id);
  if (!row || !row.published) throw new Refusal("there is no shared model at that link", 404);
  if (row.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  const newest = (await versionsOf(id, row, 1))[0];
  if (version !== undefined && version !== null && version !== newest.n) {
    throw new Refusal("that is not its newest version, so its pictures are not this one's: share it again to give it pictures", 409);
  }
  const origin = originOf(request);
  if (newest.has_image) return response.status(200).json({ id, version: newest.n, pictures: true, already: true, ...links(origin, id) });
  if (newest.implied || !(Date.now() - Date.parse(newest.at) <= PICTURES_WINDOW_MS)) {
    throw new Refusal("it was published too long ago to be given pictures now: share it again to give it pictures", 409);
  }
  await putFile(`${id}.png`, picture, "image/png");
  if (cutout) await putFile(`${id}.cutout.png`, cutout, "image/png");
  if (thumb) await putFile(`${id}.webp`, thumb, "image/webp");
  // The row first, which its page and card read; the version last, which
  // says it is done: a write that fails between is put right by asking again.
  await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, { method: "PATCH", body: { has_image: true, has_thumb: Boolean(thumb) } });
  await db(`share_versions?model=eq.${id}&n=eq.${newest.n}`, { method: "PATCH", body: { has_image: true } });
  return response.status(200).json({ id, version: newest.n, pictures: true, already: false, ...links(origin, id) });
}

async function unpublish(request, response) {
  const owner = await signedIn(request);
  const id = String(request.query?.id || request.body?.id || "");
  const row = await ownRow(id);
  if (!row) throw new Refusal("there is no shared model at that link", 404);
  if (row.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  // Out of the gallery with it: published again, it is listed again only
  // if the box is ticked again.
  await db(`shared_models?id=eq.${id}&owner=eq.${owner}`, {
    method: "PATCH", body: { published: false, listed: false, listed_at: null,
      updated_at: new Date().toISOString() } });
  // Its clip first, whatever fails after: published again, the versions
  // start again from 1, and a clip of the old model must never pass for
  // the new one's (ttreview F3; clipCurrent holds it to its version's
  // time as well).
  await dropClip(id);
  // The row stays, so the link can say it was taken down, and a
  // republish from the same model keeps the same link. The files go, every
  // version's, and then the versions themselves.
  const versions = await db(`share_versions?model=eq.${id}&select=n`);
  await deleteFiles([`${id}.mpd`, `${id}.png`, `${id}.cutout.png`, `${id}.webp`,
    ...versions.flatMap((one) => [`${id}.v${one.n}.mpd`, `${id}.v${one.n}.png`, `${id}.v${one.n}.cutout.png`,
      `${id}.v${one.n}.webp`])]);
  await db(`share_versions?model=eq.${id}`, { method: "DELETE" });
  return response.status(200).json({ id, published: false, versions: versions.length });
}

// ---------------------------------------------------------------------------
// The clip (unit turntable, supabase/model_clips.sql).
//
// The model turning once round, recorded in its designer's own browser,
// in a worker off the page's own thread, the first time they visit its
// page with no clip of its newest version (web/model-page.js,
// web/turntable-worker.js), so a model shared from the studio, the desktop
// app or the site gets one alike. Its page names it in og:video, and in
// the player's tags beside X's picture card, while it is of the newest
// version; a model with none keeps its picture card. A file per model,
// deleted on unpublish, with the account (api/_erase.js), and by the sweep
// where no published model owns it or its row names the other kind.

/// The two names a model's clip can have: what an unpublish or a deletion
/// takes away.
const clipFiles = (id) => [`${id}.mp4`, `${id}.webm`];

/// A model's clip as its row says, {version, kind, width, height, ms,
/// bytes, made_at}, or null for none. Throws where the table cannot be read
/// (before its SQL): what that means is the caller's to say.
async function clipOf(id) {
  if (!ID.test(id || "")) return null;
  const rows = await db(`model_clips?model=eq.${id}&select=version,kind,width,height,ms,bytes,made_at`);
  return rows[0] || null;
}

/// Its row gone, where there is a table to have one (before the SQL there
/// is none, and nothing to forget); with [made], only the row of the clip
/// made then.
async function forgetClip(id, made = "") {
  const which = made ? `&made_at=eq.${encodeURIComponent(made)}` : "";
  await db(`model_clips?model=eq.${id}${which}`, { method: "DELETE" }).catch((trouble) => {
    if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
  });
}

/// A model's clip taken wherever its versions start again from 1: its row
/// first, so nothing names the clip whatever fails after, then its files,
/// which the sweep takes on a later day if storage fails now.
async function dropClip(id) {
  await forgetClip(id);
  await deleteFiles(clipFiles(id)).catch((trouble) => console.error(`share: clip files of ${id}: ${trouble?.message || trouble}`));
}

/// Whether [clip] is of the [newest] version ({n, at, implied}): its number,
/// and made after that version was, so a clip a failed unpublish left of a
/// version 1 never passes for the version 1 of the model published again.
function clipCurrent(clip, newest) {
  if (!clip || !newest || !CLIP_TYPES[clip.kind] || clip.version !== newest.n) return false;
  return Boolean(newest.implied) || Date.parse(clip.made_at) >= Date.parse(newest.at);
}

/// Which clip of a model an address is of: when it was made, in base 36.
const clipMark = (clip) => (Date.parse(clip.made_at) || 0).toString(36);
/// The clip's own address, with its version and its mark: an address only
/// this clip ever has, which a CDN and a link preview may keep, and which a
/// new clip, a republish or a model published again changes.
const clipPath = (id, clip) => `/m/${id}.${clip.kind}?v=${clip.version}&c=${clipMark(clip)}`;
const clipUrl = (origin, id, clip) => `${origin}${clipPath(id, clip)}`;

/// What a page's head says of a model's [clip] (og:video, the player's
/// tags, web/embed.js playing it with ?autoplay=1 as the player), or null
/// where it has none of the [newest] version (clipCurrent). [at] the page's
/// language's part of an address ("/de"), for the player's card in it.
function clipShown(origin, id, clip, newest, at = "") {
  if (!clipCurrent(clip, newest)) return null;
  return { url: clipUrl(origin, id, clip), path: clipPath(id, clip), type: CLIP_TYPES[clip.kind], width: clip.width,
    height: clip.height, player: `${origin}${at}/m/${id}/embed?autoplay=1` };
}

// Kept by the CDN ten minutes at its own address (clipPath), and every
// range a player asks of it answered by the CDN from that one copy: a clip
// played on a busy page is a read here every ten minutes a region, not one
// a play (ttreview F1). Another address, as briefly as the pictures.
const CLIP_CACHE = "public, max-age=300, s-maxage=600, stale-while-revalidate=60";
// The last few clips this instance read, by file and when each was made,
// the latest asked last: what a CDN region's miss reads again.
const CLIPS_KEPT = 8;
const clipsKept = new Map();

/// /m/X.mp4 or /m/X.webm: the model's clip while the model is published,
/// in the kind asked; with ?v=N only while it is of version N, and with
/// ?c=K only while it is the clip K says (clipMark). Always the whole file
/// with 200: Vercel's CDN keeps it and answers each Range from it (206,
/// Safari's two bytes first among them), where a 206 from here could never
/// be kept and every play of it came here (ttreview F1).
async function clipAnswer(request, response, row, id) {
  const as = String(request.query?.as || "");
  const v = String(request.query?.v ?? "");
  const asked = v === "" ? null : VERSION.test(v) ? Number(v) : -1;
  const mark = request.query?.c === undefined ? null : String(request.query.c);
  const clip = row && CLIP_TYPES[as] ? await orUnknown("share", clipOf(id)) : null;
  const none = () => response.status(404).setHeader("Cache-Control", "no-store").end("");
  if (!clip || clip.kind !== as || (asked !== null && asked !== clip.version) || (mark !== null && mark !== clipMark(clip))) {
    return none();
  }
  const key = `${id}.${as}@${clip.made_at}`;
  let bytes = clipsKept.get(key);
  if (bytes) {
    clipsKept.delete(key);
  } else {
    bytes = await getFile(`${id}.${as}`);
    if (!bytes) return none();
  }
  clipsKept.set(key, bytes);
  while (clipsKept.size > CLIPS_KEPT) clipsKept.delete(clipsKept.keys().next().value);
  response.setHeader("Content-Type", CLIP_TYPES[as]);
  // A link preview on any site, and an embed in any page, may play it.
  response.setHeader("Cross-Origin-Resource-Policy", "cross-origin");
  response.setHeader("X-Content-Type-Options", "nosniff");
  // The CDN's ranges, from the whole file kept.
  response.setHeader("Accept-Ranges", "bytes");
  response.setHeader("Cache-Control", asked !== null && mark !== null ? CLIP_CACHE : SHARED_CACHE);
  return response.status(200).end(bytes);
}

/// The owner's own: {mine, ready, version, at, clip}: whether the model is
/// theirs and published, whether clips can be kept here yet (ready: before
/// supabase/model_clips.sql there is nowhere), its newest version's number
/// and when it was made, and its clip of that version ({version, kind}, or
/// null), from which their page decides whether to record one
/// (web/model-page.js) and what it records it from.
async function clipNeed(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const owner = await signedIn(request);
  const id = String(request.query?.id || "");
  const row = await ownRow(id);
  if (!row || !row.published || row.owner !== owner) return response.status(200).json({ mine: false });
  const [newest] = await versionsOf(id, row, 1);
  let clip = null;
  let ready = true;
  try {
    clip = await clipOf(id);
  } catch (trouble) {
    if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    ready = false;
  }
  return response.status(200).json({ mine: true, ready, version: newest.n, at: newest.at,
    clip: clipCurrent(clip, newest) ? { version: clip.version, kind: clip.kind } : null });
}

// A clip a model is a recording of its newest version, made once a visit
// at most: twenty an hour is a designer republishing all afternoon, and
// anything past it is something else.
const CLIP_LIMIT = { per_hour: 20, per_day: 60 };

/// POST ?op=clip&id=X {version, at, clip}: the owner's browser sends the
/// clip it recorded of version [version], made at [at] (clip_need's,
/// web/turntable-worker.js), base64. Read here before anything is kept
/// (api/_clip.js readClip: one picture track, H.264 in an MP4 or VP8/VP9 in
/// a WebM, 4 s or less by its frames' own times, 1.5 MB or less), and only
/// while that very version is still the newest; then kept at <id>.mp4 or
/// <id>.webm and its row written. A clip of the other kind is left for the
/// sweep: two browsers recording at once each keep their own file, and the
/// row names one (ttreview N2).
async function clipPut(request, response) {
  const owner = await signedIn(request);
  const id = String(request.query?.id || "");
  const row = await ownRow(id);
  if (!row || !row.published) throw new Refusal("there is no shared model at that link", 404);
  if (row.owner !== owner) throw new Refusal("that link is somebody else's model", 403);
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const given = body.clip;
  if (typeof given !== "string" || given.length === 0 || !/^[A-Za-z0-9+/]+=*$/.test(given)) {
    throw new Refusal("the clip is not readable", 415);
  }
  const bytes = Buffer.from(given, "base64");
  const facts = readClip(bytes);
  if (facts.error) throw new Refusal(facts.error, bytes.length > MAX_CLIP_BYTES ? 413 : 415);
  // The version it was recorded of, by its number and when it was made: a
  // version 1 of the model as it was before an unpublish is not this one.
  const ofThis = (one) => one.n === Number(body.version) && String(one.at) === String(body.at ?? "");
  const [newest] = await versionsOf(id, row, 1);
  if (!VERSION.test(String(body.version ?? "")) || !ofThis(newest)) {
    throw new Refusal("the model has a newer version than this clip: its page records one again", 409);
  }
  // Before supabase/model_clips.sql there is nowhere to keep one.
  try {
    await clipOf(id);
  } catch (trouble) {
    if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
    throw new Refusal("clips cannot be kept on this deployment yet", 503);
  }
  const allowed = await db("rpc/may_act", { method: "POST", body: { actor: owner, act: "clip", ...CLIP_LIMIT } });
  if (allowed !== true) throw new Refusal("that is a lot of clips in a short time: try again in an hour", 429);
  await putFile(`${id}.${facts.kind}`, bytes, CLIP_TYPES[facts.kind]);
  const made = new Date().toISOString();
  const clip = { version: newest.n, kind: facts.kind, width: facts.width, height: facts.height, ms: facts.ms,
    bytes: bytes.length, made_at: made };
  await db("model_clips?on_conflict=model", { method: "POST", prefer: "resolution=merge-duplicates,return=minimal",
    body: { model: id, ...clip } });
  // Taken down while it came, or published anew: nothing of it kept for a
  // link that says it was taken down, nor named for a version it is not of
  // (the sweep takes a file left within the day).
  const still = await ownRow(id);
  if (!still || !still.published) {
    await forgetClip(id, made);
    await deleteFiles(clipFiles(id)).catch(() => {});
    throw new Refusal("there is no shared model at that link", 404);
  }
  const [now] = await versionsOf(id, still, 1);
  if (!ofThis(now)) {
    await forgetClip(id, made);
    throw new Refusal("the model has a newer version than this clip: its page records one again", 409);
  }
  return response.status(200).json({ id, clip, url: clipUrl(originOf(request), id, clip) });
}

// ---------------------------------------------------------------------------
// The sweep.
//
// A row goes with its account (on delete cascade), but the bucket's files
// are not rows, and Supabase refuses to delete storage objects from SQL,
// so an account deleted in the dashboard left its models' files behind
// for good. Once a day this takes away every file that no published row
// owns, and every photo's file whose photo has no row or was taken out
// (api/_builds.js sweepPhotos). A publish writes its files a moment before
// its row, so a file younger than an hour is left for the next day's sweep.
// Neither takes more than a quarter of what it looked at unasked
// (api/_cron.js sweepHeld): rows read back empty would otherwise delete
// every file.

const SWEEP_AGE_MS = 60 * 60 * 1000;
// A deleted link's note is kept this long, covering any file of it the
// sweep had not yet come to (each is over an hour old first).
const GONE_KEPT_MS = 7 * 24 * 3600 * 1000;

/// Which of [ids] were deleted (supabase/models_gone.sql): a Set. Before
/// that file, or the read failing, none: the quarter then holds for all.
async function linksGone(ids) {
  const out = new Set();
  try {
    for (let at = 0; at < ids.length; at += 100) {
      const rows = await db(`shared_models_gone?id=in.(${ids.slice(at, at + 100).join(",")})&select=id`);
      for (const row of rows) out.add(row.id);
    }
  } catch (trouble) {
    if (!/: 40[04]$/.test(String(trouble?.message || ""))) {
      console.error(`sweep: deleted links not read: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
    return new Set();
  }
  return out;
}

/// The notes older than GONE_KEPT_MS forgotten. Never throws: a note left
/// is pruned tomorrow.
async function linksForgotten(now) {
  try {
    await db(`shared_models_gone?gone_at=lt.${new Date(now - GONE_KEPT_MS).toISOString()}`, { method: "DELETE" });
  } catch (trouble) {
    if (!/: 40[04]$/.test(String(trouble?.message || ""))) {
      console.error(`sweep: deleted links' notes kept: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
}

async function sweep(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the sweep is the cron's" });
  // The cron's run written down, however it ends (/admin#site); a check's
  // scoped one (?only=, ?photos=) is the check's, not the cron's.
  const started = new Date().toISOString();
  const scoped = Boolean(request.query?.only || request.query?.photos);
  try {
    return await sweepRun(request, response, scoped ? null : started);
  } catch (trouble) {
    if (!scoped) await cronNoted(request, "share_sweep", started, "failed", { error: String(trouble?.message || trouble).slice(0, 200) });
    throw trouble;
  }
}

async function sweepRun(request, response, started) {
  // ?only=A,B looks at those links alone, whatever their files' age: how
  // share_probe proves an orphan goes without waiting an hour. ?photos=P,Q
  // the same for photos' files; either alone looks at nothing else.
  const only = String(request.query?.only || "").split(",").filter((id) => ID.test(id));
  const photos = String(request.query?.photos || "").split(",").filter((id) => ID.test(id));
  const scoped = only.length > 0 || photos.length > 0;
  const now = Date.now();
  const files = (await listFiles()).filter((file) => {
    const id = file.name.split(".")[0];
    if (scoped) return only.includes(id);
    return now - Date.parse(file.updated_at || file.created_at || 0) > SWEEP_AGE_MS;
  });
  const ids = [...new Set(files.map((file) => file.name.split(".")[0]).filter((id) => ID.test(id)))];
  const kept = new Set();
  for (let at = 0; at < ids.length; at += 100) {
    const rows = await db(`shared_models?id=in.(${ids.slice(at, at + 100).join(",")})&published=is.true&select=id`);
    for (const row of rows) kept.add(row.id);
  }
  // A published model's clip file its row does not name goes too: the other
  // kind, when two browsers recorded at once (clipPut), or one whose row an
  // unpublish forgot while storage failed (dropClip).
  const clipsOf = [...new Set(files.filter((file) => bucketOf(file.name) === CLIPS).map((file) => file.name.split(".")[0])
    .filter((id) => kept.has(id)))];
  const named = new Set();
  for (let at = 0; at < clipsOf.length; at += 100) {
    const rows = await db(`model_clips?model=in.(${clipsOf.slice(at, at + 100).join(",")})&select=model,kind`).catch((trouble) => {
      if (!/: 40[04]$/.test(String(trouble?.message || ""))) throw trouble;
      return null;
    });
    // No table yet: nothing is known of them, and nothing goes.
    if (rows === null) for (const id of clipsOf) for (const name of clipFiles(id)) named.add(name);
    else for (const row of rows) named.add(`${row.model}.${row.kind}`);
  }
  const gone = files.map((file) => file.name).filter((name) => !kept.has(name.split(".")[0])
    || (bucketOf(name) === CLIPS && !named.has(name)));
  // Links whose rows were deleted say so (supabase/models_gone.sql), however
  // they went: a deleted account's models, every check's throwaway's. Their
  // files are known to be nobody's and go whatever their number.
  const known = scoped ? new Set() : await linksGone([...new Set(gone.map((name) => name.split(".")[0]))]);
  const knownGone = gone.filter((name) => known.has(name.split(".")[0]));
  const unknownGone = gone.filter((name) => !known.has(name.split(".")[0]));
  // Most of the rest, unasked: the rows' read is wrong, not the files
  // (api/_cron.js sweepHeld). None of those, said; the known ones still go.
  const held = scoped ? "" : sweepHeld(files.length - knownGone.length, unknownGone.length);
  if (held) console.error(`sweep: models' files ${held}`);
  const removing = held ? knownGone : gone;
  for (let at = 0; at < removing.length; at += 100) await deleteFiles(removing.slice(at, at + 100));
  if (!scoped) await linksForgotten(now);
  // Who looked at what, kept only as long as it takes to count a visitor
  // once a day: today's and yesterday's.
  const yesterday = new Date(now - 24 * 3600 * 1000).toISOString().slice(0, 10);
  if (!scoped) await db(`model_views?day=lt.${yesterday}`, { method: "DELETE" });
  // How often each account or visitor did things (may_act), kept a day.
  if (!scoped) await db(`act_log?at=lt.${new Date(now - 24 * 3600 * 1000).toISOString()}`, { method: "DELETE" });
  // A photo as a phone sent it is read and deleted at once (api/_builds.js);
  // one whose sender never asked for it to be kept is gone within the day,
  // an hour after it came. Only that bucket's, and only files over an hour.
  let originals = 0;
  if (!scoped) {
    const stale = (await uploadsLeft()).filter((file) => now - Date.parse(file.at || 0) > SWEEP_AGE_MS)
      .map((file) => file.name);
    for (let at = 0; at < stale.length; at += 100) await deleteBuildFiles(UPLOADS, stale.slice(at, at + 100));
    originals = stale.length;
  }
  // A photo's files with no photo, its copy for the cards among them: a
  // failure said in the log and the answer, never stopping the rest.
  let photoFiles = null;
  if (!scoped || photos.length > 0) {
    try {
      photoFiles = await sweepPhotos({ now, age: SWEEP_AGE_MS, only: photos });
    } catch (trouble) {
      const said = String(trouble?.message || trouble).slice(0, 160);
      console.error(`sweep: build photos: ${said}`);
      photoFiles = { trouble: said };
    }
  }
  const answer = { looked_at: files.length, kept: files.length - removing.length,
    removed: removing, ...(held ? { held } : {}), originals, photos: photoFiles };
  if (started) {
    await cronNoted(request, "share_sweep", started, held || photoFiles?.trouble ? "failed" : "done", {
      looked_at: files.length, removed: removing.length, originals, ...(held ? { held: held.slice(0, 300) } : {}),
      ...(photoFiles?.trouble ? { photos: photoFiles.trouble } : {}) });
  }
  return response.status(200).json(answer);
}

// The front's daily choice (api/_featured.js) and the weekly look at the OMR
// (api/_omr_watch.js): each the cron's alone, under its own lock, and each
// run written down (supabase/gallery_crons.sql cron_runs), however it ends.

/// Who ran a cron, for its log: Vercel's, or somebody by hand with the secret.
const holderOf = (request) => (/^vercel-cron\b/.test(String(request.headers?.["user-agent"] || "")) ? "vercel-cron" : "by-hand");

async function feature(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the front's choice is the cron's" });
  return response.status(200).json(await runFeatures({ db, sets: () => librarySets(), holder: holderOf(request) }));
}

/// /api/share/prompts, the cron's every hour (and ?tests=1 a flow's, with
/// the cron's key): the house's part of the weekly quick build
/// (api/_prompts.js runPrompts), published as the house, through the
/// publish every model goes through, with a picture drawn of its parts.
async function prompts(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the house's quick builds are the cron's" });
  const house = await db("rpc/talk_house", { method: "POST", body: {} });
  if (!house) return response.status(409).json({ error: "the house has no account on this project" });
  const tests = testsAsked(request.query || {});
  const table = partsTable();
  const root = storeRoot();
  const meshes = new Map();
  // Each part's geometry, once a mesh, from the store the app reads it from.
  const placedWith = async (text) => {
    const placed = placedOf(text, table);
    for (const one of placed) {
      if (!meshes.has(one.mesh)) {
        const bytes = root ? await storeBytes(`${one.mesh}.lbm`).catch(() => null) : null;
        meshes.set(one.mesh, bytes ? bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.length) : null);
      }
      one.bytes = meshes.get(one.mesh);
    }
    return placed;
  };
  const done = await runPrompts({
    tests, holder: holderOf(request), origin: originOf(request),
    publishAs: async ({ body, test }) => (await publishModel({ sub: house, email: "" }, body, request, { test })).answer,
    readModel: async (id) => (ID.test(id) ? (await getFile(`${id}.mpd`))?.toString("utf8") ?? null : null),
    measure: async (text) => heightOf((await placedWith(text)).map((one) => ({ m: one.m, corners: cornersOf(one.bytes) }))),
    picture: async (text) => {
      const placed = await placedWith(text);
      return placed.some((one) => one.bytes) ? pngOf(drawModel(placed, paletteOf(table))).toString("base64") : null;
    },
  });
  return response.status(200).json(done);
}

/// The corners of a part's box ([bytes] its .lbm), in LDraw's own frame
/// (its y and z turned back over): what heightOf turns as the part is placed.
function cornersOf(bytes) {
  if (!bytes) return null;
  let geometry;
  try {
    geometry = parseLbm(bytes);
  } catch {
    return null;
  }
  const low = [Infinity, Infinity, Infinity];
  const high = [-Infinity, -Infinity, -Infinity];
  for (const surface of geometry.surfaces) {
    const at = surface.position;
    for (let v = 0; v < at.length; v += 3) {
      const p = [at[v], -at[v + 1], -at[v + 2]];
      for (let k = 0; k < 3; k += 1) {
        low[k] = Math.min(low[k], p[k]);
        high[k] = Math.max(high[k], p[k]);
      }
    }
  }
  if (!Number.isFinite(low[0])) return null;
  const out = [];
  for (const x of [low[0], high[0]]) for (const y of [low[1], high[1]]) for (const z of [low[2], high[2]]) out.push([x, y, z]);
  return out;
}

/// How LDraw's site is asked, as tools/omr.py asks it: named, and briefly.
const OMR_AGENT = "brickworks (https://brickworks.diy)";

async function omrWatch(request, response) {
  response.setHeader("Cache-Control", "no-store");
  if (!isCron(request)) return response.status(401).json({ error: "the look at the OMR is the cron's" });
  // When the store's index was last written: a file of a set it has, changed
  // after that, is an update.
  const root = storeRoot();
  const head = root ? await fetch(`${root}library/index.json`, { method: "HEAD" }).catch(() => null) : null;
  const indexAt = Date.parse(head?.headers.get("last-modified") || "") || 0;
  const fetchText = async (url) => {
    const answer = await fetch(url, { headers: { "user-agent": OMR_AGENT }, signal: AbortSignal.timeout(20000) })
      .catch(() => null);
    return { status: answer ? answer.status : 0, text: answer && answer.ok ? await answer.text() : "" };
  };
  const done = await runOmrWatch({ db, fetchText, sets: () => librarySets(), indexAt, holder: holderOf(request),
    dry: request.query?.dry === "1" });
  return response.status(200).json({ ...done, index_at: indexAt ? new Date(indexAt).toISOString() : null });
}

async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
      .end();
  }
  // The desktop app publishes from no page at all; a browser on another
  // site gains nothing from a session it does not have.
  response.setHeader("Access-Control-Allow-Origin", "*");

  if (!dbConfigured() || !process.env.SUPABASE_PUBLISHABLE_KEY) {
    return response.status(503).json({ error: "sharing is not set up on this deployment" });
  }

  try {
    // HEAD as GET, its body left off by the server: what a link checker,
    // a crawler and a preview ask a page and a picture first.
    if (request.method === "GET" || request.method === "HEAD") return await read(request, response);
    if (request.method !== "POST") return response.status(405).json({ error: "GET or POST" });
    response.setHeader("Cache-Control", "no-store");
    const op = String(request.query?.op || "");
    if (op === "unpublish") return await unpublish(request, response);
    if (op === "finish") return response.status(200).json(await finishWip(await signedIn(request), request.body?.id, originOf(request)));
    if (op === "pictures") return await pictures(request, response);
    if (op === "seen") return await seen(request, response);
    if (op === "built") return await built(request, response);
    if (op === "bases") return await basesPut(request, response);
    if (op === "clip") return await clipPut(request, response);
    if (op === "made") return await madeShown(request, response);
    if (op === "") return await publish(request, response);
    return response.status(400).json({ error: `unknown op ${op}` });
  } catch (trouble) {
    if (trouble instanceof AuthError) return response.status(trouble.status).json({ error: trouble.message });
    if (trouble instanceof Refusal || trouble instanceof Unacceptable || trouble instanceof BuildRefusal) {
      return response.status(trouble.status).json({ error: trouble.message });
    }
    console.error("share:", trouble.message);
    return response.status(502).json({ error: "Brickworks could not reach its storage just now. Try again in a minute." });
  }
}

// Each 5xx kept for the owner's server-errors notification (api/_noted.js).
export default noted("share", handler);
