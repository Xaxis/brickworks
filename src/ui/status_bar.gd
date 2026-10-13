## The line along the foot of the window.
##
## On the left, what just happened — or, when nothing has, what the tool
## in use does. On the right, the model: how many parts and whether it
## stands up, how many are selected, what a part snaps to and how far a
## turn goes, and how big a stud is on screen. The counts were a pill over
## the top of the model and the messages a line in the bar beside the
## buttons; every other program keeps both down here.
class_name StatusBar
extends PanelContainer

var shell: Shell

## What the model bar says (ModelBar.say): written there, shown here.
var message: Label
## The parts count and the stability, written by the app (main.gd).
var counts: Label
var _hint: Label
var _selected: Label
var _settings: Label
var _zoom: Label
var _looked_at: int = 0
## What the app is busy with, when it is: Working, in place of the line on
## the left while it lasts.
var working: Working
## Only the work, and only while there is some: the shared model's viewer,
## which hides the builder's bar but still has slow things to say.
var work_only: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.97)
	backing.border_color = Color(1, 1, 1, 0.08)
	backing.border_width_top = 1
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 3
	backing.content_margin_bottom = 4
	add_theme_stylebox_override("panel", backing)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	# One line on the left for both: what was just said, in full white, or
	# the tool's hint, dimmed, when nothing has been. The bar writes into
	# ``message``, which is held here and never drawn itself.
	message = Label.new()
	message.visible = false
	add_child(message)
	working = Working.new()
	working.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(working)
	_hint = _label(row, 1.0)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint.clip_text = true
	_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_hint.custom_minimum_size = Vector2(80, 0)
	counts = _cell(row, "How many parts the model has, and whether it would stand up as built")
	_selected = _cell(row, "How many parts are selected")
	_settings = _cell(row, "What a part snaps to, and how far R turns a selection: both on the toolbar")
	_zoom = _cell(row, "How big one stud is on the screen at the middle of the view")


func _label(row: Container, alpha: float) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9 * alpha))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	return label


## For the shared model's viewer: nothing but the work, and only while
## there is some.
func only_the_work() -> void:
	work_only = true
	for label: Label in [counts, _selected, _settings, _zoom]:
		label.visible = false
		(label.get_meta("line") as Control).visible = false
	visible = Working.is_busy()


## A field on the right, with a line before it and a tooltip saying what
## it is.
func _cell(row: Container, says: String) -> Label:
	var line := VSeparator.new()
	line.add_theme_constant_override("separation", 16)
	line.modulate = Color(1, 1, 1, 0.4)
	row.add_child(line)
	var label: Label = _label(row, 0.82)
	label.tooltip_text = says
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.set_meta("line", line)
	return label


func _process(_delta: float) -> void:
	if shell == null:
		return
	# While something is being worked on, that is what the left says.
	var busy: bool = Working.is_busy()
	if _hint.visible == busy:
		_hint.visible = not busy
	if work_only:
		if visible != busy:
			visible = busy
		return
	# The line on the left at once, every frame: what was said, or the hint.
	var said: String = message.text
	var line: String = said if not said.is_empty() else shell.verbs.hint()
	if _hint.text != line:
		_hint.text = line
		_hint.modulate.a = 1.0 if not said.is_empty() else 0.62
	var now: int = Time.get_ticks_msec()
	if now - _looked_at < 150:
		return
	_looked_at = now
	var count: int = shell.builder.selection.size()
	_selected.text = "%d selected" % count if count > 0 else "nothing selected"
	var snap: String = {"stud": "stud", "half": "½ stud", "half_plate": "½ plate",
		"free": "free"}.get(shell.verbs.snap, shell.verbs.snap)
	_settings.text = "snap %s · turn %d°" % [snap, roundi(shell.verbs.turn_step)]
	_zoom.text = "1 stud ≈ %d px" % roundi(_stud_on_screen())
	# On a narrow screen the message and hint keep the room.
	var narrow: bool = get_viewport().get_visible_rect().size.x < 900.0
	for label: Label in [_settings, _zoom]:
		label.visible = not narrow
		(label.get_meta("line") as Control).visible = not narrow


## A stud's width in interface units, at the distance the view turns about.
func _stud_on_screen() -> float:
	var camera: CadCamera = shell.camera
	if camera == null:
		return 0.0
	var per: float = camera._ldu_per_pixel()
	return BrickLattice.STUD / per if per > 0.0 else 0.0


## The fields, for a check to read.
func fields() -> Dictionary:
	return {"message": message.text, "hint": shell.verbs.hint(), "line": _hint.text,
		"counts": counts.text, "selected": _selected.text, "settings": _settings.text,
		"zoom": _zoom.text}
