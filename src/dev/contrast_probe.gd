## Can every button the app shows be seen, read, and its default told apart?
##
##   tools/probe.sh contrast_probe
##   godot --path . --resolution 1400x900 --script src/dev/contrast_probe.gd
##   ... -- --shots=DIR    each window pictured there, to look at
##
## dialogs269 (2026-10-26): on the app's dark face the engine's buttons
## (a fill of black at 60%) were all but invisible: "Start a session",
## "Cancel", "Join". So this walks the windows dialog_look_probe walks (the
## same 108 dialogs and menus, opened as a person opens them, then every
## other one in the window), and before them the main window and its main
## panels (Library, Render, My collection, the figure builder, Settings
## and the rest), and reads each button off the window's own pixels:
##
##   its boundary or its fill against the face round it (WCAG 1.4.11, at
##   least 3:1), where it has one: a flat button is its words or its
##   picture, and those are judged against the face instead;
##   its words against its fill (at least 4.5:1), or its picture (3:1);
##   in a dialog with more than one button, the default (OK) one told apart
##   from the rest: its boundary or fill at least 3:1 from theirs.
##
## A disabled button is not judged (WCAG's inactive components), nor one
## out of sight: scrolled away, off the window, or under another.
## The app has one theme, its dark one; the website's two are the site's.
extends "res://src/dev/dialog_look_probe.gd"

## Buttons judged, by instance id.
var _judged: Dictionary = {}
var _buttons: int = 0
var _windows: int = 0
var _failing: int = 0

const PANELS: Array = [["library", "Library"], ["render", "Render"], ["collection", "My collection"],
	["minifig", "the figure builder"], ["parts_list", "the parts list"], ["settings", "Settings"],
	["keys", "Keys and controls"], ["account", "Account"], ["share", "Share"],
	["mosaic", "Mosaic"], ["part_maker", "the part maker"], ["print_part", "Print on a part"],
	["hidden_colours", "Colour the hidden parts"], ["pose", "Motions"], ["simulate", "Simulate"],
	["flex", "Hose, tube or chain"]]


func _initialize() -> void:
	_label = "contrast probe"
	super._initialize()


## The main window as it opens, then each main panel over it, alone: the
## panels it opens are judged, then closed.
func _main_window() -> void:
	print("\n  the main window")
	await _judge_here(root, "the main window")
	for panel: Array in PANELS:
		var before: Dictionary = _panels_shown()
		var windows: Dictionary = _windows_shown()
		if not _shell.run(str(panel[0])):
			print("    (%s could not be opened here)" % panel[1])
			continue
		await _frames(30)
		var opened: Array[Control] = []
		for shown: Control in _panels_shown().values():
			if not before.has(shown.get_instance_id()) \
					and not opened.any(func(o: Control) -> bool: return o.is_ancestor_of(shown)):
				opened.append(shown)
		if opened.is_empty():
			print("    (%s opens no panel of its own)" % panel[1])
		await _shot("panel_" + str(panel[0]))
		for shown: Control in opened:
			await _judge_here(root, str(panel[1]), shown)
		for shown: Control in opened:
			if shown.has_method("close"):
				shown.call("close")
			else:
				shown.hide()
		# And what it opened over itself (Mosaic asks for a picture first):
		# its chooser is judged where the dialogs are.
		for shown: Window in _windows_shown().values():
			if not windows.has(shown.get_instance_id()):
				shown.hide()
		await _frames(10)
	if "--main-only" in OS.get_cmdline_user_args():
		_summary()
		quit(1 if _failures > 0 else 0)
		await _frames(100000)


## Every window shown over the main one, by instance id.
func _windows_shown() -> Dictionary:
	var out: Dictionary = {}
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		for n: int in node.get_child_count(true):
			walk.append(node.get_child(n, true))
		if node is Window and node != root and (node as Window).visible:
			out[node.get_instance_id()] = node
	return out


## Every panel shown in the main window, by instance id.
func _panels_shown() -> Dictionary:
	var out: Dictionary = {}
	var walk: Array[Node] = [root]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		for n: int in node.get_child_count():
			var child: Node = node.get_child(n)
			if not child is Window:
				walk.append(child)
		if node is PanelContainer and (node as Control).is_visible_in_tree():
			out[node.get_instance_id()] = node
	return out


func _in_the_look(window: Window, what: String) -> void:
	_read[window.get_instance_id()] = true
	_names.append(what)
	await _judge_here(window, what)


## Every button of [param holder] (a window, or the main one; only those
## in [param under] when it is given) not judged yet, judged off a picture
## of the window.
func _judge_here(holder: Window, what: String, under: Node = null) -> void:
	await _frames(5)
	var picture: Image = await _picture()
	var shift := Vector2.ZERO if holder == root else Vector2(holder.position)
	var bounds := Rect2(shift, Vector2(holder.size)) if holder != root \
		else Rect2(Vector2.ZERO, Vector2(root.get_visible_rect().size))
	var found: Array[BaseButton] = []
	# What draws something of its own, which the face round a button is not.
	var drawn: Array[Control] = []
	var walk: Array[Node] = [under if under != null else holder]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		for n: int in node.get_child_count(true):
			var child: Node = node.get_child(n, true)
			if child is Window:
				continue
			walk.append(child)
		var control := node as Control
		if control != null and control.is_visible_in_tree() and not control is Container:
			drawn.append(control)
		var button := node as BaseButton
		if button != null and not _judged.has(button.get_instance_id()) and _in_sight(button, bounds,
				shift):
			found.append(button)
	if found.is_empty():
		return
	_windows += 1
	var wrong := PackedStringArray()
	for button: BaseButton in found:
		_judged[button.get_instance_id()] = true
		_buttons += 1
		var rect: Rect2 = button.get_global_rect()
		rect.position += shift
		# Beside it, not behind it: a control round the whole button (a
		# layer over the window, a panel's own backing) is its face.
		var others: Array[Rect2] = []
		for other: Control in drawn:
			if other != button and not other.is_ancestor_of(button) \
					and not button.is_ancestor_of(other):
				var at: Rect2 = other.get_global_rect()
				at.position += shift
				# A view or a panel beside it is a face too; a button, a
				# label or a picture there is not.
				if not at.encloses(rect) and at.get_area() < 40000.0:
					others.append(at)
		var said: String = _judge(picture, button, rect, others, bounds)
		if not said.is_empty():
			wrong.append(said)
	if holder is AcceptDialog:
		var told: String = _default_told(picture, holder as AcceptDialog, shift)
		if not told.is_empty():
			wrong.append(told)
	_failing += wrong.size()
	if "--every" in OS.get_cmdline_user_args():
		for said: String in wrong:
			print("    NOT %s" % said)
	_check("%s: %d button(s) seen and read%s" % [what, found.size(),
		"" if wrong.is_empty() else "; %d not: %s" % [wrong.size(), "; ".join(wrong.slice(0, 6))]],
		wrong.is_empty())


## Whether [param button] is a person's to see and press here: shown, on,
## inside the window and every scroll it is in.
func _in_sight(button: BaseButton, bounds: Rect2, shift: Vector2) -> bool:
	if not button.is_visible_in_tree() or button.disabled:
		return false
	var rect: Rect2 = button.get_global_rect()
	rect.position += shift
	if rect.size.x < 8 or rect.size.y < 8 or not bounds.grow(1).encloses(rect):
		return false
	var up: Node = button.get_parent()
	while up != null and up is Control:
		if up is ScrollContainer or (up as Control).clip_contents:
			var clip: Rect2 = (up as Control).get_global_rect()
			clip.position += shift
			if not clip.grow(1).encloses(rect):
				return false
		up = up.get_parent()
	return true


## What is wrong with [param button] as drawn, "" when nothing.
func _judge(picture: Image, button: BaseButton, rect: Rect2, others: Array[Rect2],
		bounds: Rect2) -> String:
	var mid: float = rect.position.y + rect.size.y * 0.5
	var fill: Color = _at(picture, Vector2(rect.position.x + 2.5, mid))
	# On each side: its edge there, the pixels across that side as drawn (a
	# line one unit wide is less than a pixel at some sizes of the window,
	# and is spread over two), against the face out from it, the first
	# point out that is on nothing else drawn nor on another's softened
	# edge. It is told from its face by the side it is best told on: a
	# panel's rail has its line on its inner side alone.
	var face_contrast: float = -1.0
	var face := Color()
	var centre: Vector2 = rect.get_center()
	for way: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		var side := Vector2(rect.position.x if way.x < 0 else rect.end.x if way.x > 0
			else centre.x, rect.position.y if way.y < 0 else rect.end.y if way.y > 0 else mid)
		var out := Vector2.INF
		for step: int in range(2, 400):
			var at: Vector2 = side + way * float(step)
			if not bounds.has_point(at):
				break
			if not others.any(func(r: Rect2) -> bool: return r.grow(1).has_point(at)):
				out = at
				break
		if out == Vector2.INF:
			continue
		var round_it: Color = _at(picture, out)
		var against: float = _ratio(fill, round_it)
		for inward: float in [-0.5, 0.0, 0.5, 1.0, 1.5]:
			against = maxf(against, _ratio(_at(picture, side - way * inward), round_it))
		if against > face_contrast:
			face_contrast = against
			face = round_it
	if face_contrast < 0.0:
		return "%s“%s”: no face round it to read, at %s" % [button.get_class(),
			(button as Button).text.left(20) if button is Button else "", rect]
	var words: bool = button is Button and not (button as Button).text.strip_edges().is_empty()
	# Made to be its words or its picture alone: a flat button, a link, a
	# tick box or a switch (their pictures are Look's), a picture button.
	# Any other has a face of its own, which is how it is seen to be one.
	var flat: bool = button is CheckBox or button is CheckButton or button is LinkButton \
		or button is TextureButton or button is Button and (button as Button).flat \
		or not _has_face(button.get_theme_stylebox("normal"))
	var marked: bool = words or button is Button and (button as Button).icon != null \
		or button is TextureButton
	# Its words or picture: the most from its fill across its middle.
	var content: float = _content(picture, rect, fill)
	var name: String = "%s“%s” %s" % [button.get_class(), (button as Button).text.left(20)
		if button is Button else "", "flat" if flat else "%.1f:1" % face_contrast]
	if "--every" in OS.get_cmdline_user_args():
		print("    %s: edge %.2f, content %.2f, flat %s, at %s" % [name, face_contrast,
			_content(picture, rect, fill), flat, rect])
	if not flat and face_contrast < 3.0:
		return "%s: its edge %.1f:1 on #%s" % [name, face_contrast, face.to_html(false)]
	# A swatch is its colour, which its edge has said.
	if not marked:
		return ""
	# Its words in their own colour on its fill, as WCAG measures them (a
	# small font's softened pixels never reach it); and drawn, which the
	# pixels say.
	if words:
		var pressed: bool = button.toggle_mode and button.button_pressed
		var ink: Color = button.get_theme_color("font_pressed_color" if pressed
			else "font_focus_color" if button.has_focus() else "font_color")
		var said: float = _ratio(fill.lerp(Color(ink, 1.0), ink.a), fill)
		if said < 4.5:
			return "%s: its words %.1f:1" % [name, said]
	if content < 3.0:
		return "%s: its %s %.1f:1 as drawn" % [name, "words" if words else "picture", content]
	return ""


## Whether [param style] draws a face: a fill or an edge to be seen by. A
## toolbar's button has none until it is pointed at, and is its picture.
static func _has_face(style: StyleBox) -> bool:
	var flat := style as StyleBoxFlat
	if flat == null:
		return not style is StyleBoxEmpty
	var edged: bool = flat.border_color.a > 0.05 and (flat.border_width_left
		+ flat.border_width_right + flat.border_width_top + flat.border_width_bottom) > 0
	return flat.draw_center and flat.bg_color.a > 0.05 or edged


## The most any pixel of [param rect]'s inside stands out from [param fill]:
## its words or its picture.
func _content(picture: Image, rect: Rect2, fill: Color) -> float:
	var content: float = 1.0
	var inner: Rect2 = rect.grow(-3)
	var y: float = inner.position.y
	while y < inner.end.y:
		var x: float = inner.position.x
		while x < inner.end.x:
			content = maxf(content, _ratio(_at(picture, Vector2(x, y)), fill))
			x += 1.0
		y += 1.0
	return content


## In a dialog with more buttons than its OK, whether the OK one is told
## apart from them: "" when it is.
func _default_told(picture: Image, dialog: AcceptDialog, shift: Vector2) -> String:
	var ok: Button = dialog.get_ok_button()
	# A default that cannot be pressed yet (Open before a file is chosen) is
	# not one to tell apart.
	if ok == null or not ok.is_visible_in_tree() or ok.disabled:
		return ""
	var row: Node = ok.get_parent()
	var looks: Array[Array] = []
	for child: Node in row.get_children(true):
		var other := child as Button
		if other == null or other == ok or not other.is_visible_in_tree():
			continue
		looks.append(_marks(picture, other, shift))
	if looks.is_empty():
		return ""
	var mine: Array = _marks(picture, ok, shift)
	for theirs: Array in looks:
		if maxf(_ratio(mine[0], theirs[0]), _ratio(mine[1], theirs[1])) < 3.0:
			return "its default “%s” not told from the rest (%.1f:1)" % [ok.text,
				maxf(_ratio(mine[0], theirs[0]), _ratio(mine[1], theirs[1]))]
	return ""


## A button's edge and fill, as drawn.
func _marks(picture: Image, button: Button, shift: Vector2) -> Array:
	var rect: Rect2 = button.get_global_rect()
	rect.position += shift
	var mid: float = rect.position.y + rect.size.y * 0.5
	return [_at(picture, Vector2(rect.position.x + 0.5, mid)),
		_at(picture, Vector2(rect.position.x + 2.5, mid))]


## WCAG's contrast ratio between two colours as drawn.
static func _ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var out: float = 0.0
	var weights: Array[float] = [0.2126, 0.7152, 0.0722]
	var channels: Array[float] = [c.r, c.g, c.b]
	for n: int in 3:
		var v: float = channels[n]
		v = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += weights[n] * v
	return out


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


func _summary() -> void:
	super._summary()
	print("\n  %d buttons judged in %d windows and panels, %d not seen or read" % [_buttons,
		_windows, _failing])
