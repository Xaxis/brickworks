---
tools: gallery
ai: brickworks.diy/gallery holds the models people built and shared, searchable by words, kind, size, how it was made (by hand or with the assistant), instructions, Technic, Tested and the parts a person owns. An assistant searches it and reads a model as a reference with gallery, and opens a copy with open_model link=.
rules:
  - A gallery model carries its credit and licence; say them when it is used as a reference.
title: The gallery
nav: The gallery
description: Find a model to look at or build, by Top builds, what is new, who you follow, its kind, its size and the parts you own.
---

The gallery is where you find a model to look at or build: everything people built in Brickworks and shared, with its steps. It is at [brickworks.diy/gallery](/gallery), **Gallery** first at the top of every page of the site, beside **Challenges** and **Docs**. Anyone can browse it, with no account.

<!-- covers
ui:gallery page
api:GET/POST /api/share
lib:directory
-->

![The gallery's front on a computer: the Gallery heading and search, the tabs Top, New, Builds, Collections and Sets with All time beside them, Filters and the kinds as pills, then model cards, the first marked Week's pick, each with its picture, name, designer and part count.](/docs/img/gallery-top.webp "The gallery's front: Top, all time.")

## On the home page {#home}

The [home page](/) is a feed of what builders make and say. Signed out, one line over it says what Brickworks is, a search finds models, builders and real sets as you type, and **Start building** opens the app. Then the feed, one post after another:

- **A build**: who made it, with **Follow**; its picture; how it was made (**Designed with the assistant**, **Built by hand**, **Made with Brickify**) and what moves, each a link to that part of these docs; its likes, comments and **Share**; and four ways into the studio: **Open in the studio**, **Remix** (a copy of your own to change, its page saying whose it was), **Build it** (its steps, one at a time) and **Parts** (to list and buy). The newest comment is under it, with **Add a comment**.
- **A thread in [Talk](/docs/talk)**, with its latest reply and **Reply**.
- **This month's [challenge](/docs/challenges)**, its days left and its entries, with **Enter the challenge**.
- **Try the studio, right here**: **Try it here** puts the studio itself in the post, a model on it to turn, play with and build step by step. **Open the whole studio** opens a copy of it as yours.
- **Builders to follow**, and photos of models people [built for real](/docs/model-pages#actions).

![The home page on a computer: Gallery, Talk, Challenges and Docs across the top; Build, share and find LEGO® models over the search and Start building; then the feed's first row, This week's pick first, each post with who made it, its picture, how it was made, its likes and Open in the studio, Remix, Build it and Parts.](/docs/img/home-first-screen.webp "The home page: one line, then the feed.")

Press **3D** on a picture, or rest the pointer on it, to turn the model in its place; [[Esc]] puts the picture back. Like, a comment and Follow ask you to sign in there and then, and go on once you are in; what you typed is kept. **Show more** at the end adds more posts.

Signed in, the line gives way to the same search, with **Share a build** beside it, which opens [the share panel](/docs/sharing) in the app for your last model, and three tabs: **For you**, everything, as you have it; **Following**, what the people you follow made; and **New**, the newest first. The arrow keys move along the tabs. In the search, the down arrow moves into what it found, [[Enter]] opens one, or the gallery's own search with what you typed; [[/]] puts the cursor in it.

![The home page on a phone: Build, share and find LEGO® models, the search and Start building, and under them the feed's first post, a build with its picture and the studio's verbs.](/docs/img/home-phone.webp "On a phone, the feed starts in the first screen.")

<!-- covers
ui:the home page's feed
ui:the home page's search
-->

## Find a model {#find}

1. Choose a tab. **Top** puts first what people built most, remixed most and found Tested; views count for nothing. **New** is the newest first.
2. To narrow it, press a kind under the tabs: **Castles and fantasy**, **Space**, **Vehicles**, **Town and buildings** and so on to **Something else**.
3. Or type in **Search models, builders, tags**: a model's name, its designer, a tag or words from its description. The cards change as you type, and [[/]] jumps to the search from anywhere on the page. A misspelt word, and words run together or apart (`spaceship`, `space ship`), still find it.
4. Press a card to open [the model's page](/docs/model-pages).

On Top, **All time** beside the tabs changes to **This week** or **This month**: what was built and remixed in that time.

The address keeps the tab, the search and the filters (`/gallery?q=castle&kind=space&sort=newest`), so Back returns to them and a search can be sent to someone.

The gallery's list can also be asked for the models built from a set, as its page lists them: `/api/share?op=list&alt=31009-1` gives those with every part from 31009-1 or built from it with a few other sets, and `&from_one_set=1` only those with every part from a single set ([built from a set](/docs/model-pages#built-from-a-set)).

## Filters {#filters}

**Filters** opens a sheet. A number on the button says how many are on.

- **Order**: Top builds, Newest, Most liked, Most remixed, Most built, and, signed in with [your collection](/docs/collection), **Parts I own**, which puts first the models you own most of the parts for.
- **Size**: Any size; Small, under 200 parts; Medium, 200 to 999; Large, 1,000 parts or more.
- **Made**: **Hand-built** or **With the assistant**, as the app that shared it said.
- **Has instructions** (steps laid out by whoever built it), **Technic or mechanism**, **Tested only**.

Each filter that is on shows as a pill beside Filters; press its × to drop it, or **Clear all** when there are two or more. **Clear the filters** in the sheet drops them all. On a phone, Top's time is in the sheet too, as **Top over**.

![The gallery on a phone with Filters open: Order Top builds, Top over All time, Size Any size, Made By hand or with the assistant, the ticks Has instructions, Technic or mechanism and Tested only, and Clear the filters.](/docs/img/gallery-filters.webp "Filters, on a phone.")

<!-- covers
lib:model kinds
lib:Top builds and this week's pick
-->

## The tabs {#tabs}

The tabs are **Top**, **New**, **Following** (signed in: what the people you follow made), **Builds** ([photos of real builds](#builds)), **Collections** (the [directory of collections](/docs/collections#directory)) and **Sets** (every [real LEGO® set](/docs/ldraw-library#website)). A tab keeps the search's words, and has an address of its own (`/builds`, `/collections`, `/library`) to reload or send.

## More than 24 {#pages}

Every list on the site pages the same way, from the gallery to a challenge's entries: 24 at a time, saying which (*Showing models 1–24*). **Show more** adds the next 24 under them; nothing loads by itself as you scroll. The address keeps the page (`?page=3`), and a link to page 3 opens page 3, with **Show earlier** above it. Back returns you to the same pages and the same card.

<!-- covers
ui:a list's pages
-->

## The front shelves {#shelves}

The gallery's front (Top, all time, nothing searched) has shelves among the cards:

- **Week's pick**, the first card, with a line saying why: chosen each Monday from the past seven days by builds, remixes and the Tested mark, never one picked in the past eight weeks. A pick the site's owner made says *Chosen by Brickworks*.
- **Today in the gallery**: one model a day, by its past 30 days' likes, builds, comments, remixes and the Tested mark, not again for four weeks; and one set from [the LDraw library](/docs/ldraw-library), never the same twice in 90 days.
- **You can build now**, signed in: models you own every part for, from [your collection](/docs/collection). With no collection yet it says how to add one (in the app, **Build › My collection…**).
- **Small builds**: under 200 parts, an evening's build, the most built and remixed first, with **See every small build**.

Everyone sees the same choice all day; nothing is drawn at random. With Order on Top builds, a line under the list says how it weighs: a build finished counts 3, a remix 2 and the Tested mark 5.

<!-- covers
ui:the gallery's front shelves
lib:build with what I own
lib:the gallery's daily choice
-->

## A card {#card}

Every model is a card, the same everywhere on the site: its picture, its name, its designer (press to open [their page](#designer)), its part count, and how many liked, built and commented on it once there are any. The heart on the picture likes it. **✓ Tested** says it passed [Brickworks' four tests](/docs/sharing#tested). A card says *Moves: steering, boom* when something on it moves, which anybody can move on its page, and *Won* with a challenge's name when it won one.

Signed in with [your collection](/docs/collection), a card also says how much of the model you have: **You have 87%** from half its parts up, **✓ You have every part** when you have them all, and nothing under half. Parts are matched by part, colour and how many, each set counting as many times as you own it (**You own** on [its page](/docs/collections#own)). Only you see it, and the gallery counts it for the whole page at once.

![Four gallery cards seen signed in with a collection: the sports car says You have 73%, the corner shop You have every part with a check, the barn owl You have 64%, and the fire station, under half, says nothing of it.](/docs/img/gallery-owned.webp "What you have of each model, on its card.")

![Two gallery cards on a phone, signed in with a collection: the sports car says You have 73% and the corner shop You have every part.](/docs/img/gallery-owned-phone.webp "The same on a phone.")

<!-- covers
ui:model card
lib:what moves on a gallery card
-->

## Builds {#builds}

[brickworks.diy/builds](/builds), the **Builds** tab, is everybody's photos of gallery models built in real bricks, newest first: the photo, the model (press it to see the photo on the model's page), who built it and when, and what they said. To add yours, press **Show your build** on the last step of [Build it](/docs/model-pages#show-your-build), or open the model's page and press **Built**. A photo stays off the tab once the model's designer hides it, or while a report of it is looked at.

<!-- covers
ui:the gallery's builds tab
lib:builds in the gallery
-->

## A designer's page {#designer}

`/u/<handle>` is a designer's page: their models in Top builds order, **Start with their most built** with **Build it**, their numbers (builds finished, remixes, models, likes, followers) and what their models won, and the tabs **Models**, **Builds**, **Collections** and, if they chose to show them, **Likes**. **Follow** puts what they make in [your feed](/docs/profiles#feed). Brickworks' own page, [brickworks.diy/u/brickworks](/u/brickworks), shares the house's models.

<!-- covers
ui:a designer's page
lib:designers' numbers
lib:the house's profile
-->

An assistant can search the gallery too, and open a copy of a model for you to change: [its tools](/docs/mcp-tools).
