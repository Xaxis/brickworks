## The tab tools/bench/claudelink.py's sessions change a model in, and the
## person's Publish once a session has ended.
##
##   godot --headless --path . --script src/dev/claudelink_tab.gd -- --mcp=PORT \
##       --assistant=on --signed-in --publish-when=FILE --published=FILE
##
## The app as a person's signed-in connector tab, as tools/bench/realset.py
## --via relay starts one (its session.json in the run's own data folder, the
## relay at BRICKWORKS_API). No tool publishes a model: only the person shares
## (export_model's description says so). So once the session has ended and
## the run has written --publish-when's file, this does what the person's
## File › Share…, Publish does (SharePanel.publish, unlisted: the run's
## account is a throwaway, whose models no public list shows), and writes
## --published's file: {state, id, status, title, remixed_from,
## remixed_from_version, parts}. Then it quits. The names are this script's
## own, none the app reads (main.gd's _argument).
extends SceneTree

const WAIT_S := 3 * 3600


func _initialize() -> void:
	_run()


func _run() -> void:
	var when: String = _given("--publish-when=")
	var out: String = _given("--published=")
	if when.is_empty() or out.is_empty():
		printerr("claudelink_tab: --publish-when=FILE and --published=FILE")
		quit(2)
		return
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	var since: int = Time.get_ticks_msec()
	while not FileAccess.file_exists(when) and Time.get_ticks_msec() - since < WAIT_S * 1000:
		await create_timer(0.5).timeout
	var store: ModelStore = main.get("_store")
	var world: BrickWorld = main.get("_world")
	var said: Dictionary = {"title": store.title, "remixed_from": store.remixed_from,
		"remixed_from_version": store.remixed_from_version,
		"parts": world.brick_count() - store.scenery.size()}
	var panel: SharePanel = main.get("_share_panel") as SharePanel
	if panel == null:
		said["state"] = "no share panel"
	else:
		if not panel.visible:
			panel.open()
		panel._list.button_pressed = false
		await panel.publish()
		said.merge({"state": panel.state, "id": store.share_id, "status": panel._status.text}, true)
	var file := FileAccess.open(out, FileAccess.WRITE)
	file.store_string(JSON.stringify(said))
	file.close()
	print("claudelink_tab: %s" % JSON.stringify(said))
	quit(0)


func _given(prefix: String) -> String:
	for one: String in OS.get_cmdline_user_args():
		if one.begins_with(prefix):
			return one.trim_prefix(prefix)
	return ""
