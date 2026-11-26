## Nothing of the studio's chrome is wider than the window, in English,
## German, French and Spanish, at 100% and 150% text (wide150, from
## wingreview3's F3 and F5). In each language at each size, through a part in
## hand, puts and undos on the ground and inside a sub-assembly, the step bar
## and the side panels open:
## - the window's column is never wider than the window, in any frame;
## - every control shown lies inside the window (what a scroller clips is
##   not shown);
## - no line is cut inside a word: a label or a button narrower than its words
##   cuts them at a word or wraps them, and a word of its own fits;
## - the model's room is one height through the puts and undos.
##
##   godot --path . --resolution 390x844 --script src/dev/wide150_probe.gd -- [--phone] [--w150langs=en,de] [--w150sizes=1.0,1.5] [--pictures=DIR]
##
## The window's size is the run's (PROBE_SIZE=320x700 tools/probe.sh
## wide150_probe): Xvfb has no window manager to resize it. --phone lays the
## studio out for a finger, as a browser on a phone gets it; a window 600 or
## more across is a tablet's, laid out wide. The language and the interface
## size are changed as Settings changes them, so one run covers all eight.
## --pictures= keeps a picture of each, viewport-clipped, inside the
## sub-assembly with Redo offered: the widest the chrome is asked to be.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _store: ModelStore
var _verbs: EditVerbs
var _shell: Shell
var _tree: Assemblies
var _bin: PartsBin
var _column: Control
var _phone: bool = false
var _pictures: String = ""
## What is being done, for a line that fails.
var _doing: String = ""
var _config: String = ""
## Each frame's watch: the column wider than the window, and the room's height.
var _watching: bool = false
var _wide_frames: int = 0
var _widest: float = 0.0
var _room_watch: bool = false
var _heights: Dictionary = {}
## What failed in each configuration, for the matrix at the end.
var _matrix: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
		_matrix[_config] = int(_matrix.get(_config, 0)) + 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var langs: PackedStringArray = ["en", "de", "fr", "es"]
	var sizes: Array[float] = [1.0, 1.5]
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--phone":
			_phone = true
		elif argument.begins_with("--w150langs="):
			langs = argument.trim_prefix("--w150langs=").split(",")
		elif argument.begins_with("--w150sizes="):
			sizes.clear()
			for one: String in argument.trim_prefix("--w150sizes=").split(","):
				sizes.append(float(one))
		elif argument.begins_with("--pictures="):
			_pictures = argument.trim_prefix("--pictures=")
	var window_px: Vector2i = DisplayServer.window_get_size()
	if _phone:
		# As a browser on a phone or a tablet lays it out (Phone._wanted):
		# a short side under 600 points is a phone's, more a tablet's.
		Phone._on = 1
		Phone._wide = mini(window_px.x, window_px.y) >= int(Phone.NARROW)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_store = _main.get("_store")
	_verbs = _main.get("_verbs")
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	_tree = _shell.assemblies
	_column = (_main.get("_bar") as Control).get_parent() as Control
	_main.call("clear_model")
	Carry.clipboard = []
	var layout: String = ("tablet" if Phone._wide else "phone") if _phone else "desktop"
	print("  wide150: %s, a %dx%d window" % [layout, window_px.x, window_px.y])

	# A wing of two parts on a plate, made a sub-assembly and copied: inside
	# it the banner says the copy follows, and a put says the copy's words,
	# the longest lines the chrome is given (room390, wingreview3).
	_put("3001", 1, Vector3(0, 24, 0))
	_put("3034", 14, Vector3(-100, 8, -40))
	_put("3004", 4, Vector3(-120, 32, -40))
	await _frames(3)
	_select_only([_world.bricks()[1].id, _world.bricks()[2].id])
	await _key(KEY_G, true)
	_verbs._name_field.text = "Wing"
	_verbs._naming.hide()
	_verbs._naming.confirmed.emit()
	await _frames(3)
	_select_only(Array(_tree.ids_under("Wing#1")))
	await _key(KEY_D, true)
	await _frames(3)
	_builder.clear_selection()
	await _key(KEY_ESCAPE)
	_check("a wing and its copy (%s)" % str(_tree.paths()), _tree.ids_under("Wing#2").size() == 2)
	_check("saved as Wide probe", _store.save_as("Wide probe"))
	process_frame.connect(_watch)

	for lang: String in langs:
		for size: float in sizes:
			await _one(lang, size, layout, window_px)

	print("")
	print("  the matrix (%s, %dx%d): FAILs in each language at each size" % [layout, window_px.x, window_px.y])
	for lang: String in langs:
		var line: PackedStringArray = []
		for size: float in sizes:
			var key: String = "%s %d%%" % [lang, roundi(size * 100.0)]
			line.append("%s %d" % [key, int(_matrix.get(key, 0))])
		print("    " + "   ".join(line))
	print("")
	if _failures == 0:
		print("wide150: nothing is wider than the window, no word is cut, the room holds still")
	else:
		print("wide150: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## One language at one size: set as Settings sets them, then the studio
## walked through what widens its rows.
func _one(lang: String, size: float, layout: String, window_px: Vector2i) -> void:
	_config = "%s %d%%" % [lang, roundi(size * 100.0)]
	Language.choose(lang)
	ShellPrefs.put("interface_size", size)
	_main.call("_match_screen_density")
	await _frames(30)
	_camera.frame(AABB(Vector3(-240, 0, -200), Vector3(480, 80, 360)), 1.6)
	await _frames(20)
	print("")
	print("  -- %s, %s, %dx%d: the window %s units" % [_config, layout, window_px.x, window_px.y,
		str(root.get_visible_rect().size)])
	_wide_frames = 0
	_widest = 0.0
	_watching = true
	_doing = "at rest"
	await _fits()

	# A part in hand, put down and undone on the ground: the room one height.
	_heights.clear()
	_room_watch = true
	_bin._on_part("3023")
	await _frames(10)
	_doing = "a part in hand"
	await _move(_screen(Vector3(60, 0, 60)))
	await _frames(5)
	await _fits()
	var spots: Array = [Vector3(60, 0, 60), Vector3(100, 0, -60), Vector3(-40, 0, 100)]
	var puts: int = 0
	for n: int in spots.size():
		var depth: int = _builder.history_depth()
		var at: Vector2 = _screen(spots[n])
		_doing = "put %d" % n
		await _move(at)
		await _move(at + Vector2(1, 0))
		await _click(at + Vector2(1, 0))
		await _frames(20)
		if _builder.history_depth() > depth:
			puts += 1
		if n == 0:
			await _fits()
		_doing = "undo %d" % n
		await _key(KEY_Z, true)
		await _frames(20)
	_doing = "Redo offered"
	await _fits()
	_room_watch = false
	_check("%s: puts made on the ground (%d of %d)" % [_config, puts, spots.size()], puts >= 2)
	_check("%s: the room is one height through the puts and undos (%s)" % [_config, str(_heights)],
		_heights.size() == 1)
	await _key(KEY_ESCAPE)
	await _key(KEY_ESCAPE)

	# Inside the wing: the banner says its copy follows; a put there, undone,
	# leaves Redo offered.
	_verbs.assemblies.enter("Wing#1")
	await _frames(10)
	_bin._on_part("3023")
	await _frames(10)
	var inside: Vector2 = _screen(Vector3(-60, 8, -40))
	_doing = "put inside the wing"
	await _move(inside)
	await _move(inside + Vector2(1, 0))
	await _click(inside + Vector2(1, 0))
	await _frames(20)
	await _fits()
	_doing = "undo inside the wing"
	await _key(KEY_Z, true)
	await _frames(20)
	await _fits()
	await _shot("%s_%dx%d_%s_%d" % [layout, window_px.x, window_px.y, lang, roundi(size * 100.0)])
	await _key(KEY_ESCAPE)
	_verbs.assemblies.leave_to("")
	await _frames(10)

	# The step bar.
	_doing = "the step bar open"
	var stem: String = "%s_%dx%d_%s_%d" % [layout, window_px.x, window_px.y, lang, roundi(size * 100.0)]
	await _shell.run("timeline")
	await _frames(40)
	await _fits()
	await _shot(stem + "_steps")
	await _shell.run("timeline")
	await _frames(20)

	# The side panels.
	if _phone:
		var phone: PhoneShell = _main.get("_phone")
		for what: String in ["parts", "more"]:
			_doing = "the %s sheet open" % what
			phone._chose(what)
			await _frames(40)
			await _fits()
			await _shot(stem + "_" + what)
			phone._chose(what)
			await _frames(30)
	else:
		for dock_name: String in ["_bin_dock", "_chat_dock"]:
			var dock: SideDock = _main.get(dock_name)
			if dock == null or not dock.is_visible_in_tree():
				continue
			var was: bool = dock.is_open()
			_doing = "%s %s" % [dock_name.trim_prefix("_"), "closed" if was else "open"]
			dock.set_open(not was, false)
			await _frames(30)
			await _fits()
			await _shot(stem + "_" + dock_name.trim_prefix("_"))
			dock.set_open(was, false)
			await _frames(20)
	_watching = false
	_check("%s: the window's column is never wider than the window (%d frames wider, the widest %.0f in %.0f)"
		% [_config, _wide_frames, _widest, root.get_visible_rect().size.x], _wide_frames == 0)


## Every control shown inside the window, and no line cut inside a word.
func _fits() -> void:
	await _frames(2)
	var window: Rect2 = root.get_visible_rect()
	var outside: Dictionary = {}
	var cut: PackedStringArray = []
	var seen: int = 0
	for found: Node in _main.find_children("*", "Control", true, false):
		var c: Control = found as Control
		if c.get_viewport() != root or not c.is_visible_in_tree():
			continue
		var shown: Rect2 = _shown(c)
		if shown.size.x < 0.5 or shown.size.y < 0.5:
			continue
		seen += 1
		if shown.position.x < window.position.x - 0.5 or shown.end.x > window.end.x + 0.5 \
				or shown.position.y < window.position.y - 0.5 or shown.end.y > window.end.y + 0.5:
			outside[c] = shown
		var why: String = _cut(c, shown)
		if not why.is_empty():
			cut.append(why)
		# What a clipping box (a side panel's holder, a scroller) holds wider
		# than itself, and why, for the lines its cut words make.
		if c.clip_contents and not (c is ScrollContainer and (c as ScrollContainer).horizontal_scroll_mode
				!= ScrollContainer.SCROLL_MODE_DISABLED):
			for child: Node in c.get_children():
				var held: Control = child as Control
				if held != null and held.is_visible_in_tree() and not held.top_level \
						and held.get_combined_minimum_size().x > c.size.x + 0.5:
					print("    (%s, %s: %s %.0f wide holds %s %.0f%s)" % [_config, _doing, _named(c), c.size.x,
						_named(held), held.get_combined_minimum_size().x, _widest_inside(held, 5)])
	# Named by the innermost: a row past the edge puts its column past it too,
	# and the row is what gives way or does not.
	var past: PackedStringArray = []
	for c: Control in outside:
		var inner: bool = true
		for child: Node in c.get_children():
			if outside.has(child):
				inner = false
				break
		if inner:
			var shown: Rect2 = outside[c]
			past.append("%s x%.1f-%.1f y%.1f-%.1f" % [_named(c), shown.position.x, shown.end.x,
				shown.position.y, shown.end.y])
			# What holds it so: its least and its children's.
			var held: PackedStringArray = []
			for child: Node in c.get_children():
				if child is Control and (child as Control).is_visible_in_tree():
					held.append("%s %s" % [_named(child as Control), (child as Control).get_combined_minimum_size()])
			print("    (%s, %s: %s least %s holds %s;%s)" % [_config, _doing, _named(c), c.get_combined_minimum_size(),
				", ".join(_most(PackedStringArray(held))), _widest_inside(c, 8)])
	_check("%s, %s: %d controls shown, every one inside the %.1f x %.1f window%s" % [_config, _doing,
		seen, window.size.x, window.size.y, "" if past.is_empty() else
		" — past it: " + "; ".join(_most(past))], past.is_empty())
	_check("%s, %s: no line cut inside a word%s" % [_config, _doing, "" if cut.is_empty() else
		" — " + "; ".join(_most(cut))], cut.is_empty())


func _most(lines: PackedStringArray) -> PackedStringArray:
	if lines.size() <= 8:
		return lines
	var out: PackedStringArray = lines.slice(0, 8)
	out.append("and %d more" % (lines.size() - 8))
	return out


## The part of [param c] drawn: its rect inside every ancestor that clips
## what it holds (a scroller's own).
func _shown(c: Control) -> Rect2:
	var rect: Rect2 = c.get_global_rect()
	var up: Node = c.get_parent()
	while up != null and up is CanvasItem:
		var holder: Control = up as Control
		if holder != null and holder.clip_contents:
			rect = rect.intersection(holder.get_global_rect())
			if rect.size.x <= 0.0 or rect.size.y <= 0.0:
				return Rect2()
		up = up.get_parent()
	return rect


## Why [param c]'s words are cut inside a word, or "": a label or a button
## whose words are wider than the room it draws them in, cut short by
## letters or clipped, or a word of its own wider than that room.
func _cut(c: Control, shown: Rect2) -> String:
	var text: String = ""
	var overrun: int = TextServer.OVERRUN_NO_TRIMMING
	var wraps: bool = false
	var room: float = 0.0
	var font: Font
	var font_size: int
	if c is Label:
		var label: Label = c as Label
		if label.text.is_empty() or label.visible_ratio < 1.0:
			return ""
		text = label.atr(label.text)
		overrun = label.text_overrun_behavior
		wraps = label.autowrap_mode != TextServer.AUTOWRAP_OFF
		# Wrapped onto more lines than it shows, its last line is cut short:
		# by letters ("1×2 avec rai…") unless at a word.
		if wraps and label.get_line_count() > label.get_visible_line_count() \
				and overrun != TextServer.OVERRUN_TRIM_WORD and overrun != TextServer.OVERRUN_TRIM_WORD_ELLIPSIS:
			return "%s: \"%s\" wrapped onto %d lines, %d shown, cut by letters" % [_named(c),
				text.replace("\n", " ").left(40), label.get_line_count(), label.get_visible_line_count()]
		if label.uppercase:
			text = text.to_upper()
		room = label.size.x - label.get_theme_stylebox("normal").get_minimum_size().x
		font = label.get_theme_font("font")
		font_size = label.get_theme_font_size("font_size")
	elif c is Button:
		var button: Button = c as Button
		if button.text.is_empty():
			return ""
		text = button.atr(button.text)
		overrun = button.text_overrun_behavior
		wraps = button.autowrap_mode != TextServer.AUTOWRAP_OFF
		# Inside the face it is drawn with now: a disabled button's is the
		# theme's, its margins narrower than the face it has when pressable.
		var face: String = "disabled" if button.disabled else ("pressed" if button.button_pressed
			else "normal")
		room = button.size.x - button.get_theme_stylebox(face).get_minimum_size().x
		# Its picture takes from the words' width only beside them: over or
		# under them (a phone's row), or centred under them, it does not.
		if button.icon != null and not button.expand_icon \
				and button.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER \
				and button.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
			room -= button.icon.get_width() + button.get_theme_constant("h_separation")
		font = button.get_theme_font("font")
		font_size = button.get_theme_font_size("font_size")
	else:
		return ""
	# Past the window's edge or a scroller's, words are cut there too.
	room = minf(room, room - (c.get_global_rect().size.x - shown.size.x))
	# Each line its own: a name set on two lines is as wide as its wider.
	var whole: float = 0.0
	for line: String in text.split("\n"):
		whole = maxf(whole, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	if whole <= room + 1.0:
		return ""
	var longest: float = 0.0
	var long_word: String = ""
	for word: String in text.replace("\n", " ").split(" ", false):
		var w: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w > longest:
			longest = w
			long_word = word
	var at_words: bool = wraps or overrun == TextServer.OVERRUN_TRIM_WORD \
		or overrun == TextServer.OVERRUN_TRIM_WORD_ELLIPSIS
	if at_words and longest <= room + 1.0:
		return ""
	if at_words:
		return "%s: \"%s\" a word wider than its room (%.0f in %.0f)" % [_named(c), long_word, longest, room]
	return "%s: \"%s\" (%.0f in %.0f; %.0f wide, its least %.0f, %d-unit type)" % [_named(c),
		text.left(40), whole, room, c.size.x, c.get_combined_minimum_size().x, font_size]


func _named(c: Control) -> String:
	var out: String = str(c.name)
	var up: Node = c.get_parent()
	for _n: int in 6:
		if up == null or up == _main:
			break
		var script: Script = up.get_script()
		if script != null and not script.get_global_name().is_empty():
			return "%s/%s" % [script.get_global_name(), out.left(24)]
		up = up.get_parent()
	return "%s(%s)" % [out.left(24), c.get_class()]


## Each frame: the column's width, and the room's height while puts and
## undos are watched.
func _watch() -> void:
	if not _watching:
		return
	var across: float = root.get_visible_rect().size.x
	if _column.size.x > across + 0.5:
		_wide_frames += 1
		if _column.size.x > _widest:
			_widest = _column.size.x
			print("    (%s, %s: the column %.0f wide in %.0f: %s)" % [_config, _doing, _column.size.x,
				across, _widest_rows()])
	if _room_watch:
		var h: float = snappedf((_main.call("_model_rect") as Rect2).size.y, 0.1)
		_heights[h] = int(_heights.get(h, 0)) + 1


## Which rows of the column ask for more than the window, each its least.
func _widest_rows() -> String:
	var across: float = root.get_visible_rect().size.x
	var out: PackedStringArray = []
	for found: Node in _column.find_children("*", "Control", true, false):
		var c: Control = found as Control
		if c.is_visible_in_tree() and c.get_combined_minimum_size().x > across + 0.5 \
				and c.get_combined_minimum_size().x <= _column.size.x + 0.5:
			var kids: bool = false
			for child: Node in c.get_children():
				if child is Control and (child as Control).is_visible_in_tree() \
						and (child as Control).get_combined_minimum_size().x > across + 0.5:
					kids = true
			if not kids:
				out.append("%s %.0f%s" % [_named(c), c.get_combined_minimum_size().x, _widest_inside(c, 4)])
	return ", ".join(_most(out))


## The widest few shown inside [param c], by their least, and inside the
## widest of them in turn: what asks for the width.
func _widest_inside(c: Control, depth: int) -> String:
	if depth <= 0:
		return ""
	var kids: Array[Control] = []
	for child: Node in c.get_children():
		if child is Control and (child as Control).is_visible_in_tree():
			kids.append(child as Control)
	if kids.is_empty():
		return ""
	kids.sort_custom(func(a: Control, b: Control) -> bool:
		return a.get_combined_minimum_size().x > b.get_combined_minimum_size().x)
	var parts: PackedStringArray = []
	for kid: Control in kids.slice(0, 4):
		var said: String = ""
		if kid is Label:
			said = " \"%s\"" % (kid as Label).text.left(24)
		elif kid is Button:
			said = " \"%s\"" % (kid as Button).text.left(24)
		parts.append("%s %.0f%s" % [_named(kid), kid.get_combined_minimum_size().x, said])
	return " [%s%s]" % [", ".join(parts), _widest_inside(kids[0], depth - 1)]


func _put(part: String, colour: int, at: Vector3) -> void:
	var where := Transform3D(Basis.IDENTITY, at)
	var brick_id: int = _world.add_brick(part, colour, where)
	_builder.register(brick_id, part, where)


func _select_only(ids: Array) -> void:
	_builder.clear_selection()
	for brick_id: int in ids:
		_builder.selection[brick_id] = true
	_builder.selection_changed.emit(_builder.selection.size())


func _screen(point: Vector3) -> Vector2:
	return _camera.unproject_position(point)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	Input.parse_input_event(event)


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


## What the window shows, as it is: the viewport's own picture, never more.
func _shot(name: String) -> void:
	if _pictures.is_empty():
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(_pictures)
	image.save_png(_pictures.path_join("%s.png" % name))
	print("    picture: %s/%s.png" % [_pictures, name])
