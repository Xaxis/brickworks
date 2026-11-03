// A call to the project that fails says which it was (api/_db.js reach),
// and a publish whose picture never reaches storage says so in its log
// line, by api/share.js's own handler (tests/test_named_calls.py). Prints
// one line of JSON.
//
//   stalled         asked, and no answer ever comes: given up, named
//   stalled_body    answered, then its body stops coming: the same
//   unreached       nothing listens there
//   answered        a call that is answered at once is not given up later
//   db_unreached    the database (api/_db.js db), where nothing listens
//   publish         a new model whose picture's upload never lands: its
//                   status, its words, the log line, and what was asked
import http from "node:http";
import { once } from "node:events";
import { webcrypto } from "node:crypto";

// What the handlers read to call themselves configured, before they load.
process.env.SUPABASE_URL = "http://db.test";
process.env.SUPABASE_SECRET_KEY = "secret";
process.env.SUPABASE_PUBLISHABLE_KEY = "publishable";

const server = http.createServer((request, response) => {
  if (request.url === "/ok") return response.end("ok");
  // Headers, then nothing more.
  if (request.url === "/body") {
    response.writeHead(200);
    response.write("x");
  }
  // /stall: nothing at all.
});
server.listen(0, "127.0.0.1");
await once(server, "listening");
const at = `http://127.0.0.1:${server.address().port}`;
const shut = http.createServer();
shut.listen(0, "127.0.0.1");
await once(shut, "listening");
const nobody = `http://127.0.0.1:${shut.address().port}`;
shut.close();

const { reach, db } = await import("../../../api/_db.js");
const said = (promise) => promise.then(() => "answered", (trouble) => trouble.message);
const out = {};
out.stalled = await said(reach("storage POST png", 0.3, `${at}/stall`, { method: "POST", body: "x" }));
out.stalled_body = await said(reach("storage GET mpd", 0.3, `${at}/body`).then((answer) => answer.text()));
out.unreached = await said(reach("storage POST png", 5, `${nobody}/`, { method: "POST", body: "x" }));
const quick = await reach("storage GET mpd", 0.3, `${at}/ok`);
const text = await quick.text();
await new Promise((done) => setTimeout(done, 500));
out.answered = { status: quick.status, text };

process.env.SUPABASE_URL = nobody;
out.db_unreached = await said(db("rpc/may_publish", { method: "POST", body: { account: "a" } }));
process.env.SUPABASE_URL = "http://db.test";

// A session for the publish, signed by a key the stand-in's JWKS has.
const ME = "11111111-1111-4111-8111-111111111111";
const pair = await webcrypto.subtle.generateKey({ name: "ECDSA", namedCurve: "P-256" }, true, ["sign", "verify"]);
const jwk = { ...(await webcrypto.subtle.exportKey("jwk", pair.publicKey)), kid: "k1", alg: "ES256" };
const b64 = (bytes) => Buffer.from(bytes).toString("base64url");
const head = b64(JSON.stringify({ alg: "ES256", kid: "k1", typ: "JWT" }));
const claims = b64(JSON.stringify({ sub: ME, aud: "authenticated", iss: "http://db.test/auth/v1",
  exp: Math.floor(Date.now() / 1000) + 3600 }));
const signature = await webcrypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, pair.privateKey,
  new TextEncoder().encode(`${head}.${claims}`));
const token = `${head}.${claims}.${b64(signature)}`;

// The project: the sign-in's keys, a publish allowed, storage that takes
// the model and never the picture, as undici fails a socket closed under it.
const asked = [];
const real = globalThis.fetch;
globalThis.fetch = async (input, init = {}) => {
  const url = new URL(String(input.url || input));
  if (url.host !== "db.test") return real(input, init);
  const method = init.method || "GET";
  asked.push(`${method} ${url.pathname.replace(/[A-Za-z0-9]{10}\./, "<id>.")}`);
  if (url.pathname === "/auth/v1/.well-known/jwks.json") return Response.json({ keys: [jwk] });
  if (url.pathname === "/rest/v1/rpc/may_publish") return Response.json(true);
  if (method === "POST" && /^\/storage\/v1\/object\/shared-models\/.+\.png$/.test(url.pathname)) {
    throw new TypeError("fetch failed", { cause: Object.assign(new Error("other side closed"), { code: "UND_ERR_SOCKET" }) });
  }
  if (url.pathname.startsWith("/storage/v1/")) return Response.json({});
  return Response.json([]);
};
const logged = [];
console.error = (...words) => logged.push(words.join(" "));

const { default: handler } = await import("../../../api/share.js");
const PNG = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 0]);
const request = { method: "POST", query: {}, headers: { host: "brickworks.test", authorization: `Bearer ${token}` },
  body: { name: "A named call", image: PNG.toString("base64"),
    model: "0 A named call\r\n0 Name: named.ldr\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 STEP\r\n" } };
const response = {
  statusCode: 200, headers: {}, body: null,
  status(code) { this.statusCode = code; return this; },
  setHeader(name, value) { this.headers[String(name).toLowerCase()] = value; return this; },
  json(value) { this.body = value; return this; },
  end() { return this; },
};
await handler(request, response);
out.publish = { status: response.statusCode, error: response.body?.error, logged, asked };

console.log(JSON.stringify(out));
process.exit(0);
