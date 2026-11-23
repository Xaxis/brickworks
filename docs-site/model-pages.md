---
panels: ShareView#viewer, BuildMode#build-it
ai: A shared model's page: its picture turned in 3D, Build it (the steps played as a booklet, a step or a part at a time), moving its parts, pictures, likes, comments, builds, remixes, its Log of versions (work in progress marked) and its parts list to download; and With your Claude, beside Open in the studio, a message for the person's own Claude that opens a copy (open_model link=) and changes it as asked, credited to the model when the copy is published.
rules:
  - Anyone can open a model's page with no account.
  - Its parts download as a BrickLink XML, a Rebrickable CSV or a LEGO® Pick a Brick CSV, and the model as LDraw (.mpd).
title: A model's page
nav: A model's page
description: Look at a shared model in 3D, build it step by step or part by part, move it, and like, save, comment on or download it.
---

A shared model's page is where anyone, with no account, looks at it in 3D, builds it and takes its parts list to a shop. It is at `brickworks.diy/m/<id>`: press a card in [the gallery](/docs/gallery), or open a link someone sent you.

<!-- covers
ui:shared model page and card
-->

![A model's page: the model's picture with View in 3D, its pictures and the tabs Overview, Comments, Parts, Builds and Remixes under it, and beside it its name and designer, Build it, Open in the studio with With your Claude, the bar of Like, Save, Share and More, and its facts.](/docs/img/model-page.webp "A shared model's page.")

## Look at it in 3D {#viewer}

**View in 3D** on the picture turns it into the model, right there: drag to turn it, zoom, or go full screen. **Open in the app** opens the app's viewer (`/app?view=<id>`), with **Build it**, **Steps**, **Booklet** and **Parts list** on its bar; nothing there can change the model. The app's header stays over it, as over every part of the app: the Brickworks mark at the left, the way back to the home page, and **Menu** and **Account** at the right; Build it and the viewer's own bar sit under it.

<!-- covers
ui:shared model viewer
-->

### In your room {#in-your-room}

On a phone or a tablet, **In your room** on the picture's foot puts the model in your room at its real size, through the camera (AR Quick Look on an iPhone or iPad, the browser's own AR on Android). **Place it in your room**, set it on the floor or a table, and pinch to change its size. A model over 32 MB as a 3D model is too big for a phone, and the page says so.

<!-- covers
ui:the model in your room
-->

### Build it {#build-it}

**Build it** plays the steps as a booklet does, the new parts shown going on.

1. Press **Build it** beside the picture; **Start** on the cover begins.
2. **Next** and **Back** turn the pages, as do the arrow keys, Space, or a swipe across the top or bottom bar; [[Home]] goes to the cover, [[End]] to the last page, a tap on the progress bar to that step.
3. **Whole step**, where you start, shows each step as the booklet does. **One part** shows the next part alone in its colours, the rest faded, with *3 of 8 in this step* under its picture: Next puts that part down, Back takes it off, and the last part's Next goes on to the next step. The choice is kept on that device.
4. **Finish** on the last page, or **Close**.

A step whose parts go on from below is shown turned over, as its booklet page is. A comment's step pill opens Build it at that step (`/app?view=<id>&step=<n>`).

![Build it a part at a time: the model built so far, faded, with the next part outlined in its colours, and under it the part's picture with 3 of 8 in this step, its name, One part chosen over Whole step, and Back and Next.](/docs/img/build-it.webp "Build it, One part.")

<!-- covers
ui:build it step player
ui:open a shared model at a step
-->

### Show your build {#show-your-build}

Built it in real bricks? Show it, right where the build ends.

1. On the last step, a card under the top bar says how many people have built the model, with **Show your build**. The viewer's timeline shows it too when you step onto its last step, and so does the viewer after **Finish**.
2. Press **Show your build**. On a phone the camera opens; on a computer, choose a photo. It comes back on the card the right way up.
3. Say something about it if you like, then **Post**. The card says **Posted: on the model's page**, a link to your photo there. It leads the model's **Builds** strip and the gallery's [Builds](/docs/gallery#builds) tab, and the model's designer is told in their [notifications](/docs/profiles#notifications).

Building needs no account; posting does. Not signed in, **Post** asks you to sign in there and then, over the step you are on, and brings you back to it with your photo still chosen, ready to post. **Not now** goes back without signing in. Photos are for accounts of people 13 and over, at most three of yours on a model. What the camera wrote into the photo (where and when it was taken, the phone) is taken out before anyone sees it, as for a photo added on the model's page. On your own model the card says **Add a photo of your build**: it goes with your own pictures of it.

![The last step of Build it: under the top bar, a card saying 14 people have built it, with Show your build beside it, the finished model below, and Finish at the bottom.](/docs/img/show-your-build.webp "Show your build, on the last step.")

<!-- covers
ui:show your build
-->

### Where does this part go? {#where-does-this-go}

Holding a part and can't find its step? Press **Where does this go?** (the camera beside the step's words) and take a photo of it, or choose a picture on a computer.

1. The first time, Build it says where the photo goes: to Brickognize, a service that recognises parts. Only the photo is sent, never the model, and nothing goes until you choose one. Agreeing here or in the parts bin counts for both.
2. Build it goes to the first step you haven't built yet that uses that part, with the part's place outlined. Building **One part** at a time, it goes to that part itself.
3. A card under the top bar names the part and its colour. If the part goes in more than one step, it says how many and lists them, each a button. **Not it?** offers Brickognize's other guesses, and **Back to step N** takes you back to where you were.

If every step that uses the part is already built, it says so: the part may be a spare, since sets come with a few. An assistant can do the same with `edit_steps` and a photo (see [edit_steps](/docs/mcp-tools#edit_steps)).

<!-- covers
ui:where does this part go
-->

### Build together {#build-together}

**Build together** on the viewer's bar shares the model out among up to four people, each on their own phone: see [Build a shared model together](/docs/build-together#party).

### Play with it {#play}

A model with something that moves says so (*Moves: steering, boom*): drag a part that moves and it moves on its real joints; **Reset** puts it back. Its own motions are buttons to play.

<!-- covers
ui:play in a shared model
-->

A link the Share panel's **Opens** wrote (`?motion=lift-the-boom`, or `?motion=boom`) opens it playing that motion there and back until you press its button, or once with **Reduce motion** on.

<!-- covers
ui:a link that opens playing
-->

## Pictures and tabs {#tabs}

Under the picture is a strip: the published picture, its designer's photos (**Add a picture**, up to three) and photos of real builds people sent; choose one to see it large. Then the tabs: **Overview** (what its designer wrote, its tags, its licence and the public lists it is in), **Comments**, **Parts**, **Builds**, **Remixes**, and **Log** once it has [more than one version](/docs/sharing#versions) or is [work in progress](/docs/sharing#progress), each with its count. Only the tab you choose shows, and each has its own address, so a link to `/m/<id>#comments` opens on its comments and Back goes to the tab before. The arrow keys move between them. An empty tab says so in a line, with the way to be the first.

<!-- covers
ui:model page pictures and tabs
ui:an object's page and its tabs
-->

## The Log {#log}

The **Log** is every version its designer published, the newest first. Each has its picture, the day it was published, what changed from the one before (*8 parts added in step 21*) and what its designer wrote with it, and opens that version at its own address, `/m/<id>/v/<n>`. Above them is what changed in the version you are looking at, part by part.

A model still being built is marked **Work in progress** at the top of its page and in its Log, each version shared so marked too. Its designer sees **Mark it finished** there: the newest version becomes the finished one, marked **Finished**, said in its Talk thread and to their followers, and the model then ranks in the gallery as any other ([Share progress](/docs/sharing#progress)).

![A model's Log while it is being built: the Work in progress mark and what it means, what changed in version 3 and its note, then every version newest first, each with its picture, its date, what changed and its note, versions marked Work in progress.](/docs/img/model-log.webp "The Log of a model shared as work in progress.")

<!-- covers
ui:a model's log
-->

## The buttons {#actions}

- **Build it**, and **Open in the studio** ([a copy in your own models](#open), to change yourself) with its second half, **With your Claude** ([below](#with-your-claude)).
- **Like**, and **Save** (into Saved at a tap, or by its arrow into any of [your lists](/docs/lists#save-card): the same control a card has). Each signs you in on the way if it must.
- **Share**: **Copy link**; **Post it to** Reddit, Bluesky, Pinterest, X, Facebook or Email, each in a new tab; and **Embed it in a page**, whose **Copy code** puts the model's picture and name, with View in 3D and Build it, in a page of your own (`/m/<id>/embed`). Pasted into a blog, Notion or a forum that reads oEmbed, the bare link becomes that embed by itself.
- **Built** says you built it, with a photo if you like; what the camera wrote into it is taken out first. Building it with [Build it](#build-it), its last step offers the same photo where you finish ([Show your build](#show-your-build)).
- **More** has **Report it** and **Takedown requests**; on your own model, **Turn comments off** instead, and, for a model made with the assistant or Brickify, **Say it was made with the assistant** (or **with Brickify**): nothing on the site says how a model was made until you choose to, and **Stop saying it was made with the assistant** takes it back. Its page then says **With the assistant** among its facts, and the gallery's **Made: With the assistant** lists it.
- **I built it: add a photo**, on the **Builds** tab, says you built it, with a photo if you like; what the camera wrote into it is taken out first. Building it with [Build it](#build-it), its last step offers the same photo where you finish ([Show your build](#show-your-build)).
- **More** has **Download** (the model as LDraw, `/m/<id>.mpd`), **Report it** and **Takedown requests**; on your own model, **Turn comments off** instead.
- On your own model, **Enter this month's challenge** ([the challenge](/docs/challenges#enter)).

![The Share sheet of a model's page: its link with Copy link, Post it to Reddit, Bluesky, Pinterest, X, Facebook and Email, and Embed it in a page with Copy code.](/docs/img/model-share.webp "Share, on a model's page.")

<!-- covers
ui:model page action bar
ui:the embed in 3D
lib:real builds: finishes counted and photos of builds
lib:a build photo made safe
ui:enter this month's challenge
-->

## Change it with your Claude {#with-your-claude}

Your own Claude can open a copy of any model here and change it as you ask, through the [Brickworks connector](/docs/connector).

1. Press **With your Claude**, the second half of **Open in the studio** (on a phone it says **Claude**).
2. Under **What should it change?** say what you want, or leave it empty and Claude asks you: *make the roof dark blue*, *add a flag on top*, *put it on a stand with a nameplate*. It takes 500 characters.
3. Press **Copy for Claude** and paste the message into a new chat with your Claude. On a phone, **Share to Claude** hands it to the Claude app. The message names the model's link and the one call that opens it, `open_model link=<id>`.
4. Claude opens a copy in your models, changes it and shows you; the shared model stays as it was. Publish the copy (**File › Share…**) and its page says **Remixed from** this model, and which version it was copied from.

No connector yet? **Connect Claude** goes to [Connect your AI](/docs/connect#with-your-claude), and your message waits at the top of that page, to copy once Claude is connected.

![A model's page with Open in the studio and its second half, With your Claude, pressed: under them Change it with your Claude, What should it change? with Make the roof dark blue typed, Copy for Claude, and No connector yet? Connect Claude.](/docs/img/model-claude.webp "With your Claude, on a model's page.")

<!-- covers
ui:change a model with your Claude
-->

## Open in the studio: a copy to change {#open}

**Open in the studio** opens the studio with this model on the baseplate, never the example car. Signed out, it is there behind the studio's sign-in, which says it opens as your own copy: sign in with your email's code or with orangecheck (a new account answers the age question first) and you come back to it. Signed in, the copy is saved in your models under the model's name, credited to this page (its page says *Remixed from* once you [share it](/docs/sharing#remix)), and framed whole. The page you came from stays as it was.

The first time, three things to do with it are offered along the top of the model: **Recolour a part** takes the Paint tool, so a colour and then a part paints it; **Add a part** opens the parts with their search ready; **Build it** plays the timeline from the first step. Your first change, [[Esc]] or **×** puts that line away, and it is not offered again.

Pressed again a moment later, in the same tab after a reload or in a second tab, Open in the studio opens the copy you made rather than making another. Signed in to the site in another tab while the studio waits at its sign-in, the studio carries on by itself.

<!-- covers
ui:open in brickworks for a stranger
ui:a copy's first acts
-->

## Comments {#comments}

Comments are newest first, each with **Reply**. A comment can name a step, and its pill opens Build it there. People 13 and over can comment; a model's designer can turn comments off.

### Mention someone {#mentions}

Type **@** and the people on the page are offered, its designer first; keep typing to narrow it, and [[Enter]], [[Tab]] or a click puts one in. Any public `@handle` works typed in full. Each person named becomes a link and hears of it in their [notifications](/docs/profiles#notifications): up to three a comment, once each, however often it is edited.

### On a part {#on-a-part}

In the page's 3D view, or in the app's viewer of a shared model, right-click a part, or touch and hold it, and choose **Comment on this part**. With the keyboard, turn the model until the part is in the middle and press [[Shift+F10]] or the menu key. Your comment then starts "On the 2 × 4 brick" (choose **Cancel** to comment on the whole model instead) and keeps the part: its number, its colour, where it stands and its line in the file.

![The Comments of a model's page: Ivy Hart's comment on the 2 × 4 brick, step 12, with its pin's number, then Jon Reyes's on the whole model, and under them Resolved (1), Jon Reyes's comment on the 2 × 2 plate folded away.](/docs/img/comments-on-parts.webp "Comments on parts, on a model's page.")

Each one shows in 3D as a small numbered dot on its part, and its comment says where: "on the 2 × 4 brick, step 12". Press that line to turn the view to the part. On a newer version, the dot stays on the same part. A part that moved up to 20 LDU since is followed, marked *moved since*. A part that was taken off, recoloured or swapped gets no dot, and its comment names the version it was made on ("on version 1"), so a comment is never shown on a part it was not about.

When the model's designer opens it in the app, the notices say how many comments on parts are still open. **Show** lists them, and choosing one lights its part and frames it. **Resolve** marks one done: on the page it folds away under **Resolved**, and **Open it again** brings it back. A comment on a part notifies its designer like any comment, saying it is "on a part".

<!-- covers
ui:comment threads on a model page
ui:comments on a step
lib:comments on a shared model
lib:replies to a comment
lib:mentions in comments
ui:comment on a part in 3D
lib:comments pinned to parts
ui:comments on parts in the studio
-->

## Parts and download {#parts}

The **Parts** tab lists every part by **Colour** or by **Kind**. Download it for a shop: **BrickLink XML** (`/m/<id>/parts.xml`), **Rebrickable CSV** (`/m/<id>/parts.csv`) or **LEGO® Pick a Brick CSV**.

### What you're missing {#missing}

Signed in, the tab says how much of the model [your collection](/docs/collection) holds, counted as the gallery's cards count it: *You have 138 of its 187 parts (73%): 49 missing, in 19 lots.* Under it, **All**, **Missing** and **Have all** show every lot, only the lots you are short of (each with how many more you need and how many you have), or the lots you have every one of. With **Missing** chosen, **BrickLink XML**, **Rebrickable CSV** and **LEGO® Pick a Brick CSV** download just the missing parts, to buy them. When you have every part it says *Have all 187 of its parts.*

Parts nobody owns on their own (stickers, parts made for the model) are not counted, and the Pick a Brick list leaves off a part with no LEGO® element number known; the tab says how many of each. The element numbers come from Rebrickable's list of LEGO® elements; whether Pick a Brick has each one in stock today, its own upload tells you.

![A model's Parts tab, signed in with a collection: You have 138 of its 187 parts (73%): 49 missing, in 19 lots; All, Missing and Have all with how many lots each, Missing chosen; BrickLink XML, Rebrickable CSV and LEGO® Pick a Brick CSV of just those; and the lots short, each with how many more and how many you have.](/docs/img/parts-missing.webp "What you're missing, on a model's Parts tab.")

![What you're missing on a phone: how much of the model you have, All, Missing and Have all, the three shops' lists of the missing parts on rows of their own, and the first lots short.](/docs/img/parts-missing-phone.webp "What you're missing, on a phone.")

<!-- covers
ui:a model's parts and its download
-->

## What it is based on {#based-on}

Under its name a page credits what the model came from: a **remix** names the model it was copied from. On your own model's page, **Say what it is based on** adds up to three: **An alternate build of a set** (by its number, such as `6080-1`), **Changed from** or **Inspired by** a set or work elsewhere (its `https://` address and title, and its author and licence if known). Each set's page lists the models based on it. **Change what it is based on** changes or removes them.

### Built from a set {#built-from-a-set}

When a model is published, Brickworks counts it against every set Rebrickable lists, by the rules [your collection](/docs/collection) is counted by: another mould of a part counts as the part, colours are matched as the shops name them, and stickers and parts made for one model are left out. Under its name its page then says what it found:

- one set holds every part: *An alternate build of 31009 Small Cottage: every part from the set*;
- no one set does, but a few together do (the fewest, up to five): *An alternate build of 42115 and 42054*;
- one set holds 80% or more of it: *97% from 31009*.

Each set's name opens its page, where the model is listed under **Built from this set**. A model of the set itself (LDraw's model of 6080 King's Castle, say, opened from the set's page with [Make your own version](/docs/ldraw-library#every-set)) is that set's own model, not another build of it: it says *A version of LEGO® set 6080 King's Castle*, and the set's page lists it under **Versions of this set**. When its designer said it is an alternate build of a set and the set lacks some of its parts, the designer's own page says so after it, *(uses 6 parts not in the set)*; nobody else is shown that.

![Under a model's name and its designer: An alternate build of 910008 Modular Construction Site, 9764 Power Puzzle Challenge Kit and 11032 Creative Color Fun, each set a link to its page.](/docs/img/model-alt-build.webp "Built from three sets, as counted when it was published.")

<!-- covers
lib:what a model is based on
lib:alternate builds counted
-->

## What a remix changed {#remix-changes}

A remix's page says what it changed from the model it was copied from, under its credit: *What it changed from version 1: 42 parts added, 8 taken away, 3 recoloured, 5 moved*. It is counted once, when the remix is shared, against the version it was copied from, by the same rules as the app's [Compare](/docs/saving-and-files#compare): a part moved or turned counts as moved, one painted where it stands as recoloured, and one both moved and painted as one taken away and one added. The version is a link to that version's page.

![A remix's credit, Remixed from Sports car and its driver, and under it what it changed from version 1, with See what changed in 3D.](/docs/img/remix-line.webp "What a remix changed, under its credit.")

**See what changed in 3D** opens the 3D view with **What changed** on: the parts it added, moved or recoloured in their own colours, every other part faded, and the parts it took away drawn as faint red ghosts where they were; a line over the view counts them. **What changed** on the view's bar turns it off and on again; it is off when the view is opened by **View in 3D**. It works the same on a phone.

### The Remixes tab {#remix-tree}

A model's **Remixes** tab draws where it came from and what was made from it as a tree: up to the first model of the line, then the model itself (marked *This model*), then its remixes, their remixes and theirs, three levels down. Each card says what it is a remix of, and of what that was a remix, and what it changed: *A remix of Harbour by Ann, itself a remix of Lighthouse: 4 parts added, 2 recoloured*. A model shared only by its link is not named, and remixes not in the gallery are counted under the tree.

![A model's Remixes tab as a tree: the model, marked This model, and its remixes under it, each with its picture, name, maker and what it changed.](/docs/img/remix-tree.webp "The Remixes tab, both ways.")

<!-- covers
lib:what a remix changed
ui:what a remix changed and the remix tree
-->

## Send your change back {#send-back}

A pull request for LEGO® models. On your own remix's page, signed in, **Send your change back to its designer** takes a note (what you changed, and why) and **Send your change**: the designer's bell lights within a minute, and their model's page lists it with what it changes (*2 added, 1 taken away, 1 moved*), your note and **Open it in the studio**. Send it again after changing your remix and the one waiting is brought up to date; nobody else sees it.

In the studio the designer sees their model as they last published it with your change drawn on it: parts you took away in red, parts you moved in amber with a faint ghost where they go, parts you recoloured in violet, and a green ghost for each part you added. Each change is a row they can press to see it framed in the view and tick or untick, and each kind (added, taken away, moved, recoloured, swapped, to another step) has a box of its own. **Take all**, **Take the ticked** or **Decline**: nothing is taken until they press one. What they take opens as their model, not yet saved, with **Share** ready to publish it as its next version, and that version credits you on the model's page and in its Log: *With part of Priya's change from their remix "Sports car with a roof rack"*. You hear of it in your notifications.

![A model's page under its facts: With part of Priya Example’s change from their remix “Sports car with a roof rack”, version 4, and With Jon Reyes’s change from their remix “Sports car in blue”, version 3, each name, remix and version a link.](/docs/img/suggest-credit.webp "The changes a model took in from its remixes, credited on its page.")

<!-- covers
ui:a change sent back on a model's page
api:suggested edits
lib:a change sent back and taken
-->

## More by and similar {#more}

At the foot: **More by** its designer, by Top builds, and **Similar models**, by kind and shared tags.

<!-- covers
lib:more by and similar models
-->

## Report it {#report}

**Report it** (under **More** on a model, a profile or a list) tells Brickworks something should not be there; a copyright or trademark claim goes to [takedown requests](/takedown).

<!-- covers
ui:report it
ui:takedown page
-->
