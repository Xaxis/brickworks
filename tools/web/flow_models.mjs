// The models the browser flows publish, their build steps carried as the
// app writes them (SharedPages), read from tests/fixtures/flow_models.
//
// The flows made them with godot from their own tree (src/dev/
// share_pages_probe.gd and tested_probe.gd, --write) until rel-m331's train:
// a release's web lane never imports its tree, so godot wrote nothing, and
// comments_flow died on ENOENT four seconds in, on the preview and on
// brickworks.diy alike (2026-11-24). They are fixed inputs, so they are made
// once from an imported tree, and src/dev/flow_models_probe.gd fails when
// one is no longer what the app writes today:
//
//   godot --headless --path . --script src/dev/flow_models_probe.gd              each as the app writes it?
//   godot --headless --path . --script src/dev/flow_models_probe.gd -- --write   write them again
//
// A flow that makes each run's model its own (a name, a comment line) finds
// TOKEN in the fixture's text, before its steps. flowModel puts the run's
// token there and names the new text where the text is named: the steps'
// head ("model", SharedPages.fingerprint, as api/_versions.js matches it)
// and, for a model tested as the Share panel tests it, the finding ("model",
// Tested.fingerprint, as api/_tested.js matches it; "app", this tree's
// version, as BuildInfo.version() says it). Nothing the steps or the tests
// say depends on the token, which the probe proves with another one.

import { existsSync, readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { modelHash } from "../../api/_directory.js";
import { fingerprint } from "../../api/_versions.js";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../..");
export const FIXTURES = path.join(root, "tests/fixtures/flow_models");
export const TOKEN = "runtoken";
const HEAD = "0 !BRICKWORKS PAGES ";
const WRITE = "src/dev/flow_models_probe.gd -- --write";

/// This tree's app version, as project.godot says it (BuildInfo.version()).
export function appVersion() {
  const found = /^config\/version="([^"]*)"/m.exec(readFileSync(path.join(root, "project.godot"), "utf8"));
  if (!found) throw new Error("project.godot says no config/version");
  return found[1];
}

/// [text] without its carried steps: what SharedPages.attach was given.
export function bareOf(text) {
  const at = String(text).indexOf(HEAD);
  return at < 0 ? String(text) : String(text).slice(0, at);
}

/// The fixtures' names, as flowModel takes them.
export function fixtureNames() {
  return existsSync(FIXTURES)
    ? readdirSync(FIXTURES).filter((f) => f.endsWith(".ldr")).map((f) => f.slice(0, -4)).sort() : [];
}

/// The fixture NAME (tests/fixtures/flow_models/NAME.ldr) with [token] for
/// TOKEN: {text, tested}, tested the app's finding of that text, or null
/// for a model the fixtures keep none for.
export function flowModel(name, token = TOKEN) {
  const file = path.join(FIXTURES, `${name}.ldr`);
  if (!existsSync(file)) throw new Error(`no model ${name} in ${FIXTURES}, only ${fixtureNames().join(", ")}`);
  if (!/^[0-9A-Za-z]+$/.test(String(token))) throw new Error(`a token is letters and digits, not "${token}"`);
  const fixture = readFileSync(file, "utf8");
  const bare = bareOf(fixture);
  const steps = fixture.slice(bare.length);
  const named = `"model":"${fingerprint(fixture)}"`;
  if (!steps.startsWith(HEAD) || !steps.split("\n")[0].includes(named)) {
    throw new Error(`${file} carries no steps of its own text: ${WRITE}`);
  }
  const mine = bare.split(TOKEN).join(String(token));
  const text = mine + steps.replace(named, `"model":"${fingerprint(mine)}"`);
  const findingFile = path.join(FIXTURES, `${name}.tested.json`);
  const tested = existsSync(findingFile)
    ? { ...JSON.parse(readFileSync(findingFile, "utf8")), model: modelHash(text), app: appVersion() } : null;
  return { text, tested };
}
