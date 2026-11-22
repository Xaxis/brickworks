// Push: what happens to your work reaches your phone or computer as the
// system's own notification, within the minute, on each device you turned
// it on for (homescreen, 2026-11-22; docs/SOCIAL.md, the units' rank 4).
//
// A device is a browser's push subscription (web/push.js asks for one,
// only after the person turns Notifications › On this device on in
// Settings and the browser's own prompt says yes): its endpoint at the
// browser's push service and its two keys. Kept in push_subscriptions
// (supabase/push.sql), one row a device, deleted with the account.
//
//   GET  /api/people?op=push[&endpoint=]    {ready, key, on}: whether this
//        deployment can push (its key, VAPID_PRIVATE_KEY, and the file
//        applied), the public key a browser subscribes with, and, signed in
//        with the device's endpoint, whether it is on for this account.
//   POST /api/people?op=push                signed in, {on, endpoint, p256dh,
//        auth, lang}: this device on (or off) for this account. An endpoint
//        another account had moves to this one: a device is one person's.
//   POST /api/people?op=push_send          the knock: what is due goes. No
//        secret, as people?op=digest: it can send nothing but notifications
//        that are really there, each once, to the devices of the person
//        they are for.
//
// What goes: a new row of the person's notifications (notification_rows,
// the page's own, so every rule of what is shown holds: nothing hidden,
// removed, by an account under 13, by somebody they blocked) of the kinds
// somebody did to them: a comment or a reply, a mention, a photo of a
// build of their model, a remix, a challenge's result. Not a like (a count
// a day on the page), a level reached, a challenge opening or the owner's
// announcements: those wait for the page (the inbox unit gives each kind
// its own choice). Each row once (push_sent), only rows newer than the
// device's turning on, and none older than half an hour.
//
// When: the database marks the person due as the row is written (push.sql's
// triggers on comments, mentions, build photos, remixes and a challenge
// settled) and knocks on brickworks.diy (pg_net), so it goes in a second or
// two; pg_cron knocks each minute while anybody is due, in case a knock was
// lost. A comment or a reply made here also sends what is due as soon as it
// is answered (api/_comments.js), on whichever deployment it was made.
//
// How: Web Push (RFC 8030), its message encrypted for the device (RFC 8291,
// aes128gcm) and the request signed with this site's key (VAPID, RFC 8292),
// all with node:crypto: the API has no npm dependencies. Only the push
// services the browsers use are ever sent to (PUSH_HOSTS): an endpoint is
// the browser's, never somewhere a person names. A device the service says
// is gone (404, 410) is deleted at its first such answer.

import { createCipheriv, createECDH, createHmac, createPrivateKey, randomBytes, sign } from "node:crypto";
import { bearer, verify } from "./_auth.js";
import { db, dbConfigured, reach } from "./_db.js";
import { SITE_LANGS, Unacceptable, inLanguage, siteWords } from "./_directory.js";
import { noticeSaid } from "./_notifications.js";
import { blockedHandles, blockedModels, rowsWithout } from "./_blocks.js";

/// The kinds of notification that are pushed.
export const KINDS = ["comment", "reply", "mention", "photo", "remix", "result"];
/// Who a push says it is from: the site, never an email address.
const SUBJECT = "https://brickworks.diy";
/// How long a push service keeps one for a device that is off: a day.
const TTL = 86400;
/// A message's words, at most: the service takes 4,096 bytes encrypted.
const MOST_BYTES = 3000;
/// At most this many pushes a device a knock: the newest.
const MOST_A_DEVICE = 5;
/// The push services of Chrome, Edge, Firefox and Safari, by host.
export const PUSH_HOSTS = [/^fcm\.googleapis\.com$/, /^android\.googleapis\.com$/,
  /^updates\.push\.services\.mozilla\.com$/, /^[a-z0-9-]+\.push\.services\.mozilla\.com$/,
  /^[a-z0-9-]+\.notify\.windows\.com$/, /^web\.push\.apple\.com$/, /^[a-z0-9-]+\.push\.apple\.com$/];
const KEY64 = /^[A-Za-z0-9_-]+={0,2}$/;
const NOT_THERE = /: 404$/;

export const NOT_YET = "Notifications on this device are not open on Brickworks yet.";

const b64u = (bytes) => Buffer.from(bytes).toString("base64url");
const unb64u = (text) => Buffer.from(String(text || ""), "base64url");
const hmac = (key, data) => createHmac("sha256", key).update(data).digest();

/// An rpc, or [missing]'s answer when push.sql is not applied.
async function call(name, body, missing) {
  try {
    return await db(`rpc/${name}`, { method: "POST", body });
  } catch (trouble) {
    if (NOT_THERE.test(String(trouble?.message || "")) && missing !== undefined) return missing();
    throw trouble;
  }
}

// ---------------------------------------------------------------------------
// The message, encrypted for one device (RFC 8291).

/// [payload] (a string or bytes) as one aes128gcm record for the device
/// whose keys are [p256dh] (its P-256 public key, 65 bytes) and [auth] (16
/// bytes), both base64url. [salt] and [serverKey] (a private key, 32 bytes)
/// are fresh each time unless a test gives them.
export function encrypt(payload, { p256dh, auth }, { salt = randomBytes(16), serverKey = null } = {}) {
  const device = unb64u(p256dh);
  const secret = unb64u(auth);
  if (device.length !== 65 || device[0] !== 4) throw new Error("push: the device's key is not a P-256 point");
  if (secret.length !== 16) throw new Error("push: the device's auth secret is not 16 bytes");
  const ecdh = createECDH("prime256v1");
  if (serverKey) ecdh.setPrivateKey(Buffer.from(serverKey));
  else ecdh.generateKeys();
  const ours = ecdh.getPublicKey();
  const shared = ecdh.computeSecret(device);
  // HKDF, its one block written out: extract then expand.
  const ikm = hmac(hmac(secret, shared), Buffer.concat([Buffer.from("WebPush: info\0"), device, ours, Buffer.from([1])]));
  const prk = hmac(salt, ikm);
  const cek = hmac(prk, Buffer.from("Content-Encoding: aes128gcm\0\x01")).subarray(0, 16);
  const nonce = hmac(prk, Buffer.from("Content-Encoding: nonce\0\x01")).subarray(0, 12);
  const cipher = createCipheriv("aes-128-gcm", cek, nonce);
  // The last (and only) record ends with 2.
  const sealed = Buffer.concat([cipher.update(Buffer.concat([Buffer.from(payload), Buffer.from([2])])), cipher.final(),
    cipher.getAuthTag()]);
  const head = Buffer.alloc(21);
  Buffer.from(salt).copy(head, 0);
  head.writeUInt32BE(4096, 16);
  head[20] = ours.length;
  return Buffer.concat([head, ours, sealed]);
}

// ---------------------------------------------------------------------------
// This site's key (VAPID, RFC 8292).

let keyMemo = null;

/// This deployment's VAPID key from VAPID_PRIVATE_KEY (its 32 bytes,
/// base64url): {publicKey (base64url, 65 bytes), privateKey (a KeyObject)},
/// or null when there is none, or it is not a P-256 key.
export function vapid() {
  const d = String(process.env.VAPID_PRIVATE_KEY || "").trim();
  if (!d) return null;
  if (keyMemo && keyMemo.d === d) return keyMemo.key;
  let key = null;
  try {
    const ecdh = createECDH("prime256v1");
    ecdh.setPrivateKey(unb64u(d));
    const point = ecdh.getPublicKey();
    const privateKey = createPrivateKey({ format: "jwk", key: { kty: "EC", crv: "P-256", d,
      x: b64u(point.subarray(1, 33)), y: b64u(point.subarray(33, 65)) } });
    key = { publicKey: b64u(point), privateKey };
  } catch {
    console.error("push: VAPID_PRIVATE_KEY is not a P-256 private key; nothing is pushed");
  }
  keyMemo = { d, key };
  return key;
}

/// The Authorization header for a push to [endpoint], signed with [key]
/// (vapid()), good for 12 hours from [now].
export function vapidHeader(endpoint, key, now = Date.now()) {
  const head = b64u(JSON.stringify({ typ: "JWT", alg: "ES256" }));
  const claims = b64u(JSON.stringify({ aud: new URL(endpoint).origin, exp: Math.floor(now / 1000) + 12 * 3600,
    sub: SUBJECT }));
  const signed = sign("sha256", Buffer.from(`${head}.${claims}`), { key: key.privateKey, dsaEncoding: "ieee-p1363" });
  return `vapid t=${head}.${claims}.${b64u(signed)}, k=${key.publicKey}`;
}

// ---------------------------------------------------------------------------
// A device, as a page hands it over: checked here, at the edge.

/// [given] ({endpoint, p256dh, auth}) as a device, or a reason it is not one.
export function deviceOf(given) {
  const endpoint = String(given?.endpoint || "");
  let url = null;
  try {
    url = new URL(endpoint);
  } catch {
    return { trouble: "endpoint is the browser's push subscription's endpoint" };
  }
  if (url.protocol !== "https:" || url.username || url.password || url.port || endpoint.length > 1000
      || !PUSH_HOSTS.some((host) => host.test(url.hostname))) {
    return { trouble: "endpoint is not a browser's push service" };
  }
  const p256dh = String(given?.p256dh || "");
  const auth = String(given?.auth || "");
  if (!KEY64.test(p256dh) || unb64u(p256dh).length !== 65 || unb64u(p256dh)[0] !== 4) {
    return { trouble: "p256dh is the subscription's p256dh key, base64url" };
  }
  if (!KEY64.test(auth) || unb64u(auth).length !== 16) return { trouble: "auth is the subscription's auth key, base64url" };
  return { endpoint, p256dh, auth };
}

/// Where [request] was made, as links in a push to a device turned on there
/// open it: brickworks.diy, or a deployment of this project.
export function originHere(request) {
  const headers = request?.headers || {};
  const host = String(headers["x-forwarded-host"] || headers.host || "").split(",")[0].trim().toLowerCase();
  if (/^(?:www\.)?brickworks\.diy$/.test(host)) return "https://brickworks.diy";
  if (/^[a-z0-9-]{1,80}\.vercel\.app$/.test(host)) return `https://${host}`;
  if (/^(?:127\.0\.0\.1|localhost):\d{1,5}$/.test(host)) return `http://${host}`;
  return "https://brickworks.diy";
}

// ---------------------------------------------------------------------------
// What a push says.

/// The notification [row] (a row of notification_rows, flattened as the
/// page's list has it) as the push to a device that reads [lang], its links
/// at [origin]: {title, body, url, tag}. The model's name over who did what,
/// the words they wrote under it: the page's own sentences (noticeSaid).
export function pushSaid(row, lang = "en", origin = "https://brickworks.diy") {
  const code = SITE_LANGS.includes(lang) ? lang : "en";
  return inLanguage(code, siteWords(code), () => {
    const said = noticeSaid(row, origin);
    const line = String(said.line || "").replace("{who}", said.who || "");
    const name = String((row.kind === "remix" ? row.of_name : row.name) || "Brickworks").slice(0, 80);
    const model = String(row.kind === "remix" ? row.of || row.model || "" : row.model || "");
    return { title: name, body: [line, said.said].filter(Boolean).join("\n").slice(0, 600), url: said.link,
      tag: model ? `model-${model}` : `kind-${row.kind}` };
  });
}

// ---------------------------------------------------------------------------
// Sending.

/// [message] ({title, body, url, tag}) pushed to [device] ({endpoint,
/// p256dh, auth}) with [key]: the service's status, or 0 not reached.
export async function deliver(device, message, key, { topic = "" } = {}) {
  let text = JSON.stringify(message);
  if (Buffer.byteLength(text) > MOST_BYTES) text = JSON.stringify({ ...message, body: String(message.body).slice(0, 200) });
  const headers = {
    TTL: String(TTL),
    Urgency: "normal",
    "Content-Encoding": "aes128gcm",
    "Content-Type": "application/octet-stream",
    Authorization: vapidHeader(device.endpoint, key),
  };
  // One waiting a model, at the service, for a device that is off.
  if (/^[A-Za-z0-9_-]{1,32}$/.test(topic)) headers.Topic = topic;
  try {
    const answer = await reach("push POST", 10, device.endpoint, { method: "POST", headers, body: encrypt(text, device) });
    await answer.arrayBuffer().catch(() => null);
    return answer.status;
  } catch (trouble) {
    console.error(`push: ${String(trouble?.message || trouble).slice(0, 120)}`);
    return 0;
  }
}

/// What is due, sent: the accounts marked due (at most [most]), each one's
/// new rows to each of its devices. {accounts, sent, gone, failed}.
export async function sendDue({ most = 25 } = {}) {
  const tally = { accounts: 0, sent: 0, gone: 0, failed: 0 };
  const key = vapid();
  if (!key || !dbConfigured()) return tally;
  const taken = await call("push_take", { p_most: most }, () => []);
  for (const due of Array.isArray(taken) ? taken : []) {
    tally.accounts += 1;
    const rows = (due.rows || []).filter((row) => KINDS.includes(row?.kind));
    if (!rows.length || !(due.devices || []).length) continue;
    // Nothing by somebody they blocked, nor about a model of theirs.
    const handles = await blockedHandles(due.account).catch(() => new Set());
    const gone = handles.size ? await blockedModels(due.account, rows.map((row) => row.model)).catch(() => new Set()) : new Set();
    const shown = rowsWithout(rows, handles, gone).sort((a, b) => Date.parse(b.at) - Date.parse(a.at));
    await Promise.all((due.devices || []).map(async (device) => {
      const after = Date.parse(device.made_at) || 0;
      const fresh = shown.filter((row) => Date.parse(row.at) > after).slice(0, MOST_A_DEVICE);
      for (const row of fresh) {
        const status = await deliver(device, pushSaid(row, device.lang, device.origin), key, { topic: `m-${row.model || row.kind}` });
        if (status >= 200 && status < 300) {
          tally.sent += 1;
        } else if (status === 404 || status === 410) {
          // Gone: the browser unsubscribed, or the person took the permission back.
          tally.gone += 1;
          await call("push_gone", { p_endpoint: device.endpoint }, () => null).catch(() => null);
          return;
        } else {
          tally.failed += 1;
          console.error(`push: the service answered ${status}`);
        }
      }
    }));
  }
  return tally;
}

// ---------------------------------------------------------------------------
// The requests.

const ready = () => Boolean(vapid() && dbConfigured());

/// GET ?op=push: {ready, key, on}.
export async function pushState(request, response) {
  response.setHeader("Cache-Control", "private, no-store");
  const key = vapid();
  const base = { ready: ready(), key: key ? key.publicKey : null, on: false };
  const token = bearer(request);
  const endpoint = String(request.query?.endpoint || "");
  if (!base.ready || !token) return response.status(200).json(base);
  const claims = await verify(token, request);
  const said = await call("push_subscribed", { p_account: claims.sub, p_endpoint: endpoint.slice(0, 1000) },
    () => ({ missing: true }));
  if (said?.missing) return response.status(200).json({ ...base, ready: false });
  return response.status(200).json({ ...base, on: said?.on === true, devices: Number(said?.devices) || 0 });
}

/// POST ?op=push, signed in: this device on or off for this account.
export async function pushChoose(request, response) {
  response.setHeader("Cache-Control", "no-store");
  const claims = await verify(bearer(request), request);
  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      body = {};
    }
  }
  body = body && typeof body === "object" ? body : {};
  if (typeof body.on !== "boolean") throw new Unacceptable("say on: true or on: false");
  if (!ready()) throw new Unacceptable(NOT_YET, 503);
  if (!body.on) {
    const endpoint = String(body.endpoint || "").slice(0, 1000);
    if (!endpoint) throw new Unacceptable("endpoint is the browser's push subscription's endpoint");
    const said = await call("push_unsubscribe", { p_account: claims.sub, p_endpoint: endpoint }, () => null);
    if (!said) throw new Unacceptable(NOT_YET, 503);
    return response.status(200).json({ on: false, devices: Number(said.devices) || 0 });
  }
  const device = deviceOf(body);
  if (device.trouble) throw new Unacceptable(device.trouble);
  const lang = SITE_LANGS.includes(String(body.lang || "")) ? String(body.lang) : "en";
  const said = await call("push_subscribe", { p_account: claims.sub, p_endpoint: device.endpoint, p_p256dh: device.p256dh,
    p_auth: device.auth, p_origin: originHere(request), p_lang: lang }, () => null);
  if (!said) throw new Unacceptable(NOT_YET, 503);
  return response.status(200).json({ on: true, devices: Number(said.devices) || 0 });
}

/// POST ?op=push_send: the knock (push.sql's, or pg_cron's).
export async function pushSend(request, response) {
  response.setHeader("Cache-Control", "no-store");
  return response.status(200).json(await sendDue());
}
