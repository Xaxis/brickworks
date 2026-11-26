## Simple's controls over the model (docs: bench/results/simplemode-2026-11-24
## /PLAN.md): the layer Main puts in place of the studio's own, the phone's
## or the desktop's, while it is in Simple (Main.use_controls).
##
## Only the controls change. The model, its undo, the selection, what is in
## hand, the camera and the save are Main's, the same objects in both, so
## nothing is converted going in or out and nothing can be lost by it. Here,
## for now, are the notices over the model (Main lends its strip while this
## is up: a file changed in another tab, a save that failed) and the way
## back, Full studio; the tray, the colours and Undo come with Simple's
## first phase.
class_name SimpleLayer
extends Control

var app: Node

## Where Main's notices strip goes while this is up, over the model's top.
var notices_slot: VBoxContainer
var _full: Button
var _back: PanelContainer


func _ready() -> void:
	name = "SimpleLayer"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	add_child(column)
	notices_slot = VBoxContainer.new()
	notices_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(notices_slot)
	# The way back, in the top right corner, where the studio's own header
	# has Account: a finger's size on a phone.
	_back = PanelContainer.new()
	_back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_back.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	add_child(_back)
	_full = Button.new()
	_full.name = "SimpleFull"
	_full.text = "Full studio"
	_full.tooltip_text = "Every tool of the studio, the same model"
	_full.focus_mode = Control.FOCUS_NONE
	_full.pressed.connect(func() -> void: app.call("use_controls", &"full"))
	_back.add_child(_full)
	resized.connect(_lay_out)
	# Kept under the notices as they come and go.
	notices_slot.resized.connect(_lay_out)
	_lay_out()


## The button a fingertip each way on a phone, and its margin from the
## window's corner.
func _lay_out() -> void:
	if _full == null or not is_inside_tree():
		return
	var gap: float = 12.0
	if Phone.on():
		var target: float = Phone.px(get_viewport(), Phone.TARGET)
		_full.custom_minimum_size = Vector2(target * 2.0, target)
		_full.add_theme_font_size_override("font_size", roundi(Phone.px(get_viewport(), 16.0)))
		gap = Phone.px(get_viewport(), 8.0)
	_back.offset_right = -gap
	_back.offset_top = gap + notices_slot.size.y


## The part of the window the model has: all of it, under the notices.
func model_room(window: Rect2) -> Rect2:
	return window


## Whether a point is on this layer's own controls, for Main to leave alone.
func covers(point: Vector2) -> bool:
	for control: Control in [_full, notices_slot]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(point):
			return true
	return false


## Its controls, for the page to find, while it is up.
func controls_by_name() -> Dictionary:
	return {"simple_full": _full} if is_visible_in_tree() else {}
