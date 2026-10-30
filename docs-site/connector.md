---
tools: tabs, select_tab
panels: ClaudeTabView#tabs
ai: The connector at https://brickworks.diy/api/mcp lets Claude (claude.ai and its apps, and Claude Code) and ChatGPT build in the person's open Brickworks tab. Each tab has a short id; a chat works in one tab, chosen with select_tab or target, and long work runs as jobs.
rules:
  - With several tabs open, a chat's first change waits until it chooses one: select_tab, or target on a call.
  - A client waits about three minutes for an answer; renders, booklets, Studio files and recordings answer with a job number.
  - An assistant's undo stops at a step another chat made.
  - The person allows the connector once; Disconnect Claude in Account ends it.
title: The Claude connector
nav: The Claude connector
description: Connect Brickworks to Claude on your Claude plan, choose which tab each chat builds in, and see the model in 3D inside Claude.
---

The connector lets Claude, in claude.ai or the Claude desktop and mobile apps, build in your Brickworks. One address serves everybody:

```text
https://brickworks.diy/api/mcp
```

<!-- covers
api:POST /api/mcp
-->

## Connect {#connect}

1. In Brickworks, with the assistant on, press **Connect Claude** in the assistant panel (or **Tools › Claude connector…**).
2. claude.ai opens its *Add custom connector* dialog with the name and address filled in. Press **Add**, then **Connect**.
3. Claude sends you to Brickworks to sign in, by email code, or straight to the question if this browser is already signed in. It names who is asking and where the answer goes. Press **Allow**.
4. You are back in Claude, connected. A connector added on claude.ai is in the Claude desktop and mobile apps too, and in Claude Code signed in with the same Claude account.

<!-- covers
ui:connect Claude sign-in page
api:Claude's OAuth sign-in
-->

Brickworks asks you to Allow once, and not again while Claude stays connected. To connect again after a Disconnect, press **Connect** on the Brickworks already in **Customize › Connectors**: adding it a second time sets up a new one, with its tool permissions to choose again.


## In ChatGPT {#chatgpt}

The same address connects ChatGPT, on a ChatGPT plan that lets you add a custom MCP server (whether yours can is your plan's and workspace's say):

1. At **chatgpt.com/plugins**, press **+**, then **Add custom MCP server**.
2. Name it **Brickworks**. Connection: a public endpoint, `https://brickworks.diy/api/mcp`; Authentication: **OAuth**.
3. Read the warning, **I understand and want to continue**, then **Create as a plugin**.
4. Brickworks asks *Let ChatGPT build in Brickworks?* and says you will go back to chatgpt.com: sign in if you need to, then **Allow**.
5. Install the plugin with the tools it lists. In a new chat, `@` and **Brickworks**, then ask it to build.

Its connection is listed in **Account** as ChatGPT, and **Disconnect** ends it as it ends Claude's. When Brickworks' tools change, **Refresh** on the plugin's page at chatgpt.com/plugins, then start a new chat.

## Build {#build}

With Brickworks open and signed in in any browser, ask Claude: *"build a small red house in Brickworks"*. Claude's calls go to your account's open tab, on whichever device it is, and you watch it build. Each change Claude makes is one undo step.

Claude asks before each Brickworks tool until you choose **Always allow** for the tools you trust, in **Customize › Connectors**, Brickworks, *Tool permissions*. Those switches are Claude's. Brickworks tells Claude which of its tools only look and change nothing: see [the tool reference](/docs/mcp-tools).

## Several tabs, several chats {#tabs}

Each tab has a short name while Claude can reach it, shown on the toolbar: `Tab k7qd`. **Account** says it in full, with the model's name.

- **Start the chat from the tab.** **New chat for this tab** (in Account, and in the assistant panel's *Or with your Claude plan*) opens claude.ai on a new chat with its first message filled in: *Use my Brickworks tab k7qd ("Castle") for this chat.* Add what to build and send it. It is copied too, and offered as a command line for Claude Code.
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
