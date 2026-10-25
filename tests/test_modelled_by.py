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

# The credit line the app writes when its library opens 6080-1
# (ModelLibrary.credit_of, ModelStore.with_share), in a file as published.
CREDITED = ("0 FILE 6080 - main.ldr\n0 main\n0 !BRICKWORKS CREDIT "
            + json.dumps({"by": "Stefan Frenz", "licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/1034",
                          "from": "LDraw's Official Model Repository"})
            + "\n0 Author: Stefan Frenz [smf]\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")


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


def test_the_credit_line_the_app_writes_is_the_one_the_server_reads() -> None:
    assert 'const CREDIT_META := "0 !BRICKWORKS CREDIT "' in STORE
    assert "const FROM := \"LDraw's Official Model Repository\"" in LIBRARY
    assert "export const LDRAW_FROM = \"LDraw's Official Model Repository\";" in DIRECTORY
    assert "/^0 !BRICKWORKS CREDIT (\\{.*\\})[ \\t\\r]*$/m" in DIRECTORY


def test_the_server_reads_whom_a_file_credits_and_nothing_else() -> None:
    said = node(
        "const d = await import('./api/_directory.js');"
        f"const credited = {json.dumps(CREDITED)};"
        "const gallery = credited.replace(\"LDraw's Official Model Repository\", 'the Brickworks gallery');"
        "const away = credited.replace('https://library.ldraw.org/omr/sets/1034', 'https://example.com/1034');"
        "const broken = credited.replace('\"by\"', 'by');"
        "console.log(JSON.stringify([d.modelledByIn(credited), d.modelledByIn(gallery), d.modelledByIn(away),"
        "  d.modelledByIn(broken), d.modelledByIn('1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat'),"
        "  d.cardOf('http://x.test', { id: 'Abcde12345', name: 'A', modelled_by: { name: 'Stefan Frenz',"
        "    page: 'https://library.ldraw.org/omr/sets/1034' } }).modelled_by,"
        "  d.cardOf('http://x.test', { id: 'Abcde12345', name: 'A' }).modelled_by]));")
    if said is None:
        return
    found, gallery, away, broken, plain, card, none = said
    assert found == {"name": "Stefan Frenz", "page": "https://library.ldraw.org/omr/sets/1034"}
    # A copy of a gallery model credits by its remix line; a page off
    # LDraw's library, a line that does not parse, or none: nobody.
    assert gallery is None and away is None and broken is None and plain is None
    assert card == found and none is None


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
    assert '<span class="who" data-modelled-by><span title="Modelled by Stefan Frenz">Modelled by Stefan Frenz</span></span>' \
        in modelled
    assert 'href="/u/brickworks"' not in modelled
    # A model its sharer made: their profile, as before.
    assert 'href="/u/brickworks"' in shared and "Modelled by" not in shared


def test_the_page_credits_who_modelled_it_with_its_ldraw_page_and_licence() -> None:
    script = (
        "const s = await import('./tools/web/design_stand_in.mjs');"
        "await s.serverPage('api', '/m/DesignAbc1');"
        "const real = globalThis.fetch;"
        "globalThis.fetch = async (input, init) => { const url = String(input.url || input);"
        "  const answer = await real(input, init);"
        "  if (!/rpc\\/directory_model$/.test(url)) return answer;"
        "  const page = await answer.json();"
        "  return new Response(JSON.stringify({ ...page, licence: 'cc-by-2.0', modelled_by: { name: 'Stefan Frenz',"
        "    page: 'https://library.ldraw.org/omr/sets/1034' } }), { status: 200,"
        "    headers: { 'content-type': 'application/json' } }); };"
        "const r = await s.serverPage('api', '/m/DesignAbc1');"
        "console.log(JSON.stringify({ status: r.status, html: r.html }));")
    page = node(script)
    if page is None:
        return
    assert page["status"] == 200
    html = page["html"]
    assert ('<p class="from modelled-by">Modelled by <b>Stefan Frenz</b> for '
            '<a href="https://library.ldraw.org/omr/sets/1034">LDraw&#39;s Official Model Repository</a></p>') in html
    licence = re.search(r'<div class="licence">.*?</div>', html, flags=re.S)[0]
    assert "<b>CC BY 2.0.</b>" in licence
    assert ("credit Stefan Frenz, who modelled it for <a href=\"https://library.ldraw.org/omr/sets/1034\">"
            "LDraw&#39;s Official Model Repository</a>") in licence
    assert 'href="https://creativecommons.org/licenses/by/2.0/" rel="license"' in licence
    # Whoever shares it is not who to credit.
    assert "@design-tester" not in licence
    data = json.loads(re.search(r'<script type="application/ld\+json">(.*?)</script>', html, flags=re.S)[1])
    assert data["author"] == {"@type": "Person", "name": "Stefan Frenz", "url": "https://library.ldraw.org/omr/sets/1034"}
    assert data["license"] == "https://creativecommons.org/licenses/by/2.0/"
