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
## The booklet's file, a piece at a time as it is drawn: the pieces one
## after another are the file. See [method _make].
signal wrote(piece: String)

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
## The hidden parts' colours (HiddenColours.live_marks): colour code ->
## {label, name, rgb}. Each is shown on the step where its first part goes
## in, and on a callout that builds with it.
var marks: Dictionary = {}

var _studio: BookletStudio
## The steps the booklet was made from, as planned: an entry's "step" meta
## is its index here (the page editor finds a page's steps by it).
var plan: Array[Instructions.Step] = []
## Draw the pictures of only these steps, by number ([method draw_steps]):
## the page being laid out by hand. Empty draws every one.
var only: Dictionary = {}
## The parts those steps add, whose pictures their parts boxes need.
var _wanted_lots: Dictionary = {}
## Lay the pages out and draw nothing ([method lay_out_only]): which steps
## go on which page, read in a moment where the pictures take minutes.
var dry: bool = false
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


## Keep the pieces sent out ([signal wrote]) and answer [method make] with
## the whole file, as a probe wants it; off, [method make] answers with its
## last piece, or "" when it came to nothing, and the file is what was
## sent out (Main._export_booklet writes it as it comes).
var keep_html: bool = true


## The booklet's file, or "" when it came to nothing (see [member keep_html]).
func make(world: BrickWorld, scenery: Dictionary, title: String) -> String:
	busy = true
	var html: String = await _make(world, scenery, title)
	busy = false
	return html


## The booklet's pages as [method make] lays them out, with no picture
## drawn: each step's place, size and look, for the timeline and a session
## (booklet_layout). The steps the booklet turns round by itself are
## decided as it draws them; here they are seen from the front.
func lay_out_only(world: BrickWorld, scenery: Dictionary, title: String) -> Array[Booklet.Page]:
	dry = true
	await _make(world, scenery, title)
	var out: Array[Booklet.Page] = []
	if document != null:
		out = document.pages
	return out


## The booklet's pages of steps with the pictures of steps [param numbers]
## drawn, and no others, their parts' pictures in [member document]'s parts:
## the page editor's (PageEditor), seconds where the whole booklet is
## minutes.
func draw_steps(world: BrickWorld, scenery: Dictionary, title: String,
		numbers: Dictionary) -> Array[Booklet.Page]:
	only = numbers
	await _make(world, scenery, title)
	var out: Array[Booklet.Page] = []
	if document != null:
		out = document.pages
	return out


## The bricks of [param order] on a stage of their own: drawn, or, laying
## out only, their boxes alone, numbered as a drawn one numbers them.
func _stage(order: Array) -> BookletStudio.Stage:
	if not dry:
		return _studio.stage(order)
	var made := BookletStudio.Stage.new()
	for entry: Array in order:
		var part: Lbm.PartMesh = library.mesh_for(str(entry[1]))
		if part == null:
			continue
		made.count += 1
		made.number[int(entry[0])] = made.count
		made.boxes.append((entry[3] as Transform3D) * part.bounds)
	return made


func _make(world: BrickWorld, scenery: Dictionary, title: String) -> String:
	_world = world
	measured.clear()
	_apart.clear()
	# In the author's steps, when the model has them.
	var steps: Array[Instructions.Step] = []
	# Planned and staged with the drawing held (GpuFence) while the booklet's
	# own tab is in front and says how it goes (tell_tab), a person's input
	# still drawn. Nothing is drawn meanwhile but the model again, as it
	# was, and in a browser drawing in software each of those frames is a
	# second: the castle's plan took 23 of them.
	var held: bool = not dry and only.is_empty() and tab_open()
	if held:
		GpuFence.hold()
	if job != null:
		steps = await Instructions.plan_paced(world, library, scenery, {}, job, true)
	else:
		steps = Instructions.plan(world, library, scenery, {}, true)
	if steps.is_empty() or _stopped():
		if held:
			GpuFence.let_go()
		return ""
	plan = steps
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
	if not dry:
		_studio = BookletStudio.new()
		_studio.library = library
		# The parts each step adds outlined, unless its designer said not.
		_studio.mark_new = BookletLooks.highlight_on(world)
		add_child(_studio)
		await get_tree().process_frame

	var order: Array = []
	for step: Instructions.Step in steps:
		for brick_id: int in step.brick_ids:
			order.append(_entry_of(brick_id))
	_main = _stage(order)
	_order = order
	await get_tree().process_frame
	if held:
		GpuFence.let_go()

	document = Booklet.Document.new()
	document.title = title
	# As the timeline and the model's page count them (Instructions.count):
	# two sub-assemblies put on in one step are two entries of one number.
	document.steps = int(Instructions.count(steps)["steps"])
	var stock: Inventory = Inventory.of(world, library, scenery)
	_stock = stock
	document.pieces = stock.pieces
	document.credits = ("Part geometry from the LDraw™ Parts Library, © the LDraw community, "
		+ "CC BY 2.0 and CC BY 4.0. Catalogue data: Rebrickable. LEGO® is a trademark of the LEGO Group of "
		+ "companies which does not sponsor, authorize or endorse this booklet.")
	var pictures: Dictionary = BookletLooks.images(world)
	for name: String in pictures:
		document.images[name] = "data:%s;base64,%s" % [
			"image/png" if name.ends_with(".png") else "image/jpeg", str(pictures[name])]
	_lap("staged")
	if not only.is_empty():
		for step: Instructions.Step in steps:
			if not only.has(step.number):
				continue
			var ids: Array = Array(step.brick_ids)
			for copy: PackedInt64Array in step.copies:
				ids.append_array(Array(copy))
			for brick_id: int in ids:
				var brick: BrickWorld.Brick = world.get_brick(brick_id)
				if brick != null:
					_wanted_lots[stock.key_of(brick)] = true
	# The whole booklet goes out as it is drawn ([signal wrote]): the cover
	# first, which is the finished model and needs nothing else, then each
	# page as soon as its pictures are, so the first are read while the last
	# are drawn. The parts' pictures come after the cover, in a stylesheet
	# of their own.
	var cover: Booklet.Page = null
	if not dry and only.is_empty():
		cover = await _cover()
		_emit(Booklet.head(document, false))
		_emit(Booklet.page_html(cover, document))
		_lap("cover")
	var lots: Dictionary = await _part_pictures(stock)
	_lap("parts drawn")
	if _stopped():
		return _forget_all()
	if cover != null:
		_emit(Booklet.parts_style(document))

	var entries: Array[Booklet.Entry] = _entries(steps, lots)
	_find_apart(entries)
	var layout := Booklet.Layout.new(entries, 2,
		int(BookletLooks.booklet(world).get("per_page", 0)))
	var pages: Array[Booklet.Page] = []
	var decided: int = 0
	var drawn: int = 0
	while not layout.done():
		# The views of the steps the next page may take, a few at a time: the
		# first page is drawn after its own steps are seen, not the booklet's.
		while decided < layout.reach():
			var upto: int = mini(entries.size(), decided + (BookletStudio.LANES
				if decided == 0 else 48))
			await _choose_views(entries, decided, upto)
			if _stopped():
				await _soon(Callable(), 1)
				await _keep_up(0)
				return _forget_all()
			_subjects(entries, decided, upto)
			decided = upto
		# A step's callout's own pages come before its page, and their
		# pictures are drawn with the step's: so they go out together, after.
		var some: Array[Booklet.Page] = layout.next()
		for page: Booklet.Page in some:
			pages.append(page)
			for entry: Booklet.Entry in page.entries:
				_adds(entry)
			if dry:
				continue
			for entry: Booklet.Entry in page.entries:
				# A callout too big to sit beside its step has pages of its own
				# (Booklet._callout_pages), and its steps are drawn with the step
				# it belongs to (_draw, from its callout's stage). Drawn here as
				# well, as a step of the model's own, they had no rank on the
				# main stage and stopped the booklet with a script error (8022
				# Tow Truck, 2026-10-16).
				if entry.in_callout or not only.is_empty() and not only.has(entry.number):
					continue
				drawn += 1
				if drawn % 5 == 1:
					_say("Drawing the steps…", entries.size(), drawn - 1)
				if _stopped():
					await _soon(Callable(), 1)
					await _keep_up(0)
					return _forget_all()
				await _soon(_draw.bind(entry))
		for page: Booklet.Page in some if cover != null else []:
			_soon_then(func() -> void: _emit(Booklet.page_html(page, document)))
	await _soon(Callable(), 1)
	await _keep_up(0)
	_lap("steps drawn")
	if dry or not only.is_empty():
		document.pages = pages
		_forget_all()
		return ""
	document.pages.append(cover)
	document.pages.append_array(pages)
	var finished: Booklet.Page = await _finished(pages.size() + 2)
	document.pages.append(finished)
	document.lots = _inventory(stock, lots)
	document.pages.append_array(Booklet.parts_pages(document.lots, finished.number + 1))

	_forget_all()
	_say("Writing the booklet…", 0)
	for page: Booklet.Page in document.pages.slice(pages.size() + 1):
		_emit(Booklet.page_html(page, document))
	_emit(Booklet.TAIL, "")
	_lap("written")
	if keep_html:
		return "".join(_written)
	return Booklet.TAIL


## Send [param text] out ([signal wrote]), and keep it for [method make]'s
## answer when [member keep_html]: the booklet's pieces, each followed by
## [param then].
func _emit(text: String, then: String = "\n") -> void:
	if keep_html:
		_written.append(text + then)
	wrote.emit(text + then)


var _written := PackedStringArray()


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
	if is_instance_valid(_studio):
		for made: BookletStudio.Stage in _stages:
			_studio.forget(made)
		if _main != null:
			_studio.forget(_main)
	_stages.clear()
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
			await _soon(Callable(), 1)
			await _keep_up(0)
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
		var extent: Rect2 = BookletStudio.extent([part.bounds], BookletStudio.FRONT)
		made.size = Booklet.part_size(extent.size)
		if dry or not only.is_empty() and not _wanted_lots.has(key):
			made.size += Vector2(1.0, 1.0)
			_soon_then(func() -> void: lots[key] = made)
			continue
		await _soon(_part_picture.bind(lot, made, extent, lots))
	await _soon(Callable(), 1)
	await _keep_up(0)
	return lots


## The picture of [param lot]'s part, into the parts' pictures ([param lots]
## and the document's), the work done with it put in [param into].
func _part_picture(into: Array, lot: Inventory.Lot, made: Booklet.Lot, extent: Rect2,
		lots: Dictionary) -> void:
	var key: String = made.key
	var stage: BookletStudio.Stage = _studio.stage(
		[[0, lot.part_id, lot.color_code, Transform3D.IDENTITY]])
	# Twice the page's resolution: a part is small on the page and
	# read closely.
	var pixels: Vector2i = Vector2i((made.size + Vector2(1.0, 1.0)) * px_per_mm * 2.0)
	var scale: float = (made.size.x / maxf(extent.size.x, 0.1)) * px_per_mm * 2.0
	var view := BookletStudio.View.new(BookletStudio.FRONT, extent.get_center(), scale)
	var shot: BookletStudio.Shot = await _studio.shoot(stage, 1, 2, view, pixels,
		_encoded.bind(Color(0, 0, 0, 0)))
	_studio.forget(stage)
	made.size += Vector2(1.0, 1.0)
	_later([shot], func() -> void:
		document.parts[key] = _uri(shot)
		lots[key] = made, into)


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
		# A section's hidden colour goes where the section starts: its
		# banner (Booklet.lay_out puts one on the step that starts it).
		if not marks.is_empty() and step.section != _section:
			_section = step.section
			var said: String = _section.capitalize() if _section.begins_with("part ") \
				else _section
			# A group joined from several sections shows in each one's banner.
			var here: Dictionary = {}
			for mark: Dictionary in marks.values():
				var label: String = str(mark["label"])
				if here.has(label) or not said in (mark.get("sections", [label]) as Array):
					continue
				here[label] = true
				_marked[label] = true
				entry.marks.append(mark)
		if step.unsupported:
			entry.note = "Hold this in place: it rests on nothing until the next step."
		var own: Dictionary = _look(entry, step)
		if step.attaches():
			var first: int = int(_ranks[index - pending.size()][0]) if not pending.is_empty() else from
			_ranks[index] = [first, rank]
			entry.callout = _callout(step, pending, lots, index - pending.size())
			entry.lots = _lots_of(step.copies[0], lots, step.copies.size())
			# An author's step puts on its own parts with the sub-assembly.
			entry.lots.append_array(_lots_of(step.brick_ids, lots))
			if not marks.is_empty():
				var built: PackedInt64Array = step.brick_ids.duplicate()
				for one: Instructions.Step in pending:
					built.append_array(one.brick_ids)
				entry.callout.marks = _marks_in(built, {})
				entry.marks.append_array(_marks_in(built, _marked))
			pending.clear()
		else:
			entry.lots = _lots_of(step.brick_ids, lots)
			if not marks.is_empty():
				entry.marks.append_array(_marks_in(step.brick_ids, _marked))
		if own.has("parts") and not bool(own["parts"]):
			entry.lots.clear()
		entries.append(entry)
	return entries


## The look its designer gave [param step] (BookletLooks), put on [param
## entry]: the view, the zoom, the size and the page. Returns the step's
## own look, {} for a step worked out here.
func _look(entry: Booklet.Entry, step: Instructions.Step) -> Dictionary:
	if step.authored_step < 0:
		return {}
	var section: String = step.authored_in
	var own: Dictionary = BookletLooks.of(_world, section, step.authored_step)
	entry.look = BookletLooks.key(BookletLooks.definition_of(section), step.authored_step)
	entry.zoom = clampf(float(own.get("zoom", 1.0)), 0.25, 4.0)
	entry.size = clampf(float(own.get("size", 1.0)), 0.4, 3.0)
	entry.page_break = str(own.get("page", ""))
	_hand_look(entry, step)
	entry.sign_off = not bool(own.get("sign", true))
	var turn: Dictionary = BookletLooks.turn_at(_world, section, step.authored_step)
	if not turn.is_empty():
		entry.fixed = true
		entry.from = BookletLooks.direction(turn)
	return own


## What its designer placed on [param step]'s page (BookletLooks "place",
## "notes", "arrows" and the room they were placed in), put on [param entry].
func _hand_look(entry: Booklet.Entry, step: Instructions.Step) -> void:
	if step.authored_step < 0:
		return
	var own: Dictionary = BookletLooks.of(_world, step.authored_in, step.authored_step)
	entry.look = BookletLooks.key(BookletLooks.definition_of(step.authored_in), step.authored_step)
	entry.place = own.get("place", {})
	entry.notes = own.get("notes", [])
	entry.drawn_arrows = own.get("arrows", [])
	entry.room = BookletLooks.rect_of(own["panel"]) if own.has("panel") else Rect2()


## The groups whose hidden colour has gone in by now, by label, and the
## section the steps are in.
var _marked: Dictionary = {}
var _section: String = ""


## The marks of the hidden colours [param ids] are in, each group once;
## those in [param shown] already are left out, and the rest added to it.
func _marks_in(ids: PackedInt64Array, shown: Dictionary) -> Array:
	var out: Array = []
	var here: Dictionary = {}
	for brick_id: int in ids:
		var brick: BrickWorld.Brick = _world.get_brick(brick_id)
		if brick == null or not marks.has(brick.color_code):
			continue
		var mark: Dictionary = marks[brick.color_code]
		var label: String = str(mark["label"])
		if shown.has(label) or here.has(label):
			continue
		here[label] = true
		out.append(mark)
	for label: String in here:
		shown[label] = true
	return out


## A callout's own stage — the first copy, in the order its steps build
## it — and its steps as entries.
func _callout(attach: Instructions.Step, built: Array[Instructions.Step],
		lots: Dictionary, first: int = -1) -> Booklet.Callout:
	var callout := Booklet.Callout.new()
	callout.name = attach.assembly
	callout.times = attach.times
	var unit: String = BookletLooks.attached(_world, attach, attach.authored_in)
	callout.own_pages = not unit.is_empty() and not BookletLooks.callout_on(_world, unit)
	var order: Array = []
	var spans: Array = []
	for step: Instructions.Step in built:
		var from: int = order.size() + 1
		for brick_id: int in step.shown_ids:
			order.append(_entry_of(brick_id))
		spans.append([from, order.size()])
	var stage: BookletStudio.Stage = _stage(order)
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
		if first >= 0:
			entry.set_meta("step", first + at)
		# Laid out by hand when it has pages of its own: what its designer
		# placed on its page, as a step of the model's (the rest of the
		# step's look, a turn or a zoom, is the callout's own).
		_hand_look(entry, built[at])
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
##
## For [param entries] from [param from] up to [param upto], after those
## before them: the pages are laid out and drawn as the views are chosen,
## so the first is read while the last are still to be seen (_make).
func _choose_views(entries: Array[Booklet.Entry], from: int, upto: int) -> void:
	if dry:
		for index: int in range(from, upto):
			var entry: Booklet.Entry = entries[index]
			if not entry.fixed:
				entry.from = BookletStudio.FRONT
			_sign(entry, index > 0 and _round_from(_before, entry.from))
			_before = entry.from
		return
	var last: int = -1
	for number: Variant in only:
		last = maxi(last, int(number))
	# Every step is measured from the front: from there when it is seen from
	# the front, and to turn back to when it is turned round. So all of them
	# are, first, many at once (BookletStudio.measure_all), and from the back
	# those the front shows too little of; the rest from the back as the
	# walk below comes to them. The walk is the one it was, step by step.
	var asks: Array = []
	var keys: Array = []
	for index: int in range(from, upto):
		var entry: Booklet.Entry = entries[index]
		if entry.fixed or last >= 0 and entry.number > last:
			continue
		asks.append(_ask(_where(entry), BookletStudio.FRONT))
		keys.append([entry, BookletStudio.FRONT])
	await _measure(asks, keys, _seen)
	if _stopped():
		return
	asks.clear()
	keys.clear()
	for index: int in range(from, upto):
		var entry: Booklet.Entry = entries[index]
		if float(_seen.get([entry, BookletStudio.FRONT], 1.0)) < 0.4:
			asks.append(_ask(_where(entry), BookletStudio.BACK))
			keys.append([entry, BookletStudio.BACK])
	await _measure(asks, keys, _seen)
	for index: int in range(from, upto):
		var entry: Booklet.Entry = entries[index]
		if _stopped():
			return
		# Past the steps being drawn: seen as laid out, from the front.
		if last >= 0 and entry.number > last:
			if not entry.fixed:
				entry.from = BookletStudio.FRONT
			continue
		# Seen the way its designer set it: turned where the turn is more
		# than a glance round from the step before.
		if entry.fixed:
			# The first step is where the reader starts: nothing to turn from.
			_sign(entry, index > 0 and _round_from(_before, entry.from))
			_before = entry.from
			_turned_to = BookletStudio.FRONT
			measured.append({"what": "view of step %d" % entry.number, "seen": -1.0,
				"other": -1.0, "turned": entry.turned, "fixed": true})
			continue
		var other: Vector3 = BookletStudio.BACK if _turned_to == BookletStudio.FRONT \
			else BookletStudio.FRONT
		var here: float = await _seen_from(entry, _turned_to)
		var turn: bool = false
		var there: float = -1.0
		if here < 0.4:
			there = await _seen_from(entry, other)
			turn = there > here + 0.25
		elif _turned_to == BookletStudio.BACK:
			# Turned round: back to the front as soon as the front shows
			# the work as well.
			there = await _seen_from(entry, other)
			turn = there >= 0.7
		measured.append({"what": "view of step %d" % entry.number, "seen": here,
			"other": there, "turned": turn})
		if turn:
			_turned_to = other
		entry.from = _turned_to
		_sign(entry, turn or _round_from(_before, entry.from))
		_before = entry.from


## Where the walk of [method _choose_views] has got to: the way the model
## faces, the view of the step before, and every measure so far, by
## [entry, from].
var _turned_to: Vector3 = BookletStudio.FRONT
var _before: Vector3 = BookletStudio.FRONT
var _seen: Dictionary = {}


## How much of [param entry]'s new parts [param from] shows: as measured
## already, or measured now.
func _seen_from(entry: Booklet.Entry, from: Vector3) -> float:
	if not _seen.has([entry, from]):
		await _measure([_ask(_where(entry), from)], [[entry, from]], _seen)
	return float(_seen.get([entry, from], -1.0))


## Measure [param asks] (BookletStudio.measure_all), a few frames' worth at
## a time, into [param seen] under [param keys].
func _measure(asks: Array, keys: Array, seen: Dictionary) -> void:
	const AT_ONCE := 48
	for from: int in range(0, asks.size(), AT_ONCE):
		if _stopped():
			return
		var some: Array = await _studio.measure_all(asks.slice(from, from + AT_ONCE))
		for index: int in some.size():
			seen[keys[from + index]] = some[index]


## What [method BookletStudio.measure_all] is asked for how much of a
## step's new parts [param from] shows: [param where] as [method _where]
## gives it.
func _ask(where: Array, from: Vector3) -> Array:
	var stage: BookletStudio.Stage = where[0]
	var extent: Rect2 = _extent_upto(stage, int(where[2]), from)
	var size := Vector2i(360, 270)
	var scale: float = minf(size.x * 0.9 / maxf(extent.size.x, 1.0),
		size.y * 0.9 / maxf(extent.size.y, 1.0))
	var view := BookletStudio.View.new(from, extent.get_center(), scale)
	return [stage, int(where[2]), int(where[1]), view, size]


## BookletStudio.extent of the first [param upto] boxes of [param stage]
## from [param from], read off the extents of every first so many, worked
## out once: each in turn over all the boxes before it was a castle's 400
## steps times its 2,500 boxes.
func _extent_upto(stage: BookletStudio.Stage, upto: int, from: Vector3) -> Rect2:
	var key: Array = [stage, from]
	if not _prefixes.has(key):
		var turn: Basis = BookletStudio.basis_for(from)
		var lows := PackedVector2Array()
		var highs := PackedVector2Array()
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		lows.append(low)
		highs.append(high)
		# The corners as BookletStudio.extent takes them, so the answer is its
		# to the last bit.
		for box: AABB in stage.boxes:
			for n: int in 8:
				var corner: Vector3 = box.position + Vector3(
					box.size.x if n & 1 else 0.0,
					box.size.y if n & 2 else 0.0,
					box.size.z if n & 4 else 0.0)
				var at := Vector2(corner.dot(turn.x), corner.dot(turn.y))
				low = low.min(at)
				high = high.max(at)
			lows.append(low)
			highs.append(high)
		_prefixes[key] = [lows, highs]
	var both: Array = _prefixes[key]
	var at: int = clampi(upto, 0, stage.boxes.size())
	var low: Vector2 = (both[0] as PackedVector2Array)[at]
	var high: Vector2 = (both[1] as PackedVector2Array)[at]
	if low.x > high.x:
		return Rect2()
	return Rect2(low, high - low)


## Stage and view -> the extents of its first so many boxes ([method
## _extent_upto]).
var _prefixes: Dictionary = {}


## The turn sign on [param entry] where it is [param due], unless its
## designer took it off (BookletLooks "sign"); [member Booklet.Entry
## .sign_off] then says it was due and is off, for the page editor to offer
## it back.
static func _sign(entry: Booklet.Entry, due: bool) -> void:
	var off: bool = entry.sign_off
	entry.turned = due and not off
	entry.sign_off = due and off
	if not due:
		entry.sign_off = false


## How far round, and how far up or down, the view may move from one step
## to the next before the builder is told to turn the model: past these, a
## LEGO booklet shows its turn sign, and so does this one.
const TURN_ROUND := 60.0
const TURN_OVER := 45.0


## Whether a step seen from [param to] after one seen from [param from] is
## the model turned: more than TURN_ROUND degrees round, or more than
## TURN_OVER degrees up or down (turned over, to work underneath).
static func _round_from(from: Vector3, to: Vector3) -> bool:
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	if from.length() < 0.01 or to.length() < 0.01:
		return false
	var pitch: float = absf(asin(clampf(to.normalized().y, -1.0, 1.0))
		- asin(clampf(from.normalized().y, -1.0, 1.0)))
	if pitch > deg_to_rad(TURN_OVER):
		return true
	if a.length() < 0.01 or b.length() < 0.01:
		return false
	return absf(a.angle_to(b)) > deg_to_rad(TURN_ROUND)


## The stage a step is drawn on and its new parts' ranks there: [stage,
## from, upto]. The model's, or a section's own ([method _find_apart]).
func _where(entry: Booklet.Entry) -> Array:
	var span: Array = _ranks[int(entry.get_meta("step"))]
	if _apart.has(entry):
		var before: int = int(_apart[entry][1])
		return [_apart[entry][0], int(span[0]) - before, int(span[1]) - before]
	return [_main, int(span[0]), int(span[1])]


## The model's bricks in the order they go in, as the main stage has them.
var _order: Array = []
## Steps drawn on a stage of their own: entry -> [stage, the ranks before it].
var _apart: Dictionary = {}


## A section that touches nothing built before it is a new thing, and its
## steps are drawn on their own, as a real booklet draws a second vehicle,
## until the build moves on: 7636 Combine Harvester's harvester began as an
## axle plate drawn in the air over the hay bales and the farmer built
## before it (docs/INSTRUCTIONS.md). What it touches is read off the parts'
## boxes, grown by a hair.
func _find_apart(entries: Array[Booklet.Entry]) -> void:
	_grid.clear()
	_gridded = 0
	var at: int = 0
	while at < entries.size():
		var first: Booklet.Entry = entries[at]
		var end: int = at
		while end + 1 < entries.size() and entries[end + 1].section == first.section:
			end += 1
		var from: int = int(_ranks[int(first.get_meta("step"))][0])
		var upto: int = int(_ranks[int(entries[end].get_meta("step"))][1])
		if not first.section.is_empty() and from > 1 and upto >= from \
				and not _touches(from, upto):
			var stage: BookletStudio.Stage = _stage(_order.slice(from - 1, upto))
			_stages.append(stage)
			for n: int in range(at, end + 1):
				_apart[entries[n]] = [stage, from - 1]
		at = end + 1


## Whether the bricks ranked [param from] to [param upto] touch any ranked
## before them. The bricks before are put in a grid as the sections go on,
## each once: a grid of every brick before each section, made afresh, was
## 0.3 s of the castle's window held still.
func _touches(from: int, upto: int) -> bool:
	const CELL := 40.0
	if from <= _gridded:
		_grid.clear()
		_gridded = 0
	for rank: int in range(_gridded + 1, from):
		var box: AABB = (_main.boxes[rank - 1] as AABB).grow(1.0)
		for cell: Vector3i in _cells_of(box, CELL):
			if not _grid.has(cell):
				_grid[cell] = []
			(_grid[cell] as Array).append(box)
	_gridded = from - 1
	for rank: int in range(from, upto + 1):
		var box: AABB = _main.boxes[rank - 1]
		for cell: Vector3i in _cells_of(box, CELL):
			for other: AABB in _grid.get(cell, []):
				if other.intersects(box):
					return true
	return false


## The bricks ranked up to [member _gridded] by the cells they are in, for
## [method _touches].
var _grid: Dictionary = {}
var _gridded: int = 0


static func _cells_of(box: AABB, size: float) -> Array[Vector3i]:
	var out: Array[Vector3i] = []
	for x: int in range(floori(box.position.x / size), floori(box.end.x / size) + 1):
		for y: int in range(floori(box.position.y / size), floori(box.end.y / size) + 1):
			for z: int in range(floori(box.position.z / size), floori(box.end.z / size) + 1):
				out.append(Vector3i(x, y, z))
	return out


## What each step's picture must show: the model as it stands, unless the
## model is too big for that to be read — then what is built of the part
## of it the step is in, so far: on a castle, the tower going up and not
## the whole castle. The rest of the model is still drawn round it, and
## fades out at the picture's edges.
##
## "Too big" is the whole finished model not fitting a page at four
## millimetres a stud.
##
## For [param entries] from [param from] up to [param upto], after those
## before them, as [method _choose_views].
func _subjects(entries: Array[Booklet.Entry], from: int, upto: int) -> void:
	if from == 0:
		var area: Vector2 = Booklet.content().size
		var whole: Rect2 = BookletStudio.extent(_main.boxes, BookletStudio.FRONT)
		_fits = minf(area.x / maxf(whole.size.x, 1.0),
			area.y / maxf(whole.size.y, 1.0)) >= 0.2
		_placed.clear()
	var fits: bool = _fits
	var placed: Dictionary = _placed
	for index: int in range(from, upto):
		var entry: Booklet.Entry = entries[index]
		var span: Array = _ranks[int(entry.get_meta("step"))]
		var key: String = "" if fits else entry.section
		if not placed.has(key):
			placed[key] = []
		for rank: int in range(int(span[0]), int(span[1]) + 1):
			(placed[key] as Array).append(_main.boxes[rank - 1])
		entry.subject = BookletStudio.extent(placed[key], entry.from)
		entry.cropped = not fits
		if _apart.has(entry):
			var where: Array = _where(entry)
			entry.subject = BookletStudio.extent(
				(where[0] as BookletStudio.Stage).boxes.slice(0, int(where[2])), entry.from)
			entry.cropped = false
		_zoomed(entry)


## Whether the whole model fits a page, and each section's boxes so far:
## see [method _subjects].
var _fits: bool = true
var _placed: Dictionary = {}


## A step its designer zoomed: in, framed on what it adds, the rest of the
## model running off the picture and faded; out, more of the page round it.
func _zoomed(entry: Booklet.Entry) -> void:
	if is_equal_approx(entry.zoom, 1.0):
		return
	var where: Array = _where(entry)
	var stage: BookletStudio.Stage = where[0]
	var fresh: Rect2 = BookletStudio.extent(stage.boxes.slice(int(where[1]) - 1, int(where[2])),
		entry.from)
	var whole: Rect2 = entry.subject
	var size: Vector2 = whole.size / entry.zoom
	var centre: Vector2 = whole.get_center()
	if entry.zoom > 1.0:
		if fresh.size.length() > 0.0:
			centre = fresh.get_center()
		centre.x = clampf(centre.x, whole.position.x + size.x * 0.5, whole.end.x - size.x * 0.5)
		centre.y = clampf(centre.y, whole.position.y + size.y * 0.5, whole.end.y - size.y * 0.5)
		entry.cropped = true
	entry.subject = Rect2(centre - size * 0.5, size)


## Where the parts a step adds are on its page, in mm: their boxes projected
## through the picture's own camera, cut to the picture. What a session
## points an arrow at (booklet_layout): one drew its arrow onto the middle of
## a step's picture, reckoned from the zoom, and it pointed at the seat
## beside the steering wheel it meant.
func _adds(entry: Booklet.Entry) -> void:
	entry.adds = Rect2()
	if entry.in_callout or entry.rect.size.x <= 0.0 or not entry.has_meta("step") \
			or not _ranks.has(int(entry.get_meta("step"))):
		return
	var where: Array = _where(entry)
	var stage: BookletStudio.Stage = where[0]
	# At a pixel a millimetre, the picture's pixels are the page's mm.
	var view: BookletStudio.View = entry.view(1.0)
	var seen := Rect2()
	var first: bool = true
	for rank: int in range(int(where[1]), int(where[2]) + 1):
		if rank < 1 or rank > stage.boxes.size():
			continue
		var box: AABB = stage.boxes[rank - 1]
		for corner: int in 8:
			var point: Vector2 = view.project(box.get_endpoint(corner), entry.rect.size)
			seen = Rect2(point, Vector2.ZERO) if first else seen.expand(point)
			first = false
	if first:
		return
	seen.position += entry.rect.position
	entry.adds = seen.intersection(entry.rect)


# -- pictures ------------------------------------------------------------------


## The pictures of [param entry], and of its callout: each drawn here, and
## what is made of it put in place once its worker is done (_later, into
## [param into]), in the order they were drawn.
func _draw(into: Array, entry: Booklet.Entry) -> void:
	var where: Array = _where(entry)
	var size: Vector2i = entry.pixels(px_per_mm)
	var view: BookletStudio.View = entry.view(px_per_mm)
	# Clear behind the model on a page laid out by hand, where a thing may sit
	# in the picture's box and must not be painted over.
	var shot: BookletStudio.Shot = await _studio.shoot(where[0], int(where[2]),
		int(where[1]), view, size,
		_encoded.bind(Color(0, 0, 0, 0) if entry.clear else PAGE_COLOUR),
		(5.0 * px_per_mm) if entry.cropped else 0.0)
	_later([shot], func() -> void:
		entry.image = _uri(shot)
		_note("step %d" % entry.number, size, shot, entry.free, entry.rect)
		# Where the new parts were laid out to be (booklet_layout), and where the
		# picture drew them, for a probe to hold the one to the other.
		if shot.new_rect.size.x > 0.0:
			measured.append({"what": "new parts of step %d" % entry.number, "laid": entry.adds,
				"drawn": Rect2(entry.rect.position + shot.new_rect.position / px_per_mm,
					shot.new_rect.size / px_per_mm)})
		_point_at_small(entry, shot), into)
	if entry.callout != null:
		var callout: Booklet.Callout = entry.callout
		var stage: BookletStudio.Stage = _callouts[callout][0]
		var spans: Array = _callouts[callout][1]
		if not callout.inline:
			for sub: Booklet.Entry in callout.steps:
				var part: Array = spans[sub.number - 1]
				var sub_size: Vector2i = sub.pixels(px_per_mm)
				var sub_shot: BookletStudio.Shot = await _studio.shoot(stage,
					int(part[1]), int(part[0]), sub.view(px_per_mm), sub_size,
					_encoded.bind(Color(0, 0, 0, 0) if sub.clear else CALLOUT_PAGE_COLOUR))
				_later([sub_shot], func() -> void:
					sub.image = _uri(sub_shot)
					_note("step %d, %s step %d" % [entry.number, callout.name, sub.number],
						sub_size, sub_shot, sub.free, sub.rect), into)
		_later([], func() -> void: callout.images.clear(), into)
		for index: int in callout.cells.size():
			var part: Array = spans[index] if callout.inline else spans[-1]
			var cell_size := Vector2i(callout.cells[index].size * px_per_mm)
			var cell_shot: BookletStudio.Shot = await _studio.shoot(stage,
				int(part[1]), int(part[0]) if callout.inline else int(part[1]) + 1,
				callout.cell_view(index, px_per_mm), cell_size,
				_encoded.bind(CALLOUT_COLOUR))
			_later([cell_shot], func() -> void:
				callout.images.append(_uri(cell_shot))
				_note("step %d, %s box %d" % [entry.number, callout.name, index + 1],
					cell_size, cell_shot, Rect2(), callout.cells[index]), into)
		_arrows(entry, view, size)


## Pictures drawn and still with their workers, each with what is to be done
## with it once they are done: [[shots], Callable], oldest first.
var _pending: Array = []


func _later(shots: Array, then: Callable, into: Array) -> void:
	into.append([shots, then])


## Pictures being drawn alongside each other, as many as the studio has
## lanes (BookletStudio.shoot): each [method _soon]'s work, whether it is
## done, and what is to be done with its pictures, in the order it was
## asked for: {"done", "later": [[shots], Callable], ...}.
var _going: Array = []


## Set [param work] (Array -> nothing, the work to be done with its
## pictures put in the Array) going alongside what is going already, once
## fewer than [param most] are (the studio's lanes, unless said); work done
## at the front handed on to _pending, in order, and what the workers have
## done with it put in place. No work, only the waiting: [code]_soon(
## Callable(), 1)[/code] is until all of it is done.
func _soon(work: Callable, most: int = BookletStudio.PICTURE_LANES) -> void:
	while true:
		while not _going.is_empty() and bool(_going[0]["done"]):
			_pending.append_array(_going.pop_front()["later"])
		var busy: int = 0
		for one: Dictionary in _going:
			if not bool(one["done"]):
				busy += 1
		if busy < most:
			break
		await get_tree().process_frame
	await _keep_up()
	if not work.is_valid():
		return
	var one: Dictionary = {"done": false, "later": []}
	_going.append(one)
	_run_soon.call(work, one)


func _run_soon(work: Callable, one: Dictionary) -> void:
	await work.call(one["later"])
	one["done"] = true


## [param then] done once all asked for before it is.
func _soon_then(then: Callable) -> void:
	_going.append({"done": true, "later": [[[], then]]})


## Put in place what the workers have done, oldest first, until no more than
## [param most] are left: a castle's pictures drawn ahead of their workers
## are megabytes each, so only so many are let wait.
func _keep_up(most: int = -1) -> void:
	if most < 0:
		most = maxi(4, OS.get_processor_count())
	while _pending.size() > most:
		var next: Array = _pending.pop_front()
		for shot: BookletStudio.Shot in next[0]:
			await _studio.finished(shot)
		(next[1] as Callable).call()


## What a worker made of [param shot]: its data URI, or "" for a picture
## that was not drawn.
static func _uri(shot: BookletStudio.Shot) -> String:
	return str(shot.made) if shot.made is String else ""


## On a worker: a picture as [method _data_uri] has it, laid on [param on].
static func _encoded(image: Image, on: Color) -> String:
	return _data_uri(image, on)


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
		_main.count + 1, view, size, _encoded.bind(PAGE_COLOUR
			if from == BookletStudio.FRONT and area.size.x > 100.0 else Color.WHITE))
	await _studio.finished(shot)
	return _uri(shot)


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


## Whether the tab opened for the booklet is there, in a browser.
static func tab_open() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval(
		"!!(window.brickworksBooklet && !window.brickworksBooklet.closed)", true))


## Close the tab opened for a booklet that was stopped or came to nothing.
static func close_tab() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		if (window.brickworksBooklet && !window.brickworksBooklet.closed) window.brickworksBooklet.close();
		window.brickworksBooklet = null;
	""", true)


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
