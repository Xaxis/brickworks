// A mock Reddit, the checks' own (socialdesk, 2026-11-18; docs/SOCIAL_DESK.md):
// the desk's pool of tests (/admin?tests=1) talks to this instead of Reddit,
// so every part of the desk (connect, the inbox, reply, post, schedule and
// results) is proven end to end and nothing is ever sent from a real account.
//
// It answers the requests api/_social_reddit.js makes, in Reddit's own shapes
// (the archived reddit source's controllers, r2/r2/controllers/api.py,
// listingcontroller.py, apiv1/user.py, and the OAuth2 wiki): the token
// endpoint (an authorization code, a refresh, a revoke), and at the API host
// /api/v1/me, the inbox (comment and post replies, a username mention, a
// private message), /search, a community's rules and about, /api/submit,
// /api/comment and /api/info. It keeps nothing between requests, as a
// deployment's functions keep nothing: what it says is worked out from the
// request and the clock. A post's id carries the second it was made, so its
// score and comments grow as time passes, as a real post's would.
//
// It holds Reddit's own rules for a client: the app's id and secret (Basic),
// a bearer token it made, and a User-Agent in Reddit's form
// (<platform>:<app id>:<version> (by /u/<name>)); anything else is refused
// as Reddit refuses it. A community named nosuchsub does not exist.
//
// [calls] keeps every request in this process, for tests/fixtures/social:
// what was sent where, never a token.

export const MOCK_CLIENT = { id: "mock-client", secret: "mock-secret" };
export const MOCK_HANDLE = "brickworks_checks";
export const calls = [];

const REDDIT = "https://www.reddit.com";
const API = "https://oauth.reddit.com";
const UA = /^[a-z]+:[A-Za-z0-9._-]+:[A-Za-z0-9._-]+ \(by \/u\/[A-Za-z0-9_-]{3,20}\)$/;
const DAY = 86400;

const json = (status, body, headers = {}) => new Response(JSON.stringify(body), { status,
  headers: { "content-type": "application/json; charset=UTF-8", "x-ratelimit-used": "1", "x-ratelimit-remaining": "99",
    "x-ratelimit-reset": "300", ...headers } });
const random = (n) => Array.from(crypto.getRandomValues(new Uint8Array(n)), (b) => "abcdefghijklmnopqrstuvwxyz0123456789"[b % 36]).join("");
const slug = (title) => String(title).toLowerCase().replace(/[^a-z0-9]+/g, "_").replace(/^_|_$/g, "").slice(0, 40) || "post";

/// The same items every day, made at fixed times of the day before, so a
/// second look finds the same ones and adds nothing.
function inbox() {
  const day = Math.floor(Date.now() / 1000 / DAY) * DAY - DAY;
  const reply = (id, minutes, data) => ({ kind: "t1", data: { id, name: `t1_${id}`, created: day + minutes * 60,
    created_utc: day + minutes * 60, new: true, was_comment: true, dest: MOCK_HANDLE, first_message_name: null,
    replies: "", score: 1, distinguished: null, likes: null, num_comments: null, ...data } });
  return [
    { kind: "t4", data: { id: "mk4001", name: "t4_mk4001", author: "afol_anna", dest: MOCK_HANDLE,
      subject: "Printing instructions?", body: "Hi! Is there a way to print the building steps of a model I made?",
      body_html: null, created: day + 900 * 60, created_utc: day + 900 * 60, new: true, was_comment: false,
      first_message_name: null, context: "", subreddit: null, parent_id: null, replies: "", distinguished: null } },
    reply("mkc003", 840, { author: "studs_up", subject: "username mention", type: "username_mention",
      body: `u/${MOCK_HANDLE} does it do Technic gears and pins?`, subreddit: "LegoMOC", subreddit_name_prefixed: "r/LegoMOC",
      link_title: "Weekly MOC tools thread", parent_id: "t3_mkp003",
      context: "/r/LegoMOC/comments/mkp003/weekly_moc_tools_thread/mkc003/?context=3" }),
    reply("mkc002", 600, { author: "moc_maker", subject: "post reply", type: "post_reply",
      body: "The gallery is lovely. Can I put my own LDraw files in it?", subreddit: "lego", subreddit_name_prefixed: "r/lego",
      link_title: "A free LEGO CAD that runs in the browser", parent_id: "t3_mkp002",
      context: "/r/lego/comments/mkp002/a_free_lego_cad_that_runs_in_the_browser/mkc002/?context=3" }),
    reply("mkc001", 300, { author: "brick_fan_42", subject: "comment reply", type: "comment_reply",
      body: "Does it export to LDraw or Studio?", subreddit: "legodesign", subreddit_name_prefixed: "r/legodesign",
      link_title: "Designing a modular in the browser", parent_id: "t1_mkc000",
      context: "/r/legodesign/comments/mkp001/designing_a_modular_in_the_browser/mkc001/?context=3" }),
  ];
}

/// What a search across Reddit finds that names the site: one post by
/// somebody else.
function found() {
  const day = Math.floor(Date.now() / 1000 / DAY) * DAY - DAY;
  return [{ kind: "t3", data: { id: "mks001", name: "t3_mks001", author: "curious_builder", title: "Has anyone tried brickworks.diy?",
    selftext: "Saw it linked somewhere. A LEGO CAD in the browser, with physics?", subreddit: "lego",
    subreddit_name_prefixed: "r/lego", permalink: "/r/lego/comments/mks001/has_anyone_tried_brickworksdiy/",
    url: "https://www.reddit.com/r/lego/comments/mks001/has_anyone_tried_brickworksdiy/", created: day + 1000 * 60,
    created_utc: day + 1000 * 60, score: 12, num_comments: 4, upvote_ratio: 0.93, is_self: true, over_18: false } }];
}

const RULES = {
  lego: [
    ["Be civil", "Treat others with respect. No personal attacks, harassment or hate."],
    ["Self-promotion", "Promote your own content in moderation. Accounts that only post their own links will be removed."],
    ["No clone brands", "Posts about clone brands or knock-off sets are removed."],
  ],
  legodesign: [
    ["Your own designs", "Share designs you made yourself; say what software you used."],
    ["Tools are welcome", "Posts about design tools are allowed if you take part in the discussion."],
  ],
  legomoc: [
    ["Original MOCs only", "Post your own creations. Credit any designer you built from."],
    ["Instructions and links", "Links to instructions are fine in a comment; no link-only posts."],
    ["No spam", "No more than one post a day per account."],
  ],
};

function listing(children) {
  return { kind: "Listing", data: { after: null, before: null, dist: children.length, modhash: null, geo_filter: "", children } };
}

/// A post's id made now: "m", the second in base 36, and three random
/// letters, so /api/info can tell its age.
const madeId = () => `m${Math.floor(Date.now() / 1000).toString(36)}${random(3)}`;
function ageOf(id) {
  const born = /^m([0-9a-z]{6,7})[0-9a-z]{3}$/.exec(id);
  return born ? Math.max(0, Date.now() / 1000 - parseInt(born[1], 36)) : DAY;
}

/// The form a POST carries, as Reddit reads it.
function formOf(init) {
  const body = init?.body;
  if (body instanceof URLSearchParams) return body;
  return new URLSearchParams(typeof body === "string" ? body : "");
}

function basicOk(init) {
  const given = String(init?.headers?.authorization || init?.headers?.Authorization || "");
  return given === `Basic ${Buffer.from(`${MOCK_CLIENT.id}:${MOCK_CLIENT.secret}`).toString("base64")}`;
}

function bearerOk(init) {
  const given = String(init?.headers?.authorization || init?.headers?.Authorization || "");
  return /^bearer mocktoken-a-[a-z0-9]{24}$/i.test(given);
}

/// The mock's answer to [url] with [init], as Reddit would give it.
export async function mockReddit(url, init = {}) {
  const asked = new URL(String(url));
  const method = String(init.method || "GET").toUpperCase();
  const ua = String(init.headers?.["user-agent"] || init.headers?.["User-Agent"] || "");
  calls.push({ method, host: asked.host, path: asked.pathname });
  // Reddit's API wiki: a generic or missing agent is limited hard.
  if (!UA.test(ua)) return json(429, { message: "Too Many Requests", error: 429 });

  if (asked.origin === REDDIT && asked.pathname === "/api/v1/access_token" && method === "POST") {
    if (!basicOk(init)) return json(401, { message: "Unauthorized", error: 401 });
    const form = formOf(init);
    const grant = form.get("grant_type");
    if (grant === "authorization_code") {
      if (!/^mock-code-[a-z0-9]{8,32}$/.test(String(form.get("code") || ""))) return json(200, { error: "invalid_grant" });
      if (!/^https?:\/\/[^/]+\/admin\?/.test(String(form.get("redirect_uri") || ""))) return json(200, { error: "redirect_uri_mismatch" });
      return json(200, { access_token: `mocktoken-a-${random(24)}`, token_type: "bearer", expires_in: 3600,
        refresh_token: `mocktoken-r-${random(24)}`, scope: "identity history privatemessages read submit" });
    }
    if (grant === "refresh_token") {
      if (!/^mocktoken-r-[a-z0-9]{24}$/.test(String(form.get("refresh_token") || ""))) return json(400, { error: "invalid_grant" });
      return json(200, { access_token: `mocktoken-a-${random(24)}`, token_type: "bearer", expires_in: 3600,
        scope: "identity history privatemessages read submit" });
    }
    return json(400, { error: "unsupported_grant_type" });
  }
  if (asked.origin === REDDIT && asked.pathname === "/api/v1/revoke_token" && method === "POST") {
    return basicOk(init) ? new Response(null, { status: 204 }) : json(401, { message: "Unauthorized", error: 401 });
  }
  if (asked.origin !== API) return json(404, { message: "Not Found", error: 404 });
  if (!bearerOk(init)) return json(401, { message: "Unauthorized", error: 401 });

  const path = asked.pathname.replace(/\/+$/, "");
  if (method === "GET" && path === "/api/v1/me") {
    return json(200, { name: MOCK_HANDLE, id: "mk0001", created_utc: 1700000000, link_karma: 1, comment_karma: 1,
      has_verified_email: true, is_suspended: false });
  }
  if (method === "GET" && (path === "/message/inbox" || path === "/message/unread")) return json(200, listing(inbox()));
  if (method === "GET" && path === "/search") return json(200, listing(found()));
  const rules = /^\/r\/([A-Za-z0-9_]{2,21})\/about\/rules$/.exec(path);
  if (method === "GET" && rules) {
    const kept = RULES[rules[1].toLowerCase()];
    if (!kept) return json(404, { message: "Not Found", error: 404, reason: "banned" });
    return json(200, { rules: kept.map(([short, description], at) => ({ kind: "all", short_name: short, description,
      violation_reason: short, priority: at, created_utc: 1600000000, description_html: null })),
    site_rules: ["Spam", "Personal and confidential information", "Threatening, harassing, or inciting violence"],
    site_rules_flow: [] });
  }
  const about = /^\/r\/([A-Za-z0-9_]{2,21})\/about$/.exec(path);
  if (method === "GET" && about) {
    if (!RULES[about[1].toLowerCase()]) return json(404, { message: "Not Found", error: 404, reason: "banned" });
    return json(200, { kind: "t5", data: { display_name: about[1], title: `${about[1]}: the checks' own`, subscribers: 1234,
      submission_type: "any", submit_text: "Read the rules before you post.", public_description: "A mock community." } });
  }
  if (method === "POST" && path === "/api/submit") {
    const form = formOf(init);
    const sr = String(form.get("sr") || "");
    if (!RULES[sr.toLowerCase()]) {
      return json(200, { json: { errors: [["SUBREDDIT_NOEXIST", "that community doesn't exist", "sr"]] } });
    }
    const title = String(form.get("title") || "");
    if (!title || title.length > 300) return json(200, { json: { errors: [["BAD_TITLE", "a title is required", "title"]] } });
    const id = madeId();
    calls.at(-1).sent = { kind: form.get("kind"), sr, title, text: form.get("text") ?? null, url: form.get("url") ?? null };
    return json(200, { json: { errors: [], data: { url: `${REDDIT}/r/${sr}/comments/${id}/${slug(title)}/`, drafts_count: 0,
      id, name: `t3_${id}` } } });
  }
  if (method === "POST" && path === "/api/comment") {
    const form = formOf(init);
    const parent = String(form.get("thing_id") || "");
    const text = String(form.get("text") || "");
    if (!/^t[134]_[a-z0-9]{1,13}$/.test(parent) || !text) {
      return json(200, { json: { errors: [["NO_TEXT", "we need something here", "text"]] } });
    }
    const id = madeId();
    calls.at(-1).sent = { parent, text };
    const message = parent.startsWith("t4_");
    return json(200, { json: { errors: [], data: { things: [{ kind: message ? "t4" : "t1", data: { id, name: `${message ? "t4" : "t1"}_${id}`,
      parent_id: parent, body: text, author: MOCK_HANDLE, created_utc: Math.floor(Date.now() / 1000),
      ...(message ? { subject: "re: your message" } : { link_id: "t3_mkp002", subreddit: "lego",
        permalink: `/r/lego/comments/mkp002/_/${id}/` }) } }] } } });
  }
  if (method === "GET" && path === "/api/info") {
    const names = String(asked.searchParams.get("id") || "").split(",").filter((one) => /^t[13]_[a-z0-9]{1,13}$/.test(one));
    return json(200, listing(names.map((name) => {
      const minutes = ageOf(name.slice(3)) / 60;
      const score = 1 + Math.floor(minutes ** 0.8);
      return { kind: name.slice(0, 2), data: { id: name.slice(3), name, score, ups: score, num_comments: Math.floor(score / 3),
        upvote_ratio: 0.9, permalink: `/r/lego/comments/${name.slice(3)}/_/` } };
    })));
  }
  return json(404, { message: "Not Found", error: 404 });
}
