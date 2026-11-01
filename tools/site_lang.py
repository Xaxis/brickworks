#!/usr/bin/env python3
"""The pages a visitor reads first, in German, French and Spanish.

    tools/site_lang.py                write web/<code>/ for each language
    tools/site_lang.py --check        say which are out of date or short of a word, exit 1 if any
    tools/site_lang.py --missing=CODE the English CODE has no words for yet, as JSON to fill in

The landing page, the download page and the pages a visitor goes on to
from them (the plans, the FAQ, the comparison, the gallery and the LDraw
library: PAGES) are written in English, in web/, as every page is. Each
language's copy is made from them here, at /de, /de/download and so on, and
kept beside them in web/de/ (tests/test_site_lang.py fails when a copy is
not what this would write): the same markup with its words in the
language, from web/_lang/<code>.json, and its links into the app and to
each of these pages kept in the language.

A page's words are found as a reader meets them: each run of text and the
inline markup in it (a link, a bold word) between the blocks around it is
one entry, its English the key, so a translation may put the words in its
own order and keep the link where its language wants it. And each alt,
title, aria-label and placeholder, the page's description for search
engines and share cards, and the JSON-LD's (a description, an FAQ's
questions and answers). A run that is a name
(Brickworks, a command to type) or has no letters stays as it is; any other
with no entry stops the copy being written, so nothing is ever half in
English, and so does an entry whose markup is not its English's (a link
lost). An entry no page says any more fails the check.
web/_lang/<code>.json's "scripts" are the words the page's scripts say
(window.brickworksLang.say, web/theme.js), put in the copy for them, with
the app's names for the Library's themes (locale/<code>.po, "theme"). Each
say("...") and counted(n, "one", "many") in a script a copy loads (and in
what it imports), and the labels the API hands the gallery and the library
to show (API_WORDS), must have its entry too, or the check fails.

The sign-in's dialogs (web/account.js) are said in the visitor's language on
every page, a copy or not, so their words are kept for each language at
/<code>/words.json too (all a copy's scripts may say): what the dialogs
say, each sentence a page asks somebody to sign in with ("Sign in to like
it: ...", SIGN_IN_WHY, in any script), orangecheck's own words for its
button and its box, and every error the sign-in's API answers with in
words (TOLD). A word of web/account.js with a capital in it that is not
said through say() fails the check (SAID_ALL), so none comes back in
English.

Which language a visitor is shown is web/theme.js's: the one they chose in
the footer, else the first of their browser's that the site has.
"""

from __future__ import annotations

import html
import json
import re
import sys
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "web"
WORDS = WEB / "_lang"
SITE = "https://brickworks.diy"

# Each language, its name in itself (the footer's choice, as the app's
# Settings lists them: src/ui/language.gd CHOICES).
LANGUAGES = {"de": "Deutsch", "fr": "Français", "es": "Español"}
# The pages, by their file, and where each is: / and /download in English.
PAGES = {"index.html": "", "download.html": "download", "plans.html": "plans", "faq.html": "faq",
         "compare.html": "compare", "gallery.html": "gallery", "library.html": "library"}

BLOCK = {"html", "head", "body", "header", "nav", "main", "section", "article", "aside", "footer",
         "div", "p", "h1", "h2", "h3", "h4", "h5", "h6", "ul", "ol", "li", "figure", "figcaption",
         "details", "summary", "title", "noscript", "dl", "dt", "dd", "blockquote", "form",
         "fieldset", "legend", "table", "tr", "td", "th", "select", "option", "label"}
VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link", "meta", "source", "track", "wbr"}
# Never words to translate: what runs, what is drawn, what a person types.
SKIP = {"script", "style", "svg", "template", "code", "kbd", "samp"}
ATTRIBUTES = ("alt", "title", "aria-label", "placeholder")
META = {"description", "og:title", "og:description", "og:image:alt", "twitter:title",
        "twitter:description", "twitter:image:alt"}
# The words the API hands the copies' scripts to show: each label of these
# constants (an "id" is not one), and the plans form's fixed replies; and
# orangecheck's code's, for its button and its box (web/account.js).
API_WORDS = {"api/_directory.js": ("KINDS", "SIZES", "SORTS", "WINDOWS", "MADES", "MINE_SORTS"),
             "api/_library.js": ("SET_SORTS",), "api/_sets.js": ("SETS_SORTS",), "api/plans.js": ("KEPT", "GONE"),
             "web/oc-button.mjs": ("SIGN_IN_BUSY_LABEL", "OUTCOME_COPY"),
             "web/oc-connect-consent.mjs": ("CONNECT_CONSENT_LABEL", "CONNECT_CONSENT_BLURB")}
STRING = r'"(?:[^"\\\n]|\\.)*"'
SAY = re.compile(rf"\bsay\(\s*((?:{STRING}\s*\+\s*)*{STRING})")
COUNTED = re.compile(rf"\bcounted\((?:[^,()]|\([^()]*\))+,\s*({STRING})(?:\s*,\s*({STRING}))?\s*\)")
# The sign-in's API, whose errors the dialogs say: each sentence an answer
# gives as its error ("POST only" is a developer's, and no sentence).
TOLD = ("api/otp.js", "api/_trust.js", "api/_oc.js", "api/orangecheck.js")
TOLD_AS = re.compile(rf"(?:\berror:\s*|\btrouble:\s*|\bsay\(response,\s*\d+,\s*|new Refusal\()((?:{STRING}\s*\+\s*)*{STRING})")
# A page's reason to sign in, which web/account.js says on any page.
SIGN_IN_WHY = re.compile(r'"(Sign in\b(?:[^"\\\n]|\\.)*\.)"')
# The scripts that say every word they show through say(): a literal with a
# capitalized word in it, outside say(), is English left on the page.
SAID_ALL = ("account.js",)
CODE_WORDS = {"Bearer"}
# Runs that are names, the same in every language.
NAMES = {"Brickworks", "brickworks.diy/app", "Claude", "Pro", "GitHub", "3D"}
# The JSON-LD fields a reader is shown: a description anywhere, and an
# FAQ's questions and answers, as search results show them.
WORDED = {"Question": "name", "Answer": "text"}
LETTER = re.compile(r"[A-Za-zÀ-ÿ]")


class Tokens(HTMLParser):
    """[text] as tokens, each [kind, start, tag, attrs]; its end the next one's start."""

    def __init__(self, text: str) -> None:
        super().__init__(convert_charrefs=False)
        self.starts = [0] + [m.end() for m in re.finditer("\n", text)]
        self.found: list[list] = []
        self.feed(text)
        self.close()
        self.ends = [t[1] for t in self.found[1:]] + [len(text)]

    def _at(self) -> int:
        line, column = self.getpos()
        return self.starts[line - 1] + column

    def handle_starttag(self, tag, attrs):
        self.found.append(["start", self._at(), tag, dict(attrs)])

    def handle_startendtag(self, tag, attrs):
        self.found.append(["empty", self._at(), tag, dict(attrs)])

    def handle_endtag(self, tag):
        self.found.append(["end", self._at(), tag, None])

    def handle_data(self, data):
        self.found.append(["data", self._at(), None, None])

    def handle_entityref(self, name):
        self.found.append(["data", self._at(), None, None])

    def handle_charref(self, name):
        self.found.append(["data", self._at(), None, None])

    def handle_comment(self, data):
        self.found.append(["comment", self._at(), None, None])

    def handle_decl(self, decl):
        self.found.append(["decl", self._at(), None, None])


class Node:
    def __init__(self, tag: str, attrs: dict, opened: int) -> None:
        self.tag, self.attrs, self.opened, self.closed = tag, attrs, opened, None
        self.kids: list = []  # Nodes, and the indexes of data tokens


def tree(tokens: Tokens) -> Node:
    root = Node("#root", {}, -1)
    stack = [root]
    for n, (kind, _, tag, attrs) in enumerate(tokens.found):
        if kind == "start" and tag not in VOID:
            node = Node(tag, attrs, n)
            stack[-1].kids.append(node)
            stack.append(node)
        elif kind in ("start", "empty"):
            node = Node(tag, attrs, n)
            node.closed = n
            stack[-1].kids.append(node)
        elif kind == "end":
            for depth in range(len(stack) - 1, 0, -1):
                if stack[depth].tag == tag:
                    stack[depth].closed = n
                    del stack[depth:]
                    break
        elif kind == "data":
            stack[-1].kids.append(n)
    return root


def plain(fragment: str) -> str:
    """The words of an HTML fragment, its tags out and its entities read."""
    return html.unescape(re.sub(r"<[^>]+>", "", fragment)).strip()


def key_of(fragment: str) -> str:
    return re.sub(r"\s+", " ", fragment).strip()


def says_something(words: str) -> bool:
    return bool(LETTER.search(words)) and words not in NAMES


class Page:
    """An English page's words: each run and attribute to say, where it is."""

    def __init__(self, text: str) -> None:
        self.text = text
        self.tokens = Tokens(text)
        self.runs: list[tuple[int, int]] = []
        self._walk(tree(self.tokens))

    def _span(self, first: int, last: int) -> tuple[int, int]:
        return self.tokens.found[first][1], self.tokens.ends[last]

    def _data(self, n: int) -> str:
        start, end = self._span(n, n)
        return self.text[start:end]

    def _walk(self, node: Node) -> None:
        if node.tag in SKIP or node.attrs.get("translate") == "no":
            return
        run: list = []
        for kid in node.kids + [None]:
            if kid is None or (isinstance(kid, Node) and kid.tag in BLOCK):
                self._run(run)
                run = []
                if kid is not None:
                    self._walk(kid)
            else:
                run.append(kid)

    def _run(self, run: list) -> None:
        said = [kid for kid in run if not isinstance(kid, int) or self._data(kid).strip()]
        if not said:
            return
        if not any(isinstance(kid, int) for kid in said):
            for kid in said:
                self._walk(kid)
            return
        first = said[0] if isinstance(said[0], int) else said[0].opened
        last = said[-1] if isinstance(said[-1], int) else said[-1].closed
        start, end = self._span(first, last)
        # The run's own spaces stay outside it.
        while self.text[start].isspace():
            start += 1
        while self.text[end - 1].isspace():
            end -= 1
        self.runs.append((start, end))

    def keys(self) -> list[str]:
        """Every English entry the page has, run or attribute, in order."""
        out = [key_of(self.text[s:e]) for s, e in self.runs]
        for kind, _, tag, attrs in self.tokens.found:
            if kind not in ("start", "empty"):
                continue
            out += [key_of(attrs[name]) for name in ATTRIBUTES if attrs.get(name)]
            if tag == "meta" and (attrs.get("name") in META or attrs.get("property") in META):
                out.append(key_of(attrs.get("content", "")))
        for block in re.findall(r'<script type="application/ld\+json">(.*?)</script>', self.text, re.S):
            out += [key_of(d) for d in descriptions(json.loads(block))]
        return [key for key in out if says_something(plain(key))]


def worded(data: dict) -> list[str]:
    return [f for f in ("description", WORDED.get(data.get("@type"))) if f and isinstance(data.get(f), str)]


def descriptions(data) -> list[str]:
    if isinstance(data, dict):
        found = [data[f] for f in worded(data)]
        return found + [d for value in data.values() for d in descriptions(value)]
    if isinstance(data, list):
        return [d for value in data for d in descriptions(value)]
    return []


def scripts_of(name: str) -> list[str]:
    """The scripts web/[name] loads, and every one they import."""
    found = re.findall(r'<script[^>]*\ssrc="/([\w.-]+\.js)"', (WEB / name).read_text(encoding="utf-8"))
    seen: list[str] = []
    while found:
        one = found.pop()
        if one in seen or not (WEB / one).exists():
            continue
        seen.append(one)
        found += re.findall(r'(?:\bfrom|\bimport\(?)\s*"(?:\.|)/([\w.-]+\.js)"', (WEB / one).read_text(encoding="utf-8"))
    return seen


def script_words() -> dict[str, str]:
    """Every word a copy's scripts may say, and where the first is said."""
    words: dict[str, str] = {}
    for one in sorted({script for name in PAGES for script in scripts_of(name)}):
        text = (WEB / one).read_text(encoding="utf-8")
        for found in SAY.finditer(text):
            words.setdefault("".join(json.loads(s) for s in re.findall(STRING, found.group(1))), f"web/{one}")
        for found in COUNTED.finditer(text):
            single = json.loads(found.group(1))
            for word in (single, json.loads(found.group(2)) if found.group(2) else f"{single}s"):
                words.setdefault(word, f"web/{one}")
    for path, names in API_WORDS.items():
        text = (ROOT / path).read_text(encoding="utf-8")
        for name in names:
            block = re.search(rf"\b(?:const|var) {name} = (.*?);\n", text, re.S).group(1)
            for key, said in re.findall(rf"(?:(\w+):\s*)?({STRING})", block):
                if key != "id" and not (key == "" and block.lstrip().startswith(("{", "["))):
                    words.setdefault(json.loads(said), path)
        for refusal in re.findall(rf"new Refusal\(({STRING})\)", text):
            words.setdefault(json.loads(refusal), path)
    for path in TOLD:
        for found in TOLD_AS.finditer((ROOT / path).read_text(encoding="utf-8")):
            said = "".join(json.loads(s) for s in re.findall(STRING, found.group(1)))
            if said.rstrip().endswith((".", "?")):
                words.setdefault(said, path)
    for one in sorted(WEB.glob("*.js")):
        for why in SIGN_IN_WHY.findall(one.read_text(encoding="utf-8")):
            words.setdefault(json.loads(f'"{why}"'), f"web/{one.name}")
    return {word: where for word, where in words.items() if says_something(word)}


def unsaid(script: str) -> list[str]:
    """The words a [script] shows in English: each literal with a
    capitalized word in it (a sentence, a label) that is not said through
    say(), its comments left out."""
    text = re.sub(r"(?<![:\"'\w])//[^\n]*", "", script)
    through = [found.span(1) for found in SAY.finditer(text)]
    out = []
    for found in re.finditer(rf"{STRING}|`(?:[^`\\]|\\.)*`", text):
        if any(start <= found.start() < end for start, end in through):
            continue
        words = re.findall(r"\b[A-Z][a-z]+\b", re.sub(r"\$\{[^}]*\}", "", found.group(0)))
        if [word for word in words if word not in CODE_WORDS]:
            out.append(found.group(0))
    return out


def table(code: str) -> dict:
    path = WORDS / f"{code}.json"
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"pages": {}, "scripts": {}}


def theme_entries(code: str) -> dict[str, str]:
    """Every theme's entry in locale/<code>.po (context "theme"): its name as
    the app draws it (LEGO® with its mark, LEGOLAND®), and the language's,
    which is the same for a product line's or a licence's."""
    po = (ROOT / "locale" / f"{code}.po").read_text(encoding="utf-8")
    return {json.loads(f'"{english}"'): json.loads(f'"{said}"') for english, said in re.findall(
        r'^msgctxt "theme"\nmsgid "((?:[^"\\]|\\.)*)"\nmsgstr "((?:[^"\\]|\\.)*)"', po, re.M) if said}


def themes(code: str) -> dict[str, str]:
    """The Library's themes that the language words its own way, by the
    app's names for them, as the site says them too (web/card.js
    themeSaid marks the catalogue's LEGO and Legoland first; script_table
    keys them by their context)."""
    return {english: said for english, said in theme_entries(code).items() if said != english}


def script_table(code: str, words: dict) -> dict[str, str]:
    """Every word a copy's scripts may say, in [code]'s language: a copy
    carries it (#site-words), and /<code>/words.json is it for the sign-in's
    dialogs on a page with no copy. A theme by its context, as gettext keys
    it ("theme\x04Space"), so a theme and a word alike in English are each
    said their own way (web/card.js themeSaid)."""
    return {**{f"theme\x04{english}": said for english, said in themes(code).items()}, **words.get("scripts", {})}


def address(code: str, where: str) -> str:
    return f"/{code}" + (f"/{where}" if where else "")


def markup(fragment: str) -> list[str]:
    return sorted(re.findall(r"<[^>]+>", fragment))


def translated(name: str, code: str, words: dict) -> tuple[str, list[str], list[str]]:
    """web/[name] in [code]'s language, the English it has no entry for, and
    the entries whose markup is not the English's (a link lost, a tag
    broken)."""
    text = (WEB / name).read_text(encoding="utf-8")
    page = Page(text)
    said: dict = words["pages"]
    missing: list[str] = []
    broken: list[str] = []

    def say(english: str) -> str:
        key = key_of(english)
        if not says_something(plain(key)):
            return said.get(key, english)
        if key not in said:
            missing.append(key)
            return english
        if markup(said[key]) != markup(key):
            broken.append(key)
        return said[key]

    # The runs first, then each tag of what that made: a link inside a
    # run is the translation's, which keeps the English's markup.
    out = spliced(text, [(s, e, say(text[s:e])) for s, e in page.runs])
    tokens = Tokens(out)
    edits = []
    for n, (kind, start, tag, attrs) in enumerate(tokens.found):
        if kind not in ("start", "empty"):
            continue
        raw = out[start:tokens.ends[n]]
        new = raw
        for attr in ATTRIBUTES:
            if attrs.get(attr):
                new = attribute(new, attr, say(attrs[attr]))
        if tag == "meta" and (attrs.get("name") in META or attrs.get("property") in META):
            new = attribute(new, "content", say(attrs.get("content", "")))
        if tag == "html":
            new = attribute(new, "lang", code)
        href = attrs.get("href")
        if href is not None:
            new = attribute(new, "href", link(href, code, tag, attrs))
        if tag == "meta" and attrs.get("property") == "og:url":
            new = attribute(new, "content", SITE + address(code, PAGES[name]))
        if new != raw:
            edits.append((start, tokens.ends[n], new))
    out = spliced(out, edits)

    def ld(found: re.Match) -> str:
        data = json.loads(found.group(1))
        describe(data, say)
        return '<script type="application/ld+json">\n' + json.dumps(data, ensure_ascii=False, indent="\t") + "\n</script>"

    out = re.sub(r'<script type="application/ld\+json">(.*?)</script>', ld, out, flags=re.S)
    # Its words for the page's scripts, and where it was made from.
    data = json.dumps(script_table(code, words), ensure_ascii=False, sort_keys=True).replace("</", "<\\/")
    out = out.replace("</head>", f'<script type="application/json" id="site-words">{data}</script>\n</head>', 1)
    out = re.sub(r"<!--.*?-->", f"<!-- web/{name} in {LANGUAGES[code]}, written by tools/site_lang.py from it and "
                 f"web/_lang/{code}.json: change those and run it, never this. -->", out, count=1, flags=re.S)
    return out, list(dict.fromkeys(missing)), list(dict.fromkeys(broken))


def spliced(text: str, edits: list[tuple[int, int, str]]) -> str:
    """[text] with each (start, end, new) put in, none overlapping: from the
    last, so each place is still where it was."""
    for start, end, new in sorted(edits, key=lambda e: e[0], reverse=True):
        text = text[:start] + new + text[end:]
    return text


def describe(data, say) -> None:
    if isinstance(data, dict):
        for f in worded(data):
            data[f] = html.unescape(say(data[f]))
        for value in data.values():
            describe(value, say)
    elif isinstance(data, list):
        for value in data:
            describe(value, say)


def attribute(tag: str, name: str, value: str) -> str:
    """[tag] with its [name] set to [value], escaped as an attribute is."""
    escaped = html.escape(html.unescape(value), quote=True).replace("&#x27;", "'")
    pattern = re.compile(rf'(\s{re.escape(name)}=")([^"]*)(")')
    if pattern.search(tag):
        return pattern.sub(lambda m: m.group(1) + escaped + m.group(3), tag, count=1)
    return tag


def link(href: str, code: str, tag: str, attrs: dict) -> str:
    """Where a link of the copy goes: the pages it has, in its language."""
    if tag == "link" and attrs.get("rel") == "canonical":
        page = next((where for where in PAGES.values() if href.rstrip("/") == f"{SITE}/{where}".rstrip("/")), None)
        return SITE + address(code, page) if page is not None else href
    if tag != "a":
        return href
    path, _, rest = href.partition("#")
    path, _, query = path.partition("?")
    rest = f"#{rest}" if rest else ""
    if path == "/app":
        return f"/app?lang={code}" + (f"&{query}" if query else "") + rest
    for where in PAGES.values():
        if path == ("/" + where if where else "/"):
            return address(code, where) + (f"?{query}" if query else "") + rest
    return href


def written() -> dict[Path, tuple[str, list[str], list[str]]]:
    out = {}
    for code in LANGUAGES:
        words = table(code)
        for name, where in PAGES.items():
            out[WEB / code / (f"{where}.html" if where else "index.html")] = translated(name, code, words)
        said = json.dumps(script_table(code, words), ensure_ascii=False, sort_keys=True, indent=0)
        out[WEB / code / "words.json"] = (said + "\n", [], [])
    return out


def main(argv: list[str]) -> int:
    asked = next((a.split("=", 1)[1] for a in argv if a.startswith("--missing=")), "")
    if asked:
        words = table(asked)
        missing = {"pages": {}, "scripts": {}}
        for name in PAGES:
            for key in translated(name, asked, words)[1]:
                missing["pages"][key] = ""
        for word in script_words():
            if word not in words.get("scripts", {}):
                missing["scripts"][word] = ""
        print(json.dumps(missing, ensure_ascii=False, indent=1))
        return 0
    check = "--check" in argv
    problems = []
    wrote = 0
    for path, (text, missing, broken) in written().items():
        rel = path.relative_to(ROOT)
        if missing:
            problems.append(f"{rel}: {len(missing)} without words in web/_lang/{path.parent.name}.json, "
                            f"first {missing[0]!r} (tools/site_lang.py --missing={path.parent.name})")
        if broken:
            problems.append(f"{rel}: web/_lang/{path.parent.name}.json's words for {broken[0]!r} have other "
                            f"markup than it ({len(broken)} entries so)")
        if missing or broken:
            continue
        if path.exists() and path.read_text(encoding="utf-8") == text:
            continue
        if check:
            problems.append(f"{rel} is not what tools/site_lang.py writes: run it")
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        wrote += 1
    # A word shown in English where it is to be said through say().
    for name in SAID_ALL:
        left = unsaid((WEB / name).read_text(encoding="utf-8"))
        if left:
            problems.append(f"web/{name} shows {len(left)} words not said through say(), first {left[0]}: "
                            "say(\"...\") them, so each language has them (tools/site_lang.py --missing)")
    # A word a script says with no entry: it would be said in English.
    said_by_scripts = script_words()
    for code in LANGUAGES:
        has = table(code).get("scripts", {})
        short = [word for word in said_by_scripts if word not in has]
        if short:
            problems.append(f"web/_lang/{code}.json's scripts have no words for {len(short)} a script says, first "
                            f"{short[0]!r} ({said_by_scripts[short[0]]}; tools/site_lang.py --missing={code})")
    # An entry no page says any more: its English was changed or taken out.
    for code in LANGUAGES:
        said = {key_of(k) for name in PAGES for k in Page((WEB / name).read_text(encoding="utf-8")).keys()}
        unused = [key for key in table(code)["pages"] if key not in said]
        if unused:
            problems.append(f"web/_lang/{code}.json has {len(unused)} entries no page says, first {unused[0]!r}: "
                            "take them out")
    for problem in problems:
        print(f"site_lang: {problem}")
    if problems:
        return 1
    count = len(LANGUAGES) * len(PAGES)
    print(f"site_lang: {count} pages and their words in {len(LANGUAGES)} languages"
          + ("" if check else f", {wrote} written"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
