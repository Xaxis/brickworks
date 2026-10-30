---
tools: submit_design, choose_sketch, plan_scale, find_reference, how_real_sets_build_this, find_techniques, show_technique, place_technique, restyle_model, add_rooms
panels: AiSettings#other-ais
ai: How an AI designs in Brickworks: Claude or another AI on the person's own key, in the assistant panel, through the connector or Claude Code. It proposes parts and the app decides: every design is checked and sent back with what failed. A design starts with plan_scale, find_reference and how_real_sets_build_this, then submit_design.
rules:
  - The app builds what is submitted, checks it holds together, and refuses what does not.
  - A sketch is under 150 parts; three sketches, then choose_sketch one.
  - Asked about a selection, change only it (selection, edit_selection), never submit_design.
  - A whole design is one undo step.
title: Designing with AI
nav: The assistant
description: How an AI designs in Brickworks: Claude or another AI on your own key, the assistant panel, sketches, and asking about a selection.
---

An AI can design a whole model from a sentence, change a part of one, or answer a question about it: Claude, or another AI on your own API key. It builds with the same real parts and the same checks you do: the app decides whether each part fits and holds, so what goes on the baseplate is buildable. There is no AI in the window until you turn the assistant on ([Connect Claude](/docs/connect-claude#assistant-on)).

## Ways to bring an AI {#ways}

| Way | You need | Where it runs |
|---|---|---|
| [The Claude connector](/docs/connector) | A Claude Pro or Max plan | claude.ai, the Claude desktop and mobile apps, building in your open Brickworks tab |
| [ChatGPT](/docs/connector#chatgpt) | A ChatGPT plan that can add a custom MCP server | chatgpt.com, building in your open Brickworks tab |
| [Claude Code](/docs/claude-code) | Claude Code, signed in to your plan | Your terminal, or started by the desktop app for you |
| [Your API key](#api-key) | A key from the Anthropic Console | The assistant panel itself |
| [Another AI on your own key](#other-ais) | A key from OpenAI, Google, OpenRouter or another provider, or a model on your own computer | The assistant panel, chosen in **Settings › AI** |

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

## Another AI on your own key {#other-ais}

**Tools › Settings…**, then **AI…**, chooses who designs: **Claude**, as above, or **another AI on your own API key**. The other AI is given the same instructions and the same tools Claude is, builds in the window as Claude does, is held to the same checks, and answers the same [fresh look](/docs/fresh-eyes) at its first save.

<!-- covers
ui:choose the AI that designs
lib:designing with any provider on the person's key
lib:designing on Anthropic's Messages or Gemini's own API
lib:designing on OpenAI's Responses
lib:saying who designs
-->

1. **Provider**: OpenAI, the Anthropic API, Google Gemini, OpenRouter, Mistral, Groq, Together, DeepSeek, xAI, or a server that speaks OpenAI's Chat Completions: Ollama, LM Studio or vLLM on your own computer, or any other at an **Address** you give.
2. **API key**: paste it in. **Show** shows it while you type; once kept, the field is cleared and only its fingerprint is shown (`sk-pro…abcd`). **Remember on this device** keeps it; untick it to keep it for this visit only. **Forget the key** deletes it.
3. **Model**: the provider's own list, asked for as soon as there is a key; type to filter it, or type a model's id and press [[Enter]] to use one not listed.
4. **Temperature**, the most a reply may write, and the **reasoning effort**, where the model takes them.
5. **Test** asks the model for one tool call and to name the colour of one small picture, and says plainly what works: an AI that cannot call tools cannot design, and one that cannot see pictures cannot judge its own work. Each test costs less than a cent.
6. **Design with it** goes back to the assistant panel, ready for your brief. The panel then designs with the AI you chose.

The app then names the AI wherever it said Claude for the one designing: the toolbar says *GPT-6.1 Sol working* while it works, its steps in **Edit › History** are its own (*GPT-6.1 Sol's submit design*), and **Ask GPT-6.1 Sol about this…** asks it about the selection. OpenAI's own models are reached through OpenAI's Responses API, which hands the model the pictures it asks for as the answer to its own call, and carries its reasoning from one step to the next.

### Where your key is kept {#key-custody}

The panel says this beside the key, for where you are:

| Where | How the key is kept |
|---|---|
| The desktop app | On this computer only, in a file encrypted to it, so a copy taken elsewhere cannot be read. Programs running as you could still reach it, so a key with a spending limit is safest. |
| A browser | In this browser's storage for brickworks.diy, scrambled but not secret: anyone using this browser could recover it. Untick **Remember** on a shared computer. |
| For this visit only | Nowhere on the device; gone when the tab or app closes. |
| From the environment (desktop) | Read from the provider's environment variable the app was started with, and not kept by Brickworks. |

Everywhere, the key is sent only to the provider you chose (or the address you gave), never to Brickworks, and never logged or saved with a model.

> [!NOTE]
> A model on your own computer (Ollama, LM Studio, vLLM) is for the desktop app: a browser asks before a website reaches your computer, and those servers refuse other sites unless told to allow them.

### From the command line {#ask-provider}

The desktop app can design one brief with another AI and quit, the key read from the provider's environment variable or the one kept, never printed:

```sh
./brickworks.x86_64 -- --ask-provider="a red tower" --provider=openai --provider-model=<model> --out=tower.ldr
```

`--provider-base=URL` names a server of your own.

<!-- covers
cli:design with another provider from a brief
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

Read on: [how the AI works](/docs/how-ai-works), and [fresh eyes](/docs/fresh-eyes), the second look every new design gets.
