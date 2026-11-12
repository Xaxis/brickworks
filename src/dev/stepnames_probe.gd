## A step's name (stepnames, APP_UX6 #9), as Studio names a step: given on
## the timeline, said beside its number there, in Build it and on the
## booklet's page, and kept in the file.
##
##   godot --path . --resolution 1400x900 --script src/dev/stepnames_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh stepnames_probe
##   PROBE_SIZE=390x844 tools/probe.sh stepnames_probe     a phone: Build it alone
##   PROBE_SIZE=1024x768 tools/probe.sh stepnames_probe    a tablet: Build it alone
##
## The bar (docs/APP_UX6.md, the units, row 9), on steps4 (four steps of the
## author's, step 2 zoomed with words on its page, step 3 on a new page):
##
##   1. Through the sign-in screen (gate_for_probe), a throwaway account let
##      in, as gate_probe lets one in.
##   2. The timeline on step 3, in the author's steps: Name… clicked where it
##      is drawn, "Build the cockpit" typed, Return. The timeline says
##      "Step 3 of 4 · Build the cockpit", inside the window; Undo names it,
##      one undo step. Build › Steps › Name the step… is a row, Shift-F2
##      asks again with the name in the field.
##   3. edit_steps {"op": "name", "step": 2, "name": "The first brick"}: one
##      call names step 2, and edit_steps' list says both names.
##   4. Saved: the file is the file saved before the names with exactly two
##      lines more, "0 !BRICKWORKS STEP_NAME ..." in steps 2 and 3. Opened
##      again, the timeline says the names; saved again, byte for byte.
##   5. The booklet: step 3's page prints "Build the cockpit" beside its
##      number, on the number's line, after it, in the HTML and in the 300
##      dpi PNG (ink where the words are; pictured).
##   6. An older build: src/dev/fixtures/stepnames/named.ldr (the names as
##      this build writes them) opened whole, every part and step, and saved
##      with each STEP_NAME line in its step, byte for byte; named_theirs.ldr,
##      the same by another author, the same. Run on the build before this
##      one, it is how an older build treats the files: both open whole;
##      another author's file keeps its lines (every build writes it back as
##      it was), while Brickworks' own is written whole from the model and
##      loses the line, as every app line an older build does not know.
##   7. pkreview's finding: steps4, its 3001 selected and Delete pressed, so
##      step 2 and its look go: Undo says "removed 1 part" (it said "changed
##      2 parts"), and gives back the part and the look.
##   8. A name of 80 characters: the timeline's words cut with an ellipsis,
##      nothing of the timeline past the window's right edge.
##   9. Build it, on a shared link of the named file, as anybody with the
##      link opens it, with its steps worked out here and with the steps a
##      share carries: Next tapped to step 3, "Build the cockpit" on a line
##      of its own under "Step 3 of 4", inside the window; step 2 "The first
##      brick"; step 4 no name.
##  10. snreview's findings (2026-11-09), on its fixtures (five, row,
##      theirs_odd and its CRLF twin, sub; 7140-1.mpd). F1: a step that kept
##      none of its parts names no step and gives it no zoom: five's step 3's
##      only part on to step 4 is "Delta pair", back to step 2 "Bravo
##      bricks", step 1 deleted "Bravo bricks" at its zoom; row's the same;
##      a merge keeps the first step's look; each saved, opened, undone.
##      F2, F3: theirs_odd's two names in a step read as the first, both
##      lines kept; saved, every name line as written where it was (spaces,
##      a tab, the header's, an empty last step's, one after NOFILE), and so
##      after a step edit, in LF and CRLF. F7: name_of's Unicode spaces and
##      its cut on a whole letter. F4: a name with quotes said quoted in the
##      reply, Undo and the list. F6: the step picture's alt escaped once.
##      F8: sub.ldr's wing step named, said for both copies; its "Both wings
##      on" shows nowhere, its line kept. F5: edit_steps names a callout's
##      step by callout_step=.
##
## At a phone's and a tablet's size (a window under 1200 wide) the layout
## for a finger, and 9 alone: Build it is what a phone has of the steps.
## Pictures in shots/stepnames/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/stepnames/"
const STEPS4 := "res://src/dev/fixtures/pullkept/steps4.ldr"
const NAMED := "res://src/dev/fixtures/stepnames/named.ldr"
const NAMED_THEIRS := "res://src/dev/fixtures/stepnames/named_theirs.ldr"
const MODELS := "user://models/"
const COCKPIT := "Build the cockpit"
const BRICK := "The first brick"
const LONG := "Put the long wing plates on both sides, then the tail fin and its two flaps last"
const WATCHDOG := 1800.0

var _failures: int = 0
var _out: String = ""
var _size: Vector2i
var _finger: bool = false
var _main: Node
var _shell: Shell
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _library: PartLibrary
var _steps: StepsBar
var _socket: CommandSocket
var _rpc_id: int = 0
var _pointer: Vector2 = Vector2.ZERO


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("stepnames_probe: needs a window")
		quit(1)
		return
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(WATCHDOG).timeout.connect(func() -> void:
		print("stepnames_probe: FAILED, not finished in %d s" % int(WATCHDOG))
		quit(1))
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_size = DisplayServer.window_get_size()
	_finger = _size.x < 1200
	if _finger:
		# The layout for a finger, as a phone's or a tablet's browser gets it.
		Phone._on = 1
		Phone._wide = _size.x >= 600
	_out = SHOTS + "%dx%d/" % [_size.x, _size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	DirAccess.make_dir_recursive_absolute(MODELS)
	print("stepnames_probe: a %dx%d window%s" % [_size.x, _size.y,
		(", laid out for a finger (%s)" % ("tablet" if Phone._wide else "phone")) if _finger else ""])
	BuildSteps._kept.clear()
	if not _finger:
		await _editor()
		await _review()
		_main.queue_free()
		await _frames(4)
		_main = null
	await _build_it()
	print("\nstepnames_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


# -- 1-8: the editor --------------------------------------------------------------------


func _editor() -> void:
	print("\n1. through the sign-in screen")
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		if _main.get("_shell") != null and _main.get("_world") != null:
			break
	await _frames(60)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_steps = _main.get("_steps")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var account: Account = _main.get("_account")
	var gate: SignInGate = _main.get("_gate")
	_check("the sign-in screen is up before anyone is in", gate != null and gate.visible)
	while account.state == Account.State.CHECKING:
		await account.changed
	# A throwaway account let in, as signing in lets one in (gate_probe).
	account.email = "stepnames-probe@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	await _frames(20)
	_check("...and gone once a throwaway account is signed in", gate == null or not gate.visible)

	print("\n2. step 3 named on the timeline")
	var plain: String = FileAccess.get_file_as_string(STEPS4)
	_write(MODELS + "sn_steps4.ldr", plain)
	await _open(MODELS + "sn_steps4.ldr")
	await _say("save_model", {"name": "sn_plain.ldr"})
	var before: String = FileAccess.get_file_as_string(MODELS + "sn_plain.ldr")
	_check("steps4 opened (%d parts) and saved as it is (%d bytes)" % [_world.brick_count(),
		before.length()], _world.brick_count() == 4 and not before.is_empty())
	await _timeline_at(3)
	var named: Dictionary = _steps.controls_by_name()
	var button: Control = named.get("steps_name")
	_check("the timeline on step 3 of the author's steps (%s), its Booklet row with Name… (%s)" % [
		_caption(), _said_control(button)], _caption().begins_with("Step 3 of 4")
		and button != null and button.is_visible_in_tree())
	var depth: int = _builder.history_depth()
	var dialog: ConfirmationDialog = null
	var pressed: bool = await _press_on(button)
	if pressed:
		dialog = _steps.get("_naming")
	var asked: bool = dialog != null and dialog.visible
	_check("Name… clicked where it is drawn asks for the name (%s)" % (
		"\"%s\", OK reads %s" % [_label_in(dialog), dialog.ok_button_text] if asked else "nothing asked"),
		asked)
	if asked:
		await _shot("2_asked")
		await _type(COCKPIT)
		await _key(KEY_ENTER)
		await _settled()
	var caption: String = _caption()
	_check("Return names it: the timeline says \"%s\"" % caption,
		caption.begins_with("Step 3 of 4 · %s · " % COCKPIT))
	var said: PackedStringArray = _builder.history_words(1)
	_check("...one undo step, Undo says it (%d → %d; \"%s\")" % [depth, _builder.history_depth(),
		said[0] if not said.is_empty() else ""], _builder.history_depth() == depth + 1
		and not said.is_empty() and said[0] == "step 3 named \"%s\"" % COCKPIT)
	var past: Array = _past_the_window(_steps)
	_check("...and the timeline inside the window (%s)" % (", ".join(past) if not past.is_empty()
		else "nothing past it"), past.is_empty())
	await _shot("2_named")
	var steps_menu: Array = Shell.SUBMENUS.get("steps", [])
	_check("Build › Steps › Name the step… is a row (%s)" % ("there" if steps_menu.has("step_name")
		else "no such row"), steps_menu.has("step_name"))
	if dialog != null:
		await _key(KEY_F2, true)
		_check("Shift-F2 asks again, the name in the field to type over (\"%s\")" % _field_text(),
			dialog.visible and _field_text() == COCKPIT)
		if dialog.visible:
			await _key(KEY_ESCAPE)
			_check("...and Escape puts it away, nothing changed (%s)" % _caption(),
				not dialog.visible and _builder.history_depth() == depth + 1)

	print("\n3. step 2 named over MCP")
	var reply: String = await _say("edit_steps", {"op": "name", "step": 2, "name": BRICK})
	_check("edit_steps {op: name, step: 2}: one call (\"%s\")" % reply.get_slice("\n", 0).left(120),
		reply.contains("named") and reply.contains(BRICK)
		and _builder.history_depth() == depth + 2)
	var listed: String = await _say("edit_steps", {})
	_check("edit_steps' list says both names (%s)" % _named_lines(listed),
		listed.contains("  2 \"%s\":" % BRICK) and listed.contains("  3 \"%s\":" % COCKPIT))

	print("\n4. saved and opened")
	await _say("save_model", {"name": "sn_named.ldr"})
	var first: String = FileAccess.get_file_as_string(MODELS + "sn_named.ldr")
	var added: Array = _added_lines(before, first)
	_check("saved: two lines more than before, each in its step (%s)" % [", ".join(added)],
		added == ["step 2: 0 !BRICKWORKS STEP_NAME " + BRICK,
			"step 3: 0 !BRICKWORKS STEP_NAME " + COCKPIT])
	_main.call("clear_model")
	await _frames(4)
	await _open(MODELS + "sn_named.ldr")
	await _timeline_at(3)
	_check("opened again: the timeline on step 3 says \"%s\"" % _caption(),
		_caption().begins_with("Step 3 of 4 · %s · " % COCKPIT))
	await _timeline_at(2)
	_check("...on step 2 \"%s\"" % _caption(), _caption().begins_with("Step 2 of 4 · %s · " % BRICK))
	await _timeline_at(4)
	_check("...on step 4, no name: \"%s\"" % _caption(), _caption().begins_with("Step 4 of 4 · ")
		and _caption().count(" · ") == 1)
	await _say("save_model", {"name": "sn_named.ldr"})
	var second: String = FileAccess.get_file_as_string(MODELS + "sn_named.ldr")
	_check("saved again: byte for byte (%d bytes, %s)" % [second.length(),
		"the same" if second == first else _first_difference(first, second)],
		not first.is_empty() and second == first)

	print("\n5. the booklet")
	await _booklet()

	print("\n6. the file as an older build opens it")
	var fixture: String = FileAccess.get_file_as_string(NAMED)
	_write(MODELS + "sn_fixture.ldr", fixture)
	_main.call("clear_model")
	await _frames(4)
	await _open(MODELS + "sn_fixture.ldr")
	var plan: Array = Instructions.plan(_world, _library, _store.scenery, {}, true)
	_check("named.ldr opened whole: %d parts of 4, %d steps of 4" % [_world.brick_count(), plan.size()],
		_world.brick_count() == 4 and plan.size() == 4)
	await _say("save_model", {"name": "sn_fixture_saved.ldr"})
	var kept: String = FileAccess.get_file_as_string(MODELS + "sn_fixture_saved.ldr")
	var lines: Array = _step_lines(kept, "0 !BRICKWORKS STEP_NAME")
	_check("...saved, each STEP_NAME line in its step (%s)" % ", ".join(lines),
		lines == ["step 2: 0 !BRICKWORKS STEP_NAME " + BRICK,
			"step 3: 0 !BRICKWORKS STEP_NAME " + COCKPIT])
	# Under the model's name, as the bar's Save writes it: up to metalines
	# save_model wrote "Model" into every file, whatever the model's name.
	var named_as: String = "0 %s\n0 Name: %s.ldr\n" % [_store.title, _store.title.to_snake_case()] \
		+ fixture.substr(fixture.find("\n", fixture.find("\n") + 1) + 1)
	_check("...and the file byte for byte, under the model's name (%s)" % ("the same"
		if kept == named_as else _first_difference(named_as, kept)), kept == named_as)
	# Someone else's file (its author not Brickworks), which every build
	# writes back as it was with what changed (ModelStore._source_written).
	var theirs: String = FileAccess.get_file_as_string(NAMED_THEIRS)
	_write(MODELS + "sn_theirs.ldr", theirs)
	_main.call("clear_model")
	await _frames(4)
	await _open(MODELS + "sn_theirs.ldr")
	plan = Instructions.plan(_world, _library, _store.scenery, {}, true)
	await _say("save_model", {"name": "sn_theirs_saved.ldr"})
	kept = FileAccess.get_file_as_string(MODELS + "sn_theirs_saved.ldr")
	lines = _step_lines(kept, "0 !BRICKWORKS STEP_NAME")
	_check("named_theirs.ldr (its author a designer's) opened whole, %d parts and %d steps, and saved with each STEP_NAME line in its step (%s), %s"
		% [_world.brick_count(), plan.size(), ", ".join(lines), "byte for byte" if kept == theirs
			else "not byte for byte: " + _first_difference(theirs, kept)],
		_world.brick_count() == 4 and plan.size() == 4 and lines == [
			"step 2: 0 !BRICKWORKS STEP_NAME " + BRICK, "step 3: 0 !BRICKWORKS STEP_NAME " + COCKPIT])

	print("\n7. a hand Delete that empties a step with a look, undone")
	_main.call("clear_model")
	await _frames(4)
	await _open(MODELS + "sn_steps4.ldr")
	# The timeline put away (Done), the whole model in sight to pick from.
	if _steps.visible:
		_steps.stop()
		await _frames(6)
	var brick: int = _id_of("3001")
	_builder.clear_selection()
	_builder.select_brick(brick, false)
	var picked: int = _builder.selection.size()
	# The model's parts, not the scenery: an edit to a model opened on no
	# floor of its own lays the floor's baseplate under it (Main.
	# _on_model_edited), a brick of the world's that is no part of the model.
	var opened: PackedStringArray = _model_parts()
	# The keys given back to the model, as a click in it gives them: the
	# Delete key is a field's while one has them.
	root.gui_release_focus()
	await _frames(4)
	await _key(KEY_DELETE)
	await _settled()
	said = _builder.history_words(1)
	var left: PackedStringArray = _model_parts()
	_check("the 3001 picked (%d selected of %s), deleted by the Delete key (%s left), Undo says \"%s\"" % [
		picked, ", ".join(opened), ", ".join(left), said[0] if not said.is_empty() else ""],
		picked == 1 and opened.size() == 4 and left.size() == 3 and not "3001" in left
		and not said.is_empty() and said[0] == "removed 1 part")
	_shell.run("undo")
	await _settled()
	var back: PackedStringArray = _model_parts()
	var looks: Dictionary = _world.step_looks.get("|1", {})
	_check("...undone: the model's parts as they opened (%s) and step 2's zoom and words back (%s)" % [
		", ".join(back), JSON.stringify(looks).left(120)], back == opened
		and is_equal_approx(float(looks.get("zoom", 0.0)), 1.5) and looks.has("notes"))

	print("\n8. a long name on the timeline")
	_main.call("clear_model")
	await _frames(4)
	await _open(MODELS + "sn_named.ldr")
	reply = await _say("edit_steps", {"op": "name", "step": 3, "name": LONG})
	await _timeline_at(3)
	caption = _caption()
	past = _past_the_window(_steps)
	_check("%d characters named over MCP: the timeline's words cut with an ellipsis (\"%s\")" % [
		LONG.length(), caption], caption.contains(LONG.left(20)) and caption.contains("…")
		and not caption.contains(LONG))
	_check("...nothing of the timeline past the window (%s)" % (", ".join(past) if not past.is_empty()
		else "nothing past it"), past.is_empty())
	await _shot("8_long_name")
	await _booklet(LONG, "8_booklet_long")


## The booklet made from the model open (sn_named.ldr): step 3's page, its
## number and the name [param words] beside it, on lines of their own where
## it is long, read back as the PDF and the PNG read it.
func _booklet(words: String = COCKPIT, picture: String = "5_booklet") -> void:
	var maker := BookletMaker.new()
	maker.library = _library
	maker.only = {3: true}
	BookletMaker.open_when_written = false
	_main.add_child(maker)
	await maker.make(_world, _store.scenery, "Step names")
	var document: Booklet.Document = maker.document
	maker.queue_free()
	var printed: Booklet.Page = null
	for page: Booklet.Page in document.pages if document != null else []:
		for entry: Booklet.Entry in page.entries:
			if entry.number == 3:
				printed = page
	if not _check("the booklet has step 3's page", printed != null):
		return
	var html: String = ProjectSettings.globalize_path(_out + picture + ".html")
	var writing: FileAccess = FileAccess.open(html, FileAccess.WRITE)
	writing.store_string("\n".join([Booklet.head(document), Booklet.page_html(printed, document),
		Booklet.TAIL]))
	writing.close()
	var written: String = FileAccess.get_file_as_string(html)
	var first_words: String = words.left(12)
	_check("its HTML says \"%s\" (%s)" % [words, "there" if written.contains(first_words) else "not there"],
		written.contains(first_words))
	var read := BookletRead.new()
	var pages: Array = []
	await read.read_all(html, func(one: BookletRead.Page) -> void: pages.append(one))
	var number: Dictionary = {}
	var lines: Array[Dictionary] = []
	for op: Dictionary in (pages[0] as BookletRead.Page).ops if not pages.is_empty() else []:
		if op["k"] != "text":
			continue
		if str(op["text"]) == "3" and bool(op.get("bold", false)) \
				and float(op["size"]) > float(number.get("size", 0.0)):
			number = op
		if not str(op["text"]).is_empty() and words.contains(str(op["text"]).strip_edges()) \
				and str(op["text"]).length() > 3:
			lines.append(op)
	var name: Dictionary = lines[0] if not lines.is_empty() else {}
	var joined: String = " ".join(lines.map(func(op: Dictionary) -> String:
		return str(op["text"]).strip_edges()))
	if not _check("read back: the number 3 (%s) and the name on %d line%s (%s)" % [_op_said(number),
			lines.size(), "" if lines.size() == 1 else "s", " | ".join(lines.map(_op_said))],
			not number.is_empty() and joined == words):
		return
	var number_at: Vector2 = number["at"]
	var name_at: Vector2 = name["at"]
	var number_end: float = number_at.x + Helvetica.text_width("3", float(number["size"]),
		true, float(number.get("spacing", 0.0)))
	var gap: float = name_at.x - number_end
	var top: float = number_at.y - float(number["size"]) * 0.75
	var beside: bool = gap >= 0.5 and gap <= 6.0 and name_at.y <= number_at.y + 0.5 \
		and name_at.y - float(name["size"]) * 0.75 >= top - 0.5
	if lines.size() == 1:
		_check("...beside the number, after it on its line: %.1f mm after it, its words' baseline %.1f mm to the number's %.1f"
			% [gap, name_at.y, number_at.y], beside)
	else:
		var widest: float = 0.0
		var lined: bool = true
		for op: Dictionary in lines:
			lined = lined and absf((op["at"] as Vector2).x - name_at.x) < 0.1
			widest = maxf(widest, Helvetica.text_width(str(op["text"]), float(op["size"]), true,
				float(op.get("spacing", 0.0))))
		_check("...beside the number, %.1f mm after it, on %d lines from one edge, the widest %.1f mm (64 at most)"
			% [gap, lines.size(), widest], gap >= 0.5 and gap <= 6.0 and lined
			and lines.size() <= 3 and widest <= 64.5)
	# The PNG, at 300 dots an inch: ink where the words are.
	var zip: String = ProjectSettings.globalize_path(_out + picture + ".zip")
	var drawer := BookletPng.new()
	root.add_child(drawer)
	await drawer.write(html, zip, "stepnames")
	var px: float = drawer.px_per_mm
	drawer.queue_free()
	var reader := ZIPReader.new()
	var image := Image.new()
	if reader.open(zip) == OK:
		var files: PackedStringArray = reader.get_files()
		if not files.is_empty():
			image.load_png_from_buffer(reader.read_file(files[0]))
		reader.close()
	if not _check("the page's PNG (%dx%d)" % [image.get_width(), image.get_height()], not image.is_empty()):
		return
	image.save_png(ProjectSettings.globalize_path(_out + picture + "_page.png"))
	var width: float = Helvetica.text_width(str(name["text"]), float(name["size"]), true,
		float(name.get("spacing", 0.0)))
	var box := Rect2(name_at.x, name_at.y - float(name["size"]) * 0.75, width, float(name["size"]) * 0.75)
	var inked: float = _ink(image, Rect2(box.position * px, box.size * px))
	_check("...in the 300 dpi PNG, ink where the name is (%.0f%% of its box dark)" % (inked * 100.0),
		inked > 0.08)
	# The number and its name, cut out, to look at.
	var below: float = (lines[-1]["at"] as Vector2).y if not lines.is_empty() else number_at.y
	var head := Rect2(Vector2(number_at.x - 4.0, top - 4.0),
		Vector2(name_at.x + 66.0 - number_at.x, maxf(float(number["size"]), below - top) + 8.0))
	var cut: Rect2i = Rect2i(Rect2(head.position * px, head.size * px)).intersection(
		Rect2i(Vector2i.ZERO, image.get_size()))
	image.get_region(cut).save_png(ProjectSettings.globalize_path(_out + picture + "_number.png"))
	print("    pictures: %s%s_page.png, %s_number.png" % [_out.trim_prefix("res://"), picture, picture])


func _ink(image: Image, rect: Rect2) -> float:
	var area: Rect2i = Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	if area.size.x <= 0 or area.size.y <= 0:
		return 0.0
	var dark: int = 0
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			if image.get_pixel(x, y).get_luminance() < 0.5:
				dark += 1
	return float(dark) / float(area.size.x * area.size.y)


func _op_said(op: Dictionary) -> String:
	if op.is_empty():
		return "none"
	return "\"%s\" %.1f mm at %s" % [op["text"], float(op["size"]), op["at"]]


# -- 10: snreview's findings (2026-11-09), each on the reviewer's fixture --------------------

const FIX := "res://src/dev/fixtures/stepnames/"
const META := "0 !BRICKWORKS STEP_NAME"
const FIVE_SAID := "1[3020/4,3020/4] \"Alpha base\" | 2[3001/14,3001/14] \"Bravo bricks\" | 3[3003/1] \"Charlie one\" | 4[3004/2,3004/2] \"Delta pair\" | 5[3005/15] \"Echo last\""
## F1: [file, what, op, part, x (or the step's number), the steps then, [step
## index, its zoom then]].
const F1_CASES: Array = [
	["five.ldr", "step 3's only part to step 4, which is named", "next", "3003", 0.0,
		"1[3020/4,3020/4] \"Alpha base\" | 2[3001/14,3001/14] \"Bravo bricks\" | 3[3003/1,3004/2,3004/2] \"Delta pair\" | 4[3005/15] \"Echo last\"",
		[1, 1.5]],
	["five.ldr", "step 3's only part to step 2, which is named", "prev", "3003", 0.0,
		"1[3020/4,3020/4] \"Alpha base\" | 2[3001/14,3001/14,3003/1] \"Bravo bricks\" | 3[3004/2,3004/2] \"Delta pair\" | 4[3005/15] \"Echo last\"",
		[1, 1.5]],
	["five.ldr", "step 1 deleted, its parts into step 2", "delete", "", 1,
		"1[3001/14,3001/14,3020/4,3020/4] \"Bravo bricks\" | 2[3003/1] \"Charlie one\" | 3[3004/2,3004/2] \"Delta pair\" | 4[3005/15] \"Echo last\"",
		[0, 1.5]],
	["row.ldr", "step 1's only part to step 2 (named, zoomed)", "next", "3001", 0.0,
		"1[3001/1,3001/4] \"Blue\" | 2[3001/14] | 3[3001/2] \"Green\"", [0, 1.5]],
	["row.ldr", "step 2's only part (named, zoomed) to step 1: its zoom goes with its name", "prev", "3001", 100.0,
		"1[3001/1,3001/4] \"Red\" | 2[3001/14] | 3[3001/2] \"Green\"", [0, 0.0]],
	["row.ldr", "step 2 merged with step 3 (nothing taken: the first step's look)", "merge", "", 2,
		"1[3001/4] \"Red\" | 2[3001/1,3001/14] \"Blue\" | 3[3001/2] \"Green\"", [1, 1.5]],
]


func _review() -> void:
	print("\n10. snreview's findings, each on the reviewer's fixture")
	await _review_follow()
	await _review_lines()
	_review_name_of()
	await _review_words()
	await _review_alt()
	await _review_copies()
	await _review_callout()


## F1: a step that kept none of its parts gives its name (and zoom) to none.
func _review_follow() -> void:
	print("\n10. F1: a step that kept none of its parts names no step")
	for case: Array in F1_CASES:
		var fixture: String = FileAccess.get_file_as_string(FIX + str(case[0]))
		await _open_text(fixture, "r_" + str(case[0]))
		var opened: String = _steps_said()
		var depth: int = _builder.history_depth()
		var reply: String = ""
		if str(case[2]) in ["next", "prev"]:
			reply = await _say("edit_steps", {"op": case[2], "bricks": [_id_at(case[3], float(case[4]))]})
		else:
			reply = await _say("edit_steps", {"op": case[2], "step": int(case[4])})
		var after: String = _steps_said()
		var spot: Array = case[6]
		var zoom: float = float(BookletLooks.of(_world, "", int(spot[0])).get("zoom", 0.0))
		_check("%s, %s: %s (%s), step %d's zoom %s" % [case[0], case[1], after,
			reply.get_slice("\n", 0).left(80), int(spot[0]) + 1, zoom if zoom > 0.0 else "none"],
			after == str(case[5]) and is_equal_approx(zoom, float(spot[1])))
		var saved: String = await _save("r_saved.ldr")
		await _open_text(saved, "r_saved_open.ldr")
		_check("...saved and opened again the same (%s)" % ("the same" if _steps_said() == after
			else _steps_said()), _steps_said() == after)
		await _open_text(fixture, "r_" + str(case[0]))
		if str(case[2]) in ["next", "prev"]:
			await _say("edit_steps", {"op": case[2], "bricks": [_id_at(case[3], float(case[4]))]})
		else:
			await _say("edit_steps", {"op": case[2], "step": int(case[4])})
		var made: int = _builder.history_depth() - depth
		_shell.run("undo")
		await _settled()
		_check("...one undo step (%d), undone as it opened (%s)" % [made, "the same"
			if _steps_said() == opened else _steps_said()], made == 1 and _steps_said() == opened)


## F2, F3: two names in a step (the first wins, both kept), and every name
## line kept as written where it was: spaces, a tab, the header's, an empty
## last step's, one after NOFILE, in LF and in CRLF.
func _review_lines() -> void:
	for file: String in ["theirs_odd.ldr", "theirs_odd_crlf.ldr"]:
		print("\n10. F2, F3: %s, its name lines as their author wrote them" % file)
		var fixture: String = FileAccess.get_file_as_string(FIX + file)
		await _open_text(fixture, "r_" + file)
		var opened: String = _steps_said()
		var more: Variant = BookletLooks.of(_world, "", 2).get("name_more")
		_check("opened: step 3 is \"First of two\", the first of its two lines, the second kept (%s; %s)"
			% [opened, more], opened.contains("3[3003/1] \"First of two\"") and more is Array
			and str((more as Array)[0]).ends_with("STEP_NAME Second of two"))
		var last: String = str(BookletLooks.of(_world, "", 4).get("name", ""))
		_check("...step 1 named in the header, step 2's spaces and tab read as one space (%s), the empty last step named \"%s\""
			% [opened, last], opened.begins_with("1[3020/4] \"From the header\" | 2[3001/14] \"Spaced out tab\"")
			and opened.ends_with("4[3004/2]") and last == "On an empty last step")
		var plain: String = await _save("r_plain_" + file)
		_check("...saved with nothing changed: every name line as written, where it was (%s)" % (
			"the same" if _name_places(plain) == _name_places(fixture) else " ; ".join(_name_places(plain))),
			_name_places(plain) == _name_places(fixture))
		# Step 2's only part to step 3: step 2 goes, and its name with it.
		var depth: int = _builder.history_depth()
		var reply: String = await _say("edit_steps", {"op": "next", "bricks": [_id_at("3001", 0.0)]})
		var moved: String = _steps_said()
		last = str(BookletLooks.of(_world, "", 3).get("name", ""))
		_check("its 3001, step 2's only part, to step 3: \"First of two\" (%s; %s), the empty last step still \"%s\"" % [
			moved, reply.get_slice("\n", 0).left(80), last],
			moved == "1[3020/4] \"From the header\" | 2[3001/14,3003/1] \"First of two\" | 3[3004/2]"
			and last == "On an empty last step")
		var text: String = await _save("r_moved_" + file)
		var want: PackedStringArray = _name_places(fixture)
		var had: PackedStringArray = PackedStringArray()
		for place: String in want:
			if not place.contains("Spaced"):
				had.append(place.get_slice(" <- ", 0))
		var lines: PackedStringArray = PackedStringArray()
		for place: String in _name_places(text):
			lines.append(place.get_slice(" <- ", 0))
		_check("...saved: the other name lines each as written, the second of two, the empty last step's and the one after NOFILE (%s)"
			% " ; ".join(lines), lines == had and text.contains("0 NOFILE" + ("\r\n" if fixture.contains("\r\n") else "\n")
				+ "0 !BRICKWORKS STEP_NAME After the end"))
		if fixture.contains("\r\n"):
			# The TITLE and FLOOR GRID lines a save adds end LF alone in a CRLF
			# file: another unit's (snreview's, the lead's call 2026-11-09).
			var bare := PackedStringArray()
			for said: String in text.split("\n"):
				if not said.is_empty() and not said.ends_with("\r") \
						and not said.begins_with("0 !BRICKWORKS TITLE") \
						and not said.begins_with("0 !BRICKWORKS FLOOR"):
					bare.append(said)
			_check("...every line CRLF still, but the TITLE and FLOOR GRID lines (%s)"
				% ("all" if bare.is_empty() else " ; ".join(bare)), bare.is_empty())
		await _open_text(text, "r_moved_open_" + file)
		_check("...opened again the same (%s)" % ("the same" if _steps_said() == moved else _steps_said()),
			_steps_said() == moved)
		await _open_text(fixture, "r_" + file)
		depth = _builder.history_depth()
		await _say("edit_steps", {"op": "next", "bricks": [_id_at("3001", 0.0)]})
		_shell.run("undo")
		await _settled()
		var undone: String = await _save("r_undone_" + file)
		_check("...undone: as it opened, its name lines as written (%s)" % ("the same"
			if _name_places(undone) == _name_places(fixture) else " ; ".join(_name_places(undone))),
			_steps_said() == opened and _name_places(undone) == _name_places(fixture))
		var _unused: int = depth


## F7: every Unicode space and line separator is a space, a name of only those
## is none, and 80 characters cut between two of a person's letters.
func _review_name_of() -> void:
	print("\n10. F7: a name's spaces and its cut")
	var family: String = "\U01F468‍\U01F469‍\U01F467"
	var cases: Array = [
		["A B C", "A B C"], ["A\u0085B", "A B"], ["A\vB\fC", "A B C"],
		["x　y z w", "x y z w"], ["　   \t", ""],
		["a".repeat(79) + family, "a".repeat(79)], ["a".repeat(79) + "é", "a".repeat(79)],
		["a".repeat(78) + family, "a".repeat(78)],
	]
	for case: Array in cases:
		var got: String = BookletLooks.name_of(case[0])
		_check("name_of(%s) is %s (%d characters)" % [str(case[0]).c_escape().left(40),
			("\"%s\"" % got.left(20) + ("..." if got.length() > 20 else "")) if not got.is_empty() else "no name",
			got.length()], got == str(case[1]))
	var whole: String = BookletLooks.name_of("a".repeat(75) + family + "b")
	_check("...and a whole emoji kept where it fits (%d characters, ends with it: %s)" % [whole.length(),
		whole.ends_with(family)], whole == "a".repeat(75) + family)


## F4: a name quoted as a motion's is, in the reply, the list and Undo.
func _review_words() -> void:
	print("\n10. F4: a name with quotes in it, said quoted")
	await _open_text(FileAccess.get_file_as_string(FIX + "five.ldr"), "r_words.ldr")
	var called: String = "Say \"hi\" twice"
	var reply: String = await _say("edit_steps", {"op": "name", "step": 2, "name": called})
	var undo: PackedStringArray = _builder.history_words(1)
	var listed: String = await _say("edit_steps", {"op": "list"})
	var line: String = ""
	for one: String in listed.split("\n"):
		if one.strip_edges().begins_with("2 "):
			line = one.strip_edges()
	_check("edit_steps name: %s; Undo: %s; the list: %s" % [reply.get_slice("\n", 0), undo, line],
		reply.begins_with("Step 2 named \"Say 'hi' twice\"") and not undo.is_empty()
		and undo[0] == "step 2 named \"Say 'hi' twice\"" and line.begins_with("2 \"Say 'hi' twice\": "))
	_shell.run("undo")
	await _settled()


## F6: the booklet picture's alt escaped once.
func _review_alt() -> void:
	print("\n10. F6: the step picture's alt in the booklet's HTML")
	await _open_text(FileAccess.get_file_as_string(FIX + "five.ldr"), "r_alt.ldr")
	var called: String = "Tom & \"Jerry\" <b>"
	await _say("edit_steps", {"op": "name", "step": 3, "name": called})
	var maker := BookletMaker.new()
	maker.library = _library
	maker.only = {3: true}
	BookletMaker.open_when_written = false
	_main.add_child(maker)
	await maker.make(_world, _store.scenery, "Alt")
	var document: Booklet.Document = maker.document
	maker.queue_free()
	var html: String = ""
	for page: Booklet.Page in document.pages if document != null else []:
		for entry: Booklet.Entry in page.entries:
			if entry.number == 3:
				html = Booklet.page_html(page, document)
	var found: RegExMatch = RegEx.create_from_string("alt=\"(Step 3[^\"]*)\"").search(html)
	var alt: String = found.get_string(1) if found != null else "none"
	_check("alt=\"%s\"" % alt, alt == "Step 3: Tom &amp; &quot;Jerry&quot; &lt;b&gt;")
	_shell.run("undo")
	await _settled()


## F8: a name given to a step of a sub-model placed twice says it is every
## copy's; the main model's step that puts the wings on shows nowhere.
func _review_copies() -> void:
	print("\n10. F8: sub.ldr, a wing placed twice, built where it stands")
	var fixture: String = FileAccess.get_file_as_string(FIX + "sub.ldr")
	await _open_text(fixture, "r_sub.ldr")
	var opened: String = _steps_said()
	var reply: String = await _say("edit_steps", {"op": "name", "step": 2, "name": "Over MCP"})
	var then: String = _steps_said()
	_check("edit_steps name step 2: %s (%s)" % [reply.get_slice("\n", 0), then],
		reply.begins_with("Step 2 named \"Over MCP\", in each of the 2 copies of the wing")
		and then.contains("2[3020/1] \"Over MCP\"") and then.contains("4[3020/1] \"Over MCP\""))
	_shell.run("undo")
	await _settled()
	var plan: Array[Instructions.Step] = _plan()
	var fourth: Instructions.Step = null
	for step: Instructions.Step in plan:
		if step.number == 4:
			fourth = step
	var said: String = _shell.change_look("name", fourth, {"name": "Second wing plate"}) \
		if fourth != null else "no step 4"
	_check("named on the timeline at step 4, the second copy's: \"%s\"" % said,
		said == "step 4 named \"Second wing plate\", in each of the 2 copies of the wing")
	_shell.run("undo")
	await _settled()
	var shown: bool = opened.contains("Both wings on")
	_check("the main model's step 2, \"Both wings on\", puts on the wings built where they stand and shows nowhere (%s); its line kept: %s"
		% ["shown" if shown else "no step for it", (await _save("r_sub_saved.ldr")).contains(META + " Both wings on")],
		not shown)


## F5: edit_steps names a callout's step, as edit_booklet takes one.
func _review_callout() -> void:
	print("\n10. F5: 7140-1.mpd, a callout's steps named over MCP")
	await _open_text(FileAccess.get_file_as_string("res://vendor/omr/files/7140-1.mpd"), "r_7140.mpd")
	var first: Instructions.Step = null
	for _n: int in 1200:
		for step: Instructions.Step in _plan():
			if step.in_callout() and step.callout_step == 1 and step.callout_steps >= 2:
				first = step
				break
		if first != null:
			break
		await process_frame
	if not _check("a callout of two steps or more (%s)" % ("step %d" % first.number if first != null
			else "none"), first != null):
		return
	var number: int = first.number
	var reply: String = await _say("edit_steps", {"op": "name", "step": number, "callout_step": 2,
		"name": "Callout two"})
	var named: Dictionary = {}
	for step: Instructions.Step in _plan():
		if step.number == number and not step.name.is_empty():
			named["%d.%d" % [step.number, step.callout_step]] = step.name
	_check("callout_step 2: %s (%s)" % [reply.get_slice("\n", 0), named],
		reply.begins_with("Step %d's callout step 2 named \"Callout two\"" % number)
		and named == {"%d.2" % number: "Callout two"})
	var wrong: String = await _say("edit_steps", {"op": "name", "step": number, "callout_step": 99,
		"name": "Nowhere"})
	_check("...callout_step 99: %s" % wrong.get_slice("\n", 0),
		wrong.begins_with("Step %d's callout has steps 1 to %d." % [number, first.callout_steps]))
	_shell.run("undo")
	await _settled()


## Each STEP_NAME line of [param text] as written, with the line before it:
## "line <- the one before".
static func _name_places(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: PackedStringArray = text.split("\n")
	for n: int in lines.size():
		if lines[n].contains("STEP_NAME"):
			out.append("%s <- %s" % [lines[n].c_escape(), lines[n - 1].c_escape() if n > 0 else ""])
	return out


func _open_text(text: String, file: String) -> void:
	_write(MODELS + file, text)
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", MODELS + file)
	await _settled()


func _save(file: String) -> String:
	await _say("save_model", {"name": file})
	return FileAccess.get_file_as_string(MODELS + file)


func _plan() -> Array[Instructions.Step]:
	return Instructions.plan(_world, _library, _store.scenery, {}, true)


## Each step as "N[its parts]" (or "N.c[...]" in a callout) and its name,
## as snreview's probe says them.
func _steps_said() -> String:
	var out := PackedStringArray()
	for step: Instructions.Step in _plan():
		var parts := PackedStringArray()
		for id: int in step.brick_ids:
			var brick: BrickWorld.Brick = _world.get_brick(id)
			if brick != null:
				parts.append("%s/%d" % [brick.part_id.get_basename(), brick.color_code])
		parts.sort()
		var label: String = ("%d.%d" % [step.number, step.callout_step]) if step.in_callout() \
			else str(step.number)
		out.append("%s[%s]%s" % [label, ",".join(parts), (" \"%s\"" % step.name)
			if not step.name.is_empty() else ""])
	return " | ".join(out)


## The model's part [param part]: the one furthest left for [param x] under
## 50 (the file's x 0), else the one at the file's x, a hundred apart.
func _id_at(part: String, x: float) -> int:
	var found: Array = []
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id) and brick.part_id.get_basename() == part:
			found.append(brick)
	if found.is_empty():
		return -1
	found.sort_custom(func(a: BrickWorld.Brick, b: BrickWorld.Brick) -> bool:
		return a.transform.origin.x < b.transform.origin.x)
	return (found[clampi(roundi(x / 100.0), 0, found.size() - 1)] as BrickWorld.Brick).id


# -- 9: Build it on a shared link ------------------------------------------------------------


func _build_it() -> void:
	var text: String = FileAccess.get_file_as_string(NAMED)
	print("\n9. Build it on a shared link, its steps worked out here")
	var viewer: Node = await _view("St3pN4mes", text, "named.ldr")
	await _build_pages(viewer, "worked")
	# The steps a share carries (SharedPages), as Share sends them.
	var carried: String = await SharedPages.attach(text, viewer.get("_library"), viewer.get("_store"))
	viewer.queue_free()
	await _frames(4)
	print("\n9. Build it on a shared link, with the steps the share carried")
	_check("the share carries its steps (%s)" % ("PAGES line there"
		if carried.contains(SharedPages.HEAD) else "none"), carried.contains(SharedPages.HEAD))
	viewer = await _view("St3pN4mes2", carried, "named.ldr, shared with its steps")
	await _build_pages(viewer, "carried")
	viewer.queue_free()
	await _frames(4)


func _build_pages(viewer: Node, called: String) -> void:
	var view: ShareView = viewer.get("_share_view")
	var mode: BuildMode = viewer.get("_build_mode")
	if view == null or view.state != "ready":
		return
	await _tap(view.controls_by_name().get("view_build"))
	var since: int = Time.get_ticks_msec()
	while not mode.is_open() and Time.get_ticks_msec() - since < 60000:
		await process_frame
	if not _check("Build it opens", mode.is_open()):
		return
	for page: int in [2, 3, 4]:
		for _n: int in 8:
			if int(viewer.call("build_state").get("page", 0)) >= page:
				break
			await _tap(mode.controls_by_name().get("build_next"))
		await _frames(10)
		var said: Dictionary = viewer.call("build_state")
		var want: String = {2: BRICK, 3: COCKPIT, 4: ""}[page]
		var label: Label = mode.get("_step_name")
		var caption: Label = mode.get("_caption")
		var placed: bool = want.is_empty() or (label != null and label.is_visible_in_tree()
			and _inside(label) and caption != null
			and label.get_global_rect().position.y >= caption.get_global_rect().end.y - 1.0)
		_check("Next to step %d: \"%s\", its name %s" % [int(said.get("page", 0)),
			said.get("caption", ""), ("\"%s\"" % said.get("name", "")) if said.has("name") else "not said"],
			int(said.get("page", 0)) == page and str(said.get("caption", "")) == "Step %d of 4" % page
			and str(said.get("name", "")) == want and placed)
		if page == 3:
			_check("...on a line of its own under the number, inside the window (%s)" % (
				label.get_global_rect() if label != null else "no such line"), placed)
			await _shot("9_build_it_%s" % called)


func _view(id: String, text: String, called: String) -> Node:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": id, "name": "Step names", "author": "Probe Builder",
		"parts": 4, "url": "https://brickworks.diy/m/" + id, "model": text}}
	var viewer: Node = load("res://src/main.tscn").instantiate()
	viewer.set("_viewing", id)
	viewer.set("_shared", fake)
	root.add_child(viewer)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = viewer.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_check("%s opened as a shared link (%s)" % [called, view.state if view != null else "no viewer"],
		view != null and view.state == "ready")
	var steps: StepsBar = viewer.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(20)
	return viewer


# -- helpers -------------------------------------------------------------------------------


func _open(path: String) -> void:
	_main.call("_open", path)
	await _settled()


## The timeline up, in the author's steps, at the end of step [param number].
func _timeline_at(number: int) -> void:
	if not _steps.visible:
		_shell.run("timeline")
	for _n: int in 900:
		await process_frame
		if _steps.visible and not _steps.is_starting():
			break
	if _steps.mode() != StepsBar.AUTHORS:
		_steps.set_mode(StepsBar.AUTHORS)
		await _frames(10)
	_steps.to_start()
	for _n: int in number:
		_steps.step_forward()
	await _frames(10)


func _caption() -> String:
	return str(_steps.page_state().get("caption", ""))


func _said_control(control: Control) -> String:
	if control == null:
		return "no such button"
	return "\"%s\"%s" % [(control as Button).text if control is Button else control.name,
		"" if control.is_visible_in_tree() else ", not shown"]


func _label_in(dialog: ConfirmationDialog) -> String:
	for label: Node in dialog.find_children("*", "Label", true, false):
		if not (label as Label).text.is_empty() and (label as Label).is_visible_in_tree():
			return (label as Label).text
	return ""


func _field_text() -> String:
	var field: Variant = _steps.get("_naming_field")
	return (field as LineEdit).text if field is LineEdit else ""


func _named_lines(listed: String) -> String:
	var out := PackedStringArray()
	for line: String in listed.split("\n"):
		if line.contains("\""):
			out.append(line.strip_edges().left(60))
	return " | ".join(out) if not out.is_empty() else "no step named"


## The lines of [param after] not in [param before], each with its step.
func _added_lines(before: String, after: String) -> Array:
	var had: Dictionary = {}
	for line: String in before.split("\n"):
		had[line.strip_edges()] = true
	return _step_lines(after, "").filter(func(said: String) -> bool:
		return not had.has(said.substr(said.find(": ") + 2)))


## Each line of [param text] starting [param start] ("" every line not had
## before, by _added_lines), as "step N: line".
func _step_lines(text: String, start: String) -> Array:
	var out: Array = []
	var step: int = 1
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line == "0 STEP":
			step += 1
			continue
		if line.is_empty() or (not start.is_empty() and not line.begins_with(start)):
			continue
		out.append("step %d: %s" % [step, line])
	return out


func _first_difference(a: String, b: String) -> String:
	var one: PackedStringArray = a.split("\n")
	var two: PackedStringArray = b.split("\n")
	for n: int in mini(one.size(), two.size()):
		if one[n] != two[n]:
			return "line %d: %s | %s" % [n + 1, one[n].strip_edges().left(80), two[n].strip_edges().left(80)]
	return "%d lines and %d" % [one.size(), two.size()]


## The model's parts by number, sorted, scenery (the floor's baseplate)
## left out.
func _model_parts() -> PackedStringArray:
	var out := PackedStringArray()
	for brick: BrickWorld.Brick in _world.bricks():
		if not _store.scenery.has(brick.id):
			out.append(brick.part_id)
	out.sort()
	return out


func _id_of(part: String) -> int:
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part:
			return brick.id
	return -1


## What of [param control] lies past the window's right or bottom edge.
func _past_the_window(control: Control) -> Array:
	var out: Array = []
	var seen: Rect2 = root.get_visible_rect()
	for node: Node in [control] + control.find_children("*", "Control", true, false):
		var each: Control = node
		if not each.is_visible_in_tree() or each.size.x <= 0.0:
			continue
		var rect: Rect2 = each.get_global_rect()
		if rect.end.x > seen.end.x + 0.5 or rect.end.y > seen.end.y + 0.5:
			out.append("%s %.0f past" % [each.name, maxf(rect.end.x - seen.end.x, rect.end.y - seen.end.y)])
	return out.slice(0, 6)


func _inside(control: Control) -> bool:
	var rect: Rect2 = control.get_global_rect()
	var seen: Rect2 = root.get_visible_rect()
	return rect.position.x >= seen.position.x - 0.5 and rect.end.x <= seen.end.x + 0.5 \
		and rect.position.y >= seen.position.y - 0.5 and rect.end.y <= seen.end.y + 0.5


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _settled() -> void:
	for _n: int in 600:
		if _store == null or _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)


func _say(tool: String, arguments: Dictionary) -> String:
	_rpc_id += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _rpc_id,
		"method": "tools/call", "params": {"name": tool, "arguments": arguments}})
	var text: String = ""
	for block: Dictionary in ((answer as Dictionary).get("result", {}) as Dictionary).get("content", []):
		text += str(block.get("text", ""))
	if text.is_empty() and (answer as Dictionary).has("error"):
		text = str((answer as Dictionary)["error"])
	var lines: PackedStringArray = text.split("\n")
	while lines.size() > 1 and (lines[0].begins_with("Tab ") or lines[0].begins_with("Careful")):
		lines.remove_at(0)
	return "\n".join(lines)


func _type(words: String) -> void:
	for n: int in words.length():
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = words.unicode_at(n)
		Input.parse_input_event(key)
		await process_frame
		key = key.duplicate()
		key.pressed = false
		Input.parse_input_event(key)
	await _frames(4)


func _key(code: Key, shift: bool = false) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.shift_pressed = shift
		key.pressed = down
		Input.parse_input_event(key)
		await _frames(2)
	await _frames(8)


func _press_on(control: Control) -> bool:
	if control == null or not control.is_visible_in_tree():
		return false
	var seen: Rect2 = control.get_global_rect().intersection(root.get_visible_rect())
	if seen.size.x < 8.0 or seen.size.y < 8.0:
		return false
	var at: Vector2 = seen.get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.relative = motion.position - _pointer
	_pointer = motion.position
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		if down:
			event.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(10)
	return true


## A finger's tap on [param control], as a phone sends it; a click with the
## mouse in a desktop's window.
func _tap(control: Control) -> void:
	if control == null:
		return
	if not _finger:
		await _press_on(control)
		await _frames(10)
		return
	var at: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await process_frame
	await _frames(12)
	await RenderingServer.frame_post_draw


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(10)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out + name + ".png"))
	print("    picture: %s%s.png" % [_out.trim_prefix("res://"), name])
