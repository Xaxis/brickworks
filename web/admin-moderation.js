// The console's Moderation (admin.html #moderation/..., console3): every
// report of every kind in one queue, the oldest first, with one set of acts;
// the comments; and what is taken out, accounts and models, with Let back
// in. Drawn from the report the Gallery asks (admin-gallery.js loadReport);
// each act is api/admin.js's, the one place it is done.
//
// A report's kind is the server's word for it (api/admin.js reportKind):
// KINDS says, for each, what its row shows of what was reported and which
// acts it has besides Let it go, which every report has. A new kind is one
// entry here; a kind with none yet is drawn plainly, with Let it go.
//
// Names, notes and comments strangers wrote: text, never markup.
import { $, address, cell, make, post, rowAct as act, say, segmented, sift, timeCell } from "/admin-kit.js";
import { again, keepInView, modelCell, onReport, tokenDrawnWith } from "/admin-gallery.js";

const to = (href, text) => { const a = make("a", "", text); a.href = href; return a; };
const modelOf = (report) => to(`/m/${encodeURIComponent(report.model)}`, report.name ?? report.model);

/// Each kind of report: its name (the filter's and the row's), what its row
/// shows of what was reported (into [about]), and its acts, each
/// [query, [button, done], confirm?] (api/admin.js ops).
export const KINDS = {
  model: {
    name: "Model",
    about: (report, about) => about.append(modelOf(report), report.listed === false ? make("small", "faint", " · not listed") : ""),
    acts: (report) => [
      [{ op: "unlist", id: report.model }, ["Take out", "Taken out."], "Take this model out of the gallery for good?"],
      [{ op: "bar", id: report.model }, ["Take out the account", "The account is out."],
        "Take every model of this account out of the gallery, and keep them out?"],
    ],
  },
  takedown: {
    name: "Takedown",
    about: (report, about) => about.append(make("b", "", "A copyright notice: "), report.model ? modelOf(report) : "—"),
    acts: (report) => (report.model ? [
      [{ op: "unlist", id: report.model }, ["Take it down", "Taken down."],
        "Take this model down, at its link and any other with the same file, as the notice asks?"],
    ] : []),
  },
  counter_notice: {
    name: "Counter-notice",
    about: (report, about) => about.append(make("b", "", "A counter-notice: "), report.model ? modelOf(report) : "—"),
    // Its model let back once the notice's time has passed: the owner lists it again.
    acts: (report) => (report.model ? [
      [{ op: "unbar_model", id: report.model }, ["Let the model back", "Let back: its owner may list it again."],
        "Let this model back? Its owner may list it in the gallery again."],
    ] : []),
  },
  comment: {
    name: "Comment",
    about: (report, about) => {
      about.append(to(`/m/${encodeURIComponent(report.model)}#comment-${encodeURIComponent(report.comment.id)}`,
        `A comment on ${report.name ?? report.model}`));
      if (report.comment.body) about.append(make("br"), make("q", "comment-said", report.comment.body));
    },
    acts: (report) => [
      [{ op: "uncomment", comment: report.comment.id }, ["Remove the comment", "The comment is removed."],
        "Take this comment off its page for good?"],
    ],
  },
  photo: {
    name: "Photo",
    // The photo itself, asked for with the owner's sign-in, since it may be
    // hidden from everybody else (supabase/builds.sql).
    about: (report, about, row) => {
      row.dataset.photo = report.photo.id;
      if (!report.photo.removed) about.append(photoOf(report.photo.id), make("br"));
      const said = [report.photo.words ? `“${report.photo.words}”` : "", report.photo.hidden ? "hidden by the model's owner" : "",
        report.photo.email ? `posted by ${report.photo.email}` : ""].filter(Boolean).join(" · ");
      if (said) about.append(make("small", "faint photo-said", said), make("br"));
      about.append(to(`/m/${encodeURIComponent(report.model)}#photo-${encodeURIComponent(report.photo.id)}`,
        `A photo of a build of ${report.name ?? report.model}`));
    },
    acts: (report) => [
      [{ op: "remove_photo", photo: report.photo.id }, ["Take the photo out", "The photo is out, and its file deleted."],
        "Take this photo out? Its file is deleted, and it is shown nowhere again."],
    ],
  },
  profile: {
    name: "Profile",
    // The picture the profile shows as its avatar, if one of its own
    // (supabase/avatars.sql), to look at before taking it out.
    about: (report, about, row) => {
      if (/^\/api\/people\?op=avatar&id=[A-Za-z0-9]{10}$/.test(String(report.picture || ""))) {
        const img = make("img", "reported-photo reported-avatar");
        img.alt = "The picture this profile shows as its avatar";
        img.width = 96;
        img.height = 96;
        img.src = report.picture;
        row.dataset.picture = report.handle;
        about.append(img, make("br"));
      }
      about.append(to(`/u/${encodeURIComponent(report.handle)}`, `@${report.handle}`));
    },
    acts: (report) => (report.picture ? [
      [{ op: "remove_avatar", handle: report.handle }, ["Take the picture out", "The picture is out, and its file deleted."],
        "Take this profile's picture out? Its file is deleted, and its avatar is made from its handle again."],
    ] : []),
  },
  list: {
    name: "List",
    about: (report, about) => about.append(to(`/c/${encodeURIComponent(report.collection)}`,
      report.list?.name ? `The list “${report.list.name}”` : `List ${report.collection}`)),
    acts: () => [],
  },
};

/// A kind the console has no entry for yet: what was reported, plainly.
const PLAIN = {
  name: "Other",
  about: (report, about) => about.append(report.model ? modelOf(report) : report.handle
    ? to(`/u/${encodeURIComponent(report.handle)}`, `@${report.handle}`)
    : report.collection ? to(`/c/${encodeURIComponent(report.collection)}`, `List ${report.collection}`) : "—"),
  acts: () => [],
};

const kindOf = (report) => KINDS[report.kind] || PLAIN;

// --- The queue --------------------------------------------------------------

let kindShown = "";

function siftQueue() {
  const n = sift($("reports"), $("reports-q").value, (row) => !kindShown || row.dataset.kind === kindShown);
  const all = $("reports").querySelectorAll("tr[data-kind]").length;
  if (all) say("reports-note", n === all ? "" : `${n} of ${all} shown.`);
}

// The filter's kinds, as KINDS has them.
$("report-kinds").append(...Object.entries(KINDS).map(([kind, one]) => {
  const button = make("button", "", one.name);
  button.type = "button";
  button.dataset.value = kind;
  button.setAttribute("aria-pressed", "false");
  return button;
}));
segmented($("report-kinds"), (value) => { kindShown = value; siftQueue(); });
$("reports-q").addEventListener("input", siftQueue);

function drawQueue(list) {
  const reports = $("reports");
  reports.replaceChildren();
  // The oldest first: the queue is worked from its oldest (api/admin.js asks so).
  const sorted = [...(list || [])].sort((a, b) => String(a.at).localeCompare(String(b.at)));
  for (const report of sorted) {
    const kind = kindOf(report);
    const row = make("tr");
    // Where the owner's email of reports links each one (api/_trust.js).
    if (Number.isInteger(report.id)) row.id = `report-${report.id}`;
    row.dataset.kind = report.kind || "";
    timeCell(row, report.at);
    cell(row, make("span", "pill", kind.name)).dataset.value = kind.name;
    const about = make("td", "about");
    kind.about(report, about, row);
    row.append(about);
    cell(row, report.reason);
    cell(row, report.note ?? "—", report.note ? "said" : "faint");
    // Whose it is, and the way the reporter gave to reach them.
    const who = cell(row, report.email ? address(report.email) : "nobody's", report.email ? "who" : "who faint");
    who.dataset.value = report.email ?? "";
    if (report.contact) who.append(make("br"), make("small", "faint", "Reach them: ", address(report.contact)));
    const acts = make("td", "acts");
    const go = ([query, said, ask]) => act(said[0], () => (!ask || confirm(ask)
      ? post(query, "reports-note", said[1], { after: again }) : Promise.resolve(false)));
    acts.append(...kind.acts(report).map(go), go([{ op: "dismiss", report: report.id }, ["Let it go", "Let go."]]));
    row.append(acts);
    reports.append(row);
  }
  $("tab-queue").textContent = sorted.length ? String(sorted.length) : "";
  say("reports-note", sorted.length ? "" : "Nothing is reported.");
  siftQueue();
  // Opened from that email: the report it named, marked (and put in view
  // once the tab shows: admin.js show()).
  if (/^#report-\d+$/.test(location.hash)) {
    const named = document.getElementById(location.hash.slice(1));
    if (named) named.classList.add("asked");
    else say("reports-note", "The report that email named is no longer open: it was settled.");
  }
}

/// A reported photo, small, fetched with the owner's sign-in and shown from
/// memory (a blob: address, which this page's policy allows).
function photoOf(id) {
  const img = make("img", "reported-photo");
  img.alt = "The reported photo";
  img.width = 160;
  (async () => {
    try {
      const reply = await fetch(`/api/admin?op=photo&photo=${encodeURIComponent(id)}`,
        { headers: { authorization: `Bearer ${tokenDrawnWith()}` } });
      if (!reply.ok) throw new Error(String(reply.status));
      img.src = URL.createObjectURL(await reply.blob());
    } catch {
      img.alt = "The photo could not be shown";
    }
  })();
  return img;
}

// --- Comments ---------------------------------------------------------------

function drawComments(list) {
  const comments = $("comments");
  comments.replaceChildren();
  for (const one of list || []) {
    const row = make("tr");
    row.id = `comment-${one.id}`;
    timeCell(row, one.at);
    const on = make("td", "about");
    on.append(to(`/m/${encodeURIComponent(one.model)}#comment-${encodeURIComponent(one.id)}`, one.name ?? one.model),
      `${one.step ? `, step ${one.step} of version ${one.version}` : `, version ${one.version}`}${one.parent ? ", a reply" : ""}`);
    row.append(on);
    cell(row, one.body, "said");
    cell(row, one.handle ? `@${one.handle}` : one.email ?? "—", one.handle || one.email ? "" : "faint");
    cell(row, one.removed ? `removed by ${one.removed_by === "admin" ? "you" : "its author"}`
      : one.hidden ? "hidden by its builder" : one.edited_at ? "edited" : "shown", one.removed ? "faint" : "");
    const acts = make("td", "acts");
    if (!one.removed) {
      acts.append(act("Remove", () => (confirm("Take this comment off its page for good?")
        ? post({ op: "uncomment", comment: one.id }, "comments-note", "Removed.", { after: again }) : Promise.resolve(false))));
    }
    row.append(acts);
    comments.append(row);
  }
  say("comments-note", list?.length ? "" : "Nobody has commented yet.");
  if (/^#comment-\d+$/.test(location.hash)) document.getElementById(location.hash.slice(1))?.classList.add("asked");
}

// --- Taken out --------------------------------------------------------------

function drawBarred(list, models) {
  const barred = $("barred");
  barred.replaceChildren();
  for (const one of list || []) {
    const row = make("tr");
    row.dataset.account = one.account;
    const who = make("td");
    who.append(to(`#people/${one.account}`, one.email ?? one.account));
    row.append(who);
    timeCell(row, one.at);
    cell(row, one.reason ?? "—", one.reason ? "" : "faint");
    const acts = make("td", "acts");
    acts.append(act("Let back in", () => post({ op: "unbar", account: one.account }, "barred-note", "Let back in.", { after: again })));
    row.append(acts);
    barred.append(row);
  }
  say("barred-note", list?.length ? "" : "Nobody is taken out.");

  const out = $("barred-models");
  out.replaceChildren();
  for (const one of models || []) {
    const row = make("tr");
    row.dataset.model = one.id;
    modelCell(row, one.id, one.name);
    const who = make("td");
    who.append(one.account ? to(`#people/${one.account}`, one.email ?? one.account) : "—");
    row.append(who);
    timeCell(row, one.at);
    const acts = make("td", "acts");
    acts.append(act("Let back in", () => (confirm(`Let "${one.name || one.id}" back? Its owner may list it in the gallery again.`)
      ? post({ op: "unbar_model", id: one.id }, "barred-models-note", `"${one.name || one.id}" is let back: its owner may list it again.`,
        { after: again })
      : Promise.resolve(false))));
    row.append(acts);
    out.append(row);
  }
  say("barred-models-note", models?.length ? "" : "No model is taken out.");
  const n = (list?.length || 0) + (models?.length || 0);
  $("tab-barred").textContent = n ? String(n) : "";
}

onReport((data) => {
  drawQueue(data.reports);
  drawComments(data.comments);
  drawBarred(data.barred, data.barred_models);
});

export { keepInView };
