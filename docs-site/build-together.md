---
panels: TogetherDialog
ai: Build together puts several people on one model live, by a link, in browsers or the desktop app: each sees the others' parts, pointers and selections in their colours, can follow another's view, and can pin comments to parts.
rules:
  - Undo takes back only a person's own changes.
  - The chat, and comments in a session, are for people 13 and over.
  - Comments pinned to parts are kept in the model's file.
title: Build together
nav: Build together
description: Build one model with other people, live, each in their own browser or the desktop app.
---

**File › Build together…** builds the model on your baseplate with others, at the same time. Each of you sees the others' parts go down, move and change colour as it happens, and their pointer with their name and the parts they have selected, each person in their own colour.

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
- **Follow** beside a name in **File › Build together…** puts your view where theirs is, and keeps it there as they turn it. Move the view yourself, or press **Stop**, to stop.
- A short chat is there for people 13 and over.
- A reload goes back into the session by itself, and sends what you had just changed. Leaving ends nothing for the others, even if you started the session.

## Comments on parts {#comments}

Select a part, then **Edit › Comments…** (or right-click the part, **Comment on it…**), write, and press **Pin**. A numbered dot in your colour stands over the part and moves with it. Press it to read the comment, and **Resolve** when it is done with; **Ctrl+Z** brings it back. **Edit › Comments…** lists them all, with resolved ones under **Show resolved**.

Comments are kept in the model's file, so saving, opening and sharing by link keep them. A shared link's page does not show them. In a session everyone 13 and over sees them as they are pinned.

## End it {#end}

**End the session** (you started it) or **Leave** (you joined). The model stays yours.
