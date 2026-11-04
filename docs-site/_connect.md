---
ai: How {called} connects to Brickworks: {way_words}, at https://brickworks.diy/api/mcp. Who can add it: {plan} Then the person signs in to Brickworks and allows it, once, and it builds in their open tab.
rules:
  - The connector's address is https://brickworks.diy/api/mcp, the same for every account and every AI app.
  - The person signs in to Brickworks and presses Allow once for each AI app; Disconnect, in Settings on the site, ends it.
title: Connect {called}
nav: {name}
description: Add Brickworks to {called}, sign in once, and it builds in your open Brickworks tab while you watch.
---
<!--
  One page for every AI app in assets/assistants.json, made by
  tools/docs_site.py from this template and that app's row. Edit the
  table for what is true of one app, and this for what every page says.
-->

## Before you start {#before}

- **Who can add it:** {plan} *Checked on {checked}.*
- **In Brickworks:** an account, and the assistant on: **Tools › Settings…**, *Assistant (AI)*, **Show the assistant**. Or [open the app with it on](/app?assistant=on).
<!-- if limits -->
- **Not yet:** {limits}
<!-- end -->

## Add Brickworks {#add}

In Brickworks, **Connect your AI** at the foot of the assistant panel (or **Tools › Connect your AI…**) does this for you: choose **{name}** under *Your AI* and press **Connect {called}**.
<!-- if way=link -->
{name} opens with Brickworks filled in. Or press this link yourself:

<p><a class="cta" href="{add_href}">Add Brickworks to {name}</a></p>

{steps}
<!-- end -->
<!-- if way=command -->
It copies this command. Or copy it here:

```sh
{add}
```

{steps}
<!-- end -->
<!-- if way=open -->
It copies Brickworks' address and opens {name}'s own page. Or copy the address here, then open [{add_shown}]({add}):

```text
{address}
```

There:

{steps}
<!-- end -->
<!-- if way=copy -->
It copies Brickworks' address, for any app that takes a remote MCP server. Or copy it here:

```text
{address}
```

{steps}
<!-- end -->

## Sign in {#sign-in}

<!-- if way=link,command,open -->
{name} sends you to Brickworks to sign in, with a code we email you, or straight on if this browser is signed in already. Brickworks asks *Let {name} build in Brickworks?* Press **Allow**.
<!-- end -->
<!-- if way=copy -->
Your AI app sends you to Brickworks to sign in, with a code we email you, or straight on if this browser is signed in already. Brickworks asks whether to let it build, by the name the app gives itself. Press **Allow**.
<!-- end -->

That is once for {called}: it stays connected, for every Brickworks tab you open, until you disconnect it.

## Build {#build}

With Brickworks open and signed in, ask {called}: *"build a small red house in Brickworks"*. It builds in your open tab, on whichever device it is, and you watch every step. Each change it makes is one step of Undo.

With several tabs open, start the chat from the one you want: **New chat for this tab**, in **Account** and under **Connect your AI**, {new_chat}. More in [Several tabs, several chats](/docs/connector#tabs).

## If something is wrong {#trouble}

- **{Called} will not let you add it.** Which of its plans can add it is for {called} to say, and may have changed since we checked. Otherwise [another AI app](/docs/connect) or [your own API key](/docs/connect#api-key) designs on any Brickworks plan.
- **Added it before?** Connect the Brickworks already in {called} rather than adding it again: adding it again sets up a new one, with its tool permissions to choose again.
- **A new Brickworks tool is missing.** Start a new chat. Still missing, connect Brickworks again in {called}.
- **It built in the wrong tab.** Start each chat from its tab, as above: a chat stays in the tab it chose.
- **To stop it,** press **Disconnect** beside it in your [Settings](/settings), under *Assistants*. Connecting again asks you to Allow again.

More in [Troubleshooting](/docs/troubleshooting).
