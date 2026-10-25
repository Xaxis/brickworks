## Every dialog and panel over the model, on a phone or a tablet, sized and
## placed for a finger.
##
## The phone's layout and a tablet's (PhoneShell) were built in points, but
## what More opens was still the desktop's: Save as with its words at 7
## points and its buttons 17 points tall, Share's licence 14, Build
## together's Join 21 by 17, every one a box in the middle of the screen
## drawn for a mouse (dialogs255). So a person on a phone could build a
## model and not save it under a name, share it or change a setting.
##
## One rule for all of them, as Access is one rule for the keys: a dialog
## shown in the layout for a finger takes the layout's sizing. Its text
## grows from the desktop's units to points, the desktop's smallest (11)
## becoming Phone.LEAST_TEXT and nothing under it; every target a finger
## has is at least Phone.TARGET points each way, a list's rows and a menu's
## items too; its title bar and its close button likewise. Its own look and
## words stay as they are. It is placed for a finger: on a phone along the
## foot of the screen as wide as it is, as a sheet, or the whole screen for
## a panel that wants the room; on a tablet in the middle, as on a desktop.
## Either way above the on-screen keyboard while it is up, with the field
## being typed in scrolled into sight.
##
## Godot's own dialogs (AcceptDialog and the rest) are found as they are
## made and sized each time they show; Main's panels over the model are
## placed by Main._inset, which hands them here. Nothing is made on a
## desktop, which keeps its dialogs to the pixel (desktop_same.mjs).
class_name TouchSizing
extends Node

## The desktop's smallest text, in its units: shown in points here it is
## Phone.LEAST_TEXT, and the rest grow with it.
const DESKTOP_LEAST := 11.0

## How far a tablet's dialog stands back from the screen's edges, in points.
const GUTTER := 16.0

## Main's panels over the model, placed here (place_panel).
const GROUP := &"touch_sized"

## The desktop's panels shown in the layout for a finger that are not
## dialogs (size_panel): sized, and left where they are.
const SIZED := &"touch_sized_only"

## What a control was on the desktop, and what it was given here.
const WAS := &"touch_was"

## Every font size a control may have, by its theme's name for it.
const FONTS: Array[StringName] = [&"font_size", &"normal_font_size", &"bold_font_size",
	&"italics_font_size", &"bold_italics_font_size", &"mono_font_size",
	&"title_button_font_size", &"font_separator_size"]

## Laid out wide, for a tablet (Phone.wide).
var wide: bool = false

## The on-screen keyboard's height, in points: 0 while it is down.
var keyboard: float = 0.0

## The dialogs open now: Windows and Main's panels.
var _open: Array = []
var _look_at: int = 0


func _ready() -> void:
	wide = Phone.wide()
	get_tree().node_added.connect(_on_added)
	get_viewport().size_changed.connect(_place_all, CONNECT_DEFERRED)
	_watch_all.call_deferred(get_tree().root)
	if OS.has_feature("web"):
		# The keyboard is told as the part of the window it covers: what the
		# visual viewport has lost from the bottom of the layout's.
		JavaScriptBridge.eval("""(function () {
			const vv = window.visualViewport; if (!vv) return;
			const tell = () => { window.brickworksKeyboardNow =
				Math.max(0, Math.round(window.innerHeight - vv.height - vv.offsetTop)); };
			vv.addEventListener('resize', tell); vv.addEventListener('scroll', tell); tell();
		})()""", true)
	set_process(true)


func _watch_all(node: Node) -> void:
	for child: Node in node.get_children(true):
		_on_added(child)
		_watch_all(child)


func _on_added(node: Node) -> void:
	var window := node as Window
	if window != null:
		if window != get_window() and not window.visibility_changed.is_connected(_window_shown):
			window.visibility_changed.connect(_window_shown.bind(window))
		return
	var control := node as Control
	if control == null:
		return
	# A row put into a dialog that is open (a list filled afresh): sized as
	# its dialog was, once whoever made it has set it up.
	var holder: Node = _dialog_of(control)
	if holder != null and (holder in _open or holder.is_in_group(SIZED)):
		_size_later.call_deferred(control)


func _size_later(control: Control) -> void:
	if is_instance_valid(control) and control.is_inside_tree():
		size_tree(control)
		var holder: Node = _dialog_of(control)
		if holder in _open:
			_place_later(holder)


## The dialog [param control] is in: the Window it is drawn in, or the panel
## of Main's it is under; null for anything else.
func _dialog_of(control: Node) -> Node:
	var up: Node = control
	while up != null:
		if up is Window:
			return up if up != get_window() else null
		if up.is_in_group(GROUP) or up.is_in_group(SIZED):
			return up
		up = up.get_parent()
	return null


func _window_shown(window: Window) -> void:
	if not is_instance_valid(window) or Tooltips.is_tooltip(window):
		return
	if not window.visible:
		_open.erase(window)
		return
	if window not in _open:
		_open.append(window)
	_size_window(window)
	size_tree(window)
	_place_later(window)


## One of Main's panels over the model (Main._inset): sized when it shows,
## and placed for a finger rather than in the middle at the desktop's size.
func place_panel(panel: Control, wants: Vector2) -> void:
	panel.set_meta(&"touch_wants", wants)
	if not panel.is_in_group(GROUP):
		panel.add_to_group(GROUP)
		panel.visibility_changed.connect(_panel_shown.bind(panel))
		if panel.visible:
			_panel_shown(panel)
	_lay_panel(panel)


func _panel_shown(panel: Control) -> void:
	if not panel.visible:
		_open.erase(panel)
		return
	if panel not in _open:
		_open.append(panel)
	size_tree(panel)
	_place_later(panel)


## A panel of the desktop's that is not a dialog, shown in the layout for a
## finger (the model tree and the properties in their drawer): sized as a
## dialog is, placed where it is.
func size_panel(panel: Control) -> void:
	panel.add_to_group(SIZED)
	size_tree(panel)


## One of those made to fit across the room it has, as a dialog is.
func fit_panel(panel: Control) -> void:
	if is_instance_valid(panel) and panel.is_visible_in_tree():
		_wrap_words(panel, panel.size.x)
		_flow_rows(panel, panel.size.x)


## Placed once what was sized has been laid out: a container sorts its
## children at the end of the frame.
func _place_later(dialog: Node) -> void:
	if dialog == null:
		return
	if not dialog.has_meta(&"touch_placing"):
		dialog.set_meta(&"touch_placing", true)
		_place_after_layout.call_deferred(dialog)


func _place_after_layout(dialog: Node) -> void:
	await get_tree().process_frame
	if not is_instance_valid(dialog):
		return
	dialog.remove_meta(&"touch_placing")
	_place(dialog)


func _place_all() -> void:
	for dialog: Node in _open.duplicate():
		if is_instance_valid(dialog):
			_place(dialog)
		else:
			_open.erase(dialog)


func _place(dialog: Node) -> void:
	if dialog is Window:
		_lay_window(dialog as Window)
	elif dialog is Control:
		_lay_panel(dialog as Control)
	_show_focus(dialog)


func _process(_delta: float) -> void:
	if not OS.has_feature("web") or Time.get_ticks_msec() < _look_at:
		return
	_look_at = Time.get_ticks_msec() + 250
	# Only while a field is being typed in: the keyboard is down otherwise,
	# whatever the visual viewport is doing (a pinch zooms it too).
	var now: float = 0.0
	if typing() != null:
		var told: Variant = JavaScriptBridge.eval("window.brickworksKeyboardNow || 0", true)
		now = float(told) if told != null else 0.0
	if absf(now - keyboard) >= 1.0:
		keyboard = now
		_place_all()


## The field being typed in, in an open dialog, if there is one.
func typing() -> Control:
	for dialog: Node in _open:
		if not is_instance_valid(dialog):
			continue
		var view: Viewport = dialog as Window if dialog is Window else get_viewport()
		var focus: Control = view.gui_get_focus_owner()
		if focus == null or not (focus is LineEdit or focus is TextEdit):
			continue
		if dialog is Window or (dialog as Control).is_ancestor_of(focus):
			return focus
	return null


## The room a dialog has, in the window's units: the screen above the
## keyboard, for the one being typed in ([param dialog], or any); the
## whole screen for one behind it, which waits for that one to go.
func room(dialog: Node = null) -> Rect2:
	var screen: Rect2 = get_viewport().get_visible_rect()
	if dialog != null and not typing_in(dialog):
		return screen
	var k: float = Phone.per_point(get_viewport())
	screen.size.y = maxf(screen.size.y - keyboard * k, screen.size.y * 0.3)
	return screen


## Whether the field being typed in is in [param dialog].
func typing_in(dialog: Node) -> bool:
	var field: Control = typing()
	return field != null and _dialog_of(field) == dialog


## The dialog the field being typed in is in, for the audit.
func typing_dialog() -> Node:
	var field: Control = typing()
	return _dialog_of(field) if field != null else null


## Everything in [param root] sized for a finger: its text at least
## Phone.LEAST_TEXT points, grown from the desktop's with it, and every
## target at least Phone.TARGET points each way. What each was is kept, so
## sizing it again (a turn, a list filled afresh) starts from the desktop's.
func size_tree(root: Node) -> void:
	var k: float = Phone.per_point(get_viewport())
	var widest: float = room().size.x - 2.0 * k * GUTTER
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		# A dialog's own dialog is sized when it shows.
		if node != root and node is Window:
			continue
		if node is Control:
			_size_one(node as Control, k, widest)
		walk.append_array(node.get_children(true))


func _size_one(control: Control, k: float, widest: float) -> void:
	# The notices strip is drawn for a finger already (Main._for_a_finger).
	if control.has_meta(&"for_a_finger"):
		return
	var was: Dictionary = control.get_meta(WAS, {})
	for item: StringName in FONTS:
		if not control.has_theme_font_size(item):
			continue
		var now: int = control.get_theme_font_size(item)
		var desktop: int = _desktop(was, item, now, control.has_theme_font_size_override(item))
		was[item] = [desktop, _text_size(desktop, k)]
		if int(was[item][1]) != now:
			control.add_theme_font_size_override(item, int(was[item][1]))
	var least: float = k * Phone.TARGET
	var own: Vector2 = control.custom_minimum_size
	var first: Vector2 = own
	if was.has(&"min") and own == (was[&"min"][1] as Vector2):
		first = was[&"min"][0]
	var wants: Vector2 = first
	if takes(control):
		wants = Vector2(maxf(first.x, least), maxf(first.y, least))
		# A finger dragged over a list's rows scrolls the list: a row that
		# stopped the drag left a list longer than the screen with no way
		# down it. The row's press is let go as the list moves (BaseButton).
		if control.mouse_filter == Control.MOUSE_FILTER_STOP and _scrolls_round(control):
			control.mouse_filter = Control.MOUSE_FILTER_PASS
	# Nothing wider than the screen leaves it: a desktop field 480 across.
	wants.x = minf(wants.x, maxf(widest, least))
	was[&"min"] = [first, wants]
	if wants != own:
		control.custom_minimum_size = wants
	# A list's rows and a tree's, each a fingertip tall.
	if control is Tree or control is ItemList:
		var font: Font = control.get_theme_font("font")
		var row: float = font.get_height(control.get_theme_font_size("font_size")) if font != null else 0.0
		var spacing: int = control.get_theme_constant("v_separation")
		var sep_was: int = int(was[&"sep"][0]) if was.has(&"sep") and spacing == int(was[&"sep"][1]) else spacing
		var sep: int = maxi(sep_was, ceili(least - row) + 1)
		was[&"sep"] = [sep_was, sep]
		if sep != spacing:
			control.add_theme_constant_override("v_separation", sep)
	# A button's words too long for the screen end in an ellipsis there: a
	# parts list's rows ran 175 points off a phone.
	var button := control as Button
	if button != null and not button.clip_text and button.get_minimum_size().x > widest:
		button.clip_text = true
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A line too long for the screen wraps there.
	var label := control as Label
	if label != null and label.autowrap_mode == TextServer.AUTOWRAP_OFF and not label.clip_text \
			and label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
			and label.get_minimum_size().x > widest:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = minf(widest, maxf(label.custom_minimum_size.x, widest * 0.6))
	control.set_meta(WAS, was)


## Whether something round [param control] scrolls up and down.
static func _scrolls_round(control: Control) -> bool:
	var up: Node = control.get_parent()
	while up != null and not up is Window:
		var scroll := up as ScrollContainer
		if scroll != null and scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			return true
		up = up.get_parent()
	return false


## What a font size was on the desktop: the one it has now, unless that is
## the one it was given here.
static func _desktop(was: Dictionary, item: StringName, now: int, overridden: bool) -> int:
	if was.has(item) and overridden and now == int(was[item][1]):
		return int(was[item][0])
	return now


## A desktop text size in units, for a finger: the desktop's smallest at
## Phone.LEAST_TEXT points, the rest in proportion, and none under it.
static func _text_size(desktop: int, k: float) -> int:
	return ceili(maxf(desktop * k * Phone.LEAST_TEXT / DESKTOP_LEAST, k * Phone.LEAST_TEXT))


## What a finger can press, as the audit counts it (Main._phone_audit).
static func takes(control: Control) -> bool:
	return control.mouse_filter != Control.MOUSE_FILTER_IGNORE and (
		control is BaseButton or control is LineEdit or control is TextEdit
		or control is Range and not control is ScrollBar and not control is ProgressBar)


## A Window's own: its title bar and close button a fingertip tall, its
## title in points; a menu's items a fingertip tall.
func _size_window(window: Window) -> void:
	var k: float = Phone.per_point(get_viewport())
	var least: int = ceili(k * Phone.TARGET)
	var was: Dictionary = window.get_meta(WAS, {})
	for item: StringName in [&"title_font_size", &"font_size", &"font_separator_size"]:
		if not window.has_theme_font_size(item):
			continue
		var now: int = window.get_theme_font_size(item)
		if now <= 0:
			now = window.get_theme_default_font_size()
		var desktop: int = _desktop(was, item, now, window.has_theme_font_size_override(item))
		was[item] = [desktop, _text_size(desktop, k)]
		window.add_theme_font_size_override(item, int(was[item][1]))
	var menu := window as PopupMenu
	if menu != null:
		# Its sides as the desktop's, in points: a phone has no room to spare
		# across for a menu of long items.
		menu.add_theme_constant_override("item_start_padding", ceili(k * 6.0))
		menu.add_theme_constant_override("item_end_padding", ceili(k * 6.0))
		# As big as the rest, or as big as lets its longest item across the
		# screen, and never under Phone.LEAST_TEXT: "From a file on this
		# computer (LDraw, Studio .io, LDD .lxf)…" ran 150 points off a phone.
		var font: Font = menu.get_theme_font("font")
		var size: int = menu.get_theme_font_size("font_size")
		if font != null:
			var longest: float = 0.0
			for n: int in menu.item_count:
				longest = maxf(longest, font.get_string_size(menu.get_item_text(n),
					HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
			var across: float = room().size.x - k * 40.0
			if longest > across:
				size = maxi(ceili(k * Phone.LEAST_TEXT), floori(size * across / longest))
				menu.add_theme_font_size_override("font_size", size)
		var row: float = font.get_height(size) if font != null else 0.0
		menu.add_theme_constant_override("v_separation", maxi(4, ceili(least - row) + 1))
	elif not window.borderless and not was.has(&"title"):
		was[&"title"] = true
		window.add_theme_constant_override("title_height", least)
		# The close button's square, the × in its middle as big as the
		# title's words.
		for icon: StringName in [&"close", &"close_pressed"]:
			window.add_theme_icon_override(icon, _square(window.get_theme_icon(icon), least,
				ceili(k * 16.0)))
		window.add_theme_constant_override("close_h_offset", least)
		window.add_theme_constant_override("close_v_offset", least)
		for item: StringName in [&"embedded_border", &"embedded_unfocused_border"]:
			var border: StyleBox = window.get_theme_stylebox(item)
			if border == null:
				continue
			var face: StyleBox = border.duplicate()
			if face is StyleBoxFlat:
				(face as StyleBoxFlat).expand_margin_top = least
			window.add_theme_stylebox_override(item, face)
	var dialog := window as AcceptDialog
	if dialog != null:
		# Its words wrap at the screen's width rather than run off it.
		dialog.dialog_autowrap = true
		# Its own buttons are sized by its theme, again at every layout of it
		# (AcceptDialog._update_child_rects): a size given them is undone.
		for item: StringName in [&"buttons_min_width", &"buttons_min_height"]:
			dialog.add_theme_constant_override(item, maxi(least, dialog.get_theme_constant(item)))
	window.set_meta(WAS, was)


## [param icon] drawn [param inner] across in the middle of a clear square
## [param across] wide: what a finger presses is the square.
static func _square(icon: Texture2D, across: int, inner: int) -> Texture2D:
	if icon == null:
		return null
	var picture: Image = icon.get_image()
	if picture == null:
		return icon
	picture = picture.duplicate()
	if picture.is_compressed():
		picture.decompress()
	picture.convert(Image.FORMAT_RGBA8)
	picture.resize(inner, inner, Image.INTERPOLATE_LANCZOS)
	var square := Image.create(across, across, false, Image.FORMAT_RGBA8)
	square.blit_rect(picture, Rect2i(Vector2i.ZERO, picture.get_size()),
		Vector2i((across - inner) / 2, (across - inner) / 2))
	return ImageTexture.create_from_image(square)


## Where a Window's frame reaches past its content: its title bar above,
## its border round the rest (left, top, right, bottom).
static func frame_of(window: Window) -> Array[float]:
	if window.borderless or window is Popup and not window is AcceptDialog:
		return [0.0, 0.0, 0.0, 0.0]
	var border := window.get_theme_stylebox("embedded_border") as StyleBoxFlat
	var title: float = float(window.get_theme_constant("title_height"))
	if border == null:
		return [0.0, title, 0.0, 0.0]
	return [border.expand_margin_left, maxf(border.expand_margin_top, title),
		border.expand_margin_right, border.expand_margin_bottom]


## A dialog wider than the screen made narrower, and laid out again: its
## long lines wrapped, and its rows of buttons let flow onto a second line
## ("Deleted “…” Undo"; the parts list's What do I need?, Save as CSV,
## BrickLink, Rebrickable and Done ran 300 points off a phone).
func _narrower(dialog: Node, across: float) -> void:
	var wrapped: bool = _wrap_words(dialog, across)
	if _flow_rows(dialog, across) or wrapped:
		_place_later(dialog)


## Every row in [param root] wider than [param across] let flow: its
## children moved into a flow inside it, which wraps them. The row stays,
## for whoever made it and keeps it.
static func _flow_rows(root: Node, across: float) -> bool:
	var flowed: bool = false
	var rows: Array[Node] = root.find_children("*", "HBoxContainer", true, false)
	rows.reverse()
	for found: Node in rows:
		var row: HBoxContainer = found
		if row.get_child_count() < 2 or row.get_combined_minimum_size().x <= across \
				or row.get_child(0) is HFlowContainer or not row.get_parent() is Container:
			continue
		# Not a row with a grid in it: a grid that takes its columns from the
		# width it is given widened its flow's line, which gave it more, and
		# the Minifigure builder's grew without end.
		if not row.find_children("*", "GridContainer", true, false).is_empty():
			continue
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.alignment = row.alignment as FlowContainer.AlignmentMode
		flow.add_theme_constant_override("h_separation", row.get_theme_constant("separation"))
		flow.add_theme_constant_override("v_separation", row.get_theme_constant("separation"))
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var children: Array[Node] = row.get_children()
		row.add_child(flow)
		for child: Node in children:
			child.reparent(flow, false)
			# What stretched along the row has a share of a line instead: a
			# field stretched in a flow grew without end.
			var control := child as Control
			if control != null and control.size_flags_horizontal & Control.SIZE_EXPAND:
				control.size_flags_horizontal = Control.SIZE_FILL
				control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, across * 0.6)
		flowed = true
	return flowed


## Every line in [param root] too wide for [param across] wrapped: one
## wider than it, or one whose row of buttons is, which then takes the room
## its row leaves it.
static func _wrap_words(root: Node, across: float) -> bool:
	var wrapped: bool = false
	for found: Node in root.find_children("*", "Label", true, false):
		var label: Label = found
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.clip_text \
				or not label.is_visible_in_tree():
			continue
		var row := label.get_parent() as HBoxContainer
		var in_row: bool = row != null and row.get_combined_minimum_size().x > across \
			and label.get_minimum_size().x > across * 0.3
		if label.get_minimum_size().x <= across and not in_row:
			continue
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if in_row:
			label.size_flags_horizontal |= Control.SIZE_EXPAND
		label.custom_minimum_size.x = across * 0.3 if in_row else minf(label.custom_minimum_size.x, across)
		wrapped = true
	return wrapped


## A Window placed for a finger: on a phone along the foot, as wide as the
## screen; on a tablet in the middle. Above the keyboard either way, and
## never taller than the room there.
func _lay_window(window: Window) -> void:
	if not window.visible:
		return
	var space: Rect2 = room(window)
	var k: float = Phone.per_point(get_viewport())
	var frame: Array[float] = frame_of(window)
	var menu: bool = window is Popup and not window is AcceptDialog
	var size: Vector2 = Vector2(window.size)
	var least: Vector2 = Vector2(window.get_contents_minimum_size())
	if menu:
		# A menu drops from what opened it: only kept on the screen.
		size = size.max(least)
		size = Vector2(minf(size.x, space.size.x), minf(size.y, space.size.y))
		var at: Vector2 = Vector2(window.position)
		at.x = clampf(at.x, space.position.x, maxf(space.position.x, space.end.x - size.x))
		at.y = clampf(at.y, space.position.y, maxf(space.position.y, space.end.y - size.y))
		window.size = Vector2i(size)
		window.position = Vector2i(at)
		return
	var gap: float = k * (GUTTER if wide else 0.0)
	var most: Vector2 = Vector2(space.size.x - frame[0] - frame[2] - gap * 2.0,
		space.size.y - frame[1] - frame[3] - gap * 2.0 - (0.0 if wide else k * 8.0))
	# A row wider than the screen ("Deleted “…” Undo"): its words wrap, and
	# it is laid out again.
	if not wide:
		# Its rows inside its own margins.
		_narrower(window, most.x - k * 24.0)
	if not wide:
		size.x = most.x
	size = Vector2(clampf(maxf(size.x, least.x), 0.0, most.x), clampf(least.y, 0.0, most.y))
	window.size = Vector2i(size.round())
	size = Vector2(window.size)
	var place: Vector2
	if wide:
		place = space.position + Vector2(frame[0], frame[1]) + (Vector2(most.x, most.y) - size) * 0.5 \
			+ Vector2(gap, gap)
	else:
		place = Vector2(space.position.x + frame[0], space.end.y - frame[3] - size.y)
	window.position = Vector2i(place.round())


## One of Main's panels placed for a finger: on a phone the whole screen
## above the keyboard; on a tablet in the middle at the size it asks for,
## or as much as there is room for.
func _lay_panel(panel: Control) -> void:
	var space: Rect2 = room(panel)
	var k: float = Phone.per_point(get_viewport())
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	if not wide:
		if panel.visible:
			_narrower(panel, space.size.x - k * 2.0 * GUTTER)
		panel.offset_left = space.position.x
		panel.offset_top = space.position.y
		panel.offset_right = space.end.x
		panel.offset_bottom = space.end.y
		return
	var wants: Vector2 = panel.get_meta(&"touch_wants", Vector2(520, 720))
	var gap: float = k * GUTTER
	if panel.visible:
		_narrower(panel, space.size.x - gap * 4.0)
	var least: Vector2 = panel.get_combined_minimum_size()
	var size := Vector2(minf(maxf(wants.x, least.x), space.size.x - gap * 2.0),
		minf(wants.y, space.size.y - gap * 2.0))
	var at: Vector2 = space.position + (space.size - size) * 0.5
	panel.offset_left = at.x
	panel.offset_top = at.y
	panel.offset_right = at.x + size.x
	panel.offset_bottom = at.y + size.y


## The field being typed in kept in sight above the keyboard: scrolled to in
## whatever scrolls round it.
func _show_focus(dialog: Node) -> void:
	var field: Control = typing()
	if field == null or _dialog_of(field) != dialog:
		return
	var up: Node = field.get_parent()
	while up != null and up != dialog:
		if up is ScrollContainer:
			(up as ScrollContainer).ensure_control_visible(field)
		up = up.get_parent()
