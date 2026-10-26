## place_technique finds the hold a real set's piece needs in the model.
##
##   godot --path . --resolution 1280x860 --script src/dev/place_held_probe.gd
##
## A sub-model cut out of a set is often held by the set around it, and
## place_technique said so ("held from outside it, so hold it in your model
## or copy it"): main2's Sydney session was shown 21012's own shell that way
## and built flat wedges, and 16 of 88 proof sessions placed any real piece
## (design281, 2026-10-26). Now it finds the hold (PieceHold): each kind of
## sub-assembly the losses named (a hinged shell, an arch, a wheel arch, a
## window frame, a roof section) is asked for in the air over a model with
## nothing there to hold it, and is laid whole on the nearest place that
## does, the model checked whole after. Asked far from anything, it is
## refused with the nearest place that holds it, and laid there when asked
## again. Each answer says the same build at the sizes real sets use it.
## Windowed for a picture of each (shots/place_held/); headless it skips
## the pictures.
extends SceneTree


## Each kind, and real pieces of it to try, held from outside them first.
const KINDS: Array = [
	["hinged shell", ["6890-1/cluster-3", "6601-1/cluster-1", "4404-1/hood"]],
	["arch", ["3938-1/cluster-2", "10359-1/cluster-1", "10220-1/van-s026"]],
	["wheel arch", ["30103-1/cluster-1", "10264-1/cluster-1", "2531-1/cluster-2",
		"10220-1/van-s014-l"]],
	["window frame", ["21037-1/cluster-2", "10270-1/cluster-1", "10182-1/cluster-3"]],
	["roof section", ["10267-1/house-step82-92", "10264-1/cluster-2",
		"10243-1/roof-roof2-window"]],
]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if not RealSnippets.available():
		print("SKIP no real-set index at %s (tools/snippets.py build)" % RealSnippets.INDEX)
		quit(3)
		return
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var assistant := Assistant.new()
	assistant.library = library
	assistant.world = world
	assistant.builder = builder
	root.add_child(assistant)
	await process_frame

	var laid_kinds: int = 0
	var held_from_outside: int = 0
	for row: Array in KINDS:
		var kind: String = row[0]
		print("\n%s" % kind)
		var laid: String = ""
		for id: String in row[1]:
			var entry: Dictionary = RealSnippets.entry(id)
			if entry.is_empty():
				print("    %s: not in this index" % id)
				continue
			await _house(assistant)
			var before: int = world.brick_count()
			# In the air, three plates over the house's walls, where nothing holds it.
			var answer: String = _text(await assistant.use_tool("place_technique",
				{"id": id, "x": 5, "y": 10, "z": 5}))
			var added: int = world.brick_count() - before
			var whole: Dictionary = assistant._check(assistant._model_from_world())
			print("    %s (%s, %d parts): %s" % [id, "lays alone" if bool(entry.get("lays"))
				else "alone: " + str(entry.get("why", "")), int(entry["parts"]),
				answer.get_slice("\n", 0).left(260)])
			if added == int(entry["parts"]) and bool(whole["ok"]) and int(whole["pieces"]) == 1:
				laid = id
				if not bool(entry.get("lays")):
					held_from_outside += 1
				_ok(answer.contains("laid whole at") and answer.contains("held by")
					and answer.contains("nearest place the model holds it"),
					"%s: laid whole where the model holds it, every part (%d), the model "
						% [id, added] + "checked whole after, and the answer says where and by what")
				await _picture(assistant, kind.replace(" ", "_"))
				break
		_ok(not laid.is_empty(), "%s: a real piece of the kind laid whole and held" % kind)
		if not laid.is_empty():
			laid_kinds += 1
	_ok(laid_kinds == KINDS.size() and held_from_outside >= 3,
		"%d of %d kinds laid, %d of them pieces that do not hold alone"
			% [laid_kinds, KINDS.size(), held_from_outside])

	print("\nasked far from anything, it says the nearest place that holds it")
	await _house(assistant)
	var far: String = _text(await assistant.use_tool("place_technique",
		{"id": "3938-1/cluster-2", "x": 40, "y": 0, "z": 40}))
	print("    " + far.left(400))
	var place: RegExMatch = RegEx.create_from_string(
		"nearest place with a hold is x=(-?[\\d.]+) y=(-?[\\d.]+) z=(-?[\\d.]+), turn (\\d)").search(far)
	_ok(far.begins_with("Not applied") and place != null,
		"refused, naming the nearest place with a hold")
	if place != null:
		var before: int = world.brick_count()
		var there: String = _text(await assistant.use_tool("place_technique",
			{"id": "3938-1/cluster-2", "x": float(place.get_string(1)),
				"y": float(place.get_string(2)), "z": float(place.get_string(3)),
				"turn": int(place.get_string(4))}))
		_ok(world.brick_count() - before == int(RealSnippets.entry("3938-1/cluster-2")["parts"])
			and not there.contains("asked at"),
			"...and asked there, it is laid there as asked: %s" % there.get_slice("\n", 0).left(160))

	print("\nthe same build at the sizes real sets use it")
	var sized: int = 0
	for row: Array in KINDS:
		for id: String in row[1]:
			var entry: Dictionary = RealSnippets.entry(id)
			if entry.is_empty():
				continue
			var sizes: Array = RealSnippets.sizes_of(entry)
			if sizes.is_empty():
				continue
			sized += 1
			var said := PackedStringArray()
			var heads: PackedStringArray = RealSnippets.first_heads(entry)
			var same: bool = true
			for other: Variant in sizes:
				said.append("%s %sx%s" % [(other as Dictionary)["id"],
					(other as Dictionary)["size"][0], (other as Dictionary)["size"][2]])
				if not RealSnippets.first_heads(other).has(heads[0]):
					same = false
			print("    %s %sx%s (%s): %s" % [id, entry["size"][0], entry["size"][2],
				" ".join(heads), "; ".join(said)])
			_ok(same, "%s: each size offered is the same thing, a %s" % [id, heads[0]])
	_ok(sized >= 5, "%d pieces have the same build at other sizes to pick from" % sized)

	print("")
	if _failures == 0:
		print("OK place_held_probe")
	else:
		print("FAILED place_held_probe: %d" % _failures)
	quit(1 if _failures > 0 else 0)


## A small house with nothing on it: a 16 x 16 plate, and walls of 1 x 4 and
## 1 x 2 bricks two courses high round a room 6 by 6.
func _house(assistant: Assistant) -> void:
	assistant.world.clear()
	assistant.builder.lattice.clear()
	var bricks: Array = [{"part": "91405", "color": 2, "x": 0, "y": 0, "z": 0, "rot": 0}]
	for y: int in [1, 4]:
		for z: int in [4, 11]:
			for x: int in [4, 8]:
				bricks.append({"part": "3010", "color": 15, "x": x, "y": y, "z": z, "rot": 0})
		for x: int in [4, 11]:
			bricks.append({"part": "3010", "color": 15, "x": x, "y": y, "z": 5, "rot": 1})
			bricks.append({"part": "3004", "color": 15, "x": x, "y": y, "z": 9, "rot": 1})
	var said: Variant = await assistant._run_tool({"name": "edit_model", "input": {"add": bricks}})
	if assistant.world.brick_count() != bricks.size():
		print("    the house was not built: %s" % _text(said).left(300))


func _picture(assistant: Assistant, name: String) -> void:
	if not ModelShot.possible():
		return
	var image: Image = await assistant._ensure_shot().take(assistant.world, "corner",
		assistant.scenery)
	if image == null:
		return
	var path: String = ProjectSettings.globalize_path("res://shots/place_held/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/place_held/%s.png" % name)


func _text(answer: Variant) -> String:
	if answer is String:
		return answer
	var said := PackedStringArray()
	for block: Variant in answer as Array:
		if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
			said.append(str((block as Dictionary)["text"]))
	return "\n".join(said)


func _ok(passed: bool, said: String) -> void:
	print("  %s  %s" % ["ok  " if passed else "FAIL", said])
	if not passed:
		_failures += 1
