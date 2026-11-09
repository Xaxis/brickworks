## The parts bin's shelves, every one in sight, and a New shelf (APP_UX7
## binrow).
##
##   godot --path . --resolution 1400x900 --script src/dev/binrow_probe.gd [-- --shots=DIR]
##   tools/probe.sh binrow_phone_probe     laid out for a phone, 390 x 844
##   tools/probe.sh binrow_tablet_probe    laid out for a tablet, 1024 x 768
##
## At 1280 x 720 with Stress's panel open the bin was about 300 wide and its
## chips one row in a scrolling window: All, Recent, Favourites and Palettes.
## Techniques, Fits and Like this sat in the rows under it with a scroll bar
## 4 px wide to say so, and the walk's click on Like this missed. Studio's
## bin also has a New parts palette, and Brickworks' had none.
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in with a password
## grant (as mosaic_window_probe), the screen gone; the account deleted at
## the end. Needs .env (SUPABASE_URL, SUPABASE_SECRET_KEY). Then, the window
## made each size in turn as a person's window is dragged (as roomfit_probe
## makes them), 1400 x 900, 1280 x 720 and 1024 x 768:
## - as a first visit opens it (nothing selected, the assistant off, the
##   properties folded) and with every column open (Stress's panel, the
##   assistant, a part clicked and its properties, the bin by its rail where
##   the assistant folded it): each of the eight shelves, All, Recent,
##   Favourites, Palettes, New, Techniques, Fits and Like this, wholly inside
##   the chips' window, unscrolled, inside the bin's column and the window;
## - at 1400 x 900 as it first opens, 42 parts wholly in sight, as roomfit
##   counts them;
## - at 1400 x 900 and at 1280 x 720 with Stress open, the walk's Like this
##   (appux_walk round3): "1x4 brick" typed, a 2 x 4 brick clicked in the
##   model, the chip clicked; Plate 2 x 4 seventh.
## And New, its chip clicked: every part the catalogue has first made in its
## latest two years (the latest year any part was first made in, and the one
## before), the newest year first, each one listed and no other; its status
## line says so; "slope" typed narrows it to its slopes.
## Laid out for a finger (the phone and tablet scripts, or --phone): the
## parts sheet opened by its button, the eight shelves inside its window
## unscrolled, and New's list. Pictures go to --shots=DIR, else user://binrow.
extends SceneTree

## The shelves, as the bin says them: written out, so the probe runs on a
## bin without New and fails there.
const SHELVES: Array[String] = ["All", "Recent", "Favourites", "Palettes", "New", "Techniques",
	"Fits", "Like this"]
const NEW := "New"
const LIKE := "Like this"
const SIZES: Array[Vector2i] = [Vector2i(1400, 900), Vector2i(1280, 720), Vector2i(1024, 768)]
## As roomfit counts them at 1400 x 900 on a first visit (APP_UX A10).
const FIRST_TILES := 42
## The walk's Like this: a 2 x 4 brick's Plate 2 x 4 seventh.
const BRICK := "3001"
const PLATE := "3020"
const PLATE_AT := 7
const RED := 4
const NEW_YEARS := 2

var _failures: int = 0
var _main: Node
var _bin: Node
var _builder: Builder
var _world: BrickWorld
var _camera: CadCamera
var _library: PartLibrary
var _shell: Shell
var _phone: bool = false
var _out: String = "user://binrow"
var _email: String = ""
var _password: String = ""
var _table: Array[String] = []


func _initialize() -> void:
	_run()


## "phone" or "tablet" for a script that is this one in another window
## (binrow_phone_probe, binrow_tablet_probe); "" here.
func _finger() -> String:
	return ""


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	ShellPrefs.kept_by_a_check = _own_data_folder()
	_phone = _finger() != "" or OS.get_cmdline_user_args().has("--phone")
	if _phone:
		Phone._on = 1
		Phone._wide = _finger() == "tablet"
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	# The sign-in screen over the app, as a person opening it meets it.
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback != null:
		(playback as BuildPlayback).stop()
	var size: Vector2i = DisplayServer.window_get_size()
	print("in a %d x %d window%s" % [size.x, size.y, ", laid out for a finger" if _phone else ""])
	if not await _way_in():
		await _finish()
		return
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	await _until(func() -> bool:
		return int(_bin.get("_offerable")) > 0 and _library.search_ready(), 1800)
	await _frames(30)
	if _phone:
		await _by_finger()
	else:
		for at: Vector2i in SIZES:
			await _at(at)
		await _new_shelf("1400x900")
	print("")
	print("  size        first: shelves  tiles   every column: shelves  rows  open")
	for line: String in _table:
		print("  " + line)
	await _finish()


## The sign-in screen up, a throwaway account signed in, the screen gone.
func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("binrow")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


## Signed in with a password grant on an account the admin key made: the
## token bucket, not a code's verify, which is 1 per 10 s for every agent.
func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


# -- the desktop's window, each size in turn ------------------------------------


func _at(size: Vector2i) -> void:
	if root.size != size:
		root.size = size
		await _frames(40)
		await _settle()
	var tag: String = "%dx%d" % [size.x, size.y]
	print("")
	print("%s (%s units)" % [tag, root.get_visible_rect().size])
	_check("the window is %s, as asked (got %s)" % [size, DisplayServer.window_get_size()],
		DisplayServer.window_get_size() == size and root.size == size)

	# As a first visit opens it.
	await _as_first_opened()
	var out: Array[String] = _shelves_out_of_sight()
	var tiles: int = _tiles_in_sight()
	_say_chips()
	_check("%s as it first opens: the eight shelves in sight, unscrolled (%s)" % [tag,
		"all" if out.is_empty() else "out of sight: " + ", ".join(out)], out.is_empty())
	if size == Vector2i(1400, 900):
		_check("...and %d parts wholly in sight (%d across), %d as before"
			% [tiles, int((_bin.get("_grid") as GridContainer).columns), FIRST_TILES],
			tiles >= FIRST_TILES)
	await _shot("%s_first" % tag)
	var first_line: String = "%-11s %14s  %5d" % [tag, "all" if out.is_empty() else
		"%d out" % out.size(), tiles]

	# Every column open.
	var open: String = await _every_column()
	out = _shelves_out_of_sight()
	_say_chips()
	_check("%s with every column open (%s; the bin %d wide): the eight shelves in sight, unscrolled (%s)"
		% [tag, open, (_bin as Control).size.x, "all" if out.is_empty() else "out of sight: "
		+ ", ".join(out)], out.is_empty() and open.begins_with("bin") and open.contains("Stress"))
	await _shot("%s_every_column" % tag)
	_table.append("%s   %20s  %4d  %s" % [first_line, "all" if out.is_empty() else
		"%d out" % out.size(), _window_rows(), open])

	# The walk's Like this, Stress's panel open, at the walk's two sizes.
	if size == Vector2i(1400, 900) or size == Vector2i(1280, 720):
		await _walk_like_this(tag)
	await _close_columns()


## As a first visit has it: nothing selected, the assistant off, Stress off,
## the bin open and the properties' column folded to its rail.
func _as_first_opened() -> void:
	_builder.clear_selection()
	await _clear_search()
	if _shell.stress != null and _shell.stress.on:
		_shell.run("stress")
	if (_main.get("_chat_dock") as SideDock).visible:
		_main.call("set_assistant", false)
	await _settle()
	var bin_dock: SideDock = _main.get("_bin_dock")
	if not bin_dock.is_open():
		await _click(bin_dock.rail().get_global_rect().get_center())
	var props_dock: SideDock = _main.get("_props_dock")
	if props_dock != null and props_dock.is_open():
		await _click(props_dock.rail().get_global_rect().get_center())
	await _settle()
	(_bin.get("_category_scroll") as ScrollContainer).scroll_vertical = 0
	await _frames(4)


## A part clicked, the assistant, the part's properties, Stress's panel and
## the bin, each by what a person presses, the bin last; what is open then,
## in words. The window keeps the model its least and folds what would take
## it (main._column_opening): at 1280 x 720 the bin and the assistant take
## turns, and Stress's panel folds the bin until its rail is clicked, as
## the walk had it, the bin then at its narrowest beside Stress.
func _every_column() -> String:
	# A part in the model first: Stress has nothing to weigh without one,
	# and is not offered ("Put a part on the baseplate first").
	await _put_brick()
	_main.call("set_assistant", true)
	await _settle()
	var props_dock: SideDock = _main.get("_props_dock")
	if props_dock != null and not props_dock.is_open() and not _props_under_bin():
		await _click(props_dock.rail().get_global_rect().get_center())
		await _settle()
	await _stress_beside_bin()
	var bin_dock: SideDock = _main.get("_bin_dock")
	var stress_panel: Control = _shell.stress.panel if _shell.stress != null else null
	var chat: Control = _main.get("_chat")
	var open: Array[String] = []
	if bin_dock.is_open():
		open.append("bin")
	if stress_panel != null and stress_panel.is_visible_in_tree():
		open.append("Stress")
	if props_dock != null and props_dock.is_open():
		open.append("properties")
	elif _props_under_bin():
		open.append("properties under the bin")
	if chat != null and chat.is_visible_in_tree():
		open.append("assistant")
	return ", ".join(open)


## Stress's panel open, and the bin by its rail beside it: Stress's column
## folds the bin (main._tool_column_shown, "the bin is a click on its rail
## away"), and a person who wants a part clicks it back.
func _stress_beside_bin() -> void:
	if _shell.stress != null and not _shell.stress.on:
		_shell.run("stress")
	await _settle()
	var bin_dock: SideDock = _main.get("_bin_dock")
	if not bin_dock.is_open():
		await _click(bin_dock.rail().get_global_rect().get_center())
		await _settle()


func _props_under_bin() -> bool:
	var near: Control = _main.get("_bin_props")
	return near != null and near.is_visible_in_tree()


func _close_columns() -> void:
	if _shell.stress != null and _shell.stress.on:
		_shell.run("stress")
	_main.call("set_assistant", false)
	_builder.clear_selection()
	_main.call("clear_model")
	await _clear_search()
	_bin.call("show_category", "All")
	await _settle()


func _clear_search() -> void:
	var search: LineEdit = _bin.get("_search")
	if search.text.is_empty():
		return
	search.text = ""
	search.text_changed.emit("")
	await create_timer(0.4).timeout
	await _until(func() -> bool: return int(_bin.get("_seeking")) < 0, 600)


## A red 2 x 4 brick on the baseplate, framed, and clicked in the model as a
## person picks it out.
func _put_brick() -> int:
	_main.call("clear_model")
	await _frames(10)
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick: int = _world.add_brick(BRICK, RED, where)
	_builder.register(brick, BRICK, where)
	_builder.clear_selection()
	_camera.frame(AABB(Vector3(-120, 0, -80), Vector3(240, 60, 160)))
	await _frames(30)
	# A finger's tap on the model is likethis_phone_probe's; here the
	# selection is only what the sheet is opened with.
	if _phone:
		_builder.select_brick(brick, false)
	else:
		await _click(_camera.unproject_position(where.origin + Vector3(0, -2, 0)))
	await _settle()
	return brick


## appux_walk's round3: "1x4 brick" typed in the bin, a 2 x 4 brick clicked
## in the model, Like this clicked where it stands. Stress's panel open.
func _walk_like_this(tag: String) -> void:
	var search: LineEdit = _bin.get("_search")
	search.text = "1x4 brick"
	search.text_changed.emit(search.text)
	await create_timer(0.4).timeout
	await _until(func() -> bool: return int(_bin.get("_seeking")) < 0, 600)
	await _frames(8)
	var brick: int = await _put_brick()
	await _stress_beside_bin()
	var stress: bool = _shell.stress != null and _shell.stress.panel.is_visible_in_tree()
	var bin_wide: float = (_bin as Control).size.x
	var chip: Button = _chip(LIKE)
	var seen: bool = chip != null and _in_sight(chip)
	_check("%s, Stress open (%s), the bin %d wide beside it, a 2 x 4 brick clicked (%s): Like this in sight to click (%s)"
		% [tag, stress, bin_wide, _builder.selection.has(brick),
		chip.get_global_rect() if chip != null else "no chip"], seen and stress
		and (_main.get("_bin_dock") as SideDock).is_open() and _builder.selection.has(brick))
	if chip == null:
		return
	await _click(chip.get_global_rect().get_center())
	await _until(func() -> bool:
		return not bool(_bin.get("_like_waiting")) and not (_bin.call("first_found", 1) as PackedStringArray).is_empty(), 600)
	await _frames(10)
	var found: PackedStringArray = _bin.call("first_found", 12)
	var at: int = found.find(PLATE) + 1
	_check("...the click chooses it (%s), and Plate 2 x 4 is %s of %s" % [_bin.get("_category"),
		_nth(at) if at > 0 else "not among the first twelve", ", ".join(found)],
		str(_bin.get("_category")) == LIKE and at == PLATE_AT)
	await _shot("%s_like_this" % tag)


# -- New ------------------------------------------------------------------------


## New, clicked: every part the catalogue has first made in its latest two
## years, newest first, and nothing else; its status line; and narrowed.
func _new_shelf(tag: String) -> void:
	print("")
	print("New, at %s" % tag)
	if root.size != Vector2i(1400, 900) and not _phone:
		root.size = Vector2i(1400, 900)
		await _settle()
	if not _phone:
		await _as_first_opened()
	var prints: CheckBox = _bin.get("_prints")
	var only_made: CheckBox = _bin.get("_only_made")
	# Each one the catalogue has: printed parts shown, not only those made
	# in the colour in hand, as a person who wants every new part sets it.
	if not prints.button_pressed:
		prints.button_pressed = true
	if only_made.button_pressed:
		only_made.button_pressed = false
	var search: LineEdit = _bin.get("_search")
	search.text = ""
	search.text_changed.emit("")
	await create_timer(0.4).timeout
	await _frames(8)
	var chip: Button = _chip(NEW)
	_check("a New chip in the bin, in sight (%s, \"%s\")" % [chip.text if chip != null else "none",
		chip.tooltip_text if chip != null else ""], chip != null and _in_sight(chip))
	if chip == null:
		return
	if _phone:
		await _tap(chip.get_global_rect().get_center())
	else:
		await _click(chip.get_global_rect().get_center())
	await _until(func() -> bool: return int(_bin.get("_seeking")) < 0, 600)
	await _frames(10)

	# What the catalogue says, read here from its years.
	var latest: int = 0
	for id: String in _library.ids():
		latest = maxi(latest, (_library.parts[id] as PartLibrary.PartInfo).first_year)
	var since: int = latest - NEW_YEARS + 1
	var wanted: Dictionary = {}
	for id: String in _library.ids():
		var info: PartLibrary.PartInfo = _library.parts[id]
		if info.first_year >= since and not info.is_redirect() and info.reachable:
			wanted[id] = info.first_year
	var display: Array = _bin.get("_display")
	var listed: Array[String] = []
	var years: Array[int] = []
	for info: PartLibrary.PartInfo in display:
		listed.append(info.id)
		years.append(info.first_year)
	var extra: Array[String] = []
	var seen: Dictionary = {}
	for id: String in listed:
		if not wanted.has(id) or seen.has(id):
			extra.append(id)
		seen[id] = true
	var missing: Array[String] = []
	for id: String in wanted:
		if not seen.has(id):
			missing.append(id)
	var newest_first: bool = true
	for n: int in range(1, years.size()):
		if years[n] > years[n - 1]:
			newest_first = false
	var of_latest: int = years.count(latest)
	_check("New chosen by its chip (%s): %d parts, first made in %d or %d, the catalogue's latest years"
		% [_bin.get("_category"), listed.size(), since, latest], str(_bin.get("_category")) == NEW
		and latest > 0 and listed.size() > 0)
	_check("...each one the catalogue has: %d of %d, none missing (%s), none else (%s)" % [
		listed.size() - extra.size(), wanted.size(), ", ".join(missing.slice(0, 8)),
		", ".join(extra.slice(0, 8))], missing.is_empty() and extra.is_empty())
	_check("...newest first: %d of %d's, then %d of %d's; first: %s" % [of_latest, latest,
		years.count(since), since, ", ".join(_names(listed.slice(0, 5)))],
		newest_first and of_latest > 0 and years.slice(0, of_latest).count(latest) == of_latest)
	var status: String = (_bin.get("_status") as Label).text
	_check("...its status line says so: \"%s\"" % status.replace("\n", " / "),
		status.contains("first made in %d or %d" % [since, latest])
		and status.contains("%d part" % listed.size()))
	var tiles: int = _tiles_in_sight()
	_check("...its tiles in sight (%d)" % tiles, tiles > 0)
	await _shot("%s_new" % tag)

	# Narrowed by words, as any shelf is.
	search.text = "slope"
	search.text_changed.emit("slope")
	await create_timer(0.4).timeout
	await _until(func() -> bool: return int(_bin.get("_seeking")) < 0, 600)
	await _frames(10)
	# Every new part named a slope, and none but new parts: a slope's
	# keywords may bring a part not named one, as the search does anywhere.
	var slopes: Array[String] = []
	var not_new: Array[String] = []
	for info: PartLibrary.PartInfo in _bin.get("_display"):
		slopes.append(info.id)
		if not wanted.has(info.id):
			not_new.append(info.id)
	var named: Array[String] = []
	for id: String in wanted:
		if (_library.parts[id] as PartLibrary.PartInfo).name.to_lower().contains("slope") \
				and not slopes.has(id):
			named.append(id)
	_check("...\"slope\" typed narrows it, still New: %d parts (%s), every new part named a slope among them (missing: %s), none not new (%s)"
		% [slopes.size(), ", ".join(_names(slopes.slice(0, 4))), ", ".join(named.slice(0, 6)),
		", ".join(not_new.slice(0, 6))], str(_bin.get("_category")) == NEW
		and not slopes.is_empty() and named.is_empty() and not_new.is_empty()
		and slopes.size() < listed.size())
	search.text = ""
	search.text_changed.emit("")
	await create_timer(0.4).timeout
	_bin.call("show_category", "All")
	await _settle()


# -- a finger's --------------------------------------------------------------------


func _by_finger() -> void:
	var phone: Node = _main.get("_phone")
	_check("the layout for a finger is made", phone != null)
	if phone == null:
		return
	var tag: String = "%dx%d_%s" % [root.size.x, root.size.y, _finger() if _finger() != "" else "phone"]
	await _put_brick()
	var button: Control = (phone.call("controls_by_name") as Dictionary).get("phone_parts")
	_check("the Parts button", button != null and button.is_visible_in_tree())
	if button == null:
		return
	await _tap(button.get_global_rect().get_center())
	await create_timer(1.0).timeout
	await _settle()
	var out: Array[String] = _shelves_out_of_sight()
	_say_chips()
	_check("%s, the parts sheet opened by its button: the eight shelves in sight, unscrolled (%s)" % [
		tag, "all" if out.is_empty() else "out of sight: " + ", ".join(out)], out.is_empty())
	await _shot("%s_sheet" % tag)
	_table.append("%-14s %11s  %5d" % [tag, "all" if out.is_empty() else "%d out" % out.size(),
		_tiles_in_sight()])
	await _new_shelf(tag)


# -- what is in sight -----------------------------------------------------------


## The shelves not wholly inside the chips' window, the window not at its
## top, the bin's column (or a finger's sheet) and the window.
func _shelves_out_of_sight() -> Array[String]:
	var out: Array[String] = []
	var row: ScrollContainer = _bin.get("_category_scroll")
	if row == null or not row.is_visible_in_tree():
		return SHELVES.duplicate()
	if row.scroll_vertical != 0:
		out.append("the chips' window scrolled %d" % row.scroll_vertical)
	for shelf: String in SHELVES:
		var chip: Button = _chip(shelf)
		if chip == null or not _in_sight(chip):
			out.append(shelf)
	return out


## Whether [param control] is wholly where a person sees it: inside the
## chips' window, the bin's column or the sheet's list, and the window.
func _in_sight(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var window := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	window = window.intersection((_bin.get("_category_scroll") as Control).get_global_rect())
	if _phone:
		window = window.intersection((_bin.get("_scroll") as Control).get_global_rect())
	else:
		var holder: Control = (_main.get("_bin_dock") as SideDock)._holder
		window = window.intersection(holder.get_global_rect())
	return window.grow(0.5).encloses(control.get_global_rect())


## The chips' window's rows, as tall as it is.
func _window_rows() -> int:
	var row: ScrollContainer = _bin.get("_category_scroll")
	var chip: Button = _chip("All")
	if chip == null or chip.size.y <= 0.0:
		return 0
	return roundi((row.size.y + 4.0) / (chip.size.y + 4.0))


func _say_chips() -> void:
	var row: ScrollContainer = _bin.get("_category_scroll")
	var words: Array[String] = []
	for shelf: String in SHELVES:
		var chip: Button = _chip(shelf)
		words.append("%s @%d,%d" % [chip.text, chip.position.x, chip.position.y] if chip != null
			else "%s missing" % shelf)
	print("    chips' window %d x %d (%d rows), bin %d wide: %s" % [row.size.x, row.size.y,
		_window_rows(), (_bin as Control).size.x, " | ".join(words)])


## Each part's tile wholly inside the bin's scroller and its column, as
## roomfit_probe counts them.
func _tiles_in_sight() -> int:
	var scroll: ScrollContainer = _bin.get("_scroll")
	if not scroll.is_visible_in_tree():
		return 0
	var window: Rect2 = scroll.get_global_rect().intersection(Rect2(Vector2.ZERO,
		root.get_visible_rect().size))
	if not _phone:
		window = window.intersection((_main.get("_bin_dock") as SideDock)._holder.get_global_rect())
	var count: int = 0
	for cell: Node in (_bin.get("_grid") as Node).get_children():
		var tile := cell as Control
		if tile != null and tile.visible and window.encloses(tile.get_global_rect()):
			count += 1
	return count


func _chip(shelf: String) -> Button:
	for child: Node in (_bin.get("_category_row") as Node).get_children():
		if str(child.get_meta("category", "")) == shelf and not child.is_queued_for_deletion():
			return child
	return null


func _names(ids: Array) -> Array[String]:
	var out: Array[String] = []
	for id: Variant in ids:
		var info: PartLibrary.PartInfo = _library.parts.get(str(id))
		out.append("%s %s" % [id, Inventory._tidy(info.name) if info != null else "?"])
	return out


func _nth(at: int) -> String:
	const WORDS: Array[String] = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh",
		"eighth", "ninth", "tenth", "eleventh", "twelfth"]
	return WORDS[at - 1] if at >= 1 and at <= WORDS.size() else "%dth" % at


# -- the window, as a person uses it ---------------------------------------------


func _click(at: Vector2) -> void:
	var spot: Vector2 = _as_event(at)
	var motion := InputEventMouseMotion.new()
	motion.position = spot
	motion.global_position = spot
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = spot.floor()
		event.global_position = spot.floor()
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


## A finger down and up where it is.
func _tap(at: Vector2) -> void:
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = whole
		Input.parse_input_event(touch)
		await _frames(3)
	await _frames(4)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _settle() -> void:
	await _frames(20)
	await create_timer(SideDock.SLIDE_SECONDS + 0.1).timeout
	await _frames(10)


func _until(test: Callable, frames: int) -> void:
	for _n: int in frames:
		if test.call():
			return
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	# No frame is drawn without a window, and frame_post_draw never comes.
	if DisplayServer.get_name() == "headless":
		return
	await _frames(10)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	if image != null and image.save_png(path) == OK:
		print("    picture: %s" % path)


func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	if _failures == 0:
		print("binrow probe: every shelf in sight at every size, and New lists the newest parts")
	else:
		print("binrow probe: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
