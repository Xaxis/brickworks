---
title: Designing with AI
nav: The assistant
description: How Claude designs in Brickworks, the assistant panel, choosing a model and effort, sketches, and asking about a selection.
---

Claude can design a whole model from a sentence, change a part of one, or answer a question about it. It builds with the same real parts and the same checks you do: the app decides whether each part fits and holds, so what goes on the baseplate is buildable. There is no AI in the window until you turn the assistant on ([Connect Claude](/docs/connect-claude#assistant-on)).

## Three ways to bring Claude {#ways}

| Way | You need | Where it runs |
|---|---|---|
| [The Claude connector](/docs/connector) | A Claude Pro or Max plan | claude.ai, the Claude desktop and mobile apps, building in your open Brickworks tab |
| [Claude Code](/docs/claude-code) | Claude Code, signed in to your plan | Your terminal, or started by the desktop app for you |
| [Your API key](#api-key) | A key from the Anthropic Console | The assistant panel itself |

## The assistant panel {#panel}

The panel on the right is where you talk to Claude in the app. Describe what you want (*a red fire engine with a ladder that lifts*) and press **Build it**. You watch it build: each part goes down as Claude places it, and the status bar says what it is doing. When it has finished, the whole design is one step of Undo.

<!-- covers
lib:design loop
lib:claude's design is one undo step
lib:a big check on a worker
-->

### Your API key {#api-key}

Paste a key from the Anthropic Console into the panel. It is checked with Anthropic before it is kept, in this browser or for this visit only, and is sent nowhere but Anthropic.

### Model and effort {#model-effort}

Choose which Claude designs and how hard it thinks. Higher effort takes longer and costs more; medium effort costs about a third of the default. The panel offers only the combinations Anthropic accepts.

<!-- covers
lib:model and effort settings
-->

### On your Claude plan, in the panel {#my-claude}

In the desktop app, with Claude Code installed and signed in, the panel can design on your Claude plan instead of a key: it starts Claude Code for you and points it at this window. A new design of a whole model is then made twice at once, the second in a copy of the app with no window, and the better of the two is kept as the model; Undo brings back the other.

<!-- covers
ui:design on your own subscription
lib:best of two
-->

## Sketch first {#sketch}

**Sketch first**, beside **Build it**, asks for three quick massings of the idea, each under 150 parts, on a cheaper model. Pick the silhouette you mean on its card with **Design this one**, and the full design is built from it at your own model and effort. It is the cheap way to find out whether the brief was understood.

<!-- covers
ui:sketch first
-->

## Ask about the selection {#ask}

Select some parts, right-click one and choose **Ask Claude about this…** (or [[Ctrl+K]]): *make this wing longer*, *why does this fall off?*, *add a door here*. Claude may change only the selected parts and the space just round them, or a bigger box if it asks and you allow it. Everything else stays where it is, and a change that reaches outside is refused whole. In [View › Stress](/docs/the-view#stress), a red part's menu has **Ask Claude to brace this**.

<!-- covers
ui:ask claude about the selection
-->

## Reference pictures {#references}

For a real subject, a landmark, a vehicle or an animal, Claude can look up a reference picture from Wikimedia Commons and design from it. Only the picture's address goes out, from your browser.

<!-- covers
lib:reference pictures
lib:find a reference picture
-->

Read on: [what a Claude build is](/docs/claude-builds), and [fresh eyes](/docs/fresh-eyes), the second look every new design gets.
