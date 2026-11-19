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
// And which engine an iPhone or iPad starts (nothreads, 2026-11-19):
//
//   phone_nothreads  on: the studio's page starts the engine without threads
//                  there (src/boot/shell.html, brickworksEngine), which on
//                  WebKit as an iPhone started in 0.70 of the time and asks
//                  for no 2 GB shared memory up front, which an iPhone has
//                  refused (godot#70621). Off, as it is until the owner says,
//                  every page gets the threaded engine, as before. Android
//                  and computers keep threads whatever it says (Chromium was
//                  no faster without them).
//
// Each is a site_settings switch (api/_settings.js), kept for one scope as
// the beta's is: brickworks.diy's, or a preview's own, so a preview's check
// sets its preview and never the site. Never set there, the measured default
// here stands.
//
//   GET  /api/plans?op=phone          {phone_parts, phone_start_s,
//                                     phone_nothreads}: anybody's, kept a
//                                     minute at the CDN
//   POST /api/admin?op=phone_rules    {phone_parts?, phone_start_s?}: the
//                                     owner's, each a whole number in its
//                                     range, refused with words otherwise
//   POST /api/admin?op=phone_engine   {on: true | false}: the owner's, the
//                                     engine switch alone, one act
//   phoneRulesRead(request)           each with its measured default and who
//                                     set it, for the console's Switches

import { settingOf, setSetting } from "./_settings.js";

export const PHONE_RULES = {
  phone_parts: {
    said: "Parts a phone opens without a warning",
    unit: "parts",
    // Measured (docs/PHONE.md): up to Wizard's Tower, the gallery's largest
    // at 10,101, a model costs a phone no memory past the studio's own (the
    // engine's 519 MB, the tab's 0.86 GB); twice it, 20,202, grew them to
    // 722 MB and 1.04 GB, past 70% of the 1.4 GB an iPhone's tab is killed at.
    fallback: 10101,
    least: 50,
    most: 100000,
  },
  phone_start_s: {
    said: "Seconds a phone takes to start the studio once it has its files",
    unit: "seconds",
    // Measured: a phone at a quarter of this box's speed (Lighthouse's
    // mid-tier phone) started the studio 42 s after its files had come.
    fallback: 40,
    least: 1,
    most: 600,
  },
};

/// The engine switch: on or off, kept as its word.
export const PHONE_ENGINE = {
  name: "phone_nothreads",
  said: "iPhones and iPads use the engine without threads",
  why: "On an iPhone it started the studio in 0.70 of the time (17.7 s against 25.2) and asks for no 2 GB of memory up front; Android and computers keep threads.",
  fallback: false,
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

/// The engine switch where [request] was made: {value: on, fallback, set,
/// set_by, set_at}. A kept word other than on or off is not used.
async function engineOf(request) {
  const kept = await settingOf(PHONE_ENGINE.name, request);
  const set = kept?.value === "on" || kept?.value === "off";
  return { name: PHONE_ENGINE.name, kind: "switch", said: PHONE_ENGINE.said, why: PHONE_ENGINE.why,
    fallback: PHONE_ENGINE.fallback, value: set ? kept.value === "on" : PHONE_ENGINE.fallback, set,
    set_by: set ? kept.set_by ?? null : null, set_at: set ? kept.set_at ?? null : null };
}

/// Every rule where [request] was made, for the console: the numbers, then
/// the engine switch.
export async function phoneRulesRead(request) {
  return Promise.all([...Object.keys(PHONE_RULES).map((name) => ruleOf(name, request)), engineOf(request)]);
}

/// GET /api/plans?op=phone: the numbers a page warns a phone by.
export async function phoneShown(request, response) {
  const rules = await phoneRulesRead(request).catch(() => null);
  if (!rules) {
    response.setHeader("Cache-Control", "no-store");
    return response.status(200).json({ ...Object.fromEntries(Object.entries(PHONE_RULES).map(([name, rule]) => [name, rule.fallback])),
      [PHONE_ENGINE.name]: PHONE_ENGINE.fallback });
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


/// POST /api/admin?op=phone_engine {on: true | false}: the engine switch set
/// here, one act. Anything but true or false is refused with words, and
/// nothing is kept.
export async function phoneEngineSet(request, response, claims) {
  const body = request.body && typeof request.body === "object" ? request.body : {};
  if (body.on !== true && body.on !== false) {
    return response.status(400).json({ error: `${PHONE_ENGINE.said}: say on as true or false.` });
  }
  const kept = await setSetting(PHONE_ENGINE.name, body.on ? "on" : "off", request, claims.email);
  return response.status(200).json({ [PHONE_ENGINE.name]: kept.value === "on", value: kept.value });
}
