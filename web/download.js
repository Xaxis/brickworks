// The download page: which build to offer, and what a careful person checks
// before running it.
//
// /releases.json is written by tools/release.py publish from what GitHub
// holds after the upload, and every url in it is pinned to its release, so
// the version, size, date and SHA-256 shown are those of the file the button
// fetches. Same origin on purpose: the site's content security policy lets a
// page connect only to itself and a short list of others, and GitHub's API is
// not on it.
(function () {
  "use strict";

  const NAMES = { linux: "Linux", macos: "macOS", windows: "Windows" };
  const PRIMARY = { linux: "AppImage", macos: "zip", windows: "zip" };

  // ?os= first, so any system's view can be linked to and tested. Then the
  // platform the browser reports, then its user agent. A phone or a tablet
  // gets no guess: none of these builds runs there. An iPad says it is a Mac
  // and gives itself away by having a touch screen.
  function detect() {
    const asked = new URLSearchParams(location.search).get("os");
    if (asked && NAMES[asked]) return asked;
    const ua = navigator.userAgent || "";
    const data = navigator.userAgentData;
    const platform = ((data && data.platform) || navigator.platform || "").toLowerCase();
    if ((data && data.mobile) || /android|iphone|ipad|ipod|mobile/i.test(ua)
        || (platform.startsWith("mac") && navigator.maxTouchPoints > 1)) return "";
    if (platform.startsWith("win") || /windows/i.test(ua)) return "windows";
    if (platform.startsWith("mac") || /macintosh|mac os x/i.test(ua)) return "macos";
    if (/linux|x11|cros|chrome os/.test(platform) || /linux|x11|cros/i.test(ua)) return "linux";
    return "";
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

  function kindOf(file) {
    if (file.kind === "AppImage") return "AppImage, one file that runs as it is";
    if (file.kind === "tar.xz") return "tar.xz, a folder to unpack anywhere";
    if (file.os === "macos") return "zip with Brickworks.app, for Apple silicon and Intel";
    return "zip with Brickworks.exe";
  }

  function fileCard(file) {
    const copy = el("button", { type: "button", text: "Copy" });
    copy.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(file.sha256);
        copy.textContent = "Copied";
      } catch {
        copy.textContent = "Select it";
      }
      setTimeout(() => { copy.textContent = "Copy"; }, 1600);
    });
    return el("div", { class: "file", "data-name": file.name },
      el("div", { class: "top" },
        el("div", {},
          el("div", { class: "name", text: file.name }),
          el("div", { class: "what", text: kindOf(file) + " · " + megabytes(file.size) })),
        el("a", { class: "cta ghost", href: file.url, text: "Download" })),
      el("div", { class: "sum" },
        el("code", { title: "SHA-256", text: file.sha256 }), copy));
  }

  function show(os) {
    for (const tab of document.querySelectorAll(".tabs button")) {
      tab.setAttribute("aria-selected", String(tab.dataset.os === os));
    }
    for (const panel of document.querySelectorAll("[data-panel]")) {
      panel.hidden = panel.dataset.panel !== os;
    }
  }

  function fill(release, mine) {
    const files = release.files || [];
    const byOs = (os) => files.filter((f) => f.os === os)
      .sort((a, b) => (a.kind === PRIMARY[os] ? -1 : 0) - (b.kind === PRIMARY[os] ? -1 : 0));

    document.getElementById("release-line").textContent =
      "Brickworks " + release.version + ", released " + day(release.date)
      + ". Every file's SHA-256 is beside it, and all of them are in SHA256SUMS on the release.";

    for (const os of Object.keys(NAMES)) {
      const list = document.querySelector('[data-files="' + os + '"]');
      list.replaceChildren(...byOs(os).map(fileCard));
      const tab = document.getElementById("tab-" + os);
      if (os === mine) tab.append(el("span", { class: "yours", text: "this computer" }));
      tab.addEventListener("click", () => show(os));
    }

    // What each needs, measured from the packages where it can be.
    const linux = byOs("linux")[0];
    const mac = byOs("macos")[0];
    const win = byOs("windows")[0];
    const need = (name, text) => {
      const at = document.querySelector('[data-need="' + name + '"]');
      if (at && text) at.textContent = text;
      else if (at && !text) at.hidden = true;
    };
    // The tar.xz is read for these: it is the same program as the AppImage,
    // and a tarball can be measured without mounting anything.
    const linuxFacts = files.find((f) => f.os === "linux" && f.glibc) || linux;
    if (linuxFacts && linuxFacts.glibc) {
      need("glibc", ", glibc " + linuxFacts.glibc + " or newer (ldd --version says)");
    }
    for (const [name, file] of [["disk-linux", linuxFacts], ["disk-macos", mac], ["disk-windows", win]]) {
      need(name, file && file.unpacked ? megabytes(file.unpacked) + " of disk once unpacked" : "");
    }
    const oldest = (mac && mac.min_macos) || {};
    need("macos", oldest.arm64 && oldest.x86_64
      ? "macOS " + oldest.arm64 + " or later on Apple silicon, " + oldest.x86_64 + " or later on Intel"
      : "A Mac with Apple silicon or Intel");

    // The first-launch steps, only while there is no signature to spare them.
    document.querySelector('[data-unsigned="macos"]').hidden = !!(mac && mac.notarized);
    document.querySelector('[data-unsigned="windows"]').hidden = !!(win && win.signed === true);

    // Commands with the real file names in them.
    if (linux) {
      document.querySelector('[data-cmd="linux-appimage"]').textContent =
        "chmod +x " + linux.name + " && ./" + linux.name;
      document.querySelector('[data-cmd="linux-sum"]').textContent = "sha256sum " + linux.name;
    }
    const tar = files.find((f) => f.kind === "tar.xz");
    if (tar) {
      document.querySelector('[data-cmd="linux-tar"]').textContent =
        "tar -xf " + tar.name + " && ./" + tar.name.replace(/\.tar\.xz$/, "") + "/brickworks.x86_64";
    }
    if (mac) document.querySelector('[data-cmd="macos-sum"]').textContent = "shasum -a 256 ~/Downloads/" + mac.name;
    if (win) {
      document.querySelector('[data-cmd="windows-sum"]').textContent =
        "Get-FileHash .\\Downloads\\" + win.name + " -Algorithm SHA256";
    }

    // The offer at the top: this computer's download, the others a click away.
    const offer = document.getElementById("offer");
    const pick = mine ? byOs(mine)[0] : null;
    if (pick) {
      const button = document.getElementById("offer-button");
      button.href = pick.url;
      button.textContent = "Download for " + NAMES[mine];
      button.dataset.name = pick.name;
      const meta = document.getElementById("offer-meta");
      meta.replaceChildren(el("b", { text: "Brickworks " + release.version }),
        " · " + megabytes(pick.size) + " · " + day(release.date) + " · " + kindOf(pick));
      const also = document.getElementById("offer-also");
      const others = Object.keys(NAMES).filter((os) => os !== mine);
      also.replaceChildren("Not on " + NAMES[mine] + "? ",
        ...others.flatMap((os, i) => {
          const link = el("a", { href: "#all", text: NAMES[os] });
          link.addEventListener("click", () => show(os));
          return i ? [" or ", link] : [link];
        }),
        ". Checksums and requirements are below.");
      offer.hidden = false;
    } else {
      document.getElementById("offer-none").hidden = false;
    }
    show(mine || "linux");
    document.getElementById("all").hidden = false;

    document.getElementById("notes-title").textContent = "What is in " + release.version;
    document.getElementById("notes-summary").textContent = release.summary || "";
    if (release.notes) document.getElementById("notes-link").href = release.notes;
    if (release.page) document.getElementById("release-link").href = release.page;
    document.getElementById("notes").hidden = false;
  }

  async function start() {
    const mine = detect();
    document.documentElement.dataset.os = mine || "none";
    let manifest;
    try {
      const response = await fetch("releases.json", { cache: "no-cache" });
      if (!response.ok) throw new Error(String(response.status));
      manifest = await response.json();
    } catch {
      document.getElementById("broken").hidden = false;
      return;
    }
    const release = (manifest.releases || []).find((r) => r.version === manifest.latest);
    if (!release) {
      document.getElementById("none-yet").hidden = false;
      return;
    }
    fill(release, mine);
  }

  start();
})();
