"""What every answer's first line says of the other chats in a tab (api/mcp.js header).

APP_UX9's MCP walk ran each task as one `claude -p --resume` turn, and Claude Code
starts a new session each time a chat is resumed, so to the relay every turn was a
chat of its own. Every answer then began "Careful: 19 other chats have been working
in it for under a minute ... the tab shows both chats": the session's own earlier
turns, held for 30 minutes, "both" for 19, and the newest chat's time for all of
them. t3's session looked at the model first for it, and y3's and n7's told the
person about "25 other chats" (mcpreach2). Now:

  - a chat not heard from in 10 minutes is not working in the tab;
  - one heard from since this chat began is another chat for certain, said with
    "Careful:", how long the first has been there, the newest's last call, and
    "both" only for two;
  - one heard from only before this chat began may be this conversation's own
    earlier self: said with no count, and how to tell.

Played under node on the header itself, with the picks as the database keeps them.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def header(picks: list[dict], key: str = "session:me") -> str | None:
    """The header for chat [key] in one open tab, with [picks] given as
    {key, picked: seconds ago, called: seconds ago or None}."""
    if shutil.which("node") is None:
        return None
    script = (
        "const { header } = await import('./api/mcp.js');"
        "const ago = (s) => s === null || s === undefined ? null : new Date(Date.now() - s * 1000).toISOString();"
        f"const given = {json.dumps(picks)};"
        "const picks = given.map((p) => ({ key: p.key, channel: 'chan-1', picked_at: ago(p.picked),"
        " called_at: ago(p.called), did: 'edit_model', moved_at: null }));"
        "const tab = { channel: 'chan-1', tab: 'k2abc', model: 'Wall', open: true, owner: 'acct-1',"
        " seen_at: new Date().toISOString(), visible: true };"
        f"console.log(JSON.stringify(header(tab, null, [tab], picks, {json.dumps(key)})));"
        "process.exit(0);"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_alone_in_its_tab_it_is_told_of_no_other_chat() -> None:
    said = header([{"key": "session:me", "picked": 60, "called": 5}])
    if said is None:
        return
    assert said == "Tab k2abc, “Wall”."


def test_a_chat_quiet_for_ten_minutes_is_not_working_in_the_tab() -> None:
    said = header([{"key": "session:me", "picked": 3600, "called": 5},
                   {"key": "session:old", "picked": 3000, "called": 601}])
    if said is None:
        return
    assert "other chat" not in said and "Careful" not in said, said


def test_one_still_calling_since_this_chat_began_is_another_chat_and_both_is_for_two() -> None:
    said = header([{"key": "session:me", "picked": 300, "called": 10},
                   {"key": "session:them", "picked": 1500, "called": 30}])
    if said is None:
        return
    assert said.startswith("Tab k2abc, “Wall”. Careful: another chat has been working in it for 25 min, "
                           "last call 30 s ago, on this same model since this chat began; the tab shows both "
                           "chats and the person can keep one."), said


def test_several_say_the_first_ones_time_and_the_newest_ones_call_and_never_both() -> None:
    said = header([{"key": "session:me", "picked": 900, "called": 10},
                   {"key": "session:a", "picked": 2400, "called": 60},
                   {"key": "session:b", "picked": 120, "called": 25},
                   {"key": "session:c", "picked": 600, "called": 400}])
    if said is None:
        return
    # The longest there is a (40 min); the newest call is b's (25 s).
    assert "Careful: 3 other chats have been working in it, the first for 40 min, last call 25 s ago" in said, said
    assert "both" not in said and "every chat" in said, said


def test_a_resumed_chats_earlier_turns_are_not_counted_or_said_to_be_working_in_it() -> None:
    # The walk's y3: this turn's chat began just now; the session's twelve earlier
    # turns each called once, in turn, and went quiet as the next began.
    picks = [{"key": "session:me", "picked": 2, "called": 1}]
    picks += [{"key": f"session:turn{n}", "picked": 45 + n * 40, "called": 25 + n * 40} for n in range(12)]
    said = header(picks)
    if said is None:
        return
    assert "Careful" not in said and "working in it for" not in said, said
    assert "12" not in said and "13" not in said, said
    assert "Before this chat's first call here, other chats called in this tab, last heard 25 s ago." in said, said
    assert "if this conversation called Brickworks earlier, those were its own calls" in said, said


def test_a_chats_first_call_with_one_chat_before_it_says_that_was_and_no_count() -> None:
    # t3: this chat has no pick yet (its first call; its pick is made as the call goes).
    said = header([{"key": "session:t1", "picked": 40, "called": 25},
                   {"key": "session:t2", "picked": 20, "called": 4}])
    if said is None:
        return
    assert said.startswith("Tab k2abc, “Wall”. Before this chat's first call here, other chats called in "
                           "this tab, last heard just now."), said
    assert "2 " not in said, said
    one = header([{"key": "session:t2", "picked": 20, "called": 4}])
    assert "another chat called in this tab" in one and "that was its own calls" in one, one
