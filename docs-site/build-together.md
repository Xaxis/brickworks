---
title: Build together
nav: Build together
description: Build one model with other people, live, each in their own browser or the desktop app.
---

**File › Build together…** builds the model on your baseplate with others, at the same time. Each of you sees the others' parts go down, move and change colour as it happens, and their pointer with their name.

<!-- covers
ui:build together
lib:building together
api:POST /api/together
-->

## Start a session {#start}

1. **File › Build together…**, then **Start a session**.
2. Send the link it gives you. Whoever opens it, signed in, joins, in a browser (`/app?together=<secret>`) or the desktop app (from 0.8.0).
3. The dialog lists who is in the session, with **Remove** beside each.

## Join {#join}

Open the link, or paste it in **File › Build together…** and press **Join**. On the desktop, `--together=<secret>` joins at start-up.

## While you build {#while}

- **Undo takes back only your own changes**, never someone else's.
- A short chat is there for people 13 and over.
- A reload goes back into the session by itself.

## End it {#end}

**End the session** (you started it) or **Leave** (you joined). The model stays yours.
