# The docs, audited and planned

Written 2026-11-09 by docshots against local `pre261` at `804c14443`.

The owner, 11-09: "a comprehensive docs update including improving the docs
quality and including images in it and having an iterative process
established such that you keep it updated as we keep on building".

brickworks.diy/docs is 41 pages written by hand in `docs-site/`, one page
made for each of the 11 AI apps in `assets/assistants.json`, and 77 tool
docs. `tools/docs_site.py` builds them and `--check` already fails on a
feature in the feature map that no page covers, on a page naming a feature
the map no longer has, and on a link that goes nowhere. Before this unit
there were 11 pictures on the pages, all taken by hand between 10-13 and
10-29 for the landing page, and none made from the app as it is.

This file says what each page is for, what is wrong with it, what pictures
it needs, and how the pictures are kept current. Then it splits the
rewrite into six units of 5 to 8 pages that share no file.

## What the best docs do

Researched on 11-09, each page fetched that day.

**BrickLink Studio** is the closest competitor
([Build mode interface](https://studiohelp.bricklink.com/hc/en-us/articles/5406574588823-Build-mode-interface),
[Managing steps](https://studiohelp.bricklink.com/hc/en-us/articles/7332196059799-Managing-steps)).
Its task pages run 180 to 340 words, open with the action ("To create a
step, click + Add Step"), and end with related articles. The interface page
has one full-window picture with lettered callouts keyed to a list. Its
faults are ours to avoid: alt text is the file name, keys are written three
ways ("Ctrl T", **R**, "Model | Create Step"), and old pictures stay on the
page under "version 2.24 and earlier".

**Onshape** ([Extrude](https://cad.onshape.com/help/Content/extrude.htm),
[shortcut keys](https://cad.onshape.com/help/Content/shortcut_keys.htm))
opens each tool's page with a one-line summary, then the key, then the
platforms it runs on, then numbered steps. Its pictures are crops of the
dialog or a small close-up of the model, about 22 KB each, with alt text
that says the act ("Clicking the Mate connector in the Extrude dialog").
Every dialog's help button opens its own page.

**Figma** ([auto layout properties](https://help.figma.com/hc/en-us/articles/360040451373-Explore-auto-layout-properties))
crops pictures to the panel and draws the cursor in. Its orientation
pictures are wireframes with lettered markers, which stay true when the
details change. Each page says who can use the feature first.

**Linear** ([Creating issues](https://linear.app/docs/creating-issues),
[llms.txt](https://linear.app/llms.txt)) titles a page with the noun the UI
uses, gives a one-sentence definition, then imperative headings ("Create
recurring issues"). About three pictures a page, each cropped to the
dialog, captioned, lazy after the first, with a zoom button. Every page has
a Markdown twin for assistants.

**The Blender manual** ([Extrude Faces](https://docs.blender.org/manual/en/latest/modeling/meshes/editing/face/extrude_faces.html),
[its markup guide](https://docs.blender.org/manual/en/4.3/contribute/guides/markup_guide.html))
puts a Reference box at the top of a tool's page (mode, menu path,
shortcut). Its capture guide fixes the theme, the zoom and the margin, and
asks for few pictures because each one costs upkeep. Keys are keycaps.

**Keeping pictures current.** GitLab writes each docs screenshot as a test
([its style guide](https://docs.gitlab.com/development/documentation/styleguide/images_and_diagrams/),
[the issue](https://gitlab.com/gitlab-org/gitlab/-/issues/14146)): visit,
find, crop to the element with padding, at most 1000 x 500 and 100 KB.
Datasette lists every shot in one file ([shot-scraper](https://simonwillison.net/2022/Oct/14/automating-screenshots/)):
the address, a selector, padding and the script that sets the state up,
and a job makes them all again.

### What Brickworks takes from them

1. Every picture is declared and made by a command from the real app, never
   taken by hand (GitLab, Datasette). Done here: `tools/docs_shots.py`.
2. Crop to the panel, dialog or menu the words are about. One whole-window
   picture with numbered marks for orientation, on the first-model page
   (Linear, Onshape, BrickLink). The marks are drawn from the controls'
   own rectangles at capture, so they cannot drift (Figma's markers, kept
   true by construction).
3. A page opens with what the feature is in one sentence, then where it is:
   the menu path and the key, in a line (Blender's Reference box, Onshape).
4. Headings are what a person does: "Put a part down", "Save a booklet as
   a PDF" (Linear, Studio). Reference tables go at the end.
5. Alt text says what the picture shows and in what state, under 320
   characters; a caption says why it is there in one line (Figma; Studio
   and Blender show the failure).
6. Keys are the app's own, written as keycaps from the keymap (Blender);
   the shortcuts and menus pages are made from the app already.
7. Pictures are lazy, at their own size, never stretched, and open whole
   on a click (Linear). The site's pictures come in both themes and only
   the page's theme's is fetched.
8. Few pictures, each earning its place (Blender): two or three a task
   page, none on a reference page.
9. No GIFs. Motion, when it matters, is a before-and-after pair (Blender).
10. What changed lives in the changelog, which links to the page; a page
    shows the app as it is now, never "in version X and earlier" (Linear;
    Studio shows the cost).

## The house rules for a page

- **The web app is the app.** The desktop app is "coming soon": no page
  tells a person to use it for something they can do today, and a
  desktop-only feature says so once, in a note, not in the steps.
- **Open with the job.** The first line is what the feature is for; the
  second is where it is (menu path, key). Then the task, in numbered steps
  where order matters.
- **Assistants in their own place.** What a session does with a tool goes
  in the page head (`ai:`, `rules:`) and the tool docs, not in the middle of
  a person's steps. A line pointing at the tool is enough.
- **Length.** A task page under about 900 words. A page past 1,500 is two
  pages.
- **A picture a task**, where the screen is not obvious from the words.

## The pages, ranked

Ranked by how often a builder comes to each, from the auditors' reading
and the app's own paths (first visit, the bin, the selection, the view,
the booklet, the files). The top ten got their pictures in this unit.

| Rank | Page | What a person comes to do | Pictures | Rewrite unit |
|---|---|---|---|---|
| 1 | first-model | build a first model in ten minutes | 3 (this unit) | docs1 |
| 2 | building | put down, turn, move and copy parts exactly | 3 (this unit) | docs1 |
| 3 | parts-bin | find the part and the colour | 2 (this unit) | docs1 |
| 4 | selecting | select many parts and change them | 2 (this unit) | docs1 |
| 5 | the-view | get the camera where I want, see inside | 3 (this unit) | docs2 |
| 6 | instructions | steps and a booklet to print | 2 (this unit) | docs3 |
| 7 | exports | a file, a shopping list or a render out | 2 (this unit) | docs3 |
| 8 | collection | what I own, what I need, what I can build | 2 (this unit) | docs3 |
| 9 | ai | have an AI design or change a model | 1 (this unit) | docs4 |
| 10 | connect | connect the AI app I already use | 2 (this unit, one of the site) | docs4 |
| 11 | index | find my way in | hero (web/img, by hand) | docs1 |
| 12 | saving-and-files | save, find and reopen; bring a file in | 2 | docs3 |
| 13 | shortcuts | look up a key | 1 | docs3 |
| 14 | sharing | publish, update or take a model down | 2 | docs5 |
| 15 | gallery | find a model to look at or build | 2 (one stale, by hand) | docs5 |
| 16 | model-pages | look at, build or download a shared model | 3 | docs5 |
| 17 | ldraw-library | open a real set, find a set's parts | 2 | docs6 |
| 18 | web-and-desktop | open it, and what the desktop will add | 2 | docs1 |
| 19 | menus | where a command is and its key | 1 | docs3 |
| 20 | joints-and-mechanisms | move on joints, simulate, check it stands | 4 | docs2 |
| 21 | panels-and-settings | find my way round the window, a setting | 3 | docs2 |
| 22 | troubleshooting | fix what went wrong | 1 | docs6 |
| 23 | connector | tabs, chats, long jobs, disconnecting | 2 | docs4 |
| 24 | claude-code | connect Claude Code | 1 | docs4 |
| 25 | profiles | my page, following, feed, settings | 3 | docs5 |
| 26 | build-together | build one model with others, live | 2 | docs5 |
| 27 | figures-and-prints | a minifigure, a print, a made part | 4 | docs2 |
| 28 | art-and-brickify | a mosaic, or a 3D file into bricks | 3 | docs2 |
| 29 | collections | lists of models | 2 | docs5 |
| 30 | challenges | enter and vote in the month's challenge | 2 | docs5 |
| 31 | account | sign in, the age question, delete | 2 | docs6 |
| 32 | plans | what Free and Pro include | 1 | docs6 |
| 33 | how-ai-works | trust what the AI builds | 1 | docs4 |
| 34 | design-session | what an assistant does (read by AIs) | 1 | docs4 |
| 35 | fresh-eyes | the second look a new design gets | 1 pair | docs4 |
| 36 | feedback | report a problem and see the answer | 2 | docs6 |
| 37 | accessibility | keyboard, screen reader, size, motion | 3 | docs2 |
| 38 | changelog | what changed lately | none | docs6 |
| 39 | beta | apply to test Pro | 1, once it opens | docs6 |
| 40 | mcp-tools | each tool an assistant has | none (generated) | docs6 |
| - | connect-<app> (11) | add Brickworks to one AI app | 1 shared (the Allow card) | docs4 (`_connect.md`) |

## The audit, page by page

Each page was read against the code at `804c14443` by four readers (three
of them in parallel, the top ten by one and checked again by this unit
where a picture needed it). "Wrong" is a statement the code contradicts,
with where; "missing" is what shipped or exists and the page does not say.

### docs1: Start and build

**index.** Wrong: "up to 25 models kept with your account" reads as
today's limit; billing is off and the cap is 500 (`api/models.js:42`,
`api/_billing.js:215`), which saving-and-files says. Missing: the
description still says it runs "on the desktop"; the hero picture is from
10-13. Quality: "Find your way" is five run-on link lists, with no way in
by task (build, print a booklet, buy the parts).

**web-and-desktop.** Wrong: none. Missing: the phone menu has Find a
command…, Brickworks website and Beta hub too (`shell.gd` APP_MENU);
Settings › Graphics (desktop) is on no page. Quality: most of the page is
about a desktop app nobody can download; put "open it in a browser" first,
the desktop as a short "coming soon" part, the command line on
claude-code. Pictures: the app's menu open; a phone at 390 px.

**first-model.** Wrong: "Press [[P]] or click a part in the parts bin…
it is now in hand": P is **Build › Parts list** (`shell.gd:1469`, the
model's parts list), and the bin has no key of its own; [[/]] opens it at
its search (`main.gd:10884`). Fixed in this unit. Missing: Check stability
has [[Alt+K]]; the tour's offer goes by itself once someone builds or
opens a model (`first_build.gd:20`); Find a command… ([[Ctrl+/]]) is the
way out for someone new. "Works the same in a browser and in the desktop
app" leads. Pictures (this unit): the window with its parts numbered; a
part in hand over the baseplate; the timeline.

**building.** Wrong: none; every key checked. Missing: the Snap and Turn
choices (Stud, ½ stud, ½ plate, Free; 90, 45, 15, 5 degrees,
`toolbar.gd:81`); a dish or a small part on one tube seats on one stud
(11-08); a cone at the stud's stop (0.19.0). Quality: at about 2,300 words
the longest page, reference order, with assistants' tool calls in the
middle of a person's steps: split into placing (in hand, typed numbers,
sideways, joints, connect, tracks) and changing (copy, patterns, move,
handles, mirror, split, lock, sub-assemblies, undo, measure). Pictures
(this unit): a typed move with its field at the pointer; the Rotate tool's
rings; the Move tool's arrows.

**selecting.** Wrong: "make a sub-model": the menu says **Make a
sub-assembly…**. Missing: the menu on a part is half named (it also has
Ask Claude to brace this…, Comments…, Split, Merge, Replace, Swing on its
hinge, the step moves); Everything connected [[Alt+J]] and The opposite
[[Alt+I]] are listed without their keys. Quality: short and right; Meet on
hinges belongs on the joints page. Pictures (this unit): the menu on a
part; a selection by colour.

**parts-bin.** Wrong: "[[P]] opens it" (as above). Missing: the palettes
chip counts (11-09). "How the app's dialogs look" is about every dialog
and belongs on panels-and-settings. Quality: it opens on how names are
drawn before "type to search". Pictures (this unit): a search with its
results; the colours under the parts.

### docs2: See and shape

**the-view.** Wrong: none; key 7 is "Isometric" in the menu and
"three-quarter" on the page. Missing: touch (two fingers turn, twist turns
round the up, Shift and two fingers slide; `cad_camera.gd:5`), though
tablets use the web app; the view cube's slide and fit buttons; Fit the
model [[Shift+F]], Fit the selection, Turn the model [[Shift+Q]] and
[[Shift+E]], Full screen [[F11]], the baseplate as part of the model; View
› Panels › **Key strip** is on no page. Quality: about 1,800 words; the
reference picture and "What an assistant sees" make a camera page long.
Pictures (this unit): the view cube; Cut away's strip; the split view.

**joints-and-mechanisms.** Wrong: "**Build › Hose, tube or chain…, Spring
or shock**": it is in the Make menu (`shell.gd:221`), which the same page
says ten lines up. Missing: the Hinge tool ([[Shift+I]]) and the menu's
**Swing on its hinge** ([[J]]) are not named; the typed Hinge angle in
Properties; **Ask Claude to brace this…** under stability; no link to
train tracks. Quality: "Grab and move" lists what the engine does, not
what a person does. Pictures: the Hinge tool mid-swing (tilt_cradle);
steering turning both wheels (steering_kart2); Simulate finding its stop
(crank_slider); Motions with its suggestions.

**figures-and-prints.** Wrong: none. Missing: the part maker's ten
families with Clip, Bar and Wedge (11-07) and Far corner cut flat (11-08);
Start from it, Add to parts, the Custom shelf, My prints and My stickers;
the bin's Stickers… button. Quality: each section is one sentence of menu
path, with no steps through the dialog and nothing on where the result
goes. Pictures: the minifigure builder; the part maker on a wedge; the
print designer; Printed versions.

**art-and-brickify.** Wrong: none; the limits check out. Missing: the two
mosaic modes, **Brick Art** (default) and **Classic**, with Panels across
and down and Depth; Blend colours; Brickify's stand, Smooth or Plain, and
its colour limit. Quality: both mosaic modes in one paragraph; "From a
link" is for assistants. Pictures: Brick Art 3 x 3; Classic with a set's
colours; Brickify's dialog; its result.

**panels-and-settings.** Wrong: **Account** is said to be on the toolbar;
it is at the far right of the menu row (`model_bar.gd:215`). The button
**AI…** reads "AI: Claude…" (`controls_dialog.gd:1134`). Missing: Invert
zoom direction, Graphics and Updates (desktop) in Settings; the Key strip.
Quality: a grab-bag; Settings comes last. Pictures: the window's panels,
numbered; Settings; the keys sheet with a search.

**accessibility.** Wrong: none. Missing: the screen-reader path is the
desktop app, which nobody can download, and the page does not say so;
What's This? ([[Shift+F1]]), Find a command ([[Ctrl+/]]), the keys sheet's
search and the Key strip are not named. Quality: browser users, today's
only users, get one sentence. Pictures: Interface size 150%; the bin with
the keyboard's focus; the docs' own search.

### docs3: Files and output

**saving-and-files.** Wrong: none. Missing: File › Open recent; New
window [[Ctrl+Shift+N]]; the Library's [[Ctrl+Shift+O]]; Versions' **Save
it now**; Clear the baseplate…; All my models (.zip) as the backup; what
start-up restores. Quality: clear, but not framed as "where are my
models?" and "get one back". Pictures: Versions; Open with its saved
models.

**instructions.** Wrong: Save as PDF does print Cyrillic and Greek now,
with the fonts embedded (11-08, `pdf_type.gd:10`); only letters no font
has (emoji, and Japanese on the web) are "?". Fixed in this unit. Missing:
[[Ctrl+Shift+B]] for Page setup; "the desktop app up to 0.19.0". Quality:
the most common goal, a PDF, is the last section; lead with three steps:
[[E]] for steps, [[Alt+B]], Save as PDF. Pictures (this unit): the
timeline under the model; the booklet's first page.

**exports.** Wrong: Render's **Backdrop** is **Background** and **View**
is **Camera** (`render_dialog.gd:526`, `:574`); Best's "256 frames" is "As
this device does best (N)", 32 on the web, and path tracing never runs on
the web (`render_settings.gd:382`, `path_tracer.gd:100`); the 3D caption
leaves out 3MF. The two names are fixed in this unit. Missing: [[F9]],
[[Shift+F9]], [[Alt+L]]. Quality: two pages in one: give Render a page of
its own (`render.md`, with `_moved.json` keeping its anchors). Pictures
(this unit): File › Export's list; Render.

**collection.** Wrong: none. Missing: nothing of note. Quality: a
150-word paragraph on edits made in two places at once is engineering
detail; it is a note. Pictures (this unit): My collection; What do I
need? in the parts list.

**menus, shortcuts.** Made from the app. Wrong: menus' description leaves
out **Make**; the shortcuts page's intro says the keys sheet opens with
[[F1]] or [[,]], but [[,]] is Settings (`shell.gd:1585`, from
`docs_site.py:772`). Pictures: Find a command with words typed (menus);
the keys sheet (shortcuts).

### docs4: AI

**connect** (and `_connect.md`, the 11 app pages). Wrong: another AI on
your own key "in the desktop app, coming soon": it works on the web, every
listed provider (`ai_settings.gd:45`, `controls_dialog.gd:991`); only a
custom server needs the desktop. The link reads "AI: Claude…", not "AI…".
Fixed in this unit. Quality: a hub and a how-to on one page. Pictures
(this unit): Connect your AI in the app; the site's Allow card, which every
app's page can share.

**ai.** Wrong: "AI…" as above; a model on your own computer "is for the
desktop app": the web reaches one that allows the site
(`ai_settings.gd:43`). Missing: #my-claude and #my-copilot are desktop
only and do not say the desktop is coming soon. Quality: 1,783 words of
reference; typing a brief and pressing **Build it** comes after a
four-way table. Pictures (this unit): the assistant panel; sketches;
Settings' AI.

**connector.** Wrong: Disconnect is "Disconnect <app>" in Account
(`account_panel.gd:384`), and the site's Settings has it too. Missing: the
seeing tools (view_board, highlight, xray, step, booklet_page), page_setup,
palettes, the ten-second busy signal. Pictures: the toolbar while a chat
works; Account's tabs and chats.

**claude-code.** Wrong: none. Missing: #started-for-you is desktop only.
Pictures: Connect your AI on Claude Code, its command copied.

**design-session.** Wrong: none; the limits match the schemas. Missing:
"Pictures" names only view_model. Quality: say at the top that the page is
the assistant's brief.

**fresh-eyes, how-ai-works.** Wrong: none. Missing: the AI now sees what
you see (several views, parts picked out, a step, a booklet page).
Quality: lab statistics and jargon (greebles, massings).

### docs5: The website

**gallery.** Wrong: the filter offers "Hand-built" and "With the
assistant" only (`api/_directory.js:108`); the tabs are six (Top, New,
Following, Builds, Collections, Sets, `web/gallery.html:268`), and the
picture (by hand, 10-29) shows three. Pictures: the gallery's Top; its
filters; a phone.

**sharing.** Wrong: Publish lists the model only with **List it in the
gallery** ticked (`share_panel.gd:28`); there is no picture chooser, the
picture is the view's (`:17`); "Older versions" is Versions › Earlier
versions (`api/share.js:1575`); the take-down is **Unpublish**. Missing:
Show who made it, What changed?, Copy link and Copy embed code, under-13
accounts. Pictures: the share panel; the panel once published.

**model-pages.** Wrong: none. Missing: Build it's **One part** and **Whole
step** and "3 of 8 in this step" (0.18.0); turning a page over (0.19.0).
Quality: 1,634 words, the build party inside "The viewer".

**profiles.** Wrong: Settings' section is **Assistants**, not "Claude"
(`web/settings.html:118`); the profile's **Likes** tab is left out.
Missing: orangecheck Link and Unlink, Feedback, the daily email; the
account menu's Send feedback and Beta hub.

**collections.** Wrong: "newest first" is what was put in last, or most
followed (`web/collections.js:5`). Quality: say how it differs from My
collection.

**challenges.** Wrong: **Withdraw** is **Take it out**; the two groups
are Built by hand and Built with the assistant, a vote in each. Missing:
the "How did you build it?" choice.

**build-together.** Wrong: none. Missing: a peer can send only words and
parts (0.19.0); the desktop's `--together` is coming soon.

### docs6: Account and reference

**ldraw-library.** Wrong: none. Missing: a set opens as it comes in the
box (0.16.0). Quality: two libraries tangled.

**account.** Wrong: Account shows "Your AI" with "Disconnect <app>", and
nothing of Claude while the assistant is hidden. Missing: orangecheck in
Settings; any provider's key, not only Anthropic's.

**plans.** Wrong: another AI on your own key "in the desktop app"; "once
its terms are out": they are at `/terms#commercial-use`.

**beta.** Wrong: as plans on other AIs. Missing: the beta is shut until
`BRICKWORKS_BETA=open` (`api/_beta.js:59`); the page reads as open.

**feedback.** Wrong: none.

**troubleshooting.** Missing: "Still stuck" points at **Report it**, which
reports content, not **Send feedback…**; nothing for a part that won't go
where wanted, a command not found ([[Ctrl+/]]), or the download saying
coming soon. Quality: three of seven entries are the connector's.

**changelog.** Wrong: "On the web now" is CHANGELOG's [Unreleased], whose
only entry is a desktop one, labelled "In the app at brickworks.diy/app"
(`docs_site.py:871`). About 15 merges since 0.19.0 are in no changelog
entry; that is CHANGELOG.md's, not the page's.

**mcp-tools.** Made from the tools. Wrong: none.

## The pictures

Every picture is written down in its page's manifest,
`docs-site/pictures/<page>.json`: its id, what to set up, what to cut it to,
its alt and caption, the features it shows. One command makes them all:

    tools/docs_shots.py                  # every picture
    tools/docs_shots.py --only=ID,ID     # just these
    tools/docs_shots.py --affected       # which ones a branch may have changed

- **The app's** are taken by `src/dev/docs_shots_probe.gd`, a windowed
  probe on the GPU (`tools/probe.sh` gives it the lease and Xvfb), from a
  locked snapshot worktree of HEAD that the command makes and removes.
  Each picture is its own Brickworks window with its own app data folder,
  so a picture is the same whether it is taken alone or with the rest. The
  window is 1400 x 900 and the app goes through the sign-in screen as a
  person does, let in as `you@example.com`, offline: no clock, no counts,
  nothing of the day. Its steps are a person's: the menus' commands by
  name, keys, clicks, the pointer over a part. It is read until two reads
  are the same pixels, cut to a control's own rectangle, and marked with
  numbered outlines where the manifest says.
- **The site's** are taken by `tools/web/docs_shots_flow.mjs` on a site
  built from the tree (`tools/site.py`), or on a deployment with `--url`,
  in Chromium on SwiftShader, in each theme the manifest names, with what
  the page asks its server answered from the manifest. Animations and the
  caret are stopped.
- Both write lossless PNGs. The command hashes each one's pixels, and a
  picture whose pixels are the ones `docs-site/img/shots.lock` says it was
  made from is left alone. So the same code makes no change, and a picture
  that changes is a UI that changed. A changed one is written as WebP
  (quality 84) into `docs-site/img/`, and its old and new picture and what
  differs, in magenta, are put side by side in the run's
  `diff/index.html`.
- Pages show one as `![alt](/docs/img/<id>.webp "caption")`;
  `tools/docs_site.py --write` copies the alt and caption from the
  manifest. The built page draws it at its own size, lazy, and a click
  opens it whole. Pictures are served at `/docs/img/`, which revalidates,
  so a picture made again is seen at once (`/img/` caches a day).

### The check

`tools/docs_site.py --check` (and so `tests/test_docs_site.py`,
`tests/test_docs_shots.py` and ci_gate) fails when:
- a manifest's picture is missing, or is not what its last run made (its
  size or bytes are not the lock's);
- a picture is on no page, on another page than its manifest's, twice, or
  with words that are not the manifest's;
- a page shows a `/docs/img/` picture no manifest has, or a file in
  `docs-site/img/` is no manifest's;
- a picture is over 300 KB;
- a page's covers, or a picture's `features`, name a feature the feature
  map no longer has;
- a feature in the map is on no page and not in `docs-site/internal.txt`.

The last two were already there; this unit plants each and proves it
fails (`tests/test_docs_shots.py`).

### Keeping them current

Two steps, one for the person who changes the UI and one for the lead.

1. **The unit that changes what a person sees** updates its feature's page
   and makes its pictures again in the same commit: `tools/docs_shots.py
   --affected` lists the pictures its diff may have changed (by the
   features each shows, and the page), and `--only=` makes them. The brief
   template's Proof list says so.
2. **The lead, after each release lands on main,** runs
   `tools/docs_shots.py` on main's tip (one GPU job, about 25 s a picture),
   looks at `diff/index.html`, and commits what changed to the next
   release branch as "docs pictures of rel-mNNN".

Not the release train, because:
- a train is a gate, pass or fail, pushed fast-forward; a picture that
  changed is not a failure, and committing into the train's branch moves
  the sha it proved;
- a changed picture needs eyes, since it may be a regression no probe saw;
- the train already holds the GPU for its probes, and every picture made
  again on every train would double that;
- what must not ship, a missing picture or a feature with no page, the
  train's ci_gate already fails on.

## The rewrite

Six units, each owning its pages, their manifests in `docs-site/pictures/`
and their pictures, so no two touch one file. `_nav.json` and
`_moved.json` are docs3's (render.md's move) and docs1's (index); a unit
needing a nav change asks in its report. Each one's bar:

- every "wrong" above fixed, checked again against the code;
- each page opens with what it is for and where it is, then tasks in a
  person's order; no task page over 900 words, longer ones split;
- the pictures listed above, made by `tools/docs_shots.py`, each looked
  at, alt and caption saying what it shows;
- no page sends a person to the desktop app for what the web does;
- `tools/docs_site.py --check`, `tools/site_lang.py --check` and the docs
  flow pass; the pages looked at on a site built from the tree at 390 and
  1280 px, light and dark.

| Unit | Pages | Pictures to add |
|---|---|---|
| docs1 Start and build | index, web-and-desktop, first-model, building, selecting, parts-bin (6) | index's hero from the pipeline; web-and-desktop 2; building split in two |
| docs2 See and shape | the-view, joints-and-mechanisms, figures-and-prints, art-and-brickify, panels-and-settings, accessibility (6) | 4 + 4 + 4 + 3 + 3 |
| docs3 Files and output | saving-and-files, instructions, exports (and a new render page), collection, menus, shortcuts (6) | 2 + render's 3 + 1 + 1 |
| docs4 AI | connect and `_connect.md`, ai, connector, claude-code, design-session, fresh-eyes, how-ai-works (7) | 2 + 2 + 1 + 1 pair |
| docs5 The website | gallery, sharing, model-pages, profiles, collections, challenges, build-together (7) | the site's, with its server's answers in the manifest: 2 + 2 + 3 + 3 + 2 + 2 + 2 |
| docs6 Account and reference | ldraw-library, account, plans, beta, feedback, troubleshooting, changelog, mcp-tools (8) | 2 + 2 + 1 + 2; and CHANGELOG [Unreleased] filled |

docs1 to docs3 can run at once; docs4 after the assistant units now
running (bugreport, betajoin) merge; docs5 and docs6 at once with the rest.
