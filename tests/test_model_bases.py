"""What a model is based on (docs/SOCIAL.md section 7, item 5), held to what it promises.

supabase/model_bases.sql goes into the live project, so it may only add: one table
only its functions reach, deleted with its model, and functions the service role
alone runs. tools/model_bases_try.sql proves what they keep and refuse in a
rolled-back dry run; here, that a designer's list is checked before it reaches the
database, that every word of it is escaped on the page, and that the page, the set's
page and the stand-in ask the same functions.
"""

from __future__ import annotations

import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SQL = (ROOT / "supabase/model_bases.sql").read_text()


def code(text: str) -> str:
    return "\n".join(line.split("--", 1)[0] for line in text.splitlines())


def node(script: str) -> dict:
    return json.loads(subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, check=True,
                                     capture_output=True, text=True).stdout)


def test_the_file_only_adds() -> None:
    plain = code(SQL).lower()
    for word in ("drop ", "truncate", "rename ", "alter column", "update public."):
        assert word not in plain, f"model_bases.sql says {word.strip()}"
    assert re.findall(r"create table if not exists public\.([a-z_]+)", plain) == ["model_bases"]
    assert re.findall(r"alter table public\.([a-z_]+) (.*);", plain) == [("model_bases", "enable row level security")]
    assert "model       text not null references public.shared_models (id) on delete cascade" in plain
    # A designer's list is replaced whole, and only it.
    assert re.findall(r"delete from public\.([a-z_]+)", plain) == ["model_bases"]
    assert set(re.findall(r"insert into public\.([a-z_]+)", plain)) == {"model_bases"}


def test_the_table_and_functions_are_the_servers_alone() -> None:
    plain = code(SQL)
    assert "revoke all on public.model_bases from public, anon, authenticated, service_role;" in plain
    assert not re.search(r"grant [^;]* on public\.model_bases\b", plain)
    names = re.findall(r"create or replace function public\.([a-z_]+)\(", plain)
    assert sorted(names) == ["model_bases_of", "model_bases_put", "set_based"]
    for name in names:
        assert re.search(rf"revoke all on function public\.{name}\([^)]*\) from public, anon, authenticated;", plain), name
        assert re.search(rf"grant execute on function public\.{name}\([^)]*\) to service_role;", plain), name
    assert plain.count("security definer") == 3 and plain.count("set search_path = public") == 3


def test_the_table_keeps_only_a_base_that_says_something() -> None:
    plain = code(SQL)
    # A set or a link, never both; a link with its title; an alternate build of a set; a set with no words of its own.
    for rule in ("check ((set_number is null) <> (url is null))", "check (url is null or title is not null)",
                 "check (how <> 'alternate' or set_number is not null)",
                 "check (set_number is null or (title is null and author is null and licence is null))",
                 "check (how in ('alternate', 'changed', 'inspired'))", "check (n between 1 and 3)",
                 "url ~ '^https://[^[:space:]<>\"]+$'"):
        assert rule in plain, rule
    put = plain[plain.index("function public.model_bases_put("):plain.index("$$;", plain.index("function public.model_bases_put("))]
    # Who may: its designer, 13 or over, not taken out; and a broken base takes the whole list back.
    for rule in ("'refused', 'no_model'", "'refused', 'not_yours'", "public.trust_kept_private(model_bases_put.account)",
                 "public.is_barred(model_bases_put.account) or m.barred", "jsonb_array_length(bases) > 3",
                 "exception when check_violation or not_null_violation then", "errcode = '22023'"):
        assert rule in put, rule
    # A set's page lists only what the gallery shows.
    assert "public.gallery_shows(m, set_based.tests)" in plain


def test_a_list_is_checked_before_the_database() -> None:
    out = node("""
      import { basesAsked } from "./api/_bases.js";
      const setOf = (n) => (n.toLowerCase() === "6080-1" ? { set: "6080-1", name: "King's Castle" } : null);
      const said = (given) => { try { return basesAsked(given, setOf); } catch (trouble) { return [trouble.status, trouble.message]; } };
      console.log(JSON.stringify({
        good: said([{ how: "alternate", set: " 6080-1 " }, { how: "changed", url: "https://example.org/a b",
          title: "  A   castle ", author: "", licence: "CC BY 4.0", extra: "dropped" }]),
        none: said([]),
        four: said([1, 2, 3, 4].map(() => ({ how: "inspired", set: "6080-1" }))),
        notList: said({}),
        how: said([{ how: "copied", set: "6080-1" }]),
        both: said([{ how: "changed", set: "6080-1", url: "https://example.org/x", title: "X" }]),
        neither: said([{ how: "changed" }]),
        noSet: said([{ how: "inspired", set: "99999-9" }, { how: "inspired", set: "6080-1" }]),
        altLink: said([{ how: "alternate", url: "https://example.org/x", title: "X" }]),
        http: said([{ how: "changed", url: "http://example.org/x", title: "X" }]),
        script: said([{ how: "changed", url: "javascript:alert(1)", title: "X" }]),
        login: said([{ how: "changed", url: "https://me:pw@example.org/x", title: "X" }]),
        bare: said([{ how: "changed", url: "https://localhost/x", title: "X" }]),
        long: said([{ how: "changed", url: `https://example.org/${"a".repeat(300)}`, title: "X" }]),
        untitled: said([{ how: "changed", url: "https://example.org/x", title: "  " }]),
      }));
    """)
    assert out["good"] == [{"how": "alternate", "set": "6080-1"},
                           {"how": "changed", "url": "https://example.org/a%20b", "title": "A castle", "author": None,
                            "licence": "CC BY 4.0"}]
    assert out["none"] == []
    assert out["four"] == [400, "At most 3: say the ones it owes most to."]
    assert out["notList"][0] == 400
    assert out["how"][1].startswith("Say how it is based on it")
    assert out["both"][1] == out["neither"][1] == "Give a set's number or a link, one of them."
    # Which one, when there are several.
    assert out["noSet"][1].startswith("There is no set 99999-9 in the library (the first)")
    assert out["altLink"][1].startswith("An alternate build is built from a set's parts")
    for key in ("http", "script", "login", "bare", "long"):
        assert out[key][1].startswith("Give the work's own address, starting https://"), key
    assert out["untitled"][1].startswith("Give the work's title")


def test_every_word_on_the_page_is_escaped() -> None:
    out = node("""
      import { basedHtml } from "./web/card.js";
      import { basesSaid } from "./api/_bases.js";
      const setOf = (n) => (n === "6080-1" ? { set: "6080-1", name: "King's <Castle>" } : null);
      const said = basesSaid([
        { how: "alternate", set_number: "6080-1" },
        { how: "inspired", set_number: "1234-1" },
        { how: "changed", url: "https://example.org/x?a=1&b=\\"2\\"", title: "<script>alert(1)</script>", author: "A & B",
          licence: null },
        { how: "copied", set_number: "6080-1" },
      ], setOf);
      console.log(JSON.stringify({ said, html: basedHtml(said), none: basedHtml([]) }));
    """)
    said, html = out["said"], out["html"]
    # A set the catalogue no longer has keeps its number; a kind not known is left out.
    assert [one["how"] for one in said] == ["alternate", "inspired", "changed"]
    assert said[1] == {"how": "inspired", "set": "1234-1", "name": None, "href": "/library/set/1234-1"}
    assert '<a href="/library/set/6080-1">set 6080-1 King&#39;s &lt;Castle&gt;</a>' in html
    assert '<a href="/library/set/1234-1">set 1234-1</a>' in html
    assert ('<a href="https://example.org/x?a=1&amp;b=&quot;2&quot;" rel="nofollow ugc noopener">'
            "“&lt;script&gt;alert(1)&lt;/script&gt;”</a> by A &amp; B</li>") in html
    assert "<script>" not in html and out["none"] == ""
    assert html.startswith('<ul class="from based-on" id="based-on" aria-label="What it is based on">')


def test_the_pages_and_the_stand_in_ask_the_same_functions() -> None:
    share = (ROOT / "api/share.js").read_text()
    assert 'if (op === "bases") return bases(request, response);' in share
    assert 'if (op === "set_based") return setBased(request, response, origin);' in share
    assert 'if (op === "bases") return await basesPut(request, response);' in share
    assert "${basedHtml(model.based || [])}" in share
    assert "isBasedOn: basedOn.length ? basedOn : undefined" in share and "based_on: (based || [])" in share
    bases = (ROOT / "api/_bases.js").read_text()
    for name in ("model_bases_of", "model_bases_put", "set_based"):
        assert f'"rpc/{name}"' in bases, name
    stand = (ROOT / "tools/web/design_stand_in.mjs").read_text()
    for name in ("model_bases_of", "set_based"):
        assert f"  {name}: (" in stand, name
    page = (ROOT / "web/set-page.js").read_text()
    assert "/api/share?op=set_based&set=" in page and 'section.id = "built-from"' in page
    model = (ROOT / "web/model-page.js").read_text()
    assert 'call("/api/share?op=bases", { method: "POST", body: { model: id, bases } })' in model
    checks = (ROOT / "tools/release/preview_checks.sh").read_text()
    assert '[based_on]="tools/web/based_on_flow.mjs --url=$P --out=$S/${TAG}_based_on"' in checks
