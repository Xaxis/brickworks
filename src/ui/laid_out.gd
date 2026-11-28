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


## The meta a holder laid by hand at a width of its own, not by its anchors
## nor its content, keeps that width in: a tablet's panel down the left
## (PhoneShell.Sheet) is 400 of a 768 window. Read from the window, the
## parts bin counted four tiles and five chips across it and held it 452
## wide, and the model beside it lost 52 (greenreds2, the tablet check).
const ACROSS := &"laid_across"


## Where the holder [param c] is laid in starts across, and its width: the
## nearest holder round it that has [constant ACROSS], else the window
## from its left edge.
static func frame(c: Control) -> Vector2:
	var at: Control = c
	while at != null:
		if at.has_meta(ACROSS):
			return Vector2(at.get_global_rect().position.x, float(at.get_meta(ACROSS)))
		at = at.get_parent() as Control
	return Vector2(0.0, c.get_viewport().get_visible_rect().size.x)


## The width the window leaves [param c]: the window's (or the width of what
## its outermost container is pinned in, or the width that container is
## given by hand, [constant ACROSS]), less each panel's and margin's
## sides, each scroller's bar, and what each row it sits in gives the rest of
## that row. Never read off c's own width, nor its holders', which a box wider
## than its room holds wide with it. Nothing (0) out of a window: a phone's
## bin fitted its chips as it was moved into its sheet (ux15_phone).
static func offered(c: Control) -> float:
	if not c.is_inside_tree():
		return 0.0
	var chain: Array[Control] = [c]
	while chain[-1].get_parent() is Container:
		chain.append(chain[-1].get_parent() as Control)
	var across: float = c.get_viewport().get_visible_rect().size.x
	if chain[-1].has_meta(ACROSS):
		across = minf(across, float(chain[-1].get_meta(ACROSS)))
	elif chain[-1].get_parent() is Control:
		across = minf(across, (chain[-1].get_parent() as Control).size.x)
	for n: int in range(chain.size() - 1, 0, -1):
		var holder: Control = chain[n]
		var held: Control = chain[n - 1]
		if holder is PanelContainer:
			across -= holder.get_theme_stylebox("panel").get_minimum_size().x
		elif holder is MarginContainer:
			across -= float(holder.get_theme_constant("margin_left") + holder.get_theme_constant("margin_right"))
		elif holder is ScrollContainer:
			var scroll: ScrollContainer = holder as ScrollContainer
			if scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_SHOW_ALWAYS \
					or (scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
						and scroll.get_v_scroll_bar().visible):
				across -= scroll.get_v_scroll_bar().get_combined_minimum_size().x
		elif holder is HBoxContainer:
			var gap: float = float(holder.get_theme_constant("separation"))
			for other: Node in holder.get_children():
				var beside: Control = other as Control
				if beside != null and beside != held and beside.visible and not beside.top_level:
					across -= beside.get_combined_minimum_size().x + gap
	return across


## [param c], a Label or Button whose words wrap at a word, never narrower
## than its longest word inside its face (and beside a checkbox's box): in a
## row it is given that much, in a flow it goes onto a line of its own, and
## no word of it is cut inside. A wrapping control asks for no width of its
## own, and in a narrow column its row gave it less than a word: "fabricadas"
## in 45 of 61, "hergestellte" in 72 of 87 (wide150b). Measured again when its
## words change, in another language too (minimum_size_changed).
## [param at_least] where it wants more than a word: a status line read as
## a column a word wide beside two buttons. [param whole]: on one line where
## the window leaves it that much (offered), wrapped only where it does not:
## held to a word, a flow put the colours' "Only parts made in it" on four
## lines beside the colour field, and the field four lines tall with it.
static func hold_a_word(c: Control, at_least: float = 0.0, whole: bool = false) -> void:
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
		var face: float = beside + c.get_theme_stylebox("normal").get_minimum_size().x
		var least: float = maxf(at_least, ceilf(longest + face))
		if whole:
			var line: float = ceilf(font.get_string_size(text.replace("\n", " "), HORIZONTAL_ALIGNMENT_LEFT, -1,
				size).x + face)
			least = maxf(least, minf(line, floorf(offered(c))))
		if absf(c.custom_minimum_size.x - least) > 0.5:
			c.custom_minimum_size.x = least
	c.minimum_size_changed.connect(fit)
	c.theme_changed.connect(fit)
	c.tree_entered.connect(fit)
	if whole:
		# What the window leaves it changes with the window and its columns.
		c.item_rect_changed.connect(fit, CONNECT_DEFERRED)
		# Heard only while it is in a window: still connected to the window
		# once freed, the window's next resize called it with nothing.
		var watch := func() -> void:
			var view: Viewport = c.get_viewport()
			if view != null and not view.size_changed.is_connected(fit):
				view.size_changed.connect(fit, CONNECT_DEFERRED)
		var unwatch := func() -> void:
			var view: Viewport = c.get_viewport()
			if view != null and view.size_changed.is_connected(fit):
				view.size_changed.disconnect(fit)
		c.tree_entered.connect(watch)
		c.tree_exiting.connect(unwatch)
		if c.is_inside_tree():
			watch.call()
	fit.call()
