// signreview3: what run_flows.sh's five ways_flow runs and its control sent toward the real
// Google and GitHub, counted four ways: strace's connect() of every process (the relay's and
// the flow's trees, Chromium's network service in them), Chromium's own net log, netwatch's
// Node lookups and connects, and the flow's own Playwright count. Every outside address a
// process connected to is named by its reverse DNS and checked against Google's and GitHub's
// published ranges (goog.json and api.github.com/meta, as of 2026; copied here, not fetched).
//
//   node count.mjs DIR
import { readFileSync, readdirSync, existsSync } from "node:fs";
import { promises as dns } from "node:dns";
import path from "node:path";

const DIR = process.argv[2];
const NET = path.join(DIR, "net");
const PROVIDER = /(^|\.)(google\.com|googleapis\.com|gstatic\.com|googleusercontent\.com|github\.com|githubusercontent\.com|githubassets\.com)$/i;

const V4 = {
  google: ["8.8.4.0/24", "8.8.8.0/24", "8.34.208.0/20", "8.35.192.0/20", "23.236.48.0/20", "23.251.128.0/19", "64.233.160.0/19",
    "66.102.0.0/20", "66.249.64.0/19", "70.32.128.0/19", "72.14.192.0/18", "74.114.24.0/21", "74.125.0.0/16", "108.170.192.0/18",
    "108.177.0.0/17", "142.250.0.0/15", "172.217.0.0/16", "172.253.0.0/16", "173.194.0.0/16", "192.178.0.0/15", "209.85.128.0/17",
    "216.58.192.0/19", "216.239.32.0/19"],
  github: ["192.30.252.0/22", "185.199.108.0/22", "140.82.112.0/20", "143.55.64.0/20"],
};
const V6 = { google: ["2001:4860:", "2404:6800:", "2607:f8b0:", "2800:3f0:", "2a00:1450:", "2c0f:fb50:"], github: ["2a0a:a44", "2606:50c0:"] };
const v4n = (ip) => ip.split(".").reduce((n, part) => n * 256 + Number(part), 0);
const inV4 = (ip, cidr) => {
  const [base, bits] = cidr.split("/");
  const size = 2 ** (32 - Number(bits));
  return Math.floor(v4n(ip) / size) === Math.floor(v4n(base) / size);
};
function owner(ip) {
  for (const [who, list] of Object.entries(ip.includes(":") ? V6 : V4)) {
    if (ip.includes(":") ? list.some((p) => ip.toLowerCase().startsWith(p)) : list.some((c) => inV4(ip, c))) return who;
  }
  return null;
}
const local = (ip) => /^(127\.|0\.0\.0\.0$|::1$|::ffff:127\.|10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)/.test(ip) || ip === "::";

// What a connect() came to: sent (0, EINPROGRESS: a TCP handshake begun, or a UDP socket
// aimed), or refused by this machine's kernel (ENETUNREACH and the like: nothing left).
// Two kinds aim a UDP socket and send nothing: glibc's address sort for getaddrinfo (RFC
// 6724, port 0), and Chromium's IPv6 reachability probe (HostResolverManager
// IsGloballyReachable: a UDP connect to 2001:4860:4860::8888 port 443, Google's public DNS
// address, with no packet). Both are named, never counted as a request.
const PROBE6 = "2001:4860:4860::8888:443";
function straced(file) {
  const out = new Map();
  if (!existsSync(file)) return null;
  for (const line of readFileSync(file, "utf8").split("\n")) {
    if (!line.includes("connect(")) continue;
    const v4 = /sin_port=htons\((\d+)\), sin_addr=inet_addr\("([\d.]+)"\)/.exec(line);
    const v6 = /sin6_port=htons\((\d+)\).*inet_pton\(AF_INET6, "([^"]+)"/.exec(line);
    const hit = v4 || v6;
    if (!hit) continue;
    const ip = hit[2];
    if (local(ip)) continue;
    const result = /= (0|-1 [A-Z]+)/.exec(line)?.[1] || "?";
    const key = `${ip}:${hit[1]}`;
    const entry = out.get(key) || { n: 0, results: new Map() };
    entry.n += 1;
    entry.results.set(result, (entry.results.get(result) || 0) + 1);
    out.set(key, entry);
  }
  return out;
}
const leftTheBox = (entry) => [...entry.results].filter(([r]) => r === "0" || r === "-1 EINPROGRESS").reduce((n, [, k]) => n + k, 0);

// Chromium's net log, read as events: each URL request begun (URL_REQUEST_START_JOB) by host,
// each redirect's Location (URL_REQUEST_REDIRECTED), and each socket's outside address.
function netlogged(dir) {
  const hosts = new Map();
  const addresses = new Set();
  const provider = [];
  const redirects = new Map();
  if (!existsSync(dir)) return null;
  for (const name of readdirSync(dir)) {
    const text = readFileSync(path.join(dir, name), "utf8");
    let log;
    try { log = JSON.parse(text); } catch { log = JSON.parse(`${text.trimEnd().replace(/,$/, "")}]}`); }
    const type = Object.fromEntries(Object.entries(log.constants.logEventTypes).map(([k, v]) => [v, k]));
    for (const event of log.events) {
      const p = event.params || {};
      const kind = type[event.type];
      if (kind === "URL_REQUEST_START_JOB" && p.url) {
        let host = "";
        try { host = new URL(p.url).hostname; } catch { continue; }
        hosts.set(host, (hosts.get(host) || 0) + 1);
        if (PROVIDER.test(host)) provider.push(p.url.slice(0, 120));
      }
      if (kind === "URL_REQUEST_REDIRECTED" && p.location) {
        const to = p.location.split("?")[0];
        redirects.set(to, (redirects.get(to) || 0) + 1);
        let host = "";
        try { host = new URL(p.location).hostname; } catch { /* relative */ }
        if (PROVIDER.test(host)) provider.push(`redirect ${p.location.slice(0, 100)}`);
      }
      for (const field of ["address", "remote_address"]) {
        if (typeof p[field] !== "string") continue;
        const ip = p[field].replace(/^\[/, "").replace(/\]?:\d+$/, "");
        if (!local(ip)) addresses.add(p[field]);
      }
    }
  }
  return { hosts, addresses, provider, redirects };
}

function watched(file) {
  const hosts = new Map();
  if (!existsSync(file)) return null;
  for (const line of readFileSync(file, "utf8").split("\n")) {
    const hit = /^\d+ (lookup|connect) (\S+)$/.exec(line);
    if (!hit) continue;
    const host = hit[1] === "connect" ? hit[2].replace(/:\d+$/, "") : hit[2];
    if (/^(127\.0\.0\.1|localhost|::1)$/.test(host)) continue;
    hosts.set(host, (hosts.get(host) || 0) + 1);
  }
  return hosts;
}

const names = new Map();
async function nameOf(ip) {
  if (!names.has(ip)) names.set(ip, await dns.reverse(ip).then((all) => all.join(","), () => "(no PTR)"));
  return names.get(ip);
}

let toProviders = 0;
// Every run there is a log of (a sixth when one of the five stopped short), then the control.
const numbered = readdirSync(DIR).map((name) => /^ways_flow_(\d+)\.log$/.exec(name)?.[1]).filter(Boolean).sort((a, b) => a - b);
const runs = [...numbered, "control"];
for (const run of runs) {
  const flowLog = path.join(DIR, run === "control" ? "control.log" : `ways_flow_${run}.log`);
  const flowText = existsSync(flowLog) ? readFileSync(flowLog, "utf8") : "";
  console.log(`== ${run === "control" ? "the control" : `run ${run}`}: ${(flowText.trim().split("\n").pop() || "(no log)").slice(0, 160)}`);
  if (run !== "control") {
    const own = /requests to Google's or GitHub's hosts: (\d+)/.exec(flowText);
    console.log(`  Playwright's count (the flow's own 10.): ${own ? own[1] : "(none printed)"}`);
  } else {
    for (const line of flowText.split("\n").filter((l) => l.startsWith("  --"))) console.log(`  control${line.slice(3)}`);
  }
  const traces = run === "control" ? [["control", path.join(NET, "strace_control.log")]]
    : [["relay", path.join(NET, `strace_relay_${run}.log`)], ["flow", path.join(NET, `strace_flow_${run}.log`)]];
  for (const [who, file] of traces) {
    const seen = straced(file);
    if (!seen) { console.log(`  strace ${who}: (no log)`); continue; }
    const parts = [];
    for (const [key, entry] of seen) {
      const ip = key.replace(/:\d+$/, "");
      const named = await nameOf(ip);
      const probe = key === PROBE6 ? "Chromium's IPv6 reachability probe (UDP, no packet)"
        : key.endsWith(":0") ? "getaddrinfo's address sort (UDP, port 0, no packet)" : "";
      const is = probe ? null : owner(ip) || (/1e100\.net|google|github/i.test(named) ? "named-provider" : null);
      const sent = leftTheBox(entry);
      if (is && run !== "control") toProviders += sent;
      parts.push(`${key} x${entry.n} [${[...entry.results].map(([r, k]) => `${r} ${k}`).join(", ")}] ${named}`
        + `${probe ? ` (${probe})` : ""}${is ? ` <<${is.toUpperCase()}, ${sent} begun>>` : ""}`);
    }
    console.log(`  strace ${who}: ${seen.size} outside address(es)${parts.length ? `: ${parts.join("; ")}` : ""}`);
  }
  const logged = netlogged(path.join(NET, `netlog_${run}`));
  if (logged) {
    const outside = [...logged.hosts].filter(([h]) => !/^(127\.0\.0\.1|localhost)$/.test(h));
    const deliberate = logged.provider.filter((u) => /^https:\/\/(accounts\.google\.com\/o\/oauth2\/v2\/auth|github\.com\/login\/oauth\/authorize)$/.test(u));
    const hops = logged.provider.length - deliberate.length;
    console.log(`  Chromium net log: requests begun by host ${outside.map(([h, n]) => `${h} x${n}`).join(", ") || "(only 127.0.0.1)"}; `
      + `outside sockets ${[...logged.addresses].join(", ") || "none"}; redirects ${[...logged.redirects].map(([l, n]) => `${l.replace(/^http:\/\/127\.0\.0\.1:\d+/, "")} x${n}`).join(", ")}; `
      + `to a provider: ${deliberate.length} bare page(s) with no query (step 10's own can't-reach probe${run === "control" ? ", here the control's" : ""}), `
      + `${hops} other${hops ? `: ${logged.provider.filter((u) => !deliberate.includes(u)).slice(0, 6).join(" ")}` : ""}`);
    if (run !== "control") toProviders += hops;
  }
  const watchFiles = run === "control" ? [["control", "control.watch"]] : [["relay", `relay_${run}.watch`], ["flow", `flow_${run}.watch`]];
  for (const [who, name] of watchFiles) {
    const hosts = watched(path.join(NET, name));
    if (!hosts) { console.log(`  netwatch ${who}: (no log)`); continue; }
    const hits = [...hosts].filter(([h]) => PROVIDER.test(h));
    if (run !== "control") toProviders += hits.reduce((n, [, k]) => n + k, 0);
    console.log(`  netwatch ${who}: ${[...hosts].map(([h, n]) => `${h} x${n}`).join(", ") || "(nothing outside)"}${hits.length ? " <<PROVIDER>>" : ""}`);
  }
}
console.log(`count: ${toProviders} request(s) toward Google's or GitHub's hosts across ${numbered.length} runs, beyond step 10's own bare probes `
  + "(strace connects begun to their addresses, net log requests and redirects, netwatch lookups; the control apart)");
