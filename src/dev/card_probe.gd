## The gallery's cards, as they were and as photographs (cardlook): each of
## the house's models opened and turned as the gallery's seed list says
## (gallery_seed.gd), then its card drawn both ways at the card's size.
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a -s "-screen 0 1600x900x24" \
##       godot --path . --resolution 1400x900 --script src/dev/card_probe.gd -- \
##       --pictures=DIR [--only=1,5,20] [--looks=LOOKS.json] [--old=0]
##
## Models are numbered through tools/web/gallery_seeds/seeds.json and then
## ldraw_library.json, 1 to 49. For each, into DIR:
##   <n>_old.png       the card as the Share panel drew it before: the cut-out
##                     (Picture, the window's light) with nothing behind it
##   <n>_<look>.png    CardPhoto's card, one for each look (LOOKS.json is
##                     {name: {RenderSettings field: value}}; "new" is
##                     CardPhoto.LOOK as it stands)
##   times.json        how long each took, milliseconds
## Under --rendering-method gl_compatibility (through zink on the GPU) it
## draws what a browser's card is: frames averaged (CardPhoto.RASTER).
## Each check says what it drew. Not --out: the app takes that.
extends SceneTree

const SEEDS: Array = ["res://tools/web/gallery_seeds/seeds.json",
	"res://tools/web/gallery_seeds/ldraw_library.json"]

var _failures: int = 0


func _initialize() -> void:
	_run()


func _arg(name: String, fallback: String = "") -> String:
	for given: String in OS.get_cmdline_user_args():
		if given.begins_with("--%s=" % name):
			return given.substr(name.length() + 3)
	return fallback


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var out: String = _arg("pictures")
	if out.is_empty():
		push_error("card_probe: --pictures=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	var only: PackedStringArray = _arg("only").split(",", false)
	var looks: Dictionary = {"new": {}}
	if not _arg("looks").is_empty():
		var read: Variant = JSON.parse_string(FileAccess.get_file_as_string(_arg("looks")))
		if read is Dictionary:
			looks = read
	var old: bool = _arg("old", "1") != "0"
	var seeds: Array = []
	for list: String in SEEDS:
		seeds.append_array(JSON.parse_string(FileAccess.get_file_as_string(list)))

	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 200:
		await process_frame
	var store: ModelStore = main.get("_store")
	var bar: ModelBar = main.get("_bar")
	var camera: CadCamera = main.get("_camera")
	var world: BrickWorld = main.get("_world")
	(main.get("_builder") as Builder).hide_preview()
	print("  renderer: %s on %s; path traced: %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), PathTracer.available()])
	var picture: Picture = (main.get("_exports") as Node).get("picture")
	var card := CardPhoto.new()
	card.world = world
	card.library = main.get("_library")
	card.scenery = store.scenery
	card.eye = camera
	card.look = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		card.rig_lights.append(main.get_node(light_name) as DirectionalLight3D)
	root.add_child(card)

	var times: Dictionary = {}
	for n: int in range(1, seeds.size() + 1):
		if not only.is_empty() and not str(n) in only:
			continue
		var said: Dictionary = seeds[n - 1]
		var file: String = str(said.get("file", ""))
		if file.is_relative_path():
			file = ProjectSettings.globalize_path("res://").path_join(file)
		var opened: Dictionary = store.open_text(FileAccess.get_file_as_string(file), str(said["name"]))
		if not str(opened["error"]).is_empty():
			_ok(false, "%d %s: %s" % [n, file, opened["error"]])
			continue
		bar.opened.emit(int(opened["placed"]))
		for _n: int in 3600:
			await process_frame
			if store.awaited.is_empty():
				break
		camera.set_view("")
		var turn: Variant = said.get("turn")
		if turn is Array and (turn as Array).size() == 2:
			var yaw: float = deg_to_rad(float(turn[0]))
			var pitch: float = deg_to_rad(float(turn[1]))
			camera.look_from(Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)))
		for _n: int in 60:
			await process_frame
		await RenderingServer.frame_post_draw
		var took: Dictionary = {"parts": int(opened["placed"])}
		if old:
			var began: int = Time.get_ticks_usec()
			var framed: Image = await picture.take(SharePanel.THUMB * 2)
			took["old"] = float(Time.get_ticks_usec() - began) / 1000.0
			_ok(framed != null and not framed.is_empty(), "%d %s: the cut-out card, %.0f ms"
				% [n, said["name"], took["old"]])
			if framed != null:
				framed.convert(Image.FORMAT_RGBA8)
				framed.resize(SharePanel.THUMB.x, SharePanel.THUMB.y, Image.INTERPOLATE_LANCZOS)
				framed.save_png(out.path_join("%d_old.png" % n))
		for look: String in looks:
			card.asked = looks[look]
			var photo: Image = await card.take(SharePanel.THUMB * 2)
			took[look] = card.last_ms
			took[look + "_steps"] = card.steps
			took[look + "_worst"] = [roundi(card.worst_frame_ms), card.worst_step]
			_ok(photo != null and photo.get_size() == SharePanel.THUMB * 2,
				"%d %s: the card as a photograph (%s), %.0f ms, its longest frame %.0f ms (%s)"
				% [n, said["name"], look, card.last_ms, card.worst_frame_ms, card.worst_step])
			if photo != null:
				photo.convert(Image.FORMAT_RGB8)
				photo.resize(SharePanel.THUMB.x, SharePanel.THUMB.y, Image.INTERPOLATE_LANCZOS)
				photo.save_png(out.path_join("%d_%s.png" % [n, look]))
		times[str(n)] = took
		store.share_id = ""
	var kept := FileAccess.open(out.path_join("times.json"), FileAccess.WRITE)
	kept.store_string(JSON.stringify(times, " "))
	kept.close()
	print("")
	print("%d FAILED" % _failures if _failures else "every card drawn, in %s" % out)
	quit(1 if _failures else 0)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
