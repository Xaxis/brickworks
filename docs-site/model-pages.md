---
panels: ShareView#viewer, BuildMode#build-it
ai: A shared model's page: the 3D viewer, Build it (the steps played as a booklet), moving its parts, pictures, likes, comments, builds, remixes, versions and its parts list to download.
rules:
  - Anyone can open a model's page with no account.
  - Its parts download as a BrickLink XML, a Rebrickable CSV or JSON, and the model as LDraw (.mpd).
title: A model's page
nav: A model's page
description: Everything on a shared model's page, from the 3D viewer and Build it to likes, comments, builds and the parts list.
---

Every shared model has a page at `brickworks.diy/m/<id>`, which anyone can open with no account.

<!-- covers
ui:shared model page and card
-->

![A model's page: its picture with View in 3D, its tabs, and beside it Build it, Open in Brickworks, Download and the action bar.](/img/docs-model.webp "A shared model's page.")

## The viewer {#viewer}

**View in 3D** on its picture opens the model in 3D: turn it, zoom, look from any side, step through its build, and open its booklet and parts list. In the app, `/app?view=<id>` opens the same model to look at; nothing there can change it.

<!-- covers
ui:shared model viewer
-->

### Build it {#build-it}

**Build it** on the viewer's bar plays the steps as a booklet does, a step at a time, the new parts shown going on, on a phone, a tablet or a computer. A comment's step pill opens it at that step (`/app?view=<id>&step=<n>`).

<!-- covers
ui:build it step player
ui:open a shared model at a step
-->

### Play with it {#play}

A model with something that moves says so under the bar (*Moves: steering, boom*): drag a part that moves, with the mouse or a finger, and it moves on its real joints. **Reset** puts it back. Its own motions are buttons to play.

<!-- covers
ui:play in a shared model
-->

## Pictures and tabs {#tabs}

Under the picture is a strip: the published picture, its owner's photos and photos of real builds people sent; choose one to see it large. Its owner can **Add a picture**. Then the tabs: **About**, **Parts**, **Comments**, **Builds**, **Remixes**, **Collections**, and **Versions** once it has more than one.

<!-- covers
ui:model page pictures and tabs
-->

## The action bar {#actions}

- **Build it**, **Open in Brickworks** (a copy in your own models) and **Download** are first.
- **Like** and **Save** (to your Favourites or one of [your collections](/docs/collections)) sign you in on the way if they need to.
- **Share** opens a sheet with the link and **Copy link**; **Post it to** Reddit, Bluesky, Pinterest, X, Facebook or email, each opening that site's own page for sharing it in a new tab; and the code to embed the model in a page of your own (`/m/<id>/embed`), its picture and name with **Build it**. On a phone the sheet also offers your device's own share sheet. Paste the model's bare link into a blog, Notion or a forum that reads oEmbed and it becomes that embed by itself.
- **Comment** goes to the comments.
- **Built** (I built it) says you built it, with a photo of your build if you like; the photo is cleaned of what the camera wrote into it before it is kept.
- **More** has **Report it** and the takedown page.
- On your own model's page, **Enter this month's challenge** sits under Like ([the challenge](/docs/challenges)).

<!-- covers
ui:model page action bar
lib:real builds: finishes counted and photos of builds
lib:a build photo made safe
ui:enter this month's challenge
-->

## Comments {#comments}

Comments are newest first, with **Reply** under each. A comment can name a step of the build: its pill opens the viewer at that step, and the app's timeline counts each step's comments. People 13 and over can comment; a model's owner can turn comments off.

### Mention someone {#mentions}

Type **@** in a comment or a reply and the people on the page are offered: its designer, then whoever commented. Keep typing to narrow it; the arrow keys and **Enter** (or a click) put one in, **Escape** closes the list and keeps what you wrote. Any public profile's `@handle` works typed out in full.

Each person named becomes a link to their page and hears of it in their [notifications](/docs/profiles#notifications), with what you said. Up to three people a comment are told, once each, however often it is edited. Nobody is told twice: the model's designer already hears of every comment, and someone in the conversation hears of each reply. Hiding or deleting the comment takes the notification with it.

<!-- covers
ui:comment threads on a model page
ui:comments on a step
lib:comments on a shared model
lib:replies to a comment
lib:mentions in comments
-->

## Parts and download {#parts}

The **Parts** tab lists every part by colour or by kind, each drawn by Brickworks, with **Show all**. Download it for a shop: a BrickLink wanted list (`/m/<id>/parts.xml`), a Rebrickable CSV (`/m/<id>/parts.csv`), or the list as JSON. **Download** gives the model itself as LDraw (`/m/<id>.mpd`).

<!-- covers
ui:a model's parts and its download
-->

## What it is based on {#based-on}

Under its name, a model's page credits what it came from. A **remix** names the model it was copied from on Brickworks. Its designer can say more, up to three, with **Say what it is based on** on their own page:

- **An alternate build of** a LEGO® set: built from that set's parts, given by its number such as `6080-1`, which links to the set's page here;
- **Changed from** a set, or from work elsewhere, given by its `https://` address with its title, and its author and licence when known;
- **Inspired by** a set or work elsewhere.

Brickworks checks a set's number against the library, and says in words what is wrong with a set it has not got or an address that is not one. A link to work elsewhere is the designer's, and marked as not Brickworks's. Search engines read them in the page too, and each set's page lists the models in the gallery based on it. **Change what it is based on** changes or removes them. An account under 13 does not show a name or link in public, so it is not offered.

<!-- covers
lib:what a model is based on
-->

## More by and similar {#more}

At the foot of the page: **More by** the designer, their other models by Top builds, and **Similar models** by kind and shared tags.

<!-- covers
lib:more by and similar models
-->

## Report it {#report}

**Report it** (under More on a model, and on a profile or a collection) tells Brickworks about something that should not be there. For a copyright or trademark claim, see [takedown requests](/takedown).

<!-- covers
ui:report it
ui:takedown page
-->
