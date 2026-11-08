## A model's page places it in a room with the GLB the app's Export writes.
##
##   godot --headless --path . --script src/dev/arview_probe.gd -- [FILE.mpd ...]
##
## APP_UX5 #13 (arview): on a phone a model's page offers In your room, and
## the model it places is a GLB written in the visitor's browser
## (web/glb.js) from the stored file (api/_parts.js roomOf) and each part's
## geometry in the store. It is a port of Export's (MeshExport._gltf), and a
## port drifts. Here, for each file (by default the example car, a small
## castle set, a modular building of sub-models with copies, and two Technic
## sets with hoses and stickers): the model opened in the app and written as
## a GLB by Export's own writer (MeshExport, as File, Export, 3D model…
## writes it), and the page's GLB of the same file (tools/web/arview_check.mjs),
## read back node by node: the same parts in the same places and assemblies,
## the same meshes, materials and colours, the same geometry, each shape once,
## and the page's under the size a phone is given it at (web/glb.js
## MOST_BYTES). Exits non-zero when one differs.
extends SceneTree

const OMR := "res://vendor/omr/files/"
const FILES: Array[String] = ["res://models/car.ldr", OMR + "6040-1.mpd", OMR + "10243-1.mpd",
	OMR + "42080-1.mpd", OMR + "8880-1.mpd"]

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
		for path: String in FILES:
			files.append(ProjectSettings.globalize_path(path))
	var out_dir: String = OS.get_user_data_dir().path_join("arview_probe")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var listed: Dictionary = {}
	for path: String in files:
		if not FileAccess.file_exists(path):
			_check("%s: its file is here" % path, false)
			continue
		store.open(path)
		var maker := MeshExport.new()
		maker.world = world
		maker.library = library
		maker.scenery = store.scenery
		var title: String = path.get_file().get_basename()
		var started: int = Time.get_ticks_msec()
		var made: MeshExport.Made = await maker.write("glb", title)
		var ok: bool = made.refused.is_empty() and made.files.size() == 1
		_check("%s: Export writes its GLB (%d parts, %d shapes, %s triangles, %d ms)%s" % [path.get_file(), made.parts,
			made.shapes, Working.comma(made.triangles), Time.get_ticks_msec() - started,
			"" if ok else ": " + made.refused], ok)
		if not ok:
			continue
		var glb_path: String = out_dir.path_join(title + ".glb")
		var file: FileAccess = FileAccess.open(glb_path, FileAccess.WRITE)
		file.store_buffer(made.files[0][1])
		file.close()
		var custom: Array = []
		for brick: BrickWorld.Brick in world.bricks():
			var info: PartLibrary.PartInfo = library.parts.get(brick.part_id)
			if info != null and info.custom and not custom.has(brick.part_id):
				custom.append(brick.part_id)
		listed[path] = {"glb": glb_path, "title": title, "parts": made.parts, "left_out": made.left_out,
			"custom": custom}
	var json_path: String = out_dir.path_join("arview_app.json")
	var list_file: FileAccess = FileAccess.open(json_path, FileAccess.WRITE)
	list_file.store_string(JSON.stringify(listed))
	list_file.close()
	var said: Array = []
	var code: int = OS.execute("node", [ProjectSettings.globalize_path("res://tools/web/arview_check.mjs"),
		"--app=" + json_path], said, true)
	for line: Variant in said:
		print(str(line).strip_edges(false, true))
	_check("the page's GLB is Export's (tools/web/arview_check.mjs exit %d)" % code, code == 0)
	print("")
	print("arview: every model's room GLB is the one Export writes" if _failures == 0
		else "arview: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
