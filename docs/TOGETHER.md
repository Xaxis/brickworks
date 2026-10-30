# Build together

Two people build one model at once, live, each in their own browser or the
desktop app. Started 2026-10-24 (unit together233).

## What a person does

1. The owner of a model opens **File, Build together…** and presses
   **Start a session**. The panel shows a link and **Copy link**.
2. They send the link. Anyone signed in who opens it joins: in a browser the
   link opens the app and joins (`/app?together=<secret>`); in the desktop
   app they paste it into the same panel and press **Join**. If the model on
   their baseplate has changes not saved, they are asked first, as opening
   any model asks.
3. Each sees the other's parts go down, move, change colour and come off as
   it happens, and everything else the model is: its name, the floor,
   motions, build steps, the booklet's looks, the colours of hidden parts,
   sections broken out, and parts made in the app (a print, a sticker, a
   made part). Each sees who is in the session (here or away, each with a
   swatch of their colour), and where each other person is working: a dot
   with their name in the view, on the part under their pointer or where
   the part in their hand would go, and the parts they have selected
   outlined in their colour. **Undo** and **Redo** are each person's own.
4. **Follow** beside a name in the panel: this view goes where theirs goes,
   framed in their colour with "Following Ann" and **Stop**, until this
   person turns, slides or zooms the view themselves, presses Stop, or the
   other leaves.
5. **A comment pinned to a part**: a part selected, **Edit, Comments…** (or
   the part's right-click, **Comment on it…**), words, **Pin**. Its mark,
   a numbered dot in the writer's colour, stands over the part and goes
   with it; pressed, a card says who wrote it and when, with **Resolve**,
   one click (Ctrl+Z brings it back). The panel lists every comment with
   **Show** and **Resolve** (resolved ones under **Show resolved**, with
   **Open again**). Comments are kept in the model's file, so a save, an
   open, the autosave and a shared link's file all keep them; in a session
   everyone 13 and over sees them as they are pinned (below).
6. A short chat in the panel, for people 13 and over (below).
7. A reload, a browser restarted, the desktop app started again, or the
   connection lost for a while: the tab goes back into the session by
   itself and catches up, both ways. Changes still on their way when the
   page goes are not lost: kept in the tab and sent again once it is back,
   or, when the tab is closed, sent as it goes.
8. The owner presses **End the session**; the model stays theirs and saves
   as it always does. Anyone else presses **Leave**, or is told the owner
   ended it; what was built stays on their baseplate, theirs to keep or not.
   The owner can **Remove** a person: the link no longer lets them in.
   The owner's page closing or reloading ends nothing: the others go on,
   and the owner goes back in as its owner. (Studio's Build Together ends
   for everyone when its host leaves.)

## How it works

- **The session.** `api/together.js` keeps a session per link
  (`supabase/together.sql`): its owner, the model as it began (the file's
  text, the height it stands at, and every part with the id the session
  calls it by), and who has joined. The link's secret is never stored, only
  its SHA-256, as the relay keeps a tab's token.
- **A change** is a part's whole state, by its session id (`uid`): `[part,
  colour, transform, group, unit, step]`, or null for taken off. A person's
  edit is read off the model as it changes (`Together._capture`: the world's
  own change log, or every part when a builder step may have changed what
  the log does not hold, such as a sub-model), so every way of editing is
  carried without touching each tool: the keys, the mouse, Grab, a tool of
  the connector's.
- **One order.** The server numbers every change (`together_append`, under
  the session row's lock, so numbers commit in order and a reader never
  skips one). Each side puts the numbered changes down in that order, and
  keeps its own changes shown until they come back numbered. So when two
  people move one part at once, both see their own move for a moment, then
  both settle on whichever was numbered later; the other is told
  ("Builder 2 changed a part you had just changed; theirs came after yours,
  so it stands"). Once nothing is on its way, the model is the same on every
  side, part for part, and its file byte for byte.
- **Undo per person.** Each side keeps its own steps (one per builder step,
  so a drag or a group edit is one undo). Undo puts a step's parts back only
  where they are still as that step left them; a part someone else changed
  since is theirs now and is left, and the status line says how many.
  Nobody's undo takes back anybody else's part. Steps from before the
  session are forgotten when it starts, and the session's when it ends, for
  the same reason.
- **What the model is besides its parts** goes the same way, a key each with
  its words as the file has them (`Together._meta_now`): `~title`,
  `~floor`, `~hidden` (the colours of hidden parts), `~motions`, `~looks`
  (the booklet's), `~unit_steps` (the steps of sub-assembly copies) and
  `~broken` (sections broken out, their parts named by uid). Each is read
  a few times a second while in a session, and on every builder step, and
  is numbered, undone and overtaken as a part is. A part made in the app (a
  print, a sticker, a part from Make a part…) goes with the first change
  that puts one down, as `~part:<id>` and its LDraw files, so the other
  side can draw it. Hide and Isolate are not carried: they are each
  person's view, as the camera is, and an app-made model's file does not
  keep them. A floor's own plate made part of the model on one side is the
  same plate on the other, not a second one on it.
- **What slips is put back.** Every two seconds each side compares what it
  shows with what the numbered changes say (`Together._heal`) and puts back
  any part or state that no change of its own on the way explains: a part
  made in the app whose geometry was built after its first part arrived,
  or anything else that slipped. Each one is said on the console and
  counted (`timing.healed`); the desktop's half of the flow reports them.
  The desktop's lag once seen after the hidden parts were coloured (its
  copy matched again at the next check, not within the check's 90 s) did
  not come back in the timed runs, so its cause is not named yet; if it is
  a part or a state that slipped, this puts it back within two seconds and
  names it.
- **Sent twice is put down once.** A send whose answer was lost is sent
  again; every side skips a copy's change it has had already (by its count,
  `cid`), the same everywhere.
- **Joining** opens the session's text as any model opens (so sub-models,
  motions, the floor and the booklet's looks come with it), then matches its
  parts to the session's ids and sets each exactly as the owner's, the
  height too; then every change since is put down in order.
- **Going back in.** A tab keeps the session it is in with its own working
  state (`TabSession.path("together.txt")`). Reloaded, restarted, or opened
  again, it joins again by itself without asking: its model is the
  session's, opened again from the session and every change since. A lost
  connection needs nothing: the waiting request is asked again every second
  until it answers, and what was changed meanwhile is sent then. Ended or
  taken out meanwhile, it is told so and forgets the session.
- **Pointers.** A few times a second, while it moves, each side sends where
  it is working (`op=point`: the ghost of the part in hand, or the part
  under the mouse), kept on its row of `together_people`; a waiting request
  answers as soon as someone's moves, and each side draws the others' as a
  dot and their name in a colour each, over the parts: the same size on
  the screen however near the view is, as a cursor is, so it never hides
  the part it points at.
- **Selections and views.** The same `op=point` carries the uids of the
  parts this side has selected (at most 500) and its view (`CadCamera.aim`,
  rounded), sent when any of the three changes. The server keeps them on
  the person's row and re-reads the rows every 250 ms while a request
  waits (every 100 ms while somebody else's pointer moved in the last
  2 s), answering as soon as one changed. Each side outlines each other
  person's selection with its own silhouette outline (`SelectionOutline`)
  in that person's colour, drawn again when the parts move. A person's
  colour is their place in the session's list of people, the same on every
  side (`Together.colour_of`).
- **Follow** (`Together.follow`) turns this view to the person's view as
  each poll brings it (`CadCamera.aim_at`), and keeps the view it set: the
  first frame the view is not what Follow set, this person moved it, and
  following stops. It stops too when they leave. The frame and the name
  are drawn over the model's column (`banner_parent`).
- **Comments pinned to parts** (`src/assembly/pinned_comments.gd`) are a
  line each in the head of the model's main file, after its motions and
  its floor, which other programs read past:
  `0 !BRICKWORKS PIN {"id","part","colour","at","text","by","tint","when"}`
  with `"resolved":true` once resolved. "at" is where its part stands in
  the file (LDraw's coordinates), as a motion names its joint: the part is
  found again by number, colour and place when the file opens, and the pin
  goes with it as it moves. A pin whose part was taken off stays where the
  part was. In a session each comment is a key of its own, `~pin:<id>`,
  naming its part by uid, so two people pinning at once both keep theirs,
  and moving a pinned part sends nothing of its pin. Pinning and resolving
  are each one undo of the builder's (`"pins"` steps), so Ctrl+Z takes them
  back per person like any edit. The marks are drawn by `PinsView` over
  the model's column; not on a model shared by link opened to look at.
- **Comments and chat's rule.** A comment is words to the others, so in a
  session it follows chat's rule (below): an account that may not chat may
  not pin or resolve one (the server refuses with 422, and the panel says
  why), the words are filtered as a chat line's, and **an account under
  13 is sent no comments**: the server takes their keys out of its ops and
  out of the model it joins on (a model sent in parts carries none in its
  parts: its comments go in the session's row, checked, and are left out
  of the answer to an account under 13). Its file is the others' without the
  comment lines. The owner's own comments in the model a session starts on
  are held to the same rule: any that may not be said stay in the owner's
  model and out of the session's, and the owner is told.
- **Changes on their way when a page goes.** Every change waiting to be
  numbered is kept as it is queued: in the tab's own storage on the web
  (`sessionStorage`), a file of the tab's on the desktop
  (`TabSession.path("together_pending.json")`). On the web the page also
  holds a request ready to send them as it goes (`pagehide`, a fetch kept
  alive past the page, 64 KB at most). Back in after a reload, the tab
  takes up its old client and counts, waits until it has caught up with
  what the server had, puts down any of its own that arrived meanwhile
  (sent as the page went) as numbered, and sends the rest again ("Sent
  again: 3 parts you changed just before the page went").
- **A model too big for one request.** Vercel takes at most 4.5 MB a
  request and as much an answer. A snapshot over 3.5 MB of JSON starts the
  session with none (`op=start {stored: n}`), then the owner sends it in
  parts of 2 MB (`op=upload`), and whoever joins reads them back
  (`op=snapshot`), waiting for a part not yet there. Its comments are not
  in the parts: `op=start` carries them, the server checks them and keeps
  them in the session's row, and whoever joins takes them from there and
  none from the parts. The parts are kept in
  `together_snapshot_parts` (`supabase/together_big.sql`); until that is
  applied a big model is refused as before. Sends are cut at 1.5 MB and
  1,000 parts an op, and a poll's answer at 3 MB, so a big model's first
  change (a select all moved) goes too. Joining matches 25,600 parts to
  their uids by place in 12 s on this box (it was 68 s, a search per part).
- **Chat** is a line of words in the same numbered log (`~chat`), shown in
  the panel and on the status line. Who may: comments' rule
  (`supabase/comments.sql`, `comments_guard`): an account that answered
  the age question 13 or over and was not taken out of the gallery; the
  words a stranger may not be shown are refused (`api/_names.js`), at most
  280 characters. Stricter than comments for under-13s, by choice: a
  comment is public, moderated and can be reported, where a chat is
  private and live with someone met by a link, so an account under 13 can
  neither say anything nor read the others' lines (its copy of each chat op
  comes with the words taken out), and the panel tells it why. Building
  together itself stays theirs, as a link is (`trust.sql`: an account under
  13 shares by link like anyone). Comments pinned to parts follow the same
  rule in a session (above).
- **Claude in a session tab.** A connected Claude's edits change the model
  in that tab like any other, so they reach everyone (proven with a real MCP
  `edit_model` through the deployment's relay). Its `undo` presses the same
  Undo, so it takes back only that side's parts.
- **Nothing runs outside a session**: `Together._process` returns at once
  (on the web it says its state to the page twice a second for checks).

## The transport, and why

Measured before choosing, 2026-10-24:

| Way | What it needs | Result |
|---|---|---|
| The relay's way: each change a row in Postgres, numbered there; each side waits on a request (`op=poll`) that looks for rows after its last every 100 ms and answers as soon as there is one | Nothing new: a Vercel function, the database as the server (`api/_db.js`), and the HTTP the app already uses for the connector, on the web and the desktop alike | Chosen. Measured on a preview (below) |
| Supabase Realtime (Broadcast or Postgres changes) | Each page and the app opening a websocket to Supabase with the publishable key and the person's session, and row security policies for `authenticated` on `realtime.messages` | Ruled out without building it: since `supabase/no_client_access.sql` (2026-10-24) pages reach Supabase only to sign in, and the page's content security policy names nothing else there. It would reopen exactly what that file closed |
| A websocket server | Something that holds a connection open | Vercel functions do not hold websockets; it would be a new host to run |

The cost of the chosen way is the wait: a poll looks every 100 ms, so a
change reaches the other side in about two round trips to Vercel and the
database plus up to 100 ms. Measured on a preview with the project's tables
(2026-10-24):

| What | p50 | p95 |
|---|---|---|
| A send to the other side's waiting poll answering (`together_probe.mjs`, 30 changes, from this box) | 224 ms | 302 ms |
| ...the same, the second part (chat, pointers, the model's own state carried) | 263 ms | 336 ms |
| ...the first version: a send that checked the session first, and polls 150 ms apart | 344 ms | 573 ms |
| An edit asked of one browser to the other browser's frame having it (`together_flow.mjs`, 38 changes, both ways, two SwiftShader pages drawing at once) | 519 ms | 688 ms |
| ...the second part's flow, on a preview while another browser check ran beside it (40 changes) | 695 ms | 1,356 ms |
| ...the same against this box's server, nothing else running (40 changes) | 307 ms | 744 ms |

A browser drawing in software takes a few hundred milliseconds a frame, so
the browser rows are mostly frames on both sides; on a real graphics card
they should come close to the first rows, which is not measured yet.

The pointer, from one person's mouse moving onto a part to the frame the
other's page drew their dot in (this box's server, 2026-10-30): two desktop
copies 248 ms p50, 352 ms p95 (`together_probe.gd`, 20 moves); two
browsers on the car after the 50 edits 314 ms and 627 ms (`together_flow.mjs`,
40 of 40 moves); on the rich car 1,133 ms and 2,000 ms, every one of the 40
within 500 ms and four of the drawing page's frames, which were 617 ms at
the median there.

**Where the time went, and the fix (2026-10-24, `tools/web/together_timing.mjs`).**
Each of the seven kinds of change made in turn on the car, ten paints after
each, every paint timed stage by stage from the app's own clocks. Before:
the send's round trip alone ("number") was 150 to 520 ms against a server
that answers in a few, and the whole change 0.5 to 1.4 s p50 with p95s to
5.6 s, rising and falling with the frames rather than with any one kind
of change: no part of the session re-read, rewrote or re-measured the
model per change (a capture took at most 13 ms, a read of the model's own
state under 5 ms; ops carried only the part changed). The cause was the
browser's HTTPRequest, which the engine polls once a frame and which takes
a frame for each of its states: every request, and above all every
answer of the waiting poll, sat two or three frames after its bytes had
arrived, and a software-drawn frame on this box is about 150 ms. In a
browser the session now asks with the page's own fetch, answered the
moment the answer is in (`Together._ask_page`). After: the send's round
trip 42 to 199 ms, and the whole change p50 193 to 701 ms, p95 under a
second for every kind but one outlier round (the printed part, 1.4 s).

The flow measures again later, once the model has a motion, a printed
part, steps of its own and its hidden parts coloured, and says how many
frames a second each page drew meanwhile. Before it said so, with the car
on a 48 × 48 baseplate, that second measure was 2.8 s p50 on this box;
then 1.3 s once the motions were read as kept rather than by measuring
each joint on the model four times a second (`ModelStore._motion_lines`,
which held the frames of a model with a motion: the session's own doing);
and 4.0 s on the preview with another browser check beside it.

## Who may

- Signed in, everyone: every request carries the person's session
  (`api/_auth.js verify`).
- The link is the invitation. A made-up link is "no such session"; an
  account that never joined is refused (403) for reading and writing; one
  the owner removed is refused from then on, the same link too.
- The owner alone ends a session or removes someone.
- **Under 13** (`supabase/trust.sql`): an account under 13 builds together
  like anyone, as it shares a model by link like anyone. Its name is never
  shown: everyone appears by their profile's name only when a visitor may
  be shown it (`shown_publicly`), and otherwise as "Builder 2", never by an
  email. It has no chat, and is sent no comments pinned to parts (above).

## Against the best named tool

Studio's Build Together co-edits over a LAN or a relay [st-bt], and the
session ends for everyone when its host leaves; LEGO's own takes turns.
Figma is the bar for working on one thing at once: each person's
cursor and selection in their colour, following someone's view by their
avatar (observation mode), and comments pinned to the canvas, resolved by
a click. Here:

- in a browser or the desktop app, joined by a link, nothing to install;
- the same model byte for byte on every side once nothing is on its way,
  and two moves of one part settle the same way everywhere, said to the
  person whose move was overtaken;
- Undo is each person's own and never takes back another's part;
- every way of editing is carried, read off the model as it changes rather
  than from each tool, and everything the model is besides its parts;
- each person's pointer and selection in the others' view, in their
  colour, and Follow on their name, as Figma has them;
- comments pinned to parts, resolved in one click, kept in the model's
  own file and going with their part as it moves;
- a chat and comments with the trust rules a children's audience needs;
- a reload or a dropped connection goes back in and catches up by itself,
  with nothing changed just before it lost; the owner leaving ends nothing;
- a model over 4 MB starts a session (in parts);
- a person's own Claude, connected to their tab, builds for everyone.

[st-bt]: https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767

## Proof

- `tools/web/together_probe.mjs`: the server's half from three accounts.
- `src/dev/together_probe.gd`: two desktop copies in one process (60 edits,
  the same part moved by both, each undo its own, the end); the others'
  selection outlined in their colour, the pointer timed over 20 moves,
  Follow and its stop; a comment pinned, byte for byte on both, resolved
  from the other side, two pinned at once, the file opened again; a copy
  going with three changes on their way and coming back; a session begun
  again on the car (someone else's file, a part moved, one in a step of its
  own) in one request and in parts, byte for byte; 25,600 parts (a
  snapshot over 4 MB) started in parts and joined byte for byte. With
  `--join` the desktop's half of the flow.
- `src/dev/together_pins_probe.gd`: the real app at 1280x720 and 1400x900,
  read off its pixels: a comment pinned from Edit, Comments…, its mark in
  its colour over its part, its card, one click on Resolve, Ctrl+Z, saved
  and opened again on the same part; another person's selection outlined
  and pointer drawn in their colour, the dot gone when they point nowhere
  and its size kept with the view 2.5 times nearer; Follow from the panel, the frame,
  following a turn, stopped by the wheel and by Stop.
- `tools/web/together_flow.mjs`: two browsers and the desktop in one
  session: 50 random edits interleaved, byte-identical after; then each
  kind of the model's own state from either side (the name typed, the
  floor, a printed part made in the app, a build step, a booklet look, a
  motion, the hidden parts coloured), byte-identical in both browsers and
  the desktop after each; Ctrl+Z per person; the time a change takes each
  way; a reload and a lost connection going back in; the owner's pointer
  drawn in the other's view; the chat, and an under-13 refused it; a real
  MCP `edit_model` from the owner's connected Claude reaching the other
  browser; the pointer timed, Follow, the selection outlined in the owner's
  colour (read off the page); a comment pinned and resolved, none of it
  sent to the person under 13, kept in a shared link's file; a reload and
  a closed page with changes on their way, the owner's page reloaded; a
  stranger refused; the owner ending it; a session begun again on the car
  as all that left it, in one request and then in parts. The pointer is
  timed over 40 moves from the mouse moving to the frame the second page
  drew its dot in, twice: on the car after the 50 edits, p95 under 1 s
  strictly; on the rich car, as the change measure is there, p95 under
  1 s or 95 of 100 within 500 ms and four of that page's frames (each
  move's own, this box's software drawing, half a second and more). Both
  say the stages and what the check reading the page saw. Red on m165 (no Build together in the File menu).

## Not done yet

- **In a browser drawing in software, a change is as quick as the frames
  let it be.** The flow's extras timed one at a time on the rich car
  (`together_timing.mjs --extras=undo,parts`, 10 paints each, p50 / p95,
  with the stages):

  | After | total | p95 | number (send's round trip) | shown (put down to on the page) |
  |---|---|---|---|---|
  | the seven kinds of change | 182 ms | 661 ms | 50 ms | 44 ms |
  | Ctrl+Z, the pointer left on a part | 842 ms | 1,365 ms | 598 ms | 653 ms |
  | twice the parts (143) | 806 ms | 1,785 ms | 641 ms | 536 ms |

  and earlier rows of the same run, with nothing added, ran from 182 to
  1,204 ms. What moves is "number" and "shown": a fetch answered while the
  page draws a frame is heard when the frame ends, and a change put down
  shows at the next frame, so both are counted in frames of about 150 ms
  each on this loaded box, more while it is busier. Neither the session's
  capture (at most 4 ms) nor its read of the model's state (at most 5 ms)
  grew. Two costs of the session's own were taken out on the way: every
  poll read the person's age (now only a poll with a chat line to give),
  and began with four trips to the database (now two). The desktop copy,
  the connected assistant and an account under 13, the other extras, were
  not timed alone: the script stopped at the desktop's (since fixed).
  On the e2c43adb preview the flow's rich measure was p50 1,907 ms, p95
  3,464 ms, the owner's page drawing 27 frames a second while idle and the
  other's 60. Timed alone (2026-10-24), the connected assistant is not it:
  the owner's page with the assistant open, Claude connected, its
  connector listening and a session live drew 60 frames a second, with the
  pointer on the model too. (The timing tool's "+ assistant" row, 1.5
  frames a second, is a page in its first seconds after the reload that
  turns the assistant on: the same page drew 7.6 a second just after
  loading with nothing else on.) The one thing the owner's page had and
  the other's did not, besides, was the pointer left on the model after
  Ctrl+Z, and the session looked for the part under the mouse four times a
  second whether or not anything had moved. It looks only when the mouse,
  the view or the model moved now (`Main`'s `pointer_at`); the timing
  tool's "+ undo" row went from p50 842 ms, p95 1,365 ms to p50 551 ms,
  p95 910 ms in the next run. On the 91db1843 preview the owner's page
  drew 59.5 frames a second while idle, the other's 60.2: the 27 was that.
  But the rich measure stayed p50 1,873 ms, p95 4,249 ms (owner to guest
  p50 2,194), against p50 383, p95 516 ms before the seven kinds in the
  same run. So in the flow's rich state the time is in the frames that
  follow a change, not in idle ones, and the timing tool's two pages do not
  reach that state (its rich rows: p50 452 to 890 ms).

  **Inside the flow itself**, at both measures, the stages and the longest
  each page's thread went between two frames after the change ("held"),
  beside the same hold after nothing but the view turning (Shift+Q: the
  model drawn again, no change made, nothing sent). With the model
  autosaved over frames while a session is live (`ModelStore.paced_always`;
  an autosave written in one frame held both pages after a change) and the
  pointer looked for only when something moved, this box, 2026-10-24:

  | Measure | p50 | p95 | number | shown | held, receiver | held by a turn of the view alone |
  |---|---|---|---|---|---|---|
  | after the 50 edits | 384 ms | 851 ms | 53 ms | 166 ms | 150 ms | 17 to 133 ms |
  | after the seven kinds (the rich car) | 644 ms | 794 ms | 322 ms | 497 ms | 483 ms | 17 to 617 ms |

  The hold after a change is the hold after a turn of the view: what is
  left is the rich car drawn again in software, about half a second a frame
  on this box, which no change of the session's makes or can take away. The
  run before (the same code, the box busier) was p50 1,789 ms, p95 2,169
  ms; the first rich measures of the day, before any of these fixes, 2.1 to
  2.8 s. On the 745989a6 preview, two browser checks drawing in software at
  once, the rich measure was p50 2,148 ms, p95 3,432 ms, and the pages were
  held 967 and 1,300 ms after a change against 850 to 2,233 ms after a turn
  of the view alone: the drawing again, on the page receiving the change
  above all (its post-change "shown" stage, 1,309 ms, against "reach", 612
  ms, for the network and the server together). So the flow's bars:

  - **the plain measure** (after the 50 edits): p95 under 1 s, strictly;
  - **the rich measure** (after the seven kinds): p95 under 1 s, or 95 of
    every 100 changes within a network budget of 500 ms plus one of the
    sender's frames (the edit picked up) and three of the receiver's (the
    frame it lands in, the one it is drawn in, the one the page is told
    in), each page's frame its own median hold after a turn of the view
    alone. On the 745989a6 preview's numbers: frames 850 ms (owner) and
    1,117 ms (the other), so 4.2 to 4.7 s allowed against a p95 of 3.4 s;
    on this box 17 and 533 ms, so 1.1 to 2.1 s against 0.8 s. A real
    graphics card draws the rich car in a few milliseconds, and the bar
    comes down to the plain one with it.
- **The desktop lagged once more**, after the second browser was reloaded
  (e2c43adb preview): both browsers matched, the desktop's file did not at
  that check and did at the next, and it had put nothing back (its count
  stayed 0), so what differed was not a part or a state the session
  tracks. The desktop's half now writes its file as of the change it last
  put down beside its line (`desktop.json.ldr`), and the flow reads it
  again for up to 5 s before calling it apart, then prints the lines that
  differ: a stale read passes, and a real difference is named. On the
  91db1843 preview every check of the desktop passed, the reload's too.
- **A file written from the owner's can put one STEP line elsewhere**
  (found by the flow's section 8, 2026-10-30; not Build together's, and the
  same on a plain start): parts in no step of the author's (ones Claude or
  a check put down in a model with its author's steps) are in a step of
  their own at the end of the owner's file, and in the step before it in
  the joiner's, which is written back from the owner's file it opened
  (`ModelStore._source_asked`, `src/parts/source_file.gd`). The session's
  parts and steps are the same on both sides; only the file differs. The
  flow allows that one difference and says so.
- **A model over 4 MB needs `supabase/together_big.sql` applied**; until
  then it is refused as before. A browser opening one is as slow as the
  page is (25,600 parts join in 12 s on the desktop).
- **Comments have no replies, mentions or report button**, and a shared
  link's page and its viewer do not show them (they are in the file it
  serves, and in a copy opened in the app). An account under 13 opening a
  copy of a shared model in the app sees the comments the file has, as it
  sees the file's other words.
- **Follow follows the view**, not the step or the panel open; Figma's
  spotlight (everyone made to follow one person) is not here.
- **A conflict is told by time**: a change of another's numbered within
  1.5 s of one's own on the same part is said to have overtaken it.
- **Chat has no report button** and no history past the session; a session
  ends a day after it ends (`together_sweep`).
