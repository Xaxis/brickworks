// The console's Site (admin.html #site, console2): which release is live
// and since when, the releases before it with their units, each cron's last
// runs, and whether the backend answers (/api/admin?op=site,
// api/_console_site.js; this deployment's commit from /version.json).
//
// Everything is put on the page as text, never as markup.
import { $, adminJson, ago, cell, day, emptyRow, make, say, timeCell, when } from "/admin-kit.js";

export const CRON_STATE = { ok: "Ran", failed: "Failed", late: "Late", running: "Running", never: "Not kept yet", unknown: "Not known" };
const OUTCOME = { done: "done", unchanged: "nothing to do", locked: "another run held it", failed: "failed" };

let version = null;
/// This deployment's /version.json: {commit, deployed}, or null.
export async function versionOf() {
  version ||= await fetch("/version.json", { cache: "no-store" }).then((reply) => (reply.ok ? reply.json() : null)).catch(() => null);
  return version;
}

/// The release of [releases] this deployment is, by its commit.
export function releaseOf(releases, commit) {
  if (!commit) return null;
  return (releases || []).find((one) => one.sha.startsWith(commit) || String(commit).startsWith(one.sha)) || null;
}

const statePill = (state) => make("span", state === "ok" ? "pill good" : state === "failed" || state === "late" ? "pill bad" : "pill",
  CRON_STATE[state] || state);

/// What a run said, in a line.
function runSaid(run) {
  const s = run.said || {};
  const bits = [];
  if (s.error) bits.push(String(s.error));
  if (Array.isArray(s.failed) && s.failed.length) bits.push(`failed ${s.failed.join("; ")}`);
  if (s.held) bits.push(String(s.held));
  if (s.removed !== undefined) bits.push(`${s.removed} files removed of ${s.looked_at ?? "?"}`);
  if (s.mailed) bits.push(`mailed: ${s.mailed}`);
  if (s.reason) bits.push(String(s.reason));
  return bits.join(" · ").slice(0, 240);
}

export async function loadSite() {
  const [s, v] = await Promise.all([adminJson({ op: "site" }), versionOf()]);
  const live = releaseOf(s.releases, v?.commit);
  if (live) {
    say("site-live-h", `${live.tag}, live since ${when(live.live_at)}`);
    say("site-live-said", `${ago(live.live_at)}. Commit ${live.sha}${live.units?.length ? `; its units: ${live.units.join(", ")}` : ""}. `
      + `${live.title || ""}`);
  } else {
    say("site-live-h", v ? `This deployment: commit ${v.commit}` : "This deployment's commit is not known");
    say("site-live-said", `${v ? `Deployed ${when(v.deployed)} (${ago(v.deployed)}). ` : ""}${s.releases === null
      ? "Releases are not kept yet: supabase/console2.sql is not applied."
      : s.releases?.length ? `Not a release that went live (a preview); the latest live is ${s.releases[0].tag}, since ${when(s.releases[0].live_at)}.`
        : "No release has been written down yet: the train writes each as it goes live."}`);
  }

  // Health.
  const health = $("health");
  health.replaceChildren();
  for (const part of Object.values(s.health?.parts || {})) {
    const row = make("tr");
    const name = make("th", "", part.name);
    name.scope = "row";
    row.append(name);
    cell(row, make("span", part.ok ? "pill good" : "pill bad", part.ok ? "Answers" : part.restricted ? "Restricted" : "Down"));
    cell(row, part.ok ? `${part.status}` : `${part.status ?? "no answer"}${part.said ? `: ${part.said}` : ""}`, "said");
    cell(row, `${part.ms} ms`, "n");
    health.append(row);
  }
  if (!health.rows.length) emptyRow(health, "Not asked.");
  say("health-said", s.health?.ok ? `Every part answers, asked ${ago(s.health.at)}.` : s.health?.fix || "", !s.health?.ok);

  // Crons.
  const crons = $("crons");
  crons.replaceChildren();
  for (const cron of s.crons || []) {
    const row = make("tr");
    row.dataset.job = cron.job;
    row.dataset.state = cron.state;
    const name = make("th", "", make("code", "", cron.path), make("br"), make("small", "faint", cron.what));
    name.scope = "row";
    row.append(name);
    cell(row, cron.when, "line");
    cell(row, statePill(cron.state));
    const last = cron.runs?.[0];
    const at = make("td", "about");
    if (last) {
      at.append(`${when(last.at)} (${ago(last.at)})`, make("br"), make("small", "faint",
        [OUTCOME[last.outcome] || last.outcome || "running", last.holder, runSaid(last)].filter(Boolean).join(" · ")));
    } else {
      at.append(cron.state === "never" ? "No run written down yet" : "—");
    }
    row.append(at);
    const before = make("td");
    const pills = make("ul", "pills states");
    for (const run of (cron.runs || []).slice(1)) {
      const one = make("li", "", make("span", run.outcome === "failed" ? "pill bad" : run.outcome === "done" || run.outcome === "unchanged"
        ? "pill good" : "pill", day(run.at)));
      one.title = `${when(run.at)}: ${OUTCOME[run.outcome] || run.outcome || "running"}${runSaid(run) ? `, ${runSaid(run)}` : ""}`;
      pills.append(one);
    }
    before.append(pills.children.length ? pills : make("span", "faint", "—"));
    row.append(before);
    crons.append(row);
  }
  if (!crons.rows.length) emptyRow(crons, "Not asked.");

  // Releases.
  const releases = $("releases");
  releases.replaceChildren();
  for (const one of s.releases || []) {
    const row = make("tr");
    row.dataset.release = one.tag;
    const name = make("th", "", one.tag);
    name.scope = "row";
    if (live && live.tag === one.tag) name.append(" ", make("span", "badge accent", "Live"));
    row.append(name);
    timeCell(row, one.live_at);
    cell(row, make("code", "", one.sha.slice(0, 9)));
    cell(row, one.units?.length ? one.units.join(", ") : "—", one.units?.length ? "units" : "units faint");
    cell(row, one.title || "—", "brought said");
    releases.append(row);
  }
  if (!releases.rows.length) {
    emptyRow(releases, s.releases === null ? "Not kept yet: supabase/console2.sql is not applied."
      : s.releases_error || "None written down yet: the release train writes each as it goes live.");
  }
  say("site-note", `Asked ${new Date().toLocaleTimeString()}.`);
  return s;
}
