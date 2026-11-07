---
ai: The same Brickworks runs in a browser tab and as a desktop app; a model is the same file in both and saved models follow the account. Each browser tab or desktop window holds its own model, and the desktop window opens a local MCP port with --mcp.
rules:
  - Each browser tab is its own model, with its own id (/app?tab=<id>).
  - The desktop's MCP port is 127.0.0.1:8787 (--mcp=PORT for another window).
  - A tab told it has been updated saves nothing to saved models until it is reloaded.
title: The web app and the desktop app
nav: Web and desktop
description: Open Brickworks in a browser, and what the desktop app, coming soon, adds.
---

There is one Brickworks, in two places. Everything you build is the same file in both, and your saved models follow your account.

## In a browser {#web-app}

Open [brickworks.diy/app](/app). It needs a recent browser on a computer, a tablet or a phone: it runs on WebGL 2 and WebAssembly threads. Nothing is installed.

- **On a tablet or a phone** the app is laid out for a finger: one row of tools, and the parts, the colours and the rest in panels beside the model or, on a phone, in sheets over it. Tap selects or puts down the part in hand, hold removes, a drag turns the view and two fingers slide and zoom. Along the top, the Brickworks mark opens About, Send feedback, the docs, **Account…** and **Back to brickworks.diy**; with the assistant on, its button sits beside the model's name. A browser window as small as a phone gets this layout too, whatever you point with. In the parts sheet the search and the chips scroll with the parts, and the count, **Prints** and **List** stay at its foot, on the screen whichever way the phone is held.
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

The desktop app for Linux, macOS and Windows is coming soon ([the desktop app's page](/download)): it carries every part on disk and builds with no network at all, and it will be free, like the web app ([Plans](/docs/plans)). Until it is out, [open Brickworks in your browser](/app): it is the same builder. If you have the desktop app already, it keeps itself up to date, and what follows is how it works.

- **File › New window** ([[Ctrl+Shift+N]]) opens a second window with its own model.
- File choosers open where you last used one of their kind, or else Pictures, Documents or Downloads, and every export asks where to save.
- While it loads, the Brickworks mark shows on the app's dark face.
- **Brickworks › About Brickworks** names every piece of other people's work in Brickworks with its terms, and opens each licence in full.
- On Linux, installed from the .deb, a folder of `.ldr`, `.mpd` and `.io` files shows a picture of each model in Files and the file managers like it, from the front corner as Brickworks draws it, where it showed the same icon for each. Parts the library has not got are left out of the picture; a file with none it knows keeps its icon.

<!-- covers
ui:download page
ui:where a chooser opens
ui:save dialog on the desktop
ui:the boot splash
ui:about and the licences
-->

### Updates {#updates}

The desktop app keeps itself up to date. Once a day, a few seconds after it opens, it asks whether a newer version is out; **Help › Check for updates…** asks at once, and says *You're up to date* with the version you have, or what is new.

- **Settings › Updates** chooses how: **Automatic** (the default) downloads a new version in the background and puts it in place when you quit, or at once with **Update and restart**; **Ask first** says it is out and downloads it when you press; **Off** asks nothing until you use Help.
- A notice above the model says when a version is out or ready, with **What's new**, **Update and restart** and **Later**. Restarting saves the model first, and the window comes back with it as it was.
- **Help › Restart Brickworks** quits and starts again the same way. **Help › Reinstall Brickworks…** downloads the version you have again and puts it in place, to repair a damaged install; your models and settings are kept.
- Brickworks installs only what its own release signed, downloaded from GitHub over HTTPS and checked against that release's size and checksum. It never installs an older version than yours. The old copy is kept until the new one has started, and put back if it does not.
- Installed where it may not write (a tar.xz unpacked under `/opt`, say), it says so and opens [the desktop app's page](/download) instead. A Mac app run from Downloads or a disk image moves itself to Applications as it updates.

<!-- covers
ui:update notice
ui:check for updates reinstall and restart
lib:the desktop app updates itself
lib:the signed update manifest
-->

### From the command line {#command-line}

The desktop app also runs from a terminal. The program is `./brickworks.x86_64` on Linux, `Brickworks.app/Contents/MacOS/Brickworks` on a Mac and `Brickworks.console.exe` on Windows; what it is asked comes after `--`:

```sh
./brickworks.x86_64 --headless -- --about                         # which build this is
./brickworks.x86_64 --headless -- --model=castle.ldr --out=copy.ldr   # open a model, write it out
./brickworks.x86_64 -- --view=<id>                                 # open a shared model to look at
./brickworks.x86_64 -- --together=<secret>                         # join a Build together session
./brickworks.x86_64 -- --mcp                                       # open the local MCP port
./brickworks.x86_64 --headless -- --thumbnail castle.ldr castle.png 256   # a picture of a model, 256 px
```

<!-- covers
cli:a model file's picture
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
