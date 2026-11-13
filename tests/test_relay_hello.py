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
    deployment's tools as a tab of its build serves them
    (CommandSocket.served_tools: the title on the tool and in its
    annotations)."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { readFileSync } from 'node:fs';"
        "import { world } from './tests/fixtures/relay/world.mjs';"
        "const w = world();"
        "const own = JSON.parse(readFileSync('./tools/mcp_tools.json', 'utf8')).map((t) =>"
        " ({ name: t.name, title: t.annotations.title, description: t.description, inputSchema: t.input_schema,"
        " annotations: t.annotations }));"
        "const tool = (name) => ({ name, description: name, inputSchema: { type: 'object', properties: {} } });"
        "const names = (said) => ((said && said.result && said.result.tools) || []).map((t) => t.name);"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
        # Not kept waiting by a read a test left slow (world.trouble).
        "process.exit(0);"
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


def test_every_tool_listed_has_its_title_on_it_and_in_its_annotations() -> None:
    """Claude's Connectors Directory flags a tool with no title (2026-11-03).
    MCP has two, the tool's own and its annotations', and Anthropic's
    quickstart sets the tool's own: every tool carries both, the same, with
    no tab open (the deployment's list), with the relay's own two, and with
    the viewer's own for a client that shows pages."""
    out = run("""
      const { toolsWithTabs } = await import('./api/mcp.js');
      const token = w.connect("person");
      const listed = (await w.ask(token, "tools/list")).result.tools;
      const shown = toolsWithTabs(own, true);
      const untitled = (tools) => tools.filter((t) => !t.title || t.title !== (t.annotations || {}).title)
        .map((t) => t.name);
      return { listed: listed.length, shown: shown.length, bare: untitled(listed), bareShown: untitled(shown) };
    """)
    if out is None:
        return
    assert out["listed"] == len(OWN) + len(RELAY)
    assert out["shown"] > out["listed"]
    assert out["bare"] == [] and out["bareShown"] == []


# The guidance lookup: a read across every tab's hello, as against a tab's
# own (helloOf, by its channel).
LOOKUP = ("const lookup = (call) => call.startsWith('GET relay_tabs?') && call.includes('hello->')"
          " && !call.includes('channel=eq.');")


def test_a_guidance_lookup_that_fails_never_fails_the_handshake() -> None:
    """The guidance is read on each cold instance of the relay, and a
    database that failed that read failed the whole initialize: 502
    {"error":"database GET relay_tabs: 500"} on a preview (2026-11-10), and a
    client whose handshake fails is taken for one that shows no pages. The
    handshake goes on without guidance, and the next one looks again."""
    out = run(LOOKUP + """
      w.tab({ owner: "stranger", hello: { instructions: "this build's guidance", tools: own } });
      const token = w.connect("fresh");
      w.trouble = (call) => (lookup(call) ? { status: 500 } : null);
      const failing = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
      w.trouble = () => null;
      const after = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
      return { failing, after: after.result && after.result.instructions,
        tools: names(await w.ask(token, "tools/list")) };
    """)
    if out is None:
        return
    assert "result" in out["failing"], out["failing"]
    assert out["failing"]["result"]["instructions"] == ""
    assert out["after"] == "this build's guidance"
    assert out["tools"] == OWN + RELAY


def test_a_slow_guidance_lookup_is_not_waited_for() -> None:
    """A lookup that takes ten seconds held the handshake those ten (9.2 s,
    then the 502, on a preview): it is answered within a second without
    guidance, and a lookup that lands later is kept for the next, not made
    again."""
    out = run(LOOKUP + """
      w.tab({ owner: "stranger", hello: { instructions: "this build's guidance", tools: own } });
      const token = w.connect("fresh");
      const timed = async () => {
        const began = Date.now();
        const said = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
        return { ms: Date.now() - began, said };
      };
      w.trouble = (call) => (lookup(call) ? { ms: 10_000 } : null);
      const stuck = await timed();
      return { stuck };
    """)
    if out is None:
        return
    stuck = out["stuck"]
    assert "result" in stuck["said"], stuck["said"]
    assert stuck["ms"] < 1000, stuck["ms"]
    assert stuck["said"]["result"]["instructions"] == ""

    out = run(LOOKUP + """
      w.tab({ owner: "stranger", hello: { instructions: "this build's guidance", tools: own } });
      const token = w.connect("fresh");
      w.trouble = (call) => (lookup(call) ? { ms: 1500 } : null);
      const began = Date.now();
      const first = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
      const ms = Date.now() - began;
      await new Promise((resolve) => setTimeout(resolve, 1700));
      const second = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
      return { ms, first: first.result && first.result.instructions,
        second: second.result && second.result.instructions, lookups: w.calls.filter(lookup).length };
    """)
    if out is None:
        return
    assert out["ms"] < 1000, out["ms"]
    assert out["first"] == ""
    assert out["second"] == "this build's guidance"
    assert out["lookups"] == 1, out["lookups"]


def test_the_guidance_is_found_past_other_builds_hellos_without_reading_a_tool_list() -> None:
    """It read the twenty latest hellos' whole tool lists, 4.3 MB taking
    1.7 to 6 s, and on 2026-11-10 found nothing at all: this build's hellos
    were the 21st and on, behind previews' and test builds'. Found by the
    short hash of the tools each hello is kept with (list), whatever has
    said hello since, and no tool list is read to find it."""
    out = run(LOOKUP + """
      w.tab({ owner: "stranger", seen_at: new Date(Date.now() - 3600_000).toISOString(),
        hello: { instructions: "this build's guidance", tools: own } });
      for (let i = 0; i < 25; i++) {
        w.tab({ owner: `tester-${i}`, hello: { instructions: "a preview's guidance",
          tools: [...own, tool(`extra_${i}`)] } });
      }
      const token = w.connect("fresh");
      const greeted = await w.ask(token, "initialize", { protocolVersion: "2025-06-18" });
      return { guidance: greeted.result.instructions,
        reads: w.calls.filter(lookup), toolLists: w.calls.filter((call) => call.includes('hello->tools')) };
    """)
    if out is None:
        return
    assert out["guidance"] == "this build's guidance"
    assert out["toolLists"] == [], out["toolLists"]
    assert len(out["reads"]) == 1, out["reads"]
