---
title: The gallery
nav: The gallery
description: Find models people built and shared, by Top builds, what is new, who you follow, kind, size and the parts you own.
---

[brickworks.diy/gallery](/gallery) holds the models people built in Brickworks and shared. Anyone can browse it, with no account.

<!-- covers
ui:gallery page
api:GET/POST /api/share
lib:directory
-->

![The gallery: Top, New and Collections, the kinds as pills, Filters, and the models as cards, each with its designer, part count and Tested mark.](/img/docs-gallery.webp "brickworks.diy/gallery")

## Tabs and filters {#tabs}

- **Top** puts first the models most people have built, over this week, this month or all time; **New** the newest; **Following**, signed in, the people you follow; **Collections** the [directory of collections](/docs/collections#directory).
- **Kinds** are pills across the top: buildings, vehicles, space, Technic and more. They and **Filters** stay in view under the header as you scroll.
- **Filters** opens a sheet: the order, the size, how it was made (by hand, with Claude, from the LDraw library), with instructions, Technic, and **Tested** only. Each filter that is on shows as a pill under the bar; press one to drop it, or **Clear all**.
- Search by a name, a builder, a tag or a description: the cards change as you type, and [[/]] jumps to the search from anywhere on the page. The address keeps it all (`/gallery?q=castle&kind=space&sort=newest`), so a search can be shared.

Every list on the site pages the same way: the gallery, [the LDraw library](/docs/ldraw-library), a designer's models and likes, collections and a challenge's entries. It shows 24 at a time and says how many it shows ("Showing 1–24 of 1,575 sets"). **Show more** adds the next 24 under them, and nothing loads by itself as you scroll. The address keeps the page (`?page=3`), so it can be shared, and a link to page 3 opens page 3, with **Show earlier** above it. The numbered pages under the list are plain links. Back returns you to the same pages and the same card.

<!-- covers
ui:a list's pages
lib:model kinds
lib:Top builds and this week's pick
-->

## The front shelves {#shelves}

Before you search, the gallery shows **This week's pick**, chosen by Brickworks, **Today in the gallery** and **Small builds** for an afternoon.

**This week's pick** and **Today in the gallery** change by themselves. Every day Brickworks features one model, chosen from what people did with it in the past 30 days: likes, builds finished, comments and remixes, with a little extra for being new. A model featured once doesn't come back for four weeks. Beside it is one set from [the LDraw library](/docs/ldraw-library), each day from a different theme and decade, and never the same set twice in 90 days. The week's pick is chosen on Monday the same way, from the past seven days. Everyone sees the same choice all day; nothing is drawn at random. Signed in with [your collection](/docs/collection), **You can build now** shows models you own every part for, and **Sort › Parts I own** ranks the rest by how much of each you have. **Sort › Top builds** says how it weighs each model.

<!-- covers
ui:the gallery's front shelves
lib:build with what I own
lib:the gallery's daily choice
-->

## A card {#card}

Every model is a card, the same everywhere on the site: its picture, its name, its designer, its part count, how many people built it, and the **Tested** mark when it has one. A card of a model with something that moves (steering, a boom) says so, and its page lets anybody move it.

<!-- covers
ui:model card
lib:what moves on a gallery card
-->

## A designer's page {#designer}

`/u/<handle>` is a designer's page: their models by Top builds, **Start with their most built**, the models others built of theirs, and what their models have earned. Brickworks' own page, [brickworks.diy/u/brickworks](/u/brickworks), shares the house's models.

<!-- covers
ui:a designer's page
lib:designers' numbers
lib:the house's profile
-->

## Claude and the gallery {#claude}

Claude can search the gallery and open a model as a reference, with its credit and licence (`gallery`), and **Open in Brickworks** a copy for you to change.
