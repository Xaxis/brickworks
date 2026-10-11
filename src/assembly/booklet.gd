## Build instructions laid out the way a LEGO booklet lays them out.
##
## The first version was a web page: a parts table, then each step as a
## photograph of the whole baseplate with the model small in the middle,
## and the parts added as a line of text. Anyone who has built a hundred
## sets reads a booklet by its conventions, and that page had none of
## them. This has them:
##
##   pages      landscape, a light blue page, several steps to a page when
##              they are small and one when it is not, numbered at the
##              foot with a bar for how far through you are
##   a step     a big number, and above it a box with a picture of each
##              part the step adds and how many, "2x"; the picture of the
##              model on the page, at a size chosen for the page and the
##              same on every step of the page, from one fixed angle
##   turning    a step whose parts are behind the model is drawn from the
##              back, with the turn-it-round sign, and turned back after
##   callouts   a sub-assembly built in a framed box beside the step that
##              puts it on, "2x" when two are built, with an arrow to
##              where it goes; one too long for a box gets pages of its
##              own in the frame, and the step that puts it on shows it
##   the end    the finished model, front and back; then every part, by
##              colour, with its count and its element number
##
## Every measurement is in millimetres on a page 269 x 199, which fits a
## sheet of A4 and of US Letter turned on its side with a margin to
## spare, so one file prints on both. On screen the same millimetre is
## scaled to the window (--mm), so the page reads the same way.
##
## The new parts are not highlighted. Modern booklets keep every colour
## true and rely on the parts box, the step's place on the page and the
## ink line round every part; a highlight colour on the model reads as a
## colour of plastic, which a reader then goes looking for. The line round
## each part (booklet_ink) is what makes the box enough: with it, the
## brick the box shows can be found by its outline.
##
## Everything goes into one file — pictures as data, each part's picture
## once — because a booklet beside a folder of images is one that arrives
## broken by email.
class_name Booklet
extends RefCounted

const PAGE := Vector2(269.0, 199.0)
const MARGIN := 9.0
## The band at the foot for the page number and the progress bar.
const FOOT := 9.0
const GUTTER := 6.0
## The strip at the head of a page that starts a part of the model.
const BANNER := 11.0

## Millimetres on paper per LDU. A model is never drawn bigger than this
## — ten millimetres a stud — or the first steps of a small model are a
## poster of two plates.
const MOST_SCALE := 0.48
## The least a page of four, or of two, may draw at before fewer steps
## go on the page: six and five millimetres a stud.
const FOUR_UP := 0.3
const TWO_UP := 0.25
## Parts in a parts box, and in the list at the end.
const PART_SCALE := 0.2
const PART_SMALLEST := 6.0
const PART_LARGEST := 30.0

const PAD := 2.2
const QUANTITY := 3.2
const NUMBER := 8.0
const NUMBER_SMALL := 6.5
const CALLOUT_NUMBER := 4.5


## A part as a parts box shows it.
class Lot extends RefCounted:
	## "part:colour", which names its picture.
	var key: String = ""
	var count: int = 0
	## On paper, in mm.
	var size: Vector2 = Vector2(10, 8)
	var name: String = ""
	var colour: String = ""
	var element: String = ""
	var part_id: String = ""


## One step, as it goes on a page.
class Entry extends RefCounted:
	var number: int = 0
	var lots: Array[Lot] = []
	## What the picture must show, on the view plane, in LDU.
	var subject: Rect2 = Rect2()
	var from: Vector3 = BookletStudio.FRONT
	## Drawn from the other side to the step before: the turn sign.
	var turned: bool = false
	var awkward: bool = false
	var section: String = ""
	## An attach step's sub-assembly.
	var callout: Callout = null
	## Inside a callout: numbered small, framed in the callout's colour.
	var in_callout: bool = false
	## Framed on part of a model too big to show whole: the rest runs off
	## the picture, faded.
	var cropped: bool = false

	## Laid out: the panel on the page, the part of it the model is drawn
	## in, and how big.
	var page: int = 0
	var rect: Rect2 = Rect2()
	var free: Rect2 = Rect2()
	var scale: float = 0.0
	var parts_rect: Rect2 = Rect2()
	var number_at: Vector2 = Vector2()
	var number_size: float = NUMBER

	## Drawn: the picture (a data URI) and the arrows, in page mm.
	var image: String = ""
	var arrows: Array = []
	var note: String = ""

	## The view the picture is drawn from: centre of the picture on the
	## view plane, and pixels per LDU at [param px_per_mm].
	func view(px_per_mm: float) -> BookletStudio.View:
		var size: Vector2 = rect.size * px_per_mm
		var k: float = scale * px_per_mm
		var target: Vector2 = (free.get_center() - rect.position) * px_per_mm
		var middle: Vector2 = subject.get_center()
		var centre := Vector2(
			middle.x - (target.x - size.x * 0.5) / k,
			middle.y + (target.y - size.y * 0.5) / k)
		return BookletStudio.View.new(from, centre, k)

	func pixels(px_per_mm: float) -> Vector2i:
		return Vector2i(rect.size * px_per_mm)


## A sub-assembly: built in a box beside the step that puts it on, or,
## when it is too long for that, on pages of its own.
class Callout extends RefCounted:
	var name: String = ""
	var times: int = 1
	var steps: Array[Entry] = []
	## The finished assembly on the view plane, in LDU.
	var subject: Rect2 = Rect2()
	var from: Vector3 = BookletStudio.FRONT
	var inline: bool = true
	## Laid out: the box on the attach step's panel, a cell per picture.
	var box: Rect2 = Rect2()
	var cells: Array[Rect2] = []
	var cell_scale: float = 0.0
	## Drawn: a picture per cell (data URIs).
	var images: PackedStringArray = PackedStringArray()

	func cell_view(index: int, px_per_mm: float) -> BookletStudio.View:
		var cell: Rect2 = cells[index]
		var k: float = cell_scale * px_per_mm
		var top: float = CALLOUT_NUMBER + 1.0 if inline else 1.0
		var room := Rect2(Vector2(0.0, top), Vector2(cell.size.x, cell.size.y - top))
		var target: Vector2 = room.get_center() * px_per_mm
		var size: Vector2 = cell.size * px_per_mm
		var middle: Vector2 = subject.get_center()
		return BookletStudio.View.new(from, Vector2(
			middle.x - (target.x - size.x * 0.5) / k,
			middle.y + (target.y - size.y * 0.5) / k), k)


class Page extends RefCounted:
	## "cover", "steps", "callout", "finished" or "parts".
	var kind: String = "steps"
	var entries: Array[Entry] = []
	var number: int = 0
	## A part of the model starting: "Part 2 · the gatehouse".
	var banner: String = ""
	## A callout page: its frame, and how many to build.
	var frame: Rect2 = Rect2()
	var times: int = 1
	var name: String = ""
	## How far through the build this page is, 0 to 1.
	var progress: float = 0.0
	## Parts pages: [[Lot, Rect2 of its picture, colour heading or ""], ...]
	var cells: Array = []
	## Cover and finished pages: pictures as [data URI, Rect2].
	var pictures: Array = []


## Everything a booklet says, ready to write out.
class Document extends RefCounted:
	var title: String = ""
	var pieces: int = 0
	var steps: int = 0
	var pages: Array[Page] = []
	## key -> data URI of each part's picture.
	var parts: Dictionary = {}
	var lots: Array[Lot] = []
	## The legal line at the end.
	var credits: String = ""


# -- layout ----------------------------------------------------------------


## The content area of a page, inside the margins and above the foot.
static func content() -> Rect2:
	return Rect2(Vector2(MARGIN, MARGIN),
		PAGE - Vector2(MARGIN * 2.0, MARGIN * 2.0 + FOOT - 3.0))


## Lay steps out on pages. [param entries] are the main steps in order,
## each attach step carrying its callout. Returns the step pages,
## callout pages among them, numbered from [param first_page].
static func lay_out(entries: Array[Entry], first_page: int = 2) -> Array[Page]:
	var pages: Array[Page] = []
	var at: int = 0
	var section: String = ""
	var total: int = maxi(1, entries.size())
	while at < entries.size():
		var entry: Entry = entries[at]
		var banner: String = ""
		if entry.section != section:
			section = entry.section
			banner = section
		if entry.callout != null:
			entry.callout.inline = _fits_inline(entry.callout)
			if not entry.callout.inline:
				for page: Page in _callout_pages(entry.callout,
						float(at) / float(total)):
					pages.append(page)
		var area: Rect2 = content()
		if not banner.is_empty():
			area = Rect2(area.position + Vector2(0.0, BANNER),
				area.size - Vector2(0.0, BANNER))
		var run: Array[Entry] = []
		for index: int in range(at, mini(at + 4, entries.size())):
			var next: Entry = entries[index]
			if index > at and (next.section != section or next.callout != null):
				break
			run.append(next)
		var page := _best_page(run, area, false)
		page.banner = banner
		page.progress = float(at + page.entries.size()) / float(total)
		pages.append(page)
		at += page.entries.size()
	for index: int in pages.size():
		pages[index].number = first_page + index
		for entry: Entry in pages[index].entries:
			entry.page = pages[index].number
	return pages


## The fullest page the run can make that is still big enough to read.
static func _best_page(run: Array[Entry], area: Rect2, framed: bool) -> Page:
	for count: int in [4, 2, 1]:
		if count > run.size():
			continue
		var group: Array[Entry] = run.slice(0, count)
		if count == 4 and group.any(func(e: Entry) -> bool: return e.callout != null):
			continue
		var best: Array = []
		var best_scale: float = -1.0
		for panels: Array in _arrangements(count, area):
			var scale: float = _page_scale(group, panels)
			if scale > best_scale:
				best_scale = scale
				best = panels
		var least: float = FOUR_UP if count == 4 else (TWO_UP if count == 2 else 0.0)
		if best_scale < least:
			continue
		var page := Page.new()
		page.kind = "callout" if framed else "steps"
		for index: int in group.size():
			_place(group[index], best[index], best_scale)
			page.entries.append(group[index])
		return page
	# Nothing fits even alone: one to a page, at whatever size it takes.
	var single := Page.new()
	single.kind = "callout" if framed else "steps"
	_place(run[0], area, _page_scale([run[0]], [area]))
	single.entries.append(run[0])
	return single


## The panels a page of [param count] is cut into: four as two by two,
## two side by side or one above the other, one as the whole.
static func _arrangements(count: int, area: Rect2) -> Array:
	var half_w: float = (area.size.x - GUTTER) * 0.5
	var half_h: float = (area.size.y - GUTTER) * 0.5
	if count == 4:
		var four: Array = []
		for row: int in 2:
			for column: int in 2:
				four.append(Rect2(area.position + Vector2(
					column * (half_w + GUTTER), row * (half_h + GUTTER)),
					Vector2(half_w, half_h)))
		return [four]
	if count == 2:
		return [
			[Rect2(area.position, Vector2(half_w, area.size.y)),
				Rect2(area.position + Vector2(half_w + GUTTER, 0.0),
					Vector2(half_w, area.size.y))],
			[Rect2(area.position, Vector2(area.size.x, half_h)),
				Rect2(area.position + Vector2(0.0, half_h + GUTTER),
					Vector2(area.size.x, half_h))],
		]
	return [[area]]


## The one scale every step on the page can be drawn at: the smallest of
## the scales each fits at, so the model does not change size from one
## step to the next on the same page.
static func _page_scale(group: Array, panels: Array) -> float:
	var scale: float = MOST_SCALE
	for index: int in group.size():
		scale = minf(scale, _fit(group[index], panels[index])[0])
	return scale


## How big the step's model can be drawn in [param panel], and where:
## [scale, free rect].
static func _fit(entry: Entry, panel: Rect2) -> Array:
	var header: Vector2 = _header(entry, panel)
	var box: Vector2 = Vector2.ZERO
	if entry.callout != null:
		box = _callout_size(entry.callout, panel)
	var options: Array[Rect2] = []
	var top: float = maxf(header.y, box.y) + 3.0
	options.append(Rect2(panel.position + Vector2(0.0, top),
		Vector2(panel.size.x, panel.size.y - top)))
	var left: float = header.x + 3.0
	var right: float = (box.x + 3.0) if box.x > 0.0 else 0.0
	options.append(Rect2(panel.position + Vector2(left, 0.0),
		Vector2(panel.size.x - left - right, panel.size.y)))
	if box.x > 0.0:
		options.append(Rect2(panel.position + Vector2(left, box.y + 3.0),
			Vector2(panel.size.x - left, panel.size.y - box.y - 3.0)))
	var best_scale: float = 0.0
	var best: Rect2 = options[0]
	var size: Vector2 = entry.subject.size.max(Vector2(1.0, 1.0))
	for option: Rect2 in options:
		if option.size.x <= 4.0 or option.size.y <= 4.0:
			continue
		var scale: float = minf(option.size.x * 0.94 / size.x,
			option.size.y * 0.94 / size.y)
		if scale > best_scale:
			best_scale = scale
			best = option
	return [minf(best_scale, MOST_SCALE), best]


static func _place(entry: Entry, panel: Rect2, scale: float) -> void:
	entry.rect = panel
	entry.scale = scale
	var header: Vector2 = _header(entry, panel)
	entry.number_size = _number_size(entry, panel)
	var parts: Vector2 = _parts_size(entry.lots, _parts_width(entry, panel))
	entry.parts_rect = Rect2(panel.position, parts) if not entry.lots.is_empty() else Rect2()
	entry.number_at = panel.position + Vector2(0.4,
		(parts.y + 1.6) if not entry.lots.is_empty() else 0.0)
	if entry.callout != null:
		var size: Vector2 = _callout_size(entry.callout, panel)
		entry.callout.box = Rect2(Vector2(panel.end.x - size.x, panel.position.y), size)
		_cells(entry.callout)
	entry.free = _fit(entry, panel)[1]
	# Centred where it fits, not stretched: the free rect is narrowed to
	# what the model needs at the page's scale.
	var need: Vector2 = entry.subject.size * scale / 0.94
	var free: Rect2 = entry.free
	if header.x > 0.0 and free.position.y > panel.position.y + 1.0:
		pass
	entry.free = Rect2(free.get_center() - need.min(free.size) * 0.5,
		need.min(free.size))


static func _number_size(entry: Entry, panel: Rect2) -> float:
	if entry.in_callout:
		return NUMBER_SMALL
	return NUMBER if panel.size.y > 120.0 else NUMBER_SMALL


## The parts box and the number under it, as one block: [width, height].
static func _header(entry: Entry, panel: Rect2) -> Vector2:
	var parts: Vector2 = _parts_size(entry.lots, _parts_width(entry, panel))
	var number: float = _number_size(entry, panel)
	var width: float = maxf(parts.x, number * 0.62 * str(entry.number).length() + 1.0)
	if entry.turned:
		width = maxf(width, number * 0.62 * str(entry.number).length() + 14.0)
	return Vector2(width, parts.y + (1.6 if not entry.lots.is_empty() else 0.0) + number)


## How wide the parts box may be: most of the panel, less the callout
## box beside it.
static func _parts_width(entry: Entry, panel: Rect2) -> float:
	var widest: float = panel.size.x * 0.62
	if entry.callout != null:
		widest = minf(widest, panel.size.x - _callout_size(entry.callout, panel).x - 4.0)
	return maxf(widest, 30.0)


## The parts box: the parts in rows, each over its "2x", no wider than
## [param widest].
static func _parts_size(lots: Array[Lot], widest: float) -> Vector2:
	if lots.is_empty():
		return Vector2.ZERO
	var rows: Array = _rows(lots, widest)
	var width: float = 0.0
	var height: float = PAD
	for row: Array in rows:
		width = maxf(width, float(row[1]))
		height += float(row[2]) + QUANTITY + 1.0
	return Vector2(width + PAD * 2.0, height + PAD - 1.0)


## [[lots], width, tallest picture] per row.
static func _rows(lots: Array[Lot], widest: float) -> Array:
	var rows: Array = []
	var row: Array[Lot] = []
	var width: float = 0.0
	var tallest: float = 0.0
	for lot: Lot in lots:
		var cell: float = maxf(lot.size.x, QUANTITY * 2.0)
		if not row.is_empty() and width + PAD + cell > widest - PAD * 2.0:
			rows.append([row, width, tallest])
			row = []
			width = 0.0
			tallest = 0.0
		width += (PAD if not row.is_empty() else 0.0) + cell
		tallest = maxf(tallest, lot.size.y)
		row.append(lot)
	if not row.is_empty():
		rows.append([row, width, tallest])
	return rows


## The callout box on the attach step's panel: a cell for each of its
## steps (or one for the finished assembly, when its steps had pages of
## their own), side by side.
static func _callout_size(callout: Callout, panel: Rect2) -> Vector2:
	var count: int = callout.steps.size() if callout.inline else 1
	var scale: float = _cell_scale(callout, panel, count)
	var cell: Vector2 = _cell_size(callout, scale)
	return Vector2(cell.x * count + PAD * (count + 1),
		cell.y + PAD * 2.0 + (QUANTITY + 1.0 if callout.times > 1 else 0.0))


static func _cell_scale(callout: Callout, panel: Rect2, count: int) -> float:
	var top: float = CALLOUT_NUMBER + 1.0 if callout.inline else 1.0
	var widest: float = (panel.size.x * 0.56 - PAD * (count + 1)) / count
	var tallest: float = panel.size.y * 0.4 - top - PAD * 2.0
	var size: Vector2 = callout.subject.size.max(Vector2(1.0, 1.0))
	return minf(MOST_SCALE * 0.8, minf((widest - 2.0) / size.x, (tallest - 2.0) / size.y))


static func _cell_size(callout: Callout, scale: float) -> Vector2:
	var top: float = CALLOUT_NUMBER + 1.0 if callout.inline else 1.0
	return callout.subject.size * scale + Vector2(2.0, 2.0 + top)


## Whether the callout's steps fit in a box on a whole page's panel at a
## size that can be read; if not, they get pages of their own.
static func _fits_inline(callout: Callout) -> bool:
	if callout.steps.size() > 3:
		return false
	callout.inline = true
	return _cell_scale(callout, content(), callout.steps.size()) >= 0.16


static func _cells(callout: Callout) -> void:
	var count: int = callout.steps.size() if callout.inline else 1
	callout.cells.clear()
	var cell: Vector2 = (callout.box.size - Vector2(PAD * (count + 1),
		PAD * 2.0 + (QUANTITY + 1.0 if callout.times > 1 else 0.0)))
	cell.x /= count
	for index: int in count:
		callout.cells.append(Rect2(callout.box.position
			+ Vector2(PAD + index * (cell.x + PAD), PAD), cell))
	var top: float = CALLOUT_NUMBER + 1.0 if callout.inline else 1.0
	var size: Vector2 = callout.subject.size.max(Vector2(1.0, 1.0))
	callout.cell_scale = minf((cell.x - 2.0) / size.x, (cell.y - 2.0 - top) / size.y)


## A long sub-assembly's own pages, framed: its steps laid out as steps
## are, numbered from 1, the frame saying how many to build.
static func _callout_pages(callout: Callout, progress: float) -> Array[Page]:
	var pages: Array[Page] = []
	var frame: Rect2 = content().grow(-1.0)
	var area := Rect2(frame.position + Vector2(5.0, 5.0),
		frame.size - Vector2(10.0, 10.0 + (QUANTITY + 3.0 if callout.times > 1 else 0.0)))
	var at: int = 0
	while at < callout.steps.size():
		var run: Array[Entry] = callout.steps.slice(at, mini(at + 4, callout.steps.size()))
		var page := _best_page(run, area, true)
		page.frame = frame
		page.times = callout.times
		page.name = callout.name
		page.progress = progress
		pages.append(page)
		at += page.entries.size()
	return pages


## The parts list at the end: every part, by colour, a column at a time.
static func parts_pages(lots: Array[Lot], first_page: int) -> Array[Page]:
	var pages: Array[Page] = []
	var area: Rect2 = content()
	area = Rect2(area.position + Vector2(0.0, 10.0), area.size - Vector2(0.0, 10.0))
	const COLUMN := 24.5
	var columns: int = int((area.size.x + 2.0) / COLUMN)
	var page := Page.new()
	page.kind = "parts"
	var column: int = 0
	var y: float = area.position.y
	var colour: String = ""
	for lot: Lot in lots:
		var size: Vector2 = _fitted(lot.size, Vector2(COLUMN - 3.0, 16.0))
		var heading: String = ""
		if lot.colour != colour:
			colour = lot.colour
			heading = colour
		var height: float = size.y + 7.6 + (6.0 if not heading.is_empty() else 0.0)
		if y + height > area.end.y:
			column += 1
			y = area.position.y
			if column >= columns:
				pages.append(page)
				page = Page.new()
				page.kind = "parts"
				column = 0
		var cell := Rect2(Vector2(area.position.x + column * COLUMN,
			y + (6.0 if not heading.is_empty() else 0.0)), size)
		page.cells.append([lot, cell, heading])
		y += height
	if not page.cells.is_empty():
		pages.append(page)
	for index: int in pages.size():
		pages[index].number = first_page + index
		pages[index].progress = 1.0
	return pages


static func _fitted(size: Vector2, most: Vector2) -> Vector2:
	var shrink: float = minf(1.0, minf(most.x / maxf(size.x, 0.1), most.y / maxf(size.y, 0.1)))
	return size * shrink


## A part's size on paper from its size on the view plane, in LDU.
static func part_size(extent: Vector2) -> Vector2:
	var size: Vector2 = extent * PART_SCALE
	var longest: float = maxf(size.x, size.y)
	if longest > PART_LARGEST:
		size *= PART_LARGEST / longest
	elif longest < PART_SMALLEST and longest > 0.0:
		size *= PART_SMALLEST / longest
	return size


# -- writing it out ----------------------------------------------------------


static func html(document: Document) -> String:
	var out := PackedStringArray()
	out.append(_head(document))
	for page: Page in document.pages:
		out.append(_page(page, document))
	out.append("</main>\n</html>\n")
	return "\n".join(out)


static func _head(document: Document) -> String:
	var parts := PackedStringArray()
	var index: int = 0
	for key: String in document.parts:
		parts.append(".%s{background-image:url(%s)}" % [_class_of(key, document),
			document.parts[key]])
		index += 1
	return """<!doctype html>
<html lang="en">
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%s — building instructions</title>
<style>
:root {
  --mm: 1mm;
  --page: #dcecf8; --box: #bcdaf1; --box-line: #3d6f97;
  --callout: #fff3c8; --callout-line: #34393f; --ink: #15191e;
}
@media screen {
  :root { --mm: min(3.78px, calc((100vw - 24px) / 269)); }
  body { background: #5f6b78; }
  .page { margin: 12px auto; box-shadow: 0 2px 14px rgba(0,0,0,.35); }
  .bar { position: sticky; top: 0; z-index: 9; display: flex; gap: 12px;
    align-items: center; justify-content: center; padding: 8px;
    background: #27313c; color: #e8eef4; font: 14px system-ui, sans-serif; }
  .bar button { font: inherit; padding: 5px 14px; border-radius: 6px;
    border: 0; background: #e3ecf4; color: #17202a; cursor: pointer; }
}
@media print {
  @page { size: landscape; margin: 0; }
  body { background: #fff; }
  .page { margin: 5mm auto 0; break-after: page; page-break-after: always; }
  .bar { display: none; }
}
* { box-sizing: border-box; }
body { margin: 0; color: var(--ink);
  font-family: "Helvetica Neue", Arial, "Segoe UI", Roboto, sans-serif; }
.page { position: relative; width: calc(269 * var(--mm)); height: calc(199 * var(--mm));
  background: var(--page); overflow: hidden;
  print-color-adjust: exact; -webkit-print-color-adjust: exact; }
.a { position: absolute; left: calc(var(--x) * var(--mm)); top: calc(var(--y) * var(--mm));
  width: calc(var(--w) * var(--mm)); height: calc(var(--h) * var(--mm)); }
.t { position: absolute; left: calc(var(--x) * var(--mm)); top: calc(var(--y) * var(--mm));
  font-size: calc(var(--s) * var(--mm)); line-height: 1; white-space: nowrap; }
img.a { display: block; }
.box { background: var(--box); border: calc(.35 * var(--mm)) solid var(--box-line);
  border-radius: calc(2.2 * var(--mm)); }
.co { background: var(--callout); border: calc(.4 * var(--mm)) solid var(--callout-line);
  border-radius: calc(2.6 * var(--mm)); }
.frame { background: #fff8de; border: calc(.5 * var(--mm)) solid var(--callout-line);
  border-radius: calc(3.5 * var(--mm)); }
.pt { position: absolute; left: calc(var(--x) * var(--mm)); top: calc(var(--y) * var(--mm));
  width: calc(var(--w) * var(--mm)); height: calc(var(--h) * var(--mm));
  background-size: contain; background-repeat: no-repeat; background-position: center bottom; }
.q { font-weight: 600; }
.n { font-weight: 700; letter-spacing: -.02em; }
.e { color: #3b4652; }
.ban { background: #23527c; color: #fff; border-radius: calc(2 * var(--mm)); }
.note { background: #fff1d6; color: #7a4a00; border-radius: calc(1.4 * var(--mm));
  padding: calc(1 * var(--mm)) calc(1.6 * var(--mm)); white-space: normal; }
svg.over { position: absolute; left: 0; top: 0; width: 100%%; height: 100%%; overflow: visible; }
.chip { display: inline-block; width: calc(2.4 * var(--mm)); height: calc(2.4 * var(--mm));
  border-radius: calc(.5 * var(--mm)); vertical-align: calc(-.3 * var(--mm));
  margin-right: calc(1 * var(--mm)); box-shadow: inset 0 0 0 calc(.2 * var(--mm)) rgba(0,0,0,.3); }
%s
</style>
<div class="bar"><span>%s</span><button onclick="print()">Print</button></div>
<main>""" % [_escape(document.title), "\n".join(parts), _escape(document.title)]


static func _class_of(key: String, document: Document) -> String:
	return "p%d" % document.parts.keys().find(key)


static func _page(page: Page, document: Document) -> String:
	var out := PackedStringArray()
	out.append("<section class=\"page %s\" id=\"page-%d\">" % [page.kind, page.number])
	var svg := PackedStringArray()
	match page.kind:
		"cover":
			_cover(page, document, out)
		"finished":
			for index: int in page.pictures.size():
				var picture: Array = page.pictures[index]
				if index > 0:
					out.append(_div(picture[1], "", "background:#fff;border-radius:calc(2.5 * var(--mm));"
						+ "box-shadow:0 0 0 calc(.35 * var(--mm)) #3d6f97"))
				_image(out, picture[0], picture[1], "The finished model")
			out.append(_text(Vector2(MARGIN, MARGIN), 8.0, "Finished", "n"))
		"parts":
			_parts_page(page, document, out)
		_:
			if page.kind == "callout":
				out.append(_div(page.frame, "frame"))
				if page.times > 1:
					var badge: Vector2 = page.frame.end - Vector2(18.0, 10.0)
					out.append(_text(badge, 7.0, "%dx" % page.times, "n"))
			if not page.banner.is_empty():
				var strip := Rect2(Vector2(MARGIN, MARGIN), Vector2(content().size.x, BANNER - 3.0))
				out.append(_div(strip, "ban"))
				out.append(_text(strip.position + Vector2(3.0, 2.0), 4.2,
					_escape(page.banner.capitalize() if page.banner.begins_with("part ")
						else page.banner), "n", "color:#fff"))
			for entry: Entry in page.entries:
				_entry(entry, document, out, svg)
	# The foot: the page number at the outer corner, and how far through.
	if page.kind != "cover":
		var left: bool = page.number % 2 == 0
		var bar := Rect2(Vector2(MARGIN + 12.0, PAGE.y - 7.0), Vector2(PAGE.x - MARGIN * 2.0 - 24.0, 1.2))
		svg.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\".6\" fill=\"#a9c9e3\"/>"
			% [_n(bar.position.x), _n(bar.position.y), _n(bar.size.x), _n(bar.size.y)])
		svg.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\".6\" fill=\"#2c6496\"/>"
			% [_n(bar.position.x), _n(bar.position.y),
				_n(bar.size.x * clampf(page.progress, 0.0, 1.0)), _n(bar.size.y)])
		var x: float = MARGIN if left else PAGE.x - MARGIN - 8.0
		out.append(_text(Vector2(x, PAGE.y - 8.6), 3.6, str(page.number), "q",
			"" if left else "text-align:right;width:calc(8 * var(--mm))"))
	if not svg.is_empty():
		out.append("<svg class=\"over\" viewBox=\"0 0 %s %s\" aria-hidden=\"true\">%s</svg>"
			% [_n(PAGE.x), _n(PAGE.y), "".join(svg)])
	out.append("</section>")
	return "\n".join(out)


static func _entry(entry: Entry, document: Document, out: PackedStringArray,
		svg: PackedStringArray) -> void:
	if not entry.image.is_empty():
		_image(out, entry.image, entry.rect, "Step %d" % entry.number)
	if not entry.lots.is_empty():
		out.append(_div(entry.parts_rect, "box"))
		var y: float = entry.parts_rect.position.y + PAD
		for row: Array in _rows(entry.lots, _parts_width(entry, entry.rect)):
			var x: float = entry.parts_rect.position.x + PAD
			var tallest: float = float(row[2])
			for lot: Lot in row[0]:
				var cell: float = maxf(lot.size.x, QUANTITY * 2.0)
				var at := Rect2(Vector2(x + (cell - lot.size.x) * 0.5, y + tallest - lot.size.y),
					lot.size)
				out.append(_part(at, lot, document))
				out.append(_text(Vector2(x, y + tallest + 0.6), QUANTITY * 0.82,
					"%dx" % lot.count, "q"))
				x += cell + PAD
			y += tallest + QUANTITY + 1.0
	out.append(_text(entry.number_at, entry.number_size, str(entry.number), "n"))
	if entry.turned:
		var size: float = 10.0
		var at := Vector2(entry.number_at.x + entry.number_size * 0.62 * str(entry.number).length() + 3.0,
			entry.number_at.y + entry.number_size * 0.5 - size * 0.5)
		svg.append(_turn_sign(Rect2(at, Vector2(size, size))))
	if not entry.note.is_empty():
		var note := Rect2(Vector2(entry.rect.position.x, entry.rect.end.y - 9.0),
			Vector2(minf(78.0, entry.rect.size.x), 8.0))
		out.append("<div class=\"t note\" style=\"--x:%s;--y:%s;--s:2.8;width:calc(%s * var(--mm))\">%s</div>"
			% [_n(note.position.x), _n(note.position.y), _n(note.size.x), _escape(entry.note)])
	if entry.callout != null:
		var callout: Callout = entry.callout
		out.append(_div(callout.box, "co"))
		for index: int in callout.cells.size():
			if index < callout.images.size() and not callout.images[index].is_empty():
				_image(out, callout.images[index], callout.cells[index],
					"%s, step %d" % [callout.name, index + 1])
			if callout.inline and callout.steps.size() > 1:
				out.append(_text(callout.cells[index].position + Vector2(0.6, 0.4),
					CALLOUT_NUMBER, str(index + 1), "n"))
		if callout.times > 1:
			out.append(_text(callout.box.end - Vector2(PAD + 7.0, PAD + QUANTITY + 0.6),
				QUANTITY * 1.15, "%dx" % callout.times, "n"))
		for arrow: Array in entry.arrows:
			svg.append(_arrow(arrow[0], arrow[1]))


static func _cover(page: Page, document: Document, out: PackedStringArray) -> void:
	out.append(_div(Rect2(Vector2.ZERO, Vector2(PAGE.x, 30.0)), "", "background:#23527c"))
	out.append(_div(Rect2(Vector2(MARGIN, 7.0), Vector2(44.0, 16.0)), "",
		"background:#d0312d;border-radius:calc(2 * var(--mm))"))
	out.append(_text(Vector2(MARGIN + 3.6, 12.4), 5.0, "BRICKWORKS", "n", "color:#fff"))
	out.append(_text(Vector2(MARGIN + 52.0, 10.0), 10.0, _escape(document.title), "n",
		"color:#fff"))
	for picture: Array in page.pictures:
		_image(out, picture[0], picture[1], "The finished model")
	out.append(_text(Vector2(MARGIN, PAGE.y - 15.0), 4.0, "%d pieces · %d steps" % [document.pieces, document.steps], "q"))
	out.append(_text(Vector2(MARGIN, PAGE.y - 9.0), 2.6, "Building instructions made with Brickworks — brickworks.diy", "e"))


static func _parts_page(page: Page, document: Document, out: PackedStringArray) -> void:
	out.append(_text(Vector2(MARGIN, MARGIN), 6.0, "Parts", "n"))
	for cell: Array in page.cells:
		var lot: Lot = cell[0]
		var at: Rect2 = cell[1]
		var heading: String = cell[2]
		if not heading.is_empty():
			out.append(_text(at.position - Vector2(0.0, 4.4), 2.5, _escape(heading), "e"))
		out.append(_part(at, lot, document))
		out.append(_text(Vector2(at.position.x, at.end.y + 0.8), 3.0, "%dx" % lot.count, "q"))
		var label: String = lot.element if not lot.element.is_empty() else lot.part_id
		out.append(_text(Vector2(at.position.x, at.end.y + 4.4), 2.5, _escape(label), "e"))
	if page.number == 0:
		pass
	out.append(_text(Vector2(MARGIN, PAGE.y - 13.0), 2.3, document.credits, "e"))


static func _part(at: Rect2, lot: Lot, document: Document) -> String:
	return "<i class=\"pt %s\" style=\"--x:%s;--y:%s;--w:%s;--h:%s\" title=\"%s\"></i>" % [
		_class_of(lot.key, document), _n(at.position.x), _n(at.position.y),
		_n(at.size.x), _n(at.size.y),
		_escape("%s, %s%s" % [lot.name, lot.colour,
			(" (%s)" % lot.element) if not lot.element.is_empty() else ""])]


static func _image(out: PackedStringArray, source: String, at: Rect2, alt: String) -> void:
	out.append("<img class=\"a\" style=\"--x:%s;--y:%s;--w:%s;--h:%s\" src=\"%s\" alt=\"%s\">"
		% [_n(at.position.x), _n(at.position.y), _n(at.size.x), _n(at.size.y), source,
			_escape(alt)])


static func _div(at: Rect2, kind: String, style: String = "") -> String:
	return "<div class=\"a %s\" style=\"--x:%s;--y:%s;--w:%s;--h:%s;%s\"></div>" % [
		kind, _n(at.position.x), _n(at.position.y), _n(at.size.x), _n(at.size.y), style]


static func _text(at: Vector2, size: float, text: String, kind: String,
		style: String = "") -> String:
	return "<div class=\"t %s\" style=\"--x:%s;--y:%s;--s:%s;%s\">%s</div>" % [
		kind, _n(at.x), _n(at.y), _n(size), style, text]


## A line from the callout box to where the assembly goes, with a head.
static func _arrow(from: Vector2, to: Vector2) -> String:
	var way: Vector2 = (to - from).normalized()
	if way == Vector2.ZERO:
		return ""
	var side := Vector2(-way.y, way.x)
	var base: Vector2 = to - way * 3.2
	return ("<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"#15191e\" stroke-width=\".45\"/>"
		% [_n(from.x), _n(from.y), _n(base.x), _n(base.y)]
		+ "<path d=\"M%s %s L%s %s L%s %s Z\" fill=\"#15191e\"/>" % [
			_n(to.x), _n(to.y), _n(base.x + side.x * 1.4), _n(base.y + side.y * 1.4),
			_n(base.x - side.x * 1.4), _n(base.y - side.y * 1.4)])


## Turn the model round: a rounded square with a half-circle arrow.
static func _turn_sign(at: Rect2) -> String:
	var c: Vector2 = at.get_center()
	var r: float = at.size.x * 0.3
	return ("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"1.6\" fill=\"#fff\" stroke=\"#15191e\" stroke-width=\".35\"/>"
		% [_n(at.position.x), _n(at.position.y), _n(at.size.x), _n(at.size.y)]
		+ "<path d=\"M%s %s A%s %s 0 1 1 %s %s\" fill=\"none\" stroke=\"#15191e\" stroke-width=\".7\"/>"
		% [_n(c.x - r), _n(c.y), _n(r), _n(r * 0.55), _n(c.x + r), _n(c.y + 0.01)]
		+ "<path d=\"M%s %s l%s %s l%s %s Z\" fill=\"#15191e\"/>"
		% [_n(c.x + r + 1.3), _n(c.y - 0.9), _n(-1.3), _n(2.4), _n(-1.4), _n(-2.0)])


static func _n(value: float) -> String:
	return String.num(value, 2)


## Text going into HTML. The part library has ampersands and quotes in
## its names — "Brick 1 x 4 with 4 Studs on Side & Groove" — and a name
## written straight into markup is a name that breaks the page.
static func _escape(raw: String) -> String:
	return (raw.replace("&", "&amp;").replace("<", "&lt;")
		.replace(">", "&gt;").replace("\"", "&quot;"))
