## View > Default view puts the view back: on an empty model too (walk180 A2).
##
##   godot --headless --path . --script src/dev/default_view_probe.gd
##
## On an empty baseplate the view is easy to lose: zoomed into empty space
## and slid away, nothing is on screen but grey. Default view turned the
## camera back to its usual angle and kept the lost focus and zoom, so it
## still showed nothing; only Fit found the baseplate again. Studio's Home
## frames the build area.
##
## So: a new model, the view lost as a person loses it (zoomed in at the
## pointer, then slid off), then Default view from the View menu's command
## and from its key, 0. Each time the view must come back to where Fit
## puts it on the same model, at the default angle.
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 90:
		await process_frame
	var bar: Node = main.get("_bar")
	var shell: Shell = main.get("_shell")
	var camera: CadCamera = main.get("_camera")
	var world: BrickWorld = main.get("_world")
	if bar == null or shell == null or camera == null:
		print("default_view_probe: the scene did not come up")
		quit(1)
		return
	await bar.call("_start_new")
	await _frames(30)
	var scenery: Dictionary = main.get("_store").scenery
	_ok(world.brick_count() == scenery.size(), "a new model: nothing built (%d parts, %d of them the ground)"
		% [world.brick_count(), scenery.size()])

	# Where Fit puts the view on this model, at the default angle.
	camera.set_view("default")
	shell.run("fit")
	await _settled(camera)
	var home: Array = _now(camera)
	print("     (Fit: focus %s, %.0f LDU away)" % [home[0], home[1]])

	for how: String in ["the View menu's Default view", "its key, 0"]:
		await _lose(camera)
		var lost: Array = _now(camera)
		_ok(lost[0].distance_to(home[0]) > 100.0 or absf(lost[1] - home[1]) > 100.0,
			"the view lost: focus %s, %.0f LDU away" % [lost[0], lost[1]])
		if how.begins_with("its key"):
			for down: bool in [true, false]:
				var key := InputEventKey.new()
				key.keycode = KEY_0
				key.physical_keycode = KEY_0
				key.pressed = down
				Input.parse_input_event(key)
				await process_frame
		else:
			_ok(shell.run("view_default"), "Default view runs")
		await _settled(camera)
		var back: Array = _now(camera)
		_ok(back[0].distance_to(home[0]) < 1.0 and absf(back[1] - home[1]) < 1.0,
			"%s: back where Fit puts it (focus %s, %.0f LDU away; Fit's %s, %.0f)" % [how, back[0], back[1],
				home[0], home[1]])
		_ok(absf(float(camera.get("_target_yaw")) - deg_to_rad(-35.0)) < 0.01
				and absf(float(camera.get("_target_pitch")) - deg_to_rad(26.0)) < 0.01,
			"%s: at the default angle" % how)

	print("\ndefault_view_probe: %s" % ("all passed" if _failures == 0 else "%d failed" % _failures))
	quit(1 if _failures else 0)


## Lost as a person loses it: zoomed in a long way at a spot off the
## baseplate, then slid well away.
func _lose(camera: CadCamera) -> void:
	var size: Vector2 = root.get_visible_rect().size
	for _n: int in 12:
		camera.zoom_by_drag(-200.0, Vector2(size.x * 0.9, size.y * 0.1))
		await process_frame
	for _n: int in 6:
		camera.slide_by_drag(Vector2(size.x * 0.6, size.y * 0.4))
		await process_frame
	camera.turn_by_drag(Vector2(300, -120))
	await _settled(camera)


func _now(camera: CadCamera) -> Array:
	return [camera.get("_target_focus") as Vector3, float(camera.get("_target_distance"))]


func _settled(camera: CadCamera) -> void:
	for _n: int in 90:
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _ok(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
