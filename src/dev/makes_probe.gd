## Show your build (makes, 2026-11-23): a photo of the real build posted from
## the step player's last step, and from the viewer's timeline at its end,
## through the build photos' own path, done as a person does it: every press
## a click sent to the window, the photo chosen in the app's own file dialog.
##
##   godot --path . --resolution 1280x800 --script src/dev/makes_probe.gd
##   PROBE_SIZE=390x844 tools/probe.sh makes_probe
##
## No network: FakeShared answers as api/share.js and api/people.js do
## (tools/web/makes_flow.mjs proves the real path, the photo read back from
## storage with no Exif and its 480 px copy). What it checks:
## - The last step (Next onto it from the step before) shows the end card
##   under the top bar: how many have built the model ("14 people have built
##   it", the finish's own answer) and Show your build, a fingertip each way;
##   the finished model framed below the card. No page before the last shows
##   it.
## - Show your build opens the photo chooser; a JPEG chosen in it (Exif in it:
##   which way up, a phone's make) comes back on the card upright, as the
##   phone held it, read on a worker (the longest frame while it is read
##   printed); words typed, and Post. What is sent is the file as chosen, its
##   type and size said first (?op=photo_start), the bytes to the URL signed
##   for them, then ?op=photo with the ticket and the words; the card says
##   "Posted: on the model's page" with its link. Two presses from the last
##   step, the bar three.
## - Nobody signed in, ten times over: Post asks for the sign-in in place
##   ("Sign in to post your build", the app's own form, Not now), over the
##   step player still on the last step; signed in, it goes, and the photo and
##   the words are on the card as they were, ready to Post; Post then posts.
##   Not now puts it away with the photo kept.
## - Refused at the start, under 13 and by may_act's limit, in the site's own
##   words: nothing of the photo sent. Words past 140 characters refused in
##   words, nothing sent. A file that is not a picture refused in words.
## - The designer's own model offers "Add a photo of your build".
## - ?op=built still once per device: twenty more finishes, Back and Next,
##   on the step player and the timeline, and nothing more sent.
## - Closed at the end, the viewer's card has the photo and Show your build; the
##   timeline stepped back puts it away, stepped onto its end brings it back.
##
## Pictures in shots/makes/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/makes/"
const ID := "Mak3sPr0be"
const FILES := "user://makes_probe/"
const BUILT_FILE := "user://makes_probe_built.cfg"
const TOO_YOUNG := "Brickworks accounts are for 13 and over. Ask a parent or guardian to sign in " \
	+ "with their own email and build with you."
const LIMIT := "that is a lot of that in a short time: try again in an hour"

var _failures: int = 0
var _main: Node
var _fake: FakeShared
var _shots: String = SHOTS


## api/share.js and api/people.js as the viewer and the end card ask them.
class FakeShared extends SharedModels:
	var answer: Dictionary = {}
	## How many had built it before this run's devices.
	var built_before: int = 13
	static var built_calls: Array[Dictionary] = []
	static var counted_keys: Dictionary = {}
	## What ?op=photos says of the account: its own model, and photos left.
	var owns: bool = false
	var left: int = 3
	var photos_asked: int = 0
	## A refusal photo_start answers with ({code, error}), none when empty.
	var refuse: Dictionary = {}
	var starts: Array[Dictionary] = []
	var sends: Array[Dictionary] = []
	var keeps: Array[Dictionary] = []

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		while answer.is_empty():
			await (Engine.get_main_loop() as SceneTree).process_frame
		return answer

	func built(id: String, device: String, version: int = 1) -> Dictionary:
		built_calls.append({"id": id, "device": device, "version": version})
		await (Engine.get_main_loop() as SceneTree).process_frame
		var counted: bool = not counted_keys.has(device + id)
		counted_keys[device + id] = true
		return {"code": 200, "body": {"counted": counted, "builds": built_before + counted_keys.size()}}

	func comments(_id: String, _version: int = 0, _token: String = "") -> Dictionary:
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 400, "body": {"error": "unknown op comments"}}

	func photos(id: String, token: String) -> Dictionary:
		photos_asked += 1
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"model": id, "owner": owns, "photos": [], "mine": [], "left": left,
			"token": token}}

	func photo_start(token: String, body: Dictionary) -> Dictionary:
		starts.append(body.merged({"token": token}))
		await (Engine.get_main_loop() as SceneTree).process_frame
		if not refuse.is_empty():
			return {"code": int(refuse["code"]), "body": {"error": refuse["error"]}}
		return {"code": 200, "body": {"upload": "https://storage.example/upload/%d" % starts.size(),
			"ticket": "%032x.jpg" % starts.size(), "type": body["type"], "key": "publishable"}}

	func photo_send(url: String, key: String, type: String, bytes: PackedByteArray) -> Dictionary:
		sends.append({"url": url, "key": key, "type": type, "bytes": bytes})
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200}

	func photo_keep(token: String, body: Dictionary) -> Dictionary:
		keeps.append(body.merged({"token": token}))
		await (Engine.get_main_loop() as SceneTree).process_frame
		var id: String = "Ph0to%05d" % keeps.size()
		return {"code": 201, "body": {"id": id, "model": body["model"], "words": body.get("words"),
			"page": "https://brickworks.diy/m/%s#photo-%s" % [body["model"], id]}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var window: Vector2i = DisplayServer.window_get_size()
	_shots = SHOTS + "%dx%d/" % [window.x, window.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_shots))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FILES))
	SharedModels.kept_at = BUILT_FILE
	_forget_built()
	BuildSteps._kept.clear()
	var text: String = FileAccess.get_file_as_string("res://models/house.ldr")
	var photo: PackedByteArray = _photo_with_exif(400, 300)
	var photo_file: String = FILES + "build.jpg"
	_write(photo_file, photo)
	_write(FILES + "notes.jpg", "these are words, not a photo".to_utf8_buffer())

	print("\nthe last step of the step player")
	var mode: BuildMode = await _open(text, "probe-token")
	if mode == null:
		_finish()
		return
	var card: MakeCard = mode.make
	var pages: BuildSteps = _main.get("_build_pages")
	var last: int = pages.last()
	var seen_before: bool = false
	while int(_main.call("build_state")["page"]) < last:
		await _press(mode.controls_by_name()["build_next"])
		if int(_main.call("build_state")["page"]) < last and card.is_visible_in_tree():
			seen_before = true
	await _until(func() -> bool: return int(card.builds) == 14)
	var said: Dictionary = _main.call("build_state")
	var make: Dictionary = said["make"]
	_ok(not seen_before, "no page before the last shows the card (%d pages)" % last)
	_ok(said["page"] == last and said["next"] == "Finish" and make["shown"] == true
		and make["offer"] == "Show your build",
		"the last step (%d of %d) shows Show your build beside Finish" % [said["page"], last])
	_ok(make["count"] == "14 people have built it",
		"...and how many have built it, with this finish: \"%s\"" % make["count"])
	_ok(FakeShared.built_calls.size() == 1, "one finish sent (%d)" % FakeShared.built_calls.size())
	var top: Rect2 = (mode.controls_by_name()["build_top"] as Control).get_global_rect()
	var card_rect: Rect2 = card.get_global_rect()
	var seen: Rect2 = (_main.get("_camera") as CadCamera).seen_rect()
	_ok(card_rect.position.y >= top.end.y and seen.position.y >= card_rect.end.y - 1.0,
		"the card is under the top bar and the finished model framed below it (%s, %s)" % [card_rect, seen])
	var targets: Dictionary = said["targets"]
	var show_size: Array = targets.get("make_show", [0, 0])
	_ok(float(show_size[0]) >= 44.0 and float(show_size[1]) >= 44.0,
		"Show your build is a fingertip each way (%s points)" % [show_size])
	await _settle()
	_save("1_last_step.png")

	print("\nShow your build, a photo, and Post")
	await _press(mode.controls_by_name()["make_show"])
	var dialog: FileDialog = _dialog_of(card)
	_ok(dialog != null and dialog.visible, "Show your build opens the photo chooser")
	if dialog != null:
		dialog.file_selected.emit(ProjectSettings.globalize_path(photo_file))
		dialog.hide()
	var longest: int = await _read_frames(card)
	make = card.card_state()
	_ok(make["state"] == "chosen" and int(make["photo"]) == photo.size() and make["type"] == "image/jpeg",
		"the photo is on the card, to be sent as chosen (%d bytes, %s)" % [make["photo"], make["type"]])
	_ok(make["size"] == [300, 400] and _top_is_red(card),
		"...shown upright, as the phone held it (Exif says turned: %s, read in %d ms, longest frame %d ms)"
		% [make["size"], make["read_ms"], longest])
	await _settle()
	_save("2_photo_chosen.png")
	(card.controls_by_name()["make_words"] as LineEdit).grab_focus()
	await _type("Built it with my son")
	_ok(card.words() == "Built it with my son" and int(_main.call("build_state")["page"]) == last,
		"words typed in its box, and no page turned by them (\"%s\")" % card.words())
	await _press(card.controls_by_name()["make_post"])
	await _until(func() -> bool: return card.state == "posted")
	make = card.card_state()
	var start: Dictionary = _fake.starts[0] if _fake.starts.size() > 0 else {}
	var sent: Dictionary = _fake.sends[0] if _fake.sends.size() > 0 else {}
	var kept: Dictionary = _fake.keeps[0] if _fake.keeps.size() > 0 else {}
	_ok(start.get("model") == ID and start.get("type") == "image/jpeg" and int(start.get("size", 0)) == photo.size()
		and start.get("token") == "probe-token",
		"?op=photo_start was told the model, the type and the size first (%s)" % [start])
	_ok(sent.get("url") == "https://storage.example/upload/1" and sent.get("key") == "publishable"
		and (sent.get("bytes", PackedByteArray()) as PackedByteArray) == photo,
		"...the photo went to the URL signed for it, byte for byte as chosen")
	_ok(kept.get("ticket") == "%032x.jpg" % 1 and kept.get("words") == "Built it with my son",
		"...and ?op=photo kept it with its ticket and the words (%s)" % [kept])
	_ok(make["posted"] == "Posted: on the model's page"
		and make["url"] == "https://brickworks.diy/m/%s#photo-Ph0to00001" % ID,
		"the card says \"%s\", a link to %s" % [make["posted"], make["url"]])
	_ok(int(make["presses"]) <= 3, "from the last step to the photo posted: %d presses (at most 3)"
		% make["presses"])
	await _settle()
	_save("3_posted.png")

	print("\ntwenty more finishes on this device")
	for _n: int in 10:
		await _press(mode.controls_by_name()["build_back"])
		await _press(mode.controls_by_name()["build_next"])
	_ok(FakeShared.built_calls.size() == 1 and int(_main.call("build_state")["page"]) == last,
		"Back and Next onto the last step ten times: no finish sent again (%d)" % FakeShared.built_calls.size())

	print("\nclosed at the end: the viewer's own card")
	await _press(mode.controls_by_name()["build_close"])
	var view: ShareView = _main.get("_share_view")
	var steps: StepsBar = _main.get("_steps")
	var shown: Dictionary = view.page_state()["make"]
	_ok(shown["shown"] == true and shown["state"] == "posted",
		"Close on the last step: the viewer says it too (%s)" % shown["state"])
	await _settle()
	_save("4_viewer_end.png")
	if steps.is_playing_back():
		for _n: int in 10:
			steps.step_back()
			await _settle()
			var away: bool = view.page_state()["make"]["shown"] == false
			steps.step_forward()
			await _settle()
			if not away or view.page_state()["make"]["shown"] != true:
				_ok(false, "the timeline stepped back puts the card away, onto its end brings it back")
				break
		_ok(FakeShared.built_calls.size() == 1,
			"...and the timeline stepped back and onto its end ten times sends no finish (%d)"
			% FakeShared.built_calls.size())
	await _close()

	await _signed_out(text, photo_file, photo)
	await _refusals(text, photo_file)
	await _designer(text)
	_forget(FILES)
	_forget_built()
	_finish()


## Nobody signed in, ten times: Post asks for the sign-in in place, and back
## the photo is there, ready to Post.
func _signed_out(text: String, photo_file: String, photo: PackedByteArray) -> void:
	print("\nnobody signed in: the sign-in in place, ten times")
	var account := Account.new()
	account.keeps = false
	root.add_child(account)
	await process_frame
	_sign(account, false)
	var mode: BuildMode = await _open(text, "", account)
	if mode == null:
		return
	var card: MakeCard = mode.make
	await _to_last(mode)
	await _choose(card, photo_file)
	(card.controls_by_name()["make_words"] as LineEdit).grab_focus()
	await _type("Our first one")
	var last: int = (_main.get("_build_pages") as BuildSteps).last()
	var held: int = 0
	for n: int in 10:
		await _press(card.controls_by_name()["make_post"])
		var gate: SignInGate = _main.get("_make_gate")
		var asked: bool = gate != null and gate.visible and str(gate.get("_title").text) == "Sign in to post your build" \
			and (_main.call("_page_controls") as Dictionary).has("signin_email") \
			and (_main.call("_page_controls") as Dictionary).has("signin_not_now")
		if n == 0:
			await _settle()
			_save("5_sign_in.png")
		var under: bool = mode.is_open() and int(_main.call("build_state")["page"]) == last
		_sign(account, true, n)
		await _settle()
		var back: bool = gate != null and not gate.visible and card.state == "chosen" \
			and card.photo == photo and card.words() == "Our first one" \
			and int(_main.call("build_state")["page"]) == last and mode.is_open() \
			and (card.controls_by_name() as Dictionary).has("make_post")
		if asked and under and back and _fake.starts.is_empty():
			held += 1
		else:
			print("     round %d: asked %s, the last step under it %s, back as it was %s, sent %d" % [n + 1,
				asked, under, back, _fake.starts.size()])
		_sign(account, false)
		await _settle()
	_ok(held == 10, "Post signed out: asked in place, and back on the last step with the photo and "
		+ "the words, ready to Post, %d of 10" % held)
	await _press(card.controls_by_name()["make_post"])
	var gate: SignInGate = _main.get("_make_gate")
	await _press(gate.controls_by_name()["signin_not_now"])
	_ok(not gate.visible and card.state == "chosen" and card.photo == photo and _fake.starts.is_empty(),
		"Not now: put away, the photo still on the card, nothing sent")
	_sign(account, true, 11)
	await _settle()
	await _press(card.controls_by_name()["make_post"])
	await _until(func() -> bool: return card.state == "posted")
	_ok(card.state == "posted" and _fake.keeps.size() == 1 and _fake.keeps[0]["words"] == "Our first one"
		and str(_fake.starts[0]["token"]) == "signed-in-11",
		"signed in, Post posts it, as the account signed in (%s)" % (_fake.starts[0]["token"]
			if not _fake.starts.is_empty() else "nothing sent"))
	await _close()
	account.queue_free()


## Refused before anything of the photo goes, in words.
func _refusals(text: String, photo_file: String) -> void:
	print("\nrefused, and nothing sent")
	var mode: BuildMode = await _open(text, "probe-token")
	if mode == null:
		return
	var card: MakeCard = mode.make
	await _to_last(mode)
	await _choose(card, FILES + "notes.jpg")
	_ok(card.state == "offer" and card.card_state()["said"] == MakeCard.NOT_A_PHOTO and card.photo.is_empty(),
		"a file that is not a picture: \"%s\"" % card.card_state()["said"])
	await _choose(card, photo_file)
	for refusal: Array in [[422, TOO_YOUNG, "under 13"], [429, LIMIT, "may_act's limit"]]:
		_fake.refuse = {"code": refusal[0], "error": refusal[1]}
		var starts: int = _fake.starts.size()
		await _press(card.controls_by_name()["make_post"])
		await _until(func() -> bool: return card.state == "chosen" and _fake.starts.size() > starts)
		var said: String = str(card.card_state()["said"])
		_ok(card.state == "chosen" and _fake.sends.is_empty() and _fake.keeps.is_empty()
			and said.to_lower().begins_with(str(refusal[1]).to_lower().substr(0, 30)),
			"%s: \"%s\", and nothing of the photo sent" % [refusal[2], said])
	_fake.refuse = {}
	var box: LineEdit = card.controls_by_name()["make_words"]
	box.text = "x".repeat(141)
	var starts_now: int = _fake.starts.size()
	await _press(card.controls_by_name()["make_post"])
	_ok(_fake.starts.size() == starts_now and str(card.card_state()["said"]).contains("141"),
		"141 characters about it: refused in words, nothing cut or sent (\"%s\")" % card.card_state()["said"])
	await _close()


## The model's own designer: theirs is a picture of it, not a make.
func _designer(text: String) -> void:
	print("\nthe designer's own model")
	var mode: BuildMode = await _open(text, "probe-token", null, true)
	if mode == null:
		return
	await _to_last(mode)
	await _until(func() -> bool: return mode.make.own)
	var make: Dictionary = mode.make.card_state()
	_ok(make["offer"] == "Add a photo of your build" and _fake.photos_asked >= 1,
		"its last step offers \"%s\"" % make["offer"])
	await _settle()
	_save("6_designer.png")
	await _close()


func _open(text: String, token: String, account: Account = null, owner: bool = false) -> BuildMode:
	_fake = FakeShared.new()
	_fake.owns = owner
	_fake.answer = {"code": 200, "body": {"id": ID, "name": "Probe House", "author": "Probe Builder",
		"parts": 0, "url": "https://brickworks.diy/m/" + ID, "model": text, "builds": 13}}
	_main = load("res://src/main.tscn").instantiate()
	_main.set("_viewing", ID)
	_main.set("_shared", _fake)
	_main.set("comment_token_for_probe", token)
	_main.set("make_account_for_probe", account)
	root.add_child(_main)
	var view: ShareView = null
	for _n: int in 1200:
		await process_frame
		view = _main.get("_share_view")
		if view != null and view.state in ["ready", "failed", "gone"]:
			break
	var steps: StepsBar = _main.get("_steps")
	var since: int = Time.get_ticks_msec()
	while steps != null and steps.is_starting() and Time.get_ticks_msec() - since < 120000:
		await process_frame
	await _settle()
	_ok(view != null and view.state == "ready", "the link opened")
	if view == null or view.state != "ready":
		return null
	await _press(view.controls_by_name()["view_build"])
	var mode: BuildMode = _main.get("_build_mode")
	_ok(mode != null and mode.is_open(), "Build it opens the step player")
	return mode if mode != null and mode.is_open() else null


func _close() -> void:
	_main.queue_free()
	_main = null
	for _n: int in 10:
		await process_frame


func _to_last(mode: BuildMode) -> void:
	var last: int = (_main.get("_build_pages") as BuildSteps).last()
	for _n: int in last + 2:
		if int(_main.call("build_state")["page"]) >= last:
			break
		await _press(mode.controls_by_name()["build_next"])


## A file chosen in the card's own photo chooser, as a person does.
func _choose(card: MakeCard, file: String) -> void:
	var before: int = card.read_ms
	await _press(card.controls_by_name().get("make_show", card.controls_by_name().get("make_another")))
	var dialog: FileDialog = _dialog_of(card)
	if dialog == null:
		_ok(false, "the photo chooser opened")
		return
	dialog.file_selected.emit(ProjectSettings.globalize_path(file))
	dialog.hide()
	await _until(func() -> bool: return card.state != "reading" and (card.read_ms != before
		or card.card_state()["said"] != ""))
	await _settle()


## The longest frame while the card reads its photo, in ms.
func _read_frames(card: MakeCard) -> int:
	var longest: int = 0
	var since: int = Time.get_ticks_msec()
	var at: int = Time.get_ticks_usec()
	while (card.state == "reading" or card.state == "offer") and Time.get_ticks_msec() - since < 20000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		longest = maxi(longest, roundi((now - at) / 1000.0))
		at = now
	return longest


func _dialog_of(card: MakeCard) -> FileDialog:
	for found: Node in card.find_children("*", "FileDialog", true, false):
		return found as FileDialog
	return null


## The probe's account signed in ([param on]) as a code would, or out.
func _sign(account: Account, on: bool, n: int = 0) -> void:
	account.state = Account.State.SIGNED_IN if on else Account.State.SIGNED_OUT
	account.email = "builder%d@probe.example" % n if on else ""
	account.set("_access", "signed-in-%d" % n if on else "")
	account.set("_expires_at", Time.get_unix_time_from_system() + 3600.0 if on else 0.0)
	account.changed.emit()


## Whether the card's photo stands as the phone held it: the file's left
## half red, turned a quarter clockwise, is the shown photo's top.
func _top_is_red(card: MakeCard) -> bool:
	var thumb: Image = (card.get("_thumb") as TextureRect).texture.get_image()
	var high: Color = thumb.get_pixel(thumb.get_width() / 2, thumb.get_height() / 5)
	var low: Color = thumb.get_pixel(thumb.get_width() / 2, thumb.get_height() * 4 / 5)
	return high.r > 0.6 and high.b < 0.4 and low.b > 0.6 and low.r < 0.4


## A JPEG of [param wide] × [param tall], its left half red and right half
## blue, with Exif saying it was taken turned a quarter (Orientation 6) on a
## phone of a make, as a phone's camera writes it.
static func _photo_with_exif(wide: int, tall: int) -> PackedByteArray:
	var image := Image.create_empty(wide, tall, false, Image.FORMAT_RGB8)
	image.fill(Color(0.1, 0.2, 0.9))
	image.fill_rect(Rect2i(0, 0, wide / 2, tall), Color(0.9, 0.1, 0.1))
	var jpeg: PackedByteArray = image.save_jpg_to_buffer(0.9)
	var make: PackedByteArray = "ProbePhone".to_ascii_buffer()
	make.append(0)
	var tiff := PackedByteArray([0x4D, 0x4D, 0x00, 0x2A, 0, 0, 0, 8, 0, 2])
	# Make, ASCII, its words after the directory.
	tiff.append_array(PackedByteArray([0x01, 0x0F, 0, 2, 0, 0, 0, make.size(), 0, 0, 0, 38]))
	# Orientation, a SHORT: 6, turned a quarter clockwise.
	tiff.append_array(PackedByteArray([0x01, 0x12, 0, 3, 0, 0, 0, 1, 0, 6, 0, 0]))
	tiff.append_array(PackedByteArray([0, 0, 0, 0]))
	tiff.append_array(make)
	var exif := PackedByteArray([0x45, 0x78, 0x69, 0x66, 0, 0])
	exif.append_array(tiff)
	var length: int = exif.size() + 2
	var out := PackedByteArray([0xFF, 0xD8, 0xFF, 0xE1, length >> 8, length & 0xFF])
	out.append_array(exif)
	out.append_array(jpeg.slice(2))
	return out


func _write(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _until(done: Callable) -> void:
	var since: int = Time.get_ticks_msec()
	while not bool(done.call()) and Time.get_ticks_msec() - since < 20000:
		await process_frame
	await _settle()


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


func _type(words: String) -> void:
	for at: int in words.length():
		var c: String = words[at]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = KEY_SPACE if c == " " else OS.find_keycode_from_string(c.to_upper())
			event.physical_keycode = event.keycode
			event.unicode = c.unicode_at(0)
			event.shift_pressed = c != c.to_lower()
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _settle()


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


## Press a control where it is on screen, with the mouse.
func _press(control: Control) -> void:
	if control == null:
		_ok(false, "a control to press")
		return
	var at: Vector2 = control.get_global_rect().get_center()
	_move(at)
	await process_frame
	_button(at, true)
	await process_frame
	_button(at, false)
	await _settle()


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _save(name: String) -> void:
	var image: Image = root.get_texture().get_image()
	if image != null and not image.is_empty():
		image.save_png(ProjectSettings.globalize_path(_shots + name))
		print("  wrote %s%s" % [_shots.trim_prefix("res://"), name])


func _forget_built() -> void:
	if FileAccess.file_exists(BUILT_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BUILT_FILE))


func _forget(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for file_name: String in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + file_name)
	DirAccess.remove_absolute(dir)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else
		"a build's photo is posted from its last step, signed in or not, and nothing else is sent")
	quit(1 if _failures else 0)
