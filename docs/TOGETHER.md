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
   made part). Each sees who is in the session (here or away), and where
   each other person is working: a dot with their name in the view, on the
   part under their pointer or where the part in their hand would go.
   **Undo** and **Redo** are each person's own.
4. A short chat in the panel, for people 13 and over (below).
5. A reload, a browser restarted, the desktop app started again, or the
   connection lost for a while: the tab goes back into the session by
   itself and catches up, both ways.
6. The owner presses **End the session**; the model stays theirs and saves
   as it always does. Anyone else presses **Leave**, or is told the owner
   ended it; what was built stays on their baseplate, theirs to keep or not.
   The owner can **Remove** a person: the link no longer lets them in.

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
  dot and their name in a colour each, over the parts.
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
  13 shares by link like anyone).
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
  email. It has no chat (above).

## Against the best named tool

Studio's Build Together co-edits over a LAN or a relay [st-bt]; LEGO's own
takes turns. Here:

- in a browser or the desktop app, joined by a link, nothing to install;
- the same model byte for byte on every side once nothing is on its way,
  and two moves of one part settle the same way everywhere, said to the
  person whose move was overtaken;
- Undo is each person's own and never takes back another's part;
- every way of editing is carried, read off the model as it changes rather
  than from each tool, and everything the model is besides its parts;
- each person's pointer in the others' view, and a chat with the trust
  rules a children's audience needs;
- a reload or a dropped connection goes back in and catches up by itself;
- a person's own Claude, connected to their tab, builds for everyone.

[st-bt]: https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767

## Proof

- `tools/web/together_probe.mjs`: the server's half from three accounts.
- `src/dev/together_probe.gd`: two desktop copies in one process (60 edits,
  the same part moved by both, each undo its own, the end); with `--join`
  the desktop's half of the flow.
- `tools/web/together_flow.mjs`: two browsers and the desktop in one
  session: 50 random edits interleaved, byte-identical after; then each
  kind of the model's own state from either side (the name typed, the
  floor, a printed part made in the app, a build step, a booklet look, a
  motion, the hidden parts coloured), byte-identical in both browsers and
  the desktop after each; Ctrl+Z per person; the time a change takes each
  way; a reload and a lost connection going back in; the owner's pointer
  drawn in the other's view; the chat, and an under-13 refused it; a real
  MCP `edit_model` from the owner's connected Claude reaching the other
  browser; a stranger refused; the owner ending it. Red on m165 (no Build
  together in the File menu).

## Not done yet

- **A change takes about 2 s to cross once the model has a motion, a
  printed part, steps of its own and its hidden parts coloured** (the
  flow's second measure on the 2026-10-24 preview: p50 2,145 ms, p95
  3,088 ms, with both pages drawing 60 frames a second when idle), against
  under half a second before those (p50 488 ms, p95 614 ms in the same
  run). Not frames, then, and not found yet: the next unit measures each
  of the seven changes in turn to find which one makes every later change
  slow, on both sides.
- **The desktop once fell behind after the hidden parts were coloured**
  (the same run): both browsers matched, the desktop's file did not within
  the check's 90 s, and it matched again at the next check. Not
  reproduced on this box (three runs passed it).

- **Changes still on their way when a page goes** (the last half second
  or so before a reload) are not sent; the session's own copy comes back.
- **A model over 4 MB of text** cannot start a session (Vercel's limit for a
  request); the session's changes are paged 500 at a time when joining.
- **A conflict is told by time**: a change of another's numbered within
  1.5 s of one's own on the same part is said to have overtaken it.
- **Chat has no report button** and no history past the session; a session
  ends a day after it ends (`together_sweep`).
