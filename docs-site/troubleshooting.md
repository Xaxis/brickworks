---
ai: What goes wrong and what people ask: an updated tab, a part that will not go where wanted, a command not found (Ctrl+/), a missing part, a slow computer, a model that will not stand, the download saying coming soon; then with an AI app: a new tool not seen, asking before every tool, the wrong tab. Still stuck: Brickworks › Send feedback… or Help › Report a bug….
rules:
  - A tool missing in Claude: a new conversation, then reconnect in Claude (Customize › Connectors); in Claude Code, /mcp and Reconnect.
  - Disconnect in Brickworks' Account ends the connection, which must then be allowed again.
title: Troubleshooting and FAQ
nav: Troubleshooting and FAQ
description: What to do when something goes wrong, from an updated tab and a part that will not go where you want to your AI's tools, and how to tell us.
---

What to do when something goes wrong, the app's first and your AI app's after. The [questions page](/faq) has more, and the [compare page](/compare) sets Brickworks beside Studio, Mecabricks, LeoCAD and LDCad.

<!-- covers
ui:FAQ page
ui:compare page
ui:landing page
ui:404 page
-->

## It says "Brickworks has been updated" {#updated}

Press **Reload** when it suits you. The model in that tab comes back as it is, under its name. Until then the tab keeps working, but it saves nothing to your saved models, so it can never write over what a tab on the new version keeps. Save again after the reload.

## A part will not go where I want {#placing}

- A part goes down only where nothing else is, as a real brick does: aim where it fits, or move what is in the way.
- **Snap** on the toolbar sets what it snaps to: **Stud**, **½ stud**, **½ plate** or **Free**.
- [[R]] turns it, [[T]] tips it onto its side; tipped, it goes onto a side stud, studs out.
- Aim at the underside of an overhang and it goes beneath it.
- To put it an exact distance away, type a number with it in hand: **3x** is 3 studs along x ([Placing parts](/docs/placing-parts#typed)).
- Parts of a model from another program a fraction off their studs: **Tools › Seat parts on their studs**.

## I can't find a command {#find-a-command}

Press [[Ctrl+/]] (**Brickworks › Find a command…**), type a few letters of its name or its menu, and press [[Enter]]. A greyed command says what it waits for, such as *Select a part first*. Every menu and its keys are in [Menus](/docs/menus).

## A part did not come {#missing-part}

Parts are fetched the first time they are used. If the network fails, each is asked again a few times; a part that never came is said once in the status bar, and the model is saved whole, so it is all there next time.

## The app is slow on my computer {#slow}

On a slow computer the app draws a lighter look while you move and the full look when you stop. Close other tabs with Brickworks in them: each one is a whole app.

## My model will not stand {#stand}

**Tools › Check stability** ([[Alt+K]]) shows where its weight is and which joints give way, and [View › Stress](/docs/the-view#stress) colours them. Brace the red parts, or select one and ask your AI to.

## What do I need to run it? {#requirements}

A recent browser on a computer, a tablet or a phone, with WebGL 2 and WebAssembly threads: open [brickworks.diy/app](/app). Nothing to install.

## The download says "Coming soon" {#desktop}

The desktop app for Linux, macOS and Windows is not out yet ([the desktop app's page](/download)). Everything in Brickworks works in your browser today, at [brickworks.diy/app](/app), and your models are kept with your account, ready for the desktop app when it comes.

## Is Brickworks made by the LEGO Group? {#lego}

No. LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this site. Part geometry is from the LDraw™ Parts Library.

## With your AI app {#ai}

### It can't see a new Brickworks tool {#new-tools}

Brickworks tells your AI app when its tools change, and an app that listens picks them up by itself. If yours hasn't: reload the Brickworks tab if it says it has been updated, then start a new conversation. Still missing? Reconnect Brickworks in the app: in Claude, **Customize › Connectors**, Brickworks, **Disconnect**, then **Connect**; in Claude Code, `/mcp`, **brickworks**, **Reconnect**. Not **Disconnect** in Brickworks' Account: that ends the connection, and you would have to allow it again.

### It asks before every tool {#always-allow}

In Claude: **Customize › Connectors**, Brickworks, and under *Tool permissions* choose **Always allow** for the tools you trust, or press **Always allow** when Claude asks. Those switches are Claude's; Brickworks tells it which tools only look ([the tool reference](/docs/mcp-tools)).

### It built in the wrong tab {#wrong-tab}

Start each chat from its tab: **New chat for this tab** in Account. A chat that names its tab stays in it. See [Several tabs, several chats](/docs/connector#tabs).

## Still stuck {#contact}

Tell us: **Brickworks › Send feedback…** in the app, **Send feedback** in the site's footer, or **Help › Report a bug…** ([[Alt+Shift+R]]) for something wrong, with a picture of the window to mark the spot on ([Feedback](/docs/feedback)). We read every one and answer.
