## An edit that changes nothing says so, and why, rather than "Done".
##
##   godot --headless --path . --script src/dev/nothing_changed_probe.gd
##
## suite236 (2026-10-24): a session asked edit_selection to paint a wheel's
## tyre blue. 3641 was never made in blue, so it was put in black, the
## nearest it was made in, which it already was, and the answer read "Done.
## 62 bricks now. 3641 … is placed in 0 Black … Changed: . One undo takes the
## whole request back." Nothing had changed, there was nothing to undo, and
## the list said so with nothing in it. Here, on the example car, a session
## (Assistant.use_tool) paints a selected tyre blue, and a selected plate
## the colour it already is: each answer begins "Nothing changed", says why,
## and offers no undo, and the history is as it was. edit_model painting a
## plate its own colour says the same. A real recolour still says what it
## changed.
extends SceneTree

var _failures: int = 0
var _library: PartLibrary
var _world: BrickWorld
var _builder: Builder
var _assistant: Assistant


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("nothing_changed: SKIPPED, no catalogue")
		quit(3)
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
	for placement: LdrModel.Placement in LdrModel.load_file("res://models/car.ldr").flatten(_library.parts):
		var id: int = _world.add_brick(placement.part_id, placement.color_code, placement.transform)
		if id != 0:
			_builder.lattice.occupy_boxes(id, _builder.boxes_for(_library.mesh_for(placement.part_id),
				_world.get_brick(id).transform))
	await process_frame
	var tyre: int = _first("3641")
	var plate: int = _first_plate()
	print("  the car: %d parts, a tyre #%d, a plate #%d (colour %d)" % [_world.brick_count(), tyre,
		plate, _world.get_brick(plate).color_code if plate != 0 else -1])

	print("a selected tyre painted blue, which 3641 was never made in")
	var said: String = await _edit_selection([tyre], {"recolor": [{"bricks": [tyre], "color": 1}]})
	_nothing(said, "never made in", "the tyre")

	print("a selected plate painted the colour it is")
	var own: int = _world.get_brick(plate).color_code
	said = await _edit_selection([plate], {"recolor": [{"bricks": [plate], "color": own}]})
	_nothing(said, "already", "the plate")

	print("edit_model painting a plate the colour it is")
	_assistant.focus_off() if _assistant.has_method("focus_off") else null
	var depth: int = _builder.history_depth()
	said = str(await _assistant.use_tool("edit_model", {"recolor": [{"bricks": [plate], "color": own}],
		"picture": false}))
	print("    %s" % said.left(220).replace("\n", " | "))
	_check("it begins \"Nothing changed\" and says the plate is already that colour",
		said.begins_with("Nothing changed") and said.contains("already"))
	_check("...and claims no recolour", not said.contains("Recoloured"))
	_check("...and the history is as it was", _builder.history_depth() == depth)

	print("a real recolour")
	said = await _edit_selection([plate], {"recolor": [{"bricks": [plate], "color": 4 if own != 4 else 14}]})
	_check("it says what it changed: %s" % said.left(160).replace("\n", " | "),
		said.begins_with("Done") and not said.contains("Changed: .") and said.contains("Changed: "))

	print("")
	print("nothing_changed: %s" % ("all checks passed" if _failures == 0
		else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


func _edit_selection(ids: Array, args: Dictionary) -> String:
	_builder.selection.clear()
	for id: int in ids:
		_builder.selection[id] = true
	var refused: String = _assistant.focus_on(ids, true)
	if not refused.is_empty():
		return "could not focus: " + refused
	var depth: int = _builder.history_depth()
	var answer: Variant = await _assistant.use_tool("edit_selection", args)
	var said: String = _text(answer)
	print("    %s" % said.left(260).replace("\n", " | "))
	_kept_depth = _builder.history_depth() == depth
	return said


var _kept_depth: bool = true


func _nothing(said: String, why: String, what: String) -> void:
	_check("%s: it begins \"Nothing changed\"" % what, said.begins_with("Nothing changed"))
	_check("...says why (\"%s\")" % why, said.contains(why))
	_check("...has no empty list of changes and offers no undo",
		not said.contains("Changed: .") and not said.contains("One undo"))
	_check("...and the history is as it was", _kept_depth)


func _text(answer: Variant) -> String:
	if answer is Array:
		var out: String = ""
		for block: Variant in answer:
			if block is Dictionary and str((block as Dictionary).get("type", "")) == "text":
				out += str(block["text"]) + "\n"
		return out.strip_edges()
	return str(answer)


func _first(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick.id
	return 0


func _first_plate() -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id in ["3023", "3020", "3021", "3022", "3710", "3666", "3795", "3024", "3623"]:
			return brick.id
	return 0
