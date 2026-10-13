## The strip across the top: the menus, what this model is called, and who
## is signed in.
##
## It was a row of a dozen buttons — New, Save, Open, Export, Parts list,
## Timeline, Mosaic, Minifig, Help, Account, Clear — with a status line
## squeezed between them. Those are menu items now (Shell), each with its
## key beside it, and the status line is the status bar along the foot.
## What is left here is what a CAD program's title row holds: the menus and
## the document's name. The work behind each item is still done here.
class_name ModelBar
extends PanelContainer

var store: ModelStore
var world: BrickWorld
var builder: Builder

## Where the menus go, between the name of the app and the model's.
var menus: HBoxContainer

var _name: LineEdit
## Written by say(); the status bar shows it (use_status).
var _status: Label = Label.new()
var _saves: PopupMenu
var _confirm: ConfirmationDialog
var _confirm_new: ConfirmationDialog
var _account: Button
var _entries: Array[ModelStore.Entry] = []
var _picker: ModelFilePicker

## An id no index can be, for the menu row that is not a saved model.
# A menu id no saved model's index reaches. Not negative: a PopupMenu
# reports a negative id as the item's index, so "From a file…", first in
# the menu, opened whichever model was first after it.
const IMPORT := 1 << 30

signal cleared()
## A new model: an empty baseplate, no name and a fresh conversation.
signal started_new()
## The model is called something else now: opened, saved, begun or typed.
signal model_named(name: String)
## Someone wants the parts list. The bar does not own the panel — it is
## an overlay across the whole window, not a strip along the top.
signal parts_wanted()
## Someone wants to turn a picture into bricks.
signal mosaic_wanted()
## Someone wants to turn a 3D model into bricks (BrickifyDialog).
signal brickify_wanted()
## The timeline: the build from empty to finished and back.
signal timeline_wanted()
## Someone wants to make a minifigure.
signal minifig_wanted()
signal controls_wanted()
## Someone wants to see who is signed in, or sign out.
signal account_wanted()
signal opened(bricks: int)
## Export's picture of the model, and its parts list for a shop
## ("bricklink" or "rebrickable").
signal picture_wanted()
signal shop_list_wanted(shop: String)
## Export as a BrickLink Studio model (.io).
signal studio_wanted()


## A button's face in each state, faint until pointed at.
const BUTTON_FACES := {"normal": Color(1, 1, 1, 0.06), "hover": Color(1, 1, 1, 0.14),
	"pressed": Color(0.36, 0.6, 1.0, 0.32)}


func _ready() -> void:
	_build()


func _build() -> void:
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.11, 0.12, 0.14, 0.97)
	backing.content_margin_left = 10
	backing.content_margin_right = 10
	backing.content_margin_top = 3
	backing.content_margin_bottom = 3
	add_theme_stylebox_override("panel", backing)

	# Wraps onto a second line rather than running off the side, on a
	# phone: the bar sets the width of everything under it, and a row wider
	# than the page once took the assistant's rail off it.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 2)
	add_child(row)

	var mark := Label.new()
	mark.text = "Brickworks"
	mark.add_theme_font_size_override("font_size", 14)
	mark.modulate = Color(1, 1, 1, 0.75)
	mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	mark.custom_minimum_size = Vector2(0, 28)
	row.add_child(mark)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	row.add_child(gap)

	menus = HBoxContainer.new()
	menus.add_theme_constant_override("separation", 0)
	row.add_child(menus)

	var gap_two := Control.new()
	gap_two.custom_minimum_size = Vector2(12, 0)
	row.add_child(gap_two)

	_name = LineEdit.new()
	_name.text = "Untitled"
	_name.custom_minimum_size = Vector2(200, 0)
	_name.tooltip_text = "What this model is called"
	_name.add_theme_font_size_override("font_size", 13)
	# The store keeps the name, so the autosave keeps it too.
	_name.text_changed.connect(func(text: String) -> void:
		if store != null:
			store.title = text.strip_edges() if not text.strip_edges().is_empty() \
				else ModelStore.UNTITLED
			store.touch()
		model_named.emit(model_name()))
	# Escape puts back the name it had (FocusGuard).
	_name.set_meta("revert_on_escape", true)
	# A click takes the whole name, so what is typed replaces it. The caret
	# went to the end, and a person who clicked "Untitled" and typed My
	# House had a model called "UntitledMy House" (brickworks.diy at
	# dd5c10c, 2026-10-12). A second click places the caret.
	_name.select_all_on_focus = true
	row.add_child(_name)

	var push := Control.new()
	push.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	push.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(push)

	# Who is signed in, and the way out. Everyone using Brickworks is.
	_account = _button(row, "Account", func() -> void: account_wanted.emit(),
		"Who is signed in, and Sign out")

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Clear the baseplate?"
	_confirm.dialog_text = ("Every brick on it goes, and it cannot be undone. "
		+ "Save first if you might want it back.")
	_confirm.ok_button_text = "Clear it"
	_confirm.confirmed.connect(_on_clear)
	add_child(_confirm)

	_confirm_new = ConfirmationDialog.new()
	_confirm_new.title = "Start a new model?"
	_confirm_new.ok_button_text = "Start new without saving"
	_confirm_new.confirmed.connect(_start_new)
	_confirm_new.add_button("Save, then start new", true, "save")
	_confirm_new.custom_action.connect(func(action: StringName) -> void:
		if action == &"save":
			_confirm_new.hide()
			_on_save()
			if not store.has_unsaved_work():
				_start_new())
	add_child(_confirm_new)

	_saves = PopupMenu.new()
	_saves.id_pressed.connect(_on_pick)
	add_child(_saves)


## Show what say() says in a label of someone else's: the status bar's.
func use_status(label: Label) -> void:
	label.text = _status.text
	_status = label


func _button(row: Container, text: String, action: Callable,
		tip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tip
	# Never keeps the keyboard.
	#
	# Godot does not drop focus for a click that lands on no Control, so
	# a toolbar button stayed focused for the rest of the session — and
	# a focused button eats the keys the app wanted. Tab and the arrows
	# stopped reaching the handler after the first click up here, which
	# is two bindings the strip along the bottom promises.
	#
	# It was worse than that while space slid the view: space is also
	# the key that presses a focused button, so panning after touching
	# this row fired whichever one had been clicked. With Clear, that is
	# the model and its undo history.
	#
	# Every other panel in the app already did this. This row was the
	# one that did not.
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# A face of its own, faint until pointed at. They were words on the
	# bar with nothing round them, and read as a heading rather than as
	# twelve things to press.
	for state: String in ["normal", "hover", "pressed"]:
		var face := StyleBoxFlat.new()
		face.bg_color = BUTTON_FACES[state]
		face.border_color = Color(1, 1, 1, 0.1 if state == "normal" else 0.22)
		face.set_border_width_all(1)
		face.set_corner_radius_all(5)
		face.content_margin_left = 9
		face.content_margin_right = 9
		face.content_margin_top = 3
		face.content_margin_bottom = 3
		button.add_theme_stylebox_override(state, face)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.pressed.connect(action)
	row.add_child(button)
	return button


func bind(to: ModelStore) -> void:
	store = to
	store.saved.connect(func(name: String) -> void:
		model_named.emit(name)
		_say_when_stored(name))
	store.loaded.connect(func(name: String, bricks: int) -> void:
		_name.text = name
		model_named.emit(name)
		_say("opened %s — %d bricks" % [name, bricks]))
	store.begun.connect(func(name: String) -> void:
		_name.text = name
		model_named.emit(name))


## The bar's own controls, for the page to find (Main._tell_page).
func controls_by_name() -> Dictionary:
	return {"model_name": _name, "account": _account}


## Who the Account button says is signed in, in its tooltip: the bar has
## no room for an address, and a button the width of one pushed Clear off
## a phone.
func show_account(email: String) -> void:
	if _account != null:
		_account.tooltip_text = ("Signed in as %s. Sign out from here." % email
			if not email.is_empty() else "Who is signed in, and Sign out")


func model_name() -> String:
	var text: String = _name.text.strip_edges()
	return text if not text.is_empty() else "Untitled"


## Say something in the bar's status line. Public because the parts list
## and the booklet live outside the bar but have nowhere else to report.
func say(text: String) -> void:
	_say(text)


func _say(text: String) -> void:
	_status.text = text
	# Clear it after a moment; a status line that never resets stops
	# meaning "just now".
	var timer: SceneTreeTimer = get_tree().create_timer(4.0)
	timer.timeout.connect(func() -> void:
		if _status.text == text:
			_status.text = "")


func _on_save() -> void:
	if store == null:
		return
	if world.brick_count() == 0:
		_say("nothing to save")
		return
	if not store.save_as(model_name()):
		_say("could not save that name")


## "Saved" once it is: on the web a save is in the browser's storage only
## some seconds after it is written (ModelStore.stored), and saying so
## sooner told a person their work was safe while closing the tab lost it.
func _say_when_stored(name: String) -> void:
	var path: String = ModelStore.SAVE_DIR + ModelStore._safe_name(name) + ".ldr"
	if ModelStore.stored(path):
		_say("saved “%s”" % name)
		return
	_status.text = "saving “%s” in this browser…" % name
	for _n: int in 240:
		await get_tree().create_timer(0.5).timeout
		if ModelStore.stored(path):
			break
	_say("saved “%s”" % name if ModelStore.stored(path)
		else "“%s” is not in this browser's storage yet — keep this tab open" % name)


func _on_open() -> void:
	if store == null:
		return
	# Saved models first, then the ones that ship with the app. Their own
	# work belongs at the top; the examples are there so the menu has
	# something in it the first time, when the honest answer to "open
	# what?" used to be "nothing saved yet".
	_entries = store.list_saved()
	var examples: Array[ModelStore.Entry] = store.list_examples()
	_saves.clear()
	# Exporting an .ldr and then having nowhere to put it back was the
	# shape of this before: the app could write the format it reads and
	# could not read the format it writes.
	_saves.add_item("From a file on this computer (LDraw, Studio .io, LDD .lxf)…", IMPORT)
	_saves.add_separator()
	if _entries.is_empty() and examples.is_empty():
		_saves.add_item("nothing saved yet")
		_saves.set_item_disabled(_saves.item_count - 1, true)
	else:
		for n: int in _entries.size():
			_saves.add_item(_entries[n].describe(), n)
		if not examples.is_empty():
			if not _entries.is_empty():
				_saves.add_separator("Examples")
			else:
				_saves.add_separator("Try one of these")
			for example: ModelStore.Entry in examples:
				_saves.add_item(example.describe(), _entries.size())
				_entries.append(example)
	_saves.reset_size()
	_saves.position = Vector2i(get_global_mouse_position()) + Vector2i(0, 8)
	_saves.popup()


func _on_pick(id: int) -> void:
	if id == IMPORT:
		_import()
		return
	if id < 0 or id >= _entries.size():
		return
	var entry: ModelStore.Entry = _entries[id]
	opened.emit(await open_with_progress(entry.path))


## Open a saved model or an example, a slice at a time, the status bar
## counting its parts as they go down (Working). How many landed.
func open_with_progress(path: String) -> int:
	var job: Working.Job = Working.begin("Opening %s…" % path.get_file())
	await job.shown()
	var placed: int = await store.open_paced(path, job)
	job.end()
	return placed


## Somebody else's .ldr, from wherever they keep it.
##
## The picker has to be asked while the click that opened the menu is
## still being handled, or a browser will not open the file dialog at
## all — which is why this is called straight from the menu rather than
## after a confirmation.
func _import() -> void:
	if _picker == null:
		_picker = ModelFilePicker.new()
		add_child(_picker)
		_picker.picked.connect(func(text: String, file_name: String) -> void:
			# A slice at a time, the status bar counting the parts as they
			# go down (Working), drawn before it begins.
			var job: Working.Job = Working.begin("Opening %s…" % file_name.get_file())
			await job.shown()
			var result: Dictionary = await store.open_text_paced(
				text, file_name.get_basename(), job)
			job.end()
			if not str(result["error"]).is_empty():
				_say(str(result["error"]))
				return
			opened.emit(int(result["placed"]))
			var note: String = "opened %d parts" % int(result["placed"])
			if int(result["missing"]) > 0:
				# Named, as an LDD model's are: a Studio model can use a part
				# Studio made, which nothing else has.
				var missing: Dictionary = result.get("missing_ids", {})
				var count: int = 0
				for id: String in missing:
					count += int(missing[id])
				note += " — %d not in the library, left out (%s)" % [count,
					ModelStore.named_counts(missing)]
			if int(result.get("waiting", 0)) > 0:
				note += " — %d are still arriving, open it again in a moment" \
					% int(result["waiting"])
			if not _picker.notes.is_empty():
				note += " — " + _picker.notes
			_say(note))
		_picker.failed.connect(func(why: String) -> void: _say(why))
	_picker.ask()


## What File, Export writes: 0 LDraw, 1 a picture, 2 BrickLink's list,
## 3 Rebrickable's, 4 a Studio model.
func _on_export_chosen(id: int) -> void:
	match id:
		0:
			_on_export()
		1:
			picture_wanted.emit()
		2:
			shop_list_wanted.emit("bricklink")
		3:
			shop_list_wanted.emit("rebrickable")
		4:
			studio_wanted.emit()


func _on_export() -> void:
	if store == null:
		return
	var said: String = export_now()
	if not said.is_empty():
		_say(said)


## The model as LDraw, into [param into] (the Downloads folder when empty;
## a download on the web). What was written, or why not: File, Export, and
## a session over MCP (AppTools).
func export_now(into: String = "") -> String:
	if world.brick_count() == 0:
		return "nothing to export"
	# A model in assemblies is written as a multi-part document, and LDraw
	# names those .mpd so that whatever opens it knows to look for them.
	var grouped: bool = world.bricks().any(func(brick: BrickWorld.Brick) -> bool:
		return not brick.group.is_empty())
	var file_name: String = model_name().to_snake_case() \
		+ (".mpd" if grouped else ".ldr")
	if OS.has_feature("web"):
		store.export_to(file_name, model_name())
		return "downloaded %s" % file_name
	# Only the name's last part: a model's title is named by whoever
	# designed it, and "../" in one would put the file somewhere else.
	var folder: String = into if not into.is_empty() \
		else OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var path: String = folder.path_join(file_name.replace("\\", "/").get_file())
	if store.export_to(path, model_name()):
		return "wrote %s" % path
	return "could not write %s" % path


## New, asking first only when there is something it would lose.
func ask_for_new() -> void:
	if store != null and store.has_unsaved_work():
		_confirm_new.dialog_text = ("“%s” is not saved as it is now. "
			% model_name() + "A new model replaces it on the baseplate.")
		_confirm_new.popup_centered()
		return
	_start_new()


func _start_new() -> void:
	var job: Working.Job = await _say_first("Clearing %s parts…")
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	if store != null:
		store.begin(ModelStore.UNTITLED)
	started_new.emit()
	if job != null:
		job.end()
	_say("new model")


## For taking a big model off the baseplate, one long frame: the status bar
## says so first (Working) and has been drawn before it starts.
func _say_first(words: String) -> Working.Job:
	if world.brick_count() < EditVerbs.BIG_CHANGE:
		return null
	var job: Working.Job = Working.begin(words % Working.comma(world.brick_count()))
	await job.shown()
	return job


func _ask_to_clear() -> void:
	_confirm.popup_centered()


func _on_clear() -> void:
	var job: Working.Job = await _say_first("Clearing %s parts…")
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	# Whatever is built next is not the model that was shared, and
	# publishing it must not replace that one at its link.
	if store != null:
		store.share_id = ""
	cleared.emit()
	if job != null:
		job.end()
	_say("cleared")
