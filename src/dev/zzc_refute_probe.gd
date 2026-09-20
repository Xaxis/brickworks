## Temporary: what the assistant panel shows after "Or sign in" is
## clicked while the account service is unreachable.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	OwnKey.forget()

	# Exactly the state Account.boot() leaves behind when the probe
	# request fails: not available, signed out. Not added to the tree, so
	# _ready/boot never fire and no real request goes out.
	var account := Account.new()
	account.available = false
	account.state = Account.State.SIGNED_OUT

	var panel := ChatPanel.new()
	root.add_child(panel)
	await process_frame
	panel.watch(account)
	await process_frame

	var composer: Control = panel.get("_composer")
	var keyform: Control = panel.get("_key_form")
	var gate: Control = panel.get("_gate")
	var status: Label = panel.get("_status")
	print("before: composer=%s keyform=%s gate=%s status=%s" % [
		composer.visible, keyform.visible, gate.visible, status.text])

	var link: LinkButton = null
	for child: Node in keyform.get_children():
		if child is LinkButton and (child as LinkButton).text.begins_with("Or sign in"):
			link = child
	if link == null:
		print("FAIL no sign-in link")
		quit(1)
		return
	print("link visible=%s" % link.visible)
	link.pressed.emit()
	await process_frame

	print("after:  composer=%s keyform=%s gate=%s status=%s" % [
		composer.visible, keyform.visible, gate.visible, status.text])
	print("showing_sign_in=%s" % panel.get("_showing_sign_in"))

	# Anything at all left to click below the header?
	var visible_controls: Array[String] = []
	_walk(panel, visible_controls)
	print("still visible: %s" % ", ".join(visible_controls))

	# Does the service coming back rescue it, without a restart?
	account.available = true
	account.changed.emit()
	await process_frame
	print("recovered: composer=%s keyform=%s gate=%s" % [
		composer.visible, keyform.visible, gate.visible])
	quit(0)


func _walk(node: Node, into: Array[String]) -> void:
	for child: Node in node.get_children():
		if child is Control and not (child as Control).visible:
			continue
		if child is Button or child is LineEdit or child is TextEdit:
			var label: String = child.get("text") if child is Button else "<field>"
			into.append("%s(%s)" % [child.get_class(), label])
		_walk(child, into)
