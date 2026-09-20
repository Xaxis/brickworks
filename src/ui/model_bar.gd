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
var _entries: Array[ModelStore.Entry] = []

signal cleared()
## Someone wants the parts list. The bar does not own the panel — it is
## an overlay across the whole window, not a strip along the top.
signal parts_wanted()
## Someone wants to turn a picture into bricks.
signal mosaic_wanted()
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
	row.add_child(_name)

	_button(row, "Save", _on_save, "Keep this model under its name")
	_button(row, "Open…", _on_open, "Reopen a saved model")
	_button(row, "Export", _on_export, "Write an .ldr file, which any brick tool reads")
	_button(row, "Parts", func() -> void: parts_wanted.emit(),
		"Every part this model needs, by colour and count")
	_button(row, "Mosaic", func() -> void: mosaic_wanted.emit(),
		"Turn a picture into a wall of plates")
	_button(row, "Clear", _on_clear, "Empty the baseplate")

	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 11)
	_status.modulate = Color(1, 1, 1, 0.55)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_status)

	_saves = PopupMenu.new()
	_saves.id_pressed.connect(_on_pick)
	add_child(_saves)


func _button(row: HBoxContainer, text: String, action: Callable,
		tip: String) -> void:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	row.add_child(button)


func bind(to: ModelStore) -> void:
	store = to
	store.saved.connect(func(name: String) -> void:
		_say("saved “%s”" % name))
	store.loaded.connect(func(name: String, bricks: int) -> void:
		_say("opened %s — %d bricks" % [name, bricks]))


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
	if _entries.is_empty() and examples.is_empty():
		_saves.add_item("nothing saved yet")
		_saves.set_item_disabled(0, true)
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
	if id < 0 or id >= _entries.size():
		return
	var entry: ModelStore.Entry = _entries[id]
	_name.text = entry.name
	opened.emit(store.open(entry.path))


func _on_export() -> void:
	if store == null:
		return
	if world.brick_count() == 0:
		_say("nothing to export")
		return
	var file_name: String = model_name().to_snake_case() + ".ldr"
	if OS.has_feature("web"):
		store.export_to(file_name, model_name())
		_say("downloaded %s" % file_name)
		return
	var path: String = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(file_name)
	if store.export_to(path, model_name()):
		_say("wrote %s" % path)


func _on_clear() -> void:
	world.clear()
	builder.lattice.clear()
	cleared.emit()
	_say("cleared")
