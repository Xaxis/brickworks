## The model tree: every sub-assembly by name, inside the ones it is in,
## with how many parts it has and whether it is hidden or locked.
##
## Studio and LDCad both have this, and it is how a model built as a kit
## is found again: "Bag 3", the left wing, the engine. A row selects its
## parts in the view; a double-click edits inside it; its name can be
## typed over; dragging a row onto another puts it inside that one, and
## onto the model puts it back at the top. The eye and the lock on each
## row hide and lock it whole.
##
## Sections suggested (SectionsUi, Suggest sections) are listed under the
## model's own rows, numbered in the order they would be built, with what
## to do with them under the tree: accept one or all (each a sub-assembly,
## one undo), rename (a double-click or F2), merge (drag one onto another,
## or Merge), split, evaluate, break out and the exploded view.
class_name Outliner
extends PanelContainer

const WIDE := 240.0
const TOOLS := "res://assets/ui/tools/"
## Button ids on a row.
const EYE := 0
const LOCK := 1
const ACCEPT := 2
## A suggestion's row and the row over them: never an assembly's path,
## which cannot hold "#" at the start of a name.
const SUGGESTED := "#suggested"
const SUGGESTION := "#suggestion:"

var shell: Shell
var assemblies: Assemblies
## Sections (SectionsUi), once the shell has made them (Shell.sections):
## null until something asks for one, and the buttons say what they would do.
var sections: Node = null

var _open: bool = true
var _header: Button
var _count: Label
var _arrow: Inspector.Arrow
var _tree: Tree
var _shown: String = ""
var _looked_at: int = 0
var _icons: Dictionary = {}
## A row being renamed holds its path here, so a refresh mid-edit does
## not throw the typing away.
var _renaming: bool = false

signal toggled(open: bool)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", PanelStack.section_style())

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var head := HBoxContainer.new()
	column.add_child(head)
	_header = Button.new()
	_header.flat = true
	_header.text = "Model tree"
	_header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_header.focus_mode = Control.FOCUS_NONE
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_theme_font_size_override("font_size", 13)
	_header.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_header.tooltip_text = "The model's sub-assemblies. Fold this away, or open it"
	_header.pressed.connect(func() -> void: set_open(not _open))
	head.add_child(_header)
	_count = Label.new()
	_count.add_theme_font_size_override("font_size", 12)
	_count.modulate = Color(1, 1, 1, 0.6)
	head.add_child(_count)
	# Which way it is folded, as the properties under it say theirs.
	_arrow = Inspector.Arrow.new()
	_arrow.custom_minimum_size = Vector2(14, 14)
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_arrow)

	_tree = Tree.new()
	_tree.accessibility_name = "Model tree"
	_tree.hide_root = false
	_tree.columns = 2
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 54)
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_rmb_select = true
	_tree.focus_mode = Control.FOCUS_CLICK
	# A key pressed with a row chosen is the window's (Y breaks the section
	# out, F fits it), not a search of the rows by their first letters.
	_tree.allow_search = false
	# As tall as the column gives it (PanelStack), and never less than
	# a few rows.
	_tree.custom_minimum_size = Vector2(WIDE - 16.0, 60)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.add_theme_font_size_override("font_size", 12)
	_tree.add_theme_constant_override("button_margin", 2)
	_tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM
	# A carry scrolls the tree at its edges by _edge_scroll, not Godot's.
	_tree.add_theme_constant_override("scroll_speed", 0)
	_tree.item_selected.connect(_on_selected)
	_tree.item_activated.connect(_on_activated)
	_tree.item_edited.connect(_on_edited)
	_tree.button_clicked.connect(_on_button)
	_tree.set_drag_forwarding(_drag_data, _can_drop, _drop)
	column.add_child(_tree)

	# A row's drag begins from the press that chose it (_carry_input), a
	# finger's from its move as the window hears it (_heard).
	_tree.gui_input.connect(_carry_input)
	get_window().window_input.connect(_heard)
	# A name typed over ends in item_edited; Esc ends it with nothing said,
	# and the tree then stood as it was (refreshes held for the typing)
	# until the next rename. Its editor going is heard as well.
	for child: Node in _tree.get_children(true):
		if child is Popup and not child is PopupMenu:
			(child as Popup).popup_hide.connect(_rename_ended, CONNECT_DEFERRED)

	var hint := Label.new()
	_hint = hint
	# A finger lifts a row by holding it first (_carry_input).
	hint.text = "Double-tap to edit inside; hold one, then drag it onto another to nest" \
		if DisplayServer.is_touchscreen_available() \
		else "Double-click to edit inside; drag onto another to nest"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDE - 16.0, 0)
	column.add_child(hint)
	_strip = HFlowContainer.new()
	_strip.add_theme_constant_override("h_separation", 4)
	_strip.add_theme_constant_override("v_separation", 4)
	_strip.custom_minimum_size = Vector2(WIDE - 16.0, 0)
	column.add_child(_strip)
	for row: Array in STRIP:
		var button := Button.new()
		button.text = str(row[1])
		button.name = str(row[0])
		Keymap.tell(button, str(row[2]))
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 11)
		var id: String = row[0]
		button.pressed.connect(func() -> void: _strip_pressed(id))
		_strip.add_child(button)
		_buttons[id] = button

	var density: float = Icons.density(self)
	for name: String in ["show_all", "hide", "lock", "unlock", "accept"]:
		var path: String = TOOLS + name + ".svg"
		if FileAccess.file_exists(path):
			_icons[name] = Icons.icon_for(path, 14.0, density)
	assemblies.changed.connect(func() -> void: _refresh(true))
	assemblies.entered_changed.connect(func(_path: String) -> void: _refresh(true))
	shell.world.rebuilt.connect(func(_b: int, _c: int, _t: int) -> void: _refresh(false))
	shell.builder.selection_changed.connect(func(_n: int) -> void: _mark_selected())
	_refresh(true)


## The buttons under the tree: name, words, tooltip.
const STRIP: Array = [
	["sections_suggest", "Suggest sections",
		"How a builder would split the model into sections, as a set into bags"],
	["sections_accept_all", "Accept all", "Make every suggested section a sub-assembly: one undo"],
	["sections_accept", "Accept", "Make the chosen suggestion a sub-assembly"],
	["sections_merge", "Merge",
		"Put the chosen suggestion in with the one it is joined to most (or drag it onto another)"],
	["sections_split", "Split", "Part the chosen suggestion in two where it is held least"],
	["sections_dismiss", "Dismiss", "Put the suggestions away"],
	["sections_evaluate", "Evaluate…",
		"The chosen section on its own: parts, weight, whether it holds together and stands, what joins it, its steps"],
	["sections_break_out", "Break out",
		"Pull the chosen section away from the model to work on it ({break_out}); again puts it back"],
	["sections_explode", "Exploded view", "Every section apart, and back together ({explode})"],
]

## The tree's state but for the suggestion, when it was last drawn.
var _shown_base: String = ""
## What the tree was last worked out from (_refresh).
var _made_from: Array = []
var _strip: HFlowContainer
var _buttons: Dictionary = {}
var _hint: Label


## Which suggestion's row is chosen, or 0.
func _chosen_suggestion() -> int:
	var row: TreeItem = _tree.get_selected() if _tree != null else null
	if row == null:
		return 0
	var meta: String = str(row.get_metadata(0))
	return meta.trim_prefix(SUGGESTION).to_int() if meta.begins_with(SUGGESTION) else 0


func _strip_pressed(id: String) -> void:
	# Made now if it was not (Shell.sections), and told to this tree.
	if shell.sections == null:
		return
	var number: int = _chosen_suggestion()
	match id:
		"sections_suggest":
			await sections.suggest()
		"sections_accept_all":
			sections.accept()
		"sections_accept":
			if number > 0:
				sections.accept([number])
		"sections_merge":
			if number > 0:
				shell.bar.say(sections.sections.merge(number))
		"sections_split":
			if number > 0:
				shell.bar.say(sections.sections.split(number))
		"sections_dismiss":
			sections.sections.dismiss()
		"sections_evaluate":
			await sections.show_evaluation("", number)
		"sections_break_out":
			sections.break_out_or_back()
		"sections_explode":
			sections.toggle_explode()
	_update_strip()


## The buttons that would do something now.
func _update_strip() -> void:
	if _strip == null:
		return
	var suggested: bool = sections != null and not sections.sections.suggested.is_empty()
	var number: int = _chosen_suggestion()
	var target: bool = not shell.section_target().is_empty()
	var out_any: bool = not shell.world.broken_out.is_empty()
	# Only what would do something now, so the row fits under the tree.
	var shown: Dictionary = {
		"sections_suggest": not suggested,
		"sections_accept_all": suggested,
		"sections_accept": number > 0,
		"sections_merge": number > 0,
		"sections_split": number > 0,
		"sections_dismiss": suggested,
		"sections_evaluate": number > 0 or target,
		"sections_break_out": not suggested and (target or out_any),
		"sections_explode": number == 0,
	}
	for id: String in _buttons:
		(_buttons[id] as Button).visible = bool(shown.get(id, true))
	if _hint != null:
		_hint.visible = _open and not suggested
	(_buttons["sections_accept"] as Button).disabled = number == 0
	(_buttons["sections_merge"] as Button).disabled = number == 0
	(_buttons["sections_split"] as Button).disabled = number == 0
	(_buttons["sections_evaluate"] as Button).disabled = number == 0 and not target
	var out: bool = not shell.world.broken_out.is_empty()
	var this_out: bool = target and sections != null \
		and not sections.sections.out_record(shell.section_target()).is_empty()
	(_buttons["sections_break_out"] as Button).text = "Put back" if this_out \
		or (not target and out) else "Break out"
	(_buttons["sections_break_out"] as Button).disabled = not target and not out
	(_buttons["sections_explode"] as Button).text = "Together" \
		if sections != null and sections.is_exploded() else "Exploded view"


func is_open() -> bool:
	return _open


## [param made] the shell's sections, made now: its suggestions shown here.
func use_sections(made: Node) -> void:
	sections = made
	sections.sections.suggested_changed.connect(func() -> void: _refresh(true))
	_update_strip()


func set_open(open: bool) -> void:
	_open = open
	if _tree != null:
		_tree.visible = open
		for child: Node in _tree.get_parent().get_children():
			if child is Label:
				(child as Label).visible = open
		if _strip != null:
			_strip.visible = open
		_arrow.down = open
		_arrow.queue_redraw()
	ShellPrefs.put("outliner_open", open)
	toggled.emit(open)
	# Folded, the tree was not kept up to date.
	_refresh(true)


func _process(delta: float) -> void:
	if _pressed and _press_finger and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_press_hold.saw()
	if get_viewport().gui_is_dragging() and _tree.is_visible_in_tree():
		_edge_scroll(delta)
	var now: int = Time.get_ticks_msec()
	if now - _looked_at < 500:
		return
	_looked_at = now
	_refresh(false)


## The tree drawn again when its shape, names, counts or toggles changed.
##
## Folded away, as it starts, or off the screen, only the count on its
## header is said, and the tree is worked out when it is opened. It was
## worked out twice a second and at every change to the world whether it
## was open or not: on Orthanc 30 to 40 ms each time on a desktop and a
## browser's frame of a few hundred, the Timeline's first step among them.
##
## And neither is worked out again until what it is made from has changed.
## The header's count is the counts line's, counted once a change; the
## open tree waits on the model, its history, what is hidden and locked.
## Worked out afresh at every redraw and twice a second, the count was 15
## to 60 ms of every move of the cut on Orthanc, and the open tree 26 to 37
## (seeinside, 2026-10-31).
func _refresh(now: bool) -> void:
	if _tree == null or _renaming:
		return
	if sections != null:
		sections.sections.forget_if_stale()
	var builder: Builder = shell.builder
	if not _open or not is_visible_in_tree():
		var total: int = Inventory.pieces_of_model(shell.world, shell.library,
			assemblies.scenery, builder.history_depth())
		_count.text = "%d part%s" % [total, "" if total == 1 else "s"]
		_shown = ""
		_shown_base = ""
		_made_from = []
		return
	# Each hide, show, lock or unlock adds or takes away, so the counts say
	# one happened; a sub-assembly made, renamed or taken apart is a step
	# of the history, and says so itself (Assemblies.changed).
	var made_from: Array = [shell.world.revision, builder.history_depth(),
		builder.lattice.unseen.size(), builder.locked.size(), assemblies.scenery.size(),
		assemblies.entered, shell.world.broken_out.size(), builder.selection.size(),
		_suggested_state()]
	if made_from == _made_from and not now:
		return
	_made_from = made_from
	var root: Assemblies.Item = assemblies.tree()
	var base: String = _state_of(root) + "|" + assemblies.entered \
		+ "|" + str(shell.world.broken_out.size()) + "|" + str(shell.builder.selection.size())
	var state: String = base + "|" + _suggested_state()
	if state == _shown and not now:
		return
	var folded: Dictionary = {}
	var item: TreeItem = _tree.get_root()
	if item != null:
		_collect_folded(item, folded)
	# Only the suggestion changed: its rows made again, not the model's. On
	# 10179-1's 392 sub-assemblies the whole tree was 62 ms of one frame.
	if base == _shown_base and item != null:
		var old: TreeItem = _find(item, SUGGESTED)
		if old != null:
			old.free()
		_shown = state
		_fill_suggested(item, folded)
		_mark_selected()
		_update_strip()
		return
	_shown = state
	_shown_base = base
	_count.text = "%d part%s" % [root.total, "" if root.total == 1 else "s"]
	_tree.clear()
	var top: TreeItem = _tree.create_item()
	_fill(top, root, folded)
	_fill_suggested(top, folded)
	_mark_selected()
	_update_strip()


func _count_rows(item: TreeItem) -> int:
	var count: int = 1
	if not item.collapsed:
		for child: TreeItem in item.get_children():
			count += _count_rows(child)
	return count


func _suggested_state() -> String:
	if sections == null:
		return ""
	var bits := PackedStringArray()
	for made: RefCounted in sections.sections.suggested:
		bits.append("%d:%s:%d" % [made.number, made.name, made.ids.size()])
	return ",".join(bits)


## The suggested sections, under the model's own rows: numbered as they
## would be built, each with its part count and a tick to accept it.
func _fill_suggested(top: TreeItem, folded: Dictionary) -> void:
	# Room for a few of them whatever the properties under it take: with a
	# suggestion's parts selected, the tree was squeezed to one row.
	var rows: int = _count_rows(top) + (0 if sections == null
		else sections.sections.suggested.size() + 1)
	_tree.custom_minimum_size.y = clampf(rows * 24.0, 60.0, 120.0)
	if sections == null or sections.sections.suggested.is_empty():
		return
	var head: TreeItem = _tree.create_item(top)
	var list: Array = sections.sections.suggested
	head.set_text(0, "Suggested sections (%d)" % list.size())
	head.set_metadata(0, SUGGESTED)
	head.set_tooltip_text(0, "How a builder would split it, in the order they are built. "
		+ "Accept makes each a sub-assembly; drag one onto another to merge them")
	head.set_custom_color(0, Color(0.55, 0.78, 1.0))
	head.collapsed = folded.has(SUGGESTED)
	for made: RefCounted in list:
		var row: TreeItem = _tree.create_item(head)
		row.set_text(0, "%d. %s" % [made.number, made.name])
		row.set_metadata(0, SUGGESTION + str(made.number))
		row.set_tooltip_text(0, made.said() + ". Click to select it, double-click to rename it")
		row.set_text(1, str(made.ids.size()))
		row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
		row.set_custom_color(1, Color(1, 1, 1, 0.55))
		row.set_custom_color(0, Color(0.75, 0.87, 1.0))
		var tick: Texture2D = _icons.get("accept")
		if tick != null:
			row.add_button(1, tick, ACCEPT, false, "Accept it: make it a sub-assembly")


func _state_of(node: Assemblies.Item) -> String:
	var parts := PackedStringArray(["%s:%d:%d:%d:%d" % [node.path, node.total, node.parts,
		node.hidden, node.locked]])
	for child: Assemblies.Item in node.children:
		parts.append(_state_of(child))
	return ",".join(parts)


func _collect_folded(item: TreeItem, into: Dictionary) -> void:
	if item.collapsed:
		into[str(item.get_metadata(0))] = true
	for child: TreeItem in item.get_children():
		_collect_folded(child, into)


func _fill(row: TreeItem, node: Assemblies.Item, folded: Dictionary) -> void:
	var is_root: bool = node.path.is_empty()
	var words: String = "Model" if is_root else Assemblies.label(node.path)
	if not is_root:
		# A sub-model's name is its builder's, drawn as it is in any
		# language: a sub-model named Car stays Car (Language), here and
		# where a status line names it.
		row.set_auto_translate_mode(0, Node.AUTO_TRANSLATE_MODE_DISABLED)
		Language.keep_name(words)
		if node.path == assemblies.entered:
			words += "  " + atr("(editing)")
	row.set_text(0, words)
	row.set_metadata(0, node.path)
	row.set_tooltip_text(0, ("The whole model: %d parts, %d loose" % [node.total, node.parts])
		if is_root else "%s: %d parts. Click to select it, double-click to edit inside it, "
		% [Assemblies.label(node.path), node.total] + "click the name again to rename it")
	row.set_text(1, str(node.total))
	row.set_text_alignment(1, HORIZONTAL_ALIGNMENT_RIGHT)
	row.set_custom_color(1, Color(1, 1, 1, 0.55))
	if not is_root:
		row.set_editable(0, false)
		var hidden: bool = node.hidden == node.total and node.total > 0
		var locked: bool = node.locked == node.total and node.total > 0
		var eye: Texture2D = _icons.get("hide" if hidden else "show_all")
		if eye != null:
			row.add_button(1, eye, EYE, false, "Show it" if hidden else "Hide it")
		var lock: Texture2D = _icons.get("lock")
		if lock != null:
			row.add_button(1, lock, LOCK, false, "Unlock it" if locked else "Lock it")
			row.set_button_color(1, row.get_button_count(1) - 1,
				Color(1, 1, 1, 1.0 if locked else 0.35))
		if hidden:
			row.set_custom_color(0, Color(1, 1, 1, 0.45))
	if node.path == assemblies.entered and not is_root:
		row.set_custom_bg_color(0, Color(0.36, 0.6, 1.0, 0.18))
	row.collapsed = folded.has(node.path)
	for child: Assemblies.Item in node.children:
		_fill(_tree.create_item(row), child, folded)


## The rows of what is selected, lit: an assembly whose parts are all in
## the selection.
func _mark_selected() -> void:
	if _tree == null or _tree.get_root() == null:
		return
	var chosen: String = assemblies.selected_assembly()
	var row: TreeItem = _find(_tree.get_root(), chosen) if not chosen.is_empty() else null
	# A suggestion whose parts are what is selected stays chosen, so its
	# Merge, Split and Evaluate stay under the tree.
	if row == null and sections != null:
		var picked: Dictionary = shell.builder.selection
		for made: RefCounted in sections.sections.suggested:
			if made.ids.size() != picked.size() or picked.is_empty():
				continue
			if Array(made.ids).all(func(id: int) -> bool: return picked.has(id)):
				row = _find(_tree.get_root(), SUGGESTION + str(made.number))
				break
	# The row chosen already is left as it is: chosen again, the tree puts
	# away the name being typed into it. A double-click on a row not yet
	# chosen opened its name on the second press, and this, run after the
	# first press's selection, closed it: in a browser both presses come in
	# one frame (sections on the web, uifix).
	if row != null and row == _tree.get_selected() and row.is_selected(0):
		_update_strip()
		return
	# Lit to match the view, which is not a person choosing the row: the
	# row's own handler would select again, and round it went.
	_marking = true
	_tree.deselect_all()
	if row != null:
		row.select(0)
		_tree.scroll_to_item(row)
	_marking = false
	_update_strip()


func _find(item: TreeItem, path: String) -> TreeItem:
	if str(item.get_metadata(0)) == path:
		return item
	for child: TreeItem in item.get_children():
		var found: TreeItem = _find(child, path)
		if found != null:
			return found
	return null


var _marking: bool = false


func _on_selected() -> void:
	if _marking:
		return
	var row: TreeItem = _tree.get_selected()
	if row == null:
		return
	var path: String = str(row.get_metadata(0))
	if path.is_empty() or path == SUGGESTED:
		_update_strip()
		return
	# After the tree's own signal returns: choosing a row in another level
	# enters it, which draws the tree again, and the tree was still walking
	# the rows that freed (assembly_probe crashed on it, 2026-10-30).
	if path.begins_with(SUGGESTION):
		_select_suggestion.call_deferred(path.trim_prefix(SUGGESTION).to_int())
		_update_strip.call_deferred()
		return
	_choose.call_deferred(path)


## A row's parts selected.
func _choose(path: String) -> void:
	# To the level where this row is one thing to click: the assembly it
	# is in, entered (or the model, for a row at the top).
	if Assemblies.parent_of(path) != assemblies.entered:
		assemblies.enter(Assemblies.parent_of(path))
	var builder: Builder = shell.builder
	builder.selection.clear()
	for brick_id: int in assemblies.ids_under(path):
		if not builder.lattice.unseen.has(brick_id):
			builder.selection[brick_id] = true
	builder.selection_changed.emit(builder.selection.size())


func _select_suggestion(number: int) -> void:
	var builder: Builder = shell.builder
	for made: RefCounted in sections.sections.suggested:
		if made.number != number:
			continue
		if not assemblies.entered.is_empty() and not Assemblies.within(made.level,
				assemblies.entered):
			assemblies.enter("")
		builder.selection.clear()
		for brick_id: int in made.ids:
			if not builder.lattice.unseen.has(brick_id):
				builder.selection[brick_id] = true
		builder.selection_changed.emit(builder.selection.size())
		shell.bar.say(made.said())


## Double-click: edit inside it. On the model's row: back to the top. On a
## suggestion: rename it.
func _on_activated() -> void:
	var row: TreeItem = _tree.get_selected()
	if row == null:
		return
	var path: String = str(row.get_metadata(0))
	if path == SUGGESTED:
		return
	if path.begins_with(SUGGESTION):
		rename_selected()
		return
	if path.is_empty():
		assemblies.enter("")
	else:
		assemblies.enter(path)
	shell.bar.say("editing %s — Esc leaves" % Assemblies.label(path) if not path.is_empty()
		else "editing the model")


## The name typed over: the definition renamed in every copy.
func _on_edited() -> void:
	var row: TreeItem = _tree.get_edited()
	_renaming = false
	if row == null:
		return
	var path: String = str(row.get_metadata(0))
	var typed: String = row.get_text(0).strip_edges()
	if path.begins_with(SUGGESTION):
		var called: String = sections.sections.rename(path.trim_prefix(SUGGESTION).to_int(), typed)
		shell.bar.say("it will be called %s" % called if not called.is_empty() else "")
		_refresh(true)
		return
	var name: String = assemblies.rename(path, typed)
	shell.verbs.edited.call()
	shell.bar.say("called %s" % name)
	_refresh(true)


## The name's editor put away: by Enter, after item_edited has drawn the
## tree again; by Esc, with the row as it was.
func _rename_ended() -> void:
	if _renaming:
		_renaming = false
		# Every row made again: the one typed in shows its name as typed.
		_shown_base = ""
		_refresh(true)


## Rename the selected row in place, as a second click on it does.
func rename_selected() -> void:
	var row: TreeItem = _tree.get_selected()
	if row == null or str(row.get_metadata(0)).is_empty() or str(row.get_metadata(0)) == SUGGESTED:
		return
	_renaming = true
	var meta: String = str(row.get_metadata(0))
	if meta.begins_with(SUGGESTION):
		var number: int = meta.trim_prefix(SUGGESTION).to_int()
		for made: RefCounted in sections.sections.suggested:
			if made.number == number:
				row.set_text(0, made.name)
	else:
		row.set_text(0, Assemblies.definition(Assemblies.leaf(meta)))
	row.set_editable(0, true)
	_tree.edit_selected(true)


func _gui_input(event: InputEvent) -> void:
	# F2 renames, as it does in every file manager.
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_F2:
		rename_selected()
		accept_event()


func _on_button(row: TreeItem, _column: int, id: int, _mouse: int) -> void:
	var path: String = str(row.get_metadata(0))
	if id == ACCEPT and path.begins_with(SUGGESTION):
		sections.accept([path.trim_prefix(SUGGESTION).to_int()])
		return
	var ids: PackedInt64Array = assemblies.ids_under(path)
	var builder: Builder = shell.builder
	match id:
		EYE:
			var hidden: bool = ids.size() > 0 and Array(ids).all(func(b: int) -> bool:
				return builder.lattice.unseen.has(b))
			for brick_id: int in ids:
				if hidden:
					builder.lattice.unseen.erase(brick_id)
				else:
					builder.lattice.unseen[brick_id] = true
			shell.verbs.apply_hidden()
		LOCK:
			var locked: bool = ids.size() > 0 and Array(ids).all(func(b: int) -> bool:
				return builder.is_locked(b))
			for brick_id: int in ids:
				if locked:
					builder.locked.erase(brick_id)
				else:
					builder.locked[brick_id] = true
			builder.clear_selection()
	_refresh(true)


func _drag_data(at: Vector2) -> Variant:
	# The engine's own drag, once the pointer has moved by its relative
	# motion: the row the mouse's press chose, which [param at] (where the
	# press was) may no longer be over (_carry_input, which begins it when
	# that motion is not said). A finger's press is the tree's scroll until
	# it has been held, and AccessKit's drag has no place (an infinite one).
	if not at.is_finite() or not _pressed or _press_finger:
		return null
	_pressed = false
	var lifted: Array = _lift()
	if lifted.is_empty():
		return null
	_tree.set_drag_preview(lifted[1])
	return lifted[0]


func _can_drop(at: Vector2, data: Variant) -> bool:
	if not shell.why_frozen().is_empty():
		return false
	if data is Dictionary and (data as Dictionary).has("suggestion"):
		var onto: TreeItem = _tree.get_item_at_position(at)
		return onto != null and str(onto.get_metadata(0)).begins_with(SUGGESTION) \
			and str(onto.get_metadata(0)).trim_prefix(SUGGESTION).to_int() \
				!= int((data as Dictionary)["suggestion"])
	if not (data is Dictionary) or not (data as Dictionary).has("assembly"):
		return false
	var row: TreeItem = _tree.get_item_at_position(at)
	if row == null:
		return false
	var into: String = str(row.get_metadata(0))
	var path: String = str((data as Dictionary)["assembly"])
	return not Assemblies.within(into, path) and Assemblies.parent_of(path) != into


func _drop(at: Vector2, data: Variant) -> void:
	var row: TreeItem = _tree.get_item_at_position(at)
	# Asked again: the model may have become one to look at, or begun
	# opening another, since the drop was last asked about.
	if row == null or not _can_drop(at, data):
		return
	var into: String = str(row.get_metadata(0))
	if (data as Dictionary).has("suggestion"):
		shell.bar.say(sections.sections.merge(int((data as Dictionary)["suggestion"]),
			into.trim_prefix(SUGGESTION).to_int()))
		return
	var moved: String = assemblies.move_into(str((data as Dictionary)["assembly"]), into)
	shell.verbs.edited.call()
	shell.bar.say("%s is in %s now" % [Assemblies.label(moved),
		"the model" if into.is_empty() else Assemblies.label(into)])
	_refresh(true)


# -- a row's drag ---------------------------------------------------------------


## A row carried onto another puts it inside that one (onto the model's, at
## the top), a suggestion onto another merges them: begun here, from the row
## the press was on. The engine begins a drag where the press was once the
## pointer has moved, and that place had changed under it: the press chose
## the row, choosing it filled Properties under the tree, and the tree shrank
## from the column's height to its least and scrolled to the row (657 to 120
## px on 7140-1), so the place pressed was under another row or off the tree,
## and every row's drag carried nothing (treedrag, 2026-11-11). It never
## started for a row not already chosen, which is the one a person drags.
##
## The mouse carries it once past the window's drag threshold, as anything
## in the window is dragged. A finger holds it still first, as long as a
## finger's hold on a part, and then moves: a row is lifted from a phone's
## list so (iOS's and Android's lists alike), because a finger that moves at
## once is scrolling the list, in any direction, and one held and lifted
## where it was has the row's own (its menu). As on iOS, a held finger that
## then moves lifts the row even where its hold has put up the row's menu:
## the window hears the finger first (_heard), because a menu, put up in the
## window, takes all of the window's input after it.
var _pressed: bool = false
var _press_meta: String = ""
## Where the press came down, in the window.
var _press_at := Vector2.ZERO
var _press_finger: bool = false
## The touch the finger's press is, once the window has heard it; -1 before.
var _press_index: int = -1
## How long the finger has been held still, by what the frames saw: on a
## page drawing a frame a second, a swipe's down and move come a frame
## apart and timed by the clock would read as a hold (PressHold).
const PressHold := preload("res://src/ui/press_hold.gd")
var _press_hold := PressHold.new()


func _carry_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.button_index == MOUSE_BUTTON_LEFT:
		_pressed = false
		if not click.pressed or click.double_click:
			return
		var row: TreeItem = _tree.get_item_at_position(click.position)
		if row == null or _carried(str(row.get_metadata(0))) == null \
				or _tree.get_button_id_at_position(click.position) >= 0:
			return
		_pressed = true
		_press_meta = str(row.get_metadata(0))
		_press_at = _tree.get_global_transform_with_canvas() * click.position
		_press_finger = click.device == InputEvent.DEVICE_ID_EMULATION
		_press_index = -1
		_press_hold.start()
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion == null:
		return
	if get_viewport().gui_is_dragging():
		# Where it would land, before the tree draws the row under it: an
		# outline on a row it may go into, none where it may not.
		_tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM \
			if _can_drop(motion.position, get_viewport().gui_get_drag_data()) else Tree.DROP_MODE_DISABLED
		return
	if not _pressed or _press_finger or motion.button_mask & MOUSE_BUTTON_MASK_LEFT == 0:
		return
	var moved: float = _press_at.distance_to(_tree.get_global_transform_with_canvas() * motion.position)
	if moved <= float(get_viewport().gui_drag_threshold):
		return
	_pressed = false
	_carry()


## A finger pressed on a row, as the window hears it, before anything in it:
## moved past a tap's slop, it lifts the row if it was held long enough and
## is the tree's scroll if not; lifted, or joined by a second (a pinch), it
## carries nothing.
func _heard(event: InputEvent) -> void:
	if _following >= 0 and _follow(event):
		return
	if not _pressed or not _press_finger:
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		# The window hears the press after the click made of it (Input
		# sends the emulated click first), so the press is the first touch.
		if touch.pressed and _press_index < 0:
			_press_index = touch.index
		elif touch.index != _press_index or not touch.pressed:
			_pressed = false
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null or drag.index != _press_index:
		return
	var at: Vector2 = get_window().get_final_transform().affine_inverse() * drag.position
	if _press_at.distance_to(at) <= CadCamera.TAP_SLOP:
		return
	_pressed = false
	if _press_hold.held_ms() >= FlingScroll.HOLD_MS:
		_carry()


## What a row carries: its assembly, a suggestion's number, or null for one
## that is not carried (the model's row, the suggestions' heading).
func _carried(meta: String) -> Variant:
	if meta.is_empty() or meta == SUGGESTED:
		return null
	if meta.begins_with(SUGGESTION):
		return {"suggestion": meta.trim_prefix(SUGGESTION).to_int()}
	return {"assembly": meta}


func _carry() -> void:
	var lifted: Array = _lift()
	if lifted.is_empty():
		return
	# A menu of the tree's own that the hold put up (the row's) goes as the
	# row lifts, as iOS's context menu does: put up in the window, it would
	# take every move of the carry.
	for child: Node in get_children():
		if child is Popup and (child as Popup).visible:
			(child as Popup).hide()
	if _press_finger and DisplayServer.is_touchscreen_available():
		# A finger on a touch screen's tree is its scroll, and Godot's Tree
		# takes no drop while that lasts (drag_touching); it ends when the
		# tree is hidden, so it is, for no frame at all.
		var focused: bool = _tree.has_focus()
		_tree.hide()
		_tree.show()
		if focused:
			_tree.grab_focus()
	_tree.force_drag(lifted[0], lifted[1])
	_following = _press_index if _press_finger else -1


## The finger a carry it lifted follows, -1 for none. Godot carries a drag
## by the mouse it makes of a finger (emulate_mouse_from_touch), and lets
## that mouse go, with the finger still down, when a menu put up in the
## window goes: the row's menu a hold put up, put away as the row lifts
## (_carry). The mouse let go is never pressed again and moves no more, so
## the carry stood still at the row it left and the finger's lift dropped
## nothing (treedrag on subexport, 2026-11-11). While it is let go, the
## finger's moves and its lift are given to the window as the mouse's.
var _following: int = -1


## [param event] given as the mouse's while Godot's is let go, the carry's
## (true), or not the carry's: the carry has ended, or it is another touch.
func _follow(event: InputEvent) -> bool:
	if not get_viewport().gui_is_dragging():
		_following = -1
		return false
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var index: int = drag.index if drag != null else touch.index if touch != null else -2
	if index != _following:
		return false
	if touch != null and not touch.pressed:
		_following = -1
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		# Godot's own mouse still has the finger: it moves and drops it.
		return true
	if drag != null:
		var move := InputEventMouseMotion.new()
		move.device = InputEvent.DEVICE_ID_EMULATION
		move.position = drag.position
		move.global_position = drag.position
		move.relative = drag.relative
		move.screen_relative = drag.screen_relative
		move.velocity = drag.velocity
		move.screen_velocity = drag.screen_velocity
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move)
	elif touch.canceled:
		get_viewport().gui_cancel_drag()
	elif not touch.pressed:
		var up := InputEventMouseButton.new()
		up.device = InputEvent.DEVICE_ID_EMULATION
		up.button_index = MOUSE_BUTTON_LEFT
		up.position = touch.position
		up.global_position = touch.position
		Input.parse_input_event(up)
	return true


## How deep the tree's top and bottom edges are, where a carry held scrolls
## it, units (at most a sixth of the tree), and how fast it goes at the very
## edge and beyond, units a second (a row a tenth of a second).
const EDGE := 20.0
const EDGE_SPEED := 240.0
var _bar: VScrollBar


## A carry held at the tree's top or bottom scrolls it to the rows out of
## sight, faster the nearer the edge. Once a row is chosen the tree is at
## its least height (Properties fills the column under it), four rows on a
## desktop and two on a tablet, so the row to put it in is most often out
## of sight. Godot's own scroll at a drag's edge is 4 units deep at 12 a
## second, too thin for a finger and too slow for anyone, and never at the
## top of a tree below its header: it compares the pointer in the tree with
## the tree's place in the column (Tree's get_rect).
func _edge_scroll(delta: float) -> void:
	if _bar == null:
		for child: Node in _tree.get_children(true):
			if child is VScrollBar:
				_bar = child
	if _bar == null or not _bar.visible:
		return
	var at: Vector2 = _tree.get_local_mouse_position()
	var tall: float = _tree.size.y
	var edge: float = minf(EDGE, tall / 6.0)
	if at.x < 0.0 or at.x > _tree.size.x or at.y < -edge or at.y > tall + edge:
		return
	var by: float = 0.0
	if at.y < edge:
		by = -minf((edge - at.y) / edge, 1.0)
	elif at.y > tall - edge:
		by = minf((at.y - (tall - edge)) / edge, 1.0)
	if by != 0.0:
		_bar.value += by * EDGE_SPEED * delta


## The pressed row's carry and what is drawn of it by the pointer, or none
## (said why) while the model may not be changed.
func _lift() -> Array:
	var refused: String = shell.why_frozen()
	if not refused.is_empty():
		shell.bar.say(refused)
		return []
	var data: Variant = _carried(_press_meta)
	if data == null or not _tree.is_visible_in_tree():
		return []
	var row: TreeItem = _find(_tree.get_root(), _press_meta)
	var words := Label.new()
	# A sub-model's name as its builder wrote it, in any language (_fill).
	words.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	words.text = row.get_text(0) if row != null else Assemblies.label(_press_meta)
	words.add_theme_font_size_override("font_size", 12)
	# Beside the pointer, and above a finger, which covers what is under it.
	var shown := Control.new()
	shown.add_child(words)
	words.position = Vector2(-24.0, -56.0) if _press_finger else Vector2(14.0, 6.0)
	_tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM
	return [data, shown]


func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var out: Dictionary = {"outliner": _header, "outliner_tree": _tree}
	for id: String in _buttons:
		if (_buttons[id] as Button).is_visible_in_tree():
			out[id] = _buttons[id]
	return out


## Where the rows are on the screen, metadata -> Rect2, walked once: what
## the page is told twice a second. Asked a row at a time, each a search of
## the whole tree, it was 100 to 300 ms of a browser's frame every half
## second on 10179-1's 392 sub-assemblies (2026-10-17).
func row_rects() -> Dictionary:
	var out: Dictionary = {}
	if _tree == null or _tree.get_root() == null or not _tree.is_visible_in_tree():
		return out
	var area: Rect2 = _tree.get_global_rect()
	# The same tree, scrolled and placed the same: the same rows. Walked
	# again only when one of those changed, not twice a second.
	var asked: String = "%s|%s|%s" % [_shown, str(area), str(_tree.get_scroll())]
	if asked == _rows_asked:
		return _rows
	_rows_asked = asked
	var shift: Vector2 = area.position - Vector2(0, _tree.get_scroll().y)
	var stack: Array = [_tree.get_root()]
	while not stack.is_empty():
		var row: TreeItem = stack.pop_back()
		var rect: Rect2 = _tree.get_item_area_rect(row)
		if rect.size != Vector2.ZERO:
			rect.position += shift
			if area.has_point(rect.get_center()):
				out[str(row.get_metadata(0))] = rect
		if not row.collapsed:
			for child: TreeItem in row.get_children():
				stack.append(child)
	_rows = out
	return out


var _rows_asked: String = ""
var _rows: Dictionary = {}

