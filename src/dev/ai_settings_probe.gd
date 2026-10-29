## Settings, AI: does a person choose another AI, keep its key safe, test it,
## and design with it?
##
##   godot --path . --resolution 1400x900 --script src/dev/ai_settings_probe.gd
##   tools/probe.sh ai_settings_probe                   (the same)
##   PROBE_SIZE=1024x768 tools/probe.sh ai_settings_probe, or 400x860 for a
##   phone's width: the pictures at that size.
##
## The provider is tools/provider_stub.py on 127.0.0.1:9660, an
## OpenAI-compatible server that wants a key (STUB_KEY, made here) and lists
## four models: stub-sees, stub-blind (refuses pictures), stub-notools
## (answers in words) and gpt-6.1-sol. Through the page as a person goes
## (Settings, AI…, the controls pressed and typed in):
##
##   Claude is who designs until another is chosen, and the assistant's
##   column is as it was; another AI chosen, the column is for it.
##   The provider "Another OpenAI-compatible server", its address; the list
##   refused without a key; a key with a space refused beside its field;
##   the key shown and hidden, kept, cleared from the field, shown only as
##   its fingerprint; the list then read, filtered, a model chosen.
##   Temperature and effort offered where the model takes them.
##   Test against each kind of model: tools and pictures, pictures refused,
##   no tools (which then cannot design).
##   Kept and read back as a restart reads it: the provider, model, address
##   and parameters from the settings file, the key from its own file,
##   which is encrypted: the key is in no file the app wrote in plain, the
##   log included. Remember unticked keeps it for the visit only.
##   Every control named for a screen reader, and Tab walking them in order.
##   Design with it: the assistant's brief, sent; the stub designs the tower
##   with the temperature and most-out chosen, the fresh look is answered, it
##   is saved, and the run's card says Done.
## Pictures in shots/ai_settings/, named by the window's size.
extends SceneTree

const PORT := 9660
const BRIEF := "A slender red tower, six bricks tall"

var _failures: int = 0
var _main: Node
var _ai: AiSettings
var _controls: ControlsDialog
var _chat: ChatPanel
var _stub: int = -1
var _log: String = ""
var _key: String = ""
var _size: String = ""


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	_size = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	# Not anybody's key: made here, so the stub can tell it came.
	_key = "sk-stub-" + Crypto.new().generate_random_bytes(16).hex_encode()
	_log = ProjectSettings.globalize_path("user://ai-settings-stub.jsonl")
	OS.set_environment("STUB_KEY", _key)
	_stub = OS.create_process("python3", ["-I",
		ProjectSettings.globalize_path("res://tools/provider_stub.py"), "--port", str(PORT),
		"--log", _log])
	OS.unset_environment("STUB_KEY")
	_check("the stub provider starts (pid %d)" % _stub, _stub > 0)

	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(150)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	(_main.get("_store") as ModelStore).keeps = false
	_controls = _main.get("_controls")
	_chat = _main.get("_chat")
	_ai = _controls.ai

	await _claude_as_before()
	await _choose_another()
	await _the_key()
	await _the_models()
	await _tests()
	await _kept()
	_names_and_keys()
	await _design()
	_no_key_anywhere()

	if _stub > 0:
		OS.kill(_stub)
	print("")
	print("ai settings: chosen, kept, tested and designed with, the key nowhere but its own file"
		if _failures == 0 else "ai settings: %d FAILED" % _failures)
	_main.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


## Claude designs until someone chooses otherwise; the column is as it was.
func _claude_as_before() -> void:
	print("\n── Claude, as before ──")
	_check("Claude designs until another is chosen",
		ProviderSettings.who() == ProviderSettings.WHO_CLAUDE)
	_check("the assistant's column has Claude's model row and the key form, as before",
		(_chat.get("_settings") as Control).visible and not _chat.designing_elsewhere()
		and (_chat.get("_key_form") as Control).visible == not OwnKey.has_key())
	(_main.get("_shell") as Shell).run("settings")
	await _frames(10)
	var words: String = _controls.ai_open.text
	_check("Settings says who designs, on the way to AI: \"%s\"" % words,
		_controls.visible and words == "AI: Claude…" and _controls.ai_open.is_visible_in_tree())
	_controls.ai_open.pressed.emit()
	await _frames(10)
	_check("AI… opens the page in Settings, Claude chosen and nothing more asked",
		(_controls.get("_ai_page") as Control).visible and _ai.who_claude.button_pressed
		and not (_ai.get("_own") as Control).visible)
	await _shot("1_claude")


## Another AI: the column is for it, and says what it lacks.
func _choose_another() -> void:
	print("\n── another AI, on a key ──")
	_ai.who_key.button_pressed = true
	await _frames(6)
	_check("chosen and kept", ProviderSettings.who() == ProviderSettings.WHO_KEY
		and (_ai.get("_own") as Control).visible)
	_check("the column is for it: Claude's model row and key form gone",
		not (_chat.get("_settings") as Control).visible
		and not (_chat.get("_key_form") as Control).visible)
	var custom: int = ProviderSettings.ORDER.find("custom")
	_ai.provider_choice.select(custom)
	_ai.provider_choice.item_selected.emit(custom)
	await _frames(4)
	_check("another OpenAI-compatible server: its address asked for",
		(_ai.get("_base_row") as Control).visible and ProviderSettings.chosen()["provider"] == "custom")
	_type(_ai.base_field, "http://127.0.0.1:%d/v1" % PORT)
	_ai.base_field.text_submitted.emit(_ai.base_field.text)
	await _until(func() -> bool: return _ai.model_words().contains("Could not list"), 10.0)
	_check("without the key the server's list is refused, and said: %s" % _ai.model_words(),
		_ai.model_words().contains("refused the key"))


func _the_key() -> void:
	print("\n── the key ──")
	_check("the key's field hides what is typed", _ai.key_field.secret)
	_type(_ai.key_field, "sk-stub with a space in it, no key at all")
	_ai.key_field.text_submitted.emit(_ai.key_field.text)
	await _frames(3)
	_check("a key with a space is refused beside its field: %s" % _ai.key_words().strip_edges(),
		_ai.key_words().contains("no spaces") and ProviderSettings.load_key("custom").is_empty())
	_type(_ai.key_field, _key)
	_ai.show_key.button_pressed = true
	await _frames(2)
	_check("Show shows it", not _ai.key_field.secret and _ai.show_key.text == "Hide")
	await _shot("2_key_shown")
	_ai.show_key.button_pressed = false
	await _frames(2)
	_check("Hide hides it again", _ai.key_field.secret)
	_ai.key_field.text_submitted.emit(_ai.key_field.text)
	await _frames(3)
	_check("kept, and cleared from the field; the field shows its fingerprint: %s"
		% _ai.key_field.placeholder_text, _ai.key_field.text.is_empty()
		and ProviderSettings.load_key("custom") == _key
		and _ai.key_field.placeholder_text.contains(ProviderSettings.fingerprint(_key))
		and not _ai.key_field.placeholder_text.contains(_key))
	_check("where it is kept, said beside it: %s" % _ai.key_words().strip_edges(),
		_ai.key_words().contains("encrypted") and _ai.key_words().contains("never to Brickworks"))


func _the_models() -> void:
	print("\n── the models ──")
	await _until(func() -> bool: return _ai.model_list.item_count == 4, 10.0)
	_check("the server's own list, read with the key: %d models (%s)" % [_ai.model_list.item_count,
		_ai.model_words()], _ai.model_list.item_count == 4)
	_type(_ai.model_filter, "blind")
	await _frames(2)
	_check("filtered as typed: %d shown" % _ai.model_list.item_count,
		_ai.model_list.item_count == 1 and str(_ai.model_list.get_item_metadata(0)) == "stub-blind")
	_type(_ai.model_filter, "")
	await _frames(2)
	_pick("gpt-6.1-sol")
	await _frames(2)
	_check("an OpenAI reasoning model: effort offered, temperature not",
		(_ai.get("_effort_row") as Control).visible
		and not (_ai.get("_temperature_row") as Control).visible)
	_pick("stub-sees")
	await _frames(2)
	_check("a model that does not reason: temperature offered, effort not",
		not (_ai.get("_effort_row") as Control).visible
		and (_ai.get("_temperature_row") as Control).visible)
	_ai.temperature_on.button_pressed = true
	_ai.temperature.value = 0.3
	_ai.max_out.value = 4000
	await _frames(2)
	var kept: Dictionary = ProviderSettings.chosen()
	_check("model and parameters kept as set: %s %s" % [kept["model"], str(kept["params"])],
		kept["model"] == "stub-sees" and is_equal_approx(float(kept["params"].get("temperature", 0)),
			0.3) and int(kept["params"].get("max_out", 0)) == 4000
		and not kept["params"].has("reasoning_effort"))
	# Typed: any id, used as it is.
	_type(_ai.model_filter, "my-own-model")
	_ai.model_filter.text_submitted.emit(_ai.model_filter.text)
	await _frames(2)
	_check("a name not in the list, typed and Enter, is used as it is",
		ProviderSettings.chosen()["model"] == "my-own-model")
	_pick("stub-sees")
	await _frames(2)


func _tests() -> void:
	print("\n── Test ──")
	var said: Dictionary = {}
	for model: String in ["stub-blind", "stub-notools", "stub-sees"]:
		_pick(model)
		await _frames(2)
		_ai.test_button.pressed.emit()
		await _until(func() -> bool: return not _ai.test_button.disabled, 30.0)
		said[model] = _ai.test_words()
		print("    %s: %s" % [model, said[model]])
		if model == "stub-blind":
			await _shot("3_tested_blind")
	_check("a model that sees and calls tools: \"%s\"" % said["stub-sees"],
		said["stub-sees"] == "tools ✓, pictures ✓: this model can design here")
	_check("one the provider refuses pictures for, in the brief's words",
		said["stub-blind"] == "tools ✓, pictures ✗: fresh eyes and view_model won't work with this model")
	_check("one that answers in words: tools ✗",
		str(said["stub-notools"]).begins_with("tools ✗, pictures ✓: this model cannot design here"))
	var notools: Dictionary = ProviderSettings.tested("custom", "stub-notools",
		"http://127.0.0.1:%d/v1" % PORT)
	_check("what Test found is kept per model", not notools.is_empty()
		and not bool(notools["tools"]) and bool(notools["pictures"]))
	var asked: Array = _requests().filter(func(one: Dictionary) -> bool: return bool(one.get("test", false)))
	_check("each Test was two real calls to the provider, with the key: %d" % asked.size(),
		asked.size() == 6 and asked.all(func(one: Dictionary) -> bool: return bool(one["key_is_stub"])))
	_check("...with the parameters chosen (temperature 0.3, at most 4000)",
		asked.slice(4).all(func(one: Dictionary) -> bool:
			return is_equal_approx(float(one["temperature"]), 0.3) and int(one["max_tokens"]) == 4000))
	await _shot("4_tested")


## As a restart reads it: from the files, nothing held in memory.
func _kept() -> void:
	print("\n── kept, and read back ──")
	var file: String = ProviderSettings.key_file("custom")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(file)
	_check("the key's file is encrypted: it does not hold the key",
		bytes.size() > 16 and bytes.slice(0, 4).get_string_from_ascii() == ProviderSettings.ENCRYPTED
		and not _holds(bytes, _key))
	var fresh := AiSettings.new()
	root.add_child(fresh)
	await _frames(4)
	var kept: Dictionary = ProviderSettings.chosen()
	_check("read back: another AI, the server, its address, stub-sees, 0.3, 4000",
		ProviderSettings.who() == ProviderSettings.WHO_KEY and kept["provider"] == "custom"
		and kept["base"] == "http://127.0.0.1:%d/v1" % PORT and kept["model"] == "stub-sees"
		and fresh.who_key.button_pressed and fresh.base_field.text == kept["base"]
		and fresh.provider_choice.selected == ProviderSettings.ORDER.find("custom")
		and fresh.temperature_on.button_pressed and is_equal_approx(fresh.temperature.value, 0.3)
		and int(fresh.max_out.value) == 4000)
	_check("the key read back from its file, shown as its fingerprint",
		ProviderSettings.load_key("custom") == _key and fresh.key_field.text.is_empty()
		and fresh.key_field.placeholder_text.contains(ProviderSettings.fingerprint(_key)))
	fresh.queue_free()
	_controls.call("_show_designer")
	_check("Settings' link says who designs now: %s" % _controls.ai_open.text,
		_controls.ai_open.text == "AI: stub-sees…")
	_ai.remember.button_pressed = false
	await _frames(2)
	_check("Remember unticked: for this visit only, the file gone, the key still in use",
		not FileAccess.file_exists(file) and ProviderSettings.load_key("custom") == _key
		and _ai.key_words().contains("this visit only"))
	_ai.remember.button_pressed = true
	await _frames(2)
	_check("ticked again: kept on the device", FileAccess.file_exists(file))


## Every control named, and Tab through them in the order they are read.
func _names_and_keys() -> void:
	print("\n── for a screen reader and a keyboard ──")
	var unnamed: Array = []
	for control: Node in _ai.find_children("*", "Control", true, false):
		var one: Control = control
		if not one.is_visible_in_tree() or one is ScrollBar:
			continue
		if not (one is BaseButton or one is LineEdit or one is SpinBox or one is ItemList):
			continue
		var name: String = str(one.accessibility_name)
		if name.is_empty() and one is Button:
			name = (one as Button).text
		if name.is_empty():
			unnamed.append(one.get_class())
	_check("every control on the page has a name a screen reader says: %s" % str(unnamed),
		unnamed.is_empty())
	var walked: Array[Control] = []
	var at: Control = _ai.who_claude
	for _n: int in 40:
		walked.append(at)
		at = at.find_next_valid_focus()
		if at == null or walked.has(at):
			break
	var order: Array[Control] = [_ai.who_claude, _ai.who_key, _ai.provider_choice,
		_ai.base_field, _ai.key_field, _ai.show_key, _ai.remember, _ai.forget,
		_ai.model_filter, _ai.refresh, _ai.model_list, _ai.temperature_on,
		_ai.test_button, _ai.design_button]
	var places: Array = order.map(func(one: Control) -> int: return walked.find(one))
	var sorted: Array = places.duplicate()
	sorted.sort()
	_check("Tab reaches each, in reading order: %s" % str(places),
		not places.has(-1) and places == sorted)


## Design with it: the assistant's column, the brief, and the stub designs.
func _design() -> void:
	print("\n── design with it ──")
	var before: int = _requests().size()
	_ai.design_button.pressed.emit()
	await _frames(10)
	var named: Dictionary = _chat.controls_by_name()
	var footer: String = (_chat.get("_which_key") as Label).text
	_check("Design with it: Settings closed, the brief ready: %s" % footer,
		not _controls.visible and (named["brief"] as Control).has_focus()
		and footer.contains("stub-sees") and footer.contains(ProviderSettings.fingerprint(_key))
		and not footer.contains(_key) and not (named["build"] as Button).disabled)
	await _shot("5_column")
	(named["brief"] as TextEdit).text = BRIEF
	(named["build"] as Button).pressed.emit()
	var loop: DesignerLoop = _main.call("designer")
	_check("the brief goes to the loop, on the chosen provider",
		loop != null and loop.busy() and loop.provider.model == "stub-sees")
	var outcome: Array = []
	if loop != null:
		loop.finished.connect(func(ok: bool, summary: String) -> void:
			outcome.append_array([ok, summary]))
		await _until(func() -> bool: return not outcome.is_empty(), 240.0)
	await _frames(10)
	_check("it finishes on the model's own last word: %s" % str(outcome),
		outcome.size() == 2 and bool(outcome[0]) and str(outcome[1]).begins_with("I built a red tower"))
	var world: BrickWorld = _main.get("_world")
	var assistant: Assistant = _main.get("_assistant")
	var parts: int = world.bricks().filter(func(brick: BrickWorld.Brick) -> bool:
		return not assistant.scenery.has(brick.id)).size()
	_check("the tower stands: %d parts" % parts, parts == 6)
	var eyes: Dictionary = assistant.call("fresh_eyes").get("last")
	_check("the fresh look was asked and answered", (eyes.get("changes", []) as Array).size() == 3)
	_check("saved", FileAccess.file_exists(ModelStore.SAVE_DIR + "stub-tower.ldr"))
	var run: Array = _requests().slice(before).filter(func(one: Dictionary) -> bool:
		return not bool(one.get("listed", false)) and not bool(one.get("test", false)))
	_check("%d design requests, each with the key, temperature 0.3 and at most 4000" % run.size(),
		run.size() >= 7 and run.all(func(one: Dictionary) -> bool:
			return (bool(one["key_is_stub"]) and is_equal_approx(float(one["temperature"]), 0.3)
				and int(one["max_tokens"]) == 4000 and str(one["model"]) == "stub-sees")))
	var card: String = ""
	for label: Node in (_chat.get("_log") as Node).find_children("*", "Label", true, false):
		card += (label as Label).text + " | "
	_check("the run's card says Done", card.contains("Done"))
	await _shot("6_designed")


## The key in no file the app wrote but its own, and not even there in plain:
## the log, the settings, the saved model, the stub's record.
func _no_key_anywhere() -> void:
	print("\n── the key, nowhere ──")
	var found: Array = []
	var looked: int = 0
	var folders: Array[String] = ["user://"]
	while not folders.is_empty():
		var folder: String = folders.pop_back()
		for name: String in DirAccess.get_directories_at(folder):
			folders.append(folder.path_join(name))
		for name: String in DirAccess.get_files_at(folder):
			var path: String = folder.path_join(name)
			if FileAccess.get_size(path) > 20_000_000:
				continue
			looked += 1
			if _holds(FileAccess.get_file_as_bytes(path), _key):
				found.append(path)
	var logs: Array = Array(DirAccess.get_files_at("user://logs")) if DirAccess.dir_exists_absolute(
		"user://logs") else []
	_check("in none of the %d files the app wrote, its log (%s) included: %s"
		% [looked, ", ".join(logs), str(found)], found.is_empty() and looked > 3 and not logs.is_empty())


func _pick(model: String) -> void:
	for index: int in _ai.model_list.item_count:
		if str(_ai.model_list.get_item_metadata(index)) == model:
			_ai.model_list.select(index)
			_ai.model_list.item_selected.emit(index)
			return
	_check("the list has %s" % model, false)


func _type(field: LineEdit, text: String) -> void:
	field.grab_focus()
	field.text = text
	field.text_changed.emit(text)


static func _holds(bytes: PackedByteArray, text: String) -> bool:
	var hex: String = bytes.hex_encode()
	var wanted: String = text.to_utf8_buffer().hex_encode()
	var at: int = hex.find(wanted)
	while at >= 0:
		if at % 2 == 0:
			return true
		at = hex.find(wanted, at + 1)
	return false


func _requests() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(_log):
		return out
	for line: String in FileAccess.get_file_as_string(_log).split("\n", false):
		var one: Variant = JSON.parse_string(line)
		if one is Dictionary:
			out.append(one)
	return out


func _until(done: Callable, seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while not bool(done.call()) and Time.get_ticks_msec() < until:
		await process_frame


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/ai_settings/%s_%s.png"
		% [_size, name])
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/ai_settings/%s_%s.png" % [_size, name])


func _check(what: String, ok: bool) -> void:
	if not ok:
		_failures += 1
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
