---
panels: SharePanel#share
ai: Sharing publishes a model at brickworks.diy/m/<id>, and in the gallery only when List it in the gallery is ticked, with its steps, booklet, motions and moving parts. It is tested for being buildable, gets new versions when shared again, and credits what it was remixed from.
rules:
  - Sharing needs the person signed in, and is the person's to do: no tool shares a model.
  - Names, tags and words are checked; brands and trademarks are refused in titles, tags and handles.
title: Sharing a model
nav: Sharing a model
description: Publish a model at a link anyone can open in 3D, step through and build, list it in the gallery, update it with new versions, or take it down.
---

Sharing gives a model a link anyone can open with no account: the model in 3D, its building steps, the booklet and the parts list. It is **File › Share…**, or **Share** on the toolbar, once there are parts on the baseplate. You need to be signed in: signed out, the panel has **Sign in** beside **Publish**, and on a phone the greyed Share row in **More** says why.

## Share a model {#share}

1. Turn the view to show the model as you want it seen: its picture is taken from where the view is looking.
2. **File › Share…**.
3. Give it a **Name**: the model's own, or, for one never named that is a single minifigure or sub-assembly, that one's. **About it (shown on its page)** says what it is, up to 1,000 characters; **Tags** help people find it; **Kind** is guessed from the name, the tags and About, and you can change it.
4. Choose a **Licence**: **CC BY 4.0** (anyone may share and change it, crediting you), **CC BY-SA 4.0** (and what they make is shared the same way) or **All rights reserved** (people may build it for themselves and ask you before sharing it).
5. Tick **Show who made it** to put a name on its page: **The name to credit** is your profile's name when you have one.
6. Tick **List it in the gallery** to put it in [the gallery](/docs/gallery) as well. Unticked, only people you send the link to find it.
7. Press **Publish**. Publishing means you agree to the [guidelines](/guidelines).

![The Share this model panel: Name, Show who made it with the name to credit, About it, Tags and Kind side by side, Licence with what it lets others do, List it in the gallery, then Publish and the guidelines.](/docs/img/sharing-panel.webp "File › Share…, before it is published.")

<!-- covers
ui:share panel
-->

Its link is `brickworks.diy/m/<id>`. Once it is published the panel shows the link, with **Copy link**, **Copy embed code** (a frame to paste into a page of your own; see [the embed](/docs/model-pages#actions)) and **Open**, and the line under Publish says what was shared: *Shared at this link, 187 parts*, and whether it is listed in the gallery and marked Tested.

![The Share panel once published: Publish now reading Update the link, then the line Shared at this link and listed in the gallery with its Tested mark, the link, Copy link, Copy embed code and Open, and Unpublish.](/docs/img/sharing-published.webp "The panel once the model is published.")

Anyone with the link can download the model's file itself. An email address in its **Author** line, and the folders on your computer that a program wrote into it (a background picture's, a parts folder's), are left out of the shared copy, however it is shared.

Its build steps, its booklet's layout, its motions and what moves in it go with it, so whoever opens the link can step through it, read its booklet and play it. A model with motions of its own has **Opens** in the link box: **Still**, or **Playing** one of its motions, and the link then [opens with that motion playing](/docs/model-pages#play).

The first time you open your model's page after publishing, signed in, your browser records the model turning once round while the page is open: four seconds, a seamless loop, drawn as the page's 3D view draws it, without slowing the page. Its link then turns where it is pasted: Discord, Slack and other sites that play a link's video play the clip where they showed the picture (X keeps its large picture), and the embed plays it too when its address ends in `?autoplay=1`, with **Pause** and **Play** in its corner. Update the link and your next visit records the new version; until then the link shows the picture. The clip is deleted when you unpublish the model or delete your account.

<!-- covers
lib:steps carried with a shared model
lib:what moves in a model
lib:build pages
ui:the model turning in its link's preview
-->

## Share a model's file from the site {#from-a-file}

A model made in BrickLink Studio, LDCad, MLCad or another LDraw program can be shared without opening it in the app: **Share yours** in [the gallery](/docs/gallery) opens [brickworks.diy/share-model](/share-model).

1. **Choose a file**, or drop it on the page: an LDraw file (`.ldr`, `.mpd` or `.dat`) or a BrickLink Studio file (`.io`). It is read in your browser, and nothing is sent until you share it. A file that is no model is refused, saying why.
2. Its **Name** is read from the file; change it if you like. **What it is**, the **Licence** and **List it in the gallery** are as in the app.
3. Press **Share it**. Signed out, you are asked to sign in first.

The model is sent, its picture is drawn on the page from the model as Brickworks reads it and put on its page, and you arrive on its own page: its parts list counted from the file, the steps the file lays out, and its picture. It counts as one publish, as sharing from the app does; after a lot of sharing in an hour, the page says so before anything is shared, and keeps your file and words while it is open. The form says what was left out of the file (an email address in its Author line, folders on your computer), and anyone with the link can download the rest. The same is left out however a model is shared: from here, from the app, or by your Claude. A Studio file's parts made in Part Designer go with it; Studio's own prints and stickers show as their plain parts. A LEGO® Digital Designer file (`.lxf`) opens in the app instead (**File › Open…**, then **File › Share…**), which turns its parts into LDraw's.

<!-- covers
ui:share a model file from the site
lib:a BrickLink Studio file read in the browser
lib:a file's private lines left out of a shared model
-->

## The Tested mark {#tested}

As a model is shared, Brickworks builds it by its own steps and tests whether a person could:

1. **It stands at every step.**
2. **Every step can be reached**: no part is put down in the air or behind what is already built.
3. **Every part is made in its colour.**
4. **Nothing is loose**: it is one piece, every part held by a stud, a joint or what catches it, and no part passing into another.

A model that passes carries **✓ Tested** on its card and its page. One that does not says which test it failed, to you alone, in the panel and on its page.

<!-- covers
lib:the Tested mark's four tests
lib:the Tested mark kept and shown
-->

## Update it {#versions}

Change the model, then **File › Share…** again from the same model: **Publish** now reads **Update the link**. **What changed? (shown with the new version)** takes up to 280 characters, such as *Fixed the roof; the door opens now*.

The link then shows the new version, and the one before is kept at its own address, `/m/<id>/v/<n>`: *Version 2 is up at this link, and version 1 is kept at its own*. The model's page says **Version 2**, and its **Versions** tab lists the **Earlier versions** with what changed in each. Someone who built an earlier one and opens Build it again is told *This model changed from step 12*, with **Go to step 12**.

<!-- covers
lib:versions of a shared model
-->

## Remixes and credit {#remix}

**Open in Brickworks** on any model's page copies it into your own models. Share your changed copy and its page says *Remixed from* the original, and the original's **Remixes** tab lists yours. A model opened from [the LDraw library](/docs/ldraw-library) keeps the name of whoever modelled it, and its page credits them, whoever shares it.

<!-- covers
lib:who modelled a shared model
-->

## Take it down {#unpublish}

**Unpublish** in the link box takes the model off its link and out of the gallery; the link then says it is no longer shared. Every version goes with it. Your saved model is untouched, and **Publish again** brings it back at the same link, as version 1.

To leave the gallery but keep the link, untick **List it in the gallery** and press **Update the link**.

## Who can share {#who}

Brickworks accounts are for people 13 and over, and an account marked under 13 can share nothing, by link or in the gallery. An account that has not yet answered the one question Brickworks asks everyone is told to sign in again and answer it before it lists a model. A model Brickworks took out of the gallery can still be shared by link, never listed again.

## Names and words {#names}

Names, tags and words on the site are checked: abuse is refused in any of them, and names somebody else owns (a brand, a trademark) are refused in titles, tags, credits and handles.

<!-- covers
lib:names filter
-->
