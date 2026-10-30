"""The site's search finds what a builder means (search, 2026-10-30).

The owner found the library's search "doesn't work very well at all": "death
star" put Death Trooper first, "deathstar" and "milenium falcon" found
nothing, "firetruck" found a bag charm, "castle" came newest first, and books
and key chains ranked with real sets. These drive the real code
(api/_search.js, api/_sets.js searchCatalog, api/_directory.js searchWords)
over the whole catalogue (assets/generated/set_catalog.json, as deployed):
tests/search_queries.tsv's searches each want one of their sets in the first
three, and each case the owner named is a test of its own, every one of which
failed on the code before.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parent.parent
CATALOGUE = ROOT / "assets" / "generated" / "set_catalog.json"

needs_catalogue = pytest.mark.skipif(shutil.which("node") is None or not CATALOGUE.exists(),
                                     reason="no node, or no assets/generated/set_catalog.json (tools/set_catalog.py)")


def node(script: str) -> Any:
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=300)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


SEARCH = """
import * as S from "./api/_sets.js";
const catalog = S.setCatalog();
const find = (q, more = {}) => {
  const found = S.searchCatalog(catalog.sets, S.askSets({ q, ...more }));
  return { total: found.total, near: found.near, meant: found.meant, sort: S.askSets({ q, ...more }).sort,
    top: found.sets.slice(0, 10).map((one) => ({ set: one.set, name: one.name, year: one.year, theme: one.theme[0] })) };
};
"""


def found(*queries: str, **more: str) -> dict[str, Any]:
    asks = ", ".join(f"{json.dumps(q)}: find({json.dumps(q)}, {json.dumps(more)})" for q in queries)
    return node(SEARCH + f"console.log(JSON.stringify({{ {asks} }}));")


@needs_catalogue
def test_the_searches_builders_type_find_what_they_mean_first_and_fast() -> None:
    done = subprocess.run(["node", "tools/web/search_score.mjs", "--json", "--bar=0"], cwd=ROOT, capture_output=True,
                          text=True, timeout=600)
    assert done.returncode == 0, done.stderr[-2000:]
    score = json.loads(done.stdout.strip().splitlines()[-1])
    assert score["of"] >= 80
    # The bar the lead set: 95% with a set meant in the first three.
    assert score["rate"] >= 0.95, score["misses"]
    # And a theme's name typed alone, every time.
    assert not [miss for miss in score["misses"] if miss["kind"] == "theme name"], score["misses"]
    # Server time on the whole catalogue, each search ten times: well under 150 ms.
    assert score["ms"]["p95"] < 150, score["ms"]


@needs_catalogue
def test_death_star_is_the_death_star_not_a_death_trooper() -> None:
    said = found("death star")["death star"]
    # Was L0002239-1 Death Trooper first: "death" in its name, "star" in Star Wars.
    assert [one["name"] for one in said["top"][:3]] == ["Death Star"] * 3
    assert said["top"][0]["set"] == "75419-1"


@needs_catalogue
def test_words_run_together_or_apart_find_the_same_sets() -> None:
    said = found("deathstar", "firetruck", "fire truck", "xwing", "x wing")
    # "deathstar" found nothing; it is the death star, and says so.
    assert said["deathstar"]["top"][0]["name"] == "Death Star" and said["deathstar"]["meant"] == "death star"
    # "firetruck" found 2 (a bag charm first), "fire truck" 49.
    assert said["firetruck"]["total"] >= 40
    assert said["firetruck"]["top"][0]["set"] == said["fire truck"]["top"][0]["set"] == "8289-1"
    assert said["xwing"]["top"][0]["set"] == said["x wing"]["top"][0]["set"] == "75355-1"


@needs_catalogue
def test_a_misspelt_word_finds_what_was_meant() -> None:
    said = found("milenium falcon", "hogwarts catsle", "lamborgini", "colloseum")
    assert said["milenium falcon"]["meant"] == "millennium falcon"
    assert said["milenium falcon"]["top"][0]["set"] == "75192-1"
    assert said["hogwarts catsle"]["meant"] == "hogwarts castle" and said["hogwarts catsle"]["top"][0]["set"] == "71043-1"
    assert said["lamborgini"]["top"][0]["name"].startswith("Lamborghini")
    assert said["colloseum"]["top"][0]["set"] == "10276-1"


@needs_catalogue
def test_a_typed_search_is_in_best_match_order_unless_another_is_chosen() -> None:
    said = found("castle")
    newest = found("castle", sort="newest")["castle"]
    browsed = node(SEARCH + 'console.log(JSON.stringify({ none: S.askSets({}).sort, match: S.askSets({ sort: "match" }).sort }));')
    # Was newest first: 72060-1, a 2027 set with no parts, then Hogwarts' east wing.
    assert said["castle"]["sort"] == "match"
    assert all(one["theme"] == "Castle" for one in said["castle"]["top"][:5])
    assert said["castle"]["top"][0]["set"] in {"375-2", "6075-2"}
    # The person's own order still works, and best match is no order with nothing typed.
    assert newest["sort"] == "newest" and newest["top"][0]["year"] >= max(one["year"] for one in newest["top"])
    assert browsed == {"none": "built", "match": "built"}


@needs_catalogue
def test_real_sets_come_before_books_and_gear_unless_they_are_asked_for() -> None:
    said = found("falcon", "hogwarts", "harry potter book", "darth vader key chain")
    # A Polish book was second for "falcon", a book first for "hogwarts".
    for q in ("falcon", "hogwarts"):
        assert not {"Books", "Gear"} & {one["theme"] for one in said[q]["top"][:5]}, said[q]["top"][:5]
    assert said["falcon"]["top"][0]["set"] == "75192-1"
    assert said["hogwarts"]["top"][0]["set"] == "71043-1"
    assert all(one["theme"] == "Books" for one in said["harry potter book"]["top"][:3])
    assert all(one["theme"] == "Gear" for one in said["darth vader key chain"]["top"][:3])


@needs_catalogue
def test_numbers_years_and_names_typed_as_builders_type_them() -> None:
    said = found("7519", "10188-1", "castle 1978", "ucs falcon", "kings castle", "pokemon")
    # A number's own set first, then the sets whose number starts so, biggest first.
    assert [one["set"] for one in said["7519"]["top"][:2]] == ["7519-1", "75192-1"]
    assert said["10188-1"]["top"][0]["set"] == "10188-1"
    assert said["castle 1978"]["top"][0]["set"] == "375-2"
    assert said["ucs falcon"]["top"][0]["set"] == "75192-1"
    assert said["kings castle"]["top"][0]["name"] == "King's Castle"
    assert said["pokemon"]["top"][0]["theme"] == "Pokémon"


@needs_catalogue
def test_a_theme_s_whole_name_is_that_theme_first() -> None:
    said = found("city", "castle", "pirates", "friends", "marvel", "ninjago", "dinosaurs")
    # "city" was NINJAGO City, then Lost City; "castle" had Hogwarts third,
    # "pirates" a Creator ship, "friends" an Icons set, "marvel" a mosaic.
    for q, theme in (("city", "City"), ("castle", "Castle"), ("pirates", "Pirates"), ("friends", "Friends"),
                     ("marvel", "Super Heroes Marvel"), ("ninjago", "Ninjago")):
        assert all(one["theme"] == theme for one in said[q]["top"][:5]), (q, said[q]["top"][:5])
    # Every LEGO City set before NINJAGO City.
    city = node("""
import { setCatalog } from "./api/_sets.js";
import { byKey, search } from "./api/_search.js";
const ordered = search(setCatalog().sets, "city").found.sort(byKey).map((one) => one.item);
const at = ordered.findIndex((one) => one.set === "70620-1");
console.log(JSON.stringify({ at, before: ordered.slice(0, at).map((one) => one.theme) }));
""")
    assert city["at"] > 1000
    assert all("City" in theme or "World City" in theme for theme in city["before"])
    # A word that is mostly not its theme's is found anywhere: the dinosaurs
    # of every theme, not 2001's Dinosaurs theme first.
    assert said["dinosaurs"]["top"][0]["set"] == "76968-1"


@needs_catalogue
def test_trains_are_today_s_trains() -> None:
    said = found("trains", "train")
    # Was 1969's Train Set, then 1964's Train.
    for q in ("trains", "train"):
        assert all(one["year"] >= 2015 and "Train" in one["name"] for one in said[q]["top"][:3]), said[q]["top"][:3]
        assert all(one["year"] >= 2010 for one in said[q]["top"][:5]), said[q]["top"][:5]


@needs_catalogue
def test_no_set_with_every_word_answers_the_nearest() -> None:
    said = found("castle xyzzy", "xyzzy")
    assert said["castle xyzzy"]["near"] is True and said["castle xyzzy"]["total"] > 100
    assert "Castle" in said["castle xyzzy"]["top"][0]["name"]
    assert said["xyzzy"]["total"] == 0 and said["xyzzy"]["near"] is False


@needs_catalogue
def test_the_gallery_s_words_are_as_forgiving_as_the_library_s() -> None:
    said = node("""
import { searchWords } from "./api/_directory.js";
import { setCatalog } from "./api/_sets.js";
import { indexOf } from "./api/_search.js";
const words = indexOf(setCatalog().sets);
const asks = ["fire truck", "spaceship", "milenium falcon", "Pokémon", "the lego batman movie", "castles", "a"];
console.log(JSON.stringify(Object.fromEntries(asks.map((q) => [q, [searchWords(q), searchWords(q, words)]]))));
""")
    # Without the catalogue's words, as before.
    assert said["castles"] == ["castle:*", "castle:*"]
    assert said["a"] == [None, None]
    # Written apart, it is the word written as one too, and run together, apart.
    assert said["fire truck"][1] == "((fire:* & truck:*) | firetruck:*)"
    assert said["spaceship"][1] == "(spaceship:* | (space <-> ship:*))"
    # Misspelt, the word it nearly is too; accented, without its accents too.
    assert said["milenium falcon"][1] == "(milenium:* | millennium:*) & falcon:*"
    assert said["Pokémon"][0] == "(pokémon:* | pokemon:*)"
    # Small words narrow nothing.
    assert said["the lego batman movie"][0] == "batman:* & movie:*"
