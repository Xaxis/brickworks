// A change sent back and taken, end to end through the real handlers
// (world.mjs): Ann sends her remix's change to Dee, sends it again, Dee's
// bell counts it at once and her notifications name it, each of them reads
// it (Dee with her own model's text, Ann without), Dee takes part of it
// and publishes that as her version 2 naming it, the remix's builder
// hears it was taken, and Dee's model's changes list credits Ann. Prints
// one JSON line for tests/test_suggest.py.
//
//   node tests/fixtures/suggest/flow.mjs

import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
for (const level of ["log", "warn", "info"]) console[level] = () => {};
const troubles = [];
console.error = (...said) => troubles.push(said.join(" ").slice(0, 300));

const { suggestWorld } = await import(path.join(here, "world.mjs"));
const { mergeSuggestion } = await import(path.join(here, "../../../api/_suggest.js"));
const mine = readFileSync(path.join(here, "car.mine.ldr"), "utf8");
const theirs = readFileSync(path.join(here, "car.theirs.ldr"), "utf8");
const w = await suggestWorld({ mine, theirs });
const out = {};
const step = async (name, asked) => {
  try {
    out[name] = await asked();
  } catch (trouble) {
    out[name] = { threw: String(trouble?.stack || trouble).slice(0, 400) };
  }
  return out[name];
};

await step("before_bell", () => w.ask("people", { query: { op: "feed_count" }, as: "dee" }));
await step("not_signed_in", () => w.ask("share", { method: "POST", query: { op: "suggest" }, body: { remix: w.REMIX } }));
await step("not_yours", () => w.ask("share", { method: "POST", query: { op: "suggest" }, as: "dee", body: { remix: w.REMIX } }));
await step("not_a_remix", () => w.ask("share", { method: "POST", query: { op: "suggest" }, as: "dee", body: { remix: w.MODEL } }));
// A note over 500 characters refused in words, never cut (briefs/self_attack.md).
await step("too_long", () => w.ask("share", { method: "POST", query: { op: "suggest" }, as: "ann",
  body: { remix: w.REMIX, note: "Wider wheels. ".repeat(40) } }));
await step("too_long_rows", () => w.suggestions.length);
// Zero-width characters dropped, other spaces one.
const sent = await step("sent", () => w.ask("share", { method: "POST", query: { op: "suggest" }, as: "ann",
  body: { remix: w.REMIX, note: "  Wider\u200b wheels,\u00a0and a\ufeff spoiler  " } }));
await step("sent_note", () => w.suggestions[0]?.note);
await step("sent_again", () => w.ask("share", { method: "POST", query: { op: "suggest" }, as: "ann",
  body: { remix: w.REMIX, note: "Wider wheels, and a spoiler" } }));
await step("open_rows", () => w.suggestions.filter((s) => s.status === "open").length);
// The bell, the moment it is sent: nothing waits on a job.
await step("bell", () => w.ask("people", { query: { op: "feed_count" }, as: "dee" }));
await step("ann_bell", () => w.ask("people", { query: { op: "feed_count" }, as: "ann" }));
const told = await step("notifications", () => w.ask("people", { query: { op: "notifications" }, as: "dee" }));
await step("bell_after_opening", () => w.ask("people", { query: { op: "feed_count" }, as: "dee" }));
const id = sent?.body?.id;
await step("as_sender", () => w.ask("share", { query: { op: "suggestion", id: String(id) }, as: "ann" }));
await step("as_nobody", () => w.ask("share", { query: { op: "suggestion", id: String(id) } }));
const opened = await step("as_designer", () => w.ask("share", { query: { op: "suggestion", id: String(id) }, as: "dee" }));
await step("open_for_dee", () => w.ask("share", { query: { op: "suggestions", id: w.MODEL }, as: "dee" }));
await step("open_for_ann", () => w.ask("share", { query: { op: "suggestions", id: w.MODEL }, as: "ann" }));
// Part of it: all but the recolour.
const ids = (opened?.body?.changes || []).filter((c) => c.kind !== "recoloured").map((c) => c.id);
await step("merge_by_ann", () => w.ask("share", { method: "POST", query: { op: "suggestion_merge" }, as: "ann",
  body: { id, n: 1, take: ids } }));
await step("merge_stale", () => w.ask("share", { method: "POST", query: { op: "suggestion_merge" }, as: "dee",
  body: { id, n: 2, take: ids } }));
const merged = await step("merged", () => w.ask("share", { method: "POST", query: { op: "suggestion_merge" }, as: "dee",
  body: { id, n: 1, take: ids } }));
out.merged_as_engine = merged?.body?.text === mergeSuggestion(mine, theirs, ids).text;
// Published as Dee's version 2, naming it.
await step("published", () => w.ask("share", { method: "POST", as: "dee", body: { id: w.MODEL, name: "Red car",
  model: merged?.body?.text, note: "With part of Ann's change", suggestion: { id, taken: merged?.body?.taken,
    whole: merged?.body?.whole } } }));
out.row = w.suggestions.find((s) => s.id === id) || null;
out.versions = w.versions.filter((v) => v.model === w.MODEL).map((v) => v.n);
out.file_now = w.files.get(`${w.MODEL}.mpd`)?.toString("utf8") === merged?.body?.text;
out.file_kept = w.files.get(`${w.MODEL}.v1.mpd`)?.toString("utf8") === mine;
await step("taken_again", () => w.ask("share", { method: "POST", query: { op: "suggestion_merge" }, as: "dee",
  body: { id, n: 2, take: "all" } }));
await step("ann_told", () => w.ask("people", { query: { op: "notifications" }, as: "ann" }));
await step("credited", () => w.ask("share", { query: { op: "suggestions", id: w.MODEL } }));
// A second change, declined: nothing taken, closed.
w.versions.push({ model: w.REMIX, n: 2, at: new Date().toISOString(), parts: 10, bytes: 1 });
w.files.set(`${w.REMIX}.v1.mpd`, w.files.get(`${w.REMIX}.mpd`));
w.files.set(`${w.REMIX}.mpd`, Buffer.from(theirs.replace("1 1 -60 -24 0", "1 2 -60 -24 0")));
const second = await step("second", () => w.ask("share", { method: "POST", query: { op: "suggest" }, as: "ann",
  body: { remix: w.REMIX } }));
await step("declined", () => w.ask("share", { method: "POST", query: { op: "suggestion_close" }, as: "dee",
  body: { id: second?.body?.id, status: "declined" } }));
await step("declined_row", () => w.suggestions.find((s) => s.id === second?.body?.id)?.status);
out.troubles = troubles.slice(0, 5);
out.told_groups = (told?.body?.groups || []).map((g) => ({ model: g.model, name: g.name,
  rows: (g.rows || []).map((r) => ({ kind: r.kind, line: r.line, link: r.link, who: r.who, said: r.said })) }));
process.stdout.write(`${JSON.stringify(out)}\n`);
process.exit(0);
