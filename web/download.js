// The download page: one button for this computer, the other systems a click
// away, and what only some people need (the first launch's steps, the
// checksums) folded away under it.
//
// /releases.json is written by tools/release.py publish from what GitHub
// holds after the upload, and every url in it is pinned to its release, so
// the version, size and SHA-256 shown are those of the file the button
// fetches. Same origin on purpose: the site's content security policy lets a
// page connect only to itself and a short list of others, and GitHub's API is
// not on it.
//
// The paid desktop, built dark (docs/PLANS.md, unit U5): /api/plans?op=download
// says whether downloads are gated. While billing is off they are not, and
// every link is the public address it always was. While it is on, a click on
// a file asks the same route with the sign-in (web/account.js) for GitHub's
// short-lived address and goes there; signed out it asks to sign in first,
// and an account whose plan has no desktop is told so, in the server's
// words, with the way to Pro.
(function () {
  "use strict";

  const NAMES = { linux: "Linux", macos: "macOS", windows: "Windows" };
  const PRIMARY = { linux: "AppImage", macos: "zip", windows: "zip" };
  const FOR = { linux: "AppImage", macos: "Apple silicon and Intel", windows: "Windows 10 and 11" };

  // What this device is: a system there is a build for, "mobile" (a phone or
  // a tablet, where none of them runs) or "other" (a computer there is no
  // build for, such as Linux on ARM). An iPad says it is a Mac and gives
  // itself away by having a touch screen.
  function detect() {
    const ua = navigator.userAgent || "";
    const data = navigator.userAgentData;
    const platform = ((data && data.platform) || navigator.platform || "").toLowerCase();
    if ((data && data.mobile) || /android|iphone|ipad|ipod|mobile/i.test(ua)
        || (platform.startsWith("mac") && navigator.maxTouchPoints > 1)) return "mobile";
    if (platform.startsWith("win") || /windows/i.test(ua)) return "windows";
    if (platform.startsWith("mac") || /macintosh|mac os x/i.test(ua)) return "macos";
    if (/linux|x11|cros|chrome os/.test(platform) || /linux|x11|cros/i.test(ua)) {
      // The Linux build is for x86 PCs. Chrome says x86_64 in its user agent
      // whatever the machine; navigator.platform still tells.
      return /arm|aarch64/i.test(navigator.platform || "") ? "other" : "linux";
    }
    return "other";
  }

  function megabytes(bytes) {
    if (bytes >= 1e9) return (bytes / 1e9).toFixed(1) + " GB";
    return (bytes / 1e6).toFixed(bytes >= 1e8 ? 0 : 1) + " MB";
  }

  // "2026-10-10" is a date, not an instant: read as one it would be midnight
  // UTC and show as the 9th everywhere west of Greenwich.
  function day(iso) {
    const [y, m, d] = iso.split("-").map(Number);
    return new Date(y, m - 1, d).toLocaleDateString(undefined, { dateStyle: "long" });
  }

  function el(tag, attrs, ...children) {
    const node = document.createElement(tag);
    for (const [key, value] of Object.entries(attrs || {})) {
      if (key === "text") node.textContent = value;
      else node.setAttribute(key, value);
    }
    for (const child of children) if (child) node.append(child);
    return node;
  }

  // A command and its Copy. Where the clipboard is refused, the command is
  // selected instead, for the keyboard's copy.
  function copyRow(command) {
    return el("div", { class: "copy-row" }, el("code", { class: "cmd", text: command }),
      el("button", { type: "button", class: "cta ghost small", "data-copy": "", text: "Copy" }));
  }

  document.addEventListener("click", async (event) => {
    const button = event.target.closest("[data-copy]");
    if (!button) return;
    const code = button.parentElement.querySelector("code");
    try {
      await navigator.clipboard.writeText(code.textContent);
      button.textContent = "Copied";
    } catch {
      getSelection().selectAllChildren(code);
      button.textContent = "Selected";
    }
    setTimeout(() => { button.textContent = "Copy"; }, 1600);
  });

  // The first launch, in one line, for the system on offer.
  function firstLine(os, file) {
    if (os === "macos") {
      return file.notarized ? "First launch: drag it into Applications."
        : "First launch: macOS asks you to allow it once.";
    }
    if (os === "windows") {
      return file.signed === true ? "First launch: extract the zip first."
        : "First launch: extract the zip, then allow it once.";
    }
    return "First launch: let the AppImage run as a program.";
  }

  // A command that checks a file is the one published, and what it prints.
  function checkCommand(os, file) {
    if (os === "windows") {
      return '(Get-FileHash "$HOME\\Downloads\\' + file.name + '").Hash -eq "' + file.sha256 + '"';
    }
    const tool = os === "macos" ? "shasum -a 256 -c" : "sha256sum -c";
    return "cd ~/Downloads && echo \"" + file.sha256 + "  " + file.name + "\" | " + tool;
  }
  const CHECK_IN = {
    linux: "In a terminal, this checks each file is the one published. It should print OK.",
    macos: "In Terminal, this checks the file is the one published. It should print OK.",
    windows: "In PowerShell, this checks the file is the one published. It should print True.",
  };

  function render(release, device) {
    const files = release.files || [];
    const byOs = (os) => files.filter((f) => f.os === os)
      .sort((a, b) => (a.kind === PRIMARY[os] ? -1 : 0) - (b.kind === PRIMARY[os] ? -1 : 0));
    const button = document.getElementById("offer-button");
    const meta = document.getElementById("offer-meta");
    const others = document.getElementById("others");
    const more = document.getElementById("more");

    // What each needs, measured from the packages where it can be. The
    // tar.xz is read for Linux: it is the same program as the AppImage, and
    // a tarball can be measured without mounting anything.
    const linuxFacts = files.find((f) => f.os === "linux" && f.glibc) || byOs("linux")[0];
    const disk = (file) => (file && file.unpacked ? ", and " + megabytes(file.unpacked) + " of disk" : "");
    const mac = byOs("macos")[0];
    const oldest = (mac && mac.min_macos) || {};
    const needs = {
      linux: "Needs 64-bit Linux on an x86 PC" + (linuxFacts && linuxFacts.glibc
        ? " with glibc " + linuxFacts.glibc + " or newer" : "")
        + ", a graphics driver with Vulkan or OpenGL 3.3" + disk(linuxFacts) + ".",
      macos: "Needs macOS " + (oldest.arm64 && oldest.x86_64
        ? oldest.arm64 + " or later on Apple silicon, " + oldest.x86_64 + " or later on Intel"
        : "on Apple silicon or Intel") + disk(mac) + ".",
      windows: "Needs 64-bit Windows 10 or 11, a graphics driver with Vulkan, Direct3D 12 or OpenGL 3.3"
        + disk(byOs("windows")[0]) + ".",
    };
    for (const [os, text] of Object.entries(needs)) {
      document.querySelector('[data-need="' + os + '"]').textContent = text;
    }

    // Commands with the real file names in them.
    const appImage = byOs("linux").find((f) => f.kind === "AppImage");
    const tar = byOs("linux").find((f) => f.kind === "tar.xz");
    if (appImage) {
      document.querySelector('[data-cmd="linux-appimage"]').textContent =
        "chmod +x " + appImage.name + " && ./" + appImage.name;
    }
    if (tar) {
      document.querySelector('[data-cmd="linux-tar"]').textContent =
        "tar -xf " + tar.name + " && ./" + tar.name.replace(/\.tar\.xz$/, "") + "/brickworks.x86_64";
      const link = document.getElementById("linux-tar");
      link.href = tar.url;
      link.textContent = ".tar.xz (" + megabytes(tar.size) + ")";
    }
    if (release.page) document.getElementById("release-link").href = release.page;

    const mine = NAMES[device] ? device : "";

    function show(os) {
      const pick = os ? byOs(os)[0] : null;
      document.documentElement.dataset.os = pick ? os : "none";
      button.hidden = !pick;
      meta.hidden = !pick;
      more.hidden = !pick;
      if (pick) {
        button.href = pick.url;
        button.textContent = "Download for " + NAMES[os];
        button.dataset.name = pick.name;
        meta.textContent = "Version " + release.version + " · " + megabytes(pick.size) + " · " + FOR[os];

        document.getElementById("steps-line").textContent = firstLine(os, pick);
        for (const steps of document.querySelectorAll("[data-steps]")) steps.hidden = steps.dataset.steps !== os;
        const unsigned = os === "macos" ? !pick.notarized : os === "windows" ? pick.signed !== true : false;
        for (const step of document.querySelectorAll('[data-steps="' + os + '"] [data-unsigned]')) {
          step.hidden = !unsigned;
        }

        document.getElementById("verify-how").textContent = CHECK_IN[os];
        const sums = byOs(os);
        document.getElementById("sums").replaceChildren(...sums.flatMap((file) => [
          sums.length > 1 ? el("p", { class: "note", text: "The " + file.kind + ":" }) : null,
          copyRow(checkCommand(os, file)),
        ].filter(Boolean)));
      }

      const rest = Object.keys(NAMES).filter((o) => o !== os && byOs(o).length);
      others.replaceChildren("Other systems: ", ...rest.flatMap((o, i) => {
        const link = el("a", { href: "?os=" + o, "data-os": o, text: NAMES[o] });
        link.addEventListener("click", (event) => {
          event.preventDefault();
          history.replaceState(null, "", "?os=" + o + location.hash);
          show(o);
        });
        return i ? [" · ", link] : [link];
      }));
      others.hidden = !rest.length;
    }

    // ?os= first, so any system's offer can be linked to and tested.
    const asked = new URLSearchParams(location.search).get("os");
    show(NAMES[asked] ? asked : mine);

    // What is new: the lines written for this release, or else the first
    // sentences of its summary. Never another release's lines.
    document.getElementById("notes-h").textContent = "New in " + release.version;
    const written = document.querySelector('[data-highlights="' + release.version + '"]');
    if (written) {
      written.hidden = false;
    } else {
      const sentences = (release.summary || "").split(/(?<=[.!?])\s+(?=[A-Z])/).filter(Boolean);
      const list = document.getElementById("notes-list");
      list.replaceChildren(...sentences.slice(0, 4).map((s) => el("li", { text: s })));
      list.hidden = !sentences.length;
    }
    document.getElementById("notes-date").textContent = "Released " + day(release.date) + " · ";
    // The site's own changelog, at this release, rather than the file on GitHub.
    document.getElementById("notes-link").href = "/changelog#v" + release.version;
    document.getElementById("notes").hidden = false;
  }

  // Wherever this device has no build of its own, the web app comes first,
  // and a desktop file is there only once a system is chosen. Said before
  // the list arrives, so a phone never sees a desktop button come and go.
  function welcome(device) {
    const mine = !!NAMES[device];
    document.documentElement.dataset.device = device;
    for (const pitch of document.querySelectorAll("[data-pitch]")) {
      pitch.hidden = pitch.dataset.pitch !== (mine ? "computer" : device);
    }
    document.getElementById("web-app").hidden = mine;
    const button = document.getElementById("offer-button");
    button.classList.toggle("ghost", !mine);
    button.hidden = !mine;
  }

  // No list, or no release in it: say so in place of the offer.
  function nothing(id) {
    document.getElementById("offer-button").hidden = true;
    document.getElementById("offer-meta").hidden = true;
    document.getElementById(id).hidden = false;
  }

  // Whether a download needs the sign-in: only while billing is on. Asked
  // once; unanswered, the links stay the public ones.
  let gated = false;
  async function askGated() {
    try {
      const reply = await fetch("/api/plans?op=download", { cache: "no-store" });
      gated = reply.ok && (await reply.json()).gated === true;
    } catch {
      gated = false;
    }
  }

  // What the route said instead of a file, under the button: its words, and
  // the way to Pro when it gave one.
  function refused(words, pro) {
    let line = document.getElementById("gate-said");
    if (!line) {
      line = el("p", { class: "note", id: "gate-said", role: "status" });
      document.getElementById("offer-meta").after(line);
    }
    line.replaceChildren(words, ...(pro ? [" ", el("a", { href: pro, text: "See Pro" })] : []));
  }

  async function fetchGated(file) {
    const account = await import("/account.js");
    const path = "/api/plans?op=download&file=" + encodeURIComponent(file);
    let reply = await account.call(path);
    if (reply.status === 401) {
      if (!(await account.askToSignIn("Sign in to download the desktop app."))) return;
      reply = await account.call(path);
    }
    if (reply.status === 200 && reply.body.url) {
      location.assign(reply.body.url);
      return;
    }
    refused(reply.body.error || "The download did not start just now. Try again in a minute.", reply.body.pro);
  }

  document.addEventListener("click", (event) => {
    const link = event.target.closest('a[href*="/releases/download/"]');
    if (!gated || !link) return;
    event.preventDefault();
    fetchGated(decodeURIComponent(link.getAttribute("href").split("/").pop()));
  });

  async function start() {
    const device = detect();
    welcome(device);
    askGated();
    let manifest;
    try {
      const response = await fetch("releases.json", { cache: "no-cache" });
      if (!response.ok) throw new Error(String(response.status));
      manifest = await response.json();
    } catch {
      return nothing("broken");
    }
    const release = (manifest.releases || []).find((r) => r.version === manifest.latest);
    if (!release) return nothing("none-yet");
    render(release, device);
  }

  start();
})();
