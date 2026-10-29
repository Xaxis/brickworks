---
title: Connect Claude
nav: Connect Claude
description: The two ways to have Claude design in Brickworks, your Claude plan or your own API key, set up in a minute.
---

Building by hand needs nothing but an account, and there is no AI in the window until you ask for it. To have Claude design, turn the assistant on and bring your own Claude. Brickworks bills nothing for it.

## Turn the assistant on {#assistant-on}

**Tools › Settings…**, then under *Assistant (AI)* choose **Show the assistant**. A first visit builds by hand, and with **Build by hand only** chosen the assistant's panel, its menu commands and the connector are all gone from the window.

<!-- covers
ui:assistant on or off
-->

## Your Claude plan {#claude-plan}

*Claude Pro or Max: no key, nothing to install.*

1. Open the app with the assistant on and press **Connect Claude** at the foot of the assistant panel.
2. claude.ai opens with Brickworks filled in as a custom connector. Press **Add**, then **Connect**.
3. Brickworks asks you to sign in (or goes straight on, if this browser is signed in) and to **Allow** Claude to build in your account.
4. In any Claude chat, ask: *"build a small red house in Brickworks"*. It builds in your open tab, on any device, and you watch every step.

This connects once for your account; the Claude desktop and mobile apps have it too. It counts against your plan's usage like any other chat. More in [The Claude connector](/docs/connector).

## Claude Code {#claude-code}

```sh
claude mcp add --transport http brickworks https://brickworks.diy/api/mcp
```

Then `/mcp` in Claude Code and **Authenticate**. More in [Claude Code](/docs/claude-code).

## Your own API key {#api-key}

*Pay as you go, from the Anthropic Console.*

1. Make a key at [console.anthropic.com](https://console.anthropic.com), safest in a workspace of its own, with a spend limit, set to expire.
2. Paste it into the assistant panel. It is checked with Anthropic before it is kept, in your browser or for this visit only.
3. Describe what you want and press **Build it**. Choose the model and how hard it thinks.

Measured at the default setting, a small house took 11 minutes and $2.40, and a castle 45 minutes and $5 to $10. Medium effort costs about a third. More in [Designing with AI](/docs/ai).

> [!NOTE]
> The key stays in your browser and is sent only to Anthropic. The page's security policy refuses to send anything anywhere but its own short list, so a key has nowhere else to go.
