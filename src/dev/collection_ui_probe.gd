## My collection in the real app, in a window.
##
##   godot --path . --resolution 1400x900 --script src/dev/collection_ui_probe.gd
##
## Opens the app with the car on the baseplate and a collection of its own
## (no account: the panel works from what it is given, as it does from the
## copy on a desktop that is offline): half of the car's parts, a white
## brick where a red one is short, four 1 x 2s where a 1 x 4 is, and one
## real set. The parts list's "What do I need?" opens the panel on the
## shortfall, which must agree with Collection's own sums; "What can I
## build?" ranks the examples and the official models with the car near the
## top; "What I own" lists the set by name. Nothing is written to the app's
## own directory and no account is touched.
##
## Pictures: shots/collection_need.png, shots/collection_build.png and
## shots/collection_own.png. Look at them.
extends SceneTree

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	CollectionStore.where = OS.get_temp_dir().path_join("brickworks_collection_ui_%d.json"
		% OS.get_process_id())
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var library: PartLibrary = _main.get("_library")
	var models: ModelStore = _main.get("_store")
	var shell: Shell = _main.get("_shell")
	var dialog: CollectionDialog = shell.collection
	_check("the panel is made with the app", dialog != null and not dialog.visible)
	_check("the Build menu has the three commands",
		shell.menu_id("collection") >= 0 and shell.menu_id("collection_need") >= 0
		and shell.menu_id("collection_build") >= 0)
	_main.call("clear_model")
	await _frames(10)
	var placed: int = models.open("res://models/car.ldr")
	(_main.get("_bar") as ModelBar).opened.emit(placed)
	await _frames(30)
	_check("the car is on the baseplate (%d parts)" % placed, placed > 20)

	# Half of every lot the car uses, and one more of each odd one; a white
	# 2 x 4 for a red one; and the Magic Shop.
	var world: BrickWorld = _main.get("_world")
	var stock: Inventory = Inventory.of(world, library, models.scenery)
	var mine := Collection.new()
	for lot: Inventory.Lot in stock.lots:
		if lot.count >= 2:
			mine.parts.append({"part": lot.part_id, "colour": library.plain_code(lot.color_code),
				"qty": lot.count / 2})
	mine.parts.append({"part": "3001", "colour": 15, "qty": 2})
	mine.parts.append({"part": "3004", "colour": 0, "qty": 4})
	mine.sets = [{"set": "6020-1", "qty": 1, "spares": false}]
	dialog.store.collection = mine
	await dialog.store.refresh_pool()
	dialog.store.changed.emit()
	var expected: Array = Collection.plan(Collection.needs_of(stock, library), dialog.store.on_hand,
		library)
	var expected_short: int = 0
	for row: Dictionary in expected:
		expected_short += int(row["short"])

	print("\n  what do I need")
	var parts_list: InventoryPanel = _main.get("_inventory")
	_main.call("_toggle_parts")
	await _frames(10)
	var need: Button = parts_list.controls_by_name().get("parts_need")
	_check("the parts list has What do I need?", need != null and need.is_visible_in_tree())
	if need != null:
		need.pressed.emit()
	await _frames(20)
	_check("...which opens the panel on the shortfall", dialog.visible and dialog._page == "need"
		and not parts_list.visible)
	var heading: String = dialog._need_heading.text
	print("     %s" % heading)
	_check("it says what is short: %d pieces in %d lots" % [expected_short, expected.size()],
		heading.contains("Short: %s pieces in %d lots" % [CollectionDialog._comma(expected_short),
			expected.size()]))
	_check("one row per short lot (%d)" % dialog._need_rows.get_child_count(),
		dialog._need_rows.get_child_count() == mini(expected.size(), CollectionDialog.MOST_ROWS))
	var text: String = _text_of(dialog._need_rows)
	_check("each row links to BrickLink", text.contains("BrickLink"))
	_check("what could stand in is said", text.contains("could stand in"))
	var short: Inventory = Collection.shortfall_stock(dialog._need_stock, dialog._need_plan, library)
	_check("the wanted list it would export is the shortfall (%d pieces)" % short.pieces,
		short.pieces == expected_short)
	await _shot("collection_need")

	print("\n  what can I build")
	dialog._show("build")
	for _n: int in 600:
		if not dialog._busy and not dialog._ranked.is_empty():
			break
		await process_frame
	await _frames(10)
	var ranked: Array = dialog._ranked
	_check("examples and official models are ranked (%d)" % ranked.size(), ranked.size() > 100)
	var kinds: Dictionary = {}
	for candidate: Dictionary in ranked:
		kinds[str(candidate["kind"]).get_slice(" ", 0)] = true
	_check("...both kinds of them: %s" % ", ".join(kinds.keys()),
		kinds.has("Example") and kinds.has("Official"))
	var ordered: bool = true
	for n: int in range(1, ranked.size()):
		if float(ranked[n]["cover"]["exact"]) > float(ranked[n - 1]["cover"]["exact"]) + 0.0001:
			ordered = false
	_check("most owned first", ordered)
	# The car by its file's name: "car.ldr" at the end of a path also found
	# sports_car.ldr (674cdc65, 2026-10-24), and the last found was taken.
	var car_at: int = -1
	for n: int in ranked.size():
		if str(ranked[n].get("path", "")).get_file() == "car.ldr":
			car_at = n
			break
	_check("the car, half owned, is near the top (%d of %d: %s)" % [car_at + 1, ranked.size(),
		str(ranked[0]["name"])], car_at >= 0 and car_at < 10)
	await _shot("collection_build")

	print("\n  what I own")
	dialog._show("own")
	await _frames(10)
	var own: String = _text_of(dialog._own_rows)
	_check("the set is listed by its name: %s" % ("Magic Shop" if own.contains("Magic Shop") else own.left(80)),
		own.contains("6020-1") and own.contains("Magic Shop"))
	_check("the summary counts it: %s" % dialog._summary.text,
		dialog._summary.text.begins_with("1 set and"))
	await _shot("collection_own")
	dialog.close()
	await _frames(4)
	_check("Done closes it", not dialog.visible)

	if FileAccess.file_exists(CollectionStore.where):
		DirAccess.remove_absolute(CollectionStore.where)
	print("")
	if _failures == 0:
		print("collection ui probe: the shortfall, the ranking and the collection on screen")
	else:
		print("collection ui probe: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _text_of(node: Node) -> String:
	var out: String = ""
	if node is Label:
		out += (node as Label).text + "\n"
	elif node is Button:
		out += (node as Button).text + "\n"
	elif node is LinkButton:
		out += (node as LinkButton).text + "\n"
	for child: Node in node.get_children():
		out += _text_of(child)
	return out


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)
