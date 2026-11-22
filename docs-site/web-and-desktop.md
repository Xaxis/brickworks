---
ai: Brickworks runs in a browser tab at brickworks.diy/app, on a computer, a tablet or a phone; a desktop app is coming soon, and a model is the same file in both, its saved copies following the account. Each browser tab or desktop window holds its own model, and the desktop window opens a local MCP port with --mcp.
rules:
  - Each browser tab is its own model, with its own id (/app?tab=<id>).
  - The desktop's MCP port is 127.0.0.1:8787 (--mcp=PORT for another window).
  - A tab told it has been updated saves nothing to saved models until it is reloaded.
title: The web app and the desktop app
nav: Web and desktop
description: Open Brickworks in a browser on a computer, a tablet or a phone, sign in, work in several tabs, and what the desktop app, coming soon, adds.
---

Brickworks is a web app: open [brickworks.diy/app](/app) and build. Nothing is installed, and the same model opens on any computer, tablet or phone you sign in on.

## Open it in a browser {#web-app}

Open [brickworks.diy/app](/app) in a recent browser on a computer, a tablet or a phone: it needs WebGL 2 and WebAssembly threads, and nothing else.

![The Brickworks menu open under the mark at the far left of the menu bar: About Brickworks, Send feedback, Find a command with its key Ctrl+/, Brickworks website, Documentation and Account.](/docs/img/web-and-desktop-menu.webp "The Brickworks menu, at the far left of the menu bar.")

The Brickworks mark at the far left of the menu bar opens the app's own menu: **About Brickworks**, **Send feedback…**, **Find a command…** ([[Ctrl+/]]), **Brickworks website**, **Documentation**, **Account…** and **Back to brickworks.diy**; a beta tester's has **Beta hub** too.

## Add it to your home screen {#install}

brickworks.diy can be installed from your browser, so it opens in a window of its own from your home screen, dock or Start menu, and can show your [notifications](/docs/profiles#settings) as the device's own. From your second visit a card at the foot of the page offers **Install**, which is your browser's own dialog; **No thanks** is kept in that browser, and **Settings › Notifications** still has **Install Brickworks** while the browser offers it. Chrome and Edge also have their own install button in the address bar.

On an iPhone or iPad, Safari has no install button a site can show: it installs only by **Share**, then **Add to Home Screen**, and the card says so. Opened from the Home Screen (iOS and iPadOS 16.4 or later), Brickworks can show notifications; in a Safari tab it cannot.

Without a connection, a page of the site you open says **You're offline.**, and opens the page you asked for by itself once you are back. Nothing else is kept: every page, the app and your models come from the network, so you always get the newest Brickworks. The app needs a connection to open.

<!-- covers
ui:installing the site
ui:offline page
lib:the site's service worker
-->

## Sign in {#sign-in}

The first time it opens, the app asks everyone to sign in. There is no password: either a six-digit code sent to your email, or **Sign in with orangecheck**, which opens its own window and accepts a Bitcoin wallet, email, Google or GitHub. A new account is asked its month and year of birth once. See [Your account and privacy](/docs/account) for what each keeps.

<!-- covers
ui:sign-in screen
lib:account session
ui:sign in with orangecheck on the desktop
-->

## Where your models are {#where-models-are}

Saved models are kept in your browser and privately with your account, so **File › Open** shows them wherever you sign in. Nobody sees a model until you share it. See [Saving, opening and files](/docs/saving-and-files).

## On a tablet or a phone {#phone}

![Brickworks on a phone, 390 pixels across: the mark, the model's name, undo and redo along the top, the red car on its baseplate with a note that it opened, and one row of tools along the foot.](/docs/img/web-and-desktop-phone.webp "On a phone: one row of tools, and the rest in sheets over the model.")

On a touch screen the app is laid out for a finger: one row of tools, and the parts, the colours and the rest in panels beside the model or, on a phone, in sheets over it. A browser window as small as a phone gets this layout too, whatever you point with.

- **Tap** selects, or puts down the part in hand; **hold** on a part removes it.
- **Drag** turns the view, and so do two fingers; **pinch** zooms. Two fingers turned about each other turn the model round as far as they turn, as a map does.
- On a phone, **tap with two fingers** to undo and **with three** to redo, as the buttons along the top do, each saying what it took back. A tap is quick and still: fingers that turn, slide or pinch the view never undo. **Double-tap** a part to select it and turn it a quarter turn, as **Turn** does, in one undo step; a locked part, or a tap on nothing, does nothing. The keys sheet lists all three first.
- The Brickworks mark along the top opens the same menu as on a computer. With the assistant on, its button sits beside the model's name.
- In the parts sheet the search and the chips scroll with the parts, and the count, **Prints** and **List** stay at its foot, whichever way the phone is held.
- **Motions** keeps **New motion** in its header, in sight however far its list is scrolled, and puts **Record** beside the motion's name, and each joint's keys are a fingertip tall. **Simulate** puts **Play** and the cycle's slider under its title. A part swung on its joint while recording opens nothing over the panel.
- The booklet's **Lay out the page…** gives its buttons, an item's corner, the knob and an arrow's ends a fingertip each. A tap in the words field keeps its words selected to type over.
- **More** opens on the commands used most, two to a line: Save, Instructions, Timeline, Render, Measure, Cut away, Check stability, Simulate, Pose and Select all. Each is in its menu too.
- To select several parts, tap one, then tap **Select** again: each tap now adds a part or takes it out, and a tap beside the model keeps them. Tap **Select** once more when you are done.
- The timeline's buttons are a fingertip each. On a phone held upright its rows of choices slide sideways, with **Lay out the page…** first.

<!-- covers
ui:two fingers' twist
ui:finger taps to undo and redo and turn
ui:page editor motions and simulate by finger
ui:more's first rows and adding to a selection by finger
-->

### What a phone is told first {#phone-warnings}

A phone gives a browser tab far less memory than a computer does, and starts the app more slowly. So before you wait, Brickworks tells you plainly:

- **A first visit on a phone** says how long it will take as it loads, from how fast the files are coming. Later visits start sooner and say nothing.
- **A big model** opened from its page on a phone asks first: *About N parts: on a phone this may close the tab.* **Open it anyway** goes on; **Not now** stays on the page. Every model in the gallery today opens on a phone without asking. On a computer or a tablet nothing is asked.
- **A browser without WebGL 2** is told at once, before the download, with what to do: turn on hardware acceleration, update the browser, or open Brickworks in another browser or on a computer. A model's page still shows its picture and its parts.
- **A browser that will not give the app the memory it needs** is told so, with what to do: close other tabs and reload, or open Brickworks on a computer.
- **On an iPhone or iPad,** Brickworks can start a build of its engine made for Safari there, which starts sooner and asks for less memory. Every other browser starts the usual one.

<!-- covers
ui:a phone asked before a big model opens
ui:the loader's words for a phone and a browser without WebGL 2
ui:the engine an iPhone or iPad starts
-->

## Work on several models at once {#tabs}

Each browser tab is its own model. **File › New tab** opens another, and each tab has a link of its own, `/app?tab=<id>`, that opens its model again in this browser. When the same model is open in two tabs and you save it in one, the other offers **Reload it**.

<!-- covers
ui:new tab or window
ui:open a tab by link
lib:a session per tab
ui:reload a model saved elsewhere
-->

## When Brickworks is updated {#newer-build}

When a new version comes out while a tab is open, the tab says *Brickworks has been updated*. Press **Reload** when it suits you: the model comes back as it was. Until then the tab saves nothing to your saved models, so it never writes over a newer tab's.

<!-- covers
ui:newer build banner
lib:newer build
-->

## A notice at the foot of the page {#notice}

Now and then a short notice floats at the foot of every page of the site: a time Brickworks will be down for upkeep, or news. It is in your page's language when one was written for it, else in English, and nothing on the page moves for it. Press **×** to put it away: it stays away in that browser until there is a new one, and when you are signed in, on every device you sign in on. A notice with an end time is gone by itself once it is over.

<!-- covers
ui:the site notice
-->

## The desktop app, coming soon {#desktop}

> [!NOTE]
> The desktop app for Linux, macOS and Windows is not out yet ([the desktop app's page](/download)). Everything on these pages works in the browser today. What follows is for those who have it already.

The desktop app is the same builder, free like the web app ([Plans](/docs/plans)). It carries every part on disk, so it builds with no network at all. What differs:

- **File › New window** ([[Ctrl+Shift+N]]) opens a second window with its own model.
- File choosers open where you last used one of their kind, and every export asks where to save.
- **Tools › Settings…**, **Graphics** chooses **Automatic**, **Full** or **Simpler**, from the next start: Simpler has no path tracing and no light bounced between the parts, for graphics that cannot run the full mode.
- **Brickworks › About Brickworks** names every piece of other people's work in it, with its terms, and opens each licence in full. While it loads, the mark shows on the app's dark face.
- On Linux, installed from the .deb, a folder of `.ldr`, `.mpd` and `.io` files shows a picture of each model in Files.

<!-- covers
ui:download page
ui:where a chooser opens
ui:save dialog on the desktop
ui:the boot splash
ui:about and the licences
-->

### Updates {#updates}

The desktop app keeps itself up to date. **Tools › Settings…**, **Updates** chooses how: **Automatic** (the default) puts a new version in place when you quit, **Ask first** waits for you, **Off** asks nothing. A notice above the model offers **What's new**, **Update and restart** and **Later**. **Help › Check for updates…** asks at once, **Help › Restart Brickworks** restarts, and **Help › Reinstall Brickworks…** repairs an install, keeping your models and settings. It installs only what its own release signed, never an older version, and puts the old copy back if the new one does not start.

<!-- covers
ui:update notice
ui:check for updates reinstall and restart
lib:the desktop app updates itself
lib:the signed update manifest
-->

### From the command line {#command-line}

The program is `./brickworks.x86_64` on Linux, `Brickworks.app/Contents/MacOS/Brickworks` on a Mac and `Brickworks.console.exe` on Windows; what it is asked comes after `--`:

```sh
./brickworks.x86_64 --headless -- --about                              # which build this is
./brickworks.x86_64 --headless -- --model=castle.ldr --out=copy.ldr    # open a model, write it out
./brickworks.x86_64 --headless -- --thumbnail castle.ldr castle.png 256  # a picture of a model
./brickworks.x86_64 -- --mcp                                            # open the local MCP port
```

With `--mcp` the window listens on `127.0.0.1:8787` for [Claude Code](/docs/claude-code#desktop). Models and settings are kept in the app's own folder (on Windows, `%APPDATA%\Godot\app_userdata\Brickworks\`).

<!-- covers
cli:a model file's picture
cli:export a model
cli:say which build this is
lib:command socket
-->
