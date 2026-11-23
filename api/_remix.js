// A remix's changes on the site (remixdiff, 2026-11-23): counted as it is
// published and kept (supabase/remix_changes.sql), said under its credit on
// its page, lit in its 3D view (/m/X/changes.json), and drawn in the
// original's Remixes tab as a tree both ways, each with its change line
// (remix_tree). What is counted, and how, is api/_remix_changes.js.
//
// Nothing here reads a model's file as a page is viewed: a publish reads
// the original's version once (the remix's own file it has in hand), and
// every page after reads the row.

import { db } from "./_db.js";
import { afterAnswer } from "./_after.js";
import { escapeHtml, say } from "./_card.js";
import { asText, cardOf, sayHtml } from "./_directory.js";
import { changeLine, readCounts, remixChanges } from "./_remix_changes.js";

const ID = /^[A-Za-z0-9]{10}$/;
/// Where version [n] of link [id] keeps its model (api/share.js versionFile).
const fileOf = (id, n, newest) => (n === newest ? `${id}.mpd` : `${id}.v${n}.mpd`);

/// Which version of the original a remix is counted against, from the
/// original's versions ([versions], newest first, each {n, at}): the one
/// its app said it was copied from ([said]) while the original has it; else
/// the newest there was when the remix was first shared ([since]), which is
/// the one a copy made then was made of; else its first. {n, inferred}.
export function againstOf(said, versions, since) {
  const kept = (versions || []).filter((one) => Number.isInteger(one?.n) && one.n >= 1);
  if (Number.isInteger(said) && kept.some((one) => one.n === said)) return { n: said, inferred: false };
  const at = Date.parse(since || "");
  const then = Number.isFinite(at) ? kept.filter((one) => Date.parse(one.at || "") <= at) : [];
  if (then.length) return { n: Math.max(...then.map((one) => one.n)), inferred: true };
  return { n: kept.length ? Math.min(...kept.map((one) => one.n)) : 1, inferred: true };
}

/// What remix [id]'s version [n] ([text], its file) changed from the
/// model it was copied from ([from]), counted and kept: the row written, or
/// null where the original is not published or its file is not there (the
/// row there was is taken away, so its page says nothing stale). [said] is
/// the version its app said; [since] when the remix was first shared;
/// [getFile] reads the shared-models bucket (api/share.js). With [keep]
/// false nothing is written or taken away: the row it would keep
/// (tools/web/remix_backfill.mjs --dry). Throws where the database or
/// storage fails.
export async function countRemix({ id, n, text, from, said = null, since = null, getFile, keep = true }) {
  if (!ID.test(id || "") || !ID.test(from || "")) return null;
  const [original] = await db(`shared_models?id=eq.${from}&published=is.true&select=id,updated_at`);
  const forget = async () => {
    if (keep) await db(`remix_changes?model=eq.${id}`, { method: "DELETE" });
    return null;
  };
  if (!original) return forget();
  let versions = await db(`share_versions?model=eq.${from}&select=n,at&order=n.desc&limit=100`);
  // Shared before its versions were kept, and not since: its version 1.
  if (!versions.length) versions = [{ n: 1, at: original.updated_at }];
  // When the remix was first shared, where its app did not say which
  // version it copied and a republish does not know: its version 1's.
  const first = since || (Number.isInteger(said) ? null
    : (await db(`share_versions?model=eq.${id}&n=eq.1&select=at`))[0]?.at || null);
  const against = againstOf(said, versions, first);
  const file = await getFile(fileOf(from, against.n, versions[0].n));
  if (!file) return forget();
  const changes = remixChanges(file.toString("utf8"), text);
  if (!changes) return null;
  const row = { model: id, n, against: from, against_n: against.n, inferred: against.inferred, ...changes.counts,
    turned: changes.turned, parts_was: changes.parts_was, parts_now: changes.parts_now, shown: changes.shown,
    at: new Date().toISOString() };
  if (keep) await db("remix_changes", { method: "POST", body: row, prefer: "resolution=merge-duplicates,return=minimal" });
  return row;
}

/// countRemix after the publish has answered (api/_after.js): the publish
/// is no slower for it, and a failure (the table not there yet, storage
/// down) is logged, never the person's.
export function countAfter(given) {
  afterAnswer(() => countRemix(given), "share: what the remix changed");
}

/// What model [id]'s Remixes tab draws (remix_tree): {changes, up, down},
/// or null before supabase/remix_changes.sql is applied (the caller reads
/// it through orUnknown, and the page is as it was).
export async function treeOf(id) {
  if (!ID.test(id || "")) return null;
  const tree = await db("rpc/remix_tree", { method: "POST", body: { model_id: id } });
  return tree && typeof tree === "object" ? tree : null;
}

/// [tree] without the remixes made by somebody blocked ([gone], [handles],
/// as api/_blocks.js withoutBlocked), and without what hangs under one.
export function treeWithout(tree, gone, handles) {
  if (!tree || !Array.isArray(tree.down)) return tree;
  const shown = new Set();
  const down = [];
  for (const node of tree.down) {
    const blocked = gone.has(String(node?.id)) || handles.has(String(node?.by?.handle || ""));
    if (blocked || (node.depth > 1 && !shown.has(String(node.parent)))) continue;
    shown.add(String(node.id));
    down.push(node);
  }
  return { ...tree, down };
}

/// /m/X/changes.json: what the 3D view of remix [row] (read as published)
/// lights and draws as ghosts, as kept with it: {n, count, added, moved,
/// recoloured, ghosts, ghost}, the ghost scene given the store's [root]
/// (api/_omr_credit.js storeRoot). 404 for a model with nothing kept.
export async function changesAnswer(response, row, root, cache) {
  const none = (status, error) => response.status(status).setHeader("Cache-Control", "no-store").json({ error });
  if (!row) return none(404, "There is no model at that link.");
  if (!row.remixed_from) return none(404, "This model is not a remix.");
  // Before supabase/remix_changes.sql there is nothing kept: the same as none.
  const [kept] = await db(`remix_changes?model=eq.${row.id}&select=n,against,against_n,added,removed,moved,recoloured,turned,shown`)
    .catch(() => []);
  if (!kept || !kept.shown || kept.against !== row.remixed_from) return none(404, "What this remix changed is not counted yet.");
  const shown = kept.shown;
  response.setHeader("Cache-Control", cache);
  return response.status(200).json({
    n: kept.n, against: kept.against, against_n: kept.against_n,
    counts: readCounts(kept), turned: kept.turned, count: shown.count,
    added: shown.added || [], moved: shown.moved || [], recoloured: shown.recoloured || [],
    ghosts: Number(shown.ghosts) || 0, ghost: shown.ghost && root ? { ...shown.ghost, root } : null,
  });
}

/// The changes [tree] says model [id] made, where they are of version
/// [n] of it and against the model it shows it was remixed from ([from]):
/// the counts, else null.
export function ownChanges(tree, n, from) {
  const changes = tree?.changes;
  if (!changes || changes.n !== n || !from || changes.against !== from) return null;
  return readCounts(changes) ? changes : null;
}

/// The line under a remix's credit: "What it changed from version 2: 42
/// parts added, 8 taken away, 3 recoloured, 5 moved", the version its
/// original's page ("What it changed: ..." where the credit above already
/// names that version, [named]), and the way to see it in 3D where its 3D
/// view has what to light (drawn).
export function changedLineHtml(changes, at, from, named = null) {
  const version = `<a href="${at}/m/${escapeHtml(from)}/v/${Number(changes.against_n)}">${asText(say("version {n}", { n: changes.against_n }))}</a>`;
  const counts = readCounts(changes);
  const any = counts && Object.values(counts).some(Boolean);
  const lead = named === changes.against_n ? asText(say("What it changed:")) : sayHtml("What it changed from {version}:", { version });
  return `<p class="remix-changes" data-against="${escapeHtml(from)}" data-against-n="${Number(changes.against_n)}">`
    + `${lead} <b>${escapeHtml(changeLine(counts))}</b>`
    + `${any && changes.drawn ? ` <button type="button" class="cta ghost small what-changed" aria-controls="model-picture">`
      + `${asText(say("See what changed in 3D"))}</button>` : ""}</p>`;
}

/// How a node of the tree says what it is: "A remix of Harbour by Ann", ",
/// itself a remix of Lighthouse" where its parent is a remix too, then what
/// it changed.
function nodeLine(changes, parent, grand) {
  if (!parent) return "";
  const named = parent.author ? say("A remix of {model} by {name}", { model: parent.name, name: parent.author })
    : parent.id ? say("A remix of {model}", { model: parent.name }) : say("A remix of a model shared by link");
  const further = grand ? (grand.id ? say(", itself a remix of {model}", { model: grand.name })
    : say(", itself a remix of a model shared by link")) : "";
  const line = changes && readCounts(changes) ? changeLine(changes) : "";
  return `${named}${further}${line ? `: ${line}` : ""}`;
}

/// A node of the tree: its picture, name, maker and line, a link to its
/// page; [self] for the model whose page it is.
function nodeHtml(origin, at, row, line, self = false) {
  const card = row.id ? cardOf(origin, row) : null;
  const picture = card ? card.thumb || card.image : null;
  const name = row.id ? escapeHtml(row.name || "") : asText(say("A model shared by link"));
  const by = row.author ? `<span class="by">${escapeHtml(say("by {name}", { name: row.author }))}</span>` : "";
  const inner = `${picture ? `<img src="${escapeHtml(picture.replace(origin, ""))}" alt="" width="64" height="48" loading="lazy" decoding="async">`
    : '<span class="no-picture" aria-hidden="true"></span>'}<span class="words"><span class="name">${name}</span>${by}`
    + `${line ? `<span class="change">${escapeHtml(line)}</span>` : ""}</span>`;
  if (self) return `<div class="node-card self" aria-current="page">${inner}<span class="here">${asText(say("This model"))}</span></div>`;
  return row.id ? `<a class="node-card" href="${at}/m/${escapeHtml(row.id)}">${inner}</a>` : `<div class="node-card">${inner}</div>`;
}

/// The Remixes tab's tree, both ways: what [model] came from, back to the
/// first, then the model itself, then what was remixed from it, three
/// levels down, each with its line. [tree] is remix_tree's; [own] the
/// model's row ({id, name, author, has_image, ...}). "" where there is
/// nothing either way (the tab says so as before).
export function treeHtml(origin, at, tree, own) {
  const up = (tree?.up || []).slice().sort((a, b) => b.depth - a.depth);
  const down = tree?.down || [];
  if (!up.length && !down.length) return "";
  // The line from the first down to the model: each node nests the next.
  const chain = [...up, { ...own, self: true, changes: tree.changes }];
  const children = new Map();
  for (const node of down) {
    const key = String(node.parent);
    if (!children.has(key)) children.set(key, []);
    children.get(key).push(node);
  }
  const byId = new Map(down.map((node) => [String(node.id), node]));
  const ownAs = { id: own.id, name: own.name, author: own.author };
  const parentOf = (node) => (node.depth === 1 ? ownAs : byId.get(String(node.parent)));
  const branch = (node) => {
    const parent = parentOf(node);
    const grand = node.depth === 1 ? (up[up.length - 1] || null) : parentOf(parent);
    const kids = children.get(String(node.id)) || [];
    return `<li>${nodeHtml(origin, at, node, nodeLine(node.changes, parent, grand))}`
      + `${kids.length && node.depth < 3 ? `<ol>${kids.map(branch).join("")}</ol>` : ""}</li>`;
  };
  const below = down.filter((node) => node.depth === 1).map(branch).join("");
  let html = "";
  for (let k = chain.length - 1; k >= 0; k -= 1) {
    const node = chain[k];
    const parent = k > 0 ? chain[k - 1] : null;
    // What the node itself was copied from, for "names both" at the top of
    // the line, where its own parent is past what is shown.
    const grand = k > 1 ? chain[k - 2] : k === 1 ? (chain[0].from || null) : null;
    const line = parent ? nodeLine(node.changes, parent.id ? parent : { id: null }, grand)
      : node.from ? nodeLine(node.changes, node.from, null) : "";
    const inner = node.self ? `${nodeHtml(origin, at, node, line, true)}${below ? `<ol>${below}</ol>` : ""}` : nodeHtml(origin, at, node, line);
    html = `<li${node.self ? ' class="self"' : ""}>${inner}${html ? `<ol>${html}</ol>` : ""}</li>`;
  }
  const label = asText(say("Where it came from and what was made from it"));
  return `<ol class="remix-tree" aria-label="${label}">${html}</ol>`;
}
