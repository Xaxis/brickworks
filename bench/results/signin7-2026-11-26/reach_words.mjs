// signin7: what reach (api/_db.js) says for each way a request can fail to connect, and whether
// _minted.js's NEVER_REACHED reads it as never reached. A local server that takes the request and
// closes without a reply stands for "reply lost"; one that never answers stands for the deadline.
import { createServer } from "node:http";
const { reach } = await import(process.argv[2] + "/api/_db.js");
const src = (await import("node:fs")).readFileSync(process.argv[2] + "/api/_minted.js", "utf8");
const NEVER_REACHED = eval(/const NEVER_REACHED = (\/.*\/);/.exec(src)[1]);
const closer = createServer((req) => req.socket.destroy()).listen(0, "127.0.0.1");
const silent = createServer(() => {}).listen(0, "127.0.0.1");
const gone = createServer().listen(0, "127.0.0.1");
await new Promise((r) => setTimeout(r, 200));
const shut = gone.address().port;
gone.close();
await new Promise((r) => setTimeout(r, 200));
const cases = [
  ["refused 127.0.0.1 (a port nobody listens on)", `http://127.0.0.1:${shut}/auth/v1/verify`, true],
  ["refused localhost (both families)", `http://localhost:${shut}/auth/v1/verify`, true],
  ["no such host", "https://verify-stand-in.invalid/auth/v1/verify", true],
  ["reply lost (socket closed after the request)", `http://127.0.0.1:${closer.address().port}/auth/v1/verify`, false],
  ["no answer within the deadline", `http://127.0.0.1:${silent.address().port}/auth/v1/verify`, false],
];
let wrong = 0;
for (const [name, url, want] of cases) {
  try {
    await reach("auth POST verify", 2, url, { method: "POST", body: "{}" });
    console.log(`??   ${name}: answered`); wrong++;
  } catch (trouble) {
    const got = NEVER_REACHED.test(trouble.message);
    if (got !== want) wrong++;
    console.log(`${got === want ? "ok  " : "BAD "} ${name}: "${trouble.message}" -> never reached ${got}`);
  }
}
closer.close(); silent.close();
console.log(`reach_words: ${wrong} wrong`);
process.exit(wrong ? 1 : 0);
