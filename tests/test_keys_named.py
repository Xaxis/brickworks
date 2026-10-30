"""Every key the app names to a person is the keymap's (src/ui/keymap.gd).

Since keys have presets and can be set in the keys sheet (APP_UX A11), a
message that spells a key out is wrong under Studio's or LDCad's keys, or
after a person sets their own: "Alt-H shows everything" is Ctrl-Shift-L
under Studio's. So a key a person can set is named by Keymap.said(), and
this fails on any string in src/ that spells one out.

A key a person can set is the key of a command in the menus' table
(Shell._add in src/ui/shell.gd), of one of Keymap.KEY_ACTIONS, or of a tool
in the app's own preset. Keymap.FIXED (Esc, Enter, Tab, F1...) are never
anybody's to set and may be spelled out, as may a modifier on a mouse
gesture ("Shift-click", "Ctrl-drag"). A single letter is a key where it is
written as one: "(Y)", "R turns", "J again", "press P", "Esc or V".
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"

# Where a key is spelled out and that is right, or is another unit's to
# change, each with why. A line here that no longer matches fails too, so
# the list cannot outlive what it excuses.
EXCUSED = {
    # The shared model's viewer answers its own keys, whatever the keymap
    # (Main reads the keymap only while no shared model is being viewed).
    ("src/ui/share_view.gd", "Step through the build (B)"),
    ("src/ui/share_view.gd", "Every part, with BrickLink and Rebrickable lists (P)"),
    # The Move tool's own words are the handles unit's (B3), which is
    # changing what Move does; it names R by the keymap there.
    ("src/ui/edit_verbs.gd", "moving %s — click to put down, R turns, Esc puts back"),
    # Connect's site choice is the connect2 unit's, rewriting these lines.
    ("src/ui/connect_tool.gd", "Connect: aim the part at the model first, then N"),
    ("src/ui/connect_tool.gd", "Connect: aim its %s at a %s · N picks another point · Esc stops"),
    ("src/ui/connect_tool.gd", "Connect: the %s picked — click the %s it goes on, R turns it about the joint"),
    ("src/ui/connect_tool.gd",
     "Connect: by its %s on %s · click puts it there · R turns it about the joint · T the other way on · N another point · Esc stops"),
    # The tour is the firstbuild unit's (A12), rewriting it. When one of
    # these units' work is merged, its lines here go.
    ("src/ui/tour.gd", "The tools a click acts through. Select is where the app rests: click a part to pick it out, "
     "drag it to move it. Place puts the part in hand down, one click at a time (Q). Move, Rotate, Hinge, Clone, "
     "Paint, Hide and Delete each do their one thing to the part you click. The lit one is in use; Escape always "
     "comes back to Select."),
    ("src/ui/tour.gd", "Right-drag turns the view, the middle button (or Shift and a right drag) slides it, the wheel "
     "zooms to the pointer — as in BrickLink Studio, or set it to work like Blender or Mecabricks in Settings. The "
     "numbers 1 to 7 look from the front, back, sides, above, below and a corner; F frames what is selected."),
}
# Not shown to a person: the keymap itself, the probes, and what the
# assistant is told (src/ai), which names parts like "Saturn V"...
SKIPPED = ("src/dev/", "src/ui/keymap.gd", "src/ai/",
           # ...and what a session is told of each tool (part=N, turns (1)).
           "src/net/app_tools.gd")

KEY_NAMES = {f"KEY_{c}": c for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"}
KEY_NAMES.update({f"KEY_F{n}": f"F{n}" for n in range(1, 13)})
KEY_NAMES.update({"KEY_DELETE": "Delete", "KEY_INSERT": "Insert", "KEY_SLASH": "/", "KEY_EQUAL": "=",
                  "KEY_MINUS": "-", "KEY_BRACKETLEFT": "[", "KEY_BRACKETRIGHT": "]", "KEY_COMMA": ",",
                  "KEY_PERIOD": ".", "KEY_QUOTELEFT": "`", "KEY_PAGEUP": "Page Up", "KEY_PAGEDOWN": "Page Down",
                  "KEY_LEFT": "Left", "KEY_RIGHT": "Right", "KEY_UP": "Up", "KEY_DOWN": "Down"})
MODS = {"CTRL": "ctrl", "SHIFT": "shift", "ALT": "alt"}


def _accel(expr: str) -> tuple[frozenset[str], str] | None:
    """`CTRL | SHIFT | KEY_Z` as ({ctrl, shift}, "Z"); None for 0 or what
    is worked out (a loop's keys)."""
    tokens = [t.strip() for t in expr.split("|")]
    mods = frozenset(MODS[t] for t in tokens if t in MODS)
    keys = [KEY_NAMES[t] for t in tokens if t in KEY_NAMES]
    if len(keys) != 1 or len(mods) + 1 != len(tokens):
        return None
    return mods, keys[0]


def settable_keys() -> set[tuple[frozenset[str], str]]:
    """Every key a person can set: the keys of the menus' commands, of
    Keymap.KEY_ACTIONS and of the app's own preset."""
    shell = (SRC / "ui/shell.gd").read_text(encoding="utf-8")
    keymap = (SRC / "ui/keymap.gd").read_text(encoding="utf-8")
    found = set()
    for expr in re.findall(r'_add\("[a-z0-9_]+",\s*"[^"]*",\s*(?:0 if web else )?([A-Z_0-9| ]+),', shell):
        found.add(_accel(expr))
    # ...and those made in a loop over a table: the tools, the views.
    for expr in re.findall(r'\["[a-z0-9_]+",\s*"[^"]*",\s*([A-Z_0-9| ]+)[\],]', shell):
        found.add(_accel(expr))
    actions = keymap[keymap.index("const KEY_ACTIONS"): keymap.index("const DONE_AS")]
    for expr in re.findall(r'\["[a-z0-9_]+", "[^"]*", ([A-Z_0-9| ]+)\]', actions):
        found.add(_accel(expr))
    own = keymap[keymap.index('"brickworks": {'): keymap.index('"studio": {')]
    for expr in re.findall(r'"[a-z_]+": ([A-Z_0-9| ]+)', own):
        found.add(_accel(expr))
    fixed = keymap[keymap.index("const FIXED"): keymap.index("const BROWSER_KEEPS")]
    for name in re.findall(r"KEY_[A-Z_0-9]+", fixed):
        found.discard((frozenset(), KEY_NAMES.get(name, name)))
    found.discard(None)
    return found


def strings(text: str) -> list[tuple[int, str]]:
    """A GDScript file's string literals, by line, comments left out."""
    out = []
    line, at, n = 1, 0, len(text)
    while at < n:
        ch = text[at]
        if ch == "\n":
            line += 1
        elif ch == "#":
            while at < n and text[at] != "\n":
                at += 1
            continue
        elif text.startswith('"""', at):
            end = text.find('"""', at + 3)
            end = n if end < 0 else end
            out.append((line, text[at + 3: end]))
            line += text.count("\n", at, end)
            at = end + 3
            continue
        elif ch in "\"'":
            start, begun = at + 1, line
            at += 1
            while at < n and text[at] != ch:
                if text[at] == "\\":
                    at += 1
                elif text[at] == "\n":
                    line += 1
                at += 1
            out.append((begun, text[start:at]))
        at += 1
    return out


KEY = r"(F1[0-2]|F[1-9]|Delete|Insert|Page Up|Page Down|[A-Z0-9/=\[\],.`])"
MODIFIED = re.compile(r"(?<![A-Za-z])((?:(?:ctrl|cmd|alt|shift|%s)[-+])+)" + KEY + r"(?![A-Za-z0-9])", re.I)
# A letter written as a key: in brackets, before what it does, or after
# "press", "Esc or" or "then"; the views' keys as "the keys 1 to 7"...
ALONE = [
    re.compile(r"\(([A-Z0-9])(?: again)?\)"),
    re.compile(r"(?<![\w-])([A-Z]) (?:again|turns|to turn|puts|shows|moves|paints|copies|removes|for |or Esc"
               r"|the other way|another|and the Rotate|frames|picks)"),
    re.compile(r"(?:[Pp]ress|Esc or|how far|then) ([A-Z])(?![\w-])"),
    re.compile(r"(?:numbers|keys) ([0-9]) to ([0-9])"),
    re.compile(r"(?<![\w-])([A-Z]), ([A-Z]), ([A-Z]) and ([A-Z])(?![\w-])"),
    # ...or set apart at a tooltip's end ("Fit the model   F"), or an
    # accessible name's ("Fit, F").
    re.compile(r"(?:  |, )([A-Z0-9])(?:$|\\n)"),
]


def spelled(text: str) -> list[tuple[frozenset[str], str]]:
    """The keys [text] spells out, each with its modifiers."""
    found = []
    for m in MODIFIED.finditer(text):
        mods = frozenset("ctrl" if p.lower() in ("cmd", "%s") else p.lower()
                         for p in re.split(r"[-+]", m.group(1)) if p)
        found.append((mods, m.group(2).upper() if len(m.group(2)) == 1 else m.group(2)))
    for pattern in ALONE:
        for m in pattern.finditer(text):
            found.extend((frozenset(), key) for key in m.groups())
    return found


def offenders() -> tuple[list[str], set[tuple[str, str]]]:
    settable = settable_keys()
    found, excused = [], set()
    for path in sorted(SRC.rglob("*.gd")):
        rel = path.relative_to(ROOT).as_posix()
        if rel.startswith(SKIPPED):
            continue
        for line, text in strings(path.read_text(encoding="utf-8")):
            keys = [k for k in spelled(text) if k in settable]
            if not keys:
                continue
            if (rel, text) in EXCUSED:
                excused.add((rel, text))
                continue
            named = ", ".join("-".join(sorted(mods) + [key]) for mods, key in keys)
            found.append(f"{rel}:{line}: {named} in \"{text}\"")
    return found, excused


def test_the_rules_find_what_they_should() -> None:
    settable = settable_keys()
    assert (frozenset({"alt"}), "H") in settable  # Show everything
    assert (frozenset({"shift"}), "X") in settable  # the Move tool, the app's own preset
    assert (frozenset(), "R") in settable  # turn the part in hand
    assert (frozenset(), "V") in settable and (frozenset(), "Q") in settable  # tools made in a loop
    assert (frozenset(), "1") in settable  # a view, from its table
    assert (frozenset(), "Esc") not in settable and (frozenset(), "F1") not in settable
    assert spelled("hid 2 parts — Alt-H, or %s-H with nothing selected, shows everything") == [
        (frozenset({"alt"}), "H"), (frozenset({"ctrl"}), "H")]
    assert spelled("swung 2 parts — J again, Shift-J back") == [(frozenset({"shift"}), "J"), (frozenset(), "J")]
    assert spelled("Cut away the other side   Shift+K") == [(frozenset({"shift"}), "K")]
    assert spelled("x-ray (I)") == [(frozenset(), "I")]
    assert spelled("Slide the view: W, A, S and D") == [(frozenset(), k) for k in "WASD"]
    assert spelled("Fit the selection, or the whole model   F") == [(frozenset(), "F")]
    assert spelled("Place %s   Q\\n%s") == [(frozenset(), "Q")] and spelled("Fit, F") == [(frozenset(), "F")]
    # A gesture, an axis and a set's name are not keys.
    assert spelled("Shift-click turns it back, Ctrl-drag copies, Alt-click takes it") == []
    assert spelled("dragged along X, Y or Z") == []
    assert spelled("Saturn V, the first stage") == []
    assert strings('const A := """<svg r="3"/>"""\nvar b := "R turns" # "C paints"\n') == [
        (1, '<svg r="3"/>'), (2, "R turns")]


def test_no_string_spells_out_a_key_a_person_can_set() -> None:
    found, _ = offenders()
    assert not found, (f"{len(found)} strings spell out a key a person can set: name it with "
                       "Keymap.said(<command>) instead\n  " + "\n  ".join(found))


def test_every_excuse_is_still_needed() -> None:
    _, excused = offenders()
    stale = EXCUSED - excused
    assert not stale, "excused in tests/test_keys_named.py but no longer found:\n  " + "\n  ".join(
        f"{rel}: {text}" for rel, text in sorted(stale))
