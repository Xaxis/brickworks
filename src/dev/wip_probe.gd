## Share progress: work in progress shared from the studio by version
## (2026-11-23, unit buildlog; api/_wip.js, supabase/wip.sql).
##
##   godot --headless --path . --script src/dev/wip_probe.gd
##   PROBE_SIZE=1280x800 tools/probe.sh wip_probe        windowed, its pictures
##
## A model was shared when it was finished, so the months it took to build
## were seen by nobody. Now the share panel has Share progress beside
## Publish: the same publish marked work in progress, listed with the
## designer's name so their followers see it and its Talk thread gets a post.
## Here, with api/share.js played by a stand-in that answers as the server
## does (wip, finished, talk), and the real toolbar and panel pressed as a
## person presses them:
##
##   1. Two presses: the toolbar's Share, then Share progress. What is sent
##      is the model with wip true, listed and credited (the designer's
##      profile name), and the panel says where it went and that Talk has
##      the post. Publish then reads Publish as finished.
##   2. The next version: Share progress again, with What changed? said:
##      wip true, the link's id and the note sent; the status says the
##      versions' own line of what changed, word for word.
##   3. Publish as finished: wip false, and the panel says it is the
##      finished one; Publish reads Update the link again.
##   4. Opened again on a link the server says is work in progress, the
##      panel says so and Publish reads Publish as finished.
##   5. Under 13: Share progress is off, and says why; pressed, nothing is
##      sent.
##
## It loads on a build from before (what is new is asked for by name), so
## that build fails its checks rather than failing to load. Pictures in
## shots/wip/, named by the window's size: 1_shared, 3_finished.
extends SceneTree

const SHOTS := "res://shots/wip/"
const CRANE := "res://vendor/omr/files/4096-1_Crane.mpd"
## The link's id. Not ID: inside FakeShared, SharedModels' own ID would be
## the one meant.
const LINK_ID := "W1pPr0b3x1"
const NOTE := "The jib is on"
const SAID := "Version 2: 60 parts added in steps 4–6."
const PROFILE := "Probe Builder"

var _failures: int = 0
var _main: Node
var _size: String = ""
var _presses: int = 0


## api/share.js as the server answers a publish: each version numbered from
## the last, work in progress while asked, finished by the first publish
## without it, and the post Talk took.
class FakeShared extends SharedModels:
	var published: Array[Dictionary] = []
	var version: int = 0
	var wip_now: bool = false
	var listed_wip: bool = false

	func publish(_token: String, body: Dictionary) -> Dictionary:
		published.append(body.duplicate())
		await (Engine.get_main_loop() as SceneTree).process_frame
		version += 1
		var asked: bool = bool(body.get("wip", false))
		var finished: bool = wip_now and not asked
		wip_now = asked
		var answer: Dictionary = {"id": LINK_ID, "url": "https://brickworks.diy/m/" + LINK_ID, "parts": 120,
			"listed": bool(body.get("listed", false)), "version": version, "updated": version > 1,
			"author": PROFILE if body.has("author") else null, "wip": asked, "finished": finished,
			"said": SAID if version == 2 else ""}
		if asked or finished:
			answer["talk"] = {"thread": 7, "post": 10 + version, "made": true, "url": "https://brickworks.diy/talk/t/7"}
		return {"code": 200 if version > 1 else 201, "body": answer}

	func mine(_token: String) -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		var shared: Array = []
		if version > 0:
			shared.append({"id": LINK_ID, "published": true, "listed": true, "barred": false, "wip": listed_wip,
				"name": "Probe Crane"})
		return {"code": 200, "body": {"shared": shared, "credit": {"name": PROFILE, "handle": "probe-builder"}}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	var text: String = FileAccess.get_file_as_string(CRANE)
	if text.is_empty():
		print("wip_probe: SKIPPED, no %s (tools/fetch_data.sh)" % CRANE)
		quit(3)
		return
	var fake := FakeShared.new()
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_shared", fake)
	root.add_child(_main)
	for _n: int in 240:
		await process_frame
	var account: Account = _main.get("_account")
	var store: ModelStore = _main.get("_store")
	var shell: Shell = _main.get("_shell")
	var bar: ModelBar = _main.get("_bar")
	await account.deployment.wait()
	account.email = "probe.builder@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.over_13 = true
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var opened: Dictionary = store.open_text(text, "Probe Crane")
	bar.opened.emit(int(opened["placed"]))
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty():
			break
	await _settle()
	var panel: SharePanel = _main.get("_share_panel")
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()

	print("\n1. two presses: the toolbar's Share, then Share progress (%s)" % _size)
	var share: Control = shell.toolbar.controls_by_name().get("tool_share") if shell.toolbar != null else null
	_ok(share != null, "the toolbar has Share")
	if share == null:
		_finish()
		return
	await _press(share)
	await _settle()
	_ok(panel.visible, "Share opens the panel")
	var progress: Button = panel.controls_by_name().get("share_progress")
	_ok(progress != null and progress.is_visible_in_tree() and progress.text == "Share progress" and not progress.disabled,
		"Share progress is beside Publish: %s" % ("missing" if progress == null else "“%s”%s" % [progress.text,
			" (off)" if progress.disabled else ""]))
	if progress == null:
		_finish()
		return
	await _press(progress)
	await _published(panel, 1)
	var first: Dictionary = fake.published.back() if not fake.published.is_empty() else {}
	_ok(_presses == 2 and fake.published.size() == 1, "published in %d presses (%d sent)" % [_presses, fake.published.size()])
	_ok(first.get("wip", false) == true and first.get("listed", false) == true,
		"sent as work in progress, listed: wip %s, listed %s" % [first.get("wip"), first.get("listed")])
	_ok(str(first.get("author", "")) == PROFILE, "credited by the designer's profile: “%s”" % first.get("author", ""))
	_ok(str(first.get("model", "")).contains("4096"), "the model itself sent (%d characters)" % str(first.get("model", "")).length())
	var said: Dictionary = panel.page_state()
	_ok(said.get("wip", false) == true and str(said.get("status", "")).contains("work in progress")
		and str(said.get("status", "")).contains("Its Talk thread has the post."),
		"the panel says where it went: %s" % said.get("status", ""))
	_ok(str(said.get("publish_text", "")) == "Publish as finished", "Publish now reads “%s”" % said.get("publish_text", ""))
	await _save("1_shared")

	print("\n2. the next version, What changed? said")
	var note: LineEdit = panel.controls_by_name().get("share_note")
	_ok(note != null, "What changed? is there for the next version")
	if note != null:
		note.text = NOTE
	await _press(progress)
	await _published(panel, 2)
	var second: Dictionary = fake.published.back()
	_ok(second.get("wip", false) == true and str(second.get("id", "")) == LINK_ID and str(second.get("note", "")) == NOTE,
		"sent as the link's next version, work in progress, with its note: wip %s, id %s, note “%s”" % [
			second.get("wip"), second.get("id", ""), second.get("note", "")])
	_ok(str(panel.page_state().get("status", "")).contains(SAID),
		"the status says what changed as the versions do: %s" % panel.page_state().get("status", ""))

	print("\n3. Publish as finished")
	var publish: Button = panel.controls_by_name().get("share_publish")
	await _press(publish)
	await _published(panel, 3)
	var third: Dictionary = fake.published.back()
	said = panel.page_state()
	_ok(third.get("wip", true) == false, "sent without work in progress: wip %s" % third.get("wip"))
	_ok(str(said.get("status", "")).contains("Version 3 is the finished one") and said.get("wip", true) == false,
		"the panel says it is finished: %s" % said.get("status", ""))
	_ok(str(said.get("publish_text", "")) == "Update the link", "Publish reads “%s” again" % said.get("publish_text", ""))
	await _save("3_finished")

	print("\n4. opened again on a link that is work in progress")
	panel.visible = false
	fake.listed_wip = true
	store.share_id = LINK_ID
	panel.open()
	for _n: int in 60:
		await process_frame
	said = panel.page_state()
	_ok(said.get("wip", false) == true and str(said.get("publish_text", "")) == "Publish as finished"
		and str(said.get("status", "")).contains("Shared as work in progress"),
		"the panel knows it: %s, “%s”" % [said.get("status", ""), said.get("publish_text", "")])

	print("\n5. under 13")
	panel.visible = false
	account.over_13 = false
	panel.open()
	await _settle()
	said = panel.page_state()
	var sent: int = fake.published.size()
	_ok(said.get("progress_disabled", false) == true, "Share progress is off: %s" % progress.tooltip_text)
	await panel.publish(true)
	_ok(fake.published.size() == sent, "pressed anyway, nothing is sent (%d)" % (fake.published.size() - sent))
	_finish()


## Until the panel has published [n] in all, or 30 s.
func _published(panel: SharePanel, n: int) -> void:
	var fake: FakeShared = _main.get("_shared")
	for _n: int in 1800:
		await process_frame
		if fake.published.size() >= n and panel.state in ["published", "failed"]:
			break
	await _settle()


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


var _mouse_at := Vector2.ZERO


func _move(at: Vector2, mask: int) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = _as_event(at - _mouse_at)
	event.button_mask = mask
	_mouse_at = at
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


## A press where a person presses: on the control's middle, counted.
func _press(control: Control) -> void:
	_presses += 1
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at, 0)
	await process_frame
	_button(at, true)
	await process_frame
	_button(at, false)
	await _settle()


## Viewport coordinates as the window's, which an event carries.
func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _save(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		var file: String = "%s_%s.png" % [_size, name]
		image.save_png(ProjectSettings.globalize_path(SHOTS + file))
		print("  wrote shots/wip/%s" % file)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("\nwip_probe: %s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
	for _n: int in 5:
		await process_frame
	quit(1 if _failures > 0 else 0)
