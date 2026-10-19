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
- **Card**: `.card`.

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
