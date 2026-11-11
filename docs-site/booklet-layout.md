---
tools: edit_booklet, booklet_page, page_setup
panels: PageEditor#lay-out, PageSetupDialog#page-setup
ai: How each step of the booklet is printed (its view, size and page, its parts box and callout, pulled-out parts, colour and 1:1 guides), the booklet's paper, cover, header, footer and colours, and pages laid out by hand. An assistant sets a step's page with edit_booklet, the page setup and its styles with page_setup, and sees a page as Instructions draws it, and as its PDF prints it, with booklet_page.
rules:
  - Each line of the cover, the header and the footer holds 120 letters; longer is cut.
  - A style kept by name carries the look to another model, never its title or the line under it.
title: Booklet layout
nav: Booklet layout
description: Print a step from another side or on a page of its own, set the paper, the cover and the colours, and lay a page out by hand.
---

Brickworks lays the [booklet](/docs/instructions#booklet) out for you. Here is how to make it yours: a step from another side or on a page of its own, your own paper, cover and colours, or a page laid out by hand. All of it is saved with the model, each change one Undo.

## Change how a step is printed {#booklet-by-hand}

Go to the step on the [timeline](/docs/instructions#timeline) ([[B]]), in **Build order** or **Author's steps**, and use its **Booklet** row, or **Build › Booklet page**:

- **Turn left**, **Turn right** (45°), **Higher**, **Lower** (15°), **Zoom in** and **Zoom out** change the step's picture; **This view** draws it from where the window looks now, and **Usual view** puts the booklet's angle back. The menu has them under **Step's view**.
- **Bigger** and **Smaller** draw the step larger or smaller on its page.
- **New page** starts a page with the step, and **Alone** gives it a page of its own. **Per page** puts at most 1, 2 or 4 steps on a page (**Steps a page** in the menu).
- **Parts list** shows or leaves off the step's box of parts. **Callout** builds the sub-assembly the step puts on in a box beside it, or on pages of its own.
- **Outline new** outlines every step's new parts in orange.

Press one again to put it back.

<!-- covers
ui:the booklet by hand
-->

## Guides and pulled-out parts {#booklet-extras}

On **Build › Booklet page**, for the step the timeline is on:

- **Pull out the selected parts** draws them 2 studs out along the way they go in, with a red arrow pointing back in; with nothing selected, all of the step's new parts.
- **Colour guide** lists the step's colours under its number.
- **1:1 guide** draws the selected parts at their real size, to lay a part on the page and check it; it prints true at 100% scale. The booklet gives one to each length of Technic axle or straight beam the first time it is used, and on such a step **1:1 guide** takes it away.
- **Sub-model preview** shows a sub-assembly built on pages of its own finished, on the first of them.

Press one again to put the step back as it was.

<!-- covers
ui:the booklet's Studio extras
ui:what is set in the booklet kept over an open
-->

## Paper, margins and colour {#page-setup}

![Page setup for the booklet, on its Page tab: the paper and which way up, the margins, the page colour, a picture behind every page, and a header and footer; under the tabs, a style to choose or keep.](/docs/img/booklet-page-setup.webp "Build › Booklet page › Page setup… (Ctrl+Shift+B).")

**Build › Booklet page › Page setup…** ([[Ctrl+Shift+B]]) has three tabs. On **Page**:

- **Paper**: the booklet's own (269 x 199 mm), A4, US Letter or A5, and **Orientation**, landscape or portrait. The booklet is laid out again on it.
- **Margins**, 5 to 30 mm.
- **Page colour**, or a **Picture behind** every page.
- **Header** and **Footer**: a line of your own words at the head of every page but the cover, and at the foot of every page, such as a copyright line or your name.

<!-- covers
ui:the booklet's page setup
-->

## The cover and the steps' colours {#booklet-look}

On the **Cover** tab:

- **Title**, across the top: the model's name, unless you type another.
- **Under the title**, a smaller line.
- **Picture**: **Choose…** a picture of your own, shown whole, or **The model** to draw the finished model again.
- **Line**, your words over the count of pieces.

On the **Steps** tab: the **Step numbers**' height (4 to 20 mm) and **Number colour**, the size of **Parts pictures**, the parts box's **frame**, **fill** and **corners** (0 for square), and the **New parts outline** colour. **Usual colours** puts the booklet's own back.

Each line of words holds 120 letters; longer is cut, and Brickworks says so.

**Use it on another model:** type a name under the tabs and press **Keep as a style**, then on the other model choose it under **Style**. A style never carries the title or the line under it.

> [!NOTE]
> The desktop app up to 0.19.0 leaves the page setup out when it saves a model: save such a model on the web.

<!-- covers
ui:the booklet's own cover and colours
-->

## Lay a page out by hand {#lay-out}

![Lay out the page: the booklet page with the step's picture, parts list and number each in a box to drag, rulers along the top and left, and buttons to add words, a picture or an arrow.](/docs/img/booklet-lay-out.webp "Lay out the page… on the timeline's Booklet row.")

**Lay out page…** on the timeline's Booklet row (**Build › Booklet page › Lay out the page…**) puts the step's page in your hands:

1. Drag the step's picture, parts list, callout and number where they go, and a corner to size each.
2. **Add words**, **Add a picture…** or **Draw an arrow**. Drag the dot in the middle of an arrow's stretch to bend it there; double-click a bend to take it out.
3. Turn words or a picture by the knob above them (it settles on every 15°) or in **Turn**; **Opacity** fades them.
4. Drag a guide out of a ruler: what you drag near it lands on it. Guides are never printed.
5. **Done** goes back to the model. **Put back** returns the selected item to where the booklet had it, and **Previous page** and **Next page** turn a callout's own pages.

When one page is right, **Apply to later pages** gives every later page with as many steps the same layout, in one Undo. Set **Per page** first, so the pages have the same number of steps. The PDF and PNG pages print each turn, fade and bend as the page shows it.

<!-- covers
ui:the booklet page by hand
-->

Your AI can set all of this over the connector: `edit_booklet`, `page_setup` and `booklet_page` in [the tool reference](/docs/mcp-tools).
