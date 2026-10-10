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
//   /api/mcp?t=T            an MCP request from Claude (Streamable HTTP,
//                           JSON responses, stateless)
//   /api/mcp?t=T&op=next    the tab asks for work; waits up to ~25 s
//   /api/mcp?t=T&op=answer  the tab answers request ?id=
//   /api/mcp?t=T&op=close   the tab stops listening
//
// The token is the whole credential, so it is long, random, made in the
// tab, and never stored: the queue (supabase/relay.sql) is keyed by its
// SHA-256. Anyone holding the address can build in that tab, which is what
// the address is for, and no more.
//
// Needs SUPABASE_URL and SUPABASE_SECRET_KEY on the project.

import { createHash } from "node:crypto";

const TOKEN = /^[A-Za-z0-9_-]{40,96}$/;
// How long Claude's request waits for the tab, and how long the tab's ask
// for work waits for Claude. Both well inside the function's 300 s.
const ANSWER_WAIT_MS = 110_000;
const WORK_WAIT_MS = 25_000;
const POLL_MS = 350;
// A tab that has not asked for work in this long is taken to be closed.
const TAB_GONE_MS = 45_000;
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
  "'Connect Claude' is off. Ask the person to open https://brickworks.diy/app " +
  "and turn on Connect Claude — the address shown there must be the one this " +
  "connector uses — then try again.";

async function tabIsOpen(channel) {
  const rows = await db(`relay_tabs?channel=eq.${channel}&select=seen_at`);
  if (!rows || rows.length === 0) return false;
  return Date.now() - Date.parse(rows[0].seen_at) < TAB_GONE_MS;
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
  const open = await tabIsOpen(channel);
  if (!open) {
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
  const until = Date.now() + ANSWER_WAIT_MS;
  while (Date.now() < until) {
    await sleep(POLL_MS);
    const [done] = await db(`relay?id=eq.${row.id}&select=response`);
    if (done && done.response) {
      await db(`relay?id=eq.${row.id}`, { method: "DELETE" });
      return response.status(200).json(done.response);
    }
  }
  return response.status(200).json(message.method === "tools/call"
    ? toolTrouble(id, "The Brickworks tab is open but did not answer in time. " +
        "It may still be working on it; look at the tab, then try again.")
    : rpcError(id, -32000, "the Brickworks tab did not answer in time"));
}

// The tab's side: say it is listening, then take the next request.
async function nextForTab(channel, response) {
  await db("relay_tabs", {
    method: "POST",
    body: { channel, seen_at: new Date().toISOString() },
    prefer: "resolution=merge-duplicates",
  });
  if (Math.random() < 0.05) await db("rpc/relay_sweep", { method: "POST", body: {} });
  const until = Date.now() + WORK_WAIT_MS;
  while (Date.now() < until) {
    const taken = await db("rpc/relay_take", { method: "POST", body: { p_channel: channel } });
    if (taken && taken.length > 0) {
      return response.status(200).json({ id: taken[0].id, request: taken[0].request });
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
  try {
    if (op === "") return await fromClaude(channel, request.body, response);
    if (op === "next") return await nextForTab(channel, response);
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
      await db(`relay_tabs?channel=eq.${channel}`, { method: "DELETE" });
      return response.status(204).end();
    }
    return response.status(400).json({ error: `no op ${op}` });
  } catch (trouble) {
    return response.status(502).json({ error: String(trouble.message || trouble) });
  }
}
