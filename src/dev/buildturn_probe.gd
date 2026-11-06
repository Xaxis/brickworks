## Build it turns the model as its booklet does (docs/APP_UX5.md, unit 1 buildturn), on a phone.
##
##   godot --path . --resolution 390x844 --script src/dev/buildturn_probe.gd
##   PROBE_SIZE=1280x720 tools/probe.sh buildturn_probe     any other window
##
## The booklet turns the model where its designer turned it, a ROTSTEP's
## roll and all, and turns it over at a step whose parts go on from below
## (rotroll). Build it looked from the turn's direction with the camera
## upright, so the sports car's step 6, two plates pressed up under its
## chassis, was a view from above with the plates out of sight. Each of
## these is the bar, measured:
##
##   1. The sports car opened as a shared link and built in Build it, page
##      by page, each page's view (where the camera is and which way is up
##      on the screen, as it is drawn) against its booklet page's
##      (BookletStudio.basis_for of the booklet's own layout): within 1
##      degree where the booklet turns the model; where it does not, the
##      camera upright on the direction it always had (0 degrees), and no
##      page turned that the booklet draws upright.
##   2. Step 6 shown turned over, the eye under the model and its underside
##      up on the screen; its new parts in sight, in pixels of the very
##      frame, at least as much of them as the booklet's own picture of the
##      page shows (BookletStudio.measure_all, the booklet's measure). The
##      lights turned with it, so the underside is lit as a top is, and the
##      floor put aside, which seen from under the model covered all of it.
##   3. A finger's drag on the turned page turns the view, still turned;
##      Next then goes to the next page's own view; and Close leaves the
##      model upright, the lights and the floor as they were.
##   4. 7140's cart, turned over by its author's ROTSTEP roll, the same in
##      the real app.
##   5. Every page of the 44 files of LDraw's model repository whose authors
##      turn the model (rotroll's validation), and the sports car, each
##      against its booklet page's layout, through the camera's own code.
##   6. The castle's pages, none turned: which are turned over is worked
##      out a little a frame while the model is looked at, no frame of it
##      past a page turn's 60 ms, and no page's view working it out.
##
## The new parts in sight are counted as the booklet counts them, by what
## is drawn where: unshaded, edges unsmoothed, on a background no part is;
## and again through a parallel lens, as the booklet draws, which says how
## much of any gap is Build it's perspective.
##
## Pictures in shots/buildturn/, named by the window's size.
extends SceneTree

const CAR := "res://models/sports_car.ldr"
const CART := "res://vendor/omr/files/7140-1.mpd"
const FILES := "res://vendor/omr/files/"
const CASTLE := "res://models/castle.ldr"
const SHOTS := "res://shots/buildturn/"
## Within this much of the booklet's view, in degrees.
const WITHIN := 1.0
## The 44 files whose authors turn the model over (rotroll,
## bench/results/rotroll-2026-11-05/validation/).
const TURNED := ["1572-1.mpd", "20009-1.mpd", "20019-1.mpd", "20021-1.mpd", "30051-1.mpd",
	"30052-1.mpd", "30055-1.mpd", "30542-1_Turkey.mpd", "30571-1.mpd", "358-1.mpd", "42084-1.mpd",
	"4837-1_Locomotive.mpd", "4837-1_Steam-Train.mpd", "4837-1_Train.mpd", "5540-1_Plane.mpd",
	"5934-1.mpd", "5973-1.mpd", "6822-1.mpd", "6870-1.mpd", "6927-1.mpd", "6929-1.mpd",
	"6991-1.mpd", "7131-1.mpd", "7140-1.mpd", "7141-1.mpd", "7150-1.mpd", "7667-1.mpd",
	"8028-1.mpd", "8029-1.mpd", "8031-1.mpd", "8033-1.mpd", "8154-1.mpd", "8258-1.mpd",
	"8272-1.mpd", "8273-1.mpd", "8273-1_Utility-Cargo-Truck.mpd", "8274-1_Dragstar.mpd",
	"8274-1.mpd", "8275-1.mpd", "891-1.mpd", "894-1.mpd", "918-1.mpd", "924-1.mpd", "928-1.mpd"]

var _failures: int = 0
var _size: String = ""
## The sun as it stands for the model upright, read as Build it opens.
var _sun_rest: Basis = Basis.IDENTITY


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
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var size: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [size.x, size.y]
	var car: String = FileAccess.get_file_as_string(CAR)
	if car.is_empty():
		print("buildturn_probe: SKIPPED, no %s" % CAR)
		quit(3)
		return
	print("buildturn_probe: a %s window" % _size)
	BuildSteps._kept.clear()

	print("\n1. the sports car in Build it, page by page against its booklet")
	var main: Node = await _open("Bu1ldTurn", car, "the sports car")
	var booklet: Dictionary = await _booklet_of(main.get("_world"), main.get("_library"),
		(main.get("_store") as ModelStore).scenery)
	_sun_rest = (main.get_node("Sun") as Node3D).basis
	var mode: BuildMode = await _build_it(main)
	var pages: BuildSteps = main.get("_build_pages")
	_ok(mode.is_open() and pages != null, "Build it opens the step player")
	if pages == null:
		await _close(main)
		_finish()
		return
	var over: int = await _every_page(main, pages, booklet, "the sports car")
	_ok(over > 0, "the booklet turns the sports car over at step %d" % over)

	if over > 0:
		print("\n2. step %d turned over, its new parts in sight" % over)
		await _turned_over(main, pages, booklet, over)
		print("\n3. a drag on it, Next, and Close")
		await _drag_next_close(main, pages, booklet, over)
	await _close(main)

	print("\n4. 7140's cart, turned over by its author's roll, in Build it")
	var cart: String = FileAccess.get_file_as_string(CART)
	if cart.is_empty():
		_ok(false, "no %s" % CART)
	else:
		main = await _open("Bu1ldCart", cart, "7140")
		booklet = await _booklet_of(main.get("_world"), main.get("_library"),
			(main.get("_store") as ModelStore).scenery)
		mode = await _build_it(main)
		pages = main.get("_build_pages")
		if pages != null:
			var turned: int = await _every_page(main, pages, booklet, "7140", true)
			_ok(turned > 0, "7140 has pages its author turned over (the first: %d)" % turned)
			if turned > 0:
				main.call("_build_go", turned)
				await _arrive(main)
				await _shot("4_7140_page_%d" % turned)
		var library: PartLibrary = main.get("_library")
		await _close(main)

		print("\n5. every page of the 44 files whose authors turn the model, and the sports car")
		await _files(library, car)
		print("\n6. the castle's pages turned over a little a frame, none in a page turn")
		await _castle_paced(library)
	_finish()


## The castle (2,497 parts, 400 steps, none of its designer's turns): which
## of its pages are turned over worked out a little a frame
## (BuildSteps.work_out_turns), each frame's own time on the main thread
## under a page turn's 60 ms; and a page's view, asked before and after,
## never working it out itself (it was 195 ms for the eight baseplates of
## step 1, asked in the page's view).
func _castle_paced(library: PartLibrary) -> void:
	var world := BrickWorld.new()
	world.library = library
	root.add_child(world)
	for piece: LdrModel.Placement in LdrModel.load_file(CASTLE).flatten(library.parts):
		var id: String = piece.part_id.to_lower().trim_suffix(".dat")
		if library.mesh_for(id) == null:
			continue
		var brick_id: int = world.add_brick(id, piece.color_code, piece.transform)
		world.get_brick(brick_id).group = piece.group
		world.get_brick(brick_id).unit = piece.unit
	var pages: BuildSteps = BuildSteps.of(world, library, Instructions.plan(world, library))
	if not pages.has_method("work_out_turns"):
		_ok(false, "the castle's pages turned over a little a frame: no BuildSteps.work_out_turns")
		world.queue_free()
		return
	var viewed: Array = []
	for page: int in range(1, pages.last() + 1):
		var span := ProbeTime.Span.new()
		pages.view(page)
		viewed.append(span.end())
	var frames: Array = []
	var since: int = Time.get_ticks_msec()
	pages.call("work_out_turns")
	var span := ProbeTime.Span.new()
	while not pages.call("turns_known") and Time.get_ticks_msec() - since < 60000:
		await process_frame
		frames.append(span.end())
		span = ProbeTime.Span.new()
	var took: float = (Time.get_ticks_msec() - since) / 1000.0
	var slowest: ProbeTime.Span = ProbeTime.slowest(frames)
	var bar: float = 60.0 * ProbeTime.slack(ProbeTime.busiest(frames))
	_ok(pages.call("turns_known") and slowest.own < bar,
		"the castle's %d pages: which are turned over known in %.1f s over %d frames, the longest %.1f ms of its own, under %.0f (%s)"
			% [pages.last(), took, frames.size(), slowest.own, bar, slowest.said()])
	var before: ProbeTime.Span = ProbeTime.slowest(viewed)
	viewed.clear()
	for page: int in range(1, pages.last() + 1):
		var one := ProbeTime.Span.new()
		pages.view(page)
		viewed.append(one.end())
	var after: ProbeTime.Span = ProbeTime.slowest(viewed)
	var view_bar: float = 20.0 * ProbeTime.slack(ProbeTime.busiest(viewed))
	_ok(before.own < view_bar and after.own < view_bar,
		"...a page's view %.1f ms of its own at most before, %.1f after, under %.0f"
			% [before.own, after.own, view_bar])
	world.queue_free()
	await process_frame


# -- 1. page by page ------------------------------------------------------------


## The booklet's own layout of [param world] (BookletMaker.lay_out_only):
## {"plan": its steps, "entries": step index -> its entry}.
func _booklet_of(world: BrickWorld, library: PartLibrary, scenery: Dictionary) -> Dictionary:
	BookletMaker.open_when_written = false
	var maker := BookletMaker.new()
	maker.library = library
	root.add_child(maker)
	var laid: Array[Booklet.Page] = await maker.lay_out_only(world, scenery, "Probe")
	var entries: Dictionary = {}
	for page: Booklet.Page in laid:
		for entry: Booklet.Entry in page.entries:
			var all: Array = [entry]
			if entry.callout != null:
				all.append_array(entry.callout.steps)
			for one: Booklet.Entry in all:
				if one.has_meta("step") and not entries.has(int(one.get_meta("step"))):
					entries[int(one.get_meta("step"))] = one
	var plan: Array[Instructions.Step] = maker.plan
	maker.queue_free()
	return {"plan": plan, "entries": entries}


## Whether the booklet turns [param entry]: its designer's turn, or over.
static func _turns(entry: Booklet.Entry) -> bool:
	return entry.fixed or entry.turn != Basis.IDENTITY


## Each page of Build it put on screen ([param main]'s own _build_go) and
## its camera read as it is drawn, against the booklet's page: within
## WITHIN degrees, eye and up, where the booklet turns the model; upright
## on the page's own direction where it does not. The first page the
## booklet turns over (its up down on the screen), or 0.
func _every_page(main: Node, pages: BuildSteps, booklet: Dictionary, called: String,
		authored: bool = false) -> int:
	var camera: CadCamera = main.get("_camera")
	var plan: Array = booklet["plan"]
	var entries: Dictionary = booklet["entries"]
	# Which pages are turned over is worked out while the model is looked
	# at (BuildSteps.work_out_turns): every one known before they are read.
	var since: int = Time.get_ticks_msec()
	while pages.has_method("turns_known") and not pages.call("turns_known") \
			and Time.get_ticks_msec() - since < 60000:
		await process_frame
	if pages.has_method("turns_known"):
		_ok(pages.call("turns_known"), "%s: which pages are turned over known %.1f s after Build it opened"
			% [called, (Time.get_ticks_msec() - since) / 1000.0])
	var same: bool = plan.size() == pages.steps.size()
	for index: int in mini(plan.size(), pages.steps.size()):
		same = same and (plan[index] as Instructions.Step).brick_ids == pages.steps[index].brick_ids
	_ok(same, "%s: Build it's %d pages are the booklet's %d steps" % [called, pages.last(), plan.size()])
	var turned: int = 0
	var matched: int = 0
	var upright: int = 0
	var wrong := PackedStringArray()
	var first_over: int = 0
	var worst: float = 0.0
	for page: int in range(1, pages.last() + 1):
		if not entries.has(page - 1):
			continue
		var entry: Booklet.Entry = entries[page - 1]
		main.call("_build_go", page)
		await _arrive(main)
		var drawn: Basis = camera.global_transform.basis.orthonormalized()
		if _turns(entry):
			turned += 1
			var want: Basis = BookletStudio.basis_for(entry.from, entry.turn)
			var off: float = maxf(_degrees(drawn.z, want.z), _degrees(drawn.y, want.y))
			worst = maxf(worst, off)
			if off <= WITHIN:
				matched += 1
			else:
				wrong.append("%d %.1f°" % [page, off])
			if first_over == 0 and want.y.y < 0.0 and (not authored or entry.fixed):
				first_over = page
		else:
			var view: Dictionary = pages.view(page)
			var want: Basis = BookletStudio.basis_for(view["from"])
			var off: float = maxf(_degrees(drawn.z, want.z), _degrees(drawn.y, want.y))
			var turned_now: bool = camera.has_method("is_turned") and bool(camera.call("is_turned"))
			if off <= 0.05 and not turned_now:
				upright += 1
			else:
				wrong.append("%d upright %.2f°" % [page, off])
	_ok(turned > 0 and matched == turned, "%s: %d of %d pages the booklet turns seen as it turns them, eye and up within %.0f° (worst %.2f°)%s"
		% [called, matched, turned, WITHIN, worst, "" if wrong.is_empty() else ": " + ", ".join(wrong)])
	var others: int = pages.last() - turned
	_ok(upright == others, "%s: the %d pages it does not turn upright, on the direction they always had (0°): %d"
		% [called, others, upright])
	return first_over


## The camera at rest where Build it sent it: a few frames with nothing
## moving, two seconds at most.
func _arrive(main: Node) -> void:
	var camera: CadCamera = main.get("_camera")
	var was := Transform3D()
	var still: int = 0
	var since: int = Time.get_ticks_msec()
	while still < 3 and Time.get_ticks_msec() - since < 4000:
		await process_frame
		if camera.global_transform.is_equal_approx(was):
			still += 1
		else:
			still = 0
		was = camera.global_transform
	await process_frame


static func _degrees(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(a.normalized().angle_to(b.normalized()))


# -- 2. the turned page ----------------------------------------------------------


func _turned_over(main: Node, pages: BuildSteps, booklet: Dictionary, page: int) -> void:
	var camera: CadCamera = main.get("_camera")
	var world: BrickWorld = main.get("_world")
	main.call("_build_go", page - 1)
	await _arrive(main)
	var sun: DirectionalLight3D = main.get_node("Sun")
	var sun_before: Vector3 = camera.global_transform.basis.inverse() * sun.global_transform.basis.z
	await _shot("2_step_%d_before" % (page - 1))
	main.call("_build_go", page)
	await _arrive(main)
	await _shot("2_step_%d_turned" % page)
	var eye: Basis = camera.global_transform.basis.orthonormalized()
	_ok(eye.y.y < -0.3 and eye.z.y < -0.3,
		"step %d seen from under the model, its underside up on the screen (the eye %.2f below, the screen's up %.2f down)"
			% [page, -eye.z.y, -eye.y.y])
	var sun_now: Vector3 = camera.global_transform.basis.inverse() * sun.global_transform.basis.z
	_ok(_degrees(sun_now, sun_before) < WITHIN,
		"...lit as a top is: the sun where it was on the screen at step %d (%.1f° off)"
			% [page - 1, _degrees(sun_now, sun_before)])
	var floor: Node3D = main.get("_floor")
	var plates: Array = world.call("batches_only_of", (main.get("_store") as ModelStore).scenery) \
		if world.has_method("batches_only_of") else []
	var plates_hidden: bool = plates.all(func(node: Node3D) -> bool: return not node.visible)
	_ok(floor != null and not floor.visible and plates_hidden,
		"...the floor put aside, its grid, shadow and %d plate batches" % plates.size())

	# Pixels of the step's new parts in the very frame, and drawn alone; and
	# the same through a parallel lens, as the booklet draws (CadCamera's
	# own square_on), which says what of any gap is the lens.
	var seen: Array = await _seen_in_frame(main, pages, page)
	var share: float = float(seen[0]) / maxf(float(seen[1]), 1.0)
	var square: Array = await _seen_in_frame(main, pages, page, true)
	var square_share: float = float(square[0]) / maxf(float(square[1]), 1.0)
	var printed: float = await _seen_in_booklet(main, booklet, page)
	_ok(seen[1] > 0 and share >= printed - 0.005,
		"its new parts in sight: %d of their %d pixels, %.1f%% (%.1f%% through a parallel lens, as the booklet draws); the booklet's page shows %.1f%% of them"
			% [seen[0], seen[1], share * 100.0, square_share * 100.0, printed * 100.0])
	await _shot("2_step_%d_turned_again" % page)


## How many pixels of [param page]'s new parts the frame shows, and how
## many it would were nothing in front of them: the frame with the parts
## and without, then the parts alone and nothing, compared pixel by pixel.
## Drawn as the booklet measures, by what is where and not how it is lit:
## unshaded, no smoothing of edges (a pixel is one part's or none's), on a
## background no part is, the outline off. Through a parallel lens with
## [param square] (CadCamera.square_on). The page put back after.
func _seen_in_frame(main: Node, pages: BuildSteps, page: int, square: bool = false) -> Array:
	var world: BrickWorld = main.get("_world")
	var camera: CadCamera = main.get("_camera")
	var outline: Node = main.get("_build_outline")
	var look: Environment = (main.get_node("WorldEnvironment") as WorldEnvironment).environment
	var kept: Array = [root.debug_draw, root.msaa_3d, root.screen_space_aa, root.use_taa,
		look.background_mode, look.background_color, outline.get("visible")]
	root.debug_draw = Viewport.DEBUG_DRAW_UNSHADED
	root.msaa_3d = Viewport.MSAA_DISABLED
	root.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.use_taa = false
	look.background_mode = Environment.BG_COLOR
	look.background_color = Color(1.0, 0.0, 1.0)
	outline.set("visible", false)
	if square:
		camera.square_on(true)
	var with: Image = await _frame()
	world.reveal_upto(pages.order, pages.count(page - 1), int(main.get("_build_key")))
	var without: Image = await _frame()
	world.show_only(pages.fresh(page))
	var alone: Image = await _frame()
	world.show_only({-1: true})
	var nothing: Image = await _frame()
	if square:
		camera.square_on(false)
	root.debug_draw = kept[0]
	root.msaa_3d = kept[1]
	root.screen_space_aa = kept[2]
	root.use_taa = kept[3]
	look.background_mode = kept[4]
	look.background_color = kept[5]
	outline.set("visible", kept[6])
	main.call("_build_go", page)
	await _arrive(main)
	return [_differ(with, without), _differ(alone, nothing)]


func _frame() -> Image:
	for _n: int in 4:
		await process_frame
	RenderingServer.force_draw(false)
	return root.get_texture().get_image()


static func _differ(a: Image, b: Image) -> int:
	var count: int = 0
	for y: int in a.get_height():
		for x: int in a.get_width():
			var p: Color = a.get_pixel(x, y)
			var q: Color = b.get_pixel(x, y)
			if absf(p.r - q.r) + absf(p.g - q.g) + absf(p.b - q.b) > 0.06:
				count += 1
	return count


## The share of [param page]'s new parts the booklet's own picture of the
## page shows (BookletStudio.measure_all, which the booklet chooses its
## views by), on a stage of the booklet's own, as it turns the page.
func _seen_in_booklet(main: Node, booklet: Dictionary, page: int) -> float:
	var world: BrickWorld = main.get("_world")
	var entry: Booklet.Entry = booklet["entries"][page - 1]
	var plan: Array = booklet["plan"]
	var order: Array = []
	var first: int = 0
	var last: int = 0
	for index: int in plan.size():
		if index == page - 1:
			first = order.size() + 1
		for brick_id: int in (plan[index] as Instructions.Step).brick_ids:
			var brick: BrickWorld.Brick = world.get_brick(brick_id)
			order.append([brick_id, brick.part_id, brick.color_code, brick.transform])
		if index == page - 1:
			last = order.size()
	var studio := BookletStudio.new()
	studio.library = main.get("_library")
	root.add_child(studio)
	var stage: BookletStudio.Stage = studio.stage(order)
	var size := Vector2i(360, 270)
	var extent: Rect2 = BookletStudio.extent(stage.boxes.slice(0, last), entry.from, entry.turn)
	var scale: float = minf(size.x * 0.9 / maxf(extent.size.x, 1.0), size.y * 0.9 / maxf(extent.size.y, 1.0))
	var view := BookletStudio.View.new(entry.from, extent.get_center(), scale, entry.turn)
	var shares: Array = await studio.measure_all([[stage, last, first, view, size]])
	studio.queue_free()
	return float(shares[0])


# -- 3. a drag, Next, Close -------------------------------------------------------


func _drag_next_close(main: Node, pages: BuildSteps, booklet: Dictionary, page: int) -> void:
	var camera: CadCamera = main.get("_camera")
	var mode: BuildMode = main.get("_build_mode")
	main.call("_build_go", page)
	await _arrive(main)
	var before: Basis = camera.global_transform.basis.orthonormalized()
	var free: Rect2 = mode.free_rect()
	var middle: Vector2 = free.get_center()
	await _swipe(middle - Vector2(free.size.x * 0.2, 0.0), middle + Vector2(free.size.x * 0.2, 0.0))
	await _arrive(main)
	var after: Basis = camera.global_transform.basis.orthonormalized()
	var turned_by: float = _degrees(after.z, before.z)
	_ok(turned_by > 10.0 and int(main.get("_build_page")) == page,
		"a finger's drag across step %d turns the view %.0f° and stays on the page" % [page, turned_by])
	_ok(after.y.y < 0.0, "...still turned over: the screen's up %.2f down, turned about the model's own turned up"
		% -after.y.y)
	await _shot("3_step_%d_dragged" % page)
	await _tap(mode.controls_by_name()["build_next"])
	await _arrive(main)
	var next: int = int(main.get("_build_page"))
	var drawn: Basis = camera.global_transform.basis.orthonormalized()
	var entry: Booklet.Entry = booklet["entries"].get(next - 1)
	var want: Basis = BookletStudio.basis_for(entry.from, entry.turn) if entry != null and _turns(entry) \
		else BookletStudio.basis_for(pages.view(next)["from"])
	var off: float = maxf(_degrees(drawn.z, want.z), _degrees(drawn.y, want.y))
	_ok(next == page + 1 and off <= WITHIN,
		"Next goes to step %d at its own view (%.2f° off; up %.2f)" % [next, off, drawn.y.y])
	await _shot("3_step_%d_next" % next)
	# Back on the turned page, then Close.
	main.call("_build_go", page)
	await _arrive(main)
	await _tap(mode.controls_by_name()["build_close"])
	await _arrive(main)
	var left: Basis = camera.global_transform.basis.orthonormalized()
	var sun: DirectionalLight3D = main.get_node("Sun")
	var floor: Node3D = main.get("_floor")
	_ok(not mode.is_open() and left.y.y > 0.3 and not (camera.has_method("is_turned")
			and bool(camera.call("is_turned"))),
		"Close leaves the model upright (the screen's up %.2f up)" % left.y.y)
	_ok(sun.basis.is_equal_approx(_sun_rest) and floor != null and floor.visible,
		"...the lights and the floor as they were")
	await _shot("3_closed")


# -- 5. the files ----------------------------------------------------------------


## Every page of each file Build it would show, against its booklet page:
## the booklet laid out (BookletMaker.lay_out_only), Build it's pages made
## from the same steps (BuildSteps.of), and a camera of the app's own
## pointed as Build it points it (CadCamera.look_from).
func _files(library: PartLibrary, car: String) -> void:
	var camera := CadCamera.new()
	root.add_child(camera)
	var texts: Array = [["sports_car.ldr", car]]
	for name: String in TURNED:
		texts.append([name, FileAccess.get_file_as_string(FILES + name)])
	var files: int = 0
	var turned: int = 0
	var matched: int = 0
	var upright: int = 0
	var unturned: int = 0
	var worst: float = 0.0
	var worst_at: String = ""
	var wrong := PackedStringArray()
	var started: int = Time.get_ticks_msec()
	for named: Array in texts:
		var text: String = named[1]
		if text.is_empty():
			wrong.append("%s missing" % named[0])
			continue
		var world := BrickWorld.new()
		world.library = library
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
		await process_frame
		store.open_text(text, str(named[0]))
		var booklet: Dictionary = await _booklet_of(world, library, store.scenery)
		var plan: Array[Instructions.Step] = booklet["plan"]
		var entries: Dictionary = booklet["entries"]
		var pages: BuildSteps = BuildSteps.of(world, library, plan, store.scenery)
		if pages.has_method("work_out_turns"):
			await pages.call("work_out_turns", 1000.0)
		var own: int = 0
		var digest := PackedStringArray()
		for index: int in plan.size():
			if not entries.has(index):
				continue
			var entry: Booklet.Entry = entries[index]
			var view: Dictionary = pages.view(index + 1)
			var up: Vector3 = view.get("up", Vector3.UP)
			if camera.get_method_argument_count("look_from") >= 2:
				camera.call("look_from", view["from"], up)
			else:
				camera.call("look_from", view["from"])
			camera.call("_apply", 1.0)
			var drawn: Basis = camera.global_transform.basis.orthonormalized()
			if _turns(entry):
				turned += 1
				own += 1
				var want: Basis = BookletStudio.basis_for(entry.from, entry.turn)
				var off: float = maxf(_degrees(drawn.z, want.z), _degrees(drawn.y, want.y))
				if off > worst:
					worst = off
					worst_at = "%s step %d" % [named[0], index + 1]
				if off <= WITHIN:
					matched += 1
				elif wrong.size() < 12:
					wrong.append("%s %d %.1f°" % [named[0], index + 1, off])
			else:
				unturned += 1
				var from: Vector3 = view["from"]
				digest.append("%.4f,%.4f,%.4f" % [from.x, from.y, from.z])
				var want: Basis = BookletStudio.basis_for(from)
				var off: float = maxf(_degrees(drawn.z, want.z), _degrees(drawn.y, want.y))
				if off <= 0.05 and up.is_equal_approx(Vector3.UP):
					upright += 1
				elif wrong.size() < 12:
					wrong.append("%s %d upright %.2f°" % [named[0], index + 1, off])
		files += 1
		# The pages it does not turn, as directions: the same before and
		# after this unit (a page with no turn unchanged).
		print("    %s: %d steps, %d turned by the booklet; unturned %s" % [named[0], plan.size(), own,
			"%08x" % ("|".join(digest)).hash()])
		pages = null
		builder.queue_free()
		world.queue_free()
		await process_frame
	camera.queue_free()
	_ok(files == texts.size(), "%d files of %d opened (%.0f s)" % [files, texts.size(),
		(Time.get_ticks_msec() - started) / 1000.0])
	_ok(turned > 0 and matched == turned,
		"%d of %d pages the booklet turns seen as it turns them, within %.0f° (worst %.2f°, %s)%s"
			% [matched, turned, WITHIN, worst, worst_at, "" if wrong.is_empty() else ": " + ", ".join(wrong)])
	_ok(upright == unturned, "%d of %d pages it does not turn upright, on the direction they always had"
		% [upright, unturned])


# -- the app ------------------------------------------------------------------------


func _open(id: String, text: String, called: String) -> Node:
	var fake := FakeShared.new()
	fake.answer = {"code": 200, "body": {"id": id, "name": "Probe Model", "author": "Probe Builder",
		"parts": 93, "url": "https://brickworks.diy/m/" + id, "model": text}}
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_viewing", id)
	main.set("_shared", fake)
	root.add_child(main)
	var view: ShareView = null
	for _n: int in 2400:
		await process_frame
		view = main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	_ok(view != null and view.state == "ready", "%s opened as a shared link (%s)" % [called,
		view.state if view != null else "no viewer"])
	var steps: StepsBar = main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _frames(20)
	return main


func _close(main: Node) -> void:
	main.queue_free()
	await process_frame
	await process_frame


func _finish() -> void:
	print("\nbuildturn_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## Build it tapped on the viewer's bar, and the step player up.
func _build_it(main: Node) -> BuildMode:
	var view: ShareView = main.get("_share_view")
	await _tap(view.controls_by_name()["view_build"])
	var mode: BuildMode = main.get("_build_mode")
	var since: int = Time.get_ticks_msec()
	while not mode.is_open() and Time.get_ticks_msec() - since < 60000:
		await process_frame
	await _settle()
	return mode


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _settle() -> void:
	await _frames(12)
	await RenderingServer.frame_post_draw


## A finger's tap on [param control]: down and up where it is.
func _tap(control: Control) -> void:
	var at: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = _as_event(at)
		Input.parse_input_event(touch)
		await process_frame
	await _settle()


## A finger dragged from [param from] to [param to], slowly enough to turn.
func _swipe(from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 0
	down.pressed = true
	down.position = _as_event(from)
	Input.parse_input_event(down)
	await process_frame
	for n: int in 16:
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _as_event(from.lerp(to, float(n + 1) / 16.0))
		drag.relative = _as_event((to - from) / 16.0)
		Input.parse_input_event(drag)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0
	up.pressed = false
	up.position = _as_event(to)
	Input.parse_input_event(up)
	await _settle()


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	root.get_texture().get_image().save_png("%s%s_%s.png" % [SHOTS, _size, name])


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
