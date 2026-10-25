"""Who modelled a model its sharer did not make, and its own licence
(gallery261, 2026-10-25): the gallery's shelf from the LDraw library.

supabase/modelled_by.sql adds shared_models.modelled_by, lets a model be
CC BY 2.0 (LDraw's CCAL 2.0) and defines again in full made_with.sql's
directory_card, so a key left out of the copy would be lost the day the
file is applied, with nothing failing. These hold the files together (the
copy keeps everything; the licences are the same ids in the SQL, the site
and the app's gallery tool; the credit line the app writes is the one the
server reads) and drive the real code: the server reads whom a file
credits, the card and the page say "Modelled by" them, and the licence
words credit them, never the account that shares it. What the SQL does is
proven by tools/modelled_by_try.sql in a rolled-back dry run, and that the
gallery answers as before by tools/sql_compare.mjs.
"""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

SQL = (ROOT / "supabase/modelled_by.sql").read_text()
MADE_WITH = (ROOT / "supabase/made_with.sql").read_text()
DIRECTORY = (ROOT / "api/_directory.js").read_text()
STORE = (ROOT / "src/parts/model_store.gd").read_text()
LIBRARY = (ROOT / "src/net/model_library.gd").read_text()
TOOL = (ROOT / "src/net/gallery_tool.gd").read_text()
LATER = (ROOT / "supabase/later.tsv").read_text()

def function(text: str, name: str) -> str:
    found = re.findall(rf"create or replace function public\.{name}\(.*?\$\$(.*?)\$\$", text, flags=re.S)
    assert found, f"no public.{name} in the file"
    return found[-1]


def squash(text: str) -> str:
    return re.sub(r"\s+", " ", re.sub(r"--[^\n]*", "", text)).strip()


def node(script: str) -> object | None:
    if shutil.which("node") is None:
        return None
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_directory_card_is_made_with_sql_s_and_modelled_by() -> None:
    before = function(MADE_WITH, "directory_card")
    after = function(SQL, "directory_card")
    keys = re.findall(r"'([a-z_]+)', ", before)
    assert len(keys) >= 20
    for key in keys:
        assert f"'{key}', " in after, f"directory_card has lost {key}"
    assert squash(after).replace("'modelled_by', m.modelled_by, ", "") == squash(before)
    assert "made_with.sql\tdirectory_card\tmodelled_by.sql\t'modelled_by', m.modelled_by" in LATER


def test_the_licences_are_the_same_ids_in_the_sql_the_site_and_the_gallery_tool() -> None:
    check = re.search(r"check \(licence is null or licence in \(([^)]*)\)\)", SQL)
    assert check
    in_sql = sorted(re.findall(r"'([a-z0-9.-]+)'", check[1]))
    block = re.search(r"export const LICENCES = \{(.*?)\n\};", DIRECTORY, flags=re.S)[1]
    in_site = sorted(re.findall(r'^  "([a-z0-9.-]+)": \{', block, flags=re.M))
    in_tool = sorted(re.findall(r'^\t"([a-z0-9.-]+)": \[', re.search(r"const LICENCES: Dictionary = \{(.*?)\n\}", TOOL,
                                                                  flags=re.S)[1], flags=re.M))
    assert in_sql == in_site == in_tool == ["all-rights-reserved", "cc-by-2.0", "cc-by-4.0", "cc-by-sa-4.0"]
    assert '"https://creativecommons.org/licenses/by/2.0/"' in DIRECTORY


def test_the_credit_line_the_app_writes_is_the_one_the_server_reads_its_page_from() -> None:
    assert 'const CREDIT_META := "0 !BRICKWORKS CREDIT "' in STORE
    assert "const FROM := \"LDraw's Official Model Repository\"" in LIBRARY
    assert "export const LDRAW_FROM = \"LDraw's Official Model Repository\";" in DIRECTORY
    assert "/^0 !BRICKWORKS CREDIT (\\{.*\\})[ \\t\\r]*$/m" in (ROOT / "api/_omr_credit.js").read_text()
    # The server never takes a name from the file: nothing in it reads "by".
    assert "said.by" not in (ROOT / "api/_omr_credit.js").read_text() and "modelledByIn" not in DIRECTORY


FIXTURE = ROOT / "tests/fixtures/omr_credit"


def credits(*texts: str) -> list | None:
    """What the server finds of who modelled each of [texts], as publishing
    asks it (api/_omr_credit.js libraryCredit), from a small copy of the
    app's Library (tests/fixtures/omr_credit: the index's entry for 346-2,
    another model of its page whose file is not there, and 6080-1) in place
    of the parts store, its parts counted by the real checkModel."""
    return node(
        "const { libraryCredit } = await import('./api/_omr_credit.js');"
        "const { checkModel } = await import('./api/share.js');"
        "const { readFileSync, existsSync } = await import('node:fs');"
        f"const root = {json.dumps(str(FIXTURE))};"
        "const index = async () => JSON.parse(readFileSync(root + '/library/index.json', 'utf8')).models;"
        "const file = async (entry) => existsSync(root + '/' + entry.file) ? readFileSync(root + '/' + entry.file, 'utf8') : null;"
        "const needsOf = (text) => checkModel(text).needs;"
        f"const texts = {json.dumps(list(texts))};"
        "const out = [];"
        "for (const text of texts) out.push(await libraryCredit(text, needsOf(text), { needsOf, index, file }));"
        "console.log(JSON.stringify(out));")


PUBLISHED = (FIXTURE / "346-2.published.ldr").read_text()
CREDIT_LINE = next(line for line in PUBLISHED.splitlines() if line.startswith("0 !BRICKWORKS CREDIT "))
PARTS = [n for n, line in enumerate(PUBLISHED.splitlines()) if line.startswith("1 ") and line.rstrip().endswith(".dat")]


def without(share: float) -> str:
    """The published 346-2 with every part line but [share] of them taken out."""
    lines = PUBLISHED.splitlines()
    cut = set(PARTS[: int(len(PARTS) * share)])
    return "\n".join(line for n, line in enumerate(lines) if n not in cut) + "\n"


def test_a_library_model_is_credited_from_the_library_not_from_its_file() -> None:
    # Its credit line names somebody famous: the name is the index's all the same.
    renamed = PUBLISHED.replace('"by":"Marc Giraudet"', '"by":"Somebody Famous"')
    said = credits(PUBLISHED, renamed)
    if said is None:
        return
    as_published, renamed_said = said
    assert as_published == {"name": "Marc Giraudet", "page": "https://library.ldraw.org/omr/sets/1024",
                            "licence": "cc-by-2.0", "changed": False}
    assert renamed_said == as_published


def test_a_forged_credit_line_gets_nobody() -> None:
    own = "0 FILE my castle.ldr\n" + CREDIT_LINE + "\n0 My castle\n" \
        + "".join(f"1 4 {x * 20} 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" for x in range(40))
    # The library model's own first FILE, and the credit line, over parts of its own.
    dressed = "0 FILE 346-2 - Main.ldr\n" + CREDIT_LINE + "\n0 Main\n" \
        + "".join(f"1 4 {x * 20} 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" for x in range(40))
    elsewhere = PUBLISHED.replace("https://library.ldraw.org/omr/sets/1024", "https://library.ldraw.org/omr/sets/999999")
    no_line = PUBLISHED.replace(CREDIT_LINE + "\n", "")
    said = credits(own, dressed, elsewhere, no_line, without(0.6))
    if said is None:
        return
    assert said == [None, None, None, None, None], said


def test_a_changed_library_model_keeps_its_credit_and_says_it_was_changed() -> None:
    said = credits(without(0.1))
    if said is None:
        return
    assert said == [{"name": "Marc Giraudet", "page": "https://library.ldraw.org/omr/sets/1024",
                     "licence": "cc-by-2.0", "changed": True}]


def test_the_card_says_who_modelled_it_not_who_shares_it() -> None:
    said = node(
        "const c = await import('./web/card.js');"
        "const base = { id: 'Abcde12345', name: 'LEGO® set 6080 King\\'s Castle', parts: 691, author: 'Brickworks',"
        "  by: { handle: 'brickworks', name: 'Brickworks' }, tags: [] };"
        "console.log(JSON.stringify([c.cardHtml({ ...base, modelled_by: { name: 'Stefan Frenz',"
        "  page: 'https://library.ldraw.org/omr/sets/1034' } }), c.cardHtml(base)]));")
    if said is None:
        return
    modelled, shared = said
    # Words straight in the who-line, which wrap on a narrow card, not a
    # span that ends in "…" (at 390 px it read "Modelled by Stefan Fr…").
    assert '<span class="who" data-modelled-by>Modelled by Stefan Frenz</span>' in modelled
    assert 'href="/u/brickworks"' not in modelled
    # A model its sharer made: their profile, as before.
    assert 'href="/u/brickworks"' in shared and "Modelled by" not in shared


def page_of(modelled_by: dict) -> dict | None:
    """The stand-in's watchtower page (Robin Castell's) as the real handler
    makes it, its row saying CC BY 2.0 and [modelled_by]."""
    return node(
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverPage('api', '/m/DesignAbc1');"
        "const real = globalThis.fetch;"
        "globalThis.fetch = async (input, init) => { const url = String(input.url || input);"
        "  const answer = await real(input, init);"
        "  if (!/rpc\\/directory_model$/.test(url)) return answer;"
        "  const page = await answer.json();"
        f"  return new Response(JSON.stringify({{ ...page, licence: 'cc-by-2.0', modelled_by: {json.dumps(modelled_by)} }}),"
        "    { status: 200, headers: { 'content-type': 'application/json' } }); };"
        "const r = await s.serverPage('api', '/m/DesignAbc1');"
        "console.log(JSON.stringify({ status: r.status, html: r.html }));")


def test_the_page_credits_who_modelled_it_with_its_ldraw_page_and_licence() -> None:
    page = page_of({"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034"})
    if page is None:
        return
    assert page["status"] == 200
    html = page["html"]
    assert ('<p class="from modelled-by">Modelled by <b>Stefan Frenz</b> for '
            '<a href="https://library.ldraw.org/omr/sets/1034">LDraw&#39;s Official Model Repository</a></p>') in html
    licence = re.search(r'<div class="licence">.*?</div>', html, flags=re.S)[0]
    assert "<b>CC BY 2.0.</b>" in licence
    assert ("credit Stefan Frenz, who modelled it for <a href=\"https://library.ldraw.org/omr/sets/1034\">"
            "LDraw&#39;s Official Model Repository</a> and link") in licence
    assert 'href="https://creativecommons.org/licenses/by/2.0/" rel="license"' in licence
    # Whoever shares it is not who to credit.
    assert "@design-tester" not in licence
    data = json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', html, flags=re.S)[1])
    assert data["author"] == {"@type": "Person", "name": "Stefan Frenz", "url": "https://library.ldraw.org/omr/sets/1034"}
    assert data["license"] == "https://creativecommons.org/licenses/by/2.0/"


def test_a_changed_one_s_page_says_who_changed_it() -> None:
    page = page_of({"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034", "changed": True})
    if page is None:
        return
    html = page["html"]
    assert ('<p class="from modelled-by">Modelled by <b>Stefan Frenz</b> for '
            '<a href="https://library.ldraw.org/omr/sets/1034">LDraw&#39;s Official Model Repository</a>, '
            'changed by Robin Castell</p>') in html
    licence = re.search(r'<div class="licence">.*?</div>', html, flags=re.S)[0]
    assert "LDraw&#39;s Official Model Repository</a>, and say Robin Castell changed it and link" in licence
