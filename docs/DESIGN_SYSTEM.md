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
  copy. The header: Gallery · Download · Account (Sign in until you are,
  web/follow.js) · **Open the app**; on a phone the mark, the way in and
  Menu. The footer: the mark and a row of links (Compare, FAQ, Changelog,
  Source, Privacy, Terms, Guidelines, Takedown), then every notice
  docs/TRADEMARKS.md asks for, small and quiet.
- **One type scale** (`--t-display`, `--t-h1`, `--t-h2`, `--t-h3`,
  `--t-lede`, `--t-small`, `--t-tiny`): `h1` is a page's title at `--t-h1`
  on every page; the landing page's one line is `h1.display`; `h2` a
  section's. A page does not size its own titles.
- **One rhythm** (`--s-1` 4 px to `--s-7` 48 px, `--page-top` above a
  page's title, `--section` between sections).

## Tokens

The colours were already there (`--bg`, `--panel`, `--line`, `--ink`,
`--ink-soft`, `--ink-faint`, `--accent`, `--on-accent`, `--focus`,
`--radius`), redefined for `prefers-color-scheme: light`. Added for the
controls:

| Token | Value | For |
|---|---|---|
| `--field` | `--bg-soft` | the fill of every field |
| `--control-h` | 44 px | a field's and a button's height, so side by side they line up |
| `--control-radius` | 10 px | a field's and a button's corners |
| `--bad` | red, per scheme | words that say something was refused |

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
  (and any `button` with no class), quiet `button.link` (underlined words).
  `.small` (36 px) for a row of actions on a card or a list, `.big` for a
  page's opening offer; a button beside a field is the regular size. A
  toggle that is on (`aria-pressed="true"`) has the accent edge. A
  `<summary>` that opens something is `summary.cta.ghost`.
- **Dialog**: the `dialog` element (sign in and the age question in
  `web/account.js`, report it in `web/report.js`): a `--panel` card, its
  title an h2, the form, the buttons last with the primary first.
- **Card**: `.card`, a panel of words.
- **Command**: `code.cmd`, a line to type in a terminal, in a box of its
  own that wraps, so a long one (a checksum check) never runs past the
  edge of a phone. The download page puts a Copy (`.cta.ghost.small`)
  beside each; the FAQ's connector command has none.
- **Disclosure**: `details.qa`, a panel whose summary opens what only
  some people need: the FAQ's answers, the download page's first-launch
  steps and checksums.
- **Model card**: `.model` (`web/cards.js` `modelCard` draws it), the one
  card for a shared model on every page: the gallery, the landing page's
  strip, a profile, a collection, your account. In `.models` (a grid),
  `.models.compact` (more to a row, beside a rail) or `.models.row` (one
  row that scrolls inside itself, never the page). Its Tested mark is
  `.model .tested`.
- **Page**: `main.page` (or a `.wrap.page-head` first under `<main>`): the
  space above the title, an optional `.page-head` (`.eyebrow`, `h1`,
  `.lede`), then its sections. `.prose` for a page of words (the FAQ's
  width, the legal pages), narrower and quieter.
- **Empty**: `.state`, a dashed box for what has nothing yet.
- **Page index**: `.subnav`, the sections of a long page (your account):
  a rail beside them on a laptop, a row across the top on a phone that
  scrolls inside itself; the one on screen `aria-current="true"`.
- **Settings**: `.settings`, a panel of `.setting` rows, what a setting is
  (an `h3` and a line) and its control beside it, under it on a phone;
  `.wide` takes the whole row. What cannot be undone is `.setting.danger`
  and its button `.cta.ghost.danger`, in `--bad`.

## The check

`tools/web/design_flow.mjs` (preview check `[design]`) visits every page
and opens every dialog, at 390 and 1280 px, light and dark, signed out and
signed in, and fails on what a person would notice: a visible control the
browser drew its own way, controls of one kind on a page that differ from
each other (the fields in type, height, corners, border or fill; the
buttons of one size), and a page that scrolls sideways on a phone.

    node tools/web/design_flow.mjs --out=shots/design

It needs no network and no account (`tools/web/design_stand_in.mjs`
answers the API and makes the server's pages from the checkout's `api/`).
Against the site before this, it fails the age question by name.
