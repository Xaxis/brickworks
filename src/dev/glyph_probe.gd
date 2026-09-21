## Is every character the app shows one the font can draw?
##
##   godot --headless --path . --script src/dev/glyph_probe.gd
##
## A character the font does not have draws as an empty box. It does not
## error, it does not warn, and it looks fine to whoever wrote it if
## their editor has a fuller font than the build ships — which is
## everyone's editor.
##
## This app has shipped tofu twice. First the chevrons and the play and
## pause marks in the booklet, replaced with drawn shapes and words.
## Then, immediately after writing that down, the turn and undo arrows
## on the touch buttons. Twice is a pattern, so this is the check.
##
## It walks everything with text in it — the scene as built, plus the
## pieces that only appear on a touchscreen and so would never be in a
## desktop scene tree — and asks the font about every character.
extends SceneTree

var _missing: Dictionary = {}   ## character -> where it was found
var _looked_at: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var font: Font = ThemeDB.fallback_font
	if font == null:
		print("no font to ask")
		quit(1)
		return

	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 90:
		await process_frame
	_walk(main, font, "the app")

	# The controls that only exist on a touchscreen, and the two
	# versions of the hint strip. A desktop run would never build
	# these, which is exactly how the arrows got through.
	var tools := TouchTools.new()
	root.add_child(tools)
	await process_frame
	_walk(tools, font, "the touch buttons")

	# Both lists, not whichever this platform would show.
	#
	# Asking bindings() on a desktop hands back the keyboard list, so
	# the touch list was never looked at — and the touch list is where
	# the arrows were. This probe passed with three empty boxes on a
	# phone, which is the same blind spot it exists to close, one level
	# up.
	for which: Array in [
		[ControlsHint.for_keyboard(), "the hint strip"],
		[ControlsHint.for_touch(), "the hint strip on a touchscreen"],
	]:
		for binding: ControlsHint.Binding in which[0]:
			for key: String in binding.keys:
				_ask(key, font, "a key on %s" % which[1])
			_ask(binding.verb, font, "a verb on %s" % which[1])

	print("  looked at %d pieces of text" % _looked_at)
	if _missing.is_empty():
		print("")
		print("every character the app shows is one the font can draw")
		quit(0)
		return

	print("")
	for character: String in _missing:
		print("  FAIL  U+%04X '%s' is not in the font — %s" % [
			character.unicode_at(0), character, _missing[character]])
	print("")
	print("%d character(s) would draw as an empty box" % _missing.size())
	quit(1)


func _walk(node: Node, font: Font, where: String) -> void:
	if node.has_method("get_text") or "text" in node:
		var text: Variant = node.get("text")
		if text is String:
			_ask(str(text), font, "%s (%s)" % [where, node.get_class()])
	# Tooltips are shown too, and are as easy to write a stray glyph into.
	if node is Control:
		_ask((node as Control).tooltip_text, font, "a tooltip in " + where)
	for child: Node in node.get_children():
		_walk(child, font, where)


func _ask(text: String, font: Font, where: String) -> void:
	if text.is_empty():
		return
	_looked_at += 1
	for n: int in text.length():
		var character: String = text[n]
		var code: int = character.unicode_at(0)
		# Ordinary whitespace is never in a font as a drawn glyph and
		# never needs to be.
		if code <= 32:
			continue
		if font.has_char(code):
			continue
		if not _missing.has(character):
			_missing[character] = where
