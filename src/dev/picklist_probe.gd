## Buying the parts from LEGO® Pick a Brick, and a BrickLink wanted list
## with BrickLink's own options (APP_UX4 4, picklist).
##
##   godot --path . --resolution 1280x720 --script src/dev/picklist_probe.gd
##   ... -- --shots=DIR   the Export menu, the parts list's note and BrickLink's choices pictured there
##   ... -- --phone        laid out for a finger, as a phone's browser gets it (390x844)
##
## LEGO's Pick a Brick takes a list of element numbers and quantities,
## `elementId,quantity`, up to 400 lines a file and 999 of an element (its
## upload, New Elementary, 2024-10). BrickLink's wanted list upload reads
## an XML whose tags its help documents (help.asp?helpID=207, "Wanted List,
## Mass Upload", updated 2025-10-16): CONDITION N or U, NOTIFY Y,
## WANTEDLISTID an additional list's ID. Here, as a person and a session do
## it, on the real scene:
##   File, Export, LEGO® Pick a Brick list: the car's list holds every lot
##   with an element number, its quantities summing to those parts, and the
##   rest are named, on the status line and in the parts list;
##   a model of 450 lots comes as two files, of 400 and 50;
##   the parts list's BrickLink choices (condition, wanted list, email) are
##   in its XML as chosen, kept for File, Export, and every tag is one the
##   help documents, with a value it allows;
##   export_model over MCP does both, the options as arguments.
## Nothing is uploaded.
extends SceneTree

## What LEGO's Pick a Brick takes (New Elementary, 2024-10).
const LINES_MOST := 400
const EACH_MOST := 999
## BrickLink's wanted list tags, in the order its help lists them, and the
## item types it allows.
const TAGS: Array[String] = ["ITEMTYPE", "ITEMID", "COLOR", "MAXPRICE", "MINQTY", "QTYFILLED",
	"CONDITION", "REMARKS", "NOTIFY", "WANTEDSHOW", "WANTEDLISTID"]
const ITEM_TYPES: Array[String] = ["S", "P", "M", "B", "G", "C", "I", "O"]

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bar: ModelBar
var _world: BrickWorld
var _store: ModelStore
var _library: PartLibrary
var _socket: CommandSocket
var _next: int = 0
var _out: String = ""
var _shots: String = ""
var _size: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots = arg.trim_prefix("--shots=")
			DirAccess.make_dir_recursive_absolute(_shots)
	_size = "%dx%d" % [root.size.x, root.size.y]
	if OS.get_cmdline_user_args().has("--phone"):
		# The layout for a finger, as a phone's browser gets it.
		Phone._on = 1
		_size += "_phone"
	_out = OS.get_user_data_dir().path_join("picklist_probe")
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
		print("  picklist probe: SKIPPED — no model came up on the baseplate")
		quit(0)
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

	await _the_car()
	await _bricklink()
	await _over_mcp()
	await _four_hundred_and_fifty()

	print("")
	if _failures == 0:
		print("picklist probe: all checks passed")
	else:
		print("picklist probe: %d check(s) FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## The car, opened as a person opens it.
func _open_car() -> void:
	_main.call("clear_model")
	await _frames(10)
	var placed: int = _store.open("res://models/car.ldr")
	_bar.opened.emit(placed)
	await _frames(30)


## The car's parts that have an element number: element -> how many; and
## the lots that have none.
func _expected() -> Dictionary:
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	var wanted: Dictionary = {}
	var missing: Array = []
	var pieces: int = 0
	for lot: Inventory.Lot in stock.lots:
		if lot.custom or lot.element.is_empty():
			missing.append(lot)
			continue
		wanted[lot.element] = int(wanted.get(lot.element, 0)) + lot.count
		pieces += lot.count
	return {"wanted": wanted, "missing": missing, "pieces": pieces, "lots": stock.lots.size(),
		"all": stock.pieces}


func _the_car() -> void:
	print("\n  File, Export, LEGO® Pick a Brick list, on the car")
	await _open_car()
	var expected: Dictionary = _expected()
	var wanted: Dictionary = expected["wanted"]
	var missing: Array = expected["missing"]
	print("     the car: %d pieces in %d lots; %d elements known for %d pieces; %d lots with none"
		% [expected["all"], expected["lots"], wanted.size(), expected["pieces"], missing.size()])
	_check("the car is open (%d pieces)" % int(expected["all"]), int(expected["all"]) > 20)
	var exports: Array = Shell.SUBMENUS.get("export", [])
	_check("File, Export lists it, after Rebrickable's (%s)" % ", ".join(exports),
		exports.has("export_pickabrick")
			and exports.find("export_pickabrick") == exports.find("export_rebrickable") + 1)
	var command: Shell.Command = _shell.command("export_pickabrick")
	_check("its row reads \"%s\"" % (command.words if command != null else "(none)"),
		command != null and command.words == "LEGO® Pick a Brick list (.csv)")
	await _shot_menu()
	var file: String = _out.path_join(_bar.model_name().to_snake_case() + "_pickabrick.csv")
	_bar.say("")
	_check("it can be pressed", _shell.run("export_pickabrick"))
	var said: String = await _said(["wrote", "could not", "no "])
	var text: String = await _file(file)
	_check("it writes %s (%s)" % [file.get_file(), said.left(90)], not text.is_empty())
	var read: Dictionary = _read_csv(text)
	_check("as LEGO's template writes it: elementId,quantity, its lines ended \\r\\n (%s)"
		% str(read["faults"]), (read["faults"] as Array).is_empty())
	var listed: Dictionary = read["rows"]
	var short: Array = []
	var extra: Array = []
	var wrong: Array = []
	for element: String in wanted:
		if not listed.has(element):
			short.append(element)
		elif int(listed[element]) != mini(int(wanted[element]), EACH_MOST):
			wrong.append("%s: %d for %d" % [element, int(listed[element]), int(wanted[element])])
	for element: String in listed:
		if not wanted.has(element):
			extra.append(element)
	var summed: int = 0
	for element: String in listed:
		summed += int(listed[element])
	_check("every lot with an element number is on it: %d lines for %d elements (short %s, more %s)"
		% [listed.size(), wanted.size(), short, extra],
		short.is_empty() and extra.is_empty() and not wanted.is_empty())
	_check("each quantity is its parts' (%s), summing to %d, its %d pieces with an element"
		% [wrong, summed, int(expected["pieces"])],
		wrong.is_empty() and summed == int(expected["pieces"]))
	var unnamed: Array = []
	for lot: Inventory.Lot in missing:
		if not said.contains("%d × %s in %s (%s)" % [lot.count, lot.name, lot.color_name,
				lot.part_id]):
			unnamed.append("%s/%d" % [lot.part_id, lot.color_code])
	_check("the %d lots with no element number are named on the status line (%s): %s"
		% [missing.size(), "none unnamed" if unnamed.is_empty() else "unnamed %s" % unnamed,
			said.get_slice(" — not on it", 1).left(160)],
		unnamed.is_empty() and (missing.is_empty() or said.contains("not on it")))
	_check("...and it says where the file goes: LEGO® Pick a Brick",
		said.contains("to upload at LEGO® Pick a Brick"))

	# The parts list's own button, and the same parts named in it.
	_shell.run("parts_list")
	await _frames(20)
	var panel: InventoryPanel = _main.get("_inventory")
	var controls: Dictionary = panel.controls_by_name() if panel != null else {}
	var button: Button = controls.get("parts_pickabrick")
	_check("the parts list has a LEGO® Pick a Brick button (%s)" % (button.text if button != null
		else "none"), button != null and button.is_visible_in_tree())
	if button == null:
		return
	DirAccess.remove_absolute(file)
	var row: Control = controls.get("parts_row")
	var row_was: Rect2 = row.get_global_rect() if row != null else Rect2()
	button.pressed.emit()
	text = await _file(file)
	await _frames(5)
	var note: Label = panel.controls_by_name().get("parts_note")
	var noted: String = note.text if note != null else ""
	unnamed.clear()
	for lot: Inventory.Lot in missing:
		if not noted.contains("%s in %s" % [lot.name, lot.color_name]):
			unnamed.append(lot.name)
	_check("pressed, it writes the same list (%d lines)" % _read_csv(text)["rows"].size(),
		(_read_csv(text)["rows"] as Dictionary) == listed)
	_check("and the parts list names the lots not on it, wrapped (%s)"
		% ("all %d" % missing.size() if unnamed.is_empty() else "unnamed %s" % unnamed),
		note != null and note.is_visible_in_tree() and unnamed.is_empty()
			and note.autowrap_mode != TextServer.AUTOWRAP_OFF)
	var row_is: Rect2 = row.get_global_rect() if row != null else Rect2(-1, -1, 0, 0)
	_check("...and no row moves when it says so, the note being at the list's foot (the first at %s, was %s)"
		% [row_is.position, row_was.position],
		row != null and row_is.position.is_equal_approx(row_was.position)
			and note != null and note.get_global_rect().position.y >= row_is.position.y)
	var header_right: float = button.get_global_rect().end.x
	var panel_right: float = panel.get_global_rect().end.x
	_check("its header's buttons are inside the panel (the last ends at %.0f, the panel at %.0f)"
		% [header_right, panel_right], header_right <= panel_right + 0.5)
	await _shot("picklist_parts_note")


## The parts list's BrickLink choices, in its XML as chosen, and every tag
## as BrickLink's help documents it.
func _bricklink() -> void:
	print("\n  BrickLink's wanted list, from the parts list's BrickLink button")
	var panel: InventoryPanel = _main.get("_inventory")
	if panel == null or not panel.visible:
		_shell.run("parts_list")
		await _frames(20)
		panel = _main.get("_inventory")
	var file: String = _out.path_join(_bar.model_name().to_snake_case() + "_bricklink.xml")
	var wants: Button = panel.controls_by_name().get("parts_bricklink_wants")
	_check("beside its BrickLink button, its choices (%s)" % (wants.tooltip_text if wants != null
		else "none"), wants != null and wants.is_visible_in_tree())
	if wants == null:
		return
	wants.pressed.emit()
	await _frames(5)
	var controls: Dictionary = panel.controls_by_name()
	var condition: OptionButton = controls.get("bricklink_condition")
	var into: LineEdit = controls.get("bricklink_list")
	var notify: CheckBox = controls.get("bricklink_notify")
	var save: Button = controls.get("bricklink_save")
	_check("pressed, it asks the condition, the wanted list and the email",
		condition != null and into != null and notify != null and save != null)
	if save == null:
		return
	var choices: Array = []
	for n: int in condition.item_count:
		choices.append(condition.get_item_text(n))
	_check("the condition is new or used, new, or used (%s)" % ", ".join(choices),
		choices.size() == 3)
	condition.select(1)
	condition.item_selected.emit(1)
	into.grab_focus()
	into.text = "12a34567"
	into.text_changed.emit(into.text)
	_check("the wanted list takes digits only (\"12a34567\" reads \"%s\")" % into.text,
		into.text == "1234567")
	notify.button_pressed = true
	await _frames(8)
	# The dialog in the window, and its fields and Save in the dialog.
	var dialog: Window = save.get_window()
	var outside: Array = []
	var placed: Rect2 = Rect2(Vector2(dialog.position), Vector2(dialog.size))
	if not root.get_visible_rect().grow(1.0).encloses(placed):
		outside.append("the dialog %s in %s" % [placed, root.get_visible_rect()])
	for control: Control in [condition, into, notify, save]:
		if not Rect2(Vector2.ZERO, Vector2(dialog.size)).grow(1.0).encloses(control.get_global_rect()):
			outside.append("%s %s in %s" % [control.get_class(), control.get_global_rect(),
				dialog.size])
	_check("its fields and Save are all in the window (%s)" % ("so" if outside.is_empty()
		else ", ".join(outside)), outside.is_empty())
	await _shot("picklist_bricklink_choices")
	DirAccess.remove_absolute(file)
	_bar.say("")
	save.pressed.emit()
	var said: String = await _said(["wrote", "could not"])
	var xml: String = await _file(file)
	var items: Array = _items(xml)
	_check("Save the list writes it (%s)" % said.left(120), not items.is_empty())
	_documented(xml, "new, list 1234567, email")
	_check("each item asks CONDITION N, NOTIFY Y and WANTEDLISTID 1234567, as chosen",
		_all(items, {"CONDITION": "N", "NOTIFY": "Y", "WANTEDLISTID": "1234567"}))
	_check("...and the line says so: %s" % said.get_slice(" — ", 1),
		said.contains("new only") and said.contains("wanted list 1234567"))
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	var counted: int = 0
	for item: Dictionary in items:
		counted += int(item.get("MINQTY", "0"))
	var made: int = 0
	var left: int = 0
	for lot: Inventory.Lot in stock.lots:
		if lot.custom or _library.bricklink_colour(lot.color_code) < 0:
			left += lot.count
		else:
			made += lot.count
	_check("its MINQTYs sum to the car's parts BrickLink has a colour for (%d of %d; %d left off)"
		% [counted, stock.pieces, left], counted == made and counted > 0)

	# Kept: File, Export writes the same.
	DirAccess.remove_absolute(file)
	_check("File, Export, BrickLink wanted list can be pressed", _shell.run("export_bricklink"))
	xml = await _file(file)
	_check("...and uses the same choices, kept",
		_all(_items(xml), {"CONDITION": "N", "NOTIFY": "Y", "WANTEDLISTID": "1234567"}))

	# Used, the main list, no email: the tags BrickLink reads as those left out.
	wants.pressed.emit()
	await _frames(5)
	_check("opened again, it shows the choice kept (%s, \"%s\", %s)" % [
		condition.get_item_text(condition.selected), into.text, notify.button_pressed],
		condition.selected == 1 and into.text == "1234567" and notify.button_pressed)
	condition.select(2)
	condition.item_selected.emit(2)
	into.text = ""
	into.text_changed.emit("")
	notify.button_pressed = false
	DirAccess.remove_absolute(file)
	save.pressed.emit()
	xml = await _file(file)
	_documented(xml, "used, main list")
	_check("used only, into the main list, no email: CONDITION U, no WANTEDLISTID, no NOTIFY",
		_all(_items(xml), {"CONDITION": "U", "NOTIFY": "", "WANTEDLISTID": ""}))
	wants.pressed.emit()
	await _frames(5)
	condition.select(0)
	condition.item_selected.emit(0)
	DirAccess.remove_absolute(file)
	save.pressed.emit()
	xml = await _file(file)
	_documented(xml, "either")
	_check("new or used: no CONDITION at all, BrickLink's own any",
		_all(_items(xml), {"CONDITION": "", "NOTIFY": "", "WANTEDLISTID": ""}))
	(panel.controls_by_name()["parts_done"] as Button).pressed.emit()
	await _frames(5)


## A session's export_model: pickabrick, and bricklink with its options.
func _over_mcp() -> void:
	print("\n  over MCP")
	var listed: Dictionary = await _rpc("tools/list", {})
	var schema: Dictionary = {}
	for tool: Dictionary in listed.get("tools", []):
		if str(tool.get("name", "")) == "export_model":
			schema = tool.get("inputSchema", tool.get("input_schema", {}))
	var properties: Dictionary = schema.get("properties", {})
	var formats: Array = (properties.get("format", {}) as Dictionary).get("enum", [])
	_check("export_model offers pickabrick, and condition, wanted_list and notify (%s)"
		% ", ".join(properties.keys()), formats.has("pickabrick") and properties.has("condition")
		and properties.has("wanted_list") and properties.has("notify"))
	var said: String = await _say("export_model", {"format": "pickabrick"})
	var paths: PackedStringArray = _paths(said)
	var expected: Dictionary = _expected()
	var rows: Dictionary = _read_csv(FileAccess.get_file_as_string(paths[0]))["rows"] \
		if paths.size() == 1 else {}
	_check("format pickabrick writes the car's list in 1 call: %s" % said.left(140),
		paths.size() == 1 and rows.size() == (expected["wanted"] as Dictionary).size())
	var missing: Array = expected["missing"]
	_check("...its answer naming the %d lots with no element number" % missing.size(),
		missing.all(func(lot: Inventory.Lot) -> bool: return said.contains(
			"%d × %s in %s (%s)" % [lot.count, lot.name, lot.color_name, lot.part_id])))
	said = await _say("export_model", {"format": "bricklink", "condition": "used",
		"wanted_list": 7654321, "notify": true})
	paths = _paths(said)
	var xml: String = FileAccess.get_file_as_string(paths[0]) if paths.size() == 1 else ""
	_documented(xml, "over MCP")
	_check("bricklink with condition used, wanted_list 7654321, notify: in its XML (%s)"
		% said.left(140), _all(_items(xml), {"CONDITION": "U", "NOTIFY": "Y",
			"WANTEDLISTID": "7654321"}))
	said = await _say("export_model", {"format": "bricklink", "condition": "mint"})
	_check("a condition BrickLink has not is refused, with its choices: %s" % said,
		said.contains("new, used or any"))
	said = await _say("export_model", {"format": "bricklink", "wanted_list": "my list"})
	_check("a wanted list that is no ID is refused, with where to find one: %s" % said.left(100),
		said.contains("wantedMoreID"))


## A model of 450 lots, each an element of its own: two files, of 400 and 50.
func _four_hundred_and_fifty() -> void:
	print("\n  a model of 450 lots")
	_main.call("clear_model")
	await _frames(10)
	var parts: Array[String] = ["3001", "3003", "3004", "3005", "3010", "3009", "3008", "3020",
		"3021", "3022", "3023", "3024", "3710", "3666", "3460", "3068b", "3069b", "3070b",
		"3062b", "4073", "3040b", "3039", "3622", "3623", "3795", "3034", "3832", "2780", "32316",
		"6558", "3700", "3701", "3894", "3895", "2412b", "3065", "3010p01", "4070", "3794b"]
	var codes: Array = _library.colors.keys()
	codes.sort()
	var taken: Dictionary = {}
	var placed: int = 0
	for part: String in parts:
		if not _library.parts.has(part):
			continue
		for code: int in codes:
			if placed >= 450:
				break
			var element: String = _library.element_for(part, code)
			if element.is_empty() or taken.has(element) or _library.plain_code(code) != code:
				continue
			taken[element] = true
			_world.add_brick(part, code, Transform3D(Basis.IDENTITY,
				Vector3((placed % 30) * 120.0, 0.0, floorf(placed / 30.0) * 120.0)))
			placed += 1
	await _frames(10)
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	_check("450 lots, each an element of its own (%d lots, %d elements)" % [stock.lot_count(),
		taken.size()], stock.lot_count() == 450 and taken.size() == 450)
	var said: String = await _say("export_model", {"format": "pickabrick"})
	var paths: PackedStringArray = _paths(said)
	var sizes: Array = []
	var all: Dictionary = {}
	var faults: Array = []
	for path: String in paths:
		var read: Dictionary = _read_csv(FileAccess.get_file_as_string(path))
		sizes.append((read["rows"] as Dictionary).size())
		all.merge(read["rows"])
		faults.append_array(read["faults"])
	_check("two files, of 400 and 50 lines (%s: %s)" % [", ".join(Array(paths).map(
		func(path: String) -> String: return path.get_file())), sizes], sizes == [400, 50])
	_check("each as LEGO's template writes it (%s), every element on one of them (%d of 450)"
		% [faults, all.size()], faults.is_empty() and all.size() == 450
			and taken.keys().all(func(element: String) -> bool: return all.has(element)))
	_check("...and the answer says why two: %s" % said.get_slice(" — ", 2),
		said.contains("2 files of 400 lines at most"))


# -- reading what was written ---------------------------------------------------


## A Pick a Brick CSV: "rows" element -> quantity, and "faults", each a way it
## is not as LEGO's template writes it (elementId,quantity, then a line an
## element, ended \r\n), or not what Pick a Brick takes.
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
	if lines.size() - 1 > LINES_MOST:
		faults.append("%d lines" % (lines.size() - 1))
	for line: String in lines.slice(1):
		var cells: PackedStringArray = line.split(",")
		if cells.size() != 2 or not cells[0].is_valid_int() or not cells[1].is_valid_int():
			faults.append("line %s" % line)
			continue
		if rows.has(cells[0]):
			faults.append("%s twice" % cells[0])
		if int(cells[1]) < 1 or int(cells[1]) > EACH_MOST:
			faults.append("%s x %s" % [cells[0], cells[1]])
		rows[cells[0]] = int(cells[1])
	return {"rows": rows, "faults": faults}


## The wanted list's items, each its tags: tag -> value.
func _items(xml: String) -> Array:
	var out: Array = []
	for found: RegExMatch in RegEx.create_from_string("(?s)<ITEM>(.*?)</ITEM>").search_all(xml):
		var item: Dictionary = {}
		for tag: RegExMatch in RegEx.create_from_string("<([A-Z]+)>([^<]*)</\\1>").search_all(
				found.get_string(1)):
			item[tag.get_string(1)] = tag.get_string(2)
		out.append(item)
	return out


## Every item has [param wanted]'s tags with those values, "" for a tag
## left out.
func _all(items: Array, wanted: Dictionary) -> bool:
	if items.is_empty():
		return false
	for item: Dictionary in items:
		for tag: String in wanted:
			if str(item.get(tag, "")) != str(wanted[tag]):
				return false
	return true


## The XML as BrickLink's help documents it: no declaration, INVENTORY around
## ITEMs; in each ITEM, ITEMTYPE and ITEMID, and only the tags it lists, in
## its order, each once, with a value it allows; no stand-alone ampersand.
func _documented(xml: String, what: String) -> void:
	var faults: Array = []
	var body: String = xml.strip_edges()
	if body.contains("<?xml"):
		faults.append("an XML declaration")
	if not body.begins_with("<INVENTORY>") or not body.ends_with("</INVENTORY>"):
		faults.append("not one INVENTORY")
	var between: String = RegEx.create_from_string("(?s)<ITEM>.*?</ITEM>").sub(
		body.trim_prefix("<INVENTORY>").trim_suffix("</INVENTORY>"), "", true)
	if not between.strip_edges().is_empty():
		faults.append("outside an ITEM: %s" % between.strip_edges().left(40))
	if RegEx.create_from_string("&(?!(amp|lt|gt|quot|apos|#\\d+);)").search(xml) != null:
		faults.append("a stand-alone &")
	var tags: RegEx = RegEx.create_from_string("<([A-Z]+)>([^<]*)</\\1>")
	var count: int = 0
	for found: RegExMatch in RegEx.create_from_string("(?s)<ITEM>(.*?)</ITEM>").search_all(body):
		count += 1
		var inside: String = found.get_string(1)
		if not tags.sub(inside, "", true).strip_edges().is_empty():
			faults.append("not a tag: %s" % tags.sub(inside, "", true).strip_edges().left(40))
		var last: int = -1
		var seen: Dictionary = {}
		for tag: RegExMatch in tags.search_all(inside):
			var name: String = tag.get_string(1)
			var value: String = tag.get_string(2).strip_edges()
			var at: int = TAGS.find(name)
			if at < 0:
				faults.append("an undocumented tag %s" % name)
			elif at <= last:
				faults.append("%s out of the help's order" % name)
			last = maxi(last, at)
			if seen.has(name):
				faults.append("%s twice" % name)
			seen[name] = true
			var allowed: bool = {
				"ITEMTYPE": value in ITEM_TYPES,
				"ITEMID": not value.is_empty(),
				"COLOR": value.is_valid_int() and int(value) >= 0,
				"MAXPRICE": value.is_valid_float() and float(value) > 0.0,
				"MINQTY": value.is_valid_int() and int(value) > 0,
				"QTYFILLED": value.is_valid_int() and int(value) >= 0,
				"CONDITION": value in ["N", "U"],
				"REMARKS": true,
				"NOTIFY": value in ["Y", "N"],
				"WANTEDSHOW": value in ["Y", "N"],
				"WANTEDLISTID": value.is_valid_int() and int(value) > 0,
			}.get(name, false)
			if not allowed:
				faults.append("%s %s" % [name, value])
		if not seen.has("ITEMTYPE") or not seen.has("ITEMID"):
			faults.append("an ITEM without ITEMTYPE and ITEMID")
	var unique: Array = []
	for fault: String in faults:
		if not unique.has(fault):
			unique.append(fault)
	_check("%s: all %d items as BrickLink's help documents them (%s)" % [what, count,
		"no fault" if unique.is_empty() else ", ".join(unique.slice(0, 6))],
		count > 0 and unique.is_empty())


## The files an answer or a line says it wrote: "Wrote A and B — …".
func _paths(said: String) -> PackedStringArray:
	var head: String = said.get_slice(" — ", 0).trim_suffix(".")
	if not head.to_lower().begins_with("wrote "):
		return PackedStringArray()
	return head.substr(6).split(" and ")


## The file at [param path] once it is written, or "" after 60 s.
func _file(path: String) -> String:
	var until: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		if FileAccess.file_exists(path):
			await _frames(3)
			return FileAccess.get_file_as_string(path)
		await process_frame
	return ""


func _said(starts: Array, seconds: float = 60.0) -> String:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		var line: String = _bar.status_text()
		for start: String in starts:
			if line.begins_with(start):
				return line
	return _bar.status_text()


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


# -- pictures -------------------------------------------------------------------


## File, Export open, its rows shown.
func _shot_menu() -> void:
	if _shots.is_empty():
		return
	var file: MenuButton = _shell.menu("File")
	if file == null:
		return
	file.show_popup()
	await _frames(5)
	var popup: PopupMenu = file.get_popup()
	var export: PopupMenu = popup.find_child("export", false, false)
	if export != null:
		var row: int = -1
		for n: int in popup.item_count:
			if popup.get_item_submenu_node(n) == export:
				row = n
		var bounds: Rect2 = Rect2(popup.position, popup.size)
		export.position = Vector2i(int(bounds.end.x), popup.position.y
			+ int(bounds.size.y * float(maxi(row, 0)) / float(maxi(popup.item_count, 1))))
		export.popup()
		await _frames(8)
	await _shot("picklist_export_menu")
	if export != null:
		export.hide()
	popup.hide()
	await _frames(3)


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
