## A model rebuilt from the parts its builder owns (ownswap, APP_UX10 #2): the
## parts list's row for the lots they own too few of, each with its swap from
## their own parts or "none you own", Use what I own in one undo, and
## replace_parts mine=true.
##
##   godot --headless --path . --script src/dev/ownswap_probe.gd
##
## A collection of 3 sets (SETS) and 40 loose lots (LOOSE), kept on this
## device (CollectionStore.where, nobody signed in), its sets' parts read from
## their inventories as the app reads them. Then, on 10 gallery models (TEN):
## - listed: every lot submit_design mine=true counts short (OwnCounts.over,
##   worked out here apart from OwnSwap) is on the list, and no other, with
##   a swap or "none you own", its shortfall the same;
## - no swap over ΔE 10 or across a finish (transparency, chrome, pearl and
##   metallic, milky, fluorescent, rubber, conductive: measured here with
##   CIEDE2000 and the colours' own finish and alpha, [method crossed]), and
##   a part swap is the same shape in the same colour (RareSwap.fits);
## - no owned part used twice: what the swaps take of each part and colour is
##   no more than was free of it (Collection.allocate, here), and the pieces
##   owned after are exactly those before and what the swaps covered;
## - Use what I own pressed as a person presses it: one undo step, undone to
##   the byte and redone to the swap's file; the owned share before and after
##   as mine=true counts it, and the row says what is still missing;
## - the time from the row's press to the list filled, and the longest frame
##   of it, written to OWNSWAP_OUT (bench/results/ownswap-2026-11-19).
## And: a lot whose pieces are partly owned changes only those short; two
## lots wanting the last pieces of one part never both get them; a part in
## a sub-model's copies changes with every copy or not at all; a part in hand
## goes back where it was first and is not lost; replace_parts mine=true in
## 1 call gives the panel's file, preview changes nothing, lots= only those
## named, mine=false a plain replace, mine with rare or find refused with
## nothing changed; Orthanc's and 10179's swaps timed.
##
##   OWNSWAP_CASES=gallery,mcp   those cases
##   OWNSWAP_OUT=DIR             where gallery.tsv goes
extends "res://src/dev/copyfaults_probe.gd"

const OWN_CASES: Array = ["gallery", "partial", "contest", "copies", "held", "mcp", "words", "time"]
const SETS: Array = ["10698-1", "31120-1", "6086-1"]
## The loose lots: part, LDraw colour, how many. Old greys and Brown for a
## model's Light and Dark Bluish Grey and Reddish Brown; plain parts for
## prints; see-through, chrome, pearl and metallic that must never stand in
## for a solid; far colours that must never be offered.
const LOOSE: Array = [
	["3001", 7, 6], ["3004", 7, 10], ["3023", 7, 8], ["3020", 8, 4], ["3010", 8, 6],
	["3005", 6, 8], ["3062b", 6, 4], ["3069b", 6, 4], ["3068b", 15, 4], ["3069b", 15, 6],
	["3070b", 14, 4], ["3626c", 14, 4], ["3665b", 7, 3], ["3001", 1, 10], ["3001", 2, 10],
	["3001", 4, 6], ["3003", 15, 8], ["3022", 71, 6], ["3021", 72, 4], ["3710", 0, 8],
	["3666", 70, 6], ["3460", 71, 4], ["2412b", 0, 4], ["4073", 71, 10], ["4073", 47, 4],
	["3024", 15, 10], ["3024", 71, 10], ["98138", 0, 4], ["3040b", 72, 6], ["3039", 71, 4],
	["4073", 297, 6], ["4073", 80, 4], ["4073", 383, 4], ["3065", 47, 4], ["3794b", 7, 4],
	["3009", 7, 2], ["2431", 0, 4], ["3062b", 7, 6], ["3700", 8, 4], ["6141", 7, 8],
]
## The ten gallery models (rareswap's ten).
const TEN: Array = ["models/orthanc.ldr", "models/corner_shop.ldr",
	"tools/web/gallery_seeds/oak_treehouse.ldr", "tools/web/gallery_seeds/red_fox.ldr",
	"tools/web/gallery_seeds/sleeping_dragon.ldr", "tools/web/gallery_seeds/lakeside_campsite.ldr",
	"models/barn_owl.ldr", "tools/web/gallery_seeds/vintage_tractor.ldr",
	"tools/web/gallery_seeds/maintenance_robot.ldr", "tools/web/gallery_seeds/village_bakery.ldr"]
const TIMED: Array = ["res://models/orthanc.ldr", "res://vendor/omr/files/10179-1.mpd"]

var _rows_out := PackedStringArray()
var _part_number: RegEx = RegEx.create_from_string("^[a-z]?\\d+[a-z0-9]*$")
var _owner: CollectionStore
## What the model being timed costs live in one frame (_live_cost).
var _live_ms: float = 0.0


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(3000.0).timeout.connect(func() -> void:
		print("ownswap probe: not finished in time")
		quit(1))
	CollectionStore.where = OS.get_temp_dir().path_join("brickworks_ownswap_%d.json" % OS.get_process_id())
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
	_owner = _shell.collection_store
	var mine := Collection.new()
	for number: String in SETS:
		mine.sets.append({"set": number, "qty": 1, "spares": false, "src": "hand"})
	for lot: Array in LOOSE:
		mine.parts.append({"part": lot[0], "colour": lot[1], "qty": lot[2], "src": "hand"})
	_owner.collection = mine
	await _owner.refresh_pool()
	var pieces: int = _owner.pieces_on_hand()
	_check("the collection: %d sets (%s), %d loose lots, %d pieces in %d part colours" % [SETS.size(),
		", ".join(_owner.records.keys()), LOOSE.size(), pieces, _owner.on_hand.size()],
		_owner.records.size() == SETS.size() and pieces > 2000)
	var cases: Array = OWN_CASES if OS.get_environment("OWNSWAP_CASES").is_empty() \
		else Array(OS.get_environment("OWNSWAP_CASES").split(",", false))
	for name: String in cases:
		print("\n== %s" % name)
		match name:
			"gallery": await _case_gallery()
			"partial": await _case_partial()
			"contest": await _case_contest()
			"copies": await _case_copies()
			"held": await _case_held()
			"mcp": await _case_mcp()
			"words": await _case_words()
			"time": await _case_time()
			_: _check("no such case %s" % name, false)
	var out: String = OS.get_environment("OWNSWAP_OUT")
	if not out.is_empty() and not _rows_out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		var file := FileAccess.open(out.path_join("gallery.tsv"), FileAccess.WRITE)
		file.store_string("model\tlots\tpieces\tshort_lots\tshort_pieces\tcolour_swaps\tpart_swaps\t"
			+ "prints_kept\tnone_you_own\tover_de_or_finish\tshare_before\tshare_after\t"
			+ "missing_after\tlist_ms\tlongest_frame_ms\n" + "\n".join(_rows_out) + "\n")
		file.close()
		print("  written %s" % out.path_join("gallery.tsv"))
	DirAccess.remove_absolute(CollectionStore.where)
	print("\nownswap probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	_world.clear()
	await _frames(4)
	quit(1 if _failures > 0 else 0)


# -- the probe's own count ------------------------------------------------------------


## What submit_design mine=true counts of the model shown, worked out here:
## {"pieces", "owned", "short": key -> pieces short, "free": key -> pieces
## owned and not used}.
func _counted() -> Dictionary:
	var used: Dictionary = SetBin.used_in(_world, _store.scenery, _library)
	var pieces: int = 0
	var needs: Dictionary = {}
	for key: String in used:
		if Collection.ownable(Collection.part_of(key), _library):
			needs[key] = int(used[key])
			pieces += int(used[key])
	var short: Dictionary = {}
	var short_pieces: int = 0
	for row: Dictionary in OwnCounts.over(_owner.on_hand, used, _library):
		short[str(row["key"])] = int(row["short"])
		short_pieces += int(row["short"])
	var free: Dictionary = {}
	var spare: Dictionary = Collection.allocate(needs, _owner.on_hand)["spare"]
	for key: String in spare:
		if int(spare[key]) > 0:
			free[key] = int(spare[key])
	return {"pieces": pieces, "owned": pieces - short_pieces, "short": short, "free": free}


static func _share(counted: Dictionary) -> String:
	return "%.1f%%" % (100.0 * float(counted["owned"]) / maxf(float(counted["pieces"]), 1.0))


## What is wrong with [param lot]'s swap, read here: "" when it keeps the
## look (a colour within ΔE 10 of the same transparency, finish and rubber,
## or an equal part in its own colour).
func _swap_wrong(lot: OwnSwap.Lot) -> String:
	if not lot.offered():
		return ""
	if not lot.into_part.is_empty():
		if lot.into_colour >= 0:
			return "a part swap that changes the colour too"
		var more: int = RareSwap.fits(_library.mesh_for(lot.part), _library.mesh_for(lot.into_part))
		return "" if more >= 0 else "%s does not sit as %s does" % [lot.into_part, lot.part]
	var was: PartLibrary.BrickColor = _library.color(lot.colour)
	var now: PartLibrary.BrickColor = _library.color(lot.into_colour)
	if was == null or now == null:
		return "a colour not known"
	var delta: float = HiddenColours.de2000(HiddenColours.lab(was.rgb), HiddenColours.lab(now.rgb))
	if delta > 10.0:
		return "ΔE %.1f" % delta
	return crossed(was, now)


## What a swap from [param was] to [param now] crosses, worked out here from
## the colours themselves: "" for nothing (osreview H1: a family that put
## milky with solid, metallic with pearl, let a Milky White part go
## Trans-Clear and Metallic Dark Grey go Conductive Black).
static func crossed(was: PartLibrary.BrickColor, now: PartLibrary.BrickColor) -> String:
	if not now.is_plastic() or now.name.contains("Conductive") or now.group == "fluorescent paint":
		return "into %s, no plastic a part is bought in" % now.name
	if was.is_transparent() != now.is_transparent():
		return "across see-through"
	if was.is_transparent() and (was.alpha < 200) != (now.alpha < 200):
		return "across clear and clouded (alpha %d to %d)" % [was.alpha, now.alpha]
	if was.drawn_as != now.drawn_as:
		return "across a finish (%s to %s)" % [was.finish_name(), now.finish_name()]
	if (was.group == "rubber") != (now.group == "rubber"):
		return "across rubber"
	return ""


# -- the parts list ------------------------------------------------------------------


func _list() -> InventoryPanel:
	return _main.get("_inventory")


func _list_up() -> InventoryPanel:
	var list: InventoryPanel = _main.get("_inventory_made")
	if list != null and list.is_showing():
		list.hide_list()
	_shell.run("parts_list")
	await _frames(6)
	return _list()


func _press(control: Control) -> bool:
	var button: BaseButton = control as BaseButton
	var inside: bool = root.get_visible_rect().encloses(control.get_global_rect())
	if button == null or not button.is_visible_in_tree() or button.disabled or not inside:
		print("  could not press %s (shown %s, off %s, inside %s)" % [control.name,
			control.is_visible_in_tree(), button != null and button.disabled, inside])
		return false
	if button.toggle_mode:
		button.button_pressed = not button.button_pressed
	else:
		button.pressed.emit()
	await _frames(4)
	return true


## The own row pressed, and the list once it is filled (60 s at most): the
## time it took and the longest frame between, in ms; [] when it did not.
func _own_up(list: InventoryPanel) -> Array:
	var row: Control = list.controls_by_name().get("parts_own")
	if row == null:
		return []
	var started: int = Time.get_ticks_usec()
	var last: int = started
	var longest: int = 0
	if not await _press(row):
		return []
	var until: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		if list.controls_by_name().has("parts_use_own") and not bool(list.get("_swapping")):
			return [(Time.get_ticks_usec() - started) / 1000.0, longest / 1000.0]
		await process_frame
		var now: int = Time.get_ticks_usec()
		longest = maxi(longest, now - last)
		last = now
	return []


## Use what I own pressed, and the list once it is taken again (60 s at most).
func _use_pressed(list: InventoryPanel) -> bool:
	var button: Button = list.controls_by_name().get("parts_use_own")
	if button == null or button.disabled:
		return false
	var depth: int = _builder.history_depth()
	if not await _press(button):
		return false
	var until: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < until:
		if not bool(list.get("_swapping")) and not list.controls_by_name().has("parts_use_own"):
			await _frames(4)
			return true
		await process_frame
	print("  Use what I own: not taken in 60 s (swapping %s, button %s, %d steps over)" % [
		list.get("_swapping"), list.controls_by_name().has("parts_use_own"), _builder.history_depth() - depth])
	return false


func _undone() -> String:
	_shell.run("undo")
	await _frames(6)
	return _save()


## [param text] opened, the parts list up and its own row pressed, the list
## filled: the list, or null.
func _opened_and_listed(text: String) -> InventoryPanel:
	await _open(text)
	var list: InventoryPanel = await _list_up()
	if (await _own_up(list)).is_empty():
		return null
	return list


# -- the cases -----------------------------------------------------------------------


func _case_gallery() -> void:
	for file: String in TEN:
		await _one_model("res://" + file)


## One model: listed, swapped, counted, undone and redone.
func _one_model(path: String) -> void:
	var name: String = path.get_file().get_basename()
	await _open(FileAccess.get_file_as_string(path))
	var before: String = _save()
	var counted: Dictionary = _counted()
	var lots: int = Inventory.of(_world, _library, _store.scenery).lot_count()
	var list: InventoryPanel = await _list_up()
	var row: Control = list.controls_by_name().get("parts_own")
	print("  %s: row \"%s\"" % [name, (row as Button).text if row != null else "(none)"])
	if counted["short"].is_empty():
		_check("%s: every piece owned, so no row" % name, row == null)
		return
	var timed: Array = await _own_up(list)
	if not _check("%s: the row opens the swaps" % name, not timed.is_empty()):
		return
	var own: Array = list.get("_own")
	# Listed: the lots short here, by Collection's spelling, and no other.
	var listed: Dictionary = {}
	for lot: OwnSwap.Lot in own:
		var key: String = Collection.key_of(lot.part, lot.colour, _library)
		listed[key] = int(listed.get(key, 0)) + lot.short()
	var unlike: Array = []
	for key: String in counted["short"]:
		if int(listed.get(key, 0)) != int(counted["short"][key]):
			unlike.append("%s short %d, listed %d" % [key, int(counted["short"][key]), int(listed.get(key, 0))])
	for key: String in listed:
		if not (counted["short"] as Dictionary).has(key):
			unlike.append("%s listed, not short" % key)
	_check("%s listed: the %d lots mine=true counts short, each with its shortfall (%d listed)%s" % [name,
		(counted["short"] as Dictionary).size(), own.size(), "" if unlike.is_empty()
		else ": " + "; ".join(unlike.slice(0, 6))], unlike.is_empty())
	# Each with a swap or "none you own", none of them changing the look.
	var swapper: OwnSwap = list.get("_own_swapper")
	var colours: int = 0
	var parts: int = 0
	var prints: int = 0
	var none: int = 0
	var wrong: Array = []
	var took: Dictionary = {}
	var covered: int = 0
	for lot: OwnSwap.Lot in own:
		print("    %s%s" % [swapper.lot_words(lot), "" if lot.picked else "  (not picked)"])
		if not lot.offered():
			none += 1
			if not swapper.into_words(lot).begins_with("none you own"):
				wrong.append("%s: no swap, not said so" % lot.key)
			continue
		var why: String = _swap_wrong(lot)
		if not why.is_empty():
			wrong.append("%s: %s" % [lot.key, why])
		var into: String = Collection.key_of(lot.into_part if not lot.into_part.is_empty() else lot.part,
			lot.into_colour if lot.into_colour >= 0 else lot.colour, _library)
		took[into] = int(took.get(into, 0)) + lot.takes
		if not lot.into_part.is_empty():
			parts += 1
			if lot.drops_print():
				prints += 1
				if lot.picked:
					wrong.append("%s: a print picked to lose its print" % lot.key)
		else:
			colours += 1
		if lot.picked != (lot.offered() and not lot.drops_print()):
			wrong.append("%s: picked %s" % [lot.key, lot.picked])
		if lot.picked:
			covered += mini(lot.takes, lot.short())
	_check("%s: each has a swap or \"none you own\", none over ΔE 10 or across a finish (%d colours, %d parts, %d prints kept, %d none)%s"
		% [name, colours, parts, prints, none, "" if wrong.is_empty() else ": " + "; ".join(wrong.slice(0, 6))],
		wrong.is_empty() and colours + parts + none == own.size())
	# No owned part used twice: what each swap takes of a part and colour is
	# no more than was free of it, counted here (a colour swap into a mould's
	# sibling counts against the sibling's family).
	var over: Array = []
	for key: String in took:
		var free: int = 0
		var family: String = "%s/%d" % [Collection.family_of(Collection.part_of(key)), Collection.colour_of(key)]
		for each: String in counted["free"]:
			if each == key or "%s/%d" % [Collection.family_of(Collection.part_of(each)),
					Collection.colour_of(each)] == family:
				free += int(counted["free"][each])
		if int(took[key]) > free:
			over.append("%s: %d taken of %d free" % [key, int(took[key]), free])
	_check("%s: no owned part used twice: %d part colours taken from, none past what was free%s" % [name,
		took.size(), "" if over.is_empty() else ": " + "; ".join(over)], over.is_empty())
	var depth: int = _builder.history_depth()
	var picked: int = own.filter(func(lot: OwnSwap.Lot) -> bool: return lot.picked).size()
	var share_before: String = _share(counted)
	if picked == 0:
		var use: Button = list.controls_by_name().get("parts_use_own")
		_check("%s: nothing of theirs stands in, so Use what I own is off" % name, use != null and use.disabled)
		_rows_out.append("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%d\t%.0f\t%.1f" % [name, lots,
			int(counted["pieces"]), own.size(), int(counted["pieces"]) - int(counted["owned"]), colours,
			parts, prints, none, wrong.size(), share_before, share_before,
			int(counted["pieces"]) - int(counted["owned"]), float(timed[0]), float(timed[1])])
		list.hide_list()
		return
	var pressed: bool = await _use_pressed(list)
	var after: String = _save()
	var then: Dictionary = _counted()
	var said: String = list.controls_by_name()["parts_own"].text if list.controls_by_name().has("parts_own") else ""
	print("  %s: after, row \"%s\"" % [name, said])
	_check("%s: Use what I own, %d lots in one undo step (%d)" % [name, picked,
		_builder.history_depth() - depth], pressed and _builder.history_depth() == depth + 1)
	_check("%s: owned %s before, %s after: %d pieces more, as the swaps covered (%d)" % [name, share_before,
		_share(then), int(then["owned"]) - int(counted["owned"]), covered],
		int(then["owned"]) == int(counted["owned"]) + covered and then["pieces"] == counted["pieces"])
	var missing: int = int(then["pieces"]) - int(then["owned"])
	_check("%s: the row says what is still missing: %s" % [name, said], said.begins_with("Swapped ")
		and (said.contains(Counted.of(missing, "piece")) if missing > 0 else said.contains("Every piece is yours")))
	_rows_out.append("%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%s\t%d\t%.0f\t%.1f" % [name, lots,
		int(counted["pieces"]), own.size(), int(counted["pieces"]) - int(counted["owned"]), colours, parts,
		prints, none, wrong.size(), share_before, _share(then), missing, float(timed[0]), float(timed[1])])
	list.hide_list()
	var undone: String = await _undone()
	_check("%s: one undo, the file before to the byte (%s)" % [name, _diff(before, undone)], undone == before)
	_shell.run("redo")
	await _frames(6)
	var redone: String = _save()
	_check("%s: a redo, the swap's file to the byte (%s)" % [name, _diff(after, redone)], redone == after)


## A brick of [param part] in [param colour] stacked [param n] high from
## [param y], at [param x].
static func _stack(part: String, colour: int, n: int, x: int = 0, y: int = 0) -> String:
	var lines := PackedStringArray()
	for k: int in n:
		lines.append("1 %d %d %d 0 1 0 0 0 1 0 0 0 1 %s.dat" % [colour, x, y - 24 * k, part])
	return "\n".join(lines)


func _count(part: String, colour: int) -> int:
	var count: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == part and brick.color_code == colour:
			count += 1
	return count


## Of 3009 in Light Bluish Grey, some owned: only the pieces short change.
func _case_partial() -> void:
	var owned: int = int(_owner.on_hand.get("3009/71", 0))
	var free: int = int(_owner.on_hand.get("3009/7", 0))
	var many: int = owned + free + 2
	var text: String = "0 Partial\n0 Name: partial.ldr\n%s\n" % _stack("3009", 71, many)
	var list: InventoryPanel = await _opened_and_listed(text)
	if not _check("partial: %d of 3009 in Light Bluish Grey, %d owned, %d Light Grey free: listed" % [many,
			owned, free], list != null):
		return
	var lot: OwnSwap.Lot = null
	for each: OwnSwap.Lot in list.get("_own"):
		if each.part == "3009":
			lot = each
	_check("partial: its swap, the %d Light Grey free for %d short (%s)" % [free, many - owned,
		(list.get("_own_swapper") as OwnSwap).lot_words(lot) if lot != null else "none"],
		lot != null and lot.into_colour == 7 and lot.takes == free and lot.missing_after() == 2)
	_check("partial: Use what I own", await _use_pressed(list))
	_check("partial: %d stay Light Bluish Grey, %d go Light Grey (%d, %d)" % [owned + 2, free,
		_count("3009", 71), _count("3009", 7)], _count("3009", 71) == owned + 2 and _count("3009", 7) == free)
	list.hide_list()


## Two lots wanting the last of one: 3665a and 3665b in Light Bluish Grey,
## and the 3665b in Light Grey free shared, never twice.
func _case_contest() -> void:
	var free: int = await _counted_free("3665b/7")
	var each: int = free
	var text: String = "0 Contest\n0 Name: contest.ldr\n%s\n%s\n" % [_stack("3665a", 71, each, 0),
		_stack("3665b", 71, each, 80)]
	var list: InventoryPanel = await _opened_and_listed(text)
	if not _check("contest: %d each of 3665a and 3665b in Light Bluish Grey, %d of 3665b in Light Grey free"
			% [each, free], list != null and free > 0):
		return
	var takes: int = 0
	for lot: OwnSwap.Lot in list.get("_own"):
		print("    %s" % (list.get("_own_swapper") as OwnSwap).lot_words(lot))
		takes += lot.takes
	_check("contest: the two take %d of the %d between them, never more" % [takes, free], takes == free)
	var before: Dictionary = _counted()
	_check("contest: Use what I own", await _use_pressed(list))
	var then: Dictionary = _counted()
	_check("contest: owned %d after, %d before: the %d free used once (%s short of 3665b/7 after)" % [
		int(then["owned"]), int(before["owned"]), free, int(then["short"].get("3665b/7", 0))],
		int(then["owned"]) == int(before["owned"]) + free)
	list.hide_list()


## What is free of [param key] with nothing open.
func _counted_free(key: String) -> int:
	_main.call("clear_model")
	await _frames(4)
	return int(_counted()["free"].get(key, 0))


## A sub-model with a 3009 in Light Bluish Grey placed as many times as
## there are Light Grey ones free, and one more on its own: the one on its
## own swaps; the copies, one more than is free, all stay.
func _case_copies() -> void:
	var free: int = int(_owner.on_hand.get("3009/7", 0)) - 0
	var owned: int = int(_owner.on_hand.get("3009/71", 0))
	if owned > 0:
		_check("copies: no 3009 in Light Bluish Grey owned (%d)" % owned, false)
		return
	var placed := PackedStringArray()
	for k: int in free:
		placed.append("1 16 %d 0 200 1 0 0 0 1 0 0 0 1 copied.ldr" % (k * 160))
	var text: String = ("0 FILE copies.ldr\n0 Copies\n0 Name: copies.ldr\n%s\n%s\n0 NOFILE\n"
		+ "0 FILE copied.ldr\n0 Copied\n0 Name: copied.ldr\n%s\n0 NOFILE\n") % [
		_stack("3009", 71, 1, 0, 0), "\n".join(placed), _stack("3009", 71, 1, 0, 0)]
	var list: InventoryPanel = await _opened_and_listed(text)
	if not _check("copies: one on its own and %d copies, %d free" % [free, free], list != null):
		return
	var lot: OwnSwap.Lot = null
	for each: OwnSwap.Lot in list.get("_own"):
		if each.part == "3009":
			lot = each
	_check("copies: it takes the one on its own, the copies a group too big (%s)" % (
		(list.get("_own_swapper") as OwnSwap).lot_words(lot) if lot != null else "none"),
		lot != null and lot.takes == 1)
	_check("copies: Use what I own", await _use_pressed(list))
	_check("copies: the one on its own Light Grey, every copy still alike (%d Light Grey, %d Light Bluish Grey)"
		% [_count("3009", 7), _count("3009", 71)], _count("3009", 7) == 1 and _count("3009", 71) == free)
	list.hide_list()


## A part in hand when Use what I own is pressed: put back first, not lost,
## and the swap one step over where it was.
func _case_held() -> void:
	var text: String = "0 Held\n0 Name: held.ldr\n%s\n%s\n" % [_stack("3009", 71, 2, 0),
		_stack("3001", 4, 1, 200)]
	await _open(text)
	var parts: int = _world.bricks().size()
	var depth0: int = _builder.history_depth()
	var list: InventoryPanel = await _list_up()
	if not _check("held: the row opens the swaps", not (await _own_up(list)).is_empty()):
		return
	var held: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001":
			held = brick
	_builder.clear_selection()
	_builder.selection[held.id] = true
	_builder.selection_changed.emit(1)
	var lifted: int = _builder.lift_selection()
	await _frames(4)
	print("    lifted %d, carrying %s, the swaps still shown %s" % [lifted, _builder.is_carrying(),
		list.controls_by_name().has("parts_use_own")])
	_check("held: Use what I own with a part in hand", await _use_pressed(list))
	list.hide_list()
	_check("held: put back first, nothing in hand, none lost, one step over the start (parts %d, were %d; %d steps; Red 3001 %d)"
		% [_world.bricks().size(), parts, _builder.history_depth() - depth0, _count("3001", 4)],
		not _builder.is_carrying() and _world.bricks().size() == parts and _count("3001", 4) == 1
		and _builder.history_depth() == depth0 + 1 and _count("3009", 7) == 2)


## replace_parts mine=true in 1 call gives the panel's file; preview, lots=,
## false and refusals change nothing they should not.
func _case_mcp() -> void:
	var text: String = FileAccess.get_file_as_string("res://" + str(TEN[1]))
	var list: InventoryPanel = await _opened_and_listed(text)
	if not _check("mcp: the row opens the swaps", list != null):
		return
	var opened: String = ""
	_check("mcp: Use what I own pressed", await _use_pressed(list))
	list.hide_list()
	var by_panel: String = _save()
	await _open(text)
	var before: String = _save()
	opened = before
	var preview: String = await _say("replace_parts", {"mine": true, "preview": true})
	print("  preview: %s" % preview.replace("\n", " / ").left(900))
	_check("mcp: preview lists and changes nothing", _save() == before and preview.contains("Nothing changed (preview)")
		and preview.contains(" → ") and preview.contains("% of its "))
	var depth: int = _builder.history_depth()
	var said: String = await _say("replace_parts", {"mine": true})
	print("  mine=true: %s" % said.replace("\n", " / ").left(1400))
	var by_call: String = _save()
	_check("mcp: replace_parts mine=true in 1 call gives the panel's file (%s)" % _diff(by_panel, by_call),
		by_call == by_panel and by_call != before)
	_check("mcp: ...as one undo step (%d), the share before and after and what is still missing said"
		% (_builder.history_depth() - depth), _builder.history_depth() == depth + 1
		and said.contains("as one undo step") and said.contains("(was ")
		and (said.contains("Still missing: ") or said.contains("Every piece is now theirs")))
	await _say("undo", {})
	_check("mcp: its undo, the file before to the byte", _save() == before)
	var refused: String = await _say("replace_parts", {"mine": true, "rare": true})
	_check("mcp: mine with rare refused, nothing changed (%s)" % refused.left(60),
		refused.contains("Give one") and _save() == before)
	refused = await _say("replace_parts", {"mine": true, "find": {"part": "3001"}})
	_check("mcp: mine with find= refused, nothing changed (%s)" % refused.left(60),
		refused.contains("takes no find=") and _save() == before)
	var plain: String = await _say("replace_parts", {"mine": false, "find": {"part": "3001"},
		"replace": {"color": 1}, "preview": true})
	_check("mcp: mine=false is a plain replace (%s)" % plain.get_slice("\n", 0).left(80),
		not plain.contains("mine=true") and _save() == before)
	# One lot named: only it changes.
	var key: String = ""
	var preview_lines: PackedStringArray = preview.split("\n")
	for line: String in preview_lines:
		if line.begins_with("- ") and not line.contains("none you own") and line.contains(" ["):
			key = line.get_slice(" [", line.get_slice_count(" [") - 1).get_slice("]", 0)
			break
	if _check("mcp: a lot with a swap named in the preview (%s)" % key, not key.is_empty()):
		var shorts: Dictionary = _counted()["short"]
		var one: String = await _say("replace_parts", {"mine": true, "lots": [key]})
		var named: String = Collection.key_of(key.get_slice("/", 0), int(key.get_slice("/", 1)), _library)
		var now: Dictionary = _counted()["short"]
		var moved: Array = []
		for each: String in shorts:
			if each != named and int(now.get(each, 0)) != int(shorts[each]):
				moved.append(each)
		print("  lots=[%s]: %s" % [key, one.get_slice("\n", one.count("\n") - 1).left(200)])
		_check("mcp: lots=[%s] swaps only it (%s short %d, was %d; others changed: %s)" % [key, named,
			int(now.get(named, 0)), int(shorts.get(named, 0)), moved], _save() != before and moved.is_empty()
			and int(now.get(named, 0)) < int(shorts.get(named, 0)))
		await _say("undo", {})
	_check("mcp: at the end the file is as opened", _save() == opened)


## Orthanc's and 10179's swaps, listed and then put in: no frame of either
## with more than 16 ms of the app's own work (self_attack "Time"; osreview
## H3: 2.1 s and 6.4 s frames), and the status bar saying so while it runs,
## each frame's own work measured as ProbeTime.Frames measures it. The totals
## are said. On 501e38ab9 this fails: one frame of Use what I own was 2,108
## ms on Orthanc, and nothing was on the bar.
##
## The bar each act must meet is what the same model already costs live, timed
## here in the same run: one frame of Find and Replace's copies
## (FindReplace._frames_for) or of the parts list opening as P opens it,
## the longer, and half again (the lead, 11-19). On 10179 those are 961 and 366
## ms, so Use what I own's 464 ms frames are no worse than what is live. The
## 16 ms target is still said, as KNOWN, until all three are paced.
func _case_time() -> void:
	for path: String in TIMED:
		var name: String = path.get_file()
		await _open(FileAccess.get_file_as_string(path))
		_live_ms = await _live_cost(name)
		var list: InventoryPanel = await _list_up()
		var row: Control = list.controls_by_name().get("parts_own")
		if not _check("time %s: the row" % name, row != null):
			continue
		var listed: Array = await _timed_act(func() -> void: (row as Button).pressed.emit(),
			func() -> bool: return list.controls_by_name().has("parts_use_own") and not bool(list.get("_swapping")))
		_time_said(name, "the swaps listed", listed, (list.get("_own") as Array).size())
		var depth: int = _builder.history_depth()
		var button: Button = list.controls_by_name().get("parts_use_own")
		if not _check("time %s: Use what I own to press" % name, button != null and not button.disabled):
			list.hide_list()
			continue
		var swapped: Array = await _timed_act(func() -> void: button.pressed.emit(),
			func() -> bool: return not bool(list.get("_swapping")) and not list.controls_by_name().has("parts_use_own"))
		_time_said(name, "Use what I own", swapped, _builder.history_depth() - depth)
		list.hide_list()
		if _builder.history_depth() > depth:
			await _undone()


## [param act] done, then frames until [param done] holds (120 s at most):
## [the time on the clock in ms, frames, the longest frame's own work in ms
## with its wait aside, how many frames had more than 16 ms of their own,
## whether the status bar said the work in a frame of it, the slack, done].
func _timed_act(act: Callable, done: Callable) -> Array:
	var frames := ProbeTime.Frames.new()
	frames.label = func() -> String:
		var job: Working.Job = Working.current()
		return job.words if job != null else ""
	root.add_child(frames)
	var started: int = Time.get_ticks_usec()
	act.call()
	var until: int = Time.get_ticks_msec() + 120000
	var finished: bool = false
	while Time.get_ticks_msec() < until:
		await process_frame
		if done.call():
			finished = true
			break
	await process_frame
	var clock: float = (Time.get_ticks_usec() - started) / 1000.0
	var longest: float = 0.0
	var over: int = 0
	var bar: bool = false
	for frame: Array in frames.work:
		var own: float = float(frame[1]) - float(frame[2])
		longest = maxf(longest, own)
		if own > 16.0 * frames.slack():
			over += 1
		bar = bar or not str(frame[3]).is_empty()
	var slack: float = frames.slack()
	var count: int = frames.work.size()
	frames.queue_free()
	return [clock, count, longest, over, bar, slack, finished]


func _time_said(name: String, what: String, timed: Array, count: int) -> void:
	print("  %s: %s (%d), %.0f ms over %d frames, the longest frame %.1f ms of its own, %d over %.0f ms, the bar %s"
		% [name, what, count, float(timed[0]), int(timed[1]), float(timed[2]), int(timed[3]),
		16.0 * float(timed[5]), "said it" if bool(timed[4]) else "said nothing"])
	var bar: float = maxf(16.0 * float(timed[5]), 1.5 * _live_ms)
	_check("time %s: %s done, no frame over %.0f ms of its own, half again what live's own costs here (the longest %.1f ms, in %.0f ms), the bar saying so"
		% [name, what, bar, float(timed[2]), float(timed[0])],
		bool(timed[6]) and float(timed[2]) <= bar and bool(timed[4]))
	print("  KNOWN %s: %s, the target of no frame over %.0f ms of its own: %s (%d over)" % [name, what,
		16.0 * float(timed[5]), "met" if int(timed[3]) == 0 else "not yet", int(timed[3])])


## What [param name] costs live in its longest single frame, timed now: Find
## and Replace's frames of its copies, or the parts list opened as P opens it.
func _live_cost(name: String) -> float:
	await _frames(4)
	var finder := FindReplace.new(_main)
	var copies: Dictionary = finder._copies_by_definition()
	var t: int = Time.get_ticks_usec()
	finder._frames_for(_world.bricks(), copies)
	var frames_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	await _frames(2)
	var list: InventoryPanel = _main.get("_inventory")
	t = Time.get_ticks_usec()
	list.show_for(_world, _library, _store.scenery, name)
	var list_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	await _frames(4)
	list.hide_list()
	await _frames(4)
	print("  %s: live's own, Find and Replace's frames %.1f ms, the parts list opened %.1f ms" % [name,
		frames_ms, list_ms])
	return maxf(frames_ms, list_ms)


## The row, the swaps, the button and what the row says after, in German,
## French and Spanish: each with nothing left in English but the library's
## names and part numbers.
func _case_words() -> void:
	var text: String = "0 Words\n0 Name: words.ldr\n%s\n%s\n%s\n" % [_stack("3009", 71, 13, 0),
		_stack("3069bp01", 15, 2, 80), _stack("4589", 36, 2, 160)]
	await _open(text)
	var list: InventoryPanel = await _list_up()
	var row: Button = list.controls_by_name().get("parts_own")
	if not _check("words: the row (%s)" % (row.text if row != null else "none"), row != null):
		return
	var texts: Array = [row.text, row.tooltip_text, "1 lot you own too few of (13 short; 0% of its 13 pieces are yours (0)): rebuild from what you own…",
		"Use what I own: 1 lot", "Use what I own: 3 lots",
		"Swapped 1 lot for parts you own, 11 parts. Every piece is yours now",
		"swapped 2 lots for parts you own, 13 parts — Ctrl+Z takes it back",
		"none you own: you have none of it in any colour to spare",
		"Plate 1 x 2 with Groove (3794b), the same shape in its colour, holding all its connections and more: the 1 of yours free",
		"Plate 1 x 2 with Groove (3794b), the same shape and connections in its colour: 3 of your 4 free; 2 still missing",
		"nothing swapped: Tile 1 x 1: no room for it", "4 × Brick 2 x 4 (3001) in Light Bluish Grey, you own 1"]
	_check("words: the row opens the swaps", not (await _own_up(list)).is_empty())
	texts.append(list.get("_heading").text)
	for node: Node in [list.get("_swap_note"), list.get("_swap_now"), list.get("_swap_back")]:
		texts.append(node.get("text"))
		if not str(node.get("tooltip_text")).is_empty():
			texts.append(node.get("tooltip_text"))
	var names: Array = []
	for lot: OwnSwap.Lot in list.get("_own"):
		names.append_array([lot.name, lot.colour_name])
		if not lot.into_part.is_empty() and _library.parts.has(lot.into_part):
			names.append(Inventory._tidy((_library.parts[lot.into_part] as PartLibrary.PartInfo).name))
		if lot.into_colour >= 0:
			names.append(_library.color(lot.into_colour).name.replace("_", " "))
		if not lot.nearest.is_empty():
			names.append(_library.color(int(lot.nearest[0])).name.replace("_", " "))
	names.append_array(["Plate 1 x 2 with Groove", "Brick 2 x 4", "Light Bluish Grey", "Tile 1 x 1"])
	names.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for child: Node in (list.get("_swaps") as Node).get_children():
		for each: Node in child.find_children("*", "", true, false):
			if each is Label and not (each as Label).text.is_empty():
				texts.append((each as Label).text)
			if each is CheckBox:
				texts.append((each as CheckBox).tooltip_text)
	if await _use_pressed(list):
		texts.append(list.controls_by_name()["parts_own"].text)
	list.hide_list()
	for code: String in ["de", "fr", "es"]:
		Language.apply(code)
		var missing: Array = []
		var drawn: Array = []
		for english: String in texts:
			if english.strip_edges() == "→" or english.strip_edges().is_empty():
				continue
			var kept: Array = Language.left_in_english(english).filter(func(w: Variant) -> bool:
				if _part_number.search(str(w).strip_edges()) != null:
					return false
				var rest: String = str(w)
				for named: String in names:
					rest = rest.replace(named, "")
				for mark: String in "0123456789½¼¾−-.,:;×→()ΔE+% ":
					rest = rest.replace(mark, "")
				return not rest.is_empty() and rest != "Ctrl" and rest != "CtrlZ")
			if Language.says(english).is_empty() or not kept.is_empty():
				missing.append("\"%s\"%s" % [english, " (kept " + str(kept) + ")"
					if not kept.is_empty() else ""])
			drawn.append(TranslationServer.translate(english))
		print("  %s: %s" % [code, " | ".join(drawn.slice(0, 3))])
		_check("words %s: each of the %d reads in the language%s" % [code, texts.size(),
			"" if missing.is_empty() else ", but not " + "; ".join(missing)], missing.is_empty())
	Language.apply("en")
