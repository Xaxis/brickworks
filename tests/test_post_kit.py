"""Post it elsewhere (unit postkit): a kit for each place a model is posted
to, checked against that place's rules (web/post-rules.js), made in its
designer's browser (web/post-kit.js) from what its page published.

Each test names the rule it holds a kit to and the page the rule is read
from, as PAGES in web/post-rules.js has it, and holds the kit to it both
ways: a kit that keeps it, and one that does not, said in words.

Under node, without a browser: the rules and words; what Brickworks draws
on a picture, read from its drawing (web/turntable-clip.js easel, on a
canvas that writes down every call) rather than from the picture; the zip,
read back by Python's zipfile; and the model page's facts and parts list as
the real api/share.js makes them over the design check's stand-in
(tools/web/design_stand_in.mjs). tools/web/postkit_flow.mjs makes the kits
in a browser.
"""

from __future__ import annotations

import io
import json
import re
import shutil
import subprocess
import zipfile
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent

LEGOMOC = "https://www.reddit.com/r/legomoc/"
LEGO = "https://www.reddit.com/r/lego/wiki/rules_policies_and_expected_behaviour"
HASHTAGS = "https://www.socialmediatoday.com/news/instagram-implements-new-limits-on-hashtag-use/808309/"
INSTAGRAM = "https://buffer.com/library/instagram-image-size"
IDEAS = "https://ideas.lego.com/guidelines"
REBRICKABLE_PARTS = "https://rebrickable.com/help/importing-parts/"
FLICKR = "https://www.flickr.com/groups/lego/"

URL = "https://brickworks.diy/m/Abcde12345"
FACTS = {"id": "Abcde12345", "name": "Watchtower", "url": URL, "by": "Sam Okafor", "pieces": 512, "made": "hand",
         "maker": "hand", "kind": "castle", "tags": ["tower", "medieval", "lego-castle", "Wach Turm"], "licence": "CC BY 4.0",
         "about": "", "credits": []}
ROBINS = {"how": "remix", "name": "Old tower", "by": "Robin Castell", "url": "https://brickworks.diy/m/Robin12345"}


def node(body: str) -> object:
    """[body], an async function's body returning something JSON, run in a
    fresh node process with web/post-rules.js as `r` and web/turntable-clip.js
    as `clip`."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "const r = await import('./web/post-rules.js');"
        "const clip = await import('./web/turntable-clip.js');"
        f"const out = await (async () => {{ {body} }})();"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def kit(place: str, facts: dict, made: dict) -> list[dict]:
    """[place]'s rules checked for a kit of [facts]: [made] as checksOf takes
    it, its words wordsOf's unless given."""
    return node(f"const f = {json.dumps(facts)}; const m = {json.dumps(made)};"
                f"m.words = m.words || r.wordsOf({json.dumps(place)}, f);"
                f"return r.checksOf({json.dumps(place)}, f, m);")


def rule(checks: list[dict], id_: str) -> dict:
    found = [one for one in checks if one["id"] == id_]
    assert len(found) == 1, (id_, checks)
    return found[0]


def images(n: int, width: int = 1600, height: int = 1200, text: list | None = None) -> list[dict]:
    drawn = {"layers": ["backdrop", "model"] + (["wordmark"] if text else []), "text": text or []}
    return [{"name": f"{k:02}.jpg", "width": width, "height": height, "drawn": drawn} for k in range(n)]


# ---------------------------------------------------------------------------
# r/legomoc and r/lego


def test_reddit_takes_one_to_twenty_pictures():
    # r/legomoc's rules and r/lego's: a post of its pictures, and a Reddit
    # gallery holds 20.
    for place, page in (("legomoc", LEGOMOC), ("lego", LEGO)):
        kept = rule(kit(place, FACTS, {"images": images(7)}), "images")
        assert kept["how"] == "keeps" and kept["page"] == page
        for n in (0, 21):
            broken = rule(kit(place, FACTS, {"images": images(n)}), "images")
            assert broken["how"] == "fails" and broken["said"] == f"This kit has {n}"
    # The kit draws seven: its picture, five turns and one from higher.
    plan = node("return r.planOf('legomoc');")
    assert plan["picture"] is True and len(plan["stills"]) == 6 and plan["turn"] is None


def test_reddit_flair_is_moc_for_your_own_and_sec_crediting_somebody_elses():
    # r/legomoc's MOC and SEC flairs (https://www.reddit.com/r/legomoc/):
    # SEC is somebody else's creation, its designer credited.
    own = node(f"return r.wordsOf('legomoc', {json.dumps(FACTS)});")
    assert own["flair"] == "MOC" and own["title"] == "[MOC] Watchtower, 512 pieces" and own["credit"] == ""
    remix = {**FACTS, "credits": [ROBINS]}
    theirs = node(f"return r.wordsOf('legomoc', {json.dumps(remix)});")
    assert theirs["flair"] == "SEC" and theirs["title"].startswith("[SEC] Watchtower")
    assert "Designed by Robin Castell" in theirs["words"] and ROBINS["url"] in theirs["words"]
    checks = kit("legomoc", remix, {"images": images(3)})
    assert rule(checks, "flair")["how"] == "keeps" and rule(checks, "flair")["page"] == LEGOMOC
    assert rule(checks, "credit")["how"] == "keeps"
    # Words that leave the designer out break the rule, and say whom.
    wrong = kit("legomoc", remix, {"images": images(3), "words": {**own, "flair": "SEC"}})
    assert rule(wrong, "credit")["how"] == "fails" and "Robin Castell" in rule(wrong, "credit")["said"]
    # A MOC flair on somebody else's design is wrong too.
    assert rule(kit("legomoc", remix, {"images": images(3), "words": own}), "flair")["how"] == "fails"
    # Your own remix of your own model, and one only inspired by another's,
    # or an alternate build of a set, are yours: MOC.
    for credit in ({**ROBINS, "by": "Sam Okafor"}, {"how": "inspired", "name": "Old tower", "by": "Robin Castell", "url": ""},
                   {"how": "alternate", "set": True, "name": "6080-1 King's Castle", "by": "", "url": ""}):
        said = node(f"return r.wordsOf('lego', {json.dumps({**FACTS, 'credits': [credit]})});")
        assert said["flair"] == "MOC", credit
    # A model somebody else modelled (the LDraw library's) is SEC.
    modelled = {**FACTS, "credits": [{"how": "modelled", "name": "Watchtower", "by": "Ada Lovelace", "url": "https://library.ldraw.org/omr/sets/9"}]}
    assert node(f"return r.wordsOf('legomoc', {json.dumps(modelled)});")["flair"] == "SEC"


def test_legomoc_tells_a_model_made_with_the_assistant_plainly_that_it_takes_no_ai_posts():
    # r/legomoc bans AI-made posts (https://www.reddit.com/r/legomoc/).
    made = {**FACTS, "made": "assistant", "maker": "assistant"}
    ai = rule(kit("legomoc", made, {"images": images(7)}), "ai")
    assert ai["how"] == "fails" and ai["page"] == LEGOMOC
    assert ai["said"] == ("r/legomoc does not take posts of models made with AI, and this one was made with the assistant. "
                          "This kit is not for r/legomoc.")
    assert rule(kit("legomoc", FACTS, {"images": images(7)}), "ai")["how"] == "keeps"
    # Its words say how it was made, wherever it goes.
    assert "designed with the Brickworks assistant" in node(f"return r.wordsOf('lego', {json.dumps(made)});")["words"]
    # r/lego has no such rule here.
    assert not [one for one in kit("lego", made, {"images": images(7)}) if one["id"] == "ai"]


def test_lego_says_the_one_in_ten_rule_once():
    # r/lego: at most one post in ten that can earn its poster money
    # (its rules_policies_and_expected_behaviour wiki page). The person keeps
    # it: said once, in r/lego's kit, and in no other.
    said = [one for one in kit("lego", FACTS, {"images": images(7)}) if one["id"] == "one-in-ten"]
    assert len(said) == 1 and said[0]["how"] == "yours" and said[0]["page"] == LEGO
    for place in ("legomoc", "instagram", "ideas", "rebrickable", "flickr"):
        assert not [one for one in kit(place, FACTS, {"images": images(1)}) if one["id"] == "one-in-ten"], place


# ---------------------------------------------------------------------------
# Instagram


def test_instagram_takes_a_portrait_cover_a_tall_turn_of_fifteen_seconds_and_five_hashtags():
    plan = node("return r.planOf('instagram');")
    assert plan["stills"] == [{"key": "cover", "width": 1080, "height": 1350, "turn": 0, "wordmark": True}]
    assert plan["turn"]["width"] == 1080 and plan["turn"]["height"] == 1920
    assert plan["turn"]["frames"] / plan["turn"]["fps"] <= 15
    mp4 = {"kind": "mp4", "width": 1080, "height": 1920, "ms": 4000}
    checks = kit("instagram", FACTS, {"images": images(1, 1080, 1350, ["brickworks.diy"]), "clip": mp4})
    assert all(one["how"] == "keeps" for one in checks), checks
    assert rule(checks, "cover")["page"] == INSTAGRAM and rule(checks, "turn")["page"] == INSTAGRAM
    assert rule(checks, "hashtags")["page"] == HASHTAGS
    # The wrong size, a turn too long, a WebM Instagram does not take.
    assert rule(kit("instagram", FACTS, {"images": images(1, 1080, 1080), "clip": mp4}), "cover")["said"] == "1080 × 1080"
    assert rule(kit("instagram", FACTS, {"images": images(1, 1080, 1350), "clip": {**mp4, "ms": 16000}}), "turn")["how"] == "fails"
    webm = rule(kit("instagram", FACTS, {"images": images(1, 1080, 1350), "clip": {**mp4, "kind": "webm"}}), "turn")
    assert webm["how"] == "fails" and "Instagram does not take" in webm["said"]
    assert rule(kit("instagram", FACTS, {"images": images(1, 1080, 1350), "clip": None}), "turn")["said"] == \
        "This browser could not record a turn"


def test_instagram_caption_has_five_hashtags_at_most_none_naming_the_mark_and_its_link():
    many = {**FACTS, "tags": [f"tag{k}" for k in range(20)] + ["LEGO", "legomoc"]}
    words = node(f"return r.wordsOf('instagram', {json.dumps(many)});")["words"]
    tags = re.findall(r"#(\w+)", words)
    assert len(tags) == 5 and tags[:3] == ["moc", "afol", "castle"]
    # The LEGO Group's mark is an adjective with its ® (docs/TRADEMARKS.md),
    # which no hashtag can be: never one.
    assert not [tag for tag in re.findall(r"#(\w+)", node(f"return r.wordsOf('instagram', {json.dumps(FACTS)});")["words"])
                if "lego" in tag]
    assert URL in words
    # A caption with more breaks the rule, and says how many.
    six = {"title": "", "flair": "", "credit": "", "words": f"{URL} #a1 #b2 #c3 #d4 #e5 #f6"}
    broken = rule(kit("instagram", FACTS, {"images": images(1, 1080, 1350), "clip": None, "words": six}), "hashtags")
    assert broken["how"] == "fails" and broken["said"] == "The caption has 6"
    assert node("return r.hashtagsIn('a #one, #two_2 and#not #drei');") == ["one", "two_2", "drei"]


# ---------------------------------------------------------------------------
# LEGO® Ideas


def test_ideas_takes_two_hundred_to_five_thousand_pieces():
    # https://ideas.lego.com/guidelines: 200 to 5,000 pieces.
    for pieces, how in ((199, "fails"), (200, "keeps"), (5000, "keeps"), (5001, "fails")):
        said = rule(kit("ideas", {**FACTS, "pieces": pieces}, {"images": images(7)}), "pieces")
        assert said["how"] == how and said["page"] == IDEAS, pieces
    assert rule(kit("ideas", {**FACTS, "pieces": 120}, {"images": images(7)}), "pieces")["said"] == "This has 120 pieces"


def test_ideas_takes_fifteen_pictures_at_most():
    assert rule(kit("ideas", FACTS, {"images": images(15)}), "images")["how"] == "keeps"
    assert rule(kit("ideas", FACTS, {"images": images(16)}), "images")["how"] == "fails"
    assert len(node("return r.planOf('ideas').stills;")) + 1 <= 15


def test_ideas_main_picture_has_no_text_by_what_brickworks_drew_on_it():
    # No text on the main image (https://ideas.lego.com/guidelines), read
    # without OCR: the easel the kit's pictures are drawn on (web/
    # turntable-clip.js) says each layer and each run of text it drew, and a
    # canvas here writes down every call it was given.
    drawn = node(
        "const calls = [];"
        "globalThis.OffscreenCanvas = class { constructor(w, h) { this.width = w; this.height = h; }"
        "  getContext() { return new Proxy({}, { get: (t, k) => (k in t ? t[k] : (...a) => { calls.push(String(k));"
        "    return k === 'createRadialGradient' ? { addColorStop() {} } : undefined; }), set: (t, k, v) => { t[k] = v; return true; } }); } };"
        "const plain = clip.easel({ width: 1600, height: 1200, wordmark: false }); plain.paint({});"
        "const plainCalls = calls.splice(0);"
        "const marked = clip.easel({ width: 1080, height: 1350, wordmark: true }); marked.paint({});"
        "return { plain: plain.drawn, plainCalls, marked: marked.drawn, markedCalls: calls };")
    assert drawn["plain"] == {"layers": ["backdrop", "model"], "text": []}
    assert "fillText" not in drawn["plainCalls"] and "strokeText" not in drawn["plainCalls"]
    assert drawn["marked"] == {"layers": ["backdrop", "model", "wordmark"], "text": ["brickworks.diy"]}
    assert "fillText" in drawn["markedCalls"]
    # The rule, held to that record: kept by the plain one, broken by the other.
    kept = rule(kit("ideas", FACTS, {"images": [{"name": "01.jpg", "width": 1600, "height": 1200, "drawn": drawn["plain"]}]}), "no-text")
    assert kept["how"] == "keeps" and kept["page"] == IDEAS
    broken = rule(kit("ideas", FACTS, {"images": [{"name": "01.jpg", "width": 1080, "height": 1350, "drawn": drawn["marked"]}]}), "no-text")
    assert broken["how"] == "fails" and broken["said"] == "It has brickworks.diy on it"
    # No box art: the model on a plain ground and nothing else.
    assert rule(kit("ideas", FACTS, {"images": [{"name": "01.jpg", "width": 1, "height": 1, "drawn": drawn["plain"]}]}), "no-box-art")["how"] == "keeps"
    assert rule(kit("ideas", FACTS, {"images": [{"name": "01.jpg", "width": 1, "height": 1, "drawn": drawn["marked"]}]}), "no-box-art")["how"] == "fails"
    # Every picture a kit for Ideas, Reddit, Rebrickable or Flickr draws is
    # drawn without the wordmark; Instagram's cover alone has it.
    plans = node("return r.PLACES.map((p) => [p, r.planOf(p).stills.map((s) => Boolean(s.wordmark))]);")
    for place, marks in plans:
        assert all(marks) if place == "instagram" else not any(marks), place


def test_ideas_wants_your_own_idea_and_says_brickworks_is_not_the_lego_group():
    theirs = rule(kit("ideas", {**FACTS, "credits": [ROBINS]}, {"images": images(7)}), "own")
    assert theirs["how"] == "fails" and "Robin Castell" in theirs["said"] and theirs["page"] == IDEAS
    assert rule(kit("ideas", FACTS, {"images": images(7)}), "own")["how"] == "keeps"
    assert rule(kit("ideas", FACTS, {"images": images(7)}), "renders")["how"] == "keeps"
    text = node(f"const f = {json.dumps(FACTS)}; const w = r.wordsOf('ideas', f);"
                "return r.postText('ideas', f, w, r.checksOf('ideas', f, { images: [], words: w }), 'LEGO® Ideas');")
    assert ("Brickworks is not the LEGO Group. LEGO® is a trademark of the LEGO Group of companies which does not sponsor, "
            "authorize or endorse this site.") in text
    assert f"({IDEAS})" in text


# ---------------------------------------------------------------------------
# Rebrickable and Flickr


def test_rebrickable_takes_its_parts_as_the_csv_it_imports():
    good = rule(kit("rebrickable", FACTS, {"images": images(7), "csv": "Part,Color,Quantity\n3001,4,2\n"}), "parts")
    assert good["how"] == "keeps" and good["page"] == REBRICKABLE_PARTS
    assert rule(kit("rebrickable", FACTS, {"images": images(7), "csv": ""}), "parts")["how"] == "fails"
    steps = rule(kit("rebrickable", FACTS, {"images": images(7), "csv": ""}), "instructions")
    assert steps["how"] == "yours" and "PDF" in steps["said"]


def test_flickr_takes_the_largest_picture():
    plan = node("return r.planOf('flickr');")
    assert plan["stills"] == [{"key": "largest", "width": 2560, "height": 1920, "turn": 0}]
    assert rule(kit("flickr", FACTS, {"images": images(1, 2560, 1920)}), "largest")["how"] == "keeps"
    small = rule(kit("flickr", FACTS, {"images": images(1, 1600, 1200)}), "largest")
    assert small["how"] == "fails" and small["page"] == FLICKR
    assert rule(kit("flickr", FACTS, {"images": images(1, 2560, 1920)}), "pool")["how"] == "yours"
    words = node(f"return r.wordsOf('flickr', {json.dumps(FACTS)});")
    assert words["tags"] == "moc afol castle tower medieval" and URL in words["words"]


def test_every_kit_carries_the_models_link():
    for place in node("return r.PLACES;"):
        words = node(f"return r.wordsOf({json.dumps(place)}, {json.dumps({**FACTS, 'credits': [ROBINS]})});")
        assert URL in words["words"], place
        link = rule(kit(place, FACTS, {"images": images(1)}), "link")
        assert link["how"] == "keeps", place
        cut = {**words, "words": words["words"].replace(URL, "")}
        assert rule(kit(place, FACTS, {"images": images(1), "words": cut}), "link")["how"] == "fails", place


# ---------------------------------------------------------------------------
# The zip, and what the page gives the kit


def test_the_kit_is_one_zip_every_file_whole():
    made = node(
        "const files = [{ name: '01-watchtower.jpg', bytes: Uint8Array.from([255, 216, 255, 0, 1, 2]) },"
        "  { name: 'post.txt', bytes: new TextEncoder().encode('Wachturm: 512 Teile, „schön“\\n') },"
        "  { name: 'leer.csv', bytes: new Uint8Array(0) }];"
        "const zip = r.zipOf(files, new Date(2026, 10, 23, 12, 30, 10));"
        "const all = new Uint8Array(zip.size); let at = 0; for (const p of zip.parts) { all.set(p, at); at += p.length; }"
        "return { size: zip.size, at, bytes: Array.from(all) };")
    assert made["size"] == made["at"]
    archive = zipfile.ZipFile(io.BytesIO(bytes(made["bytes"])))
    assert archive.testzip() is None
    assert archive.namelist() == ["01-watchtower.jpg", "post.txt", "leer.csv"]
    assert archive.read("post.txt").decode() == "Wachturm: 512 Teile, „schön“\n"
    assert archive.read("01-watchtower.jpg") == bytes([255, 216, 255, 0, 1, 2])
    assert archive.getinfo("post.txt").date_time == (2026, 11, 23, 12, 30, 10)
    assert node("return r.LIMITS.zipBytes;") == 50 * 1024 * 1024


def served(*asks: dict) -> list[dict]:
    """Each ask ({page} or {query}) as the real api/share.js answers it over
    the design check's stand-in: {status, body}."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "const out = [];"
        f"for (const ask of {json.dumps(list(asks))}) {{"
        "  const r = ask.page ? await s.serverPage('api', ask.page) : await s.serverAsk('api', { name: 'share', query: ask.query });"
        "  out.push({ status: r.status, body: r.html, headers: r.headers || {} }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True, timeout=300)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_the_page_gives_its_designers_kit_what_it_says_and_its_parts_csv():
    page, old, json_list, csv = served({"page": "/m/DesignAbc1"}, {"page": "/m/DesignAbc1/v/1"},
                                       {"query": {"op": "parts", "id": "DesignAbc1"}},
                                       {"query": {"op": "parts", "id": "DesignAbc1", "as": "csv"}})
    assert page["status"] == 200
    html = page["body"]
    # Post it elsewhere in Share's sheet, each place a button, hidden until
    # the page knows its designer is looking.
    group = re.search(r'<div class="post-kits" id="post-kits"[^>]*>', html)
    assert group and " hidden" in group.group(0)
    assert re.findall(r'data-kit="([a-z]+)"', html) == ["legomoc", "lego", "instagram", "ideas", "rebrickable", "flickr"]
    # What the kit is made from: what the page says, as data that cannot end
    # its script.
    island = re.search(r'<script type="application/json" id="post-facts">(.*?)</script>', html, re.S)
    assert island and "<" not in island.group(1)
    facts = json.loads(island.group(1))
    # Its pictures and its turn are shown before they are saved: blob:
    # addresses the page made, and nothing else besides the site's own.
    policy = dict(part.strip().split(" ", 1) for part in page["headers"]["content-security-policy"].split(";") if part.strip())
    assert policy["img-src"] == "'self' blob:" and policy["media-src"] == "blob:" and policy["default-src"] == "'none'"
    assert facts["id"] == "DesignAbc1" and facts["url"].endswith("/m/DesignAbc1")
    assert facts["scene"] == "/m/DesignAbc1/scene.json" and facts["parts"] == "/m/DesignAbc1/parts.json"
    assert facts["made"] in ("hand", "assistant") and isinstance(facts["pieces"], int) and facts["pieces"] > 0
    assert facts["name"] in html
    # An older version's page has no kit to make.
    assert old["status"] == 200 and 'id="post-facts"' not in old["body"]
    # The parts list the page loads carries Rebrickable's CSV, the very one
    # /m/X/parts.csv gives: the kit asks for nothing more.
    assert json_list["status"] == 200 and csv["status"] == 200
    listed = json.loads(json_list["body"])
    assert listed["rebrickable_csv"] == csv["body"] and csv["body"].startswith("Part,Color,Quantity\n")
