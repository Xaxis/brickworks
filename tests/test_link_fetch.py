"""A link fetched for the app in a browser (api/_link.js, POST
/api/account?op=fetch; urlfetch, 2026-11-03).

The handler runs here under node, signed in through the stand-in Supabase,
fetching from a server of the test's own under made-up names that answer
made-up public addresses (tests/fixtures/link/world.mjs). Every refusal is
a sentence a person can act on, never a code:

- a good picture comes back as its bytes, its kind sniffed, sent as
  nothing a browser would show (octet-stream, nosniff, attachment);
- no private, loopback, link-local or metadata address, as an address in
  the link, as a name's address, as one of a name's addresses, or after a
  redirect; a name that answers a public address and then a private one is
  connected to at the address checked and never the second;
- only http and https, on the usual ports, with no name and password;
- what came back is sniffed, whatever the site calls it: a web page, text
  and a script are refused;
- too large, said with its size, by the length a site says and by what it
  sends when it says none;
- signed out, and too many in an hour, refused;
- nothing of the person's is sent on, the User-Agent is fixed, and the log
  says the host and never the link.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent


def run(body: str, **options: object) -> object:
    """[body], an async function's body that returns something JSON, run in
    a fresh node process with `w` the link world and `ask` its request."""
    if shutil.which("node") is None:
        pytest.skip("no node")
    script = (
        "import { linkWorld } from './tests/fixtures/link/world.mjs';"
        "import * as link from './api/_link.js';"
        f"const w = await linkWorld({json.dumps(options)});"
        "const ask = w.ask;"
        "const logged = [];"
        "for (const name of ['log', 'error', 'warn']) {"
        "  const theirs = console[name];"
        "  console[name] = (...said) => { logged.push(said.join(' ')); if (name !== 'log') theirs(...said); };"
        "}"
        "let out;"
        f"try {{ out = await (async () => {{ {body} }})(); }} finally {{ w.close(); }}"
        "process.stdout.write(JSON.stringify(out) + '\\n');"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=90)
    assert done.returncode == 0, done.stderr[-2000:]
    return json.loads(done.stdout.strip().splitlines()[-1])


def refused(answer: dict, status: int, why: str, *words: str) -> None:
    assert answer["status"] == status, answer
    assert answer["json"]["why"] == why, answer
    said = answer["json"]["error"]
    for word in words:
        assert word in said, (word, said)
    # A sentence, never a code.
    assert said.rstrip().endswith("."), said
    assert "error " not in said.lower(), said


def test_a_good_picture_is_fetched_as_its_bytes_and_shown_as_nothing() -> None:
    out = run("const a = await ask({ url: 'http://pictures.test/pic.png?size=1' });"
              "const z = await ask({ url: 'http://pictures.test/pic.png.gz' });"
              "const r = await ask({ url: 'http://pictures.test/to-pic' });"
              "return { a, z, r, png: (await import('./tests/fixtures/link/world.mjs')).PNG.toString('base64'),"
              "  dialled: w.dialled, heard: w.heard.map((h) => h.path) };")
    assert out["a"]["status"] == 200 and out["a"]["kind"] == "png"
    assert out["a"]["bytes"] == out["png"]
    headers = out["a"]["headers"]
    assert headers["content-type"] == "application/octet-stream"
    assert headers["x-content-type-options"] == "nosniff"
    assert headers["content-disposition"] == "attachment"
    assert "sandbox" in headers["content-security-policy"]
    assert headers["cache-control"] == "private, no-store"
    # Sent packed, brought in unpacked; and a redirect on the same site followed.
    assert out["z"]["kind"] == "png" and out["z"]["bytes"] == out["png"]
    assert out["r"]["kind"] == "png" and out["r"]["bytes"] == out["png"]
    assert set(out["dialled"]) == {"93.184.215.14"}
    assert out["heard"] == ["/pic.png?size=1", "/pic.png.gz", "/to-pic", "/pic.png"]


def test_a_model_is_fetched_and_so_is_ipv6() -> None:
    out = run("return [await ask({ url: 'http://pictures.test/bunny.obj' }),"
              " await ask({ url: 'http://pictures6.test/pic.png' })];")
    assert out[0]["status"] == 200 and out[0]["kind"] == "obj"
    assert out[1]["status"] == 200 and out[1]["kind"] == "png"


@pytest.mark.parametrize("url,host", [
    ("http://127.0.0.1/pic.png", "127.0.0.1"),
    ("http://localhost.test@127.0.0.1/pic.png", None),
    ("http://169.254.169.254/latest/meta-data/", "169.254.169.254"),
    ("http://[::1]/pic.png", "::1"),
    ("http://[::ffff:127.0.0.1]/pic.png", "::ffff:7f00:1"),
    ("http://[fd00:ec2::254]/latest/meta-data/", "fd00:ec2::254"),
    ("http://2130706433/pic.png", "127.0.0.1"),
    ("http://0x7f.1/pic.png", "127.0.0.1"),
    ("http://10.1.2.3/pic.png", "10.1.2.3"),
    ("http://192.168.1.1/pic.png", "192.168.1.1"),
    ("http://172.20.0.1/pic.png", "172.20.0.1"),
    ("http://100.100.100.200/latest/meta-data/", "100.100.100.200"),
    ("http://0.0.0.0/pic.png", "0.0.0.0"),
    ("http://inside.test/pic.png", "inside.test"),
    ("http://inside6.test/pic.png", "inside6.test"),
    ("http://mixed.test/pic.png", "mixed.test"),
])
def test_a_private_address_is_refused_and_never_dialled(url: str, host: str | None) -> None:
    out = run(f"return {{ a: await ask({{ url: {json.dumps(url)} }}), dialled: w.dialled, heard: w.heard.length }};")
    if host is None:
        # A name and password in the link is refused before its host is looked at.
        refused(out["a"], 400, "credentials", "name and password")
    else:
        refused(out["a"], 403, "private", host, "private network", "open web")
    assert out["dialled"] == [] and out["heard"] == 0


@pytest.mark.parametrize("path,host", [
    ("/to-inside", "inside.test"),
    ("/to-metadata", "169.254.169.254"),
    ("/to-loopback", "::1"),
])
def test_a_redirect_to_a_private_address_is_refused(path: str, host: str) -> None:
    out = run(f"return {{ a: await ask({{ url: 'http://pictures.test{path}' }}), dialled: w.dialled }};")
    refused(out["a"], 403, "private", f"sent Brickworks on to {host}", "private network")
    assert out["dialled"] == ["93.184.215.14"]


def test_a_rebinding_name_is_fetched_from_the_address_checked_and_checked_again_next_time() -> None:
    out = run("const first = await ask({ url: 'http://rebind.test/pic.png' });"
              "const looked = [...w.looked]; const dialled = [...w.dialled];"
              "const second = await ask({ url: 'http://rebind.test/pic.png' });"
              "return { first, second, looked, dialled, after: w.dialled };")
    # Looked up once, connected to what was checked: the private answer a
    # second lookup would give is never asked for, let alone dialled.
    assert out["first"]["status"] == 200 and out["first"]["kind"] == "png"
    assert out["looked"] == ["rebind.test"] and out["dialled"] == ["93.184.215.14"]
    # The next fetch looks again, and is refused.
    refused(out["second"], 403, "private", "rebind.test")
    assert out["after"] == ["93.184.215.14"]


@pytest.mark.parametrize("url,why,words", [
    ("ftp://pictures.test/pic.png", "scheme", ["http or https", "ftp"]),
    ("file:///etc/passwd", "scheme", ["http or https"]),
    ("http://pictures.test:22/pic.png", "port", ["port 22", "80 and 443"]),
    ("http://ada:secret@pictures.test/pic.png", "credentials", ["name and password"]),
    ("pictures.test/pic.png", "unreadable", ["https://"]),
    ("", "no_link", ["url="]),
])
def test_what_is_not_a_link_to_fetch_is_refused(url: str, why: str, words: list[str]) -> None:
    out = run(f"return {{ a: await ask({{ url: {json.dumps(url)} }}), heard: w.heard.length }};")
    refused(out["a"], 400, why, *words)
    assert out["heard"] == 0


def test_a_redirect_elsewhere_than_http_or_round_and_round_is_refused() -> None:
    out = run("return [await ask({ url: 'http://pictures.test/to-ftp' }), await ask({ url: 'http://pictures.test/loop' })];")
    refused(out[0], 400, "scheme", "pictures.test sent Brickworks on to a link that is not http or https (ftp)")
    refused(out[1], 502, "hops", "more than 5 times")


@pytest.mark.parametrize("path,why,words", [
    ("/page.html", "page", ["web page", "Original file"]),
    # Said to be a PNG, and a web page all the same: the bytes decide.
    ("/lying.png", "page", ["web page"]),
    ("/notes.txt", "kind", ["not a picture", "3D model"]),
    ("/script.png", "kind", ["not a picture"]),
])
def test_the_wrong_kind_is_refused_by_its_bytes(path: str, why: str, words: list[str]) -> None:
    out = run(f"return await ask({{ url: 'http://pictures.test{path}' }});")
    refused(out, 415, why, *words)


def test_too_large_is_said_with_its_size_and_what_to_do() -> None:
    out = run("return [await ask({ url: 'http://pictures.test/big.png' }), await ask({ url: 'http://pictures.test/endless.png' })];")
    refused(out[0], 413, "too_large", "That file is 5 MB", "up to 4 MB from a link", "Save it to your computer")
    refused(out[1], 413, "too_large", "more than 4 MB", "Save it to your computer")


def test_a_site_that_fails_is_said_in_words() -> None:
    out = run("return [await ask({ url: 'http://pictures.test/missing.png' }),"
              " await ask({ url: 'http://nowhere.test/pic.png' }),"
              " await ask({ url: 'http://pictures.test/slow' }, { seconds: 1 })];")
    refused(out[0], 502, "not_found", "pictures.test says there is no file", "404 Not Found")
    refused(out[1], 502, "no_host", "There is no site called nowhere.test")
    refused(out[2], 504, "timeout", "pictures.test didn't answer within 1 s")


def test_signed_out_and_too_many_are_refused() -> None:
    out = run("const out = { signedOut: await ask({ url: 'http://pictures.test/pic.png' }, { signedIn: false }) };"
              "out.heard = w.heard.length;"
              "out.first = (await ask({ url: 'http://pictures.test/pic.png' })).status;"
              "out.second = (await ask({ url: 'http://pictures.test/pic.png' })).status;"
              "out.third = await ask({ url: 'http://pictures.test/pic.png' });"
              "out.get = await ask({ url: 'http://pictures.test/pic.png' }, { method: 'GET' });"
              "return out;", perHour=2)
    refused(out["signedOut"], 401, "signed_out", "Sign in to Brickworks")
    assert out["heard"] == 0
    assert out["first"] == 200 and out["second"] == 200
    refused(out["third"], 429, "rate", "60 an hour", "300 a day")
    assert out["get"]["status"] == 405


def test_nothing_of_the_person_goes_on_and_the_log_says_the_host_alone() -> None:
    out = run("await ask({ url: 'http://pictures.test/pic.png?token=hunter2' });"
              "await ask({ url: 'http://pictures.test/page.html?token=hunter2' });"
              "return { headers: w.heard.map((h) => h.headers), logged, agent: link.AGENT,"
              "  size: (await import('./tests/fixtures/link/world.mjs')).PNG.length };")
    for headers in out["headers"]:
        assert "cookie" not in headers and "authorization" not in headers
        assert headers["user-agent"] == out["agent"]
        assert headers["host"] == "pictures.test"
    lines = [line for line in out["logged"] if line.startswith("link:")]
    assert lines == [f"link: pictures.test png {out['size']} B", "link: pictures.test refused (page)"], out["logged"]
    assert not any("hunter2" in line or "/pic.png" in line for line in out["logged"])


@pytest.mark.parametrize("file,kind", [
    ("brickify/bunny.obj", "obj"),
    ("brickify/formats/bunny.ply", "ply"),
    ("brickify/formats/bunny_binary.ply", "ply"),
    ("brickify/formats/shapes.3mf", "3mf"),
    ("brickify/formats/scene.vox", "vox"),
    ("brickify/formats/bunny.fbx", "fbx"),
    ("brickify/formats/spotty.png", "png"),
    ("photos/3039.jpg", "jpeg"),
])
def test_every_kind_the_tools_take_is_known_by_its_bytes(file: str, kind: str) -> None:
    assert (ROOT / "tests/fixtures" / file).exists(), file
    out = run(f"return link.kindOf((await import('node:fs')).readFileSync('tests/fixtures/{file}'), '{file}');")
    assert out == kind


def test_stl_gltf_glb_svg_and_a_bin_beside_a_gltf_are_known_by_their_bytes() -> None:
    out = run(
        "const b = (s) => Buffer.from(s);"
        "const stl = Buffer.alloc(84 + 50 * 2); stl.writeUInt32LE(2, 80);"
        "const glb = Buffer.alloc(20); glb.write('glTF'); glb.writeUInt32LE(2, 4);"
        "return ["
        "  link.kindOf(stl), link.kindOf(b('solid cube\\n facet normal 0 0 1\\n')), link.kindOf(glb),"
        "  link.kindOf(b('{\"asset\": {\"version\": \"2.0\"}}')),"
        "  link.kindOf(b('<?xml version=\"1.0\"?>\\n<!-- drawn -->\\n<svg xmlns=\"http://www.w3.org/2000/svg\"/>')),"
        "  link.kindOf(Buffer.from([1, 0, 2, 0]), '/model/scene.bin'), link.kindOf(Buffer.from([1, 0, 2, 0]), '/x.dat'),"
        "  link.kindOf(b('newmtl red\\nKd 1 0 0\\n')), link.kindOf(b('{\"not\": \"a model\"}')),"
        "  link.kindOf(b('GIF89a......')), link.kindOf(b('PK\\u0003\\u0004word/document.xml'))];")
    assert out == ["stl", "stl", "glb", "gltf", "svg", "bin", "", "mtl", "", "gif", ""]
