## Your own minifig hair, made in the figure builder the way a person makes
## it: one sculpted from a real hair piece by strokes, one brought in from an
## STL; each worn on a head, placed, saved, and opened again here and where
## neither part was ever made.
##
##   godot --path . --resolution 1280x800 --script src/dev/figmould_probe.gd -- --pictures=DIR
##   PROBE_SIZE=390x844 tools/probe.sh figmould_probe -- --pictures=DIR   laid out for a phone, by touch
##
## Strokes are the mouse's at a desk and a finger's on a phone, on the view
## as a person's are: Pull the fringe up, Grow the sides, Shrink the back,
## Smooth the crown, each one step of Undo that comes back to the bit; Finer
## and its Undo; Start from a dome and Undo back into the hair; on a phone a
## second finger that pinches takes back the stroke the first had begun. The
## mould is closed unsaved and opened again, and opened by an editor made
## anew (as after a reload) from what was kept: every corner as it was.
## Saved, the figure wears it; in the model the hair is where 3901 sits on
## the head, and the model's file carries the mould's own text. The STL hair
## is seated on the head and worn the same way. Saved, the model is opened
## again and saved with no edit to the same bytes; read where neither part
## was made, each is built from the file with the same corners, and placed
## at the same place.
##
## With --pictures=DIR, three hairs sculpted from 3901, 62711 and 40233 are
## placed on figures beside figures wearing those real hair pieces, and
## pictured in the view and rendered on a light backdrop and a dark one.
##
## Made parts go to user://figmould_probe/, never the person's own.
extends SceneTree

const PROBE_DIR := "user://figmould_probe/"
const FIXTURES := "res://tests/fixtures/own_parts/"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _figures: MinifigDialog
var _editor: MouldEditor
var _pictures: String = ""
var _phone: bool = false
var _shots: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			_pictures = arg.trim_prefix("--pictures=")
	_forget(PROBE_DIR)
	CustomParts.dir = PROBE_DIR + "parts/"
	MouldEditor.drafts = PROBE_DIR + "drafts/"
	SaveTo.native = false
	Minifig.shelf_file = PROBE_DIR + "shelf.json"
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window: Vector2i = DisplayServer.window_get_size()
	_phone = mini(window.x, window.y) < int(Phone.NARROW)
	if _phone:
		Phone._on = 1
		Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	if _phone and _main.get("_phone") != null:
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			ShellPrefs.interface_size(), true)
		await _frames(20)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_figures = _main.get("_figures")
	_main.call("clear_model")
	await _frames(10)
	print("%s, %dx%d" % ["laid out for a phone, by touch" if _phone else "at a desk", window.x,
		window.y])

	var sculpted: Dictionary = await _sculpt_hair()
	if sculpted.is_empty():
		_finish()
		return
	var brought: Dictionary = await _hair_from_file()
	if brought.is_empty():
		_finish()
		return
	await _saved_and_opened([sculpted, brought])
	if not _pictures.is_empty():
		await _beside_real_hair()
	_finish()


# -- a hair by strokes -------------------------------------------------------------------


func _sculpt_hair() -> Dictionary:
	print("\na hair by strokes, from 3901")
	_main.call("_open_figures")
	await _frames(30)
	await _press(_figures._slot_buttons["headwear"])
	_check("Headgear offers \"%s\"" % _figures._make.text,
		_figures._make.is_visible_in_tree() and _figures._make.text == "Make a mould…")
	await _press(_figures._make)
	_editor = _figures.mould_editor()
	await _frames(20)
	var mould: Mould = _editor.mould
	_check("it opens on the figure's hair, 3901, symmetry on: %d triangles" % (mould.triangle_count()
		if mould != null else 0), _editor.visible and mould != null and mould.base == "3901"
		and _editor._symmetry.button_pressed)
	if mould == null:
		return {}
	_check("laid out %s" % ("for a finger, the part over the brushes" if _phone else "at a desk"),
		_editor.laid_narrow() == _phone)
	await _in_reach()
	var original: PackedVector3Array = mould.positions.duplicate()
	var locks: PackedFloat32Array = mould.locks.duplicate()
	await _shot("mould_open")

	# Pull the fringe up and forward, seen from the side.
	_editor.turn_to(PI * 0.5, 0.15, 95.0)
	await _frames(6)
	await _press(_editor._tools["pull"])
	_editor.set_brush(8.0, 0.8)
	var fringe: Vector3 = _surface(Vector3(0, 8, 60), Vector3(0, 4, 8))
	var steps: int = mould._undo.size()
	var before: PackedVector3Array = mould.positions.duplicate()
	await _stroke([fringe + Vector3(0, -2, 0), fringe, fringe + Vector3(0, 3, 1)])
	var lifted: float = _furthest(before, mould.positions)
	_check("Pull: the fringe drawn out %.1f LDU, in one step of Undo" % lifted,
		lifted > 1.0 and mould._undo.size() == steps + 1)
	var after: PackedVector3Array = mould.positions.duplicate()
	await _press(_editor.controls_by_name()["mould_undo"])
	var undone: bool = mould.positions == before
	await _press(_editor.controls_by_name()["mould_redo"])
	_check("Undo takes it back to the bit, Redo puts it back to the bit",
		undone and mould.positions == after)

	# Grow one side, seen from that side: with symmetry the other comes too.
	_editor.turn_to(PI * 0.5, 0.2, 95.0)
	await _frames(6)
	await _press(_editor._tools["inflate"])
	_editor.set_brush(8.0, 0.8)
	var side: Vector3 = _surface(Vector3(60, 0, 8), Vector3(8, 0, 2))
	before = mould.positions.duplicate()
	await _stroke([side + Vector3(0, 3, -2), side, side + Vector3(0, -3, 2)])
	var right: float = 0.0
	var left: float = 0.0
	for v: int in mould.positions.size():
		var shift: float = mould.positions[v].distance_to(before[v])
		if before[v].x > 4.0:
			right = maxf(right, shift)
		elif before[v].x < -4.0:
			left = maxf(left, shift)
	_check("Grow: the side swells %.1f LDU and, with symmetry, the other side %.1f" % [right, left],
		right > 0.5 and left > 0.5)

	# Shrink the back.
	_editor.turn_to(PI, 0.2, 95.0)
	await _frames(6)
	await _press(_editor._tools["shrink"])
	var back: Vector3 = _surface(Vector3(0, -2, -60), Vector3(0, -2, -8))
	before = mould.positions.duplicate()
	var outward_before: float = _reach_along(before, Vector3(0, 0, -1))
	await _stroke([back + Vector3(-3, 2, 0), back, back + Vector3(3, -2, 0)])
	var outward_after: float = _reach_along(mould.positions, Vector3(0, 0, -1))
	_check("Shrink: the back drawn in, %.2f to %.2f LDU behind the middle" % [outward_before,
		outward_after], _furthest(before, mould.positions) > 0.3 and outward_after <= outward_before)

	# Smooth the crown.
	_editor.turn_to(0.5, 0.9, 95.0)
	await _frames(6)
	await _press(_editor._tools["smooth"])
	var crown: Vector3 = _surface(Vector3(0, 60, 0), Vector3(0, 6, 0))
	before = mould.positions.duplicate()
	await _stroke([crown + Vector3(-5, 0, 4), crown, crown + Vector3(5, 0, -4)])
	_check("Smooth: the crown evened out", _furthest(before, mould.positions) > 0.01)

	# Finer: more corners, one step; Undo puts back the corners and triangles
	# there were.
	var corners: int = mould.positions.size()
	var faces: PackedInt32Array = mould.triangles.duplicate()
	before = mould.positions.duplicate()
	await _press(_editor.controls_by_name()["mould_finer"])
	var finer: int = mould.positions.size()
	await _press(_editor.controls_by_name()["mould_undo"])
	_check("Finer: %d corners to %d; Undo: %d corners, every one and every triangle as it was"
		% [corners, finer, mould.positions.size()], finer > corners
		and mould.positions == before and mould.triangles == faces)
	await _press(_editor.controls_by_name()["mould_redo"])
	_check("and Redo makes it finer again (%d corners)" % mould.positions.size(),
		mould.positions.size() == finer)
	await _press(_editor.controls_by_name()["mould_undo"])

	if _phone:
		await _pinch(mould)

	var moved_locked: float = 0.0
	for v: int in mini(original.size(), mould.positions.size()):
		if locks[v] >= 1.0:
			moved_locked = maxf(moved_locked, mould.positions[v].distance_to(original[v]))
	var into_head: int = 0
	for v: int in mould.positions.size():
		if mould.locks[v] < 1.0 and Mould.head_depth(mould.positions[v]) > maxf(-Mould.HEAD_MARGIN,
				Mould.head_depth(mould.rest[v])) + 1e-3:
			into_head += 1
	_check("its socket and the inside on the head never moved (%.6f), nothing pushed into the head (%d)"
		% [moved_locked, into_head], moved_locked == 0.0 and into_head == 0)
	await _shot("mould_sculpted")

	# Nothing is lost: closed unsaved, then opened again; then made anew.
	var shaped: PackedVector3Array = mould.positions.duplicate()
	var shaped_faces: PackedInt32Array = mould.triangles.duplicate()
	await _type_into(_editor._name, "Quiff")
	await _press(_editor.controls_by_name()["mould_close"])
	_check("Close: back to the figure", not _editor.visible)
	await _press(_figures._make)
	await _frames(10)
	_check("Make a mould… again: the mould as it was left, every corner, its name \"%s\": %s"
		% [_editor._name.text, _editor._status.text], _editor.visible and _editor.mould != null
		and _editor.mould.positions == shaped and _editor.mould.triangles == shaped_faces
		and _editor._name.text == "Quiff")
	var anew := MouldEditor.new()
	anew.library = _library
	HudFront.add_beside(_figures, anew)
	await _frames(3)
	anew.open("3901", "headwear", 4)
	await _frames(3)
	_check("an editor made anew, as after a reload, opens on the same corners and triangles",
		anew.mould != null and anew.mould.positions == shaped and anew.mould.triangles == shaped_faces
		and anew.mould.locks == _editor.mould.locks)
	anew.visible = false
	anew.queue_free()
	HudFront.show_panel(_editor)
	await _frames(3)
	mould = _editor.mould

	# Start from a dome, and Undo goes back into the hair.
	await _press(_editor.controls_by_name()["mould_dome"])
	var domed: bool = _editor.mould != mould and _editor.mould.name.ends_with("Dome")
	await _press(_editor.controls_by_name()["mould_undo"])
	_check("Dome starts again; Undo goes back into the hair, every corner as it was",
		domed and _editor.mould == mould and mould.positions == shaped)

	# Saved and worn.
	await _press(_editor._save)
	await _frames(20)
	var worn: String = _figures.figure.part("headwear")
	var kept: String = FileAccess.get_file_as_string(CustomParts.dir + worn + ".dat")
	_check("Save mould: the figure wears %s, kept as the mould's own text, the draft let go"
		% worn, worn.begins_with("bw-3901-m") and not _editor.visible
		and kept == mould.text(worn, "Quiff")
		and not FileAccess.file_exists(MouldEditor.drafts + "headwear.draft"))
	await _press(_figures._make)
	await _frames(10)
	var top: float = _reach_along(mould.positions, Vector3.UP)
	_check("Make a mould… once it is saved: the Quiff worn, to shape further (standing for %s), "
		% (_editor.mould.base if _editor.mould != null else "none")
		+ "its top %.2f LDU as made; not a draft" % top, _editor.mould != null
		and _editor.mould.base == "3901" and _editor._from.text == worn and not _editor._restored
		and absf(_reach_along(_editor.mould.positions, Vector3.UP) - top) < 0.05)
	await _press(_editor.controls_by_name()["mould_close"])
	_check("closed untouched, nothing is kept to come back over the next hair",
		not FileAccess.file_exists(MouldEditor.drafts + "headwear.draft"))
	await _shot("figure_sculpted")
	var placed: Dictionary = await _place(worn, Vector2(-0.18, 0.0))
	placed["text"] = kept
	return placed


## Every control a person needs on the screen, and on a phone a finger's
## size each way.
func _in_reach() -> void:
	var screen := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var named: Dictionary = _editor.controls_by_name()
	var off: PackedStringArray = []
	var small: PackedStringArray = []
	var finger: float = Phone.px(root, Phone.TARGET) - 0.5 if _phone else 0.0
	for key: String in named:
		var control: Control = named[key]
		await _reveal(control)
		var seen: Rect2 = control.get_global_rect()
		if not control.is_visible_in_tree() or not screen.encloses(seen):
			off.append(key)
		elif _phone and (control is Button or control is LineEdit) and seen.size.y < finger:
			small.append("%s %.0f" % [key, seen.size.y])
	_check("every control on the screen%s: %s off it, %s too small" % [", a fingertip tall"
		if _phone else "", off, small], off.is_empty() and small.is_empty())


## A second finger down while the first sculpts: the stroke it began taken
## back to the bit, no step of Undo left by it, and the two fingers apart come
## closer.
func _pinch(mould: Mould) -> void:
	_editor.turn_to(0.6, 0.3, 120.0)
	await _frames(6)
	await _press(_editor._tools["pull"])
	var before: PackedVector3Array = mould.positions.duplicate()
	var steps: int = mould._undo.size()
	var reach: float = _editor.reach()
	var top: Vector3 = _surface(Vector3(20, 60, 20), Vector3(4, 6, 4))
	var a: Vector2 = _on_screen(top)
	_touch(0, a, true)
	await _frames(2)
	for k: int in 6:
		_slide(0, a + Vector2(0, -4.0 * (k + 1)))
		await process_frame
	var dented: bool = mould.positions != before
	var b: Vector2 = a + Vector2(60, 60)
	_touch(1, b, true)
	await _frames(2)
	for k: int in 8:
		_slide(0, a + Vector2(-6.0 * k, -24.0 - 6.0 * k))
		_slide(1, b + Vector2(6.0 * k, 6.0 * k))
		await process_frame
	_touch(0, a + Vector2(-42, -66), false)
	await _frames(2)
	_touch(1, b + Vector2(42, 42), false)
	await _frames(6)
	_check("a second finger: the stroke begun (%s) taken back to the bit, no step left, and the pinch came %.0f to %.0f"
		% ["a dent" if dented else "nothing yet", reach, _editor.reach()],
		mould.positions == before and mould._undo.size() == steps and _editor.reach() < reach)


# -- a hair from a file ------------------------------------------------------------------


func _hair_from_file() -> Dictionary:
	print("\na hair from an STL")
	_main.call("_open_figures")
	await _frames(20)
	await _press(_figures._slot_buttons["headwear"])
	var yours: Button = _figures.get("_own")
	await _press(yours)
	var panel: Control = _figures.get("_own_editor")
	var picker: MeshFilePicker = panel.call("picker") if panel != null else null
	var chooser: FileDialog = picker.get("_dialog") if picker != null else null
	if chooser != null:
		chooser.hide()
	if picker == null:
		_check("Your own… opens the panel", false)
		return {}
	picker.open_path(ProjectSettings.globalize_path(FIXTURES + "mohawk.stl"))
	await _read_by(panel)
	var piece: MeshPart = panel.get("part")
	_check("the mohawk is in, sized and seated on the head: %s" % (piece.size_words()
		if piece != null else ""), piece != null and piece.hair and piece.head_inside <= 0.05)
	await _shot("stl_seated")
	await _press(panel.get("_add"))
	await _read_by(panel)
	var worn: String = _figures.figure.part("headwear")
	_check("Wear it: the figure wears %s" % worn, worn.begins_with("bw-") and worn != ""
		and PartPrints.bases.get(worn, "") == "3901")
	await _shot("figure_stl")
	# The file's hair sculpted on further, in the same maker: the mohawk's own
	# shape (as wide as the file's hair, not the Quiff's), no draft over it.
	await _press(_figures._make)
	await _frames(20)
	var wide: float = 0.0
	if _editor.mould != null:
		for p: Vector3 in _editor.mould.positions:
			wide = maxf(wide, absf(p.x))
	_check("Make a mould… opens on the file's hair itself, standing for 3901, %.1f LDU across "
		% (wide * 2.0) + "as the mohawk is (%.1f): %s" % [piece.box().size.x if piece != null else 0.0,
		_editor._status.text], _editor.visible and _editor.mould != null
		and _editor.mould.base == "3901" and _editor._from.text == worn and not _editor._restored
		and _editor._title.text.contains("your") and _editor.mould.triangle_count() > 100
		and piece != null and absf(wide * 2.0 - piece.box().size.x) < 1.0)
	await _shot("mould_on_stl")
	await _press(_editor.controls_by_name()["mould_close"])
	var placed: Dictionary = await _place(worn, Vector2(0.18, 0.0))
	placed["text"] = FileAccess.get_file_as_string(CustomParts.dir + worn + ".dat")
	return placed


## The figure placed in the model, [param share] of the screen from its
## middle: {id, seat (the hair's place on the head), at (the hair's place)}.
func _place(hair: String, share: Vector2) -> Dictionary:
	var before: Array = _world.bricks().duplicate()
	await _press(_find_button(_figures, "Place in model"))
	var screen: Vector2 = root.get_visible_rect().size
	# At a desk the parts bin is the screen's left 0.37: the figures go down
	# on the baseplate right of it, half as far apart.
	var at_desk := Vector2(screen.x * (0.62 + share.x * 0.5), screen.y * (0.5 + share.y))
	await _tap(at_desk if not _phone else screen * 0.5 + screen * share)
	await _frames(10)
	await _key(KEY_ESCAPE)
	var added: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return not before.has(brick))
	var seat: Variant = _seat(added, hair)
	_check("placed: %d parts, the hair where 3901 sits on the head" % added.size(),
		added.size() >= 2 and seat is Transform3D
		and (seat as Transform3D).is_equal_approx(Transform3D.IDENTITY))
	var at: Transform3D = Transform3D.IDENTITY
	for brick: BrickWorld.Brick in added:
		if brick.part_id == hair:
			at = brick.transform
	return {"id": hair, "seat": seat if seat is Transform3D else Transform3D.IDENTITY, "at": at}


# -- saved, and opened ---------------------------------------------------------------------


func _saved_and_opened(hairs: Array) -> void:
	print("\nsaved, and opened again")
	var path: String = ProjectSettings.globalize_path(PROBE_DIR + "figures.mpd")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var saved: bool = _main.call("save_model", path)
	var text: String = FileAccess.get_file_as_string(path)
	for hair: Dictionary in hairs:
		_check("the file carries %s as 0 FILE, its own text whole" % hair["id"], saved
			and text.contains("0 FILE %s.dat" % hair["id"])
			and text.contains(str(hair["text"]).strip_edges()))
	if not _pictures.is_empty():
		DirAccess.make_dir_recursive_absolute(_pictures)
		DirAccess.copy_absolute(path, _pictures.path_join("figures%s.mpd" % ("_phone" if _phone else "")))
	var meshes: Dictionary = {}
	for hair: Dictionary in hairs:
		meshes[hair["id"]] = _points(_library.mesh_for(hair["id"]))
	_main.call("clear_model")
	await _frames(10)
	_main.call("_open", path)
	for _n: int in 90:
		await process_frame
	for hair: Dictionary in hairs:
		var found: Array = _world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
			return brick.part_id == hair["id"])
		_check("opened again: %s where it was, on the head" % hair["id"], found.size() == 1
			and (found[0] as BrickWorld.Brick).transform.is_equal_approx(hair["at"]))
	var again: String = ProjectSettings.globalize_path(PROBE_DIR + "figures_again.mpd")
	_main.call("save_model", again)
	var text_again: String = FileAccess.get_file_as_string(again)
	_check("saved again with no edit: the same %d bytes" % text_again.length(),
		not text_again.is_empty() and text_again == text)

	# Where neither part was ever made: a library and a kept folder of their own.
	CustomParts.dir = PROBE_DIR + "elsewhere/"
	var fresh := PartLibrary.new()
	fresh.load_catalogue()
	var model: LdrModel = LdrModel.parse(text, "figures.mpd")
	CustomParts.take_from(fresh, model)
	var placements: Array = model.flatten(fresh.parts)
	for hair: Dictionary in hairs:
		var id: String = hair["id"]
		var points: PackedVector3Array = _points(fresh.mesh_for(id))
		var place: Array = placements.filter(func(p: LdrModel.Placement) -> bool:
			return p.part_id == id)
		var heads: Array = placements.filter(func(p: LdrModel.Placement) -> bool:
			return p.part_id.begins_with("3626"))
		var seat: Variant = null
		if place.size() == 1:
			for head: LdrModel.Placement in heads:
				var relative: Transform3D = head.transform.affine_inverse() \
					* (place[0] as LdrModel.Placement).transform
				if relative.is_equal_approx(Transform3D.IDENTITY):
					seat = relative
		_check("someone else's: %s built from the file, %d corners the same to the bit, on a head"
			% [id, points.size()], not points.is_empty() and points == meshes[id]
			and place.size() == 1 and seat != null)
	CustomParts.dir = PROBE_DIR + "parts/"


## Every corner of a built part, surface by surface, in order.
static func _points(mesh: Lbm.PartMesh) -> PackedVector3Array:
	var out := PackedVector3Array()
	if mesh == null:
		return out
	for surface: ArrayMesh in mesh.surfaces:
		out.append_array(surface.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])
	return out


# -- beside real hair, pictured --------------------------------------------------------------


## Three hairs made by strokes, each on a figure beside one wearing the real
## hair piece it was made from; in the view, and rendered light and dark.
func _beside_real_hair() -> void:
	print("\nthree hairs by strokes, beside the real ones")
	_main.call("clear_model")
	await _frames(10)
	# Each pair in a hair colour of its own (Reddish Brown, Tan, Dark Orange),
	# the real piece on the left and the mould made from it on its right, in
	# one row across the baseplate.
	var bases: Array = [["3901", "Swept quiff", 70], ["62711", "Big bob", 19],
		["40233", "Flicked tousle", 484]]
	var placed: Array = []
	for n: int in bases.size():
		var base: String = bases[n][0]
		var share := Vector2(-0.25 + 0.25 * n, 0.1)
		_main.call("_open_figures")
		await _frames(20)
		_figures.figure.choose(_library, "headwear", base)
		_figures.figure.colours["headwear"] = int(bases[n][2])
		_figures._slot = "headwear"
		_figures._refresh_all()
		await _frames(10)
		await _place(base, share + Vector2(-0.06, 0))
		_main.call("_open_figures")
		await _frames(20)
		await _press(_figures._slot_buttons["headwear"])
		await _press(_figures._make)
		await _frames(20)
		if _editor.mould == null or _editor.mould.base != base:
			_check("a mould of %s opens" % base, false)
			continue
		await _shape(n)
		await _type_into(_editor._name, bases[n][1])
		await _press(_editor._save)
		await _frames(20)
		var worn: String = _figures.figure.part("headwear")
		_check("%s sculpted from %s and worn as %s" % [bases[n][1], base, worn],
			worn.begins_with("bw-"))
		placed.append(await _place(worn, share + Vector2(0.06, 0)))
	var box := AABB()
	var first: bool = true
	for brick: BrickWorld.Brick in _world.bricks():
		var at: Vector3 = brick.transform.origin
		box = AABB(at, Vector3.ZERO) if first else box.expand(at)
		first = false
	_camera.frame(box.grow(12.0), 1.0)
	_camera.set_view("front")
	_camera.frame(box.grow(12.0), 1.0)
	await _frames(90)
	await _shot("beside_real_view")
	var dialog: Node = _main.get("_render")
	if dialog == null or not dialog.has_method("render_for"):
		print("    no render dialog to draw them light and dark")
		return
	for backdrop: Array in [["light", Color(1, 1, 1)], ["dark", Color(0.11, 0.12, 0.14)]]:
		var settings := RenderSettings.new()
		settings.quality = RenderSettings.Quality.QUICK
		settings.size = Vector2i(1280, 800) if not _phone else Vector2i(780, 1688)
		settings.backdrop = backdrop[1]
		settings.view = "current"
		var said: String = await dialog.call("render_for", "picture", settings)
		var image: Image = dialog.call("last_picture")
		if image != null:
			var file: String = _pictures.path_join("%s_beside_real_%s.png" % [
				"phone" if _phone else "desk", backdrop[0]])
			image.save_png(file)
			print("    picture: %s" % file)
		else:
			print("    no %s render: %s" % [backdrop[0], said])


## A few strokes of its own on each, from the front three-quarter view.
func _shape(n: int) -> void:
	var mould: Mould = _editor.mould
	match n:
		0:
			_editor.turn_to(PI * 0.5, 0.15, 95.0)
			await _frames(6)
			await _press(_editor._tools["pull"])
			_editor.set_brush(9.0, 1.0)
			var fringe: Vector3 = _surface(Vector3(0, 8, 60), Vector3(0, 4, 8))
			for k: int in 3:
				await _stroke([fringe + Vector3(0, -2, 0), fringe + Vector3(0, 2, 1)])
		1:
			_editor.turn_to(PI * 0.5, 0.1, 95.0)
			await _frames(6)
			await _press(_editor._tools["inflate"])
			_editor.set_brush(10.0, 1.0)
			var side: Vector3 = _surface(Vector3(60, -8, 0), Vector3(8, -8, 0))
			for k: int in 3:
				await _stroke([side + Vector3(0, 4, -3), side + Vector3(0, -4, 3)])
		2:
			_editor.turn_to(0.4, 0.7, 95.0)
			await _frames(6)
			await _press(_editor._tools["pull"])
			_editor.set_brush(6.0, 1.0)
			var top: Vector3 = _surface(Vector3(12, 60, 6), Vector3(3, 6, 2))
			for k: int in 3:
				await _stroke([top, top + Vector3(1, 2, 0)])
			await _press(_editor._tools["smooth"])
			await _stroke([top + Vector3(-4, 0, 0), top + Vector3(4, 0, 0)])
	_check("the mould of %s changed by its strokes" % mould.base, mould.can_undo())
	await _shot("mould_%s" % mould.base)


# -- driving it ----------------------------------------------------------------------


func _surface(from: Vector3, toward: Vector3) -> Vector3:
	var hit: Dictionary = _editor.mould.pick(from, (toward - from).normalized())
	if hit.is_empty():
		_check("a ray from %s towards %s finds the surface" % [from, toward], false)
		return toward
	return hit["at"]


func _on_screen(point: Vector3) -> Vector2:
	return _editor.view().get_global_rect().position + _editor.on_view(point)


static func _furthest(a: PackedVector3Array, b: PackedVector3Array) -> float:
	var out: float = 0.0
	for v: int in mini(a.size(), b.size()):
		out = maxf(out, a[v].distance_to(b[v]))
	return out


static func _reach_along(points: PackedVector3Array, way: Vector3) -> float:
	var out: float = -INF
	for p: Vector3 in points:
		out = maxf(out, p.dot(way))
	return out


## A stroke through points of the part: the mouse's at a desk, a finger's
## on a phone.
func _stroke(points: Array) -> void:
	var seen: Array = points.map(func(p: Vector3) -> Vector2: return _on_screen(p))
	if _phone:
		_touch(0, seen[0], true)
	else:
		_move(seen[0], 0)
		await _frames(2)
		_button(seen[0], true, MOUSE_BUTTON_MASK_LEFT)
	await _frames(2)
	for n: int in range(1, seen.size()):
		var a: Vector2 = seen[n - 1]
		var b: Vector2 = seen[n]
		var steps: int = maxi(1, ceili(a.distance_to(b) / 4.0))
		for k: int in range(1, steps + 1):
			if _phone:
				_slide(0, a.lerp(b, float(k) / steps))
			else:
				_move(a.lerp(b, float(k) / steps), MOUSE_BUTTON_MASK_LEFT)
			await process_frame
	if _phone:
		_touch(0, seen[seen.size() - 1], false)
	else:
		_button(seen[seen.size() - 1], false, 0)
	await _frames(4)


func _touch(index: int, at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _slide(index: int, at: Vector2) -> void:
	var drag := InputEventScreenDrag.new()
	drag.index = index
	drag.position = _as_event(at)
	Input.parse_input_event(drag)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _move(at: Vector2, mask: int = 0) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = mask
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool, mask: int) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = mask
	Input.parse_input_event(event)


## A finger's tap on a phone's layout, the mouse's click on a desktop's.
func _tap(at: Vector2) -> void:
	if _phone:
		for down: bool in [true, false]:
			_touch(0, at, down)
			await _frames(2)
		await _frames(6)
		return
	_move(at)
	await _frames(4)
	for down: bool in [true, false]:
		_button(at, down, MOUSE_BUTTON_MASK_LEFT if down else 0)
		await _frames(2)
	await _frames(6)


## Every list it is in scrolled to show it.
func _reveal(control: Control) -> void:
	var up: Node = control.get_parent()
	var moved: bool = false
	while up != null:
		if up is ScrollContainer:
			(up as ScrollContainer).ensure_control_visible(control)
			moved = true
		up = up.get_parent()
	if moved:
		await _frames(3)


func _press(control: Control) -> void:
	if control == null:
		_check("there is a control to press", false)
		return
	await _reveal(control)
	await _tap(control.get_global_rect().get_center())


func _key(code: Key, text: String = "") -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		if not text.is_empty():
			event.unicode = text.unicode_at(0)
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _type_into(line: LineEdit, text: String) -> void:
	await _press(line)
	line.grab_focus()
	line.select_all()
	await _key(KEY_BACKSPACE)
	for character: String in text:
		var code: Key = OS.find_keycode_from_string(character.to_upper())
		if character == " ":
			code = KEY_SPACE
		await _key(code, character)
	await _frames(4)
	line.release_focus()


func _find_button(under: Node, text: String) -> Button:
	for child: Node in under.find_children("*", "Button", true, false):
		if (child as Button).text == text and (child as Button).is_visible_in_tree():
			return child
	return null


## The hair's place relative to the head's; null when either is missing.
func _seat(bricks: Array, hair: String) -> Variant:
	var head: BrickWorld.Brick = null
	var worn: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in bricks:
		if brick.part_id == hair:
			worn = brick
		elif brick.part_id.begins_with("3626"):
			head = brick
	if head == null or worn == null:
		return null
	return head.transform.affine_inverse() * worn.transform


func _read_by(panel: Control) -> void:
	var since: int = Time.get_ticks_msec()
	await _frames(3)
	while bool(panel.call("reading")) and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(10)


func _shot(name: String) -> void:
	if _pictures.is_empty():
		return
	await RenderingServer.frame_post_draw
	_shots += 1
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_pictures)
	var path: String = _pictures.path_join("%s%02d_%s.png" % ["phone_" if _phone else "desk_",
		_shots, name])
	image.save_png(path)
	print("    picture: %s" % path)


func _finish() -> void:
	_forget(PROBE_DIR)
	print("")
	if _failures == 0:
		print("figmould probe: a hair by strokes and one from an STL, each worn, placed, saved, "
			+ "opened again and by someone who never had them, exactly")
	else:
		print("figmould probe: %d FAILED" % _failures)
	quit(1 if _failures else 0)


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(name))
	for name: String in DirAccess.get_directories_at(dir):
		_forget(dir.path_join(name))
	DirAccess.remove_absolute(dir)
