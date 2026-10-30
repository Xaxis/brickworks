---
ai: Claude Code builds in Brickworks through the connector (claude mcp add --transport http brickworks https://brickworks.diy/api/mcp) or straight into a desktop window over its local port, with tools/brickworks_mcp.py as the bridge.
rules:
  - The desktop window must be started with --mcp; the bridge relays to 127.0.0.1:8787.
  - When a tool is missing, /mcp, brickworks, Reconnect.
title: Claude Code
nav: Claude Code
description: Build in Brickworks from Claude Code, over the connector or straight into a desktop window.
---

Claude Code can build in Brickworks two ways: through the same connector claude.ai uses, into your open tab anywhere, or straight into a desktop window on the same computer.

## Through the connector {#connector}

```sh
claude mcp add --transport http brickworks https://brickworks.diy/api/mcp
```

Then `/mcp` in Claude Code and **Authenticate** (or `claude mcp login brickworks` from a shell). Your browser opens on the Brickworks sign-in; **Allow**, and Claude Code holds the token. With Brickworks open and signed in, ask it to build. The [connector's rules for tabs](/docs/connector#tabs) apply: **New chat for this tab** in Account offers the first message as a command line.

## Into a desktop window {#desktop}

Start the desktop app with its local port open, then add the bridge that ships with Brickworks' source:

```sh
./brickworks.x86_64 -- --mcp
claude mcp add brickworks -- /path/to/brickworks/tools/brickworks_mcp.py
```

The bridge relays Claude Code's calls to the window over `127.0.0.1:8787`. It serves the tools the app itself offers, so the two cannot drift; while the app is closed it answers from a copy, and tells Claude Code when the app's list changes. `tools/brick.py` calls one tool from a shell, for scripts: `tools/brick.py search_parts '{"query":"wedge"}'`.

<!-- covers
cli:mcp server
cli:drive the app from a shell
-->

## Started for you {#started-for-you}

In the desktop app with Claude Code installed and signed in, the assistant panel can start Claude Code itself, so a design runs on your plan with no key. See [On your Claude plan, in the panel](/docs/ai#my-claude). From a terminal, `--ask-claude-code="a small post box"` does the same at start-up.

## When tools change {#tools-change}

Brickworks tells Claude Code when its tools change. If a new tool is missing, run `/mcp`, choose **brickworks** and **Reconnect**.
