"""A flow that publishes never spends the shared test account's limits.

Brickworks limits what one account does in a short time (api/share.js
may_publish: 20 publishes an hour, 60 a day). Every browser flow launched by
tools/web/browser.mjs is signed in as the one shared test account, and the
four dialogs checks publish: run by every unit's preview and every train, they
spent its 60 a day between them, and from 2026-11-08 19:47Z each was refused
Share. A flow that publishes now signs in as an account of the run's own
(launch({ ownAccount: true })) or as throwaways it makes itself (launch({
signedOut: true }) and session.mjs's mintSession). Held here: that no flow
presses Publish as the shared account, and that the sweep of accounts runs
left behind takes those of ended processes and nothing else.

And that every new account a flow mints has the beta's welcome answered
before a page meets it (welcomeall, 2026-11-10), only when it is due, never
for the owner, and not for a flow that says it will meet it itself.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SESSION = ROOT / "tools/web/session.mjs"

# The Share panel's Publish, pressed by its control's name.
PUBLISH = re.compile(r"""["'`]share_publish["'`]""")
LAUNCH = re.compile(r"\blaunch\s*\(")
OWN = re.compile(r"\b(?:signedOut|ownAccount)\s*:\s*true\b")


def test_no_flow_publishes_as_the_shared_test_account() -> None:
    publishing = [path for path in sorted((ROOT / "tools").rglob("*.mjs"))
                  if "node_modules" not in path.parts and PUBLISH.search(path.read_text())]
    assert any(path.name == "dialogs_flow.mjs" for path in publishing), publishing
    stray = [str(path.relative_to(ROOT)) for path in publishing
             if LAUNCH.search(path.read_text()) and not OWN.search(path.read_text())]
    assert not stray, (f"{', '.join(stray)}: each presses Publish in a browser signed in as the shared test "
                       "account, whose publishes every preview and train share (60 a day); launch it with "
                       "{ ownAccount: true } (tools/web/browser.mjs)")


SWEEP = r"""
import { spawn } from "node:child_process";
import { leftBehind, runAddress } from "SESSION";
const now = Date.now();
const hour = 60 * 60 * 1000;
const at = (ago) => new Date(now - ago).toISOString();
const child = spawn(process.execPath, ["-e", "setTimeout(() => {}, 60000)"], { stdio: "ignore" });
await new Promise((up) => child.once("spawn", up));
const its = runAddress(child.pid);
const seen = { running: leftBehind({ email: its, created_at: at(hour) }, now) };
child.kill("SIGKILL");
await new Promise((gone) => child.once("exit", gone));
seen.ended = leftBehind({ email: its, created_at: at(hour) }, now);
const mine = runAddress();
seen.mine = leftBehind({ email: mine, created_at: at(hour) }, now);
seen.mineOverADay = leftBehind({ email: mine, created_at: at(25 * hour) }, now);
// The same pid, but another process: one that started at another time.
seen.pidAgain = leftBehind({ email: mine.replace(/-(\d+)-([0-9a-f]+@)/, "-1$1-$2"), created_at: at(hour) }, now);
const elsewhere = its.replace(/flowrun-[0-9a-f]{6}-/, (m) => `flowrun-${m.slice(8, 14) === "000000" ? "111111" : "000000"}-`);
seen.elsewhere = leftBehind({ email: elsewhere, created_at: at(hour) }, now);
seen.elsewhereOverADay = leftBehind({ email: elsewhere, created_at: at(25 * hour) }, now);
seen.otherThrowaway = leftBehind({ email: "delivered+bw-share-owner-1a2b3c4d@resend.dev", created_at: at(25 * hour) }, now);
seen.shared = leftBehind({ email: "delivered+brickworks-tests@resend.dev", created_at: at(25 * hour) }, now);
seen.mineUndated = leftBehind({ email: mine }, now);
console.log(JSON.stringify({ its, mine, seen }));
"""


@pytest.mark.skipif(shutil.which("node") is None or not Path("/proc/self/stat").exists(),
                    reason="needs node and /proc")
def test_the_sweep_takes_only_accounts_of_ended_runs() -> None:
    out = subprocess.run(["node", "--input-type=module", "-e", SWEEP.replace("SESSION", SESSION.as_uri())],
                         cwd=ROOT, capture_output=True, text=True, timeout=60)
    assert out.returncode == 0, out.stderr
    told = json.loads(out.stdout.strip().splitlines()[-1])
    assert re.fullmatch(r"delivered\+bw-flowrun-[0-9a-f]{6}-\d+-\d+-[0-9a-f]{6}@resend\.dev", told["mine"]), told
    assert len(told["mine"].split("@")[0]) <= 64, told
    assert told["seen"] == {
        "running": False,           # a run still going keeps its account
        "ended": True,              # a run killed outright: swept by the next
        "mine": False,
        "mineOverADay": True,       # anything over a day old, wherever made
        "pidAgain": True,           # its pid now another process's
        "elsewhere": False,         # another machine's run may be going
        "elsewhereOverADay": True,
        "otherThrowaway": False,    # other flows' throwaways are theirs
        "shared": False,
        "mineUndated": False,
    }, told


# mintSession and mintCode against a stand-in Supabase: which of the beta's
# functions each asked, by case.
WELCOME = r"""
import { mintCode, mintSession } from "SESSION";
let member = { welcome: true };
let asked = [];
const json = (status, body) => new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
globalThis.fetch = async (url, init = {}) => {
  const { pathname } = new URL(url);
  const body = init.body ? JSON.parse(init.body) : {};
  if (pathname.startsWith("/rest/v1/rpc/beta_")) asked.push(pathname.slice("/rest/v1/rpc/".length));
  if (pathname === "/auth/v1/admin/users") return json(422, {});
  if (pathname === "/auth/v1/token") return json(200, { access_token: "a", refresh_token: "r", user: { id: "u1", email: body.email } });
  if (pathname === "/auth/v1/admin/generate_link") return json(200, { id: "u2", email: body.email, email_otp: "123456" });
  if (pathname === "/auth/v1/verify") return json(200, { access_token: "a", refresh_token: "r", user: { id: "u3", email: body.email } });
  if (pathname === "/rest/v1/rpc/answer_age") return json(200, null);
  if (pathname === "/rest/v1/rpc/beta_member") return member === 404 ? json(404, { code: "PGRST202" }) : json(200, member);
  if (pathname === "/rest/v1/rpc/beta_leave") return json(200, { tester: false, state: "not_now", welcome: false });
  return json(500, { unexpected: pathname });
};
const said = [];
console.log = (line) => said.push(String(line));
const seen = {};
const run = async (name, how, as = { welcome: true }) => {
  member = as;
  asked = [];
  await how();
  seen[name] = asked.join(" ");
};
const fresh = "delivered+bw-new@resend.dev";
await run("due", () => mintSession(fresh));
await run("dueAgain", () => mintSession(fresh));
await run("tester", () => mintSession(fresh), { welcome: false, tester: true, state: "tester" });
await run("leftToTheFlow", () => mintSession(fresh, { welcome: false }));
await run("code", () => mintCode(fresh));
await run("codeLeftToTheFlow", () => mintCode(fresh, { welcome: false }));
await run("owner", () => mintSession("owner@example.com"));
await run("ownersCode", () => mintCode("owner@example.com"));
await run("notApplied", () => mintSession(fresh), 404);
seen.said = said;
process.stdout.write(JSON.stringify(seen) + "\n");
"""


@pytest.mark.skipif(shutil.which("node") is None, reason="needs node")
def test_a_minted_account_has_the_beta_welcome_answered_only_when_due() -> None:
    env = {"PATH": "/usr/bin:/bin", "SUPABASE_URL": "http://supabase.invalid", "SUPABASE_SECRET_KEY": "secret",
           "SUPABASE_PUBLISHABLE_KEY": "key", "MASTER_EMAIL": "Owner@example.com"}
    node = shutil.which("node")
    out = subprocess.run([node, "--input-type=module", "-e", WELCOME.replace("SESSION", SESSION.as_uri())],
                         cwd=ROOT, capture_output=True, text=True, timeout=60, env=env)
    assert out.returncode == 0, out.stderr
    told = json.loads(out.stdout.strip().splitlines()[-1])
    assert told == {
        "due": "beta_member beta_leave",       # Not now, as signing up would have answered it
        "dueAgain": "beta_member beta_leave",  # due again (not kept): answered again
        "tester": "beta_member",               # a tester is never made to leave
        "leftToTheFlow": "",                   # the beta's own flows meet it themselves
        "code": "beta_member beta_leave",      # a code typed into the dialog: answered before
        "codeLeftToTheFlow": "",
        "owner": "",                           # never the owner's account
        "ownersCode": "",
        "notApplied": "beta_member",           # no beta_join.sql there: quiet
        "said": [],
    }, told
