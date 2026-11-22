// Push as tests/test_push.py runs it: api/people.js's ?op=push, ?op=push_send
// and api/_push.js behind tests/fixtures/billing/world.mjs's Supabase, with
// supabase/push.sql's functions stood in for in memory, a device of the
// test's own (a P-256 key and an auth secret, as a browser makes), and the
// push services answering here: each push kept with its headers and its
// body, which decrypt() opens with the device's own key, as a browser does
// (RFC 8291), so what was sent is read back, not assumed.
//
//   const p = await pushWorld();
//   await p.people("POST", { op: "push" }, { on: true, ...p.device }, await p.signIn(ADA));

import { createDecipheriv, createECDH, createHmac, randomBytes } from "node:crypto";
import { SUPABASE_URL, world } from "./billing/world.mjs";

const hmac = (key, data) => createHmac("sha256", key).update(data).digest();

/// A browser's device: its keys, and the endpoint at [service].
export function makeDevice(endpoint) {
  const ecdh = createECDH("prime256v1");
  ecdh.generateKeys();
  const auth = randomBytes(16);
  return { ecdh, auth, json: { endpoint, p256dh: ecdh.getPublicKey().toString("base64url"), auth: auth.toString("base64url") } };
}

/// [body] (an aes128gcm message) opened with [device]'s key: its text.
export function decrypt(body, device) {
  const salt = body.subarray(0, 16);
  const idlen = body[20];
  const server = body.subarray(21, 21 + idlen);
  const sealed = body.subarray(21 + idlen);
  const shared = device.ecdh.computeSecret(server);
  const mine = device.ecdh.getPublicKey();
  const ikm = hmac(hmac(device.auth, shared), Buffer.concat([Buffer.from("WebPush: info\0"), mine, server, Buffer.from([1])]));
  const prk = hmac(salt, ikm);
  const cek = hmac(prk, Buffer.from("Content-Encoding: aes128gcm\0\x01")).subarray(0, 16);
  const nonce = hmac(prk, Buffer.from("Content-Encoding: nonce\0\x01")).subarray(0, 12);
  const decipher = createDecipheriv("aes-128-gcm", cek, nonce);
  decipher.setAuthTag(sealed.subarray(sealed.length - 16));
  const plain = Buffer.concat([decipher.update(sealed.subarray(0, sealed.length - 16)), decipher.final()]);
  if (plain[plain.length - 1] !== 2) throw new Error("not the last record's delimiter");
  return plain.subarray(0, plain.length - 1).toString("utf8");
}

export async function pushWorld({ vapid = true, sqlApplied = true } = {}) {
  const w = await world({});
  if (vapid) {
    const ecdh = createECDH("prime256v1");
    ecdh.generateKeys();
    process.env.VAPID_PRIVATE_KEY = ecdh.getPrivateKey().toString("base64url");
  } else {
    delete process.env.VAPID_PRIVATE_KEY;
  }
  const self = {
    world: w,
    /// push_subscriptions as push.sql keeps it, by endpoint.
    devices: new Map(),
    /// What push_take answers next: [{account, rows, devices}] (devices
    /// filled from [devices] when left out).
    due: [],
    /// Each push a service was sent: {endpoint, headers, body}.
    sent: [],
    /// What each push service answers, by endpoint: 201 unless said.
    answers: new Map(),
    /// Each rpc asked, {name, body}.
    rpcs: [],
    signIn: (claims) => w.signIn(claims),
  };
  const theirs = globalThis.fetch;
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    if (url.hostname.endsWith("push.services.mozilla.com") || url.hostname === "fcm.googleapis.com") {
      const headers = Object.fromEntries(Object.entries(init.headers || {}).map(([k, v]) => [k.toLowerCase(), String(v)]));
      self.sent.push({ endpoint: String(input), headers, body: Buffer.from(init.body) });
      return new Response("", { status: self.answers.get(String(input)) ?? 201 });
    }
    const rpc = url.origin === SUPABASE_URL && /^\/rest\/v1\/rpc\/(push_\w+)$/.exec(url.pathname);
    if (!rpc) return theirs(input, init);
    const reply = (body, status = 200) => new Response(JSON.stringify(body), { status });
    if (!sqlApplied) return reply({ message: "not found" }, 404);
    const a = JSON.parse(String(init.body || "{}"));
    self.rpcs.push({ name: rpc[1], body: a });
    const count = (account) => [...self.devices.values()].filter((one) => one.account === account).length;
    if (rpc[1] === "push_subscribe") {
      const was = self.devices.get(a.p_endpoint);
      self.devices.set(a.p_endpoint, { endpoint: a.p_endpoint, account: a.p_account, p256dh: a.p_p256dh, auth: a.p_auth,
        origin: a.p_origin, lang: a.p_lang, made_at: was && was.account === a.p_account ? was.made_at : new Date(Date.now() - 60000).toISOString() });
      return reply({ on: true, devices: count(a.p_account) });
    }
    if (rpc[1] === "push_unsubscribe") {
      const was = self.devices.get(a.p_endpoint);
      if (was && was.account === a.p_account) self.devices.delete(a.p_endpoint);
      return reply({ on: false, devices: count(a.p_account) });
    }
    if (rpc[1] === "push_subscribed") {
      const was = self.devices.get(a.p_endpoint);
      return reply({ on: Boolean(was && was.account === a.p_account), devices: count(a.p_account) });
    }
    if (rpc[1] === "push_gone") {
      const gone = self.devices.delete(a.p_endpoint) ? 1 : 0;
      return reply({ gone });
    }
    if (rpc[1] === "push_take") {
      const taken = self.due.splice(0).map((one) => ({ ...one,
        devices: one.devices || [...self.devices.values()].filter((d) => d.account === one.account) }));
      return reply(taken);
    }
    return reply({ message: "no such function" }, 404);
  };
  /// One request through api/people.js's handler: {status, json}.
  self.people = async (method, query, body, token = null) => {
    const { default: handle } = await import("../../api/people.js");
    let status = 0;
    let json = null;
    const response = {
      setHeader: () => response,
      status: (s) => { status = s; return response; },
      json: (b) => { json = b; return response; },
      end: () => response,
    };
    const headers = { host: "brickworks.diy", ...(token ? { authorization: `Bearer ${token}` } : {}) };
    await handle({ method, query, headers, body }, response);
    return { status, json };
  };
  return self;
}
