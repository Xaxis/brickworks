## Can a building that stands be given floors and furnished rooms in one
## call?
##
##   godot --headless --path . --script src/dev/rooms_probe.gd
##   xvfb-run -a godot --path . --resolution 1200x800 --script src/dev/rooms_probe.gd
##                     ... and with a window, pictures in shots/rooms/
##
## Twelve Orthancs were solid shells or bare open backs, and their variety
## never reached a real set's: 46 shapes and six colours where a fantasy set
## has 109 and 23, which real sets get from their interiors. add_rooms is the
## one call for it (src/ai/rooms.gd). What has to be true of it is what a
## design needs to trust it with a tower it spent an hour on: the result
## passes the check, every floor is held, each room has the furniture of its
## kind, nothing collides, the shell is exactly as it was — and the model is
## made of more different things than it was.
##
## The tower is an octagonal prism open at the back, with a dungeon, a forge
## (with a stair up), a library and a study; then a box shell with two
## libraries, to see the seed make them two different rooms; then every piece
## of furniture on its own, as techniques_probe checks the worked examples.
extends SceneTree

const OUT := "res://shots/rooms"

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant


func _initialize() -> void:
	_run()


func _run() -> void:
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	_world = BrickWorld.new()
	_world.library = _library
	root.add_child(_world)
	_builder = Builder.new()
	_builder.world = _world
	_builder.library = _library
	root.add_child(_builder)
	_assistant = Assistant.new()
	_assistant.library = _library
	_assistant.world = _world
	_assistant.builder = _builder
	root.add_child(_assistant)
	await process_frame

	print("  each piece of furniture, on its own")
	_each_piece()

	print("")
	print("  an octagonal tower open at the back, four rooms")
	var prism := {"pattern": "prism", "at": {"x": 16, "y": 0, "z": 16}, "sides": 8,
		"radius": 9, "courses": 32, "color": 0, "mix_color": 72, "open": 3}
	var tower: Assistant.Model = _assistant._read_model({"name": "Tower",
		"patterns": [prism]})
	var built: Dictionary = _assistant._check(tower)
	_check("the shell holds on its own, %s" % built["summary"], bool(built["ok"]))
	# What the check says of the bare shell names the call, the way the style
	# advice names restyle_model: a design takes up a call it is told of.
	_assistant._brief = "The Tower of Orthanc"
	var thin: String = _assistant._variety(tower)
	_check("the bare tower is thin, and the advice names add_rooms",
		thin.contains("add_rooms"))
	_assistant._apply(tower)
	var shell: Dictionary = _snapshot()
	var before: Dictionary = _measure()
	var started: int = Time.get_ticks_msec()
	var said: Variant = await _assistant.use_tool("add_rooms", {
		"prism": {"at": {"x": 16, "y": 0, "z": 16}, "sides": 8, "radius": 9},
		"floors": [{"room": "dungeon"}, {"room": "forge", "stair": true},
			{"room": "library"}, {"room": "Saruman's chamber"}],
		"seed": 3})
	var text: String = _text_of(said)
	print("        (%d ms)" % (Time.get_ticks_msec() - started))
	for line: String in text.split("\n"):
		if line.begins_with("Measured"):
			break
		if not line.strip_edges().is_empty():
			print("        | %s" % line)
	_check("add_rooms laid it: %s" % text.get_slice("\n", 0),
		text.begins_with("Laid 4 floors") and text.contains("Done."))
	var after: Dictionary = _measure()
	var verdict: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	_check("the whole of it passes the check: %s" % verdict["summary"],
		bool(verdict["ok"]))
	_check("...nothing floating and nothing overlapping",
		not (verdict.get("kinds", []) as Array).has("floating")
			and not (verdict.get("kinds", []) as Array).has("overlap"))
	_check("the shell is exactly as it was: %s" % _shell_changes(shell),
		_shell_changes(shell) == "untouched")
	_check_rooms(text)
	print("        before: %s" % _said(before))
	print("        after:  %s" % _said(after))
	_check("more different shapes than the shell alone: %d, from %d"
		% [after["shapes"], before["shapes"]], int(after["shapes"]) > int(before["shapes"]) + 25)
	_check("and more colours: %d, from %d" % [after["colours"], before["colours"]],
		int(after["colours"]) > int(before["colours"]) + 8)
	if ModelShot.possible():
		await _pictures("tower")
		# And each floor close up from the open side, which is how a person
		# judges whether a room reads as the room it is.
		for one: Dictionary in _last_floors():
			var y: float = float(one["y"])
			await _pictures("tower_%s" % str(one["room"]).replace(" ", "_"),
				AABB(Vector3(7, y, 7) * Vector3(20, 8, 20), Vector3(18, 24, 18) * Vector3(20, 8, 20)),
				["back"])
	_write_ldr("%s/tower.ldr" % OUT)

	print("")
	print("  a box shell open at the back, two libraries")
	var house: Dictionary = _house(16)
	var two: Variant = await _assistant.use_tool("add_rooms", {
		"where": {"x_from": 40, "x_to": 56, "z_from": 0, "z_to": 14},
		"floors": ["library", "library"], "seed": 11})
	var told: String = _text_of(two)
	for line: String in told.split("\n"):
		if line.begins_with("  "):
			print("        | %s" % line)
	_check("add_rooms took a box and two rooms by name: %s" % told.get_slice("\n", 0),
		told.begins_with("Laid 2 floors") and told.contains("Done."))
	_check("...the house is as it was: %s" % _shell_changes(house),
		_shell_changes(house) == "untouched")
	var libraries: Array = _floor_signatures()
	_check("two libraries, two different rooms: %s" % " / ".join(PackedStringArray(libraries)),
		libraries.size() == 2 and libraries[0] != libraries[1])
	var ok: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	_check("...and it passes the check: %s" % ok["summary"], bool(ok["ok"]))
	if ModelShot.possible():
		await _pictures("house")

	print("")
	print("  every other kind of room, one above another")
	var kinds: Array = ["throne room", "kitchen", "bedchamber", "hall", "armoury",
		"lookout", "palantir room", "stair"]
	var tall: Dictionary = _house(kinds.size() * 8)
	var all: String = _text_of(await _assistant.use_tool("add_rooms", {
		"where": {"x_from": 40, "x_to": 56, "z_from": 0, "z_to": 14},
		"floors": kinds, "seed": 5}))
	for line: String in all.split("\n"):
		if line.begins_with("  "):
			print("        | %s" % line)
	_check("add_rooms laid %d floors: %s" % [kinds.size(), all.get_slice("\n", 0)],
		all.begins_with("Laid %d floors" % kinds.size()) and all.contains("Done."))
	var each: Array = _last_floors()
	for one: Dictionary in each:
		var signature: String = Rooms.KINDS[one["room"]]["items"][0]
		_check("the %s has its %s, and %d pieces" % [one["room"], signature,
			(one["furniture"] as Array).size()],
			(one["furniture"] as Array).has(signature))
	var whole: Dictionary = _assistant._check(_assistant._model_from_world(), true)
	_check("...it passes the check: %s" % whole["summary"], bool(whole["ok"]))
	_check("...and the house is as it was: %s" % _shell_changes(tall),
		_shell_changes(tall) == "untouched")
	if ModelShot.possible():
		await _pictures("kinds", AABB(), ["back"])

	print("")
	print("  what it says when it cannot")
	_assistant.clear_built()
	var none: String = _text_of(await _assistant.use_tool("add_rooms",
		{"floors": ["library"]}))
	_check("no box and no prism is refused with what to give: %s" % none.get_slice(".", 0),
		none.contains("where="))
	var bare: String = _text_of(await _assistant.use_tool("add_rooms",
		{"where": {"x_from": 0, "x_to": 10, "z_from": 0, "z_to": 10},
			"floors": ["library"]}))
	_check("nothing standing there is said, not built: %s" % bare.get_slice(".", 0),
		not bare.contains("Done."))
	_check("add_rooms is in the design's tools, and so on MCP",
		_assistant.tool_catalogue().any(func(tool: Dictionary) -> bool:
			return str(tool["name"]) == "add_rooms"))

	print("")
	if _failures == 0:
		print("rooms: all pass")
	else:
		print("rooms: %d FAIL" % _failures)
	quit(1 if _failures > 0 else 0)


## Each piece of furniture holds together on its own, in each of the four
## turns it may be stood at: a piece that only holds one way round would
## pass here and fail in a room.
func _each_piece() -> void:
	var rooms := Rooms.new(_assistant)
	for name: String in Rooms.FURNITURE:
		var bad: PackedStringArray = []
		var rng := RandomNumberGenerator.new()
		for turns: int in 4:
			var shape: Dictionary = rooms._shape(name, rooms._recoloured(name, rng), turns)
			var model := Assistant.Model.new()
			for raw: Dictionary in shape["bricks"]:
				model.placements.append(Assistant.Placement.from_dict(raw))
			if model.placements.is_empty():
				bad.append("no bricks")
				break
			var verdict: Dictionary = _assistant._check(model)
			if not bool(verdict["ok"]):
				bad.append("turned %d: %s" % [turns, verdict["summary"]])
		_check("%s holds, every way round%s" % [name,
			"" if bad.is_empty() else " — " + "; ".join(bad)], bad.is_empty())
	# And a ladder, as tall as two storeys can want, every way round.
	for tall: int in [23, 17, 30]:
		var bad: PackedStringArray = []
		for turns: int in 4:
			var shape: Dictionary = rooms._shape("ladder %d" % tall,
				Rooms._ladder(tall, 0), turns)
			var model := Assistant.Model.new()
			for raw: Dictionary in shape["bricks"]:
				model.placements.append(Assistant.Placement.from_dict(raw))
			var verdict: Dictionary = _assistant._check(model)
			if not bool(verdict["ok"]):
				bad.append("turned %d: %s" % [turns, verdict["summary"]])
		_check("a ladder %d plates up holds, every way round%s" % [tall,
			"" if bad.is_empty() else " — " + "; ".join(bad)], bad.is_empty())
	for kind: String in Rooms.KINDS:
		for name: String in Rooms.KINDS[kind]["items"]:
			if not Rooms.FURNITURE.has(name):
				_check("%s's %s is a piece there is" % [kind, name], false)
	for said: Array in [["Saruman's chamber", "study"], ["the great hall", "hall"],
			["palantír room", "palantir room"], ["smithy", "forge"],
			["wine cellar", "dungeon"]]:
		_check("\"%s\" is a %s" % said, Rooms.kind_of(said[0]) == said[1])


func _check_rooms(text: String) -> void:
	var floors: Array = _last_floors()
	_check("four floors, each its own kind: %s" % ", ".join(PackedStringArray(
		floors.map(func(one: Dictionary) -> String: return str(one["room"])))),
		floors.size() == 4 and floors.map(func(one: Dictionary) -> String:
			return str(one["room"])) == ["dungeon", "forge", "library", "study"])
	for one: Dictionary in floors:
		var kind: Dictionary = Rooms.KINDS[one["room"]]
		var furniture: Array = one["furniture"]
		var signature: String = kind["items"][0]
		_check("the %s at y=%d has %d pieces of its kind, its %s among them"
			% [one["room"], int(one["y"]), furniture.size(), signature],
			furniture.size() >= 3 and furniture.has(signature)
				and furniture.all(func(name: String) -> bool:
					return (kind["items"] as Array).has(name)))
		if int(one["y"]) > 0:
			_check("...its floor held up on %d columns" % int(one["columns"]),
				int(one["columns"]) >= 1)
	_check("%s climbs from the forge to the library"
		% (str(floors[1]["climb"]) if floors.size() > 1 and not str(floors[1]["climb"]).is_empty()
			else "nothing"),
		floors.size() > 1 and not str(floors[1]["climb"]).is_empty())
	_check("it is open to the back, and says so", text.contains("open to the back"))


## The report of the last add_rooms, floor by floor.
func _last_floors() -> Array:
	return _assistant._last_rooms


## What each furnished floor of the last call was made of, to compare.
func _floor_signatures() -> Array:
	var out: Array = []
	for one: Dictionary in _last_floors():
		out.append("%s" % ", ".join(PackedStringArray(one["furniture"])))
	return out


## A house of three walls two studs thick, open at the back (-z), [param
## courses] high, built and standing; what it was, to compare against.
func _house(courses: int) -> Dictionary:
	_assistant.clear_built()
	var box: Assistant.Model = _assistant._read_model({"name": "House",
		"patterns": [
			{"pattern": "fill", "shape": "rectangle", "at": {"x": 40, "y": 0, "z": 0},
				"across": 2, "deep": 14, "layers": courses, "rise": 3, "color": 19},
			{"pattern": "fill", "shape": "rectangle", "at": {"x": 54, "y": 0, "z": 0},
				"across": 2, "deep": 14, "layers": courses, "rise": 3, "color": 19},
			{"pattern": "fill", "shape": "rectangle", "at": {"x": 42, "y": 0, "z": 12},
				"across": 12, "deep": 2, "layers": courses, "rise": 3, "color": 19},
		]})
	var verdict: Dictionary = _assistant._check(box)
	_check("the house holds on its own, %s" % verdict["summary"], bool(verdict["ok"]))
	_assistant._apply(box)
	return _snapshot()


func _snapshot() -> Dictionary:
	var out: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		out[brick.id] = [brick.part_id, brick.color_code, brick.transform]
	return out


func _shell_changes(before: Dictionary) -> String:
	var gone: int = 0
	var changed: int = 0
	for id: int in before:
		var brick: BrickWorld.Brick = _world.get_brick(id)
		if brick == null:
			gone += 1
			continue
		var was: Array = before[id]
		if brick.part_id != was[0] or brick.color_code != was[1] \
				or not brick.transform.is_equal_approx(was[2]):
			changed += 1
	if gone == 0 and changed == 0:
		return "untouched"
	return "%d gone, %d changed" % [gone, changed]


## Shapes and colours as tools/style.py counts them, and the style shares
## as the app's Style measures them.
func _measure() -> Dictionary:
	var parts: Array = []
	var shapes: Dictionary = {}
	var colours: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		var mesh: Lbm.PartMesh = _library.mesh_for(brick.part_id)
		if mesh == null:
			continue
		parts.append([brick.part_id, brick.color_code, brick.transform, mesh.bounds])
		shapes[_library.resolve(brick.part_id)] = true
		colours[brick.color_code] = true
	var found: Dictionary = Style.measure(parts)
	found["shapes"] = shapes.size()
	found["colours"] = colours.size()
	found["count"] = parts.size()
	return found


func _said(found: Dictionary) -> String:
	var shares := PackedStringArray()
	for key: String in ["snot", "angled", "curve", "texture", "plain", "symmetry"]:
		shares.append("%s %d%%" % [key, int(round(float(found.get(key, 0)) * 100))])
	return "%d parts, %d shapes, %d colours; %s" % [found["count"], found["shapes"],
		found["colours"], ", ".join(shares)]


func _pictures(name: String, only: AABB = AABB(),
		views: Array = ["back", "far corner", "corner"]) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var shot := ModelShot.new()
	shot.library = _library
	shot.rulers = false
	root.add_child(shot)
	for from: String in views:
		var image: Image = await shot.take(_world, from, {}, only)
		if image != null:
			var path: String = "%s/%s_%s.png" % [OUT, name, from.replace(" ", "_")]
			image.save_png(path)
			print("        wrote %s" % path)
	shot.queue_free()


func _write_ldr(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var placements: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		placements.append(LdrModel.Placement.new(brick.part_id, brick.color_code,
			brick.transform, 0))
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(LdrModel.write_ldr(placements, "Tower with rooms"))
		file.close()
		print("        wrote %s" % path)


static func _text_of(said: Variant) -> String:
	if said is String:
		return said
	var out := PackedStringArray()
	for block: Variant in said:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			out.append(str(block["text"]))
	return "\n".join(out)


func _check(label: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % label)
	else:
		_failures += 1
		print("  FAIL  %s" % label)
