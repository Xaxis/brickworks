---
tools: tabs, select_tab
panels: ClaudeTabView#tabs
ai: The connector at https://brickworks.diy/api/mcp lets the person's own AI app (Claude and its apps, ChatGPT, Gemini, Claude Code, Codex, Cursor and the others on /docs/connect) build in their open Brickworks tab. Each tab has a short id; a chat works in one tab, chosen with select_tab or target, and long work runs as jobs.
rules:
  - With several tabs open, a chat's first change waits until it chooses one: select_tab, or target on a call.
  - A client waits about three minutes for an answer; renders, booklets, Studio files and recordings answer with a job number.
  - An assistant's undo stops at a step another chat made.
  - The person allows each AI app once; Disconnect, in Account or the site's Settings, ends it.
title: The connector
nav: The connector
description: How the AI app you use builds in Brickworks: one address, one sign-in, the tab each chat builds in, long work, and the model in 3D inside Claude.
---

The connector lets the AI app you use, Claude, ChatGPT, Gemini or another, build in your Brickworks. One address serves everybody, and every app:

```text
https://brickworks.diy/api/mcp
```

<!-- covers
api:POST /api/mcp
-->

## Connect {#connect}

Each AI app takes the address its own way, in the fewest steps it allows: [Connect your AI](/docs/connect) has a page for each. Then, for every one of them:

1. The app sends you to Brickworks to sign in, by email code, or straight to the question if this browser is already signed in. It names who is asking and where the answer goes. Press **Allow**.
2. You are back in the app, connected. A connector added on claude.ai is in the Claude desktop and mobile apps too, and in Claude Code signed in with the same Claude account.

<!-- covers
ui:connect Claude sign-in page
api:Claude's OAuth sign-in
-->

Brickworks asks you to Allow once for each app, and not again while it stays connected. To connect Claude again after a Disconnect, press **Connect** on the Brickworks already in **Customize › Connectors**: adding it a second time sets up a new one, with its tool permissions to choose again.


## In ChatGPT {#chatgpt}

[Connect ChatGPT](/docs/connect-chatgpt) says how ChatGPT adds Brickworks, and which of its plans can. Once it has, install the plugin with the tools it lists; in a new chat, `@` and **Brickworks**, then ask it to build. Its connection is listed in **Account** as ChatGPT, and **Disconnect** ends it as it ends Claude's.

## Build {#build}

With Brickworks open and signed in in any browser, ask your AI: *"build a small red house in Brickworks"*. Its calls go to your account's open tab, on whichever device it is, and you watch it build. Each change it makes is one undo step.

Claude asks before each Brickworks tool until you choose **Always allow** for the tools you trust, in **Customize › Connectors**, Brickworks, *Tool permissions*. Those switches are Claude's. Brickworks tells Claude which of its tools only look and change nothing: see [the tool reference](/docs/mcp-tools).

## Several tabs, several chats {#tabs}

Each tab has a short name while Claude can reach it, shown on the toolbar: `Tab k7qd`. **Account** says it in full, with the model's name.

- **Start the chat from the tab.** **New chat for this tab** (in Account, and in the assistant panel's *Connect your AI*) opens claude.ai on a new chat with its first message filled in: *Use my Brickworks tab k7qd ("Castle") for this chat.* Add what to build and send it. It is copied too, and offered as a command line for Claude Code.
- **A chat that has not chosen asks first.** With one tab open, a new chat works there. With several, its first change does nothing until Claude chooses a tab, by its name or its model's (*work in the castle tab*).
- **A chat stays in its tab** until it chooses another. Clicking into another tab to watch changes nothing.
- **The tab says who is working in it**: *Claude working · tab k7qd* on the toolbar while a chat works there. If two chats work in one tab, Account has **Keep this one** beside each.
- **Undo keeps to its own chat.** Claude's `undo` stops at a step another chat made. Your own Undo takes back any step.

<!-- covers
ui:this tab and its claude chats
-->

## Long work {#jobs}

Claude waits about three minutes for an answer. A render, a booklet, a Studio file, a picture or a recording answers at once with *Started job N*, and goes on in the tab with its bar showing; Claude follows it with the `job` tool and gets the answer, picture and all, when it is done.

## The model in Claude, in 3D {#in-claude}

In a Claude app that shows pages, the model appears beside the chat as a card you can turn in 3D, whatever it is: pick a part, check it, step through its instructions, read its parts list, go full screen, or **Open in Brickworks**. The card is drawn from the model packed as it was when Claude last looked.

<!-- covers
ui:the model in Claude in 3D
lib:the model in Claude
lib:the model packed for the viewer
lib:the viewer's own tools
-->

## What Claude can do {#tools}

Everything you can do from the menus, Claude can do with a tool: design and edit, look from any side, check, set the floor, edit steps and the booklet, lay hoses, pose and animate, play motions, simulate, render, export, search the gallery, and more. The [MCP tool reference](/docs/mcp-tools) lists every one. [How a design session works](/docs/design-session) says how an assistant uses them, the words it is given, and the limits it works within.

<!-- covers
lib:the window's commands over mcp
lib:the gallery over mcp
-->

## Disconnect {#disconnect}

**Disconnect Claude** in Brickworks' Account ends Claude's connection, and deleting your account ends it too; Claude must connect and be allowed again. When a Brickworks tool is new and Claude cannot see it, start a new conversation, or reconnect in Claude: see [Troubleshooting](/docs/troubleshooting#new-tools).
