## What one set or model shares with another, and what to buy to build one
## from the other (APP_UX6 #7, comparesets).
##
##   godot --path . --resolution 1400x900 --script src/dev/comparesets_probe.gd
##   ... -- --shots=DIR   the sheet pictured there
##
## Rebrickable's set compare answers its most asked question, "can I build
## this from that set?": the parts in both, the parts in only one, and what
## to buy. Here, as a person and a session ask it, on the real scene:
##   File, Compare two sets or models…, 7140 typed for A and 9493 for B: the
##   pieces in both and in each alone add up to each set's inventory exactly
##   (read here from the inventory's own file, its spares apart), each tab's
##   rows to its count, and in both is no less than the two lists share part
##   for part and colour for colour; Swap turns it round;
##   the car against 7140: the LEGO® Pick a Brick button writes the list to
##   buy, element for element what the car needs beyond 7140 (Collection's
##   own sums, done here), its lines summing to those pieces, the lots with no
##   element named;
##   parts_list which="compare" over MCP in 1 call says the window's counts,
##   and with shop=pickabrick writes the same file;
##   a set under test in a bench run (DesignMemory.holds) is not compared.
## Every control of the sheet inside it, and it inside the window. Nothing
## is uploaded.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bar: ModelBar
var _world: BrickWorld
var _store: ModelStore
var _library: PartLibrary
var _socket: CommandSocket
var _compare: Control
var _next: int = 0
var _out: String = ""
var _shots: String = ""
var _size: String = ""
## What the window said of 7140 against 9493: in both, only in 7140-1, only in 9493-1.
var _window_counts: Array = []
## The window's list to buy, the car from 7140, as written.
var _window_file: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_size = "%dx%d" % [root.size.x, root.size.y]
	_out = OS.get_user_data_dir().path_join("comparesets_probe")
	DirAccess.make_dir_recursive_absolute(_out)
	for name: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out.path_join(name))

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		_bar = _main.get("_bar")
		_world = _main.get("_world")
		if _shell != null and _bar != null and _world != null and _world.brick_count() > 1:
			break
	if _world == null or _world.brick_count() <= 1:
		print("  comparesets probe: SKIPPED — no model came up on the baseplate")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_store = _main.get("_store")
	_library = _main.get("_library")
	# Every file where this probe can read it, without a dialog (SaveTo.ask).
	(_main.get("_exports") as Exports).folder = _out
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await _frames(20)

	await _sets_in_window()
	await _car_from_7140()
	await _over_mcp()
	await _held_out()

	print("")
	if _failures == 0:
		print("comparesets probe: all checks passed")
	else:
		print("comparesets probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


# -- the inventories, read here from their own files ---------------------------------


## A set's record as tools/collection_data.py wrote it: {"n", "y", "p", "s"}.
func _record(number: String) -> Dictionary:
	var file: String = "res://assets/generated/sets/%03d.json" % SetInventories.shard_of(number)
	var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	if typeof(read) != TYPE_DICTIONARY:
		return {}
	return (read as Dictionary).get("sets", {}).get(number, {})


## A record's pieces but its spares, and its rows as "part/colour" -> how many.
func _pieces(record: Dictionary) -> int:
	var sum: int = 0
	for row: Variant in record.get("p", []):
		sum += int((row as Array)[2])
	return sum


func _raw(record: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for row: Variant in record.get("p", []):
		var key: String = "%s/%d" % [str(row[0]), int(row[1])]
		out[key] = int(out.get(key, 0)) + int(row[2])
	return out


# -- in the window -------------------------------------------------------------------


func _sets_in_window() -> void:
	print("\n  File, Compare two sets or models…: 7140 against 9493")
	var a_record: Dictionary = _record("7140-1")
	var b_record: Dictionary = _record("9493-1")
	var a_pieces: int = _pieces(a_record)
	var b_pieces: int = _pieces(b_record)
	var a_raw: Dictionary = _raw(a_record)
	var b_raw: Dictionary = _raw(b_record)
	var shared: int = 0
	for key: String in b_raw:
		shared += mini(int(b_raw[key]), int(a_raw.get(key, 0)))
	print("     the inventories: 7140-1 %s, %d pieces; 9493-1 %s, %d pieces; %d share part and colour as listed"
		% [a_record.get("n", "?"), a_pieces, b_record.get("n", "?"), b_pieces, shared])
	_check("both sets are in the inventories", a_pieces > 0 and b_pieces > 0)
	var file_rows: Array = []
	for row: Variant in Shell.MENUS:
		if str(row[0]) == "File":
			file_rows = row[1]
	_check("File lists it after Compare with… (%s)" % ", ".join(file_rows.slice(
		maxi(0, file_rows.find("compare") - 1), file_rows.find("compare") + 3)),
		file_rows.has("compare_sets") and file_rows.find("compare_sets") == file_rows.find("compare") + 1)
	var command: Shell.Command = _shell.command("compare_sets")
	_check("its row reads \"%s\"" % (command.words if command != null else "(none)"),
		command != null and command.words == "Compare two sets or models…")
	_check("it can be pressed", _shell.run("compare_sets"))
	await _frames(10)
	_compare = _shell.get("compare")
	var controls: Dictionary = _controls()
	var a_number: LineEdit = controls.get("compare_a_number")
	_check("A asks for a set's number first, its field ready to type into", a_number != null
		and a_number.is_visible_in_tree() and a_number.has_focus())
	if a_number == null:
		return
	a_number.insert_text_at_caret("7140")
	var b: OptionButton = controls.get("compare_b")
	var at: int = _item(b, "A set, by its number")
	_check("B offers a set by its number (row %d)" % at, at >= 0)
	if at < 0:
		return
	b.select(at)
	b.item_selected.emit(at)
	await _frames(3)
	var b_number: LineEdit = _controls().get("compare_b_number")
	_check("...and asks for its number, ready to type into", b_number != null
		and b_number.is_visible_in_tree() and b_number.has_focus())
	if b_number == null:
		return
	b_number.insert_text_at_caret("9493")
	b_number.text_submitted.emit(b_number.text)
	var fields: Dictionary = await _compared()
	var counts: Array = _tab_counts(fields)
	print("     the tabs: %s" % ", ".join(fields.get("tabs", [])))
	_window_counts = counts
	_check("its tabs name the two: %s" % ", ".join(fields.get("tabs", [])), counts.size() == 3
		and str(fields["tabs"][1]).begins_with("Only in 7140-1")
		and str(fields["tabs"][2]).begins_with("Only in 9493-1"))
	if counts.size() < 3:
		return
	_check("in both and only in 7140-1 add up to 7140-1's %d pieces: %d + %d = %d" % [a_pieces,
		counts[0], counts[1], counts[0] + counts[1]], counts[0] + counts[1] == a_pieces)
	_check("in both and only in 9493-1 add up to 9493-1's %d pieces: %d + %d = %d" % [b_pieces,
		counts[0], counts[2], counts[0] + counts[2]], counts[0] + counts[2] == b_pieces)
	_check("in both is no less than the two lists share as listed (%d >= %d), and no more than the smaller set (%d)"
		% [counts[0], shared, mini(a_pieces, b_pieces)],
		counts[0] >= shared and counts[0] <= mini(a_pieces, b_pieces))
	_check("each side said, its pieces counted: %s" % str(fields.get("sides", "")).replace("\n", " / "),
		str(fields.get("sides", "")).contains("7140-1 X-wing Fighter")
			and str(fields.get("sides", "")).contains("%d pieces" % a_pieces)
			and str(fields.get("sides", "")).contains("9493-1 X-wing Starfighter")
			and str(fields.get("sides", "")).contains("%d pieces" % b_pieces))
	# Each tab's rows, read as a person reads them: "4 × 2412b Tile 1 x 2 …".
	var tabs: TabBar = _controls().get("compare_tabs")
	for tab: int in 3:
		tabs.current_tab = tab
		await _frames(4)
		var rows: Array = _fields().get("rows", [])
		var sum: int = 0
		for row: String in rows:
			sum += int(row.get_slice(" ", 0))
		_check("%s: %d rows, by part and colour, summing to %d" % [str(_fields()["tabs"][tab]),
			rows.size(), sum], sum == counts[tab] and not rows.is_empty())
		if tab == 0:
			await _shot("comparesets_both")
	tabs.current_tab = 2
	await _frames(4)
	_check("what to buy, said under the list: %s" % _fields().get("buy", ""),
		str(_fields().get("buy", "")).begins_with("To build 9493-1 from 7140-1, buy these %d pieces"
			% counts[2]))
	await _frames(60)
	await _shot("comparesets_sets")
	_placed()
	_names_shown()

	var swap: Button = _controls().get("compare_swap")
	swap.pressed.emit()
	fields = await _compared()
	var turned: Array = _tab_counts(fields)
	_check("Swap turns it round: %s" % ", ".join(fields.get("tabs", [])), turned.size() == 3
		and turned[0] == counts[0] and turned[1] == counts[2] and turned[2] == counts[1]
		and str(fields["tabs"][1]).begins_with("Only in 9493-1"))
	swap.pressed.emit()
	await _compared()


## The car against 7140: what to buy to build the car from the set, to LEGO®
## Pick a Brick from the sheet's own button.
func _car_from_7140() -> void:
	print("\n  The car against 7140: the list to buy, to LEGO® Pick a Brick")
	_main.call("clear_model")
	await _frames(10)
	var placed: int = _store.open("res://models/car.ldr")
	_bar.opened.emit(placed)
	await _frames(30)
	_check("another model opened closes the comparison", not _compare.visible)
	# What the car needs beyond 7140, by Collection's own sums: the car as What
	# do I need? counts it, the set's rows in the same spelling.
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	var needs: Dictionary = Collection.needs_of(stock, _library)
	var held: Dictionary = {}
	for row: Variant in _record("7140-1").get("p", []):
		var key: String = Collection.key_of(str(row[0]), int(row[1]), _library)
		held[key] = int(held.get(key, 0)) + int(row[2])
	var given: Dictionary = Collection.allocate(needs, held)
	var wanted: Dictionary = {}   ## element -> how many
	var short_pieces: int = 0
	var unnumbered: Array = []    ## [count, part, colour]
	for key: String in needs:
		var short: int = int(needs[key]) - int(given["have"].get(key, 0))
		if short <= 0:
			continue
		short_pieces += short
		var element: String = _library.element_for(Collection.part_of(key), Collection.colour_of(key))
		if element.is_empty():
			unnumbered.append([short, Collection.part_of(key), Collection.colour_of(key)])
		else:
			wanted[element] = int(wanted.get(element, 0)) + short
	print("     the car: %d pieces; beyond 7140 %d, %d of them with an element in %d elements, %d lots with none"
		% [stock.pieces, short_pieces, short_pieces - unnumbered.reduce(
			func(sum: int, lot: Array) -> int: return sum + int(lot[0]), 0), wanted.size(),
			unnumbered.size()])
	_check("it opens again from File", _shell.run("compare_sets"))
	await _frames(10)
	var b: OptionButton = _controls().get("compare_b")
	var at: int = _item(b, "The model open now")
	_check("B offers the model open now (\"%s\")" % (b.get_item_text(at) if at >= 0 else "none"),
		at >= 0 and not b.is_item_disabled(at))
	if at < 0:
		return
	b.select(at)
	b.item_selected.emit(at)
	var fields: Dictionary = await _compared()
	var counts: Array = _tab_counts(fields)
	_check("A is still 7140 (\"%s\"), and the car's to buy is %d pieces: %s" % [fields.get("a", ""),
		short_pieces, ", ".join(fields.get("tabs", []))], str(fields.get("a", "")).ends_with("7140")
		and counts.size() == 3 and counts[2] == short_pieces)
	_check("...and in both with it adds up to the car's %d pieces (%s)" % [Collection.coverage(
		needs, {})["pieces"], counts], counts.size() == 3 and counts[0] + counts[2] == int(
		Collection.coverage(needs, {})["pieces"]))
	var button: Button = _controls().get("compare_pickabrick")
	_check("its LEGO® Pick a Brick button is there to press", button != null
		and button.is_visible_in_tree() and not button.disabled)
	if button == null:
		return
	_bar.say("")
	button.pressed.emit()
	var note: String = await _note()
	var paths: PackedStringArray = _paths(note)
	_check("pressed, it writes the list (%s)" % note.left(110), paths.size() == 1)
	if paths.is_empty():
		return
	_window_file = FileAccess.get_file_as_string(paths[0])
	var read: Dictionary = _read_csv(_window_file)
	var listed: Dictionary = read["rows"]
	var summed: int = 0
	for element: String in listed:
		summed += int(listed[element])
	var off: Array = []
	for element: String in wanted:
		if int(listed.get(element, 0)) != int(wanted[element]):
			off.append("%s: %d for %d" % [element, int(listed.get(element, 0)), int(wanted[element])])
	for element: String in listed:
		if not wanted.has(element):
			off.append("%s not to buy" % element)
	_check("as LEGO's template writes it (%s), named for the two: %s" % [read["faults"],
		paths[0].get_file()], (read["faults"] as Array).is_empty()
		and paths[0].get_file().contains("from_7140"))
	_check("every element the car needs beyond 7140, at its count (%d lines for %d; %s)"
		% [listed.size(), wanted.size(), "none off" if off.is_empty() else ", ".join(off.slice(0, 6))],
		off.is_empty() and not wanted.is_empty())
	var with_element: int = short_pieces - unnumbered.reduce(
		func(sum: int, lot: Array) -> int: return sum + int(lot[0]), 0)
	_check("its lines sum to the list's %d pieces with an element: %d" % [with_element, summed],
		summed == with_element)
	var unnamed: Array = []
	for lot: Array in unnumbered:
		var info: PartLibrary.PartInfo = _library.parts.get(str(lot[1]))
		var name: String = Inventory._tidy(info.name) if info != null else str(lot[1])
		if not note.contains("%d × %s" % [int(lot[0]), name]):
			unnamed.append("%s/%d" % [lot[1], lot[2]])
	_check("the %d lots with no element number are named under the buttons (%s)" % [unnumbered.size(),
		"none unnamed" if unnamed.is_empty() else "unnamed %s" % unnamed], unnamed.is_empty())
	await _frames(30)
	await _shot("comparesets_car")
	_placed()
	_compare.call("close")
	await _frames(3)


# -- over MCP ------------------------------------------------------------------------


func _over_mcp() -> void:
	print("\n  parts_list which=\"compare\" over MCP")
	var said: String = await _say("parts_list", {"which": "compare", "a": "7140", "b": "9493"})
	print("     %s" % "\n     ".join(said.split("\n").slice(0, 5)))
	var counts: Array = _window_counts if _window_counts.size() == 3 else [-1, -1, -1]
	_check("in 1 call, the window's counts: %d in both, %d only in 7140-1, %d only in 9493-1"
		% counts, _window_counts.size() == 3 and said.contains("In both: %d pieces" % counts[0])
		and said.contains("Only in 7140-1: %d pieces" % counts[1])
		and said.contains("buy these: %d pieces" % counts[2]))
	# Each list under its own head, a lot a line: "  4 x 2412b Tile 1 x 2 Grille, Red (element …)".
	var lot: RegEx = RegEx.create_from_string("\\n {2}[ \\d]{3} x \\S+ .+, [^\\n]+")
	var heads: Array = []
	for head: String in ["In both:", "Only in 7140-1:", "Only in 9493-1: to build it from 7140-1, buy these:"]:
		var at: int = said.find("\n" + head + "\n")
		var next: RegExMatch = lot.search(said, at + 1) if at >= 0 else null
		if next == null or next.get_start() != at + head.length() + 1:
			heads.append(head)
	_check("...then each list by part and colour, a lot a line (%s)" % ("all three" if heads.is_empty()
		else "missing %s" % [heads]), heads.is_empty() and said.contains("(element "))
	DirAccess.remove_absolute(_out.path_join("car_from_7140_1_pickabrick.csv"))
	for name: String in DirAccess.get_files_at(_out):
		DirAccess.remove_absolute(_out.path_join(name))
	var wrote: String = await _say("parts_list", {"which": "compare", "a": "7140", "b": "open",
		"shop": "pickabrick"})
	var line: String = wrote.split("\n")[-1]
	var paths: PackedStringArray = _paths(line)
	var text: String = FileAccess.get_file_as_string(paths[0]) if paths.size() == 1 else ""
	_check("with shop=pickabrick, in 1 call, the window's file to the byte (%s)" % line.left(100),
		not text.is_empty() and text == _window_file)
	var refused: String = await _say("parts_list", {"which": "compare", "a": "7140"})
	_check("without b= it says what it takes: %s" % refused.left(80), refused.contains("a= and b="))


## A set under test in a bench run is compared by no path: its parts list is
## the answer (DesignMemory.holds, as every real set's path keeps it).
func _held_out() -> void:
	print("\n  A set under test")
	DesignMemory.hold_out(PackedStringArray(["9493-1"]))
	var said: String = await _say("parts_list", {"which": "compare", "a": "7140", "b": "9493"})
	_check("over MCP, not compared: %s" % said.left(100), said.contains("under test")
		and not said.contains("In both"))
	_shell.run("compare_sets")
	await _frames(5)
	var b: OptionButton = _controls().get("compare_b")
	var at: int = _item(b, "A set, by its number")
	if at >= 0:
		b.select(at)
		b.item_selected.emit(at)
		await _frames(3)
		var number: LineEdit = _controls().get("compare_b_number")
		if number != null:
			number.text = "9493"
			number.text_submitted.emit("9493")
	var fields: Dictionary = await _compared()
	_check("nor in the window: %s" % str(fields.get("sides", "")), str(fields.get("sides", "")).contains(
		"under test") and _fields().get("rows", []).is_empty())
	DesignMemory.hold_out(PackedStringArray())
	_compare.call("close")
	await _frames(3)


# -- reading the sheet ---------------------------------------------------------------


func _controls() -> Dictionary:
	if _compare == null or not _compare.has_method("controls_by_name"):
		return {}
	return _compare.call("controls_by_name")


func _fields() -> Dictionary:
	if _compare == null or not _compare.has_method("parts_fields"):
		return {}
	return _compare.call("parts_fields")


## The sheet once a comparison is done, or as it is after 30 s.
func _compared() -> Dictionary:
	var until: int = Time.get_ticks_msec() + 30000
	await _frames(2)
	while Time.get_ticks_msec() < until:
		var fields: Dictionary = _fields()
		if not fields.is_empty() and not bool(fields.get("comparing", true)):
			await _frames(3)
			return _fields()
		await process_frame
	return _fields()


## Each tab's count, "In both · 120" -> 120; [] before a comparison.
func _tab_counts(fields: Dictionary) -> Array:
	var out: Array = []
	for title: String in fields.get("tabs", []):
		if not title.contains(" · "):
			return []
		out.append(int(title.get_slice(" · ", 1)))
	return out


## The row of [param pick] whose words begin [param words], or -1.
func _item(pick: OptionButton, words: String) -> int:
	if pick == null:
		return -1
	for n: int in pick.item_count:
		if pick.get_item_text(n).begins_with(words):
			return n
	return -1


## What the sheet says under its shops' buttons once a list is written.
func _note() -> String:
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		var note: String = str(_fields().get("note", ""))
		if not note.is_empty():
			return note
		await process_frame
	return ""


## Each row's part named where a person reads it: the name's column as wide as
## the room the sheet leaves it, not squeezed to nothing.
func _names_shown() -> void:
	var rows: Control = _compare.get("_list_rows")
	var first: Control = rows.get_child(0) if rows != null and rows.get_child_count() > 0 else null
	var name: Label = first.get_child(4) as Label if first != null and first.get_child_count() > 4 \
		else null
	var width: float = name.size.x if name != null else 0.0
	_check("a row names its part, in a column %.0f px wide: %s" % [width,
		name.text if name != null else "no row"],
		name != null and not name.text.is_empty() and width >= 120.0)


## The sheet inside the window, and each of its controls inside it.
func _placed() -> void:
	var sheet: Rect2 = _compare.get_global_rect()
	# In the UI's own units, as the sheet's rect is (the window is scaled).
	var window: Rect2 = root.get_visible_rect()
	var outside: Array = []
	for name: String in _controls():
		var control: Control = _controls()[name]
		if control == null or not control.is_visible_in_tree():
			continue
		if not sheet.grow(0.5).encloses(control.get_global_rect()):
			outside.append("%s %s" % [name, control.get_global_rect()])
	_check("the sheet (%s) inside the %s window, every control inside it (%s)" % [sheet, _size,
		"all" if outside.is_empty() else ", ".join(outside)],
		window.grow(0.5).encloses(sheet) and outside.is_empty() and sheet.size.x >= 300.0)


## A Pick a Brick CSV: "rows" element -> quantity, and "faults", each a way it
## is not as LEGO's template writes it (elementId,quantity, then a line an
## element, ended \r\n).
func _read_csv(text: String) -> Dictionary:
	var rows: Dictionary = {}
	var faults: Array = []
	if text.is_empty():
		return {"rows": rows, "faults": ["empty"]}
	if text.contains("\n") and text.count("\r\n") != text.count("\n"):
		faults.append("a line not ended \\r\\n")
	var lines: PackedStringArray = text.strip_edges().split("\r\n")
	if lines[0] != "elementId,quantity":
		faults.append("header %s" % lines[0])
	for line: String in lines.slice(1):
		var cells: PackedStringArray = line.split(",")
		if cells.size() != 2 or not cells[0].is_valid_int() or not cells[1].is_valid_int():
			faults.append("line %s" % line)
			continue
		if rows.has(cells[0]):
			faults.append("%s twice" % cells[0])
		rows[cells[0]] = int(cells[1])
	return {"rows": rows, "faults": faults}


## The files a line says it wrote: "Wrote A and B — …".
func _paths(said: String) -> PackedStringArray:
	var head: String = said.get_slice(" — ", 0).trim_suffix(".")
	if not head.to_lower().begins_with("wrote "):
		return PackedStringArray()
	return head.substr(6).split(" and ")


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


func _say(tool: String, arguments: Dictionary) -> String:
	var result: Dictionary = await _rpc("tools/call", {"name": tool, "arguments": arguments})
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _shot(named: String) -> void:
	if _shots.is_empty():
		return
	await RenderingServer.frame_post_draw
	var path: String = _shots.path_join("%s_%s.png" % [named, _size])
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok
