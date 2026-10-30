"""What the relay lists before a tab has said hello (api/mcp.js).

Claude signed in to an account lists the connector's tools whether or not
a tab of that account is open. With no tab, or before its tab had said
hello, the relay answered with the fullest hello anyone had sent, and on
2026-10-29 that was another unit's test build with a tool no person's app
has: 69 tools listed where the app serves 68 (model_view_check on a
preview). Now it lists the tools of the app build the deployment serves
(tools/mcp_tools.json, which mcp_sync holds to the app), with the guidance
of a hello of that very list; once the tab says hello, the tab's own.

Played under node through the real handler, against a stand-in for the
database (tests/fixtures/relay/world.mjs) that hands rows back with their
keys in the order the real one keeps them.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OWN = [tool["name"] for tool in json.loads((ROOT / "tools" / "mcp_tools.json").read_text())]
RELAY = ["tabs", "select_tab"]


def run(body: str) -> dict | None:
    """[body] (an async function's body that returns something JSON) run in
    a fresh node process, with `w` a world (the fixture) and `own` the
    deployment's tools as a tab of its build serves them."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { readFileSync } from 'node:fs';"
        "import { world } from './tests/fixtures/relay/world.mjs';"
        "const w = world();"
        "const own = JSON.parse(readFileSync('./tools/mcp_tools.json', 'utf8')).map((t) =>"
        " ({ name: t.name, description: t.description, inputSchema: t.input_schema, annotations: t.annotations }));"
        "const tool = (name) => ({ name, description: name, inputSchema: { type: 'object', properties: {} } });"
        "const names = (said) => ((said && said.result && said.result.tools) || []).map((t) => t.name);"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_with_no_tab_the_list_is_the_deployments_own() -> None:
    out = run("""
      // A test build's tab, fuller than the app, seen last; a tab of this
      // build; and an account of its own whose last tab, closed, was an
      // older build's.
      w.tab({ owner: "stranger-1", hello: { instructions: "a test build's guidance",
        tools: [...own, tool("extra_tool")] } });
      w.tab({ owner: "stranger-2", seen_at: new Date(Date.now() - 60_000).toISOString(),
        hello: { instructions: "this build's guidance", tools: own } });
      w.tab({ owner: "older", open: false, hello: { instructions: "an older build's guidance",
        tools: [tool("look_at_model")] } });
      const fresh = w.connect("fresh");
      const older = w.connect("older");
      return {
        fresh: names(await w.ask(fresh, "tools/list")),
        older: names(await w.ask(older, "tools/list")),
        guidance: (await w.ask(fresh, "initialize", { protocolVersion: "2025-06-18" })).result.instructions,
      };
    """)
    if out is None:
        return
    assert out["fresh"] == OWN + RELAY, (len(out["fresh"]), len(OWN))
    assert out["older"] == OWN + RELAY
    assert out["guidance"] == "this build's guidance"


def test_no_hello_of_this_build_means_no_guidance_but_still_its_tools() -> None:
    out = run("""
      w.tab({ owner: "stranger", hello: { instructions: "a test build's guidance",
        tools: [...own, tool("extra_tool")] } });
      const token = w.connect("fresh");
      const greeted = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
      return { guidance: greeted.result.instructions, tools: names(await w.ask(token, "tools/list")) };
    """)
    if out is None:
        return
    assert out == {"guidance": "", "tools": OWN + RELAY}


def test_a_tab_that_said_hello_lists_its_own() -> None:
    out = run("""
      w.tab({ owner: "stranger", hello: { instructions: "this build's guidance", tools: own } });
      w.tab({ owner: "person", hello: { instructions: "the tab's guidance",
        tools: [tool("look_at_model"), tool("newer_tool")] } });
      const token = w.connect("person");
      const greeted = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
      return { guidance: greeted.result.instructions, tools: names(await w.ask(token, "tools/list")) };
    """)
    if out is None:
        return
    assert out == {"guidance": "the tab's guidance", "tools": ["look_at_model", "newer_tool"] + RELAY}


def test_a_tab_of_this_build_saying_hello_changes_nothing_a_conversation_was_given() -> None:
    """The list a conversation was given before its tab said hello is
    remembered by its hash (relay_lists), and a call is told the tools have
    changed when its tab serves another. A tab of this very build serves the
    same list, read back from the database in the database's own key order:
    nothing to be told. A tab of another build: told."""
    out = run("""
      const listed = () => w.written.filter((one) => one.table === "relay_lists").map((one) => one.body.listed);
      const token = w.connect("person");
      await w.ask(token, "tools/list");
      w.tab({ owner: "person", hello: { instructions: "this build's guidance", tools: own } });
      await w.ask(token, "tools/list");
      w.tab({ owner: "other", hello: { instructions: "another build's guidance", tools: [...own, tool("extra_tool")] } });
      const other = w.connect("other");
      await w.ask(other, "tools/list");
      return listed();
    """)
    if out is None:
        return
    before, this_build, another_build = out
    assert before and before == this_build
    assert another_build != before
