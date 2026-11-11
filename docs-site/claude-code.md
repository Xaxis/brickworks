---
ai: Claude Code builds in Brickworks through the connector (claude mcp add --transport http brickworks https://brickworks.diy/api/mcp), into the person's open tab, on the web or the desktop. The desktop app, coming soon, also opens a local port (--mcp) that tools/brickworks_mcp.py bridges to, and designs a brief from a terminal with --ask-claude-code, --ask-copilot or --ask-provider.
rules:
  - The desktop window must be started with --mcp; the bridge relays to 127.0.0.1:8787 (--mcp=PORT and the bridge's --port=PORT for another window).
  - When a tool is missing, /mcp, brickworks, Reconnect.
title: Claude Code
nav: Claude Code
description: Build in Brickworks from Claude Code through the connector, into your open tab; and, in the desktop app, from a terminal.
---

Claude Code builds in Brickworks through the same connector claude.ai uses, into your open Brickworks tab, wherever it is. Add it once, from a terminal; **Tools › Connect your AI…** gives you the command.

## Add Brickworks to Claude Code {#connector}

![Connect your AI after Claude Code is pressed: Copied, run it in a terminal, then /mcp, brickworks and Authenticate; below, the start of the command, claude mcp add --transport http, with a Copy button.](/docs/img/claude-code-command.webp "Connect your AI, Claude Code: the command to add Brickworks, copied.")

1. In Brickworks, **Tools › Connect your AI…**, then **Claude Code** under **Connect Claude** (or choose **Claude Code** under **Your AI** and press **Connect Claude Code**). The command is copied:

   ```sh
   claude mcp add --transport http brickworks https://brickworks.diy/api/mcp
   ```

2. Run it in a terminal, in any folder.
3. In Claude Code, type `/mcp`, choose **brickworks** and **Authenticate** (or run `claude mcp login brickworks`). Your browser opens on the Brickworks sign-in: **Allow**, and Claude Code holds the token.
4. With Brickworks open and signed in, ask Claude Code to build.

Claude Code signed in with the same Claude account as claude.ai has the connector from there already. The [connector's rules for tabs](/docs/connector#tabs) apply: **New chat for this tab**, in Account, gives a chat for one tab as a command line: `claude "Use my Brickworks tab k7qd (“Castle”) for this chat."`

## When tools change {#tools-change}

Brickworks tells Claude Code when its tools change. If a new tool is missing, run `/mcp`, choose **brickworks** and **Reconnect**.

## In the desktop app {#desktop}

> [!NOTE]
> The desktop app is coming soon. Until it is out, [the connector](#connector) reaches Brickworks in your browser, and everything below is for the desktop only.

Started with its local port open, a desktop window takes Claude Code straight in, with no sign-in, through the bridge that ships with Brickworks' source:

```sh
./brickworks.x86_64 -- --mcp
claude mcp add brickworks -- /path/to/brickworks/tools/brickworks_mcp.py
```

The bridge relays Claude Code's calls to the window over `127.0.0.1:8787`. It serves the tools the app itself offers, so the two cannot drift; while the app is closed it answers from a copy, and tells Claude Code when the app's list changes. For a second window, `--mcp=8795` and the bridge's `--port=8795`. `tools/brick.py` calls one tool from a shell, for scripts: `tools/brick.py search_parts '{"query":"wedge"}'`.

<!-- covers
cli:mcp server
cli:drive the app from a shell
-->

### Started for you {#started-for-you}

With Claude Code installed and signed in, the assistant panel can start Claude Code itself, so a design runs on your Claude plan with no key: **My Claude**, in [the assistant panel](/docs/ai#my-claude).

### From the command line {#command-line}

The desktop app can be given a brief as it starts, for Claude Code, GitHub Copilot or another AI on your own key to design. The program is `./brickworks.x86_64` on Linux (`Brickworks.app/Contents/MacOS/Brickworks` on a Mac, `Brickworks.console.exe` on Windows):

```sh
./brickworks.x86_64 -- --ask-claude-code="a small post box"
./brickworks.x86_64 -- --ask-copilot="a small post box"
./brickworks.x86_64 -- --ask-provider="a red tower" --provider=openai --provider-model=<model> --out=tower.ldr
```

`--ask-provider` reads the key from the provider's environment variable, or the one kept in Settings, and never prints it; `--provider-base=URL` names a server of your own. The rest of the command line is in [Web and desktop](/docs/web-and-desktop#command-line).

<!-- covers
cli:design with another provider from a brief
-->
