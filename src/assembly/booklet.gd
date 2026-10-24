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
## The new parts are outlined, as Studio's Instruction Maker and LEGO
## booklets of the app era outline them: a band of orange just outside
## what the step adds, past the ink line round it (booklet_ink), and the
## parts inside keep their own colours, so the band reads as a mark and not
## as plastic. Its designer can turn it off for the whole booklet
## (BookletLooks "highlight"), for a booklet that relies on the parts box
## and the ink line alone, as most printed ones do.
##
## A designer can also lay a page out by hand (BookletLooks "place" and
## "notes"): a step's picture, its parts box, its callout and its number
## where they were dragged to, and words and pictures of their own on the
## page. What was not placed is laid out as below.
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
## How much larger than that a step given a page alone may be drawn.
const ALONE_MOST := 3.0
## How near, in mm, an item dragged on the page snaps to a margin or to
## another item's edge (BookletPlace).
const SNAP := 2.5
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
	## The hidden parts' colours that start on this step (BookletMaker
	## .marks): [{label, name, rgb}], a chip each beside the number, or in
	## the banner when the step starts the section it is the colour of.
	var marks: Array = []
	## As its designer set it (BookletLooks): drawn from a direction they
	## chose, zoomed in or out on what it adds, larger or smaller on the
	## page, at the top of a new page ("new") or on one alone ("alone").
	var fixed: bool = false
	var zoom: float = 1.0
	var size: float = 1.0
	var page_break: String = ""
	## The step's look's name (BookletLooks.key), "" for a worked-out step.
	var look: String = ""
	## Placed by hand (BookletLooks "place"): item -> [x, y, w, h] in page
	## mm; the words and pictures its designer put on its page, and the
	## arrows they drew on it; all of them as they were placed in [member
	## room], the step's room then, and once laid out, in its room now.
	var place: Dictionary = {}
	var notes: Array = []
	var drawn_arrows: Array = []
	var room: Rect2 = Rect2()
	## Its designer took the turn sign off it (BookletLooks "sign").
	var sign_off: bool = false
	## Its picture drawn with nothing behind the model: its page was laid
	## out by hand, where things may sit in the picture's box. A picture is
	## otherwise drawn on the page's colour, which is a smaller file.
	var clear: bool = false

	## Laid out: the room the page gives it (its panel), the picture's
	## rect, the part of it the model is drawn in, and how big.
	var page: int = 0
	var panel: Rect2 = Rect2()
	var rect: Rect2 = Rect2()
	var free: Rect2 = Rect2()
	var scale: float = 0.0
	var parts_rect: Rect2 = Rect2()
	## How wide its parts box may be before a row wraps.
	var parts_width: float = 0.0
	var number_at: Vector2 = Vector2()
	var number_size: float = NUMBER
	## Where the parts it adds are drawn on the page, in mm, cut to its
	## picture (BookletMaker._adds); empty when none shows.
	var adds: Rect2 = Rect2()

	## Drawn: the picture (a data URI) and the arrows, in page mm: from a
	## callout to where it goes, and red ones onto small new parts.
	var image: String = ""
	var arrows: Array = []
	var pointers: Array = []
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
	## The hidden colours it is built with: a chip in its corner each.
	var marks: Array = []
	## Built on pages of its own whatever its size: its designer turned the
	## callout box off (BookletLooks.callout_on).
	var own_pages: bool = false

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
	## Steps pages: what was found on top of something else and where it
	## went ([method _settle]): [{step, item, on_step, on_item, moved}].
	var overlaps: Array = []


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
	## The pictures a designer put on its pages: name -> data URI.
	var images: Dictionary = {}


# -- layout ----------------------------------------------------------------


## The content area of a page, inside the margins and above the foot.
static func content() -> Rect2:
	return Rect2(Vector2(MARGIN, MARGIN),
		PAGE - Vector2(MARGIN * 2.0, MARGIN * 2.0 + FOOT - 3.0))


## Lay steps out on pages. [param entries] are the main steps in order,
## each attach step carrying its callout. Returns the step pages,
## callout pages among them, numbered from [param first_page].
## [param per_page] is the most steps a page may have (1, 2 or 4; 0 as many
## as fit), and a step's [member Entry.page_break] starts a page or has one
## alone.
static func lay_out(entries: Array[Entry], first_page: int = 2,
		per_page: int = 0) -> Array[Page]:
	var layout := Layout.new(entries, first_page, per_page)
	var pages: Array[Page] = []
	while not layout.done():
		pages.append_array(layout.next())
	return pages


## [method lay_out] a page at a time, for a booklet drawn as it is laid
## out, its first pages read while the rest are drawn (BookletMaker): the
## next page, and the callout pages before it, need only the steps from
## [member at] to [method reach] seen and sized.
class Layout extends RefCounted:
	var entries: Array[Entry]
	var first_page: int
	## The most steps a page may have.
	var most: int
	## The first step not on a page yet.
	var at: int = 0
	## Pages laid out so far.
	var made: int = 0
	var _section: String = ""
	var _total: int

	func _init(steps: Array[Entry], first: int = 2, per_page: int = 0) -> void:
		entries = steps
		first_page = first
		most = per_page if per_page in [1, 2, 4] else 4
		_total = maxi(1, entries.size())

	func done() -> bool:
		return at >= entries.size()

	## The steps the next page may take are those before this.
	func reach() -> int:
		return mini(at + most, entries.size())

	## The next page, after the pages of its step's callout when it has any.
	func next() -> Array[Page]:
		var pages: Array[Page] = []
		var entry: Entry = entries[at]
		var banner: String = ""
		if entry.section != _section:
			_section = entry.section
			banner = _section
		if entry.callout != null:
			entry.callout.inline = Booklet._fits_inline(entry.callout) and not entry.callout.own_pages
			if not entry.callout.inline:
				for page: Page in Booklet._callout_pages(entry.callout,
						float(at) / float(_total)):
					pages.append(page)
		var area: Rect2 = Booklet.content()
		if not banner.is_empty():
			area = Rect2(area.position + Vector2(0.0, BANNER),
				area.size - Vector2(0.0, BANNER))
		var run: Array[Entry] = []
		for index: int in range(at, mini(at + most, entries.size())):
			var next_one: Entry = entries[index]
			if index > at and (next_one.section != _section or next_one.callout != null
					or not next_one.page_break.is_empty() or entries[index - 1].page_break == "alone"):
				break
			run.append(next_one)
		var page := Booklet._best_page(run, area, false, most)
		page.banner = banner
		Booklet._settle(page)
		page.progress = float(at + page.entries.size()) / float(_total)
		pages.append(page)
		at += page.entries.size()
		for laid: Page in pages:
			laid.number = first_page + made
			made += 1
			for one: Entry in laid.entries:
				one.page = laid.number
		return pages


## The fullest page the run can make that is still big enough to read.
static func _best_page(run: Array[Entry], area: Rect2, framed: bool,
		most: int = 4) -> Page:
	for count: int in [4, 2, 1]:
		if count > run.size() or count > most:
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
	var scale: float = INF
	for index: int in group.size():
		var entry: Entry = group[index]
		scale = minf(scale, minf(_most(entry), _fit(entry, panels[index])[0] / _grown(entry)))
	return scale


## The largest [param entry] may be drawn, in mm an LDU: ten millimetres a
## stud, or, for a step its designer gave a page alone, as large as fills
## it up to three times that. A small model alone at ten millimetres a stud
## sat small in the middle of its page.
static func _most(entry: Entry) -> float:
	return MOST_SCALE * (ALONE_MOST if entry.page_break == "alone" else 1.0)


## How much larger than the page's other steps its designer drew [param
## entry]: its size, and its zoom, which frames a smaller part of the model
## in the same room (BookletMaker._zoomed).
static func _grown(entry: Entry) -> float:
	return maxf(entry.size, 0.1) * maxf(entry.zoom, 0.1)


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
	return [minf(best_scale, _most(entry) * _grown(entry)), best]


static func _place(entry: Entry, panel: Rect2, scale: float) -> void:
	entry.panel = panel
	entry.rect = panel
	# Larger or smaller than the page's other steps where its designer said.
	entry.scale = minf(scale * _grown(entry), _fit(entry, panel)[0]) \
		if not is_equal_approx(_grown(entry), 1.0) else scale
	entry.number_size = _number_size(entry, panel)
	entry.parts_width = _parts_width(entry, panel)
	var parts: Vector2 = _parts_size(entry.lots, entry.parts_width)
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
	entry.free = Rect2(free.get_center() - need.min(free.size) * 0.5,
		need.min(free.size))
	_by_hand(entry)


## What its designer placed by hand, where they placed it (BookletLooks
## "place"), within the page: the picture filling the rect it was given,
## the parts box as wide as it was made, the number under it unless it was
## placed itself, the callout box's pictures fitted to its new size.
static func _by_hand(entry: Entry) -> void:
	# Placed in a room the step no longer has (a step edit or a page break
	# moved it): what was placed goes with the step, into its room now.
	if entry.room.size.x > 0.0 and not BookletLooks.same_room(entry.room, entry.panel):
		var moved: Dictionary = BookletLooks.rebased({"place": entry.place, "notes": entry.notes,
			"arrows": entry.drawn_arrows, "panel": BookletLooks.said_rect(entry.room)}, entry.panel)
		entry.place = moved.get("place", {})
		entry.notes = moved.get("notes", [])
		entry.drawn_arrows = moved.get("arrows", [])
		entry.room = entry.panel
	if entry.place.is_empty():
		return
	if entry.place.has("picture"):
		var at: Rect2 = _on_page(BookletLooks.rect_of(entry.place["picture"]), Vector2(8, 8))
		entry.rect = at
		var size: Vector2 = entry.subject.size.max(Vector2(1.0, 1.0))
		entry.scale = minf(at.size.x * 0.94 / size.x, at.size.y * 0.94 / size.y)
		entry.free = at
	if entry.place.has("parts") and not entry.lots.is_empty():
		var at: Rect2 = BookletLooks.rect_of(entry.place["parts"])
		entry.parts_width = maxf(at.size.x, 12.0)
		var parts: Vector2 = _parts_size(entry.lots, entry.parts_width)
		# As wide as it was made, and wider where a part needs it.
		parts.x = maxf(parts.x, entry.parts_width)
		entry.parts_rect = _on_page(Rect2(at.position, parts), parts)
		entry.number_at = entry.parts_rect.position + Vector2(0.4, parts.y + 1.6)
	if entry.place.has("number"):
		var at: Rect2 = BookletLooks.rect_of(entry.place["number"])
		var size := Vector2(entry.number_size * 0.62 * str(entry.number).length() + 1.0,
			entry.number_size)
		entry.number_at = _on_page(Rect2(at.position, size), size).position
	if entry.callout != null and entry.place.has("callout"):
		entry.callout.box = _on_page(BookletLooks.rect_of(entry.place["callout"]),
			Vector2(12, 12))
		_cells(entry.callout)


## Nothing on a page of steps drawn over anything else. A page laid out by
## the booklet alone has nothing on top of anything; a page laid out by
## hand can, when a step's page changes round what was placed on it, or an
## item is dropped on another. Each thing keeps its place in turn — what its
## designer placed, step by step, then what the booklet laid out, then words
## and pictures — and one that would land on a thing already kept goes to
## the nearest free room of its size on the page, or, for a picture, a
## callout or a picture of the designer's, smaller (down to half), and is
## said in [member Page.overlaps], for the page editor and a session to say.
## One with no room anywhere stays, and is said as not moved.
static func _settle(page: Page) -> void:
	page.overlaps.clear()
	var by_hand: bool = page.entries.any(func(entry: Entry) -> bool:
		return not entry.place.is_empty() or not entry.notes.is_empty() \
			or not entry.drawn_arrows.is_empty())
	for entry: Entry in page.entries:
		entry.clear = by_hand
	var kept: Array = []
	for thing: Dictionary in things_on(page):
		var under: Dictionary = _under(thing["rect"], kept)
		if under.is_empty():
			kept.append(thing)
			continue
		var spot: Array = _free_spot(thing["rect"], kept, _room_of(page),
			str(thing["kind"]) in ["picture", "callout", "image"])
		var said: Dictionary = {"step": (thing["entry"] as Entry).number, "item": thing["kind"],
			"on_step": (under["entry"] as Entry).number, "on_item": under["kind"],
			"moved": not spot.is_empty()}
		if thing.has("index"):
			said["index"] = thing["index"]
		if under.has("index"):
			said["on_index"] = under["index"]
		page.overlaps.append(said)
		if not spot.is_empty():
			_move_thing(thing, spot[0], float(spot[1]))
			thing["rect"] = spot[0]
		kept.append(thing)


## The part of [param page] things may be moved into: inside its margins,
## under its banner; inside the frame of a callout's own page.
static func _room_of(page: Page) -> Rect2:
	if page.kind == "callout":
		return page.frame.grow(-2.0)
	var area: Rect2 = content()
	if not page.banner.is_empty():
		area = Rect2(area.position + Vector2(0.0, BANNER), area.size - Vector2(0.0, BANNER))
	return area


## Two things overlap where they share more than this, in mm, both ways.
const OVERLAP := 0.6


## What [method _settle] found on [param page], as a person reads it: "step
## 6's picture was on step 5's picture: moved off it", or "".
static func overlaps_said(page: Page) -> String:
	var said := PackedStringArray()
	for one: Dictionary in page.overlaps:
		said.append("step %d's %s was on step %d's %s: %s" % [int(one["step"]),
			_thing_word(str(one["item"])), int(one["on_step"]), _thing_word(str(one["on_item"])),
			"moved off it" if bool(one["moved"]) else "there is no room on the page to move it"])
	return "; ".join(said)


static func _thing_word(kind: String) -> String:
	return {"parts": "parts list", "text": "words", "image": "added picture"}.get(kind, kind)


## What is on a page of steps, each a box in page mm, in the order they
## keep their place ([method _settle]): [{entry, kind, rect, index (a
## note's)}]. A picture is the model as drawn in it, not its box; a parts
## box carries its number (and turn sign) under it unless the number was
## placed on its own.
static func things_on(page: Page) -> Array:
	var placed: Array = []
	var laid: Array = []
	var notes: Array = []
	for entry: Entry in page.entries:
		var own: Array = []
		own.append({"kind": "picture", "rect": ink_of(entry), "hand": entry.place.has("picture")})
		var header: Rect2 = number_rect(entry)
		if entry.turned:
			header = header.merge(sign_rect(entry))
		if entry.lots.is_empty():
			own.append({"kind": "number", "rect": header, "hand": entry.place.has("number")})
		elif entry.place.has("number"):
			own.append({"kind": "parts", "rect": entry.parts_rect, "hand": entry.place.has("parts")})
			own.append({"kind": "number", "rect": header, "hand": true})
		else:
			own.append({"kind": "parts", "rect": entry.parts_rect.merge(header),
				"hand": entry.place.has("parts")})
		if entry.callout != null:
			own.append({"kind": "callout", "rect": entry.callout.box,
				"hand": entry.place.has("callout")})
		for thing: Dictionary in own:
			thing["entry"] = entry
			(placed if bool(thing["hand"]) else laid).append(thing)
		for at: int in entry.notes.size():
			var note: Variant = entry.notes[at]
			if note is Dictionary and ((note as Dictionary).has("text") or (note as Dictionary).has("image")):
				notes.append({"entry": entry, "kind": "text" if (note as Dictionary).has("text") else "image",
					"rect": BookletLooks.rect_of(note.get("at", [])), "index": at})
	return placed + laid + notes


## The model as drawn in [param entry]'s picture, on the page.
static func ink_of(entry: Entry) -> Rect2:
	var need: Vector2 = entry.subject.size * entry.scale
	return Rect2(entry.free.get_center() - need * 0.5, need)


## The step's number on the page.
static func number_rect(entry: Entry) -> Rect2:
	return Rect2(entry.number_at, Vector2(entry.number_size * 0.62 * str(entry.number).length() + 1.0,
		entry.number_size))


## The turn sign's square: under the step's number, as a LEGO booklet puts
## it, as wide as the number is high and a quarter more.
static func sign_rect(entry: Entry) -> Rect2:
	var size: float = entry.number_size * SIGN
	return Rect2(entry.number_at + Vector2(0.0, entry.number_size + SIGN_GAP), Vector2(size, size))


## The turn sign's size against the step number's height, and the gap above it.
const SIGN := 1.25
const SIGN_GAP := 2.0


## The first of [param kept] that [param rect] overlaps, or {}.
static func _under(rect: Rect2, kept: Array) -> Dictionary:
	for thing: Dictionary in kept:
		var shared: Rect2 = rect.intersection(thing["rect"])
		if shared.size.x > OVERLAP and shared.size.y > OVERLAP:
			return thing
	return {}


## The nearest room on the page, on a 2 mm grid from where [param rect] was,
## that overlaps none of [param kept]: [rect, scale], or [].
static func _free_spot(rect: Rect2, kept: Array, area: Rect2, can_shrink: bool) -> Array:
	for scale: float in ([1.0, 0.85, 0.7, 0.55] if can_shrink else [1.0]):
		var size: Vector2 = rect.size * scale
		if size.x > area.size.x or size.y > area.size.y:
			continue
		var best: Rect2 = Rect2()
		var nearest: float = INF
		var x: float = area.position.x + fposmod(rect.position.x - area.position.x, 2.0)
		while x + size.x <= area.end.x + 0.01:
			var y: float = area.position.y + fposmod(rect.position.y - area.position.y, 2.0)
			while y + size.y <= area.end.y + 0.01:
				var at := Rect2(Vector2(x, y), size)
				var away: float = at.get_center().distance_squared_to(rect.get_center())
				if away < nearest and _under(at, kept).is_empty():
					best = at
					nearest = away
				y += 2.0
			x += 2.0
		if nearest < INF:
			return [best, scale]
	return []


## [param thing] put at [param to], [param scale] the size it was.
static func _move_thing(thing: Dictionary, to: Rect2, scale: float) -> void:
	var entry: Entry = thing["entry"]
	var was: Rect2 = thing["rect"]
	var by: Vector2 = to.position - was.position
	match str(thing["kind"]):
		"picture":
			entry.rect.position += to.get_center() - was.get_center()
			entry.free = Rect2(to.get_center() - entry.free.size * scale * 0.5, entry.free.size * scale)
			entry.scale *= scale
		"parts":
			entry.parts_rect.position += by
			if not entry.place.has("number"):
				entry.number_at += by
		"number":
			entry.number_at += by
		"callout":
			entry.callout.box = Rect2(entry.callout.box.position + by, entry.callout.box.size * scale)
			_cells(entry.callout)
		"text", "image":
			# A copy: the notes are the look's own until here.
			entry.notes = entry.notes.duplicate(true)
			entry.notes[int(thing["index"])]["at"] = BookletLooks.said_rect(to)


## Where an item dragged on the page comes to rest: [param at] moved, or
## with [param resize] its far corner moved, onto the nearest of the page's
## margins and middle and the edges and middles of [param others] (Rect2s
## in page mm) within SNAP mm, each way on its own. {"rect": Rect2, "lines":
## [["x" or "y", mm]] for the guides it snapped to}.
static func snapped_to(at: Rect2, others: Array, resize: bool = false) -> Dictionary:
	var area: Rect2 = content()
	var xs: Array = [area.position.x, area.end.x, PAGE.x * 0.5]
	var ys: Array = [area.position.y, area.end.y, PAGE.y * 0.5]
	for other: Variant in others:
		var rect: Rect2 = other
		xs.append_array([rect.position.x, rect.end.x, rect.get_center().x])
		ys.append_array([rect.position.y, rect.end.y, rect.get_center().y])
	var out: Rect2 = at
	var lines: Array = []
	var by_x: Array = _nearest([at.end.x] if resize
		else [at.position.x, at.get_center().x, at.end.x], xs)
	if not by_x.is_empty():
		if resize:
			out.size.x += float(by_x[0])
		else:
			out.position.x += float(by_x[0])
		lines.append(["x", by_x[1]])
	var by_y: Array = _nearest([at.end.y] if resize
		else [at.position.y, at.get_center().y, at.end.y], ys)
	if not by_y.is_empty():
		if resize:
			out.size.y += float(by_y[0])
		else:
			out.position.y += float(by_y[0])
		lines.append(["y", by_y[1]])
	return {"rect": out, "lines": lines}


## The nearest of [param targets] to any of [param edges] within SNAP:
## [how far to move, the target], or [].
static func _nearest(edges: Array, targets: Array) -> Array:
	var best: Array = []
	for edge: Variant in edges:
		for target: Variant in targets:
			var gap: float = float(target) - float(edge)
			if absf(gap) <= SNAP and (best.is_empty() or absf(gap) < absf(float(best[0]))):
				best = [gap, float(target)]
	return best


## [param at] kept on the page, no smaller than [param least].
static func _on_page(at: Rect2, least: Vector2) -> Rect2:
	var size: Vector2 = at.size.max(least).min(PAGE)
	var position: Vector2 = at.position.clamp(Vector2.ZERO, PAGE - size)
	return Rect2(position, size)


static func _number_size(entry: Entry, panel: Rect2) -> float:
	if entry.in_callout:
		return NUMBER_SMALL
	return NUMBER if panel.size.y > 120.0 else NUMBER_SMALL


## The parts box and the number under it, as one block: [width, height].
static func _header(entry: Entry, panel: Rect2) -> Vector2:
	var parts: Vector2 = _parts_size(entry.lots, _parts_width(entry, panel))
	var number: float = _number_size(entry, panel)
	var width: float = maxf(parts.x, number * 0.62 * str(entry.number).length() + 1.0)
	var height: float = parts.y + (1.6 if not entry.lots.is_empty() else 0.0) + number
	if entry.turned:
		# The turn sign under the number, as a LEGO booklet puts it.
		width = maxf(width, number * SIGN)
		height += number * SIGN + SIGN_GAP
	return Vector2(width, height)


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
		_settle(page)
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
	out.append(head(document))
	for page: Page in document.pages:
		out.append(page_html(page, document))
	out.append(TAIL)
	return "\n".join(out)


## How the file ends.
const TAIL := "</main>\n</html>\n"


## The file up to its first page: its title, its stylesheet, the bar with
## Print. With [param parts] the parts' pictures' rules in the stylesheet;
## without, they come in [method parts_style] after the first pages, which
## a booklet being read as it is drawn shows first.
static func head(document: Document, parts: bool = true) -> String:
	return _head(document, parts)


## The parts' pictures' rules in a stylesheet of their own: see [method head].
static func parts_style(document: Document) -> String:
	return "<style>\n%s\n</style>" % "\n".join(_part_rules(document))


## One page of the file.
static func page_html(page: Page, document: Document) -> String:
	return _page(page, document)


static func _part_rules(document: Document) -> PackedStringArray:
	var parts := PackedStringArray()
	for key: String in document.parts:
		parts.append(".%s{background-image:url(%s)}" % [_class_of(key, document),
			document.parts[key]])
	return parts


static func _head(document: Document, with_parts: bool = true) -> String:
	var parts: PackedStringArray = _part_rules(document) if with_parts else PackedStringArray()
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
.tx { white-space: pre-wrap; line-height: 1.2; overflow-wrap: break-word; }
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
	var numbers := PackedStringArray()
	for entry: Entry in page.entries:
		numbers.append(str(entry.number))
	out.append("<section class=\"page %s\" id=\"page-%d\"%s>" % [page.kind, page.number,
		(" data-steps=\"%s\"" % " ".join(numbers)) if not numbers.is_empty() else ""])
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
			var in_banner: Array = []
			if not page.banner.is_empty():
				var strip := Rect2(Vector2(MARGIN, MARGIN), Vector2(content().size.x, BANNER - 3.0))
				out.append(_div(strip, "ban"))
				var said: String = page.banner.capitalize() if page.banner.begins_with("part ") \
					else page.banner
				out.append(_text(strip.position + Vector2(3.0, 2.0), 4.2, _escape(said), "n",
					"color:#fff"))
				# The section's hidden colour, where the section starts.
				var starting: Array = page.entries[0].marks if not page.entries.is_empty() else []
				for mark: Dictionary in starting:
					if said in (mark.get("sections", [str(mark["label"])]) as Array):
						in_banner.append(mark)
						out.append(_text(Vector2(strip.end.x - 64.0, strip.position.y + 2.4), 3.0,
							_mark_words(mark, false), "q mk",
							"color:#fff;width:calc(61 * var(--mm));text-align:right"))
			for entry: Entry in page.entries:
				_entry(entry, document, out, svg, in_banner)
			# What its designer put on the page, over the rest: pictures, then words,
			# and the arrows they drew over all.
			for entry: Entry in page.entries:
				_notes(entry, document, out)
			for entry: Entry in page.entries:
				for arrow: Variant in entry.drawn_arrows:
					if arrow is Dictionary:
						svg.append(drawn_arrow(arrow))
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
		svg: PackedStringArray, in_banner: Array = []) -> void:
	if not entry.image.is_empty():
		_image(out, entry.image, entry.rect, "Step %d" % entry.number)
	# A hidden colour starting here: under the number and its turn sign, one
	# line a colour.
	var line: float = (sign_rect(entry).end.y if entry.turned
		else entry.number_at.y + entry.number_size) + 1.2
	for mark: Dictionary in entry.marks:
		if mark in in_banner:
			continue
		out.append(_text(Vector2(entry.number_at.x, line), 2.6, _mark_words(mark), "q mk"))
		line += 3.4
	if not entry.lots.is_empty():
		out.append(_div(entry.parts_rect, "box"))
		var y: float = entry.parts_rect.position.y + PAD
		for row: Array in _rows(entry.lots, entry.parts_width):
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
		svg.append(_turn_sign(sign_rect(entry)))
	for pointer: Array in entry.pointers:
		svg.append(_arrow(pointer[0], pointer[1], "#d01012", 0.9, 2.6))
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
		var corner: float = callout.box.end.y - PAD - 2.8
		for mark: Dictionary in callout.marks:
			out.append(_text(Vector2(callout.box.position.x + PAD, corner), 2.4,
				_mark_words(mark), "q mk"))
			corner -= 3.2
		for arrow: Array in entry.arrows:
			svg.append(_arrow(arrow[-2], arrow[-1], "#15191e", 0.45, 1.4,
				arrow.slice(0, arrow.size() - 1)))


## The words and pictures a designer put on [param entry]'s page
## (BookletLooks "notes"), where they put them.
static func _notes(entry: Entry, document: Document, out: PackedStringArray) -> void:
	for kind: String in ["image", "text"]:
		for note: Variant in entry.notes:
			if not (note is Dictionary) or not (note as Dictionary).has(kind):
				continue
			var at: Rect2 = BookletLooks.rect_of(note.get("at", []))
			if kind == "image":
				var source: String = str(document.images.get(str(note["image"]), ""))
				if not source.is_empty():
					_image(out, source, at, "A picture of the designer's")
				continue
			var size: float = clampf(float(note.get("size", 4.0)), 1.5, 40.0)
			var words: String = _escape(str(note["text"])).replace("\n", "<br>")
			out.append("<div class=\"t tx\" style=\"--x:%s;--y:%s;--s:%s;width:calc(%s * var(--mm));min-height:calc(%s * var(--mm))\">%s</div>"
				% [_n(at.position.x), _n(at.position.y), _n(size), _n(at.size.x), _n(at.size.y),
					words])


## A hidden colour's chip and words: "■ Tower: Bright Green"; in its own
## section's banner, "■ inside: Bright Green".
static func _mark_words(mark: Dictionary, with_label: bool = true) -> String:
	return "<i class=\"chip\" style=\"background:%s\"></i>%s: %s" % [
		str(mark.get("rgb", "#888")),
		_escape(str(mark.get("label", ""))) if with_label else "inside",
		_escape(str(mark.get("name", "")))]


static func _cover(page: Page, document: Document, out: PackedStringArray) -> void:
	out.append(_div(Rect2(Vector2.ZERO, Vector2(PAGE.x, 30.0)), "", "background:#23527c"))
	out.append(_div(Rect2(Vector2(MARGIN, 7.0), Vector2(44.0, 16.0)), "",
		"background:#d0312d;border-radius:calc(2 * var(--mm))"))
	out.append(_text(Vector2(MARGIN + 3.6, 12.4), 5.0, "BRICKWORKS", "n", "color:#fff"))
	# As big as fits on one line: the example car is "Example Car for
	# Demonstration of LDRAW Library", which at 10 mm ran off the page.
	var room: float = PAGE.x - MARGIN * 2.0 - 52.0
	var size: float = clampf(room / (0.58 * maxf(1.0, float(document.title.length()))), 4.0, 10.0)
	out.append(_text(Vector2(MARGIN + 52.0, 15.0 - size * 0.5), size, _escape(document.title),
		"n", "color:#fff"))
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


## The path of an arrow from a callout box to [param target], as a
## booklet draws it: out of the box's nearest side at a right angle, and
## round one corner to the target — down and across, or across and down
## — rather than a diagonal across the picture. [start, corner, target],
## or [start, target] when it is straight; empty when the target is in
## the box or touching it.
static func elbow(box: Rect2, target: Vector2) -> Array:
	const INSET := 3.0
	if box.grow(2.0).has_point(target):
		return []
	var inside := Vector2(
		clampf(target.x, box.position.x + INSET, box.end.x - INSET),
		clampf(target.y, box.position.y + INSET, box.end.y - INSET))
	var start: Vector2
	var corner: Vector2
	if target.y > box.end.y and target.x >= box.position.x - 20.0:
		start = Vector2(inside.x, box.end.y)
		corner = Vector2(start.x, target.y)
	elif target.x < box.position.x:
		start = Vector2(box.position.x, inside.y)
		corner = Vector2(target.x, start.y)
	elif target.x > box.end.x:
		start = Vector2(box.end.x, inside.y)
		corner = Vector2(target.x, start.y)
	else:
		start = Vector2(inside.x, box.position.y)
		corner = Vector2(start.x, target.y)
	if corner.distance_to(target) < 2.0 or corner.distance_to(start) < 2.0:
		return [start, target]
	return [start, corner, target]


## A line with a head: from the callout box to where the assembly goes
## (through [param bends], when it turns a corner), or a red one onto a
## small new part.
static func _arrow(from: Vector2, to: Vector2, colour: String = "#15191e",
		width: float = 0.45, head: float = 1.4, bends: Array = []) -> String:
	var way: Vector2 = (to - from).normalized()
	if way == Vector2.ZERO:
		return ""
	var side := Vector2(-way.y, way.x)
	var base: Vector2 = to - way * head * 2.3
	var outline: String = " stroke=\"#fff\" stroke-width=\".35\" paint-order=\"stroke\""
	var points := PackedStringArray()
	for bend: Vector2 in bends.slice(0, bends.size() - 1) if bends.size() > 1 else []:
		points.append("%s,%s" % [_n(bend.x), _n(bend.y)])
	points.append("%s,%s" % [_n(from.x), _n(from.y)])
	points.append("%s,%s" % [_n(base.x), _n(base.y)])
	var line: String = " ".join(points)
	# Under the line a white one a little wider: a black arrow across a
	# black tower was no arrow at all.
	return ("<polyline points=\"%s\" fill=\"none\" stroke=\"#fff\" stroke-width=\"%s\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
		% [line, _n(width + 0.7)]
		+ "<polyline points=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\" stroke-linejoin=\"round\"/>"
		% [line, colour, _n(width)]
		+ "<path d=\"M%s %s L%s %s L%s %s Z\" fill=\"%s\"%s/>" % [
			_n(to.x), _n(to.y), _n(base.x + side.x * head), _n(base.y + side.y * head),
			_n(base.x - side.x * head), _n(base.y - side.y * head), colour, outline])


## An arrow its designer drew (BookletLooks "arrows"), drawn as the
## booklet's own are: a line with a white edge under it, so it reads across
## a model of its colour, and a head; through its bend, when it has one, as
## a curve, for a part turned or swung in. The head is as big for its width
## as the booklet's red pointer's.
static func drawn_arrow(arrow: Dictionary) -> String:
	var points: Array = BookletLooks.arrow_points(arrow)
	if points.is_empty():
		return ""
	var from: Vector2 = points[0]
	var to: Vector2 = points[1]
	var width: float = BookletLooks.arrow_width(float(arrow.get("width", 0.9)))
	var colour: String = str(BookletLooks.ARROW_COLOURS.get(str(arrow.get("colour", "red")),
		BookletLooks.ARROW_COLOURS["red"]))
	var head: float = width * 2.9
	# The curve through the bend at its middle: a quadratic whose control
	# point is the bend pushed out by as much again.
	var control: Vector2 = (points[2] as Vector2) * 2.0 - (from + to) * 0.5 \
		if points[2] != null else (from + to) * 0.5
	var way: Vector2 = (to - control).normalized()
	if way == Vector2.ZERO:
		return ""
	var side := Vector2(-way.y, way.x)
	var base: Vector2 = to - way * head * 2.3
	var line: String = "M%s %s Q%s %s %s %s" % [_n(from.x), _n(from.y), _n(control.x),
		_n(control.y), _n(base.x), _n(base.y)]
	return ("<path class=\"drawn-arrow\" d=\"%s\" fill=\"none\" stroke=\"#fff\" stroke-width=\"%s\" stroke-linecap=\"round\"/>"
		% [line, _n(width + 0.7)]
		+ "<path d=\"%s\" fill=\"none\" stroke=\"%s\" stroke-width=\"%s\"/>" % [line, colour, _n(width)]
		+ "<path d=\"M%s %s L%s %s L%s %s Z\" fill=\"%s\" stroke=\"#fff\" stroke-width=\".35\" paint-order=\"stroke\"/>"
		% [_n(to.x), _n(to.y), _n(base.x + side.x * head), _n(base.y + side.y * head),
			_n(base.x - side.x * head), _n(base.y - side.y * head), colour])


## Turn the model: the sign a LEGO booklet puts under the step's number
## where the model is turned round or over, a white rounded square with two
## rings round a middle, one upright and one flat, each with an arrowhead
## on it, the flat one over the upright where they cross.
static func _turn_sign(at: Rect2) -> String:
	var s: float = at.size.x
	var stroke: float = s * 0.055
	var out := PackedStringArray()
	out.append("<g class=\"turn-sign\">")
	out.append("<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" rx=\"%s\" fill=\"#fff\" stroke=\"#15191e\" stroke-width=\".35\"/>"
		% [_n(at.position.x), _n(at.position.y), _n(s), _n(at.size.y), _n(s * 0.16)])
	# The upright ring, from low on the right round under, up the left and
	# over the top to its head on the right, pointing down; then the flat
	# one, from low on the left round the back to its head at the front,
	# pointing left, on a white edge so it reads in front where they cross.
	# Angles clockwise from the right, as the page's y runs down.
	var heads := PackedStringArray()
	for ring: Array in [[Vector2(0.22, 0.36), 95.0, 415.0, false],
			[Vector2(0.37, 0.15), 150.0, 470.0, true]]:
		var drawn: Array = _ring_arrow(at.get_center(), (ring[0] as Vector2) * s, float(ring[1]),
			float(ring[2]), stroke, s * 0.15, bool(ring[3]))
		out.append(drawn[0])
		heads.append(drawn[1])
	# The heads over both rings.
	out.append("".join(heads))
	out.append("</g>")
	return "".join(out)


## Part of an ellipse round [param c] ([param radii]) from [param from] to
## [param to] degrees, clockwise, on a white edge when [param edged], and
## an arrowhead [param head] long at its end: [ring, head] as SVG.
static func _ring_arrow(c: Vector2, radii: Vector2, from: float, to: float, stroke: float,
		head: float, edged: bool) -> Array:
	var at := func(degrees: float) -> Vector2:
		return c + Vector2(cos(deg_to_rad(degrees)) * radii.x, sin(deg_to_rad(degrees)) * radii.y)
	var start: Vector2 = at.call(from)
	var end: Vector2 = at.call(to)
	var way: Vector2 = Vector2(-sin(deg_to_rad(to)) * radii.x, cos(deg_to_rad(to)) * radii.y).normalized()
	var arc: String = "M%s %s A%s %s 0 1 1 %s %s" % [_n3(start.x), _n3(start.y), _n3(radii.x),
		_n3(radii.y), _n3(end.x), _n3(end.y)]
	var out: String = ""
	if edged:
		out += "<path d=\"%s\" fill=\"none\" stroke=\"#fff\" stroke-width=\"%s\"/>" % [arc, _n3(stroke * 2.4)]
	out += "<path d=\"%s\" fill=\"none\" stroke=\"#15191e\" stroke-width=\"%s\"/>" % [arc, _n3(stroke)]
	var side := Vector2(-way.y, way.x)
	var tip: Vector2 = end + way * head * 0.7
	var base: Vector2 = end - way * head * 0.3
	return [out, "<path d=\"M%s %s L%s %s L%s %s Z\" fill=\"#15191e\" stroke=\"#fff\" stroke-width=\"%s\" paint-order=\"stroke\"/>" % [
		_n3(tip.x), _n3(tip.y), _n3(base.x + side.x * head * 0.5), _n3(base.y + side.y * head * 0.5),
		_n3(base.x - side.x * head * 0.5), _n3(base.y - side.y * head * 0.5), _n3(stroke * 0.8)]]


static func _n3(value: float) -> String:
	return String.num(value, 3)


static func _n(value: float) -> String:
	return String.num(value, 2)


## Text going into HTML. The part library has ampersands and quotes in
## its names — "Brick 1 x 4 with 4 Studs on Side & Groove" — and a name
## written straight into markup is a name that breaks the page.
static func _escape(raw: String) -> String:
	return (raw.replace("&", "&amp;").replace("<", "&lt;")
		.replace(">", "&gt;").replace("\"", "&quot;"))
