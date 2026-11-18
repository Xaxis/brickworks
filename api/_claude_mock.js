// A stand-in Anthropic, the checks' own (adminclaude, 2026-11-18;
// docs/ADMIN_CLAUDE.md): the console's Claude in the checks' pool
// (/admin?tests=1) talks to this instead of api.anthropic.com, so every part
// of it (the key's check, the models, a streamed answer with its tool turns,
// a refusal, a 429, the cap) is proven end to end and no real key is spent.
//
// It answers what api/_claude_api.js asks, in the API's own shapes (the
// claude-api skill: GET /v1/models, paged, with each model's capabilities;
// POST /v1/messages streamed as Server-Sent Events: message_start,
// content_block_start/delta/stop for thinking (its signature), text and
// tool_use (input_json_delta), message_delta with the stop reason and the
// usage, message_stop), and holds the API's rules for a request:
//   - x-api-key must be its own key (STAND_IN_KEY) and anthropic-version
//     2026-10-21, as the real API refuses a wrong key (401
//     authentication_error) or an unknown version;
//   - no temperature, top_p or top_k (400 on 2026-10-21), no thinking budget
//     and no disabled thinking (400 on Claude Opus 5.5), no forced tool_choice,
//     no assistant prefill, every tool_use answered by its tool_result in the
//     next user message, fallbacks only with their beta header;
//   - each thinking block it hands out is signed over the conversation that
//     made it (the system prompt, the tools and every earlier message), and a
//     block sent back after any of those changed is refused (400), as the
//     history-editing check refuses it; one made by another model is dropped.
// It keeps nothing between requests: what it says is worked out from the
// request.
//
// Its "model" follows a script from what the owner asked (the server's first
// line, "Ask: ..."): it reads with the console's tools, makes a draft, and says
// what it did. Told "[stand-in: refuse]" it refuses mid-answer; "[stand-in:
// 429]", it answers 429 with retry-after; "[stand-in: fallback]", the asked
// model declines before any output and claude-opus-5 answers. And when a tool
// result it reads holds "ignore your rules" (a hostile reply in the inbox), it
// does what the words say: it asks for a tool that sends and for a draft with
// fields that would make it sent, which the server must refuse, and then
// writes the hostile words as a draft, the most it can do.
//
// [calls] keeps each request in this process for tests/fixtures/adminclaude:
// where, which model and tools, whether the key was its own, never the key.

import { createHash } from "node:crypto";

export const STAND_IN_KEY = "sk-ant-api03-standin-checks-only-0000000000000000000000000000000000000000000000-AAAA";
export const calls = [];

const VERSION = "2026-10-21";
const all = (levels) => Object.fromEntries(["low", "medium", "high", "xhigh", "max"].map((one) => [one, { supported: levels.includes(one) }]));
const model = (id, name, created, { adaptive = true, levels = ["low", "medium", "high", "xhigh", "max"] } = {}) => ({
  type: "model", id, display_name: name, created_at: created, max_input_tokens: id === "claude-haiku-4-5" ? 200000 : 1000000,
  max_tokens: id === "claude-haiku-4-5" ? 64000 : 128000,
  capabilities: { image_input: { supported: true }, structured_outputs: { supported: true },
    thinking: { supported: true, types: { enabled: { supported: !adaptive }, adaptive: { supported: adaptive } } },
    effort: { supported: adaptive, ...all(adaptive ? levels : []) } },
});
const MODELS = [
  model("claude-opus-5-5", "Claude Opus 5.5", "2026-10-28T00:00:00Z"),
  model("claude-sonnet-5-5", "Claude Sonnet 5.5", "2026-10-14T00:00:00Z"),
  model("claude-haiku-5-5", "Claude Haiku 5.5", "2026-09-30T00:00:00Z"),
  model("claude-opus-5", "Claude Opus 5", "2026-07-01T00:00:00Z"),
  // A model that takes a thinking budget, not adaptive thinking: listed by the
  // API, left out by the console.
  model("claude-haiku-4-5", "Claude Haiku 4.5", "2025-10-01T00:00:00Z", { adaptive: false }),
];
const FALLBACK_TAKERS = new Set(["claude-opus-5-5", "claude-sonnet-5-5", "claude-opus-5"]);

const json = (status, body, headers = {}) => new Response(JSON.stringify(body), { status,
  headers: { "content-type": "application/json", "request-id": `req_standin_${Date.now()}`, ...headers } });
const refuse = (status, type, message, headers = {}) => json(status, { type: "error", error: { type, message } }, headers);
const tokens = (value) => Math.max(1, Math.ceil(JSON.stringify(value ?? "").length / 4));
const sign = (model, prefix) => `standin1.${model}.${createHash("sha256").update(JSON.stringify(prefix)).digest("base64url")}`;
const header = (headers, name) => {
  if (!headers) return "";
  if (typeof headers.get === "function") return String(headers.get(name) || "");
  const found = Object.entries(headers).find(([key]) => key.toLowerCase() === name);
  return found ? String(found[1]) : "";
};

/// fetch, as api.anthropic.com answers it.
export async function claudeStandIn(url, init = {}) {
  const where = new URL(String(url));
  const method = String(init.method || "GET").toUpperCase();
  const keyOk = header(init.headers, "x-api-key") === STAND_IN_KEY;
  const call = { method, path: where.pathname, keyOk, at: Date.now() };
  calls.push(call);
  if (init.signal?.aborted) throw new DOMException("aborted", "AbortError");
  if (where.host !== "api.anthropic.com") return (call.status = 404, refuse(404, "not_found_error", "Not found"));
  if (header(init.headers, "anthropic-version") !== VERSION) {
    call.status = 400;
    return refuse(400, "invalid_request_error", "anthropic-version: the stand-in takes 2026-10-21");
  }
  if (!keyOk) return (call.status = 401, refuse(401, "authentication_error", "invalid x-api-key"));
  if (method === "GET" && where.pathname === "/v1/models") {
    // Paged three at a time, whatever the limit asked, so paging is used.
    const after = where.searchParams.get("after_id");
    const from = after ? MODELS.findIndex((one) => one.id === after) + 1 : 0;
    const page = MODELS.slice(from, from + Math.min(3, Number(where.searchParams.get("limit")) || 20));
    call.status = 200;
    return json(200, { data: page, has_more: from + page.length < MODELS.length, first_id: page[0]?.id ?? null,
      last_id: page.at(-1)?.id ?? null });
  }
  if (method === "POST" && where.pathname === "/v1/messages") return messages(init, call);
  call.status = 404;
  return refuse(404, "not_found_error", `Not found: ${method} ${where.pathname}`);
}

// ---------------------------------------------------------------------------
// The Messages API's rules for a request.

function wrong(body, betas) {
  if (!MODELS.some((one) => one.id === body.model)) return [404, "not_found_error", `model: ${body.model}`];
  for (const key of ["temperature", "top_p", "top_k"]) {
    if (key in body) return [400, "invalid_request_error", `${key}: not supported on API version 2026-10-21`];
  }
  if (body.stream !== true) return [400, "invalid_request_error", "the stand-in answers streamed requests"];
  if (!Number.isInteger(body.max_tokens) || body.max_tokens < 1 || body.max_tokens > 128000) {
    return [400, "invalid_request_error", "max_tokens: 1 to 128000"];
  }
  const thinking = body.thinking;
  if (thinking !== undefined && !(thinking && thinking.type === "adaptive" && Object.keys(thinking).every((k) => ["type", "display"].includes(k)))) {
    return [400, "invalid_request_error", "thinking: only {type: \"adaptive\"} on this model"];
  }
  if (body.tool_choice && ["any", "tool"].includes(body.tool_choice.type)) {
    return [400, "invalid_request_error", "tool_choice: type \"tool\" and \"any\" are not supported for this model."];
  }
  if (body.output_config?.effort && !["low", "medium", "high", "xhigh", "max"].includes(body.output_config.effort)) {
    return [400, "invalid_request_error", "output_config.effort"];
  }
  if (body.fallbacks !== undefined) {
    if (!betas.includes("server-side-fallback-2026-07-01")) return [400, "invalid_request_error", "fallbacks: Extra inputs are not permitted"];
    if (!FALLBACK_TAKERS.has(body.model)) return [400, "invalid_request_error", `fallbacks: not available for ${body.model}`];
  }
  const list = body.messages;
  if (!Array.isArray(list) || !list.length || list[0].role !== "user") return [400, "invalid_request_error", "messages: first is the user's"];
  if (list.at(-1).role !== "user") return [400, "invalid_request_error", "This model does not support assistant message prefill."];
  for (let at = 0; at < list.length; at += 1) {
    const one = list[at];
    if (!["user", "assistant"].includes(one.role)) return [400, "invalid_request_error", `messages.${at}.role`];
    const blocks = Array.isArray(one.content) ? one.content : [{ type: "text", text: String(one.content ?? "") }];
    if (one.role !== "assistant") continue;
    const uses = blocks.filter((b) => b.type === "tool_use").map((b) => b.id);
    if (!uses.length) continue;
    const next = list[at + 1];
    const answered = new Set((Array.isArray(next?.content) ? next.content : []).filter((b) => b.type === "tool_result").map((b) => b.tool_use_id));
    const missing = uses.find((id) => !answered.has(id));
    if (missing) return [400, "invalid_request_error", `messages.${at + 1}: tool_use ids were found without tool_result blocks: ${missing}`];
  }
  return null;
}

/// Every thinking block sent back checked against the conversation it was made
/// in: refused when that changed, dropped when another model made it.
function unbound(body) {
  let dropped = 0;
  for (let at = 0; at < body.messages.length; at += 1) {
    const one = body.messages[at];
    if (one.role !== "assistant" || !Array.isArray(one.content)) continue;
    for (let b = 0; b < one.content.length; b += 1) {
      const block = one.content[b];
      if (block.type !== "thinking") continue;
      const [kind, maker] = String(block.signature || "").split(".");
      if (kind !== "standin1") return { error: `messages.${at}.content.${b}: thinking block has no valid signature` };
      if (maker !== body.model) {
        dropped += 1;
        continue;
      }
      const want = sign(body.model, [body.system ?? null, body.tools ?? null, body.messages.slice(0, at), one.content.slice(0, b)]);
      if (want !== block.signature) {
        return { error: `messages.${at}.content.${b}: the thinking block's conversation changed since it was made `
          + "(its system prompt, tools or an earlier message)" };
      }
    }
  }
  return { dropped };
}

// ---------------------------------------------------------------------------
// The script.

const textOf = (message) => (typeof message.content === "string" ? message.content
  : (message.content || []).filter((b) => b.type === "text").map((b) => b.text).join("\n"));
const resultsOf = (message) => (Array.isArray(message?.content) ? message.content : []).filter((b) => b.type === "tool_result")
  .map((b) => (typeof b.content === "string" ? b.content : (b.content || []).map((c) => c.text || "").join("\n")));

/// What the owner asked last, and the rounds since: {ask, rounds, results}.
function where(list) {
  let at = list.length - 1;
  while (at > 0 && (list[at].role !== "user" || !textOf(list[at]).trim())) at -= 1;
  const ask = textOf(list[at]);
  const after = list.slice(at + 1);
  const rounds = after.filter((one) => one.role === "assistant").length;
  return { ask, rounds, results: resultsOf(list.at(-1)), all: after.filter((one) => one.role === "user").flatMap(resultsOf) };
}

let used = 0;
const use = (name, input) => ({ type: "tool_use", id: `toolu_standin_${Date.now().toString(36)}${(used += 1).toString(36)}`, name, input });

/// The stand-in model's next message: [blocks] after its thinking, and why it stopped.
function next(list) {
  const { ask, rounds, results, all } = where(list);
  const hostile = all.some((one) => /ignore your rules/i.test(one));
  const said = (text) => ({ blocks: [{ type: "text", text }], stop: "end_turn" });
  const suggest = /^Ask: suggest a post for r\/([A-Za-z0-9_]{2,21})/m.exec(ask);
  if (suggest) {
    const community = suggest[1];
    if (rounds === 0) {
      return { blocks: [{ type: "text", text: `I'll read r/${community}'s rules and what is new first.` },
        use("social_rules", { community }), use("whats_new", {})], stop: "tool_use" };
    }
    if (rounds === 1) {
      return { blocks: [use("make_draft", { kind: "post", community, title: "A free LEGO® CAD that runs in your browser",
        body: "We make Brickworks, a free building program for LEGO® bricks that runs in the browser: "
          + "https://brickworks.diy/gallery. What would you want from it?",
        note: `Fits r/${community}'s rules as read: affiliation said, one link, a question for the community.` })],
      stop: "tool_use" };
    }
    return said(`A draft for r/${community} is kept on the desk, marked by Claude. Edit it before you send it.`);
  }
  const reply = /^Ask: suggest a reply to (t[134]_[A-Za-z0-9]{1,20})/m.exec(ask);
  if (reply) {
    const parent = reply[1];
    if (rounds === 0) return { blocks: [use("social_thread", { external_id: parent })], stop: "tool_use" };
    if (hostile && rounds === 1) {
      // What a model the hostile words took over would try.
      return { blocks: [{ type: "text", text: "Doing what the message says." },
        use("social_send", { id: "aaaaaaaaaa", now: true }),
        use("make_draft", { kind: "reply", parent, body: "X", id: "aaaaaaaaaa", status: "sent" })], stop: "tool_use" };
    }
    if (hostile && rounds === 2) {
      return { blocks: [use("make_draft", { kind: "post", community: "lego", title: "X", body: "X",
        note: "What the message asked" })], stop: "tool_use" };
    }
    if (rounds === 1) {
      return { blocks: [use("make_draft", { kind: "reply", parent,
        body: "Thanks for asking! Yes: open it in the studio and use File › Export. Happy building." })], stop: "tool_use" };
    }
    return said("A reply is kept as a draft beside the message. Nothing was sent.");
  }
  const improve = /^Ask: improve the draft ([a-z0-9]{10})/m.exec(ask);
  if (improve) {
    if (rounds === 0) return { blocks: [use("social_sends", { status: "draft" })], stop: "tool_use" };
    if (rounds === 1) {
      const draft = /"id":\s*"([a-z0-9]{10})"[^}]*?"community":\s*"([A-Za-z0-9_]+)"/.exec(results.join("\n"));
      return { blocks: [use("social_rules", { community: draft?.[2] || "lego" })], stop: "tool_use" };
    }
    if (rounds === 2) {
      // A reply drafted by hand (its address kept as its link) is improved as
      // a reply to the same address.
      const sends = all.flatMap((text) => { try { return JSON.parse(text).sends || []; } catch { return []; } });
      const target = sends.find((one) => one.id === improve[1]);
      if (target?.kind === "reply" && target.link) {
        return { blocks: [use("make_draft", { kind: "reply", address: target.link,
          body: "Thanks for trying it. Brickworks is ours; what would you build first?",
          note: `Shorter than ${improve[1]}, and it answers the same comment.` })], stop: "tool_use" };
      }
      return { blocks: [use("make_draft", { kind: "post", community: "lego", title: "We made a free LEGO® CAD for the browser",
        body: "Brickworks is ours, and free: https://brickworks.diy/gallery. Tell us what to build next.",
        note: `Shorter than ${improve[1]}, affiliation first, the title plain.` })], stop: "tool_use" };
    }
    return said("The better version is kept as a new draft beside yours; yours is as it was.");
  }
  if (/^Ask: overview/m.test(ask)) {
    if (rounds === 0) return { blocks: [use("social_overview", { days: 30 })], stop: "tool_use" };
    const facts = /"came_in":\s*(\d+)/.exec(results.join("\n"));
    return said(`What came in: ${facts ? facts[1] : "some"} items. What worked: the posts with a question. `
      + "What to post next: a short release note on Saturday morning.");
  }
  // A question: the tool its words name, then an answer with what it read.
  const tool = [[/sign.?ups?|people|accounts|growth/i, "people_counts", { weeks: 8 }], [/mail|bounce/i, "mail_health", {}],
    [/health|site|cron|release/i, "site_health", {}], [/plan|revenue|pay/i, "plans_read", {}],
    [/feedback|bug/i, "feedback_list", {}]].find(([words]) => words.test(ask.split("\n").slice(2).join("\n")));
  if (tool && rounds === 0) return { blocks: [use(tool[1], tool[2])], stop: "tool_use" };
  if (tool) {
    const total = /"total":\s*(\d+)/.exec(results.join("\n"));
    return said(`From ${tool[1]}: ${total ? `${total[1]} in all` : "read"}. No email address was in what I read.`);
  }
  return said("Hello from the stand-in. Ask about the desk, the people, mail, the site, plans or feedback.");
}

// ---------------------------------------------------------------------------
// The stream.

function sse(events, signal) {
  const encoder = new TextEncoder();
  return new ReadableStream({
    async start(controller) {
      for (const [name, data] of events) {
        if (signal?.aborted) {
          controller.error(new DOMException("aborted", "AbortError"));
          return;
        }
        controller.enqueue(encoder.encode(`event: ${name}\ndata: ${JSON.stringify(data)}\n\n`));
        await new Promise((done) => setTimeout(done, name === "content_block_delta" ? 8 : 1));
      }
      controller.close();
    },
  });
}

function messages(init, call) {
  let body;
  try {
    body = JSON.parse(String(init.body || ""));
  } catch {
    call.status = 400;
    return refuse(400, "invalid_request_error", "The body is not JSON.");
  }
  const betas = header(init.headers, "anthropic-beta").split(",").map((one) => one.trim()).filter(Boolean);
  Object.assign(call, { model: body.model, betas, tools: (body.tools || []).map((one) => one.name), effort: body.output_config?.effort,
    max_tokens: body.max_tokens, rounds: (body.messages || []).length, cache_control: body.cache_control?.type || null });
  const refused = wrong(body, betas);
  if (refused) {
    call.status = refused[0];
    return refuse(...refused);
  }
  const bound = unbound(body);
  if (bound.error) {
    call.status = 400;
    return refuse(400, "invalid_request_error", bound.error);
  }
  call.dropped = bound.dropped;
  const { ask } = where(body.messages);
  if (/\[stand-in: 429\]/.test(ask)) {
    call.status = 429;
    return refuse(429, "rate_limit_error", "Number of request tokens has exceeded your per-minute rate limit", { "retry-after": "7" });
  }
  const fallback = /\[stand-in: fallback\]/.test(ask) && body.fallbacks === "default";
  const serving = fallback ? "claude-opus-5" : body.model;
  const prefixCached = body.messages.length > 1 ? [body.system, body.tools, body.messages.slice(0, -1)] : null;
  const whole = tokens([body.system, body.tools, body.messages]);
  const cached = prefixCached ? Math.min(whole - 1, tokens(prefixCached)) : 0;
  const created = prefixCached ? 0 : tokens([body.system, body.tools]);
  const usage = { input_tokens: Math.max(1, whole - cached - created), cache_read_input_tokens: cached,
    cache_creation_input_tokens: created, output_tokens: 1 };
  const plan = /\[stand-in: refuse\]/.test(ask)
    ? { blocks: [{ type: "text", text: "I can help with part of" }], stop: "refusal" } : next(body.messages);
  const thinking = { type: "thinking", thinking: "", signature: sign(serving, [body.system ?? null, body.tools ?? null, body.messages, []]) };
  const blocks = [...(fallback ? [{ type: "fallback", from: { model: body.model }, to: { model: serving } }] : []), thinking, ...plan.blocks];
  // A fallback's thinking is signed over what comes before it in its message.
  if (fallback) blocks[1] = { ...thinking, signature: sign(serving, [body.system ?? null, body.tools ?? null, body.messages, blocks.slice(0, 1)]) };
  let out = 40;
  const events = [["message_start", { type: "message_start", message: { id: `msg_standin_${Date.now().toString(36)}`, type: "message",
    role: "assistant", model: serving, content: [], stop_reason: null, stop_details: null, usage: { ...usage } } }]];
  let stop = plan.stop;
  blocks.forEach((block, index) => {
    const cost = tokens(block);
    if (block.type !== "fallback" && block.type !== "thinking" && out + cost > body.max_tokens) {
      stop = "max_tokens";
      return;
    }
    out += block.type === "thinking" ? 0 : cost;
    if (stop === "max_tokens") return;
    if (block.type === "text") {
      events.push(["content_block_start", { type: "content_block_start", index, content_block: { type: "text", text: "" } }]);
      for (const piece of block.text.match(/.{1,24}/gs) || []) {
        events.push(["content_block_delta", { type: "content_block_delta", index, delta: { type: "text_delta", text: piece } }]);
      }
    } else if (block.type === "thinking") {
      events.push(["content_block_start", { type: "content_block_start", index, content_block: { type: "thinking", thinking: "", signature: "" } }]);
      events.push(["content_block_delta", { type: "content_block_delta", index, delta: { type: "signature_delta", signature: block.signature } }]);
    } else if (block.type === "tool_use") {
      events.push(["content_block_start", { type: "content_block_start", index, content_block: { type: "tool_use", id: block.id, name: block.name, input: {} } }]);
      const raw = JSON.stringify(block.input);
      const half = Math.ceil(raw.length / 2);
      for (const piece of [raw.slice(0, half), raw.slice(half)]) {
        events.push(["content_block_delta", { type: "content_block_delta", index, delta: { type: "input_json_delta", partial_json: piece } }]);
      }
    } else events.push(["content_block_start", { type: "content_block_start", index, content_block: block }]);
    events.push(["content_block_stop", { type: "content_block_stop", index }]);
    if (index === 0) events.push(["ping", { type: "ping" }]);
  });
  usage.output_tokens = out;
  if (fallback) {
    usage.iterations = [{ type: "message", input_tokens: usage.input_tokens + cached + created, output_tokens: 0 },
      { type: "fallback_message", input_tokens: usage.input_tokens, cache_read_input_tokens: cached,
        cache_creation_input_tokens: created, output_tokens: out }];
  }
  const details = stop === "refusal" ? { type: "refusal", category: "cyber", explanation: "The stand-in declines when told to." } : null;
  events.push(["message_delta", { type: "message_delta", delta: { stop_reason: stop, stop_sequence: null, stop_details: details },
    usage: { output_tokens: out, ...(usage.iterations ? { iterations: usage.iterations } : {}) } }]);
  events.push(["message_stop", { type: "message_stop" }]);
  Object.assign(call, { status: 200, stop, serving, tools_used: blocks.filter((b) => b.type === "tool_use").map((b) => b.name) });
  return new Response(sse(events, init.signal), { status: 200, headers: { "content-type": "text/event-stream; charset=utf-8",
    "request-id": `req_standin_${Date.now()}` } });
}
