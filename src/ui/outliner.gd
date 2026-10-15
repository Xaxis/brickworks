## The model tree: every sub-assembly by name, inside the ones it is in,
## with how many parts it has and whether it is hidden or locked.
##
## Studio and LDCad both have this, and it is how a model built as a kit
## is found again: "Bag 3", the left wing, the engine. A row selects its
## parts in the view; a double-click edits inside it; its name can be
## typed over; dragging a row onto another puts it inside that one, and
## onto the model puts it back at the top. The eye and the lock on each
## row hide and lock it whole.
class_name Outliner
extends PanelContainer

const WIDE := 240.0
const TOOLS := "res://assets/ui/tools/"
## Button ids on a row.
const EYE := 0
const LOCK := 1

var shell: Shell
var assemblies: Assemblies

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
	_tree.hide_root = false
	_tree.columns = 2
	_tree.set_column_expand(0, true)
	_tree.set_column_expand(1, false)
	_tree.set_column_custom_minimum_width(1, 54)
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_rmb_select = true
	_tree.focus_mode = Control.FOCUS_CLICK
	# As tall as the column gives it (PanelStack), and never less than
	# a few rows.
	_tree.custom_minimum_size = Vector2(WIDE - 16.0, 60)
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.add_theme_font_size_override("font_size", 12)
	_tree.add_theme_constant_override("button_margin", 2)
	_tree.drop_mode_flags = Tree.DROP_MODE_ON_ITEM
	_tree.item_selected.connect(_on_selected)
	_tree.item_activated.connect(_on_activated)
	_tree.item_edited.connect(_on_edited)
	_tree.button_clicked.connect(_on_button)
	_tree.set_drag_forwarding(_drag_data, _can_drop, _drop)
	column.add_child(_tree)

	var hint := Label.new()
	hint.text = "Double-click to edit inside; drag onto another to nest"
	hint.add_theme_font_size_override("font_size", 11)
	hint.modulate = Color(1, 1, 1, 0.55)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size = Vector2(WIDE - 16.0, 0)
	column.add_child(hint)

	var density: float = Icons.density(self)
	for name: String in ["show_all", "hide", "lock", "unlock"]:
		var path: String = TOOLS + name + ".svg"
		if FileAccess.file_exists(path):
			_icons[name] = Icons.texture_for(path, 14.0, density)
	assemblies.changed.connect(func() -> void: _refresh(true))
	assemblies.entered_changed.connect(func(_path: String) -> void: _refresh(true))
	shell.world.rebuilt.connect(func(_b: int, _c: int, _t: int) -> void: _refresh(false))
	shell.builder.selection_changed.connect(func(_n: int) -> void: _mark_selected())
	_refresh(true)


func is_open() -> bool:
	return _open


func set_open(open: bool) -> void:
	_open = open
	if _tree != null:
		_tree.visible = open
		for child: Node in _tree.get_parent().get_children():
			if child is Label:
				(child as Label).visible = open
		_arrow.down = open
		_arrow.queue_redraw()
	ShellPrefs.put("outliner_open", open)
	toggled.emit(open)
	# Folded, the tree was not kept up to date.
	_refresh(true)


func _process(_delta: float) -> void:
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
func _refresh(now: bool) -> void:
	if _tree == null or _renaming:
		return
	if not _open or not is_visible_in_tree():
		var total: int = maxi(0, shell.world.brick_count() - assemblies.scenery.size())
		_count.text = "%d part%s" % [total, "" if total == 1 else "s"]
		_shown = ""
		return
	var root: Assemblies.Item = assemblies.tree()
	var state: String = _state_of(root) + "|" + assemblies.entered
	if state == _shown and not now:
		return
	_shown = state
	_count.text = "%d part%s" % [root.total, "" if root.total == 1 else "s"]
	var folded: Dictionary = {}
	var item: TreeItem = _tree.get_root()
	if item != null:
		_collect_folded(item, folded)
	_tree.clear()
	var top: TreeItem = _tree.create_item()
	_fill(top, root, folded)
	_mark_selected()


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
	if not is_root and node.path == assemblies.entered:
		words += "  (editing)"
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
	# Lit to match the view, which is not a person choosing the row: the
	# row's own handler would select again, and round it went.
	_marking = true
	_tree.deselect_all()
	if row != null:
		row.select(0)
		_tree.scroll_to_item(row)
	_marking = false


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
	if path.is_empty():
		return
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


## Double-click: edit inside it. On the model's row: back to the top.
func _on_activated() -> void:
	var row: TreeItem = _tree.get_selected()
	if row == null:
		return
	var path: String = str(row.get_metadata(0))
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
	var name: String = assemblies.rename(path, typed)
	shell.verbs.edited.call()
	shell.bar.say("called %s" % name)
	_refresh(true)


## Rename the selected row in place, as a second click on it does.
func rename_selected() -> void:
	var row: TreeItem = _tree.get_selected()
	if row == null or str(row.get_metadata(0)).is_empty():
		return
	_renaming = true
	row.set_text(0, Assemblies.definition(Assemblies.leaf(str(row.get_metadata(0)))))
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
	var row: TreeItem = _tree.get_item_at_position(at)
	if row == null or str(row.get_metadata(0)).is_empty():
		return null
	var words := Label.new()
	words.text = row.get_text(0)
	_tree.set_drag_preview(words)
	return {"assembly": str(row.get_metadata(0))}


func _can_drop(at: Vector2, data: Variant) -> bool:
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
	if row == null:
		return
	var into: String = str(row.get_metadata(0))
	var moved: String = assemblies.move_into(str((data as Dictionary)["assembly"]), into)
	shell.verbs.edited.call()
	shell.bar.say("%s is in %s now" % [Assemblies.label(moved),
		"the model" if into.is_empty() else Assemblies.label(into)])
	_refresh(true)


func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	return {"outliner": _header, "outliner_tree": _tree}
