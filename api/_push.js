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
//        auth, lang}: this device on (or off) for this account, tied to the
//        sign-in it was turned on with (it goes when that ends). An endpoint
//        another account had moves to this one: a device is one person's.
//        Signed in, {on: false, all: true}: every device of the account off.
//        Signed in or not, {on: false, endpoint, auth}: the device with that
//        endpoint and secret forgotten (a browser signing out, web/account.js:
//        only it knows the secret).
//   POST /api/people?op=push_send          the knock: what is due goes, 204
//        with nothing said. Only at brickworks.diy (S1, hsfix): every
//        deployment is a production one with the key, and a preview's take
//        would send real people's pushes with its branch's code. Anywhere
//        else it takes only what is due to a check's own account (a Resend
//        test address) the knock is signed in as, and brickworks.diy's take
//        leaves those alone (supabase/push_2.sql push_take_tester): so a
//        preview's flow proves push end to end with its own code, knocking as
//        the throwaway who is due, and never touches the live queue.
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
// two; pg_cron's minute (push_2.sql push_sweep) knocks while anybody is due,
// in case a knock was lost. A model is pushed to a device at most once in
// three minutes: what comes meanwhile goes as one push that says how many.
//
// Never unfiltered, and at most three tries more: a block list that cannot
// be read, or a push service answering 5xx or 429 (or not at all), puts what
// was not delivered back (push_again), due again a minute later, then two,
// then three, then dropped. A function cut off mid-send loses what it took:
// delivery is at most once.
//
// How: Web Push (RFC 8030), its message encrypted for the device (RFC 8291,
// aes128gcm) and the request signed with this site's key (VAPID, RFC 8292),
// all with node:crypto: the API has no npm dependencies. Only the push
// services the browsers use are ever sent to (PUSH_HOSTS): an endpoint is
// the browser's, never somewhere a person names. A device the service says
// is gone (404, 410) is deleted at its first such answer.

import { createCipheriv, createECDH, createHmac, createPrivateKey, randomBytes, sign } from "node:crypto";
import { AuthError, bearer, isTestAccount, verify } from "./_auth.js";
import { db, dbConfigured, reach } from "./_db.js";
import { SITE_LANGS, Unacceptable, inLanguage, siteWords } from "./_directory.js";
import { PINNABLE, noticeSaid } from "./_notifications.js";
import { pinnedAmong } from "./_comments.js";
import { blockedHandles, blockedModels, rowsWithout } from "./_blocks.js";
import { say } from "./_card.js";

/// The kinds of notification that are pushed (Talk's since talk.sql).
export const KINDS = ["comment", "reply", "mention", "photo", "remix", "result", "talk_reply", "talk_mention"];
const TALK = new Set(["talk_reply", "talk_mention"]);
/// Who a push says it is from: the site, never an email address.
const SUBJECT = "https://brickworks.diy";
/// How long a push service keeps one for a device that is off: a day.
const TTL = 86400;
/// A message's words, at most: the service takes 4,096 bytes encrypted.
const MOST_BYTES = 3000;
/// At most this many pushes a device a knock, a model each: the newest.
const MOST_A_DEVICE = 5;
/// The one address whose knock takes what is due to people.
const LIVE = /^(?:www\.)?brickworks\.diy$/;
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
/// [more]: how many others came with it, about the same model, said under it.
export function pushSaid(row, lang = "en", origin = "https://brickworks.diy", more = 0) {
  const code = SITE_LANGS.includes(lang) ? lang : "en";
  return inLanguage(code, siteWords(code), () => {
    const said = noticeSaid(row, origin);
    const line = String(said.line || "").replace("{who}", said.who || "");
    // A thread of Talk is named as Notifications names it, one push a thread.
    const thread = TALK.has(row.kind) ? Number(row.thread) || 0 : 0;
    const name = String((row.kind === "remix" ? row.of_name : thread ? say("Talk: {title}", { title: row.title || "" }) : row.name)
      || "Brickworks").slice(0, 80);
    const model = String(row.kind === "remix" ? row.of || row.model || "" : row.model || "");
    const others = more > 0 ? say("{n} more on its page", { n: more }) : "";
    return { title: name, body: [line, said.said, others].filter(Boolean).join("\n").slice(0, 600), url: said.link,
      tag: model ? `model-${model}` : thread ? `talk-${thread}` : `kind-${row.kind}` };
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

/// Whether [request] came to brickworks.diy itself: its host, as Vercel
/// hands it on, and nothing else said.
export function live(request) {
  const headers = request?.headers || {};
  const hosts = [headers.host, headers["x-forwarded-host"]].filter(Boolean)
    .map((one) => String(one).split(",")[0].trim().toLowerCase());
  return hosts.length > 0 && hosts.every((host) => LIVE.test(host));
}

/// What is due, sent ([request]: the knock): at brickworks.diy, the
/// accounts marked due (at most [most]); anywhere else, only a check's own
/// account the knock is signed in as. Each device's new rows, a push a
/// model: {accounts, sent, gone, failed, again}.
export async function sendDue(request, { most = 25 } = {}) {
  const tally = { accounts: 0, sent: 0, gone: 0, failed: 0, again: 0 };
  const key = vapid();
  if (!key || !dbConfigured()) return tally;
  let taken;
  if (live(request)) {
    taken = await call("push_take", { p_most: most }, () => []);
  } else {
    const claims = await verify(bearer(request), request).catch(() => null);
    if (!claims || !isTestAccount(claims)) return tally;
    taken = await call("push_take_tester", { p_account: claims.sub }, () => []);
  }
  for (const due of Array.isArray(taken) ? taken : []) {
    tally.accounts += 1;
    const tries = Number(due.tries) || 0;
    const devices = (due.devices || []).map((device) => ({ ...device,
      rows: (Array.isArray(device.rows) ? device.rows : []).filter((row) => KINDS.includes(row?.kind)) }))
      .filter((device) => device.rows.length);
    const keysOf = (rows) => rows.flatMap((row) => [row.key, row.last]).filter(Boolean);
    // Put back, to be tried again (bounded in push_again), never sent as it is.
    const again = async (rows) => {
      tally.again += rows.length;
      await call("push_again", { p_account: due.account, p_keys: keysOf(rows), p_tries: tries }, () => null)
        .catch((trouble) => console.error(`push: not put back: ${String(trouble?.message || trouble).slice(0, 120)}`));
    };
    const all = devices.flatMap((device) => device.rows);
    // Nothing by somebody they blocked, nor about a model of theirs; and
    // nothing at all while that cannot be read.
    let handles;
    let hidden;
    try {
      handles = await blockedHandles(due.account);
      hidden = handles.size ? await blockedModels(due.account, all.map((row) => row.model)) : new Set();
    } catch (trouble) {
      console.error(`push: a block list not read, nothing sent: ${String(trouble?.message || trouble).slice(0, 120)}`);
      await again(all);
      continue;
    }
    // A comment on a part says so, as Notifications does.
    await pinnedAmong(all.filter((row) => PINNABLE.has(row?.kind)));
    await Promise.all(devices.map(async (device) => {
      const shown = new Set(rowsWithout(device.rows, handles, hidden));
      // A push a model, its newest row's words, with how many came with it.
      const models = new Map();
      for (const row of [...device.rows].sort((a, b) => Date.parse(b.at) - Date.parse(a.at))) {
        const one = models.get(row.last || row.key) || { rows: [], shown: [] };
        one.rows.push(row);
        if (shown.has(row)) one.shown.push(row);
        models.set(row.last || row.key, one);
      }
      const said = [...models.values()].filter((one) => one.shown.length);
      const groups = said.slice(0, MOST_A_DEVICE);
      // More models than a knock pushes a device: the rest a minute on.
      if (said.length > groups.length) await again(said.slice(MOST_A_DEVICE).flatMap((one) => one.rows));
      for (const [n, group] of groups.entries()) {
        const [newest] = group.shown;
        const status = await deliver(device, pushSaid(newest, device.lang, device.origin, group.shown.length - 1), key,
          { topic: `m-${newest.model || newest.kind}` });
        if (status >= 200 && status < 300) {
          tally.sent += 1;
        } else if (status === 404 || status === 410) {
          // Gone: the browser unsubscribed, or the person took the permission back.
          tally.gone += 1;
          await call("push_gone", { p_endpoint: device.endpoint }, () => null).catch(() => null);
          return;
        } else if (status === 0 || status === 429 || status >= 500) {
          // Not now: this group and the rest of this device's, again later.
          tally.failed += 1;
          console.error(`push: the service answered ${status}; tried again later`);
          await again(groups.slice(n).flatMap((one) => one.rows));
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

/// POST ?op=push: this device on or off for the account signed in; every
/// device of it off; or, signed in or not, a device forgotten by its
/// endpoint and secret.
export async function pushChoose(request, response) {
  response.setHeader("Cache-Control", "no-store");
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
  // A browser signing out: its device forgotten, whoever is signed in (or
  // nobody, a sign-in that has just ended). The secret is the proof.
  if (body.on === false && typeof body.auth === "string" && !bearer(request)) {
    const endpoint = String(body.endpoint || "").slice(0, 1000);
    if (!endpoint || !KEY64.test(body.auth)) throw new Unacceptable("endpoint and auth are the device's");
    if (!dbConfigured()) return response.status(204).end();
    await call("push_forget", { p_endpoint: endpoint, p_auth: body.auth }, () => null);
    return response.status(204).end();
  }
  const claims = await verify(bearer(request), request);
  if (!ready()) throw new Unacceptable(NOT_YET, 503);
  if (body.on === false && body.all === true) {
    const said = await call("push_unsubscribe_all", { p_account: claims.sub }, () => null);
    if (!said) throw new Unacceptable(NOT_YET, 503);
    return response.status(200).json({ on: false, devices: 0, gone: Number(said.gone) || 0 });
  }
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
  // Tied to this sign-in: it goes when the sign-in does (push_2.sql).
  const said = await call("push_subscribe", { p_account: claims.sub, p_endpoint: device.endpoint, p_p256dh: device.p256dh,
    p_auth: device.auth, p_origin: originHere(request), p_lang: lang, p_session: claims.session_id || null }, () => null);
  if (!said) throw new Unacceptable(NOT_YET, 503);
  if (said.refused) throw new AuthError("You were signed out. Sign in again.");
  return response.status(200).json({ on: true, devices: Number(said.devices) || 0 });
}

/// POST ?op=push_send: the knock (push.sql's, pg_cron's, or a check's).
/// Says nothing of what it sent, or to whom: 204.
export async function pushSend(request, response) {
  response.setHeader("Cache-Control", "no-store");
  await sendDue(request);
  return response.status(204).end();
}
