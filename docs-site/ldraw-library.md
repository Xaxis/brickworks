---
ai: The LDraw community's models of real sets, opened in the app (File › Library) or browsed at /library, and the LDraw Parts Library every part comes from. An assistant searches them with gallery library=true and opens one with open_model library=.
rules:
  - One LDraw unit is 0.4 mm exactly; files go to and from LDCad, LeoCAD and Studio unchanged.
  - Each set says who modelled it and under which licence.
title: The LDraw library
nav: The LDraw library
description: Every LEGO® set's parts on the website, the LDraw community's 3D models of real sets to open, and where Brickworks' parts come from.
---

## Real sets to open {#sets}

**File › Library…** (or **Open › From the library…**) opens any of the LDraw community's models of real sets, or a model the community shared in the gallery, in a new tab or window. Each says who modelled it.

The search comes first, and asks as you type: by a set's name, number or theme. [[Ctrl+F]] comes back to it, [[Esc]] clears it, and [[Enter]] opens the first set found (on a phone, Enter only searches). When nothing is found it says so where the covers were, with **Clear the search**, the filters let go, and the other shelf to look in.

<!-- covers
ui:library search
-->

## On the website {#website}

[brickworks.diy/library](/library) is the same library, browsed as the gallery is: every model of a real set the app's Library opens, as cards with a cover, name, number, theme, year and modeller. Search by name, number, theme or modeller; the themes are pills; **Filters** sets the order, the size and the years. It is linked from the gallery's tabs and every page's footer.

Each set has a page of its own, at `brickworks.diy/library/<id>`, as a shared model has: its picture, who modelled it for LDraw's Official Model Repository and under which licence, its parts list to download for BrickLink or Rebrickable, **Share**, and **Open in Brickworks**, which opens it in the app as **File › Library…** does.

<!-- covers
ui:LDraw library page
ui:an LDraw set's page
-->

## Every set there is {#every-set}

The library on the website lists every LEGO® set in [Rebrickable](https://rebrickable.com/)'s catalogue, about 28,000 of them, beside the few hundred LDraw has modelled in 3D, which are marked **3D**. Search by a set's number (`10497` finds 10497-1 first, `7519` the sets whose number starts so) or its name; the themes are pills, and **Filters** adds the theme inside the one chosen, the year in the decade, only the sets with a 3D model, and minifigures. Browsing leaves out what Rebrickable lists with no parts, such as books and key rings; a search finds those too.

The search takes words as you type them. A misspelling finds what you meant (`milenium falcon`, and the list says **Showing sets for millennium falcon**), as do words run together or apart (`deathstar`, `fire truck`, `xwing`), plurals, a word without its accents (`pokemon`), a year (`castle 1978`) and builders' short names (`UCS`, `LOTR`). While words are typed the list is in **Best match** order: a set's number, then a set whose name you typed, then every word in its name, then every word anywhere. A theme's name typed alone (`city`, `trains`, `marvel`) lists that theme's sets first, so LEGO® City sets come before NINJAGO City. Real sets come before books, gear, key chains and promotions unless you ask for those (`harry potter book`); then the bigger and newer set. Choose another **Order** in **Filters** and the search keeps it. When no set has every word, the list shows the nearest and says so.

Each set has a page at `brickworks.diy/library/set/<number>`, such as [10497-1](/library/set/10497-1):

- its number, name, year, theme, part count, minifigures and any sets packed inside it;
- its whole parts list, by colour or by kind, each part drawn by Brickworks from LDraw's geometry, with a BrickLink XML and a Rebrickable CSV to download;
- signed in with a collection (**My collection** in the app), **Parts you own: N of M**, and what you are missing as a BrickLink wanted list or a Rebrickable CSV;
- **Open its parts in Brickworks**, which opens the app with the set's parts in the parts bin, the most used first;
- **Design with these parts**, which opens the app with the assistant on and a brief naming the set's parts in its box, for your own AI to design with when you send it;
- when LDraw has a model of it, **Build it in 3D** and the model's own page, which links back.
- **Based on this set**: the models in the gallery that their designers said were built from it, changed from it or inspired by it ([what a model is based on](/docs/model-pages#based-on)).

Its picture is LDraw's model when there is one; otherwise the set's own picture, as [Rebrickable](https://rebrickable.com/) has it and credited to them, kept on Brickworks' own storage so your browser never asks them; and for the few sets with no picture anywhere, a few of its most distinctive parts drawn by Brickworks from their own geometry. Set and inventory data is Rebrickable's, read from a copy Brickworks takes at most once a day.

In the app, `/app?parts=<number>` puts a set's parts in the bin. Claude finds every set too: the gallery tool's `library=true` search names the sets LDraw has no model of with their parts list, and `open_model library=` takes a set's number or name.

<!-- covers
ui:every set's page
api:a set's own picture
lib:a set's picture drawn from its parts
-->

## The parts {#parts}

Every part in Brickworks is from the [LDraw Parts Library](https://library.ldraw.org), the community's model of every LEGO® element, licensed CC BY 2.0 and CC BY 4.0. One LDraw unit is 0.4 mm exactly, and every size was read off the parts themselves: a stud is 8 mm apart from the next, a brick 9.6 mm tall, a plate 3.2 mm. Brickworks reads and writes LDraw files exactly, so a model goes to and from LDCad, LeoCAD and Studio.

## Credits {#credits}

**Brickworks › About Brickworks** (the mark at the left of the menu bar) names every piece of other people's work Brickworks is built with, the LDraw library among them, with its terms. LDraw™ is a trademark owned and licensed by the Estate of James Jessiman; Brickworks is not affiliated with or endorsed by LDraw.org. Catalogue data is from [Rebrickable](https://rebrickable.com/downloads/).
