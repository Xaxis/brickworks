// The database api/mcp.js talks to, in memory, behind the one fetch: as
// much of PostgREST as the handshake and the tool list ask of it. Tabs are
// rows of relay_tabs; a connection is an access token whose grant names
// its account. Rows come back with their keys in the order the database
// keeps a jsonb value's (shorter first, then by bytes), as the real one
// sends them, so a hello is read back here as it is there.
//
//   const w = world();
//   const token = w.connect("acct-1");
//   w.tab({ owner: "acct-1", hello: { instructions: "…", tools: [...] } });
//   const listed = await w.ask(token, "tools/list");

import { createHash, randomBytes } from "node:crypto";

export const ORIGIN = "https://brickworks.test";
const SUPABASE_URL = "https://db.test";

const byKept = (a, b) => a.length - b.length || (a < b ? -1 : a > b ? 1 : 0);
const kept = (value) => {
  if (Array.isArray(value)) return value.map(kept);
  if (!value || typeof value !== "object") return value;
  return Object.fromEntries(Object.keys(value).sort(byKept).map((key) => [key, kept(value[key])]));
};

// One column of a select: name, alias:name, alias:col->key, alias:col->>key.
function column(row, said) {
  const [alias, path] = said.includes(":") ? said.split(/:(.*)/s) : [said, said];
  const text = path.match(/^(\w+)->>(\w+)$/);
  const json = path.match(/^(\w+)->(\w+)$/);
  if (text) {
    const value = row[text[1]]?.[text[2]];
    return [alias, value === undefined || value === null ? null : typeof value === "string" ? value : JSON.stringify(value)];
  }
  if (json) return [alias, row[json[1]]?.[json[2]] ?? null];
  return [alias, row[path] ?? null];
}

function matches(row, filters) {
  return filters.every(([col, test]) => {
    const value = row[col];
    if (test === "not.is.null") return value !== undefined && value !== null;
    if (test === "is.null") return value === undefined || value === null;
    if (test === "is.true") return value === true;
    if (test.startsWith("eq.")) return String(value) === test.slice(3);
    throw new Error(`the stand-in does not filter ${col}=${test}`);
  });
}

export function world() {
  process.env.SUPABASE_URL = SUPABASE_URL;
  process.env.SUPABASE_SECRET_KEY = "secret";
  delete process.env.PUBLIC_ORIGIN;
  const tables = { relay_tabs: [], oauth_tokens: [] };
  const self = {
    /// Every request, "METHOD table?query".
    calls: [],
    /// What each write sent, {table, body}.
    written: [],
    /// An access token for [owner]'s account.
    connect(owner) {
      const token = `bwa_${randomBytes(32).toString("base64url").slice(0, 43)}`;
      tables.oauth_tokens.push({
        hash: createHash("sha256").update(token).digest("hex"), kind: "access",
        expires_at: new Date(Date.now() + 3600_000).toISOString(),
        grant: { id: `grant-${owner}`, owner, resource: `${ORIGIN}/api/mcp`, client_name: "test",
          redirect_uri: "", client_info: {}, channel: null, used_at: new Date().toISOString() },
      });
      return token;
    },
    /// A tab's row: open and seen just now unless [row] says otherwise.
    tab(row) {
      const now = new Date().toISOString();
      tables.relay_tabs.push({ channel: randomBytes(16).toString("hex"), seen_at: now, instance: "instance-1",
        visible: true, open: true, owner: null, tab: "abcd", model: "a model", used_at: now, hello: null, ...row });
    },
    /// One MCP request through the handler, as Claude signed in sends it:
    /// the JSON-RPC answer.
    async ask(token, method, params = {}) {
      const { default: handle } = await import("../../../api/mcp.js");
      let json = null;
      const response = {
        setHeader: () => response,
        status: () => response,
        json: (body) => { json = body; return response; },
        end: () => response,
      };
      await handle({
        method: "POST", query: {},
        headers: { host: new URL(ORIGIN).host, authorization: `Bearer ${token}`, accept: "application/json" },
        body: { jsonrpc: "2.0", id: 1, method, params },
      }, response);
      return json;
    },
  };
  globalThis.fetch = async (input, init = {}) => {
    const url = new URL(String(input));
    const method = (init.method || "GET").toUpperCase();
    if (url.origin !== SUPABASE_URL) throw new TypeError(`nothing here answers ${url.origin}`);
    const table = url.pathname.replace("/rest/v1/", "");
    self.calls.push(`${method} ${table}${url.search}`);
    if (method !== "GET") {
      self.written.push({ table, body: JSON.parse(String(init.body || "null")) });
      return new Response("", { status: 201 });
    }
    const filters = [];
    let select = "*";
    let limit = Infinity;
    for (const [key, value] of url.searchParams) {
      if (key === "select") select = value;
      else if (key === "limit") limit = Number(value);
      else if (key !== "order") filters.push([key, value]);
    }
    if (table === "oauth_tokens") {
      const rows = tables.oauth_tokens.filter((row) => matches(row, filters));
      return new Response(JSON.stringify(rows.map((row) => ({ expires_at: row.expires_at, grant: row.grant }))));
    }
    const rows = (tables[table] || []).filter((row) => matches(row, filters))
      .sort((a, b) => String(b.seen_at || "").localeCompare(String(a.seen_at || ""))).slice(0, limit)
      .map((row) => (select === "*" ? row : Object.fromEntries(select.split(",").map((one) => column(row, one)))));
    return new Response(JSON.stringify(kept(rows)));
  };
  return self;
}
