// What api/_link.js fetches from, in a test: a server of its own on this
// computer, reached under made-up names that answer made-up public
// addresses (resolve), each checked address then connected to here (dial).
// Every address dialled is in [dialled] and every lookup in [looked], so a
// test can say a private one never was. Signed in through the stand-in
// Supabase of tests/fixtures/billing/world.mjs, with may_act counted here.
//
//   const w = await linkWorld();
//   const answer = await w.ask({ url: `http://pictures.test/pic.png` });
//   w.close();
import { createServer } from "node:http";
import { gzipSync } from "node:zlib";
import { readFileSync } from "node:fs";
import { world, SUPABASE_URL } from "../billing/world.mjs";
import { linkFetch } from "../../../api/_link.js";

export const PUBLIC = "93.184.215.14";
export const PUBLIC6 = "2606:2800:21f:cb07:6820:80da:af6b:8b2c";

// A 1 x 1 PNG.
export const PNG = Buffer.from("89504e470d0a1a0a0000000d4948445200000001000000010806000000"
  + "1f15c4890000000d49444154789c6360f8cfc0f01f0005000201a1e8b3b40000000049454e44ae426082", "hex");

export async function linkWorld({ perHour = 60 } = {}) {
  const w = await world({});
  const heard = [];
  const served = {
    "/pic.png": [200, { "content-type": "image/png" }, PNG],
    "/pic.png.gz": [200, { "content-type": "image/png", "content-encoding": "gzip" }, gzipSync(PNG)],
    "/bunny.obj": [200, { "content-type": "text/plain" }, readFileSync("tests/fixtures/brickify/bunny.obj")],
    "/page.html": [200, { "content-type": "text/html" }, Buffer.from("<!DOCTYPE html><html><body>a page</body></html>")],
    "/lying.png": [200, { "content-type": "image/png" }, Buffer.from("<!doctype html><html>not a picture</html>")],
    "/notes.txt": [200, { "content-type": "text/plain" }, Buffer.from("not a model, not a picture\n")],
    "/script.png": [200, { "content-type": "image/png" }, Buffer.from("#!/bin/sh\necho hello\n")],
    "/missing.png": [404, { "content-type": "text/plain" }, Buffer.from("no")],
    "/big.png": [200, { "content-type": "image/png" }, Buffer.concat([PNG, Buffer.alloc(5 * 2 ** 20)])],
    "/to-pic": [302, { location: "/pic.png" }, Buffer.alloc(0)],
    "/to-inside": [302, { location: "http://inside.test/pic.png" }, Buffer.alloc(0)],
    "/to-metadata": [301, { location: "http://169.254.169.254/latest/meta-data/" }, Buffer.alloc(0)],
    "/to-loopback": [307, { location: "http://[::1]/pic.png" }, Buffer.alloc(0)],
    "/to-ftp": [302, { location: "ftp://pictures.test/pic.png" }, Buffer.alloc(0)],
    "/loop": [302, { location: "/loop" }, Buffer.alloc(0)],
  };
  const server = createServer((request, response) => {
    heard.push({ path: request.url, headers: request.headers });
    const path = request.url.split("?")[0];
    if (path === "/slow") return; // never answers
    if (path === "/endless.png") {
      // No length said: more than the most, a part at a time.
      response.writeHead(200, { "content-type": "image/png" });
      response.write(PNG);
      const part = Buffer.alloc(256 * 1024);
      let sent = 0;
      const more = () => {
        while (sent < 6 * 2 ** 20) {
          sent += part.length;
          if (!response.write(part)) return response.once("drain", more);
        }
        response.end();
      };
      return more();
    }
    const [status, headers, body] = served[path] || [404, {}, Buffer.from("no")];
    response.writeHead(status, { "content-length": body.length, ...headers });
    response.end(body);
  });
  await new Promise((done) => server.listen(0, "127.0.0.1", done));
  const port = server.address().port;

  const looked = [];
  const dialled = [];
  let rebinds = 0;
  const names = {
    "pictures.test": () => [{ address: PUBLIC, family: 4 }],
    "pictures6.test": () => [{ address: PUBLIC6, family: 6 }],
    "inside.test": () => [{ address: "10.0.0.5", family: 4 }],
    "inside6.test": () => [{ address: "fd00::5", family: 6 }],
    "mixed.test": () => [{ address: PUBLIC, family: 4 }, { address: "127.0.0.1", family: 4 }],
    // Public when first asked, this computer after: DNS rebinding.
    "rebind.test": () => (rebinds++ === 0 ? [{ address: PUBLIC, family: 4 }] : [{ address: "127.0.0.1", family: 4 }]),
  };
  const resolve = async (host) => {
    looked.push(host);
    if (!names[host]) throw Object.assign(new Error(`getaddrinfo ENOTFOUND ${host}`), { code: "ENOTFOUND" });
    return names[host]();
  };
  // A checked public address is this server; anything else a closed port,
  // so a private one that got through would show here and fetch nothing.
  const dial = (address, wanted) => {
    dialled.push(address);
    return address === PUBLIC || address === PUBLIC6 ? ["127.0.0.1", port] : ["127.0.0.1", 9];
  };

  // may_act (supabase/moderation.sql), counted an account at a time.
  const acts = new Map();
  const theirs = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    if (url.origin === SUPABASE_URL && url.pathname === "/rest/v1/rpc/may_act") {
      const asked = JSON.parse(init.body);
      const key = `${asked.actor}:${asked.act}`;
      const done = acts.get(key) || 0;
      const allowed = done < Math.min(perHour, asked.per_hour);
      if (allowed) acts.set(key, done + 1);
      return new Response(JSON.stringify(allowed), { status: 200 });
    }
    return theirs(input, init);
  };

  const ADA = { sub: "7d6c1a2e-0000-4000-8000-00000000ada0", email: "ada@example.com" };
  const token = await w.signIn(ADA);
  /// One POST ?op=fetch: {status, json} for a refusal, {status, kind,
  /// bytes (base64), headers} for a file.
  async function ask(body, { signedIn = true, method = "POST", seconds } = {}) {
    let status = 0;
    let json = null;
    let sent = null;
    const headers = {};
    const response = {
      setHeader: (name, value) => { headers[name.toLowerCase()] = value; return response; },
      status: (s) => { status = s; return response; },
      json: (b) => { json = b; return response; },
      end: (b) => { sent = b ?? null; return response; },
    };
    const request = { method, query: { op: "fetch" }, body,
      headers: signedIn ? { authorization: `Bearer ${token}`, cookie: "sb=secret" } : {} };
    await linkFetch(request, response, { resolve, dial, ...(seconds ? { seconds } : {}) });
    return json !== null ? { status, json } : { status, kind: headers["x-link-kind"],
      bytes: Buffer.from(sent || []).toString("base64"), headers };
  }
  return { ask, looked, dialled, heard, acts, port, close: () => server.close() };
}
