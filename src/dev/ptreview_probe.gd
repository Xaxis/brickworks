## ptreview: an independent review's reproductions for pagetools (8835f52aa):
## page lock and freeze through every path that writes the page, and the
## file through an older build's order. Reports what happens; each check
## names the behaviour the review expects, so a FAIL is a finding. ptfix
## added E: every writer the page editor, the steps bar and Apply to later
## pages use (Shell.change_look's ops and place_pages), refused on a locked
## page, and what a lock is not (a name, steps a page, the outline) let
## through.
##
##   godot --headless --path . --script src/dev/ptreview_probe.gd -- [--into=DIR]
##
## Headless: lay_out_only and the MCP tools need no pictures.
extends SceneTree

const GATEHOUSE := "res://tests/fixtures/steps/gatehouse.mpd"

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _library: PartLibrary
var _steps: StepsBar
var _tools: AppTools
var _out: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.trim_prefix("--into=")
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("ptreview_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	BookletMaker.open_when_written = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_library = _main.get("_library")
	_steps = _main.get("_steps")
	_tools = AppTools.new()
	_tools.app = _main
	_tools.assistant = _main.get("_assistant")
	await _open(ProjectSettings.globalize_path(GATEHOUSE))
	await _mcp_on_locked()
	await _gate_on_locked()
	await _breaks_on_locked()
	await _setup_on_locked()
	await _four_locked()
	await _false_alone()
	await _older_order()
	await _odd_words()
	await _sub_model_lock()
	print("")
	print("ptreview: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	_main.queue_free()
	await _frames(2)
	quit(1 if _failures > 0 else 0)


func _open(path: String) -> void:
	_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", path)
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)
	print("  (opened %s: %d parts)" % [path.get_file(), _world.brick_count()])
	if not _steps.visible:
		await _steps.start(_world, _library, _store.scenery)
	await _frames(4)


func _history() -> int:
	return _builder._history.size()


func _undo_to(count: int) -> void:
	while _history() > count:
		_builder.undo()
	await _frames(2)


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _laid() -> Array[Booklet.Page]:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "gatehouse")
	maker.queue_free()
	return pages


static func _page_with(pages: Array[Booklet.Page], number: int) -> Booklet.Page:
	for page: Booklet.Page in pages:
		if page.kind == "steps" and page.entries.any(func(entry: Booklet.Entry) -> bool:
				return entry.number == number):
			return page
	return null


static func _numbers(page: Booklet.Page) -> Array:
	return page.entries.map(func(entry: Booklet.Entry) -> int: return entry.number) if page != null else []


## Where everything on the page is: each step's picture, parts box and number,
## and how many notes and arrows the designer put on it.
static func _where(page: Booklet.Page) -> Array:
	var out: Array = []
	if page == null:
		return out
	for entry: Booklet.Entry in page.entries:
		out.append([entry.number, entry.rect, entry.parts_rect, entry.number_at, entry.place.duplicate(true),
			entry.notes.size(), entry.drawn_arrows.size()])
	return out


func _run_tool(tool: String, input: Dictionary) -> String:
	return str(await _tools.run(tool, input))


## A page of [param size] steps, not the first page of steps; its first step's number.
func _page_of_size(size: int) -> int:
	var pages: Array[Booklet.Page] = await _laid()
	var seen: int = 0
	var fallback: int = -1
	for page: Booklet.Page in pages:
		if page.kind != "steps" or page.entries.size() != size:
			continue
		seen += 1
		if fallback < 0:
			fallback = page.entries[0].number
		if seen >= 2:
			return page.entries[0].number
	return fallback


# -- A: the MCP tools on a locked page --------------------------------------------


func _mcp_on_locked() -> void:
	print("")
	print("A: edit_booklet place=, text=, arrow=, back= on a locked page")
	var start: int = _history()
	await _run_tool("edit_booklet", {"step": 1, "per_page": 2})
	var lead: int = await _page_of_size(2)
	if not _check("a page of 2 steps to lock: step %d" % lead, lead > 0):
		return
	var said: String = await _run_tool("edit_booklet", {"step": lead, "lock": true})
	print("    lock: %s" % said)
	var history: int = _history()
	var before: Array = _where(_page_with(await _laid(), lead))
	for input: Dictionary in [
			{"step": lead, "place": {"item": "picture", "x": 40, "y": 40}},
			{"step": lead, "place": {"item": "number", "x": 120, "y": 30}},
			{"step": lead, "text": {"words": "Added on a locked page", "x": 30, "y": 120}},
			{"step": lead, "arrow": {"x1": 30, "y1": 30, "x2": 80, "y2": 80}}]:
		var at: int = _history()
		var reply: String = await _run_tool("edit_booklet", input)
		var now: Array = _where(_page_with(await _laid(), lead))
		_check("%s on locked page (step %d) refused, nothing written: \"%s\" (undo steps +%d, page %s)" % [
			input.keys().filter(func(k: String) -> bool: return k != "step")[0], lead, reply.left(110),
			_history() - at, "unchanged" if now == before else "CHANGED"],
			_history() == at and now == before)
	# back=true on a picture placed before the lock.
	await _undo_to(history - 1)
	await _run_tool("edit_booklet", {"step": lead, "place": {"item": "picture", "x": 30, "y": 30}})
	await _run_tool("edit_booklet", {"step": lead, "lock": true})
	var placed: Array = _where(_page_with(await _laid(), lead))
	var at_back: int = _history()
	var reply_back: String = await _run_tool("edit_booklet", {"step": lead,
		"place": {"item": "picture", "back": true}})
	_check("back=true on a locked page refused: \"%s\" (undo steps +%d, page %s)" % [reply_back.left(110),
		_history() - at_back, "unchanged" if _where(_page_with(await _laid(), lead)) == placed else "CHANGED"],
		_history() == at_back)
	await _undo_to(start)


# -- E: every writer through the one gate --------------------------------------


static func _step_of(plan: Array[Instructions.Step], number: int) -> Instructions.Step:
	for step: Instructions.Step in plan:
		if step.number == number and step.callout_step == 0:
			return step
	return null


func _gate_on_locked() -> void:
	print("")
	print("E: the page editor's writers, the step commands and Apply to later pages on a locked page")
	var start: int = _history()
	await _run_tool("edit_booklet", {"step": 1, "per_page": 2})
	var lead: int = await _page_of_size(2)
	if not _check("a page of 2 steps to lock: step %d" % lead, lead > 0):
		await _undo_to(start)
		return
	# Words and an arrow on it before the lock: the Turn and Opacity boxes,
	# the words field and the arrow's buttons have them to change.
	await _run_tool("edit_booklet", {"step": lead, "text": {"words": "Before the lock", "x": 30, "y": 120}})
	await _run_tool("edit_booklet", {"step": lead, "arrow": {"x1": 30, "y1": 30, "x2": 60, "y2": 60}})
	await _run_tool("edit_booklet", {"step": lead, "lock": true})
	var plan: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {}, true)
	var held: Array = _numbers(_page_with(await _laid(), lead))
	var first: Instructions.Step = _step_of(plan, lead)
	var second: Instructions.Step = _step_of(plan, int(held[1])) if held.size() > 1 else null
	if not _check("its steps %s, the first and second found" % str(held), first != null and second != null):
		await _undo_to(start)
		return
	var picture := Image.create(4, 4, false, Image.FORMAT_RGB8)
	picture.fill(Color.ORANGE)
	var data: String = Marshalls.raw_to_base64(picture.save_png_to_buffer())
	var text: String = _store.to_text("gatehouse", true)
	var page: Array = _where(_page_with(await _laid(), lead))
	var room: Array = BookletLooks.said_rect(_page_with(await _laid(), lead).entries[0].panel)
	for spec: Array in [
			[first, "note", {"index": 0, "turn": 30.0, "room": room}, "the Turn box"],
			[first, "note", {"index": 0, "opacity": 0.5, "room": room}, "the Opacity box"],
			[first, "note", {"index": 0, "text": "Reworded", "room": room}, "the words field"],
			[first, "note", {"index": 0, "size": 6.0, "room": room}, "Words larger"],
			[first, "note", {"index": 0, "remove": true, "room": room}, "Put back on words"],
			[first, "arrow", {"at": [40, 40, 90, 90], "colour": "red", "width": 0.9, "room": room},
				"an arrow armed before the lock"],
			[first, "arrow_edit", {"index": 0, "colour": "black", "room": room}, "Arrow colour"],
			[first, "image", {"data": data, "at": [150, 120, 20, 20], "room": room},
				"a picture the file picker returns after it"],
			[first, "place", {"item": "picture", "at": null, "room": room}, "Put back on its picture"],
			[second, "place", {"item": "number", "at": [100, 100], "room": room}, "a drag on its second step"],
			[second, "bigger", {}, "Bigger"], [second, "smaller", {}, "Smaller"],
			[second, "zoom_in", {}, "Zoom in"], [second, "turn_left", {}, "Turn left"],
			[second, "tilt_up", {}, "Tilt up"], [second, "parts", {}, "Parts list"],
			[second, "sign", {}, "the turn sign"], [second, "new_page", {}, "New page"],
			[first, "alone", {}, "A page alone"], [second, "set", {"size": 1.5}, "size="],
			[first, "set", {"page": null}, "page=auto"], [second, "page_lock", {"steps": 1}, "a lock inside it"],
			[second, "page_freeze", {}, "a freeze inside it"]]:
		var at: int = _history()
		var reply: String = _shell.change_look(spec[1], spec[0], spec[2])
		_check("%s (%s on step %d): refused, nothing written: \"%s\" (undo +%d, file %s)" % [spec[3], spec[1],
			(spec[0] as Instructions.Step).number, reply.left(80), _history() - at,
			"as it was" if _store.to_text("gatehouse", true) == text else "CHANGED"],
			_history() == at and reply.contains("is locked") and _store.to_text("gatehouse", true) == text)
	var applied: String = _shell.place_pages([[second, {"picture": [20, 20, 60, 60]}, room]], "a test's layout")
	_check("Apply to later pages / follow= given its step: passed by (\"%s\"), nothing written" % applied,
		applied.contains("passed by") and _store.to_text("gatehouse", true) == text)
	_check("...and the page as it was", _where(_page_with(await _laid(), lead)) == page)
	# What is not the page's goes through on it.
	var at_free: int = _history()
	var named: String = _shell.change_look("name", second, {"name": "Locked but named"})
	var per: String = _shell.change_look("set", second, {"per_page": 4})
	var outline: String = _shell.change_look("highlight", second, {"highlight": false})
	_check("a name (\"%s\"), steps a page (\"%s\") and the outline (\"%s\") go through: undo +%d" % [
		named.left(40), per.left(40), outline.left(40), _history() - at_free], _history() == at_free + 3)
	await _undo_to(at_free)
	# Unlocked, the same edit goes through.
	var unlocked: String = _shell.change_look("page_lock", first)
	var at_bigger: int = _history()
	var bigger: String = _shell.change_look("bigger", second)
	_check("unlocked (\"%s\"), Bigger on step %d goes through (\"%s\", undo +%d)" % [unlocked.left(40),
		second.number, bigger.left(40), _history() - at_bigger], _history() == at_bigger + 1
		and not bigger.contains("locked"))
	await _undo_to(start)


# -- B: page breaks on a locked page --------------------------------------------


func _breaks_on_locked() -> void:
	print("")
	print("B: page= on a locked page's steps")
	var start: int = _history()
	await _run_tool("edit_booklet", {"step": 1, "per_page": 2})
	var lead: int = await _page_of_size(2)
	await _run_tool("edit_booklet", {"step": lead, "lock": true})
	var held: Array = _numbers(_page_with(await _laid(), lead))
	var at: int = _history()
	var reply: String = await _run_tool("edit_booklet", {"step": lead, "page": "alone"})
	var now: Array = _numbers(_page_with(await _laid(), lead))
	_check("page=\"alone\" on the locked page's first step: refused, or the page alone (\"%s\"; undo +%d; page holds %s, was %s)"
		% [reply.left(90), _history() - at, str(now), str(held)],
		(_history() == at) or now == [lead])
	await _undo_to(at)
	var second: int = int(held[1]) if held.size() > 1 else -1
	if second > 0:
		reply = await _run_tool("edit_booklet", {"step": second, "page": "new"})
		var page: Booklet.Page = _page_with(await _laid(), second)
		_check("page=\"new\" on its second step %d: refused, or a new page there (\"%s\"; undo +%d; step %d's page holds %s)"
			% [second, reply.left(90), _history() - at, second, str(_numbers(page))],
			(_history() == at) or (page != null and page.entries[0].number == second))
		await _undo_to(at)
	# page=auto takes a page break off over MCP, which Shell's new_page refuses.
	await _undo_to(at - 1)
	await _run_tool("edit_booklet", {"step": lead, "page": "new"})
	await _run_tool("edit_booklet", {"step": lead, "lock": true})
	var at_auto: int = _history()
	reply = await _run_tool("edit_booklet", {"step": lead, "page": "auto"})
	_check("page=\"auto\" on a locked page's first step refused as new_page is (\"%s\"; undo +%d)" % [
		reply.left(90), _history() - at_auto], _history() == at_auto)
	await _undo_to(start)


# -- C: page setup on a locked page ---------------------------------------------


func _setup_on_locked() -> void:
	print("")
	print("C: the booklet's page set up again, a locked (not frozen) page")
	var start: int = _history()
	await _run_tool("edit_booklet", {"step": 1, "per_page": 2})
	var lead: int = await _page_of_size(2)
	await _run_tool("edit_booklet", {"step": lead, "lock": true})
	var before: Array = _where(_page_with(await _laid(), lead))
	var reply: String = await _run_tool("page_setup", {"margin": 25})
	var after: Array = _where(_page_with(await _laid(), lead))
	_check("page_setup margin=25 (\"%s\"): the locked page's items did not move\n        before %s\n        after  %s"
		% [reply.left(60), str(before), str(after)], before == after)
	await _undo_to(start)


# -- D: a locked page of four ------------------------------------------------------


func _four_locked() -> void:
	print("")
	print("D: a locked page of 4 steps holds them when they grow")
	var start: int = _history()
	await _run_tool("edit_booklet", {"step": 1, "per_page": 4})
	var lead: int = await _page_of_size(4)
	if lead < 0:
		print("    (no page of 4 steps in the gatehouse at per_page=4)")
		lead = await _page_of_size(2)
	if not _check("a page to lock: step %d" % lead, lead > 0):
		await _undo_to(start)
		return
	await _run_tool("edit_booklet", {"step": lead, "lock": true})
	var held: Array = _numbers(_page_with(await _laid(), lead))
	for input: Dictionary in [{"tool": "page_setup", "args": {"margin": 30, "number": 20, "parts": 2}},
			{"tool": "edit_booklet", "args": {"step": lead, "size": 2}}]:
		var at: int = _history()
		var reply: String = await _run_tool(input["tool"], input["args"])
		var now: Array = _numbers(_page_with(await _laid(), lead))
		_check("%s %s (\"%s\"): the locked page still holds %s (holds %s)" % [input["tool"],
			JSON.stringify(input["args"]), reply.left(50), str(held), str(now)], now == held)
		await _undo_to(at)
	await _undo_to(start)


# -- L: false as absent, and what is said -------------------------------------------


func _false_alone() -> void:
	print("")
	print("L: lock=false / freeze=false alone on a page not held")
	var at: int = _history()
	var reply: String = await _run_tool("edit_booklet", {"step": 1, "lock": false})
	_check("lock=false alone on an unlocked page: nothing written, and the reply names lock= (\"%s\")" % reply.left(140),
		_history() == at and reply.contains("lock"))
	await _undo_to(at)


# -- G: an older build's order --------------------------------------------------


func _older_order() -> void:
	print("")
	print("G: a step with PAGE NEW and PAGE LOCK as an older build writes it whole")
	var start: int = _history()
	await _run_tool("edit_booklet", {"step": 1, "per_page": 2})
	var lead: int = await _page_of_size(2)
	await _run_tool("edit_booklet", {"step": lead, "page": "new"})
	await _run_tool("edit_booklet", {"step": lead, "lock": true})
	await _run_tool("edit_booklet", {"step": lead, "freeze": true})
	var text: String = _store.to_text("gatehouse", true)
	_write(_out.path_join("g_new_build.mpd"), text)
	# What a build before pagetools writes for that step when it writes the
	# model whole: the same _step_lines, with the lines it could not read as
	# "unread" (they are read now, so build the look by hand).
	var older := PackedStringArray()
	var lines: PackedStringArray = text.split("\n")
	var ours: Array = []
	for line: String in lines:
		if line.begins_with("0 !BRICKWORKS PAGE LOCK") or line.begins_with("0 !BRICKWORKS PAGE FREEZE"):
			ours.append(line)
	BookletLooks._step_lines(older, {"|9": {"page": "new", "unread": ours}}, "", 9, true, "", {})
	print("    an older build writes the step's lines: %s" % str(older))
	print("    this build writes them:                 %s" % str(Array(lines).filter(func(line: String) -> bool:
		return line.begins_with("0 !BRICKWORKS PAGE"))))
	# The file as the older build left it: the lock and freeze lines above PAGE NEW.
	var swapped := PackedStringArray()
	var held: Array = []
	for line: String in lines:
		if line in ours:
			held.append(line)
			continue
		if line == "0 !BRICKWORKS PAGE NEW" and not ours.is_empty():
			for one: String in ours:
				swapped.append(one)
		swapped.append(line)
	var old_text: String = "\n".join(swapped)
	var path: String = _out.path_join("g_older_build.mpd")
	_write(path, old_text)
	await _open(path)
	var again: String = _store.to_text("gatehouse", true)
	_write(_out.path_join("g_older_resaved.mpd"), again)
	_check("the older build's file opened and saved unedited, byte for byte (%d vs %d bytes, same: %s)" % [
		old_text.length(), again.length(), again == old_text], again == old_text)
	await _open(ProjectSettings.globalize_path(GATEHOUSE))
	await _undo_to(start)


# -- H: odd words on a frozen page --------------------------------------------------


func _odd_words() -> void:
	print("")
	print("H: a frozen page's header of odd words, saved and opened again")
	var odd: String = "Gate [left] {x} \"q\" <b>&amp; \\n ünï 🧱 0 STEP"
	await _run_tool("page_setup", {"header": odd, "footer": "  two  spaces  "})
	await _run_tool("edit_booklet", {"step": 1, "per_page": 2})
	var lead: int = await _page_of_size(2)
	var said: String = await _run_tool("edit_booklet", {"step": lead, "freeze": true})
	await _run_tool("page_setup", {"header": "", "footer": ""})
	var text: String = _store.to_text("gatehouse", true)
	var frozen: Array = Array(text.split("\n")).filter(func(line: String) -> bool:
		return line.begins_with("0 !BRICKWORKS PAGE FREEZE"))
	print("    %s; the file: %s" % [said, str(frozen)])
	var path: String = _out.path_join("h_odd.mpd")
	_write(path, text)
	await _open(path)
	var again: String = _store.to_text("gatehouse", true)
	var page: Booklet.Page = _page_with(await _laid(), lead)
	var own: BookletSheet = page.entries[0].own_sheet if page != null and not page.entries.is_empty() else null
	_check("reopened: the frozen header and footer as given (\"%s\" / \"%s\")" % [own.header if own else "",
		own.footer if own else ""], own != null and own.header == odd and own.footer == "two  spaces")
	_check("...and saved again byte for byte", again == text)
	if own != null:
		var document := Booklet.Document.new()
		document.sheet = BookletSheet.of(_world)
		var html: String = Booklet.page_html(page, document)
		_check("the booklet's page escapes it (%s)" % ("&lt;b&gt;" if html.contains("&lt;b&gt;&amp;amp;") else "NOT ESCAPED"),
			html.contains("&lt;b&gt;&amp;amp;") and not html.contains("<b>&amp;"))
	await _open(ProjectSettings.globalize_path(GATEHOUSE))


# -- I: a sub-model's page locked --------------------------------------------------


func _sub_model_lock() -> void:
	print("")
	print("I: a page whose first step is a sub-model's, locked, saved and opened again")
	await _run_tool("edit_booklet", {"step": 1, "per_page": 2})
	var plan: Array[Instructions.Step] = Instructions.plan(_world, _library, _store.scenery, {}, true)
	var pages: Array[Booklet.Page] = await _laid()
	var lead: int = -1
	var inside: String = ""
	for page: Booklet.Page in pages:
		if page.kind != "steps" or page.entries.is_empty():
			continue
		for step: Instructions.Step in plan:
			if step.number == page.entries[0].number and not step.authored_in.is_empty():
				lead = step.number
				inside = step.authored_in
				break
		if lead > 0:
			break
	if lead < 0:
		print("    (no page of steps starts with a sub-model's step)")
		return
	var said: String = await _run_tool("edit_booklet", {"step": lead, "lock": true})
	var text: String = _store.to_text("gatehouse", true)
	var path: String = _out.path_join("i_sub.mpd")
	_write(path, text)
	var where: String = ""
	var section: String = ""
	for line: String in text.split("\n"):
		if line.begins_with("0 FILE"):
			section = line
		if line.begins_with("0 !BRICKWORKS PAGE LOCK"):
			where = section
	await _open(path)
	var layout: String = await _run_tool("booklet_layout", {})
	var line_said: String = ""
	for one: String in layout.split("\n"):
		if one.strip_edges().begins_with("page") and one.contains("(locked)"):
			line_said = one.strip_edges()
	var again: String = _store.to_text("gatehouse", true)
	_check("step %d (%s's) locked (\"%s\"), written in %s; reopened \"%s\"; saved again byte for byte: %s"
		% [lead, inside, said.left(60), where, line_said.left(70), again == text],
		not line_said.is_empty() and again == text)
	await _open(ProjectSettings.globalize_path(GATEHOUSE))
