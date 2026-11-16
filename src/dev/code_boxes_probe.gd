## The sign-in screen's code typed one digit to a box (signinux, 2026-11-13),
## as the site's dialog takes it: the real SignInForm, with an account that
## answers here instead of the deployment and Supabase, so nothing is sent.
##
##   godot --path . --resolution 900x700 --script src/dev/code_boxes_probe.gd
##
## In a window: the clipboard is the display server's, and a headless one
## keeps none, so a paste could never be tried there.
##
## The address step first: Email me a code, then "or", then Sign in with
## orangecheck, each 44 px tall and the form's width. Then the code's step:
## eight boxes (the deployment's code length, api/otp.js `digits`), centred,
## each named "Digit N of 8", the number keyboard, the keys in the first;
## four digits typed fill four boxes and the keys move on; a letter is
## refused; Backspace empties and steps back across boxes; Left and Right
## move; Sign in with a box empty says so and sends nothing; "1234 5678"
## pasted with Ctrl+V into the fifth box fills all eight from the first and
## signs in by itself, the boxes still while it is checked; refused as
## wrong, the row shakes, empties and the keys are back in the first box,
## with the words; "1234-5678" pasted into the third box, refused for a
## limit, keeps its digits; a whole code arriving in the first box at once
## (a password manager's fill) fans out and signs in; and the last digit
## typed signs in. Pictures in shots/code_boxes/.
extends SceneTree

const SHOTS := "res://shots/code_boxes/"
const LIMIT := "Too many attempts just now. Wait a minute and try again."


## The account, answering here: a code asked for is accepted with eight
## digits, and a code checked gets [member answer] after a few frames.
class StubAccount extends Account:
	var answer: String = ""
	var asked: Array[String] = []

	func request_code(_with_email: String) -> String:
		code_digits = 8
		return ""

	func verify_code(_with_email: String, code: String) -> String:
		asked.append(code)
		for _n: int in 12:
			await (Engine.get_main_loop() as SceneTree).process_frame
		return answer


var _failures: int = 0
var _form: SignInForm
var _account: StubAccount
var _done: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.09, 0.1, 0.12)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)
	# On the sign-in screen's own card (SignInGate): its face, edge, corners
	# and margins, 420 wide.
	var card := PanelContainer.new()
	card.position = Vector2(240, 60)
	card.custom_minimum_size = Vector2(420, 0)
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 26
	backing.content_margin_right = 26
	backing.content_margin_top = 22
	backing.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", backing)
	backdrop.add_child(card)
	var margin := MarginContainer.new()
	card.add_child(margin)

	var deployment := Deployment.new()
	deployment.orangecheck_for_everyone = true
	deployment.orangecheck_native = {"project": "pk_test_code_boxes", "auth": "https://ochk.io",
		"audience": "https://brickworks.diy"}
	_account = StubAccount.new()
	_account.keeps = false
	_account.deployment = deployment
	_form = SignInForm.new()
	_form.setup(_account)
	_form.done.connect(func() -> void: _done += 1)
	margin.add_child(_form)
	_form.focus_first()
	await _frames(10)

	print("\nthe address: Email me a code, or, Sign in with orangecheck")
	var named: Dictionary = _form.controls_by_name()
	var send: Button = named["signin_send"]
	var oc: Button = named["signin_orangecheck"]
	var divider: Control = _divider()
	_ok(divider != null and divider.is_visible_in_tree()
		and send.global_position.y < divider.global_position.y
		and divider.global_position.y < oc.global_position.y,
		"\"or\" between Email me a code and Sign in with orangecheck")
	_ok(send.size.y >= 44.0 and oc.size.y >= 44.0 and absf(send.size.x - oc.size.x) < 1.0
		and absf(send.size.x - _form.size.x) < 1.0,
		"both 44 px tall and the form's width (%dx%d, %dx%d, form %d)" % [roundi(send.size.x),
			roundi(send.size.y), roundi(oc.size.x), roundi(oc.size.y), roundi(_form.size.x)])
	await _save("1_address.png")

	print("\nthe code's step")
	(named["signin_email"] as LineEdit).text = "builder@example.org"
	send.pressed.emit()
	await _frames(10)
	named = _form.controls_by_name()
	var row: Control = named.get("signin_code_row")
	var boxes: Array[LineEdit] = []
	if row != null:
		for child: Node in row.get_children():
			if child is LineEdit:
				boxes.append(child)
	_ok(row != null and row.is_visible_in_tree() and boxes.size() == 8,
		"Email me a code moves on to a row of 8 boxes (%d)" % boxes.size())
	if boxes.size() != 8:
		await _save("2_code.png")
		_finish()
		return
	_ok(named["signin_code"] == boxes[0], "signin_code is the first box, for a flow to click")
	var names: Array[String] = []
	var keyboards: bool = true
	for box: LineEdit in boxes:
		names.append(box.accessibility_name)
		keyboards = keyboards and box.virtual_keyboard_type == LineEdit.KEYBOARD_TYPE_NUMBER
	_ok(names[0] == "Digit 1 of 8" and names[7] == "Digit 8 of 8",
		"each named for a screen reader: %s … %s" % [names[0], names[7]])
	_ok(str(row.accessibility_name) == "The code sent to builder@example.org",
		"the row named as the code sent: %s" % row.accessibility_name)
	_ok(keyboards, "the number keyboard on a phone, every box")
	var left: float = boxes[0].global_position.x - _form.global_position.x
	var right: float = _form.global_position.x + _form.size.x - (boxes[7].global_position.x + boxes[7].size.x)
	_ok(absf(left - right) <= 2.0, "the row centred (%d px either side, %d)" % [roundi(left), roundi(right)])
	_ok(boxes[0].size.y >= 44.0 and boxes[0].size.x >= 28.0,
		"each box sized for a thumb (%dx%d)" % [roundi(boxes[0].size.x), roundi(boxes[0].size.y)])
	var small_gap: float = boxes[1].position.x - (boxes[0].position.x + boxes[0].size.x)
	var middle_gap: float = boxes[4].position.x - (boxes[3].position.x + boxes[3].size.x)
	_ok(middle_gap > small_gap, "read in halves: %d px between 4 and 5, %d between the others"
		% [roundi(middle_gap), roundi(small_gap)])
	_ok(boxes[0].has_focus(), "the keys in the first box")
	await _save("2_code.png")

	print("\ntyped")
	await _type("1234")
	_ok(_code_of(boxes) == "1234" and boxes[4].has_focus(),
		"four digits fill four boxes and the keys move on (%s, at %d)" % [_code_of(boxes), _at(boxes)])
	await _save("2b_typed.png")
	await _type("a")
	_ok(_code_of(boxes) == "1234" and boxes[4].text == "" and boxes[4].has_focus(),
		"a letter is refused (%s)" % _code_of(boxes))
	await _key(KEY_BACKSPACE)
	_ok(_code_of(boxes) == "123" and boxes[3].has_focus(),
		"Backspace in an empty box steps back and empties that one (%s, at %d)" % [_code_of(boxes), _at(boxes)])
	await _key(KEY_BACKSPACE)
	_ok(_code_of(boxes) == "12" and boxes[2].has_focus(),
		"...and again (%s, at %d)" % [_code_of(boxes), _at(boxes)])
	await _key(KEY_LEFT)
	var after_left: int = _at(boxes)
	await _key(KEY_RIGHT)
	_ok(after_left == 1 and boxes[2].has_focus(), "Left and Right move (%d, then %d)" % [after_left, _at(boxes)])
	await _type("9")
	await _key(KEY_LEFT)
	await _key(KEY_BACKSPACE)
	_ok(_code_of(boxes) == "12" and boxes[2].text == "" and boxes[2].has_focus(),
		"Backspace in a filled box empties it and stays (%s)" % "|".join(_texts(boxes)))
	(named["signin_go"] as Button).pressed.emit()
	await _frames(4)
	_ok(_form_says().contains("Enter all 8 digits of the code.") and _account.asked.is_empty(),
		"Sign in with a box empty says so and sends nothing (%s)" % _form_says())

	print("\npasted, refused as wrong")
	_account.answer = Account.WRONG_CODE
	DisplayServer.clipboard_set("1234 5678")
	boxes[4].grab_focus()
	await _frames(2)
	await _paste()
	_ok(_code_of(boxes) == "12345678", "\"1234 5678\" pasted into the fifth box fills all eight (%s)" % _code_of(boxes))
	_ok(_account.asked == ["12345678"], "...and signs in by itself (%s)" % str(_account.asked))
	var still: bool = true
	for box: LineEdit in boxes:
		still = still and not box.editable
	_ok(still and (named["signin_go"] as Button).text == "Checking…",
		"the boxes still while it is checked, Sign in saying Checking…")
	var shaken: float = 0.0
	for _n: int in 40:
		await process_frame
		shaken = maxf(shaken, absf(float(row.get("shake_offset"))))
	_ok(shaken > 2.0, "refused, the row shakes (%.1f px)" % shaken)
	_ok(_code_of(boxes) == "" and boxes[0].has_focus() and boxes[0].editable,
		"...empties, and the keys are back in the first box (%s, at %d)" % [_code_of(boxes), _at(boxes)])
	_ok(_form_says().contains("That code is wrong or has expired. Check it, or ask for a new one."),
		"...saying so in words")
	await create_timer(0.5).timeout
	await _save("3_wrong.png")

	print("\npasted, refused for a limit")
	_account.answer = LIMIT
	DisplayServer.clipboard_set("1234-5678")
	boxes[2].grab_focus()
	await _frames(2)
	await _paste()
	for _n: int in 30:
		await process_frame
	_ok(_account.asked.size() == 2 and _account.asked[1] == "12345678",
		"\"1234-5678\" pasted into the third box: all eight, from the first (%s)" % str(_account.asked))
	_ok(_code_of(boxes) == "12345678" and _form_says().contains("Too many attempts"),
		"refused for a limit, the digits are kept to try again (%s)" % _code_of(boxes))

	print("\na whole code at once, and the last digit")
	_account.answer = ""
	for box: LineEdit in boxes:
		box.text = ""
	boxes[0].grab_focus()
	await _frames(2)
	# Pasted by the box's own menu (right-click, Paste), which reaches the
	# box without passing the keys, as a fill or a phone's paste does.
	DisplayServer.clipboard_set("8765 4321")
	boxes[0].menu_option(LineEdit.MENU_PASTE)
	for _n: int in 30:
		await process_frame
	_ok(_account.asked.size() == 3 and _account.asked[2] == "87654321" and _done == 1,
		"a whole code arriving in the first box by its own Paste fans out and signs in (%s)" % str(_account.asked))
	send.pressed.emit()
	await _frames(10)
	boxes = []
	for child: Node in (_form.controls_by_name()["signin_code_row"] as Node).get_children():
		if child is LineEdit:
			boxes.append(child)
	await _type("1122334")
	_ok(_account.asked.size() == 3, "seven digits send nothing")
	await _type("4")
	for _n: int in 30:
		await process_frame
	_ok(_account.asked.size() == 4 and _account.asked[3] == "11223344" and _done == 2,
		"the eighth digit typed signs in by itself (%s)" % str(_account.asked))

	print("\non a phone's card")
	send.pressed.emit()
	await _frames(4)
	card.custom_minimum_size = Vector2(358, 0)
	card.size = Vector2.ZERO
	await _frames(6)
	var last: LineEdit = boxes[7]
	var inside: bool = last.global_position.x + last.size.x <= _form.global_position.x + _form.size.x + 0.5 \
		and boxes[0].global_position.x >= _form.global_position.x - 0.5
	_ok(card.size.x <= 358.5 and inside and boxes[0].size.x >= 30.0,
		"the row narrows to a 358 px card, nothing past it (card %d, boxes %d wide)" % [roundi(card.size.x),
			roundi(boxes[0].size.x)])
	await _save("4_phone.png")
	_finish()


## The "or" between the two ways in: a row holding a Label that says it.
func _divider() -> Control:
	for child: Node in _form.get_children():
		if child is BoxContainer:
			for inner: Node in child.get_children():
				if inner is Label and (inner as Label).text == "or":
					return child as Control
	return null


func _code_of(boxes: Array[LineEdit]) -> String:
	return "".join(_texts(boxes))


func _texts(boxes: Array[LineEdit]) -> PackedStringArray:
	var out := PackedStringArray()
	for box: LineEdit in boxes:
		out.append(box.text)
	return out


func _at(boxes: Array[LineEdit]) -> int:
	for at: int in boxes.size():
		if boxes[at].has_focus():
			return at
	return -1


func _form_says() -> String:
	var said := PackedStringArray()
	for child: Node in _form.find_children("*", "Label", true, false):
		if (child as Label).is_visible_in_tree():
			said.append((child as Label).text)
	return "\n".join(said)


func _frames(n: int) -> void:
	for _n: int in n:
		await process_frame


func _key(code: Key, ctrl: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


func _paste() -> void:
	await _key(KEY_V, true)


func _type(text: String) -> void:
	for character: String in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	await _frames(3)


func _save(name: String) -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(SHOTS + name))
	print("  wrote shots/code_boxes/%s" % name)


func _ok(ok: bool, what: String) -> void:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _finish() -> void:
	print("")
	print("%d FAILED" % _failures if _failures else "the code is typed one digit to a box, and the last one signs in")
	quit(1 if _failures else 0)
