## A copy just made by Open in Brickworks (Main._maybe_copy): three first
## things to do with it, offered once along the top of the model, in the
## look of the other lines there (FirstBuild's offer): Recolour a part, Add
## a part and Build it, and × to put it away (firstminute, 2026-11-23).
##
## The walk behind docs/MASTERPLAN.md's row 11 found a stranger who pressed
## Open in Brickworks on a model, signed in, and was left in a full CAD with
## nothing to say what to do with the copy: of six visits, one put a part
## down and none saved. Each act is one press to the tool a first change
## takes, and does what the app's own commands do (EditVerbs, the parts,
## the timeline), so nothing here is a second way of doing anything.
##
## Gone at the person's first change to the model, however it was made (Main
## ._on_model_edited), at Escape, at ×, and when another model is opened. It
## is offered to a person once ever on this device ([method offer] keeps who
## was offered, ShellPrefs "first_acts"), so a reload, a second copy or a
## second tab does not offer it again.
class_name FirstActs
extends PanelContainer

## The acts, in order, and their words.
const ACTS: Array[String] = ["recolour", "add", "build"]
const WORDS: Dictionary = {"recolour": "Recolour a part", "add": "Add a part", "build": "Build it"}
## What each says it does, for the pointer and a screen reader.
const TIPS: Dictionary = {
	"recolour": "The Paint tool: pick a colour, then click a part to paint it",
	"add": "The parts: pick one, then click where it goes",
	"build": "The timeline: the model step by step, as its booklet builds it"}
## Under this much room across, the line goes without its words.
const NARROW := 560.0
## How many people this device remembers were offered it.
const KEPT := 40

## What each act does: a Callable of no arguments, set by Main.
var acts: Dictionary = {}

var _words: Label
var _buttons: Dictionary = {}
var _close: Button


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	backing.border_color = Color(Look.ACCENT, 0.55)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 14
	backing.content_margin_right = 10
	backing.content_margin_top = 6
	backing.content_margin_bottom = 6
	add_theme_stylebox_override("panel", backing)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(120, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(_words)
	for act: String in ACTS:
		var button: Button = _button(str(WORDS[act]), act == "recolour")
		button.tooltip_text = str(TIPS[act])
		button.pressed.connect(_do.bind(act))
		row.add_child(button)
		_buttons[act] = button
	_close = Button.new()
	_close.text = "×"
	_close.flat = true
	_close.tooltip_text = "Not now"
	_close.focus_mode = Control.FOCUS_NONE
	_close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close.add_theme_font_size_override("font_size", 16)
	_close.pressed.connect(dismiss)
	row.add_child(_close)
	get_viewport().size_changed.connect(_fit)


## The same look as the other lines over the model (FirstBuild._button).
func _button(words: String, main: bool) -> Button:
	var button := Button.new()
	button.text = words
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 13)
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		var base: Color = Color(0.29, 0.5, 0.92) if main else Color(1, 1, 1, 0.08)
		face.bg_color = base.lightened(0.12) if state == "hover" else (
			base.darkened(0.12) if state == "pressed" else base)
		face.set_corner_radius_all(6)
		face.content_margin_left = 12
		face.content_margin_right = 12
		face.content_margin_top = 4
		face.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	return button


## Offered for the copy [param name] to [param person] (the account's id, or
## its address), unless they were offered it before on this device. True
## when it shows.
func offer(name: String, person: String) -> bool:
	if person.is_empty() or offered_before(person):
		return false
	_keep(person)
	_words.text = "“%s” is yours to change:" % name
	_fit()
	visible = true
	return true


## Whether [param person] was offered it before on this device.
static func offered_before(person: String) -> bool:
	var kept: Variant = ShellPrefs.value("first_acts")
	return kept is Array and (kept as Array).has(person)


static func _keep(person: String) -> void:
	var kept: Variant = ShellPrefs.value("first_acts")
	var people: Array = (kept as Array).duplicate() if kept is Array else []
	people.erase(person)
	people.append(person)
	ShellPrefs.put("first_acts", people.slice(maxi(people.size() - KEPT, 0)))


func dismiss() -> void:
	visible = false


func _do(act: String) -> void:
	dismiss()
	var done: Variant = acts.get(act)
	if done is Callable and (done as Callable).is_valid():
		(done as Callable).call()


## Escape, wherever the focus is, puts it away; and goes on to do what it
## does there (puts back what is in hand, lets go of the selection).
func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		dismiss()


func _fit() -> void:
	# A phone held upright has room for the three acts and × alone.
	if _words != null:
		_words.visible = get_viewport_rect().size.x >= NARROW and not (Phone.on() and not Phone.wide())


## Each act's button while it shows, for the page to find
## (tools/web/firstminute_flow.mjs).
func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var named: Dictionary = {"first_close": _close}
	for act: String in ACTS:
		named["first_" + act] = _buttons[act]
	return named


func page_state() -> Dictionary:
	return {"shown": visible, "acts": ACTS.duplicate() if visible else [],
		"words": _words.text if _words != null else ""}
