extends SceneTree

var frames: int = 0
var shot: bool = false
var grid: GridContainer

func _initialize() -> void:
	var panel := PanelContainer.new()
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.94)
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 10
	backing.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", backing)
	panel.position = Vector2(0, 0)
	panel.size = Vector2(340, 110)
	root.add_child(panel)

	grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 4)
	panel.add_child(grid)
	for n: int in range(4):
		var b := Button.new()
		b.custom_minimum_size = Vector2(74, 84)
		b.toggle_mode = true
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.set_anchors_preset(Control.PRESET_FULL_RECT)
		b.add_child(box)
		var lab := Label.new()
		lab.text = ["plain", "focus", "press", "both"][n]
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.add_theme_font_size_override("font_size", 9)
		lab.modulate = Color(1, 1, 1, 0.65)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(lab)
		grid.add_child(b)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 10:
		return false
	if not shot:
		(grid.get_child(2) as Button).button_pressed = true
		(grid.get_child(3) as Button).button_pressed = true
		(grid.get_child(1) as Button).grab_focus()
		shot = true
		return false
	if frames < 20:
		return false
	var img: Image = root.get_texture().get_image()
	img.save_png("/private/tmp/claude-501/-Users-wilneeley-Projects-lego-emulator/74b3e6cf-d7f3-4f3b-a3f5-adf7aa464ba6/scratchpad/cells.png")
	print("saved ", img.get_size())
	return true
