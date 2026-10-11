// Claude, as the client, driving a Brickworks tab: the connector relay.
//
// Someone on a Claude plan opens Brickworks, turns on "Connect Claude" and
// gets a private address: https://brickworks.diy/api/mcp?t=<token>. They
// add it to Claude as a custom connector (claude.ai, the Claude app, or
// `claude mcp add --transport http`), then ask Claude to build something.
// Claude sends MCP requests here; the tab collects them, answers them with
// the same code that serves the desktop's MCP tools (CommandSocket), and
// posts the answers back. This endpoint only carries messages between the
// two. It never sees an API key or a Claude login, and it never calls a
// model: Claude is the client, on the person's own plan, which is ordinary
// use of Anthropic's products.
//
// Routes, all POST to this one function:
//   /api/mcp?t=T              an MCP request from Claude (Streamable HTTP,
//                             JSON responses, stateless)
//   /api/mcp?t=T&op=hello     the tab switches on: its answers to initialize
//                             and tools/list, and which page load it is (?i=)
//   /api/mcp?t=T&op=next      the tab asks for work; waits up to ~25 s
//   /api/mcp?t=T&op=answer    the tab answers request ?id=
//   /api/mcp?t=T&op=state     the page is alive, and in or out of view
//                             (?visible=0|1): sent by the page itself every
//                             ten seconds and whenever it goes in or out of
//                             view, whatever the app is busy with
//   /api/mcp?t=T&op=close     the tab stops listening, or the page has gone
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
// The token is the whole credential, so it is long, random, made in the
// tab, and never stored: the queue (supabase/relay.sql) is keyed by its
// SHA-256. Anyone holding the address can build in that tab, which is what
// the address is for, and no more.
//
// Needs SUPABASE_URL and SUPABASE_SECRET_KEY on the project.

import { createHash } from "node:crypto";

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

// PostgREST with the server's own key. Row level security keeps every
// other key out of these tables.
async function db(path, { method = "GET", body, prefer } = {}) {
  const url = `${process.env.SUPABASE_URL}/rest/v1/${path}`;
  const key = process.env.SUPABASE_SECRET_KEY;
  const headers = {
    apikey: key,
    authorization: `Bearer ${key}`,
    "content-type": "application/json",
  };
  if (prefer) headers.prefer = prefer;
  const answer = await fetch(url, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!answer.ok) {
    throw new Error(`queue ${method} ${path.split("?")[0]}: ${answer.status}`);
  }
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
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
  "https://brickworks.diy/app and switch on the connector under \"Or with " +
  "your Claude plan\" — on the same browser they set it up in, so the " +
  "address is the one this connector uses — then try again.";

const HIDDEN =
  "The Brickworks tab is open, but this browser has paused it out of view, " +
  "so it cannot build until it is shown again. Ask the person to bring the " +
  "Brickworks tab into view for a moment — it carries on by itself — then " +
  "call again.";

async function tabOf(channel) {
  const rows = await db(
    `relay_tabs?channel=eq.${channel}&select=seen_at,hello,instance,visible,open`);
  return rows && rows.length ? rows[0] : null;
}

// "closed", "hidden" or "ready". Alive is ready, in view or not; a page
// that has stopped is "hidden" when it was last out of view, which is a
// browser that paused it, and "closed" when it was in view.
function stateOf(tab) {
  if (!tab || !tab.open) return "closed";
  if (Date.now() - Date.parse(tab.seen_at) <= TAB_GONE_MS) return "ready";
  return tab.visible ? "closed" : "hidden";
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
async function fromClaude(channel, message, response) {
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
  let tab = await tabOf(channel);
  const hello = tab && tab.hello;

  // The handshake and the tool list, from what the tab sent when it
  // switched on: answered whether or not the tab is awake to answer.
  if (hello && ["initialize", "tools/list", "ping"].includes(message.method)) {
    if (tab.open) await tellTab(channel, message.method);
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
      tab = await tabOf(channel);
      state = stateOf(tab);
    }
    if (state === "hidden") return response.status(200).json(toolTrouble(id, HIDDEN));
  }
  if (state !== "ready") {
    // Enough to be added as a connector with the tab closed; nothing that
    // pretends the tab is there.
    if (message.method === "initialize") {
      return response.status(200).json({
        jsonrpc: "2.0", id,
        result: {
          protocolVersion: message.params?.protocolVersion || PROTOCOL,
          capabilities: { tools: { listChanged: false } },
          serverInfo: { name: "brickworks", version: "1" },
          instructions: NOT_OPEN,
        },
      });
    }
    if (message.method === "ping") {
      return response.status(200).json({ jsonrpc: "2.0", id, result: {} });
    }
    if (message.method === "tools/call") {
      return response.status(200).json(toolTrouble(id, NOT_OPEN));
    }
    return response.status(200).json(rpcError(id, -32000, NOT_OPEN));
  }

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
        const why = now === "hidden" ? HIDDEN : NOT_OPEN;
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

// The tab switching on: what it would answer to initialize and tools/list,
// and which page load it is. The latest page load to switch on is the one
// that listens; an older one asking for work is told it has been replaced.
async function helloFromTab(channel, instance, body, response) {
  if (!body || typeof body !== "object" || !Array.isArray(body.tools)) {
    return response.status(400).json({ error: "hello needs tools" });
  }
  await db("relay_tabs", {
    method: "POST",
    body: {
      channel, seen_at: new Date().toISOString(), instance, visible: true, open: true,
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
  if (!process.env.SUPABASE_URL || !process.env.SUPABASE_SECRET_KEY) {
    return response.status(503).json({ error: "the connector is not configured on this deployment" });
  }
  const token = String(request.query?.t || "");
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
    if (op === "") return await fromClaude(channel, request.body, response);
    if (op === "hello") {
      if (!instance) return response.status(400).json({ error: "hello needs ?i=" });
      return await helloFromTab(channel, instance, request.body, response);
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
