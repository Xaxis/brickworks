// The switches the owner flips from the console (/admin; supabase/console.sql
// site_settings, docs/ADMIN.md), each kept for one scope: "live", the site
// at brickworks.diy, or one deployment's own address, so a preview's check
// flips its preview and never the site. A switch never set in its scope is
// the project's setting in Vercel's environment, which the caller reads
// (api/_beta.js betaMode: the beta's, BRICKWORKS_BETA).
//
// Read on every request that needs one, so each read is kept a few seconds
// in the instance (a function's instances are many: another one follows
// within SECONDS); the instance that writes one keeps what it wrote. Not
// reached, or console.sql not applied, is no setting: the project's stands.

import { db, dbConfigured } from "./_db.js";

export const SECONDS = 15;
const LIVE = new Set(["brickworks.diy", "www.brickworks.diy"]);
const SCOPE = /^[a-z0-9.:-]{1,200}$/;
const held = new Map();

/// Where a request was made: "live" for the site, else its host.
export function scopeOf(request) {
  const headers = request?.headers || {};
  const host = String(headers["x-forwarded-host"] || headers.host || "").split(",")[0].trim().toLowerCase();
  if (LIVE.has(host)) return "live";
  return SCOPE.test(host) ? host : "unknown";
}

/// [name]'s setting where [request] was made: {value, set_by, set_at}, or
/// null when it was never set there or cannot be read now.
export async function settingOf(name, request, now = Date.now()) {
  if (!dbConfigured()) return null;
  const scope = scopeOf(request);
  const key = `${name}@${scope}`;
  const kept = held.get(key);
  if (kept && now - kept.at < SECONDS * 1000) return kept.value;
  let value = null;
  try {
    value = (await db("rpc/site_setting", { method: "POST", body: { p_name: name, p_scope: scope } })) || null;
  } catch (trouble) {
    if (!/: 404$/.test(String(trouble?.message || ""))) {
      console.error(`settings: ${String(trouble?.message || trouble).slice(0, 120)}`);
    }
  }
  held.set(key, { at: now, value });
  return value;
}

/// [name] set to [value] where [request] was made, by [by]: {value, set_by,
/// set_at, was, scope}. Throws when it cannot be kept.
export async function setSetting(name, value, request, by) {
  const scope = scopeOf(request);
  const made = await db("rpc/site_setting_set", { method: "POST",
    body: { p_name: name, p_scope: scope, p_value: value, p_by: String(by || "the owner").slice(0, 320) } });
  held.set(`${name}@${scope}`, { at: Date.now(), value: { value: made.value, set_by: made.set_by, set_at: made.set_at } });
  return { ...made, scope };
}

/// Every reading forgotten (a test's, between its scenarios).
export function forgetSettings() {
  held.clear();
}
