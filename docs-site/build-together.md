---
panels: TogetherDialog
tools: point_at
ai: Build together puts several people on one model live, by a link, each in their own browser: each sees the others' parts, pointers and selections in their colours, can point a part out to everyone (Alt+W, for 5 seconds), can follow another's view, and can pin comments to parts. On a shared model's viewer, Build together deals the model out among up to four phones by a code, to build in real bricks.
rules:
  - Undo takes back only a person's own changes.
  - The chat, and comments in a session, are for people 13 and over.
  - Comments pinned to parts are kept in the model's file.
  - Someone in a session can send the others only words and parts.
  - A session opened to watchers has a page of its own, /live/<watch>; a watcher sees each part land and chats, and never changes the model. Only the designer gives a watcher who asked to build a seat.
  - Starting or joining a session is the person's own: an assistant sends them to File › Build together…, where they start one and send its link; no tool opens one, and it never says one cannot be had.
title: Build together
nav: Build together
description: Design one model with other people, live, each in their own browser; or build a shared model in real bricks together, each on their own phone.
---

There are two ways to build with other people:

- **Design together**: everyone works on the same model in the app at once, each in their own browser. **File › Build together…**.
- **Build a shared model together** in real bricks: each of you on your own phone gets a share of it to build, with no account. **Build together** on [its viewer](/docs/model-pages#viewer).

## Design together {#design}

**File › Build together…** puts the model on your baseplate in front of others, live. Each of you sees the others' parts go down, move and change colour as it happens, and their pointer with their name and the parts they have selected, each person in their own colour.

<!-- covers
ui:build together
lib:building together
api:POST /api/together
-->

### Start a session {#start}

1. **File › Build together…**, then **Start a session**.
2. **Copy link**, and send it to whoever you are building with. Anyone signed in who opens it joins (`/app?together=<secret>`), until you end the session.
3. The dialog lists who is in, each in their colour, *here* or *away*. Beside each, you can **Remove** them.

![File › Build together…, before a session: what building together does, Start a session, and a box to paste a link someone sent you with Join.](/docs/img/together-dialog.webp "File › Build together…")

### Join {#join}

Open the link someone sent you and sign in. Or paste it in **File › Build together…** under **Or paste a link someone sent you**, and press **Join**.

### While you build {#while}

- **Undo takes back only your own changes**, never someone else's.
- **Point a part out**: put the pointer on it and press [[Alt+W]], or right-click it and choose **Point it out to the others**. Everyone in the session sees it outlined in your colour with your name over it for 5 seconds, and their status bar says who points at what. [[Esc]] takes yours back from everyone; on someone else's screen, Esc puts theirs away. Your Claude can point one out too, named as yours ([point_at](/docs/mcp-tools)).
- **Follow** beside a name puts your view where theirs is and keeps it there as they turn it; a bar over the view says *Following* with **Stop**. Moving the view yourself stops it too.
- A short chat is there for people 13 and over.
- Someone you build with can send you only their words and parts, never anything that runs.
- A reload goes back into the session by itself and sends what you had just changed. So does closing the tab: what you had just changed is sent as it closes, or, if it could not be, the next time you open Brickworks. Leaving ends nothing for the others, even if you started the session.

### Comments on parts {#comments}

Select a part, then **File › Comments…** (or right-click the part, **Comment on it…**), write in **Say something about this part**, and press **Pin**. A numbered dot in your colour stands over the part and moves with it. Press it to read the comment, and **Resolve** when it is done with; [[Ctrl+Z]] brings it back. **File › Comments…** lists them all, each with **Show**; tick **Show resolved** for the resolved ones, each with **Open again**.

Comments are kept in the model's file, so saving, opening and sharing by link keep them; a shared model's page does not show them. In a session everyone 13 and over sees them as they are pinned.

### Open it to watchers {#watch}

**Open to watchers**, under the link, gives the session a page anyone can watch, at `/live/<name>`. **Copy** its address to send it. While you build it is listed first on the home page, under *Building now*, and on your profile. The panel says how many are watching.

![A build being watched at /live/<name>: Building now over its title and its designer, how many watch with Ask to build and Copy link, the model in 3D as it stands, and the chat beside it with who is building.](/docs/img/live-watch.webp "Watching a build: each part lands as it is put down.")

![Building now, first in the home page's feed: a card for each build open to watchers, with Live on it, its title, who is building it and how many watch.](/docs/img/live-listing.webp "Building now, on the home page.")

- Watchers see each part land in 3D as you put it down, and the chat beside it. Signed in, anyone 13 or over can chat with you there; you read their lines in the panel's chat as you read your builders'.
- **Ask to build** on the watch page asks you for a seat. The panel shows *Wren asks to build* with **Give a seat**. Once you give one, their page offers **Build with them now**, which opens the session in their studio. **Remove** takes them out again.
- Nothing a watcher does changes the model. Their page has no way to, and the server refuses it.
- **Close to watchers** closes the page (it says so) and takes the build off the lists; the session goes on.

<!-- covers
ui:watching a build live
ui:building now listed
-->

### End it {#end}

**End the session** (you started it) or **Leave** (you joined). The model stays yours. If the session was open to watchers and the model is shared, ending it keeps where it got to as a version in the model's log, as **Share progress** does.

> [!NOTE]
> The desktop app is coming soon. It will join a session by the same link, or with `--together=<secret>` at start-up.

## Build a shared model together {#party}

Up to four people can build one shared model in real bricks at once, each on their own phone, tablet or computer, with no account.

1. Everyone opens the model's viewer (`/app?view=<id>`: on its page, **View in 3D**, then **Open in the app**) and presses **Build together** beside **Build it**. Each can give a name in **Your name (you can leave it out)**, or be *Builder 2*.
2. One of you presses **Start a build** and gets a code of four letters and numbers.
3. The others type it under **Code** and press **Join**.
4. When everyone is in, the one who started presses **Start building** (*Start building: 3 phones*).

![Build together on a shared model's viewer: what it does, a box for your name, Start a build, and a box for a code with Join.](/docs/img/build-party.webp "Build together, on a shared model's viewer.")

Brickworks deals the model out: each sub-assembly whole to one person, and the main build cut into runs of its steps when there are more people than parts. Each person's Build it then has only their own steps, and along its top everyone's progress (*Mia 4 of 9*). Done first, you wait on your last step, built. When everyone is done, everyone is shown the last step, which puts the parts together: the others' parts outlined where they go on.

**Close** mid-build puts the card back, with **Back to building** and **Leave the build**. Join again with the same code, kept on that device, and you are back on your own share where you left it. A build lasts a day.

<!-- covers
ui:build party
-->
