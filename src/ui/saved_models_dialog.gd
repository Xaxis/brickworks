## File, Open, Rename or delete saved models…: the person's saved models,
## newest first, each to rename or delete (lib219, 2026-10-24).
##
## A saved model could be opened and saved over, and never taken away or
## called anything else. The account keeps 500 models and 64 MB at most
## (CloudModels), so a person who saved a lot came to be unable to save
## with it, with nothing they could do about it. Delete asks first, and
## each delete is kept in this tab for Undo, on its row here
## (ModelStore.delete_saved). Signed in, a delete or a rename reaches the
## account and every browser and computer signed in to it.
##
## Opened by the offer of a full account (AccountFullOffer) oldest first,
## where the models to delete most likely are.
class_name SavedModelsDialog
extends AcceptDialog

var store: ModelStore
var cloud: CloudModels
var say: Callable = func(_line: String) -> void: pass

var _note: Label
var _rows: VBoxContainer
var _shown: Array[ModelStore.Entry] = []
var _renames: Array[Button] = []
var _deletes: Array[Button] = []
var _undos: Array[Button] = []
## This tab's deletes, the newest last: {name, kept}, kept being the copy
## Undo puts back.
var deleted: Array[Dictionary] = []
var _oldest_first: bool = false
## The saved model a question is about, by name.
var _asked: String = ""

var _confirm_delete: ConfirmationDialog
var _rename: ConfirmationDialog
var _rename_words: Label
var _rename_field: LineEdit


func _ready() -> void:
	title = "Saved models"
	ok_button_text = "Close"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(480, 0)
	add_child(column)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(480, 0)
	column.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)

	_confirm_delete = ConfirmationDialog.new()
	_confirm_delete.ok_button_text = "Delete"
	_confirm_delete.confirmed.connect(func() -> void: _delete(_asked))
	add_child(_confirm_delete)

	# As Save asks a name (ModelBar.ask_name): kept up while the name will
	# not do, saying why.
	_rename = ConfirmationDialog.new()
	_rename.title = "Rename"
	_rename.ok_button_text = "Rename"
	_rename.dialog_hide_on_ok = false
	var asking := VBoxContainer.new()
	_rename_words = Label.new()
	asking.add_child(_rename_words)
	_rename_field = LineEdit.new()
	_rename_field.custom_minimum_size = Vector2(320, 0)
	_rename_field.text_submitted.connect(func(_text: String) -> void: _take_rename())
	asking.add_child(_rename_field)
	_rename.add_child(asking)
	_rename.confirmed.connect(_take_rename)
	add_child(_rename)


## Show the saved models, newest first, or with [param oldest_first] the
## oldest: to make room in a full account.
func open(oldest_first: bool = false) -> void:
	_oldest_first = oldest_first
	fill()
	popup_centered()


## The rows again, as the saved models are now.
func fill() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	_renames.clear()
	_deletes.clear()
	_undos.clear()
	_shown = store.list_saved()
	if _oldest_first:
		_shown.reverse()
	var words: String = ("No models are saved %s." % CloudModels.here()) if _shown.is_empty() \
		else ("Your saved models, %s first. Rename one, or delete those you no longer need."
			% ("oldest" if _oldest_first else "newest"))
	if _with_account():
		words += " A delete or a rename is made with your account too, in every browser and on every computer you are signed in to."
		var short: String = cloud.short_words()
		if not short.is_empty():
			words += "\n\n" + short
	_note.text = words
	for n: int in _shown.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var said := Label.new()
		said.text = _shown[n].describe()
		said.clip_text = true
		said.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(said)
		var rename := _row_button("Rename…", "Call “%s” something else" % _shown[n].name)
		rename.pressed.connect(_ask_rename.bind(_shown[n].name))
		row.add_child(rename)
		_renames.append(rename)
		var delete := _row_button("Delete…", "Delete “%s”, asking first" % _shown[n].name)
		delete.pressed.connect(_ask_delete.bind(_shown[n].name))
		row.add_child(delete)
		_deletes.append(delete)
		_rows.add_child(row)
	# What this tab deleted, newest first, each with Undo.
	for n: int in range(deleted.size() - 1, -1, -1):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var said := Label.new()
		said.text = "Deleted “%s”" % str(deleted[n]["name"])
		said.modulate.a = 0.7
		said.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(said)
		var undo := _row_button("Undo", "Put “%s” back" % str(deleted[n]["name"]))
		undo.pressed.connect(_undo.bind(n))
		row.add_child(undo)
		_undos.append(undo)
		_rows.add_child(row)


## A row's button, as Versions' Open is.
static func _row_button(words: String, tip: String) -> Button:
	var made := Button.new()
	made.text = words
	made.focus_mode = Control.FOCUS_NONE
	made.tooltip_text = tip
	return made


func _with_account() -> bool:
	return cloud != null and cloud._on()


func _ask_delete(name: String) -> void:
	_asked = name
	_confirm_delete.title = "Delete “%s”?" % name
	_confirm_delete.dialog_text = ("“%s” is deleted %s%s. Undo, here, puts it back." % [name,
		CloudModels.here(), " and from your account, so from every browser and computer you are signed in to"
		if _with_account() else ""])
	_confirm_delete.popup_centered()


func _delete(name: String) -> void:
	var kept: String = store.delete_saved(name)
	if kept.is_empty():
		say.call("could not delete “%s”" % name)
		fill()
		return
	deleted.append({"name": name, "kept": kept})
	while deleted.size() > ModelStore.OPENS_KEPT:
		deleted.pop_front()
	say.call("deleted “%s”" % name)
	fill()


func _undo(n: int) -> void:
	if n < 0 or n >= deleted.size():
		return
	var was: Dictionary = deleted[n]
	var back: String = store.put_back(str(was["kept"]))
	if back.is_empty():
		say.call("could not put “%s” back" % str(was["name"]))
		return
	deleted.remove_at(n)
	say.call("put back “%s”" % back if back == str(was["name"])
		else "put back “%s” as “%s”: a model has its name now" % [str(was["name"]), back])
	fill()


func _ask_rename(name: String) -> void:
	_asked = name
	_rename_words.text = "What should “%s” be called?" % name
	_rename_field.text = name
	_rename.popup_centered()
	_rename_field.grab_focus()
	_rename_field.select_all()


func _take_rename() -> void:
	var wanted: String = _rename_field.text.strip_edges()
	var why: String = store.rename_saved(_asked, wanted)
	if not why.is_empty():
		_rename_words.text = why
		return
	_rename.hide()
	if wanted != _asked:
		say.call("renamed “%s” “%s”" % [_asked, wanted])
	fill()


## What a browser check presses: each row's Rename and Delete, numbered from
## 1 as listed, and each deleted one's Undo, the newest first; and the
## questions' answers while one is asked.
func controls_by_name() -> Dictionary:
	var out: Dictionary = {}
	if _confirm_delete.visible:
		out["saved_delete_ok"] = _confirm_delete.get_ok_button()
		out["saved_delete_cancel"] = _confirm_delete.get_cancel_button()
	if _rename.visible:
		out["saved_rename_name"] = _rename_field
		out["saved_rename_ok"] = _rename.get_ok_button()
	if not visible:
		return out
	out["saved_close"] = get_ok_button()
	for n: int in _shown.size():
		out["saved_rename_%d" % (n + 1)] = _renames[n]
		out["saved_delete_%d" % (n + 1)] = _deletes[n]
	for n: int in _undos.size():
		out["saved_undo_%d" % (n + 1)] = _undos[n]
	return out


## What it says and lists, for a check.
func page_state() -> Dictionary:
	var rows: Array = []
	for entry: ModelStore.Entry in _shown:
		rows.append(entry.name)
	var gone: Array = []
	for one: Dictionary in deleted:
		gone.append(str(one["name"]))
	return {"open": visible, "note": _note.text if _note != null else "", "rows": rows,
		"deleted": gone, "asking": _rename_words.text if _rename != null and _rename.visible else ""}
