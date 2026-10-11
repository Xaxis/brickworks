// Claude, as the client, driving a Brickworks tab: the connector relay.
//
// Someone on a Claude plan adds Brickworks to Claude as a connector
// (claude.ai or the Claude apps, or Claude Code), then asks Claude to build
// something. Claude sends MCP requests here; a Brickworks tab of theirs
// collects them, answers them with the same code that serves the desktop's
// MCP tools (CommandSocket), and posts the answers back. This endpoint only
// carries messages between the two. It never sees an API key or a Claude
// login, and it never calls a model: Claude is the client, on the person's
// own plan, which is ordinary use of Anthropic's products.
//
// Two ways in (2026-10-11):
//
//   https://brickworks.diy/api/mcp          one address for everybody.
//       Claude signs in to it with OAuth (api/oauth.js): asked with no
//       token, this answers 401 and names where to sign in, Claude sends
//       the person to Brickworks to sign in and allow it, and is given a
//       token for their account. Each call goes to that account's open
//       tab, whichever it is, on any device. The app opens claude.ai's
//       "Add custom connector" with this address filled in.
//   https://brickworks.diy/api/mcp?t=<token>  one browser's private
//       address, made by the tab and pasted into Claude by hand: the way
//       from 2026-10-09, kept working for everyone who added one.
//
// Routes, all POST to this one function:
//   /api/mcp                  an MCP request from Claude signed in to an
//                             account ("Authorization: Bearer <token>")
//   /api/mcp?t=T              an MCP request from Claude (Streamable HTTP,
//                             JSON responses, stateless)
//   /api/mcp?t=T&op=hello     the tab switches on: its answers to initialize
//                             and tools/list, and which page load it is (?i=).
//                             Signed in: it carries the person's session
//                             ("Authorization: Bearer …"), and the account
//                             it names becomes the connector's owner
//   /api/mcp?t=T&op=next      the tab asks for work; waits up to ~25 s
//   /api/mcp?t=T&op=answer    the tab answers request ?id=
//   /api/mcp?t=T&op=state     the page is alive, and in or out of view
//                             (?visible=0|1): sent by the page itself every
//                             ten seconds and whenever it goes in or out of
//                             view, whatever the app is busy with
//   /api/mcp?t=T&op=close     the tab stops listening, or the page has gone
//
// Every tab listens on its own token's channel, either way; a call for an
// account is put on the channel of that account's tab.
//
// A browser stops drawing a tab it is not showing, and the app runs on
// drawing. While the connector is on the page now keeps the app running
// out of view (src/net/claude_connector.gd), and says every ten seconds
// that it is alive. So a tab is open while its page says so, in view or
// not: judging it by the app's requests for work called a tab "not open"
// while it built a large design, and while it woke from being out of
// view, and Claude told the person Brickworks was not connected while it
// plainly was. Only a page that has stopped altogether — closed, or a
// browser that froze it anyway — is not; a call then says which. Claude
// adds a connector and lists its tools from claude.ai's settings, so
// those are answered here, from what the tab sent when it switched on.
//
// A tab's token is long, random, made in the tab, and never stored: the
// queue (supabase/relay.sql) is keyed by its SHA-256. Anyone holding a
// private address can build in that tab, which is what the address is
// for, and no more.
//
// And a connector belongs to an account. Everyone who uses Brickworks
// signs in, and only a signed-in tab can switch a connector on: op=hello
// carries the session's access token, verified here as api/_auth.js
// verifies every token, and relay_tabs records whose connector it is
// (owner). An address one account switched on cannot be switched on by
// another, and a tab that never said hello while signed in is handed no
// work. That owner is what a call signed in to an account is routed by.
//
// Needs SUPABASE_URL and SUPABASE_SECRET_KEY on the project, and
// SUPABASE_PUBLISHABLE_KEY for accounts.

import { createHash } from "node:crypto";
import { AuthError, bearer, verify } from "./_auth.js";
import { db, dbConfigured } from "./_db.js";
import { challenge, grantOf, originOf, resourceOf } from "./_oauth.js";

const TOKEN = /^[A-Za-z0-9_-]{40,96}$/;
const INSTANCE = /^[A-Za-z0-9_-]{8,40}$/;
// How long Claude's request waits for the tab, and how long the tab's ask
// for work waits for Claude. Both well inside the function's 300 s.
// Long, because a large submit_design is checked and built in the tab: three
// Orthanc runs of 2,700-2,900 parts timed out at a shorter limit, and a
// design that times out gets rebuilt coarser to beat the clock.
const ANSWER_WAIT_MS = 240_000;
const WORK_WAIT_MS = 25_000;
const POLL_MS = 350;
// A page that has said nothing in this long — no request for work and no
// word that it is alive, which it sends every ten seconds — has stopped.
const TAB_GONE_MS = 45_000;
// How long a call waits for a stopped tab out of view to come back, and
// for any tab to take a call at all, before Claude is told why not.
const HIDDEN_WAIT_MS = 20_000;
const UNTAKEN_MS = 30_000;
const PROTOCOL = "2025-06-18";

const sleep = (ms) => new Promise((done) => setTimeout(done, ms));

function channelOf(token) {
  return createHash("sha256").update(token).digest("hex");
}

function rpcError(id, code, message) {
  return { jsonrpc: "2.0", id, error: { code, message } };
}

// What Claude is told when the tab is not there to answer. In words, since
// a person reads it through Claude.
function toolTrouble(id, text) {
  return { jsonrpc: "2.0", id, result: { isError: true, content: [{ type: "text", text }] } };
}

const NOT_OPEN =
  "The Brickworks tab this connector belongs to is not open, or its " +
  "Claude connector is switched off. Ask the person to open " +
  "https://brickworks.diy/app, sign in, and switch on the connector under " +
  "\"Or with your Claude plan\" — on the same browser they set it up in, " +
  "so the address is the one this connector uses — then try again.";

// The same, for Claude signed in to an account: any of its tabs will do.
const notOpenFor = (origin) =>
  "No Brickworks tab is open for the account this connector is signed in " +
  `to. Ask the person to open ${origin}/app in a browser and sign in with ` +
  "the email address they connected Claude with — Claude finds the tab by " +
  "itself, on any computer — and, if its panel shows \"Claude can build in " +
  "this tab\" switched off, to switch it on. Then try again.";

const HIDDEN =
  "The Brickworks tab is open, but this browser has paused it out of view, " +
  "so it cannot build until it is shown again. Ask the person to bring the " +
  "Brickworks tab into view for a moment — it carries on by itself — then " +
  "call again.";

const TAB = "channel,seen_at,hello,instance,visible,open,owner";

async function tabOf(channel) {
  const rows = await db(`relay_tabs?channel=eq.${channel}&select=${TAB}`);
  return rows && rows.length ? rows[0] : null;
}

// "closed", "hidden" or "ready". Alive is ready, in view or not; a page
// that has stopped is "hidden" when it was last out of view, which is a
// browser that paused it, and "closed" when it was in view. A tab no
// signed-in page has switched on is closed whatever it says: it is handed
// no work, so a call waiting for it would wait four minutes for nothing.
function stateOf(tab) {
  if (!tab || !tab.open || !tab.owner) return "closed";
  if (Date.now() - Date.parse(tab.seen_at) <= TAB_GONE_MS) return "ready";
  return tab.visible ? "closed" : "hidden";
}

// Where Claude's requests go. Two ways in:
//
//   one tab     an address with a token in it (?t=), made by one browser:
//               that tab, and no other — the way since 2026-10-09, kept
//               for everyone who added such an address
//   an account  Claude signed in with OAuth (api/oauth.js), at the one
//               address everybody adds: whichever of the account's tabs
//               is open, on any device
//
// Each says which tab to send a request to now, what to answer the
// handshake and the tool list with, and what to tell Claude when there
// is no tab.
function oneTab(channel) {
  return {
    find: () => tabOf(channel),
    hello: async (tab) => (tab && tab.hello) || null,
    notOpen: NOT_OPEN,
    used: async () => {},
  };
}

function accountTabs(grant, origin) {
  return {
    // The tab to build in: one that is answering before one that is
    // paused; the tab this connection last built in before any other, so a
    // conversation's model stays in one place; then one in view, then the
    // most recently heard from.
    async find() {
      const rows = await db(`relay_tabs?owner=eq.${grant.owner}&open=is.true`
        + `&select=${TAB}&order=seen_at.desc&limit=20`) || [];
      const score = (tab) => {
        const state = stateOf(tab);
        return (state === "ready" ? 100 : state === "hidden" ? 10 : 0)
          + (state !== "closed" && tab.channel === grant.channel ? 5 : 0)
          + (tab.visible ? 2 : 0);
      };
      return rows.sort((a, b) => score(b) - score(a))[0] || null;
    },
    // The handshake and the tool list are the app's, the same for every
    // account: from the tab if there is one, else from the last tab of this
    // account to switch on, else from somebody's — so Claude can add the
    // connector before the person has opened Brickworks at all. Somebody's
    // is the fullest of the latest few, so a test's one-tool tab is never
    // what a person's Claude is shown.
    async hello(tab) {
      if (tab && tab.hello) return tab.hello;
      const own = await db(`relay_tabs?owner=eq.${grant.owner}&hello=not.is.null`
        + "&select=hello&order=seen_at.desc&limit=1");
      if (own && own.length) return own[0].hello;
      const recent = await db("relay_tabs?hello=not.is.null&owner=not.is.null"
        + "&select=channel,tools:hello->tools&order=seen_at.desc&limit=20") || [];
      const count = (row) => (Array.isArray(row.tools) ? row.tools.length : 0);
      const fullest = recent.sort((a, b) => count(b) - count(a))[0];
      if (!fullest) return null;
      const [row] = await db(`relay_tabs?channel=eq.${fullest.channel}&select=hello`) || [];
      return row ? row.hello : null;
    },
    notOpen: notOpenFor(origin),
    // What the account panel shows of the connection: when Claude last
    // used it, what it called itself, and the tab it builds in.
    async used(message, tab) {
      const change = {};
      if (!grant.used_at || Date.now() - Date.parse(grant.used_at) > 60_000) {
        change.used_at = new Date().toISOString();
      }
      const info = message.method === "initialize" ? message.params?.clientInfo : null;
      if (info && typeof info === "object") {
        const said = {
          name: String(info.name || "").slice(0, 80),
          version: String(info.version || "").slice(0, 40),
        };
        if (JSON.stringify(said) !== JSON.stringify(grant.client_info || {})) change.client_info = said;
      }
      if (tab && message.method === "tools/call" && tab.channel !== grant.channel) {
        change.channel = tab.channel;
      }
      if (Object.keys(change).length) {
        Object.assign(grant, change);
        await db(`oauth_grants?id=eq.${grant.id}`, { method: "PATCH", body: change });
      }
    },
  };
}

// Lets the tab show that Claude has reached it, for the requests answered
// here without it. A notification: the tab answers nothing.
async function tellTab(channel, asked) {
  await db("relay", {
    method: "POST",
    body: { channel, request: { jsonrpc: "2.0", method: "brickworks/claude_here", params: { asked } } },
  });
}

// Claude's side: put the request in the queue and wait for the tab.
async function fromClaude(where, message, response) {
  if (Array.isArray(message)) {
    return response.status(200).json(rpcError(null, -32600, "batches are not supported"));
  }
  if (!message || typeof message !== "object" || message.jsonrpc !== "2.0") {
    return response.status(400).json(rpcError(null, -32600, "not a JSON-RPC request"));
  }
  // A notification wants no answer, and the tab needs none of them.
  if (message.id === undefined || message.id === null) {
    return response.status(202).end();
  }
  const id = message.id;
  let tab = await where.find();
  const hello = await where.hello(tab);

  // The handshake and the tool list, from what the tab sent when it
  // switched on: answered whether or not the tab is awake to answer.
  if (hello && ["initialize", "tools/list", "ping"].includes(message.method)) {
    await where.used(message, null);
    if (tab && tab.open) await tellTab(tab.channel, message.method);
    if (message.method === "ping") {
      return response.status(200).json({ jsonrpc: "2.0", id, result: {} });
    }
    if (message.method === "tools/list") {
      return response.status(200).json({ jsonrpc: "2.0", id, result: { tools: hello.tools || [] } });
    }
    return response.status(200).json({
      jsonrpc: "2.0", id,
      result: {
        protocolVersion: message.params?.protocolVersion || PROTOCOL,
        capabilities: { tools: { listChanged: false } },
        serverInfo: { name: "brickworks", version: "1" },
        instructions: hello.instructions || "",
      },
    });
  }

  let state = stateOf(tab);
  if (state === "hidden" && message.method === "tools/call") {
    // Often only a moment: they have gone to look at the tab.
    const until = Date.now() + HIDDEN_WAIT_MS;
    while (state === "hidden" && Date.now() < until) {
      await sleep(1000);
      tab = await where.find();
      state = stateOf(tab);
    }
    if (state === "hidden") return response.status(200).json(toolTrouble(id, HIDDEN));
  }
  if (state !== "ready") {
    await where.used(message, null);
    // Enough to be added as a connector with the tab closed; nothing that
    // pretends the tab is there.
    if (message.method === "initialize") {
      return response.status(200).json({
        jsonrpc: "2.0", id,
        result: {
          protocolVersion: message.params?.protocolVersion || PROTOCOL,
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: "brickworks", version: "1" },
          instructions: where.notOpen,
        },
      });
    }
    if (message.method === "ping") {
      return response.status(200).json({ jsonrpc: "2.0", id, result: {} });
    }
    if (message.method === "tools/call") {
      return response.status(200).json(toolTrouble(id, where.notOpen));
    }
    return response.status(200).json(rpcError(id, -32000, where.notOpen));
  }
  await where.used(message, tab);

  const channel = tab.channel;
  const [row] = await db("relay", {
    method: "POST",
    body: { channel, request: message },
    prefer: "return=representation",
  });
  const asked = Date.now();
  const until = asked + ANSWER_WAIT_MS;
  let checked = asked;
  while (Date.now() < until) {
    await sleep(POLL_MS);
    const [done] = await db(`relay?id=eq.${row.id}&select=response,taken_at`);
    if (done && done.response) {
      await db(`relay?id=eq.${row.id}`, { method: "DELETE" });
      return response.status(200).json(done.response);
    }
    // Not taken at all, and the page has stopped since: say so now rather
    // than at the end of four minutes.
    if (done && !done.taken_at && Date.now() - asked > UNTAKEN_MS
        && Date.now() - checked > 5_000) {
      checked = Date.now();
      const now = stateOf(await tabOf(channel));
      if (now !== "ready") {
        await db(`relay?id=eq.${row.id}`, { method: "DELETE" });
        const why = now === "hidden" ? HIDDEN : where.notOpen;
        return response.status(200).json(message.method === "tools/call"
          ? toolTrouble(id, why) : rpcError(id, -32000, why));
      }
    }
  }
  // Gone, so that a tab waking later does not do what Claude has stopped
  // waiting for and may be about to ask for again.
  await db(`relay?id=eq.${row.id}`, { method: "DELETE" });
  return response.status(200).json(message.method === "tools/call"
    ? toolTrouble(id, "The Brickworks tab did not answer in time. If it is " +
        "out of view, ask the person to bring it into view; then try again.")
    : rpcError(id, -32000, "the Brickworks tab did not answer in time"));
}

// Claude signed in with OAuth, at the address with no token in it. With
// no token, or one that does not do, the answer is a 401 naming where to
// sign in (the protected resource metadata), which is what starts Claude's
// sign-in; with one, the call goes to the account's tab.
async function forAccount(request, response) {
  const origin = originOf(request);
  // Browser-based MCP clients read the challenge across origins.
  response.setHeader("access-control-allow-origin", "*");
  response.setHeader("access-control-expose-headers", "www-authenticate");
  if (request.method === "OPTIONS") {
    return response.status(204)
      .setHeader("access-control-allow-headers",
        "authorization, content-type, mcp-protocol-version, mcp-session-id")
      .setHeader("access-control-allow-methods", "POST, GET, DELETE, OPTIONS")
      .end();
  }
  const presented = bearer(request);
  const grant = presented ? await grantOf(presented, resourceOf(origin)) : null;
  if (!grant) {
    response.setHeader("www-authenticate", presented
      ? challenge(origin, "the token is unknown, expired, or its connection was disconnected")
      : challenge(origin));
    return response.status(401).json({
      error: presented ? "invalid_token" : "unauthorized",
      error_description: "Sign in to Brickworks: Claude asks you to when you add this address as a connector.",
    });
  }
  if (request.method === "GET") return response.status(405).setHeader("allow", "POST").end();
  if (request.method === "DELETE") return response.status(204).end();
  if (request.method !== "POST") return response.status(405).end();
  return await fromClaude(accountTabs(grant, origin), request.body, response);
}

// The tab switching on: what it would answer to initialize and tools/list,
// and which page load it is. The latest page load to switch on is the one
// that listens; an older one asking for work is told it has been replaced.
//
// Only while signed in. The session's access token comes with it and is
// verified before anything is written; the account it names becomes the
// connector's owner, and an address another account owns is refused.
async function helloFromTab(channel, instance, request, response) {
  let claims;
  try {
    claims = await verify(bearer(request));
  } catch (trouble) {
    const status = trouble instanceof AuthError ? trouble.status : 401;
    return response.status(status).json({
      error: "sign in to Brickworks to connect Claude",
      reason: trouble.message,
    });
  }
  const body = request.body;
  if (!body || typeof body !== "object" || !Array.isArray(body.tools)) {
    return response.status(400).json({ error: "hello needs tools" });
  }
  const tab = await tabOf(channel);
  if (tab && tab.owner && tab.owner !== claims.sub) {
    return response.status(403).json({
      error: "this connector address belongs to another Brickworks account",
    });
  }
  await db("relay_tabs", {
    method: "POST",
    body: {
      channel, seen_at: new Date().toISOString(), instance, visible: true, open: true,
      owner: claims.sub,
      hello: { instructions: String(body.instructions || ""), tools: body.tools },
    },
    prefer: "resolution=merge-duplicates",
  });
  return response.status(204).end();
}

// The tab's side: say it is listening, then take the next request.
async function nextForTab(channel, instance, response) {
  const tab = await tabOf(channel);
  if (instance && tab && tab.instance && tab.instance !== instance) {
    return response.status(409).json({ error: "another page took over this connector" });
  }
  // Work goes only to a connector a signed-in page switched on. Without
  // this, the check on hello would be one a page could step round by
  // never saying hello.
  if (!tab || !tab.owner) {
    return response.status(401).json({
      error: "switch the connector on while signed in to Brickworks",
    });
  }
  await db("relay_tabs", {
    method: "POST",
    body: { channel, seen_at: new Date().toISOString(), open: true },
    prefer: "resolution=merge-duplicates",
  });
  if (Math.random() < 0.05) await db("rpc/relay_sweep", { method: "POST", body: {} });
  const until = Date.now() + WORK_WAIT_MS;
  while (Date.now() < until) {
    const taken = await db("rpc/relay_take", { method: "POST", body: { p_channel: channel } });
    if (taken && taken.length > 0) {
      const { id, request } = taken[0];
      // A notification is delivered once and wants no answer, so it is
      // not left to be handed out again.
      if (request.id === undefined || request.id === null) {
        await db(`relay?id=eq.${id}`, { method: "DELETE" });
      }
      return response.status(200).json({ id, request });
    }
    await sleep(POLL_MS);
  }
  return response.status(204).end();
}

export default async function handler(request, response) {
  response.setHeader("cache-control", "no-store");
  if (!dbConfigured()) {
    return response.status(503).json({ error: "the connector is not configured on this deployment" });
  }
  const token = String(request.query?.t || "");
  if (token === "") {
    try {
      return await forAccount(request, response);
    } catch (trouble) {
      return response.status(502).json({ error: String(trouble.message || trouble) });
    }
  }
  if (!TOKEN.test(token)) {
    return response.status(404).json({ error: "no such connector" });
  }
  // Streamable HTTP's server-to-client stream, which a stateless server
  // does not offer.
  if (request.method === "GET") {
    return response.status(405).setHeader("allow", "POST").end();
  }
  if (request.method === "DELETE") return response.status(204).end();
  if (request.method !== "POST") return response.status(405).end();

  const channel = channelOf(token);
  const op = String(request.query?.op || "");
  const instance = INSTANCE.test(String(request.query?.i || "")) ? String(request.query.i) : null;
  // Only the page load that is listening may say it is out of view or gone.
  const mine = instance ? `&or=(instance.is.null,instance.eq.${instance})` : "";
  try {
    if (op === "") return await fromClaude(oneTab(channel), request.body, response);
    if (op === "hello") {
      if (!instance) return response.status(400).json({ error: "hello needs ?i=" });
      return await helloFromTab(channel, instance, request, response);
    }
    if (op === "next") return await nextForTab(channel, instance, response);
    if (op === "state") {
      // Also the page's word that it is alive, so it counts as seen.
      await db(`relay_tabs?channel=eq.${channel}${mine}`, {
        method: "PATCH",
        body: { visible: String(request.query?.visible) !== "0", seen_at: new Date().toISOString() },
      });
      return response.status(204).end();
    }
    if (op === "answer") {
      const id = Number(request.query?.id);
      const answer = request.body;
      if (!Number.isInteger(id) || !answer || typeof answer !== "object") {
        return response.status(400).json({ error: "answer what?" });
      }
      await db(`relay?id=eq.${id}&channel=eq.${channel}`, {
        method: "PATCH",
        body: { response: answer, answered_at: new Date().toISOString() },
      });
      return response.status(204).end();
    }
    if (op === "close") {
      // Kept, for its hello: Claude can still list the tools, and a call
      // is told the tab is shut.
      await db(`relay_tabs?channel=eq.${channel}${mine}`, {
        method: "PATCH",
        body: { open: false },
      });
      return response.status(204).end();
    }
    return response.status(400).json({ error: `no op ${op}` });
  } catch (trouble) {
    return response.status(502).json({ error: String(trouble.message || trouble) });
  }
}
