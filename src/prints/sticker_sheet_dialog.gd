## The model's sticker sheet: every sticker it uses, how many, and their
## sizes; another stuck on, one moved or peeled off; and the sheet saved to
## print — a PDF at true size or a PNG at 300 dpi (StickerSheet). Below, the
## stickers made before that this model does not use, to stick on too.
class_name StickerSheetDialog
extends PanelContainer

var studio: PrintStudio
## What the model is called, for the sheet's heading.
var title: String = "Model"

var _list: VBoxContainer
var _heading: Label
var _status: Label
var _save_dialog: FileDialog
var _saving: String = ""


func _ready() -> void:
	visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.99)
	backing.border_color = Color(1, 1, 1, 0.16)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	for side: String in ["left", "right", "top", "bottom"]:
		backing.set("content_margin_" + side, 14)
	add_theme_stylebox_override("panel", backing)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_heading = Label.new()
	_heading.add_theme_font_size_override("font_size", 15)
	_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_heading)
	_button(header, "New sticker…", func() -> void:
		close()
		studio.sticker(), "Draw a sticker for a face of the model")
	_button(header, "Close", close, "Back to the model (Escape)")
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	column.add_child(bottom)
	_button(bottom, "Save sheet as PDF", func() -> void: _save("pdf"),
		"One A4 page, every sticker at its true size with a cut line round it: print at 100%")
	_button(bottom, "Save sheet as PNG (300 dpi)", func() -> void: _save("png"),
		"The same page as a picture at 300 dots to the inch")
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 12)
	_status.modulate = Color(1.0, 0.86, 0.6)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_status)


func open() -> void:
	visible = true
	refresh()


func close() -> void:
	visible = false


func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if _list == null or studio == null:
		return
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var library: PartLibrary = studio.library
	var used: Dictionary = Stickers.in_model(studio.world, library)
	var count: int = 0
	for id: String in used:
		count += (used[id] as PackedInt64Array).size()
	_heading.text = "Sticker sheet: %d sticker%s in this model" % [count, "" if count == 1 else "s"]
	var ids: Array = used.keys()
	ids.sort()
	for id: String in ids:
		_list.add_child(_row(id, (used[id] as PackedInt64Array).size()))
	var others: Array = []
	for id: String in library.custom:
		if not used.has(id) and Stickers.is_sticker(library, id):
			others.append(id)
	if not others.is_empty():
		var words := Label.new()
		words.text = "My stickers, not in this model"
		words.add_theme_font_size_override("font_size", 12)
		words.modulate = Color(1, 1, 1, 0.7)
		_list.add_child(words)
		others.sort()
		for id: String in others:
			_list.add_child(_row(id, 0))
	if count == 0 and others.is_empty():
		var none := Label.new()
		none.text = "No stickers yet. \"New sticker…\" draws one for a face of the model."
		none.modulate = Color(1, 1, 1, 0.55)
		_list.add_child(none)


func _row(id: String, count: int) -> Control:
	var library: PartLibrary = studio.library
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var picture := TextureRect.new()
	picture.custom_minimum_size = Vector2(120, 48)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = ImageTexture.create_from_image(StickerSheet._picture(library, id))
	row.add_child(picture)
	var size: Vector2 = Stickers.size_of(library, id) * Lbm.LDU_MM
	var info: PartLibrary.PartInfo = library.parts.get(id)
	var words := Label.new()
	words.text = "%s\n%s x %s mm%s" % [StickerSheet._title(info.name if info != null else id),
		String.num(size.x, 1), String.num(size.y, 1), "  ·  %d on the model" % count if count > 0 else ""]
	words.add_theme_font_size_override("font_size", 12)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	_button(row, "Stick on…", func() -> void:
		close()
		studio.stick_again(id), "Stick one on a face the next click names")
	if count > 0:
		_button(row, "Move…", func() -> void:
			close()
			studio.move(id), "Peel one off and stick it where the next click says")
		_button(row, "Peel off", func() -> void: studio.peel(id), "Take one off the model")
	row.set_meta("sticker", id)
	return row


func _button(row: Container, text: String, action: Callable, tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	button.pressed.connect(action)
	row.add_child(button)
	return button


# -- saving the sheet ----------------------------------------------------------------


func _save(kind: String) -> void:
	var items: Array = StickerSheet.items_for(studio.world, studio.library)
	if items.is_empty():
		_status.text = "There are no stickers in this model to print."
		return
	var name: String = "%s stickers.%s" % [title, kind]
	var bytes: PackedByteArray = sheet_bytes(kind)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, name, "application/pdf" if kind == "pdf"
			else "image/png")
		_status.text = "Saved %s: print it at actual size (100%%)." % name
		return
	_saving = kind
	if _save_dialog == null:
		_save_dialog = FileDialog.new()
		_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
		_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_save_dialog.size = Vector2i(760, 520)
		_save_dialog.file_selected.connect(func(path: String) -> void:
			var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				_status.text = "Could not write %s." % path
				return
			file.store_buffer(sheet_bytes(_saving))
			file.close()
			_status.text = "Saved %s: print it at actual size (100%%)." % path)
		add_child(_save_dialog)
	_save_dialog.clear_filters()
	_save_dialog.add_filter("*.%s" % kind, kind.to_upper())
	_save_dialog.current_file = name
	_save_dialog.popup_centered()


## The sheet's bytes: "pdf", or "png" at 300 dpi.
func sheet_bytes(kind: String) -> PackedByteArray:
	var items: Array = StickerSheet.items_for(studio.world, studio.library)
	if kind == "pdf":
		return StickerSheet.pdf(items, title)
	return StickerSheet.png_bytes(StickerSheet.picture(items, title, 300.0), 300.0)


func controls_by_name() -> Dictionary:
	var named: Dictionary = {}
	for button: Node in find_children("*", "Button", true, false):
		match (button as Button).text:
			"Save sheet as PDF": named["sheet_pdf"] = button
			"Save sheet as PNG (300 dpi)": named["sheet_png"] = button
			"Close": named["sheet_close"] = button
			"New sticker…": named["sheet_new"] = button
	var n: int = 0
	for row: Node in _list.get_children():
		if row.has_meta("sticker"):
			for button: Node in row.find_children("*", "Button", true, false):
				named["sheet_%d_%s" % [n, (button as Button).text.trim_suffix("…").to_lower()
					.replace(" ", "_")]] = button
			n += 1
	return named
