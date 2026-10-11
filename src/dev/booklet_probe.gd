## Does the booklet read like a booklet?
##
##   godot --path . --resolution 1200x800 --script src/dev/booklet_probe.gd
##
## Needs a window: every picture in it is drawn (BookletStudio), and a
## headless run has nothing to draw with. Leaves the booklets it made in
## shots/booklet/ to open and look at, which is the real test.
##
## The booklet it replaced passed every check that existed: it had a
## picture for every step and a line of parts under it. Each picture was
## of the whole 32 x 32 baseplate with the model small in the middle, the
## parts were words, and nothing in it was built on the side. So this
## asks what a reader would:
##
##   is each step's picture of the model — the model filling the space
##   it is given, the new parts inside the picture and in view?
##   does each step have a parts box with a picture of every part, and
##   do the counts in it add up to what the step adds?
##   is a sub-assembly built in a callout, "2x" for two, with an arrow to
##   each copy? a figure in its own callout?
##   when a step's parts are behind the model, is it turned round?
##   does the timeline number its steps as the booklet does?
##   does every page fit its sheet (Booklet.PAGE inside A4 and Letter)?
extends SceneTree

var _failures: int = 0
var _library: PartLibrary


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/booklet"))

	_assert("a page fits landscape A4 and Letter with 5 mm to spare",
		Booklet.PAGE.x + 10.0 <= 279.4 and Booklet.PAGE.y + 10.0 <= 210.0)

	await _shed()
	await _house()
	await _turned()
	await _the_button()

	print("")
	print("%d failed" % _failures if _failures else "the booklet reads like a booklet")
	quit(1 if _failures else 0)


## The shed of instructions_probe: two windows from one sub-model and a
## figure. Callouts, "2x", arrows, and the timeline's numbers.
func _shed() -> void:
	var world: BrickWorld = _world_of(LdrModel.parse(_SHED, "shed.ldr"))
	var made: Array = await _make(world, "shed")
	var maker: BookletMaker = made[0]
	var html: String = made[1]
	print("\n  a shed with two windows and a figure")
	_pictures("shed", maker)
	_parts_boxes("shed", maker, html)
	var windows: Booklet.Callout = null
	var figure: Booklet.Callout = null
	var attach: Booklet.Entry = null
	for entry: Booklet.Entry in _entries(maker):
		if entry.callout == null:
			continue
		if entry.callout.times == 2:
			windows = entry.callout
			attach = entry
		else:
			figure = entry.callout
	_assert("the windows are built in a callout, 2x", windows != null)
	if windows != null:
		_assert("...with a picture for each of its steps (%d of %d)" % [
			windows.images.size(), windows.cells.size()],
			windows.cells.size() >= 1 and windows.images.size() == windows.cells.size()
			and Array(windows.images).all(func(uri: String) -> bool: return uri.length() > 100))
		_assert("...and an arrow to each window (%d)" % attach.arrows.size(),
			attach.arrows.size() == 2)
		var inside: bool = true
		for arrow: Array in attach.arrows:
			inside = inside and attach.rect.has_point(arrow[1])
		_assert("...that ends on the step's picture", inside)
		_assert("...and \"2x\" printed on the box", html.contains(">2x</div>"))
	_assert("the figure is built in a callout of its own", figure != null
		and figure.images.size() == 1)

	# The timeline steps through the same numbers the pages print.
	var printed: Dictionary = {}
	for entry: Booklet.Entry in _entries(maker):
		printed[entry.number] = true
	var bar := StepsBar.new()
	root.add_child(bar)
	await process_frame
	bar.start(world, _library)
	var said: Dictionary = {}
	for _n: int in 40:
		var caption: String = bar._caption.text
		said[int(caption.get_slice(" ", 1))] = caption
		bar.step_forward()
	bar.stop()
	bar.queue_free()
	_assert("the timeline numbers its steps as the booklet does (%s against %s)" % [
		str(said.keys()), str(printed.keys())],
		said.keys().all(func(number: int) -> bool: return printed.has(number))
		and printed.keys().all(func(number: int) -> bool: return said.has(number)))
	var callout_caption: bool = said.values().any(func(caption: String) -> bool:
		return caption.contains("Window (2x), 1 of"))
	_assert("...and says when it is building the callout", callout_caption)


## The house: no callouts, but every step of a real model, and the
## inventory at the end.
func _house() -> void:
	var world: BrickWorld = _world_of(LdrModel.load_file("res://models/house.ldr"))
	var made: Array = await _make(world, "house")
	var maker: BookletMaker = made[0]
	var html: String = made[1]
	print("\n  the house, %d pieces" % world.brick_count())
	_pictures("house", maker)
	_parts_boxes("house", maker, html)
	var kinds: Array = maker.document.pages.map(func(page: Booklet.Page) -> String:
		return page.kind)
	_assert("a cover first, the finished model and then the parts last (%s … %s)" % [
		kinds[0], ", ".join(kinds.slice(-2))],
		kinds[0] == "cover" and kinds.has("finished")
		and kinds[-1] == "parts" and kinds.find("finished") < kinds.rfind("parts"))
	var listed: int = 0
	var pictured: bool = true
	var numbered: int = 0
	for lot: Booklet.Lot in maker.document.lots:
		listed += lot.count
		pictured = pictured and str(maker.document.parts.get(lot.key, "")).length() > 100
		numbered += 1 if not lot.element.is_empty() else 0
	_assert("the parts list has every piece (%d of %d), each with a picture" % [
		listed, world.brick_count()], listed == world.brick_count() and pictured)
	_assert("...and element numbers (%d of %d lots)" % [numbered,
		maker.document.lots.size()], numbered * 10 >= maker.document.lots.size() * 9)
	var order: Array = []
	for lot: Booklet.Lot in maker.document.lots:
		if order.is_empty() or order[-1] != lot.colour:
			order.append(lot.colour)
	var grouped: bool = true
	for colour: String in order:
		grouped = grouped and order.count(colour) == 1
	_assert("...grouped by colour (%s)" % ", ".join(order), grouped)
	var steps_per_page: Array = maker.document.pages.filter(func(page: Booklet.Page) -> bool:
		return page.kind == "steps").map(func(page: Booklet.Page) -> int:
			return page.entries.size())
	_assert("small steps share a page (%s)" % str(steps_per_page),
		steps_per_page.max() >= 2)


## A tall wall at the front, built first, and then plates on the floor
## behind it: from the front they cannot be seen at all.
func _turned() -> void:
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	# Named parts, the wall first: a region is finished before the next.
	for course: int in 8:
		for x: float in [-120.0, -40.0, 40.0, 120.0]:
			var id: int = world.add_brick("3001", 4, Transform3D(Basis.IDENTITY,
				Vector3(x, course * 24.0, 60.0)))
			world.get_brick(id).group = "wall"
	for x: float in [-40.0, 40.0]:
		var id: int = world.add_brick("3020", 2, Transform3D(Basis.IDENTITY,
			Vector3(x, 0.0, -60.0)))
		world.get_brick(id).group = "yard"
	var made: Array = await _make(world, "turned")
	var maker: BookletMaker = made[0]
	var html: String = made[1]
	print("\n  plates behind a wall")
	var behind: Booklet.Entry = _entries(maker)[-1]
	_assert("the step behind the wall is drawn from the back, with the turn sign",
		behind.turned and behind.from == BookletStudio.BACK
		and html.count("rx=\"1.6\" fill=\"#fff\"") >= 1)
	var note: Dictionary = _note_for(maker, "step %d" % behind.number)
	_assert("...where its plates are in sight (%s)" % str(note.get("new", Rect2())),
		(note.get("new", Rect2()) as Rect2).size.x > 10.0)


## The app's own toolbar: Instructions sits after Timeline, and pressing
## it writes the booklet of what is on the baseplate to Downloads, where
## the desktop opens it (not here: open_when_written is off).
func _the_button() -> void:
	print("\n  the app's Instructions button")
	BookletMaker.open_when_written = false
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	var bar: Node = null
	for _n: int in 400:
		await process_frame
		bar = main.get("_bar")
		if bar != null and is_instance_valid(BookletMaker.shown_button) \
				and (main.get("_world") as BrickWorld).brick_count() > 1:
			break
	var button: Button = BookletMaker.shown_button
	_assert("the toolbar has it", is_instance_valid(button) and button.is_visible_in_tree())
	if not is_instance_valid(button):
		main.queue_free()
		return
	var row: Node = button.get_parent()
	var before: Node = row.get_child(button.get_index() - 1)
	_assert("...after Timeline (%s)" % (before as Button).text if before is Button else "?",
		before is Button and (before as Button).text == "Timeline")
	# The example car, or whatever a first run puts on the baseplate.
	var title: String = (bar as ModelBar).model_name()
	var path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(
		title.to_snake_case() + "_instructions.html")
	if path.is_empty() or path.begins_with("/_"):
		path = OS.get_user_data_dir().path_join(title.to_snake_case() + "_instructions.html")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	button.pressed.emit()
	var said: String = ""
	for _n: int in 3000:
		await process_frame
		said = bar.get("_status").text
		if said.begins_with("wrote ") or said.begins_with("could not") \
				or said.begins_with("nothing"):
			break
	var written: bool = FileAccess.file_exists(path)
	var html: String = FileAccess.get_file_as_string(path) if written else ""
	_assert("pressing it writes the booklet (%s)" % said,
		written and html.contains("section class=\"page steps\""))
	if written:
		DirAccess.remove_absolute(path)
	main.queue_free()
	await process_frame


func _make(world: BrickWorld, name: String) -> Array:
	var maker := BookletMaker.new()
	maker.library = _library
	maker.px_per_mm = 2.5
	root.add_child(maker)
	var started: int = Time.get_ticks_msec()
	var html: String = await maker.make(world, {}, name.capitalize())
	var file := FileAccess.open("res://shots/booklet/%s.html" % name, FileAccess.WRITE)
	file.store_string(html)
	file.close()
	print("  (%s: %d pages in %.1f s, shots/booklet/%s.html)" % [name,
		maker.document.pages.size(), (Time.get_ticks_msec() - started) / 1000.0, name])
	return [maker, html]


## Every step's picture is of the model: drawn, the model filling the
## space the page gave it, the new parts all inside the picture.
func _pictures(what: String, maker: BookletMaker) -> void:
	var drawn: int = 0
	var framed: int = 0
	var inside: int = 0
	var steps: int = 0
	var worst: String = ""
	for note: Dictionary in maker.measured:
		if not str(note["what"]).begins_with("step ") or str(note["what"]).contains("box"):
			continue
		steps += 1
		drawn += 1 if note["drawn"] else 0
		var size := Vector2(note["size"])
		var model: Rect2 = note["model"]
		var free: Rect2 = note["free"]
		var rect: Rect2 = note["rect"]
		# The model's extent in the picture, in mm, against the room the
		# page gave it: it fills that room in one direction at least.
		var scale: float = size.x / rect.size.x
		var fill: float = maxf(model.size.x / scale / maxf(free.size.x, 1.0),
			model.size.y / scale / maxf(free.size.y, 1.0))
		if fill >= 0.75:
			framed += 1
		elif worst.is_empty():
			worst = "%s fills %d%%" % [note["what"], int(fill * 100.0)]
		var fresh: Rect2 = note["new"]
		if fresh.size.x > 0.0 and Rect2(Vector2.ONE, size - Vector2(2, 2)).encloses(fresh):
			inside += 1
	_assert("%s: every step has a picture (%d of %d)" % [what, drawn, steps],
		steps > 0 and drawn == steps)
	_assert("%s: every picture is framed on the model (%d of %d%s)" % [what, framed, steps,
		", " + worst if not worst.is_empty() else ""], framed == steps)
	_assert("%s: every step's new parts are in the picture (%d of %d)" % [what, inside, steps],
		inside == steps)


## Every step has a parts box, a picture for each part in it, and its
## counts add up to what the step adds.
func _parts_boxes(what: String, maker: BookletMaker, html: String) -> void:
	var boxes: int = 0
	var short: String = ""
	var lots: int = 0
	var steps: int = 0
	for entry: Booklet.Entry in _entries(maker, true):
		steps += 1
		if entry.lots.is_empty():
			if short.is_empty():
				short = "step %d has none" % entry.number
			continue
		boxes += 1
		for lot: Booklet.Lot in entry.lots:
			lots += 1
			if str(maker.document.parts.get(lot.key, "")).length() < 100 and short.is_empty():
				short = "step %d's %s has no picture" % [entry.number, lot.name]
	_assert("%s: every step has a parts box with a picture of each part (%d of %d%s)"
		% [what, boxes, steps, ", " + short if not short.is_empty() else ""],
		boxes == steps and short.is_empty())
	var drawn: int = html.count("<i class=\"pt ")
	var inventory: int = maker.document.lots.size()
	_assert("%s: ...and each is on the page (%d part pictures for %d lots and %d listed)"
		% [what, drawn, lots, inventory], drawn == lots + inventory)


## Every step entry, main and (with [param callouts]) a callout's own.
func _entries(maker: BookletMaker, callouts: bool = false) -> Array[Booklet.Entry]:
	var out: Array[Booklet.Entry] = []
	for page: Booklet.Page in maker.document.pages:
		for entry: Booklet.Entry in page.entries:
			if entry.in_callout and not callouts:
				continue
			out.append(entry)
	return out


func _note_for(maker: BookletMaker, what: String) -> Dictionary:
	for note: Dictionary in maker.measured:
		if note["what"] == what:
			return note
	return {}


func _world_of(ldr: LdrModel) -> BrickWorld:
	var world := BrickWorld.new()
	world.library = _library
	root.add_child(world)
	for piece: LdrModel.Placement in ldr.flatten(_library.parts):
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if _library.mesh_for(id) == null:
			continue
		var brick_id: int = world.add_brick(id, piece.color_code, piece.transform)
		world.get_brick(brick_id).group = piece.group
		world.get_brick(brick_id).unit = piece.unit
	return world


func _assert(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


const _SHED := """0 FILE shed.ldr
0 Shed
1 16 0 0 0 1 0 0 0 1 0 0 0 1 walls.ldr
1 16 0 0 0 1 0 0 0 1 0 0 0 1 figure.ldr
0 NOFILE
0 FILE walls.ldr
0 Walls
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3958.dat
1 15 0 -24 -50 1 0 0 0 1 0 0 0 1 3009.dat
1 15 0 -48 -50 1 0 0 0 1 0 0 0 1 3009.dat
1 15 0 -24 50 1 0 0 0 1 0 0 0 1 3004.dat
1 15 0 -48 50 1 0 0 0 1 0 0 0 1 3004.dat
1 4 -40 -24 50 1 0 0 0 1 0 0 0 1 window.ldr
1 4 40 -24 50 1 0 0 0 1 0 0 0 1 window.ldr
0 NOFILE
0 FILE window.ldr
0 Window
1 16 0 0 0 1 0 0 0 1 0 0 0 1 3004.dat
1 16 0 -24 0 1 0 0 0 1 0 0 0 1 3004.dat
0 NOFILE
0 FILE figure.ldr
0 Saruman
1 15 0 -28 1.25 1 0 0 0 1 0 0 0 1 3816c.dat
1 15 0 -28 1.25 1 0 0 0 1 0 0 0 1 3817c.dat
1 15 0 -40 1.25 1 0 0 0 1 0 0 0 1 3815b.dat
1 14 23.69 -45.226 -8.648 0.985 0.12 -0.12 -0.17 0.696 -0.696 0 0.707 0.707 3820.dat
1 14 -23.69 -45.226 -8.648 0.985 -0.12 0.12 0.17 0.696 -0.696 0 0.707 0.707 3820.dat
1 15 -15.552 -63 1.25 0.985 -0.17 0 0.17 0.985 0 0 0 1 3818.dat
1 15 15.552 -63 1.25 0.985 0.17 0 -0.17 0.985 0 0 0 1 3819.dat
1 15 0 -72 1.25 1 0 0 0 1 0 0 0 1 973.dat
1 14 0 -96 1.25 1 0 0 0 1 0 0 0 1 3626c.dat
0 NOFILE
"""
