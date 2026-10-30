## A set built from its own bin, at Studio's pace (docs/APP_UX2.md, pace):
## the set's number typed into the bin's search and Build from it, then the
## walk's parts, one after another as the set's file has them, each taken
## from its tile and put where the file puts it, through the window as a
## person does it: keys, clicks and typing sent as input events against the
## real scene. Every action is counted as docs/CADTASK.md's flow counts
## them: a click somewhere new a point and a click, a click where the pointer
## is a click, a key or a character typed 1, a notch of the wheel 1, the
## scroll bar dragged 3 (a point, a press, a point, a release).
##
##   godot --path . --resolution 1280x720 --script src/dev/setwalk_probe.gd [-- only=8841-1,5762-1 shots=1 from=library]
##
## The walks are 8841-1 Balance's first 25 parts (the 25 docs/CADTASK.md
## section 9 built, at 29.76 actions a part, and appux371's walk with
## Connect at 17.80) and 5762-1 Plane's first 25. The bar is 12 actions a
## part or fewer for each, from the bin's search to the last click, and
## every part exact: its number and colour as the set's bin has them, its
## place to 0.05 LDU and its turn to 0.002, or a turn the part looks the
## same in by its own mesh, against the file, from where the first part
## went down. Each part goes on by the way a person who knows the app
## takes for it: by its studs where it sits on studs, by its ghost onto a
## pin or an axle, by Connect (N) where the ghost cannot, and the rest
## typed (Enter) where the pointer cannot slide it. Which view and which
## R and T presses is judged first, uncounted, as an expert sees it; then
## the keys, the view cube's clicks and every aim are made and counted.
## from=library takes each part from the whole library instead, as section
## 9's run did: the search, the number, the tile and the colour's swatch.
## PROBE_SIZE=1400x900 runs it at the larger window. Pictures go to
## shots/setwalk/WxH/ with shots=1 (WxH-library/ from the library), the
## rows beside them as <set>.json.
extends SceneTree

const SETS := "res://vendor/omr/files/"
## The set, its file, and the file's parts in the order the walk puts them
## (by their place in the file, from 1). 8841-1's first step is 24 parts in
## one picture, and the file lists the top beam's 1 x 4 seventh, in the air
## until the column and its axle are up: they go in the order section 9's
## run put them, each on what holds it. The plane goes in the file's order.
const WALKS := [
	["8841-1", "8841-1_Balance.mpd", [1, 2, 3, 17, 16, 20, 4, 5, 13, 14, 6, 18, 15, 19, 21, 22,
		7, 12, 10, 8, 11, 9, 23, 24, 25]],
	["5762-1", "5762-1_Plane.mpd", [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17,
		18, 19, 20, 21, 22, 23, 24, 25]],
]
const BAR := 12.0
## Following the set's booklet (PartsBin.build_from's booklet, appux2 bin2
## follow-up): the step's parts first in the bin. 8841-1's walk was 6.76 a
## part at 1280 x 720 with the bin most held first, a fifth of it scrolling
## to parts held once (docs/CADTASK.md section 11); the plane's 6.36, no
## worse.
const BOOKLET_BAR: Dictionary = {"8841-1": 5.5, "5762-1": 6.36}
const EXACT_PLACE := 0.05
const EXACT_TURN := 0.002
## Aims after the first, each a pointer moved by what the ghost is off.
const CORRECTIONS := 4
## How near the ghost has to come, in LDU, for the rest to be typed.
const NEAR := 40.0

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary
var _store: ModelStore
var _shell: Shell
var _verbs: EditVerbs
var _bin: PartsBin
var _acts: Dictionary = {}
var _pointer := Vector2.ZERO
var _shots: bool = false
## From where the file has a part to where the model has it: set by the
## first part, which goes down wherever the view's middle is.
var _shift := Vector3.ZERO
var _rows: Array = []
var _shapes: Dictionary = {}
## The walk taken from the whole library instead, as section 9's run took
## it: each part's number typed into the search and its colour chosen.
var _from_library: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _until(func() -> bool:
		var bin: PartsBin = _main.get("_bin")
		return bin != null and int(bin.get("_offerable")) > 0, 1200)
	await _frames(30)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_verbs = _main.get("_verbs")
	_bin = _main.get("_bin")
	var dock: Variant = _main.get("_bin_dock")
	if dock != null and not dock.is_open():
		dock.set_open(true)
	print("  window %s" % DisplayServer.window_get_size())
	var only: String = ""
	var from: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("only="):
			only = arg.substr(5)
		elif arg == "shots=1":
			_shots = true
		elif arg == "from=library":
			_from_library = true
	var lines: Array = []
	for walk: Array in WALKS:
		if only.is_empty() or str(walk[0]) in only.split(","):
			print("\n  -- %s, %s" % [walk[0], walk[1]])
			lines.append(await _walk(str(walk[0]), str(walk[1]), walk[2]))
	print("")
	for line: String in lines:
		print("  %s" % line)
	print("")
	print("setwalk: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


# -- a walk -------------------------------------------------------------------------


func _walk(number: String, file: String, order: Array) -> String:
	var truth: Array = await _truth_of(file)
	await _rest()
	var began: int = Time.get_ticks_msec()
	_count_from()
	if _from_library:
		_bin.leave_set()
		await _frames(10)
	else:
		await _build_from(number, file)
	var from_bin: Dictionary = _acts.duplicate()
	var spent: int = _total()
	if not _from_library:
		_check("%s's bin from its number typed and one click (its booklet, else Build from it), in %d actions (%s): \"%s\""
			% [number, spent, _acts, _bin.set_showing()], _bin.set_showing().begins_with(number))
	_rows = []
	var count: int = order.size()
	var exact: int = 0
	var how: Dictionary = {}
	for n: int in order:
		var row: Dictionary = await _put(truth, n - 1, n == order[0])
		_rows.append(row)
		spent += int(row["acts"])
		if bool(row["exact"]):
			exact += 1
		how[row["how"]] = int(how.get(row["how"], 0)) + 1
		print("    %s #%d %s in %d: %s in %d actions %s%s" % [number, n, row["part"],
			row["colour"], "exact" if row["exact"] else "NOT EXACT (%s)" % row["why"],
			row["acts"], row["spent"], " by " + str(row["how"])])
		if _shots:
			await _shot("%s_%02d" % [number, n])
	# The model against the file, part by part, as it stands at the end.
	var wrong: PackedStringArray = _against_file(truth, order)
	_check("%s: the model is the file's first %d parts, each exact (%s)" % [number, count,
		", ".join(wrong.slice(0, 4)) if not wrong.is_empty() else "none off"],
		wrong.is_empty() and exact == count)
	var per_part: float = float(spent) / count
	var path: String = _out("%s.json" % number)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var out := FileAccess.open(path, FileAccess.WRITE)
	out.store_string(JSON.stringify({"set": number, "file": file, "bin": from_bin,
		"parts": _rows, "actions": spent, "per_part": per_part}, " "))
	out.close()
	var line: String = "%s: %d/%d exact; %d actions (%.2f a part, the bin's %d among them), %.1f s a part; by %s" % [
		file.get_basename(), exact, count, spent, per_part, from_bin.values().reduce(
		func(a: int, b: int) -> int: return a + b, 0), (Time.get_ticks_msec() - began) / 1000.0 / count,
		how]
	var bar: float = BAR if _from_library else float(BOOKLET_BAR.get(number, BAR))
	_check("%s: %.2f actions a part from the %s, the bar %.2f" % [number, per_part,
		"whole library" if _from_library else "set's bin, following its booklet", bar],
		per_part <= bar)
	return line


## The set's number typed into the bin's search, and the booklet of the
## model walked chosen among the set's ([param file]'s), which builds from
## the set's parts; Build from it where the bin offers no such choice.
func _build_from(number: String, file: String) -> void:
	var search: LineEdit = _bin.controls_by_name()["part search"]
	await _act_click(search.get_global_rect().get_center())
	await _type(number)
	var go: Button = _bin.controls_by_name()["set build"]
	var offered: bool = await _until(func() -> bool: return go.is_visible_in_tree(), 1200)
	# A lambda's locals are its own copies: the button is read again after.
	var named: String = "booklet " + file.get_basename()
	await _until(func() -> bool:
		var shown: Button = _bin.controls_by_name().get(named)
		return shown != null and shown.is_visible_in_tree(), 120)
	var booklet: Button = _bin.controls_by_name().get(named)
	var chosen: Button = booklet if booklet != null and booklet.is_visible_in_tree() else go
	print("    typed \"%s\" into the search; %s; %s at %s" % [search.text,
		"offered: " + go.text if offered else "nothing offered",
		"its booklet " + chosen.text if chosen == booklet else "no booklet of %s offered" % file,
		chosen.get_global_rect()])
	await _act_click(chosen.get_global_rect().get_center())
	await _until(func() -> bool: return not _bin.set_showing().is_empty(), 600)
	await _frames(10)
	var followed: Dictionary = _bin.call("booklet_followed") if _bin.has_method("booklet_followed") else {}
	print("    the bin follows %s" % ("no booklet" if followed.is_empty()
		else "%s, step %d of %d, %s first" % [followed["name"], followed["step"], followed["steps"],
			", ".join(followed["first"])]))


## Part [param n] of the walk taken from the bin and put where the file has
## it: what it cost, and whether it went exactly there.
func _put(truth: Array, n: int, first: bool) -> Dictionary:
	var part: String = truth[n][0]
	var colour: int = truth[n][1]
	var want: Transform3D = truth[n][2]
	want.origin += _shift
	_count_from()
	var before: int = _newest_id()
	var row: Dictionary = {"n": n + 1, "part": part, "colour": colour, "how": "", "why": ""}
	var key: String = ""
	if _from_library:
		key = await _take_from_library(part, colour)
	else:
		key = await _take(part, colour)
	row["key"] = key
	if key.is_empty():
		row["why"] = "no tile for it in the set's bin"
	elif first:
		row["how"] = await _first(truth[n][2])
	else:
		# A part that goes on a pin, an axle or into a hole of a part down
		# goes on by that joint: its ghost onto it, then Connect. One that
		# sits on studs or hangs under them goes on by its studs.
		var pair: Array = _goes_on(part, want)
		if not pair.is_empty():
			var site: JointSnap.End = pair[1]
			var aim: Vector3 = _aim_point_for(site, _end_at(part, int(pair[0]), want))
			await _look_at([aim], func(hit: Vector3, id: int) -> bool:
				return id == site.brick or hit.distance_to(aim) < 12.0, site.axis)
			row["how"] = await _onto_joint(part, want, pair)
			if row["how"] == "":
				row["how"] = await _by_connect(part, want, pair)
		if row["how"] == "":
			row["how"] = await _by_studs(part, want)
	if first:
		want = truth[n][2]
		want.origin += _shift
	var put: BrickWorld.Brick = _newest()
	var exact: bool = put != null and put.id != before and _same(put.part_id, put.transform, want) \
		and Collection.key_of(put.part_id, put.color_code, _library) == key
	if not exact and row["why"] == "":
		row["why"] = "nothing put down" if put == null or put.id == before else "%s %d at %s" % [
			put.part_id, put.color_code, _ldr_of(put.transform)]
	row["acts"] = _total()
	row["spent"] = _acts.duplicate()
	row["exact"] = exact
	if not exact:
		# Off: taken off (uncounted) and laid as the file has it, so the
		# walk goes on from the model it should be.
		if put != null and put.id != before:
			_builder.remove_brick_id(put.id)
		var id: int = _world.add_brick(part, colour, want)
		_builder.register(id, part, want)
	return row


## The part's tile in the set's bin clicked, scrolled to if it is out of
## sight: the bin's key for it, or "" when the set has no tile for it. The
## same part and colour still in hand from the last is not taken again.
func _take(part: String, colour: int) -> String:
	var key: String = Collection.key_of(part, colour, _library)
	var bin: SetBin = _bin.get("_set_bin")
	if bin == null:
		return ""
	if not bin.have.has(key):
		# The file's colour is not the set's (5762-1's old greys, where the
		# set has Light Bluish Grey): the set's own, as building from it
		# gives it.
		var own: String = ""
		for other: String in bin.order:
			if Collection.part_of(other) == Collection.part_of(key):
				own = other
				break
		if own.is_empty():
			return ""
		key = own
	if _builder.held_part == Collection.part_of(key) \
			and _builder.held_color == Collection.colour_of(key) and _builder.has_preview():
		return key
	# The bin as a person sees it: counted again a tenth of a second after
	# a part goes in, and listed again when its booklet's step turns.
	await _until(func() -> bool: return int(_bin.get("_counted_at")) == _world.revision, 60)
	await _frames(2)
	var scroll: ScrollContainer = _bin.controls_by_name()["parts list"]
	var cell: Button = _cell(key)
	if cell == null:
		# Not made yet: the bin makes its tiles as it is scrolled to them.
		await _drag_bar(scroll, null, key)
		cell = _cell(key)
	if cell == null:
		return ""
	# More than a row away: the scroll bar dragged, one action. A row or
	# less: the wheel, a notch an action.
	var off: float = _off_screen(scroll, cell)
	if absf(off) > cell.size.y * 1.2:
		await _drag_bar(scroll, cell)
	for _n: int in 40:
		off = _off_screen(scroll, cell)
		if off == 0.0:
			break
		await _act_wheel(scroll.get_global_rect().get_center(),
			MOUSE_BUTTON_WHEEL_DOWN if off > 0.0 else MOUSE_BUTTON_WHEEL_UP)
	await _act_click(cell.get_global_rect().get_center())
	await _until(func() -> bool: return _library.mesh_for(Collection.part_of(key)) != null, 600)
	await _frames(3)
	return key


## The part taken from the whole library: its number typed into the search
## (a click on it, Ctrl+A, the number) and its tile clicked, and its colour
## chosen: its swatch clicked where the palette shows it, else its number
## typed into the palette's own search and the swatch clicked. The key, or
## "" when the search does not show it.
func _take_from_library(part: String, colour: int) -> String:
	var key: String = Collection.key_of(part, colour, _library)
	if _builder.held_part == part and _builder.held_color == colour and _builder.has_preview():
		return key
	var named: Dictionary = _bin.controls_by_name()
	if _builder.held_part != part:
		var search: LineEdit = named["part search"]
		await _act_click(search.get_global_rect().get_center())
		await _act_key_ctrl(KEY_A)
		await _type(part)
		var cell: Button = null
		for _n: int in 600:
			cell = _library_tile(part)
			if cell != null:
				break
			await process_frame
		if cell == null:
			return ""
		var scroll: ScrollContainer = named["parts list"]
		if absf(_off_screen(scroll, cell)) > cell.size.y * 1.2:
			await _drag_bar(scroll, cell)
		for _n: int in 40:
			var off: float = _off_screen(scroll, cell)
			if off == 0.0:
				break
			await _act_wheel(scroll.get_global_rect().get_center(),
				MOUSE_BUTTON_WHEEL_DOWN if off > 0.0 else MOUSE_BUTTON_WHEEL_UP)
		await _act_click(cell.get_global_rect().get_center())
		await _until(func() -> bool: return _library.mesh_for(part) != null, 600)
	if _builder.held_color != colour:
		var palette: Control = named["palette"]
		var swatch: Control = (_bin.get("_swatches") as Dictionary).get(colour)
		if swatch == null or not swatch.is_visible_in_tree() \
				or not palette.get_global_rect().encloses(swatch.get_global_rect()):
			var find: LineEdit = named["colour find"]
			await _act_click(find.get_global_rect().get_center())
			await _act_key_ctrl(KEY_A)
			await _type(str(colour))
			await _frames(10)
			swatch = (_bin.get("_swatches") as Dictionary).get(colour)
		if swatch == null:
			return ""
		await _act_click(swatch.get_global_rect().get_center())
	await _frames(3)
	return key


## The tile of [param part] the search shows, or null.
func _library_tile(part: String) -> Button:
	for cell: Node in (_bin.get("_grid") as GridContainer).get_children():
		if str(cell.get_meta("part", "")) == part \
				or Collection.part_of(str(cell.get_meta("key", ""))) == part:
			return cell
	return null


## How far [param cell] is below the list's foot (more than 0) or above its
## head (less than 0), in pixels; 0 when it is all in sight.
func _off_screen(scroll: ScrollContainer, cell: Control) -> float:
	var shown: Rect2 = scroll.get_global_rect()
	var at: Rect2 = cell.get_global_rect()
	if shown.encloses(at):
		return 0.0
	return at.end.y - shown.end.y if at.position.y > shown.position.y else at.position.y - shown.position.y


## The list's scroll bar dragged by its grabber until [param cell] is in
## sight: the pointer to the grabber, and the drag, its press, its move and
## its letting go, as the keystroke-level model counts it (P B P B): three.
## With [param key], the tile is looked for as the bar goes, and the bar
## dragged down while the bin has not yet made it.
func _drag_bar(scroll: ScrollContainer, cell: Control, key: String = "") -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if not bar.is_visible_in_tree():
		return
	_acts["point"] = int(_acts["point"]) + 1
	_acts["drag"] = int(_acts.get("drag", 0)) + 2
	var track: Rect2 = bar.get_global_rect()
	var span: float = maxf(bar.max_value - bar.min_value, 1.0)
	var grab: float = maxf(bar.page / span * track.size.y, 12.0)
	var from := Vector2(track.get_center().x, track.position.y
		+ (bar.value - bar.min_value) / span * (track.size.y - grab) * span / maxf(span - bar.page, 1.0)
		+ grab * 0.5)
	await _move(from)
	_button(from, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	var at: Vector2 = from
	for _n: int in 200:
		if not key.is_empty():
			cell = _cell(key)
		var off: float = _off_screen(scroll, cell) if cell != null else 1.0e6
		if off == 0.0:
			break
		at.y += clampf(off * (track.size.y - grab) / maxf(span - bar.page, 1.0), -6.0, 6.0) \
			if absf(off) > 1.0 else signf(off)
		var event := InputEventMouseMotion.new()
		event.position = _as_event(at)
		event.global_position = event.position
		event.relative = event.position - _as_event(_pointer)
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
		_pointer = at
		Input.parse_input_event(event)
		await _frames(1)
	_button(at, MOUSE_BUTTON_LEFT, false)
	await _frames(4)


## The first part: turned as the file has it and put down in the view's
## middle, wherever that is; every other part goes where the file has it
## from there.
func _first(want: Transform3D) -> String:
	await _turn_hand(want.basis)
	var middle: Vector2 = _camera.get_viewport().get_visible_rect().get_center()
	var view: Rect2 = _camera.seen_rect()
	if view.size.x > 0.0:
		middle = view.get_center()
	await _act_move(middle)
	await _again(middle)
	if not _builder.has_preview() or not _builder.can_place():
		return ""
	var at: Transform3D = _builder.ghost_transform()
	await _act_click(middle)
	var put: BrickWorld.Brick = _newest()
	if put == null:
		return ""
	_shift = put.transform.origin - want.origin
	print("    the first part went down %s from the file's place" % _shift)
	return "studs"


## Onto the pin, axle or hole of a part down it goes on by, by its ghost:
## the pointer at the joint, then T and R until the ghost is the file's.
func _onto_joint(part: String, want: Transform3D, pair: Array) -> String:
	var end_index: int = pair[0]
	var site: JointSnap.End = pair[1]
	var at: Vector2 = _aim_for(site, _end_at(part, end_index, want))
	if not _in_view(at):
		print("      joint: its place at %s is out of the view %s" % [at, _camera.seen_rect()])
		return ""
	await _act_move(at)
	if not _builder.is_on_joint():
		print("      joint: aimed at %s, the ghost is not on a joint (%s)" % [at, _ghost_words(want)])
		return ""
	var to: Variant = await _turn_onto(want, at)
	if to == null or not _exact_ghost(want):
		print("      joint: no T and R puts it there (%s)" % _ghost_words(want))
		to = await _turn_onto(want, at, true)
		if to != null and await _typed_rest(want):
			return "joint, typed"
		return ""
	await _act_click(to)
	return "joint"


## Connect: N, the point it goes on by, the joint, and T and R.
func _by_connect(part: String, want: Transform3D, pair: Array) -> String:
	var end_index: int = pair[0]
	var site: JointSnap.End = pair[1]
	var at: Vector2 = _aim_for(site, _end_at(part, end_index, want))
	if not _in_view(at):
		print("      connect: its place at %s is out of the view %s" % [at, _camera.seen_rect()])
		return ""
	if _pointer.distance_to(at) > 1.0:
		await _act_move(at)
	await _act_key_of("mode_connect")
	var on: Vector2 = _point_on_screen(end_index)
	if on.x < 0:
		print("      connect: no point %d offered (%s, %d points)" % [end_index,
			_verbs.connect_tool.stage, _verbs.connect_tool.points.size()])
		await _act_key(KEY_ESCAPE)
		return ""
	await _act_click(on)
	await _act_move(at)
	var to: Variant = await _turn_onto(want, at)
	if to == null or not _exact_ghost(want):
		print("      connect: no T and R puts it there (%s)" % _ghost_words(want))
		to = await _turn_onto(want, at, true)
		if to != null and await _typed_rest(want):
			return "connect, typed"
		await _act_key(KEY_ESCAPE)
		return ""
	# Put down, it stays in hand by the same point; the next tile taken
	# ends Connect, so nothing is pressed to leave it.
	await _act_click(to)
	return "connect"


## By its studs: turned as the file has it, the pointer at what holds it
## ([method _aim_points]), the view turned to see that first, then moved by
## what the ghost is off, as a person nudges it.
func _by_studs(part: String, want: Transform3D) -> String:
	await _turn_hand(want.basis)
	for aim: Array in _aim_points(part, want):
		var point: Vector3 = aim[0]
		await _look_at([point], func(hit: Vector3, _id: int) -> bool:
			return hit.distance_to(point) < 4.0, aim[1])
		var at: Vector2 = _screen(point)
		if not _in_view(at):
			print("      studs: %s at %s is out of the view %s" % [point, at, _camera.seen_rect()])
			continue
		await _act_move(at)
		await _again(at)
		for _n: int in CORRECTIONS:
			if _exact_ghost(want) or not _builder.has_preview():
				break
			var ghost: Transform3D = _builder.ghost_transform()
			var step: Vector2 = _screen(point + (want.origin - ghost.origin)) - _screen(point)
			if step.length() < 1.5:
				break
			at += step
			if not _in_view(at):
				break
			await _act_move(at)
			await _again(at)
		if _exact_ghost(want):
			await _act_click(at)
			return "studs"
		print("      studs: aimed at %s (%s), %s" % [point, aim[1], _ghost_words(want)])
		if _turned_near(want) and await _typed_rest(want):
			return "studs, typed"
	return ""


## Where the ghost stands against [param want], in words.
func _ghost_words(want: Transform3D) -> String:
	if not _builder.has_preview():
		return "no ghost"
	var at: Transform3D = _builder.ghost_transform()
	return "the ghost %s off%s%s%s" % [at.origin - want.origin,
		"" if _same(_builder.held_part, Transform3D(at.basis, want.origin), want) else ", turned otherwise",
		"" if _builder.can_place() else ", no room", ", on a joint" if _builder.is_on_joint() else ""]


## Where a person points to put [param part] down where [param want] has
## it, each with the way the face pointed at looks: the top of what it
## stands on under its middle, or under the stud nearest its middle that
## something holds (a 1 x 8 across two plates); the side of a part it goes
## against, where they meet (a 1 x 12 against a 1 x 2); the underside of
## what it hangs from. Each a hair inside the part pointed at.
func _aim_points(part: String, want: Transform3D) -> Array:
	var box: AABB = (want * _library.mesh_for(part).bounds).abs()
	var middle: Vector3 = box.get_center()
	var below: Array = []
	var above: Array = []
	# A stud's height off the top: what hangs from it meets its top face.
	var top: float = box.end.y - 4.0
	var x: float = box.position.x + 10.0
	while x < box.end.x:
		var z: float = box.position.z + 10.0
		while z < box.end.z:
			var foot := Vector3(x, box.position.y, z)
			var hit: BrickLattice.Hit = _builder.lattice.raycast(foot + Vector3.UP * 2.0, Vector3.DOWN, 5.0)
			if hit.is_valid():
				below.append(foot + Vector3.DOWN * 0.5)
			var head := Vector3(x, top, z)
			hit = _builder.lattice.raycast(head + Vector3.DOWN * 2.0, Vector3.UP, 9.0)
			if hit.is_valid():
				above.append(Vector3(x, top + (hit.distance - 2.0) + 0.5, z))
			z += 20.0
		x += 20.0
	var nearest := func(a: Vector3, b: Vector3) -> bool:
		return Vector2(a.x - middle.x, a.z - middle.z).length() \
			< Vector2(b.x - middle.x, b.z - middle.z).length()
	below.sort_custom(nearest)
	above.sort_custom(nearest)
	var out: Array = []
	# On its side (a round plate in a clip's ring): along its own down, at
	# the middle of its underside a stud's height out, where what holds it
	# is, as a person points at the ring (CADTASK section 9).
	var up: Vector3 = (want.basis * Vector3.UP).normalized()
	if absf(up.y) < 0.9:
		var bounds: AABB = _library.mesh_for(part).bounds
		var under: Vector3 = want * Vector3(bounds.get_center().x, bounds.position.y,
			bounds.get_center().z)
		out.append([under - up * 4.0, up])
	for point: Vector3 in below.slice(0, 2):
		out.append([point, Vector3.UP])
	out.append_array(_against(box))
	for point: Vector3 in above.slice(0, 2):
		out.append([point, Vector3.DOWN])
	return out


## Where the box [param box] meets the side of a part down: the middle of
## where they meet, a hair inside that part, and the way its side looks.
func _against(box: AABB) -> Array:
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if _store.scenery.has(brick.id):
			continue
		var other: AABB = (brick.transform * _library.mesh_for(brick.part_id).bounds).abs()
		for axis: int in [0, 2]:
			var across: int = 2 - axis
			var normal := Vector3.ZERO
			if absf(box.position[axis] - other.end[axis]) < 0.6:
				normal[axis] = 1.0
			elif absf(box.end[axis] - other.position[axis]) < 0.6:
				normal[axis] = -1.0
			else:
				continue
			var low := Vector2(maxf(box.position[across], other.position[across]),
				maxf(box.position.y, other.position.y))
			var high := Vector2(minf(box.end[across], other.end[across]),
				minf(box.end.y, other.end.y))
			if high.x - low.x < 4.0 or high.y - low.y < 4.0:
				continue
			var point := Vector3.ZERO
			point[axis] = box.position[axis] if normal[axis] > 0.0 else box.end[axis]
			point[axis] -= normal[axis] * 0.5
			point[across] = (low.x + high.x) * 0.5
			# At the bottom plate of what they share: a part against a side
			# goes at the plate pointed at (CADTASK section 9).
			point.y = low.y + 4.0
			out.append([point, normal])
	return out


## Where a person points to put a part's [param mine] on [param site], in
## the world.
func _aim_point_for(site: JointSnap.End, mine: JointSnap.End) -> Vector3:
	if mine.is_male():
		var eye: Vector3 = _camera.global_position
		return site.aimed(eye, (site.at - eye).normalized())
	return mine.at


# -- the view ----------------------------------------------------------------------


## The view turned, by the fewest keys and clicks a person has for it, until
## each of [param points] is in sight: on the model's part of the window,
## and the line from the eye to it meeting first what [param seen] says
## (the point it met and the part's id). [param facing] is the way the face
## aimed at looks: a view along it, or square to it for a joint, is
## wanted. The ways are tried as a person judges them before turning,
## uncounted; the one taken is pressed, counted.
func _look_at(points: Array, seen: Callable, facing: Vector3) -> void:
	if _sees(points, seen, facing):
		return
	var was: Dictionary = _camera.aim()
	var found: Array = []
	for way: Array in _view_ways():
		await _view_by(way, false)
		if _sees(points, seen, facing):
			found = way
			break
		_camera.aim_at(was)
		await _settle()
	_camera.aim_at(was)
	await _settle()
	if found.is_empty():
		print("      view: no view of %d keys or clicks shows %s" % [2, points])
		return
	print("      view: %s" % [found])
	await _view_by(found, true)


## The ways to turn the view, fewest actions first: a view key, a click on
## the view cube's face, edge or corner in sight, Fit; then Fit after each.
func _view_ways() -> Array:
	var ones: Array = [["key", "fit"]]
	for view: String in ["view_default", "view_front", "view_back", "view_left", "view_right",
			"view_top", "view_bottom", "view_iso"]:
		ones.append(["key", view])
	for from: Vector3 in _cube_regions():
		ones.append(["cube", from])
	var ways: Array = []
	for one: Array in ones:
		ways.append([one])
	for one: Array in ones:
		if str(one[1]) != "fit":
			ways.append([one, ["key", "fit"]])
	return ways


## The directions the view cube's faces, edges and corners in sight look
## from, as a click on each gives them.
func _cube_regions() -> Array:
	var cube: ViewCube = _main.get("_gizmo")
	var out: Array = []
	if cube == null or not cube.is_visible_in_tree():
		return out
	for face: Dictionary in ViewCube.FACES:
		var n: Vector3 = face["normal"]
		if (cube.call("_seen", n) as Vector3).z <= 0.02:
			continue
		for a: float in [-0.85, 0.0, 0.85]:
			for b: float in [-0.85, 0.0, 0.85]:
				var local: Vector2 = cube.call("_to_screen", n + face["u"] * a + face["v"] * b)
				var from: Vector3 = cube.call("_region", local)
				if from != Vector3.ZERO and not out.has(from):
					out.append(from)
	return out


## Each step of [param way] done: by its key or its click on the cube when
## [param counted], straight on the camera when only judged.
func _view_by(way: Array, counted: bool) -> void:
	for step: Array in way:
		if step[0] == "key":
			if counted:
				await _act_key_of(str(step[1]))
			elif step[1] == "fit":
				_camera.frame(_main.call("_built_bounds"))
			else:
				_camera.set_view(str(step[1]).trim_prefix("view_").replace("iso", "isometric"))
		else:
			var from: Vector3 = step[1]
			if counted:
				var at: Variant = _cube_point(from)
				if at == null:
					_camera.look_from(from)
				else:
					await _act_click(at)
			else:
				_camera.look_from(from)
		await _settle()


## Where on the window a click on the view cube looks from [param from].
func _cube_point(from: Vector3) -> Variant:
	var cube: ViewCube = _main.get("_gizmo")
	for face: Dictionary in ViewCube.FACES:
		var n: Vector3 = face["normal"]
		if (cube.call("_seen", n) as Vector3).z <= 0.02:
			continue
		for a: float in [0.0, -0.85, 0.85]:
			for b: float in [0.0, -0.85, 0.85]:
				var local: Vector2 = cube.call("_to_screen", n + face["u"] * a + face["v"] * b)
				if cube.call("_region", local) == from:
					return cube.get_global_transform() * local
	return null


## Whether each of [param points] is in sight now (see [method _look_at]).
func _sees(points: Array, seen: Callable, facing: Vector3) -> bool:
	var eye: Vector3 = _camera.global_position
	# From under the ground the line meets the baseplate first.
	if eye.y < Builder.GROUND_CELL * BrickLattice.CELL + 1.0:
		return false
	for point: Vector3 in points:
		if _camera.is_position_behind(point) or not _in_view(_screen(point)):
			return false
		var way: Vector3 = (point - eye).normalized()
		# A face seen edge on is not aimed at: a top from above, an
		# underside from below, a hole from in front of it or beside it.
		if facing == Vector3.UP and way.y > -0.2:
			return false
		if facing == Vector3.DOWN and way.y < 0.2:
			return false
		if absf(facing.y) < 0.9 and absf(way.dot(facing)) < 0.3:
			return false
		var hit: BrickLattice.Hit = _builder.lattice.raycast(eye, way)
		if not hit.is_valid():
			return false
		if not bool(seen.call(eye + way * hit.distance, hit.brick_id)):
			return false
	return true


## Until the view has come to rest.
func _settle() -> void:
	var last: Transform3D = _camera.global_transform
	for _n: int in 120:
		await _frames(2)
		var now: Transform3D = _camera.global_transform
		if now.origin.distance_to(last.origin) < 0.01 and now.basis.is_equal_approx(last.basis):
			break
		last = now
	await _frames(2)


## The hand turned to [param basis] by T and R, as a person turns a part to
## the way the booklet shows it before aiming it.
func _turn_hand(basis: Basis) -> void:
	var face: String = BrickLattice.face_of(basis)
	var rot: int = BrickLattice.turns_about(basis, face)
	var faces: Array[String] = BrickLattice.FACES
	var tips: int = posmod(faces.find(face) - maxi(faces.find(_builder.held_face), 0), faces.size())
	if tips > faces.size() / 2:
		tips -= faces.size()
	for _n: int in absi(tips):
		await _act_key(KEY_T, tips < 0)
	var turns: int = posmod(rot - _builder.held_rotation, 4)
	if turns == 3:
		await _act_key(KEY_R, true)
	else:
		for _n: int in turns:
			await _act_key(KEY_R)


## Each part against the file's, from the first: what is off, in words.
func _against_file(truth: Array, order: Array) -> PackedStringArray:
	var wrong := PackedStringArray()
	var built: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			built.append(brick)
	if built.size() != order.size():
		wrong.append("%d parts in the model" % built.size())
	for index: int in order:
		var n: int = index - 1
		var want: Transform3D = truth[n][2]
		want.origin += _shift
		var found: bool = false
		for brick: BrickWorld.Brick in built:
			if Collection.part_of(Collection.key_of(brick.part_id, 0, _library)) \
					== Collection.part_of(Collection.key_of(truth[n][0], 0, _library)) \
					and _same(brick.part_id, brick.transform, want):
				found = true
				built.erase(brick)
				break
		if not found:
			wrong.append("#%d %s" % [n + 1, truth[n][0]])
	return wrong


# -- what a person aims at -----------------------------------------------------------


## The point of [param part] that, where the file has it at [param want], is on
## a joint of a part down, and that joint: [index in its points, site], the
## nearest the joint's line first and then a pin's or axle's middle nearest
## the hole's. [] for none.
func _goes_on(part: String, want: Transform3D) -> Array:
	var best: Array = []
	var best_off: float = INF
	var ends: Array = JointSnap.ends_for(_library, part)
	var eye: Vector3 = _camera.global_position
	for n: int in ends.size():
		var mine: JointSnap.End = (ends[n] as JointSnap.End).placed(want, 0)
		for site: JointSnap.End in JointSnap.sites_in(_world, _library):
			if not JointSnap.mates(ends[n], site) or absf(mine.axis.dot(site.axis)) < 0.999:
				continue
			var off: float = _off_line(mine.at, site)
			# On its line and on it, not further along the same line: a
			# second 1 x 8's holes are in line with a pin in the first's.
			if off > 2.0 or _gap(mine, site) > 2.0:
				continue
			off += _gap(mine, site) * 0.01 + site.at.distance_to(eye) * 0.00001
			if off < best_off:
				best_off = off
				best = [n, site]
	return best


static func _gap(a: JointSnap.End, b: JointSnap.End) -> float:
	var male: JointSnap.End = a if a.is_male() else b
	var other: JointSnap.End = b if male == a else a
	if not male.is_male() or other.is_male():
		return a.at.distance_to(b.at)
	var from: Vector3 = male.at - male.axis * male.back
	var to: Vector3 = male.at + male.axis * male.reach
	return other.at.distance_to(Geometry3D.get_closest_point_to_segment(other.at, from, to))


## Where a person points to put [param mine] on [param site]: a hole's middle
## for a pin or an axle in hand, and where the hole in hand goes, on the pin
## or along the axle, for a hole.
func _aim_for(site: JointSnap.End, mine: JointSnap.End) -> Vector2:
	if mine.is_male():
		var eye: Vector3 = _camera.global_position
		return _screen(site.aimed(eye, (site.at - eye).normalized()))
	return _screen(mine.at)


## T, R and Shift-R, the fewest that bring the ghost to [param want], as a
## person presses them looking at it, and then the pointer slid along the
## joint by what the ghost is off along it (a wheel along its axle): each
## way tried from the hand as it was (put back between tries, uncounted),
## then the one found pressed and slid, counted. Where the pointer ends,
## or null when none of up to five presses does.
func _turn_onto(want: Transform3D, at: Vector2, loose: bool = false) -> Variant:
	var was: Dictionary = _builder.hand_state()
	for keys: Array in [[]] + TURNS:
		_builder.set_hand_state(was)
		await _again(at)
		for code: String in keys:
			await _key(KEY_T if code.to_lower() == "t" else KEY_R, false, code == code.to_upper())
		await _again(at)
		var to: Vector2 = await _slid(want, at)
		if not _exact_ghost(want) and not (loose and _turned_near(want)):
			continue
		_builder.set_hand_state(was)
		await _again(at)
		for code: String in keys:
			_acts["key"] = int(_acts["key"]) + 1
			await _key(KEY_T if code.to_lower() == "t" else KEY_R, false, code == code.to_upper())
		await _again(at)
		if to != at:
			await _act_move(to)
			await _again(to)
		return to
	_builder.set_hand_state(was)
	await _again(at)
	return null


## The ghost turned as the file has it, with room, and near its place: the
## rest typed ([method _typed_rest]).
func _turned_near(want: Transform3D) -> bool:
	if not _builder.has_preview() or not _builder.can_place():
		return false
	var ghost: Transform3D = _builder.ghost_transform()
	return ghost.origin.distance_to(want.origin) <= NEAR \
		and _same(_builder.held_part, Transform3D(ghost.basis, want.origin), want)


## What the pointer cannot say, typed while the part is in hand (TypedEntry,
## docs/APP_UX.md B1) and put down with Enter: "-1lz", 1 LDU back along z.
## Each character an action, and Enter one. Whether it went down exactly.
func _typed_rest(want: Transform3D) -> bool:
	var ghost: Transform3D = _builder.ghost_transform()
	var off: Vector3 = want.origin - ghost.origin
	var words: String = ""
	for i: int in 3:
		var v: float = snappedf(off[i], 0.01)
		if absf(v) < 0.01:
			continue
		var unit: String = "l"
		var n: float = v
		if is_zero_approx(fposmod(v, 20.0)) and i != 1:
			unit = ""
			n = v / 20.0
		elif is_zero_approx(fposmod(v, 8.0)):
			unit = "p"
			n = v / 8.0
		var figure: String = str(roundi(n)) if is_equal_approx(n, roundf(n)) else String.num(n, 2)
		words += "%s%s%s" % [figure, unit, "xyz"[i]]
	if words.is_empty():
		return false
	var before: int = _newest_id()
	await _type(words)
	print("      typed \"%s\": %s" % [words, _ghost_words(want)])
	await _act_key(KEY_ENTER)
	var put: BrickWorld.Brick = _newest()
	return put != null and put.id != before and _same(put.part_id, put.transform, want)


## On a joint and turned as the file has it but along the joint from its
## place: the pointer moved along it by what the ghost is off, up to three
## times. Where the pointer is after.
func _slid(want: Transform3D, at: Vector2) -> Vector2:
	var to: Vector2 = at
	for _n: int in 3:
		if _exact_ghost(want) or not _builder.is_on_joint():
			break
		var ghost: Transform3D = _builder.ghost_transform()
		if not _same(_builder.held_part, Transform3D(ghost.basis, want.origin), want):
			break
		var step: Vector2 = _screen(want.origin) - _screen(ghost.origin)
		if step.length() < 0.05:
			break
		to += step
		await _again(to)
	return to


## The presses tried, fewest first: t is T, T is Shift-T, r is R, R is
## Shift-R. T steps through the ways onto a joint (in from the other face,
## the next hole of a beam), R turns about it.
static var TURNS: Array = _turns()


static func _turns() -> Array:
	var out: Array = []
	for tips: Array in [[], ["t"], ["T"], ["t", "t"], ["T", "T"], ["t", "t", "t"], ["T", "T", "T"],
			["t", "t", "t", "t"], ["t", "t", "t", "t", "t"]]:
		for turns: Array in [[], ["r"], ["R"], ["r", "r"], ["r", "r", "r"]]:
			if not tips.is_empty() or not turns.is_empty():
				out.append(tips + turns)
	out.sort_custom(func(a: Array, b: Array) -> bool: return a.size() < b.size())
	return out


## The pointer nudged and back, so the ghost is worked out again where it is.
func _again(at: Vector2) -> void:
	await _move(at + Vector2(0, 1))
	await _move(at)


## Where Connect draws point [param n] on the screen while it offers them.
func _point_on_screen(n: int) -> Vector2:
	for point: Dictionary in _verbs.connect_tool.screen_points():
		if int(point["index"]) == n:
			return Vector2(point["x"], point["y"])
	return Vector2(-100, -100)


func _end_at(part: String, n: int, at: Transform3D) -> JointSnap.End:
	return (JointSnap.ends_for(_library, part)[n] as JointSnap.End).placed(at, 0)


## Whether [param at] is on the model's part of the window, where a click
## lands on the model and not on a panel.
func _in_view(at: Vector2) -> bool:
	var view: Rect2 = _camera.seen_rect()
	return view.grow(-8.0).has_point(at) and not bool(_main.call("_over_panel_at", at))


func _exact_ghost(want: Transform3D) -> bool:
	return _builder.has_preview() and _builder.can_place() \
		and _same(_builder.held_part, _builder.ghost_transform(), want)


static func _off_line(point: Vector3, site: JointSnap.End) -> float:
	var v: Vector3 = point - site.at
	return (v - site.axis * v.dot(site.axis)).length()


# -- helpers ----------------------------------------------------------------------


## Nothing in hand, nothing selected, the Select tool, the model a new one
## on its baseplate, and the default view.
func _rest() -> void:
	if _verbs.mode == "connect":
		await _key(KEY_ESCAPE)
	_verbs.set_mode("select")
	_builder.clear_selection()
	_builder.held_face = "up"
	_builder.held_rotation = 0
	_main.call("clear_model")
	_shift = Vector3.ZERO
	_camera.set_view("default")
	await _frames(40)


func _truth_of(file: String) -> Array:
	_main.call("clear_model")
	await _frames(4)
	_store.open_text(FileAccess.get_file_as_string(SETS + file), file.get_basename())
	await _frames(10)
	var out: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append([brick.part_id, brick.color_code, brick.transform])
	return out


func _cell(key: String) -> Button:
	for cell: Node in (_bin.get("_grid") as GridContainer).get_children():
		if str(cell.get_meta("key", "")) == key:
			return cell
	return null


func _newest() -> BrickWorld.Brick:
	var best: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and (best == null or brick.id > best.id):
			best = brick
	return best


func _newest_id() -> int:
	var newest: BrickWorld.Brick = _newest()
	return newest.id if newest != null else 0


## Whether [param part] at [param a] is where it is at [param b]: the same
## place and turn, or a turn the part looks the same in, its own shape
## over itself (an axle end for end, a round plate turned about its
## middle), each of its corners within 0.1 LDU of one of its own.
func _same(part: String, a: Transform3D, b: Transform3D) -> bool:
	if _near(a, b):
		return true
	if a.origin.distance_to(b.origin) > 400.0:
		return false
	var shape: Dictionary = _shape_of(part)
	if shape.is_empty():
		return false
	var back: Transform3D = b.affine_inverse() * a
	for point: Vector3 in shape["samples"]:
		var there: Vector3 = back * point
		var cell := Vector3i((there / 0.5).round())
		var found: bool = false
		for dx: int in [-1, 0, 1]:
			for dy: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					for other: Vector3 in (shape["cells"] as Dictionary).get(cell + Vector3i(dx, dy, dz), []):
						if other.distance_to(there) < 0.1:
							found = true
		if not found:
			return false
	return true


## The corners of [param part]'s own mesh, kept by the half LDU, and two
## hundred of them to test with.
func _shape_of(part: String) -> Dictionary:
	if _shapes.has(part):
		return _shapes[part]
	var mesh: Lbm.PartMesh = _library.mesh_for(part)
	var cells: Dictionary = {}
	var all := PackedVector3Array()
	if mesh != null:
		for surface: ArrayMesh in mesh.surfaces:
			for n: int in surface.get_surface_count():
				var points: PackedVector3Array = surface.surface_get_arrays(n)[Mesh.ARRAY_VERTEX]
				all.append_array(points)
	for point: Vector3 in all:
		var cell := Vector3i((point / 0.5).round())
		if not cells.has(cell):
			cells[cell] = []
		(cells[cell] as Array).append(point)
	var samples := PackedVector3Array()
	var every: int = maxi(1, all.size() / 200)
	for n: int in range(0, all.size(), every):
		samples.append(all[n])
	_shapes[part] = {} if all.is_empty() else {"cells": cells, "samples": samples}
	return _shapes[part]


static func _near(a: Transform3D, b: Transform3D) -> bool:
	if a.origin.distance_to(b.origin) > EXACT_PLACE:
		return false
	for n: int in 3:
		if (a.basis[n] - b.basis[n]).length() > EXACT_TURN:
			return false
	return true


func _ldr_of(at: Transform3D) -> String:
	var numbers: PackedFloat64Array = LdrModel.from_transform(at)
	var words: PackedStringArray = []
	for n: int in numbers.size():
		words.append(String.num(numbers[n], 3 if n < 3 else 4))
	return " ".join(words)


func _count_from() -> void:
	_acts = {"point": 0, "click": 0, "key": 0, "typed": 0, "wheel": 0, "drag": 0}


func _total() -> int:
	var sum: int = 0
	for kind: String in _acts:
		sum += int(_acts[kind])
	return sum


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _until(done: Callable, most: int = 600) -> bool:
	for _n: int in most:
		if done.call():
			return true
		await process_frame
	return bool(done.call())


func _as_event(at: Vector2) -> Vector2:
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / root.get_visible_rect().size) if window.x > 0.0 else at


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _as_event(_pointer)
	_pointer = at
	Input.parse_input_event(event)
	await _frames(3)


func _act_move(at: Vector2) -> void:
	_acts["point"] = int(_acts["point"]) + 1
	await _move(at)


func _button(at: Vector2, which: MouseButton, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = which
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, MOUSE_BUTTON_LEFT, true)
	await _frames(2)
	_button(at, MOUSE_BUTTON_LEFT, false)
	await _frames(4)


## A click: one action, and the pointer moved there first another, as
## docs/CADTASK.md's walks and its keystroke-level model count them (P BB).
func _act_click(at: Vector2) -> void:
	if _pointer.distance_to(at) > 1.0:
		_acts["point"] = int(_acts["point"]) + 1
	_acts["click"] = int(_acts["click"]) + 1
	await _click(at)


func _act_wheel(at: Vector2, which: MouseButton) -> void:
	_acts["wheel"] = int(_acts["wheel"]) + 1
	if _pointer.distance_to(at) > 1.0:
		_acts["point"] = int(_acts["point"]) + 1
		await _move(at)
	_button(at, which, true)
	_button(at, which, false)
	await _frames(6)


func _key(code: Key, command: bool = false, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		event.shift_pressed = shift
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _act_key_ctrl(code: Key) -> void:
	_acts["key"] = int(_acts["key"]) + 1
	await _key(code, true)


func _act_key(code: Key, shift: bool = false) -> void:
	_acts["key"] = int(_acts["key"]) + 1
	await _key(code, false, shift)


## The key the keymap gives [param action], pressed: one action.
func _act_key_of(action: String) -> void:
	_acts["key"] = int(_acts["key"]) + 1
	var down: InputEventKey = Keymap.press_of(Keymap.key_of(action))
	Input.parse_input_event(down)
	await process_frame
	var up: InputEventKey = down.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	await _frames(4)


## Characters typed into what has the focus, one action each.
func _type(text: String) -> void:
	for n: int in text.length():
		var code: int = text.unicode_at(n)
		var event := InputEventKey.new()
		event.unicode = code
		event.keycode = OS.find_keycode_from_string(text[n].to_upper())
		event.physical_keycode = event.keycode
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		var up: InputEventKey = event.duplicate()
		up.pressed = false
		Input.parse_input_event(up)
		_acts["typed"] = int(_acts["typed"]) + 1
		await _frames(2)


## Where a run's file goes: shots/setwalk/WxH/, or WxH-library/ for the
## walk from the whole library, so runs at once do not write over another's.
func _out(name: String) -> String:
	var size: Vector2i = DisplayServer.window_get_size()
	return ProjectSettings.globalize_path("res://shots/setwalk/%dx%d%s/%s" % [size.x, size.y,
		"-library" if _from_library else "", name])


func _shot(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out("%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s" % path)
