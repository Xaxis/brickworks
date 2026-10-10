## The strip across the top: what this model is called, and what can be
## done with it.
##
## Deliberately small. A model has a name, it can be saved and reopened,
## it can leave as a file, and it can be thrown away — and none of that
## should need a menu to find.
class_name ModelBar
extends PanelContainer

var store: ModelStore
var world: BrickWorld
var builder: Builder

var _name: LineEdit
var _status: Label
var _saves: PopupMenu
var _confirm: ConfirmationDialog
var _confirm_new: ConfirmationDialog
var _new: Button
var _save: Button
var _entries: Array[ModelStore.Entry] = []
var _picker: PickModel

## An id no index can be, for the menu row that is not a saved model.
const IMPORT := -2

signal cleared()
## A new model: an empty baseplate, no name and a fresh conversation.
signal started_new()
## The model is called something else now: opened, saved, begun or typed.
signal model_named(name: String)
## Someone wants the parts list. The bar does not own the panel — it is
## an overlay across the whole window, not a strip along the top.
signal parts_wanted()
## Someone wants to turn a picture into bricks.
signal mosaic_wanted()
## The timeline: the build from empty to finished and back.
signal timeline_wanted()
## Someone wants to make a minifigure.
signal minifig_wanted()
signal controls_wanted()
signal opened(bricks: int)


func _ready() -> void:
	_build()


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 6
	backing.content_margin_bottom = 6
	add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var mark := Label.new()
	mark.text = "Brickworks"
	mark.add_theme_font_size_override("font_size", 14)
	mark.modulate = Color(1, 1, 1, 0.75)
	row.add_child(mark)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(10, 0)
	row.add_child(gap)

	_name = LineEdit.new()
	_name.text = "Untitled"
	_name.custom_minimum_size = Vector2(190, 0)
	_name.tooltip_text = "What this model is called"
	# The store keeps the name, so the autosave keeps it too.
	_name.text_changed.connect(func(text: String) -> void:
		if store != null:
			store.title = text.strip_edges() if not text.strip_edges().is_empty() \
				else ModelStore.UNTITLED
			store.touch()
		model_named.emit(model_name()))
	row.add_child(_name)

	# In groups: the file, what to make of it, and help. Seven identical
	# buttons in a row gave Clear the same weight as Save, one place
	# along from Controls.
	# There was no way to begin another model: Clear empties the board and
	# keeps the name, the conversation and the autosave of what was there.
	_new = _button(row, "New", ask_for_new, "Start a new model on an empty baseplate (Ctrl+N)")
	_save = _button(row, "Save", _on_save, "Keep this model under its name")
	_button(row, "Open…", _on_open, "Reopen a saved model")
	_button(row, "Export", _on_export,
		"Write an LDraw file, which any brick tool reads — an .mpd of its assemblies when it has them")
	row.add_child(VSeparator.new())
	_button(row, "Parts list", func() -> void: parts_wanted.emit(),
		"Every part this model needs, by colour and count")
	_button(row, "Timeline", func() -> void: timeline_wanted.emit(),
		"Play the build from an empty baseplate to the finished model and back, or drag along it (B)")
	_button(row, "Mosaic", func() -> void: mosaic_wanted.emit(),
		"Turn a picture into a wall of plates")
	_button(row, "Minifig", func() -> void: minifig_wanted.emit(),
		"Make a minifigure from real parts and stand it in the model (M)")
	row.add_child(VSeparator.new())
	_button(row, "Help", func() -> void: controls_wanted.emit(),
		"What every button and key does, and how to change two of them")

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1, 1, 1, 0.65)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)

	# At the far end, and asked about. It empties the baseplate and the
	# undo history with it, and sat between Controls and the status line
	# as one more grey button that did it without a word.
	var clear: Button = _button(row, "Clear…", _ask_to_clear,
		"Empty the baseplate. Asks first: it cannot be undone")
	clear.modulate = Color(1.0, 0.75, 0.72)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Clear the baseplate?"
	_confirm.dialog_text = ("Every brick on it goes, and it cannot be undone. "
		+ "Save first if you might want it back.")
	_confirm.ok_button_text = "Clear it"
	_confirm.confirmed.connect(_on_clear)
	add_child(_confirm)

	_confirm_new = ConfirmationDialog.new()
	_confirm_new.title = "Start a new model?"
	_confirm_new.ok_button_text = "Start new without saving"
	_confirm_new.confirmed.connect(_start_new)
	_confirm_new.add_button("Save, then start new", true, "save")
	_confirm_new.custom_action.connect(func(action: StringName) -> void:
		if action == &"save":
			_confirm_new.hide()
			_on_save()
			if not store.has_unsaved_work():
				_start_new())
	add_child(_confirm_new)

	_saves = PopupMenu.new()
	_saves.id_pressed.connect(_on_pick)
	add_child(_saves)


func _button(row: HBoxContainer, text: String, action: Callable,
		tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	# Never keeps the keyboard.
	#
	# Godot does not drop focus for a click that lands on no Control, so
	# a toolbar button stayed focused for the rest of the session — and
	# a focused button eats the keys the app wanted. Tab and the arrows
	# stopped reaching the handler after the first click up here, which
	# is two bindings the strip along the bottom promises.
	#
	# It was worse than that while space slid the view: space is also
	# the key that presses a focused button, so panning after touching
	# this row fired whichever one had been clicked. With Clear, that is
	# the model and its undo history.
	#
	# Every other panel in the app already did this. This row was the
	# one that did not.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.pressed.connect(action)
	row.add_child(button)
	return button


func bind(to: ModelStore) -> void:
	store = to
	store.saved.connect(func(name: String) -> void:
		model_named.emit(name)
		_say("saved “%s”" % name))
	store.loaded.connect(func(name: String, bricks: int) -> void:
		_name.text = name
		model_named.emit(name)
		_say("opened %s — %d bricks" % [name, bricks]))


## The bar's own controls, for the page to find (Main._tell_page).
func controls_by_name() -> Dictionary:
	return {"model_name": _name, "new": _new, "save": _save}


func model_name() -> String:
	var text: String = _name.text.strip_edges()
	return text if not text.is_empty() else "Untitled"


## Say something in the bar's status line. Public because the parts list
## and the booklet live outside the bar but have nowhere else to report.
func say(text: String) -> void:
	_say(text)


func _say(text: String) -> void:
	_status.text = text
	# Clear it after a moment; a status line that never resets stops
	# meaning "just now".
	var timer: SceneTreeTimer = get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if _status.text == text:
			_status.text = "")


func _on_save() -> void:
	if store == null:
		return
	if world.brick_count() == 0:
		_say("nothing to save")
		return
	if not store.save_as(model_name()):
		_say("could not save that name")


func _on_open() -> void:
	if store == null:
		return
	# Saved models first, then the ones that ship with the app. Their own
	# work belongs at the top; the examples are there so the menu has
	# something in it the first time, when the honest answer to "open
	# what?" used to be "nothing saved yet".
	_entries = store.list_saved()
	var examples: Array[ModelStore.Entry] = store.list_examples()
	_saves.clear()
	# Exporting an .ldr and then having nowhere to put it back was the
	# shape of this before: the app could write the format it reads and
	# could not read the format it writes.
	_saves.add_item("From a file on this computer…", IMPORT)
	_saves.add_separator()
	if _entries.is_empty() and examples.is_empty():
		_saves.add_item("nothing saved yet")
		_saves.set_item_disabled(_saves.item_count - 1, true)
	else:
		for n: int in _entries.size():
			_saves.add_item(_entries[n].describe(), n)
		if not examples.is_empty():
			if not _entries.is_empty():
				_saves.add_separator("Examples")
			else:
				_saves.add_separator("Try one of these")
			for example: ModelStore.Entry in examples:
				_saves.add_item(example.describe(), _entries.size())
				_entries.append(example)
	_saves.reset_size()
	_saves.position = Vector2i(get_global_mouse_position()) + Vector2i(0, 8)
	_saves.popup()


func _on_pick(id: int) -> void:
	if id == IMPORT:
		_import()
		return
	if id < 0 or id >= _entries.size():
		return
	var entry: ModelStore.Entry = _entries[id]
	opened.emit(store.open(entry.path))


## Somebody else's .ldr, from wherever they keep it.
##
## The picker has to be asked while the click that opened the menu is
## still being handled, or a browser will not open the file dialog at
## all — which is why this is called straight from the menu rather than
## after a confirmation.
func _import() -> void:
	if _picker == null:
		_picker = PickModel.new()
		add_child(_picker)
		_picker.picked.connect(func(text: String, file_name: String) -> void:
			var result: Dictionary = store.open_text(
				text, file_name.get_basename())
			if not str(result["error"]).is_empty():
				_say(str(result["error"]))
				return
			opened.emit(int(result["placed"]))
			var note: String = "opened %d parts" % int(result["placed"])
			if int(result["missing"]) > 0:
				note += " — %d are not in the library" % int(result["missing"])
			if int(result.get("waiting", 0)) > 0:
				note += " — %d are still arriving, open it again in a moment" \
					% int(result["waiting"])
			_say(note))
		_picker.failed.connect(func(why: String) -> void: _say(why))
	_picker.ask()


func _on_export() -> void:
	if store == null:
		return
	if world.brick_count() == 0:
		_say("nothing to export")
		return
	# A model in assemblies is written as a multi-part document, and LDraw
	# names those .mpd so that whatever opens it knows to look for them.
	var grouped: bool = world.bricks().any(func(brick: BrickWorld.Brick) -> bool:
		return not brick.group.is_empty())
	var file_name: String = model_name().to_snake_case() \
		+ (".mpd" if grouped else ".ldr")
	if OS.has_feature("web"):
		store.export_to(file_name, model_name())
		_say("downloaded %s" % file_name)
		return
	# Only the name's last part: a model's title is named by whoever
	# designed it, and "../" in one would put the file somewhere else.
	var path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(
		file_name.replace("\\", "/").get_file())
	if store.export_to(path, model_name()):
		_say("wrote %s" % path)


## New, asking first only when there is something it would lose.
func ask_for_new() -> void:
	if store != null and store.has_unsaved_work():
		_confirm_new.dialog_text = ("“%s” is not saved as it is now. "
			% model_name() + "A new model replaces it on the baseplate.")
		_confirm_new.popup_centered()
		return
	_start_new()


func _start_new() -> void:
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	_name.text = ModelStore.UNTITLED
	if store != null:
		store.title = ModelStore.UNTITLED
		# Nothing in it is missing, so the autosave may keep it.
		store.adopt()
	model_named.emit(ModelStore.UNTITLED)
	started_new.emit()
	_say("new model")


func _ask_to_clear() -> void:
	_confirm.popup_centered()


func _on_clear() -> void:
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	cleared.emit()
	_say("cleared")
