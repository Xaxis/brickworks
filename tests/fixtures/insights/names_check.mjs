// web/tally.js's names, in node: what a row's name, a page, a source and a
// device are made from what the browser gives. The collector itself stays
// still (this browser says no, as Settings' choice would). What
// tests/test_insights.py asks of them.
//
//   node tests/fixtures/insights/names_check.mjs
//
// Prints one JSON object, each finding by name.
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

const web = new URL("../../../web/", import.meta.url);
const sent = [];
globalThis.window = globalThis;
globalThis.location = new URL("https://brickworks.diy/gallery");
globalThis.document = { querySelector: () => null, documentElement: { lang: "en" }, referrer: "", visibilityState: "visible" };
globalThis.localStorage = { getItem: (key) => (key === "brickworks.counting" ? "no" : null), setItem: () => {} };
globalThis.sessionStorage = { getItem: () => null, setItem: () => {} };
globalThis.screen = { width: 1280, height: 800 };
globalThis.fetch = async (...asked) => {
  sent.push(asked);
  return new Response("", { status: 204 });
};
// The page's own imports, from this checkout.
const here = mkdtempSync(join(tmpdir(), "names-"));
writeFileSync(join(here, "counting.mjs"), readFileSync(new URL("counting.js", web), "utf8"));
writeFileSync(join(here, "tally.mjs"), readFileSync(new URL("tally.js", web), "utf8")
  .replaceAll('"/counting.js"', JSON.stringify(pathToFileURL(join(here, "counting.mjs")).href))
  .replaceAll('"/counting-ask.js"', '"data:text/javascript,export const ask = () => {}"'));
const tally = await import(pathToFileURL(join(here, "tally.mjs")).href);

const out = {};
out.names = Object.fromEntries([
  ["Paint", "Paint"], ["accents", "Ünïcödé Tóol"], ["zero_width", "pa​i‍nt﻿"], ["spaces", "  render   go "],
  ["digits", "step 12 of 340"], ["at", "ada@example.com"], ["markup", "<b>x</b>"], ["long", "x".repeat(100)],
  ["symbols", "tool:paint/1#a.b-c"], ["empty", ""], ["null", null], ["fullwidth", "ＰＡＩＮＴ"],
].map(([key, text]) => [key, tally.nameOf(text)]));
out.names_digits = tally.nameOf("res://src/ui/main.gd:1234", true);
out.pages = Object.fromEntries([
  ["model", ["/m/AbCdEfGhIj"]], ["version_de", ["/de/m/AbCdEfGhIj/v/3"]], ["profile", ["/u/ada-l"]], ["challenge", ["/c/0123456789"]],
  ["set", ["/library/set/10294-1"]], ["app", ["/app"]], ["build", ["/b/0123abcd"]], ["unknown", ["/no/such/page"]],
  ["canonical", ["/gallery", "https://brickworks.diy/gallery"]], ["canonical_fr", ["/fr/gallery", "https://brickworks.diy/fr/gallery/"]],
  ["canonical_odd", ["/x", "https://brickworks.diy/AB%20cd"]], ["said_es", ["/about", "https://brickworks.diy/about", "es-ES"]],
  ["talk", ["/talk", "https://brickworks.diy/talk"]], ["talk_board_de", ["/de/talk/b/help", "https://brickworks.diy/de/talk/b/help"]],
  ["talk_thread", ["/talk/t/12/my-tower", "https://brickworks.diy/talk/t/12/my-tower"]], ["talk_bare", ["/talk/t/12"]],
  ["talk_new", ["/fr/talk/new"]],
].map(([key, [path, canonical, said]]) => [key, tally.pageOf(path, canonical, said)]));
out.sources = Object.fromEntries([
  ["desk", ["https://brickworks.diy/?utm_source=reddit&utm_medium=social&utm_campaign=bw-abcdefghij", "https://www.reddit.com/r/lego/comments/xyz"]],
  ["google", ["https://brickworks.diy/", "https://www.google.com/search?q=ada+lovelace"]],
  ["chatgpt", ["https://brickworks.diy/", "https://chatgpt.com/c/123"]],
  ["paid", ["https://brickworks.diy/?utm_source=Google&utm_medium=cpc&utm_campaign=Winter Sale 2026", ""]],
  ["mail", ["https://brickworks.diy/?utm_medium=email&utm_source=newsletter", ""]],
  ["own", ["https://brickworks.diy/", "https://brickworks.diy/gallery"]],
  ["blog", ["https://brickworks.diy/", "https://someones-blog.example/post/ada?id=7"]],
  ["desk_digits", ["https://brickworks.diy/?utm_source=reddit&utm_medium=social&utm_campaign=bw-k3j2h1g0f9", ""]],
  ["digit_host", ["https://brickworks.diy/", "https://9to5mac.com/2026/11/lego"]],
  ["email_source", ["https://brickworks.diy/?utm_source=ada@example.com&utm_campaign=x", ""]],
  ["none", ["https://brickworks.diy/", ""]],
  ["bad", ["not a url", "also not"]],
].map(([key, [landing, referrer]]) => [key, tally.cameFrom(landing, referrer)]));
out.devices = Object.fromEntries([
  ["iphone", ["Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1", 5, 390]],
  ["ipad", ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15", 5, 820]],
  ["mac", ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Safari/605.1.15", 0, 900]],
  ["android", ["Mozilla/5.0 (Linux; Android 15; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Mobile Safari/537.36", 5, 412]],
  ["android_tablet", ["Mozilla/5.0 (Linux; Android 14; SM-X710) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36", 5, 800]],
  ["edge", ["Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36 Edg/131.0", 0, 1080]],
  ["firefox_linux", ["Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0", 0, 1080]],
].map(([key, [ua, touch, short]]) => [key, tally.deviceOf(ua, touch, short)]));
// Said no: nothing sent, nothing started, after a beacon's time.
await new Promise((resolve) => setTimeout(resolve, 200));
out.sent_when_no = sent.length;
out.started_when_no = Boolean(globalThis.brickworksTallying);
process.stdout.write(`${JSON.stringify(out)}\n`);
process.exit(0);
