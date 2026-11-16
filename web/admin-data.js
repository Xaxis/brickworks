// The console's Data (admin.html #data, console3): the set catalogue and
// Rebrickable's tables it is made from, the set pictures, the parts
// library's index, what the weekly look at LDraw's model repository found,
// and what the project uses (/api/admin?op=data, api/_console_data.js).
// Supabase's egress is said to be read at Supabase, and why.
//
// Everything is put on the page as text, never as markup.
import { $, adminJson, ago, cell, count, day, emptyRow, make, say, segmented, timeCell, when } from "/admin-kit.js";

const STATE = { found: "Found, to look at", staged: "Staged", live: "In the library", refused: "Refused" };

/// [bytes] in the largest unit that keeps it under a thousand.
export function size(bytes) {
  const n = Number(bytes);
  if (!Number.isFinite(n)) return "—";
  const units = ["bytes", "KB", "MB", "GB", "TB"];
  let at = 0;
  let value = n;
  while (value >= 1000 && at < units.length - 1) {
    value /= 1000;
    at += 1;
  }
  return `${at ? value.toFixed(value < 10 ? 1 : 0) : value} ${units[at]}`;
}

let omrShown = "";

function siftOmr() {
  for (const row of $("omr").rows) if (row.dataset.state) row.hidden = Boolean(omrShown) && row.dataset.state !== omrShown;
}

export async function loadData() {
  const d = await adminJson({ op: "data" });
  const f = d.facts || {};
  const cat = f.catalogue;
  $("n-sets").textContent = cat ? count(cat.sets) : "—";
  say("n-sets-said", cat ? `the catalogue made ${day(cat.made)}` : "not known: this deployment was made without it");
  $("n-pictures").textContent = cat ? count(cat.with_picture) : "—";
  say("n-pictures-said", cat ? `${count(cat.without_picture)} without, ${Math.round((100 * cat.with_picture) / Math.max(1, cat.sets))}% have one`
    : "");
  const rb = f.rebrickable;
  $("n-rebrickable").textContent = rb?.newest ? day(rb.newest) : "—";
  // Fetched at most once a day, a condition of Rebrickable's grant
  // (tools/fetch_data.sh); older than a week is worth knowing.
  const stale = rb?.newest && Date.now() - Date.parse(rb.newest) > 7 * 86400000;
  say("n-rebrickable-said", rb?.newest ? `${ago(rb.newest)}${stale ? ": older than a week" : ""}` : "not known here", Boolean(stale));

  // The facts whole.
  const facts = $("data-facts");
  facts.replaceChildren();
  const fact = (term, ...value) => facts.append(make("dt", "", term), make("dd", "", ...value));
  fact("Set catalogue", cat ? `${count(cat.sets)} sets, ${count(cat.with_picture)} with a picture of their own in our storage, `
    + `${count(cat.without_picture)} without; made ${when(cat.made)}` : "not known");
  fact("Set pictures", f.pictures ? `${count(f.pictures.sets)} made${f.pictures.made ? `, last ${when(f.pictures.made)}` : ""} `
    + "(tools/set_pictures.py)" : "not known");
  const tables = Object.entries(rb?.tables || {});
  fact("Rebrickable", tables.length ? `${tables.length} tables, fetched ${rb.oldest === rb.newest ? when(rb.newest)
    : `${when(rb.oldest)} to ${when(rb.newest)}`} (tools/fetch_data.sh, at most once a day)` : "not known");
  const index = d.index;
  fact("Parts library", index?.at ? `its index written ${when(index.at)} (${ago(index.at)}), ${size(index.bytes)}`
    : index ? `the store answered ${index.status || "nothing"}` : "no store here (PARTS_URL)");
  fact("This was made", f.made ? `${when(f.made)}, as this deployment was` : "—");

  // The OMR.
  const omr = d.omr || {};
  const states = omr.states || {};
  $("n-omr-found").textContent = omr.arrivals === null ? "—" : count(states.found || 0);
  const last = omr.runs?.[0];
  say("n-omr-said", last ? `looked ${ago(last.at)}${last.outcome === "failed" ? ", and failed" : ""}` : "not looked yet",
    last?.outcome === "failed");
  say("omr-said", omr.arrivals === null ? "Not kept yet: supabase/gallery_crons.sql is not applied."
    : `What the weekly look found: each new model of a set, and what became of it. ${Object.entries(states)
      .map(([state, n]) => `${n} ${(STATE[state] || state).toLowerCase()}`).join(", ") || "Nothing found yet"}.`
      + `${last ? ` Last looked ${when(last.at)}.` : ""} Run it now from Site.`);
  const group = $("omr-states");
  for (const button of [...group.querySelectorAll("button")].slice(1)) button.remove();
  for (const state of Object.keys(states)) {
    const button = make("button", "", `${STATE[state] || state} ${states[state]}`);
    button.type = "button";
    button.dataset.value = state;
    button.setAttribute("aria-pressed", String(omrShown === state));
    group.append(button);
  }
  const body = $("omr");
  body.replaceChildren();
  for (const one of omr.arrivals || []) {
    const row = make("tr");
    row.dataset.state = one.state;
    timeCell(row, one.found_at);
    cell(row, one.name || "—", "about");
    cell(row, one.set_number || "—");
    cell(row, one.author || "—", one.author ? "" : "faint");
    cell(row, `${STATE[one.state] || one.state}${one.why ? `: ${one.why}` : ""}`, one.state === "refused" ? "said faint" : "said");
    body.append(row);
  }
  if (!body.rows.length) emptyRow(body, omr.arrivals === null ? "Not kept yet." : "Nothing found yet.");
  siftOmr();

  // Usage.
  const u = d.usage;
  $("n-db").textContent = u ? size(u.database) : "—";
  say("n-db-said", u ? `of the database, ${u.tables?.length ? `the biggest table ${u.tables[0].name}` : ""}` : "not read: supabase/console3.sql");
  const buckets = u?.buckets || [];
  const stored = buckets.reduce((n, one) => n + (Number(one.bytes) || 0), 0);
  $("n-storage").textContent = u?.buckets ? size(stored) : "—";
  say("n-storage-said", u?.buckets ? `${count(buckets.reduce((n, one) => n + (Number(one.files) || 0), 0))} files in ${buckets.length} buckets`
    : "not read here");
  say("usage-said", u ? `Read ${when(u.at)}, from the database itself (supabase/console3.sql admin_usage).` : "");
  $("egress-said").textContent = d.egress?.why || "";
  if (d.egress?.href) {
    const to = make("a", "", "Supabase's usage");
    to.href = d.egress.href;
    to.rel = "noopener";
    to.target = "_blank";
    $("egress-said").append(" ", to);
  }
  const bucketRows = $("buckets");
  bucketRows.replaceChildren();
  for (const one of buckets) {
    const row = make("tr");
    const name = make("th", "", one.bucket);
    name.scope = "row";
    row.append(name);
    cell(row, count(one.files), "n");
    cell(row, size(one.bytes), "n");
    bucketRows.append(row);
  }
  if (!buckets.length) emptyRow(bucketRows, u ? "No bucket could be read." : "Not read.");
  const tableRows = $("db-tables");
  tableRows.replaceChildren();
  for (const one of u?.tables || []) {
    const row = make("tr");
    const name = make("th", "", one.name);
    name.scope = "row";
    row.append(name);
    cell(row, Number(one.rows) >= 0 ? count(Math.round(Number(one.rows))) : "—", "n");
    cell(row, size(one.bytes), "n");
    tableRows.append(row);
  }
  if (!tableRows.rows.length) emptyRow(tableRows, "Not read.");
  say("data-note", `Asked ${new Date().toLocaleTimeString()}.`);
  return d;
}

segmented($("omr-states"), (value) => { omrShown = value; siftOmr(); });
