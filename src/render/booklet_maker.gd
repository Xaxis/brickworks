## Makes the booklet: plans the build, decides how each step is seen,
## lays the pages out and draws every picture on them.
##
## The order of the work matters, because each stage needs the one
## before it:
##
##   1. the plan (Instructions), and a stage with the model on it in the
##      order the plan builds it
##   2. a picture of every part, at one scale, for the parts boxes
##   3. which way each step is seen: from the front unless its new parts
##      are hidden there and the back shows them (BookletStudio.shoot,
##      measuring), turning back when the front will do again
##   4. what each step's picture has to show, on that view's plane
##   5. the pages (Booklet.lay_out), which say how big each picture is
##   6. the pictures themselves, the callouts', and the arrows from each
##      callout to where its assembly went, worked out by projecting the
##      assembly through the same camera
##   7. the cover, the finished model and the parts list
##
## A node, because pictures take frames.
class_name BookletMaker
extends Node

## Said as the work goes, for the status line.
signal progress(said: String)

## The colours the pictures are laid on: see Booklet's stylesheet.
const PAGE_COLOUR := Color8(220, 236, 248)
const CALLOUT_COLOUR := Color8(255, 243, 200)
const CALLOUT_PAGE_COLOUR := Color8(255, 248, 222)

var library: PartLibrary
## Pixels per millimetre of paper: 5 is 127 dots an inch. Fewer on the
## web, where a castle's pictures at full size would be a slow afternoon.
var px_per_mm: float = 5.0
## For a probe: what each picture showed, [{what, size, model, new, seen}].
var measured: Array = []
var document: Booklet.Document

## What the status bar shows while it works (Working), and Cancel. Null
## for the command line and the probes, which wait for it regardless.
var job: Working.Job = null

var _studio: BookletStudio
var _world: BrickWorld
## The parts list the booklet ends with, which its steps' parts boxes agree
## with.
var _stock: Inventory
var _main: BookletStudio.Stage


## True while a booklet is being made, so a second press waits for it.
static var busy: bool = false
## The toolbar's Instructions button, for the page to find (main._tell_page).
static var shown_button: Button = null
## Open the file in the browser once it is written, on the desktop. A probe
## that presses the button turns this off rather than opening a browser.
static var open_when_written: bool = not OS.has_feature("web")


func make(world: BrickWorld, scenery: Dictionary, title: String) -> String:
	busy = true
	var html: String = await _make(world, scenery, title)
	busy = false
	return html


func _make(world: BrickWorld, scenery: Dictionary, title: String) -> String:
	_world = world
	measured.clear()
	# In the author's steps, when the model has them.
	var steps: Array[Instructions.Step] = []
	if job != null:
		steps = await Instructions.plan_paced(world, library, scenery, {}, job, true)
	else:
		steps = Instructions.plan(world, library, scenery, {}, true)
	if steps.is_empty() or _stopped():
		return ""
	_say("Setting out %d steps…" % steps.size(), 0)
	for index: int in steps.size():
		if steps[index].attaches():
			_attach_copies[index] = steps[index].copies
	if OS.has_feature("web"):
		px_per_mm = minf(px_per_mm, 4.0)
	# Coarser as the booklet gets longer. At five a millimetre the castle
	# was 104 MB and Orthanc, 1,405 steps, 256 MB: a file a browser takes
	# a minute to open. 3.6 is still 90 dots an inch, and a page a quarter
	# the size of a LEGO PDF's.
	if steps.size() > 1000:
		px_per_mm = minf(px_per_mm, 3.6)
	elif steps.size() > 300:
		px_per_mm = minf(px_per_mm, 4.2)
	_studio = BookletStudio.new()
	_studio.library = library
	add_child(_studio)
	await get_tree().process_frame

	var order: Array = []
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			order.append(_entry_of(brick_id))
	_main = _studio.stage(order)
	await get_tree().process_frame

	document = Booklet.Document.new()
	document.title = title
	var stock: Inventory = Inventory.of(world, library, scenery)
	_stock = stock
	document.pieces = stock.pieces
	document.credits = ("Part geometry from the LDraw™ Parts Library, © the LDraw community, "
		+ "CC BY 2.0 and CC BY 4.0. Catalogue data: Rebrickable. LEGO® is a trademark of the LEGO Group of "
		+ "companies which does not sponsor, authorize or endorse this booklet.")
	_lap("staged")
	var lots: Dictionary = await _part_pictures(stock)
	_lap("parts drawn")
	if _stopped():
		return _forget_all()

	var entries: Array[Booklet.Entry] = _entries(steps, lots)
	document.steps = entries.size()
	await _choose_views(entries)
	_lap("views chosen")
	if _stopped():
		return _forget_all()
	_subjects(entries)

	var pages: Array[Booklet.Page] = Booklet.lay_out(entries, 2)
	var drawn: int = 0
	var total: int = 0
	for page: Booklet.Page in pages:
		total += page.entries.size()
	for page: Booklet.Page in pages:
		for entry: Booklet.Entry in page.entries:
			drawn += 1
			if drawn % 5 == 1:
				_say("Drawing the steps…", total, drawn - 1)
			if _stopped():
				return _forget_all()
			await _draw(entry)

	_lap("steps drawn")
	document.pages.append(await _cover())
	document.pages.append_array(pages)
	var finished: Booklet.Page = await _finished(pages.size() + 2)
	document.pages.append(finished)
	document.lots = _inventory(stock, lots)
	document.pages.append_array(Booklet.parts_pages(document.lots, finished.number + 1))

	_forget_all()
	_say("Writing the booklet…", 0)
	await get_tree().process_frame
	var html: String = Booklet.html(document)
	_lap("written")
	return html


## Say how it is going: to the status line (progress), and to the job with
## how far along when [param total] is given (0: not countable).
func _say(words: String, total: int = -1, done: int = 0) -> void:
	if job != null:
		job.say(words)
		if total >= 0:
			job.count(done, total)
	progress.emit(words)


## Whether Cancel was pressed.
func _stopped() -> bool:
	return job != null and job.cancelled


## Put the stages away, as at the end; an empty booklet, for a stop.
func _forget_all() -> String:
	for made: BookletStudio.Stage in _stages:
		_studio.forget(made)
	_stages.clear()
	if _main != null:
		_studio.forget(_main)
		_main = null
	if is_instance_valid(_studio):
		_studio.queue_free()
	return ""


var _stages: Array[BookletStudio.Stage] = []
var _clock: int = Time.get_ticks_msec()
## How long each stage took, for whoever is timing it: [[what, ms], ...].
var laps: Array = []


func _lap(what: String) -> void:
	var now: int = Time.get_ticks_msec()
	laps.append([what, now - _clock])
	_clock = now
## Each step's bricks as ranks on the main stage: index -> [from, upto].
var _ranks: Dictionary = {}
## World brick id -> its box.
var _boxes: Dictionary = {}
## Callout number -> [stage, [[from, upto] per step], copies' boxes].
var _callouts: Dictionary = {}


func _entry_of(brick_id: int) -> Array:
	var brick: BrickWorld.Brick = _world.get_brick(brick_id)
	return [brick_id, brick.part_id, brick.color_code, brick.transform]


func _box(brick_id: int) -> AABB:
	if not _boxes.has(brick_id):
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		var part: Lbm.PartMesh = library.mesh_for(brick.part_id)
		_boxes[brick_id] = (brick.transform * part.bounds) if part != null \
			else AABB(brick.transform.origin, Vector3.ZERO)
	return _boxes[brick_id]


# -- parts ---------------------------------------------------------------------


## A picture of every part in every colour the model has it in, at one
## scale, the way a parts box draws them. key -> Booklet.Lot (sized).
func _part_pictures(stock: Inventory) -> Dictionary:
	# A hose laid along a bend is listed as the straight hose, which the
	# model never drew: on the web it may not be here yet.
	var waiting: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		if stock.items.values().has(lot) and library.mesh_for(lot.part_id) == null \
				and library.request_mesh(lot.part_id, true):
			waiting[lot.part_id] = true
	var until: int = Time.get_ticks_msec() + 30000
	while not waiting.is_empty() and Time.get_ticks_msec() < until:
		await get_tree().process_frame
		for id: String in waiting.keys():
			if library.is_resident(id):
				waiting.erase(id)
	var lots: Dictionary = {}
	var count: int = 0
	for lot: Inventory.Lot in stock.lots:
		count += 1
		if count % 10 == 1:
			_say("Drawing the parts…", stock.lots.size(), count - 1)
		if _stopped():
			return lots
		var key: String = "%s:%d" % [lot.part_id, lot.color_code]
		var made := Booklet.Lot.new()
		made.key = key
		made.part_id = lot.part_id
		made.name = lot.name
		made.colour = lot.color_name
		made.element = lot.element
		made.count = lot.count
		var part: Lbm.PartMesh = library.mesh_for(lot.part_id)
		if part == null:
			continue
		var stage: BookletStudio.Stage = _studio.stage(
			[[0, lot.part_id, lot.color_code, Transform3D.IDENTITY]])
		var extent: Rect2 = BookletStudio.extent([part.bounds], BookletStudio.FRONT)
		made.size = Booklet.part_size(extent.size)
		# Twice the page's resolution: a part is small on the page and
		# read closely.
		var pixels: Vector2i = Vector2i((made.size + Vector2(1.0, 1.0)) * px_per_mm * 2.0)
		var scale: float = (made.size.x / maxf(extent.size.x, 0.1)) * px_per_mm * 2.0
		var view := BookletStudio.View.new(BookletStudio.FRONT, extent.get_center(), scale)
		var shot: BookletStudio.Shot = await _studio.shoot(stage, 1, 2, view, pixels)
		_studio.forget(stage)
		made.size += Vector2(1.0, 1.0)
		document.parts[key] = _data_uri(shot.image)
		lots[key] = made
	return lots


## The parts list at the end, by colour: the whites, the greys and black,
## then the colours round the wheel, then the clear ones; within a
## colour, small parts first.
func _inventory(stock: Inventory, lots: Dictionary) -> Array[Booklet.Lot]:
	var listed: Array[Booklet.Lot] = []
	var rank: Dictionary = {}
	for lot: Inventory.Lot in stock.lots:
		var key: String = "%s:%d" % [lot.part_id, lot.color_code]
		if not lots.has(key):
			continue
		listed.append(lots[key])
		var colour: PartLibrary.BrickColor = library.color(lot.color_code)
		var order: float = 9.0
		if colour != null:
			var c: Color = colour.rgb
			if colour.is_transparent():
				order = 3.0 + c.h
			elif c.s < 0.18:
				order = 1.0 - c.v
			else:
				order = 2.0 + c.h
		rank[key] = [order, lot.color_code]
	listed.sort_custom(func(a: Booklet.Lot, b: Booklet.Lot) -> bool:
		var ra: Array = rank[a.key]
		var rb: Array = rank[b.key]
		if ra[1] != rb[1]:
			if not is_equal_approx(float(ra[0]), float(rb[0])):
				return float(ra[0]) < float(rb[0])
			return int(ra[1]) < int(rb[1])
		var area_a: float = a.size.x * a.size.y
		var area_b: float = b.size.x * b.size.y
		if not is_equal_approx(area_a, area_b):
			return area_a < area_b
		return a.part_id < b.part_id)
	return listed


func _lots_of(ids: PackedInt64Array, lots: Dictionary, times: int = 1) -> Array[Booklet.Lot]:
	var counts: Dictionary = {}
	var order: Array[String] = []
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		# A hose laid along a bend is the one hose, not its rings.
		var key: String = _stock.key_of(brick)
		if key.is_empty():
			continue
		if not counts.has(key):
			order.append(key)
		counts[key] = int(counts.get(key, 0)) + times
	var out: Array[Booklet.Lot] = []
	for key: String in order:
		if not lots.has(key):
			continue
		var source: Booklet.Lot = lots[key]
		var lot := Booklet.Lot.new()
		lot.key = key
		lot.part_id = source.part_id
		lot.name = source.name
		lot.colour = source.colour
		lot.element = source.element
		lot.size = source.size
		lot.count = int(counts[key])
		out.append(lot)
	# Biggest first, as a box is filled: the 2 x 4 before the 1 x 1.
	out.sort_custom(func(a: Booklet.Lot, b: Booklet.Lot) -> bool:
		return a.size.x * a.size.y > b.size.x * b.size.y)
	return out


# -- steps ---------------------------------------------------------------------


func _entries(steps: Array[Instructions.Step], lots: Dictionary) -> Array[Booklet.Entry]:
	var entries: Array[Booklet.Entry] = []
	var rank: int = 0
	var pending: Array[Instructions.Step] = []
	for index: int in steps.size():
		var step: Instructions.Step = steps[index]
		var from: int = rank + 1
		rank += step.brick_ids.size()
		_ranks[index] = [from, rank]
		if step.in_callout():
			pending.append(step)
			continue
		var entry := Booklet.Entry.new()
		entry.number = step.number
		entry.awkward = step.unsupported
		entry.section = step.section
		entry.set_meta("step", index)
		if step.unsupported:
			entry.note = "Hold this in place: it rests on nothing until the next step."
		if step.attaches():
			var first: int = int(_ranks[index - pending.size()][0]) if not pending.is_empty() else from
			_ranks[index] = [first, rank]
			entry.callout = _callout(step, pending, lots)
			entry.lots = _lots_of(step.copies[0], lots, step.copies.size())
			# An author's step puts on its own parts with the sub-assembly.
			entry.lots.append_array(_lots_of(step.brick_ids, lots))
			pending.clear()
		else:
			entry.lots = _lots_of(step.brick_ids, lots)
		entries.append(entry)
	return entries


## A callout's own stage — the first copy, in the order its steps build
## it — and its steps as entries.
func _callout(attach: Instructions.Step, built: Array[Instructions.Step],
		lots: Dictionary) -> Booklet.Callout:
	var callout := Booklet.Callout.new()
	callout.name = attach.assembly
	callout.times = attach.times
	var order: Array = []
	var spans: Array = []
	for step: Instructions.Step in built:
		var from: int = order.size() + 1
		for brick_id: int in step.shown_ids:
			order.append(_entry_of(brick_id))
		spans.append([from, order.size()])
	var stage: BookletStudio.Stage = _studio.stage(order)
	_stages.append(stage)
	callout.from = _facing(attach)
	var boxes: Array = []
	for brick_id: int in attach.copies[0]:
		boxes.append(_box(brick_id))
	callout.subject = BookletStudio.extent(boxes, callout.from)
	for at: int in built.size():
		var entry := Booklet.Entry.new()
		entry.number = at + 1
		entry.in_callout = true
		entry.from = callout.from
		entry.subject = callout.subject
		entry.lots = _lots_of(built[at].shown_ids, lots)
		callout.steps.append(entry)
	_callouts[callout] = [stage, spans]
	return callout


## Which way to look at a sub-assembly: as it sits in the model, except a
## figure, which is looked at in the face.
func _facing(attach: Instructions.Step) -> Vector3:
	if not attach.figure:
		return BookletStudio.FRONT
	var bricks: Array = []
	for brick_id: int in attach.copies[0]:
		bricks.append(_world.get_brick(brick_id))
	var frame: Variant = Minifig.frame_of(bricks, library)
	if not (frame is Transform3D):
		return BookletStudio.FRONT
	var facing: Vector3 = (frame as Transform3D).basis.z
	var yaw: float = atan2(facing.x, facing.z)
	return BookletStudio.FRONT.rotated(Vector3.UP, yaw)


## From the front, unless this step's new parts cannot be seen from there
## and can from the back. A real booklet turns the model round with a
## sign, and turns it back with another; so does this, and it stays
## turned while the back is still where the work is.
func _choose_views(entries: Array[Booklet.Entry]) -> void:
	var facing: Vector3 = BookletStudio.FRONT
	var keep: int = _studio.supersample
	_studio.supersample = 1
	var count: int = 0
	for entry: Booklet.Entry in entries:
		count += 1
		if count % 10 == 1:
			_say("Choosing how each step is seen…", entries.size(), count - 1)
		if _stopped():
			return
		var span: Array = _ranks[int(entry.get_meta("step"))]
		var here: float = await _seen(span, facing)
		var other: Vector3 = BookletStudio.BACK if facing == BookletStudio.FRONT \
			else BookletStudio.FRONT
		var turn: bool = false
		var there: float = -1.0
		if here < 0.4:
			there = await _seen(span, other)
			turn = there > here + 0.25
		elif facing == BookletStudio.BACK:
			# Turned round: back to the front as soon as the front shows
			# the work as well.
			there = await _seen(span, other)
			turn = there >= 0.7
		measured.append({"what": "view of step %d" % entry.number, "seen": here,
			"other": there, "turned": turn})
		if turn:
			facing = other
			entry.turned = true
		entry.from = facing
	_studio.supersample = keep


func _seen(span: Array, from: Vector3) -> float:
	var boxes: Array = []
	for rank: int in range(1, int(span[1]) + 1):
		boxes.append(_main.boxes[rank - 1])
	var extent: Rect2 = BookletStudio.extent(boxes, from)
	var size := Vector2i(360, 270)
	var scale: float = minf(size.x * 0.9 / maxf(extent.size.x, 1.0),
		size.y * 0.9 / maxf(extent.size.y, 1.0))
	var view := BookletStudio.View.new(from, extent.get_center(), scale)
	var shot: BookletStudio.Shot = await _studio.shoot(_main, int(span[1]),
		int(span[0]), view, size, true)
	return shot.seen


## What each step's picture must show: the model as it stands, unless the
## model is too big for that to be read — then what is built of the part
## of it the step is in, so far: on a castle, the tower going up and not
## the whole castle. The rest of the model is still drawn round it, and
## fades out at the picture's edges.
##
## "Too big" is the whole finished model not fitting a page at four
## millimetres a stud.
func _subjects(entries: Array[Booklet.Entry]) -> void:
	var area: Vector2 = Booklet.content().size
	var whole: Rect2 = BookletStudio.extent(_main.boxes, BookletStudio.FRONT)
	var fits: bool = minf(area.x / maxf(whole.size.x, 1.0),
		area.y / maxf(whole.size.y, 1.0)) >= 0.2
	var placed: Dictionary = {}
	for entry: Booklet.Entry in entries:
		var span: Array = _ranks[int(entry.get_meta("step"))]
		var key: String = "" if fits else entry.section
		if not placed.has(key):
			placed[key] = []
		for rank: int in range(int(span[0]), int(span[1]) + 1):
			(placed[key] as Array).append(_main.boxes[rank - 1])
		entry.subject = BookletStudio.extent(placed[key], entry.from)
		entry.cropped = not fits


# -- pictures ------------------------------------------------------------------


func _draw(entry: Booklet.Entry) -> void:
	var span: Array = _ranks[int(entry.get_meta("step"))]
	var size: Vector2i = entry.pixels(px_per_mm)
	var view: BookletStudio.View = entry.view(px_per_mm)
	_studio.fade = (5.0 * px_per_mm) if entry.cropped else 0.0
	var shot: BookletStudio.Shot = await _studio.shoot(_main, int(span[1]),
		int(span[0]), view, size)
	_studio.fade = 0.0
	entry.image = _data_uri(shot.image, PAGE_COLOUR)
	_note("step %d" % entry.number, size, shot, entry.free, entry.rect)
	_point_at_small(entry, shot)
	if entry.callout == null:
		return
	var callout: Booklet.Callout = entry.callout
	var stage: BookletStudio.Stage = _callouts[callout][0]
	var spans: Array = _callouts[callout][1]
	if not callout.inline:
		for sub: Booklet.Entry in callout.steps:
			var part: Array = spans[sub.number - 1]
			var sub_size: Vector2i = sub.pixels(px_per_mm)
			var sub_shot: BookletStudio.Shot = await _studio.shoot(stage,
				int(part[1]), int(part[0]), sub.view(px_per_mm), sub_size)
			sub.image = _data_uri(sub_shot.image, CALLOUT_PAGE_COLOUR)
			_note("step %d, %s step %d" % [entry.number, callout.name, sub.number],
				sub_size, sub_shot, sub.free, sub.rect)
	callout.images.clear()
	for index: int in callout.cells.size():
		var part: Array = spans[index] if callout.inline else spans[-1]
		var cell_size := Vector2i(callout.cells[index].size * px_per_mm)
		var cell_shot: BookletStudio.Shot = await _studio.shoot(stage,
			int(part[1]), int(part[0]) if callout.inline else int(part[1]) + 1,
			callout.cell_view(index, px_per_mm), cell_size)
		callout.images.append(_data_uri(cell_shot.image, CALLOUT_COLOUR))
		_note("step %d, %s box %d" % [entry.number, callout.name, index + 1],
			cell_size, cell_shot, Rect2(), callout.cells[index])
	_arrows(entry, view, size)


## A red arrow down onto what the step adds, when that is small enough to
## miss: a flag and a round plate on top of a tower are a few millimetres
## of the page, and a real booklet points at them. Only when what is new
## is in one place — an arrow between two parts points at neither.
func _point_at_small(entry: Booklet.Entry, shot: BookletStudio.Shot) -> void:
	if entry.callout != null or shot.new_rect.size.x <= 0.0:
		return
	var fresh := Rect2(entry.rect.position + shot.new_rect.position / px_per_mm,
		shot.new_rect.size / px_per_mm)
	if fresh.size.x > 14.0 or fresh.size.y > 14.0:
		return
	var tip := Vector2(fresh.get_center().x, fresh.position.y - 1.0)
	var tail: Vector2 = tip - Vector2(0.0, 11.0)
	if tail.y < entry.rect.position.y:
		return
	entry.pointers.append([tail, tip])


## An arrow from the callout box to each copy of the assembly, at the
## middle of where it went, projected through the picture's own camera.
func _arrows(entry: Booklet.Entry, view: BookletStudio.View, size: Vector2i) -> void:
	var step: int = int(entry.get_meta("step"))
	var copies: int = entry.callout.times
	var box: Rect2 = entry.callout.box
	for copy: int in copies:
		var bounds := AABB()
		var first: bool = true
		# The copies' bricks come interleaved step by step; take this
		# copy's own, which the plan lists in Step.copies.
		for rank: int in _copy_ranks(step, copy):
			var b: AABB = _main.boxes[rank - 1]
			bounds = b if first else bounds.merge(b)
			first = false
		if first:
			continue
		var pixel: Vector2 = view.project(bounds.get_center(), Vector2(size))
		var target: Vector2 = entry.rect.position + pixel / px_per_mm
		var path: Array = Booklet.elbow(box, target)
		if path.is_empty():
			continue
		entry.arrows.append(path)


## The ranks on the main stage of copy [param copy]'s bricks.
var _copy_rank_cache: Dictionary = {}


func _copy_ranks(step: int, copy: int) -> Array:
	var key: String = "%d:%d" % [step, copy]
	if _copy_rank_cache.has(key):
		return _copy_rank_cache[key]
	var out: Array = []
	var ids := PackedInt64Array()
	if _attach_copies.has(step) and copy < (_attach_copies[step] as Array).size():
		ids = _attach_copies[step][copy]
	for brick_id: int in ids:
		if _main.number.has(brick_id):
			out.append(int(_main.number[brick_id]))
	_copy_rank_cache[key] = out
	return out


## Step index -> each copy's brick ids, for the attach steps.
var _attach_copies: Dictionary = {}


func _note(what: String, size: Vector2i, shot: BookletStudio.Shot, free: Rect2,
		rect: Rect2) -> void:
	measured.append({"what": what, "size": size, "model": shot.model_rect,
		"new": shot.new_rect, "free": free, "rect": rect,
		"drawn": shot.image != null})


func _cover() -> Booklet.Page:
	var page := Booklet.Page.new()
	page.kind = "cover"
	page.number = 1
	var area := Rect2(Vector2(Booklet.MARGIN, 36.0), Vector2(Booklet.PAGE.x - Booklet.MARGIN * 2.0, 136.0))
	page.pictures.append([await _whole(BookletStudio.FRONT, area, 0.96), area])
	return page


func _finished(number: int) -> Booklet.Page:
	var page := Booklet.Page.new()
	page.kind = "finished"
	page.number = number
	page.progress = 1.0
	var area: Rect2 = Booklet.content()
	area = Rect2(area.position + Vector2(0.0, 12.0), area.size - Vector2(0.0, 12.0))
	var corner := Rect2(Vector2(area.end.x - 70.0, area.end.y - 52.0), Vector2(70.0, 52.0))
	area.size.x -= 40.0
	page.pictures.append([await _whole(BookletStudio.FRONT, area, 0.9), area])
	page.pictures.append([await _whole(BookletStudio.BACK, corner, 0.8), corner])
	return page


## The whole finished model, fitted to [param area].
func _whole(from: Vector3, area: Rect2, fill: float) -> String:
	var extent: Rect2 = BookletStudio.extent(_main.boxes, from)
	var size := Vector2i(area.size * px_per_mm)
	var scale: float = minf(size.x * fill / maxf(extent.size.x, 1.0),
		size.y * fill / maxf(extent.size.y, 1.0))
	scale = minf(scale, Booklet.MOST_SCALE * 1.5 * px_per_mm)
	var view := BookletStudio.View.new(from, extent.get_center(), scale)
	var shot: BookletStudio.Shot = await _studio.shoot(_main, _main.count,
		_main.count + 1, view, size)
	return _data_uri(shot.image, PAGE_COLOUR if from == BookletStudio.FRONT
		and area.size.x > 100.0 else Color.WHITE)


## A picture as a data URI. A step's picture is laid on the colour it
## sits on and kept as a JPEG: a browser printing to PDF passes a JPEG
## through as it is and re-encodes anything else without loss, and the
## castle's booklet saved as a PDF was 360 MB of WebP turned into Flate.
## (Kept with alpha, WebP had made the page itself 96 MB.) A part's
## picture keeps its alpha, in WebP, because it sits on a box.
static func _data_uri(image: Image, on: Color = Color(0, 0, 0, 0)) -> String:
	if image == null:
		return ""
	if on.a > 0.0:
		var page := Image.create(image.get_width(), image.get_height(), false,
			Image.FORMAT_RGBA8)
		page.fill(on)
		page.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		page.convert(Image.FORMAT_RGB8)
		var jpeg: PackedByteArray = page.save_jpg_to_buffer(0.82)
		if not jpeg.is_empty():
			return "data:image/jpeg;base64," + Marshalls.raw_to_base64(jpeg)
		image = page
	var bytes: PackedByteArray = image.save_webp_to_buffer(true, 0.82)
	if not bytes.is_empty():
		return "data:image/webp;base64," + Marshalls.raw_to_base64(bytes)
	return "data:image/png;base64," + Marshalls.raw_to_base64(image.save_png_to_buffer())


## The booklet's Print button's own handler, which only a file opened on
## its own may run (Booklet's header).
const PRINT_INLINE := " onclick=\"print()\""


## In a browser: open the tab the booklet will be shown in, now, while
## the click that asked for it still counts as a click. A page may only
## open a window in answer to one, and the pictures take seconds.
static func open_tab() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		window.brickworksBooklet = window.open('', '_blank');
		if (window.brickworksBooklet) {
			window.brickworksBooklet.document.write(
				'<title>Building instructions</title>' +
				'<p style="font:16px system-ui,sans-serif;margin:40px">' +
				'Drawing your building instructions&hellip;</p>' +
				'<p id="working" style="font:14px system-ui,sans-serif;margin:0 40px;color:#555"></p>');
		}
	""", true)


## Say in the tab opened for the booklet how it is going: that tab is in
## front while the booklet is drawn, and it said only "Drawing your
## building instructions…" for as long as that took.
static func tell_tab(line: String) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		(() => {
			const tab = window.brickworksBooklet;
			const said = tab && !tab.closed && tab.document.getElementById('working');
			if (said) said.textContent = %s;
		})();
	""" % JSON.stringify(line), true)


## Close the tab opened for a booklet that was stopped or came to nothing.
static func close_tab() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		if (window.brickworksBooklet && !window.brickworksBooklet.closed) window.brickworksBooklet.close();
		window.brickworksBooklet = null;
	""", true)


## Put the booklet in the tab opened for it. False when there is none —
## the browser blocked it — and the caller downloads the file instead.
static func fill_tab(html: String) -> bool:
	if not OS.has_feature("web"):
		return false
	var window: JavaScriptObject = JavaScriptBridge.get_interface("window")
	if window == null:
		return false
	var tab: Variant = window.brickworksBooklet
	if tab == null or not (tab is JavaScriptObject):
		return false
	var document: JavaScriptObject = (tab as JavaScriptObject).document
	if document == null:
		return false
	document.open()
	# The tab was opened from the app, so it is under the app's security
	# policy, which runs no inline handler: Print did nothing in a browser
	# (share_flow, 2026-10-12). The app gives the button its click instead;
	# the file the desktop writes keeps its own.
	document.write(html.replace(PRINT_INLINE, ""))
	document.close()
	JavaScriptBridge.eval("""
		(() => {
			const tab = window.brickworksBooklet;
			const button = tab && tab.document.querySelector('.bar button');
			if (button) button.addEventListener('click', () => tab.print());
		})();
	""", true)
	window.brickworksBooklet = null
	return true


## Put an Instructions button on the toolbar, after the button that says
## [param after]: the booklet where people are, not only behind B and a
## command-line switch. Found by its words rather than added in the
## toolbar's own code, which another piece of work owns at the moment;
## the button is the same kind as its neighbours either way.
static func add_button(bar: Node, after: String, action: Callable) -> Button:
	var anchor: Button = _find_button(bar, after)
	var button := Button.new()
	shown_button = button
	button.text = "Instructions"
	button.tooltip_text = ("A printable booklet of how to build this, step by step, "
		+ "the way a set's booklet is laid out")
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	if anchor == null:
		bar.add_child(button)
		return button
	button.add_theme_font_size_override("font_size",
		anchor.get_theme_font_size("font_size"))
	anchor.add_sibling(button)
	return button


static func _find_button(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child: Node in node.get_children():
		var found: Button = _find_button(child, text)
		if found != null:
			return found
	return null
