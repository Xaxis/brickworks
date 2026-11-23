## A stranger's Open in Brickworks (/app?copy=<id>), in the real window: the
## model asked for from the first frame, its copy made once they are in,
## and three first acts offered (firstminute, 2026-11-23).
##
##   godot --path . --resolution 1400x900 --script src/dev/firstminute_probe.gd
##
## The link's model (the house, from a gallery that answers here) is on the
## baseplate at start, behind the sign-in screen, never the example car, and
## nothing is saved while nobody is signed in; the screen says the model is
## theirs to change once they are in. Signed in, it is saved into their
## models under its name, credited to the link, framed whole, and Recolour
## a part, Add a part and Build it are offered along the top of the model,
## the first visit's "Show the assistant" left for another visit. The same
## link again (a reload after the copy, a second tab) opens that copy: no
## second one is saved, and the acts are not offered again to that person.
##
## Each act does what it says: Recolour a part takes the Paint tool, and a
## click on the model then paints a part; Add a part opens the parts with
## the search ready; Build it plays the timeline from its first step. Each
## act's press puts the line away, as does a first change made by hand (a
## part put down) and Escape, and a person offered it once is never offered
## it again. A reload behind the age question, the copy made and the acts
## not yet offered, opens that copy and offers them once the question goes,
## no second copy made. A reload in the middle of signing in, the tab's working model
## brought back, is known for the model asked for only when this tab opened
## it so (AskedCopy.shown_here) and it says it came from the link: work of
## the person's own is not taken for it.
##
## Pictures in shots/firstminute/. A window is needed: the screen is drawn.
extends SceneTree

const SHOTS := "res://shots/firstminute/"
const LINK := "Pr0beFirst"
const NAME := "First Minute Probe House"
const SAMPLE := "Car"

var _failures: int = 0
var _main: Node


## A gallery that answers with the model it is given.
class FakeShared extends SharedModels:
	var text: String = ""
	var asked: int = 0

	func fetch(_id: String, _version: int = 0) -> Dictionary:
		asked += 1
		await (Engine.get_main_loop() as SceneTree).process_frame
		return {"code": 200, "body": {"name": NAME, "model": text, "version": 2,
			"author": "Probe Designer", "handle": "probe-designer", "licence": "CC BY 4.0"}}


func _initialize() -> void:
	_run()


func _run() -> void:
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	AskedCopy.forget()
	ShellPrefs.put("first_acts", [])
	for name: String in _saved_like():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ModelStore.saved_path(name)))
	var shared := FakeShared.new()
	shared.text = FileAccess.get_file_as_string("res://models/house.ldr")
	var parts: int = ModelStore.count_in(shared.text)
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	_main.set("_copying", LINK)
	_main.set("_shared", shared)
	root.add_child(_main)
	for _n: int in 150:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	var account: Account = _main.get("_account")
	var gate: SignInGate = _main.get("_gate")
	var store: ModelStore = _main.get("_store")
	var world: BrickWorld = _main.get("_world")
	var acts: FirstActs = _main.get("_first_acts")
	_ok(gate != null and account != null and acts != null, "the app made a sign-in screen and the first acts")
	if gate == null or acts == null:
		_finish()
		return
	while account.state == Account.State.CHECKING:
		await account.changed
	await _settle()

	print("\nbehind the sign-in screen")
	_ok(store.title == NAME and store.title != SAMPLE,
		"the model asked for is on the baseplate, not the example car: “%s”" % store.title)
	_ok(world.brick_count() - store.scenery.size() == parts,
		"...all of it: %d parts of %d" % [world.brick_count() - store.scenery.size(), parts])
	_ok(not bool(_main.get("_sample_untouched")), "...and the example car never opened")
	_ok(bool(_main.get("_asked_open")) and gate.asked == NAME, "...known for the one asked, by the screen too")
	_ok(store.remixed_from == LINK, "...credited to its link: %s" % store.remixed_from)
	_ok(_saved_like().is_empty(), "nothing is saved while nobody is signed in: %s" % [_saved_like()])
	account.state = Account.State.SIGNED_OUT
	account.changed.emit()
	await _settle()
	var said: String = _text_on(gate)
	_ok(gate.visible and said.contains("Sign in to make it yours") and said.contains("“%s”" % NAME),
		"the screen says it is theirs to change once they are in: %s" % said.get_slice("\n", 0))
	_save("1_signed_out.png")

	print("\nsigned in")
	account.email = "first-minute-a@example.com"
	account.user_id = "probe-person-a"
	account._access = "probe.signed.in"
	account._expires_at = Time.get_unix_time_from_system() + 3600.0
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	var kept: String = ""
	for _n: int in 600:
		await process_frame
		kept = str(_main.get("_copy_made"))
		if not kept.is_empty():
			break
	await _settle()
	_ok(not gate.visible, "the screen goes")
	_ok(kept == NAME and FileAccess.file_exists(ModelStore.saved_path(kept)),
		"the copy is saved into their models as “%s”" % kept)
	_ok(store.title == kept and store.remixed_from == LINK and store.remixed_from_version == 2,
		"...it is the model on the baseplate, from the link's version 2 (%s v%d)" % [
			store.remixed_from, store.remixed_from_version])
	_ok(str(store.credit.get("by", "")) == "Probe Designer",
		"...credited to its designer: %s" % [store.credit])
	_ok(shared.asked == 1, "...fetched once, at start: %d asks" % shared.asked)
	_ok(bool(_main.call("_whole_in_view", _main.call("_built_bounds"))), "...framed whole")
	_ok(AskedCopy.made(LINK, "probe-person-a") == kept, "...and this device knows the copy is made")
	_ok(acts.visible and acts.controls_by_name().keys().size() == 4,
		"Recolour a part, Add a part and Build it offered, with ×: %s" % [acts.controls_by_name().keys()])
	var offer: Control = _main.get("_offer")
	_ok(offer == null or not offer.visible, "the first visit's Show the assistant is left for another visit")
	_ok(_text_on(acts).contains("“%s” is yours to change" % kept), "...saying whose it is: %s" % _text_on(acts))
	_save("2_copied.png")

	print("\nthe same link again: a reload after the copy, a second tab")
	var before: Array = _saved_like()
	_main.set("_copy_started", false)
	await _main.call("_maybe_copy")
	await _settle()
	_ok(_saved_like() == before, "no second copy: %s" % [_saved_like()])
	_ok(store.title == kept, "...the copy made is what is open")
	_ok(not acts.offer(kept, "probe-person-a"), "...and the acts are not offered again to that person")

	print("\nRecolour a part")
	_ok(acts.offer(kept, "probe-person-b"), "offered to somebody new")
	var history: int = (_main.get("_builder") as Builder).history_depth()
	await _press(acts.controls_by_name()["first_recolour"])
	_ok(not acts.visible, "the press puts the line away")
	_ok((_main.get("_verbs") as EditVerbs).mode == "paint", "...and takes the Paint tool")
	# The colour in hand, one no part of the house is: the click paints.
	(_main.get("_builder") as Builder).held_color = 22
	await _click_model()
	_ok((_main.get("_builder") as Builder).history_depth() == history + 1,
		"a click on the model then paints a part (%d to undo, %d before)" % [
			(_main.get("_builder") as Builder).history_depth(), history])
	_save("3_recoloured.png")
	(_main.get("_verbs") as EditVerbs).set_mode("select")

	print("\nAdd a part")
	_ok(acts.offer(kept, "probe-person-c"), "offered to somebody new")
	await _press(acts.controls_by_name()["first_add"])
	var bin_dock: SideDock = _main.get("_bin_dock")
	var search: Control = (_main.get("_bin") as PartsBin).controls_by_name().get("part search")
	_ok(not acts.visible and bin_dock.is_open() and search != null and search.has_focus(),
		"the parts are out, their search ready")
	_save("4_add_a_part.png")
	if search != null:
		search.release_focus()

	print("\nBuild it")
	_ok(acts.offer(kept, "probe-person-d"), "offered to somebody new")
	await _press(acts.controls_by_name()["first_build"])
	var steps: StepsBar = _main.get("_steps")
	for _n: int in 900:
		await process_frame
		if steps.is_playing_back():
			break
	await _settle()
	_ok(not acts.visible and steps.is_playing_back() and steps.timeline_at().x <= 1,
		"the timeline plays from its first step: %s" % steps.timeline_at())
	_save("5_build_it.png")
	steps.stop()
	await _settle()

	print("\nput away by a change made by hand, and by Escape")
	_ok(acts.offer(kept, "probe-person-e"), "offered to somebody new")
	(_main.get("_verbs") as EditVerbs).set_mode("place")
	var bricks: int = world.brick_count()
	await _click_model()
	_ok(world.brick_count() == bricks + 1 and not acts.visible,
		"a part put down puts it away (%d parts, %d before)" % [world.brick_count(), bricks])
	(_main.get("_verbs") as EditVerbs).set_mode("select")
	# Written as the app writes it, in this run's own data folder (probe.sh).
	ShellPrefs.kept_by_a_check = true
	_ok(acts.offer(kept, "probe-person-f"), "offered to somebody new")
	await _key(KEY_ESCAPE)
	_ok(not acts.visible, "Escape puts it away")
	_ok(not acts.offer(kept, "probe-person-f"), "...and it is never offered to them again")
	# Read again from its file, as a reload or a second tab reads it: kept
	# only in this run's memory, the next start offered it again.
	ShellPrefs._loaded = false
	_ok(FirstActs.offered_before("probe-person-f"), "...kept on this device, read back from its file")
	ShellPrefs.kept_by_a_check = false

	# The copy is made the moment the code is taken, with the age question
	# still to come: a reload then comes back to the link's address, which
	# opens the copy made, and the acts wait for the question to go.
	print("\na reload behind the age question, the copy made, its acts not yet offered")
	account.user_id = "probe-person-g"
	AskedCopy.mark_made(LINK, "probe-person-g", kept)
	account.age_ask = true
	account.changed.emit()
	await _settle()
	var copies: Array = _saved_like()
	_main.set("_copy_started", false)
	_main.call("_maybe_copy")
	for _n: int in 30:
		await process_frame
	_ok(gate.visible and not acts.visible, "behind the question, nothing offered yet")
	account.age_ask = false
	account.changed.emit()
	# By the clock: the app looks again every 0.25 s, and frames here are
	# not paced.
	var asked_at: int = Time.get_ticks_msec()
	while not acts.visible and Time.get_ticks_msec() - asked_at < 5000:
		await process_frame
	_ok(acts.visible and _text_on(acts).contains("“%s”" % kept),
		"the question answered, the acts offered on the copy: %s" % _text_on(acts))
	_ok(store.title == kept and _saved_like() == copies, "...the copy made, not another: %s" % [_saved_like()])
	acts.dismiss()

	print("\na reload in the middle of signing in")
	_main.set("_copying", "Pr0beAgain")
	store.remixed_from = "Pr0beAgain"
	AskedCopy.mark_shown("Pr0beAgain")
	var back: int = await _main.call("_open_asked", 7)
	_ok(back == 7 and bool(_main.get("_asked_open")),
		"the working model brought back is the one this tab opened for the link")
	AskedCopy.forget()
	back = await _main.call("_open_asked", 7)
	_ok(back == 7 and not bool(_main.get("_asked_open")),
		"...but not work of the person's own that says the same link, unopened here")
	# A stranger back for a second look: the example car, untouched, came
	# back from the first visit's autosave. The model asked for goes in its
	# place, never the car behind the sign-in screen.
	_main.set("_copying", "Pr0beFirst")
	var car: int = _main.call("_open", "res://models/car.ldr")
	back = await _main.call("_open_asked", car)
	_ok(car > 0 and back > 0 and store.title == NAME and bool(_main.get("_asked_open")),
		"the example car brought back untouched gives way to the model asked for (%s)" % store.title)
	_main.set("_copying", "")
	_finish()


## The person's saved models of the probe's name, by name.
func _saved_like() -> Array:
	var named: Array = []
	var dir: DirAccess = DirAccess.open(ModelStore.SAVE_DIR)
	if dir == null:
		return named
	for file: String in dir.get_files():
		if file.begins_with(NAME) and file.ends_with(".ldr"):
			named.append(file.get_basename())
	named.sort()
	return named


func _press(control: Control) -> void:
	if control is BaseButton:
		(control as BaseButton).pressed.emit()
	for _n: int in 10:
		await process_frame


func _settle() -> void:
	for _n: int in 20:
		await process_frame
	await RenderingServer.frame_post_draw


## A click on a part of the model, at a point the app's own hit test finds
## one under (EditVerbs.brick_at, what a click with any tool asks). The
## builder's hovered part was waited for here: it follows the pointer only
## while a part is in hand, so with the Paint tool no point ever had one and
## no click was made (fmfin, 2026-11-23).
func _click_model() -> void:
	var view: Control = (_main.get("_marquee") as Control).get_parent()
	var builder: Builder = _main.get("_builder")
	var verbs: EditVerbs = _main.get("_verbs")
	builder.hide_preview()
	await process_frame
	for offset: Vector2 in [Vector2(0, 40), Vector2(0, 0), Vector2(30, 60), Vector2(-30, 20)]:
		var at: Vector2 = view.get_global_rect().get_center() + offset
		_move(at)
		var found: int = 0
		for _n: int in 60:
			await process_frame
			found = verbs.brick_at(at)
			if found != 0:
				break
		if found == 0:
			continue
		_button(at, true)
		_button(at, false)
		for _n: int in 20:
			await process_frame
		return


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _button(at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	for _n: int in 4:
		await process_frame


func _text_on(node: Node) -> String:
	var said := PackedStringArray()
	for child: Node in node.find_children("*", "Label", true, false):
		if (child as Label).is_visible_in_tree():
			said.append((child as Label).text)
	return "\n".join(said)


func _save(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(SHOTS + name))
	print("  wrote shots/firstminute/%s" % name)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "Open in Brickworks leads a stranger to the model they chose, ready to change")
	quit(1 if _failures else 0)
