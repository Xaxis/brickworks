// The database, as the server: PostgREST with the project's secret key.
//
// Row level security keeps every other key out of the relay's and the
// connector's tables (supabase/relay.sql, supabase/oauth.sql), so this is
// the only way in to them. Shared by the relay (api/mcp.js) and the
// connector's sign-in (api/oauth.js); deploy.sh puts a copy beside each.

export function dbConfigured() {
  return Boolean(process.env.SUPABASE_URL && process.env.SUPABASE_SECRET_KEY);
}

/// fetch, for one call to the project that names itself when it fails:
/// [what] is its verb and its table or bucket ("storage POST png"), never a
/// row or a file's name. Given up after [seconds], its answer's reading
/// included, it throws "<what>: no answer in <seconds> s"; never reaching
/// the project, "<what>: not reached". A bare abort says only "The
/// operation was aborted due to timeout", which is all seven refused
/// publishes left in the log on 2026-11-02, when Supabase's storage took
/// up to 40 s a write (sharetime).
export async function reach(what, seconds, url, init = {}) {
  const deadline = new AbortController();
  setTimeout(() => deadline.abort(new Error(`${what}: no answer in ${seconds} s`)), seconds * 1000).unref?.();
  try {
    return await fetch(url, { ...init, signal: deadline.signal });
  } catch (trouble) {
    if (deadline.signal.aborted) throw deadline.signal.reason;
    throw new Error(`${what}: not reached (${trouble?.cause?.code || trouble?.message || trouble})`);
  }
}

/// [read], a lookup beside what was asked for (a count, a mark, a credit,
/// what a model is based on), or null when it fails: the answer it is part
/// of still goes out with that field unknown, and the failure is logged by
/// the name db() gives it ("share: database GET model_stats: 555"). One
/// read of a build count failing took a whole shared model down with it
/// (rel-m251, 2026-11-03). Never for what was asked for itself: that fails.
export function orUnknown(where, read) {
  return Promise.resolve(read).catch((trouble) => {
    console.error(`${where}: ${String(trouble?.message || trouble).slice(0, 160)}`);
    return null;
  });
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
  const what = `database ${method} ${path.split("?")[0]}`;
  const answer = await reach(what, 15, `${base}/rest/v1/${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!answer.ok) throw new Error(`${what}: ${answer.status}`);
  const text = await answer.text();
  return text ? JSON.parse(text) : null;
}
