## Settings, AI: who designs, and for a model on the person's own key, which
## provider, which model, the key, and the settings a reply is made with.
##
## docs/PROVIDERS.md, section 6. One question first, then only what it needs:
## Claude, as it was (the connector, My Claude, or an Anthropic key in the
## assistant's column), or another AI on the person's own key. For that:
##
##   Provider, from ProviderSettings' presets, and Address for a server that
##   is not a big host's (a server on this computer, or any other that
##   speaks OpenAI's Chat Completions).
##   API key: a password field with Show, Remember on this device, Forget,
##   and where it is kept and who could read it, in words beside it. Kept
##   the moment it is given (Enter, or leaving the field) and then cleared
##   from the field: a key left in a field is a screenshot away from being
##   someone else's. The fingerprint says which key is kept.
##   Model: the provider's own list (its models endpoint, asked as soon as
##   there is a key), filtered by what is typed; Enter on a name not in the
##   list uses it as it is.
##   Temperature where the model takes one, the most a reply may write, and
##   the reasoning effort for a model that reasons.
##   Test: two real, minimal calls (ModelTest), and what works said plainly.
##   Design with it: the assistant's brief, ready for this model.
##
## Every change is kept at once, as the rest of Settings is.
class_name AiSettings
extends VBoxContainer

## Something kept changed: who designs, or with what.
signal changed
## Design with it was pressed: the assistant's brief is wanted.
signal design_wanted
## Test has answered, in [param said]: for the page to scroll it into sight.
signal tested(said: Control)

## Interface units: the width of a row's name.
const LABEL_WIDE := 100.0
const NOTE := Color(0.62, 0.65, 0.72)
const WRONG := Color(1.0, 0.6, 0.5)

var who_claude: CheckBox
var who_key: CheckBox
var provider_choice: OptionButton
var base_field: LineEdit
var key_field: LineEdit
var show_key: Button
var remember: CheckBox
var forget: Button
var model_filter: LineEdit
var model_list: ItemList
var refresh: Button
var temperature_on: CheckBox
var temperature: SpinBox
var max_out: SpinBox
var effort_choice: OptionButton
var test_button: Button
var design_button: Button

var _own: VBoxContainer
var _base_row: Control
var _base_note: Label
var _key_note: Label
var _key_problem: Label
var _model_note: Label
var _temperature_row: Control
var _effort_row: Control
var _test_said: Label
var _test_detail: Label
var _claude_note: Label

## The provider shown, by its preset's id, and the model chosen for it.
var _id: String = ProviderSettings.DEFAULT_PROVIDER
var _model: String = ""
## The provider's models, as its list gave them (Provider.listed's shape).
var _listed: Array = []
## Bumped by each list asked for, so an older answer arriving late is dropped.
var _asking: int = 0
## How asking for the list went, when it is not simply there.
var _list_said: String = ""
var _tester: ModelTest
## True while the controls are being set from what is kept, so setting them
## keeps nothing.
var _showing: bool = false


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_tester = ModelTest.new()
	add_child(_tester)
	_build()
	show_kept()


func _build() -> void:
	add_child(_words("Who designs", 12))
	var who := ButtonGroup.new()
	who_claude = _radio("Claude, on your Claude plan or Anthropic key", who)
	_claude_note = _note("Connect Claude, My Claude, or a key in the assistant's column, as before.")
	add_child(_claude_note)
	who_key = _radio("Another AI, on your own API key", who)
	who_key.toggled.connect(func(on: bool) -> void:
		_own.visible = on
		if not _showing:
			ProviderSettings.set_who(ProviderSettings.WHO_KEY if on else ProviderSettings.WHO_CLAUDE)
			changed.emit())

	_own = VBoxContainer.new()
	_own.add_theme_constant_override("separation", 8)
	add_child(_own)
	_own.add_child(HSeparator.new())

	provider_choice = OptionButton.new()
	provider_choice.accessibility_name = "Provider"
	provider_choice.add_theme_font_size_override("font_size", 12)
	provider_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# As wide as the page, not as its longest name: the page fits a phone.
	provider_choice.fit_to_longest_item = false
	provider_choice.clip_text = true
	for id: String in ProviderSettings.ORDER:
		provider_choice.add_item(str(ProviderSettings.PRESETS[id]["name"]))
	provider_choice.item_selected.connect(func(index: int) -> void:
		if not _showing:
			_show_provider(ProviderSettings.ORDER[index], true))
	_own.add_child(_row("Provider", provider_choice))

	base_field = _field("Address", "https://…/v1")
	base_field.text_submitted.connect(func(_text: String) -> void: _base_given())
	base_field.focus_exited.connect(_base_given)
	_base_row = _row("Address", base_field)
	_own.add_child(_base_row)
	_base_note = _note("")
	_own.add_child(_base_note)

	key_field = _field("API key", "Paste your key")
	key_field.secret = true
	key_field.text_submitted.connect(func(_text: String) -> void: _keep_key())
	key_field.focus_exited.connect(_keep_key)
	show_key = Button.new()
	show_key.text = "Show"
	show_key.toggle_mode = true
	show_key.accessibility_name = "Show the key as it is typed"
	show_key.add_theme_font_size_override("font_size", 12)
	show_key.toggled.connect(func(on: bool) -> void:
		key_field.secret = not on
		show_key.text = "Hide" if on else "Show")
	var key_row: HBoxContainer = _row("API key", key_field)
	key_row.add_child(show_key)
	_own.add_child(key_row)
	_key_problem = _note("")
	_key_problem.add_theme_color_override("font_color", WRONG)
	_own.add_child(_key_problem)
	var keeping := HBoxContainer.new()
	keeping.add_theme_constant_override("separation", 8)
	remember = CheckBox.new()
	remember.text = "Remember on this device"
	remember.button_pressed = true
	remember.add_theme_font_size_override("font_size", 12)
	remember.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	remember.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remember.toggled.connect(func(on: bool) -> void:
		if _showing:
			return
		# The key in use moves: into the file, or out of it to this visit.
		var key: String = ProviderSettings.load_key(_id)
		if not key.is_empty():
			ProviderSettings.remember(_id, key, on)
		_show_key_state())
	keeping.add_child(remember)
	forget = Button.new()
	forget.text = "Forget the key"
	forget.add_theme_font_size_override("font_size", 12)
	forget.pressed.connect(func() -> void:
		ProviderSettings.forget(_id)
		_show_key_state()
		_fetch()
		changed.emit())
	keeping.add_child(forget)
	_own.add_child(_indented(keeping))
	_key_note = _note("")
	_own.add_child(_indented(_key_note))

	model_filter = _field("Model", "Filter, or any model's id and Enter")
	model_filter.text_changed.connect(func(_text: String) -> void: _fill_models())
	model_filter.text_submitted.connect(_model_typed)
	model_filter.gui_input.connect(func(event: InputEvent) -> void:
		# Down from the filter goes into the list, as in any combo box.
		var key: InputEventKey = event as InputEventKey
		if key != null and key.pressed and key.keycode == KEY_DOWN and model_list.item_count > 0:
			model_list.grab_focus()
			if model_list.get_selected_items().is_empty():
				model_list.select(0)
			model_filter.accept_event())
	refresh = Button.new()
	refresh.text = "Refresh"
	refresh.accessibility_name = "Ask the provider for its models again"
	refresh.add_theme_font_size_override("font_size", 12)
	refresh.pressed.connect(func() -> void:
		_keep_key()
		_fetch())
	var model_row: HBoxContainer = _row("Model", model_filter)
	model_row.add_child(refresh)
	_own.add_child(model_row)
	model_list = ItemList.new()
	model_list.accessibility_name = "Models"
	model_list.custom_minimum_size = Vector2(0, 118)
	model_list.add_theme_font_size_override("font_size", 12)
	model_list.item_selected.connect(func(index: int) -> void:
		_choose_model(str(model_list.get_item_metadata(index))))
	_own.add_child(_indented(model_list))
	_model_note = _note("")
	_own.add_child(_indented(_model_note))

	temperature_on = CheckBox.new()
	temperature_on.text = "Set"
	temperature_on.accessibility_name = "Set a temperature"
	temperature_on.add_theme_font_size_override("font_size", 12)
	temperature_on.toggled.connect(func(on: bool) -> void:
		temperature.editable = on
		_save())
	temperature = _number("Temperature", 0.0, 2.0, 0.05)
	temperature.value = 1.0
	temperature.editable = false
	temperature.value_changed.connect(func(_value: float) -> void: _save())
	var warmth: HBoxContainer = _row("Temperature", temperature_on)
	temperature_on.size_flags_horizontal = Control.SIZE_FILL
	warmth.add_child(temperature)
	_temperature_row = warmth
	_own.add_child(warmth)

	max_out = _number("Max output, in tokens", 0.0, 1_000_000.0, 1000.0)
	max_out.value_changed.connect(func(_value: float) -> void: _save())
	var most: HBoxContainer = _row("Max output", max_out)
	most.add_child(_note("tokens; 0 is the model's own"))
	_own.add_child(most)

	effort_choice = OptionButton.new()
	effort_choice.accessibility_name = "Reasoning effort"
	effort_choice.add_theme_font_size_override("font_size", 12)
	effort_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	effort_choice.fit_to_longest_item = false
	effort_choice.clip_text = true
	effort_choice.item_selected.connect(func(_index: int) -> void: _save())
	_effort_row = _row("Reasoning", effort_choice)
	_own.add_child(_effort_row)

	var acting := HBoxContainer.new()
	acting.add_theme_constant_override("separation", 8)
	test_button = Button.new()
	test_button.text = "Test"
	test_button.accessibility_name = "Test the model: one tool call and one picture"
	test_button.custom_minimum_size = Vector2(88, 30)
	test_button.pressed.connect(_test)
	acting.add_child(test_button)
	design_button = Button.new()
	design_button.text = "Design with it"
	design_button.accessibility_name = "Design with this model in the assistant"
	design_button.custom_minimum_size = Vector2(0, 30)
	design_button.pressed.connect(func() -> void: design_wanted.emit())
	acting.add_child(design_button)
	_own.add_child(_indented(acting))
	_test_said = Label.new()
	_test_said.add_theme_font_size_override("font_size", 13)
	_test_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_own.add_child(_indented(_test_said))
	_test_detail = _note("")
	_own.add_child(_indented(_test_detail))


## Set every control from what is kept, and ask for the provider's models.
func show_kept() -> void:
	_showing = true
	var own: bool = ProviderSettings.who() == ProviderSettings.WHO_KEY
	who_key.button_pressed = own
	who_claude.button_pressed = not own
	_own.visible = own
	_showing = false
	_show_provider(str(ProviderSettings.chosen()["provider"]), false)


## Show provider [param id] as it was left; [param chosen_now] keeps it as
## the one that designs.
func _show_provider(id: String, chosen_now: bool) -> void:
	_showing = true
	_id = id
	var kept: Dictionary = ProviderSettings.settings_for(id)
	var preset: Dictionary = ProviderSettings.PRESETS[id]
	provider_choice.select(ProviderSettings.ORDER.find(id))
	_model = str(kept["model"])
	var base: String = str(kept["base"])
	base_field.text = base
	base_field.placeholder_text = str(preset["base"]) if not str(preset["base"]).is_empty() \
		else "https://…/v1"
	# An address to give where the preset has none or it is the person's own
	# server; a big host's is its own, and kept out of the way.
	_base_row.visible = str(preset["base"]).is_empty() or not bool(preset["needs_key"]) \
		or not base.is_empty()
	_say(_base_note, "On a web page a server on your own computer answers only if it allows "
		+ "this site (Ollama: OLLAMA_ORIGINS), and the browser asks you first."
		if OS.has_feature("web") and not bool(preset["needs_key"]) and id != "custom" else "")
	var params: Dictionary = kept["params"]
	temperature_on.button_pressed = params.has("temperature")
	temperature.editable = params.has("temperature")
	temperature.value = float(params.get("temperature", 1.0))
	max_out.value = float(params.get("max_out", 0))
	model_filter.text = ""
	_listed = []
	for suggested: String in preset["models"]:
		_listed.append(Provider.listed(suggested))
	_showing = false
	_show_params(str(params.get("reasoning_effort", "")))
	_fill_models()
	_show_key_state()
	_show_test()
	if chosen_now:
		_save()
		changed.emit()
	_fetch()


## The key's field, its note and its buttons, for the key kept now.
func _show_key_state() -> void:
	var preset: Dictionary = ProviderSettings.PRESETS[_id]
	var key: String = ProviderSettings.load_key(_id)
	var on_device: bool = ProviderSettings.kept_on_device(_id)
	if not key.is_empty():
		_showing = true
		remember.button_pressed = on_device
		_showing = false
	key_field.placeholder_text = ("Kept: %s. Paste another to replace it"
		% ProviderSettings.fingerprint(key)) if not key.is_empty() \
		else "Paste your key" if bool(preset["needs_key"]) \
		else "None needed; paste one if the server asks"
	var source: String = ProviderSettings.key_source(_id)
	_key_note.text = ProviderSettings.custody(_id, source if not source.is_empty() else "device")
	# A key from the environment is not the app's to forget.
	forget.visible = source == "device" or source == "visit"


## Keep the key in the field, if there is one: said beside it when it will
## not do, else kept, cleared from the field and the models asked for.
func _keep_key() -> void:
	var typed: String = key_field.text.strip_edges()
	if typed.is_empty():
		_say(_key_problem, "")
		return
	var problem: String = ProviderSettings.remember(_id, typed, remember.button_pressed)
	_say(_key_problem, problem)
	if not problem.is_empty():
		return
	key_field.text = ""
	show_key.button_pressed = false
	_show_key_state()
	_fetch()
	changed.emit()


func _base_given() -> void:
	if _showing:
		return
	_save()
	_fetch()
	changed.emit()


## The provider's own list of its models, asked for: costs nothing, and needs
## the key where the provider takes one.
func _fetch() -> void:
	var preset: Dictionary = ProviderSettings.PRESETS[_id]
	var key: String = ProviderSettings.load_key(_id)
	_asking += 1
	var asking: int = _asking
	if bool(preset["needs_key"]) and key.is_empty():
		_list_said = "Paste a key to see %s's own list of models." % str(preset["name"])
		_fill_models()
		return
	var provider: Provider = ProviderSettings.provider_for(_id, _model, key, base_field.text)
	if provider == null or provider.base_url.strip_edges().is_empty():
		_list_said = "Give the server's address to see its models."
		_fill_models()
		return
	_list_said = "Asking %s for its models…" % str(preset["name"])
	_fill_models()
	var answer: Dictionary = await _tester.models(provider)
	if asking != _asking or not is_inside_tree():
		return
	if not bool(answer["ok"]):
		_list_said = "Could not list the models: %s" % str(answer["error"])
		_fill_models()
		return
	_list_said = ""
	var suggested: Array = preset["models"]
	var models: Array = answer["models"]
	# The suggested first, best first, then the rest by name.
	models.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var at: int = suggested.find(a["id"])
		var bt: int = suggested.find(b["id"])
		if at != bt and (at >= 0 or bt >= 0):
			return bt < 0 or (at >= 0 and at < bt)
		return str(a["id"]) < str(b["id"]))
	_listed = models
	_fill_models()
	_show_params(str(effort_choice.get_item_metadata(effort_choice.selected))
		if effort_choice.selected > 0 else "")


## The list, filtered by what is typed, the chosen model selected.
func _fill_models() -> void:
	model_list.clear()
	var wanted: String = model_filter.text.strip_edges().to_lower()
	for model: Dictionary in _listed:
		var id: String = str(model["id"])
		if not wanted.is_empty() and not id.to_lower().contains(wanted) \
				and not str(model["name"]).to_lower().contains(wanted):
			continue
		var missing: PackedStringArray = []
		if model["tools"] == false:
			missing.append("no tools")
		if model["pictures"] == false:
			missing.append("no pictures")
		var index: int = model_list.add_item(id + (" · " + ", ".join(missing) if not missing.is_empty()
			else ""))
		model_list.set_item_metadata(index, id)
		if id == _model:
			model_list.select(index)
	_model_note.text = "Chosen: %s. %s" % [_model if not _model.is_empty() else "none yet",
		_list_said if not _list_said.is_empty()
		else "%d of %d shown." % [model_list.item_count, _listed.size()] if not wanted.is_empty()
		else "%d to choose from; type to filter, or type any model's id and press Enter."
			% _listed.size()]


## Enter in the filter: the first model shown, or the words as an id.
func _model_typed(text: String) -> void:
	var typed: String = text.strip_edges()
	if typed.is_empty():
		return
	var exact: bool = _listed.any(func(model: Dictionary) -> bool: return str(model["id"]) == typed)
	if not exact and model_list.item_count > 0:
		typed = str(model_list.get_item_metadata(0))
	_choose_model(typed)
	model_filter.text = ""
	_fill_models()


func _choose_model(id: String) -> void:
	if id == _model:
		return
	_model = id
	_show_params("")
	_save()
	_show_test()
	_fill_models()
	changed.emit()


## Temperature and effort, where the chosen model takes them.
func _show_params(effort: String) -> void:
	var info: Dictionary = {}
	for model: Dictionary in _listed:
		if str(model["id"]) == _model:
			info = model
	_temperature_row.visible = ProviderSettings.takes_temperature(_model, info)
	var provider: Provider = ProviderSettings.provider_for(_id, _model, "", base_field.text)
	_showing = true
	effort_choice.clear()
	effort_choice.add_item("The model's own")
	effort_choice.set_item_metadata(0, "")
	for level: String in (provider.efforts() if provider != null else []):
		effort_choice.add_item(level)
		effort_choice.set_item_metadata(effort_choice.item_count - 1, level)
		if level == effort:
			effort_choice.select(effort_choice.item_count - 1)
	_showing = false
	_effort_row.visible = ProviderSettings.takes_effort(_model, info)


## What the person set, as the adapter takes it: only what is set.
func _params() -> Dictionary:
	var params: Dictionary = {}
	if _temperature_row.visible and temperature_on.button_pressed:
		params["temperature"] = snappedf(temperature.value, 0.01)
	if max_out.value > 0:
		params["max_out"] = int(max_out.value)
	if _effort_row.visible and effort_choice.selected > 0:
		params["reasoning_effort"] = str(effort_choice.get_item_metadata(effort_choice.selected))
	return params


func _save() -> void:
	if _showing:
		return
	ProviderSettings.choose(_id, _model, base_field.text if _base_row.visible else "", _params())


func _test() -> void:
	_keep_key()
	_save()
	var why: String = ProviderSettings.not_ready()
	# Test is how a model that calls no tool is found out, so that is no
	# reason not to test it.
	if not why.is_empty() and not why.contains("did not call a tool"):
		_test_said.text = why
		_say(_test_detail, "")
		return
	test_button.disabled = true
	test_button.text = "Testing…"
	_test_said.text = "Asking %s: one tool call and one picture." % _model
	_say(_test_detail, "")
	var base: String = base_field.text if _base_row.visible else ""
	var model: String = _model
	var id: String = _id
	var found: Dictionary = await _tester.run(ProviderSettings.current())
	test_button.disabled = false
	test_button.text = "Test"
	if bool(found["ok"]):
		ProviderSettings.keep_test(id, model, base, found)
	if id != _id or model != _model:
		return
	_test_said.text = str(found["words"])
	_say(_test_detail, str(found["detail"]))
	tested.emit(_test_detail if _test_detail.visible else _test_said)
	changed.emit()


## What the last Test of the chosen model found, if it was tested.
func _show_test() -> void:
	var found: Dictionary = ProviderSettings.tested(_id, _model,
		base_field.text if _base_row.visible else "")
	_test_said.text = (str(found["words"]) + " (tested %s)" % str(found["when"]).get_slice("T", 0)) \
		if not found.is_empty() else "Not tested yet: Test asks the model for one tool call and one picture."
	_say(_test_detail, "")


## The controls, by name, for the page and the probes.
func controls_by_name() -> Dictionary:
	return {"ai_who_claude": who_claude, "ai_who_key": who_key, "ai_provider": provider_choice,
		"ai_address": base_field, "ai_key": key_field, "ai_show_key": show_key,
		"ai_remember": remember, "ai_forget": forget, "ai_model_filter": model_filter,
		"ai_models": model_list, "ai_refresh": refresh, "ai_temperature_on": temperature_on,
		"ai_temperature": temperature, "ai_max_out": max_out, "ai_effort": effort_choice,
		"ai_test": test_button, "ai_design": design_button}


## What Test said last, for the probes.
func test_words() -> String:
	return _test_said.text


func model_words() -> String:
	return _model_note.text


func key_words() -> String:
	return _key_note.text + " " + _key_problem.text


func _row(name: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var words := Label.new()
	words.text = name
	words.custom_minimum_size = Vector2(LABEL_WIDE, 0)
	words.add_theme_font_size_override("font_size", 12)
	row.add_child(words)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _indented(control: Control) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(LABEL_WIDE) + 8)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(control)
	return margin


func _field(name: String, placeholder: String) -> LineEdit:
	var field := LineEdit.new()
	field.accessibility_name = name
	field.placeholder_text = placeholder
	field.custom_minimum_size = Vector2(0, 30)
	field.add_theme_font_size_override("font_size", 12)
	return field


func _number(name: String, least: float, most: float, step: float) -> SpinBox:
	var number := SpinBox.new()
	number.accessibility_name = name
	number.min_value = least
	number.max_value = most
	number.step = step
	number.add_theme_font_size_override("font_size", 12)
	number.get_line_edit().accessibility_name = name
	return number


func _radio(text: String, group: ButtonGroup) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.button_group = group
	box.add_theme_font_size_override("font_size", 12)
	box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(box)
	return box


func _words(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	return label


## A note's words, and the note gone when it has none.
static func _say(label: Label, text: String) -> void:
	label.text = text
	label.visible = not text.is_empty()


func _note(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", NOTE)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.visible = not text.is_empty()
	return label
