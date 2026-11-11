---
tools: submit_design, choose_sketch, plan_scale, find_reference, how_real_sets_build_this, find_techniques, show_technique, place_technique, restyle_model, add_rooms
ai: How a person designs with an AI in Brickworks: in the assistant panel, with Claude on their own key or another AI on their own key, or in their own AI app through the connector. It proposes parts and the app decides: every design is checked and sent back with what failed. A design starts with plan_scale, find_reference and how_real_sets_build_this, then submit_design. Asked about a selection, the AI changes only that.
rules:
  - The app builds what is submitted, checks it holds together, and refuses what does not.
  - A sketch is under 150 parts; three sketches, then choose_sketch one.
  - Asked about a selection, change only it (selection, edit_selection), never submit_design.
  - A whole design is one undo step.
title: Designing with AI
nav: The assistant
description: Have an AI design a model from a sentence, sketch ideas first, or change only the parts you select, in the assistant panel or from your own AI app.
---

The assistant designs a whole model from a sentence, changes only the parts you select, or answers a question about them. It builds with the real parts and the checks you do: the app decides whether each part fits and holds, so what goes on the baseplate is buildable. It is the panel on the right once it is on (**Tools › Settings…**, *Assistant (AI)*, **Show the assistant**).

## Choose who designs {#ways}

Every AI is your own, set up once in [Connect your AI](/docs/connect):

- **Your AI app**, Claude, ChatGPT, Gemini, Claude Code or another, through [the connector](/docs/connector): you type the brief in that app, and it builds in your tab.
- **Claude on your own Anthropic key**, in the panel itself.
- **Another AI on your own key**, from OpenAI, Google, OpenRouter and others, chosen in **Tools › Settings…**, **AI: Claude…**.

## Build a model from a sentence {#panel}

![The assistant panel beside the parts bin: a box to describe what to build, Build it with Sketch first ticked, the model and how hard it thinks, a place for your Anthropic key, and Connect your AI at its foot.](/docs/img/ai-assistant.webp "The assistant panel: say what to build, then Build it.")

1. Describe what you want in the box at the top of the panel: *a red fire engine with a ladder that lifts*. Say the size if it matters (*16 by 16 studs*, *about 30 cm long*).
2. For something real, **Add a picture of it**: a photo or drawing, whose proportions are measured rather than remembered.
3. Press **Build it**. With **Sketch first** ticked, as it is for a new model, you choose from three sketches first (below).
4. Watch it build: each part goes down as it is placed, and the panel says what it is doing.
5. When it has finished, the whole design is one step of **Undo**. Change any part by hand, or ask for changes in the box.

**New chat**, at the top of the panel, starts a fresh conversation; the model stays.

<!-- covers
lib:design loop
lib:claude's design is one undo step
lib:a big check on a worker
-->

### Sketch first {#sketch}

**Sketch first**, beside **Build it**, asks for three quick sketches of the idea, each under 150 parts, on a cheaper model. They come as cards with their sizes: choose the shape you mean with **Design this one**, and the full design is built from it at your own model and effort. It is the cheap way to find out whether the brief was understood.

<!-- covers
ui:sketch first
-->

### Model and effort {#model-effort}

The two menus under **Build it** choose which Claude designs (Opus, Sonnet or Haiku) and how hard it thinks, from low to max. Higher effort takes longer and costs more; medium costs about a third of the default. A model that takes no effort setting shows none.

<!-- covers
lib:model and effort settings
-->

### Your API key {#api-key}

With no AI app connected and no other AI chosen, the panel asks for an Anthropic key the first time: see [Claude on your own key](/docs/connect#api-key). **Change key**, at the panel's foot, forgets it for another.

## Change only the parts you select {#ask}

![A part's right-click menu with the assistant on: Ask Claude about this…, with its key Ctrl+K, at the top, above the menu's other commands.](/docs/img/ai-ask.webp "Right-click a part: Ask Claude about this…")

1. Select the parts to change.
2. Right-click one and choose **Ask Claude about this…**, or press [[Ctrl+K]] (also in the **Tools** menu).
3. Say what you want: *make this wing longer*, *why does this fall off?*, *add a door here*.

The AI may change only the selected parts and the space just round them, or a bigger box if it asks and you allow it. Everything else stays where it is, and a change that reaches outside is refused whole. In [View › Stress](/docs/the-view#stress), a red part's menu also has **Ask Claude to brace this…**.

<!-- covers
ui:ask claude about the selection
-->

## Reference pictures {#references}

For a real subject, a landmark, a vehicle or an animal, the AI looks up a reference picture on Wikimedia Commons and sizes the model from it. Only the picture's address goes out, from your browser. Or give it your own with **Add a picture of it**.

<!-- covers
lib:reference pictures
lib:find a reference picture
-->

## Another AI designing {#other-ais}

Chosen in Settings ([how](/docs/connect#other-ai)), another AI gets the same instructions and tools Claude does, is held to the same checks, and gets the same [fresh look](/docs/fresh-eyes) at its first save. The app names it wherever it would say Claude: the toolbar says *GPT-6.1 Sol working*, its steps in **Edit › History** are its own (*GPT-6.1 Sol's submit design*), and the part's menu says **Ask GPT-6.1 Sol about this…**. A design goes down brick by brick while the AI is still writing it, and gives way to the checked model when it is done.

<!-- covers
lib:designing on Anthropic's Messages or Gemini's own API
lib:designing on OpenAI's Responses
lib:saying who designs
lib:a design drawn as any provider writes it
-->

## In the desktop app {#desktop}

> [!NOTE]
> The desktop app is coming soon. These two run there only, because a browser cannot start a program on your computer.

### On your Claude plan {#my-claude}

With Claude Code installed and signed in, **My Claude** beside the model menus designs on your Claude plan with no key: the panel starts Claude Code for you, pointed at this window and nothing else. A new design is made twice at once, the second in a copy of the app with no window; the better is kept, and Undo brings back the other.

<!-- covers
ui:design on your own subscription
lib:best of two
-->

### On your GitHub Copilot plan {#my-copilot}

With the GitHub Copilot CLI installed and signed in (`copilot login`), **My Copilot** designs on your Copilot plan, with the model you chose there. Copilot gets this window's tools and nothing else: no shell, no files, none of your other MCP servers. Both can also be started from a terminal: [the command line](/docs/claude-code#command-line).

<!-- covers
ui:design on your own Copilot plan
-->

Read on: [how the AI works](/docs/how-ai-works), and [fresh eyes](/docs/fresh-eyes), the second look every new design gets.
