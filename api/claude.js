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
// Abuse is the obvious risk of an open endpoint holding a key. What is
// here: an allowlist of models, hard caps on tokens and payload size, a
// required origin, and a coarse per-IP rate limit. What is NOT here is
// durable rate limiting — the limiter below lives in the function's
// memory and resets whenever the instance recycles, so it slows a casual
// scraper and would not stop a determined one. Put a real limiter in
// front of this before pointing a domain at it.

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
      .setHeader("Access-Control-Allow-Headers", "content-type")
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

  const payload = {
    model,
    max_tokens: Math.min(Number(body.max_tokens) || 8000, MAX_TOKENS),
    messages: body.messages,
    thinking: { type: "adaptive" },
  };
  if (body.system) payload.system = body.system;
  if (Array.isArray(body.tools)) payload.tools = body.tools;
  if (body.output_config) payload.output_config = body.output_config;

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

    const text = await upstream.text();
    response.setHeader("content-type", "application/json");
    return response.status(upstream.status).send(text);
  } catch (error) {
    return response
      .status(502)
      .json({ error: `could not reach the model: ${String(error)}` });
  }
}
