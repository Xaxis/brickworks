## Help, About names everyone whose work ships in Brickworks, on what
## terms, and opens Godot's licence and BrickNet's in full, by keys alone.
##
##   tools/probe.sh about_credits_probe
##   godot --path . --resolution 1400x900 --script src/dev/about_credits_probe.gd
##   ... -- --shots=DIR    About and each licence pictured there
##
## M6 of docs/PLANS.md: before Brickworks is sold, Godot's licence asks for
## its text "somewhere in your game", BrickNet's MIT for its notice and
## permission, Rebrickable for "Catalog data: Rebrickable", the LDraw
## library for its CC BY notice. About had the LDraw and BrickNet lines
## only, and no licence in full (2026-10-29). So this opens About as the
## Help menu does and reads it:
##
##   every one in Credits.LIST is shown, its name and terms in its words,
##   scrolled into sight; Rebrickable's credit is said as its terms ask,
##   and LDraw's names CC BY 2.0 and CC BY 4.0 with links to both;
##   About fits the window, its OK on the screen;
##   Tab reaches the link to Godot's licence, Return opens it: the engine's
##   own licence text, its components' notices and their licence texts, the
##   keys on the text, Escape puts it away and About is still up;
##   the same for BrickNet's, whose text is its MIT licence word for word,
##   put away with Close;
##   every control About and the licence have, a person can operate, has a
##   name a screen reader says.
##
## Nothing is opened in a browser: a link to an address is read, not pressed.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _shots: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		if _shell != null and _main.get("_bin") != null:
			break
	if _shell == null:
		print("  about credits probe: SKIPPED — the shell never came up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(30)

	_check("Help, About can be run", _shell.run("about"))
	await _frames(12)
	var about: AcceptDialog = _shell.get("_about")
	if not _check("About is up", about != null and about.visible):
		_finish()
		return
	await _credits(about)
	await _fits(about)
	await _read(about, "godot", _wrong_in_godots, "02_godot_licence")
	await _read(about, "bricknet", _wrong_in_bricknets, "03_bricknet_licence")
	_names(about)
	about.hide()
	await _frames(5)
	_finish()


## What is missing from Godot's licence as About opens it, or "".
func _wrong_in_godots(text: String) -> String:
	var missing: PackedStringArray = []
	for wanted: String in [Engine.get_license_text().split("\n")[0], "Permission is hereby granted",
			"== Components ==", "FreeType", "Open Sans font", "== Licence texts ==", "--- OFL-1.1 ---"]:
		if not text.contains(wanted):
			missing.append(wanted)
	return ", ".join(missing)


## What is wrong with BrickNet's as About opens it, or "".
func _wrong_in_bricknets(text: String) -> String:
	if text != Credits.BRICKNET_MIT:
		return "not BrickNet's MIT text"
	if not text.contains("Copyright (c) 2026 Peter Kulits") \
			or not text.contains("The above copyright notice and this permission notice"):
		return "its notice or its permission"
	return ""


## Every credit shown, in words, scrolled into sight; and the terms its
## owner asks for, said.
func _credits(about: AcceptDialog) -> void:
	await _shot("01_about")
	var scroll: ScrollContainer = _shell.get("_about_scroll")
	var said: Dictionary = {}
	for one: Dictionary in Credits.LIST:
		var id: String = one["id"]
		var entry: Control = about.find_child("credit_" + id, true, false)
		if not _check("%s is in About" % one["name"], entry != null and entry.is_visible_in_tree()):
			continue
		scroll.ensure_control_visible(entry)
		await _frames(4)
		var words: String = _words_in(entry)
		said[id] = words
		var seen: Rect2 = scroll.get_global_rect()
		_check("...its name and terms said, in sight (%s)" % words.substr(0, 90).replace("\n", " "),
			words.contains(one["name"]) and words.contains(one["terms"]) and words.contains(one["what"])
			and seen.grow(1.0).encloses(entry.get_global_rect()))
	_check("Rebrickable's credit as its terms ask: \"Catalog data: Rebrickable\"",
		str(said.get("rebrickable", "")).contains("Catalog data: Rebrickable"))
	_check("LDraw's notice: CC BY 2.0 and CC BY 4.0, the community, the trademark",
		str(said.get("ldraw", "")).contains("CC BY 2.0 and CC BY 4.0")
		and str(said.get("ldraw", "")).contains("© the LDraw community")
		and str(said.get("ldraw", "")).contains("Estate of James Jessiman"))
	var ldraw: Node = about.find_child("credit_ldraw", true, false)
	var to: PackedStringArray = []
	for link: LinkButton in _all(ldraw, "LinkButton"):
		to.append(link.tooltip_text)
	_check("...with a link to each licence (%s)" % ", ".join(to),
		to.has("https://creativecommons.org/licenses/by/2.0/")
		and to.has("https://creativecommons.org/licenses/by/4.0/"))
	_check("BrickNet's names its licence and holder",
		str(said.get("bricknet", "")).contains("MIT License. Copyright (c) 2026 Peter Kulits"))
	_check("Godot's names its licence and its type",
		str(said.get("godot", "")).contains("MIT License") and str(said.get("godot", "")).contains("Open Sans"))
	scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
	await _frames(4)
	await _shot("01b_about_end")
	scroll.scroll_vertical = 0
	await _frames(4)


## About inside the window, and its OK on the screen.
func _fits(about: AcceptDialog) -> void:
	var screen: Rect2 = root.get_visible_rect()
	var frame := Rect2(Vector2(about.position), Vector2(about.size))
	var ok: Button = about.get_ok_button()
	var at := Rect2(frame.position + ok.get_global_rect().position, ok.size)
	var scroll: ScrollContainer = _shell.get("_about_scroll")
	var said: Control = scroll.get_child(0)
	print("    About %s in %s; its words %.0f tall, %.0f shown" % [frame, screen,
		said.size.y, scroll.size.y])
	_check("About is inside the window", screen.grow(1.0).encloses(frame))
	_check("...and its OK on the screen", screen.grow(1.0).encloses(at))


## The licence [param id] reached by Tab from About and opened with Return:
## its words judged by [param judge] (what is wrong, or ""), the keys on
## them; then put away and About still up.
func _read(about: AcceptDialog, id: String, judge: Callable, shot: String) -> void:
	var one: Dictionary = Credits.find(id)
	var link: Control = about.find_child("read_" + id, true, false)
	if not _check("a link to %s" % one["full"], link != null and link.is_visible_in_tree()):
		return
	about.grab_focus()
	about.get_ok_button().grab_focus()
	await _frames(3)
	var reached: Control = null
	for _n: int in 40:
		var on: Control = about.gui_get_focus_owner()
		if on == link:
			reached = on
			break
		await _key(KEY_TAB)
	_check("Tab reaches \"%s\" (%s)" % [one["full"], _said(about.gui_get_focus_owner())],
		reached == link)
	if reached == null:
		return
	await _key(KEY_ENTER)
	await _frames(10)
	var licence: AcceptDialog = _shell.get("_licence")
	if not _check("Return opens it", licence != null and licence.visible
			and licence.title == one["full"]):
		return
	var text: TextEdit = _shell.get("_licence_text")
	var wrong: String = judge.call(text.text)
	_check("...in full, %d lines (%s)" % [text.get_line_count(),
		"as it should be" if wrong.is_empty() else "missing: " + wrong], wrong.is_empty())
	_check("...as Credits.full_text says it", text.text == Credits.full_text(id))
	_check("...read only", not text.editable)
	_check("...the keys on its words, named \"%s\"" % text.accessibility_name,
		licence.gui_get_focus_owner() == text and text.accessibility_name == one["full"])
	var frame := Rect2(Vector2(licence.position), Vector2(licence.size))
	_check("...inside the window (%s)" % frame,
		root.get_visible_rect().grow(1.0).encloses(frame))
	await _key(KEY_PAGEDOWN)
	await _key(KEY_PAGEDOWN)
	_check("...and Page Down scrolls it (to line %d)" % text.get_first_visible_line(),
		text.get_line_count() < 30 or text.get_first_visible_line() > 0)
	await _shot(shot)
	_names(licence)
	if id == "godot":
		await _key(KEY_ESCAPE)
		_check("Escape puts it away", not licence.visible)
	else:
		licence.get_ok_button().pressed.emit()
		await _frames(4)
		_check("Close puts it away (%s)" % licence.get_ok_button().text,
			not licence.visible and licence.get_ok_button().text == "Close")
	_check("...and About is still up", about.visible)
	await _frames(5)


## Every control in [param window] a person can operate says a name.
func _names(window: Window) -> void:
	var unnamed: PackedStringArray = []
	var count: int = 0
	for node: Node in _all(window, ""):
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		if not (control is BaseButton or control is TextEdit or control is LineEdit):
			continue
		count += 1
		if _said_name(control).strip_edges().is_empty():
			unnamed.append("%s %s" % [control.get_class(), control.name])
	_check("%s: %d controls, every one named%s" % [window.title, count,
		"" if unnamed.is_empty() else " but " + ", ".join(unnamed)], unnamed.is_empty() and count > 0)


func _words_in(node: Node) -> String:
	var out: PackedStringArray = []
	for one: Node in _all(node, ""):
		if one is Label:
			out.append((one as Label).text)
		elif one is Button or one is LinkButton:
			out.append(str(one.get("text")))
	return "\n".join(out)


func _all(node: Node, of_class: String) -> Array[Node]:
	var out: Array[Node] = []
	if node == null:
		return out
	for child: Node in node.get_children(true):
		if of_class.is_empty() or child.is_class(of_class):
			out.append(child)
		out.append_array(_all(child, of_class))
	return out


func _said(control: Control) -> String:
	if control == null:
		return "nothing"
	return "%s \"%s\"" % [control.get_class(), _said_name(control)]


## What a screen reader calls [param control]: its name, or a button's
## words (a LinkButton is no Button, and is read by its words too).
func _said_name(control: Control) -> String:
	var name: String = control.accessibility_name
	if name.is_empty() and (control is Button or control is LinkButton):
		name = str(control.get("text"))
	return name


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _shot(name: String) -> void:
	if _shots.is_empty():
		return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.save_png(_shots.path_join(name + ".png"))
	print("    picture: %s" % _shots.path_join(name + ".png"))


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	print("")
	if _failures == 0:
		print("about credits probe: all checks passed")
	else:
		print("about credits probe: %d check(s) FAILED" % _failures)
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(1 if _failures > 0 else 0)
