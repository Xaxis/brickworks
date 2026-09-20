extends SceneTree

var grid: GridContainer
var log_lines: Array[String] = []
var frames: int = 0
var done: bool = false

func _initialize() -> void:
	grid = GridContainer.new()
	grid.columns = 4
	root.add_child(grid)
	for n: int in range(3):
		var b := Button.new()
		b.text = "p%d" % n
		b.custom_minimum_size = Vector2(74, 84)
		b.toggle_mode = true
		b.pressed.connect(_on_part.bind(n))
		b.button_down.connect(func() -> void: log_lines.append("button_down %d" % n))
		b.button_up.connect(func() -> void: log_lines.append("button_up %d" % n))
		b.toggled.connect(func(on: bool) -> void: log_lines.append("toggled %d -> %s" % [n, on]))
		b.gui_input.connect(func(e: InputEvent) -> void: log_lines.append("gui_input %d %s" % [n, e.as_text()]))
		grid.add_child(b)

func _process(_delta: float) -> bool:
	frames += 1
	if frames < 5 or done:
		return done
	done = true
	var target: Button = grid.get_child(1)
	var centre: Vector2 = target.global_position + target.size * 0.5
	print("centre ", centre, " size ", target.size)
	for pressed: bool in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = centre
		ev.global_position = centre
		root.push_input(ev, true)
	print("AFTER: ", _states())
	var t: Button = grid.get_child(1)
	print("has_focus ", t.has_focus(), " focus_mode ", t.focus_mode)
	var fb: StyleBox = t.get_theme_stylebox("focus")
	print("focus stylebox ", fb)
	if fb is StyleBoxFlat:
		var f: StyleBoxFlat = fb
		print("  draw_center ", f.draw_center, " bg ", f.bg_color,
			" border ", f.border_width_top, " border_color ", f.border_color,
			" expand ", f.expand_margin_top)
	var nb: StyleBox = t.get_theme_stylebox("normal")
	var pb: StyleBox = t.get_theme_stylebox("pressed")
	if nb is StyleBoxFlat and pb is StyleBoxFlat:
		print("  normal bg ", (nb as StyleBoxFlat).bg_color,
			" pressed bg ", (pb as StyleBoxFlat).bg_color,
			" hover bg ", (t.get_theme_stylebox("hover") as StyleBoxFlat).bg_color)
	for line: String in log_lines:
		print(line)
	return true

func _states() -> Array:
	return [(grid.get_child(0) as Button).button_pressed,
		(grid.get_child(1) as Button).button_pressed,
		(grid.get_child(2) as Button).button_pressed]

func _on_part(n: int) -> void:
	log_lines.append("handler for %d entered; states on entry = %s" % [n, _states()])
	for child: Node in grid.get_children():
		var button: Button = child
		button.button_pressed = false
	log_lines.append("handler for %d left;    states on exit  = %s" % [n, _states()])
