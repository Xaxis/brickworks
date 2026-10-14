## Does a save of no parts ever go over a model that has some, unless the
## person emptied the baseplate?
##
##   godot --headless --path . --script src/dev/empty_save_probe.gd
##
## The autosave writes the working model a few seconds after any change, on
## its own (ModelStore.tick). So whatever left the baseplate bare (a model
## that opened with none of its parts, the catalogue not arriving, the app
## clearing it for its own work) was written over the model it had held, and
## on the web that file was the only copy. A Save did the same to a named
## model. Only the app's own state is used here, as it stood on main, so the
## probe fails there: the autosave and the save both write the empty model.
##
## The person's own emptying still saves: Clear, New, and their edit taking
## the last part off. And a model that opened short of parts is still never
## written back, as before.
extends SceneTree

const NAME := "Empty Save Probe House"

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = main.get("_playback")
	if playback != null:
		playback.stop()
	var store: ModelStore = main.get("_store")
	var world: BrickWorld = main.get("_world")
	var bar: ModelBar = main.get("_bar")
	# A probe keeps no working model unless it turns that on (Main).
	store.keeps = true
	var autosave: String = ModelStore.autosave()
	var saved: String = ModelStore.saved_path(NAME)
	DirAccess.remove_absolute(autosave)
	DirAccess.remove_absolute(saved)

	var placed: int = store.open("res://models/house.ldr")
	store.title = NAME
	store.adopt()
	store.touch()
	store.write_now()
	var had: int = _parts(autosave)
	_check("the working model is kept: %d parts in the autosave" % had, had > 0 and had == placed)
	_check("and saved under its name: %s" % store.refused, store.save_as(NAME) and _parts(saved) == had)

	# The app empties the baseplate, not the person: the autosave and Save
	# must leave the files as they were.
	world.clear()
	store.touch()
	store.write_now()
	_check("an empty baseplate the person did not empty is not autosaved over the model: %d parts kept"
		% _parts(autosave), _parts(autosave) == had)
	var empty_save: bool = store.save_as(NAME)
	_check("nor saved over the named model: %d parts kept (%s)" % [_parts(saved), store.refused],
		not empty_save and _parts(saved) == had)

	# A model that opened short of parts is still never written back.
	store.open("res://models/house.ldr")
	store.title = NAME
	store.adopt()
	store.touch()
	store.write_now()
	var short: String = FileAccess.get_file_as_string("res://models/house.ldr") \
		+ "\n1 4 0 -400 0 1 0 0 0 1 0 0 0 1 nosuchpart.dat\n"
	store.open_text(short, NAME)
	store.touch()
	store.write_now()
	_check("a model that opened short of a part is not autosaved: %d parts kept" % _parts(autosave),
		_parts(autosave) == had)

	# The person's own emptying is saved: Clear…
	store.open("res://models/house.ldr")
	store.title = NAME
	store.adopt()
	store.touch()
	store.write_now()
	await bar._on_clear()
	store.touch()
	store.write_now()
	_check("Clear, by the person, is autosaved empty: %d parts" % _parts(autosave),
		FileAccess.file_exists(autosave) and _parts(autosave) == 0)

	# …their edit taking the last part off…
	store.open("res://models/house.ldr")
	store.title = NAME
	store.adopt()
	store.touch()
	store.write_now()
	for brick: BrickWorld.Brick in world.bricks():
		if not store.scenery.has(brick.id):
			world.remove_brick(brick.id)
	store.adopt()
	store.touch()
	store.write_now()
	_check("their own edit taking the last part off is autosaved empty: %d parts" % _parts(autosave),
		_parts(autosave) == 0)

	# …and New.
	store.open("res://models/house.ldr")
	store.title = NAME
	store.adopt()
	store.touch()
	store.write_now()
	await bar._start_new()
	store.touch()
	store.write_now()
	_check("New starts an empty working model: %d parts" % _parts(autosave), _parts(autosave) == 0)

	DirAccess.remove_absolute(saved)
	_done()


func _parts(path: String) -> int:
	return ModelStore.count_in(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else -1


func _check(what: String, ok: bool) -> void:
	if ok:
		print("  ok    %s" % what)
		return
	_failures += 1
	print("  FAIL  %s" % what)


func _done() -> void:
	print("")
	if _failures == 0:
		print("no save of no parts goes over a model with parts unless the person emptied it")
	else:
		print("%d FAILURE(S)" % _failures)
	quit(1 if _failures else 0)
