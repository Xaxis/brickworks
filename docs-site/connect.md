---
ai: The ways to have an AI design in Brickworks: the AI app the person already uses (Claude, ChatGPT, Gemini, Claude Code, Cursor and the others below) through the connector, each with a page saying how it adds Brickworks; or a model on the person's own API key in the assistant panel. The assistant must be switched on first (Settings, Assistant (AI)).
rules:
  - The connector's address is https://brickworks.diy/api/mcp, the same for every account and every AI app.
  - With Build by hand only, the assistant's panel, its commands and the connector are gone from the window.
  - A key is checked with its provider before it is kept, and is sent only to that provider.
generated: assistants
title: Connect your AI
nav: Connect your AI
description: Have the AI app you already use design in Brickworks, Claude, ChatGPT, Gemini or another, or bring your own API key.
---

Building by hand needs nothing but an account, and there is no AI in the window until you ask for it. To have an AI design, turn the assistant on, then connect the AI app you use, or paste your own API key. AI is never limited, on any plan: you bring your own, so Brickworks never counts it or bills for it ([Plans](/docs/plans#ai)).

## Turn the assistant on {#assistant-on}

**Tools › Settings…**, then under *Assistant (AI)* choose **Show the assistant**. A first visit builds by hand, and with **Build by hand only** chosen the assistant's panel, its menu commands and the connector are all gone from the window.

<!-- covers
ui:assistant on or off
-->

## Your AI app {#apps}

Every app adds Brickworks at the same address, signs in the same way and builds in the same tab. What differs is how it takes the address, in the fewest steps each allows, and who may add one. Each page says both, with the day we checked.

<!-- generated -->

## In the app {#in-the-app}

**Connect your AI**, at the foot of the assistant panel (or **Tools › Connect your AI…**), starts on Claude. Choose the app you use under **Your AI**, then press **Connect**: it opens that app's link, copies its command, or copies the address and opens its page, as its card above says, with its steps, who can add it and what it cannot do yet under the button. Then sign in to Brickworks and **Allow**, once for each app.

<!-- covers
ui:connect your AI
-->

## Your own API key {#api-key}

*Pay as you go, from the Anthropic Console.*

1. Make a key at [console.anthropic.com](https://console.anthropic.com), safest in a workspace of its own, with a spend limit, set to expire.
2. Paste it into the assistant panel. It is checked with Anthropic before it is kept, in your browser or for this visit only.
3. Describe what you want and press **Build it**. Choose the model and how hard it thinks.

Measured at the default setting, a small house took 11 minutes and $2.40, and a castle 45 minutes and $5 to $10. Medium effort costs about a third. More in [Designing with AI](/docs/ai).

## Another AI on your own key {#other-ai}

In the desktop app, **Tools › Settings…**, **AI…** sets another AI on your own key, from OpenAI, Google Gemini, OpenRouter and others: see [Another AI on your own key](/docs/ai#other-ais).

> [!NOTE]
> A key stays in your browser or on your computer, and is sent only to its own provider. The page's security policy refuses to send anything anywhere but its own short list, so a key has nowhere else to go.
