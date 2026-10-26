## A shared model's page lists the parts the app's parts list does.
##
##   godot --headless --path . --script src/dev/parts_page_probe.gd -- [FILE.mpd ...]
##
## site278: /m/<id> lists a model's parts, and exports them for BrickLink and
## Rebrickable, from the stored .mpd (api/_parts.js), so every model already
## shared has a list without its owner publishing again. It is a port of the
## app's count, and a port drifts. Here, for each file (by default a small
## castle set, a modular building of sub-models and two Technic sets with
## hoses, pneumatic tubes, LDCad skins and stickers): the model opened in the
## app, its Inventory.of and ShopLists, and the page's own list of the same
## file (tools/web/parts_check.mjs), lot by lot and the two exports word for
## word. Exits non-zero when one differs.
extends SceneTree

const OMR := "res://vendor/omr/files/"
const SETS: Array[String] = ["6040-1", "10243-1", "42080-1", "8880-1"]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	get_root().add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	CustomParts.keeps = false
	await process_frame
	var files: Array[String] = []
	for arg: String in OS.get_cmdline_user_args():
		files.append(arg)
	if files.is_empty():
		for number: String in SETS:
			files.append(ProjectSettings.globalize_path(OMR + number + ".mpd"))
	var out: Dictionary = {}
	for path: String in files:
		if not FileAccess.file_exists(path):
			_check("%s: its file is here" % path, false)
			continue
		store.open(path)
		var stock: Inventory = Inventory.of(world, library, store.scenery)
		var lots: Array = []
		for lot: Inventory.Lot in stock.lots:
			lots.append([lot.part_id, lot.color_code, lot.count, lot.name, lot.bricklink_id,
				library.bricklink_colour(lot.color_code), lot.rebrickable_id, lot.rebrickable_colour,
				lot.element, lot.custom])
		out[path] = {"pieces": stock.pieces, "lots": lots,
			"xml": str(ShopLists.bricklink_xml(stock, library)["text"]),
			"csv": str(ShopLists.rebrickable_csv(stock)["text"])}
	var json_path: String = OS.get_user_data_dir().path_join("parts_page_app.json")
	var file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(out))
	file.close()
	var said: Array = []
	var code: int = OS.execute("node", [ProjectSettings.globalize_path("res://tools/web/parts_check.mjs"),
		"--app=" + json_path], said, true)
	for line: Variant in said:
		print(str(line).strip_edges(false, true))
	_check("the page's lists are the app's (tools/web/parts_check.mjs exit %d)" % code, code == 0)
	print("")
	print("parts page: the page lists every model's parts as the app does" if _failures == 0
		else "parts page: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
