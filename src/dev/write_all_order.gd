## The parts bin's All with nothing typed, worked out once for the web pack's
## catalogue and written beside it (PartsBin.ALL_ORDER), so a first visit
## reads the order rather than sorting twenty thousand parts and waiting for
## the parts LDraw keeps only for old files: most of a second of the web's
## start (webload, 2026-10-30). The same code as the bin's own
## (PartsBin.all_unasked), so the two cannot disagree; the bin works it out
## itself for any other catalogue, or with parts made in the app.
## Run by tools/export.sh after tools/web_pack.py:
##
##   godot --headless --path . --script src/dev/write_all_order.gd
##
## It writes the web pack's catalogue as columns beside it too
## (PartLibrary.COLUMNS), which the web build ships in the JSON's place,
## and reads them back: every field of every part must be the JSON's
## (catalogue_columns_probe), or the export stops.
extends SceneTree

const COLUMNS_PROBE := preload("res://src/dev/catalogue_columns_probe.gd")


func _initialize() -> void:
	var library := PartLibrary.new()
	if not library.load_catalogue(PartLibrary.PACK_ROOT + "catalogue.json"):
		printerr("all_order: no web catalogue at %scatalogue.json (tools/web_pack.py)" % PartLibrary.PACK_ROOT)
		quit(1)
		return
	var made: Array = PartsBin.write_all_order(library)
	if made.is_empty():
		printerr("all_order: cannot write %s" % PartsBin.ALL_ORDER)
		quit(1)
		return
	print("all_order: %d parts in All, %d set aside, of %d" % [
		(made[0] as Array).size(), int(made[1]), library.ids().size()])
	var columns: String = PartLibrary.PACK_ROOT + PartLibrary.COLUMNS
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(PartLibrary.PACK_ROOT + "catalogue.json"))
	var out: FileAccess = FileAccess.open(columns, FileAccess.WRITE)
	if typeof(document) != TYPE_DICTIONARY or out == null:
		printerr("catalogue_columns: cannot write %s" % columns)
		quit(1)
		return
	out.store_buffer(var_to_bytes(PartLibrary.columns_of(document)))
	out.close()
	var back := PartLibrary.new()
	var said: PackedStringArray = COLUMNS_PROBE.differences(library, back) \
		if back.load_catalogue(columns) else PackedStringArray(["they do not read"])
	if not said.is_empty():
		# Taken away, so tools/export.sh finds none and stops.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(columns))
		print("catalogue_columns: %s reads otherwise than the JSON, and is taken away:" % columns)
		for one: String in said:
			print("catalogue_columns:   " + one)
		quit(1)
		return
	print("catalogue_columns: %d parts, %.1f MB, every field as the JSON's" % [back.parts.size(),
		FileAccess.get_file_as_bytes(columns).size() / 1e6])
	quit(0)
