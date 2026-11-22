## StudWorx's page tools in the booklet's page editor (APP_UX11 pagetools):
## the element inspector, a page locked and a page frozen, each one undo and
## kept in the model's file byte for byte.
##
##   godot --path . --resolution 1280x720 --script src/dev/pagetools_probe.gd -- [--into=DIR]
##
## Windowed: the page editor is drawn, and shot.
##
## - The file's words: "PAGE LOCK 2", "PAGE FREEZE MARGIN 12 COLOUR
##   #FFFFFF" and "PAGE FREEZE_TEXT HEADER words" read onto the step; a
##   frozen line with a word a frozen page does not keep (a paper) kept as
##   it was written, unread.
## - The inspector: with Alt held, the selected item's room to the page's
##   edges, its margins and its nearest neighbours, measured here from the
##   items' own boxes and matched to the millimetre; shot.
## - Lock page: one undo; a drag and Put back on it refused, nothing moved;
##   Apply to later pages from an earlier page passes it by and leaves it
##   as it was; Steps a page 1 leaves its steps on it; its page break not
##   taken off until it is unlocked.
## - Freeze page: one undo; the booklet's page set up white with wider
##   margins after, the frozen page keeps its colour and margins, in the
##   page editor, in the booklet's page and in the PDF's reading of it.
## - Saved and opened again the same text; the autosave's text the same
##   looks; unlocked after a reopen, that one line goes and nothing else.
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
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.trim_prefix("--into=")
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("pagetools_probe")
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
	_words()
	await _open(ProjectSettings.globalize_path(GATEHOUSE))
	await _pages()
	_quit()


func _quit() -> void:
	print("")
	print("pagetools: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
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
	_check("opened %s: %d parts" % [path.get_file(), _world.brick_count()], _world.brick_count() > 0)
	if not _steps.visible:
		await _steps.start(_world, _library, _store.scenery)
	await _frames(4)


func _history() -> int:
	return _builder._history.size()


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _shot(name: String) -> void:
	await _frames(3)
	var image: Image = root.get_texture().get_image()
	if image != null:
		image.save_png(_out.path_join(name + ".png"))


func _laid() -> Array[Booklet.Page]:
	var maker := BookletMaker.new()
	maker.library = _library
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "gatehouse")
	maker.queue_free()
	return pages


func _until_laid(editor: PageEditor) -> void:
	for _n: int in 600:
		if not bool(editor.page_state().get("laying", false)):
			break
		await process_frame
	await _frames(3)


## The laid page whose first step is the model's step [param number].
static func _page_of(pages: Array[Booklet.Page], number: int) -> Booklet.Page:
	for page: Booklet.Page in pages:
		if page.kind == "steps" and not page.entries.is_empty() and page.entries[0].number == number:
			return page
	return null


static func _numbers(page: Booklet.Page) -> Array:
	return page.entries.map(func(entry: Booklet.Entry) -> int: return entry.number) if page != null else []


# -- the file's words ------------------------------------------------------------


func _words() -> void:
	print("")
	print("the file's words")
	var text: String = "\n".join(["0 FILE main.ldr", "0 Name: main.ldr",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"0 !BRICKWORKS PAGE LOCK 2", "0 !BRICKWORKS PAGE FREEZE MARGIN 12 COLOUR #FFFFFF",
		"0 !BRICKWORKS PAGE FREEZE_TEXT HEADER The gatehouse, left side",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"0 !BRICKWORKS PAGE FREEZE A4 PORTRAIT",
		"1 4 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP", ""])
	var looks: Dictionary = BookletLooks.read(text, {}, "main.ldr")
	var one: Dictionary = looks.get("|1", {})
	_check("PAGE LOCK 2 on step 1: lock %s" % str(one.get("lock")), int(one.get("lock", 0)) == 2)
	var sheet: Dictionary = (one.get("freeze", {}) as Dictionary).get("sheet", {})
	_check("PAGE FREEZE and FREEZE_TEXT on step 1: %s" % str(sheet),
		is_equal_approx(float(sheet.get("margin", 0.0)), 12.0)
		and str(sheet.get("colour", "")).to_lower() == "#ffffff"
		and str(sheet.get("header", "")) == "The gatehouse, left side")
	var two: Dictionary = looks.get("|2", {})
	_check("a frozen line with a paper, which a frozen page keeps the booklet's, kept as written (%s)"
		% str(two.get("unread", [])), not two.has("freeze")
		and two.get("unread", []) == ["0 !BRICKWORKS PAGE FREEZE A4 PORTRAIT"])
	var typed: Dictionary = BookletLooks.typed({"|1": {"lock": 9, "freeze": {"sheet": {"paper": "a4",
		"margin": 14}}}}, PackedStringArray())
	_check("a peer's lock and freeze kept in range, the paper not frozen (%s)" % str(typed),
		int((typed.get("|1", {}) as Dictionary).get("lock", 0)) == BookletLooks.LOCK_MOST
		and ((typed["|1"] as Dictionary).get("freeze", {}) as Dictionary).get("sheet", {})
			== {"margin": 14.0})


# -- the page editor ------------------------------------------------------------


func _pages() -> void:
	print("")
	print("the page editor")
	# Two steps a page, as a designer laying a booklet out sets it, so a
	# page holds more than one step and the lock has steps to hold.
	_steps.refresh(1)
	_shell.change_look("set", _steps.current_step(), {"per_page": 2})
	var pages: Array[Booklet.Page] = await _laid()
	var counts := PackedStringArray()
	for page: Booklet.Page in pages:
		counts.append("%s:%d" % [page.kind, page.entries.size()])
	print("  the pages: %s" % " ".join(counts))
	# Two pages of steps with as many steps: the first to lay out from, the
	# later one to lock and freeze.
	var first: Booklet.Page = null
	var later: Booklet.Page = null
	for at: int in pages.size():
		if pages[at].kind != "steps" or pages[at].entries.size() < 2:
			continue
		for after: int in range(at + 1, pages.size()):
			if pages[after].kind == "steps" and pages[after].entries.size() == pages[at].entries.size():
				first = pages[at]
				later = pages[after]
				break
		if first != null:
			break
	if not _check("two pages of %d steps: %s and %s" % [first.entries.size() if first else 0,
			str(_numbers(first)), str(_numbers(later))], first != null and later != null):
		return
	var held: Array = _numbers(later)
	var lead: int = int(held[0])
	var editor: PageEditor = _main.get("_page_editor")
	_steps.refresh(lead)
	await editor.open()
	await _until_laid(editor)
	await _inspector(editor)

	# Lock page.
	var base: String = _store.to_text("gatehouse", true)
	var history: int = _history()
	var said: String = await editor.lock_page()
	await _until_laid(editor)
	var state: Dictionary = editor.page_state()
	_check("Lock page: \"%s\", one undo, the page locked, its button Unlock page" % said,
		_history() == history + 1 and bool(state.get("locked", false))
		and (editor._named["page_lock"] as Button).text == "Unlock page")
	await _shot("pagetools_locked_1280x720")
	var items: Dictionary = state.get("items", {})
	var name: String = ""
	for item: String in items:
		if item.begins_with("page_picture_"):
			name = item
			break
	var at: int = editor.item_named(name)
	var moved: String = ""
	if at >= 0:
		var rect: Rect2 = editor._items[at]["rect"]
		moved = await editor.place(at, Rect2(rect.position + Vector2(20, 10), rect.size))
	editor._select(editor.item_named(name))
	editor._pressed("page_put_back")
	await _until_laid(editor)
	_check("a drag of %s on it refused (\"%s\") and Put back refused: nothing moved, no undo" % [name, moved],
		at >= 0 and moved.contains("locked") and _history() == history + 1
		and editor.page_state().get("items", {}) == items)

	# Its page break kept until it is unlocked.
	var step: Instructions.Step = _steps.current_step()
	var set_it: bool = not _shell.change_look("new_page", step).contains("locked")
	var history_new: int = _history()
	var refused: String = _shell.change_look("new_page", step)
	_check("its page break not taken off while locked: \"%s\"" % refused,
		refused.contains("locked") and _history() == history_new)
	if set_it:
		_builder.undo()
	await _frames(2)

	# Steps a page 1: the locked page keeps its steps.
	var history_per: int = _history()
	_shell.change_look("set", step, {"per_page": 1})
	var one_a_page: Booklet.Page = _page_of(await _laid(), lead)
	_check("Steps a page 1: the locked page still holds steps %s (%s)" % [str(held),
		str(_numbers(one_a_page))], _numbers(one_a_page) == held)
	while _history() > history_per:
		_builder.undo()
	await _frames(2)

	# Apply to later pages from the first page passes it by.
	_steps.refresh(int(first.entries[0].number))
	editor.close()
	await editor.open()
	await _until_laid(editor)
	var before: Booklet.Page = _page_of(await _laid(), lead)
	var placed_before: Dictionary = before.entries[0].place.duplicate(true) if before != null else {}
	var source: Dictionary = editor.page_state().get("items", {})
	var picture: int = -1
	for item: String in source:
		if item.begins_with("page_picture_"):
			picture = editor.item_named(item)
			break
	var history_apply: int = _history()
	if picture >= 0:
		var rect: Rect2 = editor._items[picture]["rect"]
		await editor.place(picture, Rect2(rect.position + Vector2(6, 4), rect.size * 0.9))
	var applied: String = await editor.apply_to_later()
	var after: Booklet.Page = _page_of(await _laid(), lead)
	_check("Apply to later pages: \"%s\": the locked page %d passed by, as it was" % [applied,
		later.number], applied.contains("passed by") and after != null
		and after.entries[0].place == placed_before)
	while _history() > history_apply:
		_builder.undo()
	await _frames(2)

	# Freeze page, then the booklet's page set up white with wider margins.
	_steps.refresh(lead)
	editor.close()
	await editor.open()
	await _until_laid(editor)
	var history_freeze: int = _history()
	said = await editor.freeze_page()
	await _until_laid(editor)
	_check("Freeze page: \"%s\", one undo, its button Unfreeze page" % said,
		_history() == history_freeze + 1 and bool(editor.page_state().get("frozen", false))
		and (editor._named["page_freeze"] as Button).text == "Unfreeze page")
	_shell.page_setup({"colour": "#ffffff", "margin": 15})
	await _frames(2)
	editor.close()
	await editor.open()
	await _until_laid(editor)
	var laid: Array[Booklet.Page] = await _laid()
	var frozen: Booklet.Page = _page_of(laid, lead)
	var other: Booklet.Page = _page_of(laid, int(first.entries[0].number))
	var own: BookletSheet = frozen.entries[0].own_sheet if frozen != null else null
	_check("the booklet set up white, margins 15: the frozen page keeps its own (%s, %s mm), "
		% [own.colour.to_html(false) if own else "none", own.margin if own else -1.0]
		+ "another page takes the booklet's (%s mm)" % (other.sheet.margin if other else -1.0),
		own != null and BookletSheet.same_colour(own.colour, BookletSheet.PAGE_COLOUR)
		and is_equal_approx(own.margin, BookletSheet.MARGIN) and other != null
		and is_equal_approx(other.sheet.margin, 15.0) and frozen.sheet == own)
	var shown: BookletSheet = editor.shown_sheet()
	_check("...and the page editor shows it on its own page (%s, %s mm)" % [shown.colour.to_html(false),
		shown.margin], bool(editor.page_state().get("frozen", false))
		and BookletSheet.same_colour(shown.colour, BookletSheet.PAGE_COLOUR)
		and is_equal_approx(shown.margin, BookletSheet.MARGIN))
	# ptreview F6: what is dragged on it snaps to its own margins, not the
	# booklet's: 1 mm in from its own right margin it snaps there, and 1 mm
	# in from where the booklet's is now (15 mm) it does not.
	var wide: float = shown.size().x
	var to_own: Vector2 = editor._snap_point(Vector2(wide - BookletSheet.MARGIN - 1.0, 60.0))
	var to_booklet: Vector2 = editor._snap_point(Vector2(wide - 15.0 + 1.0, 60.0))
	_check("...and snaps to its own margins: %s mm -> %s (its own at %s), %s mm -> %s (the booklet's at %s)" % [
		_n(wide - BookletSheet.MARGIN - 1.0), _n(to_own.x), _n(wide - BookletSheet.MARGIN),
		_n(wide - 14.0), _n(to_booklet.x), _n(wide - 15.0)],
		absf(to_own.x - (wide - BookletSheet.MARGIN)) < 0.05 and absf(to_booklet.x - (wide - 15.0)) > 0.05)
	await _shot("pagetools_frozen_1280x720")
	var document := Booklet.Document.new()
	document.sheet = BookletSheet.of(_world)
	var html: String = Booklet.page_html(frozen, document)
	_check("the booklet's page says its own colour: %s" % html.get_slice(">", 0),
		html.get_slice(">", 0).contains("--page:#dcecf8"))
	var read := BookletRead.new()
	var read_pages: Array[BookletRead.Page] = read.feed("\n".join([Booklet.head(document),
		html, Booklet.page_html(other, document), Booklet.TAIL]))
	_check("...and the PDF's reading of it: the frozen page #%s, the next #%s" % [
		read_pages[0].colour.to_html(false) if not read_pages.is_empty() else "",
		read_pages[1].colour.to_html(false) if read_pages.size() > 1 else ""],
		read_pages.size() == 2 and BookletSheet.same_colour(read_pages[0].colour, BookletSheet.PAGE_COLOUR)
		and BookletSheet.same_colour(read_pages[1].colour, Color.WHITE))
	editor.close()
	await _kept(lead)
	await _mcp(lead, int(held[1]) if held.size() > 1 else 0)


## The same over MCP, as a person's own Claude would: edit_booklet lock=
## and freeze=, booklet_layout saying them, follow= passing a locked page by.
func _mcp(lead: int, second: int) -> void:
	print("")
	print("over MCP")
	await _open(ProjectSettings.globalize_path(GATEHOUSE))
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	await tools.run("edit_booklet", {"step": 1, "per_page": 2})
	var history: int = _history()
	var said: String = str(await tools.run("edit_booklet", {"step": lead, "lock": true}))
	var again: String = str(await tools.run("edit_booklet", {"step": lead, "lock": true}))
	var layout: String = str(await tools.run("booklet_layout", {}))
	var line: String = ""
	for one: String in layout.split("\n"):
		if one.contains(": step") and one.contains(" %d" % lead) and one.strip_edges().begins_with("page"):
			line = one.strip_edges()
			break
	_check("edit_booklet lock=true: \"%s\", one undo; again: \"%s\"; booklet_layout: \"%s\"" % [said,
		again, line.left(80)], _history() == history + 1 and again.contains("already")
		and line.contains("(locked)"))
	# The page's second step is not the one that starts it.
	if second > 0:
		var wrong: String = str(await tools.run("edit_booklet", {"step": second, "lock": true}))
		_check("its second step is said with the first: \"%s\"" % wrong,
			wrong.contains("step=%d" % lead) and _history() == history + 1)
	said = str(await tools.run("edit_booklet", {"step": lead, "freeze": true}))
	_check("edit_booklet freeze=true: \"%s\", one undo" % said, _history() == history + 2
		and said.contains("frozen"))
	said = str(await tools.run("edit_booklet", {"step": lead, "lock": false}))
	_check("edit_booklet lock=false: \"%s\"" % said, _history() == history + 3 and said.contains("unlocked"))
	# A lock beside another field is refused before anything is written; a
	# false where the page is not held is as if it were absent.
	var both: String = str(await tools.run("edit_booklet", {"step": lead, "lock": true, "zoom": 1.2}))
	_check("lock= beside zoom= refused, nothing written: \"%s\"" % both, _history() == history + 3
		and both.contains("Nothing was changed"))
	var absent: String = str(await tools.run("edit_booklet", {"step": lead, "lock": false, "zoom": 1.2}))
	_check("lock=false on an unlocked page is as if absent: zoom= done (\"%s\"), one undo" % absent,
		_history() == history + 4 and not absent.contains("lock"))
	while _history() > history:
		_builder.undo()
	await _frames(2)


## The inspector on the page shown: Alt held over a selected item.
func _inspector(editor: PageEditor) -> void:
	var items: Dictionary = editor.page_state().get("items", {})
	var name: String = ""
	for item: String in items:
		if item.begins_with("page_picture_"):
			name = item
			break
	editor._select(editor.item_named(name))
	var alt := InputEventKey.new()
	alt.keycode = KEY_ALT
	alt.physical_keycode = KEY_ALT
	alt.pressed = true
	Input.parse_input_event(alt)
	await _frames(4)
	var state: Dictionary = editor.page_state()
	var seen: Dictionary = state.get("inspected", {})
	var box: Rect2 = PageEditor._box_of(editor._items[editor.item_named(name)])
	var sheet: BookletSheet = editor.shown_sheet()
	var edges: Dictionary = seen.get("edges", {})
	var margins: Dictionary = seen.get("margins", {})
	_check("Alt held: inspecting %s (%s)" % [name, str(seen)], bool(state.get("inspecting", false)))
	_check("its room to the page's edges, measured here: left %s top %s right %s bottom %s" % [
		edges.get("left"), edges.get("top"), edges.get("right"), edges.get("bottom")],
		is_equal_approx(float(edges.get("left", -1)), snappedf(box.position.x, 0.1))
		and is_equal_approx(float(edges.get("right", -1)), snappedf(sheet.size().x - box.end.x, 0.1))
		and is_equal_approx(float(edges.get("bottom", -1)), snappedf(sheet.size().y - box.end.y, 0.1)))
	_check("...to its margins (%s mm): left %s top %s" % [sheet.margin, margins.get("left"),
		margins.get("top")], is_equal_approx(float(margins.get("left", -99)),
		snappedf(box.position.x - sheet.margin, 0.1)) and is_equal_approx(float(margins.get("top", -99)),
		snappedf(box.position.y - sheet.margin, 0.1)))
	# Its nearest neighbour on each side, found here from every other item.
	var want: Dictionary = {}
	for other: int in editor._items.size():
		var them: Rect2 = PageEditor._box_of(editor._items[other])
		if editor._item_name(other) == name:
			continue
		if them.position.y < box.end.y and them.end.y > box.position.y and them.position.x >= box.end.x:
			var gap: float = snappedf(them.position.x - box.end.x, 0.1)
			if not want.has("right") or gap < float(want["right"]):
				want["right"] = gap
		if them.position.x < box.end.x and them.end.x > box.position.x and them.position.y >= box.end.y:
			var gap: float = snappedf(them.position.y - box.end.y, 0.1)
			if not want.has("bottom") or gap < float(want["bottom"]):
				want["bottom"] = gap
	var near: Dictionary = seen.get("neighbours", {})
	var match_all: bool = true
	for side: String in want:
		match_all = match_all and near.has(side) and is_equal_approx(float(near[side][1]), float(want[side]))
	_check("...to its nearest neighbours: %s (measured here %s)" % [str(near), str(want)], match_all)
	await _shot("pagetools_inspector_1280x720")
	alt.pressed = false
	Input.parse_input_event(alt)
	await _frames(4)
	_check("Alt let go: the inspector gone", not bool(editor.page_state().get("inspecting", true)))


# -- kept ------------------------------------------------------------------------


func _kept(lead: int) -> void:
	print("")
	print("saved and opened again")
	var text: String = _store.to_text("gatehouse", true)
	var lines: PackedStringArray = text.split("\n")
	var lock: Array = Array(lines).filter(func(line: String) -> bool:
		return line.strip_edges().begins_with("0 !BRICKWORKS PAGE LOCK"))
	var freeze: Array = Array(lines).filter(func(line: String) -> bool:
		return line.strip_edges().begins_with("0 !BRICKWORKS PAGE FREEZE"))
	_check("the file says the lock and the freeze: %s %s" % [str(lock), str(freeze)],
		lock.size() == 1 and freeze.size() == 1)
	var path: String = _out.path_join("pagetools_saved.mpd")
	_write(path, text)
	var autosaved: String = _store.to_text("gatehouse", false)
	await _open(path)
	var again: String = _store.to_text("gatehouse", true)
	_check("opened again and saved, the same text byte for byte (%d bytes)" % again.length(),
		again == text)
	_write(_out.path_join("pagetools_autosave.ldr"), autosaved)
	await _open(_out.path_join("pagetools_autosave.ldr"))
	var lock_now: int = 0
	var frozen_now: bool = false
	for name: String in _world.step_looks:
		var look: Variant = _world.step_looks[name]
		if look is Dictionary:
			lock_now = maxi(lock_now, int((look as Dictionary).get("lock", 0)))
			frozen_now = frozen_now or (look as Dictionary).get("freeze") is Dictionary
	_check("the autosave's text opened again: locked %d, frozen %s" % [lock_now, frozen_now],
		lock_now > 0 and frozen_now)
	await _open(path)
	_steps.refresh(lead)
	var history: int = _history()
	var said: String = _shell.change_look("page_lock", _steps.current_step())
	var changed: PackedStringArray = _store.to_text("gatehouse", true).split("\n")
	var gone: Array = []
	for line: String in lines:
		if not line in changed:
			gone.append(line.strip_edges())
	_check("unlocked after the reopen (\"%s\"): that one line gone, nothing else (%s)" % [said, str(gone)],
		_history() == history + 1 and changed.size() == lines.size() - 1 and gone == [str(lock[0]).strip_edges()])
	_builder.undo()
	await _frames(2)
	_check("...and undone, the text as it was", _store.to_text("gatehouse", true) == text)


static func _n(value: float) -> String:
	return str(snappedf(value, 0.1))
