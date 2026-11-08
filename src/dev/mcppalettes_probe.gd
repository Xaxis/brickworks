## Does the person's Claude keep and use palettes (APP_UX7 #8, mcppalettes)?
## Each tool called as the connector and the desktop's MCP port call it
## (CommandSocket.answer_rpc, tools/call), the bin looked at as a person
## looks at it.
##
##   ~/.claude/claude-core/bin/gpu godot --path . --resolution 1280x720 \
##       --script src/dev/mcppalettes_probe.gd
##
## PROBE_SIZE=1400x900 tools/probe.sh mcppalettes runs it at 1400 x 900.
## Pictures go to shots/mcppalettes/. Look at them.
##
##   1. tools/list: palettes says it only looks (readOnlyHint), edit_palette
##      that it changes;
##   2. Castle made in 1 call: edit_palette make, twelve parts of the model
##      each in its colour and the four of a gatepost as the sub-assembly
##      Gatepost. The bin's Palettes chip counts it at once (it said
##      "Palettes 0" beside it), and two presses show it: twelve tiles in
##      their colours and Gatepost. The same twelve and gatepost kept through
##      the bin's own New palette and Add rows: the two palettes' entries the
##      same, byte for byte in the file, but for each entry's id and the time
##      its name was given (a palette's and an entry's own, by design);
##   3. read-only: palettes lists Castle in 1 call, the model and the file the
##      same to the byte after it; in a tab showing a model shared to look at,
##      palettes answers and edit_palette is refused;
##   4. another model: Gatepost placed whole in 1 call at x 2, y 0, z 2, each
##      part where it stood beside the others to 0.01 LDU, its low corner
##      there, as one assembly called Gatepost; the same again where it stands
##      refused with nothing changed; one undo takes it all back;
##   5. a part taken out, and the bin follows; the sub-assembly taken out and
##      the palette deleted only with agreed=true; a name taken, and parts the
##      model has not, refused with the file as it was.
## Written to run on a build without the tools (pre261): there it fails, it
## does not stop.
extends SceneTree

## The twelve, each part in its colour (palettes_probe's).
const PARTS: Array = [["3001", 4], ["3003", 1], ["3004", 14], ["3010", 15], ["3020", 2],
	["3022", 71], ["3023b", 72], ["3024", 0], ["3039", 4], ["3068b", 15], ["3069b", 1], ["4070", 14]]
## The gatepost: two 2 x 2 bricks, a plate and a tile, stacked.
const POST: Array = [["3003", 71, Vector3(400, 24, 400)], ["3003", 71, Vector3(400, 48, 400)],
	["3022", 72, Vector3(400, 56, 400)], ["3068b", 15, Vector3(400, 64, 400)]]
const ADD_PARTS := 1
const ADD_ASSEMBLY := 2
const SHELF_FILE := "user://mcppalettes_probe_shelf.cfg"
const PALETTES_FILE := "user://mcppalettes_probe.cfg"
const LDU := 0.01

var _failures: int = 0
var _main: Node
var _socket: CommandSocket
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _library: PartLibrary
var _camera: CadCamera
var _store: ModelStore
var _next: int = 0
var _calls: int = 0
var _tag: String = ""
var _autosave: PackedByteArray = PackedByteArray()
var _had_autosave: bool = false


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	await process_frame
	PartShelf.file = SHELF_FILE
	PartShelf.keeps = true
	PartShelf.palettes_file = PALETTES_FILE
	PartShelf.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PALETTES_FILE))
	PartShelf.forget_palettes()
	_had_autosave = FileAccess.file_exists(ModelStore.autosave())
	if _had_autosave:
		_autosave = FileAccess.get_file_as_bytes(ModelStore.autosave())
	await _open_app()
	if not ModelShot.possible():
		print("mcppalettes probe: SKIPPED: no window to draw in")
		_finish(3)
		return
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d" % [size.x, size.y]
	print("mcppalettes: the window %s" % _tag)

	await _listed()
	var post_shape: Array = await _made_in_one_call()
	await _read_only()
	await _placed(post_shape)
	await _changed_and_refused()
	_finish(1 if _failures > 0 else 0)


func _finish(code: int) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PALETTES_FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PALETTES_FILE + ".unreadable"))
	PartShelf.clear()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SHELF_FILE))
	_put_back_autosave()
	print("")
	if code == 0:
		print("mcppalettes: every check passed (%s)" % _tag)
	elif code != 3:
		print("mcppalettes: %d FAILED (%s)" % [_failures, _tag])
	quit(code)


func _open_app() -> void:
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _until(func() -> bool:
		var bin: PartsBin = _main.get("_bin")
		return bin != null and int(bin.get("_offerable")) > 0, 1200)
	await _frames(60)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_world = _main.get("_world")
	_library = _main.get("_library")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_store.keeps = false
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	(_main.get("_bin_dock") as SideDock).set_open(true)
	await create_timer(SideDock.SLIDE_SECONDS * 2.0).timeout
	await _frames(30)


# -- 1. what a session is told ---------------------------------------------------------


func _listed() -> void:
	print("")
	print("── 1. what tools/list says ──")
	var listed: Dictionary = await _rpc("tools/list", {})
	var tools: Dictionary = {}
	for tool: Dictionary in listed.get("tools", []):
		tools[str(tool["name"])] = tool
	var reads: Dictionary = (tools.get("palettes", {}) as Dictionary).get("annotations", {})
	var edits: Dictionary = (tools.get("edit_palette", {}) as Dictionary).get("annotations", {})
	_check("palettes is listed and says it only looks (%s)" % str(reads),
		reads.get("readOnlyHint", false) == true)
	_check("edit_palette is listed and says it changes things (%s)" % str(edits),
		not edits.is_empty() and edits.get("readOnlyHint", true) == false)
	var takes: Dictionary = ((tools.get("edit_palette", {}) as Dictionary).get("inputSchema",
		{}) as Dictionary).get("properties", {})
	_check("...taking action=, palette=, bricks=, assembly=, assembly_bricks= and at=",
		takes.has("action") and takes.has("palette") and takes.has("bricks")
		and takes.has("assembly") and takes.has("assembly_bricks") and takes.has("at"))


# -- 2. made in one call, as the bin makes one -------------------------------------------


## Castle: twelve parts in their colours and a gatepost, from the model in 1
## call. Returns the gatepost's shape as it stood.
func _made_in_one_call() -> Array:
	print("")
	print("── 2. a palette of twelve parts and a sub-assembly, made in 1 call ──")
	_main.clear_model()
	await _frames(10)
	var twelve: Array = []
	for n: int in PARTS.size():
		twelve.append(_put(str(PARTS[n][0]), int(PARTS[n][1]),
			Vector3(-200 + (n % 4) * 100, 24, -200 + (n / 4) * 100)))
	var post: Array = []
	for one: Array in POST:
		post.append(_put(str(one[0]), int(one[1]), one[2]))
	var shape: Array = _shape_of(post.map(func(id: int) -> BrickWorld.Brick: return _world.get_brick(id)))
	_camera.frame(AABB(Vector3(-260, 0, -260), Vector3(720, 120, 720)))
	await _frames(20)

	var calls: int = _calls
	var said: String = await _call("edit_palette", {"action": "make", "palette": "Castle",
		"bricks": twelve, "assembly": "Gatepost", "assembly_bricks": post})
	_print(said)
	var castle: Dictionary = _palette_named("Castle")
	_check("made in %d call: Castle holds the twelve, each in its colour (%s)" % [_calls - calls,
		_pairs_of(castle)], _calls - calls == 1 and _same_pairs(_pairs_of(castle), PARTS))
	var gatepost: Dictionary = _assembly_of(castle, "Gatepost")
	_check("...and Gatepost, whole: %d parts, %d entries in all" % [int(gatepost.get("count", 0)),
		(castle.get("entries", []) as Array).size()], int(gatepost.get("count", 0)) == 4
		and (castle.get("entries", []) as Array).size() == 13)
	_check("...and says so: \"%s\"" % said.get_slice("\n", 0),
		said.begins_with("Made the palette “Castle”: 12 parts, each in its colour; the sub-assembly “Gatepost”, 4 parts, whole."))

	# The chip counts it before the bin's Palettes is opened.
	var chip: Button = _named("palettes")
	_check("the bin's Palettes chip counts it at once: \"%s\"" % chip.text,
		await _until(func() -> bool: return chip.text == "Palettes 1", 10))
	# The bin, as a person opens it: Palettes, then Castle.
	await _click(chip.get_global_rect().get_center())
	var row: Button = _bin.controls_by_name().get("palette row Castle")
	_check("the bin's Palettes lists Castle", row != null)
	if row != null:
		await _click(row.get_global_rect().get_center())
	var tiles: Array = _part_tiles()
	var cell: Button = _bin.controls_by_name().get("sub-assembly Gatepost")
	_check("...and opened shows its twelve in their colours (%d) and Gatepost" % tiles.size(),
		_same_pairs(tiles, PARTS) and cell != null)
	await _pictures_drawn()
	await _shot("castle_made_by_claude")

	# The same kept through the bin's own rows, for the file to be compared.
	await _click(_named("palette back").get_global_rect().get_center())
	await _click(_named("palette new").get_global_rect().get_center())
	await _type_keys("Castle by hand")
	await _key(KEY_ENTER)
	_select(twelve)
	await _from_add(ADD_PARTS)
	_select(post)
	await _from_add(ADD_ASSEMBLY)
	var asked: LineEdit = _bin.controls_by_name().get("name field")
	if asked != null and asked.is_visible_in_tree():
		await _type_keys("Gatepost")
		await _key(KEY_ENTER)
	_select([])
	var by_claude: Dictionary = _file_palette("Castle")
	var by_hand: Dictionary = _file_palette("Castle by hand")
	var mine: String = _entries_as_kept(by_claude)
	var theirs: String = _entries_as_kept(by_hand)
	_check("in the file, Claude's Castle is the bin's own, byte for byte but each entry's id "
		+ "and when it was named (%d and %d bytes)" % [mine.length(), theirs.length()],
		not by_hand.is_empty() and (by_hand.get("entries", []) as Array).size() == 13
		and mine == theirs)
	if mine != theirs:
		print("    Claude's: " + mine.left(400).replace("\n", " "))
		print("    the bin's: " + theirs.left(400).replace("\n", " "))
	return shape


# -- 3. the list only looks ----------------------------------------------------------------


func _read_only() -> void:
	print("")
	print("── 3. palettes only looks ──")
	var model: String = _standing()
	var file: PackedByteArray = _file_bytes()
	var calls: int = _calls
	var said: String = await _call("palettes", {})
	_print(said)
	_check("listed in %d call: Castle, its parts and Gatepost" % (_calls - calls),
		_calls - calls == 1 and said.contains("“Castle”: 12 parts, 1 sub-assembly")
		and said.contains("sub-assembly “Gatepost”, 4 parts") and said.contains("part 3039"))
	_check("...the model and the palettes file the same to the byte after it",
		_standing() == model and _file_bytes() == file and not file.is_empty())
	var one: String = await _call("palettes", {"palette": "castle by hand"})
	_check("palette= reads one by its name, whatever its case", one.begins_with("“Castle by hand”"))

	var shell: Shell = _main.get("_shell")
	shell.read_only = true
	var looked: String = await _call("palettes", {})
	var refused: String = await _call("edit_palette", {"action": "make", "palette": "Looked at",
		"from": "model"})
	shell.read_only = false
	_check("in a tab showing a model shared to look at, palettes answers",
		looked.contains("“Castle”"))
	_check("...and edit_palette is refused (\"%s\"), nothing changed" % refused.left(60),
		refused.contains("shared to look at") and _file_bytes() == file)


# -- 4. placed whole in another model ---------------------------------------------------------


func _placed(post_shape: Array) -> void:
	print("")
	print("── 4. Gatepost placed whole in another model ──")
	_main.clear_model()
	await _frames(10)
	_camera.frame(AABB(Vector3(-100, 0, -100), Vector3(300, 120, 300)))
	await _frames(10)
	_check("a new model, nothing on it (%d parts)" % _count(), _count() == 0)
	var file: PackedByteArray = _file_bytes()
	var calls: int = _calls
	var answer: Dictionary = await _rpc("tools/call", {"name": "edit_palette", "arguments": {
		"action": "place", "palette": "Castle", "assembly": "Gatepost",
		"at": {"x": 2, "y": 0, "z": 2}}})
	_calls += 1
	var said: String = _text(answer)
	_print(said)
	var down: Array = _world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not _store.scenery.has(b.id))
	_check("placed in %d call: %d parts, each where it stood beside the others to %.2f LDU"
		% [_calls - calls, down.size(), LDU], _calls - calls == 1 and down.size() == 4
		and _same_shape(_shape_of(down), post_shape))
	var low: Vector3 = _low_corner(down)
	_check("...its low corner at x %.2f, y %.2f, z %.2f (asked 2, 0, 2)" % [low.x, low.y, low.z],
		low.distance_to(Vector3(2, 0, 2)) < LDU)
	var groups: Dictionary = {}
	for brick: BrickWorld.Brick in down:
		groups[brick.group] = true
	_check("...as one assembly called Gatepost (%s)" % [groups.keys()], groups.keys() == ["Gatepost"])
	_check("...and the palette as it was", _file_bytes() == file)
	var pictures: Array[Image] = _images(answer)
	_check("...answered with it pictured (%d)" % pictures.size(), pictures.size() == 1)
	for n: int in pictures.size():
		_save(pictures[n], "placed_answer")
	await _shot("gatepost_placed")

	var again: String = await _call("edit_palette", {"action": "place", "palette": "Castle",
		"assembly": "Gatepost", "at": {"x": 2, "y": 0, "z": 2}, "picture": false})
	_print(again)
	_check("the same again where it stands is refused, nothing changed (%d parts)" % _count(),
		again.begins_with("Not put down") and _count() == 4)
	await _call("undo", {})
	await _frames(6)
	_check("one undo takes it all back (%d parts)" % _count(), _count() == 0)


# -- 5. changed, and refused ----------------------------------------------------------------


func _changed_and_refused() -> void:
	print("")
	print("── 5. taken out, renamed, deleted; refusals ──")
	# Castle open in the bin: it follows a session's change.
	await _click(_named("palette back").get_global_rect().get_center())
	var row: Button = _bin.controls_by_name().get("palette row Castle")
	if row != null:
		await _click(row.get_global_rect().get_center())
	var out: String = await _call("edit_palette", {"action": "take_out", "palette": "Castle",
		"parts": [{"part": "3001", "color": 4}]})
	_print(out.get_slice("\n", 0))
	_check("a part taken out: Castle holds 11 and Gatepost (%d entries)"
		% (_palette_named("Castle").get("entries", []) as Array).size(),
		(_palette_named("Castle").get("entries", []) as Array).size() == 12
		and _pairs_of(_palette_named("Castle")).size() == 11)
	await _until_seconds(func() -> bool: return _part_tiles().size() == 11, 3.0)
	_check("...and the bin shows 11 tiles within 3 s (%d)" % _part_tiles().size(),
		_part_tiles().size() == 11)
	await _shot("castle_after_take_out")

	var file: PackedByteArray = _file_bytes()
	var asks: String = await _call("edit_palette", {"action": "take_out", "palette": "Castle",
		"assembly": "Gatepost"})
	_check("the sub-assembly taken out without agreed=true is refused, asking the person first",
		asks.contains("asks the person first") and _file_bytes() == file)
	var taken: String = await _call("edit_palette", {"action": "rename", "palette": "Castle",
		"to": "Keep"})
	_check("renamed: \"%s\"" % taken, _palette_named("Keep").size() > 0 and _palette_named("Castle").is_empty())
	file = _file_bytes()
	var twice: String = await _call("edit_palette", {"action": "make", "palette": "keep",
		"from": "model"})
	_check("a name taken is refused, the file as it was (\"%s\")" % twice.left(60),
		twice.contains("already") and _file_bytes() == file)
	var unknown: String = await _call("edit_palette", {"action": "add", "palette": "Keep",
		"bricks": [99999]})
	_check("a part the model has not is refused, the file as it was (\"%s\")" % unknown.left(60),
		unknown.contains("No part of the model numbered 99999") and _file_bytes() == file)
	var kept: String = await _call("edit_palette", {"action": "delete", "palette": "Keep"})
	_check("deleting without agreed=true is refused", kept.contains("asks the person first")
		and not _palette_named("Keep").is_empty())
	var gone: String = await _call("edit_palette", {"action": "delete", "palette": "Keep",
		"agreed": true})
	_check("...and with it, deleted: \"%s\"" % gone.left(70), _palette_named("Keep").is_empty()
		and not _palette_named("Castle by hand").is_empty())


# -- what the palettes hold ---------------------------------------------------------------


func _palette_named(name: String) -> Dictionary:
	for one: Dictionary in PartShelf.palettes():
		if str(one["name"]) == name:
			return one
	return {}


func _pairs_of(one: Dictionary) -> Array:
	var out: Array = []
	for entry: Dictionary in one.get("entries", []):
		if entry.has("part"):
			out.append([str(entry["part"]), int(entry["colour"])])
	return out


func _assembly_of(one: Dictionary, name: String) -> Dictionary:
	for entry: Dictionary in one.get("entries", []):
		if entry.has("ldraw") and str(entry["name"]) == name:
			return entry
	return {}


func _same_pairs(got: Array, wanted: Array) -> bool:
	if got.size() != wanted.size():
		return false
	for pair: Array in wanted:
		if not got.has([str(pair[0]), int(pair[1])]):
			return false
	return true


func _file_palette(name: String) -> Dictionary:
	var file := ConfigFile.new()
	if file.load(PALETTES_FILE) != OK:
		return {}
	for one: Dictionary in file.get_value("palettes", "list", []):
		if str(one["name"]) == name:
			return one
	return {}


func _file_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(PALETTES_FILE) if FileAccess.file_exists(PALETTES_FILE) \
		else PackedByteArray()


## A palette's entries as the file keeps them, each but its id and when its
## name was given: what makes two palettes the same.
static func _entries_as_kept(one: Dictionary) -> String:
	var out: Array = []
	for entry: Dictionary in one.get("entries", []):
		var kept: Dictionary = entry.duplicate()
		kept.erase("id")
		kept.erase("named")
		out.append(kept)
	return var_to_str(out)


func _part_tiles() -> Array:
	var out: Array = []
	for child: Node in (_bin.get("_grid") as GridContainer).get_children():
		var key: String = str(child.get_meta("key", ""))
		if child.has_meta("part") and child.has_meta("entry") and key.contains("/"):
			out.append([key.get_slice("/", 0), int(key.get_slice("/", 1))])
	return out


func _named(name: String) -> Control:
	return _bin.controls_by_name().get(name)


func _pictures_drawn() -> void:
	await _until(func() -> bool:
		for child: Node in (_bin.get("_grid") as GridContainer).get_children():
			if not child.has_meta("tile"):
				continue
			var tile: ThumbTile = child.get_meta("tile")
			if tile.state != ThumbTile.State.READY or tile.texture == null:
				return false
		return true, 600)


## Add pressed, and its row chosen, as a person chooses it.
func _from_add(row: int) -> void:
	var add: MenuButton = _named("palette add")
	await _click(add.get_global_rect().get_center())
	var popup: PopupMenu = add.get_popup()
	popup.id_pressed.emit(row)
	popup.hide()
	await _frames(10)


# -- the model ---------------------------------------------------------------------------


func _put(part: String, colour: int, at: Vector3) -> int:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)
	return brick_id


func _select(ids: Array) -> void:
	_builder.selection.clear()
	for brick_id: Variant in ids:
		_builder.selection[int(brick_id)] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _count() -> int:
	return _world.brick_count() - _store.scenery.size()


## Each part, colour, turn and place from the lowest, sorted from the bottom.
func _shape_of(bricks: Array) -> Array:
	var sorted: Array = bricks.duplicate()
	sorted.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.y < b.transform.origin.y)
	var out: Array = []
	if sorted.is_empty():
		return out
	var first: Vector3 = (sorted[0] as BrickWorld.Brick).transform.origin
	for brick: BrickWorld.Brick in sorted:
		out.append([brick.part_id, brick.color_code, brick.transform.basis,
			brick.transform.origin - first])
	return out


func _same_shape(a: Array, b: Array) -> bool:
	if a.size() != b.size() or a.is_empty():
		return false
	for n: int in a.size():
		if a[n][0] != b[n][0] or a[n][1] != b[n][1] or not (a[n][2] as Basis).is_equal_approx(b[n][2]):
			return false
		if ((a[n][3] as Vector3) - (b[n][3] as Vector3)).length() > LDU:
			return false
	return true


## The low corner of [param bricks] in studs, plates and studs.
func _low_corner(bricks: Array) -> Vector3:
	var low := Vector3.INF
	for brick: BrickWorld.Brick in bricks:
		var info: PartLibrary.PartInfo = _library.parts.get(brick.part_id)
		low = low.min((brick.transform * info.bounds).abs().position)
	return Vector3(low.x / 20.0, low.y / 8.0, low.z / 20.0)


func _standing() -> String:
	var rows := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		rows.append("%d %s %d %s" % [brick.id, brick.part_id, brick.color_code, brick.transform])
	rows.sort()
	return "\n".join(rows)


# -- calls, as a session makes them --------------------------------------------------------


func _call(tool: String, arguments: Dictionary) -> String:
	_calls += 1
	return _text(await _rpc("tools/call", {"name": tool, "arguments": arguments}))


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary if answer is Dictionary else {}


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


static func _images(result: Dictionary) -> Array[Image]:
	var out: Array[Image] = []
	for block: Dictionary in result.get("content", []):
		if str(block.get("type", "")) == "image":
			var picture := Image.new()
			if picture.load_png_from_buffer(Marshalls.base64_to_raw(str(block.get("data", "")))) == OK:
				out.append(picture)
	return out


func _print(said: String) -> void:
	print("    " + said.left(900).replace("\n", "\n    "))


# -- the window, as a person uses it --------------------------------------------------------


func _type_keys(text: String) -> void:
	for letter: String in text:
		var code: int = letter.to_upper().unicode_at(0)
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = code as Key
			event.physical_keycode = code as Key
			event.unicode = letter.unicode_at(0)
			event.shift_pressed = letter != letter.to_lower()
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _click(at: Vector2) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at).floor()
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(6)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _until(done: Callable, most: int = 600) -> bool:
	for _n: int in most:
		if done.call():
			return true
		await process_frame
	return bool(done.call())


func _until_seconds(done: Callable, seconds: float) -> bool:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		if done.call():
			return true
		await process_frame
	return bool(done.call())


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	_save(root.get_texture().get_image(), name)


func _save(picture: Image, name: String) -> void:
	var path: String = ProjectSettings.globalize_path("res://shots/mcppalettes/%s_%s.png" % [name, _tag])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	picture.save_png(path)
	print("    picture: %s" % path)


func _put_back_autosave() -> void:
	if _had_autosave:
		var file: FileAccess = FileAccess.open(ModelStore.autosave(), FileAccess.WRITE)
		if file != null:
			file.store_buffer(_autosave)
			file.close()
	elif FileAccess.file_exists(ModelStore.autosave()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.autosave()))
