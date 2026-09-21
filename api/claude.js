// A thin proxy so the web build can reach Claude without shipping a key.
//
// Deliberately thin. The design loop — the system prompt, the tools, the
// validator that decides whether a model holds together — all live in the
// app, because that is where the real catalogue and the real collision
// lattice are. Duplicating the validator here in JavaScript would mean
// two implementations of "does this brick overlap that one" that could
// disagree, and the one that matters is the one the renderer uses.
//
// So this adds the key, checks the request is the shape we expect, and
// forwards. Nothing else.
//
// Abuse is the obvious risk of an endpoint holding a key, so this one is
// not open. Every request has to carry a signed-in account, and every
// design is counted against that account's monthly budget in Postgres —
// a limit that survives the function recycling, which the per-IP limiter
// below does not. The per-IP limit is still here, in front of the token
// check, to keep a flood of junk from costing a signature verification
// each.
//
// Who this answers for is narrower than it looks: one account, the one
// named by MASTER_EMAIL. There is no payment system yet and no free
// tier on our spend, so everybody else runs the assistant on a key of
// their own — which their browser sends straight to Anthropic, and
// which never arrives here to be stored, logged or leaked.
//
// The builder itself needs none of this. Placing bricks, searching the
// catalogue, saving a model — none of it comes through here, which is
// what lets everything but the assistant work with no account at all.

import {
  AuthError,
  authConfigured,
  bearer,
  claimDesign,
  designId,
  isMaster,
  tierFor,
  verify,
} from "./_auth.js";

const ALLOWED_MODELS = new Set(["claude-opus-5", "claude-sonnet-5"]);
const MAX_TOKENS = 16000;
const MAX_BODY_BYTES = 512 * 1024;
const WINDOW_MS = 60_000;
const MAX_PER_WINDOW = 12;

const seen = new Map();

function rateLimited(ip) {
  const now = Date.now();
  const hits = (seen.get(ip) || []).filter((t) => now - t < WINDOW_MS);
  hits.push(now);
  seen.set(ip, hits);
  // Keep the map from growing without bound across a long-lived instance.
  if (seen.size > 5000) {
    for (const [key, times] of seen) {
      if (!times.length || now - times[times.length - 1] > WINDOW_MS) {
        seen.delete(key);
      }
    }
  }
  return hits.length > MAX_PER_WINDOW;
}

export default async function handler(request, response) {
  if (request.method === "OPTIONS") {
    return response
      .status(204)
      .setHeader("Access-Control-Allow-Origin", "*")
      .setHeader("Access-Control-Allow-Headers", "content-type, authorization")
      .setHeader("Access-Control-Allow-Methods", "POST, OPTIONS")
      .end();
  }

  response.setHeader("Access-Control-Allow-Origin", "*");

  if (request.method !== "POST") {
    return response.status(405).json({ error: "POST only" });
  }

  const key = process.env.ANTHROPIC_API_KEY;
  if (!key) {
    return response
      .status(503)
      .json({ error: "The design assistant is not configured on this deployment." });
  }

  const ip =
    (request.headers["x-forwarded-for"] || "").split(",")[0].trim() ||
    request.socket?.remoteAddress ||
    "unknown";
  if (rateLimited(ip)) {
    return response
      .status(429)
      .json({ error: "Too many designs at once. Give it a minute." });
  }

  // Fail closed. A deployment that holds an API key but has no accounts
  // configured is a misconfiguration, not a free-for-all, and the shape
  // of that mistake is an open endpoint spending someone else's money.
  // ASSISTANT_OPEN exists so a local `vercel dev` can skip sign-in; it is
  // deliberately awkward to set by accident.
  const open = process.env.ASSISTANT_OPEN === "1";
  let account = null;
  let tier = "builder";
  if (!open) {
    if (!authConfigured()) {
      return response
        .status(503)
        .json({ error: "Accounts are not configured on this deployment." });
    }
    try {
      const claims = await verify(bearer(request));
      if (!isMaster(claims)) {
        // Not a failure of theirs to fix by signing in again, so it is
        // not 401 and does not ask them to. The app reads this and
        // shows the field for a key of their own.
        return response.status(403).json({
          error:
            "The assistant runs on your own Anthropic key. Add one in the "
            + "assistant panel — it stays on this device and is never sent "
            + "to us.",
          bring_your_own_key: true,
        });
      }
      account = claims.sub;
      tier = await tierFor(account);
    } catch (error) {
      const status = error instanceof AuthError ? error.status : 401;
      return response
        .status(status)
        .json({ error: error.message, signin_required: status === 401 });
    }
  }

  let body = request.body;
  if (typeof body === "string") {
    try {
      body = JSON.parse(body);
    } catch {
      return response.status(400).json({ error: "body is not JSON" });
    }
  }
  if (!body || typeof body !== "object") {
    return response.status(400).json({ error: "body is not an object" });
  }

  const encoded = JSON.stringify(body);
  if (encoded.length > MAX_BODY_BYTES) {
    return response
      .status(413)
      .json({ error: "That conversation is too large to forward." });
  }

  const model = body.model || "claude-opus-5";
  if (!ALLOWED_MODELS.has(model)) {
    return response.status(400).json({ error: `model ${model} is not allowed here` });
  }
  if (!Array.isArray(body.messages) || body.messages.length === 0) {
    return response.status(400).json({ error: "messages must be a non-empty array" });
  }

  // Charged here rather than at the top: a request that was going to be
  // refused for its shape should not cost the player a design.
  if (account) {
    let spend;
    try {
      spend = await claimDesign(account, tier, designId(body.design_id));
    } catch (error) {
      const status = error instanceof AuthError ? error.status : 503;
      return response.status(status).json({ error: error.message });
    }
    if (!spend.allowed) {
      return response.status(429).json({
        error:
          `That is all ${spend.budget} designs for this month. ` +
          `The builder itself keeps working.`,
        used: spend.used,
        budget: spend.budget,
        quota_exhausted: true,
      });
    }
    response.setHeader("x-designs-used", String(spend.used));
    response.setHeader("x-designs-budget", String(spend.budget));
  }

  // Streaming is the client's choice, not ours. It asks so that it can
  // put the design on the baseplate brick by brick as the model writes
  // it, instead of showing a spinner for a minute and then everything
  // at once.
  const wantsStream = body.stream === true;
  let streaming = false;

  const payload = {
    model,
    max_tokens: Math.min(Number(body.max_tokens) || 8000, MAX_TOKENS),
    messages: body.messages,
    thinking: { type: "adaptive" },
  };
  if (body.system) payload.system = body.system;
  if (Array.isArray(body.tools)) payload.tools = body.tools;
  if (body.output_config) payload.output_config = body.output_config;
  if (wantsStream) payload.stream = true;

  try {
    const upstream = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "content-type": "application/json",
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify(payload),
    });

    if (wantsStream && upstream.ok && upstream.body) {
      streaming = true;
      response.setHeader("content-type", "text/event-stream");
      response.setHeader("cache-control", "no-cache, no-transform");
      response.setHeader("connection", "keep-alive");
      // Nginx and friends buffer an event stream by default, which
      // turns it back into one lump delivered at the end — the exact
      // thing the client asked not to happen.
      response.setHeader("x-accel-buffering", "no");
      response.status(200);
      const reader = upstream.body.getReader();
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        response.write(Buffer.from(value));
      }
      return response.end();
    }

    // An error, or a client that did not ask for a stream. Either way
    // it is one JSON document and the client knows how to read it.
    const text = await upstream.text();
    response.setHeader("content-type", "application/json");
    return response.status(upstream.status).send(text);
  } catch (error) {
    // Once the stream has started, the status and headers are already
    // on the wire. Trying to send a 502 then throws
    // ERR_HTTP_HEADERS_SENT and the response is never ended at all, so
    // the client sits there until its own timeout rather than being
    // told anything. Closing the connection is the only signal left,
    // and the client already treats a stream that stops part way
    // through as a failure to retry.
    if (streaming) {
      try { response.end(); } catch {}
      return;
    }
    return response
      .status(502)
      .json({ error: `could not reach the model: ${String(error)}` });
  }
}
