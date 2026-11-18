// The owner's console, part C (console3, 2026-11-13; docs/ADMIN.md): its
// Switches (/admin#switches) and the notice on every page.
//
//   switchesRead   every variable of the deployment by name: whether this
//                  deployment has it (never its value, never its length),
//                  which environments Vercel has it in (as the release
//                  train last wrote them down, supabase/console3.sql
//                  site_env), what it switches and where it is changed; the
//                  site's settings (site_settings) with the beta's, which
//                  the console flips; and the notice, with the ones before
//   noticeShown    the notice showing where a request was made, for every
//                  page (/api/plans?op=notice, kept a minute at the CDN)
//   noticeSet      {words: {en, de?, fr?, es?}, tone: info | warn, ends?}: shown on
//                  every page of this deployment's scope (brickworks.diy's
//                  on the site, a preview's own on a preview), in place of
//                  the one before; German, French and Spanish only as the
//                  owner typed them, English on those pages otherwise
//   noticeClear    taken down
//
// api/admin.js asks these behind its owner check; noticeShown is anybody's.

import { db } from "./_db.js";
import { scopeOf } from "./_settings.js";
import { noticeEnds, setNoticeEnds } from "./_announce.js";

const notYet = (trouble) => /: 404$/.test(String(trouble?.message || ""));
const VERCEL = "https://vercel.com/xaxis-projects/brickworks/settings/environment-variables";

/// Every variable the site's code reads, what it switches and where it is
/// changed. A variable Vercel has that is not here is said as one nothing
/// reads (ANTHROPIC_API_KEY, since 2026-10-09).
export const VARIABLES = [
  { name: "MASTER_EMAIL", what: "Who the owner is: the one account this console answers", where: "vercel" },
  { name: "BRICKWORKS_BETA", what: "The beta, open or off, where the console's switch was never flipped", where: "console" },
  { name: "BRICKWORKS_BILLING", what: "Plans: off, test or live (real money)", where: "vercel" },
  { name: "SUPABASE_URL", what: "The database, sign-in and storage", where: "vercel" },
  { name: "SUPABASE_SECRET_KEY", what: "The server's key to the database (every row)", where: "vercel" },
  { name: "SUPABASE_PUBLISHABLE_KEY", what: "The key pages and the app hold (row security keeps it to its own)", where: "vercel" },
  { name: "PARTS_URL", what: "Where the parts, the library and set pictures are read from", where: "vercel" },
  { name: "RESEND_API_KEY", what: "Mail: sign-in codes, the beta's, answers, digests (send only)", where: "vercel" },
  { name: "EMAIL_FROM", what: "Who mail is from", where: "vercel" },
  { name: "EMAIL_FROM_FALLBACK", what: "A borrowed sender while the domain waits on its records", where: "vercel" },
  { name: "BETA_REPLY_TO", what: "Where answers to the beta's and feedback's mail go", where: "vercel" },
  { name: "REPORT_MAIL", what: "off: no hourly email of reports to the owner", where: "vercel" },
  { name: "COMMENT_MAIL", what: "off: no daily email of comments to builders", where: "vercel" },
  { name: "RESEND_WEBHOOK_SECRET", what: "Resend's word on each mail (Mail): its signing secret", where: "vercel" },
  { name: "ADMISSION_URL", what: "Plans and payments: Admission's address", where: "vercel" },
  { name: "ADMISSION_KEY", what: "Plans and payments: the product's key at Admission", where: "vercel" },
  { name: "ADMISSION_WEBHOOK_SECRET", what: "Admission's word on a plan: its signing secret", where: "vercel" },
  { name: "ADMISSION_READ_TOKEN", what: "Revenue and Admission's record in Plans: an owner read token", where: "vercel" },
  { name: "OC_PROJECT_KEY", what: "Sign in with orangecheck", where: "vercel" },
  { name: "OC_SIGNING_SECRET", what: "orangecheck's signatures", where: "vercel" },
  { name: "OC_CONNECT_KEY", what: "orangecheck Connect: makes and deletes orangecheck accounts", where: "vercel" },
  { name: "OC_ME_ORIGIN", what: "orangecheck's own address", where: "vercel" },
  { name: "OC_ISSUER", what: "orangecheck's tokens: who issues them", where: "vercel" },
  { name: "OC_AUDIENCE", what: "orangecheck's tokens: whom they are for", where: "vercel" },
  { name: "REDDIT_CLIENT_ID", what: "The social desk: the Reddit app's id, to connect by Reddit's API (Social)", where: "vercel" },
  { name: "REDDIT_CLIENT_SECRET", what: "The social desk: the Reddit app's secret (Social)", where: "vercel" },
  { name: "CRON_SECRET", what: "The crons' own key (Run now in Site uses it here, on the server)", where: "vercel" },
  { name: "VIEW_SECRET", what: "Shared views' signatures", where: "vercel" },
  { name: "PUBLIC_ORIGIN", what: "The site's address, where a request does not say it", where: "vercel" },
  { name: "VERCEL_ENV", what: "Vercel's own: production or preview", where: "vercel_own" },
  { name: "VERCEL_URL", what: "Vercel's own: this deployment's address", where: "vercel_own" },
  { name: "VERCEL_AUTOMATION_BYPASS_SECRET", what: "Vercel's own: past a preview's protection", where: "vercel_own" },
];

export const WHERE = {
  vercel: { said: "Vercel: Settings, Environment Variables, then a redeploy", href: VERCEL },
  console: { said: "Here: the beta's switch (Beta), which wins over this", href: "#beta" },
  vercel_own: { said: "Set by Vercel itself", href: null },
};

/// What Vercel's list of variables was when the train last wrote it down:
/// {vars: Map(name -> environments), noted_at}, or null before console3.sql.
async function vercelSays() {
  try {
    const listed = await db("rpc/site_env_list", { method: "POST", body: {} });
    return { vars: new Map((listed?.vars || []).map((one) => [one.name, one.environments || []])), noted_at: listed?.noted_at ?? null };
  } catch (trouble) {
    if (notYet(trouble)) return null;
    throw trouble;
  }
}

/// GET /api/admin?op=switches: the beta's switch and the rest of what part
/// A's switches said (api/_console.js switches), with every variable, the
/// settings and the notice.
export async function switchesRead(request, base) {
  const scope = scopeOf(request);
  const [vercel, settings, notice, notices] = await Promise.all([
    vercelSays(),
    db("rpc/site_settings_list", { method: "POST", body: {} }).catch(() => null),
    noticeOf(scope).catch(() => undefined),
    db("rpc/site_notices_list", { method: "POST", body: { p_scope: scope, p_limit: 10 } }).catch(() => null),
  ]);
  const known = new Set(VARIABLES.map((one) => one.name));
  const variables = VARIABLES.map((one) => ({
    name: one.name,
    what: one.what,
    here: Boolean(String(process.env[one.name] ?? "").trim()),
    // Not known until the train has written Vercel's list down once.
    environments: vercel?.noted_at ? vercel.vars.get(one.name) || [] : null,
    where: WHERE[one.where].said,
    href: WHERE[one.where].href,
  }));
  // What Vercel has that nothing here reads: worth taking out.
  for (const [name, environments] of vercel?.vars || []) {
    if (known.has(name)) continue;
    variables.push({ name, what: "Nothing in the site's code reads it", here: Boolean(String(process.env[name] ?? "").trim()),
      environments, where: WHERE.vercel.said, href: VERCEL, unread: true });
  }
  return {
    ...base,
    scope,
    variables,
    vercel_noted_at: vercel?.noted_at ?? null,
    vercel_ready: vercel !== null,
    // Every setting kept, each scope's; the beta's is flipped here and in
    // Beta (one act, ?op=beta_switch). None other is the owner's yet.
    settings: settings === null ? null : settings.map((one) => ({ ...one, here: one.scope === scope,
      switch: one.name === "beta" ? "beta_switch" : null })),
    notice: notice === undefined ? null : notice,
    notice_ready: notice !== undefined,
    notices: notices || [],
  };
}

/// The notice showing in [scope], or null.
async function noticeOf(scope) {
  try {
    return (await db("rpc/site_notice", { method: "POST", body: { p_scope: scope } })) || null;
  } catch (trouble) {
    if (notYet(trouble)) return undefined;
    throw trouble;
  }
}

/// GET /api/plans?op=notice: the notice on every page where this was asked,
/// for anybody: {notice: {id, words, tone} | null}. Kept a minute at the CDN,
/// so a notice set or cleared is seen everywhere within it; never who set it.
export async function noticeShown(request, response) {
  let notice = null;
  try {
    const one = await noticeOf(scopeOf(request));
    // Its end (supabase/announce.sql), so a page kept open takes it down then.
    if (one) notice = { id: one.id, words: one.words, tone: one.tone, ends_at: one.ends_at ?? null };
  } catch (trouble) {
    console.error(`notice: ${String(trouble?.message || trouble).slice(0, 120)}`);
    response.setHeader("Cache-Control", "no-store");
    return response.status(200).json({ notice: null });
  }
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=60, stale-while-revalidate=300");
  return response.status(200).json({ notice });
}

const LANGS = ["en", "de", "fr", "es"];

/// The notice's words as typed: one line each, at most 300 characters,
/// English needed, the others only if typed. {words} or {error}.
export function noticeWords(given) {
  const words = {};
  for (const lang of LANGS) {
    const said = String(given?.[lang] ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim();
    if (said.length > 300) return { error: `The ${lang === "en" ? "English" : lang} words are over 300 characters.` };
    if (said) words[lang] = said;
  }
  if (!words.en) return { error: "Give the notice its words in English: every page shows them where no other language is typed." };
  return { words };
}

/// POST /api/admin?op=notice_set {words: {en, de?, fr?, es?}, tone, ends?}:
/// [ends] the time it goes by itself (api/_announce.js noticeEnds).
export async function noticeSet(request, response, claims) {
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const checked = noticeWords(body.words);
  if (checked.error) return response.status(400).json({ error: checked.error });
  const ends = noticeEnds(body.ends);
  const tone = body.tone === "warn" ? "warn" : "info";
  let made;
  try {
    made = await db("rpc/site_notice_set", { method: "POST", body: { p_scope: scopeOf(request), p_words: checked.words,
      p_tone: tone, p_by: String(claims.email || "the owner").slice(0, 320) } });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(503).json({ error: "Not open yet: supabase/console3.sql is not applied." });
    throw trouble;
  }
  const end = ends && made.notice?.id ? await setNoticeEnds(scopeOf(request), made.notice.id, ends) : { ends_at: null };
  return response.status(200).json({ notice: made.notice?.id ?? null, was: made.was ?? null, tone,
    languages: Object.keys(checked.words), scope: scopeOf(request), ...end });
}

/// POST /api/admin?op=notice_clear.
export async function noticeClear(request, response, claims) {
  let gone;
  try {
    gone = await db("rpc/site_notice_clear", { method: "POST", body: { p_scope: scopeOf(request),
      p_by: String(claims.email || "the owner").slice(0, 320) } });
  } catch (trouble) {
    if (notYet(trouble)) return response.status(503).json({ error: "Not open yet: supabase/console3.sql is not applied." });
    throw trouble;
  }
  if (!gone?.cleared) return response.status(404).json({ error: "No notice is showing here." });
  return response.status(200).json({ cleared: gone.cleared, scope: scopeOf(request) });
}
