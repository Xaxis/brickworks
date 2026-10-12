// The database, as the server: PostgREST with the project's secret key.
//
// Row level security keeps every other key out of the relay's and the
// connector's tables (supabase/relay.sql, supabase/oauth.sql), so this is
// the only way in to them. Shared by the relay (api/mcp.js) and the
// connector's sign-in (api/oauth.js); deploy.sh puts a copy beside each.

export function dbConfigured() {
  return Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SECRET_KEY);
}

/// One PostgREST request. Throws on anything but a success, naming the
/// table and the status and nothing else (no row ever ends up in a log).
export async function db(path, { method = "GET", body, prefer } = {}) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  const key = process.env.SUPABASE_SECRET_KEY;
  const headers = {
    apikey: key,
    authorization: `Bearer ${key}`,
    "content-type": "application/json",
  };
  if (prefer) headers.prefer = prefer;
  const answer = await fetch(`${base}/rest/v1/${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.timeout(15000),
  });
  if (!answer.ok) {
    throw new Error(`database ${method} ${path.split("?")[0]}: ${answer.status}`);
  }
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}
