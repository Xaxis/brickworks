---
ai: The ways to have an AI design in Brickworks, every one of them the person's own: the AI app they already use (Claude, ChatGPT, Gemini, Claude Code, Cursor and the others below) through the connector, each with a page saying how it adds Brickworks; Claude on their own Anthropic key in the assistant panel; or another AI on their own key (OpenAI, Google Gemini, OpenRouter, Mistral and others, or a model on their own computer), chosen in Settings, AI. All of them work in the web app. The assistant must be switched on first (Settings, Assistant (AI)).
rules:
  - The connector's address is https://brickworks.diy/api/mcp, the same for every account and every AI app.
  - With Build by hand only, the assistant's panel, its commands and the connector are gone from the window.
  - A key is checked with its provider before it is kept, and is sent only to that provider.
  - Brickworks has no AI and no provider key of its own; whatever AI designs is the person's, billed by its maker.
generated: assistants
panels: AiSettings#other-ai
title: Connect your AI
nav: Connect your AI
description: Bring the AI you already use to Brickworks: your AI app, Claude on your own key, or another AI on your own key, all in the web app.
---

Brickworks has no AI of its own: you bring yours, so it is never limited and Brickworks never bills for it, on any plan ([Plans](/docs/plans#ai)). Bring the AI app you already use, or a key from an AI provider; each works in the web app. Turn the assistant on first.

## Turn the assistant on {#assistant-on}

**Tools › Settings…** ([[,]]), then under *Assistant (AI)* choose **Show the assistant**, or [open the app with it on](/app?assistant=on). A first visit builds by hand, and with **Build by hand only** chosen the assistant's panel, its menu commands and the connector are all gone from the window.

<!-- covers
ui:assistant on or off
-->

## Your AI app {#apps}

The AI app you already use builds in your open Brickworks tab while you talk to it there, on your plan with it. Every app adds Brickworks at the same address and signs in the same way; what differs is how it takes the address and which of its plans may. Each page says both, with the day we checked.

<!-- generated -->

## Connect it from the app {#in-the-app}

![Or connect your AI, at the foot of the assistant panel: Your AI set to Claude, what each Claude plan needs, and the Connect Claude button.](/docs/img/connect-your-ai.webp "Tools › Connect your AI…: choose your app, then Connect.")

1. Open **Tools › Connect your AI…**, or scroll to the foot of the assistant panel.
2. Under **Your AI**, choose the app you use. Who can add it, and what it cannot do yet, is said under it.
3. Press **Connect** (it names the app: **Connect Claude**, **Connect ChatGPT**). It opens the app's link, copies its command, or copies the address and opens its page, and says what to do there.
4. The app sends you to Brickworks to sign in, with a code we email you, or straight on if this browser is signed in already. Press **Allow**.
5. Ask it to build, in the app: *"build a small red house in Brickworks"*.

![The Brickworks page your AI app opens, here for Claude: signed in as you@example.com, it asks Let Claude build in Brickworks?, lists what it will be able to do, and has Allow and Cancel buttons.](/docs/img/connect-allow.webp "The one question Brickworks asks, once for each app.")

That is once for each app: it stays connected, for every Brickworks tab you open, until you disconnect it. Tabs, chats and long work are in [The connector](/docs/connector).

<!-- covers
ui:connect your AI
-->

## Claude on your own key {#api-key}

*Pay as you go: Anthropic bills each design to your key.*

1. Make a key at [console.anthropic.com](https://console.anthropic.com), safest in a workspace of its own, with a spend limit, set to expire.
2. Paste it into the assistant panel, under *With your Anthropic API key*, and press **Use this key**. It is checked with Anthropic before it is kept; untick **Remember it on this device** to keep it for this visit only.
3. Describe what you want and press **Build it** ([Designing with AI](/docs/ai#panel)).

Measured at the default setting, a small house took 11 minutes and $2.40, and a castle 45 minutes and $5 to $10. Medium effort costs about a third.

## Another AI on your own key {#other-ai}

![Settings' AI page with Another AI, on your own API key chosen: the provider, OpenAI, a box to paste its API key with Show, and Remember on this device.](/docs/img/connect-other-ai.webp "Tools › Settings…, AI: Claude…, then Another AI.")

1. **Tools › Settings…** ([[,]]), then **AI: Claude…** beside *Assistant (AI)*. The link names who designs now.
2. Choose **Another AI, on your own API key**.
3. **Provider**: OpenAI, the Anthropic API, Google Gemini, OpenRouter, Mistral, Groq, Together, DeepSeek or xAI; Ollama, LM Studio or vLLM on your own computer; or any other server that speaks OpenAI's Chat Completions, at an **Address** you give.
4. **API key**: paste it and press [[Enter]]. It is kept at once and the field cleared; its fingerprint (`sk-pro…abcd`) says which key is kept. **Show** shows it as you type, untick **Remember on this device** to keep it for this visit only, and **Forget the key** deletes it.
5. **Model**: the provider's own list, asked for once there is a key. Type to filter it, or type a model's id and press [[Enter]] to use one not listed.
6. Where the model takes them: **Temperature** (tick **Set**), **Max output** in tokens (0 is the model's own) and **Reasoning**.
7. **Test** asks the model for one tool call and the colour of one small picture, for less than a cent, and says plainly what works: an AI that cannot call tools cannot design, and one that cannot see pictures cannot judge its own work.
8. **Design with it** goes back to the assistant panel, ready for your brief. What changes when it designs: [Another AI designing](/docs/ai#other-ais).

<!-- covers
ui:choose the AI that designs
lib:designing with any provider on the person's key
-->

### A model on your own computer {#own-computer}

Ollama, LM Studio or vLLM on your computer answers the web app if it allows brickworks.diy (for Ollama, `OLLAMA_ORIGINS`), and the browser asks you first. A server elsewhere that is not in the list needs the desktop app, coming soon.

### Where your key is kept {#key-custody}

Settings says this beside the key, for where you are, and a key pasted in the assistant panel for Claude is kept the same way. Everywhere, a key is sent only to its provider (or the address you gave), never to Brickworks, and never logged or saved with a model.

| Where | How the key is kept |
|---|---|
| In a browser | In this browser's storage for brickworks.diy, scrambled but not secret: anyone using this browser could recover it, so untick **Remember** on a shared computer. |
| For this visit only | Nowhere on the device; gone when the tab closes. |
| The desktop app, coming soon | In the computer's keyring (GNOME Keyring or KWallet, the login Keychain, Windows Credential Manager), locked with your login; where none answers, in a file encrypted to that computer. |

> [!NOTE]
> The site's security policy lets the page reach only the providers listed and your own computer, and runs no script but Brickworks' own, so a key has nowhere else to go.

<!-- covers
lib:a person's own keys kept in the system's keychain
-->
