## The card drawn as a photograph after the publish has answered (cardlook,
## 2026-11-23; src/ui/share_panel.gd _card_after, api/share.js op=card).
##
##   ~/.claude/claude-core/bin/gpu xvfb-run -a -s "-screen 0 1600x900x24" \
##       godot --path . --resolution 1400x900 --script src/dev/card_after_probe.gd
##
## The card had been drawn before the publish was sent, a second or two the
## person waited for. Now the publish goes with the cut-out, as it did
## before cardlook, and the photograph is drawn once it has answered and put
## on the link with op=card. Here, with api/share.js played by a stand-in
## that answers as the server does and times each request, the real panel
## publishes a house model twice:
##
##   1. Its publish sends the cut-out card (a WebP with clear pixels) and
##      answers with nothing drawn in between; then, after the answer, one
##      op=card for the same link puts a 480 x 360 opaque WebP, traced where
##      rays are traced, and the panel says the server took it.
##   2. Published again and a part moved at once: the model is not the one
##      published, so no card is put.
## In a window: a card needs one to draw in (CardPhoto.possible).
extends SceneTree

const MODEL := "res://models/sports_car.ldr"
const LINK_ID := "C4rdAft3r1"

var _failures: int = 0


## api/share.js as it answers: the publish and op=card, each timed.
class FakeShared extends SharedModels:
	var published: Array[Dictionary] = []
	var answered_at: Array[int] = []
	var cards: Array[Dictionary] = []

	func _fetch(path: String, method: int, _token: String, body: String) -> Dictionary:
		var tree: SceneTree = Engine.get_main_loop() as SceneTree
		await tree.process_frame
		if path == "/api/share" and method == HTTPClient.METHOD_POST:
			var sent: Variant = JSON.parse_string(body)
			published.append(sent if sent is Dictionary else {})
			answered_at.append(Time.get_ticks_msec())
			return _wire(201, {"id": LINK_ID, "url": "https://brickworks.diy/m/" + LINK_ID,
				"embed": SharedModels.embed_for(LINK_ID), "parts": 9, "updated": false, "listed": false,
				"version": published.size(), "said": ""})
		if path.begins_with("/api/share?op=card&id="):
			var sent: Variant = JSON.parse_string(body)
			var card: Dictionary = (sent as Dictionary).duplicate() if sent is Dictionary else {}
			card["path"] = path
			card["at"] = Time.get_ticks_msec()
			cards.append(card)
			return _wire(200, {"id": LINK_ID, "card": true, "kind": card.get("kind")})
		if path == "/api/share?op=mine":
			return _wire(200, {"shared": [], "credit": null})
		return _wire(404, {"error": "not here"})

	func _wire(code: int, said: Dictionary) -> Dictionary:
		return {"code": code, "body": said}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	var fake := FakeShared.new()
	var main: Node = load("res://src/main.tscn").instantiate()
	main.set("_shared", fake)
	root.add_child(main)
	for _n: int in 200:
		await process_frame
	var account: Account = main.get("_account")
	var store: ModelStore = main.get("_store")
	var bar: ModelBar = main.get("_bar")
	(main.get("_builder") as Builder).hide_preview()
	account.email = "probe.builder@example.com"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.over_13 = true
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	print("  renderer: %s on %s; path traced: %s" % [RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(), PathTracer.available()])
	var text: String = FileAccess.get_file_as_string(MODEL)
	var opened: Dictionary = store.open_text(text, "Probe Card After")
	_ok(str(opened["error"]).is_empty() and int(opened["placed"]) > 0,
		"the sports car opened (%d parts)" % int(opened["placed"]))
	bar.opened.emit(int(opened["placed"]))
	for _n: int in 3600:
		await process_frame
		if store.awaited.is_empty():
			break
	for _n: int in 60:
		await process_frame
	main.call("_share_wanted")
	for _n: int in 30:
		await process_frame
	var panel: Node = main.get("_share_panel")
	_ok(panel != null and (panel as Control).visible, "File › Share… opens the panel")
	if panel == null:
		_finish()
		return

	print("\n1. the publish goes with the cut-out; the photograph follows it")
	var pressed: int = Time.get_ticks_msec()
	await panel.call("publish")
	var answered: int = Time.get_ticks_msec()
	_ok(str(panel.get("state")) == "published" and fake.published.size() == 1,
		"published (%s), in %d ms from the press" % [panel.get("state"), answered - pressed])
	var sent: Dictionary = fake.published[0] if not fake.published.is_empty() else {}
	var cut := _webp(str(sent.get("thumb", "")))
	_ok(cut != null and cut.get_size() == Vector2i(480, 360) and cut.detect_alpha() != Image.ALPHA_NONE,
		"its card went as the cut-out: %s" % _said(cut))
	_ok(fake.cards.is_empty(), "nothing put on the link before the publish answered (%d)" % fake.cards.size())
	for _n: int in 1800:
		await process_frame
		if not fake.cards.is_empty() and not (panel.get("card_put") as Dictionary).is_empty():
			break
	var card: Dictionary = fake.cards[0] if not fake.cards.is_empty() else {}
	_ok(fake.cards.size() == 1 and str(card.get("path", "")).ends_with("id=" + LINK_ID),
		"then one op=card for its link (%s)" % card.get("path", "none"))
	var photo := _webp(str(card.get("thumb", "")))
	var kind: String = "traced" if PathTracer.available() else "raster"
	_ok(photo != null and photo.get_size() == Vector2i(480, 360) and photo.detect_alpha() == Image.ALPHA_NONE
		and str(card.get("kind", "")) == kind, "a photograph, %s: %s, %s" % [card.get("kind", "?"), _said(photo),
		"%d ms after the answer" % (int(card.get("at", 0)) - fake.answered_at[0]) if not card.is_empty() else ""])
	var put: Dictionary = panel.get("card_put")
	_ok(int(put.get("code", 0)) == 200 and str(put.get("id", "")) == LINK_ID,
		"the panel says the server took it: %s" % put)
	if photo != null:
		photo.save_png(OS.get_user_data_dir().path_join("card_after.png"))

	print("\n2. published again, and a part moved at once: no card for a model that is not the one published")
	panel.set("card_put", {})
	panel.call("publish")
	# The world changed while the publish goes: the next frame's.
	var world: BrickWorld = main.get("_world")
	var moved: bool = false
	var before: int = world.revision
	for _n: int in 600:
		await process_frame
		if fake.published.size() == 2 and not moved:
			var one: BrickWorld.Brick = world.bricks()[0]
			world.move_brick(one.id, one.transform.translated(Vector3(0, 0, 0.8)))
			moved = true
		if str(panel.get("state")) == "published" and moved:
			break
	for _n: int in 300:
		await process_frame
	_ok(moved and world.revision != before and fake.published.size() == 2,
		"published again, a part moved (the model's revision %d, then %d)" % [before, world.revision])
	_ok(fake.cards.size() == 1, "no second card put (%d put)" % fake.cards.size())
	_finish()


func _webp(base64: String) -> Image:
	if base64.is_empty():
		return null
	var image := Image.new()
	return image if image.load_webp_from_buffer(Marshalls.base64_to_raw(base64)) == OK else null


func _said(image: Image) -> String:
	if image == null:
		return "none"
	return "%dx%d, %s" % [image.get_width(), image.get_height(),
		"clear pixels" if image.detect_alpha() != Image.ALPHA_NONE else "opaque"]


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("card_after_probe: %s" % ("%d FAILED" % _failures if _failures else "all passed"))
	quit(1 if _failures else 0)
