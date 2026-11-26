## Once a panel is laid out: a scroll to what a change just put in waits for
## that, not for a count of frames.
##
## A press is read before its frame's layout, and that frame's process_frame
## can come before its layout too. One frame on, the card Build it opened had no
## size yet, and the chat stopped 240 px short of it, 19 clicks in 30
## (chat_follow_probe); the connector form's box just opened was 3,815 px
## tall, and the panel scrolled 16 px where the box fitted (suitegrab). A
## second frame held only because the press was read where those were.
class_name LaidOut
extends RefCounted

signal _passed


## Returns once the layout a change just made sets off is done. A frame lays
## its panels out in one pass of deferred calls, every sort the pass sets off
## done in it, and a call deferred now runs in that pass: so that call is
## waited for, then the next frame, which begins once the pass is done. No
## sort is asked for here: a ScrollContainer sorted before what it holds was
## laid out took its scroll back to fit the shorter content and kept it
## there, 202 px, 2 runs in 4 (connect_form_probe).
static func settled(node: Node) -> void:
	var hook := LaidOut.new()
	(func() -> void: hook._passed.emit()).call_deferred()
	await hook._passed
	if is_instance_valid(node) and node.is_inside_tree():
		await node.get_tree().process_frame


## [param scroll] at the end of what it holds, once that is laid out.
static func to_end(scroll: ScrollContainer) -> void:
	await settled(scroll)
	if is_instance_valid(scroll):
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


## [param control] scrolled into [param scroll]'s view, once it is laid out.
static func into_view(scroll: ScrollContainer, control: Control) -> void:
	await settled(scroll)
	if is_instance_valid(scroll) and is_instance_valid(control) and control.is_visible_in_tree():
		scroll.ensure_control_visible(control)


## [param c], a Label or Button whose words wrap at a word, never narrower
## than its longest word inside its face (and beside a checkbox's box): in a
## row it is given that much, in a flow it goes onto a line of its own, and
## no word of it is cut inside. A wrapping control asks for no width of its
## own, and in a narrow column its row gave it less than a word: "fabricadas"
## in 45 of 61, "hergestellte" in 72 of 87 (wide150b). Measured again when its
## words change, in another language too (minimum_size_changed).
## [param at_least] where it wants more than a word: a status line read as
## a column a word wide beside two buttons.
static func hold_a_word(c: Control, at_least: float = 0.0) -> void:
	var fit := func() -> void:
		if not is_instance_valid(c) or not c.is_inside_tree():
			return
		var text: String = ""
		var beside: float = 0.0
		if c is Label:
			text = c.atr((c as Label).text)
		elif c is Button:
			var button: Button = c as Button
			text = button.atr(button.text)
			var box: Texture2D = button.get_theme_icon("unchecked") if button is CheckBox else button.icon
			if box != null and (button is CheckBox or button.vertical_icon_alignment == VERTICAL_ALIGNMENT_CENTER):
				beside = box.get_width() + button.get_theme_constant("h_separation")
		var font: Font = c.get_theme_font("font")
		var size: int = c.get_theme_font_size("font_size")
		var longest: float = 0.0
		for word: String in text.replace("\n", " ").split(" ", false):
			longest = maxf(longest, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		var least: float = maxf(at_least, ceilf(longest + beside + c.get_theme_stylebox("normal").get_minimum_size().x))
		if absf(c.custom_minimum_size.x - least) > 0.5:
			c.custom_minimum_size.x = least
	c.minimum_size_changed.connect(fit)
	c.theme_changed.connect(fit)
	c.tree_entered.connect(fit)
	fit.call()
