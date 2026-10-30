## What is drawn over the model in each view: the main one, and the second
## view beside it while View, Split shows it (SplitView). The handles and
## Connect's points are drawn in both, each clipped to its own view, so what
## is drawn for one never runs over the other. The caller draws in the
## window's units, as its points and the pointer's are.
class_name ViewOverlays
extends CanvasLayer

var camera: CadCamera
## Draws on [param canvas] for [param view] (CadCamera.MAIN or SECOND).
var draw_in: Callable = func(_canvas: Control, _view: int) -> void: pass

var _canvases: Array[Control] = []


func _ready() -> void:
	# Over the model, under the menus and dialogs.
	layer = 2
	for view: int in [CadCamera.MAIN, CadCamera.SECOND]:
		var canvas := Control.new()
		canvas.name = "Main" if view == CadCamera.MAIN else "Second"
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.clip_contents = true
		canvas.visible = false
		canvas.draw.connect(_drawn.bind(view))
		add_child(canvas)
		_canvases.append(canvas)


## Shown over each view there is, and drawn again; or put away.
func show_drawn(on: bool) -> void:
	for view: int in _canvases.size():
		var canvas: Control = _canvases[view]
		var room: Rect2 = rect(view) if on else Rect2()
		var shown: bool = on and room.has_area()
		if shown and (canvas.position != room.position or canvas.size != room.size):
			canvas.position = room.position
			canvas.size = room.size
		canvas.visible = shown
		if shown:
			canvas.queue_redraw()


func is_shown() -> bool:
	return not _canvases.is_empty() and _canvases[0].visible


## [param view]'s part of the window, in the window's units: the second
## view's picture, and for the main view the window less it.
func rect(view: int) -> Rect2:
	if not is_inside_tree():
		return Rect2()
	var whole := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var second: SplitView = camera.second if camera != null else null
	var split: bool = second != null and second.is_showing() and not second.pose().is_empty()
	if view == CadCamera.SECOND:
		return second.picture_rect() if split else Rect2()
	if split:
		whole.size.x = second.picture_rect().position.x
	return whole


## The font the interface draws with.
func font() -> Font:
	return _canvases[0].get_theme_default_font()


func _drawn(view: int) -> void:
	var canvas: Control = _canvases[view]
	canvas.draw_set_transform(-canvas.position)
	draw_in.call(canvas, view)
