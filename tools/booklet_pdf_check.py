#!/usr/bin/env python3
"""Is a booklet's PDF (and its pages' zip) the booklet, read by readers not ours?

    python3 tools/booklet_pdf_check.py BOOKLET.html BOOKLET.pdf [--zip PAGES.zip] [--out DIR]
        [--shots DIR]

The PDF is read by poppler (pdfinfo, pdftotext, pdftoppm), which every Linux
desktop has, and by pypdf where it can be imported (PYTHONPATH, or a folder
named by BOOKLET_PYPDF). Checked against the booklet's own file:

  the PDF opens, has the booklet's pages, each 269 x 199 mm
  each page's step pictures are the booklet's own JPEGs, byte for byte
    (pypdf; with poppler alone, the first and the last page)
  the title is words on the first page, and the last page's element numbers
    are words on the last
  every font the PDF uses is in it (pdffonts: emb yes), so every reader
    draws the same letters
  the zip has a PNG a page, and its first and last are the PDF's pages
    drawn by poppler, to within what two drawings of one page differ by;
    each is 300 dots an inch, in its pixels and in what it says (pHYs)
  with --shots, the browser's own pictures of those pages (page-N.png, from
    tools/web/booklet_print.mjs) are the PDF's too

Prints a line a check, and exits 1 when one fails.
"""
import argparse
import base64
import hashlib
import io
import os
import re
import subprocess
import sys
import tempfile
import zipfile

SECTION = re.compile(r'<section class="page[^"]*" id="page-(\d+)"')
JPEG = re.compile(r'src="data:image/jpeg;base64,([^"]+)"')
TITLE = re.compile(r"<title>(.*?)</title>")
TEXT = re.compile(r'<div class="t[^"]*"[^>]*>(.*?)</div>')

failures = 0


def check(what, ok):
    global failures
    print(("ok   " if ok else "FAIL ") + what)
    if not ok:
        failures += 1
    return ok


def booklet(path):
    """Each page's number, its JPEGs' digests, and its words, a page at a time."""
    pages, title = [], ""
    current = None
    with open(path, encoding="utf-8", errors="replace") as file:
        for line in file:
            if not title:
                found = TITLE.search(line)
                if found:
                    title = found.group(1)
            found = SECTION.search(line)
            if found:
                current = {"number": int(found.group(1)), "jpegs": [], "words": []}
                pages.append(current)
            if current is None:
                continue
            for data in JPEG.findall(line):
                current["jpegs"].append(hashlib.sha1(base64.b64decode(data)).hexdigest())
            for words in TEXT.findall(line):
                current["words"].append(re.sub(r"<[^>]*>", "", words).replace("&amp;", "&"))
    return title, pages


def run(*command):
    return subprocess.run(command, capture_output=True, text=True, check=False)


def rendered(pdf, number, dpi, into):
    stem = os.path.join(into, "pdf-%d" % number)
    run("pdftoppm", "-r", str(dpi), "-f", str(number), "-l", str(number), "-png",
        "-singlefile", pdf, stem)
    return stem + ".png"


def embedded(pdf):
    """[(name, embedded)] for each font pdffonts lists, read by its columns."""
    lines = run("pdffonts", pdf).stdout.splitlines()
    if len(lines) < 2:
        return []
    columns, at = [], 0
    for dashes in lines[1].split(" "):
        columns.append((at, at + len(dashes)))
        at += len(dashes) + 1
    out = []
    for line in lines[2:]:
        cells = [line[a:b].strip() for a, b in columns]
        if len(cells) > 3 and cells[0]:
            out.append((cells[0], cells[3] == "yes"))
    return out


def differ(a, b):
    """How far apart two pictures of one page are: the mean difference of a
    channel out of 255, both at 400 px wide. Small enough that two ways of
    smoothing one picture's pixels agree; big enough that a box, a line of
    words or a picture out of place by a millimetre does not."""
    from PIL import Image, ImageChops, ImageStat
    one = Image.open(a).convert("RGB")
    size = (400, round(400 * one.size[1] / one.size[0]))
    one = one.resize(size, Image.LANCZOS)
    two = Image.open(b).convert("RGB").resize(size, Image.LANCZOS)
    return sum(ImageStat.Stat(ImageChops.difference(one, two)).mean) / 3.0


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("html")
    parser.add_argument("pdf")
    parser.add_argument("--zip")
    parser.add_argument("--out")
    parser.add_argument("--shots")
    parser.add_argument("--most", type=float, default=8.0,
                        help="the most two drawings of a page may differ by (of 255)")
    args = parser.parse_args()
    out = args.out or tempfile.mkdtemp()
    os.makedirs(out, exist_ok=True)

    title, pages = booklet(args.html)
    count = len(pages)
    print("the booklet: %d pages, %d step pictures, %s" % (
        count, sum(len(p["jpegs"]) for p in pages), title))
    info = run("pdfinfo", args.pdf)
    check("poppler opens the PDF (%s)" % (info.stderr.strip()[:80] or "no errors"),
          info.returncode == 0 and not info.stderr.strip())
    said = dict(line.split(":", 1) for line in info.stdout.splitlines() if ":" in line)
    pdf_pages = int(said.get("Pages", "0").strip() or 0)
    check("...with the booklet's %d pages (%d)" % (count, pdf_pages), pdf_pages == count > 0)
    size = said.get("Page size", "").strip()
    check("...each 269 x 199 mm (%s)" % size, size.startswith("762.52 x 564.09"))
    check("...and its title (%s)" % said.get("Title", "").strip(),
          said.get("Title", "").strip() == title.replace("&amp;", "&"))
    fonts = embedded(args.pdf)
    check("every font is in the PDF (%s)" % (", ".join("%s %s" % (name, "embedded" if emb else "NOT embedded")
                                                      for name, emb in fonts) or "pdffonts lists none"),
          fonts and all(emb for _, emb in fonts))

    # The step pictures, byte for byte.
    pypdf = None
    if os.environ.get("BOOKLET_PYPDF"):
        sys.path.insert(0, os.environ["BOOKLET_PYPDF"])
    try:
        import pypdf  # noqa: F811
    except ImportError:
        pypdf = None
    if pypdf is not None:
        reader = pypdf.PdfReader(args.pdf)
        check("pypdf %s opens it, %d pages" % (pypdf.__version__, len(reader.pages)),
              len(reader.pages) == count)
        wrong = []
        for index, page in enumerate(reader.pages):
            found = []
            xobjects = page["/Resources"].get("/XObject", {})
            for name in xobjects:
                image = xobjects[name].get_object()
                if image.get("/Filter") == "/DCTDecode":
                    found.append(hashlib.sha1(image.get_data()).hexdigest())
            if index < count and sorted(found) != sorted(pages[index]["jpegs"]):
                wrong.append(pages[index]["number"])
        check("each page's step pictures are the booklet's own JPEGs, byte for byte "
              "(%d pages differ%s)" % (len(wrong), (": %s" % wrong[:8]) if wrong else ""),
              not wrong)
    else:
        print("     pypdf is not here: the first and last pages' pictures by poppler alone")
        for index in sorted({0, count - 1}):
            folder = tempfile.mkdtemp(dir=out)
            number = index + 1
            run("pdfimages", "-j", "-f", str(number), "-l", str(number), args.pdf,
                os.path.join(folder, "i"))
            found = sorted(hashlib.sha1(open(os.path.join(folder, name), "rb").read()).hexdigest()
                           for name in os.listdir(folder) if name.endswith(".jpg"))
            check("page %d's step pictures are the booklet's own JPEGs (%d)" % (
                number, len(found)), found == sorted(pages[index]["jpegs"]))

    # Words a reader finds.
    first = run("pdftotext", "-f", "1", "-l", "1", args.pdf, "-").stdout
    name = title.split(" — ")[0].replace("&amp;", "&")
    check("the first page's words have the title (%s)" % name, name in first)
    last = run("pdftotext", "-f", str(count), "-l", str(count), args.pdf, "-").stdout
    labels = [w for w in pages[-1]["words"] if re.fullmatch(r"[0-9a-z]{3,}", w)] if pages else []
    missing = [w for w in labels if w not in last]
    check("the last page's words have its %d element numbers (%d missing%s)" % (
        len(labels), len(missing), (": %s" % missing[:5]) if missing else ""),
          labels and not missing)

    # The pages as pictures, against the PDF drawn by poppler.
    if args.zip and not check("the zip is there (%s)" % args.zip, os.path.exists(args.zip)):
        pass
    elif args.zip:
        with zipfile.ZipFile(args.zip) as archive:
            names = sorted(n for n in archive.namelist() if n.endswith(".png"))
            check("the zip has a PNG a page (%d)" % len(names), len(names) == count)
            for index in sorted({0, count - 1}) if names else []:
                number = pages[index]["number"]
                ours = os.path.join(out, "png-%d.png" % number)
                with open(ours, "wb") as file:
                    file.write(archive.read(names[index]))
                from PIL import Image
                picture = Image.open(ours)
                wide = picture.size[0]
                dpi = round(wide / (269 / 25.4))
                says = picture.info.get("dpi", (0, 0))
                check("page %d's PNG is 300 dots an inch: %d x %d px, and says %.0f x %.0f" % (
                    number, wide, picture.size[1], says[0], says[1]),
                      dpi == 300 and abs(says[0] - 300) < 0.5 and abs(says[1] - 300) < 0.5)
                drawn = rendered(args.pdf, number, dpi, out)
                apart = differ(ours, drawn)
                check("page %d's PNG (%d px wide) is the PDF's page drawn by poppler "
                      "(%.2f apart of 255)" % (number, wide, apart), apart <= args.most)
    if args.shots:
        for index in sorted({0, 1, count - 1}):
            number = pages[index]["number"]
            shot = os.path.join(args.shots, "page-%d.png" % number)
            if not os.path.exists(shot):
                continue
            drawn = rendered(args.pdf, number, 96, out)
            apart = differ(shot, drawn)
            check("page %d drawn by the browser is the PDF's page (%.2f apart of 255)" % (
                number, apart), apart <= args.most)
    print("%s: %s" % (os.path.basename(args.pdf), "PASS" if failures == 0 else "FAIL (%d)" % failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
