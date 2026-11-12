---
panels: ShareView#viewer, BuildMode#build-it
ai: A shared model's page: its picture turned in 3D, Build it (the steps played as a booklet, a step or a part at a time), moving its parts, pictures, likes, comments, builds, remixes, versions and its parts list to download.
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

![A model's page: the model's picture with View in 3D, the tabs About, Parts, Comments, Builds and Remixes under it, and beside it its name and designer, Build it, Open in Brickworks, Download, and the bar of Like, Save, Share, Comment and Built.](/docs/img/model-page.webp "A shared model's page.")

## Look at it in 3D {#viewer}

**View in 3D** on the picture turns it into the model, right there: drag to turn it, zoom, or go full screen. **Open in the app** opens the app's viewer (`/app?view=<id>`), with **Build it**, **Steps**, **Booklet** and **Parts list** on its bar; nothing there can change the model.

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

![Build it a part at a time: the model built so far, faded, with the next part in its colours, and on the card the part's picture, its name and 3 of 8 in this step, with One part chosen over Whole step, and Back and Next.](/docs/img/build-it.webp "Build it, One part.")

<!-- covers
ui:build it step player
ui:open a shared model at a step
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

Under the picture is a strip: the published picture, its designer's photos (**Add a picture**, up to three) and photos of real builds people sent; choose one to see it large. Then the tabs: **About**, **Parts**, **Comments**, **Builds**, **Remixes**, **Collections** once it is in one, and **Versions** once it has [more than one](/docs/sharing#versions).

<!-- covers
ui:model page pictures and tabs
-->

## The buttons {#actions}

- **Build it**, **Open in Brickworks** (a copy in your own models) and **Download** (the model as LDraw, `/m/<id>.mpd`).
- **Like**, **Save** to your Favourites or one of [your collections](/docs/collections), and **Comment**. Each signs you in on the way if it must.
- **Share**: **Copy link**; **Post it to** Reddit, Bluesky, Pinterest, X, Facebook or Email, each in a new tab; and **Embed it in a page**, whose **Copy code** puts the model's picture and name, with View in 3D and Build it, in a page of your own (`/m/<id>/embed`). Pasted into a blog, Notion or a forum that reads oEmbed, the bare link becomes that embed by itself.
- **Built** says you built it, with a photo if you like; what the camera wrote into it is taken out first.
- **More** has **Report it** and **Takedown requests**; on your own model, **Turn comments off** instead.
- On your own model, **Enter this month's challenge** ([the challenge](/docs/challenges#enter)).

![The Share sheet of a model's page: its link with Copy link, Post it to Reddit, Bluesky, Pinterest, X, Facebook and Email, and Embed it in a page with Copy code.](/docs/img/model-share.webp "Share, on a model's page.")

<!-- covers
ui:model page action bar
ui:the embed in 3D
lib:real builds: finishes counted and photos of builds
lib:a build photo made safe
ui:enter this month's challenge
-->

## Comments {#comments}

Comments are newest first, each with **Reply**. A comment can name a step, and its pill opens Build it there. People 13 and over can comment; a model's designer can turn comments off.

### Mention someone {#mentions}

Type **@** and the people on the page are offered, its designer first; keep typing to narrow it, and [[Enter]], [[Tab]] or a click puts one in. Any public `@handle` works typed in full. Each person named becomes a link and hears of it in their [notifications](/docs/profiles#notifications): up to three a comment, once each, however often it is edited.

<!-- covers
ui:comment threads on a model page
ui:comments on a step
lib:comments on a shared model
lib:replies to a comment
lib:mentions in comments
-->

## Parts and download {#parts}

The **Parts** tab lists every part by **Colour** or by **Kind**. Download it for a shop: **BrickLink XML** (`/m/<id>/parts.xml`), **Rebrickable CSV** (`/m/<id>/parts.csv`) or **LEGO® Pick a Brick CSV**.

<!-- covers
ui:a model's parts and its download
-->

## What it is based on {#based-on}

Under its name a page credits what the model came from: a **remix** names the model it was copied from. On your own model's page, **Say what it is based on** adds up to three: **An alternate build of a set** (by its number, such as `6080-1`), **Changed from** or **Inspired by** a set or work elsewhere (its `https://` address and title, and its author and licence if known). Each set's page lists the models based on it. **Change what it is based on** changes or removes them.

<!-- covers
lib:what a model is based on
-->

## More by and similar {#more}

At the foot: **More by** its designer, by Top builds, and **Similar models**, by kind and shared tags.

<!-- covers
lib:more by and similar models
-->

## Report it {#report}

**Report it** (under **More** on a model, a profile or a collection) tells Brickworks something should not be there; a copyright or trademark claim goes to [takedown requests](/takedown).

<!-- covers
ui:report it
ui:takedown page
-->
