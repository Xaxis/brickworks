// Anthropic's API as the console's Claude asks it (adminclaude, 2026-11-18;
// docs/ADMIN_CLAUDE.md): the Models API (GET /v1/models) and the Messages API
// streamed (POST /v1/messages, stream: true), in plain HTTP. The functions ship
// through tools/package_api.sh with no npm dependencies, and the official SDK
// (@anthropic-ai/sdk) cannot be packed by it: it copies api/*.js and nothing
// of node_modules. So this is the HTTP shape of the claude-api skill's cURL
// docs: x-api-key, anthropic-version 2026-10-21 (no temperature, top_p or
// top_k, which that version refuses), adaptive thinking with output_config's
// effort, no assistant prefill, tool_choice left to auto, eager input
// streaming on each tool with every input checked before it runs, and the
// server-side refusal fallback ("default", beta server-side-fallback-
// 2026-07-01) on the models that take it.
//
// [transport] is fetch's shape: the real one (api.anthropic.com), or the
// stand-in's (api/_claude_mock.js) for the checks' pool. The key goes in one
// header of one request and nowhere else: never in an error, a log or an
// answer.

export const API = "https://api.anthropic.com";
export const VERSION = "2026-10-21";
export const DEFAULT_MODEL = "claude-opus-5-5";
export const EFFORTS = ["low", "medium", "high", "xhigh", "max"];

/// The models whose refusals the API can hand to another model inside the same
/// call (claude-api skill: fallbacks "default" on these).
const FALLBACKS = new Set(["claude-fable-5-2", "claude-fable-5-1", "claude-opus-5-5", "claude-opus-5", "claude-sonnet-5-5"]);
export const FALLBACK_BETA = "server-side-fallback-2026-07-01";

/// Dollars a million tokens: [input, output, cache read, cache write (5 minutes)],
/// from the claude-api skill's model table (cached 2026-11-03). A cache write
/// is 1.25 times the input. A model not here is counted at the dearest here,
/// so the cap is never under-counted; the page says so.
const PRICES = {
  "claude-fable-5-2": [8, 40, 0.2, 10],
  "claude-mythos-5-2": [8, 40, 0.2, 10],
  "claude-fable-5-1": [10, 50, 0.25, 12.5],
  "claude-mythos-5-1": [10, 50, 0.25, 12.5],
  "claude-fable-5": [10, 50, 1, 12.5],
  "claude-mythos-5": [10, 50, 1, 12.5],
  "claude-opus-5-5": [4, 20, 0.2, 5],
  "claude-opus-5": [5, 25, 0.5, 6.25],
  "claude-opus-4-8": [5, 25, 0.5, 6.25],
  "claude-opus-4-7": [5, 25, 0.5, 6.25],
  "claude-opus-4-6": [5, 25, 0.5, 6.25],
  "claude-sonnet-5-5": [2, 10, 0.1, 2.5],
  "claude-sonnet-5": [2, 10, 0.2, 2.5],
  "claude-sonnet-4-6": [3, 15, 0.3, 3.75],
  // Haiku 5.5's dearer rate, past 100K tokens of prompt: counted whole at it.
  "claude-haiku-5-5": [0.5, 2.5, 0.05, 0.625],
  "claude-haiku-4-5": [1, 5, 0.1, 1.25],
};
const DEAREST = [10, 50, 1, 12.5];

/// [model]'s prices, {input, output, cache_read, cache_write, known}.
export function priceOf(model) {
  const known = Object.hasOwn(PRICES, model);
  const [input, output, cacheRead, cacheWrite] = known ? PRICES[model] : DEAREST;
  return { input, output, cache_read: cacheRead, cache_write: cacheWrite, known };
}

/// What [usage] cost in dollars at [model]'s prices. With a fallback that ran,
/// each attempt (usage.iterations) is counted at the dearer of the asked and
/// the serving model, so a switch never under-counts.
export function costOf(usage, asked, served = asked) {
  const one = (u) => {
    const a = priceOf(asked);
    const b = priceOf(served);
    const at = (key) => Math.max(a[key], b[key]) / 1e6;
    return (Number(u?.input_tokens) || 0) * at("input") + (Number(u?.output_tokens) || 0) * at("output")
      + (Number(u?.cache_read_input_tokens) || 0) * at("cache_read")
      + (Number(u?.cache_creation_input_tokens) || 0) * at("cache_write");
  };
  const iterations = Array.isArray(usage?.iterations) && usage.iterations.length ? usage.iterations : null;
  return iterations ? iterations.reduce((sum, u) => sum + one(u), 0) : one(usage);
}

/// Anthropic's refusal of a request, said in the console's words: [status],
/// [type] (rate_limit_error...), and seconds to wait when it said.
export class ClaudeRefusal extends Error {
  constructor(said, status = 502, type = "api_error", retry = null) {
    super(said);
    this.status = status;
    this.type = type;
    this.retry = retry;
  }
}

/// What an error answer from Anthropic says, never the request's headers.
async function refusalOf(reply) {
  let body = null;
  try {
    body = await reply.json();
  } catch { /* not JSON */ }
  const type = String(body?.error?.type || "api_error").slice(0, 60);
  const message = String(body?.error?.message || "").replace(/sk-ant-[A-Za-z0-9_-]+/g, "[a key]").slice(0, 240);
  const retry = Number(reply.headers?.get?.("retry-after")) || null;
  const said = {
    authentication_error: "Anthropic did not accept the key (authentication_error).",
    permission_error: "Anthropic says the key may not do this (permission_error).",
    billing_error: "Anthropic says the account behind the key cannot pay for this (billing_error).",
    not_found_error: "Anthropic does not know that model or address (not_found_error).",
    rate_limit_error: `Anthropic says too many requests (rate_limit_error)${retry ? `: try again in ${retry} s` : ""}.`,
    overloaded_error: "Anthropic is overloaded just now (overloaded_error): try again in a minute.",
    request_too_large: "The conversation is too large for Anthropic (request_too_large): start a new one.",
    invalid_request_error: `Anthropic refused the request (invalid_request_error)${message ? `: ${message}` : ""}.`,
  }[type] || `Anthropic answered ${reply.status} (${type})${message ? `: ${message}` : ""}.`;
  const status = reply.status === 429 ? 429 : reply.status === 401 || reply.status === 403 ? 400 : 502;
  return new ClaudeRefusal(said, status, type, retry);
}

function headersOf(key, betas = []) {
  const headers = { "x-api-key": key, "anthropic-version": VERSION, "content-type": "application/json" };
  if (betas.length) headers["anthropic-beta"] = betas.join(",");
  return headers;
}

/// [seconds] to answer, or refused with words.
async function within(transport, url, init, seconds, outer = null) {
  const deadline = new AbortController();
  const timer = setTimeout(() => deadline.abort(), seconds * 1000);
  timer.unref?.();
  const stop = () => deadline.abort();
  outer?.addEventListener?.("abort", stop);
  try {
    return await transport(url, { ...init, signal: deadline.signal });
  } catch {
    if (outer?.aborted) throw new ClaudeRefusal("Stopped.", 499, "stopped");
    if (deadline.signal.aborted) throw new ClaudeRefusal(`Anthropic did not answer within ${seconds} s.`, 504, "timeout");
    throw new ClaudeRefusal("Anthropic could not be reached.", 502, "unreachable");
  } finally {
    clearTimeout(timer);
  }
}

/// Every model the key may use, the Models API's own list, paged.
export async function modelsOf(transport, key) {
  const out = [];
  let after = null;
  for (let page = 0; page < 10; page += 1) {
    const query = new URLSearchParams({ limit: "100", ...(after ? { after_id: after } : {}) });
    const reply = await within(transport, `${API}/v1/models?${query}`, { method: "GET", headers: headersOf(key) }, 20);
    if (!reply.ok) throw await refusalOf(reply);
    const body = await reply.json();
    for (const one of Array.isArray(body?.data) ? body.data : []) out.push(one);
    if (!body?.has_more || !body?.last_id) break;
    after = body.last_id;
  }
  return out;
}

/// A model from the list as the page shows it, or null when the console cannot
/// use it: it must think adaptively (every current model; the older that take a
/// thinking budget are left out) and say which efforts it takes.
export function choosable(model) {
  const caps = model?.capabilities || {};
  const adaptive = caps.thinking?.types?.adaptive?.supported === true;
  if (!adaptive || !/^claude-[a-z0-9.-]{1,60}$/.test(String(model?.id || ""))) return null;
  const efforts = caps.effort?.supported === true ? EFFORTS.filter((level) => caps.effort?.[level]?.supported === true) : [];
  const price = priceOf(model.id);
  return { id: model.id, name: String(model.display_name || model.id).slice(0, 80), created_at: model.created_at || null,
    efforts, context: Number(model.max_input_tokens) || null, most_out: Number(model.max_tokens) || null,
    price: { input: price.input, output: price.output, cache_read: price.cache_read, known: price.known } };
}

/// The request body: the frozen system prompt and tools first (so the cache
/// and every thinking block's prefix hold), the conversation, the effort.
export function bodyOf({ model, effort, system, tools, messages, maxTokens }) {
  const body = {
    model,
    max_tokens: maxTokens,
    stream: true,
    system: [{ type: "text", text: system }],
    tools,
    messages,
    thinking: { type: "adaptive" },
    // The last cacheable block, cached: each round of a turn reads the one before.
    cache_control: { type: "ephemeral" },
  };
  if (effort) body.output_config = { effort };
  if (FALLBACKS.has(model)) body.fallbacks = "default";
  return body;
}

/// One streamed Messages call: [onEvent] hears each text delta, and the whole
/// message comes back as the API built it ({id, model, content, stop_reason,
/// stop_details, usage}).
export async function stream(transport, key, body, { onText = () => {}, signal = null, seconds = 240 } = {}) {
  const betas = body.fallbacks ? [FALLBACK_BETA] : [];
  // One deadline for the whole answer, its last byte included, and the
  // owner's Stop (or the page going away) ends it at once.
  const deadline = new AbortController();
  const timer = setTimeout(() => deadline.abort(), seconds * 1000);
  timer.unref?.();
  const stop = () => deadline.abort();
  signal?.addEventListener?.("abort", stop);
  if (signal?.aborted) stop();
  try {
    return await streamWithin(transport, key, body, betas, onText, deadline.signal, signal, seconds);
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener?.("abort", stop);
  }
}

async function streamWithin(transport, key, body, betas, onText, own, signal, seconds) {
  let reply;
  try {
    reply = await transport(`${API}/v1/messages`, { method: "POST", headers: headersOf(key, betas), body: JSON.stringify(body),
      signal: own });
  } catch {
    if (signal?.aborted) throw new ClaudeRefusal("Stopped.", 499, "stopped");
    if (own.aborted) throw new ClaudeRefusal(`Anthropic did not answer within ${seconds} s.`, 504, "timeout");
    throw new ClaudeRefusal("Anthropic could not be reached.", 502, "unreachable");
  }
  if (!reply.ok) throw await refusalOf(reply);
  const message = { id: null, model: body.model, content: [], stop_reason: null, stop_details: null, usage: {} };
  const partial = new Map();
  const reader = reply.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";
  let event = "";
  let data = [];
  const handle = (name, raw) => {
    let one;
    try {
      one = JSON.parse(raw);
    } catch {
      return;
    }
    const type = one?.type || name;
    if (type === "message_start") {
      Object.assign(message, { id: one.message?.id ?? null, model: one.message?.model || body.model });
      message.usage = { ...(one.message?.usage || {}) };
    } else if (type === "content_block_start") {
      const block = { ...(one.content_block || {}) };
      if (block.type === "tool_use") {
        partial.set(one.index, "");
        block.input = {};
      }
      message.content[one.index] = block;
    } else if (type === "content_block_delta") {
      const block = message.content[one.index];
      const delta = one.delta || {};
      if (!block) return;
      if (delta.type === "text_delta") {
        block.text = (block.text || "") + String(delta.text || "");
        onText(String(delta.text || ""));
      } else if (delta.type === "thinking_delta") block.thinking = (block.thinking || "") + String(delta.thinking || "");
      else if (delta.type === "signature_delta") block.signature = String(delta.signature || "");
      else if (delta.type === "input_json_delta") partial.set(one.index, (partial.get(one.index) || "") + String(delta.partial_json || ""));
      else if (delta.type === "citations_delta" && delta.citation) (block.citations ||= []).push(delta.citation);
    } else if (type === "content_block_stop") {
      const block = message.content[one.index];
      if (block?.type === "tool_use") {
        const text = partial.get(one.index) || "";
        // Eager input streaming: the API did not check the input, so it is
        // parsed strictly here and checked again by the tool before it runs.
        try {
          block.input = text ? JSON.parse(text) : {};
        } catch {
          block.input = {};
          block.unparsed = text.slice(0, 4000);
        }
      }
    } else if (type === "message_delta") {
      if (one.delta?.stop_reason !== undefined) message.stop_reason = one.delta.stop_reason;
      if (one.delta?.stop_details !== undefined) message.stop_details = one.delta.stop_details;
      Object.assign(message.usage, one.usage || {});
    } else if (type === "error") {
      const kind = String(one.error?.type || "api_error");
      throw new ClaudeRefusal(kind === "overloaded_error" ? "Anthropic is overloaded just now (overloaded_error): try again in a minute."
        : `Anthropic stopped mid-answer (${kind}).`, 502, kind);
    }
  };
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      let at;
      while ((at = buffer.indexOf("\n")) >= 0) {
        const line = buffer.slice(0, at).replace(/\r$/, "");
        buffer = buffer.slice(at + 1);
        if (line === "") {
          if (data.length) handle(event, data.join("\n"));
          event = "";
          data = [];
        } else if (line.startsWith("event:")) event = line.slice(6).trim();
        else if (line.startsWith("data:")) data.push(line.slice(5).replace(/^ /, ""));
      }
    }
    if (data.length) handle(event, data.join("\n"));
  } catch (trouble) {
    // Begun: Anthropic may have spent tokens on it, how many is not known.
    const cut = trouble instanceof ClaudeRefusal ? trouble : signal?.aborted ? new ClaudeRefusal("Stopped.", 499, "stopped")
      : own.aborted ? new ClaudeRefusal(`Anthropic did not finish within ${seconds} s.`, 504, "timeout")
        : new ClaudeRefusal("Anthropic's answer broke off.", 502, "broken");
    cut.began = true;
    throw cut;
  }
  message.content = message.content.filter(Boolean);
  if (!message.stop_reason) {
    const cut = new ClaudeRefusal("Anthropic's answer ended before it said why it stopped.", 502, "broken");
    cut.began = true;
    throw cut;
  }
  return message;
}
