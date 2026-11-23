## The rare row and its swaps on a phone, by finger (rsreview, kept by
## rsfix): every target 44 points or more and inside the window; a touch
## anywhere on a swap's row picks or unpicks it (F10: a finger lands on the
## words); each box named with what it swaps and into what (F11); Swap by
## touch, one undo step.
##
##   godot --path . --resolution 430x932 --script src/dev/rsreview_phone_probe.gd
##
## RSR_OUT=DIR keeps its pictures.
extends "res://src/dev/copyfaults_probe.gd"


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	create_timer(900.0).timeout.connect(func() -> void:
		print("rsreview phone probe: not finished in time")
		quit(1))
	Phone._on = 1
	Phone._wide = false
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(120)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	if DisplayServer.get_name() != "headless":
		(_main.get("_phone") as Node).set("holds_scale", true)
		for link: Dictionary in root.size_changed.get_connections():
			var call: Callable = link["callable"]
			if call.get_method() == &"_match_screen_density":
				root.size_changed.disconnect(call)
		var main_script: GDScript = _main.get_script()
		root.content_scale_factor = main_script.sized_factor(Room.across(), Room.down(), true,
			DisplayServer.screen_get_scale())
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_store = _main.get("_store")
	_store.keeps = false
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	await _frames(20)
	print("window %s, content scale %.2f, per point %.2f" % [root.get_visible_rect().size,
		root.content_scale_factor, Phone.per_point(root)])
	var bar: ModelBar = _main.get("_bar")
	var opened: Dictionary = await bar.open_text_with_progress(
		FileAccess.get_file_as_string("res://src/dev/fixtures/rareswap_kept.mpd"), "kept")
	bar.opened.emit(int(opened.get("placed", 0)))
	await _frames(20)
	_shell.run("parts_list")
	await _frames(20)
	var list: InventoryPanel = _main.get("_inventory")
	var shots: String = OS.get_environment("RSR_OUT")
	_targets("the parts list", list, ["parts_rare"])
	await _shot(shots, "phone_list.png")
	var row: Button = list.controls_by_name().get("parts_rare")
	if row == null:
		_check("phone: the rare row shows", false)
		quit(1)
		return
	# By finger: a touch at the row's middle.
	await _touch(row.get_global_rect().get_center())
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until and not list.controls_by_name().has("parts_swap_row"):
		await process_frame
	await _frames(10)
	_check("phone: a touch on the rare row opens the swaps", list.controls_by_name().has("parts_swap_row"))
	var boxes: Array = []
	for each: Node in (list.get("_swaps") as Node).get_children():
		if each.get_child_count() > 0 and each.get_child(0) is CheckBox:
			boxes.append(each.get_child(0))
	var names: Dictionary = {"parts_swap": list.controls_by_name().get("parts_swap"),
		"parts_swap_back": list.controls_by_name().get("parts_swap_back")}
	for n: int in boxes.size():
		names["box %d" % n] = boxes[n]
	_targets("the swaps", list, [], names)
	var said := PackedStringArray()
	var unsaid := PackedStringArray()
	for box: CheckBox in boxes:
		said.append("%s: %s" % [box.accessibility_name, box.accessibility_description])
		if box.accessibility_name.is_empty() or box.accessibility_description.is_empty():
			unsaid.append(str(box.get_meta("lot").get("key")))
	print("box names: %s" % said)
	_check("phone: every swap box named with what it swaps and into what (%d boxes)%s" % [boxes.size(),
		"" if unsaid.is_empty() else ": none for " + ", ".join(unsaid)], not boxes.is_empty() and unsaid.is_empty())
	await _shot(shots, "phone_swaps.png")
	# A box toggled by a touch on its row's words (a finger lands on the words).
	var target: CheckBox = null
	for box: CheckBox in boxes:
		if not box.disabled:
			target = box
			break
	if target != null:
		var was: bool = target.button_pressed
		var words: Control = target.get_parent().get_child(target.get_parent().get_child_count() - 1)
		await _touch(words.get_global_rect().get_center())
		print("touch on the words: box %s -> %s" % [was, target.button_pressed])
		_check("phone: a touch on a swap's words picks or unpicks it", target.button_pressed != was)
		await _touch(target.get_global_rect().get_center())
		print("touch on the box: box -> %s" % target.button_pressed)
		_check("phone: a touch on the box itself toggles it back", target.button_pressed == was)
		# Then picked, so Swap has one to swap whatever the defaults picked.
		if not target.button_pressed:
			await _touch(words.get_global_rect().get_center())
	_check("phone: one swap picked to swap", target != null and target.button_pressed)
	var swap: Button = list.controls_by_name().get("parts_swap")
	var depth: int = _builder.history_depth()
	_check("phone: Swap shown and pressable", swap != null and not swap.disabled)
	if swap != null and not swap.disabled:
		_check("phone: Swap is inside the window (%s in %s)" % [swap.get_global_rect(), root.get_visible_rect()],
			root.get_visible_rect().encloses(swap.get_global_rect()))
		await _touch(swap.get_global_rect().get_center())
		until = Time.get_ticks_msec() + 20000
		while Time.get_ticks_msec() < until and _builder.history_depth() == depth:
			await process_frame
		_check("phone: a touch on Swap swaps (%d undo steps)" % (_builder.history_depth() - depth),
			_builder.history_depth() == depth + 1)
	await _shot(shots, "phone_after.png")
	print("\nrsreview phone probe: %s" % ("all checks passed" if _failures == 0
		else "%d checks failed" % _failures))
	quit(1 if _failures > 0 else 0)


func _targets(what: String, list: Control, named: Array, controls: Dictionary = {}) -> void:
	for n: String in named:
		controls[n] = list.call("controls_by_name").get(n)
	var small := PackedStringArray()
	var least: float = INF
	for n: String in controls:
		var control: Control = controls[n]
		if control == null or not control.is_visible_in_tree():
			small.append("%s not shown" % n)
			continue
		var size: Vector2 = control.size / Phone.per_point(root)
		least = minf(least, minf(size.x, size.y))
		if size.x < Phone.TARGET - 0.5 or size.y < Phone.TARGET - 0.5:
			small.append("%s %.0fx%.0f" % [n, size.x, size.y])
	_check("phone: %s, %d targets each 44 points or more (least %.1f)%s" % [what, controls.size(), least,
		"" if small.is_empty() else ": " + ", ".join(small)], small.is_empty())
	_check("phone: %s wholly in the window (%s in %s)" % [what, list.get_global_rect(), root.get_visible_rect()],
		root.get_visible_rect().grow(0.5).encloses(list.get_global_rect()))


func _touch(at: Vector2) -> void:
	# A finger, as carryrest_probe touches: a screen touch in the window's
	# pixels, which Godot hands on as a mouse press too.
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	var where: Vector2 = at * (window / rect) if window.x > 0.0 and rect.x > 0.0 else at
	for down: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.pressed = down
		touch.position = where
		Input.parse_input_event(touch)
		await _frames(3)
	await _frames(6)


func _shot(dir: String, file: String) -> void:
	if dir.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dir.path_join(file))
