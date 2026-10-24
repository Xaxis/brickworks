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
// Only what the functions ask of these tables: eq., gt. and in. filters, select
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
//
// For supabase/builds.sql: model_builds (and count_build, and the builds a
// card, a model's page and model_stats say), build_photos (with the file's
// trigger: 13 or over, three on a model) and report_photos; and, held with
// build_photos, the file's two storage buckets, in memory too, with the
// upload a page sends straight to storage signed for one path and sent to
// this server (/__held_storage/upload/...), as Supabase's signed upload
// takes it. What they hold is at /__held_storage/list/<bucket> and
// /__held_storage/file/<bucket>/<path>. Several held files' functions are
// layered, each adding what its file adds.
//
// For supabase/avatars.sql: profile_avatars (a person's own picture, with
// the profile's trigger: 13 or over) and, held with it, the avatars bucket;
// profile_choices (whether a profile shows the models its owner liked); and
// the file's three functions answered here whole over the real project:
// avatars_of (by the real people, as shown_publicly says), profile_likes
// (the real likes, newest first, each the real directory_model's card) and
// profile_likes_count.

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

const jsonReply = (status, value) => new Response(value === undefined ? null : JSON.stringify(value),
  { status, headers: { "content-type": "application/json" } });

/// How many devices built [id], as model_stats.builds would say.
const buildsOf = (rows, id) => rows.filter((row) => row.model === id).length;

/// What builds.sql adds to the gallery's cards: their builds, and its sort.
async function withBuilds(real, base, url, init, rows) {
  const query = JSON.parse(String(init.body || "{}")).query || {};
  const sorted = query.sort === "builds";
  const asked = sorted ? { ...query, sort: "newest", size: 49, skip: 0 } : query;
  const answer = await real(url, { ...init, body: JSON.stringify({ query: asked }) });
  if (!answer.ok) return answer;
  let cards = (await answer.json()).map((card) => ({ ...card, builds: buildsOf(rows, card.id) }));
  if (sorted) {
    const skip = Number(query.skip) || 0;
    cards = cards.map((card, at) => [card, at]).sort((a, b) => b[0].builds - a[0].builds || a[1] - b[1])
      .map(([card]) => card).slice(skip, skip + (Number(query.size) || 25));
  }
  return jsonReply(200, cards);
}

/// The profile's trigger (trust.sql trust_guard_person): 13 or over, asked
/// as the API asks it.
async function overThirteen(row, rows, base, headers) {
  const age = await globalThis.fetch(`${base}/rest/v1/rpc/age_of`, { method: "POST",
    headers: { ...headers, "content-type": "application/json" }, body: JSON.stringify({ account: row.account }) });
  const said = age.ok ? await age.json() : null;
  return said && said.over_13 === true ? "" : "brickworks: a public profile is for accounts 13 or over";
}

/// The models [whose] liked that the gallery shows, newest like first, each
/// as the real directory_model gives its card (avatars.sql profile_likes).
async function likedCards(real, base, headers, whose, tests) {
  if (!/^[0-9a-f-]{36}$/.test(String(whose))) return [];
  const got = await real(`${base}/rest/v1/model_likes?account=eq.${whose}&select=model,at&order=at.desc&limit=500`, { headers });
  const likes = got.ok ? await got.json() : [];
  if (!likes.length) return [];
  const ids = likes.map((one) => one.model);
  const flags = await real(`${base}/rest/v1/shared_models?id=in.(${ids.join(",")})&select=id,published,listed,barred,test,owner`, { headers });
  const shown = new Map((flags.ok ? await flags.json() : []).filter((m) => m.published && m.listed && !m.barred && (tests || !m.test))
    .map((m) => [m.id, m]));
  const cards = [];
  for (const id of ids.filter((one) => shown.has(one))) {
    const page = await real(`${base}/rest/v1/rpc/directory_model`, { method: "POST",
      headers: { ...headers, "content-type": "application/json" }, body: JSON.stringify({ model_id: id }) });
    const card = page.ok ? await page.json() : null;
    if (card && card.id) cards.push(card);
  }
  return cards;
}

const TABLES = {
  // supabase/builds.sql
  model_builds: {
    key: ["model", "device"],
    parents: [{ column: "model", table: "shared_models", on: "id" }],
    defaults: () => ({ at: new Date().toISOString() }),
    check(row) {
      return /^[0-9a-f]{32}$/.test(String(row.device)) ? "" : "model_builds_device_check";
    },
    rpc: {
      // A new function, answered here whole, as the file makes it.
      async count_build(real, base, url, init, rows) {
        const { model_id: model, device_key: device } = JSON.parse(String(init.body || "{}"));
        if (!/^[0-9a-f]{32}$/.test(String(device))) {
          return jsonReply(400, { code: "23514", message: 'violates check constraint "model_builds_device_check"' });
        }
        const found = await real(`${base}/rest/v1/shared_models?id=eq.${encodeURIComponent(model)}&published=is.true&select=id`,
          { headers: init.headers });
        if (!found.ok || (await found.json()).length === 0) return jsonReply(200, false);
        if (rows.some((row) => row.model === model && row.device === device)) return jsonReply(200, false);
        rows.push({ model, device, at: new Date().toISOString() });
        return jsonReply(200, true);
      },
      directory_models: withBuilds,
      async directory_model(real, base, url, init, rows) {
        const answer = await real(url, init);
        if (!answer.ok) return answer;
        const page = await answer.json();
        if (!page || typeof page !== "object") return jsonReply(200, page);
        return jsonReply(200, { ...page, builds: buildsOf(rows, page.id),
          remixes_listed: (page.remixes_listed || []).map((card) => ({ ...card, builds: buildsOf(rows, card.id) })) });
      },
    },
    // model_stats' new column, read alone: model_stats?model=eq.X&select=builds.
    column: { table: "model_stats", select: "builds", value: (rows, model) => buildsOf(rows, model) },
  },
  build_photos: {
    key: ["id"],
    parents: [{ column: "model", table: "shared_models", on: "id" }],
    defaults: () => ({ at: new Date().toISOString(), words: null, hidden_at: null, removed_at: null, removed_why: null }),
    check(row) {
      if (!/^[A-Za-z0-9]{10}$/.test(String(row.id))) return "build_photos_id_check";
      if (row.words !== null && (typeof row.words !== "string" || row.words.length < 1 || row.words.length > 140)) {
        return "build_photos_words_check";
      }
      if (!Number.isInteger(row.width) || row.width < 1 || row.width > 1600) return "build_photos_width_check";
      if (!Number.isInteger(row.height) || row.height < 1 || row.height > 1600) return "build_photos_height_check";
      if (!Number.isInteger(row.bytes) || row.bytes < 1 || row.bytes > 4194304) return "build_photos_bytes_check";
      if (!["jpeg", "png", "webp"].includes(row.was)) return "build_photos_was_check";
      return "";
    },
    // The file's trigger: 13 or over (asked as the API asks it, so the
    // trust stand-in answers until trust.sql is applied), three on a model.
    async guard(row, rows, base, headers) {
      const age = await globalThis.fetch(`${base}/rest/v1/rpc/age_of`, { method: "POST",
        headers: { ...headers, "content-type": "application/json" }, body: JSON.stringify({ account: row.account }) });
      const said = age.ok ? await age.json() : null;
      if (!said || said.over_13 !== true) return "brickworks: a photo of a build is for accounts 13 or over";
      if (rows.filter((one) => one.account === row.account && one.model === row.model && !one.removed_at).length >= 3) {
        return "brickworks: three photos of a model at most";
      }
      return "";
    },
  },
  report_photos: {
    key: ["report"],
    parents: [{ column: "report", table: "reports", on: "id" }, { column: "photo", table: "build_photos", on: "id" }],
    defaults: () => ({}),
    check: (row) => (Number.isInteger(row.report) && typeof row.photo === "string" ? "" : "report_photos_check"),
  },
  // supabase/profile_shows.sql: what a profile shows besides its name,
  // one row an account, written as PostgREST's upsert writes it.
  profile_shows: {
    key: ["account"],
    parents: [],
    defaults: () => ({ links: [], banner: null, pins: [], updated_at: new Date().toISOString() }),
    check(row) {
      const link = /^https:\/\/[^/?#@\s]+\.[^/?#@\s]+([/?#]\S*)?$/;
      if (!Array.isArray(row.links) || row.links.length > 2
        || row.links.some((one) => typeof one !== "string" || one.length < 12 || one.length > 200 || !link.test(one))) {
        return "profile_shows_links_check";
      }
      if (!Array.isArray(row.pins) || row.pins.length > 3 || new Set(row.pins).size !== row.pins.length
        || row.pins.some((id) => !/^[A-Za-z0-9]{10}$/.test(String(id)))) return "profile_shows_pins_check";
      if (row.banner !== null && !/^[A-Za-z0-9]{10}$/.test(String(row.banner))) return "profile_shows_banner_check";
      return "";
    },
    // The profile's trigger (trust.sql trust_guard_person): 13 or over.
    async guard(row, rows, base, headers) {
      const age = await globalThis.fetch(`${base}/rest/v1/rpc/age_of`, { method: "POST",
        headers: { ...headers, "content-type": "application/json" }, body: JSON.stringify({ account: row.account }) });
      const said = age.ok ? await age.json() : null;
      return said && said.over_13 === true ? "" : "brickworks: a public profile is for accounts 13 or over";
    },
  },
  // supabase/avatars.sql: a person's own picture, one row an account.
  profile_avatars: {
    key: ["account"],
    parents: [],
    defaults: () => ({ at: new Date().toISOString(), removed_at: null, removed_why: null }),
    check(row) {
      if (!/^[A-Za-z0-9]{10}$/.test(String(row.id))) return "profile_avatars_id_check";
      if (!Number.isInteger(row.side) || row.side < 120 || row.side > 400) return "profile_avatars_side_check";
      if (!Number.isInteger(row.bytes) || row.bytes < 1 || row.bytes > 1048576) return "profile_avatars_bytes_check";
      if (!["jpeg", "png", "webp"].includes(row.was)) return "profile_avatars_was_check";
      if (row.removed_why !== null && (typeof row.removed_why !== "string" || row.removed_why.length < 1
        || row.removed_why.length > 200)) return "profile_avatars_removed_why_check";
      return "";
    },
    guard: overThirteen,
    rpc: {
      // Which of the handles show a picture of their own now.
      async avatars_of(real, base, url, init, rows) {
        const handles = (JSON.parse(String(init.body || "{}")).handles || []).filter((one) => /^[a-z0-9-]{3,24}$/.test(String(one)));
        if (!handles.length) return jsonReply(200, []);
        const answer = await real(`${base}/rest/v1/people?handle=in.(${handles.join(",")})&select=account,handle`, { headers: init.headers });
        const people = answer.ok ? await answer.json() : [];
        const out = [];
        for (const person of people) {
          const row = rows.find((one) => one.account === person.account && !one.removed_at);
          if (!row) continue;
          const shown = await real(`${base}/rest/v1/rpc/shown_publicly`, { method: "POST",
            headers: { ...init.headers, "content-type": "application/json" }, body: JSON.stringify({ account: person.account }) });
          if (shown.ok && (await shown.json()) === true) out.push({ handle: person.handle, avatar: row.id });
        }
        return jsonReply(200, out);
      },
    },
  },
  // supabase/avatars.sql: whether a profile shows the models its owner liked.
  profile_choices: {
    key: ["account"],
    parents: [],
    defaults: () => ({ shows_likes: false, updated_at: new Date().toISOString() }),
    check: (row) => (typeof row.shows_likes === "boolean" ? "" : "profile_choices_shows_likes_check"),
    guard: overThirteen,
    rpc: {
      async profile_likes(real, base, url, init) {
        const { whose, size = 25, skip = 0, tests = false } = JSON.parse(String(init.body || "{}"));
        const cards = await likedCards(real, base, init.headers, whose, tests);
        return jsonReply(200, cards.slice(Math.max(0, skip), Math.max(0, skip) + Math.min(Math.max(size, 1), 49)));
      },
      async profile_likes_count(real, base, url, init) {
        const { whose, tests = false } = JSON.parse(String(init.body || "{}"));
        return jsonReply(200, (await likedCards(real, base, init.headers, whose, tests)).length);
      },
    },
  },
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
  // supabase/together.sql: building together (api/together.js). The
  // sessions, their numbered changes and who is in each, with the file's
  // two functions answered here as it makes them: together_append numbers
  // a send after every change before it, refused for an ended session or
  // an author not in it, and together_sweep.
  together_sessions: {
    key: ["id"],
    parents: [],
    defaults: () => ({ title: "", last_seq: 0, created_at: new Date().toISOString(),
      changed_at: new Date().toISOString(), ended_at: null }),
    check(row) {
      if (!/^[0-9a-f]{64}$/.test(String(row.id))) return "together_sessions_id_check";
      if (String(row.title).length > 120) return "together_sessions_title_check";
      return "";
    },
  },
  together_people: {
    key: ["session", "account"],
    parents: [{ column: "session", table: "together_sessions", on: "id" }],
    defaults: () => ({ name: "", joined_at: new Date().toISOString(), seen_at: new Date().toISOString(),
      left_at: null, removed_at: null }),
    check(row) {
      return String(row.name).length > 40 ? "together_people_name_check" : "";
    },
  },
  together_ops: {
    key: ["session", "seq"],
    parents: [{ column: "session", table: "together_sessions", on: "id" }],
    defaults: () => ({ at: new Date().toISOString() }),
    check(row) {
      if (!/^[a-z0-9]{6,16}$/.test(String(row.client))) return "together_ops_client_check";
      if (!row.changes || typeof row.changes !== "object" || Array.isArray(row.changes)) return "together_ops_changes_check";
      return "";
    },
    rpc: {
      async together_append(real, base, url, init, rows) {
        const { p_session: id, p_author: author, p_client: client, p_ops: ops } = JSON.parse(String(init.body || "{}"));
        if (!Array.isArray(ops) || ops.length < 1 || ops.length > 500) {
          return jsonReply(400, { code: "22023", message: "brickworks: send between 1 and 500 changes" });
        }
        const session = (held.get("together_sessions") || []).find((one) => one.id === id && !one.ended_at);
        if (!session) return jsonReply(400, { code: "P0001", message: "brickworks: that session has ended", hint: "together:ended" });
        const member = (held.get("together_people") || []).some((one) => one.session === id && one.account === author
          && !one.removed_at);
        if (session.owner !== author && !member) {
          return jsonReply(400, { code: "P0001", message: "brickworks: not in this session", hint: "together:refused" });
        }
        const first = session.last_seq;
        session.last_seq += ops.length;
        session.changed_at = new Date().toISOString();
        ops.forEach((op, k) => rows.push({ session: id, seq: first + k + 1, author, client, cid: op.cid,
          changes: op.changes, at: new Date().toISOString() }));
        return jsonReply(200, ops.map((_, k) => first + k + 1));
      },
      async together_sweep() {
        return jsonReply(200, 0);
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
    // Each held file's say, layered: the innermost asks the database.
    const wrappers = Object.entries(TABLES).filter(([name, table]) => held.has(name) && table.rpc?.[path.slice(4)]);
    if (wrappers.length === 0) return null;
    let call = real;
    for (const [name, table] of wrappers) {
      const inner = call;
      call = (asked, given) => (asked === url ? table.rpc[path.slice(4)](inner, base, asked, given, held.get(name))
        : inner(asked, given));
    }
    return call(url, init);
  }
  // A held file's new column of a table that is not held, read alone.
  for (const [name, table] of Object.entries(TABLES)) {
    if (!held.has(name) || !table.column || path !== table.column.table) continue;
    const params = new URLSearchParams(search);
    const model = /^eq\.(.*)$/.exec(params.get("model") || "");
    if (params.get("select") === table.column.select && model && String(init.method || "GET").toUpperCase() === "GET") {
      return jsonReply(200, [{ [table.column.select]: table.column.value(held.get(name), model[1]) }]);
    }
  }
  if (!held.has(path)) return null;
  const table = TABLES[path];
  const rows = held.get(path);
  const params = new URLSearchParams(search);
  const method = String(init.method || "GET").toUpperCase();
  const json = jsonReply;

  const filters = [];
  for (const [column, said] of params) {
    if (["select", "order", "limit", "on_conflict"].includes(column)) continue;
    const eq = /^eq\.(.*)$/.exec(said);
    const among = /^in\.\((.*)\)$/.exec(said);
    const is = /^is\.(null|true|false)$/.exec(said);
    const above = /^gt\.(-?\d+)$/.exec(said);
    if (above) filters.push((row) => Number(row[column]) > Number(above[1]));
    else if (eq) filters.push((row) => String(row[column]) === eq[1]);
    else if (among) filters.push((row) => among[1].split(",").includes(String(row[column])));
    else if (is) filters.push((row) => (is[1] === "null" ? row[column] === null || row[column] === undefined
      : row[column] === (is[1] === "true")));
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
    const merging = params.has("on_conflict") && String(init.headers?.prefer || "").includes("resolution=merge-duplicates");
    for (const one of Array.isArray(given) ? given : [given]) {
      const before = merging ? rows.find((other) => table.key.every((column) => other[column] === one[column])) : null;
      const row = { ...table.defaults(), ...(before || {}), ...one };
      const broken = table.check(row);
      if (broken) return json(400, { code: "23514", message: `violates check constraint "${broken}"` });
      if (!before && rows.some((other) => table.key.every((column) => other[column] === row[column]))) {
        return json(409, { code: "23505", message: `duplicate key value violates unique constraint "${path}_pkey"` });
      }
      for (const { column, table: parentTable, on } of table.parents || [table.parent]) {
        const there = held.has(parentTable)
          ? held.get(parentTable).some((other) => String(other[on]) === String(row[column]))
          : await (async () => {
            const parent = await real(`${base}/rest/v1/${parentTable}?${on}=eq.${encodeURIComponent(row[column])}&select=${on}`,
              { headers: init.headers });
            return parent.ok && (await parent.json()).length > 0;
          })();
        if (!there) return json(409, { code: "23503", message: `violates foreign key constraint "${path}_${column}_fkey"` });
      }
      const refused = table.guard ? await table.guard(row, rows, base, init.headers) : "";
      if (refused) return json(400, { code: "P0001", message: refused });
      // An upsert (on_conflict, resolution=merge-duplicates): the row there
      // takes the columns given, as PostgREST's insert ... on conflict does.
      if (before) Object.assign(before, one);
      else rows.push(row);
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

// ---------------------------------------------------------------------------
// Storage: builds.sql's two buckets, held with build_photos.

const BUCKETS = {
  "build-photo-uploads": { most: 8388608, types: ["image/jpeg", "image/png", "image/webp"], with: "build_photos" },
  "build-photos": { most: 4194304, types: ["image/jpeg"], with: "build_photos" },
  // supabase/avatars.sql
  avatars: { most: 1048576, types: ["image/jpeg"], with: "profile_avatars" },
};
/// Whether [bucket] is held here: the table it comes with is.
const bucketHeld = (bucket) => Boolean(BUCKETS[bucket]) && held.has(BUCKETS[bucket].with);
const files = new Map(Object.keys(BUCKETS).map((bucket) => [bucket, new Map()]));
const tickets = new Map();
let here = "";

/// A storage request for a held bucket, answered from memory; null else.
async function storage(url, init = {}) {
  if (!Object.keys(BUCKETS).some(bucketHeld)) return null;
  const at = url.indexOf("/storage/v1/object/");
  if (at < 0) return null;
  const rest = url.slice(at + 19).split("?")[0];
  const method = String(init.method || "GET").toUpperCase();
  const signing = /^upload\/sign\/([a-z-]+)\/(.+)$/.exec(rest);
  if (signing && bucketHeld(signing[1]) && method === "POST") {
    const token = Math.random().toString(36).slice(2) + Date.now().toString(36);
    tickets.set(token, { bucket: signing[1], name: decodeURIComponent(signing[2]) });
    return jsonReply(200, { url: `${here}/__held_storage/upload/${signing[1]}/${signing[2]}?token=${token}` });
  }
  const listing = /^list\/([a-z-]+)$/.exec(rest);
  if (listing && bucketHeld(listing[1])) {
    const { prefix = "" } = JSON.parse(String(init.body || "{}"));
    const names = [...files.get(listing[1]).keys()].filter((name) => name.startsWith(prefix)).map((name) => name.slice(prefix.length));
    const folders = [...new Set(names.filter((name) => name.includes("/")).map((name) => name.split("/")[0]))];
    return jsonReply(200, [...folders.map((name) => ({ name, id: null })),
      ...names.filter((name) => !name.includes("/")).map((name) => ({ name, id: name,
        updated_at: files.get(listing[1]).get(prefix + name).at }))]);
  }
  const whole = /^([a-z-]+)$/.exec(rest);
  if (whole && bucketHeld(whole[1]) && method === "DELETE") {
    const { prefixes = [] } = JSON.parse(String(init.body || "{}"));
    for (const name of prefixes) files.get(whole[1]).delete(name);
    return jsonReply(200, prefixes.map((name) => ({ name })));
  }
  const one = /^([a-z-]+)\/(.+)$/.exec(rest);
  if (!one || !bucketHeld(one[1])) return null;
  const name = decodeURIComponent(one[2]);
  if (method === "GET") {
    const file = files.get(one[1]).get(name);
    return file ? new Response(file.bytes, { status: 200, headers: { "content-type": file.type } })
      : jsonReply(400, { statusCode: "404", error: "not_found", message: "Object not found" });
  }
  if (method === "POST" || method === "PUT") {
    const bytes = Buffer.from(await new Response(init.body).arrayBuffer());
    const type = String((init.headers || {})["content-type"] || "");
    const refused = put(one[1], name, bytes, type);
    return refused || jsonReply(200, { Key: `${one[1]}/${name}` });
  }
  return null;
}

/// A file put in a held bucket, refused as the bucket refuses: too big, or
/// a type it does not take.
function put(bucket, name, bytes, type) {
  if (bytes.length > BUCKETS[bucket].most) return jsonReply(413, { statusCode: "413", error: "Payload too large" });
  if (!BUCKETS[bucket].types.includes(type.split(";")[0].trim())) {
    return jsonReply(415, { statusCode: "415", error: "invalid_mime_type" });
  }
  files.get(bucket).set(name, { bytes, type, at: new Date().toISOString() });
  return null;
}

/// This server's own storage addresses (relay_server.mjs): the signed
/// upload a page sends, and what a check reads. {status, type, body} or null.
export function storageRoute(url, method, headers, body) {
  if (!Object.keys(BUCKETS).some(bucketHeld)) return null;
  const upload = /^\/__held_storage\/upload\/([a-z-]+)\/(.+)$/.exec(url.pathname);
  if (upload && method === "PUT") {
    const ticket = tickets.get(url.searchParams.get("token") || "");
    const name = decodeURIComponent(upload[2]);
    if (!ticket || ticket.bucket !== upload[1] || ticket.name !== name) {
      return { status: 400, type: "application/json", body: JSON.stringify({ error: "invalid signature" }) };
    }
    tickets.delete(url.searchParams.get("token"));
    const refused = put(upload[1], name, body, String(headers["content-type"] || ""));
    return refused ? { status: refused.status, type: "application/json", body: JSON.stringify({ error: "refused" }) }
      : { status: 200, type: "application/json", body: JSON.stringify({ Key: `${upload[1]}/${name}` }) };
  }
  const listed = /^\/__held_storage\/list\/([a-z-]+)$/.exec(url.pathname);
  if (listed && bucketHeld(listed[1])) {
    return { status: 200, type: "application/json", body: JSON.stringify([...files.get(listed[1]).entries()]
      .map(([name, file]) => ({ name, bytes: file.bytes.length, type: file.type, at: file.at }))) };
  }
  const read = /^\/__held_storage\/file\/([a-z-]+)\/(.+)$/.exec(url.pathname);
  if (read && bucketHeld(read[1])) {
    const file = files.get(read[1]).get(decodeURIComponent(read[2]));
    return file ? { status: 200, type: file.type, body: file.bytes } : { status: 404, type: "text/plain", body: "" };
  }
  return null;
}

/// Hold [names] in this process: fetch answers for them from here. [origin]
/// is this server's own address, for the uploads a page sends it.
export function hold(names, { origin = "" } = {}) {
  const base = String(process.env.SUPABASE_URL || "").replace(/\/+$/, "");
  here = origin;
  for (const name of names) {
    if (!TABLES[name]) throw new Error(`held_tables: no table ${name} to hold`);
    held.set(name, []);
  }
  const real = globalThis.fetch.bind(globalThis);
  globalThis.fetch = async (url, init) => (url && String(url).startsWith(base) ? await storage(String(url), init) : null)
    ?? (await answer(real, base, String(url), init)) ?? real(url, init);
}

/// What a held table has now, for a check to read (relay_server's
/// /__held/<table>).
export function rowsOf(name) {
  return held.has(name) ? held.get(name).map((row) => ({ ...row })) : null;
}
