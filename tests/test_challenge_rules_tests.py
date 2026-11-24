"""The studio is told a test challenge only when it asks for one.

The challenges check sets a test week on the preview's database. The studio's
?op=challenge_rules told it to every test account unasked, so each check
beside it, signed in as a test account, drew the week's line over its model:
drawn found its stack of nine cut off under it (nightly 2026-11-24). Here
api/_challenges.js challengeRules runs as it is, its database and sign-in
stood in (Node's module hooks), and is asked as each caller would ask.
"""
from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

HARNESS = r"""
import { registerHooks } from "node:module";
const root = process.argv[2];
const stub = (source) => "data:text/javascript," + encodeURIComponent(source);
registerHooks({
  resolve(specifier, context, next) {
    if (specifier === "./_db.js") return { url: stub(`
      export async function db(path, init) {
        const tests = path === "rpc/challenge_open" && init?.body?.tests === true;
        return tests ? { id: 7, title: "Test week", brief: "", starts_on: "2026-11-24", ends_on: "2026-11-30", test: true } : null;
      }
      export async function orUnknown(_what, promise) { return promise; }
    `), shortCircuit: true };
    if (specifier === "./_auth.js") return { url: stub(`
      export function bearer(request) { return request.headers?.authorization ? request.headers.authorization.slice(7) : null; }
      export async function verify(token) { return { sub: token, test: token.startsWith("test") }; }
      export function isTestAccount(claims) { return claims.test === true; }
    `), shortCircuit: true };
    return next(specifier, context);
  },
});
const { challengeRules } = await import(root + "/api/_challenges.js");
const said = {};
for (const [who, query] of [["person", {}], ["person", { tests: "1" }], ["test-pool", {}], ["test-pool", { tests: "1" }],
                            ["", {}], ["", { tests: "1" }]]) {
  let answer = null;
  const response = { setHeader() {}, status() { return this; }, json(body) { answer = body; return this; } };
  const headers = who ? { authorization: `Bearer ${who}` } : {};
  await challengeRules({ headers, query }, response, { origin: "https://preview.invalid" });
  said[`${who || "nobody"}${query.tests ? " asking tests" : ""}`] = answer.challenge ? answer.challenge.title : null;
}
console.log(JSON.stringify(said));
"""


@pytest.mark.skipif(shutil.which("node") is None, reason="no node")
def test_a_test_week_is_told_only_where_asked_for(tmp_path):
    harness = tmp_path / "harness.mjs"
    harness.write_text(HARNESS)
    run = subprocess.run(["node", str(harness), str(ROOT)], capture_output=True, text=True, timeout=60)
    assert run.returncode == 0, run.stderr
    said = json.loads(run.stdout.strip().splitlines()[-1])
    assert said == {
        # A person's studio never: their sign-in says what they are.
        "person": None, "person asking tests": None,
        # A test account's only when it asks, as a page asked with tests=1.
        "test-pool": None, "test-pool asking tests": "Test week",
        "nobody": None, "nobody asking tests": "Test week",
    }, said
