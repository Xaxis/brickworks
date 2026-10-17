## The step player's pages (BuildSteps): what each step puts on the
## baseplate, what it fades, which parts it lists, which way it looks,
## and where a link was left.
##
##   godot --headless --path . --script src/dev/build_steps_probe.gd
##
## Followed through as someone at a table would: every part is picked up
## on exactly one page; a page shows what is built so far and nothing
## after; what came before is faded and what is new is not; the parts
## along the bottom are the new parts, counted by part and colour, the
## most first. A shed with two windows and a figure for the callouts
## (instructions_probe's), the house for an ordinary model, the castle
## for a big one. A part hidden behind a wall is looked at from the back.
## A tile on a big model is framed close. The place kept for a link comes
## back, and a kept value of the wrong shape is no place at all. The same
## file opened twice makes the same pages.
extends SceneTree

const SHED_FROM := "res://src/dev/instructions_probe.gd"

var _failures: int = 0


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)

	var shed: String = load(SHED_FROM).get("SHED")
	_follow("the shed (two windows and a figure, in callouts)", world, library,
		LdrModel.parse(shed, "shed.ldr"))
	_follow("the house", world, library, LdrModel.load_file("res://models/house.ldr"))
	_follow("the castle", world, library, LdrModel.load_file("res://models/castle.ldr"))
	_same_file_same_pages(world, library)
	_behind_a_wall(world, library)
	_close_on_a_speck(world, library)
	_kept_place()

	print("")
	print("%d FAILED" % _failures if _failures else
		"every page of the step player can be built from, and a link comes back where it was left")
	quit(1 if _failures else 0)


func _load(world: BrickWorld, library: PartLibrary, ldr: LdrModel) -> void:
	world.clear()
	for piece: LdrModel.Placement in ldr.flatten(library.parts):
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(id) == null:
			continue
		var brick_id: int = world.add_brick(id, piece.color_code, piece.transform)
		world.get_brick(brick_id).group = piece.group
		world.get_brick(brick_id).unit = piece.unit


## Every page of a model, as a person building it goes through them.
func _follow(what: String, world: BrickWorld, library: PartLibrary, ldr: LdrModel) -> void:
	print("\n%s" % what)
	if ldr == null:
		_ok(false, "the model can be read")
		return
	_load(world, library, ldr)
	var planned: int = Time.get_ticks_usec()
	var steps: Array[Instructions.Step] = Instructions.plan(world, library)
	var plan_ms: float = (Time.get_ticks_usec() - planned) / 1000.0
	var started: int = Time.get_ticks_usec()
	var pages: BuildSteps = BuildSteps.of(world, library, steps)
	var made_ms: float = (Time.get_ticks_usec() - started) / 1000.0
	var every: Dictionary = {}
	for brick: BrickWorld.Brick in world.bricks():
		every[brick.id] = true
	print("  %d parts in %d steps, worked out in %.0f ms when the link opened; its pages in %.1f ms"
		% [every.size(), steps.size(), plan_ms, made_ms])
	_ok(pages.last() == steps.size(), "a page a step, after the cover (%d)" % pages.last())

	# The cover: the finished model, nothing faded, nothing to pick up.
	_ok(pages.shown(0).size() == every.size() and pages.faded(0).is_empty()
		and pages.fresh(0).is_empty() and pages.lots(0).is_empty() and pages.note(0).is_empty(),
		"the cover is the whole model, nothing faded and no parts listed")
	_ok(pages.caption(0) == "%d steps" % steps.size(), "...and says how many steps (%s)" % pages.caption(0))

	var picked: Dictionary = {}
	var twice: int = 0
	var bad_show: int = 0
	var bad_fade: int = 0
	var bad_lots: int = 0
	var unsorted: int = 0
	var bad_caption: int = 0
	var slowest_view: float = 0.0
	var first_view: float = 0.0
	var before: Dictionary = {}
	var attached: int = 0
	for page: int in range(1, pages.last() + 1):
		var step: Instructions.Step = pages.step_of(page)
		var shown: Dictionary = pages.shown(page)
		var faded: Dictionary = pages.faded(page)
		var fresh: Dictionary = pages.fresh(page)
		# On screen: what came before, and this page's.
		var expected: Dictionary = before.duplicate()
		for brick_id: int in step.brick_ids:
			expected[brick_id] = true
		if shown.size() != expected.size() or not shown.keys().all(func(id: int) -> bool:
				return expected.has(id)):
			bad_show += 1
		# Faded: everything on screen but this page's; never one of this
		# page's, never one not yet on.
		for brick_id: int in faded:
			if fresh.has(brick_id) or not shown.has(brick_id):
				bad_fade += 1
		for brick_id: int in shown:
			if not fresh.has(brick_id) and not faded.has(brick_id):
				bad_fade += 1
		if step.attaches():
			attached += 1
			var copies: int = 0
			for copy: PackedInt64Array in step.copies:
				copies += copy.size()
			if fresh.size() != copies or not pages.lots(page).is_empty() \
					or not pages.note(page).begins_with("Put"):
				bad_lots += 1
		else:
			# Picked up here: this page's own new parts, each once.
			var counted: Dictionary = {}
			for brick_id: int in step.brick_ids:
				if picked.has(brick_id):
					twice += 1
				picked[brick_id] = page
				var brick: BrickWorld.Brick = world.get_brick(brick_id)
				var key: String = "%s:%d" % [brick.part_id, brick.color_code]
				counted[key] = int(counted.get(key, 0)) + 1
			var listed: Dictionary = {}
			var last_count: int = 1 << 30
			for lot: Dictionary in pages.lots(page):
				listed["%s:%d" % [lot["part"], lot["colour"]]] = int(lot["count"])
				if int(lot["count"]) > last_count:
					unsorted += 1
				last_count = int(lot["count"])
			if listed != counted or pages.pieces(page) != step.brick_ids.size():
				bad_lots += 1
		if pages.caption(page) != step.caption(steps[-1].number) \
				or not pages.caption(page).begins_with("Step %d of " % step.number):
			bad_caption += 1
		var looked_at: int = Time.get_ticks_usec()
		var view: Dictionary = pages.view(page)
		var took: float = (Time.get_ticks_usec() - looked_at) / 1000.0
		if page == 1:
			first_view = took
		else:
			slowest_view = maxf(slowest_view, took)
		if not (view["box"] as AABB).has_volume():
			bad_show += 1
		before = shown
		for brick_id: int in fresh:
			before[brick_id] = true
	_ok(bad_show == 0, "each page shows what is built by then and nothing after (%d wrong)" % bad_show)
	_ok(bad_fade == 0, "...what came before faded, this page's new parts not (%d wrong)" % bad_fade)
	_ok(twice == 0 and picked.size() == every.size(),
		"every part is picked up on exactly one page (%d of %d, %d twice)" % [
			picked.size(), every.size(), twice])
	_ok(bad_lots == 0, "the parts listed are the page's new parts, by part and colour (%d wrong)"
		% bad_lots)
	_ok(unsorted == 0, "...the most of them first")
	_ok(bad_caption == 0, "each page is numbered as the timeline and the booklet number it")
	_ok(pages.shown(pages.last()).size() == every.size() and pages.faded(pages.last()).size()
		== every.size() - pages.fresh(pages.last()).size(),
		"the last page is the whole model, all but its own parts faded")
	_turns_change_only_the_step(pages, every.size())

	# On the desktop, where the web on a phone is several times slower:
	# the first page includes laying every part out on the view plane.
	_ok(first_view < 20.0 and slowest_view < 20.0,
		"a page's view is worked out in %.1f ms at most, the first in %.1f" % [
			slowest_view, first_view])
	if steps.any(func(step: Instructions.Step) -> bool: return step.in_callout()):
		_ok(attached > 0, "a sub-assembly built on the side is put on in a page of its own, "
			+ "outlining every copy (%d)" % attached)
		var first_callout: int = -1
		for page: int in range(1, pages.last() + 1):
			if pages.step_of(page).in_callout() and pages.step_of(page).callout_step == 1:
				first_callout = page
				break
		_ok(first_callout > 0 and pages.note(first_callout).begins_with("Build"),
			"...and its first page says to build it on the side (%s)" % (
				pages.note(first_callout) if first_callout > 0 else "none"))


## A page turned as the player turns it: a count of the order, and only the
## bricks whose fading changes faded or not (BuildSteps.count, fading) — the
## same on screen as the whole model asked (shown, faded), next, back, and a
## jump either way, the cover included.
func _turns_change_only_the_step(pages: BuildSteps, every: int) -> void:
	var wrong_count: int = 0
	var wrong_fading: int = 0
	var most: int = 0
	var pairs: Array[Vector2i] = []
	for page: int in range(0, pages.last()):
		pairs.append(Vector2i(page, page + 1))
		pairs.append(Vector2i(page + 1, page))
	for jump: int in [0, 1, 3, 30, pages.last()]:
		pairs.append(Vector2i(mini(2, pages.last()), mini(jump, pages.last())))
		pairs.append(Vector2i(mini(jump, pages.last()), 0))
	for pair: Vector2i in pairs:
		var to: int = pair.y
		# On screen at [to]: the first count(to) of the order, each once.
		var seen: Dictionary = {}
		for n: int in pages.count(to):
			seen[pages.order[n]] = true
		var shown: Dictionary = pages.shown(to)
		if seen.size() != shown.size() or pages.standing(to) != shown.size():
			wrong_count += 1
		# Faded there: what was faded at [from], with the changes made.
		var faded: Dictionary = pages.faded(pair.x).duplicate()
		var changes: Dictionary = pages.fading(pair.x, to)
		most = maxi(most, changes.size()) if absi(pair.x - to) == 1 else most
		for brick_id: int in changes:
			if changes[brick_id]:
				faded[brick_id] = true
			else:
				faded.erase(brick_id)
		var wanted: Dictionary = pages.faded(to)
		if faded.size() != wanted.size() or not wanted.keys().all(func(id: int) -> bool:
				return faded.has(id)):
			wrong_fading += 1
	_ok(wrong_count == 0, "a page is a count of the order: the same parts on the baseplate as "
		+ "the whole model asked (%d of %d turns wrong)" % [wrong_count, pairs.size()])
	_ok(wrong_fading == 0, "...and a turn fades only what changes, to the same page as the whole "
		+ "model asked (%d wrong); a step's turn changes %d parts at most of %d" % [
			wrong_fading, most, every])


## The steps break ties by the order the parts stand in, so the same file
## must make the same pages every time it is opened: a person coming back
## to page 12 is coming back to the same page 12.
func _same_file_same_pages(world: BrickWorld, library: PartLibrary) -> void:
	print("\nthe same file, opened twice")
	var ldr: LdrModel = LdrModel.load_file("res://models/house.ldr")
	var looks: Array[String] = []
	for _n: int in 2:
		_load(world, library, ldr)
		looks.append(_pages_as_text(world, library))
	_ok(looks[0] == looks[1], "the same pages, page for page")
	# In another order, as on the web, where each part stands when it
	# arrives: what the viewer opens again for (main._view_shared).
	world.clear()
	var placements: Array = ldr.flatten(library.parts)
	placements.reverse()
	for piece: LdrModel.Placement in placements:
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(id) != null:
			world.add_brick(id, piece.color_code, piece.transform)
	var reversed: String = _pages_as_text(world, library)
	print("  in the reverse order the pages are %s" % (
		"the same" if reversed == looks[0] else "different: why the viewer opens a link again in its file's order once every part is in"))


func _pages_as_text(world: BrickWorld, library: PartLibrary) -> String:
	var pages: BuildSteps = BuildSteps.of(world, library, Instructions.plan(world, library))
	var lines := PackedStringArray()
	for page: int in range(1, pages.last() + 1):
		var parts := PackedStringArray()
		for brick_id: int in pages.fresh(page):
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			parts.append("%s:%d@%s" % [brick.part_id, brick.color_code, brick.transform.origin])
		parts.sort()
		lines.append(",".join(parts))
	return "\n".join(lines)


## A brick behind a wall is looked at from the back, as a booklet turns
## the model round; one in the open from the front.
func _behind_a_wall(world: BrickWorld, library: PartLibrary) -> void:
	print("\na part behind a wall")
	world.clear()
	# The eye is towards +z (BookletStudio.FRONT): a wall of 1 x 8 bricks
	# five high at z = 60 hides a 1 x 1 at z = 0 behind it.
	var wall := Instructions.Step.new()
	wall.number = 1
	for course: int in 5:
		for along: int in [-80, 80]:
			var at := Transform3D(Basis(), Vector3(along, 24 * course, 60))
			var brick_id: int = world.add_brick("3008", 4, at)
			wall.brick_ids.append(brick_id)
			wall.parts["3008"] = int(wall.parts.get("3008", 0)) + 1
	var hidden := Instructions.Step.new()
	hidden.number = 2
	var behind: int = world.add_brick("3005", 1, Transform3D(Basis(), Vector3(0, 0, 0)))
	hidden.brick_ids.append(behind)
	hidden.parts["3005"] = 1
	var open := Instructions.Step.new()
	open.number = 3
	var on_top: int = world.add_brick("3005", 14, Transform3D(Basis(), Vector3(0, 120, 60)))
	open.brick_ids.append(on_top)
	open.parts["3005"] = 1
	var made: Array[Instructions.Step] = [wall, hidden, open]
	for index: int in made.size():
		made[index].index = index + 1
	var pages: BuildSteps = BuildSteps.of(world, library, made)
	var front: float = pages.seen(2, BookletStudio.FRONT)
	var back: float = pages.seen(2, BookletStudio.BACK)
	_ok(front < BuildSteps.TURN_BELOW and back > front + BuildSteps.TURN_GAIN,
		"behind it, it is hidden from the front (%.2f seen) and not from the back (%.2f)" % [
			front, back])
	_ok(pages.view(2)["from"] == BookletStudio.BACK, "...so its page looks from the back")
	_ok(pages.view(3)["from"] == BookletStudio.FRONT and pages.seen(3, BookletStudio.FRONT) > 0.9,
		"one on top of the wall is looked at from the front (%.2f seen)"
		% pages.seen(3, BookletStudio.FRONT))
	_ok(pages.view(1)["from"] == BookletStudio.FRONT, "...and so is the wall")


## One tile on a big model: framed close, with what it goes on round it,
## not the whole model with the tile a speck in it.
func _close_on_a_speck(world: BrickWorld, library: PartLibrary) -> void:
	print("\na tile on a big model")
	world.clear()
	var floor_step := Instructions.Step.new()
	floor_step.number = 1
	for x: int in 6:
		for z: int in 6:
			var brick_id: int = world.add_brick("3036", 2,
				Transform3D(Basis(), Vector3(x * 120, 0, z * 160)))
			floor_step.brick_ids.append(brick_id)
	var tile_step := Instructions.Step.new()
	tile_step.number = 2
	var tile: int = world.add_brick("3070b", 4, Transform3D(Basis(), Vector3(300, -8, 400)))
	tile_step.brick_ids.append(tile)
	var made: Array[Instructions.Step] = [floor_step, tile_step]
	var pages: BuildSteps = BuildSteps.of(world, library, made)
	var whole: AABB = pages.view(1)["box"]
	var close: AABB = pages.view(2)["box"]
	var tile_box: AABB = world.get_brick(tile).transform * library.mesh_for("3070b").bounds
	_ok(close.size.length() < whole.size.length() * 0.5 and close.encloses(tile_box),
		"the tile's page frames %.0f LDU across round it, of the model's %.0f" % [
			close.size.length(), whole.size.length()])
	_ok(close.size.length() > tile_box.size.length() * 2.0,
		"...with what it goes on round it, not the tile alone (%.0f, the tile %.0f)" % [
			close.size.length(), tile_box.size.length()])


## Where a link was left, on this device.
func _kept_place() -> void:
	print("\nwhere a link was left")
	_ok(BuildSteps.recall("Pr0beBu1ld").is_empty(), "a link never built from has no place")
	BuildSteps.remember("Pr0beBu1ld", 7, true)
	var kept: Dictionary = BuildSteps.recall("Pr0beBu1ld")
	_ok(kept == {"page": 7, "building": true}, "the page and that it was being built come back (%s)"
		% kept)
	BuildSteps.remember("Pr0beBu1ld", 9, false)
	_ok(BuildSteps.recall("Pr0beBu1ld") == {"page": 9, "building": false}
		and BuildSteps.recall("0therL1nk").is_empty(), "...kept per link")
	for junk: Variant in ["7", {"page": "seven"}, {"building": true}, [7], null]:
		BuildSteps._kept["Pr0beJunk0"] = junk
		_ok(BuildSteps.recall("Pr0beJunk0").is_empty(), "a kept value of the wrong shape is no place (%s)"
			% [junk])
	BuildSteps._kept["Pr0beJunk0"] = {"page": -4, "building": "yes"}
	_ok(BuildSteps.recall("Pr0beJunk0") == {"page": 0, "building": false},
		"...and one out of range is the cover, not being built")
	BuildSteps._kept.clear()


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
