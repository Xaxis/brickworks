## Every submenu of the menu bar under a person's pointer, on the desktop
## (menufix, 2026-11-27; the owner: "the submenus like 'Import' or 'Open
## recent' are almost completely unresponsive ... they take forever to load
## and then flash away").
##
##   godot --path . --resolution 1280x800 --script src/dev/submenu_probe.gd -- [--saves=50]
##   godot --headless --path . --script src/dev/submenu_probe.gd -- --paths
##
## In a window the times are judged; headless (--paths, which the release
## train runs: tools/suite/headless.txt) only where the pointer goes, what
## opens and what stays: a headless frame says nothing of a hand's wait.
##
## The pointer is the one the menus read. A menu reads where the pointer is
## from the platform as well as from each move (Viewport.get_mouse_position,
## DisplayServer.mouse_get_position: the engine's way into a submenu and its
## safe rectangle). In a window a move parsed into Input never moved the X
## server's pointer, so the menus read a pointer left where it was, and shut
## (menufix's window run: File hidden, "pointer y -1"; menufix2). So in a
## window the pointer is moved on the X server (Input.warp_mouse), and the
## platform makes each move and its speed as it does a mouse's; headless,
## where the engine's pointer is Input's own, each move is parsed with the
## speed the platform would give it (Input.get_last_mouse_velocity), and
## events are given in the root's own units (a headless window is 0 x 0).
## Either way a move made just after the pointer stood still has no speed,
## as a person's has. For each submenu of File, Edit and View: the pointer
## comes down the menu from its title and rests on the row, and the submenu
## must open (in a window, be drawn within DRAWN_MS, with no frame over
## FRAME_MS from the first move until then); it must stay open while the
## pointer goes straight across and down to its third row that may be
## pressed, which must be lit, and again on a slant to that row over the rows
## below its own. And a hand that rested on one submenu's row and then went
## down to the next within a tenth of a second opens the next (Open recent,
## then Import). --saves=N (50 unless given) saved models are on the shelf,
## and Open recent's second row, clicked, opens its model. "SUBMENU row"
## lines are the table; exits 1 on any failure.
extends SceneTree

const DRAWN_MS := 150
const FRAME_MS := 50
const SUBMENUS := [["File", "Open recent"], ["File", "Import"], ["File", "Compare"],
	["File", "Export"], ["Edit", "History"], ["Edit", "Select by"], ["Edit", "Show and hide"],
	["View", "Viewpoint"], ["View", "Floor"], ["View", "Edges and studs"],
	["View", "Cut away by"], ["View", "Panels"]]
const SHELF := ["sports_car", "three_core_rocket", "station", "orrery", "corner_shop", "barn_owl"]

var _main: Node
var _shell: Shell
var _failures: int = 0
var _saves: int = 50
var _headless: bool = false
var _pointer := Vector2(640, 400)
var _frame_at: int = 0
var _frames: PackedInt64Array = []


func _initialize() -> void:
	_run.call_deferred()
	create_timer(1500.0).timeout.connect(func() -> void:
		print("SUBMENU cut off after 1500 s")
		quit(1))


func _check(what: String, ok: bool) -> bool:
	print("SUBMENU %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var only: PackedStringArray = []
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--saves="):
			_saves = int(arg.get_slice("=", 1))
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1).split(",")
	_headless = DisplayServer.get_name() == "headless"
	print("SUBMENU %s: the platform's pointer %s, the window %s, the root %s" % [
		"headless" if _headless else "in a window",
		"read" if DisplayServer.has_feature(DisplayServer.FEATURE_MOUSE) else "Input's own",
		str(root.size), str(root.get_visible_rect().size)])
	_shelve(_saves)
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 200:
		await process_frame
	var store: ModelStore = _main.get("_store")
	for _n: int in 600:
		if not store.laying:
			break
		await process_frame
	_shell = _main.get("_shell")
	_watch_menus()
	process_frame.connect(func() -> void:
		var now: int = Time.get_ticks_usec()
		if _frame_at > 0:
			_frames.append(now - _frame_at)
		_frame_at = now)
	# What a row costs as its menu opens, alone: the engine's part left out.
	_costs()
	for pair: Array in SUBMENUS:
		if only.is_empty() or str(pair[1]) in only:
			await _try(str(pair[0]), str(pair[1]))
	await _rest_then_next()
	await _crossed_and_left()
	if _saves > 0:
		await _open_recent_row()
	print("SUBMENU %d failed" % _failures)
	quit(1 if _failures > 0 else 0)


## [param count] saved models, cycled from the models that ship.
func _shelve(count: int) -> void:
	if count <= 0:
		return
	DirAccess.make_dir_recursive_absolute(ModelStore.SAVE_DIR)
	for n: int in count:
		var text: String = FileAccess.get_file_as_string("res://models/%s.ldr" % SHELF[n % SHELF.size()])
		var file := FileAccess.open(ModelStore.SAVE_DIR + "Shelf model %02d.ldr" % (n + 1), FileAccess.WRITE)
		file.store_string(text)
		file.close()
	print("SUBMENU shelf: %d saved models" % count)


func _costs() -> void:
	for pair: Array in SUBMENUS:
		var popup: PopupMenu = _popup_of(str(pair[0]))
		var index: int = _row_of(popup, str(pair[1]))
		var sub: PopupMenu = popup.get_item_submenu_node(index)
		var began: int = Time.get_ticks_usec()
		sub.about_to_popup.emit()
		print("SUBMENU cost %s › %s: %.2f ms as it opens" % [pair[0], pair[1],
			(Time.get_ticks_usec() - began) / 1000.0])
	for title: String in ["File", "Edit", "View"]:
		var began: int = Time.get_ticks_usec()
		var popup: PopupMenu = _popup_of(title)
		popup.about_to_popup.emit()
		print("SUBMENU cost %s: %.2f ms as it opens" % [title, (Time.get_ticks_usec() - began) / 1000.0])
		# And shut, as a menu that opened says: its title heard "about to
		# popup" (MenuButton._popup_visibility_changed), was left pressed and
		# looking every frame for the pointer on another title, and opened the
		# one under it, File, Edit or View, once a frame for each title left
		# so: File, with two, opened and shut every frame (greenreds2).
		_shutting = true
		popup.popup_hide.emit()
		_shutting = false


func _button_of(title: String) -> MenuButton:
	for button: MenuButton in _shell.get("_menus"):
		if button.text == title:
			return button
	return null


func _popup_of(title: String) -> PopupMenu:
	return _button_of(title).get_popup()


func _row_of(popup: PopupMenu, words: String) -> int:
	for index: int in popup.item_count:
		if popup.get_item_submenu_node(index) != null and popup.get_item_text(index) == words:
			return index
	return -1


# -- the pointer, as a mouse moves it ---------------------------------------------


## A point of the root's canvas as the window's pixels, where a platform puts
## its events. A headless window is 0 x 0 and its events are the root's own.
func _as_event(at: Vector2) -> Vector2:
	var scale := Vector2(root.size) / root.get_visible_rect().size
	if not (scale.x > 0.0 and scale.y > 0.0):
		return at
	return at * scale


func _move(to: Vector2) -> void:
	if not _headless:
		# On the X server: the platform makes the move, its speed, and the
		# pointer the menus read, as it does for a mouse.
		_pointer = to
		Input.warp_mouse(_as_event(to))
		return
	var event := InputEventMouseMotion.new()
	event.position = _as_event(to)
	event.global_position = event.position
	event.relative = _as_event(to - _pointer)
	event.screen_relative = event.relative
	# As the platform gives a move its speed: the one measured before it.
	event.velocity = Input.get_last_mouse_velocity()
	event.screen_velocity = event.velocity
	_pointer = to
	Input.parse_input_event(event)
	Input.flush_buffered_events()


## The pointer from where it is to [param to] in [param steps] moves,
## [param gap] seconds apart (a hand's 30 ms a move), each frame drawn.
func _glide(to: Vector2, steps: int, gap: float = 0.03) -> void:
	var from: Vector2 = _pointer
	for n: int in steps:
		_move(from.lerp(to, float(n + 1) / steps))
		await create_timer(gap).timeout


func _click(at: Vector2) -> void:
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
		await process_frame


func _shut() -> void:
	_shutting = true
	for button: MenuButton in _shell.get("_menus"):
		button.get_popup().hide()
	_shutting = false
	for _n: int in 4:
		await process_frame


var _shutting: bool = false
var _opened_at: int = 0


## A menu the probe opened, shut by anything but the probe: when, and what
## else was on screen and had just taken the window's focus.
func _watch_menus() -> void:
	for button: MenuButton in _shell.get("_menus"):
		var popup: PopupMenu = button.get_popup()
		popup.popup_hide.connect(func() -> void:
			if _shutting:
				return
			var shown: PackedStringArray = []
			for node: Node in root.find_children("*", "Window", true, false):
				var window := node as Window
				if window != null and window.visible and window != popup:
					shown.append("%s(%s)" % [window.name, window.get_class()])
			print("SUBMENU (%s shut by itself %.2f s after it opened; windows shown: %s; focused control: %s)"
				% [button.text, (Time.get_ticks_usec() - _opened_at) / 1000000.0, ", ".join(shown),
				str(root.gui_get_focus_owner())]))
	for node: Node in root.find_children("*", "MenuButton", true, false):
		var other := node as MenuButton
		other.get_popup().about_to_popup.connect(func() -> void:
			if Time.get_ticks_usec() - _opened_at < 1000000:
				var on_bar: PackedStringArray = []
				for button: MenuButton in _shell.get("_menus"):
					on_bar.append("%s %s%s" % [button.text, "shown" if button.is_visible_in_tree() else "FOLDED",
						" (its menu up)" if button.get_popup().visible else ""])
				print("SUBMENU (%s %s opens; hovered %s; frame %d; bar: %s; mouse buttons %d; from %s)" % [other.name,
					other.text, str(root.gui_get_hovered_control()), Engine.get_process_frames(),
					", ".join(on_bar), Input.get_mouse_button_mask(), str(get_stack())]))


## A row's band in its menu, top and bottom, found as the pointer finds it:
## moved down the menu a few pixels at a time, the row it lights read. The
## submenus are kept shut while it looks (their delay put off).
func _band(popup: PopupMenu, index: int) -> Vector2:
	var delay: float = popup.submenu_popup_delay
	popup.submenu_popup_delay = 100.0
	var x: float = popup.position.x + 40.0
	var top: float = -1.0
	var bottom: float = -1.0
	var plain: float = -1.0
	var y: float = popup.position.y + 2.0
	while y < popup.position.y + popup.size.y:
		_move(Vector2(x, y))
		await process_frame
		await process_frame
		var lit: int = popup.get_focused_item()
		if lit >= 0 and popup.get_item_submenu_node(lit) == null and not popup.is_item_disabled(lit):
			plain = y
		if lit == index:
			if top < 0.0:
				top = y
			bottom = y
		elif top >= 0.0:
			break
		y += 2.0
	# Back onto a row with no submenu: the menu stops its long timer and
	# forgets the submenu row it was timing, as a hand's pointer passing over
	# such a row has it do. (Left timing a row, the engine never times that
	# row again when the pointer comes back onto it: _crossed_and_left.)
	if plain >= 0.0:
		_move(Vector2(x, plain))
		await process_frame
		await process_frame
	popup.submenu_popup_delay = delay
	return Vector2(top, bottom)


## The menu opened by a click on its title, the pointer then on the title.
func _open(title: String) -> PopupMenu:
	await _shut()
	var button: MenuButton = _button_of(title)
	var at: Vector2 = button.get_global_rect().get_center()
	_move(at)
	await process_frame
	_opened_at = Time.get_ticks_usec()
	await _click(at)
	for _n: int in 6:
		await process_frame
	await create_timer(0.4).timeout
	if not button.get_popup().visible:
		print("SUBMENU (%s not open after its click)" % title)
	return button.get_popup()


## Rested on [param index]: the time from the last move to the submenu open
## and its frame drawn, and the longest frame from the first move until then.
func _rest_on(popup: PopupMenu, index: int, band: Vector2) -> Dictionary:
	var sub: PopupMenu = popup.get_item_submenu_node(index)
	var at := Vector2(popup.position.x + 40.0, (band.x + band.y) / 2.0)
	_frames.clear()
	await _glide(at, 6)
	var rested: int = Time.get_ticks_usec()
	var opened: int = -1
	for _n: int in 400:
		await process_frame
		if sub.visible:
			# Drawn: the frame it is in handed to the screen (headless, none is).
			if _headless:
				await process_frame
			else:
				await RenderingServer.frame_post_draw
			opened = Time.get_ticks_usec()
			break
		if Time.get_ticks_usec() - rested > 3000000:
			break
	var longest: int = 0
	for frame: int in _frames:
		longest = maxi(longest, frame)
	if opened < 0:
		print("SUBMENU (not open: menu %s at %s, lit row %d of wanted %d, pointer %s, band %s)" % [
			"shown" if popup.visible else "hidden", str(popup.position), popup.get_focused_item(),
			index, str(at), str(band)])
	return {"at": at, "sub": sub, "ms": (opened - rested) / 1000.0 if opened > 0 else -1.0,
		"longest": longest / 1000.0}


## The third row of [param sub] that may be pressed (or the last of fewer),
## and its middle, found as the pointer finds it.
func _third(sub: PopupMenu) -> Array:
	var pressable: Array[int] = []
	for index: int in sub.item_count:
		if not sub.is_item_separator(index) and not sub.is_item_disabled(index):
			pressable.append(index)
	if pressable.is_empty():
		return [-1, Vector2(sub.position.x + 40.0, sub.position.y + 12.0)]
	var index: int = pressable[mini(2, pressable.size() - 1)]
	var band: Vector2 = await _band(sub, index)
	return [index, Vector2(sub.position.x + 40.0, (band.x + band.y) / 2.0)]


func _try(title: String, words: String) -> void:
	var popup: PopupMenu = await _open(title)
	var index: int = _row_of(popup, words)
	if not _check("%s › %s: a row of its menu" % [title, words], index >= 0):
		return
	var band: Vector2 = await _band(popup, index)
	# The submenu's third row, found once with the submenu open.
	await _shut()
	popup = await _open(title)
	var rest: Dictionary = await _rest_on(popup, index, band)
	var sub: PopupMenu = rest.sub
	# Headless, a frame's time is no hand's: the submenu has only to open.
	var timed: String = ("%.0f ms to drawn (bar %d), longest frame %.1f ms (bar %d)"
		% [rest.ms, DRAWN_MS, rest.longest, FRAME_MS]) if not _headless else (
		"%.0f ms to open, headless (not timed)" % rest.ms)
	if not _check("%s › %s opens with the pointer rested on it: %s" % [title, words, timed],
			sub.visible and rest.ms >= 0.0 and (_headless or (rest.ms <= DRAWN_MS and rest.longest <= FRAME_MS))):
		if not sub.visible:
			return
	var third: Array = await _third(sub)
	# Straight: across its row into the submenu, then down to the third row.
	await _shut()
	popup = await _open(title)
	rest = await _rest_on(popup, index, band)
	var straight: bool = false
	if sub.visible:
		var target: Vector2 = third[1]
		await _glide(Vector2(sub.position.x + 30.0, rest.at.y), 8)
		await _glide(target, 4)
		await create_timer(0.6).timeout
		straight = sub.visible and (int(third[0]) < 0 or sub.get_focused_item() == int(third[0]))
	_check("%s › %s stays open as the pointer goes straight across and down to its third row, lit"
		% [title, words], straight)
	# Slanted: from the row to the third row in one line, over the rows below,
	# its first move already past the row's edge, as the moves of a quick hand
	# or a slow frame reach the menus gathered into one (Input's accumulated
	# moves): the move a submenu opened under a resting pointer hears first is
	# then off its row (Shell._show_row_point).
	await _shut()
	popup = await _open(title)
	var again: Dictionary = await _rest_on(popup, index, band)
	var slant: bool = false
	if sub.visible:
		var target: Vector2 = third[1]
		var rise: float = target.y - again.at.y
		if absf(rise) > 0.5:
			var edge: float = band.y + 3.0 if rise > 0.0 else band.x - 3.0
			_move(again.at.lerp(target, clampf((edge - again.at.y) / rise, 0.0, 1.0)))
			await create_timer(0.03).timeout
		await _glide(target, 6)
		await create_timer(0.6).timeout
		slant = sub.visible and (int(third[0]) < 0 or sub.get_focused_item() == int(third[0]))
	_check("%s › %s stays open as the pointer goes on a slant to its third row, lit" % [title, words],
		slant)
	print("SUBMENU row %s › %s | drawn %.0f / %.0f ms | longest frame %.1f / %.1f ms | straight %s | slant %s"
		% [title, words, rest.ms, again.ms, rest.longest, again.longest,
		"stays" if straight else "CLOSED", "stays" if slant else "CLOSED"])
	await _shut()


## A hand that rested on Open recent, its submenu open, then went down to
## Import inside a tenth of a second and rested there: Import opens.
func _rest_then_next() -> void:
	var popup: PopupMenu = await _open("File")
	var recent: int = _row_of(popup, "Open recent")
	var import: int = _row_of(popup, "Import")
	var recent_band: Vector2 = await _band(popup, recent)
	var import_band: Vector2 = await _band(popup, import)
	popup = await _open("File")
	var rest: Dictionary = await _rest_on(popup, recent, recent_band)
	await create_timer(0.5).timeout
	await _glide(Vector2(rest.at.x, (import_band.x + import_band.y) / 2.0), 2, 0.02)
	var sub: PopupMenu = popup.get_item_submenu_node(import)
	var began: int = Time.get_ticks_usec()
	while not sub.visible and Time.get_ticks_usec() - began < 1500000:
		await process_frame
	_check("rested on Open recent, then down to Import within a tenth of a second: Import opens "
		+ "(%.0f ms)" % ((Time.get_ticks_usec() - began) / 1000.0), sub.visible
		and not popup.get_item_submenu_node(recent).visible)
	await _shut()


## A hand that came onto Import, went on past the menu's side before Import
## opened, and came back onto it: Import opens as it rests there. (The engine
## times a submenu's row only once until the pointer goes to another row:
## Shell._wake_submenus.)
func _crossed_and_left() -> void:
	var popup: PopupMenu = await _open("File")
	var import: int = _row_of(popup, "Import")
	var band: Vector2 = await _band(popup, import)
	popup = await _open("File")
	var sub: PopupMenu = popup.get_item_submenu_node(import)
	var on := Vector2(popup.position.x + 40.0, (band.x + band.y) / 2.0)
	await _glide(on, 6)
	await create_timer(0.03).timeout
	var shut_on_leaving: bool = not sub.visible
	await _glide(Vector2(popup.position.x + popup.size.x + 80.0, on.y), 2, 0.02)
	await create_timer(0.5).timeout
	await _glide(on, 3)
	var rested: int = Time.get_ticks_usec()
	while not sub.visible and Time.get_ticks_usec() - rested < 1500000:
		await process_frame
	var ms: float = (Time.get_ticks_usec() - rested) / 1000.0
	_check("onto Import, out past the menu's side before it opened, back onto it: Import opens "
		+ "(%.0f ms, bar %d)" % [ms, DRAWN_MS], shut_on_leaving and sub.visible and ms <= DRAWN_MS)
	print("SUBMENU row File › Import, crossed and left | drawn %.0f ms | %s" % [ms,
		"opens" if sub.visible else "NEVER OPENS"])
	await _shut()


## Open recent's first row, clicked, opens its model.
func _open_recent_row() -> void:
	var popup: PopupMenu = await _open("File")
	var index: int = _row_of(popup, "Open recent")
	var band: Vector2 = await _band(popup, index)
	popup = await _open("File")
	var rest: Dictionary = await _rest_on(popup, index, band)
	var sub: PopupMenu = rest.sub
	if not _check("Open recent opens with %d models saved" % _saves, sub.visible and sub.item_count > 0):
		return
	# The second row: the first may be the model the app opened as it started.
	var row: int = mini(1, sub.item_count - 1)
	var band_row: Vector2 = await _band(sub, row)
	var at := Vector2(sub.position.x + 40.0, (band_row.x + band_row.y) / 2.0)
	var words: String = sub.get_item_text(row)
	var listed: Array = _shell.get("_recent")
	var path: String = listed[row].path if row < listed.size() else ""
	var store: ModelStore = _main.get("_store")
	var before: String = store.title
	_move(at)
	await process_frame
	await _click(at)
	var bar: ModelBar = _main.get("_bar")
	for _n: int in 60:
		await process_frame
	var dont: Button = bar.get("_dont_save_button")
	if dont != null and dont.is_visible_in_tree():
		dont.pressed.emit()
	var began: int = Time.get_ticks_usec()
	while Time.get_ticks_usec() - began < 30000000 and (store.laying or str(store.get("_known_path")) != path):
		await process_frame
	var opened: String = str(store.get("_known_path"))
	_check("Open recent's row \"%s\", clicked, opens its model: \"%s\" from %s (was \"%s\")"
		% [words, store.title, opened.get_file(), before],
		not path.is_empty() and opened == path and not store.laying)
