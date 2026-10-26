# The site's design system

brickworks.diy draws every control one way, from `web/site.css`. The owner
found it did not (2026-10-19): the age question's month was the browser's
bare dropdown, small and unstyled beside a full-size year box. Each unit
had copied the control styles it needed into its own page or into
`web/directory.css`, with small differences, and whatever a copy missed
the browser drew.

**The rule: use a component, do not copy one.** A page lays controls out
(a width, `flex: 1`, a gap); it does not restyle them. A control the system
lacks goes into `site.css` and this page, in the same commit.

This is the website only. The app (src/ui/) has its own look and is not
part of it.

**And one site, not fourteen pages (2026-10-20).** The owner: "the main nav
has too many links… the entirety of the cohesive site". Each page had its
own copy of the header (seven links) and footer (eight different ones), and
sized its own titles, from 26 to 74 px. Now:

- **The shell.** One header and one footer, written once in
  `web/_shell.html`. `python3 tools/site_shell.py` writes them into every
  page of web/ that has a site header, marking the link to the page itself
  (`aria-current`); `tests/test_site_shell.py` fails when a page's copy
  differs, or the header has more than four things. The server's pages
  (/m/, /u/, /c/) take theirs from web/gallery.html (api/_directory.js
  `siteChrome`). Edit `_shell.html`, then run the script; never a page's
  copy. The header: Gallery · Download · **Open the app** · Account (Sign
  in until you are, then your avatar: the account menu, below), the
  account last at the far right (the owner, 2026-10-23: "an obvious
  pattern"; design_flow.mjs fails a header in another order), from 600
  px, so a tablet has it too; on a phone the mark, the way in and Menu
  (your avatar, once signed in), the last 16 px from the edge as the
  page's words are, down to 320 px: where the bar has no room for the
  word, the mark is the cube alone, the word wrapped out of sight with
  no breakpoint of its own (design_flow.mjs fails a header that runs
  into the gutter at 320, 360 or 390 px). Everything in it is 44 px
  tall, a finger's: the mark, its links, Open the app (the regular
  `.cta`, 44 px at 16, not a size of its own), Menu and your avatar's
  button (2026-10-26; they were 36-42). The footer: the mark and a row
  of links (Challenge, Collections, Compare, FAQ, Changelog, Source,
  Privacy, Terms, Guidelines, Takedown), each a finger's 44 x 44 with
  its words 12 px apart (at 16 the tenth wraps the Theme choice at
  1280), then every notice docs/TRADEMARKS.md asks for, small and quiet.
- **One type scale** (`--t-display`, `--t-h1` 32-46 px, `--t-h2` 22-26
  px, `--t-h3` 18 px, `--t-lede`, then the words: `--t-body` 16,
  `--t-small` 14.5, `--t-tiny` 13, `--t-micro` 12): `h1` is a page's
  title at `--t-h1` on every page; the landing page's one line is
  `h1.display`; `h2` a section's, at `--t-h2` wherever it is (a model's
  About it and More by, a settings row, a notice, a dialog's title, a
  legal page's parts); `h3` a part of a section, at `--t-h3`. A page
  does not size its own titles, and design_flow.mjs fails an h2 or an
  h3 drawn at any other size. There were three sizes of h2 and four of
  h3 (2026-10-26), and `--t-h2` was 23-30 px: one size for every section
  head made it 22-26, so a settings row or a dialog is not shouting.
- **One rhythm** (`--s-1` 4 px to `--s-7` 48 px, `--page-top` above a
  page's title, `--section` between sections).
- **Four breakpoints** (2026-10-26): **600, 900, 1200 and 1600 px**, and
  no others, in `site.css`, `directory.css` and a page's own `<style>`.
  Under 600 is a phone, 600 to 900 a tablet, 900 to 1200 a laptop, 1200
  to 1600 a desktop, 1600 and over a wide one. Written in the range form,
  `@media (width < 600px)` and `@media (width >= 600px)`, so a query and
  its opposite name the same number. There were 13 (389, 480, 520, 599,
  620, 640, 700, 860, 1100 and the four), each a unit's guess at its own
  page; a layout that needs another width is made fluid instead.

## Themes

Dark, and light (2026-10-22, the owner: "a light color theme as an option
so user can choose between dark/light"). The person chooses System, Light
or Dark in the footer of every page, on Menu at a phone's width and in
Settings; System, the default, follows the computer. `web/theme.js`, in
every page's `<head>` before the stylesheet, sets `<html data-theme>` from
the choice kept in the browser before anything is drawn, and the two
`theme-color` lines so the browser's bar is the page's colour. The light
set in `site.css` is written twice, under `:root[data-theme="light"]` and,
with no choice, `prefers-color-scheme: light`; `tests/test_site_contrast.py`
fails if they differ, and measures every text token on every surface
(4.5:1) and the state edges (3:1) in both. Never a colour outside the
tokens: a page that needs one adds a token.

## Tokens

The colours (`--bg`, `--bg-soft`, `--panel`, `--panel-hi`, `--line`,
`--ink`, `--ink-soft`, `--ink-faint`, `--accent`, `--on-accent`,
`--focus`, `--bad`, `--green`), each with its light value. And:

| Token | Value | For |
|---|---|---|
| `--accent-edge` | the yellow; `#a67c00` in light | an edge that marks a state: a pressed toggle, the New pill, the older-version box, a checkbox. The yellow is 1.33:1 on the light pages; a yellow button keeps the yellow |
| `--brick-red`, `-yellow`, `-blue`, `-green` | the bricks' colours, both themes | the 404's wall |
| `--field` | `--bg-soft` | the fill of every field |
| `--control-h` | 44 px | a field's and a button's height, so side by side they line up |
| `--r-1`, `--r-2`, `--r-3`, `--r-pill` | 6, 10, 14, 999 px | corners: small (a chip, a code box), a control's, a card's or panel's, a pill's; a circle is 50% |
| `--control-radius`, `--radius` | `--r-2`, `--r-3` | a control's corners, a card's |
| `--t-code` | 0.92em | code in a line of words: a monospace face looks larger at one size |
| `--shade`, `--shine` | dark and light, see-through | a brick's lower edge and top: the 404's wall, a colour's dot |
| `--scrim` | black, 55% | the dim behind an open dialog |
| `--avatar-1` … `-8`, `--on-avatar` | eight tiles, white | an avatar made from a handle, its letter 5.37:1 or more on each |
| `--motion`, `--motion-open`, `--ease` | 150 ms, 180 ms, an ease-out | a control answering the pointer; a dialog or menu opening ("Motion") |
| `--head-h` | 61 px | the header's height, which `main` fills the window under ("Steady loads") |

**Only the scale (2026-10-22).** Every font size is a `--t-*`, every corner
an `--r-*` (`--radius`, `--control-radius`), `0` or `50%`, and every colour
a token, in `site.css`, `directory.css`, a page's own `<style>` and a
`style=""`. There were 33 sizes and 16 corners for 7 and 2 tokens.
`design_flow.mjs` names any rule off the scale; a page that needs a colour
adds a token to `:root`, and only `:root` makes one. And **a count is
said once there is one**: never "0 likes" or "following 0" (a card, a
model's page, a profile, your account); a count that a press can make one
is on the page, `hidden`, for the script to show.

## Components

- **Field**: every `input` (text, email, search, number, url, file),
  `select` and `textarea`, styled by element at zero specificity
  (`:where`), so none is left to the browser and a page can still size one.
  16 px type, `--control-h`, `--control-radius`, a 1 px `--line` border,
  the `--field` fill. A **dropdown** is the same box with its own arrow in
  the page's ink; a required one's hidden first choice ("Month") shows in
  `--ink-soft` until one is made. A **file picker** is the box, its button
  drawn as a secondary one.
- **Field label**: in a `form`, a `label` holds its words above its field;
  `small` inside it for the quieter part.
- **Date**: dropdowns, never the browser's date box (which draws itself,
  and differently in every browser). A date of birth is month and year
  (the age question's `dialog .when`); a day is `fieldset.date`, its words
  the legend, then day, month and year side by side in `.dropdowns`
  (/admin's challenge days).
- **Checkbox and radio**: the browser's own, 18 px, in `--accent`. With its
  words: `label.choice` (or `.tick`).
- **Buttons**: primary `.cta` (yellow, the way in), secondary `.cta.ghost`
  (and any `button` with no class), quiet `button.link` (underlined words;
  `a.link` for one that goes somewhere, as the embed's View in 3D).
  `.small` (36 px) for a row of actions on a card or a list, `.big` for a
  page's opening offer; a button beside a field is the regular size. A
  toggle that is on (`aria-pressed="true"`) has the accent edge. A
  `<summary>` that opens something is `summary.cta.ghost`.
- **Sign in with orangecheck**: our own `.cta.ghost` with `data-oc-sign-in`
  and a `<span data-oc-mark>` holding its mark's place, made orangecheck's
  by its own code (`web/oc-button.mjs`, `account.js` `orangecheckButton`):
  its mark in the button's ink before the words, its busy state, its window
  opened from the click. `web/oc-button.css` is orangecheck's too, at zero
  specificity, so every rule here wins; it holds the mark's size and the
  44 px target `--control-h` gives every button already. Under it in the
  sign-in dialog, orangecheck Connect's box (`dialog .consent`): a
  `label.choice`, never ticked but by the person, and orangecheck's own
  words, label and line, exactly as `web/oc-connect-consent.mjs` gives them.
- **Dialog**: the `dialog` element (sign in and the age question in
  `web/account.js`, report it in `web/report.js`): a `--panel` card, its
  title an h2 that names it (`aria-labelledby`), the form, the buttons
  last with the primary first. Opened with `showModal()`; `web/kit.js`
  keeps the keyboard in it (Tab from the last control comes round to the
  first) and, closed, gives the focus back to what opened it, or to the
  More menu's button when what opened it was folded away with the menu.
- **Card**: `.card`, a panel of words.
- **Table**: `.table`, a `<table>` of facts in a box that scrolls inside
  itself where the table is wider than the page, never the page: a named
  region the keyboard reaches and scrolls (`role="region"`, its
  `aria-label` or `aria-labelledby`, `tabindex="0"`). Each row's name is
  its `th scope="row"`; a number is `.n`, right-aligned in even figures.
  `.table.wide` is many columns, /compare's field: each at least 130 px,
  its headings in the ink, and each row's name kept in view on the page's
  ground while the rest scrolls past it on a phone. The FAQ's dimensions
  and /compare's field (2026-10-24, from the FAQ's own copy); /admin's
  tables still carry theirs.
- **Command**: `code.cmd`, a line to type in a terminal, in a box of its
  own that wraps, so a long one (a checksum check) never runs past the
  edge of a phone. The download page puts a Copy (`.cta.ghost.small`)
  beside each; the FAQ's connector command has none.
- **Disclosure**: `details.qa`, a panel whose summary opens what only
  some people need: the FAQ's answers, the download page's first-launch
  steps and checksums.
- **Model card**: `.model`, the one card for a shared model on every page:
  the gallery, the landing page's strip, a profile, a collection, a model's
  remixes, your account. One renderer, `web/card.js` `cardHtml`, a pure
  string function: the server's pages draw with it (through
  `api/_card.js`, which `tools/deploy.sh` replaces with the file itself)
  and the browser with `modelCard`, the same string parsed, so the two are
  the same markup (`tools/web/card_check.mjs` proves it). Its picture is
  4:3, the middle of the 1200 x 630 one by `object-fit: cover`
  (docs/SOCIAL.md D3), with its marks over the top corner (`.marks`: the
  Tested `.pill.good`, and `.pill.made` Assistant or Brickify, read from
  its tags). It is an `article`: its name (`a.open`) is the one link to the
  model, stretched over the whole card, so the designer's name and a like
  sit inside it as a link and a button of their own. Under the name, `.by`:
  the designer's `.small` avatar and name (`a.who`, to their page) and its
  size; then `.acts`, its numbers last, each an icon and a count and none
  at nought: the like (an `.icon-btn.small`, `aria-pressed`, when the page
  passes `like: true`, as the gallery does; a `.tally` elsewhere), builds
  finished and comments. In `.models` (a grid: two to a row on a phone,
  three from 900 px, four from 1200), `.models.compact` (more to a row,
  beside a rail), `.models.wide` (fewer, one to a row on a phone, for cards
  that carry a button under them) or `.models.row` (one row that scrolls
  inside itself, never the page).
- **Page**: `main.page` (or a `.wrap.page-head` first under `<main>`): the
  space above the title, an optional `.page-head` (`.eyebrow`, `h1`,
  `.lede`), then its sections. `.prose` for a page of words (the FAQ's
  width, the legal pages), narrower and quieter.
- **Empty**: `.state`, a dashed box for what has nothing yet.
- **Segmented**: `.segmented`, a few buttons in a row, the chosen one
  `aria-pressed="true"` and edged in `--accent-edge`, as tall as a field
  (its buttons 36 px); under 600 px its buttons are a finger's 44.
  The theme (`[data-theme-choice]`: System, Light, Dark), with its word in
  `.theme-choice`; any `[data-theme-choice]` button works with no script of
  the page's own.
- **Pill**: `.pill`, a fact, a tag or a mark, small and round. A link or a
  button pill (`a.pill`, `button.pill`, `summary.pill`) is a finger's
  height, 32 px, and takes the pointer's edge. `.good` green (Tested),
  `.new` edged in `--accent-edge`, `.tag` says "#" first, `small` inside
  for a quieter part (a handle). A row of them is `ul.pills` or
  `div.pills`; `.pills.row` keeps them on one line that scrolls inside
  itself (the gallery's kinds), and a chosen button pill is
  `aria-pressed="true"`, edged in `--accent-edge`. The one pill: a model's facts and tags, its Tested mark,
  the gallery's tag filter, a comment's Designer and its step, the feed's New,
  whom you follow on your account. There were seven copies.
- **Tabs**: `.tabs`, a row of links or buttons, the one shown
  `aria-current="page"` (or `aria-selected` in a tablist), underlined in
  `--accent-edge`, a count in `.n`; on a phone the row scrolls inside
  itself. For the gallery's Top · New · Following and a profile's Models
  · Builds · Collections (docs/SOCIAL.md U3, U5).
- **Avatar**: `.avatar`, a person's picture or one made from their handle
  (`web/kit.js` `avatarHtml`: a round tile in one of eight colours, the
  same for a handle on every page, and the first letter of their name;
  never a figure's likeness, docs/TRADEMARKS.md). Sizes `.small` 24
  (a byline), 40, `.big` 64 (your account), `.huge` 112 (a profile; 80 under 600 px). It is
  decoration beside the name, so `aria-hidden`. A person's own picture
  (`.avatar.pictured`, supabase/avatars.sql) fills the same circle over its
  tile, and only this site's address for one is drawn. **Cropper**:
  `.cropper` in `dialog.crop-dialog` (`web/picture.js`), the picture chosen
  on a square canvas with the circle it is cut to, dragged and zoomed, the
  zoom two `.icon-btn`s (zoom-out, zoom-in) under it.
- **Icon**: `.icon`, one of the sprite's (`web/icons.svg`: like, save,
  share, comment, more, build, search, filter, award, zoom-in, zoom-out;
  `web/kit.js` `iconHtml`),
  drawn in the words' colour. **Icon button**: `.icon-btn` (`iconButtonHtml`), round,
  as tall as a field (`.small` 36 for a card's row), its count beside its
  icon once there is one. `.labelled` (`iconButtonHtml({ labelled: true })`)
  says a word for it too, between the icon and the count (`word`, its
  name unless said, and in its label): a model's Like and I built it
  ("Built"), which nobody reads from a glyph alone; on a phone (600 px and
  under) the row of six has room for icons and counts only, and the word
  is hidden there. Its label says its name and count to a screen
  reader ("Like, 12 likes"; "Like" at none); a toggle is `aria-pressed`,
  and pressed is edged in `--accent-edge` with its icon filled. A button
  that opens something rather than toggling (Save, which opens your
  lists) is `aria-expanded`, and `data-on` while what it stands for is on
  (the model is in one of your lists), drawn as pressed. The server's
  pages draw the kit from the same file: `web/card.js` makes the avatar,
  the icons and the icon button (`web/kit.js` passes them on to the
  browser's pages), and the server imports them through `api/_card.js`,
  which `tools/deploy.sh` replaces with `web/card.js` itself.
- **Action bar**: `.action-bar`, a model's page's row of icon buttons
  (Like, Save, Share, Comment, I built it) with the more menu at its end;
  one row across the column on a phone. `api/share.js` `actionBar`,
  `web/model-page.js`.
- **Share's sheet** (docs/SOCIAL.md U14): `dialog.share-sheet`, the site's
  dialog made wider for the embed code, opened by Share: the page's link
  (selected as it opens) and the embed code, each a field in a `.copy-row`
  with its Copy beside it (under it on a phone), Copy link the primary;
  what was copied said in the sheet's own `.said` status line, since the
  toast is behind a modal dialog for a screen reader too; Share with
  another app (the phone's own sheet, given the link) only where the
  browser has one; Close, and Escape, back on Share. `api/share.js`
  `shareSheet`, `web/model-page.js`. The embed (`/m/<id>/embed`) loads
  `web/theme.js` as every page does, so it is in the theme its viewer chose
  where their browser lets a frame read the site's own storage, else their
  device's; `<html data-embed>`, so it never asks their account. Its
  picture, then a bar: the name and credit (a link to the model's page),
  View in 3D as an `a.link` (hidden under 400 px, where the bar has no room
  for it), and Build it, `.cta.small`, the guided build at step 1 as the
  model's page's is; each opens a tab of its own.
- **A model's page** (`/m/<id>`, `web/directory.css`, docs/SOCIAL.md U4):
  `.media`, the picture and under it `.media-strip`, a row of thumbnails
  that scrolls inside itself, the one shown large `aria-current` and edged
  in `--accent-edge`; `.side`, the column that stays beside it on a laptop;
  and `.page-tabs`, the kit's `.tabs` as links to the parts of the page,
  sticky under the header, with a ground of its own only once stuck. The
  Its Parts (`.parts`, docs/SOCIAL.md, site278): the count in a `.note` ("N parts in M lots"),
  `.parts-bar` (a `.segmented` Colour · Kind, then the shops' lists as
  `.cta.ghost.small` links that download), and `ul.lot-list`, a row a
  colour or kind (`li.group`: its swatch, name and count) over a row a lot
  (`li.lot`: `.pic`, its 48 px picture on `--picture-ground`; `.what`, the
  name and `.meta`, number and colour, each one line that ends in an
  ellipsis; `.qty`), every row 60 px so the space the list takes is kept
  before it comes; a colour's swatch is an inline `svg.swatch` filled with
  the brick's own colour, which is the model's, not the site's. Download is
  a `.cta.ghost` in the column's actions: Build it across the column, Open
  in Brickworks and Download sharing the row under it. The
  public collections it is in (docs/SOCIAL.md U11) are a fact `a.pill`
  ("In 2 collections"), a tab and `.in-lists`, a `.list-cards` of their
  covers, each saying whose; none of the three while it is in none. Its
  comments (docs/SOCIAL.md U8) are threads: each comment a `--panel` card
  with its writer's 40 px avatar beside it, Designer (`.pill`) on the
  owner's and its step as `a.pill`, then `.replies` under a 2 px `--line`
  rule, each reply with the `.small` avatar and no card of its own, and a
  reply's box (`form.reply-new`, a field and `.cta.small` with
  `.cta.ghost.small` Cancel) under the thread.
- **Toast**: `web/kit.js` `toast("Link copied")`: one line at the foot of
  the screen, in the page's colours the other way round, read out
  (`role="status"`, on the page empty from its load, since a screen
  reader reads a region's change and not a region that arrives already
  speaking), gone in 2.4 s.
- **More menu**: `details.more-menu`, an `.icon-btn` summary with the
  more icon and the header Menu's `.menu-list` panel of links and
  buttons (Report it, Takedown requests), opening along the row from the
  button's start (`.end`: back from its end, at a row's end). It opens with no script;
  `web/kit.js` closes it on a click elsewhere and on Escape. The gallery's
  Filters is one too, its summary a `summary.pill` with the filter icon
  and how many are on, its panel the fields of a search.
- **A person's page** (`/u/<handle>`, `web/directory.css`, docs/SOCIAL.md
  U5): the head (`.profile-head`: a `.huge` avatar, the name, the handle,
  Follow, Share and More; on your own page Edit profile where Follow
  would be), `.numbers` (one row of counts, each `<b>` and
  its word, hidden at none), `.pinned` (a `.models.row`), the `.tabs`, and
  two cards of its own: `.list-card` (a collection, its cover) and
  `.build-grid` (photos of builds in columns, any shape).
- **A collection's cover**: `.mosaic` (`api/_lists.js` `mosaicHtml`), up
  to four of its models' pictures kept wide (one whole, two one over the
  other, three a wide one over two), 4:3 whatever its pictures' own shape,
  "No pictures yet" with none. On a `.list-card` and at the head of a
  collection's page.
- **A collection's page** (`/c/<id>`, `api/people.js` `listPage`,
  docs/SOCIAL.md U11), headed as a playlist's or a board's: `.list-head`,
  its `.cover` beside `.who` (the `.eyebrow`, the name, whose and when in
  `.handle`, its words, `.numbers`: models and followers, each hidden at
  none) and `.acts` (Follow as on a person's page, `.cta.ghost.follow`
  with `data-follow-list`, its words in `.said`; Share; More with Report
  it); on a phone the cover across the top at 2:1. Then its models as
  `.models`, or a `.state`.
- **Achievements** (`web/card.js` `awardsHtml`, docs/SOCIAL.md U13):
  `ul.pills.awards` after a person's `.numbers`, the two in one
  `.standing` row that wraps (beside them on a laptop, under them on a
  phone), on their page and on your own, each `li[data-award]` a `.pill` with the award icon (16 px, at its
  words' height) and its name,
  what it means as its title; a challenge won is `a.pill.new` to the model
  that won it. The rarest first; none at all, no row.
- **A challenge, between months** (`/challenge`, docs/SOCIAL.md U12):
  under the one shown, Coming next (`#next`, a `.card` of its theme and
  days) and Past challenges (`#past`, each an `article.past-one`: its name
  a link to its own page, its days, its winners as `.models` cards); its own
  page (`?id=N`) is the same page under the `.crumbs` back to the hub.
- **Your profile** (`/profile`, `web/profile.html`, docs/SOCIAL.md U6):
  your page as a person's page draws it (the same `.profile-head`,
  `.numbers`, `.pinned` and `.tabs`), with Edit profile, Settings, Share
  and More in its head; the tabs Models · Builds as everybody sees them,
  then Saved · Sets · Insights, which only you see, each a `?tab=` of its
  own. Edit profile is a `dialog` of the site's fields; signed in with no
  profile, the same form is in the page with its two fields, name and
  handle. `/settings` is one `.settings` panel: Profile, Appearance, Email,
  Privacy, Claude, Sign out, Delete account.
- **The account menu** (`web/follow.js`, docs/SOCIAL.md U7): signed in,
  your avatar in the header (`summary.account-btn`, 36 px) with what is
  new for you as the header's `.count` over its corner, opening a
  `details.more-menu.end.account-menu` with the header Menu's panel: who
  you are (`.menu-who`), your places (`.account-part nav`: Your profile,
  Notifications and Your feed each with its `.count`, Saved, Settings),
  the theme and Sign out (`.menu-list > .sign-out`). At a phone's width
  Menu's summary is the avatar and its panel holds the site's links, then
  the same. Open, the avatar is ringed in `--accent-edge`.
- **Notifications** (`/notifications`, `web/directory.css`): `.notices`,
  a list of `.notice` cards, one a model: its 4:3 `.pic`, its name as an
  `h2` at `--t-body`, and `.lines`, each a link with an avatar (who did
  it) or an icon (likes, a challenge's end), `.what` its words, a New
  `.pill`, a quote and the time. Not opened yet: `.unread`, edged in
  `--accent-edge` with a `.dot`. The page's head is `.notices-head` (the
  title and Mark all read); `/notifications` and `/feed` share one `.tabs`
  row, each tab's count in `.n`, hidden at none.
- **The feed** (`/feed`, `web/directory.css`, docs/SOCIAL.md U9): a
  column of posts (`.feed-list`, 600 px at most), each a `.feed-row`: its
  `.post-head` (the avatar, `.what` the sentence with who and the thing's
  name as links and a New `.pill`, then the `time`), what they said as a
  `q`, then the thing: the model's card (`.model`, the one renderer) or
  `.feed-photo`, the photo of a build in a panel with its model under it.
  `.feed-rail`, a panel of designers to follow (`.people-list`, each a
  `.person-row`: avatar, name and their best models, Follow as
  `.cta.ghost.small`), beside the posts from 1100 px and under them on a
  phone; Latest on Brickworks (`.latest`: the gallery's `.models` and a
  `.build-grid`) after it when the feed has nothing of its own, its empty
  state a `.state` saying why (signed out, with Sign in; following nobody;
  nothing in 90 days).
- **A person to follow**: `.person-row` in a `.people-list` (`site.css`,
  so any page's dialog has it): the avatar (`.face`), the name and their
  best models (`.names`), Follow as `.cta.ghost.small`, and what Follow
  said under them (`.said`). The feed's designers and First steps.
- **First steps** (`web/first-steps.js`, docs/SOCIAL.md U10): after a
  first sign-in, the site's `dialog` made wider (`dialog.first-steps`),
  its step counted in the `.eyebrow`, one step at a time: the profile's
  two fields under a `.big` avatar made from the handle (`.face-row`),
  the gallery's kinds as button pills, then a `.people-list` and six
  cards (three to a row, two on a phone). The primary button first, Skip
  as a secondary one.
- **The kit page**: `web/_kit.html` (at `/_kit` when the checkout is
  served, never published: `tools/site.py` leaves out a name that starts
  with "_") shows every component once, drawn by `web/kit.js` and
  `web/card.js`, so `design_flow.mjs` judges what no page uses yet.
- **Settings**: `.settings`, a panel of `.setting` rows, what a setting is
  (an `h2` under the page's `h1`, and a line) and its control beside it, under it on a phone;
  `.wide` takes the whole row. What cannot be undone is `.setting.danger`
  and its button `.cta.ghost.danger`, in `--bad`.

## Motion

Every control and card answers the pointer (site275, 2026-10-26; site273
found two transitions on the whole site, both the toast's). All of it is
in `site.css` "motion", by kind, so a page adds none of its own:

- **Ease, not snap**: `.cta`, any `button`, `.icon-btn`, `.pill`, a tab,
  a `.segmented` button, the header's links and Menu, a menu's items, the
  footer's links, a field, `.model`, `.list-card`, `details.qa` and a
  strip's thumbnail change colour, ground, edge, shadow, transform and
  brightness over `--motion` (150 ms) on `--ease`.
- **A press sinks**: `:active` scales a button, an icon button, a button
  pill, a segmented button and Menu to 0.97 (a primary one a shade darker
  too), a card to 0.99; a tab and a menu's item take the panel's ground.
  For a finger as much as a mouse: a phone shows no hover.
- **A card lifts** 2 px under a mouse (`@media (hover: hover)`), never
  under a finger, where a hover sticks.
- **Opening**: a `dialog` rises and fades in over `--motion-open` (180 ms),
  its backdrop fades; a menu (`details[open] > .menu-list`: Menu, More,
  the account menu, Filters) drops 4 px and fades in.
- **Drawn at once**: a press that marks something (a card's like, a
  model's Like, Follow) is drawn as pressed when it is pressed, then as the
  server says; if the server refuses, it is drawn back as it was and says
  why (`.marks-said`, Follow's `.said`, the toast on a card).

## Steady loads

Nothing moves once it is drawn (site275; site273 measured layout shifts of
0.12 to 1.17 on 13 of 24 page states). The check: CLS under 0.02 at load
and after scrolling, every page at 390 and 1280 px.

- **`main` fills the window** under the header (`--head-h`), so the
  footer starts at the window's foot on a short page and never comes into
  view while a page's script is still drawing.
- **A skeleton holds a script's place** (`.skeleton`): what a script draws
  from an answer is in its place at about its size before the answer, as
  the site's own panels and cards with `.bone` bars in `--panel-hi`,
  breathing slowly. A card's is `.skeleton-card` (`web/card.js`
  `skeletonHtml`, the same markup in a page's HTML), not a `.model`, so
  nothing that counts cards counts it. When the answer comes the skeleton
  is taken out whole and what came put in, in one frame: new, not moved.
  The gallery's first three rows, the landing page's strip, /profile (its
  head, tabs and cards; a tab drawn the first time), /settings (its
  panel), /feed (posts and the rail) and /notifications.
- **Drawn whole**: a page whose parts come from several answers (the
  gallery's cards, pick and challenge line; Settings' rows; your profile)
  waits for all of them and draws them together, rather than each as it
  came, each moving the others. What comes with them goes where it moves
  nothing: the gallery's challenge line is the grid's first row
  (`#feed > #challenge-line`), not a line over it, and a part the script
  only hides or shows is drawn at load as it will be (the gallery's
  filter count and tag chips start `hidden`; a model's "I built it" box
  starts shown).
- **Held, then drawn**: a model page's comments are asked after it loads;
  until then `#comments-hold` (`directory.css .comments-hold`, bones) holds
  their place at the height of a section with none yet and the box, and
  goes in the frame they are drawn in.
- **Signed in at once**: a page that is yours (/profile, /settings, /feed,
  /notifications) knows from the session kept in this browser that you
  are signed in, so it never says "Looking for your sign-in…" while it
  asks; it shows your page's skeleton.
- **Under, not over**: what only one person sees on a page every visitor
  shares (a designer's own numbers on their /u/ page) is put under the
  page's work, where its coming moves nothing in view; or over what is
  there (a model's owner's Add a picture, `.on-picture`, on the picture's
  corner while it has no strip of pictures, where a strip shown for it
  alone pushed the page down).
- **Pictures**: every `img` has `width` and `height`. The first screen's
  are asked at once and first (`loading="eager" fetchpriority="high"`:
  `cardHtml`'s `eager`, the first `FIRST_SCREEN` (8) of a list; a pinned
  row; the landing page's first feature; a collection's cover and the
  first four collection cards, `mosaicHtml`'s and `listCardHtml`'s
  `eager`; the first five of a model's strip); the rest are
  `loading="lazy"`.

## Accessibility

Every page is for a person on the keyboard alone and a person with a
screen reader too (docs/COMPETITIVE.md item 14, 2026-10-23). What the kit
does for every page, so a page need not:

- **Focus is never lost.** A button disabled while what it asked is done
  (Like, Follow, Send) loses the keyboard's focus to the page's body in
  the browser; `web/kit.js` gives it back once it is enabled again. What a
  press redraws (a comment's thread, your lists under Save) puts the focus
  back on the same control, and what a press takes away (Cancel a reply,
  Mark all read) puts it on what is left: Reply, the page's title.
- **Escape closes** a More menu, your lists under Save and a reply's box,
  back on the button that opened them, as it closes a dialog.
- **Names**: an icon button says its name and count; a card's like says
  which model ("Like Riverside Watchtower, 96 likes"); a comment's Reply
  says whose ("Reply to Jo Lindqvist"). A table that scrolls sideways is a
  named region the keyboard can reach and scroll.
- **Targets**: every link and button 24 px at least (a card's name too);
  everything in the header and the footer 44 x 44 (the footer's links
  pad out to it); a link on a line of its own (a crumb, Older versions,
  a designer's name on a card or in a list, Version 1) 30-32 px, by
  padding that does not move the words (`site.css` "Targets"). A
  checkbox's target is its `label.choice`, which ticks it.
- **Reduced motion**: nothing moves. Every transition and animation is
  0 s (a skeleton does not breathe, a dialog does not fade, a card does not
  lift, a press does not sink), the toast does not slide, and the page
  does not scroll smoothly.

`tools/web/a11y_flow.mjs` (preview check `[a11y]`) runs axe-core
(`tools/web/axe-core`, vendored) on every page and state `[design]`
visits (`tools/web/site_pages.mjs`, one list for both) and fails on a
serious or critical finding; and it reads every control's name from the
browser's accessibility tree, failing on one that says nothing (none, a
bare number, a picture's file) and on a key page whose controls are not
there by name. `tools/web/keyboard_flow.mjs` (`[keyboard]`) does what
people come for with Tab, Enter and Escape alone, judging every stop's
focus ring.

What is left. Before this, axe made 246 serious findings on 58 of the
356 pages and states: 240 a card's name, a 20 px target on a phone; 2
/admin's tables, out of the keyboard's reach; and 4 a button under the
pointer, whose brighter hover axe cannot read (the check now moves the
pointer away). After, none; and of the moderate ones:

- **The embed** (`/m/<id>/embed`) has no `h1`, axe's one moderate
  finding: it is a card inside somebody else's page, a few links, and their
  page has the heading.
- **The app** (`/app`) draws its controls on a canvas: a screen reader
  reaches it only through the engine's own accessibility (Godot's
  AccessKit), which is item 14's other half and not the site's.

## The check

`tools/web/design_flow.mjs` (preview check `[design]`) visits every page
and opens every dialog, at 390 and 1280 px, light and dark, signed out and
signed in, and fails on what a person would notice: a visible control the
browser drew its own way, controls of one kind on a page that differ from
each other (the fields in type, height, corners, border or fill; the
buttons of one size), a page that scrolls sideways on a phone, a count of
none shown ("0 likes"), an h2 or h3 drawn off `--t-h2` or `--t-h3`
(2026-10-26: red on a planted `.prose h2` at the h3's size), and any
rule in the page's stylesheets, its own style or a `style=""` with a font size, corner or colour off the scale
(named once, with its stylesheet). Against the site before the kit
(2026-10-22) it named 178 such rules (123 sizes, 43 corners, 12 colours or
fonts) and a quiet model's "0 remixes"; after, none.

    node tools/web/design_flow.mjs --out=shots/design

It needs no network and no account (`tools/web/design_stand_in.mjs`
answers the API and makes the server's pages from the checkout's `api/`).
`tools/web/theme_flow.mjs` (preview check `[theme]`) chooses each theme on
every kind of page at both widths, and fails on a reload, a theme not kept
across a reload or a new tab, or a single frame of a load in the other
theme.
Against the site before this, it fails the age question by name.
