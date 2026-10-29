## The model library's cover pictures: each model opened as the app opens a
## file and drawn built, from the three-quarter view, by the app's own
## ModelShot, as a 512 x 384 WebP (tools/library_build.py covers starts it).
##
##   gpu xvfb-run -a godot --path . --resolution 640x480 \
##     --script src/dev/library_covers.gd -- --list=FILE --out=DIR [--most=N]
##
## FILE has one model a line, "<path of its .mpd><TAB><id>". Each whose
## DIR/<id>.webp or DIR/<id>.failed is not there yet is opened and drawn; a
## model with no picture gets the .failed, saying why, so a second run does
## not try it again. It leaves after N models (all of them by default), or
## once it has held the GPU for HOLD_MS when another job waits for it, and the
## builder starts it again on a fresh lease: a lease is held for seconds,
## never for the whole library.
##
## With --clear and --cards=DIR, the website's pictures of each (library333,
## tools/library_build.py pictures): the model with nothing behind it, as a
## shared model's page and card have theirs (SharePanel), so it sits on the
## site's own ground in its light theme and its dark one alike. One drawing
## a model, at CLEAR_DRAWN: DIR/<id>.webp its page's (PAGE), and the cards'
## DIR/<id>.webp (CARD), each four to three.
extends SceneTree

const COVER := Vector2i(512, 384)
## Room round the model, as a share of the picture's longer side.
const MARGIN := 0.06
## What ModelShot draws behind the model (its environment's colour), which
## is what a picture's empty rows and columns are.
const GROUND := Color(0.93, 0.94, 0.96)
const QUALITY := 0.82
## How long a drawer keeps the lease when another job waits for it: about
## what starting one costs, and a model is drawn in 0.1 to 6 s. Leaving
## after every model when the GPU was busy drew one model a lease, each
## behind the queue again (2026-10-22).
const HOLD_MS := 20000
## The website's pictures (--clear): a page's and a card's, four to three as
## the site's frames are, the card's the size of a shared model's
## (SharePanel.THUMB), from a drawing twice ModelShot's own size, so a page's
## is drawn down, never up.
const PAGE := Vector2i(1200, 900)
const CARD := Vector2i(480, 360)
const CLEAR_DRAWN := 2048
## What a pixel's alpha must be over to be the model's.
const SOLID := 0.06


func _initialize() -> void:
	_run()


func _arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix + "="):
			return a.substr(prefix.length() + 1)
	return ""


func _run() -> void:
	await process_frame
	var list: String = _arg("--list")
	var out: String = _arg("--out")
	var clear: bool = OS.get_cmdline_user_args().has("--clear")
	var cards: String = _arg("--cards")
	if clear and not DirAccess.dir_exists_absolute(cards):
		print("library_covers: --clear writes the cards' pictures to --cards=DIR")
		quit(2)
		return
	var most: int = int(_arg("--most")) if not _arg("--most").is_empty() else 1 << 30
	if not FileAccess.file_exists(list) or not DirAccess.dir_exists_absolute(out):
		print("library_covers: give --list=FILE and --out=DIR")
		quit(2)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var library := PartLibrary.new()
	if not library.load_catalogue():
		print("library_covers: no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = library
	world.keeps_history = false
	root.add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = library
	root.add_child(builder)
	var store := ModelStore.new()
	store.world = world
	store.library = library
	store.builder = builder
	store.keeps = false
	# Only looked at, as the shared model's viewer opens one: the lattice
	# that a move needs is never told of the parts.
	store.lattice_later = true
	var shot := ModelShot.new()
	shot.library = library
	shot.rulers = false
	shot.give_up_after = 60.0
	root.add_child(shot)
	await process_frame
	if clear:
		# Drawn on nothing, larger: its viewport made now rather than at the
		# first picture, and given the frames it wants before it draws
		# (ModelShot._take).
		shot._build()
		for _n: int in 4:
			await process_frame
		shot._viewport.size = Vector2i(CLEAR_DRAWN, CLEAR_DRAWN)
		shot._viewport.transparent_bg = true
		shot._viewport.world_3d.environment.background_mode = Environment.BG_CLEAR_COLOR

	var drawn: int = 0
	var failed: int = 0
	var since: int = Time.get_ticks_msec()
	for line: String in FileAccess.get_file_as_string(list).split("\n", false):
		var bits: PackedStringArray = line.split("\t")
		if bits.size() < 2:
			continue
		var path: String = bits[0]
		var id: String = bits[1]
		var webp: String = out.path_join(id + ".webp")
		var fail: String = out.path_join(id + ".failed")
		if FileAccess.file_exists(webp) or FileAccess.file_exists(fail):
			continue
		if drawn + failed >= most or (Time.get_ticks_msec() - since > HOLD_MS and _others_wait()):
			print("library_covers: leaving the GPU after %d" % (drawn + failed))
			break
		print("library_covers: opening %s" % id)
		var began: int = Time.get_ticks_msec()
		var why: String = ""
		if clear:
			why = await _clear(path, webp, cards.path_join(id + ".webp"), store, world, shot)
		else:
			why = await _cover(path, webp, store, world, shot)
		if why.is_empty():
			drawn += 1
			print("library_covers: %s %d parts in %d ms" % [id, world.brick_count(),
				Time.get_ticks_msec() - began])
		else:
			failed += 1
			var note: FileAccess = FileAccess.open(fail, FileAccess.WRITE)
			note.store_string(why + "\n")
			note.close()
			print("library_covers: %s NO PICTURE: %s" % [id, why])
	print("library_covers: %d drawn, %d without a picture" % [drawn, failed])
	quit(0)


## Draws one; an empty string, or why there is no picture.
func _cover(path: String, webp: String, store: ModelStore, world: BrickWorld,
		shot: ModelShot) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "could not read " + path
	var opened: Dictionary = await store.open_text_fetched(text, path.get_file().get_basename())
	if int(opened.get("placed", 0)) == 0:
		return "nothing placed: " + str(opened.get("error", ""))
	var image: Image = await shot.take(world, "corner", store.scenery)
	if image == null:
		return "ModelShot gave no picture"
	var cover: Image = framed(image)
	if cover.save_webp(webp, true, QUALITY) != OK:
		return "could not write " + webp
	return ""


## Draws one with nothing behind it: its page's picture at [param page] and its
## card's at [param card]. An empty string, or why there is no picture.
func _clear(path: String, page: String, card: String, store: ModelStore, world: BrickWorld,
		shot: ModelShot) -> String:
	var text: String = FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "could not read " + path
	var opened: Dictionary = await store.open_text_fetched(text, path.get_file().get_basename())
	if int(opened.get("placed", 0)) == 0:
		return "nothing placed: " + str(opened.get("error", ""))
	var image: Image = await shot.take(world, "corner", store.scenery)
	if image == null:
		return "ModelShot gave no picture"
	image.convert(Image.FORMAT_RGBA8)
	var big: Image = cut(image, PAGE)
	var small: Image = big.duplicate()
	small.resize(CARD.x, CARD.y, Image.INTERPOLATE_LANCZOS)
	if big.save_webp(page, true, QUALITY) != OK or small.save_webp(card, true, QUALITY) != OK:
		return "could not write " + page
	return ""


## [param image], drawn on nothing, cut round the model and set in a picture
## of [param size] with a margin, on nothing (framed, by alpha).
static func cut(image: Image, size: Vector2i) -> Image:
	var whole: Vector2i = image.get_size()
	var small: Image = image.duplicate()
	const LOOK := 256
	small.resize(LOOK, LOOK, Image.INTERPOLATE_BILINEAR)
	var low := Vector2i(LOOK, LOOK)
	var high := Vector2i(-1, -1)
	for y: int in LOOK:
		for x: int in LOOK:
			if small.get_pixel(x, y).a > SOLID:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y))
	var box := Rect2(Vector2.ZERO, Vector2(whole))
	if high.x >= 0:
		var scale: Vector2 = Vector2(whole) / float(LOOK)
		box = Rect2(Vector2(low) * scale, Vector2(high - low + Vector2i.ONE) * scale)
	box = box.grow(maxf(box.size.x, box.size.y) * MARGIN)
	var aspect: float = float(size.x) / float(size.y)
	if box.size.x / box.size.y < aspect:
		box = box.grow_individual((box.size.y * aspect - box.size.x) * 0.5, 0.0,
			(box.size.y * aspect - box.size.x) * 0.5, 0.0)
	else:
		box = box.grow_individual(0.0, (box.size.x / aspect - box.size.y) * 0.5,
			0.0, (box.size.x / aspect - box.size.y) * 0.5)
	var at := Rect2i(box.position.round(), box.size.round())
	var canvas := Image.create(at.size.x, at.size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var inside: Rect2i = at.intersection(Rect2i(Vector2i.ZERO, whole))
	canvas.blit_rect(image, inside, inside.position - at.position)
	canvas.resize(size.x, size.y, Image.INTERPOLATE_LANCZOS)
	return canvas


## The model cut from its square picture and set in a 4:3 one with a margin,
## on the ground it was drawn on. Where the model is comes from a small copy,
## which is quick to look through and loses nothing a margin does not cover.
static func framed(image: Image) -> Image:
	image.convert(Image.FORMAT_RGB8)
	var size: Vector2i = image.get_size()
	var small: Image = image.duplicate()
	const LOOK := 128
	small.resize(LOOK, LOOK, Image.INTERPOLATE_BILINEAR)
	var low := Vector2i(LOOK, LOOK)
	var high := Vector2i(-1, -1)
	for y: int in LOOK:
		for x: int in LOOK:
			var c: Color = small.get_pixel(x, y)
			if absf(c.r - GROUND.r) + absf(c.g - GROUND.g) + absf(c.b - GROUND.b) > 0.03:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y))
	var box := Rect2(Vector2.ZERO, Vector2(size))
	if high.x >= 0:
		var scale: Vector2 = Vector2(size) / float(LOOK)
		box = Rect2(Vector2(low) * scale, Vector2(high - low + Vector2i.ONE) * scale)
	# A margin, then widened or heightened to 4:3 about the model's middle.
	var side: float = maxf(box.size.x, box.size.y) * MARGIN
	box = box.grow(side)
	var aspect: float = float(COVER.x) / float(COVER.y)
	if box.size.x / box.size.y < aspect:
		box = box.grow_individual((box.size.y * aspect - box.size.x) * 0.5, 0.0,
			(box.size.y * aspect - box.size.x) * 0.5, 0.0)
	else:
		box = box.grow_individual(0.0, (box.size.x / aspect - box.size.y) * 0.5,
			0.0, (box.size.x / aspect - box.size.y) * 0.5)
	var whole := Rect2i(box.position.round(), box.size.round())
	var canvas := Image.create(whole.size.x, whole.size.y, false, Image.FORMAT_RGB8)
	canvas.fill(GROUND)
	var inside: Rect2i = whole.intersection(Rect2i(Vector2i.ZERO, size))
	canvas.blit_rect(image, inside, inside.position - whole.position)
	canvas.resize(COVER.x, COVER.y, Image.INTERPOLATE_LANCZOS)
	return canvas


## Whether another job waits for the GPU's lease, as src/dev/draw_shots.gd asks.
static func _others_wait() -> bool:
	var dir: String = OS.get_environment("BOX_GPU_DIR")
	var queue: String = (dir if not dir.is_empty() else "/tmp/box-gpu").path_join("queue")
	return DirAccess.dir_exists_absolute(queue) and not DirAccess.get_files_at(queue).is_empty()
