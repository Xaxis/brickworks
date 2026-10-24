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
   it happens, and who is in the session (here or away). **Undo** and
   **Redo** are each person's own.
4. The owner presses **End the session**; the model stays theirs and saves
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
- **Joining** opens the session's text as any model opens (so sub-models,
  motions, the floor and the booklet's looks come with it), then matches its
  parts to the session's ids and sets each exactly as the owner's, the
  height too; then every change since is put down in order.
- **Nothing runs outside a session**: `Together._process` returns at once
  (on the web it says its state to the page twice a second for checks).

## The transport, and why

Measured before choosing, 2026-10-24:

| Way | What it needs | Result |
|---|---|---|
| The relay's way: each change a row in Postgres, numbered there; each side waits on a request (`op=poll`) that looks for rows after its last every 150 ms and answers as soon as there is one | Nothing new: a Vercel function, the database as the server (`api/_db.js`), and the HTTP the app already uses for the connector, on the web and the desktop alike | Chosen. Measured on a preview (below) |
| Supabase Realtime (Broadcast or Postgres changes) | Each page and the app opening a websocket to Supabase with the publishable key and the person's session, and row security policies for `authenticated` on `realtime.messages` | Ruled out without building it: since `supabase/no_client_access.sql` (2026-10-24) pages reach Supabase only to sign in, and the page's content security policy names nothing else there. It would reopen exactly what that file closed |
| A websocket server | Something that holds a connection open | Vercel functions do not hold websockets; it would be a new host to run |

The cost of the chosen way is the wait: a poll looks every 150 ms, so a
change reaches the other side in about one round trip to Vercel plus up to
150 ms. Measured on this machine against the deployment's code with the
tables in memory (`tools/web/together_probe.mjs`): 152 ms p50, 155 ms p95
from send to the other side's poll answering. The browser numbers include
the frames each page draws (SwiftShader, two pages at once); the preview's
are in the unit's report.

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
  email.

## Against the best named tool

Studio's Build Together co-edits over a LAN or a relay [st-bt]; LEGO's own
takes turns. Here:

- in a browser or the desktop app, joined by a link, nothing to install;
- the same model byte for byte on every side once nothing is on its way,
  and two moves of one part settle the same way everywhere, said to the
  person whose move was overtaken;
- Undo is each person's own and never takes back another's part;
- every way of editing is carried, read off the model as it changes rather
  than from each tool.

[st-bt]: https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767

## Proof

- `tools/web/together_probe.mjs`: the server's half from three accounts.
- `src/dev/together_probe.gd`: two desktop copies in one process (60 edits,
  the same part moved by both, each undo its own, the end); with `--join`
  the desktop's half of the flow.
- `tools/web/together_flow.mjs`: two browsers and the desktop in one
  session: 50 random edits interleaved, byte-identical after, Ctrl+Z per
  person, the time a change takes each way, a stranger refused, the owner
  ending it. Red on m165 (no Build together in the File menu).

## Not done yet

- **A reload leaves the session.** The page forgets it; the link joins
  again (the model is opened again from the session). The owner's tab
  reloaded cannot end it from the panel; it ends a week after its last
  change (`together_sweep`).
- **Only parts are carried.** A motion, the floor, hidden colours, the
  booklet's looks and a section broken out change on one side only; the
  file the session began with has them as they were.
- **Seeing where the other is working**: their selection and pointer are not
  shown, only what they change.
- **Chat.** Studio's Build Together has one [st-bt]; this has none yet, and
  for under-13 accounts any chat would have to follow trust.sql's comment
  rules.
- **A model over 4 MB of text** cannot start a session (Vercel's limit for a
  request); the session's changes are paged 500 at a time when joining.
- **Claude in a session's tab** is not yet tried with a real chat. Its
  edits are read off the model like any other, and its `undo` tool presses
  the same Undo (`EditVerbs.press`), so it takes back only that side's
  parts; but the words it answers with still name the builder's step.
- **A conflict is told by time**: a change of another's numbered within
  1.5 s of one's own on the same part is said to have overtaken it.
