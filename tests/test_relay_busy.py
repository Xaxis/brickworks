"""A tab busy with its own work is busy, not closed (api/mcp.js).

The Charger's tab (design19, 2026-11-05) answered a job's 45 s wait, and the
session's next call, a second later, found the tab's last word 48 s old: the
relay said the tab had closed, nothing was done, and let the chat go of it.
The session ended "I didn't save the model before the tab went away".

Now an answer is the tab speaking. A tab in view that has said nothing for
45 s is "quiet": listed as busy, its call waits for it and is then told it is
busy, the chat keeps it, and nothing it built is said to be lost. Closed is a
page that said it has gone, or one silent for three minutes.

Played under node through the real handler, against the stand-in database
(tests/fixtures/relay/world.mjs), as test_relay_hello is.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_relay_hello import run  # noqa: E402

AGO = "new Date(Date.now() - {s} * 1000).toISOString()"


def test_a_tab_silent_a_minute_is_listed_busy_and_one_silent_four_is_not_listed() -> None:
    out = run(f"""
      w.tab({{ owner: "person", tab: "busy", model: "Charger", seen_at: {AGO.format(s=50)} }});
      w.tab({{ owner: "person", tab: "gone", model: "Old car", seen_at: {AGO.format(s=240)} }});
      const token = w.connect("person");
      const said = await w.ask(token, "tools/call", {{ name: "tabs", arguments: {{}} }});
      return said.result.content.map((one) => one.text).join("\\n");
    """)
    if out is None:
        return
    assert "busy: not answered for 50 s" in out, out
    assert "Old car" not in out, out


def test_a_call_to_a_busy_tab_waits_and_says_busy_not_closed() -> None:
    """The call waits half a minute for the tab to speak (QUIET_WAIT_MS):
    this test takes that long."""
    out = run(f"""
      w.tab({{ owner: "person", tab: "busy", model: "Charger", seen_at: {AGO.format(s=50)} }});
      const token = w.connect("person");
      const began = Date.now();
      const said = await w.ask(token, "tools/call", {{ name: "look_at_model", arguments: {{}} }});
      return {{ waited: Date.now() - began, error: said.result.isError,
        text: said.result.content.map((one) => one.text).join("\\n") }};
    """)
    if out is None:
        return
    assert out["waited"] >= 25_000, out
    assert out["error"] is True, out
    assert "has not answered for" in out["text"] and "It is still open" in out["text"], out
    assert "Nothing it has built is lost" in out["text"], out
    assert "closed" not in out["text"], out


def test_a_busy_tab_that_speaks_again_takes_the_call() -> None:
    """Heard from while the call waits: the call goes to it (here it is
    queued, which the stand-in cannot hold, so the queueing is what shows)."""
    out = run(f"""
      const row = w.tab({{ owner: "person", tab: "busy", model: "Charger", seen_at: {AGO.format(s=50)} }});
      setTimeout(() => {{ row.seen_at = new Date().toISOString(); }}, 2000);
      const token = w.connect("person");
      const began = Date.now();
      try {{ await w.ask(token, "tools/call", {{ name: "look_at_model", arguments: {{}} }}); }} catch {{}}
      return {{ waited: Date.now() - began, queued: w.written.some((one) => one.table === "relay") }};
    """)
    if out is None:
        return
    assert out["queued"] is True, out
    assert out["waited"] < 20_000, out


def test_an_answer_counts_as_the_tab_seen() -> None:
    out = run("""
      const { default: handle } = await import('./api/mcp.js');
      const response = { setHeader: () => response, status: () => response, json: () => response,
        end: () => response };
      const before = Date.now();
      await handle({ method: "POST", query: { t: "a-tab-token-".padEnd(48, "x"), i: "instance-1", op: "answer", id: "7" },
        headers: { host: "brickworks.test" }, body: { jsonrpc: "2.0", id: 7, result: { content: [] } } },
        response);
      const seen = w.written.filter((one) => one.table.startsWith("relay_tabs") && one.body.seen_at);
      return seen.map((one) => Date.parse(one.body.seen_at) - before);
    """)
    if out is None:
        return
    assert len(out) == 1 and 0 <= out[0] < 5_000, out
