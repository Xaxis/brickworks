## A colour's tooltip in the parts bin says in how many sets the part in hand
## comes in it, and reads "rare in this colour" for three sets or fewer
## (APP_UX7 #21, rarity).
##
##   godot --path . --resolution 1400x900 --script src/dev/rarity_probe.gd [-- --shots=DIR]
##
## BrickMissing tells a person who lost a piece whether it can be replaced:
## a part and colour in three sets or fewer is rare. The bin's swatch said
## only "3001 comes in it", and PartLibrary counted sets per part, never per
## colour. The counts are Rebrickable's set inventories, beside the shards
## (tools/collection_data.py, colours_NN.json); tests/test_collection.py
## counts ten of them straight off Rebrickable's tables.
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in with a password
## grant (as binrow_probe), the screen gone; the account deleted at the end.
## Needs .env (SUPABASE_URL, SUPABASE_SECRET_KEY). Then at 1400 x 900 and
## 1280 x 720, the window made each size in turn:
## - "3001" typed in the bin's search and its tile clicked: the 2 x 4 brick in
##   hand;
## - the pointer rested on Red's swatch until its tooltip is up: it reads
##   "3001 comes in it, in N sets", N the colours file's, and not rare;
## - and on a colour the file has it in three sets or fewer, the palette's
##   long list opened by its button if the short one has none: "in N sets:
##   rare in this colour" (or "in 1 set");
## - every swatch in sight says its own count, rare exactly where it is three
##   or fewer, and nothing of sets where the file has none;
## - 7049b, a 2 x 4 brick with axle bushes, which the catalogue's colour list
##   says was never made in Black: its Black swatch says it comes in it, in
##   the sets the file counts, with the dot of a colour it was made in.
## And the three new sentences in German, French and Spanish (Language.says),
## each count grouped as the language groups it. Pictures go to --shots=DIR,
## else user://rarity: each tooltip up over the palette.
extends SceneTree

const SIZES: Array[Vector2i] = [Vector2i(1400, 900), Vector2i(1280, 720)]
const PART := "3001"
const RED := 4
const ODD := "7049b"
const BLACK := 0
## BrickMissing's: three sets or fewer is rare. Written out, so the probe
## needs nothing of the code it checks.
const RARE_IN := 3
## The colours files, and their rule (tools/collection_data.py colour_shard_of).
const FILES := "res://assets/generated/sets/colours_%02d.json"
const FILE_COUNT := 64
const THOUSANDS: Dictionary = {"de": ".", "fr": " ", "es": "."}

var _failures: int = 0
var _main: Node
var _bin: Node
var _library: PartLibrary
var _out: String = "user://rarity"
var _email: String = ""
var _password: String = ""


func _initialize() -> void:
	_run()


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
	if not await _way_in():
		await _finish()
		return
	_bin = _main.get("_bin")
	_library = _main.get("_library")
	await _until(func() -> bool:
		return int(_bin.get("_offerable")) > 0 and _library.search_ready(), 1800)
	await _frames(30)
	var counts: Dictionary = _counts(PART)
	var odd: Dictionary = _counts(ODD)
	_check("the colours file has %s in %d colours, Red in %d sets; %s in Black in %d" % [PART,
		counts.size(), int(counts.get(RED, 0)), ODD, int(odd.get(BLACK, 0))],
		int(counts.get(RED, 0)) > RARE_IN and int(odd.get(BLACK, 0)) > RARE_IN)
	for size: Vector2i in SIZES:
		await _at(size, counts, odd)
	_in_languages(counts)
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
	_email = SignInHelper.throwaway("rarity")
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


## [param part]'s colour -> sets, read from its colours file here, as
## tools/collection_data.py wrote it.
func _counts(part: String) -> Dictionary:
	var h: int = 0
	for byte: int in part.to_lower().to_utf8_buffer():
		h = (h * 31 + byte) % 1000003
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILES % (h % FILE_COUNT)))
	var out: Dictionary = {}
	if raw is Dictionary and (raw as Dictionary).get("parts") is Dictionary:
		var row: Array = ((raw as Dictionary)["parts"] as Dictionary).get(part, [])
		for at: int in range(0, row.size() - 1, 2):
			out[int(row[at])] = int(row[at + 1])
	return out


## What the swatch of a colour the part is in [param sets] sets should say.
static func _said(part: String, sets: int, grouped: String = ",") -> String:
	if sets > RARE_IN:
		return "%s comes in it, in %s sets" % [part, _grouped(sets, grouped)]
	if sets == 1:
		return "%s comes in it, in 1 set: rare in this colour" % part
	return "%s comes in it, in %d sets: rare in this colour" % [part, sets]


static func _grouped(value: int, mark: String) -> String:
	var text: String = str(value)
	var out: String = ""
	for n: int in text.length():
		if n > 0 and (text.length() - n) % 3 == 0:
			out += mark
		out += text[n]
	return out


# -- each size ---------------------------------------------------------------


func _at(size: Vector2i, counts: Dictionary, odd: Dictionary) -> void:
	if root.size != size:
		root.size = size
		await _frames(40)
		await _settle()
	var tag: String = "%dx%d" % [size.x, size.y]
	print("")
	print("%s (%s units)" % [tag, root.get_visible_rect().size])
	var only_made: CheckBox = _bin.get("_only_made")
	if only_made.button_pressed:
		only_made.button_pressed = false
	var all_colours: Button = _bin.get("_all_colours")
	# The short palette, as it first opens.
	if all_colours.button_pressed:
		await _click(all_colours.get_global_rect().get_center())
	_check("%s: %s in hand, its tile clicked" % [tag, PART], await _hold(PART))

	var swatches: Dictionary = _bin.get("_swatches")
	var red: Control = swatches.get(RED)
	var tip: String = await _rest_on(red, "%s_%s_red" % [tag, PART])
	_check("%s: Red's tooltip, rested on: \"%s\"" % [tag, tip.replace("\n", " / ")],
		tip.split("\n").has(_said(PART, int(counts[RED]))) and not tip.contains("rare"))

	# A colour it is rare in, in the short palette or else the long one.
	var rare: int = _rare_in_sight(counts)
	if rare < 0:
		await _click(all_colours.get_global_rect().get_center())
		await _frames(10)
		swatches = _bin.get("_swatches")
		rare = _rare_in_sight(counts)
	_check("%s: a colour %s is in %d sets or fewer has a swatch: %s" % [tag, PART, RARE_IN,
		_library.color(rare).name if rare >= 0 else "none"], rare >= 0)
	if rare >= 0:
		tip = await _rest_on(swatches[rare], "%s_%s_rare" % [tag, PART])
		_check("%s: %s's tooltip, rested on: \"%s\"" % [tag, _library.color(rare).name,
			tip.replace("\n", " / ")], tip.split("\n").has(_said(PART, int(counts[rare]))))

	# Every swatch in sight.
	var right: int = 0
	var rare_said: int = 0
	var wrong: Array[String] = []
	for code: int in swatches:
		var said: String = (swatches[code] as Control).tooltip_text
		var sets: int = int(counts.get(code, 0))
		var ok: bool = said.split("\n").has(_said(PART, sets)) if sets > 0 \
			else not said.contains(" sets") and not said.contains(" set:")
		ok = ok and said.contains("rare in this colour") == (sets > 0 and sets <= RARE_IN)
		if ok:
			right += 1
			rare_said += 1 if sets > 0 and sets <= RARE_IN else 0
		elif wrong.size() < 4:
			wrong.append("%d: %s" % [code, said.replace("\n", " / ")])
	_check("%s: every swatch in sight (%d) says its sets, rare in %d of them%s" % [tag,
		swatches.size(), rare_said, "" if wrong.is_empty() else "; wrong: " + "; ".join(wrong)],
		right == swatches.size() and rare_said > 0)
	await _click(all_colours.get_global_rect().get_center())
	await _frames(10)

	# 7049b in Black: in sets, though its colour list says never.
	_check("%s: %s in hand, its tile clicked" % [tag, ODD], await _hold(ODD))
	swatches = _bin.get("_swatches")
	var black: PartsBin.Swatch = swatches.get(BLACK)
	tip = await _rest_on(black, "%s_%s_black" % [tag, ODD])
	_check("%s: %s's Black tooltip: \"%s\", the dot of a colour it came in (%d)" % [tag, ODD,
		tip.replace("\n", " / "), black.made_in if black != null else 0],
		tip.split("\n").has(_said(ODD, int(odd[BLACK]))) and not tip.contains("never")
		and black != null and black.made_in == 1)


## [param part] typed in the bin's search and its tile clicked, as a person
## picks it.
func _hold(part: String) -> bool:
	var search: LineEdit = _bin.get("_search")
	search.text = part
	search.text_changed.emit(part)
	await create_timer(0.4).timeout
	await _until(func() -> bool: return int(_bin.get("_seeking")) < 0, 600)
	await _frames(10)
	var tile: Control = null
	for cell: Node in (_bin.get("_grid") as Node).get_children():
		for button: Node in [cell] + cell.find_children("*", "Button", true, false):
			if button is Button and str(button.get_meta("part", "")) == part:
				tile = button
				break
		if tile != null:
			break
	if tile == null:
		return false
	_into_view(tile)
	await _frames(4)
	await _click(tile.get_global_rect().get_center())
	await _frames(10)
	return str(_bin.get("_selected_part")) == part


## The first swatch in sight of a colour [param counts] has in three sets or fewer.
func _rare_in_sight(counts: Dictionary) -> int:
	var swatches: Dictionary = _bin.get("_swatches")
	for code: int in swatches:
		var sets: int = int(counts.get(code, 0))
		if sets > 0 and sets <= RARE_IN and (swatches[code] as Control).is_visible_in_tree():
			return code
	return -1


## [param control] rested on until its tooltip is up, its words read off the
## tooltip and the window pictured; "" when none comes up.
func _rest_on(control: Control, picture: String) -> String:
	if control == null:
		return ""
	_into_view(control)
	_move(root.get_visible_rect().size * Vector2(0.55, 0.62))
	await _frames(3)
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at)
	await _frames(3)
	_move(at + Vector2(1, 0))
	var until: int = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await process_frame
		for sub: Window in root.get_embedded_subwindows():
			if Tooltips.is_tooltip(sub) and sub.visible:
				await _frames(4)
				await _shot(picture)
				for label: Node in sub.get_children():
					if label is Label:
						return (label as Label).text
	return ""


# -- in German, French and Spanish ---------------------------------------------


func _in_languages(counts: Dictionary) -> void:
	print("")
	print("in German, French and Spanish")
	var lines: Array[String] = [_said(PART, int(counts[RED])), _said(PART, 1), _said(PART, 2)]
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var said: Array[String] = []
		var ok: bool = true
		for line: String in lines:
			var drawn: String = Language.says(line)
			said.append(drawn)
			var count: String = _grouped(int(counts[RED]), THOUSANDS[code]) \
				if line == lines[0] else ""
			ok = ok and not drawn.is_empty() and drawn != line and drawn.begins_with(PART) \
				and (count.is_empty() or drawn.contains(count))
		_check("%s: %s" % [code, " | ".join(said)], ok)
	Language.apply("en")


# -- the window, as a person uses it ---------------------------------------------


func _click(at: Vector2) -> void:
	var spot: Vector2 = root.get_final_transform() * at
	if OS.get_environment("XAUTHORITY").contains("xvfb-run"):
		Input.warp_mouse(spot)
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


## The pointer moved, as an event and, on Xvfb, for real (tooltip_probe's
## _move says why).
func _move(at: Vector2) -> void:
	var spot: Vector2 = root.get_final_transform() * at
	if OS.get_environment("XAUTHORITY").contains("xvfb-run"):
		Input.warp_mouse(spot)
	var event := InputEventMouseMotion.new()
	event.position = spot
	event.global_position = spot
	Input.parse_input_event(event)


func _into_view(control: Control) -> void:
	var up: Node = control.get_parent()
	while up != null and not up is ScrollContainer:
		up = up.get_parent()
	if up != null:
		(up as ScrollContainer).ensure_control_visible(control)


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
		print("rarity probe: each colour's tooltip says the part's sets in it, and rare in three or fewer")
	else:
		print("rarity probe: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)
