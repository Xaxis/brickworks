## Views kept with the model (APP_UX5 #8, savedviews): where the window looks
## from, saved by a name and kept in the model's file, as StudWorx and
## Studio's Eyesight keep camera presets. The same angles were set up again
## after every change.
##
## A view is the camera's own words (CadCamera.aim): its turn round the
## model's up, its tilt, how far it stands from what it looks at and that
## point, the turn of the whole view when Build it had turned it over, and
## whether it was square on (View, Orthographic) and how wide then. It is put
## back by the camera's own calls (CadCamera.aim_at, square_on), so the window
## eases to it as to any view, and cad_camera.gd knows nothing of it.
##
## The world holds them in the window's coordinates (BrickWorld.saved_views).
## The model's file keeps each as a line LDraw readers pass over
## ([constant META]), in the file's coordinates, as the cut is kept
## (CutShape): they come back when the file opens, the parts are never
## changed, and an older Brickworks opens the file whole and passes over them.
##
## The first nine have a key each (Shell's saved_view_1 to 9, View ›
## Viewpoint: Alt-Shift and the digit, beside the digits alone, which are the
## eight views every model has). Render's Camera lists them, the render queue
## draws each (Render each saved view), and a session asks for one by its
## name: view_model's and render_model's view= (Assistant, AppTools).
##
## This is also View › Viewpoint › Save this view…: a name asked for, and the
## model's views listed under it, each to look from or to take out.
class_name SavedViews
extends ConfirmationDialog

## A view's line in the model's file: JSON, in the file's coordinates (LDraw's:
## y down, z towards the viewer, the model where the file has it):
##   {"name": "Cockpit", "yaw": 0.61, "pitch": 0.45, "distance": 412.0,
##    "focus": [10.0, -24.0, 0.0], "square": false}
## yaw is the turn round the model's up from its front and pitch the tilt up
## from level, in radians, as the window's camera has them; distance and focus
## in LDU. A view square on has its "size", the height it shows, in LDU; one
## Build it had turned over its "frame", that turn as a quaternion.
const META := "0 !BRICKWORKS VIEW "
## The views with a key each: Alt-Shift and 1 to 9.
const KEYED := 9
## The longest name a view keeps.
const LONGEST := 60
## The command that looks from the view at a place, from 0: Shell's.
const COMMAND := "saved_view_"


# -- kept with the model --------------------------------------------------------


## The views [param text] keeps, in its order, as [method written_into] wrote
## them (the file's coordinates).
static func read(text: String) -> Array:
	return read_from(MetaIndex.of_text(text))


## The views the model's own lines keep (MetaIndex: a sub-model's views are
## its own, and stay in it), in their order, each line read taken. A line
## this cannot read, a newer build's say, stays in the file as it is, where
## it is (MetaIndex.lines_for), and is said ([method unread_words]); up to
## metalines a save left it out, unsaid. A view of a name an earlier one has
## is beaten (MetaIndex.Line.beaten): kept while the views are as the open
## read them, and let go once they change, or it came back as the view of
## that name once the first was taken out (mlcheck F2).
static func read_from(metas: MetaIndex) -> Array:
	var out: Array = []
	var taken: Dictionary = {}
	for line: MetaIndex.Line in metas.own(["VIEW"]):
		var view: Dictionary = _parsed(line.said)
		if view.is_empty():
			continue
		if taken.has(_key(view["name"])):
			line.beaten = true
			continue
		taken[_key(view["name"])] = true
		line.taken = true
		out.append(view)
	return out


## The lines [param views] (the file's coordinates) are kept on, in their
## order.
static func lines_of(views: Array) -> PackedStringArray:
	var lines := PackedStringArray()
	for view: Dictionary in views:
		lines.append(META + JSON.stringify(view))
	return lines


## [param unread], view lines an open could not read, and [param beaten],
## those of a name an earlier line has, in words for where an open says
## what it kept: "1 view line not read, kept in the file as it is"; "" for
## none. One of a name another has is kept only until the views change.
static func unread_words(unread: PackedStringArray,
		beaten: PackedStringArray = PackedStringArray()) -> String:
	var said := PackedStringArray()
	if not unread.is_empty():
		said.append("1 view line not read, kept in the file as it is" if unread.size() == 1
			else "%d view lines not read, kept in the file as they are" % unread.size())
	if not beaten.is_empty():
		said.append(("1 view line names a view an earlier one has: not read, and kept "
			+ "until the views change") if beaten.size() == 1 else ("%d view lines name "
			+ "views earlier ones have: not read, and kept until the views change") % beaten.size())
	return " — ".join(said)


## [param text] with [param views] (the file's coordinates) written into it
## (MetaIndex): each its main model has that says one kept where it is, the
## rest under its first line, and any it had that is not one taken out. A
## sub-model's lines are left as they are: up to 2026-11-07 a view kept in
## one was moved into the main model at the first save (lreview).
static func written_into(text: String, views: Array) -> String:
	return MetaIndex.written(text, [MetaIndex.family(["VIEW"], lines_of(views))])


## [param views] as the window holds them, in the file's coordinates: the
## model stood [param lift] up from where its file has it (ModelStore.lift).
static func in_file(views: Array, lift: Vector3) -> Array:
	var out: Array = []
	for view: Dictionary in views:
		out.append(_with_focus(view, (focus_of(view) - lift) * LdrModel.FLIP))
	return out


## [param views] as a file keeps them, in the window's coordinates: the
## model stood [param lift] up from where its file has it.
static func placed(views: Array, lift: Vector3) -> Array:
	var out: Array = []
	for view: Dictionary in views:
		out.append(_with_focus(view, focus_of(view) * LdrModel.FLIP + lift))
	return out


## [param views] with every point looked at moved [param by]: the model they
## look at stood lower or higher once its parts arrived (ModelStore._settle).
static func moved(views: Array, by: Vector3) -> Array:
	var out: Array = []
	for view: Dictionary in views:
		out.append(_with_focus(view, focus_of(view) + by))
	return out


## A sub-model's view [param line] carried by [param through], from the file's
## coordinates of one frame of its definition to another's (Assemblies
## .rebased): the point it looks at, and the way it looks turned with it, a
## turn about the model's up as its yaw and any other as its frame. A
## reflection (a mirrored copy's frame) is a mirror across the x axis and
## then a turn: the view looks the mirrored way, its yaw the other way round
## and its frame mirrored, from the mirrored place; up to 2026-11-11 only its
## point was carried, and it looked the way it had (pccheck FW, FX). A line
## this cannot read is as it was.
static func through_line(line: String, through: Transform3D) -> String:
	if not line.begins_with(META):
		return line
	var view: Dictionary = _parsed(line.substr(META.length()).strip_edges())
	if view.is_empty():
		return line
	var out: Dictionary = _with_focus(view, through * focus_of(view))
	var flip: Basis = Basis.from_scale(LdrModel.FLIP)
	var turn: Basis = (flip * through.basis * flip).orthonormalized()
	var yaw: float = float(view["yaw"])
	var own: Basis = _frame_of(view)
	if turn.determinant() < 0.0:
		var across := Basis.from_scale(Vector3(-1.0, 1.0, 1.0))
		turn = turn * across
		yaw = -yaw
		own = across * own * across
		out["yaw"] = snappedf(yaw, 0.000001)
		if view.has("frame"):
			out["frame"] = _quaternion_words(own.get_rotation_quaternion())
	if not turn.is_equal_approx(Basis.IDENTITY):
		if not view.has("frame") and (turn * Vector3.UP).is_equal_approx(Vector3.UP):
			var ahead: Vector3 = turn * Vector3.BACK
			out["yaw"] = snappedf(yaw + atan2(ahead.x, ahead.z), 0.000001)
		else:
			out["frame"] = _quaternion_words((turn * own).get_rotation_quaternion())
	return META + JSON.stringify(out)


static func _quaternion_words(q: Quaternion) -> Array:
	return [snappedf(q.x, 0.000001), snappedf(q.y, 0.000001), snappedf(q.z, 0.000001),
		snappedf(q.w, 0.000001)]


## Whether [param a] and [param b] are the same views, to a hundredth of an
## LDU and a ten-thousandth of a radian: what a file keeps of them is rounded.
static func same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for n: int in a.size():
		var one: Dictionary = a[n]
		var other: Dictionary = b[n]
		if str(one["name"]) != str(other["name"]) \
				or bool(one.get("square", false)) != bool(other.get("square", false)) \
				or focus_of(one).distance_to(focus_of(other)) > 0.01:
			return false
		for field: String in ["yaw", "pitch", "distance", "size"]:
			var tolerance: float = 0.0001 if field in ["yaw", "pitch"] else 0.01
			if absf(float(one.get(field, 0.0)) - float(other.get(field, 0.0))) > tolerance:
				return false
		if _frame_of(one).get_rotation_quaternion().angle_to(
				_frame_of(other).get_rotation_quaternion()) > 0.0001:
			return false
	return true


## Where [param name] is among [param views], whatever its capitals; -1 when
## it is not one of them. A name a session sent in quotes, as a refusal or
## in_view writes them (“Plan”), is that name when no view has the quotes
## in its own (Quotes.off, APP_UX6 mcpsee3).
static func index_of(views: Array, name: String) -> int:
	for wanted: String in [_key(name), _key(Quotes.off(name))]:
		for n: int in views.size():
			if _key((views[n] as Dictionary)["name"]) == wanted:
				return n
	return -1


## Their names, in order.
static func names(views: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for view: Dictionary in views:
		out.append(str(view["name"]))
	return out


## [param views] in words for a session (in_view, APP_UX6 mcpsee3): each by
## its name, with its key, in their order; or that the model keeps none.
static func listed(views: Array) -> String:
	if views.is_empty():
		return ("No views are saved with the model; save_view keeps the window's view by a "
			+ "name, as %s does." % Keymap.menu_row("save_view"))
	var each := PackedStringArray()
	for n: int in views.size():
		var key: String = Keymap.written(COMMAND + str(n + 1)) if n < KEYED else ""
		each.append("“%s”%s" % [str((views[n] as Dictionary)["name"]),
			" (%s)" % key if not key.is_empty() else ""])
	return ("%s saved with the model: %s. view_model, render_model and render_queue take each "
		% ["One view is" if views.size() == 1 else "%d views are" % views.size(), ", ".join(each)]
		+ "by its name as view=; save_view keeps the window's view by a name.")


## Why [param name] was looked for among [param views] and not found, in
## words for a session or the status bar, naming those there are.
static func not_kept(views: Array, name: String) -> String:
	if views.is_empty():
		return ("No view called “%s” is saved with the model: it keeps none. %s keeps one."
			% [name, Keymap.menu_row("save_view")])
	var quoted := PackedStringArray()
	for each: String in names(views):
		quoted.append("“%s”" % each)
	var last: String = quoted[quoted.size() - 1]
	quoted.remove_at(quoted.size() - 1)
	return "No view called “%s” is saved with the model. It keeps %s." % [name,
		last if quoted.is_empty() else "%s and %s" % [", ".join(quoted), last]]


# -- the camera, through its own calls ----------------------------------------------


## The window's view now as [param camera] has it, kept as [param name], in
## the window's coordinates: its own words (CadCamera.aim), rounded as finely
## as a file keeps them.
static func of_camera(camera: CadCamera, name: String) -> Dictionary:
	var aim: Dictionary = camera.aim()
	var focus: Array = aim["focus"]
	var view: Dictionary = {"name": name, "yaw": snappedf(float(aim["yaw"]), 0.000001),
		"pitch": snappedf(float(aim["pitch"]), 0.000001),
		"distance": snappedf(float(aim["distance"]), 0.001),
		"focus": [snappedf(float(focus[0]), 0.001), snappedf(float(focus[1]), 0.001),
			snappedf(float(focus[2]), 0.001)],
		"square": camera.is_square_on()}
	if camera.is_square_on():
		view["size"] = snappedf(camera.size, 0.001)
	if aim.has("frame"):
		view["frame"] = aim["frame"]
	return view


## [param camera] sent to look from [param view], as the window eases to any
## view: square on or not as it was, then its turn, tilt, distance and focus.
static func look_from(camera: CadCamera, view: Dictionary) -> void:
	camera.square_on(bool(view.get("square", false)))
	var focus: Vector3 = focus_of(view)
	var aim: Dictionary = {"yaw": float(view["yaw"]), "pitch": float(view["pitch"]),
		"distance": float(view["distance"]), "focus": [focus.x, focus.y, focus.z],
		"size": float(view.get("size", 0.0))}
	if view.has("frame"):
		aim["frame"] = view["frame"]
	camera.aim_at(aim)


## Where the eye is, and which way it looks, from [param view]: where
## [param camera] comes to rest sent there ([method look_from]), worked out
## as the camera works out its own pose (CadCamera._apply), so a render of
## the view is drawn from there without the window turning to it. Its limits
## are [param camera]'s; the camera itself is left as it is.
static func eye_of(view: Dictionary, camera: Camera3D = null) -> Transform3D:
	var yaw: float = float(view["yaw"])
	var pitch: float = clampf(float(view["pitch"]), -deg_to_rad(89.0), deg_to_rad(89.0))
	var least: float = 8.0
	var most: float = 40000.0
	if camera is CadCamera:
		least = (camera as CadCamera).min_distance
		most = (camera as CadCamera).max_distance
	var distance: float = clampf(float(view["distance"]), least, most)
	var focus: Vector3 = focus_of(view)
	var frame: Basis = _frame_of(view)
	var offset := Vector3(cos(pitch) * sin(yaw), sin(pitch), cos(pitch) * cos(yaw)) * distance
	var at: Vector3 = focus + frame * offset
	return Transform3D(Basis.looking_at(focus - at, frame * Vector3.UP), at)


## The point [param view] looks at.
static func focus_of(view: Dictionary) -> Vector3:
	var focus: Array = view["focus"]
	return Vector3(float(focus[0]), float(focus[1]), float(focus[2]))


static func _frame_of(view: Dictionary) -> Basis:
	var turn: Variant = view.get("frame")
	if not turn is Array or (turn as Array).size() != 4:
		return Basis.IDENTITY
	var q := Quaternion(float(turn[0]), float(turn[1]), float(turn[2]), float(turn[3]))
	return Basis(q.normalized()) if q.length() > 0.5 else Basis.IDENTITY


static func _with_focus(view: Dictionary, focus: Vector3) -> Dictionary:
	var out: Dictionary = view.duplicate(true)
	out["focus"] = [snappedf(focus.x, 0.001), snappedf(focus.y, 0.001), snappedf(focus.z, 0.001)]
	return out


static func _key(name: Variant) -> String:
	return str(name).strip_edges().to_lower()


## A view's line read back: every number a number, finite and in reason,
## the name a name. Empty for anything else: a file is anybody's to edit.
static func _parsed(said: String) -> Dictionary:
	var raw: Variant = JSON.parse_string(said)
	if not raw is Dictionary:
		return {}
	var given: Dictionary = raw
	var name: String = clean_name(str(given.get("name", "")))
	if name.is_empty() or not given.get("name") is String:
		return {}
	var view: Dictionary = {"name": name}
	for field: String in ["yaw", "pitch", "distance"]:
		if not _number(given.get(field)):
			return {}
		view[field] = float(given[field])
	if float(view["distance"]) <= 0.0:
		return {}
	var focus: Variant = given.get("focus")
	if not focus is Array or (focus as Array).size() != 3 \
			or not (focus as Array).all(func(n: Variant) -> bool: return _number(n)):
		return {}
	view["focus"] = [float(focus[0]), float(focus[1]), float(focus[2])]
	view["square"] = given.get("square", false) is bool and bool(given.get("square", false))
	if view["square"]:
		if not _number(given.get("size")) or float(given["size"]) <= 0.0:
			return {}
		view["size"] = float(given["size"])
	var turn: Variant = given.get("frame")
	if turn is Array and (turn as Array).size() == 4 \
			and (turn as Array).all(func(n: Variant) -> bool: return _number(n)) \
			and Quaternion(float(turn[0]), float(turn[1]), float(turn[2]),
				float(turn[3])).length() > 0.5:
		view["frame"] = [float(turn[0]), float(turn[1]), float(turn[2]), float(turn[3])]
	return view


static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) \
		and absf(float(value)) < 1e7


## [param name] as a view keeps it: on one line, without spaces at its ends,
## at most [constant LONGEST] letters.
static func clean_name(name: String) -> String:
	return name.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges() \
		.left(LONGEST).strip_edges()


# -- View › Viewpoint: saving one, looking from one, taking one out -------------------


## The model's views, as the window holds them.
var world: BrickWorld
var camera: CadCamera
## Said on the status bar (ModelBar.say).
var say: Callable = func(_words: String) -> void: pass
## Told when the views change, for the model's autosave (ModelStore.touch).
var changed: Callable = func() -> void: pass

var _name: LineEdit
var _list: VBoxContainer
var _note: Label


func _init() -> void:
	title = "Save this view"
	ok_button_text = "Save"
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var asking := Label.new()
	asking.text = "What should this view be called?"
	column.add_child(asking)
	_name = LineEdit.new()
	_name.accessibility_name = "Name of the view"
	_name.custom_minimum_size = Vector2(340, 0)
	_name.max_length = LONGEST
	_name.text_submitted.connect(func(_text: String) -> void:
		hide()
		save_now(_name.text))
	column.add_child(_name)
	_note = Label.new()
	_note.add_theme_font_size_override("font_size", 12)
	_note.modulate = Color(1, 1, 1, 0.7)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(340, 0)
	column.add_child(_note)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 2)
	column.add_child(_list)
	add_child(column)
	confirmed.connect(func() -> void: save_now(_name.text))


## Ask for a name for the window's view now, the model's views listed under it.
func ask() -> void:
	_name.text = _free_name()
	_fill()
	popup_centered()
	_name.grab_focus()
	_name.select_all()


## Keep the window's view now as [param name]: a view of that name already
## kept is replaced where it is, keeping its key. What was said.
func save_now(name: String) -> String:
	var called: String = clean_name(name)
	if called.is_empty() or world == null or camera == null:
		return ""
	var views: Array = world.saved_views.duplicate()
	var at: int = index_of(views, called)
	var view: Dictionary = of_camera(camera, called)
	if at >= 0:
		views[at] = view
	else:
		views.append(view)
		at = views.size() - 1
	# A new array each time: the autosave may be reading the one before.
	world.saved_views = views
	Language.keep_name(called)
	changed.call()
	var words: String = "kept the view “%s” with the model" % called
	if at < KEYED:
		words += Keymap.filled(" — {%s%d|looks from it again}" % [COMMAND, at + 1])
	say.call(words)
	if visible:
		_fill()
	return words


## Look from the view at [param index], from 0, as it was saved. False when
## the model keeps no view there.
func go(index: int) -> bool:
	if world == null or camera == null or index < 0 or index >= world.saved_views.size():
		return false
	var view: Dictionary = world.saved_views[index]
	look_from(camera, view)
	say.call("the view “%s”" % str(view["name"]))
	return true


## Take the view called [param name] out of the model: those after it each
## take the key before. False when there is none of that name.
func remove(name: String) -> bool:
	var views: Array = world.saved_views.duplicate()
	var at: int = index_of(views, name)
	if at < 0:
		return false
	var called: String = str((views[at] as Dictionary)["name"])
	views.remove_at(at)
	world.saved_views = views
	changed.call()
	say.call("took the view “%s” out of the model%s" % [called,
		"; those after it each have the key before" if at < views.size() and at < KEYED else ""])
	if visible:
		_fill()
	return true


## A name no view has: View 1, View 2...
func _free_name() -> String:
	var views: Array = world.saved_views if world != null else []
	for n: int in range(1, 1000):
		var name: String = tr("View %d") % n
		if index_of(views, name) < 0:
			return name
	return ""


## The model's views under the name: each with its key, Look from and Remove.
func _fill() -> void:
	for row: Node in _list.get_children():
		row.queue_free()
	var views: Array = world.saved_views if world != null else []
	_note.text = ("A view of the same name is replaced. Each of the first nine has a key, "
		+ "and Render's Camera lists them all.") if not views.is_empty() \
		else "Kept with the model, the first nine each with a key, and in Render's Camera."
	for n: int in views.size():
		var called: String = str((views[n] as Dictionary)["name"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = called
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(label)
		var key := Label.new()
		key.text = Keymap.written(COMMAND + str(n + 1)) if n < KEYED else ""
		key.modulate = Color(1, 1, 1, 0.6)
		key.add_theme_font_size_override("font_size", 12)
		row.add_child(key)
		var index: int = n
		row.add_child(_small("Look from it", func() -> void: go(index),
			"Look from this view now"))
		row.add_child(_small("Remove", func() -> void: remove(called),
			"Take this view out of the model"))
		_list.add_child(row)


func _small(words: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	return button
