## A model made easier to buy (rareswap, APP_UX9 #12): the parts list's rare
## row, its swaps, applied in one undo, and replace_parts rare=true.
##
##   godot --headless --path . --script src/dev/rareswap_probe.gd
##
## The bar, line by line:
## - listed: on 10 gallery models (TEN), every lot whose part comes in its
##   colour in 3 sets or fewer (PartLibrary.sets_in_colour, counted here
##   apart from RareSwap) is on the parts list's rare row, and tagged on its
##   own row;
## - swapped: each has a swap that comes in 20 or more sets, read here from
##   the colours files again: the nearest colour (its ΔE said), or the same
##   colour in an equal part, whose shape is the old one's box and
##   connection points; the row pressed, Swap pressed, as a person presses
##   them: one undo step;
## - measured: the row's rare count before and after, on each of the 10,
##   written to RARESWAP_OUT (bench/results/rareswap-2026-11-17/gallery.tsv);
## - over MCP: replace_parts rare=true in 1 call gives the panel's file;
##   preview changes nothing; lots= swaps only those named, a print among
##   them to its plain part;
## - kept, the save path's attacks on someone else's file
##   (fixtures/rareswap_kept.mpd: its author, licence, history and comments,
##   a line spaced as nobody else spaces it, a wing placed twice and once by
##   a mirror, a tip inside the wing): opened and saved, the file to the
##   byte; swapped, only the swapped lines change, each sub-model written
##   once; undo the file to the byte, redo the swap's file; saved and
##   opened again, every part as it was shown and the same rare count; a
##   print kept unless picked; a swap inside a sub-model changes every copy,
##   the mirrored one too; a locked part stays and is said;
## - the words in German, French and Spanish.
##
##   RARESWAP_CASES=gallery,mcp   those cases (scout: all 19 seeds, counts only)
##   RARESWAP_OUT=DIR             where gallery.tsv goes
extends "res://src/dev/copyfaults_probe.gd"

const RARE_CASES: Array = ["gallery", "mcp", "kept", "printed", "locked", "picks", "words"]
## The ten gallery models: the seeds (tools/web/gallery_seeds/seeds.json) with
## the most rare lots, as the scout case counts them.
const TEN: Array = ["models/orthanc.ldr", "models/corner_shop.ldr",
	"tools/web/gallery_seeds/oak_treehouse.ldr", "tools/web/gallery_seeds/red_fox.ldr",
	"tools/web/gallery_seeds/sleeping_dragon.ldr", "tools/web/gallery_seeds/lakeside_campsite.ldr",
	"models/barn_owl.ldr", "tools/web/gallery_seeds/vintage_tractor.ldr",
	"tools/web/gallery_seeds/maintenance_robot.ldr", "tools/web/gallery_seeds/village_bakery.ldr"]
const SEEDS := "res://tools/web/gallery_seeds/seeds.json"
const KEPT := "rareswap_kept.mpd"

var _rows_out := PackedStringArray()
var _part_number: RegEx = RegEx.create_from_string("^[a-z]?\\d+[a-z0-9]*$")


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(2400.0).timeout.connect(func() -> void:
		print("rareswap probe: not finished in time")
		quit(1))
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	_socket = (_main.get("_connector") as ClaudeConnector).rpc
	var cases: Array = RARE_CASES if OS.get_environment("RARESWAP_CASES").is_empty() \
		else Array(OS.get_environment("RARESWAP_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"scout": await _case_scout()
			"gallery": await _case_gallery()
			"mcp": await _case_mcp()
			"kept": await _case_kept()
			"printed": await _case_printed()
			"locked": await _case_locked()
			"picks": await _case_picks()
			"words": await _case_words()
			_: _check("no such case %s" % name, false)
	var out: String = OS.get_environment("RARESWAP_OUT")
	if not out.is_empty() and not _rows_out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		var file := FileAccess.open(out.path_join("gallery.tsv"), FileAccess.WRITE)
		file.store_string("model\tlots\trare_before\trare_after\tcolour_swaps\tpart_swaps\t"
			+ "prints_kept\tno_swap\tmean_delta_e\n" + "\n".join(_rows_out) + "\n")
		file.close()
		print("  written %s" % out.path_join("gallery.tsv"))
	print("\nrareswap probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the probe's own count of what is rare ------------------------------------------


## Every lot of the model shown whose part comes in its colour in 3 sets or
## fewer, counted here from the colours files apart from RareSwap: "part/
## colour" -> sets. A sticker, a custom part and a part in no set in any
## colour are left out.
func _rare_here() -> Dictionary:
	var out: Dictionary = {}
	var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
	for lot: Inventory.Lot in stock.lots:
		if lot.custom or not Collection.ownable(lot.part_id, _library):
			continue
		var sets: int = _library.sets_in_colour(lot.part_id, lot.color_code)
		if sets > 3:
			continue
		var any: bool = false
		for code: int in _library.colors:
			if _library.sets_in_colour(lot.part_id, code) > 0:
				any = true
				break
		if any:
			out["%s/%d" % [lot.part_id, lot.color_code]] = sets
	return out


## How many times [param text] defines sub-model [param file].
func _defined(text: String, file: String) -> int:
	return text.count("0 FILE %s" % file)


## How many of the model's parts are [param part] in [param colour].
func _count(part: String, colour: int) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.color_code == colour:
			count += 1
	return count


# -- the parts list ------------------------------------------------------------------


func _list() -> InventoryPanel:
	return _main.get("_inventory")


## The parts list opened by its command (P), as the Build menu opens it.
func _list_up() -> InventoryPanel:
	var list: InventoryPanel = _main.get("_inventory_made")
	if list != null and list.is_showing():
		list.hide_list()
	_shell.run("parts_list")
	await _frames(6)
	return _list()


## The rare row's count: the number it starts with, 0 when it says none.
static func _row_count(text: String) -> int:
	var at: String = text.get_slice(". Still rare: ", 1) if text.contains(". Still rare: ") else text
	if text.contains("No lot is rare now") or at.is_empty():
		return 0
	if at.begins_with("1 lot comes"):
		return 1
	return int(at.get_slice(" ", 0))


## A control pressed with the mouse where it is on screen, as a person
## presses it.
func _press(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	var rect: Vector2 = root.get_visible_rect().size
	var event_at: Vector2 = at * (Vector2(DisplayServer.window_get_size()) / rect) \
		if rect.x > 0.0 and rect.y > 0.0 else at
	var move := InputEventMouseMotion.new()
	move.position = event_at
	move.global_position = event_at
	Input.parse_input_event(move)
	await process_frame
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
		event.position = event_at
		event.global_position = event_at
		Input.parse_input_event(event)
		await process_frame
	await _frames(4)


## The rare row pressed, and the swaps' list once it is filled (30 s at most).
func _swaps_up(list: InventoryPanel) -> bool:
	var row: Control = list.controls_by_name().get("parts_rare")
	if row == null:
		return false
	await _press(row)
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		if list.controls_by_name().has("parts_swap_row") and not bool(list.get("_swapping")):
			return true
		await process_frame
	return false


## Swap pressed, and the list once it is taken again (30 s at most).
func _swap_pressed(list: InventoryPanel) -> bool:
	var button: Button = list.controls_by_name().get("parts_swap")
	if button == null or button.disabled:
		return false
	var depth: int = _builder.history_depth()
	await _press(button)
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		if not bool(list.get("_swapping")) and not list.controls_by_name().has("parts_swap") \
				and _builder.history_depth() != depth:
			await _frames(4)
			return true
		await process_frame
	return false


# -- the cases -----------------------------------------------------------------------


## Every gallery seed's rare lots, counted: which ten the bar is measured on.
func _case_scout() -> void:
	var seeds: Variant = JSON.parse_string(FileAccess.get_file_as_string(SEEDS))
	for seed: Dictionary in seeds:
		await _open(FileAccess.get_file_as_string("res://" + str(seed["file"])))
		var rare: Dictionary = _rare_here()
		var stock: Inventory = Inventory.of(_world, _library, _store.scenery)
		print("  %s: %d lots, %d rare: %s" % [seed["file"], stock.lot_count(), rare.size(),
			", ".join(rare.keys())])


## The bar's ten: each listed, each swapped, measured, in one undo, undone
## and redone to the byte.
func _case_gallery() -> void:
	for file: String in TEN:
		var text: String = FileAccess.get_file_as_string("res://" + file)
		await _open(text)
		var name: String = file.get_file().get_basename()
		var before: String = _save()
		var rare: Dictionary = _rare_here()
		var list: InventoryPanel = await _list_up()
		var said: String = list.controls_by_name()["parts_rare"].text \
			if list.controls_by_name().has("parts_rare") else ""
		print("  %s: row \"%s\"" % [name, said])
		var listed: Dictionary = {}
		for lot: RareSwap.Lot in list.get("_rare"):
			listed[lot.key] = lot.sets
		var missing: Array = rare.keys().filter(func(key: String) -> bool: return not listed.has(key))
		var extra: Array = listed.keys().filter(func(key: String) -> bool: return not rare.has(key))
		_check("%s listed: the row's %d is every lot in 3 sets or fewer (%d here)%s%s" % [name,
			_row_count(said), rare.size(), "" if missing.is_empty() else ", missing " + str(missing),
			"" if extra.is_empty() else ", more " + str(extra)], _row_count(said) == rare.size()
			and missing.is_empty() and extra.is_empty() and not rare.is_empty())
		var tagged: int = (list.get("_rare_rows") as Dictionary).size()
		_check("%s listed: ...each tagged on its own row (%d)" % [name, tagged], tagged == rare.size())
		if not await _swaps_up(list):
			_check("%s: the rare row opens the swaps" % name, false)
			continue
		var colour_swaps: int = 0
		var part_swaps: int = 0
		var prints_kept: int = 0
		var none: Array = []
		var delta: float = 0.0
		var wrong: Array = []
		for lot: RareSwap.Lot in list.get("_rare"):
			print("    %s" % (list.get("_swapper") as RareSwap).lot_words(lot))
			if not lot.offered():
				none.append(lot.key)
				continue
			var part: String = lot.into_part if not lot.into_part.is_empty() else lot.part
			var colour: int = lot.into_colour if lot.into_colour >= 0 else lot.colour
			var sets: int = _library.sets_in_colour(part, colour)
			if sets < 20 or sets != lot.into_sets:
				wrong.append("%s: %s/%d in %d sets" % [lot.key, part, colour, sets])
			if not lot.into_part.is_empty():
				part_swaps += 1
				if lot.into_colour >= 0 or not RareSwap.same_shape(_library.mesh_for(lot.part),
						_library.mesh_for(lot.into_part)):
					wrong.append("%s: %s is not its shape in its colour" % [lot.key, lot.into_part])
				if lot.drops_print():
					prints_kept += 1
					if lot.picked:
						wrong.append("%s: a print picked to lose its print" % lot.key)
			else:
				colour_swaps += 1
				delta += lot.delta_e
				if lot.into_colour == lot.colour:
					wrong.append("%s: the same colour" % lot.key)
		_check("%s swapped: each of %d has a swap in 20 sets or more (%d colours, %d parts; none for %s)%s"
			% [name, listed.size(), colour_swaps, part_swaps, none, "" if wrong.is_empty()
			else ": " + "; ".join(wrong)], wrong.is_empty() and none.is_empty())
		var depth: int = _builder.history_depth()
		var pressed: bool = await _swap_pressed(list)
		var after_said: String = list.controls_by_name()["parts_rare"].text \
			if list.controls_by_name().has("parts_rare") else ""
		var after: String = _save()
		var left: int = _rare_here().size()
		print("  %s: after, row \"%s\"" % [name, after_said])
		_check("%s swapped: in one undo step (%d)" % [name, _builder.history_depth() - depth],
			pressed and _builder.history_depth() == depth + 1)
		_check("%s measured: the row says %d rare before and %d after, as counted here (%d)"
			% [name, _row_count(said), _row_count(after_said), left],
			_row_count(after_said) == left and after_said.begins_with("Swapped ")
			and left == prints_kept)
		_rows_out.append("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.1f" % [name,
			Inventory.of(_world, _library, _store.scenery).lot_count(), rare.size(), left,
			colour_swaps, part_swaps, prints_kept, none.size(),
			delta / maxf(colour_swaps, 1)])
		list.hide_list()
		var undone: String = await _undone()
		_check("%s: one undo, the save before to the byte (%s)" % [name, _diff(before, undone)],
			undone == before)
		_shell.run("redo")
		await _frames(6)
		var redone: String = _save()
		_check("%s: a redo, the swap's save to the byte (%s)" % [name, _diff(after, redone)],
			redone == after)


## The undo, then the save as it stands.
func _undone() -> String:
	_shell.run("undo")
	await _frames(6)
	return _save()


## replace_parts rare=true in 1 call gives the panel's file; preview changes
## nothing; lots= only those named.
func _case_mcp() -> void:
	var text: String = FileAccess.get_file_as_string("res://models/corner_shop.ldr")
	await _open(text)
	var list: InventoryPanel = await _list_up()
	await _swaps_up(list)
	await _swap_pressed(list)
	list.hide_list()
	var by_panel: String = _save()
	await _open(text)
	var before: String = _save()
	var preview: String = await _say("replace_parts", {"rare": true, "preview": true})
	print("  preview: %s" % preview.replace("\n", " / ").left(900))
	_check("mcp: preview lists the rare lots and changes nothing", _save() == before
		and preview.contains("Rare lots (") and preview.contains("Nothing changed (preview)")
		and preview.contains(" → "))
	var depth: int = _builder.history_depth()
	var said: String = await _say("replace_parts", {"rare": true})
	print("  rare=true: %s" % said.replace("\n", " / ").left(900))
	var by_call: String = _save()
	_check("mcp: replace_parts rare=true in 1 call gives the panel's file (%s)"
		% _diff(by_panel, by_call), by_call == by_panel and by_call != before)
	_check("mcp: ...as one undo step (%d), its answer the rare count before and after"
		% (_builder.history_depth() - depth), _builder.history_depth() == depth + 1
		and said.contains("as one undo step") and said.contains("Rare lots now: "))
	await _say("undo", {})
	_check("mcp: its undo, the save before to the byte", _save() == before)
	# One lot named: only it changes.
	var rare: Dictionary = _rare_here()
	var key: String = ""
	for each: String in rare:
		if not each.contains("p") or each.get_slice("/", 0).is_valid_int():
			key = each
			break
	var one: String = await _say("replace_parts", {"rare": true, "lots": [key]})
	var changed: Array = _minus(_save(), before)
	print("  lots=[%s]: %s" % [key, one.get_slice("\n", one.count("\n"))])
	var part: String = key.get_slice("/", 0)
	_check("mcp: lots=[%s] swaps only it (%d lines, each its part's: %s)" % [key, changed.size(),
		changed.slice(0, 3)], not changed.is_empty() and _count(part, int(key.get_slice("/", 1))) == 0
		and _rare_here().size() == rare.size() - 1)
	await _say("undo", {})
	var refused: String = await _say("replace_parts", {"rare": true, "find": {"part": "3001"}})
	_check("mcp: rare=true with find= is refused with the shape to give (%s)" % refused.left(80),
		refused.contains("takes no find=") and _save() == before)


## Someone else's file: saved as it came, swapped in its lines only, each
## sub-model once, undone and redone to the byte, saved and opened again.
func _case_kept() -> void:
	var text: String = _fixture(KEPT)
	await _open(text)
	var before: String = _save()
	_check("kept: someone else's file opened and saved, to the byte (%s)" % _diff(text, before),
		before == text)
	var rare: Dictionary = _rare_here()
	print("  rare: %s" % rare)
	var list: InventoryPanel = await _list_up()
	await _swaps_up(list)
	var picked := PackedStringArray()
	for lot: RareSwap.Lot in list.get("_rare"):
		print("    %s%s" % [(list.get("_swapper") as RareSwap).lot_words(lot),
			"" if lot.picked else "  (not picked)"])
		if lot.picked:
			picked.append(lot.key)
	var shown_before: int = _rare_here().size()
	var depth: int = _builder.history_depth()
	await _swap_pressed(list)
	list.hide_list()
	var after: String = _save()
	_check("kept: one undo step (%d)" % (_builder.history_depth() - depth),
		_builder.history_depth() == depth + 1)
	# The swapped lines and no others: each one a part line of a picked lot.
	var gone: Array = _minus(before, after)
	var came: Array = _minus(after, before)
	var others: Array = gone.filter(func(line: String) -> bool:
		var bits: PackedStringArray = line.split(" ", false)
		return bits.size() < 15 or not picked.has("%s/%s" % [bits[14].trim_suffix(".dat"), bits[1]]))
	print("  - %s" % "\n  - ".join(gone))
	print("  + %s" % "\n  + ".join(came))
	_check("kept: keep_text, every line but the swapped ones byte for byte (%d out, %d in, %d not a swapped lot's%s)"
		% [gone.size(), came.size(), others.size(), "" if others.is_empty() else ": " + str(others)],
		not gone.is_empty() and gone.size() == came.size() and others.is_empty()
		and after.contains("0 // the Sand Blue 1 x 3 above came in one set")
		and after.contains("1 0  360 -8 0 1 0 0 0 1 0 0 0 1 2431p70.dat")
		and after.contains("0 !HISTORY 2026-11-17 [abuilder] First version"))
	_check("kept: each sub-model written once (wing %d, tip %d)" % [_defined(after,
		"rareswap_wing.ldr"), _defined(after, "rareswap_tip.ldr")],
		_defined(after, "rareswap_wing.ldr") == 1 and _defined(after, "rareswap_tip.ldr") == 1)
	# A swap inside the wing changes both its copies, the mirrored one too.
	_check("kept: the wing's 87087 and 3665a and the tip's 3070a changed in both copies (%d, %d, %d left)"
		% [_count("87087", 379), _count("3665a", 0), _count("3070a", 14)],
		_count("87087", 379) == 0 and _count("3665a", 0) == 0 and _count("3070a", 14) == 0)
	_check("kept: the print kept, not picked (%d 2431p70)" % _count("2431p70", 0),
		_count("2431p70", 0) == 1)
	var shown: Array = _looks()
	var left: int = _rare_here().size()
	await _open(after)
	_check("kept: saved and opened again, every part as it was shown%s" % _unlike(shown, _looks()),
		shown == _looks())
	_check("kept: ...the same rare count (%d, was %d)" % [_rare_here().size(), shown_before],
		_rare_here().size() == left and left < shown_before)
	_check("kept: ...and it saves to itself (%s)" % _diff(after, _save()), _save() == after)
	await _open(text)
	list = await _list_up()
	await _swaps_up(list)
	await _swap_pressed(list)
	list.hide_list()
	var undone: String = await _undone()
	_check("kept: the undo, the file opened to the byte (%s)" % _diff(before, undone),
		undone == before)
	_shell.run("redo")
	await _frames(6)
	_check("kept: the redo, the swap's file to the byte (%s)" % _diff(after, _save()),
		_save() == after)


## A print is offered its plain part, not picked; picked, it swaps.
func _case_printed() -> void:
	await _open(_fixture(KEPT))
	var list: InventoryPanel = await _list_up()
	await _swaps_up(list)
	var print_lot: RareSwap.Lot = null
	var box: CheckBox = null
	for each: Control in list.call("_swap_boxes"):
		var lot: RareSwap.Lot = each.get_meta("lot")
		(each as CheckBox).button_pressed = lot.part == "2431p70"
		if lot.part == "2431p70":
			print_lot = lot
			box = each
	_check("printed: 2431p70 offered its plain part, 2431 in Black (%s)" % (
		(list.get("_swapper") as RareSwap).lot_words(print_lot) if print_lot != null else "none"),
		print_lot != null and print_lot.into_part == "2431" and print_lot.into_colour < 0)
	await _swap_pressed(list)
	list.hide_list()
	_check("printed: picked alone, it alone swaps (2431p70 %d, 2431 %d, 87087 %d)" % [
		_count("2431p70", 0), _count("2431", 0), _count("87087", 379)],
		_count("2431p70", 0) == 0 and _count("2431", 0) == 1 and _count("87087", 379) == 2)


## A locked part stays, and the status bar says why.
func _case_locked() -> void:
	await _open(_fixture(KEPT))
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3622":
			_builder.locked[brick.id] = true
	var said: Array = []
	var list: InventoryPanel = await _list_up()
	list.said.connect(func(line: String) -> void: said.append(line))
	await _swaps_up(list)
	await _swap_pressed(list)
	list.hide_list()
	print("  said: %s" % said)
	_check("locked: the locked 3622 stays Sand Blue, the rest swap (%d, 87087 %d)" % [
		_count("3622", 379), _count("87087", 379)], _count("3622", 379) == 1
		and _count("87087", 379) == 0)
	_check("locked: ...and the status bar says it was left out",
		not said.is_empty() and str(said[-1]).contains("locked"))
	_builder.locked.clear()


## Some picked and not others: those not picked stay rare, the row says so.
func _case_picks() -> void:
	await _open(_fixture(KEPT))
	var list: InventoryPanel = await _list_up()
	await _swaps_up(list)
	for each: Control in list.call("_swap_boxes"):
		var lot: RareSwap.Lot = each.get_meta("lot")
		if lot.part == "3622":
			await _press(each)
	var swap: Button = list.controls_by_name()["parts_swap"]
	print("  button: %s" % swap.text)
	_check("picks: one box pressed off, the button says one fewer (%s)" % swap.text,
		swap.text == "Swap 4 lots")
	await _swap_pressed(list)
	var row: String = list.controls_by_name()["parts_rare"].text
	print("  row: %s" % row)
	list.hide_list()
	_check("picks: the one not picked stays (3622 %d), the row says 2 still rare" % _count("3622", 379),
		_count("3622", 379) == 1 and _row_count(row) == 2)


## The row, the swaps and the button in German, French and Spanish.
func _case_words() -> void:
	await _open(_fixture(KEPT))
	var list: InventoryPanel = await _list_up()
	var texts: Array = [list.controls_by_name()["parts_rare"].text,
		list.controls_by_name()["parts_rare"].tooltip_text,
		"1 lot comes in 3 sets or fewer, so few sellers have it: swap for common parts…",
		"1 lot comes in 3 sets or fewer, so few sellers have it",
		"4 lots come in 3 sets or fewer, so few sellers have them",
		"Each comes in its colour in 3 sets or fewer, by Rebrickable's set inventories",
		"Counting the sets each part comes in…", "Swap 1 lot", "Swap",
		"Swapped 3 rare lots for common ones, 9 parts. No lot is rare now",
		"Swapped 1 rare lot for common ones, 1 part. Still rare: 1 lot comes in 3 sets or fewer, so few sellers have it: swap for common parts…",
		"nothing swapped"]
	await _swaps_up(list)
	texts.append(list.get("_heading").text)
	for node: Node in [list.get("_swap_note"), list.get("_swap_now"), list.get("_swap_back")]:
		texts.append(node.get("text"))
		if not str(node.get("tooltip_text")).is_empty():
			texts.append(node.get("tooltip_text"))
	for row: Node in (list.get("_swaps") as Node).get_children():
		for child: Node in row.get_children():
			if child is Label and not (child as Label).text.is_empty():
				texts.append((child as Label).text)
			if child is CheckBox:
				texts.append((child as CheckBox).tooltip_text)
	for lot: RareSwap.Lot in list.get("_rare"):
		texts.append("rare: " + RareSwap.sets_words(lot.sets))
	list.hide_list()
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var missing: Array = []
		var drawn: Array = []
		for english: String in texts:
			if english.strip_edges() == "→":
				continue
			var kept: Array = Language.left_in_english(english).filter(func(w: Variant) -> bool:
				# A part's number ("3665a", "2431p70") is no word to translate.
				if _part_number.search(str(w).strip_edges()) != null:
					return false
				var rest: String = str(w)
				for mark: String in "0123456789½¼¾−-.,:×→()ΔE ":
					rest = rest.replace(mark, "")
				return not rest.is_empty())
			if Language.says(english).is_empty() or not kept.is_empty():
				missing.append("\"%s\"%s" % [english, " (kept " + str(kept) + ")"
					if not kept.is_empty() else ""])
			drawn.append(TranslationServer.translate(english))
		print("  %s: %s" % [code, " | ".join(drawn.slice(0, 4))])
		_check("words %s: each of the %d reads in the language%s" % [code, texts.size(),
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty())
	Language.apply("en")
