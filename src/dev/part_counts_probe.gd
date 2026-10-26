## A model's part count is one count: its card, the model opened and its box.
##
##   godot --headless --path . --script src/dev/part_counts_probe.gd
##
## walk256 (findings D11): the Cat D11's Library card said 2,183 parts, it
## opened as 5,108 (6,793 on rel-m175) and its box holds 3,853. The card was
## what of its set's box the file was matched to, which left out the 1,679
## parts the file carries itself; the opened model counted its four motors'
## cables as 2,891 ribbon segments. A part count is now the parts a builder
## takes out of the box (Inventory.is_piece, Inventory.pieces_in): sub-models
## expanded, a hose or a pneumatic tube once, the bits LDraw draws a bigger
## part with (a cable's segments, a ~ part) none. Here, for the D11 and nine
## more of the Library's sets of every size: the model opened counts the same
## as its file read (Inventory.count_of_text, what the card says once the
## index is built again), and that agrees with its box to a fiftieth or the
## card says the box too (ModelLibrary.parts_words). Exits non-zero when a
## count disagrees with nothing said.
extends SceneTree

const OMR := "res://vendor/omr/files/"
## Of every size: a Technic set with motors, a UCS ship, two modular
## buildings, a creator cottage, a castle shop, a town ambulance, a Technic
## set with pneumatic tubes and one with hoses and stickers, and a set whose
## LDraw model builds only part of it.
const SETS: Array[String] = ["42131-1", "10179-1", "10243-1", "10218-1", "31009-1",
	"6040-1", "6680-1", "42080-1", "8880-1", "8032-1"]

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
	var models: Dictionary = {}
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		SetInventories.ROOT + "models.json"))
	if listed is Dictionary:
		for model: Dictionary in (listed as Dictionary).get("models", []):
			models[str(model["file"])] = model
	print("set          drawn   opened    card     box   card says")
	for number: String in SETS:
		var path: String = OMR + number + ".mpd"
		if not FileAccess.file_exists(path):
			_check("%s: its file is here" % number, false)
			continue
		# Read first, as the card is counted (collection_models), with none of
		# the parts it carries in the library yet.
		var card: int = Inventory.count_of_text(FileAccess.get_file_as_string(path), library)
		store.open(path)
		var drawn: int = world.brick_count() - store.scenery.size()
		var opened: int = Inventory.pieces_in(world, library, store.scenery)
		var box: int = await ModelLibrary.box_of(number)
		var said: String = ModelLibrary.parts_words({"parts": card, "box": box})
		var before: int = 0
		for row: Variant in (models.get(number + ".mpd", {}) as Dictionary).get("p", []):
			before += int((row as Array)[2])
		print("%-10s %7d %8d %7d %7d   %s   (the card before: %d)" % [number, drawn, opened, card,
			box, said, before])
		_check("%s: opened and read, one count: %d and %d" % [number, opened, card], opened == card)
		_check("%s: agrees with its box (%d), or the card says it: %s" % [number, box, said],
			ModelLibrary.agrees(card, box) or said.contains("its box"))
	print("")
	print("part counts: the card, the model opened and its box say one count, or the card says "
		+ "the box's too" if _failures == 0 else "part counts: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
