// A table the live project does not have yet, held in this process, for
// proving the code that reads and writes it before its SQL is applied.
//
//   node tools/web/relay_server.mjs 8790 --hold=share_versions
//
// The functions under api/ talk to Supabase's PostgREST with fetch. With
// --hold, the relay server's fetch answers requests for the named tables
// from memory instead, the way PostgREST would, and sends every other
// request to the real project as before: the accounts, the models' rows and
// their files are the real ones. What a held table is made of, and refuses,
// is proven against the real database by its file's dry run
// (tools/apply_sql.mjs --dry --try=FILE), which rolls back.
//
// Only what the functions ask of these tables: eq. and in. filters, select
// of named columns, order by one column, limit; insert of one row or
// several, with the table's own refusals (TABLES below); update and delete
// by filter. Kept for the life of the process.
//
// A held table whose file also changes the database's functions says what
// they would answer, as the file makes them (TABLES[...].rpc): the real
// function is asked, and its answer is given what the file adds. For
// share_tests (supabase/tested.sql), the gallery's cards say whether each is
// marked Tested, and Tested only lists those that are. Paged after the
// filter rather than in the database, which the few models of a flow never
// notice; the file's own paging is proven by its dry run.

/// [ids]' newest versions, from the real share_versions: id -> n.
async function newestOf(real, base, headers, ids) {
  if (ids.length === 0) return new Map();
  const answer = await real(`${base}/rest/v1/share_versions?model=in.(${ids.join(",")})&select=model,n`, { headers });
  const out = new Map();
  for (const one of answer.ok ? await answer.json() : []) out.set(one.model, Math.max(out.get(one.model) || 0, one.n));
  return out;
}

/// Whether [id] is marked Tested by [rows], as model_tested says.
const testedBy = (rows, newest, id) => rows.some((row) => row.model === id && row.n === (newest.get(id) ?? 1)
  && row.passed === true && !row.cleared_at);

const TESTS = ["stands", "steps", "parts", "whole"];

const TABLES = {
  // supabase/tested.sql
  share_tests: {
    key: ["model", "n"],
    // Its version must be a row of share_versions, as the foreign key says
    // (by its model: the dry run proves the pair).
    parent: { column: "model", table: "share_versions", on: "model" },
    defaults: () => ({ at: new Date().toISOString(), by: "app", cleared_at: null, cleared_why: null }),
    check(row) {
      if (!Number.isInteger(row.n) || row.n < 1 || row.n > 100000) return "share_tests_n_check";
      if (row.by !== "app") return "share_tests_by_check";
      if (!/^[0-9]{1,4}\.[0-9]{1,4}\.[0-9]{1,6}([-+.][0-9A-Za-z.-]{1,40})?$/.test(String(row.app))) return "share_tests_app_check";
      if (!/^[0-9a-f]{64}$/.test(String(row.file_hash))) return "share_tests_file_hash_check";
      if (!Number.isInteger(row.parts) || row.parts < 1 || row.parts > 200000) return "share_tests_parts_check";
      if (!Number.isInteger(row.steps) || row.steps < 1 || row.steps > 200000) return "share_tests_steps_check";
      if (!row.tests || typeof row.tests !== "object" || !TESTS.every((name) => name in row.tests)
          || JSON.stringify(row.tests).length > 8192) return "share_tests_tests_check";
      if (row.passed !== TESTS.every((name) => row.tests[name]?.ok === true)) return "share_tests_check";
      if (row.cleared_why !== null && (typeof row.cleared_why !== "string" || row.cleared_why.length < 1
          || row.cleared_why.length > 280)) return "share_tests_cleared_why_check";
      return "";
    },
    rpc: {
      async directory_models(real, base, url, init, rows) {
        const query = JSON.parse(String(init.body || "{}")).query || {};
        const wanted = query.tested === true;
        const asked = wanted ? { ...query, size: 49, skip: 0 } : query;
        const answer = await real(url, { ...init, body: JSON.stringify({ query: asked }) });
        if (!answer.ok) return answer;
        let cards = await answer.json();
        const newest = await newestOf(real, base, init.headers, cards.map((card) => card.id));
        cards = cards.map((card) => ({ ...card, tested: testedBy(rows, newest, card.id) }));
        if (wanted) {
          const skip = Number(query.skip) || 0;
          cards = cards.filter((card) => card.tested).slice(skip, skip + (Number(query.size) || 25));
        }
        return new Response(JSON.stringify(cards), { status: 200, headers: { "content-type": "application/json" } });
      },
      async directory_model(real, base, url, init, rows) {
        const answer = await real(url, init);
        if (!answer.ok) return answer;
        const page = await answer.json();
        if (!page || typeof page !== "object") return new Response(JSON.stringify(page), { status: 200 });
        const newest = await newestOf(real, base, init.headers, [page.id]);
        return new Response(JSON.stringify({ ...page, tested: testedBy(rows, newest, page.id) }),
          { status: 200, headers: { "content-type": "application/json" } });
      },
    },
  },
  // supabase/versions.sql
  share_versions: {
    key: ["model", "n"],
    // Its model must be a row of shared_models, as the foreign key says.
    parent: { column: "model", table: "shared_models", on: "id" },
    defaults: () => ({ at: new Date().toISOString(), note: null, steps: null, has_image: false,
      changes: null, first_changed: null, remixed_from_version: null }),
    check(row) {
      if (!Number.isInteger(row.n) || row.n < 1 || row.n > 100000) return "share_versions_n_check";
      if (row.note !== null && (typeof row.note !== "string" || row.note.length < 1 || row.note.length > 280)) {
        return "share_versions_note_check";
      }
      if (!Number.isInteger(row.parts) || row.parts < 1 || row.parts > 200000) return "share_versions_parts_check";
      if (row.steps !== null && !(Number.isInteger(row.steps) && row.steps >= 1)) return "share_versions_steps_check";
      if (!Number.isInteger(row.bytes) || row.bytes < 1 || row.bytes > 2097152) return "share_versions_bytes_check";
      if (row.changes !== null && (typeof row.changes !== "object" || Array.isArray(row.changes))) {
        return "share_versions_changes_check";
      }
      if (row.first_changed !== null && !(Number.isInteger(row.first_changed) && row.first_changed >= 1)) {
        return "share_versions_first_changed_check";
      }
      return "";
    },
  },
};

const held = new Map();

/// Answer [url] for a held table, or null for anything else.
async function answer(real, base, url, init = {}) {
  const at = url.indexOf("/rest/v1/");
  if (at < 0 || !url.startsWith(base)) return null;
  const [path, search = ""] = url.slice(at + 9).split("?");
  // A function a held table's file changes: asked of the database, and its
  // answer given what the file adds.
  if (path.startsWith("rpc/")) {
    for (const [name, table] of Object.entries(TABLES)) {
      const said = held.has(name) && table.rpc?.[path.slice(4)];
      if (said) return said(real, base, url, init, held.get(name));
    }
    return null;
  }
  if (!held.has(path)) return null;
  const table = TABLES[path];
  const rows = held.get(path);
  const params = new URLSearchParams(search);
  const method = String(init.method || "GET").toUpperCase();
  const json = (status, value) => new Response(value === undefined ? null : JSON.stringify(value),
    { status, headers: { "content-type": "application/json" } });

  const filters = [];
  for (const [column, said] of params) {
    if (["select", "order", "limit"].includes(column)) continue;
    const eq = /^eq\.(.*)$/.exec(said);
    const among = /^in\.\((.*)\)$/.exec(said);
    if (eq) filters.push((row) => String(row[column]) === eq[1]);
    else if (among) filters.push((row) => among[1].split(",").includes(String(row[column])));
    else return json(400, { message: `held table: no filter like ${said}` });
  }
  const chosen = () => rows.filter((row) => filters.every((test) => test(row)));

  if (method === "GET") {
    let out = chosen();
    const order = params.get("order");
    if (order) {
      const [column, way = "asc"] = order.split(".");
      out = [...out].sort((a, b) => (a[column] < b[column] ? -1 : a[column] > b[column] ? 1 : 0) * (way === "desc" ? -1 : 1));
    }
    if (params.has("limit")) out = out.slice(0, Number(params.get("limit")));
    const select = params.get("select");
    if (select && select !== "*") {
      const columns = select.split(",");
      out = out.map((row) => Object.fromEntries(columns.map((column) => [column, row[column] ?? null])));
    }
    return json(200, out);
  }
  if (method === "POST") {
    const given = JSON.parse(String(init.body || "null"));
    for (const one of Array.isArray(given) ? given : [given]) {
      const row = { ...table.defaults(), ...one };
      const broken = table.check(row);
      if (broken) return json(400, { code: "23514", message: `violates check constraint "${broken}"` });
      if (rows.some((other) => table.key.every((column) => other[column] === row[column]))) {
        return json(409, { code: "23505", message: `duplicate key value violates unique constraint "${path}_pkey"` });
      }
      const { column, table: parentTable, on } = table.parent;
      const parent = await real(`${base}/rest/v1/${parentTable}?${on}=eq.${encodeURIComponent(row[column])}&select=${on}`,
        { headers: init.headers });
      if (!parent.ok || (await parent.json()).length === 0) {
        return json(409, { code: "23503", message: `violates foreign key constraint "${path}_${column}_fkey"` });
      }
      rows.push(row);
    }
    return new Response(null, { status: 201 });
  }
  if (method === "PATCH") {
    if (filters.length === 0) return json(400, { message: "held table: an update names its rows" });
    const given = JSON.parse(String(init.body || "{}"));
    const changed = [];
    for (const row of chosen()) {
      const after = { ...row, ...given };
      const broken = table.check(after);
      if (broken) return json(400, { code: "23514", message: `violates check constraint "${broken}"` });
      changed.push([row, after]);
    }
    for (const [row, after] of changed) Object.assign(row, after);
    const wants = String(init.headers?.prefer || "").includes("return=representation");
    return wants ? json(200, changed.map(([row]) => ({ ...row }))) : new Response(null, { status: 204 });
  }
  if (method === "DELETE") {
    if (filters.length === 0) return json(400, { message: "held table: a delete names its rows" });
    const going = new Set(chosen());
    held.set(path, rows.filter((row) => !going.has(row)));
    return new Response(null, { status: 204 });
  }
  return json(405, { message: `held table: no ${method}` });
}

/// Hold [names] in this process: fetch answers for them from here.
export function hold(names) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  for (const name of names) {
    if (!TABLES[name]) throw new Error(`held_tables: no table ${name} to hold`);
    held.set(name, []);
  }
  const real = globalThis.fetch.bind(globalThis);
  globalThis.fetch = async (url, init) => (await answer(real, base, String(url), init)) ?? real(url, init);
}

/// What a held table has now, for a check to read (relay_server's
/// /__held/<table>).
export function rowsOf(name) {
  return held.has(name) ? held.get(name).map((row) => ({ ...row })) : null;
}
