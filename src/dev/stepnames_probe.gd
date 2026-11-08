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
const WATCHDOG := 900.0

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
		and not said.is_empty() and said[0] == "step 3 named “%s”" % COCKPIT)
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
	_check("...and the file byte for byte (%s)" % ("the same" if kept == fixture
		else _first_difference(fixture, kept)), kept == fixture)
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
	# Counted as opened, its parts named: the check is the Delete's and the
	# Undo's, one part each way, whatever else the open put in the model.
	var opened: int = _world.brick_count()
	var parts: PackedStringArray = []
	for each: BrickWorld.Brick in _world.bricks():
		parts.append(each.part_id)
	# The keys given back to the model, as a click in it gives them: the
	# Delete key is a field's while one has them.
	root.gui_release_focus()
	await _frames(4)
	await _key(KEY_DELETE)
	await _settled()
	said = _builder.history_words(1)
	_check("the 3001 picked (%d selected of %d parts: %s), deleted by the Delete key (%d left), Undo says \"%s\"" % [
		picked, opened, ", ".join(parts), _world.brick_count(), said[0] if not said.is_empty() else ""],
		picked == 1 and _world.brick_count() == opened - 1 and _id_of("3001") < 0
		and not said.is_empty() and said[0] == "removed 1 part")
	_shell.run("undo")
	await _settled()
	var looks: Dictionary = _world.step_looks.get("|1", {})
	_check("...undone: %d parts again (%d), the 3001 back, and step 2's zoom and words back (%s)" % [
		opened, _world.brick_count(), JSON.stringify(looks).left(120)], _world.brick_count() == opened
		and _id_of("3001") >= 0 and is_equal_approx(float(looks.get("zoom", 0.0)), 1.5)
		and looks.has("notes"))

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
	_main.queue_free()
	await _frames(4)
	_main = null


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
