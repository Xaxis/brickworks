## File, Versions…: the last saves of the model on the baseplate, newest
## first, each to open in place of what is there (ModelVersions).
##
## A model is opened from here as File, Open opens one, under its own
## name, so Save makes the version opened the newest save again. Opening
## replaces what is on the baseplate and cannot be undone, so when that has
## changes not saved the dialog says so, with Save beside it.
##
## Each row's Compare draws the model on the baseplate against that save
## instead (CompareView), changing nothing; File, Compare with… opens the
## list with Compare alone.
class_name VersionsDialog
extends AcceptDialog

var store: ModelStore
var bar: ModelBar
## Compare the model on the baseplate with a save (CompareView.open_with).
var compare: Callable = func(_version: ModelVersions.Version) -> void: pass
## Opened by Compare with…: each row offers Compare alone.
var comparing: bool = false

var _note: Label
var _save: Button
var _rows: VBoxContainer
var _opens: Array[Button] = []
var _compares: Array[Button] = []
var _shown: Array[ModelVersions.Version] = []


func _ready() -> void:
	title = "Versions"
	ok_button_text = "Close"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(420, 0)
	add_child(column)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(420, 0)
	column.add_child(_note)
	_save = Button.new()
	_save.text = "Save it now"
	_save.focus_mode = Control.FOCUS_NONE
	_save.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_save.pressed.connect(func() -> void:
		await bar._on_save()
		fill())
	column.add_child(_save)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 4)
	scroll.add_child(_rows)


## Show the versions of the model on the baseplate; with [param to_compare],
## each to compare it with and none to open.
func open(to_compare: bool = false) -> void:
	comparing = to_compare
	title = "Compare with a save" if comparing else "Versions"
	fill()
	popup_centered()


## The rows again, for the model on the baseplate as it is now.
func fill() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	_opens.clear()
	_compares.clear()
	_shown = store.versions()
	var name: String = store.title
	if name == ModelStore.UNTITLED or store.example:
		_note.text = ("This model has not been saved. Each time it is saved, the save is kept "
			+ "here too: the last %d." % ModelVersions.KEPT)
	elif _shown.is_empty():
		_note.text = ("No saves of “%s” are kept yet. Each time it is saved, the save is kept "
			+ "here too: the last %d.") % [name, ModelVersions.KEPT]
	elif comparing:
		_note.text = ("The last %d saves of “%s”, newest first. Compare one with the model on "
			+ "the baseplate: what was added since is green, what was taken away red, what "
			+ "was moved or turned amber and what was recoloured violet. Nothing is changed.") \
			% [_shown.size(), name]
	else:
		_note.text = ("The last %d saves of “%s”, newest first. Open one to put it on the "
			+ "baseplate in place of what is there; Save then makes it the newest. Compare "
			+ "shows what changed since, changing nothing.") % [_shown.size(), name]
	# Comparing replaces nothing, so there is nothing to save first.
	var unsaved: bool = not comparing and not _shown.is_empty() and store.has_unsaved_work()
	if unsaved:
		_note.text += ("\n\nThe model on the baseplate has changes that are not saved, and "
			+ "opening a version replaces them. Save it first to keep them as a version.")
	_save.visible = unsaved
	for n: int in _shown.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var words := Label.new()
		words.text = _shown[n].describe() + ("  (the last save)" if n == 0 else "")
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Wrapped rather than pushing Compare and Open off the row.
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(words)
		var compare_it := Button.new()
		compare_it.text = "Compare"
		compare_it.focus_mode = Control.FOCUS_NONE
		compare_it.tooltip_text = ("Compare with this save: added green, removed red, moved or "
			+ "turned amber, recoloured violet")
		compare_it.pressed.connect(_compare_version.bind(n))
		row.add_child(compare_it)
		_compares.append(compare_it)
		if not comparing:
			var open_it := Button.new()
			open_it.text = "Open"
			open_it.focus_mode = Control.FOCUS_NONE
			open_it.tooltip_text = "Put this save of “%s” on the baseplate" % name
			open_it.pressed.connect(_open_version.bind(n))
			row.add_child(open_it)
			_opens.append(open_it)
		_rows.add_child(row)


func _open_version(n: int) -> void:
	if n < 0 or n >= _shown.size():
		return
	var version: ModelVersions.Version = _shown[n]
	hide()
	if not await bar.ask_to_replace("“%s” as saved %s" % [store.title, version.when()]):
		return
	# Said in the status bar either way, opened or not.
	await bar.open_version(version)


func _compare_version(n: int) -> void:
	if n < 0 or n >= _shown.size():
		return
	hide()
	compare.call(_shown[n])


## What a browser check presses: each row's Open and Compare, numbered from
## 1, newest first; and Save, when there are changes not saved.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"versions_close": get_ok_button()}
	for n: int in _opens.size():
		out["version_open_%d" % (n + 1)] = _opens[n]
	for n: int in _compares.size():
		out["version_compare_%d" % (n + 1)] = _compares[n]
	if _save.visible:
		out["versions_save"] = _save
	return out


## What it says and lists, for a probe.
func page_state() -> Dictionary:
	var rows: Array = []
	for version: ModelVersions.Version in _shown:
		rows.append({"parts": version.parts, "at": version.at})
	return {"open": visible, "note": _note.text if _note != null else "", "rows": rows,
		"comparing": comparing}
