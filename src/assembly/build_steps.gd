## A model's steps as pages to build from, with real bricks on a table:
## what the step player (BuildMode, src/ui/build_mode.gd) shows of each.
##
## Page 0 is the finished model, as a booklet's cover is; page n is
## Instructions step n. For each page it says what is on the baseplate,
## what is new (drawn in full colour and outlined), what was built before
## (drawn faded, BrickWorld.set_faded), the parts to pick up with how many
## of each in which colour, and which way to look.
##
## A page can also be put down a part at a time (BuildMode.by_part, as BUF3D
## does on a phone): its part k is the page's first k things on the
## baseplate, the k-th alone in full colour and outlined and everything
## else faded. The things are each part the page adds, in the order the step
## lists them, and first, on a page that puts a finished sub-assembly on,
## the whole of it. Every function here that takes a part takes 0 for the
## page whole, as it was.
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
## page -> [from, turn] as its booklet page turns the model, or [] for none
## ([method booklet_turn]).
var _turns: Dictionary = {}
## The model has turns of its designer's (BookletLooks.any_turn): a step is
## turned where they say and never turned over for its parts, as the
## booklet turns it.
var _own_turns: bool = false
## The booklet's maker, which says which way a step's parts go on
## ([method _booklet_maker]): a BookletMaker, reached through Later as the
## first screen reaches it; and the page that puts a callout on -> its
## stage ([method _callout_stage]).
var _maker: Node = null
var _callouts: Dictionary = {}
## Which pages the booklet turns over for their parts, worked out a little
## a frame ([method work_out_turns]): page -> true, turned over; every page
## asked so far; all of them; the job going, and told to stop; the page
## the player asked for while it went, asked next.
var _over: Dictionary = {}
var _asked: Dictionary = {}
var _overs_known: bool = false
var _working: bool = false
var _stopped: bool = false
var _wanted: int = 0

## [param page]'s turn over is known now ([method work_out_turns]): its
## view is the booklet's, where until now it was the right way up.
signal turned_over(page: int)
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
## A part at a time: page -> where each brick it adds stands in [member
## order], as _added lists them (a count of the order shows up to one);
## page -> the finished sub-assembly it puts on, every copy, or none; and
## brick id -> its place among the bricks its page adds.
var _added_at: Array[PackedInt64Array] = []
var _put_on: Array[Dictionary] = []
var _place: Dictionary = {}


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
	_own_turns = BookletLooks.any_turn(_world)
	var stock: Inventory = Inventory.of(_world, _library, scenery)
	for lot: Inventory.Lot in stock.lots:
		_lots["%s:%d" % [lot.part_id, lot.color_code]] = lot
	_fresh.append({})
	_built_box.append(AABB())
	_upto.append(0)
	_added.append(PackedInt64Array())
	_standing.append(0)
	_added_at.append(PackedInt64Array())
	_put_on.append({})
	var built := AABB()
	var any: bool = false
	for page: int in range(1, steps.size() + 1):
		var step: Instructions.Step = steps[page - 1]
		var fresh: Dictionary = {}
		var added := PackedInt64Array()
		var added_at := PackedInt64Array()
		var base: int = order.size()
		order.append_array(step.brick_ids)
		_upto.append(order.size())
		for n: int in step.brick_ids.size():
			var brick_id: int = step.brick_ids[n]
			if _rank.has(brick_id):
				continue
			_rank[brick_id] = page
			_place[brick_id] = added.size()
			fresh[brick_id] = true
			added.append(brick_id)
			added_at.append(base + n)
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
		var put_on: Dictionary = {}
		if step.attaches():
			for copy: PackedInt64Array in step.copies:
				for brick_id: int in copy:
					fresh[brick_id] = true
					if int(_rank.get(brick_id, page)) != page:
						put_on[brick_id] = true
		_fresh.append(fresh)
		_built_box.append(built)
		_added.append(added)
		_standing.append(_standing[page - 1] + added.size())
		_added_at.append(added_at)
		_put_on.append(put_on)
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


## Everything on the baseplate at [param page] (at its [param part], a
## part at a time): the ground, and what is built by then. The cover is the
## whole model.
func shown(page: int, part: int = 0) -> Dictionary:
	page = clamped(page)
	part = clamped_part(page, part)
	var down: int = _down(page, part)
	var out: Dictionary = scenery.duplicate()
	for brick_id: int in _rank:
		var rank: int = int(_rank[brick_id])
		if page == 0 or rank < page or (rank == page and int(_place[brick_id]) < down):
			out[brick_id] = true
	return out


## How much of [member order] is on the baseplate at [param page] (at its
## [param part]): the whole of it on the cover.
func count(page: int, part: int = 0) -> int:
	page = clamped(page)
	if page == 0:
		return order.size()
	part = clamped_part(page, part)
	var down: int = _down(page, part)
	if part == 0 or down >= _added[page].size():
		return int(_upto[page])
	return int(_upto[page - 1]) if down == 0 else int(_added_at[page][down - 1]) + 1


## How many bricks are on the baseplate at [param page] (at its [param
## part]), the ground not counted: what shown() holds, without gathering it.
func standing(page: int, part: int = 0) -> int:
	page = clamped(page)
	if page == 0:
		return _rank.size()
	part = clamped_part(page, part)
	return int(_standing[page]) if part == 0 \
		else int(_standing[page - 1]) + _down(page, part)


## The bricks whose fading changes going from page [param from] to page
## [param to] (from part to part, a part at a time), each to whether it is
## faded there: id -> bool. Only the two pages' own parts and those of the
## pages between them, so the next page is the page before's parts faded
## and nothing else — not every brick in the model asked, as faded() asks.
func fading(from: int, to: int, from_part: int = 0, to_part: int = 0) -> Dictionary:
	from = clamped(from)
	to = clamped(to)
	from_part = clamped_part(from, from_part)
	to_part = clamped_part(to, to_part)
	var out: Dictionary = {}
	if from == to and from_part == to_part:
		return out
	var asked: Array = [_fresh[from], _fresh[to]]
	for page: int in range(mini(from, to), maxi(from, to) + 1):
		asked.append(_added[page])
	for some: Variant in asked:
		for brick_id: int in some:
			var there: bool = _is_faded(brick_id, to, to_part)
			if there != _is_faded(brick_id, from, from_part):
				out[brick_id] = there
	return out


## Whether a brick is drawn faded on [param page]: built on a page before
## it, and not one the page points at. A part at a time, at [param part]:
## everything on the baseplate but the one thing it puts down.
func _is_faded(brick_id: int, page: int, part: int = 0) -> bool:
	if page <= 0:
		return false
	var rank: int = int(_rank.get(brick_id, page + 1))
	if part == 0:
		return rank < page and not _fresh[page].has(brick_id)
	if rank > page or _lit(brick_id, page, part):
		return false
	return rank < page or int(_place[brick_id]) < _down(page, part)


## What [param page] adds (at its [param part], the one thing put down):
## drawn in full colour and outlined.
func fresh(page: int, part: int = 0) -> Dictionary:
	page = clamped(page)
	part = clamped_part(page, part)
	if part == 0:
		return _fresh[page]
	if part == 1 and not _put_on[page].is_empty():
		return _put_on[page]
	return {_added[page][_down(page, part) - 1]: true}


## What was built before [param page] (and, at its [param part], the parts
## put down before it): drawn faded. None on the cover.
func faded(page: int, part: int = 0) -> Dictionary:
	page = clamped(page)
	part = clamped_part(page, part)
	var out: Dictionary = {}
	if page == 0:
		return out
	for brick_id: int in _rank:
		if _is_faded(brick_id, page, part):
			out[brick_id] = true
	return out


# -- a part at a time ------------------------------------------------------


## How many things [param page] puts down a part at a time: each part it
## adds, and first the finished sub-assembly on a page that puts one on.
## None on the cover, nor on a page that adds nothing.
func parts(page: int) -> int:
	page = clamped(page)
	if page == 0:
		return 0
	return (0 if _put_on[page].is_empty() else 1) + _added[page].size()


## [param part] as [param page] can show it: from 1 to its parts, a
## negative its last; 0, the page whole, when it is asked for or the page
## has no parts to put down one by one.
func clamped_part(page: int, part: int) -> int:
	var most: int = parts(page)
	if part == 0 or most == 0:
		return 0
	return most if part < 0 else clampi(part, 1, most)


## How many of the bricks [param page] adds are down at [param part]: all
## of them on the page whole.
func _down(page: int, part: int) -> int:
	if part == 0 or page == 0:
		return _added[page].size()
	return maxi(part - (0 if _put_on[page].is_empty() else 1), 0)


## Whether [param brick_id] is the thing [param page] puts down at [param part].
func _lit(brick_id: int, page: int, part: int) -> bool:
	if part == 1 and not _put_on[page].is_empty():
		return _put_on[page].has(brick_id)
	return int(_rank.get(brick_id, -1)) == page and int(_place[brick_id]) == _down(page, part) - 1


## The parts to pick up for [param page], as a booklet's callout lists
## them: one entry a part in a colour, the most of them first, each
## {"part", "colour", "count", "name", "colour_name"}. A hose laid in a bend
## is the one hose (Inventory.key_of). None on the cover. On a page that
## puts a finished sub-assembly on, the parts that go on beside it: the
## sub-assembly itself was picked up on its callout's pages. At a [param
## part], a part at a time, the one part put down, or none for the
## sub-assembly.
func lots(page: int, part: int = 0) -> Array[Dictionary]:
	page = clamped(page)
	part = clamped_part(page, part)
	var counts: Dictionary = {}
	var step: Instructions.Step = step_of(page)
	# An attach step carries the loose parts that go on beside the
	# sub-assembly, as an author's step does (Instructions.ATTACH_TAKES_PARTS).
	if step == null:
		return []
	var only: Dictionary = fresh(page, part) if part > 0 else {}
	for brick_id: int in step.brick_ids:
		if int(_rank.get(brick_id, -1)) != page or (part > 0 and not only.has(brick_id)):
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
## steps say which, "Step 12 of 40 · Window (2x), 1 of 3". The cover says
## how many, as the booklet and the model's page count them: "87 steps, and
## 12 sub-assemblies built on the side in 64 steps of their own"
## (Instructions.count). It said every page, 151, where its pages said "of 87".
func caption(page: int) -> String:
	var step: Instructions.Step = step_of(page)
	if step == null:
		return Instructions.count_words(Instructions.count(steps))
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
## direction from the model to the eye, "up": the way up on the screen,
## "turn": how the model is turned (BookletStudio.View.turn), "box": the
## box to fit}. As its booklet page draws it ([method booklet_turn]): turned
## where its designer turned it, roll and all, and turned over where its
## parts go on from below, so the eye is under the model and its underside
## is up on the screen (BookletStudio.basis_for), once that is known
## ([method work_out_turns], turned_over). Otherwise from the front,
## as every booklet step is drawn (BookletStudio.FRONT), or from the back
## where the step's new parts are hidden from the front and the back shows
## them, as BookletMaker turns a page round, the right way up; framed on
## what is built so far, or close round the new parts when they are a speck
## of it.
##
## Each page is decided on its own, where the booklet stays turned round
## while the back is the work: the player can open on any page (a person
## comes back to it), and a page's view must not hang on every page before
## it. The booklet's turn over is a page's own too: it is not held.
func view(page: int) -> Dictionary:
	page = clamped(page)
	if _views.has(page):
		return _views[page]
	var from: Vector3 = BookletStudio.FRONT
	var turn: Basis = Basis.IDENTITY
	var fresh_now: Dictionary = _fresh[page]
	var booklet: Array = booklet_turn(page)
	if not booklet.is_empty():
		from = booklet[0]
		turn = booklet[1]
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
	# Where the booklet's camera stands on the model as it stands, turned
	# (BookletStudio.basis_for): the up is the model's own up turned, which a
	# drag turns it about (CadCamera.look_from).
	if turn != Basis.IDENTITY:
		from = BookletStudio.basis_for(from, turn).z
	_views[page] = {"from": from, "up": turn.transposed() * Vector3.UP, "turn": turn, "box": box}
	return _views[page]


## How [param page]'s booklet page turns the model, as BookletMaker draws
## it: [the direction it looks from, the model's turn], or [] where it draws
## the step the right way up, from the front or the back as it chooses.
## Its designer's turn (BookletLooks.turn_at: a ROTSTEP, the timeline's
## Booklet row), the roll too (BookletLooks.roll); in a model with none of
## its designer's turns (BookletLooks.any_turn), turned over where a part
## of the step goes on from below what was built before it and none from
## above (BookletMaker._goes_on, the booklet's own, on the booklet's own
## stage of the bricks), and upright again on the next step that does not.
## A callout's step turns from the way the callout faces, on what the
## callout has built (BookletMaker._callout).
func booklet_turn(page: int) -> Array:
	page = clamped(page)
	if _turns.has(page):
		return _turns[page]
	var out: Array = []
	var step: Instructions.Step = step_of(page)
	if step != null:
		var turn: Dictionary = BookletLooks.turn_at(_world, step.authored_in, step.authored_step) \
			if step.authored_step >= 0 else {}
		if not turn.is_empty():
			var facing: Vector3 = _facing(page)
			out = [BookletLooks.direction(turn, facing), BookletLooks.roll(turn, facing)]
		elif _over.has(page):
			var facing: Vector3 = _facing(page)
			var over: Dictionary = Later.script(&"BookletMaker").get_script_constant_map()["OVER_TURN"]
			out = [facing, BookletLooks.roll(over, facing)]
		elif not _own_turns and not _asked.has(page):
			# Not known yet: the right way up until it is (turned_over), and
			# this page asked next.
			_wanted = page
			return out
	_turns[page] = out
	return out


## Whether every page's turn is known: none of them waits on
## [method work_out_turns].
func turns_known() -> bool:
	return _own_turns or _overs_known or last() < 1


## Work out which pages the booklet turns over because their parts go on
## from below, as it does (BookletMaker._goes_on: each of the step's bricks
## asked BookletMaker._stud_way, on the booklet's own stage of the model),
## spending at most [param budget_ms] of a frame's time before the next
## frame, from page 1 on, a page the player asks for meanwhile first. A
## castle's 400 pages are two seconds of joints read (Exact.connections),
## and a step of eight baseplates a fifth of one, which a page turn cannot
## spend: so it is done while the model is looked at, and a page asked
## before its turn is known is the right way up until it is, then turned
## (turned_over). Nothing to do in a model with turns of its designer's.
func work_out_turns(budget_ms: float = 4.0) -> void:
	if turns_known() or _working:
		return
	_working = true
	var tree := Engine.get_main_loop() as SceneTree
	var budget: int = int(budget_ms * 1000.0)
	var began: Array = [Time.get_ticks_usec()]
	var pause := func() -> bool:
		if Time.get_ticks_usec() - int(began[0]) < budget:
			return false
		await tree.process_frame
		began[0] = Time.get_ticks_usec()
		return true
	var maker: Node = _booklet_maker()
	# The booklet's stage of the model (BookletMaker._main), its bricks in
	# the pages' order, a slice a frame.
	var entries: Array = []
	for brick_id: int in order:
		entries.append(maker.call(&"_entry_of", brick_id))
		await pause.call()
		if _stopped:
			return
	maker.set(&"_order", entries)
	maker.set(&"_main", maker.call(&"_stage", entries))
	var next: int = 1
	while not _stopped:
		var page: int = _wanted if _wanted > 0 and not _asked.has(_wanted) else next
		_wanted = 0
		while page <= last() and _asked.has(page):
			page += 1
		if page > last():
			break
		if page == next:
			next += 1
		var way: int = await _goes_on(page, pause)
		if _stopped:
			break
		_asked[page] = true
		if way < 0:
			_over[page] = true
			_turns.erase(page)
			_views.erase(page)
			turned_over.emit(page)
		await pause.call()
	_working = false
	_overs_known = not _stopped


## Stop [method work_out_turns]: these pages are done with.
func stop() -> void:
	_stopped = true


## The way the booklet looks at [param page]'s step before any turn: the
## front, or for a callout's step the way its callout faces, a figure's
## face (BookletMaker._facing).
func _facing(page: int) -> Vector3:
	var step: Instructions.Step = step_of(page)
	if step == null or not step.in_callout():
		return BookletStudio.FRONT
	var attach: int = _attach_of(page)
	if attach < 1 or not steps[attach - 1].figure:
		return BookletStudio.FRONT
	return _booklet_maker().call(&"_facing", steps[attach - 1])


## Which way [param page]'s parts go on, as the booklet says for its step
## (BookletMaker._goes_on): -1 one from below what was built before them
## and none from above, 1 one from above, 0 neither. Ranked as the booklet
## ranks its steps (BookletMaker._entries): the step that puts a callout's
## sub-assembly on takes in the callout's parts; a callout's own step on
## the callout's own stage, the first copy as its steps build it.
##
## BookletMaker._goes_on asked a brick at a time, [param pause] between
## them (a step of eight baseplates is a fifth of a second of the castle):
## the same bricks in the same order, the same answer, one from above
## enough.
func _goes_on(page: int, pause: Callable) -> int:
	var maker: Node = _booklet_maker()
	var step: Instructions.Step = step_of(page)
	var span := Vector2i.ZERO
	var stage: Object = maker.get(&"_main")
	var ranked: Array = maker.get(&"_order")
	if step.in_callout():
		var attach: int = _attach_of(page)
		if attach < 1:
			return 0
		var callout: Array = _callout_stage(attach)
		var at: int = (callout[3] as Array).find(page)
		if at < 0:
			return 0
		span = Vector2i(int(callout[2][at][0]), int(callout[2][at][1]))
		stage = callout[0]
		ranked = callout[1]
	else:
		var first: int = page
		if step.attaches():
			first -= _built_for(page).size()
		span = Vector2i(_upto[first - 1] + 1, _upto[page])
	var below: bool = false
	var last_rank: int = mini(span.y, (stage.get(&"boxes") as Array).size())
	for rank: int in range(span.x, last_rank + 1):
		var way: int = int(maker.call(&"_stud_way", rank, span.x, last_rank, stage, ranked))
		if way > 0:
			return 1
		below = below or way < 0
		await pause.call()
		if _stopped:
			return 0
	return -1 if below else 0


## The page that puts on the callout [param page] is a step of: the next
## of the model's steps that puts a sub-assembly on (BookletMaker._entries
## holds a callout's steps until one does), or 0 for none.
func _attach_of(page: int) -> int:
	for at: int in range(page + 1, last() + 1):
		var step: Instructions.Step = steps[at - 1]
		if not step.in_callout() and step.attaches():
			return at
	return 0


## The callout's steps [param attach] puts on, as BookletMaker._entries
## gathers them: every callout step since the last page that put one on.
func _built_for(attach: int) -> Array[int]:
	var built: Array[int] = []
	for at: int in range(attach - 1, 0, -1):
		var step: Instructions.Step = steps[at - 1]
		if step.in_callout():
			built.push_front(at)
		elif step.attaches():
			break
	return built


## The stage BookletMaker._callout lays the callout [param attach] puts on
## out on: [stage, its order, each step's span, the steps' pages].
func _callout_stage(attach: int) -> Array:
	if _callouts.has(attach):
		return _callouts[attach]
	var maker: Node = _booklet_maker()
	var built: Array[int] = _built_for(attach)
	var callout_order: Array = []
	var spans: Array = []
	for at: int in built:
		var from: int = callout_order.size() + 1
		for brick_id: int in steps[at - 1].shown_ids:
			callout_order.append(maker.call(&"_entry_of", brick_id))
		spans.append([from, callout_order.size()])
	_callouts[attach] = [maker.call(&"_stage", callout_order), callout_order, spans, built]
	return _callouts[attach]


## The booklet's maker, laying out only (BookletMaker.dry), on the model's
## bricks: what says which way a step's parts go on, and which way a
## figure's callout faces, is the booklet's, not a copy. Its stage of the
## model in [member order] is set by [method work_out_turns]. Made when
## first asked, which in a model with no figure and turns of its
## designer's is never; freed with the pages. Through Later, as everything
## the first screen does not need (main._ready_the_pages compiles it on a
## worker before the pages ask).
func _booklet_maker() -> Node:
	if _maker != null:
		return _maker
	_maker = Later.script(&"BookletMaker").new()
	_maker.set(&"dry", true)
	_maker.set(&"library", _library)
	_maker.set(&"_world", _world)
	return _maker


## Whether a page's turn asks the booklet's maker ([method
## _booklet_maker]): the model has none of its designer's turns, so a step
## whose parts go on from below is turned over; or a callout of a figure
## faces the way the figure does.
func asks_the_booklet() -> bool:
	if last() < 1:
		return false
	if not _own_turns:
		return true
	for step: Instructions.Step in steps:
		if step.figure:
			return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _maker != null:
		_maker.free()
		_maker = null


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
