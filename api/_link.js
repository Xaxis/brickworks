// A link fetched for the app in a browser (urlfetch, 2026-11-03): the
// picture or 3D model a person or a session gives it as a link, brickify
// url= and print_part picture_url= (src/net/app_tools.gd, _fetch).
//
//   POST /api/account?op=fetch   {url}, signed in: 200 with the file's
//                                bytes (application/octet-stream, its kind
//                                in X-Link-Kind); otherwise {error, why},
//                                the error a sentence a person can act on.
//
// A browser cannot fetch from most sites itself: the app's page names a
// few hosts in connect-src, and a site that sends no CORS headers is
// refused even then. Every link came back "Could not fetch … (error 4)".
// The desktop fetches direct, as ever; the web build asks here.
//
// Run on the open internet for anyone signed in, so it fetches only what
// the tools take, from where anyone could:
//
//   - http and https on the web's usual ports, nothing sent but a fixed
//     User-Agent: no cookie, no sign-in, no name and password in the link;
//   - every address the host has checked before a byte is sent, and the
//     request made to the address checked, so a name that answers a public
//     address and then a private one (DNS rebinding) never reaches the
//     second. No private, loopback, link-local, metadata, multicast or
//     reserved address, at every hop: redirects are followed here, HOPS at
//     most, each one checked the same way;
//   - at most MOST bytes (Vercel answers a function's response of over
//     4.5 MB with an error of its own), SECONDS for the whole of it;
//   - what came back sniffed from its bytes, whatever the site says it is:
//     a picture (PNG, JPEG, WebP, GIF, BMP, SVG) or a 3D model Brickify
//     reads (OBJ, STL, glTF, GLB, PLY, 3MF, VOX, FBX) and what an OBJ or a
//     glTF names beside it (.mtl, .bin). The answer is never served as what
//     it is: octet-stream, nosniff, an attachment, sandboxed;
//   - LIMITS a signed-in account, counted by may_act (moderation.sql);
//   - the log says the host, never the link: a query can hold anything.
import { lookup } from "node:dns/promises";
import http from "node:http";
import https from "node:https";
import { BlockList, isIP } from "node:net";
import zlib from "node:zlib";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";

export const MOST = 4 * 1024 * 1024;
export const SECONDS = 20;
export const HOPS = 5;
export const PORTS = Object.freeze([80, 443, 8080, 8443]);
export const AGENT = "Brickworks/1 (+https://brickworks.diy; a link a person gave the app)";
// How many links an account may fetch: [an hour, a day]. An OBJ with its
// .mtl and two pictures is four.
export const LIMITS = Object.freeze([60, 300]);
const LONGEST = 2048;

export class LinkRefusal extends Error {
  constructor(status, why, said) {
    super(said);
    this.status = status;
    this.why = why;
  }
}

// Where a link may not lead: this computer, the network it is on, and
// every range that is not somebody's site on the open internet.
const NEAR = new BlockList();
for (const [net, bits] of [["0.0.0.0", 8], ["10.0.0.0", 8], ["100.64.0.0", 10], ["127.0.0.0", 8],
  ["169.254.0.0", 16], ["172.16.0.0", 12], ["192.0.0.0", 24], ["192.0.2.0", 24], ["192.88.99.0", 24],
  ["192.168.0.0", 16], ["198.18.0.0", 15], ["198.51.100.0", 24], ["203.0.113.0", 24], ["224.0.0.0", 4],
  ["240.0.0.0", 4]]) {
  NEAR.addSubnet(net, bits, "ipv4");
}
// IPv6: only global unicast (2000::/3), less Teredo, documentation and
// 6to4, which carry or stand for an IPv4 address of their own.
const GLOBAL6 = new BlockList();
GLOBAL6.addSubnet("2000::", 3, "ipv6");
for (const [net, bits] of [["2001::", 32], ["2001:db8::", 32], ["2002::", 16]]) NEAR.addSubnet(net, bits, "ipv6");

/// Whether [address] (an IP) is one a link may not lead to.
export function isNear(address) {
  const family = isIP(address);
  if (family === 4) return NEAR.check(address, "ipv4");
  if (family === 6) return !GLOBAL6.check(address, "ipv6") || NEAR.check(address, "ipv6");
  return true;
}

/// Bytes as a person says them: "14 MB", "4.3 MB", "640 KB".
export function sizeWords(bytes) {
  if (bytes >= 10 * 2 ** 20) return `${Math.round(bytes / 2 ** 20)} MB`;
  if (bytes >= 2 ** 20) return `${Number((bytes / 2 ** 20).toFixed(1))} MB`;
  return `${Math.max(1, Math.round(bytes / 1024))} KB`;
}

const TOO_LARGE = (size) => `That file is ${size}; Brickworks can bring in up to ${sizeWords(MOST)} from a link. `
  + "Save it to your computer and bring it in from there instead.";
const KINDS_WORDS = "a picture (PNG, JPEG, WebP, GIF, BMP or SVG) or a 3D model (OBJ, STL, glTF, GLB, PLY, 3MF, "
  + "VOX or FBX)";

/// What [bytes] are, by their bytes, of the kinds a link may bring in, or
/// "". [path] is the link's, for a glTF's .bin alone, which is bare numbers
/// and says nothing of itself.
export function kindOf(bytes, path = "") {
  const at = (text, offset = 0) => bytes.subarray(offset, offset + text.length).toString("latin1") === text;
  if (bytes.length >= 8 && bytes.readUInt32BE(0) === 0x89504e47 && bytes.readUInt32BE(4) === 0x0d0a1a0a) return "png";
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "jpeg";
  if (at("RIFF") && at("WEBP", 8)) return "webp";
  if (at("GIF87a") || at("GIF89a")) return "gif";
  if (at("BM") && bytes.length >= 26 && [12, 40, 52, 56, 64, 108, 124].includes(bytes.readUInt32LE(14))) return "bmp";
  if (at("glTF") && bytes.length >= 12 && bytes.readUInt32LE(4) === 2) return "glb";
  if (at("VOX ")) return "vox";
  if (at("Kaydara FBX Binary")) return "fbx";
  if (at("PK\x03\x04")) return bytes.toString("latin1").toLowerCase().includes("3d/3dmodel.model") ? "3mf" : "";
  if (at("ply\n") || at("ply\r\n")) return "ply";
  // A binary STL: an 80-byte header, its triangles' count, 50 bytes each.
  if (bytes.length >= 134 && bytes.length === 84 + 50 * bytes.readUInt32LE(80)) return "stl";
  const bin = /\.bin$/i.test(path);
  if (bytes.subarray(0, 8192).includes(0)) return bin ? "bin" : "";
  const text = bytes.toString("utf8").replace(/^﻿/, "");
  if (/^\s*solid\b/.test(text) && /\bfacet\s+normal\b/.test(text)) return "stl";
  if (/^\s*; FBX/.test(text) && text.includes("FBXHeaderExtension")) return "fbx";
  const markup = text.replace(/^\s*(<\?xml[^>]*\?>\s*)?((<!--[\s\S]*?-->|<!DOCTYPE[^>]*>)\s*)*/i, "");
  if (/^<svg[\s>]/i.test(markup)) return "svg";
  if (/^\s*\{/.test(text)) {
    try {
      const json = JSON.parse(text);
      if (json && typeof json.asset === "object") return "gltf";
    } catch {}
  }
  if (/^newmtl\s/m.test(text)) return "mtl";
  if (/^v\s+[-+.\d]/m.test(text) && /^f\s+[-\d]/m.test(text)) return "obj";
  return bin ? "bin" : "";
}

/// Whether [bytes] are a web page: what a link to a file's page, rather
/// than the file, brings.
function isPage(bytes) {
  return /^\s*(<!doctype html|<html|<head|<body)/i.test(bytes.subarray(0, 1024).toString("utf8").replace(/^﻿/, ""));
}

/// [raw] read as a link that may be fetched: a URL, or a LinkRefusal.
function linkOf(raw) {
  const text = String(raw ?? "").trim();
  if (!text) throw new LinkRefusal(400, "no_link", "Give the link: url= the whole address, starting https://.");
  if (text.length > LONGEST) throw new LinkRefusal(400, "long", `That link is ${text.length} characters; `
    + `Brickworks fetches links of up to ${LONGEST}.`);
  let link;
  try {
    link = new URL(text);
  } catch {
    throw new LinkRefusal(400, "unreadable", "That is not a link Brickworks can read: give the whole address, "
      + "starting https://.");
  }
  return checked(link, null);
}

/// [link] if it may be fetched, as the first or a later hop ([from], the
/// host that sent Brickworks there); otherwise a LinkRefusal.
function checked(link, from) {
  const scheme = link.protocol.replace(/:$/, "");
  if (scheme !== "http" && scheme !== "https") {
    throw new LinkRefusal(400, "scheme", from
      ? `${from} sent Brickworks on to a link that is not http or https (${scheme}), so nothing was fetched.`
      : `Only an http or https link can be fetched, and that one is ${scheme}.`);
  }
  if (link.username || link.password) {
    throw new LinkRefusal(400, "credentials", `${from ? `${from} sent Brickworks on to a link` : "That link"} with a `
      + "name and password in it, which Brickworks does not send. Give a link anyone can open.");
  }
  const port = Number(link.port || (scheme === "https" ? 443 : 80));
  if (!PORTS.includes(port)) {
    throw new LinkRefusal(400, "port", `${from ? `${from} sent Brickworks on to` : "That link asks for"} port ${port}; `
      + "Brickworks fetches from the web's usual ports, 80 and 443 (and 8080 and 8443).");
  }
  return link;
}

/// Every address of [host], checked: [{address, family}], or a LinkRefusal.
async function addressesOf(host, resolve, from) {
  const bare = host.replace(/^\[|\]$/g, "");
  let found;
  if (isIP(bare)) {
    found = [{ address: bare, family: isIP(bare) }];
  } else {
    try {
      found = await resolve(bare);
    } catch (trouble) {
      if (["ENOTFOUND", "ENODATA", "EAI_NONAME"].includes(trouble?.code)) {
        throw new LinkRefusal(502, "no_host", `There is no site called ${bare}: check the link.`);
      }
      throw new LinkRefusal(502, "dns", `Brickworks could not look up ${bare} just now. Try again in a minute.`);
    }
  }
  if (!found.length) throw new LinkRefusal(502, "no_host", `There is no site called ${bare}: check the link.`);
  if (found.some((one) => isNear(one.address))) {
    throw new LinkRefusal(403, "private", from
      ? `That link sent Brickworks on to ${bare}, which is on a private network, so nothing was fetched.`
      : `${bare} is on a private network, which Brickworks does not fetch from. Give a link on the open web.`);
  }
  return found;
}

const systemResolve = (host) => lookup(host, { all: true, verbatim: true });

/// One request to [link], made to [address] (already checked) with the
/// host's own name in Host and the certificate's check: its response.
function ask(link, address, port, signal) {
  const host = link.hostname.replace(/^\[|\]$/g, "");
  const transport = link.protocol === "https:" ? https : http;
  return new Promise((done, fail) => {
    const request = transport.request({
      host: address,
      port,
      path: `${link.pathname}${link.search}`,
      method: "GET",
      headers: {
        host: link.host,
        "user-agent": AGENT,
        accept: "image/*, model/*, application/octet-stream;q=0.9, */*;q=0.5",
        "accept-encoding": "gzip, deflate, br",
      },
      servername: isIP(host) ? undefined : host,
      agent: false,
      signal,
    }, done);
    request.on("error", fail);
    request.end();
  });
}

/// The body of [answer], unpacked, at most [most] bytes: a Buffer, or a
/// LinkRefusal.
async function bodyOf(answer, most) {
  const packed = String(answer.headers["content-encoding"] || "").trim().toLowerCase();
  const unpack = { gzip: zlib.createGunzip, "x-gzip": zlib.createGunzip, deflate: zlib.createInflate,
    br: zlib.createBrotliDecompress }[packed];
  const stream = unpack ? answer.pipe(unpack()) : answer;
  if (unpack) answer.on("error", (trouble) => stream.destroy(trouble));
  const parts = [];
  let size = 0;
  for await (const part of stream) {
    size += part.length;
    if (size > most) {
      answer.destroy();
      stream.destroy();
      throw new LinkRefusal(413, "too_large", `That file is more than ${sizeWords(most)}, the most Brickworks can `
        + "bring in from a link. Save it to your computer and bring it in from there instead.");
    }
    parts.push(part);
  }
  return Buffer.concat(parts);
}

/// Why [trouble], thrown by a request to [host], fetched nothing: a
/// LinkRefusal in words.
function troubleWords(trouble, host, answered, late, seconds) {
  if (trouble instanceof LinkRefusal) return trouble;
  const code = String(trouble?.code || trouble?.cause?.code || "");
  if (late || trouble?.name === "AbortError" || code === "ABORT_ERR") {
    return answered
      ? new LinkRefusal(504, "slow", `${host} was still sending the file after ${seconds} s. Save it to your computer `
        + "and bring it in from there instead.")
      : new LinkRefusal(504, "timeout", `${host} didn't answer within ${seconds} s. Try again later.`);
  }
  if (code === "ECONNREFUSED") {
    return new LinkRefusal(502, "refused", `${host} would not take a connection: the site may be down. Try again `
      + "later, or check the link.");
  }
  if (code === "ECONNRESET" || code === "EPIPE" || code === "ERR_STREAM_PREMATURE_CLOSE") {
    return new LinkRefusal(502, "reset", `${host} broke off the connection before the file came. Try again.`);
  }
  if (/CERT|SSL|TLS|SELF_SIGNED|UNABLE_TO_VERIFY/.test(code)) {
    return new LinkRefusal(502, "certificate", `${host}'s certificate could not be trusted, so Brickworks did not `
      + "fetch from it.");
  }
  if (/^Z_|^ERR__ERROR/.test(code)) {
    return new LinkRefusal(502, "unpack", `${host} sent the file packed in a way that could not be unpacked.`);
  }
  return new LinkRefusal(502, "network", `Brickworks could not fetch from ${host}: the connection failed. Try again `
    + "later.");
}

/// The words for [status] from [host], which is not the file.
function statusWords(status, host) {
  if (status === 404 || status === 410) {
    return new LinkRefusal(502, "not_found", `${host} says there is no file at that link (${status} Not Found). Check `
      + "the link.");
  }
  if (status === 401 || status === 403) {
    return new LinkRefusal(502, "forbidden", `${host} would not hand the file over (${status} ${status === 401
      ? "Unauthorized" : "Forbidden"}): it may want you signed in there. Save it to your computer and bring it in `
      + "from there instead.");
  }
  if (status === 429) {
    return new LinkRefusal(502, "busy", `${host} is turning requests away just now (429 Too Many Requests). Try again `
      + "in a few minutes.");
  }
  if (status >= 500) return new LinkRefusal(502, "site_error", `${host} had a problem of its own (${status}). Try again later.`);
  return new LinkRefusal(502, "status", `${host} answered ${status}, not the file.`);
}

/// The file at [raw], a link: {bytes, kind, host}, or a LinkRefusal.
/// [resolve] (a host's addresses) and [dial] (where a checked address is
/// connected to) are the system's but in a test, which serves the files
/// itself under made-up names.
export async function fetchLink(raw, { resolve = systemResolve, dial = (address, port) => [address, port],
  seconds = SECONDS, most = MOST } = {}) {
  let link = linkOf(raw);
  const deadline = new AbortController();
  const timer = setTimeout(() => deadline.abort(), seconds * 1000);
  let host = link.hostname;
  let answered = false;
  try {
    for (let hop = 0; ; hop++) {
      host = link.hostname.replace(/^\[|\]$/g, "");
      const [first] = await addressesOf(link.hostname, resolve, hop > 0);
      const [address, port] = dial(first.address, Number(link.port || (link.protocol === "https:" ? 443 : 80)));
      const answer = await ask(link, address, port, deadline.signal);
      const status = answer.statusCode || 0;
      if ([301, 302, 303, 307, 308].includes(status) && answer.headers.location) {
        answer.resume();
        if (hop + 1 > HOPS) {
          throw new LinkRefusal(502, "hops", `That link sent Brickworks on more than ${HOPS} times without reaching `
            + "the file.");
        }
        let next;
        try {
          next = new URL(String(answer.headers.location), link);
        } catch {
          throw new LinkRefusal(502, "redirect", `${host} sent Brickworks on to an address that is not a link.`);
        }
        link = checked(next, host);
        continue;
      }
      if (status !== 200) {
        answer.resume();
        throw statusWords(status, host);
      }
      answered = true;
      const told = Number(answer.headers["content-length"] || 0);
      if (told > most && !answer.headers["content-encoding"]) {
        answer.destroy();
        throw new LinkRefusal(413, "too_large", TOO_LARGE(sizeWords(told)));
      }
      const bytes = await bodyOf(answer, most);
      if (!bytes.length) throw new LinkRefusal(415, "empty", `${host} sent an empty file.`);
      const kind = kindOf(bytes, link.pathname);
      if (!kind) {
        throw new LinkRefusal(415, isPage(bytes) ? "page" : "kind", isPage(bytes)
          ? "That link is a web page, not the file itself. Open it, and give the link to the picture or model on it "
            + "(on Wikimedia, the Original file link)."
          : `That link is not ${KINDS_WORDS}, so Brickworks did not bring it in.`);
      }
      return { bytes, kind, host };
    }
  } catch (trouble) {
    throw troubleWords(trouble, host, answered, deadline.signal.aborted, seconds);
  } finally {
    clearTimeout(timer);
  }
}

/// POST /api/account?op=fetch: the file at {url} for whoever is signed in.
/// [options] as fetchLink's, for a test.
export async function linkFetch(request, response, options = {}) {
  const refuse = (status, why, said) => response.status(status).json({ error: said, why });
  if (request.method !== "POST") return refuse(405, "method", "POST {url}, signed in.");
  let claims;
  try {
    claims = await verify(bearer(request), request);
  } catch (trouble) {
    if (!(trouble instanceof AuthError)) throw trouble;
    return refuse(trouble.status || 401, "signed_out", bearer(request)
      ? `Sign in to Brickworks again to bring in a link: ${trouble.message}.`
      : "Sign in to Brickworks to bring in a picture or a model from a link.");
  }
  if (!dbConfigured()) return refuse(503, "unready", "This deployment of Brickworks cannot fetch links.");
  let allowed;
  try {
    allowed = await db("rpc/may_act", { method: "POST", body: { actor: claims.sub, act: "fetch_link",
      per_hour: LIMITS[0], per_day: LIMITS[1] } });
  } catch (trouble) {
    console.error(`link: may_act: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return refuse(503, "unready", "Brickworks could not fetch links just now. Try again in a minute.");
  }
  if (allowed !== true) {
    return refuse(429, "rate", `That is a lot of links in a short time: Brickworks fetches up to ${LIMITS[0]} an hour `
      + `and ${LIMITS[1]} a day for an account. Try again later, or bring the file in from your computer.`);
  }
  const body = request.body && typeof request.body === "object" ? request.body : {};
  let host = "";
  try {
    host = new URL(String(body.url || "")).hostname;
  } catch {}
  try {
    const got = await fetchLink(body.url, options);
    console.log(`link: ${got.host} ${got.kind} ${got.bytes.length} B`);
    response.setHeader("content-type", "application/octet-stream");
    response.setHeader("content-disposition", "attachment");
    response.setHeader("x-content-type-options", "nosniff");
    response.setHeader("content-security-policy", "default-src 'none'; sandbox");
    response.setHeader("cache-control", "private, no-store");
    response.setHeader("x-link-kind", got.kind);
    return response.status(200).end(got.bytes);
  } catch (trouble) {
    if (!(trouble instanceof LinkRefusal)) throw trouble;
    console.log(`link: ${host || "?"} refused (${trouble.why})`);
    return refuse(trouble.status, trouble.why, trouble.message);
  }
}
