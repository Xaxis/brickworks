## Is the look left as it is where frames are quick, and lowered where slow?
##
##   tools/probe.sh look_probe
##   ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a \
##     --server-args="-screen 0 1280x800x24" godot --path . --resolution 1280x800 \
##     --script src/dev/look_probe.gd
##   ... -- --shots=DIR    and the window at three views written to DIR, for a
##                         byte compare with a checkout before (this same file
##                         runs there: it asks for the frame budget by name)
##   ... -- --model=res://models/castle.ldr   a big model (2,438 parts)
##
## A frame drawn in software costs a second whatever is in it, and the app
## now lowers what it draws when its frames are slow (FrameBudget). Where
## they are quick, nothing may change: the owner's look is the app's look.
##
## 1. The judgment by itself, on a budget of its own fed frame times: quick
##    frames cut nothing; slow ones the ladder's first cut, much slower ones
##    more at once; each cut is what the frame stops drawing (glow off,
##    multisampling off, the sun casting no shadow and lit to match), and
##    letting a check's cuts go puts every one back.
## 2. This machine: Main up as the app runs, drawing only what changed and
##    its budget watching, the house opened. After the first look (frames
##    drawn on purpose and timed), on a graphics card the frames are judged
##    under the budget and nothing is cut; in software (llvmpipe) the look
##    is lowered. Which it is comes from the adapter's name, and is said.
##    Compatibility on the card: Xvfb has no OpenGL of its own, so it goes
##    through Mesa's zink, OpenGL ES on the card's Vulkan (GALLIUM_DRIVER=zink
##    MESA_LOADER_DRIVER_OVERRIDE=zink MESA_VK_DEVICE_SELECT=1002:73df
##    MESA_VK_DEVICE_SELECT_FORCE_DEFAULT_DEVICE=1 before godot, and
##    --rendering-method gl_compatibility); without it, llvmpipe draws it.
## 3. With --shots, the window at three views once the first look is over.
##    On the graphics card, run here and in a checkout without FrameBudget,
##    the pictures are the same byte for byte (cmp).
## 4. A look timed by fences, as on the web, on a card of a speed the
##    probe chooses: a quick one, the drawing held inside the look as
##    GpuFence holds it while the parts bin's pictures are read back, is
##    judged quick and cuts nothing on the graphics card; a slow one is
##    judged after a few frames, never more than two of them ahead of it.
extends SceneTree

const MODEL := "res://models/house.ldr"

var _failures: int = 0
var _main: Node


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _arg(prefix: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix + "="):
			return arg.trim_prefix(prefix + "=")
	return ""


func _run() -> void:
	await process_frame
	var adapter: String = RenderingServer.get_video_adapter_name()
	var software: bool = adapter.to_lower().contains("llvmpipe") or adapter.to_lower().contains("lavapipe") \
		or adapter.to_lower().contains("swiftshader")
	print("  %s, %s (%s)" % [RenderingServer.get_current_rendering_method(), adapter,
		"software" if software else "a graphics card"])
	var budget_script: Script = load("res://src/render/frame_budget.gd") \
		if ResourceLoader.exists("res://src/render/frame_budget.gd") else null
	if budget_script != null:
		await _judgment(budget_script)
	else:
		print("  (no FrameBudget in this checkout: the judgment is not checked)")

	# 2. The app as it runs: drawing only what changed (IdleDraw), which Main
	# leaves off in a probe unless the probe turned it on first.
	OS.low_processor_usage_mode = true
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 10:
		await process_frame
	var budget: Node = _main.get_node_or_null("FrameBudget")
	if budget != null:
		budget.call("watch")
	var model: String = _arg("--model") if not _arg("--model").is_empty() else MODEL
	var placed: int = int(_main.call("_open", model))
	var opened_at: int = Time.get_ticks_msec()
	print("  %s, %d parts" % [model.get_file(), placed])
	var world: BrickWorld = _main.get("_world")
	var library: PartLibrary = _main.get("_library")
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 120000:
		await process_frame
		var waiting: bool = false
		for brick: BrickWorld.Brick in world.bricks():
			if library.mesh_for(brick.part_id) == null:
				waiting = true
				break
		if not waiting:
			break
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var camera: CadCamera = _main.get("_camera")
	camera.frame(world.model_bounds())
	# The first look: two seconds after the budget began watching, frames
	# drawn on purpose and timed.
	var waited: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - waited < 60000:
		await process_frame
		if budget == null:
			if Time.get_ticks_msec() - waited > 5000:
				break
			continue
		var told: Dictionary = budget.call("page_state")
		if int(told["looks"]) > 0 and int(told["looking"]) == 0 and not (told["timed"] as Array).is_empty():
			break
	_check("the app's frame budget is there and watching", budget != null and bool(budget.get("watching")))
	if budget != null:
		var told: Dictionary = budget.call("page_state")
		var timed: Array = told["timed"]
		var cuts: Array = told["cuts"]
		print("    frames timed %s ms; judged %s; cuts %s" % [str(timed), str(told["judged"]), str(cuts)])
		_check("the first look timed frames (%d)" % timed.size(), timed.size() >= 4)
		if software:
			_check("drawn in software, the look is lowered (%s)" % str(cuts), not cuts.is_empty())
		else:
			# Judged as the app judges, by the second fastest of the last
			# six: Compatibility on the card (through zink, under Xvfb) drew
			# two of its first six in 48 and 75 ms, building its programs,
			# and the rest in 17 to 27.
			var most: float = 0.0
			for ms: Variant in timed:
				most = maxf(most, float(ms))
			var judged_ms: float = float(told["cost"])
			_check("on a graphics card the frames are judged quick (%.1f ms of %.0f; the worst %.1f)"
				% [judged_ms, float(budget_script.get("SLOW_MS")), most],
				judged_ms >= 0.0 and judged_ms < float(budget_script.get("SLOW_MS")))
			_check("and nothing is cut (%s)" % str(cuts), cuts.is_empty())
			var viewport: Viewport = root
			var environment: Environment = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
			var sun: DirectionalLight3D = _main.get_node("Sun")
			_check("the window still drawn four samples deep at full scale, with glow and the sun's shadow",
				viewport.msaa_3d == Viewport.MSAA_4X and is_equal_approx(viewport.scaling_3d_scale, 1.0)
				and environment.glow_enabled and sun.shadow_enabled)

	var shots: String = _arg("--shots")
	if not shots.is_empty():
		DirAccess.make_dir_recursive_absolute(shots)
		# The bar says "opened House — 71 bricks" for 4 s (ModelBar._say):
		# a first picture taken sooner on one run than the other differed
		# in the status line alone.
		while Time.get_ticks_msec() - opened_at < 5000:
			await process_frame
		var views: Array[Vector3] = [Vector3(1, 0.8, 1), Vector3(-1, 0.5, 0.6), Vector3(0.3, 1.4, -1)]
		for n: int in views.size():
			camera.look_from(views[n])
			camera.frame(world.model_bounds())
			await _settle()
			var image: Image = root.get_texture().get_image()
			var file: String = shots.path_join("view_%d.png" % n)
			image.save_png(file)
			print("    picture: %s" % file)
	if budget != null and budget_script.get("IN_FLIGHT") != null:
		await _fenced(budget, budget_script, software)
	print("look probe: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## 4. A card of [card].ms a frame: each fence passes that long after it was
## put in or after the card had done the one before it, whichever is later,
## as SwiftShader draws a page's frames one after another behind it.
## [card].ahead is the most frames the card was ever behind by.
func _fenced(budget: Node, budget_script: Script, software: bool) -> void:
	var card: Dictionary = {"ms": 2, "next": 1, "done": {}, "last": 0, "ahead": 0}
	var put := func() -> int:
		var now: int = Time.get_ticks_msec()
		var n: int = card["next"]
		card["next"] = n + 1
		var ahead: int = 1
		for m: int in card["done"]:
			if int(card["done"][m]) > now:
				ahead += 1
		card["ahead"] = maxi(int(card["ahead"]), ahead)
		card["last"] = maxi(now, int(card["last"])) + int(card["ms"])
		card["done"][n] = card["last"]
		return n
	var passed := func(n: int) -> bool:
		return Time.get_ticks_msec() >= int((card["done"] as Dictionary).get(n, 0))
	budget.call("fence_by", put, passed)
	var in_flight: int = int(budget_script.get("IN_FLIGHT"))
	var slow: float = float(budget_script.get("SLOW_MS"))

	# A quick card, the drawing stopped for three frames after the look's
	# fourth and let go.
	var cut_before: Array = (budget.get("cuts") as Array).duplicate()
	budget.call("look")
	var drawn: int = Engine.get_frames_drawn()
	while Engine.get_frames_drawn() < drawn + 4:
		await process_frame
	RenderingServer.render_loop_enabled = false
	for _n: int in 3:
		await process_frame
	RenderingServer.render_loop_enabled = true
	await _look_over(budget)
	var told: Dictionary = budget.call("page_state")
	print("    a quick card: timed %s ms by fences, %d frames ahead at most" % [str(told["timed"]), int(card["ahead"])])
	_check("a look timed by fences times its frames (%d)" % (told["timed"] as Array).size(),
		(told["timed"] as Array).size() >= 4)
	if not software:
		_check("on a graphics card, held inside the look, it is judged quick (%.1f ms) and cuts nothing (%s)"
			% [float(told["cost"]), str(told["cuts"])],
			float(told["cost"]) >= 0.0 and float(told["cost"]) < slow and str(told["cuts"]) == str(cut_before))

	# A slow card, 400 ms a frame: judged after SOON frames, not after a
	# dozen, with at most IN_FLIGHT of them drawn ahead.
	card["ms"] = 400
	card["ahead"] = 0
	var cut_at: int = (budget.get("cuts") as Array).size()
	var ladder: int = (told["ladder"] as Array).size()
	var judged_at: int = (budget.get("judged") as Array).size()
	var began: int = Time.get_ticks_msec()
	budget.call("look")
	while Time.get_ticks_msec() - began < 30000:
		await process_frame
		if (budget.get("judged") as Array).size() > judged_at or int(budget.get("looks")) > 0 \
				and int((budget.call("page_state") as Dictionary)["looking"]) == 0:
			break
	var took: int = Time.get_ticks_msec() - began
	var frames: int = int(budget_script.get("SOON"))
	told = budget.call("page_state")
	print("    a slow card: judged %s, %d ms after the look began, %d frames ahead at most" % [str(told["judged"]), took, int(card["ahead"])])
	_check("a slow card is never more than %d frames behind the look (%d)" % [in_flight, int(card["ahead"])],
		int(card["ahead"]) <= in_flight)
	if cut_at < ladder:
		_check("and is judged after %d of its frames, %d ms (bar %d), cutting two (%s)"
			% [frames, took, (frames + 1) * 400 + 500, str(told["cuts"])],
			took <= (frames + 1) * 400 + 500 and (told["cuts"] as Array).size() == mini(cut_at + 2, ladder))
	else:
		print("    (every rung was already cut: nothing for the slow card to judge)")


## Until the look in hand has timed its frames, or 30 s.
func _look_over(budget: Node) -> void:
	var began: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 30000:
		await process_frame
		if int((budget.call("page_state") as Dictionary)["looking"]) == 0:
			return


## Until nothing has been drawn for a second and a half, or 20 s.
func _settle() -> void:
	var began: int = Time.get_ticks_msec()
	var drawn: int = Engine.get_frames_drawn()
	var still: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - began < 20000:
		await process_frame
		if Engine.get_frames_drawn() != drawn:
			drawn = Engine.get_frames_drawn()
			still = Time.get_ticks_msec()
		elif Time.get_ticks_msec() - still > 1500:
			return


## 1. A budget of its own, on a viewport, environment and sun of its own.
func _judgment(budget_script: Script) -> void:
	var slow: float = float(budget_script.get("SLOW_MS"))
	var compat: Array = budget_script.call("ladder_for", "gl_compatibility", 1.0)
	var dense: Array = budget_script.call("ladder_for", "forward_plus", 3.0)
	_check("the web's ladder has no occlusion and, at one to one, nothing to make less dense (%s)" % str(compat),
		not compat.has("ssao") and not compat.has("dense") and compat.has("msaa"))
	_check("Forward+ at 3x cuts both (%s)" % str(dense), dense.has("ssao") and dense.has("dense"))
	var few: Array[float] = [10.0, 900.0, 12.0, 11.0, 13.0, 10.0]
	_check("a judgment is by the fastest fifth, so one long frame among quick ones is quick (%.0f)"
		% float(budget_script.call("judge", few)), float(budget_script.call("judge", few)) < slow)
	_check("frames under the budget cut nothing; over it one; at 4x and 16x it, two and three",
		int(budget_script.call("cuts_for", slow * 0.9)) == 0 and int(budget_script.call("cuts_for", slow * 2.0)) == 1
		and int(budget_script.call("cuts_for", slow * 5.0)) == 2 and int(budget_script.call("cuts_for", slow * 20.0)) == 3)

	var view := SubViewport.new()
	view.size = Vector2i(64, 64)
	view.msaa_3d = Viewport.MSAA_4X
	root.add_child(view)
	var environment := Environment.new()
	environment.glow_enabled = true
	environment.ssao_enabled = true
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_energy = 0.1
	view.add_child(sun)
	var budget: Node = budget_script.new()
	root.add_child(budget)
	budget.call("setup", view, environment, sun, 0.5)
	var ladder: Array = budget.call("page_state")["ladder"]
	for ms: float in [20.0, 22.0, 19.0, 21.0, 20.0, 23.0]:
		budget.call("take", ms)
	_check("six quick frames cut nothing (%s)" % str(budget.get("cuts")), (budget.get("cuts") as Array).is_empty())
	for ms: float in [120.0, 130.0, 110.0, 125.0, 118.0, 140.0]:
		budget.call("take", ms)
	var once: Array = budget.get("cuts")
	_check("six slow ones cut the ladder's first (%s of %s)" % [str(once), str(ladder)],
		once.size() == 1 and once[0] == ladder[0])
	for ms: float in [2000.0, 2100.0, 1900.0, 2050.0, 1980.0, 2200.0]:
		budget.call("take", ms)
	var more: Array = budget.get("cuts")
	_check("six frames of two seconds cut three more (%s)" % str(more),
		more.size() == 4 and str(more) == str(ladder.slice(0, 4)))
	# A look after the last rung could cut nothing, and its frames were drawn
	# while a person stood still (outline_check, 2026-10-19).
	var told: Dictionary = budget.call("page_state")
	if more.size() < ladder.size():
		_check("with a rung left, it looks again at once (%d frames to time)" % int(told["looking"]),
			int(told["looking"]) > 0)
		for ms: float in [2000.0, 2100.0, 1900.0, 2050.0, 1980.0, 2200.0]:
			budget.call("take", ms)
		more = budget.get("cuts")
		told = budget.call("page_state")
	_check("the last rung cut (%s), and no look after it (%d frames to time)" % [str(more), int(told["looking"])],
		more.size() == ladder.size() and int(told["looking"]) == 0)
	budget.call("pin", ["glow", "msaa", "shadow"] as Array[String])
	_check("pinned, glow is off, the view one sample deep, and the sun casts no shadow at its unshadowed energy",
		not environment.glow_enabled and view.msaa_3d == Viewport.MSAA_DISABLED
		and not sun.shadow_enabled and is_equal_approx(sun.light_energy, 0.5))
	budget.call("pin", [] as Array[String])
	_check("pinned to nothing, every one is back (glow, four samples, the sun's shadow at 0.1)",
		environment.glow_enabled and view.msaa_3d == Viewport.MSAA_4X and sun.shadow_enabled
		and is_equal_approx(sun.light_energy, 0.1) and environment.ssao_enabled)
	budget.queue_free()
	view.queue_free()
	await process_frame
