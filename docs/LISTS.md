# Your sets and lists: research and design

The owner (2026-11-13): people should easily make and manage lists in
the gallery, add things to them, and show off the sets they own, with a
highly intuitive interface; research the field first, then build it.

This page is that research (section 1), what we chose and why (2), where
we go further than each of them (3), what unit lists1 built and where it
lives (4), and what is left for a unit lists2, in order (5).

## 0. The short of it

- **Words.** A set is **Own** or **Want**; a gallery model is **Save**d.
  Anything else goes in **lists** of your own. "Wishlist" names the Want
  list wherever it is shared, because that is the word people give a link
  to. The app's **My collection** stays the name of the parts you own.
- **One control.** Every set card, set page, gallery model card and model
  page gets a split button: its main half sets the main state at a tap (Own
  for a set, Save for a model), and its chevron opens one panel with a box
  for every list, a How many stepper for an owned set, and **New list…**
  inline. Each box saves as it is ticked and says so, and every tap can be
  undone from its toast.
- **Privacy.** What you own is private until you choose to show it on your
  profile; the wishlist is private until you make it public; a new list is
  private. One switch per thing, never two bundled.
- **The sets you own are My collection.** Owning a set on the site adds it
  to the same collection the app's **Build › My collection…** reads, by the
  same revision rule, so its parts count as yours everywhere at once.

## 1. What the others do

Sources were the sites' own help pages and forums, read 2026-11-13 (some
blocked automated reading; those were read through search excerpts).

| Site | Words | One tap | Profile | Privacy default | Import and export |
|---|---|---|---|---|---|
| Brickset | own, want, 8 flags of your own; quantities when switched on | two checkboxes on every set row | opt-in profile; collection value from BrickLink prices; graphs by theme | private | CSV in and out (the columns changed four times; match by header) |
| Rebrickable | Set Lists, Part Lists | none: you need a Set List before you can add a set | value estimate | not stated | CSV with Set Number and Quantity in any order; 100 sets a list free |
| BrickLink | Wanted lists (Main and named), My Collection | heart opens a list picker | none | private | XML or a file in, each tab out alone |
| BrickEconomy | collections | add buttons | value and growth per collection | not stated | basic CSV |
| LEGO.com | wishlist | a heart beside Add to Bag; a picker once you have more lists | none | private, shared by link | none; 30 items in the general list; Wanted lists lost in the VIP change |
| Letterboxd | Watched, Like, Watchlist, Lists, four favourites | three icons on every poster | four favourites, stats | public | CSV in, into a new or existing list |
| Goodreads | Want to Read, Reading, Read (exclusive), shelves | a hover menu on the add button | shelves | public | CSV out with exclusive shelf, shelves, copies |
| Discogs | Collection, Wantlist, folders | add buttons | value (min, median, max) | collection public or not | CSV out |
| Steam | Wishlist with categories (2026) | Add to Wishlist with a category dropdown | showcases unlocked by level | friends only since 2018 | none; one category shared by a link you can revoke |
| Pinterest | Save, boards | Save with a predicted board | boards | public unless secret | none |
| Spotify | Liked Songs, playlists | (+) saves, a second tap opens every playlist | playlists | public playlists | none |
| Printables, MakerWorld | collections | Collect (MakerWorld 2025: straight into a default) | public collections | per collection | none |

What people hate, most to least:

1. **Saving silently to a list they did not pick**, and removing from every
   list without saying which (MakerWorld's 2025 Collect, Pinterest's
   suggested boards). People asked for the old way back.
2. **Things welded together**: Goodreads' exclusive shelves, Spotify making
   you Like a song before it can go in a playlist, Steam's one switch for
   the whole profile.
3. **A tick that does not stick, and no undo** (Spotify's 2025 sheet,
   Goodreads' accidental adds).
4. **No bulk edit, no defaults, tedious list building** (Rebrickable,
   Brickset, Letterboxd).
5. **Caps and lost data**: LEGO's 30 items, Rebrickable's 100 sets,
   Printables' 20 collections, LEGO's Wanted lists gone in a scheme change;
   and value figures that mislead (Discogs' median).

What they do well, and what we took: Brickset's two independent states
(own one, want another), Spotify's split of a one-tap main state from a
panel of every list, Steam's per-list sharing and drag ranking,
Letterboxd's profile that shows a person's taste at a glance, Pinterest's
board covers, Rebrickable's link from the sets you own to what you can
build.

## 2. What we chose, and why

**Own and Want for sets, Save for models, lists for the rest.** Own and
Want are Brickset's words, the words LEGO fans already use for sets. A
gallery model is not owned (it is a design) and "want to build" overlaps
with lists of your own, so a model is Saved, as on Pinterest and Instagram.
Lists are "lists" in the controls: the word a person would say. The
existing public "collections" of models are the same thing (one table), so
a list of yours is a collection when it is public; renaming the site's
"Collections" to "Lists" is for lists2 (section 5), because it moves pages
other units own.

**A split button, the main state at a tap.** One tap sets the state that
matters most, and it shows at once (optimistic) with the server answering
behind it; the chevron opens the panel where everything else is. The labels
never change (Own stays "Own" when pressed: the pressed state is
`aria-pressed`, a check in place of the plus, the accent edge), so a voice
user can always say the name they see. A card shows "×2" when two copies
are owned, and a dot on the chevron when the thing is in any of your lists.

**The panel saves as you tick.** Each box saves at once and says so in the
panel's status line ("In Castles."); nothing waits for a Done button
(Spotify's lost ticks). On a phone it is a sheet at the foot of the screen;
on a computer a popover by the button. **New list…** is inline: a name,
a Public box, **Make it**, and the thing goes straight in.

**Undo everywhere.** Every tap's toast carries Undo for eight seconds and
stays while the pointer or keyboard is on it. Undo puts back exactly what
that step changed and nothing else: a set taken off I own comes back with
its missing-part marks and the site that brought it, an item taken out of
a list goes back to its place and date, and a Copy or Move into a list
that already held an item leaves it there. A deleted list is removed only
when its toast goes without Undo pressed (or the page is left).

**Privacy one switch at a time.** Owned sets: off the profile until you
switch on "Show on my profile" on Your lists. Wishlist: private until you
make it public (then it is a page with a link to share, and on your
profile, never in the gallery's directory). A new list: private. A list
taken down by Brickworks is private and stays so.

**Import what people have, in the shape they have it.** Rebrickable CSV,
BrickLink XML (both already read by My collection's import) and Brickset's
CSV (by header name, `Number` plus `Variant` or a `Number` holding n-v,
never `SetID`, trailing commas allowed). A file into the sets you own
replaces what that site's file brought in before (and nothing else: a
Brickset file never touches sets from before files were marked with
their site), or adds, as you choose;
wanted rows go to the wishlist. A list of your own also takes set numbers
typed or pasted ("10497, 6080, 75192-1"). Export is one CSV, Rebrickable's
columns, so it goes straight back into Rebrickable or Brickset.

**No caps a person meets.** The limits are abuse limits (thousands of
items, hundreds of lists), never a free-tier squeeze. Every count is the
database's own (`Prefer: count=exact`), never a read's rows, since a read
stops at 1,000.

**The profile shows a collection, not a number.** A **Sets** tab with the
count of sets, parts, minifigures and themes, the theme owned most, every
set as a card, and filters by theme, decade and size, a search and an
order, all in the address so a filtered view can be linked.

## 3. Better than each

- **Brickset**: one tap on every card everywhere, not only list rows;
  undo; lists of your own that mix sets and community models; the owned
  sets feed straight into building (the app's My collection).
- **Rebrickable**: no list to make before the first set; no 100-set cap;
  the sets you own are a showcase, not a spreadsheet.
- **BrickLink**: wishlist and owned in one place with the panel; a
  shareable wishlist page.
- **BrickEconomy**: free, unlimited lists; (value is deliberately not shown
  yet, see Discogs).
- **LEGO.com**: no 30-item cap; an owned list; a wishlist people can share
  without an account scheme; nothing lost when a scheme changes (export).
- **Letterboxd**: bulk select, move and copy between lists; one panel for
  every list rather than an add flow per list.
- **Goodreads**: Own and Want are independent (own one, want another);
  undo on every tap.
- **Discogs**: no misleading median value; the collection's numbers are
  what is certain (sets, parts, minifigures, themes).
- **Steam**: each switch on its own; ordering by drag, arrow buttons for
  touch and keyboard, or by date added.
- **Pinterest, MakerWorld**: nothing ever goes into a list you did not
  tick; taking something out says which list it left.
- **Spotify**: a tick saves and says so; the same thing into many lists in
  one panel; bulk move.
- **Printables**: no collection cap; a list holds sets and models.

## 4. What lists1 built

Server (Vercel's function cap is full, so new endpoints are ops of
`/api/people` and `/api/collection`, the logic in `api/_mylists.js`):

- `supabase/lists.sql` (additive, applied to the live project 2026-11-13):
  `model_collections` gains `kind` (`list` or `want`, one want per owner),
  `sort` (`added` or `manual`), `cover`, `taken_down_at` (a taken-down list
  cannot be public); `model_collection_items.position`; new table
  `collection_sets` (a list's sets); `profile_shows.owned`; functions
  `list_items`, `list_model_cards`, `list_place`, `list_directory`
  (service role only, as every function here).
- `POST /api/collection` op `own` `{set, was, qty}`: the hand-entered copies
  of one set made `qty`, held to `was` like every other op, so two tabs
  never undo each other; a 409 answers what is owned now. Taking copies
  off remembers them whole (marks, source) with the op in `recent`, and
  putting the count back to what it was, while nothing else changed, puts
  those copies back, once (a caller with no `id` too).
- `/api/people`: `GET ?op=keeps&sets=&models=` (what you have of each, for
  the controls), `?op=lists` (Your lists' rail), `?op=list_items&id=`
  (a list a page at a time, the built-ins `owned`, `want`, `saved`),
  `?op=list_csv&id=` (download); `POST ?op=keep` `{items, list, on, from,
  back}` answers `added` (the keys this call put in) and `taken` (each
  key taken out, with its date and place), and `back` puts a taken key
  back as it was, so Undo changes only what its step changed;
  `?op=list_order` `{id, keys, sort}`, `?op=owned_choice` `{shows}`;
  `?op=collection` takes `sort` and `cover`.
- `/u/<handle>?tab=sets` (`ownedPanel`): the sets shown, with `q`, `theme`,
  `decade`, `size`, `sort`, `page` in the address.
- `/c/<id>` shows a list's sets and models; `/collections` lists public
  lists with sets too (wishlists and taken-down lists never).
- `POST /api/admin?op=list_down&id=`: Brickworks takes a reported list
  down (private, its name and words kept for the owner); the report in
  /admin › Gallery shows the list's name and words (docs/ADMIN.md).

Site:

- `web/card.js` `keepHtml`: the split control on every set card and, with
  `keep: true`, every gallery model card (`web/models.js`).
- The set page's bar, `keepBarHtml` (`api/_sets.js`): Own, Want, Add to
  a list. The page's cache is unchanged: what you have is asked after it
  loads.
- `web/keep.js`: the controls' behaviour, the panel, sign-in for a
  visitor (`askToSignIn`, then it carries on), the toast's Undo.
- `web/lists.html`, `web/lists.js`: **Your lists** (account menu): a rail
  of I own, I want, Saved and your lists (a dropdown under 900 px); a
  list's head with Share, Edit, Add sets, Download CSV; Your order or
  Newest first, drag or arrows; Select for bulk Copy, Move, Take out;
  New list; Edit (name, words, public, cover, delete with undo); Show on
  my profile for the sets you own.
- Words in German, French and Spanish (`web/_lang/`).

Proof: `tools/web/lists_flow.mjs` (preview check `[lists]`).

## 5. lists2, in order

1. **Model pages' Save uses the panel**: the model page's own Save panel
   (`web/model-page.js` `#save-panel`) becomes `keep.js`'s, Favourites
   named Saved everywhere (the tested model page markup moves with it).
2. **Rename Collections to Lists** on the site (`/collections`, the
   gallery tab, the profile tab, docs), with `/collections` redirecting.
3. **Link-only lists**: a third visibility, shared by a link that can be
   revoked, never on the profile or in the directory (Steam 2026); the
   wishlist's default when shared.
4. **I've built it**, with a build photo, as a state of a model (the
   model's page then counts real builds).
5. **"In N lists"** on a set's page, and public lists with a set on it,
   as a model's page has.
6. **Import preview**: matched, not found and already there before
   anything is written.
7. **Lists in the feed**: a set put in a followed list, as models are.
8. **Owned quantity and "can I build it" on profile and gallery cards**,
   from the parts the owned sets hold (`build with what I own`).
9. **Value**, opt-in and private by default, only when a source is
   trustworthy enough to show a range, not a median.
