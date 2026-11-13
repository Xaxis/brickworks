---
tools: gallery
ai: brickworks.diy/gallery holds the models people built and shared, searchable by words, kind, size, how it was made (by hand or with the assistant), instructions, Technic, Tested and the parts a person owns. An assistant searches it and reads a model as a reference with gallery, and opens a copy with open_model link=.
rules:
  - A gallery model carries its credit and licence; say them when it is used as a reference.
title: The gallery
nav: The gallery
description: Find a model to look at or build, by Top builds, what is new, who you follow, its kind, its size and the parts you own.
---

The gallery is where you find a model to look at or build: everything people built in Brickworks and shared, with its steps. It is at [brickworks.diy/gallery](/gallery), **Gallery** at the top of every page of the site. Anyone can browse it, with no account.

<!-- covers
ui:gallery page
api:GET/POST /api/share
lib:directory
-->

![The gallery's front on a computer: the Gallery heading and search, the tabs Top, New, Builds, Collections and Sets with All time beside them, Filters and the kinds as pills, then model cards, the first marked Week's pick, each with its picture, name, designer and part count.](/docs/img/gallery-top.webp "The gallery's front: Top, all time.")

## Find a model {#find}

1. Choose a tab. **Top** puts first what people built most, remixed most and found Tested; views count for nothing. **New** is the newest first.
2. To narrow it, press a kind under the tabs: **Castles and fantasy**, **Space**, **Vehicles**, **Town and buildings** and so on to **Something else**.
3. Or type in **Search models, builders, tags**: a model's name, its designer, a tag or words from its description. The cards change as you type, and [[/]] jumps to the search from anywhere on the page. A misspelt word, and words run together or apart (`spaceship`, `space ship`), still find it.
4. Press a card to open [the model's page](/docs/model-pages).

On Top, **All time** beside the tabs changes to **This week** or **This month**: what was built and remixed in that time.

The address keeps the tab, the search and the filters (`/gallery?q=castle&kind=space&sort=newest`), so Back returns to them and a search can be sent to someone.

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

<!-- covers
ui:model card
lib:what moves on a gallery card
-->

## Builds {#builds}

[brickworks.diy/builds](/builds), the **Builds** tab, is everybody's photos of gallery models built in real bricks, newest first: the photo, the model (press it to see the photo on the model's page), who built it and when, and what they said. To add yours, open the model's page and press **Built**. A photo stays off the tab once the model's designer hides it, or while a report of it is looked at.

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
