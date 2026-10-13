## The example car's name goes with it, and new work is named for itself.
##
##   godot --headless --path . --script src/dev/example_name_probe.gd
##
## A first visit opens the example, "Car". The
## assistant starting a design on it, or Brickify putting a model down,
## takes the car off to make room — and the model kept the car's name, so
## the tower in its place was saved as the example. This takes it off each
## way there is and reads the name the bar, the store and the window give:
## a design is called what its brief asks for, then what the design calls
## itself; a brickified model is called after its file; Clear and the
## command socket's clear_model leave an Untitled model. Then the rest of
## the ways a model is cleared or begun: a person's own name is kept by
## Clear and by a design, New is Untitled, a bare untitled baseplate is
## named by the design started on it, and a name a saved model has gets a
## number rather than being written over.
##
## Saves only under names of its own, and removes them.
extends SceneTree

const EXAMPLE := "Car"
const OWN := "Brickworks Name Probe House"
const TAKEN := "Brickworks Name Probe Tower"
const DESIGNED := "Brickworks Name Probe Orthanc"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _bar: ModelBar
var _world: BrickWorld
var _builder: Builder
var _chat: ChatPanel
var _made: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_store = _main.get("_store")
	_bar = _main.get("_bar")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_chat = _main.get("_chat")
	var assistant: Assistant = _main.get("_assistant")
	if _store == null or _bar == null or _chat == null or assistant == null:
		print("  FAIL  no store, bar, chat or assistant")
		quit(1)
		return
	var example_save: String = ModelStore.SAVE_DIR + EXAMPLE + ".ldr"
	var example_saved_at: int = FileAccess.get_modified_time(example_save) \
		if FileAccess.file_exists(example_save) else -1

	print("\n  a first visit, and a design started on it")
	_check("a first visit opens the example, %s: \"%s\"" % [_counts(), _bar.model_name()],
		_bar.model_name() == EXAMPLE and _own_bricks() > 0
		and bool(_main.get("_sample_untouched")))
	_chat.designing.emit(
		"Build the Tower of Orthanc from Lord of the Rings, about 40 cm tall")
	await process_frame
	_check("the design takes the car off: %s" % _counts(), _own_bricks() == 0)
	_check("...and the model is named for the brief, not the car: bar \"%s\", store \"%s\""
			% [_bar.model_name(), _store.title],
		_bar.model_name() == "Tower of Orthanc" and _store.title == "Tower of Orthanc")
	_check("...and so is the window: \"%s\"" % _main.get_window().title,
		_main.get_window().title.begins_with("Tower of Orthanc"))
	var answer: Variant = await assistant.use_tool("submit_design", {
		"name": DESIGNED, "description": "a probe's one brick",
		"bricks": [{"part": "3001", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0}],
	})
	await process_frame
	_check("the design stands (%s) and its own name takes over: \"%s\""
			% [str(answer).left(60).replace("\n", " "), _bar.model_name()],
		_own_bricks() == 1 and _bar.model_name() == DESIGNED and _store.title == DESIGNED)
	_bar._on_save()
	_made.append(ModelStore.SAVE_DIR + DESIGNED + ".ldr")
	_check("Save keeps it under that name", FileAccess.file_exists(_made[-1]))
	var example_now: int = FileAccess.get_modified_time(example_save) \
		if FileAccess.file_exists(example_save) else -1
	_check("...and writes nothing under the example's", example_now == example_saved_at)
	await assistant.use_tool("submit_design", {
		"name": "Something Else", "description": "the same brick, renamed",
		"bricks": [{"part": "3001", "color": 0, "x": 0, "y": 0, "z": 0, "rot": 0}],
	})
	await process_frame
	_check("once saved, a design's name is not put over it: \"%s\"" % _bar.model_name(),
		_bar.model_name() == DESIGNED)

	print("\n  Brickify on the example")
	_first_visit()
	var dialog: BrickifyDialog = _main.get("_brickify")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(
		"res://tests/fixtures/brickify/bunny.obj")
	var mesh: MeshFile = MeshFile.read(bytes, "bunny.obj", {})
	dialog.show_for(mesh)
	dialog._studs.value = 24
	var down: Array = [false]
	dialog.brickified.connect(func(_ids: PackedInt64Array, _summary: String) -> void:
		down[0] = true, CONNECT_ONE_SHOT)
	dialog._go.pressed.emit()
	for _n: int in 3000:
		if down[0]:
			break
		await process_frame
	var bunny: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and brick.group == "bunny":
			bunny += 1
	_check("the bunny goes down where the car was: %s, %d of them the bunny"
			% [_counts(), bunny], down[0] and bunny > 0 and bunny == _own_bricks())
	_check("...and the model is called after the file, not the car: \"%s\""
			% _bar.model_name(), _bar.model_name() == "bunny" and _store.title == "bunny")

	print("\n  clearing the example")
	_first_visit()
	_bar._on_clear()
	await process_frame
	_check("Clear on the example leaves an Untitled model: \"%s\", %s"
			% [_bar.model_name(), _counts()],
		_own_bricks() == 0 and _bar.model_name() == ModelStore.UNTITLED
		and _store.title == ModelStore.UNTITLED)
	_bar.opened.emit(_store.open(_main.get("SAMPLE_MODEL")))
	_bar._on_clear()
	await process_frame
	_check("...and on the example opened from the menu: \"%s\"" % _bar.model_name(),
		_bar.model_name() == ModelStore.UNTITLED)
	_first_visit()
	_main.call("clear_model")
	await process_frame
	_check("the command socket's clear_model too: \"%s\"" % _bar.model_name(),
		_own_bricks() == 0 and _bar.model_name() == ModelStore.UNTITLED)

	print("\n  a person's own model")
	_name(OWN)
	_place(0)
	_bar._on_clear()
	await process_frame
	_check("Clear keeps a name somebody gave it: \"%s\"" % _bar.model_name(),
		_bar.model_name() == OWN)
	_chat.designing.emit("a lighthouse")
	await process_frame
	_check("...and so does a design started on it bare: \"%s\"" % _bar.model_name(),
		_bar.model_name() == OWN)
	await assistant.use_tool("submit_design", {
		"name": "Lighthouse", "description": "one brick",
		"bricks": [{"part": "3001", "color": 4, "x": 0, "y": 0, "z": 0, "rot": 0}],
	})
	await process_frame
	_check("...and when it stands: \"%s\"" % _bar.model_name(), _bar.model_name() == OWN)
	_main.call("clear_model")
	await process_frame
	_check("clear_model, for something new, begins an Untitled one: \"%s\""
			% _bar.model_name(), _bar.model_name() == ModelStore.UNTITLED)

	print("\n  New, and a design on a bare baseplate")
	_name(OWN)
	_bar._start_new()
	await process_frame
	_check("New is Untitled: \"%s\"" % _bar.model_name(),
		_bar.model_name() == ModelStore.UNTITLED and _store.title == ModelStore.UNTITLED)
	for pair: Array in [
			["Build the Tower of Orthanc from Lord of the Rings, about 40 cm tall",
				"Tower of Orthanc"],
			["a small red house with a door and two windows", "Small red house"],
			["Can you make me a LEGO model of the Eiffel Tower?", "Eiffel Tower"],
			["a red and white lighthouse", "Red and white lighthouse"],
			["a double decker bus", "Double decker bus"],
			["lighthouse", "Lighthouse"]]:
		_bar._start_new()
		_chat.designing.emit(pair[0])
		await process_frame
		_check("a design on a bare, untitled baseplate: \"%s\" is \"%s\""
				% [pair[0], _bar.model_name()], _bar.model_name() == pair[1])
	_bar._start_new()
	_place(0)
	_chat.designing.emit("a lighthouse")
	await process_frame
	_check("...but not one going into bricks already standing: \"%s\"" % _bar.model_name(),
		_bar.model_name() == ModelStore.UNTITLED)

	print("\n  a name a saved model has")
	var taken := FileAccess.open(ModelStore.SAVE_DIR + TAKEN + ".ldr", FileAccess.WRITE)
	taken.store_string("0 %s\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n" % TAKEN)
	taken.close()
	_made.append(ModelStore.SAVE_DIR + TAKEN + ".ldr")
	_bar._start_new()
	_chat.designing.emit("the %s, in grey" % TAKEN)
	await process_frame
	_check("new work is not given a saved model's name: \"%s\"" % _bar.model_name(),
		_bar.model_name() == TAKEN + " 2")

	# Before the fix, Save wrote the tower here.
	if example_saved_at == -1:
		_made.append(example_save)
	for path: String in _made:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("")
	print("%d failed" % _failures if _failures
		else "new work is named for itself, never for the example it replaced")
	quit(1 if _failures else 0)


## The example car on the baseplate as a first visit has it.
func _first_visit() -> void:
	_main.call("_open", _main.get("SAMPLE_MODEL"))
	_main.call("_lay_baseplate")
	_main.set("_sample_untouched", true)


## Typed into the bar, as a person names a model.
func _name(text: String) -> void:
	_bar._name.text = text
	_bar._name.text_changed.emit(text)


func _place(x: int) -> void:
	var at := Transform3D(Basis.IDENTITY, Vector3(x, 24, 0))
	_builder.register(_world.add_brick("3001", 1, at), "3001", at)


func _own_bricks() -> int:
	return _world.brick_count() - _store.scenery.size()


func _counts() -> String:
	return "%d parts on the baseplate" % _own_bricks()
