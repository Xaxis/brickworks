## ptreview C and D, static: Booklet.lay_out on steps made by hand. A locked
## page (Entry.lock, as BookletMaker sets it from "PAGE LOCK n") when the
## booklet's page setup changes and it is not frozen: do its items stay
## where they were, and does it keep its steps? Seconds; no app.
##
## C locks the page as the app does (ptfix): each item placed where it is
## (Booklet.held_places, what Shell.change_look "page_lock" writes, with the
## room it was placed in), then the margins changed. C0 is the same page
## locked with no places, as 8835f52aa locked it: its items moved.
##
##   godot --headless --path . --script src/dev/ptreview_layout_check.gd
extends SceneTree

var _failures: int = 0


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


static func _entries(count: int, side: float, lock_first: int, places: Array = []) -> Array[Booklet.Entry]:
	var out: Array[Booklet.Entry] = []
	for index: int in count:
		var entry := Booklet.Entry.new()
		entry.number = index + 1
		entry.subject = Rect2(0, 0, side, side * 0.8)
		# A list of parts, so its box and the number under it are on the page.
		var lot := Booklet.Lot.new()
		lot.key = "3001|4"
		lot.part_id = "3001"
		lot.count = 2
		lot.size = Vector2(12, 9)
		entry.lots.append(lot)
		out.append(entry)
	out[0].lock = lock_first
	# What a lock wrote: each step's place, in the room it had then.
	for pair: Array in places:
		var entry: Booklet.Entry = out[int(pair[0]) - 1]
		entry.place = (pair[1] as Dictionary).duplicate(true)
		entry.room = BookletLooks.rect_of(pair[2])
	return out


static func _first(side: float, lock_first: int, per_page: int, sheet: BookletSheet,
		places: Array = []) -> Booklet.Page:
	var pages: Array[Booklet.Page] = Booklet.lay_out(_entries(8, side, lock_first, places), 2, per_page,
		sheet)
	return pages[0]


static func _where(page: Booklet.Page) -> Array:
	return page.entries.map(func(entry: Booklet.Entry) -> Array:
		return [entry.number, Booklet.ink_of(entry), entry.parts_rect, entry.number_at])


## [[number, place, room]] as the lock writes them for [param page].
static func _held(page: Booklet.Page) -> Array:
	return Booklet.held_places(page).map(func(pair: Array) -> Array:
		var entry: Booklet.Entry = pair[0]
		return [entry.number, pair[1], BookletLooks.said_rect(entry.panel)])


static func _near(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for index: int in a.size():
		for field: int in range(1, 4):
			var one: Variant = a[index][field]
			var two: Variant = b[index][field]
			if one is Rect2 and ((one as Rect2).position.distance_to((two as Rect2).position) > 0.11
					or (one as Rect2).size.distance_to((two as Rect2).size) > 0.11):
				return false
			if one is Vector2 and (one as Vector2).distance_to(two as Vector2) > 0.11:
				return false
	return true


func _initialize() -> void:
	var usual := BookletSheet.new()
	var wide := BookletSheet.from({"margin": 30, "number": 20})
	# C0: locked with nothing placed, as 8835f52aa locked a page.
	var bare: Booklet.Page = _first(400.0, 2, 2, usual)
	var bare_after: Booklet.Page = _first(400.0, 2, 2, BookletSheet.from({"margin": 25}))
	print("  (C0, locked with nothing placed: 9 mm %s; 25 mm %s)" % [str(_where(bare)),
		str(_where(bare_after))])
	# C: a locked page of 2, locked as the app locks it, then margins 25 mm.
	var free: Booklet.Page = _first(400.0, 0, 2, usual)
	var places: Array = _held(free)
	var before: Booklet.Page = _first(400.0, 2, 2, usual, places)
	var after: Booklet.Page = _first(400.0, 2, 2, BookletSheet.from({"margin": 25}), places)
	_check("C: locking a page of 2 moves nothing on it (to 0.1 mm)\n        laid:   %s\n        locked: %s"
		% [str(_where(free)), str(_where(before))], _near(_where(free), _where(before)))
	_check("C: a locked page of 2 (%s), margins 9 -> 25: its items stay where they were\n        9 mm:  %s\n        25 mm: %s"
		% [str(before.entries.map(func(e: Booklet.Entry) -> int: return e.number)), str(_where(before)),
		str(_where(after))], _where(before) == _where(after))
	var numbers: Booklet.Page = _first(400.0, 2, 2, BookletSheet.from({"number": 20}), places)
	_check("C: ...and step numbers made 20: the pictures and parts lists stay, the numbers under them\n        %s"
		% str(_where(numbers)), _where(numbers).map(func(one: Array) -> Array: return [one[1], one[2]])
		== _where(before).map(func(one: Array) -> Array: return [one[1], one[2]]))
	# D: steps that fit four to a page at the booklet's own page and not at
	# margins of 30 and step numbers of 20.
	var side: float = -1.0
	for size: int in range(100, 4000, 20):
		if _first(float(size), 0, 4, usual).entries.size() == 4 \
				and _first(float(size), 0, 4, wide).entries.size() < 4:
			side = float(size)
			break
	if side < 0.0:
		_check("D: steps four fit on the usual page and not on the wide one", false)
	else:
		var locked: Booklet.Page = _first(side, 4, 4, usual)
		var locked_wide: Booklet.Page = _first(side, 4, 4, wide)
		_check("D: a locked page of 4 (steps %d LDU wide) holds %d at the usual page, %d with margins 30 and numbers 20"
			% [int(side), locked.entries.size(), locked_wide.entries.size()],
			locked.entries.size() == 4 and locked_wide.entries.size() == 4)
		# N3: a lock holds a count: one step of four per page grown too big
		# for four stays four, and a lock of 3 lays out three.
		var three: Booklet.Page = _first(side, 3, 1, wide)
		_check("D: a locked page of 3, at one step a page, holds 3 (holds %d)" % three.entries.size(),
			three.entries.size() == 3)
	print("ptreview_layout_check: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)
