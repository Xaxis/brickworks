---
ai: What goes wrong and what people ask: an updated tab, Claude not seeing a new tool, asking before every tool, the wrong tab, a missing part, a slow computer, a model that will not stand.
rules:
  - A tool missing in Claude: a new conversation, then reconnect in Claude (Customize › Connectors); in Claude Code, /mcp and Reconnect.
  - Disconnect Claude in Brickworks ends the connection, which must then be allowed again.
title: Troubleshooting and FAQ
nav: Troubleshooting and FAQ
description: Answers to what goes wrong and what people ask, from updates and Claude's tools to files and parts.
---

The [questions page](/faq) has more, and the [compare page](/compare) sets Brickworks beside Studio, Mecabricks, LeoCAD and LDCad.

<!-- covers
ui:FAQ page
ui:compare page
ui:landing page
ui:404 page
-->

## It says "Brickworks has been updated" {#updated}

Press **Reload** when it suits you. The model in that tab comes back as it is, under its name. Until then the tab keeps working, but it saves nothing to your saved models, so it can never write over what a tab on the new version keeps. Save again after the reload.

## Claude can't see a new Brickworks tool {#new-tools}

Brickworks tells Claude when its tools change, and a Claude app that listens picks them up by itself. If yours hasn't: reload the Brickworks tab if it says it has been updated, then start a new conversation. Still missing? Reconnect Brickworks in Claude: **Customize › Connectors**, Brickworks, **Disconnect**, then **Connect**. In Claude Code, `/mcp`, **brickworks**, **Reconnect**. Not *Disconnect Claude* in Brickworks: that ends the connection, and you would have to allow it again.

## Claude asks before every tool {#always-allow}

In Claude: **Customize › Connectors**, Brickworks, and under *Tool permissions* choose **Always allow** for the tools you trust, or press **Always allow** when Claude asks. Those switches are Claude's; Brickworks tells Claude which tools only look ([the tool reference](/docs/mcp-tools)).

## Claude built in the wrong tab {#wrong-tab}

Start each chat from its tab: **New chat for this tab** in Account. A chat that names its tab stays in it. See [Several tabs, several chats](/docs/connector#tabs).

## A part did not come {#missing-part}

Parts are fetched the first time they are used. If the network fails, each is asked again a few times; a part that never came is said once in the status bar, and the model is saved whole, so it is all there next time. The desktop app carries every part on disk.

## The app is slow on my computer {#slow}

On a slow computer the app draws a lighter look while you move and the full look when you stop. Close other tabs with Brickworks in them: each one is a whole app. The desktop app is faster than a browser on the same machine.

## My model will not stand {#stand}

**Tools › Check stability** shows where its weight is and which joints give way; [View › Stress](/docs/the-view#stress) colours them. Brace the red parts, or select one and ask Claude to.

## What do I need to run it? {#requirements}

A recent browser on a computer, a tablet or a phone, with WebGL 2 and WebAssembly threads. Or the [desktop app](/download) for Linux, macOS and Windows.

## Is Brickworks made by the LEGO Group? {#lego}

No. LEGO® is a trademark of the LEGO Group of companies which does not sponsor, authorize or endorse this site. Part geometry is from the LDraw™ Parts Library.

## Still stuck {#contact}

Ask on the [questions page](/faq), or press **Report it** on anything on the site that should not be there.
