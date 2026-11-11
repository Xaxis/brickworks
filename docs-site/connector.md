---
tools: tabs, select_tab
panels: ClaudeTabView#tabs
ai: The connector at https://brickworks.diy/api/mcp lets the person's own AI app (Claude and its apps, ChatGPT, Gemini, Claude Code, Codex, Cursor and the others on /docs/connect) build in their open Brickworks tab. Each tab has a short id; a chat works in one tab, chosen with select_tab or target, and long work runs as jobs. A tab says it is alive every ten seconds, so a tab busy with long work is waited for, not called closed.
rules:
  - With several tabs open, a chat's first change waits until it chooses one: select_tab, or target on a call.
  - A client waits about three minutes for an answer; renders, booklets, Studio files and recordings answer with a job number, and any call still going after 20 s becomes one.
  - A tab that has not answered for 45 s while in view is busy: a call waits up to 30 s for it and the chat keeps the tab. Closed is a page that said it has gone, or three minutes of silence.
  - An assistant's undo stops at a step another chat made.
  - The person allows each AI app once. Disconnect ends it: in the app's Account it ends every AI app's connection, in the site's Settings one at a time.
title: The connector
nav: The connector
description: How the AI app you use builds in Brickworks: one address, one sign-in, the tab each chat builds in, long work, what it can see, and how to disconnect.
---

The connector lets the AI app you already use, Claude, ChatGPT, Gemini or another, build in your open Brickworks tab while you watch. One address serves every account and every app:

```text
https://brickworks.diy/api/mcp
```

<!-- covers
api:POST /api/mcp
-->

## Connect {#connect}

Each AI app takes the address its own way: **Tools › Connect your AI…** does it for you, and [Connect your AI](/docs/connect) has a page for each. Then:

1. The app sends you to Brickworks to sign in, by an emailed code, or straight on if this browser is signed in. Press **Allow**.
2. You are back in the app, connected. One added on claude.ai is in the Claude desktop and mobile apps too, and in Claude Code on the same account.

<!-- covers
ui:connect Claude sign-in page
api:Claude's OAuth sign-in
-->

You allow each app once. To connect Claude again after a disconnect, press **Connect** on the Brickworks already in Claude's **Customize › Connectors**: adding it again sets up a new one, with its tool permissions to choose again.

## Build {#build}

With Brickworks open and signed in, in any browser, ask your AI: *"build a small red house in Brickworks"*. It builds in your open tab, on whichever device, while you watch. Each change it makes is one step of **Undo**.

Claude asks before each Brickworks tool until you choose **Always allow** for the tools you trust, in **Customize › Connectors**, Brickworks, *Tool permissions*. Those switches are Claude's; Brickworks tells Claude which of its tools only look and change nothing.

## Several tabs, several chats {#tabs}

Each tab has a short name while your AI can reach it, on the toolbar: `Tab k7qd`. A press on it opens **Account**.

![The toolbar's right end while a Claude chat works in the tab: a green dot and Claude working · tab k7qd, beside Account.](/docs/img/connector-toolbar.webp "The toolbar names the tab, and says when a chat is working in it.")

- **Start the chat from the tab.** **New chat for this tab**, in **Account** and under *Connect your AI*, opens claude.ai on a new chat whose first message names the tab: *Use my Brickworks tab k7qd ("Castle") for this chat.* Add what to build and send it. For another app it copies that message, or a command for Claude Code, Codex or Gemini CLI.
- **A chat that has not chosen asks first.** With one tab open, a new chat works there. With several, its first change does nothing until it chooses a tab, by its name or its model's (*work in the castle tab*).
- **A chat stays in its tab** until it chooses another. Clicking into another tab to watch changes nothing.
- **Two chats in one tab?** Account has **Keep this one** beside each; the other is asked to choose another tab.
- **Undo keeps to its own chat.** An AI's `undo` stops at a step another chat made. Your own **Undo** takes back any step.

![Account's Your AI: Claude connected since 4 Oct and last used 1 Nov, this tab's name k7qd to say to Claude, no chat working in it yet, New chat for this tab, Open in Claude and Disconnect Claude.](/docs/img/connector-account.webp "Account: your AI apps, this tab's name and a new chat for it.")

<!-- covers
ui:this tab and its claude chats
-->

## Long work, and a busy tab {#jobs}

An AI app waits about three minutes for an answer. So a render, a booklet, a Studio file, a picture or a recording answers at once with *Started job N*, as does any call still going after 20 seconds, and goes on in the tab with its bar showing. The AI follows it with the `job` tool, and gets the answer when it is done.

A tab tells the connector every ten seconds that it is open, whatever it is busy with. One that goes quiet while in view is busy, not gone: a call waits up to half a minute for it, is told it is busy, and the chat keeps its tab. A tab is closed only when its page says so, or after three minutes of silence. A browser may pause a tab out of view: bring it into view for a moment. Nothing built is lost: each tab's model is kept as it goes.

## What your AI can see and do {#tools}

What you do from the menus, your AI can do with a tool: design and edit, check, edit the steps and the booklet, set up its page (`page_setup`), keep parts in your palettes (`palettes`, `edit_palette`), pose, simulate, render, export, and more.

It sees what you see. `view_board` shows the model from up to six sides in one picture, with chosen parts picked out, parts made see-through, or as built to a step; `booklet_page` shows a booklet page as it prints; `in_view` says your step, the part in your hand and what you have selected. Looking changes nothing.

The [MCP tool reference](/docs/mcp-tools) lists every tool; [How a design session works](/docs/design-session) says how an AI uses them.

<!-- covers
lib:the window's commands over mcp
lib:the gallery over mcp
-->

## The model in Claude, in 3D {#in-claude}

In a Claude app that shows pages, the model appears beside the chat as a card you can turn in 3D: pick a part, check it, step through its instructions, read its parts list, go full screen, or **Open in Brickworks**. The card is drawn from the model as it was when Claude last looked.

<!-- covers
ui:the model in Claude in 3D
lib:the model in Claude
lib:the model packed for the viewer
lib:the viewer's own tools
-->

## Disconnect {#disconnect}

- **In Brickworks**, **Account**, *Your AI*: **Disconnect Claude** (it names every app connected, *Disconnect Claude and ChatGPT*) ends every AI app's connection to your account at once.
- **On the site**, [Settings](/settings), *Assistants*: **Disconnect** beside one app ends only that one, after asking.

Either way the app must connect and be allowed again, and it may forget the tool permissions you gave it. Deleting your account ends every connection too. A new tool your AI cannot see is not a reason to disconnect: start a new conversation, or see [Troubleshooting](/docs/troubleshooting#new-tools).
