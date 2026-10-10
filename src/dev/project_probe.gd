## A model has a name, keeps it across a restart, and a new one can begin.
##
##   godot --headless --path . --script src/dev/project_probe.gd
##
## The owner, in the web app: "there literally isnt a way to start a new
## project file. And when the app loads it loads the last project (which
## is fine) but it still says "Untitled" even though the project was saved
## and has a name!" The autosave was written as "Working model", and the
## bar never took a name from what it opened. So this saves a named model,
## lets the autosave write, opens it again the way a restart does, and
## asks the name field; then starts a new model with and without
## something to lose.
##
## It runs against this machine's own user data, so the autosave there
## is put back as it was, and the one model it saves is removed.
extends SceneTree

const NAME := "Brickworks Probe Tower"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var store: ModelStore = main.get("_store")
	var bar: ModelBar = main.get("_bar")
	var world: BrickWorld = main.get("_world")
	var builder: Builder = main.get("_builder")
	if store == null or bar == null or world == null:
		print("  FAIL  no store, bar or world")
		quit(1)
		return
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()

	var autosave_was: String = FileAccess.get_file_as_string(ModelStore.AUTOSAVE)
	var kept_at: String = ModelStore.SAVE_DIR + NAME + ".ldr"
	store.keeps = true

	# A model of its own, named the way a person names one: by typing.
	bar._on_clear()
	await process_frame
	for n: int in 3:
		var placed := Transform3D(Basis.IDENTITY, Vector3(0, 24 + 24 * n, 0))
		var brick_id: int = world.add_brick("3001", 4, placed)
		builder.register(brick_id, "3001", placed)
	bar._name.text = NAME
	bar._name.text_changed.emit(NAME)
	bar._on_save()
	_check("Save keeps it under its name, and the store knows the name",
		FileAccess.file_exists(kept_at) and store.title == NAME)
	_check("...and right after saving there is nothing a new model would lose",
		not store.has_unsaved_work())

	# The autosave, as it writes once a change has settled.
	store.touch()
	store.set("_dirty_at", 0)
	store.tick()
	_check("the autosave carries the name, not \"Working model\"",
		FileAccess.get_file_as_string(ModelStore.AUTOSAVE).begins_with("0 " + NAME))

	# A restart, as far as the name goes: a fresh bar, and the autosave
	# opened the way the app opens it.
	bar._name.text = ModelStore.UNTITLED
	store.restore()
	await process_frame
	_check("reopened, the name field says %s" % bar.model_name(),
		bar.model_name() == NAME)
	_check("...and so does the window's title: %s" % main.get_window().title,
		main.get_window().title.begins_with(NAME))
	_check("...and, saved and unchanged, it is nothing a new model would lose",
		not store.has_unsaved_work())

	# Something changed and not saved: New asks, and leaves it alone.
	var more := Transform3D(Basis.IDENTITY, Vector3(40, 24, 0))
	builder.register(world.add_brick("3001", 1, more), "3001", more)
	_check("a change after saving is work a new model would lose",
		store.has_unsaved_work())
	var standing: int = world.brick_count()
	bar.ask_for_new()
	await process_frame
	_check("...so New asks first, and the model is still there, %d bricks"
		% world.brick_count(),
		bar._confirm_new.visible and world.brick_count() == standing)
	bar._confirm_new.hide()
	bar._confirm_new.confirmed.emit()
	for _n: int in 5:
		await process_frame
	var scenery: Dictionary = store.scenery
	_check("starting new without saving leaves only the baseplate, %d bricks, %d of them ground"
			% [world.brick_count(), scenery.size()],
		world.brick_count() == scenery.size())
	_check("...and the new model is Untitled", bar.model_name() == ModelStore.UNTITLED
		and store.title == ModelStore.UNTITLED)

	# Nothing to lose: New just begins.
	bar.ask_for_new()
	await process_frame
	_check("with nothing on the baseplate, New does not ask",
		not bar._confirm_new.visible)

	# An autosave from before, titled "Working model", opens as Untitled
	# rather than under that placeholder.
	var old := FileAccess.open(ModelStore.AUTOSAVE, FileAccess.WRITE)
	old.store_string("0 Working model\n1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
	old.close()
	bar._name.text = "something else"
	store.restore()
	await process_frame
	_check("an autosave from before reopens as %s" % bar.model_name(),
		bar.model_name() == ModelStore.UNTITLED)

	# The way the owner met it: the sample car, as a first visit opens it,
	# named, saved, written to the autosave and opened again. New then
	# said it was not saved.
	# Through the app's own open, as a first visit does: it was the one
	# path that did not stand the car on the ground.
	var sample: String = main.get("SAMPLE_MODEL")
	world.clear()
	main.call("_open", sample)
	await process_frame
	bar._name.text = NAME
	bar._name.text_changed.emit(NAME)
	bar._on_save()
	store.touch()
	store.set("_dirty_at", 0)
	store.tick()
	store.restore()
	for _n: int in 5:
		await process_frame
	var now_lines: PackedStringArray = ModelStore._brick_lines(store.to_text(ModelStore.UNTITLED))
	var kept_lines: PackedStringArray = ModelStore._brick_lines(FileAccess.get_file_as_string(kept_at))
	var differ: PackedStringArray = PackedStringArray()
	for line: String in now_lines:
		if not kept_lines.has(line):
			differ.append("now  " + line)
	for line: String in kept_lines:
		if not now_lines.has(line):
			differ.append("kept " + line)
	_check("the sample, saved and reopened, is nothing a new model would lose (%d of %d lines differ%s)"
			% [differ.size() / 2, now_lines.size(),
				": " + differ[0] if not differ.is_empty() else ""],
		not store.has_unsaved_work())

	# Every model the app ships, opened the way a first visit opens one,
	# stands on the ground: nothing below it, and nothing lifted clear of
	# it. Measured by the cells the bricks occupy, as the lift used to be,
	# so the catalogue-bounds lift that replaced it agrees with it.
	for entry: ModelStore.Entry in store.list_examples():
		var raw: LdrModel = LdrModel.load_file(entry.path)
		var needed: Vector3 = store.lift_for(raw.flatten(main.get("_library").parts)) \
			if raw != null else Vector3.ZERO
		world.clear()
		main.call("_open", entry.path)
		await process_frame
		var lowest: int = 0x7FFFFFFF
		for brick: BrickWorld.Brick in world.bricks():
			var mesh: Lbm.PartMesh = main.get("_library").mesh_for(brick.part_id)
			if mesh != null:
				for cell: Vector3i in builder._cells_for(mesh, brick.transform):
					lowest = mini(lowest, cell.y)
		_check("%s opens on the ground: lowest cell %d%s" % [entry.name, lowest,
				", lifted %.0f LDU" % needed.y if needed.y > 0.0 else ""],
			lowest >= 0 and (needed.y == 0.0 or lowest == 0))

	# Leave the machine as it was.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(kept_at))
	var back := FileAccess.open(ModelStore.AUTOSAVE, FileAccess.WRITE)
	back.store_string(autosave_was)
	back.close()
	store.keeps = false

	print("")
	print("%d failed" % _failures if _failures
		else "a model keeps its name, and a new one can begin")
	quit(1 if _failures else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
