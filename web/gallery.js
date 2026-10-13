// The gallery, /gallery: the models people listed when they shared them,
// newest first, a page at a time from /api/share?op=list (api/share.js).
//
// Names and credits were typed by strangers, so every one goes on the
// page as text (textContent), never as markup; a link is built from the
// model's id alone, and only an id that is one. Same origin throughout:
// the site's content security policy lets a page talk to itself and a
// short list of others.
(function () {
  "use strict";

  const ID = /^[A-Za-z0-9]{10}$/;
  const $ = (id) => document.getElementById(id);
  const grid = $("models");
  const more = $("more");
  let page = 0;

  function parts(n) {
    const count = Number(n) || 0;
    return `${count.toLocaleString("en-US")} part${count === 1 ? "" : "s"}`;
  }

  function card(model) {
    const link = document.createElement("a");
    link.className = "model";
    link.href = `/m/${model.id}`;
    link.dataset.id = model.id;
    const frame = document.createElement("div");
    frame.className = "frame";
    if (model.image) {
      const img = document.createElement("img");
      img.src = `/m/${model.id}.png`;
      img.alt = String(model.name);
      img.width = 1200;
      img.height = 630;
      img.loading = "lazy";
      img.decoding = "async";
      frame.append(img);
    } else {
      frame.classList.add("none");
      frame.textContent = "No picture";
    }
    const words = document.createElement("div");
    words.className = "words";
    const name = document.createElement("b");
    name.textContent = String(model.name);
    name.title = String(model.name);
    const about = document.createElement("span");
    about.textContent = model.author ? `${parts(model.parts)}, by ${model.author}` : parts(model.parts);
    words.append(name, about);
    link.append(frame, words);
    return link;
  }

  async function next() {
    more.disabled = true;
    try {
      const reply = await fetch(`/api/share?op=list&page=${page + 1}`, { headers: { accept: "application/json" } });
      if (!reply.ok) throw new Error(String(reply.status));
      const data = await reply.json();
      page = Number(data.page) || page + 1;
      for (const model of data.models || []) {
        if (model && ID.test(String(model.id))) grid.append(card(model));
      }
      $("loading").hidden = true;
      $("empty").hidden = grid.children.length > 0;
      more.hidden = !data.more;
      document.documentElement.dataset.gallery = "ready";
    } catch {
      $("loading").hidden = true;
      $("broken").hidden = false;
      document.documentElement.dataset.gallery = "broken";
    } finally {
      more.disabled = false;
    }
  }

  more.addEventListener("click", next);
  next();
})();
