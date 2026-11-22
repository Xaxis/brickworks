## "Where does this go?" measured (APP_UX11 partstep): 30 photos of parts of
## the car and 10179, through Build mode's own path to the real Brickognize.
##
##   gpu xvfb-run -a -s '-screen 0 1400x900x24' godot --path . --resolution 390x844 \
##     --script src/dev/partstep_bench.gd -- --render --out=DIR     the photos
##   gpu xvfb-run ... --script src/dev/partstep_bench.gd -- --ask --out=DIR   the measure
##
## --render: for each model, ten of its lots (part and colour) chosen by rule
## (sorted most first, every tenth of the list, no stickers), each drawn alone
## by the app's renderer and dressed as a phone's photo of a part held over a
## table: from above at a phone's angle, on a wood or grey table, in warm
## light falling from one side, a little soft, and a JPEG. And five more lots
## of each, by the same rule from the other end of the list, as Brickognize's
## own pictures of that part in that colour (its thumbnails, the pictures
## its answers show): 20 renders and 10 of Brickognize's own. DIR/photos.json
## says what each is.
##
## --ask: each model opened as a shared link and Build it opened, as a builder
## does; for each photo the builder is put mid-build (on the step after the
## first that places the part, where it is placed more than once, so the
## first is built), and the photo goes through Build mode's own path
## (BuildMode.identify, as the picker hands one over) to Brickognize itself.
## For each: the right part in the top three; the step it goes to against the
## first step not yet built that places that part in that colour; the time
## from the photo to the step shown. DIR/bench.json and a table on stdout.
##
## Bars (APP_UX11 partstep): the right part in the top 3 for 80% or more; the
## right step whenever the part was right; 3 s or less from the photo to the step.
extends SceneTree

const MODELS: Array = [["car", "res://models/car.ldr"], ["10179", "res://vendor/omr/files/10179-1.mpd"]]
const RENDERS := 10
const EXAMPLES := 5
const THUMBS := "https://storage.googleapis.com/brickognize-static/thumbnails/v5.0/part/%s/%d.webp"
const VIEWS: Array = ["corner", "front left", "far corner", "back right"]
const TABLES: Array = [Color(0.72, 0.58, 0.42), Color(0.56, 0.56, 0.58), Color(0.80, 0.70, 0.55)]

var _out: String = ""
var _failures: int = 0


class FakeShared extends SharedModels:
	var answer: Dictionary = {}

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(_id: String, _device: String, _version: int = 1) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"counted": true, "builds": 1}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"comments": [], "open": true, "you": {"signed_in": false}}}


func _initialize() -> void:
	_run()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for arg: String in args:
		if arg.begins_with("--out="):
			_out = arg.get_slice("=", 1)
	if _out.is_empty():
		print("partstep_bench: give --out=DIR")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out + "/photos")
	await process_frame
	if args.has("--render"):
		await _render()
	elif args.has("--ask"):
		await _ask_all()
	else:
		print("partstep_bench: --render or --ask")
		quit(2)
		return
	quit(1 if _failures > 0 else 0)


# -- the photos ----------------------------------------------------------------


func _render() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 120:
		await process_frame
	var playback: Variant = main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	var store: ModelStore = main.get("_store")
	store.keeps = false
	var world: BrickWorld = main.get("_world")
	var library: PartLibrary = main.get("_library")
	var builder: Builder = main.get("_builder")
	var shot: Node = Later.make(&"ModelShot")
	shot.set("rulers", false)
	shot.set("library", library)
	main.add_child(shot)
	var listed: Array = []
	var n: int = 0
	for model: Array in MODELS:
		var bar: ModelBar = main.get("_bar")
		main.call("clear_model")
		await _frames(4)
		var opened: Dictionary = await bar.open_text_with_progress(FileAccess.get_file_as_string(model[1]),
			str(model[0]))
		bar.opened.emit(int(opened.get("placed", 0)))
		await _frames(20)
		var stock: Inventory = Inventory.of(world, library, store.scenery)
		var lots: Array = []
		for lot: Inventory.Lot in stock.lots:
			if library.sticks(lot.part_id) or lot.custom or not library.parts.has(lot.part_id):
				continue
			lots.append(lot)
		lots.sort_custom(func(a: Inventory.Lot, b: Inventory.Lot) -> bool:
			return a.count > b.count if a.count != b.count else a.part_id < b.part_id)
		print("%s: %d parts, %d lots" % [model[0], world.brick_count(), lots.size()])
		var renders: Array = []
		for k: int in RENDERS:
			renders.append(lots[int(float(k) * lots.size() / RENDERS)])
		var examples: Array = []
		var k2: int = 0
		# From the other end, a lot not rendered, one with a picture of Brickognize's.
		var at: int = lots.size() - 1 - int(lots.size() / (2 * EXAMPLES))
		while examples.size() < EXAMPLES and at >= 0:
			var lot: Inventory.Lot = lots[at]
			at -= maxi(1, int(lots.size() / (2 * EXAMPLES)))
			if renders.has(lot):
				continue
			var got: Image = await _thumbnail(main, library, lot)
			k2 += 1
			if got == null:
				continue
			var file: String = "%s_example_%d_%s_%d.jpg" % [model[0], examples.size(), lot.part_id, lot.color_code]
			got.save_jpg(_out + "/photos/" + file, 0.88)
			examples.append(lot)
			listed.append({"file": file, "model": model[0], "part": lot.part_id, "colour": lot.color_code,
				"name": lot.name, "colour_name": lot.color_name, "kind": "brickognize"})
		# The renders: each lot alone, a phone's photo of it.
		var parts: Array = []
		for lot: Inventory.Lot in renders:
			parts.append([lot.part_id, lot.color_code, lot.name, lot.color_name])
		main.call("clear_model")
		await _frames(4)
		for k: int in parts.size():
			var part: Array = parts[k]
			world.clear()
			builder.lattice.clear()
			store.scenery.clear()
			world.add_brick(str(part[0]), int(part[1]), Transform3D.IDENTITY)
			await _frames(4)
			var picture: Image = await shot.call("take", world, VIEWS[n % VIEWS.size()])
			if picture == null:
				print("  FAIL  %s could not be drawn" % part[0])
				_failures += 1
				continue
			var phone: Image = _as_a_phone(picture, n)
			var file: String = "%s_render_%d_%s_%d.jpg" % [model[0], k, part[0], part[1]]
			phone.save_jpg(_out + "/photos/" + file, 0.82)
			listed.append({"file": file, "model": model[0], "part": part[0], "colour": part[1],
				"name": part[2], "colour_name": part[3], "kind": "render", "view": VIEWS[n % VIEWS.size()]})
			n += 1
	var file := FileAccess.open(_out + "/photos.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(listed, "  "))
	file.close()
	print("partstep_bench: %d photos in %s/photos" % [listed.size(), _out])


## Brickognize's own picture of [param lot]'s part in its colour, or null.
func _thumbnail(host: Node, library: PartLibrary, lot: Inventory.Lot) -> Image:
	var colour: int = library.bricklink_colour(lot.color_code)
	var number: String = library.shop_part(lot.part_id, "BrickLink")
	if colour < 0:
		return null
	var http := HTTPRequest.new()
	http.timeout = 20.0
	host.add_child(http)
	if http.request(THUMBS % [number, colour]) != OK:
		http.queue_free()
		return null
	var answer: Array = await http.request_completed
	http.queue_free()
	if int(answer[0]) != HTTPRequest.RESULT_SUCCESS or int(answer[1]) != 200:
		print("  no picture of Brickognize's for %s in BrickLink colour %d (HTTP %d)" % [number, colour, int(answer[1])])
		return null
	var image := Image.new()
	if image.load_webp_from_buffer(answer[3]) != OK:
		return null
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
	return image


## A render dressed as a phone's photo of a part over a table: the
## renderer's plain backdrop a table's colour with its grain, warm light
## falling from one side, a little soft and grainy, the part off the middle
## and smaller in a 4:3 frame.
func _as_a_phone(picture: Image, n: int) -> Image:
	var image: Image = picture.duplicate()
	image.convert(Image.FORMAT_RGB8)
	var backdrop := Color(0.93, 0.94, 0.96)
	var table: Color = TABLES[n % TABLES.size()]
	var w: int = image.get_width()
	var h: int = image.get_height()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + n
	var warm := Color(1.0, 0.94, 0.84)
	for y: int in h:
		for x: int in w:
			var c: Color = image.get_pixel(x, y)
			if absf(c.r - backdrop.r) + absf(c.g - backdrop.g) + absf(c.b - backdrop.b) < 0.06:
				var grain: float = 0.04 * sin(float(y) * 0.09 + sin(float(x) * 0.013) * 3.0)
				c = Color(table.r + grain, table.g + grain * 0.8, table.b + grain * 0.6)
			# Light from the left, warm, falling off to the right.
			var lit: float = lerpf(1.12, 0.78, float(x) / w) * lerpf(1.04, 0.92, float(y) / h)
			c = Color(c.r * warm.r * lit, c.g * warm.g * lit, c.b * warm.b * lit)
			var noise: float = rng.randf_range(-0.025, 0.025)
			image.set_pixel(x, y, Color(clampf(c.r + noise, 0, 1), clampf(c.g + noise, 0, 1),
				clampf(c.b + noise, 0, 1)))
	# Soft: a phone's small lens and a hand that moves.
	image.resize(w / 2, h / 2, Image.INTERPOLATE_BILINEAR)
	image.resize(w, h, Image.INTERPOLATE_BILINEAR)
	# A 4:3 frame round it, the part off the middle and smaller.
	var frame := Image.create(roundi(w * 1.6), roundi(h * 1.2), false, Image.FORMAT_RGB8)
	var edge: Color = Color(table.r * warm.r * 0.9, table.g * warm.g * 0.9, table.b * warm.b * 0.9)
	frame.fill(edge)
	var dx: int = roundi(frame.get_width() * (0.12 + 0.18 * float(n % 3) / 2.0))
	var dy: int = roundi(frame.get_height() * 0.06)
	frame.blit_rect(image, Rect2i(0, 0, w, h), Vector2i(dx, dy))
	return frame


# -- the measure ------------------------------------------------------------------


func _ask_all() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(_out + "/photos.json"))
	if not listed is Array:
		print("partstep_bench: no %s/photos.json: --render first" % _out)
		_failures += 1
		return
	var rows: Array = []
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="):
			only = arg.get_slice("=", 1)
	for model: Array in MODELS:
		if not only.is_empty() and str(model[0]) != only:
			continue
		var photos: Array = (listed as Array).filter(func(one: Dictionary) -> bool:
			return str(one["model"]) == str(model[0]))
		if photos.is_empty():
			continue
		var text: String = FileAccess.get_file_as_string(model[1])
		var main: Node = await _open("B3nch%s" % str(model[0]).replace("_", ""), text, str(model[0]))
		var mode: BuildMode = await _build_it(main)
		var pages: BuildSteps = main.get("_build_pages")
		if not mode.is_open() or pages == null:
			print("  FAIL  %s: Build it did not open" % model[0])
			_failures += 1
			main.queue_free()
			await _frames(4)
			continue
		var world: BrickWorld = main.get("_world")
		var library: PartLibrary = main.get("_library")
		print("%s: %d pages" % [model[0], pages.last()])
		for one: Dictionary in photos:
			var part: String = str(one["part"])
			var colour: int = int(one["colour"])
			var hits: Array = []
			for page: int in range(1, pages.last() + 1):
				for brick_id: int in pages.added(page):
					var brick: BrickWorld.Brick = world.get_brick(brick_id)
					if brick.part_id == part and brick.color_code == colour:
						hits.append(page)
						break
			# Mid-build: the first that places it built, where there is a second.
			var home: int = int(hits[0]) + 1 if hits.size() >= 2 else 1
			var expected: int = int(hits[1]) if hits.size() >= 2 else (int(hits[0]) if not hits.is_empty() else -1)
			main.call("_build_go", home)
			await _frames(6)
			var photo := Image.load_from_file(_out + "/photos/" + str(one["file"]))
			var since: int = Time.get_ticks_msec()
			mode.identify(photo)
			var card: Dictionary = {}
			while Time.get_ticks_msec() - since < 40000:
				await process_frame
				card = mode.page_state()["partstep"]
				if int(card["photo_ms"]) >= 0 or (bool(card["shown"]) and int(card["step"]) < 0
						and str(card["title"]) != "Asking Brickognize what part this is…"):
					break
			await _frames(4)
			var said: Dictionary = main.call("build_state")
			card = said["partstep"]
			var options: Array = card["options"]
			var answer: Dictionary = mode.get("_card").get("answer")
			var right_part: bool = false
			var rank: int = -1
			var opts: Array = answer.get("options", []) if not answer.is_empty() else []
			for k: int in opts.size():
				if (opts[k]["parts"] as Array).has(part) or str(opts[k]["part"]) == library.current(part) \
						or str(opts[k]["part"]) == library.current(PartPrints.plain_of(library, part)):
					right_part = true
					rank = k + 1
					break
			var picked_right: bool = not answer.is_empty() and int(answer["picked"]) >= 0 \
				and (opts[int(answer["picked"])]["parts"] as Array).has(part)
			var shown: int = int(said["page"]) if int(card["photo_ms"]) >= 0 else -1
			var row: Dictionary = {"file": one["file"], "kind": one["kind"], "model": model[0], "part": part,
				"colour": colour, "name": one["name"], "colour_name": one["colour_name"],
				"options": options, "top3": right_part, "rank": rank, "picked_right": picked_right,
				"home": home, "expected": expected, "shown": shown,
				"step_right": shown == expected, "colour_read": int(card["colour"]),
				"ms": int(card["photo_ms"]), "where": card["where"], "title": card["title"]}
			rows.append(row)
			print("  %s  %-34s top3 %s (rank %d)  step %s (from %d: %d, wanted %d)  %d ms  %s" % [
				"ok  " if right_part and shown == expected else "miss", str(one["file"]).left(34),
				"yes" if right_part else "no ", rank, "right" if shown == expected else "WRONG",
				home, shown, expected, int(card["photo_ms"]), str(options)])
			(mode.get("_card") as PartStep).hide_card()
			mode.set("_home", -1)
			# Brickognize's own pace: a photo every two seconds or so.
			await _wait(1.5)
		main.queue_free()
		await _frames(10)
	var top3: int = rows.filter(func(row: Dictionary) -> bool: return bool(row["top3"])).size()
	var steps_right: int = rows.filter(func(row: Dictionary) -> bool:
		return bool(row["top3"]) and bool(row["picked_right"]) and bool(row["step_right"])).size()
	var picked: int = rows.filter(func(row: Dictionary) -> bool: return bool(row["picked_right"])).size()
	var times: Array = rows.map(func(row: Dictionary) -> int: return int(row["ms"])).filter(
		func(ms: int) -> bool: return ms >= 0)
	times.sort()
	var slowest: int = int(times[-1]) if not times.is_empty() else -1
	var middle: int = int(times[times.size() / 2]) if not times.is_empty() else -1
	var summary: Dictionary = {"photos": rows.size(), "top3": top3, "picked_right": picked,
		"step_right_when_part_right": steps_right, "median_ms": middle, "slowest_ms": slowest,
		"rows": rows}
	var file := FileAccess.open(_out + "/bench%s.json" % ("" if only.is_empty() else "_" + only),
		FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "  "))
	file.close()
	print("\npartstep_bench: %d photos; the right part in the top 3: %d (%d%%), named first: %d; the right step when the part was named: %d of %d; photo to step median %d ms, slowest %d ms" % [
		rows.size(), top3, roundi(100.0 * top3 / maxi(rows.size(), 1)), picked, steps_right, picked,
		middle, slowest])
	if (only.is_empty() and rows.size() < 30) or top3 * 10 < rows.size() * 8 or steps_right < picked or slowest > 3000:
		_failures += 1


func _open(id: String, text: String, called: String) -> Node:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": id, "name": called, "author": "Bench",
		"parts": 100, "url": "https://brickworks.diy/m/" + id, "model": text}}
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_viewing", id)
	main.set("_shared", fake)
	root.add_child(main)
	var view: ShareView = null
	var since: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < 300000:
		await process_frame
		view = main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	print("%s opened as a link: %s in %d s" % [called, view.state if view != null else "no viewer",
		(Time.get_ticks_msec() - since) / 1000])
	var steps: StepsBar = main.get("_steps")
	since = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 300000:
		await process_frame
	await _frames(20)
	return main


func _build_it(main: Node) -> BuildMode:
	main.call("_enter_build", 1)
	var mode: BuildMode = main.get("_build_mode")
	var since: int = Time.get_ticks_msec()
	while not mode.is_open() and Time.get_ticks_msec() - since < 300000:
		await process_frame
	await _frames(20)
	return mode


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
