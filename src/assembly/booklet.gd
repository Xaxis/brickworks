## Build instructions as a page you can print.
##
## The booklet exists in the app already — it is what the step bar walks
## through — but it cannot leave, and instructions you can only follow at
## the screen you designed at are instructions for nobody. A set comes
## with a booklet because you build on a table.
##
## So this writes one file with everything in it: the pictures inline as
## data, the parts each step adds, and the whole inventory at the front.
## One file matters more than it sounds — a page with images beside it is
## a page that arrives broken by email, loses its pictures when moved,
## and cannot simply be handed to somebody.
##
## The layout is the one every set uses, because it is the one that
## works: a picture of what the model looks like after this step, and
## beside it the parts this step adds. What changed is what you can see
## appear against the picture before it.
class_name Booklet
extends RefCounted


## One page: the picture after the step, and what the step added.
class Page extends RefCounted:
	var index: int = 0
	var image: String = ""     ## a data: URI, ready to drop into <img>
	var adds: Array = []       ## [{count, part, name, colour, rgb}]
	var awkward: bool = false  ## the step had to be taken out of order


## Build the whole document.
static func html(title: String, pages: Array[Page], stock: Inventory) -> String:
	var out := PackedStringArray()
	out.append(_head(title))
	out.append(_cover(title, pages.size(), stock))
	out.append(_parts(stock))
	for page: Page in pages:
		out.append(_page(page, pages.size()))
	out.append(_foot())
	return "\n".join(out)


static func _head(title: String) -> String:
	# Everything inline. A stylesheet beside the file is one more thing to
	# lose, and this has to survive being emailed.
	return """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s — build instructions</title>
<style>
  :root {
    --ink: #14181d; --soft: #5b6472; --faint: #97a0ae;
    --line: #e2e6ec; --paper: #ffffff; --panel: #f5f7fa;
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; background: var(--panel); color: var(--ink);
    font: 16px/1.55 ui-sans-serif, -apple-system, "Segoe UI", Roboto, sans-serif;
  }
  .sheet {
    max-width: 860px; margin: 0 auto; padding: 44px 34px;
    background: var(--paper);
  }
  h1 { font-size: 34px; letter-spacing: -0.02em; margin: 0 0 6px; }
  h2 { font-size: 19px; margin: 34px 0 12px; }
  .sub { color: var(--soft); margin: 0 0 4px; }
  .tally { color: var(--faint); font-size: 14px; }
  table { border-collapse: collapse; width: 100%%; font-size: 14.5px; }
  th { text-align: left; font-weight: 600; color: var(--soft);
       border-bottom: 1px solid var(--line); padding: 7px 8px; }
  td { padding: 6px 8px; border-bottom: 1px solid var(--line); }
  td.n { text-align: right; width: 58px; color: var(--soft); }
  .chip { display: inline-block; width: 13px; height: 13px; border-radius: 3px;
          vertical-align: -2px; margin-right: 7px;
          box-shadow: inset 0 0 0 1px rgba(0,0,0,.22); }
  .step { border-top: 1px solid var(--line); padding-top: 26px; margin-top: 30px; }
  .step:first-of-type { border-top: 0; }
  .num { font-size: 13px; letter-spacing: .1em; text-transform: uppercase;
         color: var(--faint); margin-bottom: 10px; }
  .step img { width: 100%%; border-radius: 8px; background: var(--panel);
              display: block; }
  .adds { margin-top: 14px; display: flex; flex-wrap: wrap; gap: 8px 18px; }
  .add { font-size: 14.5px; }
  .add b { font-weight: 600; }
  .warn { margin-top: 10px; font-size: 14px; color: #9a5b00;
          background: #fff5e2; border-radius: 6px; padding: 8px 11px; }
  footer { color: var(--faint); font-size: 13px; margin-top: 44px;
           border-top: 1px solid var(--line); padding-top: 16px; }
  a { color: inherit; }
  /* One step to a sheet, so a page break never lands between a picture
     and the parts that go with it. */
  @media print {
    body { background: #fff; }
    .sheet { max-width: none; padding: 0 12mm; }
    .step { break-inside: avoid; page-break-inside: avoid; }
    h2 { break-after: avoid; }
  }
</style>
<div class="sheet">""" % _escape(title)


static func _cover(title: String, steps: int, stock: Inventory) -> String:
	return """<h1>%s</h1>
<p class="sub">%d steps · %d pieces · %d lots · %s</p>
<p class="tally">Made with Brickworks. Every part is drawn at its true
size, so what you see here is the size it will be on the table.</p>""" % [
		_escape(title), steps, stock.pieces, stock.lot_count(), stock.weight()]


static func _parts(stock: Inventory) -> String:
	var rows := PackedStringArray()
	rows.append("<h2>What you need</h2>")
	rows.append("<table><thead><tr><th class=\"n\">Qty</th><th>Part</th>"
		+ "<th>Name</th><th>Colour</th></tr></thead><tbody>")
	for lot: Inventory.Lot in stock.lots:
		rows.append("<tr><td class=\"n\">%d</td><td>%s</td><td>%s</td>"
			% [lot.count, _escape(lot.part_id), _escape(lot.name)]
			+ "<td><span class=\"chip\" style=\"background:%s\"></span>%s</td></tr>"
			% [_hex(lot), _escape(lot.color_name)])
	rows.append("</tbody></table>")
	return "\n".join(rows)


static func _page(page: Page, total: int) -> String:
	var adds := PackedStringArray()
	for add: Dictionary in page.adds:
		adds.append("<span class=\"add\"><span class=\"chip\" style=\"background:%s\"></span>"
			% str(add.get("rgb", "#888"))
			+ "<b>%d ×</b> %s <span style=\"color:var(--faint)\">%s</span></span>"
			% [int(add.get("count", 0)), _escape(str(add.get("name", ""))),
				_escape(str(add.get("colour", "")))])

	var warning := ""
	if page.awkward:
		warning = ("<p class=\"warn\">Hold this one in place — it does not "
			+ "rest on anything until the next step.</p>")

	return """<section class="step">
  <div class="num">Step %d of %d</div>
  <img src="%s" alt="The model after step %d.">
  <div class="adds">%s</div>%s
</section>""" % [page.index, total, page.image, page.index,
		" ".join(adds), warning]


static func _foot() -> String:
	return """<footer>
  Part geometry from the LDraw&trade; Parts Library, &copy; the LDraw
  community, licensed CC BY 4.0. LEGO&reg; is a trademark of the LEGO
  Group, which does not sponsor or endorse this.
  <a href="https://brickworks.diy">brickworks.diy</a>
</footer>
</div>
</html>"""


static func _hex(lot: Inventory.Lot) -> String:
	return "#%s" % lot.rgb_hex


## Text going into HTML. The part library has ampersands and quotes in
## its names — "Brick 1 x 4 with 4 Studs on Side & Groove" — and a name
## written straight into markup is a name that breaks the page.
static func _escape(raw: String) -> String:
	return (raw.replace("&", "&amp;").replace("<", "&lt;")
		.replace(">", "&gt;").replace("\"", "&quot;"))
