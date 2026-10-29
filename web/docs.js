// The documentation's pages (tools/docs_site.py writes them): the pages list
// on a phone, search over every page, what is on this page as you read, and
// a Copy on each block of code. The pages read whole without it; this is
// what makes them quick to move about in.
//
// Search is the docs' own, in the browser: /docs/search.json, every page cut
// at its headings, fetched the first time search opens. Ctrl+K (Cmd+K on a
// Mac) or / opens it anywhere on a docs page; the arrows choose, Enter goes.
(() => {
  const mac = /Mac|iPhone|iPad/.test(navigator.platform || navigator.userAgent);

  // -- the pages list, behind Browse the docs under 900 px ------------------
  const side = document.getElementById("docs-side");
  const browse = document.querySelector(".docs-menu-button");
  if (side && browse) {
    browse.addEventListener("click", () => {
      const open = browse.getAttribute("aria-expanded") !== "true";
      browse.setAttribute("aria-expanded", String(open));
      side.classList.toggle("open", open);
      if (open) side.querySelector('a[aria-current="page"], a')?.focus();
    });
    side.addEventListener("keydown", (event) => {
      if (event.key === "Escape" && side.classList.contains("open")) {
        browse.click();
        browse.focus();
      }
    });
  }

  // -- Copy on a block of code -------------------------------------------------
  for (const block of document.querySelectorAll(".code")) {
    const button = document.createElement("button");
    button.type = "button";
    button.className = "cta ghost small copy";
    button.textContent = "Copy";
    button.setAttribute("aria-label", "Copy the code");
    button.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(block.querySelector("code").textContent);
        button.textContent = "Copied";
      } catch {
        button.textContent = "Select it";
      }
      setTimeout(() => { button.textContent = "Copy"; }, 1600);
    });
    block.append(button);
  }

  // -- what is on this page: the section being read, marked -------------------
  const toc = document.querySelector(".docs-toc");
  if (toc && "IntersectionObserver" in window) {
    const links = new Map([...toc.querySelectorAll("a")].map((a) => [decodeURIComponent(a.hash.slice(1)), a]));
    const heads = [...links.keys()].map((id) => document.getElementById(id)).filter(Boolean);
    const mark = () => {
      let current = heads[0];
      for (const head of heads) {
        if (head.getBoundingClientRect().top < 140) current = head;
      }
      // At the foot of the page, the last section, however short.
      if (innerHeight + scrollY >= document.scrollingElement.scrollHeight - 2) current = heads[heads.length - 1];
      for (const a of links.values()) a.removeAttribute("aria-current");
      if (current) links.get(current.id)?.setAttribute("aria-current", "true");
    };
    const watch = new IntersectionObserver(mark, { rootMargin: "0px 0px -60% 0px" });
    heads.forEach((head) => watch.observe(head));
    addEventListener("scroll", mark, { passive: true });
    mark();
  }

  // -- search -------------------------------------------------------------------
  const dialog = document.querySelector("dialog.docs-search");
  if (!dialog) return;
  const input = dialog.querySelector("input");
  const list = dialog.querySelector(".docs-results");
  const said = dialog.querySelector(".docs-search-said");
  let index = null;
  let loading = null;
  let found = [];
  let active = -1;

  if (mac) {
    for (const k of document.querySelectorAll(".docs-search-open kbd.keys kbd:first-child")) k.textContent = "⌘";
  }

  const escape = (text) => text.replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
  const words = (text) => text.toLowerCase().split(/[^a-z0-9®]+/).filter((w) => w.length > 0);

  function load() {
    loading ||= fetch("/docs/search.json")
      .then((r) => (r.ok ? r.json() : Promise.reject(new Error(String(r.status)))))
      .then((rows) => {
        index = rows.map((row) => ({ ...row, hl: row.h.toLowerCase(), pl: row.p.toLowerCase(), tl: row.t.toLowerCase() }));
        return index;
      })
      .catch(() => {
        loading = null;
        said.textContent = "Search could not load. Try again in a moment.";
        return null;
      });
    return loading;
  }

  function score(row, terms, phrase) {
    let total = 0;
    for (const term of terms) {
      const inHead = row.hl.includes(term);
      const inPage = row.pl.includes(term);
      const inText = row.tl.includes(term);
      if (!inHead && !inPage && !inText) return 0;
      if (inHead) total += 10 + (new RegExp(`\\b${term}`).test(row.hl) ? 5 : 0);
      if (inPage) total += 4;
      if (inText) total += 2;
    }
    if (terms.length > 1) {
      if (row.hl.includes(phrase)) total += 25;
      else if (row.tl.includes(phrase)) total += 10;
    }
    if (!row.h) total += 1; // a page's own entry, when it ties with a section
    return total;
  }

  function snippet(row, terms) {
    const at = Math.max(0, Math.min(...terms.map((t) => row.tl.indexOf(t)).filter((i) => i >= 0)));
    const start = Math.max(0, at - 60);
    let text = (start > 0 ? "…" : "") + row.t.slice(start, start + 170) + (row.t.length > start + 170 ? "…" : "");
    text = escape(text);
    for (const term of terms) {
      text = text.replace(new RegExp(`(${term.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")})`, "gi"), "<mark>$1</mark>");
    }
    return text;
  }

  function choose(n) {
    const items = list.querySelectorAll("li");
    if (!items.length) return;
    active = (n + items.length) % items.length;
    items.forEach((li, i) => li.setAttribute("aria-selected", String(i === active)));
    input.setAttribute("aria-activedescendant", items[active].id);
    items[active].scrollIntoView({ block: "nearest" });
  }

  async function run() {
    const query = input.value.trim().toLowerCase();
    const rows = index || (await load());
    if (!rows) return;
    const terms = words(query);
    if (!terms.length) {
      list.replaceChildren();
      said.textContent = "";
      input.setAttribute("aria-expanded", "false");
      input.removeAttribute("aria-activedescendant");
      return;
    }
    found = rows.map((row) => [score(row, terms, query), row]).filter(([s]) => s > 0)
      .sort((a, b) => b[0] - a[0]).slice(0, 20).map(([, row]) => row);
    list.innerHTML = found.map((row, i) => `<li id="docs-hit-${i}" role="option" aria-selected="false">
      <a href="${escape(row.u)}" tabindex="-1"><small>${escape(row.s)} › ${escape(row.p)}</small>
      <b>${escape(row.h || row.p)}</b>${snippet(row, terms)}</a></li>`).join("");
    said.textContent = found.length ? `${found.length === 20 ? "The first 20" : found.length} result${found.length === 1 ? "" : "s"}` : `Nothing found for “${input.value.trim()}”.`;
    input.setAttribute("aria-expanded", String(found.length > 0));
    list.dataset.for = input.value.trim();
    active = -1;
    if (found.length) choose(0);
  }

  function go(n) {
    const row = found[n];
    if (!row) return;
    const here = new URL(row.u, location.href);
    dialog.close();
    if (here.pathname === location.pathname && here.hash) {
      location.hash = here.hash;
      document.getElementById(decodeURIComponent(here.hash.slice(1)))?.focus?.();
    } else {
      location.href = row.u;
    }
  }

  let opener = null;
  function open() {
    if (dialog.open) return;
    opener = document.activeElement;
    dialog.showModal();
    input.select();
    load();
  }

  for (const button of document.querySelectorAll("[data-docs-search]")) button.addEventListener("click", open);
  addEventListener("keydown", (event) => {
    const typing = /^(INPUT|TEXTAREA|SELECT)$/.test(event.target.tagName) || event.target.isContentEditable;
    if ((event.key === "k" || event.key === "K") && (event.metaKey || event.ctrlKey) && !event.altKey) {
      event.preventDefault();
      dialog.open ? dialog.close() : open();
    } else if (event.key === "/" && !typing && !dialog.open) {
      event.preventDefault();
      open();
    }
  });
  dialog.addEventListener("close", () => opener?.focus?.());
  dialog.addEventListener("click", (event) => { if (event.target === dialog) dialog.close(); });
  let pending = 0;
  input.addEventListener("input", () => {
    clearTimeout(pending);
    pending = setTimeout(run, 80);
  });
  input.addEventListener("keydown", (event) => {
    if (event.key === "ArrowDown") { event.preventDefault(); choose(active + 1); }
    else if (event.key === "ArrowUp") { event.preventDefault(); choose(active - 1); }
    else if (event.key === "Enter") {
      event.preventDefault();
      if (active >= 0) go(active);
    }
  });
  dialog.querySelector("form").addEventListener("submit", (event) => {
    if (event.submitter?.value !== "close") event.preventDefault();
  });
  list.addEventListener("click", (event) => {
    const li = event.target.closest("li");
    if (!li) return;
    event.preventDefault();
    go([...list.children].indexOf(li));
  });
})();
