## The parts bin's All with nothing typed, worked out once for the web pack's
## catalogue and written beside it (PartsBin.ALL_ORDER), so a first visit
## reads the order rather than sorting twenty thousand parts and waiting for
## the parts LDraw keeps only for old files: most of a second of the web's
## start (webload, 2026-10-30). The same code as the bin's own
## (PartsBin.all_unasked), so the two cannot disagree; the bin works it out
## itself for any other catalogue, or with parts made in the app.
## Run by tools/export.sh after tools/web_pack.py:
##
##   godot --headless --path . --script src/dev/all_order.gd
extends SceneTree


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
	quit(0)
