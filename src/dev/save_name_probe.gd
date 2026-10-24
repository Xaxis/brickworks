## Does Save ask what to call a model nobody has named, and never write over
## a saved one?
##
##   godot --headless --path . --script src/dev/save_name_probe.gd
##
## walk180 (2026-10-23): New, a model built, then New's "Save, then start
## new", and it was saved as "Untitled" without a word. So here a new model
## is built and saved as a person does: Save asks a name first (ModelBar
## .ask_name); Cancel saves nothing; a name a saved model has is refused,
## the question kept up; a name of its own saves it under that. Then Save on
## it asks nothing; and "Save, then start new" on another new model asks,
## saves and starts the new one.
##
## Saves only under names of its own, in its own data folder (tools/probe.sh).
extends SceneTree

const TAKEN := "Save Name Probe Taken"
const NAMED := "Save Name Probe House"
const AFTER := "Save Name Probe Tower"

var _failures: int = 0
var _main: Node
var _store: ModelStore
var _bar: ModelBar
var _world: BrickWorld
var _builder: Builder


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
	if _store == null or _bar == null:
		print("  FAIL  no store or bar")
		quit(1)
		return

	# A saved model of the name a person might type.
	await _bar._start_new()
	_place(0)
	_name(TAKEN)
	_check("a model saved as \"%s\"" % TAKEN, await _bar._on_save())
	var taken_text: String = FileAccess.get_file_as_string(ModelStore.saved_path(TAKEN))

	print("\n  a new model, built and saved")
	await _bar._start_new()
	_place(0)
	_place(48)
	_check("New is Untitled: \"%s\"" % _bar.model_name(), _bar.model_name() == ModelStore.UNTITLED)
	var answer: Array = []
	_save_into(answer)
	await process_frame
	_check("Save asks what to call it: \"%s\"" % _words(), _asking() and _words() == ModelBar.NAME_ASK)
	_check("...and has saved nothing yet",
		not FileAccess.file_exists(ModelStore.saved_path(ModelStore.UNTITLED)))
	(_bar.get("_ask_name") as ConfirmationDialog).get_cancel_button().pressed.emit()
	await process_frame
	_check("Cancel puts the question away and saves nothing: %s, \"%s\"" % [str(answer), _bar.status_text()],
		not _asking() and answer == [false]
		and not FileAccess.file_exists(ModelStore.saved_path(ModelStore.UNTITLED)))

	answer.clear()
	_save_into(answer)
	await process_frame
	_type(TAKEN)
	(_bar.get("_ask_name") as ConfirmationDialog).get_ok_button().pressed.emit()
	await process_frame
	_check("a name a saved model has is refused, the question kept up: \"%s\"" % _words(),
		_asking() and _words().contains("is a saved model already") and answer.is_empty())
	_check("...and that model is as it was",
		FileAccess.get_file_as_string(ModelStore.saved_path(TAKEN)) == taken_text)
	_type(NAMED)
	(_bar.get("_ask_name") as ConfirmationDialog).get_ok_button().pressed.emit()
	for _n: int in 10:
		await process_frame
	_check("a name of its own saves it under that: %s, \"%s\", %d parts in the file" % [str(answer),
			_store.title, ModelStore.count_in(FileAccess.get_file_as_string(ModelStore.saved_path(NAMED)))],
		not _asking() and answer == [true] and _store.title == NAMED and _bar.model_name() == NAMED
		and ModelStore.count_in(FileAccess.get_file_as_string(ModelStore.saved_path(NAMED))) == 2)
	_place(96)
	answer.clear()
	_save_into(answer)
	for _n: int in 10:
		await process_frame
	_check("Save on it again asks nothing, and saves: %s, %d parts" % [str(answer),
			ModelStore.count_in(FileAccess.get_file_as_string(ModelStore.saved_path(NAMED)))],
		not _asking() and answer == [true]
		and ModelStore.count_in(FileAccess.get_file_as_string(ModelStore.saved_path(NAMED))) == 3)

	print("\n  \"Save, then start new\" on another new model")
	await _bar._start_new()
	_place(0)
	var done: Array = []
	_then_new_into(done)
	await process_frame
	_check("it asks what to call it", _asking())
	_type(AFTER)
	(_bar.get("_ask_name_field") as LineEdit).text_submitted.emit(AFTER)
	for _n: int in 20:
		await process_frame
	_check("Enter saves it under that name, then starts the new model: \"%s\", %d parts on the baseplate"
			% [_bar.model_name(), _own_bricks()],
		done == [true] and FileAccess.file_exists(ModelStore.saved_path(AFTER))
		and _bar.model_name() == ModelStore.UNTITLED and _own_bricks() == 0)
	_check("...and nothing was ever saved as \"Untitled\"",
		not FileAccess.file_exists(ModelStore.saved_path(ModelStore.UNTITLED)))

	for name: String in [TAKEN, NAMED, AFTER]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.saved_path(name)))
	print("")
	print("%d failed" % _failures if _failures
		else "Save asks a new model's name, and never writes over a saved model with it")
	quit(1 if _failures else 0)


func _save_into(answer: Array) -> void:
	answer.append(await _bar._on_save())


func _then_new_into(done: Array) -> void:
	await _bar._save_then_new()
	done.append(true)


func _asking() -> bool:
	return (_bar.get("_ask_name") as ConfirmationDialog).visible


func _words() -> String:
	return (_bar.get("_ask_name_words") as Label).text


func _type(text: String) -> void:
	(_bar.get("_ask_name_field") as LineEdit).text = text


## Typed into the bar, as a person names a model.
func _name(text: String) -> void:
	_bar._name.text = text
	_bar._name.text_changed.emit(text)


func _place(x: int) -> void:
	var at := Transform3D(Basis.IDENTITY, Vector3(x, 24, 0))
	_builder.register(_world.add_brick("3001", 1, at), "3001", at)


func _own_bricks() -> int:
	return _world.brick_count() - _store.scenery.size()
