// signreview3 (2026-11-25): every host a Node process looks up or connects to, and, in a
// process that drives Playwright's Chromium, Chromium's own net log of every request and
// DNS job, so a count of requests to the real Google and GitHub does not rest on
// Playwright's own events (signreview2 SR4: Playwright's routes missed redirect hops).
//
//   NETWATCH_LOG=FILE NETWATCH_NETLOG_DIR=DIR NODE_OPTIONS="--import=/abs/netwatch.mjs" node ...
//
// Each line of FILE: "<pid> lookup <host>" or "<pid> connect <host>:<port>". NETWATCH_NETLOG_DIR,
// when set, adds --log-net-log=DIR/netlog-<pid>-<n>.json to each chromium.launch.
import dns from "node:dns";
import net from "node:net";
import { appendFileSync } from "node:fs";

const LOG = process.env.NETWATCH_LOG || "";
const note = (line) => {
  if (LOG) {
    try { appendFileSync(LOG, `${process.pid} ${line}\n`); } catch { /* the log is not the test */ }
  }
};

const lookup = dns.lookup;
dns.lookup = function watchedLookup(host, ...rest) {
  note(`lookup ${host}`);
  return lookup.call(this, host, ...rest);
};
const plookup = dns.promises.lookup;
dns.promises.lookup = function watchedPromiseLookup(host, ...rest) {
  note(`lookup ${host}`);
  return plookup.call(this, host, ...rest);
};
const connect = net.Socket.prototype.connect;
net.Socket.prototype.connect = function watchedConnect(...args) {
  const first = args[0];
  const options = Array.isArray(first) ? first[0] : first;
  if (options && typeof options === "object" && !options.path) note(`connect ${options.host || "localhost"}:${options.port}`);
  else if (typeof first === "number" || (typeof first === "string" && /^\d+$/.test(first))) note(`connect ${args[1] || "localhost"}:${first}`);
  return connect.apply(this, args);
};

const DIR = process.env.NETWATCH_NETLOG_DIR || "";
if (DIR) {
  const { chromium } = await import("/mnt/Projects/brickworks/tools/web/node_modules/playwright/index.mjs");
  const launch = chromium.launch.bind(chromium);
  let n = 0;
  chromium.launch = (options = {}) => {
    n += 1;
    const file = `${DIR}/netlog-${process.pid}-${n}.json`;
    note(`netlog ${file}`);
    return launch({ ...options, args: [...(options.args || []), `--log-net-log=${file}`, "--net-log-capture-mode=Default"] });
  };
}
