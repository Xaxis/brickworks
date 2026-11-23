"""Twelve remix pairs, each an original and a remix of it made by one kind of
edit or by several (remixdiff, 2026-11-23): what the site counts a remix
changed (api/_remix_changes.js) is held to the app's Compare on these
files (src/dev/compare_probe.gd, tests/test_remix_changes.py).

    python3 tests/fixtures/remix_pairs/make_pairs.py      writes <name>.was.ldr and <name>.now.ldr here

The original is a cottage of 38 parts on a floor of plates: walls, a row of
ten 1 x 1 bricks, two windows (one sub-model placed twice, in white through
colour 16), round bricks of the old solid-stud mould, plates by a retired
number (3023, moved to 3023b), a tyre by one whose stub turns it (3139 to
3139b), a slope LDraw keeps only in blue (303923), and a brick by BrickLink
Studio's name for it (bl_3001). Each remix is that file with its edits.
"""

from __future__ import annotations

from pathlib import Path

HERE = Path(__file__).resolve().parent
I = (1, 0, 0, 0, 1, 0, 0, 0, 1)
QUARTER = (0, 0, 1, 0, 1, 0, -1, 0, 0)     # a quarter turn round the vertical
HALF = (-1, 0, 0, 0, 1, 0, 0, 0, -1)       # a half turn round the vertical
# 3139's stub puts 3139b a quarter turn round: what Update all writes.
TYRE_STUB = (0, 0, -1, 0, 1, 0, 1, 0, 0)


def line(colour, x, y, z, part, turn=I):
    numbers = " ".join(str(v) for v in (x, y, z, *turn))
    return f"1 {colour} {numbers} {part if part.endswith('.ldr') else part + '.dat'}"


def cottage():
    """The original's parts, as {name: line}, in file order."""
    parts = {}
    for row, z in enumerate((-80, 0, 80)):
        for column, x in enumerate((-60, -20, 20, 60)):
            parts[f"floor{row}{column}"] = line(2, x, 0, z, "3020")
    for k, x in enumerate((-60, -20, 20, 60)):
        parts[f"wall_back{k}"] = line(4, x, -8, -100, "3001", QUARTER)
    parts["wall_left"] = line(4, -80, -8, 0, "3001")
    parts["wall_right"] = line(4, 80, -8, 0, "3001")
    for k in range(10):
        parts[f"row{k}"] = line(15, -90 + 20 * k, -32, -100, "3005")
    parts["round_a"] = line(14, -40, -8, 40, "3062a")
    parts["round_b"] = line(14, 40, -8, 40, "3062a")
    parts["old_plate_a"] = line(0, -40, -8, -40, "3023")
    parts["old_plate_b"] = line(0, 40, -8, -40, "3023")
    parts["tyre"] = line(0, 0, -8, 60, "3139")
    parts["blue_slope"] = line(16, 0, -32, 0, "303923")
    parts["red_slope"] = line(4, 0, -56, 0, "3039")
    parts["studio_brick"] = line(1, 0, -8, -60, "bl_3001")
    parts["window1"] = line(15, -60, -8, 100, "window.ldr")
    parts["window2"] = line(15, 60, -8, 100, "window.ldr")
    return parts


WINDOW = ["1 16 0 0 0 1 0 0 0 1 0 0 0 1 3010.dat",
          "1 47 -20 -24 0 1 0 0 0 1 0 0 0 1 3024.dat",
          "1 47 20 -24 0 1 0 0 0 1 0 0 0 1 3024.dat"]
CHIMNEY = ["1 71 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat",
           "1 71 0 -24 0 1 0 0 0 1 0 0 0 1 3003.dat",
           "1 72 0 -48 0 1 0 0 0 1 0 0 0 1 3003.dat",
           "1 0 0 -56 0 1 0 0 0 1 0 0 0 1 3022.dat"]


def written(parts, window=WINDOW, extra=()):
    out = ["0 FILE cottage.ldr", "0 Cottage", "0 Name: cottage.ldr", "0 Author: Brickworks", ""]
    out += list(parts.values())
    out += ["0 NOFILE", "", "0 FILE window.ldr", "0 Window", "0 Name: window.ldr", *window, "0 NOFILE"]
    for name, title, body in extra:
        out += ["", f"0 FILE {name}", f"0 {title}", f"0 Name: {name}", *body, "0 NOFILE"]
    return "\n".join(out) + "\n"


def pairs():
    base = cottage()

    def edit(**changes):
        parts = dict(base)
        for name, value in changes.items():
            if value is None:
                del parts[name]
            else:
                parts[name] = value
        return parts

    out = {}
    # 1. Five bricks added on the floor.
    added = {f"new{k}": line(14, -60 + 30 * k, -8, 20, "3003") for k in range(5)}
    out["01_add"] = (written(base), written({**base, **added}))
    # 2. Two plates of the floor, a brick from the row's middle and the red
    #    slope taken away.
    out["02_remove"] = (written(base), written(edit(floor00=None, floor23=None, row4=None, red_slope=None)))
    # 3. A wall recoloured, a window's copy recoloured through colour 16 (its
    #    1 x 4 brick, not its clear plates, which are their own colour) and a
    #    round brick painted.
    out["03_recolour"] = (written(base), written(edit(wall_left=line(1, -80, -8, 0, "3001"),
                                                      window2=line(1, 60, -8, 100, "window.ldr"),
                                                      round_a=line(4, -40, -8, 40, "3062a"))))
    # 4. A wall moved two studs, a plate of the floor up a plate, a 1 x 1
    #    brick a single LDU and the Studio-named brick a stud along.
    out["04_move"] = (written(base), written(edit(wall_right=line(4, 120, -8, 0, "3001"),
                                                  floor11=line(2, -20, -8, 0, "3020"),
                                                  row9=line(15, 91, -32, -100, "3005"),
                                                  studio_brick=line(1, 20, -8, -60, "bl_3001"))))
    # 5. Two walls a quarter turn where they stand, a round brick half a turn.
    out["05_turn"] = (written(base), written(edit(wall_left=line(4, -80, -8, 0, "3001", QUARTER),
                                                  wall_back0=line(4, -60, -8, -100, "3001"),
                                                  round_b=line(14, 40, -8, 40, "3062a", HALF))))
    # 6. A mould swapped: both round bricks to the hollow-stud 3062b; and the
    #    retired numbers written as the parts they became, as Update all
    #    writes them (3023b where 3023 stood, 3139b turned as 3139's stub
    #    turns it), which the app reads as the same parts.
    out["06_swap_mould"] = (written(base), written(edit(round_a=line(14, -40, -8, 40, "3062b"),
                                                        round_b=line(14, 40, -8, 40, "3062b"),
                                                        old_plate_a=line(0, -40, -8, -40, "3023b"),
                                                        old_plate_b=line(0, 40, -8, -40, "3023b"),
                                                        tyre=line(0, 0, -8, 60, "3139b", TYRE_STUB))))
    # 7. A sub-model added (a chimney of four) and one part added to the
    #    window, which is placed twice: six parts added.
    chimney = {"chimney": line(16, 60, -80, -60, "chimney.ldr")}
    out["07_sub_model_added"] = (written(base),
                                 written({**base, **chimney}, window=WINDOW + ["1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3024.dat"],
                                         extra=[("chimney.ldr", "Chimney", CHIMNEY)]))
    # 8. Two added, one taken away, one recoloured.
    out["08_mix_add_remove_recolour"] = (written(base), written({**edit(row0=None, wall_back3=line(14, 60, -8, -100, "3001", QUARTER)),
                                                                 "door": line(70, 0, -8, 100, "3001"),
                                                                 "step": line(7, 0, 0, 130, "3022")}))
    # 9. One moved, one turned and one recoloured, and a part both moved and
    #    painted, which is one taken away and one added.
    out["09_mix_move_turn_recolour"] = (written(base), written(edit(wall_left=line(4, -80, -8, 40, "3001"),
                                                                    wall_back1=line(4, -20, -8, -100, "3001"),
                                                                    red_slope=line(1, 0, -56, 0, "3039"),
                                                                    round_a=line(4, -40, -8, -20, "3062a"))))
    # 10. A copy of the window moved a stud: its three parts moved; and the
    #     other copy's reference turned half round: its three turned.
    out["10_mix_sub_model_moved"] = (written(base), written(edit(window2=line(15, 80, -8, 100, "window.ldr"),
                                                                 window1=line(15, -60, -8, 100, "window.ldr", HALF))))
    # 11. Ten alike in a row, one moved to the end (one moved, not one taken
    #     away and one put down); and a plate of the floor taken from one
    #     corner and one put down beyond another (one moved).
    out["11_mix_ten_alike"] = (written(base), written(edit(row3=line(15, 110, -32, -100, "3005"),
                                                           floor20=None, extra_floor=line(2, 100, 0, 80, "3020"))))
    # 12. Old numbers: the blue-only slope as the slope it draws in blue,
    #     the Studio name as LDraw's number (both the same parts to the
    #     app), the tyre by its new number without its stub's turn (turned),
    #     and a line that places nothing (no size), which nothing reads.
    out["12_mix_old_numbers"] = (written(base), written({**edit(blue_slope=line(1, 0, -32, 0, "3039"),
                                                                studio_brick=line(1, 0, -8, -60, "3001"),
                                                                tyre=line(0, 0, -8, 60, "3139b")),
                                                         "nothing": line(4, 0, -100, 0, "3001", (0, 0, 0, 0, 0, 0, 0, 0, 0))}))
    return out


def main():
    for name, (was, now) in pairs().items():
        (HERE / f"{name}.was.ldr").write_text(was)
        (HERE / f"{name}.now.ldr").write_text(now)
        print(name)


if __name__ == "__main__":
    main()
