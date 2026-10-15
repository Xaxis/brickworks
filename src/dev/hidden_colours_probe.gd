## Tools, Colour the hidden parts…, held to what it promises.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 \
##     --script src/dev/hidden_colours_probe.gd
##
## Needs a window: what is hidden is measured from pictures (SeenParts).
## In the real scene, through the panel and the session's tool:
##
##   found exactly   a closed box of walls with three bricks stacked inside:
##                   the three, and nothing else, are hidden. A gap in the
##                   wall shows the middle one; so does a window of clear
##                   plastic in the gap.
##   only those      on the castle, every part changed was hidden, and every
##                   part hidden that could take a colour did
##   outside same    the model drawn from eight sides before and after, three
##                   of them sides it was never measured from, the same pixel
##                   for pixel
##   valid colours   each part changed is in a colour the catalogue says that
##                   part was made in, none of them seen on the outside
##   one undo        Undo once and every part is its own colour again; copies
##                   of sub-assemblies were not rebuilt
##   asked first     a preview changes nothing, nor does apply without the
##                   person's yes; a model from a real set waits for a yes to
##                   that as well
##   kept with it    saved and opened again, the scheme is there, and the
##                   booklet shows a section's colour where it starts
##
## Pictures in shots/hidden_colours/.
extends SceneTree

const SHOTS := "res://shots/hidden_colours"
## Eight sides to compare from: the four round it and the top, which are
## among the 96 measured, and three that are not.
const COMPARED: Array[Vector3] = [Vector3(0, 0, 1), Vector3(0, 0, -1), Vector3(-1, 0, 0),
	Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0.37, 0.61, -0.7), Vector3(-0.83, 0.21, 0.52),
	Vector3(0.2, -0.9, 0.39)]

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _panel: HiddenColoursPanel


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	if not SeenParts.possible():
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_library = _main.get("_library")
	_panel = _main.get("_hidden_colours")
	# 96 sides as the app measures, at 1,024 pixels rather than 2,048: the
	# same code, four times fewer pixels, in the suite's time in software.
	_panel.most_pixels = 1024
	var shell: Shell = _main.get("_shell")
	_check("Tools has Colour the hidden parts", shell.can("hidden_colours"))

	await _the_box()
	await _a_gap()
	await _castle()
	await _a_real_set()

	print("")
	print("%d failed" % _failures if _failures else
		"the hidden parts, and only those, take colours a person can find their place by")
	quit(1 if _failures else 0)


# -- found exactly --------------------------------------------------------------------


## A 6 x 6 box: a plate under, a plate over, three courses of wall, and a
## stack of three 2 x 2 bricks inside touching neither. [param course_two]
## is the front wall's second course.
func _box(course_two: String) -> String:
	var lines := PackedStringArray(["0 A closed box", "0 Name: box.ldr", "0 Author: probe"])
	var turn: String = "0 0 1 0 1 0 -1 0 0"
	var flat: String = "1 0 0 0 1 0 0 0 1"
	lines.append("1 72 0 0 0 %s 3958.dat" % flat)
	for course: int in [1, 2, 3]:
		var y: int = -24 * course
		if course == 2 and not course_two.is_empty():
			lines.append(course_two % [y, y])
		else:
			lines.append("1 71 0 %d 50 %s 3009.dat" % [y, flat])
		lines.append("1 71 0 %d -50 %s 3009.dat" % [y, flat])
		lines.append("1 71 -50 %d 0 %s 3010.dat" % [y, turn])
		lines.append("1 71 50 %d 0 %s 3010.dat" % [y, turn])
		lines.append("1 0 0 %d 0 %s 3003.dat" % [y, flat])
	lines.append("1 72 0 -80 0 %s 3958.dat" % flat)
	return "\n".join(lines) + "\n"


## Opened as File, Open opens it: the floor's baseplate laid under it.
func _open(text: String, name: String) -> void:
	_store.open_text(text, name)
	_main.call("_lay_baseplate")
	await _frames(10)


func _inner() -> Array[int]:
	var out: Array[int] = []
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3003" and not _store.scenery.has(brick.id):
			out.append(brick.id)
	return out


func _the_box() -> void:
	print("\n  a closed box with three bricks inside")
	await _open(_box(""), "box.ldr")
	var inner: Array[int] = _inner()
	var measured: SeenParts.Result = await _panel.measured()
	var hidden: Dictionary = measured.hidden()
	var parts: int = _world.brick_count() - _store.scenery.size()
	_check("measured from %d sides, every one drawn (%d parts, a pixel %.2f LDU at most)" % [
		measured.views, parts, measured.coarsest], measured.complete
		and measured.views == SeenParts.directions(SeenParts.VIEWS).size() and measured.views >= 90)
	var exact: bool = hidden.size() == 3 and inner.all(func(id: int) -> bool:
		return hidden.has(id))
	_check("exactly the three inside are hidden (%d hidden)" % hidden.size(), exact)
	_check("...and the sides measured showed different parts (%d to %d)" % [
		Array(measured.per_view).min(), Array(measured.per_view).max()],
		Array(measured.per_view).min() > 0 and Array(measured.per_view).max() < parts)

	var colours: Dictionary = _colours()
	var depth: int = _builder.history_depth()
	var previewed: Variant = await _panel.for_session({"mode": "sections"})
	_check("a preview changes nothing", _colours() == colours
		and _builder.history_depth() == depth and previewed is Array)
	var refused: Variant = await _panel.for_session({"mode": "sections", "apply": true})
	_check("apply without the person's yes changes nothing either: %s" % _tail(str(refused)),
		_colours() == colours and str(refused).contains("agreed=true"))
	var done: Variant = await _panel.for_session({"mode": "sections", "apply": true,
		"agreed": true})
	var changed: Array = _changed(colours)
	_check("with it, the three inside take a colour, and nothing else (%s)" % _tail(str(done)),
		changed.size() == 3 and changed.all(func(id: int) -> bool: return inner.has(id)))
	_check("...one step to undo", _builder.history_depth() == depth + 1)
	_valid(changed, measured)
	_check("...the scheme is kept with the model (%s)" % JSON.stringify(_store.hidden_scheme),
		not (_store.hidden_scheme.get("groups", []) as Array).is_empty())
	var text: String = _store.to_text("Box", true)
	await _open(text, "box.ldr")
	_check("saved and opened again, the colours and the scheme are back",
		_inner().all(func(id: int) -> bool:
			return (_world.get_brick(id) as BrickWorld.Brick).color_code != 0)
		and HiddenColours.read(text) == _store.hidden_scheme
		and not _store.hidden_scheme.is_empty())
	# The booklet: the section's colour where it starts.
	var path: String = ProjectSettings.globalize_path(SHOTS.path_join("box_booklet.html"))
	BookletMaker.open_when_written = false
	await _main.call("_export_booklet", path)
	var html: String = FileAccess.get_file_as_string(path)
	var mark: Dictionary = HiddenColours.live_marks(_store.hidden_scheme, _world, _library,
		_store.scenery)
	var hex: String = str((mark.values()[0] as Dictionary)["rgb"]) if not mark.is_empty() else "?"
	_check("the booklet shows the hidden colour where it starts (%s, %s)" % [hex,
		str((mark.values()[0] as Dictionary)["name"]) if not mark.is_empty() else "none"],
		not mark.is_empty() and html.contains("class=\"chip\" style=\"background:%s\"" % hex))
	# A section's colour goes in its banner, the page where it starts.
	var page := Booklet.Page.new()
	page.banner = "Tower"
	var entry := Booklet.Entry.new()
	entry.section = "Tower"
	entry.marks = [{"label": "Tower", "name": "Bright Green", "rgb": "#58ab41"},
		{"label": "Gate", "name": "Blue", "rgb": "#1e5aa8"}]
	page.entries.append(entry)
	var document := Booklet.Document.new()
	document.pages.append(page)
	var written: String = Booklet.html(document)
	var banner_at: int = written.find("class=\"a ban\"")
	var green_at: int = written.find("background:#58ab41\"></i>inside: Bright Green")
	_check("...a section's in its banner (\"inside: Bright Green\"), another's by the step",
		banner_at >= 0 and green_at > banner_at
		and written.contains("background:#1e5aa8\"></i>Gate: Blue"))


func _a_gap() -> void:
	print("\n  a gap in the wall, then a clear window in it")
	# The front wall's second course a 1 x 2 each side of a 2-stud gap.
	await _open(_box("1 71 -40 %d 50 1 0 0 0 1 0 0 0 1 3004.dat\n"
		+ "1 71 40 %d 50 1 0 0 0 1 0 0 0 1 3004.dat"), "gap.ldr")
	var middle: int = _inner_at(-48.0)
	var hidden: Dictionary = (await _panel.measured()).hidden()
	_check("the brick behind the gap is seen (%d hidden)" % hidden.size(),
		middle != 0 and not hidden.has(middle))
	var window: String = _box("1 71 -40 %d 50 1 0 0 0 1 0 0 0 1 3004.dat\n"
		+ "1 71 40 %d 50 1 0 0 0 1 0 0 0 1 3004.dat") \
		+ "1 47 0 -48 50 1 0 0 0 1 0 0 0 1 3004.dat\n"
	await _open(window, "window.ldr")
	middle = _inner_at(-48.0)
	var result: SeenParts.Result = await _panel.measured()
	_check("...and behind clear plastic too, which is itself never in front (%d hidden)"
		% result.hidden().size(), middle != 0 and not result.hidden().has(middle)
		and result.see_through.size() == 1)


## The inner brick at height [param y] as the file put it, before the lift.
func _inner_at(y: float) -> int:
	var inner: Array[int] = _inner()
	inner.sort_custom(func(a: int, b: int) -> bool:
		return _world.get_brick(a).transform.origin.y < _world.get_brick(b).transform.origin.y)
	return inner[1] if inner.size() == 3 and y == -48.0 else 0


# -- the castle: only those, the outside the same, one undo --------------------------


func _castle() -> void:
	print("\n  the castle, by section")
	_store.open("res://models/castle.ldr")
	_main.call("_lay_baseplate")
	await _frames(20)
	var colours: Dictionary = _colours()
	var bricks: Array = HiddenColours.bricks_of(_world, _store.scenery)
	var depth: int = _builder.history_depth()
	_panel.plan = null
	_panel.after = null
	_main.call("open_hidden_colours", "sections")
	var until: int = Time.get_ticks_msec() + 600000
	while (_panel.plan == null or _panel.after == null) and Time.get_ticks_msec() < until:
		await _frames(5)
	await _frames(5)
	var made: HiddenColours.Plan = _panel.plan
	var measured: SeenParts.Result = await _panel.measured()
	var hidden: Dictionary = measured.hidden()
	_check("the panel shows the plan and the inside twice: %s" % _tail(made.summary(_library)
		if made != null else "nothing"), made != null and _panel.before != null
		and _panel.after != null and not made.changes.is_empty())
	if made == null:
		return
	_panel.before.save_png(ProjectSettings.globalize_path(SHOTS.path_join("castle_inside_before.png")))
	_panel.after.save_png(ProjectSettings.globalize_path(SHOTS.path_join("castle_inside_after.png")))
	_check("every part it would change is hidden (%d of %d hidden)" % [made.changes.size(),
		hidden.size()], made.changes.keys().all(func(id: int) -> bool: return hidden.has(id)))
	var coloured: int = 0
	for group: HiddenColours.Group in made.groups:
		coloured += group.recoloured
	var kept: int = 0
	for reason: String in made.kept:
		kept += int(made.kept[reason])
	_check("...and every hidden part is coloured or kept for a reason said (%d + %d = %d)"
		% [coloured, kept, hidden.size()], coloured + kept == hidden.size()
		and coloured >= made.changes.size())
	var controls: Dictionary = _panel.controls_by_name()
	var apply: Button = controls.get("hidden_apply")
	_check("Apply is offered: \"%s\"" % (apply.text if apply != null else "none"),
		apply != null and not apply.disabled)
	apply.pressed.emit()
	await _frames(5)
	var changed: Array = _changed(colours)
	_check("pressed, it changed those %d and no other" % changed.size(),
		changed.size() == made.changes.size()
		and changed.all(func(id: int) -> bool: return made.changes.has(id)))
	_check("...one step of the history, called \"%s\"" % (_builder.history_words(1)[0]
		if _builder.history_depth() > 0 else ""), _builder.history_depth() == depth + 1)
	var steps: Array = _builder.last_step().get("steps", [])
	var recolours: bool = steps.all(func(one: Dictionary) -> bool:
		return str(one.get("undo", "")) == "recolor")
	var assemblies: Assemblies = (_main.get("_verbs") as EditVerbs).assemblies
	var rebuilt: int = int(assemblies.copies_follow(_builder.touched_groups(
		_builder.last_step()))[1])
	_check("...and no copy of a sub-assembly was built again for it: the step is %d recolours, "
		% steps.size() + "and the copies all match still (%d to rebuild)" % rebuilt,
		recolours and steps.size() == changed.size() and rebuilt == 0)
	_valid(changed, measured)

	var after: Array = HiddenColours.bricks_of(_world, _store.scenery)
	var frame: AABB = _panel._frame(bricks)
	var differing: int = 0
	var compared: int = 0
	for way: Vector3 in COMPARED:
		var was: Image = await _panel._seen.picture(bricks, way, frame, 700)
		var now: Image = await _panel._seen.picture(after, way, frame, 700)
		if was == null or now == null:
			continue
		compared += 1
		var off: int = _pixels_apart(was, now)
		differing += off
		if way == COMPARED[0] or off > 0:
			was.save_png(ProjectSettings.globalize_path(SHOTS.path_join("castle_out_%d_before.png"
				% COMPARED.find(way))))
			now.save_png(ProjectSettings.globalize_path(SHOTS.path_join("castle_out_%d_after.png"
				% COMPARED.find(way))))
		if off > 0:
			print("    %d pixels differ from %s" % [off, way])
	_check("the outside from %d sides, 3 never measured from, the same pixel for pixel (%d differ)"
		% [compared, differing], compared == COMPARED.size() and differing == 0)
	var cut: Array = HiddenColoursPanel.cut_through(bricks, made.changes, _library)
	var inside_was: Image = await _panel._seen.picture(bricks, cut[1], frame, 700, true, cut[0])
	var inside_now: Image = await _panel._seen.picture(after, cut[1], frame, 700, true, cut[0])
	_check("...where cut open, the inside is not (%d pixels differ)" % _pixels_apart(inside_was,
		inside_now), _pixels_apart(inside_was, inside_now) > 0)

	await (_main.get("_verbs") as EditVerbs).press("undo")
	await _frames(5)
	_check("one undo puts every part back in its own colour (%d differ)" % _changed(colours).size(),
		_changed(colours).is_empty() and _builder.history_depth() == depth)


# -- asked first --------------------------------------------------------------------


func _a_real_set() -> void:
	print("\n  a real set, as its designers coloured it")
	_store.open("res://vendor/omr/files/10182-1.mpd")
	_main.call("_lay_baseplate")
	await _frames(20)
	_check("opened from the LDraw model repository, it knows the set (%s)" % _store.from_set,
		_store.from_set == "10182")
	var colours: Dictionary = _colours()
	var said: Variant = await _panel.for_session({"mode": "stages", "apply": true,
		"agreed": true, "from_below": false})
	_check("agreed is not enough for a set's own colours: %s" % _tail(str(said), 160),
		_colours() == colours and str(said).contains("set_agreed"))
	said = await _panel.for_session({"mode": "stages", "apply": true, "agreed": true,
		"set_agreed": true, "from_below": false})
	var changed: Array = _changed(colours)
	_check("...and with a yes to that, its hidden parts take the stages' colours (%d)"
		% changed.size(), not changed.is_empty())
	var text: String = _store.to_text("Cafe", true)
	_check("...saved, it still says it is the set", ModelStore.set_in(text) == "10182")
	await (_main.get("_verbs") as EditVerbs).press("undo")
	await _frames(5)


# -- helpers ------------------------------------------------------------------------


## The model's colours by part, the baseplate it stands on left out.
func _colours() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out[brick.id] = brick.color_code
	return out


## What is not as it was: a part another colour, or a part come or gone.
func _changed(before: Dictionary) -> Array:
	var out: Array = []
	var now: Dictionary = _colours()
	for id: int in now:
		if int(before.get(id, -999)) != int(now[id]):
			out.append(id)
	for id: int in before:
		if not now.has(id):
			out.append(id)
	return out


## Each changed part is in a colour its part was made in, and none of those
## colours is seen on the outside.
func _valid(changed: Array, measured: SeenParts.Result) -> void:
	var outside: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and measured.seen.has(brick.id):
			outside[_library.plain_code(brick.color_code)] = true
	var wrong := PackedStringArray()
	var seen_colour := PackedStringArray()
	var used: Dictionary = {}
	for id: int in changed:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		used[brick.color_code] = true
		if info == null or not info.colors.has(brick.color_code):
			wrong.append("%s in %d" % [brick.part_id, brick.color_code])
		if outside.has(brick.color_code):
			seen_colour.append(str(brick.color_code))
	_check("...each in a colour its part was made in (%s)%s" % [", ".join(
		used.keys().map(func(c: int) -> String: return HiddenColours.colour_name(_library, c))),
		"" if wrong.is_empty() else ": not " + ", ".join(wrong)], wrong.is_empty())
	_check("...and none of those colours is seen outside%s" % ("" if seen_colour.is_empty()
		else ": " + ", ".join(seen_colour)), seen_colour.is_empty())


static func _pixels_apart(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var first: PackedByteArray = a.get_data()
	var second: PackedByteArray = b.get_data()
	if first == second:
		return 0
	var off: int = 0
	for at: int in range(0, first.size(), 4):
		if first[at] != second[at] or first[at + 1] != second[at + 1] \
				or first[at + 2] != second[at + 2]:
			off += 1
	return off


static func _tail(words: String, most: int = 110) -> String:
	return words if words.length() <= most else words.left(most) + "…"
