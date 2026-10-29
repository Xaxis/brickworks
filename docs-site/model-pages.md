---
title: A model's page
nav: A model's page
description: Everything on a shared model's page, from the 3D viewer and Build it to likes, comments, builds and the parts list.
---

Every shared model has a page at `brickworks.diy/m/<id>`, which anyone can open with no account.

<!-- covers
ui:shared model page and card
-->

## The viewer {#viewer}

The model opens in 3D at the top of its page: turn it, zoom, look from any side, step through its build, and open its booklet and parts list. In the app, `/app?view=<id>` opens the same model to look at; nothing there can change it.

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

Under the picture is a strip: the published picture, its owner's photos and photos of real builds people sent; choose one to see it large. Its owner can **Add a picture**. Then the tabs: **About**, **Comments**, **Builds**, **Remixes**, **Versions** and **Parts**.

<!-- covers
ui:model page pictures and tabs
-->

## The action bar {#actions}

- **Like** and **Save** (to your Favourites or one of [your collections](/docs/collections)) sign you in on the way if they need to.
- **Share** copies the link, or opens your device's share sheet.
- **Comment** goes to the comments.
- **I built it** says you built it, with a photo of your build if you like; the photo is cleaned of what the camera wrote into it before it is kept.
- **More** has the code to embed the model in a page of your own (`/m/<id>/embed`) and **Report it**.
- On your own model's page, **Enter this month's challenge** sits under Like ([the challenge](/docs/challenges)).

<!-- covers
ui:model page action bar
lib:real builds: finishes counted and photos of builds
lib:a build photo made safe
ui:enter this month's challenge
-->

## Comments {#comments}

Comments are newest first, with **Reply** under each. A comment can name a step of the build: its pill opens the viewer at that step, and the app's timeline counts each step's comments. People 13 and over can comment; a model's owner can turn comments off.

<!-- covers
ui:comment threads on a model page
ui:comments on a step
lib:comments on a shared model
lib:replies to a comment
-->

## Parts and download {#parts}

The **Parts** tab lists every part by colour or by kind, each drawn by Brickworks, with **Show all**. Download it for a shop: a BrickLink wanted list (`/m/<id>/parts.xml`), a Rebrickable CSV (`/m/<id>/parts.csv`), or the list as JSON. **Download** gives the model itself as LDraw (`/m/<id>.mpd`).

<!-- covers
ui:a model's parts and its download
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
