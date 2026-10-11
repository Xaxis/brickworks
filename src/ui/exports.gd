## What Export writes besides the LDraw file: a picture of the model, and
## its parts list for BrickLink or Rebrickable. See [Picture], [ShopLists].
class_name Exports
extends Node

var world: BrickWorld
var library: PartLibrary
var scenery: Dictionary = {}
var say: Callable = func(_line: String) -> void: pass
## The model's name, for the file's.
var named: Callable = func() -> String: return "Model"
## Where files go on the desktop; the Downloads folder when empty. A probe
## points it at a folder of its own.
var folder: String = ""

var picture: Picture


func _ready() -> void:
	picture = Picture.new()
	add_child(picture)


func take_picture() -> String:
	if world.brick_count() - scenery.size() <= 0:
		say.call("nothing to take a picture of")
		return ""
	say.call("taking the picture…")
	var image: Image = await picture.take()
	if image == null:
		say.call("nothing to take a picture of")
		return ""
	var line: String = Picture.keep(image, _file("png"), folder)
	say.call(line)
	return line


func shop_list(shop: String) -> String:
	var stock: Inventory = Inventory.of(world, library, scenery)
	if stock.lots.is_empty():
		say.call("nothing to list yet")
		return ""
	var made: Dictionary
	var file_name: String
	var mime: String
	if shop == "bricklink":
		made = ShopLists.bricklink_xml(stock, library)
		file_name = _file("xml", "_bricklink")
		mime = "application/xml"
	else:
		made = ShopLists.rebrickable_csv(stock)
		file_name = _file("csv", "_rebrickable")
		mime = "text/csv"
	var line: String = _give(str(made["text"]), file_name, mime, folder)
	if int(made["left_out"]) > 0:
		line += " — %d of %d lots left off: colours %s has no number for here, or made parts" % [
			int(made["left_out"]), stock.lots.size(),
			"BrickLink" if shop == "bricklink" else "Rebrickable"]
	say.call(line)
	return line


func _file(extension: String, suffix: String = "") -> String:
	var base: String = str(named.call()).to_snake_case()
	if base.is_empty():
		base = "model"
	return "%s%s.%s" % [base, suffix, extension]


## Downloaded in a browser, written to Downloads on the desktop.
static func _give(text: String, file_name: String, mime: String,
		into: String = "") -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), file_name, mime)
		return "downloaded %s" % file_name
	var to: String = into if not into.is_empty() \
		else OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	if to.is_empty():
		to = OS.get_user_data_dir()
	var path: String = to.path_join(file_name.replace("\\", "/").get_file())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "could not write %s" % file_name
	file.store_string(text)
	file.close()
	return "wrote %s" % path
