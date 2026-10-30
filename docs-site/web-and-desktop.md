---
ai: The same Brickworks runs in a browser tab and as a desktop app; a model is the same file in both and saved models follow the account. Each browser tab or desktop window holds its own model, and the desktop window opens a local MCP port with --mcp.
rules:
  - Each browser tab is its own model, with its own id (/app?tab=<id>).
  - The desktop's MCP port is 127.0.0.1:8787 (--mcp=PORT for another window).
  - A tab told it has been updated saves nothing to saved models until it is reloaded.
title: The web app and the desktop app
nav: Web and desktop
description: Open Brickworks in a browser or install it, sign in, and what each one does that the other does not.
---

There is one Brickworks, in two places. Everything you build is the same file in both, and your saved models follow your account.

## In a browser {#web-app}

Open [brickworks.diy/app](/app). It needs a recent browser on a computer, a tablet or a phone: it runs on WebGL 2 and WebAssembly threads. Nothing is installed.

- **On a tablet or a phone** the app is laid out for a finger: one row of tools, and the parts, the colours and the rest in panels beside the model or, on a phone, in sheets over it. Tap selects or puts down the part in hand, hold removes, a drag turns the view and two fingers slide and zoom. Along the top, the Brickworks mark opens About, Send feedback, the docs, **Account…** and **Back to brickworks.diy**; with the assistant on, its button sits beside the model's name. A browser window as small as a phone gets this layout too, whatever you point with.
- **Several models at once**: each browser tab is its own model. **File › New tab** opens another. A tab can be opened by its link, `/app?tab=<id>`: if that tab's model is kept in this browser it opens; if it is already open in another tab, that tab says it is the one.
- **A newer build**: when Brickworks is updated while a tab is open, the tab says *Brickworks has been updated*. Press **Reload** when it suits you; the model in the tab comes back as it was. Until you do, that tab saves nothing to your saved models, so it can never write over what a tab on the new version keeps.

<!-- covers
ui:new tab or window
ui:open a tab by link
lib:a session per tab
ui:newer build banner
lib:newer build
ui:reload a model saved elsewhere
-->

When the same model is open in two tabs and you save it in one, the other offers **Reload it**.

![Three browser tabs, each with its own model in Brickworks.](/img/compare-tabs.webp "Each tab is its own model.")

## On the desktop {#desktop}

Download it from [the download page](/download), for Linux, macOS and Windows. The desktop app carries every part on disk and builds with no network at all. It is free to download until Pro opens; then it comes with Pro, and every account made before 29 October 2026 keeps it free ([Plans](/docs/plans)).

- **File › New window** ([[Ctrl+Shift+N]]) opens a second window with its own model.
- File choosers open where you last used one of their kind, or else Pictures, Documents or Downloads, and every export asks where to save.
- While it loads, the Brickworks mark shows on the app's dark face.
- **Brickworks › About Brickworks** names every piece of other people's work in Brickworks with its terms, and opens each licence in full.

<!-- covers
ui:download page
ui:where a chooser opens
ui:save dialog on the desktop
ui:the boot splash
ui:about and the licences
-->

### From the command line {#command-line}

The desktop app also runs from a terminal. The program is `./brickworks.x86_64` on Linux, `Brickworks.app/Contents/MacOS/Brickworks` on a Mac and `Brickworks.console.exe` on Windows; what it is asked comes after `--`:

```sh
./brickworks.x86_64 --headless -- --about                         # which build this is
./brickworks.x86_64 --headless -- --model=castle.ldr --out=copy.ldr   # open a model, write it out
./brickworks.x86_64 -- --view=<id>                                 # open a shared model to look at
./brickworks.x86_64 -- --together=<secret>                         # join a Build together session
./brickworks.x86_64 -- --mcp                                       # open the local MCP port
```

<!-- covers
cli:export a model
cli:say which build this is
lib:command socket
-->

With `--mcp` the window listens on `127.0.0.1:8787` (`--mcp=PORT` for a second window), one JSON command a line: that is how [Claude Code](/docs/claude-code) can drive a desktop window directly. Your models and settings are kept in the app's own folder (on Windows, `%APPDATA%\Godot\app_userdata\Brickworks\`).

## Signing in {#sign-in}

The first time it opens, the app asks you to sign in, as everyone is. There is no password: either a six-digit code sent to your email, or **Sign in with orangecheck**, which opens its own window and accepts a Bitcoin wallet, email, Google or GitHub. A new account is asked its month and year of birth once.

<!-- covers
ui:sign-in screen
lib:account session
ui:sign in with orangecheck on the desktop
-->

See [Your account and privacy](/docs/account) for what each keeps.

## Where your models are {#where-models-are}

Saved models are kept in your browser (on your computer in the desktop app) and privately with your account, so **File › Open** shows them wherever you sign in. Nobody sees a model until you share it. See [Saving, opening and files](/docs/saving-and-files).
