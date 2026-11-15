## Missing and moved parts: as a person opens a model whose file names parts
## by a number LDraw has moved ("3023", now 3023b) or keeps as an alias of
## another, or has no file for, each is listed with why, the part it points
## to and how many it places in which sub-model (ModelStore.moved).
##
## The model is down already, as it always was: a moved part drawn as the
## part it moved to, an alias as itself, a missing one held and kept in the
## file. Keep as is leaves it so. Replace checked writes each checked number
## in the file as the part it points to, in the model and every sub-model,
## and lays it again (ModelStore.replace_moved): one undo puts back the file
## as it was. A part with no file has nothing to point to; Search looks for
## its number among the parts (StudWorx's Missing and Moved Parts, APP_UX8
## #15).
##
## Not modal: the model stays to be looked at, turned and searched while the
## list is up. Shown after a person's own open (File, Open; a file; Recent;
## the library), never after a session's, Together's or an undo's.
class_name MovedPartsDialog
extends ConfirmationDialog

var store: ModelStore
## Replace checked: the numbers, replaced as ModelBar.replace_moved does.
var replace: Callable = func(_numbers: Array) -> void: pass
## Search: the parts bin looking for a number (PartsBin.search_for).
var search: Callable = func(_number: String) -> void: pass

var _note: Label
var _rows: VBoxContainer
## number -> its CheckBox, for a moved or alias part.
var _checks: Dictionary = {}
## number -> its Search, for a part with no file.
var _searches: Dictionary = {}
## The world's generation the list is of: a list shown for one model is
## never applied to the next.
var _of_generation: int = -1


func _ready() -> void:
	title = "Missing and moved parts"
	ok_button_text = "Replace checked"
	cancel_button_text = "Keep as is"
	# The model stays to be looked at, and searched, while it is up.
	exclusive = false
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	column.custom_minimum_size = Vector2(460, 0)
	add_child(column)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(460, 0)
	column.add_child(_note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 260)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 6)
	scroll.add_child(_rows)
	confirmed.connect(_replace_checked)


## Show the list of the model on the baseplate, as its open found it.
func open() -> void:
	fill()
	if _checks.is_empty() and _searches.is_empty():
		return
	popup_centered()


## The rows again, for the model on the baseplate.
func fill() -> void:
	for child: Node in _rows.get_children():
		child.queue_free()
	_checks.clear()
	_searches.clear()
	_of_generation = store.world.generation() if store != null and store.world != null else -1
	var listed: Dictionary = store.moved if store != null else {}
	var renumbered: int = 0
	var absent: int = 0
	# Moved and alias first, then those with no file, each by its number.
	var numbers: Array = listed.keys()
	numbers.sort_custom(func(a: String, b: String) -> bool:
		var a_missing: bool = str(listed[a]["kind"]) == MovedParts.MISSING
		var b_missing: bool = str(listed[b]["kind"]) == MovedParts.MISSING
		return a < b if a_missing == b_missing else b_missing)
	for number: String in numbers:
		var row: Dictionary = listed[number]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		var words := Label.new()
		words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.text = row_words(row)
		if str(row["kind"]) == MovedParts.MISSING:
			absent += 1
			var named := Label.new()
			named.text = number
			named.custom_minimum_size = Vector2(110, 0)
			line.add_child(named)
			line.add_child(words)
			var look := Button.new()
			look.text = "Search"
			look.focus_mode = Control.FOCUS_NONE
			look.tooltip_text = "Look for %s among the parts" % number
			look.pressed.connect(_search_for.bind(number))
			line.add_child(look)
			_searches[number] = look
		else:
			renumbered += 1
			var check := CheckBox.new()
			check.text = number
			check.button_pressed = true
			check.custom_minimum_size = Vector2(110, 0)
			check.toggled.connect(func(_on: bool) -> void: _fit_buttons())
			line.add_child(check)
			line.add_child(words)
			_checks[number] = check
		_rows.add_child(line)
	_note.text = note_words(renumbered, absent)
	_fit_buttons()


## What a row says after its number (MovedParts.row_words).
static func row_words(row: Dictionary) -> String:
	return "%s · %s" % [MovedParts.why_words(row), MovedParts.used_words(row)]


## What the list says above its rows.
static func note_words(renumbered: int, absent: int) -> String:
	var said := PackedStringArray()
	if renumbered > 0:
		said.append(("This file names 1 part by a number LDraw has moved or made an alias. "
			if renumbered == 1 else "This file names %d parts by numbers LDraw has moved or made aliases. "
			% renumbered)
			+ "Each is drawn as the part it points to. Replace checked writes that part's number "
			+ "in the file, in every sub-model, in one undo.")
	if absent > 0:
		said.append("1 part has no file in the library: it is kept in the file, not shown."
			if absent == 1 else "%d parts have no file in the library: they are kept in the file, not shown."
			% absent)
	said.append("Keep as is leaves the file as it is.")
	return " ".join(said)


## The numbers checked.
func checked() -> Array:
	var out: Array = []
	for number: String in _checks:
		if (_checks[number] as CheckBox).button_pressed:
			out.append(number)
	return out


## Replace checked only with something checked; Keep as is always.
func _fit_buttons() -> void:
	get_ok_button().visible = not _checks.is_empty()
	get_ok_button().disabled = checked().is_empty()


func _replace_checked() -> void:
	var numbers: Array = checked()
	hide()
	# Another model opened meanwhile: this list is not of it.
	if numbers.is_empty() or store == null or store.world == null \
			or store.world.generation() != _of_generation:
		return
	replace.call(numbers)


func _search_for(number: String) -> void:
	hide()
	search.call(number)


## What a browser check presses: Replace checked, Keep as is, and each
## row's check box and Search by its number.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var out: Dictionary = {"moved_replace": get_ok_button(), "moved_keep": get_cancel_button()}
	for number: String in _checks:
		out["moved_check_" + number] = _checks[number]
	for number: String in _searches:
		out["moved_search_" + number] = _searches[number]
	return out


## What it says and lists, for a probe.
func page_state() -> Dictionary:
	var rows: Dictionary = {}
	for line: Node in _rows.get_children():
		if line.is_queued_for_deletion():
			continue
		var first: Control = line.get_child(0)
		var number: String = (first as CheckBox).text if first is CheckBox else (first as Label).text
		rows[number] = {"checked": (first as CheckBox).button_pressed if first is CheckBox else false,
			"words": (line.get_child(1) as Label).text}
	return {"open": visible, "note": _note.text if _note != null else "", "rows": rows}
