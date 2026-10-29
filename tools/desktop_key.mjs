// The key a desktop token is signed with (api/_desktop.js, src/account/desktop_pass.gd).
//
//   node tools/desktop_key.mjs new FILE        make an RSA key: the private half written
//                                              to FILE (0600, never over another), the
//                                              public half's id and its line for the app
//                                              printed. Never the private half.
//   node tools/desktop_key.mjs public          the id and the app's line for the key in
//                                              DESKTOP_TOKEN_KEY, to see which key a
//                                              deployment signs with
//   node tools/desktop_key.mjs sign FILE JSON  a token of the claims JSON (or its base64:
//                                              Godot's OS.execute drops quotes) signed with
//                                              the key in FILE (a probe's own test key)
//
// docs/RELEASING.md, "The desktop token's key", says how one is made, set
// on Vercel and rotated.
import { createPublicKey, generateKeyPairSync } from "node:crypto";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { kidOf, sign, signingKey } from "../api/_desktop.js";

const [what, file, claims] = process.argv.slice(2);

/// The line that holds [publicKey] in DesktopPass.KEYS.
function appLine(publicKey) {
  const pem = publicKey.export({ type: "spki", format: "pem" });
  return `\t"${kidOf(publicKey)}": ${JSON.stringify(pem)},`;
}

function fail(words) {
  console.error(`desktop_key: ${words}`);
  process.exit(2);
}

if (what === "new") {
  if (!file) fail("new FILE: where to write the private half");
  if (existsSync(file)) fail(`${file} is there already; a key is never written over`);
  const { privateKey, publicKey } = generateKeyPairSync("rsa", { modulusLength: 3072 });
  writeFileSync(file, privateKey.export({ type: "pkcs8", format: "pem" }), { mode: 0o600, flag: "wx" });
  console.log(`private half written to ${file} (0600). Set it on Vercel, then delete or lock it away:`);
  console.log(`  base64 -w0 ${file} | vercel env add DESKTOP_TOKEN_KEY production`);
  console.log(`key id ${kidOf(publicKey)}; its line in src/account/desktop_pass.gd's KEYS:`);
  console.log(appLine(publicKey));
} else if (what === "public") {
  const signer = signingKey();
  if (!signer) fail("DESKTOP_TOKEN_KEY is unset, or not an RSA private key of 2048 bits or more");
  console.log(`key id ${signer.kid}`);
  console.log(appLine(createPublicKey(signer.key)));
} else if (what === "sign") {
  if (!file || !claims) fail("sign FILE JSON");
  const signer = signingKey({ DESKTOP_TOKEN_KEY: readFileSync(file, "utf8") });
  if (!signer) fail(`${file} is not an RSA private key of 2048 bits or more`);
  const text = claims.trim().startsWith("{") ? claims : Buffer.from(claims, "base64").toString("utf8");
  console.log(sign(JSON.parse(text), signer));
} else {
  fail("new FILE | public | sign FILE JSON");
}
