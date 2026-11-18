// The numbers behind what the site tells a phone before the studio opens
// (phonetruth, 2026-11-18; docs/PHONE.md), which the owner changes in the
// console (/admin#switches, Phones) and every page that warns reads:
//
//   phone_parts    the most parts a phone opens with no word first: past
//                  it, a model's page asks before it opens the studio on a
//                  phone ("about N parts; on a phone this may close the
//                  tab"). The measured default is the largest gallery model
//                  whose tab stayed under the memory an iPhone gives a tab
//                  with room to spare (docs/PHONE.md, "What was measured")
//   phone_start_s  what a phone takes to start the studio once its files
//                  have come, on a mid-range Android phone's speed: the
//                  loader adds it to the download it times as it goes, to
//                  say how long a first visit on a phone will take
//
// Each is a site_settings switch (api/_settings.js), kept for one scope as
// the beta's is: brickworks.diy's, or a preview's own, so a preview's check
// sets its preview and never the site. Never set there, the measured default
// here stands.
//
//   GET  /api/plans?op=phone          {phone_parts, phone_start_s}: anybody's,
//                                     kept a minute at the CDN
//   POST /api/admin?op=phone_rules    {phone_parts?, phone_start_s?}: the
//                                     owner's, each a whole number in its
//                                     range, refused with words otherwise
//   phoneRulesRead(request)           each with its measured default and who
//                                     set it, for the console's Switches

import { settingOf, setSetting } from "./_settings.js";

export const PHONE_RULES = {
  phone_parts: {
    said: "Parts a phone opens without a warning",
    unit: "parts",
    fallback: 2500,
    least: 50,
    most: 100000,
  },
  phone_start_s: {
    said: "Seconds a phone takes to start the studio once it has its files",
    unit: "seconds",
    fallback: 25,
    least: 1,
    most: 600,
  },
};

const whole = (given) => {
  const text = String(given ?? "").replace(/[\s\u200b-\u200d\u2060\ufeff,]+/g, "");
  return /^\d{1,7}$/.test(text) ? Number(text) : NaN;
};

/// [name]'s number where [request] was made: {value, fallback, set,
/// set_by, set_at}. A kept value out of its range is not used.
async function ruleOf(name, request) {
  const rule = PHONE_RULES[name];
  const kept = await settingOf(name, request);
  const value = whole(kept?.value);
  const set = Number.isFinite(value) && value >= rule.least && value <= rule.most;
  return { name, said: rule.said, unit: rule.unit, least: rule.least, most: rule.most, fallback: rule.fallback,
    value: set ? value : rule.fallback, set, set_by: set ? kept.set_by ?? null : null, set_at: set ? kept.set_at ?? null : null };
}

/// Every rule where [request] was made, for the console.
export async function phoneRulesRead(request) {
  return Promise.all(Object.keys(PHONE_RULES).map((name) => ruleOf(name, request)));
}

/// GET /api/plans?op=phone: the numbers a page warns a phone by.
export async function phoneShown(request, response) {
  const rules = await phoneRulesRead(request).catch(() => null);
  if (!rules) {
    response.setHeader("Cache-Control", "no-store");
    return response.status(200).json(Object.fromEntries(Object.entries(PHONE_RULES).map(([name, rule]) => [name, rule.fallback])));
  }
  response.setHeader("Cache-Control", "public, max-age=0, s-maxage=60, stale-while-revalidate=300");
  return response.status(200).json(Object.fromEntries(rules.map((one) => [one.name, one.value])));
}

/// POST /api/admin?op=phone_rules {phone_parts?, phone_start_s?}: each named
/// one set here. All are checked before any is kept: a number out of its
/// range, or not a whole number, refuses the lot with words.
export async function phoneSet(request, response, claims) {
  const body = request.body && typeof request.body === "object" ? request.body : {};
  const asked = Object.keys(PHONE_RULES).filter((name) => body[name] !== undefined && body[name] !== null && body[name] !== "");
  if (!asked.length) {
    return response.status(400).json({ error: `Give a number for ${Object.keys(PHONE_RULES).join(" or ")}.` });
  }
  const values = {};
  for (const name of asked) {
    const rule = PHONE_RULES[name];
    const value = whole(body[name]);
    if (!Number.isFinite(value) || value < rule.least || value > rule.most) {
      return response.status(400).json({ error: `${rule.said}: give a whole number from ${rule.least.toLocaleString("en-US")} `
        + `to ${rule.most.toLocaleString("en-US")} ${rule.unit}.` });
    }
    values[name] = value;
  }
  const made = {};
  for (const name of asked) {
    const kept = await setSetting(name, String(values[name]), request, claims.email);
    made[name] = Number(kept.value);
  }
  return response.status(200).json({ ...made, value: asked.map((name) => `${name}=${made[name]}`).join(", ") });
}
