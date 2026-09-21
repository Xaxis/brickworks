## Temporary review probe: do HUD controls overlap each other?
extends SceneTree

func _initialize() -> void:
	_run()

func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 60:
		await process_frame

	var gizmo: Control = main.get("_gizmo")
	var chat: Control = main.get("_chat")
	var chat_dock: Control = main.get("_chat_dock")
	var bin_dock: Control = main.get("_bin_dock")
	print("window ", DisplayServer.window_get_size())
	print("gizmo rect ", gizmo.get_global_rect(), " filter=", gizmo.mouse_filter)
	print("chat dock rect ", chat_dock.get_global_rect())
	print("bin dock rect ", bin_dock.get_global_rect())

	# force the composer on, as it is for anyone with a key
	var composer: Control = chat.get("_composer")
	var key_form: Control = chat.get("_key_form")
	var gate: Control = chat.get("_gate")
	composer.visible = true
	key_form.visible = false
	gate.visible = false
	for _n: int in 4:
		await process_frame
	_walk(composer, gizmo.get_global_rect(), "composer")
	print("--- key form state ---")
	composer.visible = false
	key_form.visible = true
	for _n: int in 4:
		await process_frame
	_walk(key_form, gizmo.get_global_rect(), "keyform")

	# hint strip clipping
	var hint: Control = _find(main, "ControlsHint")
	if hint != null:
		print("hint rect ", hint.get_global_rect(), " parent ",
			(hint.get_parent() as Control).get_global_rect())
	quit(0)

func _find(node: Node, cls: String) -> Control:
	if node.get_class() == cls or (node.get_script() != null and node.is_class("Control") and node is ControlsHint):
		return node as Control
	for child: Node in node.get_children():
		var found: Control = _find(child, cls)
		if found != null:
			return found
	return null

func _walk(node: Node, box: Rect2, tag: String) -> void:
	if node is Button or node is LinkButton or node is LineEdit:
		var control: Control = node
		var rect: Rect2 = control.get_global_rect()
		var hit: Rect2 = rect.intersection(box)
		if hit.size.x > 0.0 and hit.size.y > 0.0:
			var share: float = (hit.size.x * hit.size.y) / maxf(rect.size.x * rect.size.y, 1.0)
			print("  %s OVERLAP %.0f%% of %s '%s' rect=%s" % [
				tag, share * 100.0, control.get_class(),
				control.get("text") if control.has_method("get") else "", rect])
	for child: Node in node.get_children():
		_walk(child, box, tag)
