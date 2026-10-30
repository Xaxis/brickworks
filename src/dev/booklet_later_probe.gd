## Apply to later pages: a 40-page booklet laid out from its first page,
## as Studio's page design applies a page's layout to "followings".
##
##   godot --path . --resolution 1280x720 --script src/dev/booklet_later_probe.gd -- [--into=DIR] [--set=FILE]
##
## Windowed, on the GPU, under Xvfb (tools/probe.sh runs it so): every
## act is the mouse on the window's own controls, and the page editor
## draws its steps' pictures. FILE is 42004-1's (vendor/omr), 46 steps of
## its author's and six sub-models, unless named.
##
## A person lays the booklet out in these acts, and the probe counts them
## (the bar is 10 or fewer):
##   the timeline (B); Per page, to one step a page; Lay out page… on the
##   first step; its parts list dragged to the page's right; its number
##   dragged to the top left; its picture picked, its corner dragged in,
##   and the picture dragged to the lower right; Apply to later pages.
## Then, read from the booklet laid out again as it prints:
##   is it 40 pages of steps or more, every later page of one step laid
##   out, and the others said as left?
##   on each later page, is the picture's model centred where the first
##   page's is, the parts list and the number where the first page has
##   them, the list as wide as its own parts need and grown away from the
##   page's edge (or the page says what it moved off what), the model drawn no
##   larger than the booklet draws a step, and nothing on anything else or
##   off the page? A sub-assembly's callout box on its page, where the
##   booklet lays it, as the first page placed none.
##   one undo step: Ctrl-Z gives back the file as it was, byte for byte;
##   saved and opened again, the pages are laid out the same.
##   over MCP, edit_booklet follow=true on the first step does it again,
##   to the same file.
## A run where Apply to later pages did nothing fails the first page's
## places on every later page.
##
## --into=DIR keeps the screenshots: a later page before and after.
extends SceneTree

const SET := "res://vendor/omr/files/42004-1.mpd"
## The most a later page's things may be from where the first page's
## place says, in mm: a tenth for the places the file keeps, and the
## snapping of a look's numbers.
const NEAR := 0.6

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _store: ModelStore
var _shell: Shell
var _steps: StepsBar
var _out: String = ""
var _set: String = SET
var _acts: int = 0


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


## A click where a person clicks, in the window's own pixels.
func _click(at: Vector2) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var moved := InputEventMouseMotion.new()
	moved.position = at * scale
	moved.global_position = moved.position
	Input.parse_input_event(moved)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = at * scale
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(3)


## A press at [param from], the pointer moved to [param to] in steps, and a
## release there: a drag as a person drags.
func _drag_mouse(from: Vector2, to: Vector2) -> void:
	var scale: Vector2 = Vector2(DisplayServer.window_get_size()) / root.get_visible_rect().size
	var moved := InputEventMouseMotion.new()
	moved.position = from * scale
	moved.global_position = moved.position
	Input.parse_input_event(moved)
	await _frames(3)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = from * scale
	down.global_position = down.position
	Input.parse_input_event(down)
	await _frames(3)
	for n: int in range(1, 9):
		var step := InputEventMouseMotion.new()
		step.position = from.lerp(to, n / 8.0) * scale
		step.global_position = step.position
		step.button_mask = MOUSE_BUTTON_MASK_LEFT
		step.relative = (to - from) / 8.0 * scale
		Input.parse_input_event(step)
		await _frames(2)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = to * scale
	up.global_position = up.position
	Input.parse_input_event(up)
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
	await _frames(4)


## One act of the person's: [param what] said, and counted.
func _act(what: String) -> void:
	_acts += 1
	print("  act %d: %s" % [_acts, what])


func _run() -> void:
	await process_frame
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--into="):
			_out = arg.substr(7)
		if arg.begins_with("--set="):
			_set = arg.substr(6)
	if _out.is_empty():
		_out = OS.get_user_data_dir().path_join("sessions/probe/booklet_later")
	DirAccess.make_dir_recursive_absolute(_out)
	Download.folder = _out
	BookletMaker.open_when_written = false
	if not FileAccess.file_exists(_set):
		print("booklet later probe: SKIPPED, %s is not in this checkout" % _set)
		quit(0)
		return
	if DisplayServer.get_name() == "headless":
		print("booklet later probe: needs a window; run it with tools/probe.sh")
		quit(1)
		return
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(90)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_shell = _main.get("_shell")
	_steps = _main.get("_steps")
	_shell.set_assistant(false)
	await _open(_set)
	var opened: String = _save()

	# The person's acts.
	await _key(KEY_B)
	_act("the timeline (B)")
	await _frames(10)
	var shown: Instructions.Step = _steps.booklet_step()
	if shown == null or shown.number != 1:
		await _click((_steps.controls_by_name()["steps_start"] as Control).get_global_rect().get_center())
		_act("the timeline's first step")
	var per_page: Control = _steps.controls_by_name().get("booklet_per_page")
	_check("the timeline's Booklet row shows Per page", per_page != null and per_page.is_visible_in_tree())
	if per_page == null or not per_page.is_visible_in_tree():
		_end()
		return
	await _click(per_page.get_global_rect().get_center())
	_act("Per page, once: %s" % str(per_page.get("text")))
	_check("...one step a page (%s)" % str(BookletLooks.booklet(_world)),
		int(BookletLooks.booklet(_world).get("per_page", 0)) == 1)
	await _click((_steps.controls_by_name()["booklet_lay_out"] as Control).get_global_rect().get_center())
	_act("Lay out page…")
	var editor: PageEditor = _main.get("_page_editor")
	await _until_laid(editor)
	var state: Dictionary = editor.page_state()
	var first: int = int((state.get("steps", [0]) as Array)[0])
	_check("Lay out page… on page %d, step %d" % [int(state.get("page", 0)), first],
		editor.is_open() and (state.get("steps", []) as Array).size() == 1)
	var pages: Array[Booklet.Page] = await _laid()
	var later_page: Booklet.Page = _steps_pages(pages)[mini(9, _steps_pages(pages).size() - 1)]
	await _shot(editor, later_page.number, "before")
	editor.show_page_numbered(int(state.get("page", 0)))
	await _frames(6)

	var k: float = editor._scale() * editor._canvas.get_global_transform().get_scale().x
	var origin: Vector2 = editor._canvas.get_global_rect().position
	# Its parts list to the page's right, under the top margin.
	var parts: int = editor.item_named("page_parts_%d" % first)
	var parts_was: Rect2 = editor._items[parts]["rect"]
	var parts_to := Vector2(Booklet.PAGE.x - Booklet.MARGIN - parts_was.size.x - 20.0, Booklet.MARGIN + 6.0)
	await _drag_mouse((editor._items[parts]["control"] as Control).get_global_rect().get_center(),
		(editor._items[parts]["control"] as Control).get_global_rect().get_center()
			+ (parts_to - parts_was.position) * k)
	_act("the parts list dragged to the right")
	await _until_laid(editor)
	# Its number to the top left.
	var number: int = editor.item_named("page_number_%d" % first)
	var number_was: Rect2 = editor._items[number]["rect"]
	await _drag_mouse((editor._items[number]["control"] as Control).get_global_rect().get_center(),
		(editor._items[number]["control"] as Control).get_global_rect().get_center()
			+ (Vector2(Booklet.MARGIN + 4.0, Booklet.MARGIN + 4.0) - number_was.position) * k)
	_act("the number dragged to the top left")
	await _until_laid(editor)
	# Its picture: picked, its corner drawn in, and moved to the lower right.
	var picture: int = editor.item_named("page_picture_%d" % first)
	await _click((editor._items[picture]["control"] as Control).get_global_rect().get_center())
	_act("the picture picked")
	var was: Rect2 = editor._items[picture]["rect"]
	var corner: Vector2 = editor._handle.get_global_rect().get_center()
	await _drag_mouse(corner, corner + (was.position + Vector2(170.0, 125.0) - was.end) * k)
	_act("the picture's corner dragged in")
	await _until_laid(editor)
	picture = editor.item_named("page_picture_%d" % first)
	was = editor._items[picture]["rect"]
	await _drag_mouse((editor._items[picture]["control"] as Control).get_global_rect().get_center(),
		(editor._items[picture]["control"] as Control).get_global_rect().get_center()
			+ (Vector2(70.0, 50.0) - was.position) * k)
	_act("the picture dragged to the lower right")
	await _until_laid(editor)
	var placed: Dictionary = await _first_place(first)
	_check("the first step's picture, parts list and number placed (%s)" % str(placed),
		placed.has("picture") and placed.has("parts") and placed.has("number"))
	var before: String = _save()
	var history: int = _builder._history.size()
	await _click((editor.controls_by_name()["page_apply_later"] as Control).get_global_rect().get_center())
	_act("Apply to later pages")
	await _until_laid(editor)
	for _n: int in 600:
		if _builder._history.size() > history and not bool(editor.page_state().get("laying", false)):
			break
		await process_frame
	await _frames(6)
	var said: String = str(editor.page_state().get("said", ""))
	_check("the page says what it did: \"%s\"" % said, said.contains("later page"))
	_check("one undo step (%d)" % (_builder._history.size() - history), _builder._history.size() == history + 1)
	_check("%d acts lay the booklet out, 10 or fewer" % _acts, _acts <= 10)

	pages = await _laid()
	var judged: Dictionary = _judge(pages, first)
	await _shot(editor, later_page.number, "after")
	# The first page a thing was moved on, and the page of the longest list.
	if not (judged.get("moved_pages", []) as Array).is_empty():
		await _shot(editor, int(judged["moved_pages"][0]), "moved")
	if int(judged.get("tallest", -1)) > 0:
		await _shot(editor, int(judged["tallest"]), "longest_list")
	var after: String = _save()

	# Undone, the file as it was.
	await _key(KEY_Z, true)
	await _until_laid(editor)
	_check("Ctrl-Z: the file as it was before Apply, byte for byte", _save() == before)
	editor.close()
	await _frames(4)

	# Over MCP: the same.
	var tools := AppTools.new()
	tools.app = _main
	tools.assistant = _main.get("_assistant")
	history = _builder._history.size()
	var answer: String = str(await tools.run("edit_booklet", {"step": first, "follow": true}))
	print("  edit_booklet follow=true: %s" % answer)
	_check("edit_booklet follow=true: one undo step, the same file as the page's button",
		_builder._history.size() == history + 1 and _save() == after)

	# Saved, opened again, laid out the same.
	var path: String = _out.path_join("booklet_later.mpd")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(after)
	file.close()
	await _open(path)
	var again: Array[Booklet.Page] = await _laid()
	_check("saved and opened again: the pages laid out the same (%s)" % _same(pages, again),
		_same(pages, again) == "the same")
	_check("...and saved again, the same file", _save() == after)
	if judged.is_empty():
		_check("the booklet was judged", false)
	_end()
	print("  opened as %d bytes; laid out %d" % [opened.length(), after.length()])


func _end() -> void:
	print("booklet later probe: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(1 if _failures > 0 else 0)


func _open(path: String) -> void:
	_steps.stop()
	_main.call("clear_model")
	await _frames(4)
	_main.call("_open", ProjectSettings.globalize_path(path))
	for _n: int in 600:
		if _store.awaited.is_empty():
			break
		await process_frame
	await _frames(10)
	_check("opened %s: %d parts, %s" % [path.get_file(), _world.brick_count(),
		"the author's steps" if AuthorSteps.any(_world, _store.scenery) else "no steps of its own"],
		_world.brick_count() > 10 and _store.awaited.is_empty())


func _save() -> String:
	return _store.to_text("booklet_later", true)


func _until_laid(editor: PageEditor) -> void:
	await _frames(3)
	for _n: int in 900:
		if not bool(editor.page_state().get("laying", false)):
			break
		await process_frame
	await _frames(3)


## The booklet laid out as it would print now, without its pictures.
func _laid() -> Array[Booklet.Page]:
	var maker := BookletMaker.new()
	maker.library = _main.get("_library")
	_main.add_child(maker)
	var pages: Array[Booklet.Page] = await maker.lay_out_only(_world, _store.scenery, "Model")
	maker.queue_free()
	return pages


static func _steps_pages(pages: Array[Booklet.Page]) -> Array[Booklet.Page]:
	var out: Array[Booklet.Page] = []
	for page: Booklet.Page in pages:
		if page.kind == "steps":
			out.append(page)
	return out


## What step [param number] has placed, as the booklet reads it.
func _first_place(number: int) -> Dictionary:
	for page: Booklet.Page in _steps_pages(await _laid()):
		for entry: Booklet.Entry in page.entries:
			if entry.number == number:
				return entry.place
	return {}


## The later pages against the first: each a check line. Returns what was
## found, empty when there was nothing to judge.
func _judge(pages: Array[Booklet.Page], first: int) -> Dictionary:
	var steps: Array[Booklet.Page] = _steps_pages(pages)
	var source: Booklet.Entry = null
	var at: int = -1
	for index: int in steps.size():
		if steps[index].entries.size() == 1 and steps[index].entries[0].number == first:
			source = steps[index].entries[0]
			at = index
	if source == null:
		return {}
	var later: Array[Booklet.Page] = steps.slice(at + 1)
	var single: Array = later.filter(func(page: Booklet.Page) -> bool: return page.entries.size() == 1)
	_check("%d pages of steps, 40 or more; %d after the first, %d of them of one step"
		% [steps.size(), later.size(), single.size()], steps.size() >= 40 and single.size() >= 39)
	# Where the first page's things were put (a thing the page moved off
	# another is kept where it was put, and goes there on a later page).
	var parts_place: Rect2 = BookletLooks.rect_of(source.place.get("parts", []))
	var parts_at: Vector2 = parts_place.position
	# A list at the right of the page keeps its right edge, and grows to the
	# left to be as wide as its own parts need.
	var right_side: bool = parts_place.get_center().x > Booklet.PAGE.x * 0.5
	var number_at: Vector2 = BookletLooks.rect_of(source.place.get("number", [])).position
	var exact: int = 0
	var said_moved: int = 0
	var moved_pages: Array = []
	var tallest: Booklet.Page = null
	var wrong: Array = []
	var too_big: Array = []
	var overlapping: Array = []
	var off_page: Array = []
	var callouts: int = 0
	var callouts_wrong: Array = []
	for page: Booklet.Page in single:
		var entry: Booklet.Entry = page.entries[0]
		var same_room: bool = BookletLooks.same_room(entry.panel, source.panel)
		# Where the first page's things go in this page's room.
		var mapped: Dictionary = BookletLooks.rebased({"place": {"picture": source.place.get("picture"),
			"parts": [parts_at.x, parts_at.y, parts_place.size.x], "number": [number_at.x, number_at.y]},
			"panel": BookletLooks.said_rect(source.panel)}, entry.panel).get("place", {})
		# ...less what the step's own list, grown for its parts, covers of it.
		var want_centre: Vector2 = PageEditor.clear_of(BookletLooks.rect_of(source.place.get("picture", []))
			if same_room else BookletLooks.rect_of(mapped["picture"]), PageEditor.list_rect(entry, entry.place),
			entry.subject.size.max(Vector2.ONE)).get_center()
		var mapped_parts: Array = [parts_at.x, parts_at.y, parts_place.size.x] if same_room else mapped["parts"]
		var want_parts := Vector2(float(mapped_parts[0]) + (float(mapped_parts[2]) if right_side else 0.0),
			float(mapped_parts[1]))
		var parts_edge := Vector2(entry.parts_rect.end.x if right_side else entry.parts_rect.position.x,
			entry.parts_rect.position.y)
		var want_number: Vector2 = number_at if same_room else Vector2(float(mapped["number"][0]), float(mapped["number"][1]))
		var ink: Rect2 = Booklet.ink_of(entry)
		if tallest == null or entry.parts_rect.size.y > tallest.entries[0].parts_rect.size.y:
			tallest = page
		var moved: Dictionary = {}
		for one: Dictionary in page.overlaps:
			if bool(one["moved"]):
				moved[str(one["item"])] = true
		var right: bool = ink.get_center().distance_to(want_centre) < NEAR or moved.has("picture")
		if not entry.lots.is_empty():
			right = right and (parts_edge.distance_to(want_parts) < NEAR or moved.has("parts"))
		right = right and (entry.number_at.distance_to(want_number) < NEAR or moved.has("number")
			or moved.has("parts") and not entry.place.has("number"))
		if right and moved.is_empty():
			exact += 1
		elif right:
			said_moved += 1
			moved_pages.append(page.number)
			print("  page %d: %s" % [page.number, Booklet.overlaps_said(page)])
		else:
			wrong.append("%d (picture %s want %s, parts %s want %s, number %s want %s)" % [page.number,
				_v(ink.get_center()), _v(want_centre), _v(parts_edge), _v(want_parts),
				_v(entry.number_at), _v(want_number)])
		var most: float = Booklet._most(entry) * Booklet._grown(entry)
		if entry.scale > most * 1.01:
			too_big.append("%d (%.3f mm an LDU, the most %.3f)" % [page.number, entry.scale, most])
		var things: Array = Booklet.things_on(page)
		for a: int in things.size():
			var rect: Rect2 = things[a]["rect"]
			if not Rect2(Vector2.ZERO, Booklet.PAGE).grow(0.05).encloses(rect):
				off_page.append("%d's %s" % [page.number, things[a]["kind"]])
			for b: int in range(a + 1, things.size()):
				var shared: Rect2 = rect.intersection(things[b]["rect"])
				if shared.size.x > Booklet.OVERLAP and shared.size.y > Booklet.OVERLAP:
					overlapping.append("%d: %s on %s" % [page.number, things[a]["kind"], things[b]["kind"]])
		if entry.callout != null and entry.callout.inline:
			callouts += 1
			if entry.place.has("callout") or not Booklet._room_of(page).grow(0.05).encloses(entry.callout.box):
				callouts_wrong.append(page.number)
	_check("every later page of one step laid out as the first: %d exactly, %d with a thing moved off another and said%s"
		% [exact, said_moved, (", wrong: %s" % ", ".join(PackedStringArray(wrong.slice(0, 4)))) if not wrong.is_empty() else ""],
		wrong.is_empty() and exact + said_moved == single.size() and exact >= single.size() * 3 / 4)
	_check("no later page's model drawn larger than the booklet draws a step%s" % (
		(": " + ", ".join(PackedStringArray(too_big.slice(0, 4)))) if not too_big.is_empty() else ""),
		too_big.is_empty())
	_check("nothing on a later page on anything else%s" % ((": " + ", ".join(
		PackedStringArray(overlapping.slice(0, 4)))) if not overlapping.is_empty() else ""),
		overlapping.is_empty())
	_check("nothing off a later page%s" % ((": " + ", ".join(PackedStringArray(off_page.slice(0, 4))))
		if not off_page.is_empty() else ""), off_page.is_empty())
	_check("%d later steps' callout boxes where the booklet lays them, on the page%s" % [callouts,
		(", not: %s" % str(callouts_wrong)) if not callouts_wrong.is_empty() else ""],
		callouts_wrong.is_empty())
	return {"exact": exact, "moved": said_moved, "moved_pages": moved_pages,
		"tallest": tallest.number if tallest != null else -1}


static func _v(at: Vector2) -> String:
	return "%.1f,%.1f" % [at.x, at.y]


## Whether two layouts put every step's things in the same places.
static func _same(a: Array[Booklet.Page], b: Array[Booklet.Page]) -> String:
	if a.size() != b.size():
		return "%d pages, then %d" % [a.size(), b.size()]
	for index: int in a.size():
		if a[index].entries.size() != b[index].entries.size():
			return "page %d's steps differ" % a[index].number
		for slot: int in a[index].entries.size():
			var one: Booklet.Entry = a[index].entries[slot]
			var two: Booklet.Entry = b[index].entries[slot]
			if one.rect.position.distance_to(two.rect.position) > 0.05 \
					or one.parts_rect.position.distance_to(two.parts_rect.position) > 0.05 \
					or one.number_at.distance_to(two.number_at) > 0.05:
				return "page %d, step %d differs" % [a[index].number, one.number]
	return "the same"


## The page editor on page [param page], its pictures drawn, the window
## kept as [param name].
func _shot(editor: PageEditor, page: int, name: String) -> void:
	editor.show_page_numbered(page)
	for _n: int in 3000:
		var shown: Dictionary = editor.page_state()
		if (shown.get("drawn", []) as Array).size() == (shown.get("steps", []) as Array).size():
			break
		await process_frame
	await _frames(6)
	var image: Image = root.get_texture().get_image()
	var size: Vector2i = DisplayServer.window_get_size()
	var path: String = _out.path_join("later_%s_%dx%d.png" % [name, size.x, size.y])
	if image != null:
		image.save_png(path)
		print("  %s: %s" % [name, path])
