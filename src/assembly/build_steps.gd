## A model's steps as pages to build from, with real bricks on a table:
## what the step player (BuildMode, src/ui/build_mode.gd) shows of each.
##
## Page 0 is the finished model, as a booklet's cover is; page n is
## Instructions step n. For each page it says what is on the baseplate,
## what is new (drawn in full colour and outlined), what was built before
## (drawn faded, BrickWorld.set_faded), the parts to pick up with how many
## of each in which colour, and which way to look.
##
## The steps are the timeline's (StepsBar.steps), worked out once when the
## model opened, so the player, the timeline and the booklet number them
## alike. A callout's steps are pages too: the world cannot build a window
## on the side, so its parts go up where they will stand, as on the
## timeline, and the page that puts it on outlines the whole of it.
##
## Nothing here draws; main.gd puts a page on screen. The probe is
## src/dev/build_steps_probe.gd.
class_name BuildSteps
extends RefCounted

## How much of a step's new parts must be seen from the front, at least,
## before the page is looked at from the back instead; and how much more
## of them the back must show. BookletMaker._choose_views's numbers, which
## it measures in pixels and this in rays, so a page turns where its
## booklet page does.
const TURN_BELOW := 0.4
const TURN_GAIN := 0.25
## The cells the view plane is cut into to find what is in front of a
## point, in LDU: two studs. A ray is tested against the boxes in its
## point's cell only, not against the model. At a stud and a half the
## castle's 2,438 boxes went into 120,000 cells and its first page took
## 60 ms to look at.
const CELL := 40.0
## A step's new parts smaller than this share of what is built so far,
## across, are framed close: a phone showing a whole castle for the sake
## of one tile shows the tile as a speck.
const CLOSE_BELOW := 0.2

var steps: Array[Instructions.Step] = []
## The baseplate's bricks: on screen from the first page, never faded.
var scenery: Dictionary = {}
var _library: PartLibrary
var _world: BrickWorld
## brick id -> the page it is added on.
var _rank: Dictionary = {}
## brick id -> its box in the world.
var _boxes: Dictionary = {}
## page -> the bricks it adds, and the bricks it outlines.
var _fresh: Array[Dictionary] = []
## page -> the box round everything on the baseplate by then.
var _built_box: Array[AABB] = []
## page -> {"from": Vector3, "box": AABB}, worked out when first asked.
var _views: Dictionary = {}
## direction -> {"turn": Basis, "cells": {Vector2i: PackedInt64Array}}
var _planes: Dictionary = {}
## brick id -> the lot key it is counted under (Inventory.key_of), and the
## lots by key.
var _lot_of: Dictionary = {}
var _lots: Dictionary = {}
## The bricks in the order the pages add them, as the timeline lays them
## out (StepsBar's order: each step's bricks in turn), and for each page
## how many of that order are on the baseplate by then: a page is a count
## of the order (BrickWorld.reveal_upto), not a set of the whole model.
var order := PackedInt64Array()
var _upto := PackedInt64Array()
## page -> the bricks it adds (by _rank), and how many bricks are on the
## baseplate by then, each once.
var _added: Array[PackedInt64Array] = []
var _standing := PackedInt64Array()


## The pages for the bricks in [param world], in the order of [param
## made] (StepsBar.steps, or Instructions.plan's).
static func of(world: BrickWorld, library: PartLibrary,
		made: Array[Instructions.Step], ground: Dictionary = {}) -> BuildSteps:
	var pages := BuildSteps.new()
	pages._world = world
	pages._library = library
	pages.steps = made
	pages.scenery = ground
	pages._read()
	return pages


func _read() -> void:
	var stock: Inventory = Inventory.of(_world, _library, scenery)
	for lot: Inventory.Lot in stock.lots:
		_lots["%s:%d" % [lot.part_id, lot.color_code]] = lot
	_fresh.append({})
	_built_box.append(AABB())
	_upto.append(0)
	_added.append(PackedInt64Array())
	_standing.append(0)
	var built := AABB()
	var any: bool = false
	for page: int in range(1, steps.size() + 1):
		var step: Instructions.Step = steps[page - 1]
		var fresh: Dictionary = {}
		var added := PackedInt64Array()
		order.append_array(step.brick_ids)
		_upto.append(order.size())
		for brick_id: int in step.brick_ids:
			if _rank.has(brick_id):
				continue
			_rank[brick_id] = page
			fresh[brick_id] = true
			added.append(brick_id)
			var brick: BrickWorld.Brick = _world.get_brick(brick_id)
			if brick == null:
				continue
			_lot_of[brick_id] = stock.key_of(brick)
			var box: AABB = _box_of(brick)
			_boxes[brick_id] = box
			built = box if not any else built.merge(box)
			any = true
		# Putting a finished sub-assembly on adds nothing new: it is the
		# whole of it, every copy, that the page points at.
		if step.attaches():
			for copy: PackedInt64Array in step.copies:
				for brick_id: int in copy:
					fresh[brick_id] = true
		_fresh.append(fresh)
		_built_box.append(built)
		_added.append(added)
		_standing.append(_standing[page - 1] + added.size())
	_built_box[0] = built


func _box_of(brick: BrickWorld.Brick) -> AABB:
	var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
	if mesh != null:
		return brick.transform * mesh.bounds
	return AABB(brick.transform.origin - Vector3(10, 10, 10), Vector3(20, 20, 20))


## The last page: one for each step, after the cover.
func last() -> int:
	return steps.size()


## The page as it can be shown: within the cover and the last step.
func clamped(page: int) -> int:
	return clampi(page, 0, last())


## The step a page shows, or null for the cover.
func step_of(page: int) -> Instructions.Step:
	return steps[page - 1] if page >= 1 and page <= steps.size() else null


## Everything on the baseplate at [param page]: the ground, and what is
## built by then. The cover is the whole model.
func shown(page: int) -> Dictionary:
	page = clamped(page)
	var out: Dictionary = scenery.duplicate()
	for brick_id: int in _rank:
		if page == 0 or int(_rank[brick_id]) <= page:
			out[brick_id] = true
	return out


## How much of [member order] is on the baseplate at [param page]: the
## whole of it on the cover.
func count(page: int) -> int:
	page = clamped(page)
	return order.size() if page == 0 else int(_upto[page])


## How many bricks are on the baseplate at [param page], the ground not
## counted: what shown(page) holds, without gathering it.
func standing(page: int) -> int:
	page = clamped(page)
	return _rank.size() if page == 0 else int(_standing[page])


## The bricks whose fading changes going from page [param from] to page
## [param to], each to whether it is faded there: id -> bool. Only the
## two pages' own parts and those of the pages between them, so the next
## page is the page before's parts faded and nothing else — not every
## brick in the model asked, as faded() asks.
func fading(from: int, to: int) -> Dictionary:
	from = clamped(from)
	to = clamped(to)
	var out: Dictionary = {}
	if from == to:
		return out
	var asked: Array = [_fresh[from], _fresh[to]]
	for page: int in range(mini(from, to), maxi(from, to) + 1):
		asked.append(_added[page])
	for some: Variant in asked:
		for brick_id: int in some:
			var there: bool = _is_faded(brick_id, to)
			if there != _is_faded(brick_id, from):
				out[brick_id] = there
	return out


## Whether a brick is drawn faded on [param page]: built on a page before
## it, and not one the page points at.
func _is_faded(brick_id: int, page: int) -> bool:
	return page > 0 and int(_rank.get(brick_id, page)) < page and not _fresh[page].has(brick_id)


## What [param page] adds: drawn in full colour and outlined.
func fresh(page: int) -> Dictionary:
	return _fresh[clamped(page)]


## What was built before [param page]: drawn faded. None on the cover.
func faded(page: int) -> Dictionary:
	page = clamped(page)
	var out: Dictionary = {}
	if page == 0:
		return out
	var fresh_now: Dictionary = _fresh[page]
	for brick_id: int in _rank:
		if int(_rank[brick_id]) < page and not fresh_now.has(brick_id):
			out[brick_id] = true
	return out


## The parts to pick up for [param page], as a booklet's callout lists
## them: one entry a part in a colour, the most of them first, each
## {"part", "colour", "count", "name", "colour_name"}. A hose laid in a bend
## is the one hose (Inventory.key_of). None on the cover. On a page that
## puts a finished sub-assembly on, the parts that go on beside it: the
## sub-assembly itself was picked up on its callout's pages.
func lots(page: int) -> Array[Dictionary]:
	page = clamped(page)
	var counts: Dictionary = {}
	var step: Instructions.Step = step_of(page)
	# An attach step carries the loose parts that go on beside the
	# sub-assembly, as an author's step does (Instructions.ATTACH_TAKES_PARTS).
	if step == null:
		return []
	for brick_id: int in step.brick_ids:
		if int(_rank.get(brick_id, -1)) != page:
			continue
		var key: String = str(_lot_of.get(brick_id, ""))
		if key.is_empty():
			continue
		counts[key] = int(counts.get(key, 0)) + 1
	var out: Array[Dictionary] = []
	for key: String in counts:
		var lot: Inventory.Lot = _lots.get(key)
		if lot == null:
			continue
		out.append({"part": lot.part_id, "colour": lot.color_code, "count": int(counts[key]),
			"name": lot.name, "colour_name": lot.color_name})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["count"]) != int(b["count"]):
			return int(a["count"]) > int(b["count"])
		if str(a["name"]) != str(b["name"]):
			return str(a["name"]) < str(b["name"])
		return str(a["colour_name"]) < str(b["colour_name"]))
	return out


## How many pieces [param page] adds, all told.
func pieces(page: int) -> int:
	var total: int = 0
	for lot: Dictionary in lots(page):
		total += int(lot["count"])
	return total


## "Step 3 of 24", as the timeline and the booklet number it; a callout's
## steps say which, "Step 12 of 40 · Window (2x), 1 of 3".
func caption(page: int) -> String:
	var step: Instructions.Step = step_of(page)
	if step == null:
		return "%d steps" % steps.size()
	return step.caption(steps[-1].number)


## What else a person building it needs told, or nothing.
func note(page: int) -> String:
	var step: Instructions.Step = step_of(page)
	if step == null:
		return ""
	var said := PackedStringArray()
	if step.attaches():
		said.append("Put %s on" % ("them" if step.times > 1 else "it"))
	elif step.in_callout() and step.callout_step == 1:
		said.append("Build %s on the side" % ("these %d" % step.times if step.times > 1 else "this"))
	if step.unsupported:
		# The alternative is a step that looks wrong to anyone following
		# it with real bricks in their hands.
		said.append("hold this one in place")
	return " · ".join(said)


## Which way to look at [param page] and what to frame: {"from": the
## direction from the model to the eye, "box": the box to fit}. From the
## front, as every booklet step is drawn (BookletStudio.FRONT), unless its
## designer turned it (BookletLooks.turn_at, as the booklet draws it), or
## the step's new parts are hidden from there and the back shows them, as
## BookletMaker turns a page round; framed on what is built so far, or
## close round the new parts when they are a speck of it.
##
## Each page is decided on its own, where the booklet stays turned while
## the back is the work: the player can open on any page (a person comes
## back to it), and a page's view must not hang on every page before it.
func view(page: int) -> Dictionary:
	page = clamped(page)
	if _views.has(page):
		return _views[page]
	var from: Vector3 = BookletStudio.FRONT
	var fresh_now: Dictionary = _fresh[page]
	# Turned where its designer turned it (a ROTSTEP, the timeline's Booklet
	# row), as the booklet draws the step.
	var step: Instructions.Step = step_of(page)
	var turn: Dictionary = BookletLooks.turn_at(_world, step.authored_in, step.authored_step) \
		if step != null and step.authored_step >= 0 else {}
	if not turn.is_empty():
		from = BookletLooks.direction(turn)
	elif page > 0 and not fresh_now.is_empty():
		var here: float = seen(page, BookletStudio.FRONT)
		if here < TURN_BELOW:
			var there: float = seen(page, BookletStudio.BACK)
			if there > here + TURN_GAIN:
				from = BookletStudio.BACK
	var box: AABB = _built_box[page]
	if page > 0 and not fresh_now.is_empty():
		var near := AABB()
		var any: bool = false
		for brick_id: int in fresh_now:
			if not _boxes.has(brick_id):
				continue
			var one: AABB = _boxes[brick_id]
			near = one if not any else near.merge(one)
			any = true
		var across: float = box.size.length()
		if any and across > 0.0 and near.size.length() < across * CLOSE_BELOW:
			# A box round the new parts a fifth of the model across,
			# kept within what is built, so what they go on is there too.
			var grow: float = maxf(across * CLOSE_BELOW - near.size.length(), 0.0) * 0.5
			var close: AABB = near.grow(grow).intersection(box)
			if close.size.length() > near.size.length():
				box = close
			else:
				box = near
	_views[page] = {"from": from, "box": box}
	return _views[page]


## The share of [param page]'s new parts that can be seen from [param
## from]: of a few points on each (the middle of its box and of its top,
## and four round the top), those with nothing built in front of them.
func seen(page: int, from: Vector3) -> float:
	page = clamped(page)
	var way: Vector3 = from.normalized()
	var plane: Dictionary = _plane_for(from)
	var turn: Basis = plane["turn"]
	var cells: Dictionary = plane["cells"]
	var looked: int = 0
	var clear: int = 0
	for brick_id: int in _fresh[page]:
		if not _boxes.has(brick_id):
			continue
		var box: AABB = _boxes[brick_id]
		var middle: Vector3 = box.get_center()
		var top: float = box.end.y
		var points: Array[Vector3] = [middle, Vector3(middle.x, top, middle.z)]
		for corner: Vector2 in [Vector2(0.25, 0.25), Vector2(0.75, 0.25),
				Vector2(0.25, 0.75), Vector2(0.75, 0.75)]:
			points.append(Vector3(box.position.x + box.size.x * corner.x, top,
				box.position.z + box.size.z * corner.y))
		for point: Vector3 in points:
			looked += 1
			if not _hidden(point, way, brick_id, page, turn, cells):
				clear += 1
	return float(clear) / float(looked) if looked > 0 else 1.0


## Whether something on the baseplate by [param page], other than [param
## own], is between [param point] and the eye.
func _hidden(point: Vector3, way: Vector3, own: int, page: int, turn: Basis,
		cells: Dictionary) -> bool:
	var cell := Vector2i(floori(point.dot(turn.x) / CELL), floori(point.dot(turn.y) / CELL))
	# Started a hair towards the eye, off the part's own surface.
	var start: Vector3 = point + way * 0.5
	for brick_id: int in cells.get(cell, PackedInt64Array()):
		if brick_id == own or int(_rank[brick_id]) > page:
			continue
		var box: AABB = _boxes[brick_id]
		if box.has_point(start):
			# Touching it, as a brick on another's studs is: what is in
			# front is the question, not what it sits in.
			continue
		if box.intersects_ray(start, way) != null:
			return true
	return false


## Each brick's box on the view plane from [param from], by the cells it
## covers. Made once for each way of looking.
func _plane_for(from: Vector3) -> Dictionary:
	if _planes.has(from):
		return _planes[from]
	var turn: Basis = BookletStudio.basis_for(from)
	var cells: Dictionary = {}
	# A box's shadow on the plane, from its middle and half its size: the
	# same rectangle as BookletStudio.extent's eight corners, for a
	# fraction of the work, which on the castle is most of a page's.
	var reach_x: Vector3 = turn.x.abs()
	var reach_y: Vector3 = turn.y.abs()
	for brick_id: int in _boxes:
		var box: AABB = _boxes[brick_id]
		var middle: Vector3 = box.get_center()
		var half: Vector3 = box.size * 0.5
		var at := Vector2(middle.dot(turn.x), middle.dot(turn.y))
		var spread := Vector2(half.dot(reach_x), half.dot(reach_y))
		var low := Vector2i(floori((at.x - spread.x) / CELL), floori((at.y - spread.y) / CELL))
		var high := Vector2i(floori((at.x + spread.x) / CELL), floori((at.y + spread.y) / CELL))
		for x: int in range(low.x, high.x + 1):
			for y: int in range(low.y, high.y + 1):
				var cell := Vector2i(x, y)
				# A packed array is a value: appended to as it is read out
				# of the dictionary, the copy took the id and the cell did
				# not, and every part was seen from everywhere.
				var held: PackedInt64Array = cells.get(cell, PackedInt64Array())
				held.append(brick_id)
				cells[cell] = held
	_planes[from] = {"turn": turn, "cells": cells}
	return _planes[from]


# -- where a person got to -------------------------------------------------
#
# The page a link was left on, kept on this device, so a phone that sleeps
# or a tab that is closed comes back where it was. In the browser's
# localStorage, under its own key per link: the viewer otherwise writes
# nothing at all (share_view.gd), and this is not the visitor's work or
# their layout, only their place in somebody else's. Off the web, for this
# run only: a desktop viewer writes nothing to disk.

const KEPT_AS := "brickworks.build."
static var _kept: Dictionary = {}


## Where [param link] was left: {"page": int, "building": bool, "version":
## int}, or empty for a link not built from here. Read at the edge and made
## precise: a value of the wrong shape is no value. A place kept before
## links had versions was kept on version 1, which every link then was.
static func recall(link: String) -> Dictionary:
	var raw: Variant = null
	if OS.has_feature("web"):
		var text: Variant = JavaScriptBridge.eval(
			"(function(){try{return localStorage.getItem(%s)||''}catch(e){return ''}})()"
			% JSON.stringify(KEPT_AS + link), true)
		if text is String and not (text as String).is_empty():
			raw = JSON.parse_string(text)
	else:
		raw = _kept.get(link)
	if not (raw is Dictionary):
		return {}
	var kept: Dictionary = raw
	if not (kept.get("page") is float or kept.get("page") is int):
		return {}
	var building: Variant = kept.get("building")
	var version: Variant = kept.get("version")
	return {"page": maxi(int(kept["page"]), 0), "building": building is bool and building,
		"version": maxi(int(version), 1) if (version is float or version is int) else 1}


## Keep [param page] as where [param link] is, on [param version] of it.
static func remember(link: String, page: int, building: bool, version: int = 1) -> void:
	var kept: Dictionary = {"page": page, "building": building, "version": maxi(version, 1)}
	if OS.has_feature("web"):
		JavaScriptBridge.eval(
			"(function(){try{localStorage.setItem(%s,%s)}catch(e){}})()"
			% [JSON.stringify(KEPT_AS + link), JSON.stringify(JSON.stringify(kept))], true)
	else:
		_kept[link] = kept


## Whether a place kept on one version of a link still holds on another:
## the first step that differs between version [param from] and version
## [param to], when [param page] is at it or past it; 0 when nothing up to
## [param page] changed, and the place holds. [param versions] are the
## link's as api/share.js answers them ({"n", "first_changed"}, worked out
## by api/_versions.js): the earliest first changed step of every version
## between the two. A version the answer does not reach is a change from
## step 1.
static func changed_since(versions: Array, from: int, to: int, page: int) -> int:
	if from == to or from < 1 or to < 1 or page < 1:
		return 0
	var first: int = 0
	for n: int in range(mini(from, to) + 1, maxi(from, to) + 1):
		var row: Dictionary = {}
		for one: Variant in versions:
			if one is Dictionary and int((one as Dictionary).get("n", 0)) == n:
				row = one
		if row.is_empty():
			first = 1
			break
		var changed: Variant = row.get("first_changed")
		if (changed is float or changed is int) and int(changed) >= 1 \
				and (first == 0 or int(changed) < first):
			first = int(changed)
	return first if first >= 1 and page >= first else 0
