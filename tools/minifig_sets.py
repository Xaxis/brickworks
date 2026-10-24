#!/usr/bin/env python3
"""Which minifigure parts real sets use, and with what.

A design asks for a figure in a few words: "smile", "beard", "captain hat".
Matched against LDraw's names alone, "smile" was a baby's head and "grin"
SpongeBob's, and "beard" was Tony Stark's (walk180, 2026-10-23): the names
say what is printed, not whose face it is. Rebrickable's set inventories
say whose: a head that only Marvel sets carry is Tony Stark however LDraw
names it. So for every minifigure part this joins to an inventory, how many
sets carry it, and how many of those are not a licence or a theme's cast of
named characters — the parts a generic word may be answered with.

And the arms real sets put with a plain torso of each colour: a figure told
only that its torso is black came out with the default red arms, which no
set pairs with black. Rebrickable names each torso assembly by its arms'
and hands' colours ("Torso, Black Arms, Yellow Hands [Plain]"), so the
pairs are counted from every figure inventory there is.

Reads vendor/rebrickable/*.csv.gz and assets/generated/{catalogue,colors}.json;
writes assets/knowledge/minifig_sets.json. tools/refresh_catalogue.py runs it
after each refresh.

    tools/minifig_sets.py [--generated DIR] [--out FILE]
"""

from __future__ import annotations

import argparse
import collections
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import rebrickable as rb  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "knowledge" / "minifig_sets.json"

# Themes whose figures are somebody's characters: a licence, or one of
# LEGO's own story lines with a named cast. Matched against every name on a
# theme's path, so "Collectible Minifigures > The Simpsons Series 1" is one
# and "Collectible Minifigures > Series 4 Minifigures" is not.
CHARACTER_THEMES = [
    "Star Wars", "Super Heroes", "Marvel", "DC", "Batman", "Spider-Man",
    "Disney", "Harry Potter", "Fantastic Beasts", "Minecraft", "Super Mario",
    "Jurassic", "The Hobbit", "Lord of the Rings", "Pokémon", "Cars",
    "Toy Story", "Unikitty", "Sonic", "Indiana Jones", "Ninja Turtles",
    "Animal Crossing", "One Piece", "Fortnite", "SpongeBob", "Overwatch",
    "Gabby", "Wicked", "Scooby-Doo", "Bluey", "Minions", "Despicable Me",
    "Trolls", "Avatar", "Lone Ranger", "Wednesday", "Angry Birds", "Ben 10",
    "Speed Racer", "Stranger Things", "Powerpuff", "Ghostbusters", "Zelda",
    "Shrek", "KPop", "Horizon", "Simpsons", "Looney Tunes", "Muppets",
    "Prince of Persia", "Pirates of the Caribbean", "Back to the Future",
    "Dungeons & Dragons", "Formula 1", "Team GB", "DFB", "The LEGO Movie",
    "Ninjago", "Legends of Chima", "Nexo Knights", "Monkie Kid",
    "Hidden Side", "Dreamzzz", "Mixels", "Bionicle", "Hero Factory", "Elves",
    "VIDIYO", "Dimensions", "Brickheadz", "Galidor", "Agents", "Exo-Force",
    "Power Miners", "Atlantis", "Monster Fighters", "Ultra Agents",
]
CHARACTER = re.compile(r"\b(" + "|".join(re.escape(t) for t in CHARACTER_THEMES) + r")\b",
                       re.IGNORECASE)
# "Torso, Black Arms, Yellow Hands [Plain]", "Torso, Yellow Arms and Hands".
ARMS = re.compile(r",\s*([A-Za-z][A-Za-z -]*?) Arms\b")


def main() -> None:
    ask = argparse.ArgumentParser(description="Which minifigure parts real sets use.")
    ask.add_argument("--generated", type=Path, default=ROOT / "assets" / "generated",
                     help="the catalogue.json and colors.json to join with")
    ask.add_argument("--out", type=Path, default=OUT)
    args = ask.parse_args()
    catalogue = json.loads((args.generated / "catalogue.json").read_text())
    colours = json.loads((args.generated / "colors.json").read_text())
    ldraw_of_colour = {int(c["rebrickable_id"]): int(c["code"]) for c in colours
                       if c.get("rebrickable_id") is not None}
    rb_colour_named = {r["name"].lower(): int(r["id"]) for r in rb._rows("colors")}

    themes = {r["id"]: r for r in rb._rows("themes")}

    def path(theme: str) -> str:
        out = []
        while theme:
            out.append(themes[theme]["name"])
            theme = themes[theme]["parent_id"]
        return " > ".join(reversed(out))

    character_set: dict[str, bool] = {}
    for row in rb._rows("sets"):
        if row["theme_id"] in themes:
            character_set[row["set_num"]] = CHARACTER.search(path(row["theme_id"])) is not None

    inventory_set = {r["id"]: r["set_num"] for r in rb._rows("inventories") if r["version"] == "1"}
    # A figure's own inventory, and the sets that carry the figure.
    fig_sets: dict[str, set[str]] = collections.defaultdict(set)
    for row in rb._rows("inventory_minifigs"):
        owner = inventory_set.get(row["inventory_id"])
        if owner is not None and owner in character_set:
            fig_sets[row["fig_num"]].add(owner)

    rb_name = {r["part_num"]: r["name"] for r in rb._rows("parts")}
    part_sets: dict[str, set[str]] = collections.defaultdict(set)
    arm_pairs: dict[int, collections.Counter] = collections.defaultdict(collections.Counter)
    for row in rb._rows("inventory_parts"):
        owner = inventory_set.get(row["inventory_id"])
        if owner is None or row["is_spare"] != "False":
            continue
        part = row["part_num"]
        carried = fig_sets.get(owner, {owner} if owner in character_set else set())
        part_sets[part].update(carried)
        # A plain torso's arms, from the assembly's own name.
        if part.startswith("973c") and "pr" not in part and owner.startswith("fig-"):
            found = ARMS.search(rb_name.get(part, ""))
            torso = ldraw_of_colour.get(int(row["color_id"]))
            arms = rb_colour_named.get(found.group(1).strip().lower()) if found else None
            if torso is not None and arms is not None and arms in ldraw_of_colour:
                arm_pairs[torso][ldraw_of_colour[arms]] += 1

    out_parts: dict[str, list[int]] = {}
    for entry in catalogue["parts"]:
        name = entry.get("name", "")
        if not (name.startswith("Minifig") or str(entry.get("category", "")).startswith("Minifig")):
            continue
        rb_id = None
        for word in entry.get("keywords", []):
            if word.lower().startswith("rebrickable ") and len(word.split()) == 2:
                rb_id = word.split()[1]
                break
        if rb_id is None and entry["id"] in part_sets:
            rb_id = entry["id"]
        if rb_id is None or rb_id not in part_sets:
            continue
        carried = part_sets[rb_id]
        generic = sum(1 for s in carried if not character_set.get(s, False))
        out_parts[entry["id"]] = [len(carried), generic]

    arms = {str(torso): [[code, n] for code, n in pairs.most_common(6)]
            for torso, pairs in sorted(arm_pairs.items())}
    args.out.write_text(json.dumps({
        "format": 1,
        "about": "Minifigure part -> [sets that carry it, of which not a licence or a "
                 "named cast]; plain torso colour -> [[arm colour, figures]], "
                 "from Rebrickable's set inventories (tools/minifig_sets.py).",
        "parts": dict(sorted(out_parts.items())),
        "plain_arms": arms,
    }, separators=(",", ":")) + "\n")
    print(f"{len(out_parts)} parts, {sum(1 for v in out_parts.values() if v[1] == 0)} "
          f"only in character themes; {len(arms)} torso colours with arms -> {args.out}")


if __name__ == "__main__":
    main()
