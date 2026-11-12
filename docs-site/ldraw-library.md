---
ai: The LDraw community's 3D models of real sets, opened in the app (File › Library) or browsed at /library with every other LEGO® set and its parts list, and the LDraw Parts Library every part comes from. An assistant searches them with gallery library=true and opens one with open_model library=.
rules:
  - One LDraw unit is 0.4 mm exactly; files go to and from LDCad, LeoCAD and Studio unchanged.
  - Each set says who modelled it and under which licence.
title: The LDraw library
nav: The LDraw library
description: Open LDraw's 3D models of real LEGO® sets, find any set's parts list on the website, and where Brickworks' parts come from.
---

"Library" means three things here: **LDraw's 3D models of real sets**, to open in the app, look at and build; **every LEGO® set and its parts**, on the website; and the **LDraw Parts Library**, which every part in Brickworks comes from.

## Open a real set {#sets}

**File › Library…** ([[Ctrl+Shift+O]]), or **File › Open…** then *From the library*, holds the LDraw community's models of real sets. Its other shelf, **Community**, has the models people shared in the gallery.

1. Type a set's name, number or theme in the search at the top. It asks as you type, and finds the set through a misspelling or words run together. [[Ctrl+F]] comes back to the search; [[Esc]] clears it.
2. Narrow it by theme, years and size, or choose another order.
3. Press **Open** under a cover, or [[Enter]] for the first set found (on a phone, Enter only searches).

The set opens in a new tab, and the model you had stays as it was. It opens as it comes in the box: on the grid, with no baseplate added unless the set has one among its parts (**View › Floor** lays one under it). The parts bin becomes the set's parts and follows its booklet, the step you are on first ([building from a set's parts](/docs/collection#set-bin)). **Properties** names the LDraw member who modelled it, its licence and its LDraw page.

When nothing is found it says so where the covers were, with **Clear the search**, the filters let go, and the other shelf to look in.

<!-- covers
ui:library search
-->

## Find any set on the website {#website}

[brickworks.diy/library](/library), the gallery's **Sets** tab and **Sets** in every page's footer, lists every LEGO® set in [Rebrickable](https://rebrickable.com/)'s catalogue, about 28,000, and marks **3D** the 1,260 or so that LDraw has modelled.

![The gallery's Sets tab searching fire with Only with a 3D model chosen: the search box, the theme pills, Filters with one on, and cards of fire sets, each with its picture, name, number, theme, year and the 3D mark.](/docs/img/ldraw-library-sets.webp "brickworks.diy/library, the sets LDraw has modelled in 3D.")

1. Search by a set's number (`10497` finds 10497-1 first; `7519`, the sets whose number starts so), its name, its theme or who modelled it.
2. Press a theme's pill to keep to it. **Filters** sets the order, the size, the years and the year within them, the theme inside the one chosen, only the sets with a 3D model, and minifigures.
3. Open a card for the set's page.

![The Sets tab's Filters open: Order, Size, Decade, Year, Inside the theme, 3D model set to Only with a 3D model, and Minifigures.](/docs/img/ldraw-library-filters.webp "Filters, on the Sets tab.")

The search reads words as people type them: a misspelling (`milenium falcon` says **Showing sets for millennium falcon**), words run together or apart (`deathstar`, `xwing`), plurals, a word without its accents (`pokemon`), a year (`castle 1978`) and builders' short names (`UCS`, `LOTR`). While words are typed the order is **Best match**: a set's number, then a set whose name you typed, then sets with every word in the name, then every word anywhere. A theme's name alone (`city`, `trains`) lists that theme first. Real sets come before books, gear and promotions unless you ask (`harry potter book`). When no set has every word, the list shows the nearest and says so. Browsing leaves out what has no parts, such as key rings; a search finds those too.

<!-- covers
ui:LDraw library page
-->

## A set's page {#every-set}

Each set has a page at `brickworks.diy/library/set/<number>`, such as [10497-1](/library/set/10497-1):

- its number, name, year, theme, part count, minifigures and any sets packed inside it;
- its whole parts list, by colour or by kind, each part drawn from LDraw's geometry, as a BrickLink XML or a Rebrickable CSV;
- signed in, with sets in [My collection](/docs/collection), **Parts you own: N of M**, and what you are missing as a BrickLink wanted list or a Rebrickable CSV;
- **Open its parts in Brickworks**: the app with the set's parts in the bin, the most used first (`/app?parts=<number>` does the same);
- **Design with these parts**: the app with the assistant on and a brief naming the set's parts, for your own AI to design from when you send it;
- where LDraw has a model of it, **Build it in 3D**, and that model's own page at `brickworks.diy/library/<id>`: who modelled it and under which licence, **Share**, and **Open in Brickworks**, which opens it as File › Library… does;
- **Based on this set**: gallery models whose designers said they were built from it, changed from it or inspired by it ([based on](/docs/model-pages#based-on)).

Its picture is LDraw's model where there is one; otherwise the set's own picture, Rebrickable's and credited to them, kept on Brickworks' storage so your browser never asks them; for the few with none, a few of its most distinctive parts, drawn by Brickworks. Set and inventory data is Rebrickable's, copied at most once a day.

<!-- covers
ui:an LDraw set's page
ui:every set's page
api:a set's own picture
lib:a set's picture drawn from its parts
-->

## The parts {#parts}

Every part is from the [LDraw Parts Library](https://library.ldraw.org), the community's model of every LEGO® element, licensed CC BY 2.0 and CC BY 4.0. One LDraw unit is 0.4 mm exactly, and every size was read off the parts themselves: studs 8 mm apart, a brick 9.6 mm tall, a plate 3.2 mm. Brickworks reads and writes LDraw files exactly, so a model goes to and from LDCad, LeoCAD and Studio.

## Credits {#credits}

**Brickworks › About Brickworks** (the mark at the left of the menu bar) names every piece of other people's work Brickworks is built with, the LDraw library among them, with its terms. LDraw™ is a trademark owned and licensed by the Estate of James Jessiman; Brickworks is not affiliated with or endorsed by LDraw.org. Catalogue data is from [Rebrickable](https://rebrickable.com/downloads/).
