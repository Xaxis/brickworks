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

## The app's own menu, first in the row: the mark and the app's name, as
## the site's header has them, the way a CAD program's top left has its
## logo. Shell fills it (Shell.APP_MENU). Where the row has no room for the
## name on one line, the mark alone ([method _fit_mark]).
var mark: MenuButton
## Where the menus go, between the app's menu and the model's name.
var menus: HBoxContainer

const NAME := "Brickworks"
## The mark (web/icon.svg; this copy is tools/web/make_icons.mjs's), drawn
## this many units tall.
const MARK := "res://assets/ui/mark.svg"
const MARK_TALL := 18.0
## The model's name box: its width, and the least it gives way to in a
## narrow window (_fit_mark).
const NAME_WIDE := 200.0
const NAME_NARROW := 120.0

var _name: LineEdit
## Written by say(); the status bar shows it (use_status).
var _status: Label = Label.new()
## How many times say() has been called: its timer clears only the last.
var _said: int = 0
var _saves: PopupMenu
var _confirm: ConfirmationDialog
var _confirm_new: ConfirmationDialog
var _confirm_open: ConfirmationDialog
var _dont_save_button: Button
## What the person answered _confirm_open: "save", "discard" or "cancel".
signal _replace_answered(answer: String)
var _account: Button
var _claude_tab: HBoxContainer
var _claude_dot: ColorRect
var _claude_words: Button
var _entries: Array[ModelStore.Entry] = []
var _picker: ModelFilePicker

## An id no index can be, for the menu row that is not a saved model.
# A menu id no saved model's index reaches. Not negative: a PopupMenu
# reports a negative id as the item's index, so "From a file…", first in
# the menu, opened whichever model was first after it.
const IMPORT := 1 << 30
## And the row for the library (LibraryDialog), beside it.
const LIBRARY := IMPORT + 1
## And the one to rename or delete the saved models, above them
## (SavedModelsDialog, which Main owns).
const MANAGE := IMPORT + 2

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
## Someone wants to make a minifigure.
signal minifig_wanted()
signal controls_wanted()
## Someone wants to see who is signed in, or sign out.
signal account_wanted()
## Someone wants the library: LDraw's models of real sets and the
## community's (LibraryDialog, which Shell owns).
signal library_wanted()
## Someone wants to rename or delete saved models (SavedModelsDialog).
signal saved_models_wanted()
signal opened(bricks: int)
## Whatever the bar says (say), for a phone's line over the model.
signal said(text: String)


## How a dialog's button runs its command, said on the status bar first when
## it is slow: Shell.attend. As it is, without a shell.
var attend: Callable = func(_name: String, work: Callable) -> void: await work.call()


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

	mark = MenuButton.new()
	mark.name = "app_menu"
	mark.text = NAME
	mark.flat = true
	# Pointed at with another menu open, it opens in that one's place, as
	# File does from Edit.
	mark.switch_on_hover = true
	mark.set_disable_shortcuts(true)
	# Tab and the arrows reach it (F6 goes in here first); a click leaves
	# the keys with the model.
	FocusGuard.by_keyboard(mark)
	mark.add_theme_font_size_override("font_size", 14)
	mark.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	mark.add_theme_color_override("font_focus_color", Color(1, 1, 1, 0.75))
	mark.add_theme_color_override("font_hover_color", Color.WHITE)
	mark.add_theme_color_override("font_pressed_color", Color.WHITE)
	mark.add_theme_constant_override("h_separation", 7)
	mark.custom_minimum_size = Vector2(0, 28)
	mark.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var face := StyleBoxEmpty.new()
	face.content_margin_left = 2
	face.content_margin_right = 4
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		mark.add_theme_stylebox_override(state, face)
	mark.add_theme_stylebox_override("focus", FocusGuard.ring())
	mark.accessibility_name = NAME
	row.add_child(mark)
	row.sort_children.connect(_fit_mark, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_draw_mark)
	_draw_mark.call_deferred()

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
	_name.custom_minimum_size = Vector2(NAME_WIDE, 0)
	_name.tooltip_text = "What this model is called"
	_name.accessibility_name = "Model name"
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

	# This tab as Claude knows it, and whether a Claude chat is working in it
	# (ClaudeTabView.badge): quiet, always there while Claude can reach it.
	# A press opens Account, where the chats are and a new chat for this tab.
	_claude_tab = HBoxContainer.new()
	_claude_tab.add_theme_constant_override("separation", 6)
	_claude_tab.visible = false
	row.add_child(_claude_tab)
	_claude_dot = ColorRect.new()
	_claude_dot.custom_minimum_size = Vector2(7, 7)
	_claude_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_claude_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_claude_tab.add_child(_claude_dot)
	_claude_words = Button.new()
	_claude_words.flat = true
	_claude_words.focus_mode = Control.FOCUS_NONE
	_claude_words.add_theme_font_size_override("font_size", 12)
	_claude_words.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	_claude_words.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_claude_words.pressed.connect(func() -> void: account_wanted.emit())
	_claude_tab.add_child(_claude_words)

	# Who is signed in, and the way out. Everyone using Brickworks is.
	_account = _button(row, "Account", func() -> void: account_wanted.emit(),
		"Who is signed in, and Sign out")

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Clear the baseplate?"
	_confirm.dialog_text = ("Every brick on it goes, and it cannot be undone. "
		+ "Save first if you might want it back.")
	_confirm.ok_button_text = "Clear it"
	_confirm.confirmed.connect(func() -> void: attend.call("clear", _on_clear))
	add_child(_confirm)

	_confirm_new = ConfirmationDialog.new()
	_confirm_new.title = "Start a new model?"
	_confirm_new.ok_button_text = "Start new without saving"
	_confirm_new.confirmed.connect(func() -> void: attend.call("new", _start_new))
	_save_then_new_button = _confirm_new.add_button("Save, then start new", true, "save")
	_confirm_new.custom_action.connect(func(action: StringName) -> void:
		if action == &"save":
			_confirm_new.hide()
			attend.call("save_new", _save_then_new))
	add_child(_confirm_new)

	# Every open over a model with changes not saved asks this first
	# (ask_to_replace), as New does, and as Studio, LeoCAD and LDCad ask.
	_confirm_open = ConfirmationDialog.new()
	_confirm_open.ok_button_text = "Save"
	_confirm_open.confirmed.connect(func() -> void: _replace_answered.emit("save"))
	_confirm_open.canceled.connect(func() -> void: _replace_answered.emit("cancel"))
	_dont_save_button = _confirm_open.add_button("Don't save", false, "discard")
	_confirm_open.custom_action.connect(func(action: StringName) -> void:
		if action == &"discard":
			_confirm_open.hide()
			_replace_answered.emit("discard"))
	add_child(_confirm_open)

	# Save on a model nobody has named asks what to call it, as Save as asks
	# (Shell): "Save, then start new" saved a walk's model as "Untitled",
	# asking nothing (walk180, 2026-10-23).
	_ask_name = ConfirmationDialog.new()
	_ask_name.title = "Save"
	_ask_name.ok_button_text = "Save"
	# Kept up while the name will not do, saying why.
	_ask_name.dialog_hide_on_ok = false
	var asking := VBoxContainer.new()
	_ask_name_words = Label.new()
	asking.add_child(_ask_name_words)
	_ask_name_field = LineEdit.new()
	_ask_name_field.accessibility_name = "Name"
	_ask_name_field.custom_minimum_size = Vector2(320, 0)
	_ask_name_field.text_submitted.connect(func(_text: String) -> void: _take_name())
	asking.add_child(_ask_name_field)
	_ask_name.add_child(asking)
	_ask_name.confirmed.connect(_take_name)
	# Cancel, Escape, the close button, or put away by anything else.
	_ask_name.canceled.connect(_answer_name.bind(""))
	_ask_name.visibility_changed.connect(func() -> void:
		if not _ask_name.visible:
			_answer_name(""))
	add_child(_ask_name)

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
		# Its edge 3:1 on the bar (Look.OUTLINE): at 10% white it was 1.5:1.
		face.border_color = Look.OUTLINE
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
	# The name it was saved under, in the field too: a link's copy is saved
	# under a name of its own, and Save then wrote the field's, the shared
	# model's name, over the person's own model of that name.
	store.saved.connect(func(name: String) -> void:
		_name.text = name
		model_named.emit(name)
		_say_when_stored(name))
	store.loaded.connect(func(name: String, bricks: int) -> void:
		on_disk = ""
		_name.text = name
		model_named.emit(name)
		# The parts a builder counts, as the counts line and the parts list
		# do: the Cat D11 said 6,793 here, its motors' cable segments each one.
		var parts: int = bricks if store.world == null else Inventory.pieces_in(
			store.world, store.library, store.scenery)
		_say("opened %s — %d bricks" % [name, parts]))
	store.begun.connect(func(name: String) -> void:
		on_disk = ""
		_name.text = name
		model_named.emit(name))


## The bar's own controls, for the page to find (Main._tell_page).
## This tab's line about Claude: [param said] from ClaudeTabView.badge,
## [text, colour, tooltip]; hidden for "".
func show_claude_tab(said: Array) -> void:
	if _claude_tab == null:
		return
	var text: String = str(said[0])
	_claude_tab.visible = not text.is_empty()
	if _claude_words.text != text:
		_claude_words.text = text
	_claude_dot.color = said[1]
	_claude_words.tooltip_text = str(said[2])


## What it says now, for probes.
func claude_tab_words() -> String:
	return _claude_words.text if _claude_tab != null and _claude_tab.visible else ""


## The mark at the screen's own density, sharp at 1x and at 2x alike, as
## the toolbar draws its icons (Toolbar._draw_icons).
func _draw_mark() -> void:
	var density: float = Icons.density(mark)
	if is_equal_approx(density, _mark_drawn_at):
		return
	_mark_drawn_at = density
	var texture: ImageTexture = Icons.texture_for(MARK, MARK_TALL, density)
	mark.icon = texture
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if texture != null:
		mark.add_theme_constant_override("icon_max_width", roundi(texture.get_width() / density))


var _mark_drawn_at: float = 0.0


## The app's name beside the mark while the row holds everything on one
## line with it, and the mark alone where it would not: the row wraps
## rather than run off the side, and a second line would push the toolbar
## and the model down. At 720 units across (a narrow browser) the row has
## about 40 to spare without the menu (2026-10-29), so a Claude tab
## showing, or Account's count, takes the name first. Then the model's
## name box gives way, down to NAME_NARROW: the Make menu (keys3) took 50
## of those 40, and a Claude tab put Account on a second line.
func _fit_mark() -> void:
	var row: HFlowContainer = mark.get_parent()
	var gap: int = row.get_theme_constant("h_separation")
	var wide: float = 0.0
	var mine: bool = _name.get_parent() == row
	for child: Node in row.get_children():
		var control: Control = child as Control
		if control != null and control != mark and control.visible and not (mine and control == _name):
			wide += control.get_combined_minimum_size().x + gap
	var word: float = mark.get_theme_font("font").get_string_size(NAME, HORIZONTAL_ALIGNMENT_LEFT,
		-1, mark.get_theme_font_size("font_size")).x + mark.get_theme_constant("h_separation")
	var bare: float = mark.get_combined_minimum_size().x - (0.0 if mark.text.is_empty() else word)
	if mine:
		wide += gap
		var box: float = clampf(floorf(row.size.x - wide - bare), NAME_NARROW, NAME_WIDE)
		if row.size.x <= 0.0:
			box = NAME_WIDE
		if not is_equal_approx(_name.custom_minimum_size.x, box):
			_name.custom_minimum_size.x = box
		wide += box
	var named: String = NAME if wide + bare + word <= row.size.x else ""
	if mark.text != named:
		mark.text = named


func controls_by_name() -> Dictionary:
	var out: Dictionary = {"model_name": _name, "account": _account, "app_menu": mark}
	if _claude_tab != null and _claude_tab.is_visible_in_tree():
		out["claude_tab"] = _claude_words
	# New's question, for tools/web/progress_check.mjs.
	if _confirm_new.visible:
		out["new_save"] = _save_then_new_button
		out["new_discard"] = _confirm_new.get_ok_button()
	# And the name Save asks for.
	if _ask_name.visible:
		out["save_name"] = _ask_name_field
		out["save_name_ok"] = _ask_name.get_ok_button()
		out["save_name_cancel"] = _ask_name.get_cancel_button()
	# And an open's.
	if _confirm_open.visible:
		out["replace_save"] = _confirm_open.get_ok_button()
		out["replace_discard"] = _dont_save_button
		out["replace_cancel"] = _confirm_open.get_cancel_button()
	return out


var _save_then_new_button: Button
## What Save asks of a model nobody has named (ask_name).
var _ask_name: ConfirmationDialog
var _ask_name_words: Label
var _ask_name_field: LineEdit
signal _name_answered(name: String)
var _asking_name: bool = false
const NAME_ASK := "What should this model be called?"


## Who the Account button says is signed in, in its tooltip: the bar has
## no room for an address, and a button the width of one pushed Clear off
## a phone.
func show_account(email: String) -> void:
	_email = email
	_say_account()


## What came into the feed since it was last opened (AccountPanel.ask_feed):
## a small count on Account, "Account · 3".
func show_feed_count(count: int) -> void:
	_feed = maxi(count, 0)
	_say_account()


var _email := ""
var _feed := 0


func _say_account() -> void:
	if _account == null:
		return
	_account.text = "Account" if _feed == 0 else "Account · %s" % ("99+" if _feed > 98 else str(_feed))
	var who: String = ("Signed in as %s. Sign out from here." % _email
		if not _email.is_empty() else "Who is signed in, and Sign out")
	_account.tooltip_text = who if _feed == 0 else "%s new in your feed. %s" % [
		"99+" if _feed > 98 else str(_feed), who]


## What Account says now, for the browser flows.
func account_words() -> String:
	return _account.text if _account != null else ""


func model_name() -> String:
	var text: String = _name.text.strip_edges()
	return text if not text.is_empty() else "Untitled"


## What the status line says now, for a probe.
func status_text() -> String:
	return _status.text


## Say something in the bar's status line. Public because the parts list
## and the booklet live outside the bar but have nowhere else to report.
func say(text: String) -> void:
	_say(text)


func _say(text: String) -> void:
	_status.text = text
	said.emit(text)
	_said += 1
	var said: int = _said
	# Clear it after a moment; a status line that never resets stops
	# meaning "just now". Only if nothing has been said since: the same
	# words said again were cleared by the first saying's timer, Check
	# stability pressed twice gone a moment after the second press. A line
	# naming a file just written stays long enough to press its Show in
	# folder (StatusBar).
	var timer: SceneTreeTimer = get_tree().create_timer(20.0 if SaveTo.names(text) else 4.0)
	timer.timeout.connect(func() -> void:
		if _said == said and _status.text == text:
			_status.text = "")


## Save under the model's name. True when it was saved.
##
## A big model's build order is worked out a slice at a time, the status
## bar counting it with Cancel (ModelStore.save_as_paced): worked out in
## one go it held a browser for seconds on Orthanc, which is what "Save,
## then start new" froze on (2026-10-13).
func _on_save() -> bool:
	if store == null:
		return false
	if world.brick_count() == 0:
		_say("nothing to save")
		return false
	var name: String = model_name()
	# A model nobody has named is asked what to call it first.
	if name == ModelStore.UNTITLED and on_disk.is_empty():
		name = await ask_name()
		if name.is_empty():
			_say("not saved")
			return false
		_name.text = name
		_name.text_changed.emit(name)
	var saved: bool = false
	if not store.says_writing():
		saved = store.save_as(name)
	elif _saving != null:
		return false
	else:
		_saving = Working.begin("Saving “%s”…" % name, 0, true)
		await _saving.shown()
		saved = await store.save_as_paced(name, _saving)
		var stopped: bool = _saving.cancelled
		_saving.end()
		_saving = null
		if stopped:
			_say("stopped saving “%s”; nothing was written" % name)
			return false
	if not saved:
		_say(store.refused if not store.refused.is_empty() else "could not save that name")
	elif not on_disk.is_empty() and on_disk.get_file().get_basename().strip_edges() == name:
		if await store.export_paced(on_disk, name):
			SaveTo.wrote(on_disk)
			_say("saved “%s” — wrote %s" % [name, on_disk])
		else:
			_say("saved “%s” here, but could not write %s" % [name, on_disk])
			return false
	return saved


## The name a model nobody has named is saved under, asked as Save as asks
## (Shell); "" when the person cancels. Never one a saved model has: Save
## would write over that model with this one.
func ask_name() -> String:
	if _asking_name:
		return ""
	_asking_name = true
	_ask_name_words.text = NAME_ASK
	_ask_name_field.text = ""
	_ask(_ask_name)
	_ask_name_field.grab_focus()
	# The person is the one working now (Working.attend): no "Saving…" bar
	# under the question, and the time they take is not the save's.
	Working.asking += 1
	Working.asked += 1
	var called: String = await _name_answered
	Working.asking -= 1
	return called


func _take_name() -> void:
	var called: String = _ask_name_field.text.strip_edges()
	if called.is_empty() or called == ModelStore.UNTITLED or ModelStore._safe_name(called).is_empty():
		_ask_name_words.text = "Give it a name, in letters or numbers, to save it under."
		return
	if FileAccess.file_exists(ModelStore.saved_path(called)):
		_ask_name_words.text = "“%s” is a saved model already. Choose another name." % called
		return
	_answer_name(called)
	_ask_name.hide()


func _answer_name(called: String) -> void:
	if not _asking_name:
		return
	_asking_name = false
	_name_answered.emit(called)


## The save going, while it works out the build order.
var _saving: Working.Job = null
## The file on the computer that Save as wrote on the desktop, which each
## Save writes again while the model keeps the file's name: "" for none.
## Opening or beginning another model lets it go.
var on_disk: String = ""


## File › Save as on the desktop: the model named after the file the person
## chose in the platform's Save dialog (SaveTo), saved here under that name
## as Save does (Open, Versions), and written to the file. True when both
## were.
func save_to_file(path: String) -> bool:
	var called: String = path.get_file().get_basename()
	on_disk = path
	_name.text = called
	_name.text_changed.emit(called)
	return await _on_save()


## "Save, then start new": the new model only once the save has been made.
func _save_then_new() -> void:
	if await _on_save():
		await _start_new()


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
	_saves.add_item("From the library: real sets and the community's models…", LIBRARY)
	# With the other commands, above the saves. Under them, forty saves put
	# it below the window's foot, out of sight until the menu was scrolled,
	# and no tap on a phone found it (fling272b, 2026-10-26).
	if not _entries.is_empty():
		_saves.add_item("Rename or delete saved models…", MANAGE)
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
	if id == LIBRARY:
		library_wanted.emit()
		return
	if id == MANAGE:
		saved_models_wanted.emit()
		return
	if id < 0 or id >= _entries.size():
		return
	var entry: ModelStore.Entry = _entries[id]
	if not await ask_to_replace("“%s”" % entry.name):
		return
	var placed: int = await open_with_progress(entry.path)
	if placed >= 0:
		opened.emit(placed)


## Open a saved model or an example, the status bar saying so first
## (Working) and drawn before the open. How many parts landed, 0 for a model
## of none; -1 when it did not open, said in the status bar, the model on
## the baseplate as it was.
##
## A big model is laid a slice at a time, counted on the bar, with nothing
## of it drawn until it is all down (ModelStore._open_into): drawn as it went
## down, in a browser drawing in software, Orthanc took 16 s, and 8.8 s with
## slices of a tenth of a second, against 3.7 s in one frame (2026-10-13).
func open_with_progress(path: String) -> int:
	var job: Working.Job = Working.begin("Opening %s…" % path.get_file())
	await job.shown()
	var placed: int = await store.open_fetched(path, job)
	job.end()
	if not store.not_opened.is_empty():
		_say("could not open %s: %s" % [path.get_file(), store.not_opened])
		return -1
	return placed


## A model's text opened and called [param name], said first as
## [method open_with_progress] says it: open_text_fetched's answer, with
## "placed" 0 when it could not be read. Called that whatever the file calls
## itself: a set's file from the library calls its model "main"
## (ModelLibrary).
##
## Read on a worker first, and its flexible parts built on workers, the bar
## saying so: the library's biggest file, 8466-1 at 36 MB, took 2.1 s of a
## desktop's frame to read and 2.6 s more to build its 29 hoses, and a
## browser drawing in software is several times slower. Then laid out a
## slice at a time (ModelStore._open_into), the bar counting it.
func open_text_with_progress(text: String, name: String) -> Dictionary:
	var job: Working.Job = Working.begin("Reading %s (%s)…" % [name, ModelLibrary.size_words(text.length())])
	await job.shown()
	var parsed: LdrModel = await read_off_frame(text, name)
	if parsed != null:
		store.ask_geometry(parsed)
	if parsed != null and not parsed.generated.is_empty():
		job.say("Building the flexible parts of %s…" % name)
		await CustomParts.warm_skins(store.library, parsed)
	job.end()
	job = Working.begin("Opening %s…" % name)
	await job.shown()
	var result: Dictionary = await store.open_text_fetched(text, name, parsed, job)
	job.end()
	if not str(result["error"]).is_empty():
		result["placed"] = 0
		return result
	if store.title != name:
		store.title = name
		_name.text = name
		model_named.emit(name)
		store.touch()
	return result


## [param text] read as LDraw on a worker, the frames going on meanwhile:
## LdrModel.parse touches nothing but what it makes.
static func read_off_frame(text: String, name: String) -> LdrModel:
	var out: Array = [null]
	var task: int = WorkerThreadPool.add_task(func() -> void: out[0] = LdrModel.parse(text, name),
		false, "read a model")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	return out[0]


## What an open left out or is still waiting for, as File, Open from a file
## says it: " — 3 not in the library, left out (3001pr1, …)"; "" for nothing.
## Parts still on their way are put down as each arrives: [param again]
## says so as the file picker always has, asking for the file again; the
## library's open says nothing of them.
static func left_out_words(result: Dictionary, again: bool = true) -> String:
	var note: String = ""
	if int(result.get("missing", 0)) > 0:
		# Named, as an LDD model's are: a Studio model can use a part
		# Studio made, which nothing else has.
		# Kept in the file when it is someone else's (SourceFile): a save
		# writes them back. A flexible part is named once, by the sub-model
		# it is, not by the pieces it is drawn with.
		var missing: Dictionary = result.get("unshown", result.get("missing_ids", {}))
		var count: int = 0
		for id: String in missing:
			count += int(missing[id])
		note += (" — %d not shown, kept in the file (%s)" if bool(result.get("kept"))
			else " — %d not in the library, left out (%s)") % [count,
			ModelStore.named_counts(missing)]
	if again and int(result.get("waiting", 0)) > 0:
		note += " — %d are still arriving, open it again in a moment" % int(result["waiting"])
	return note


## Who made a model and on what terms, in a line: "LDraw model by Roland
## Dahl, CCAL 2.0" (ModelStore.credit); "" for the person's own.
static func credit_words(credit: Dictionary) -> String:
	if credit.is_empty():
		return ""
	var from: String = str(credit.get("from", ""))
	var by: String = str(credit.get("by", ""))
	var said: String = ("LDraw model" if from == ModelLibrary.FROM else "Model") \
		+ (" by %s" % by if not by.is_empty() else "")
	if not str(credit.get("licence", "")).is_empty():
		said += ", " + str(credit["licence"])
	return said


## A save of a model kept as a version (File, Versions…; open_model over
## MCP), opened in place of what is on the baseplate as Open opens a model,
## under the name it is a save of: [param name], or the model on the
## baseplate's. How many parts landed: -1 when it could not be read, said,
## and then nothing on the baseplate has changed.
func open_version(version: ModelVersions.Version, name: String = "") -> int:
	if name.is_empty():
		name = store.title
	var job: Working.Job = Working.begin("Opening “%s” as saved %s…" % [name, version.when()])
	await job.shown()
	var placed: int = await store.open_version(version.path, name, job)
	job.end()
	if not store.not_opened.is_empty():
		_say("could not open “%s” as saved %s: %s" % [name, version.when(), store.not_opened])
		return -1
	opened.emit(placed)
	_say("opened “%s” as saved %s, %d parts — Save makes it the newest save"
		% [name, version.when(), version.parts])
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
		_picker.library = store.library
		add_child(_picker)
		_picker.picked.connect(func(text: String, file_name: String) -> void:
			# Asked once the file is chosen: the browser opens its picker
			# only in the click itself.
			if not await ask_to_replace("“%s”" % file_name.get_file()):
				return
			# The status bar says so first (Working), and has been drawn
			# before it begins; a big file is read and laid over frames,
			# counted there (see open_with_progress).
			var job: Working.Job = Working.begin("Opening %s…" % file_name.get_file())
			await job.shown()
			var result: Dictionary = await store.open_text_fetched(
				text, file_name.get_basename(), null, job)
			job.end()
			if not str(result["error"]).is_empty():
				_say(str(result["error"]))
				return
			opened.emit(int(result["placed"]))
			var note: String = "opened %d parts" % int(result["placed"]) + left_out_words(result)
			if not _picker.notes.is_empty():
				note += " — " + _picker.notes
			_say(note))
		_picker.failed.connect(func(why: String) -> void: _say(why))
	_picker.ask()


func _on_export() -> void:
	if store == null:
		return
	var said: String = await export_now("", true)
	if not said.is_empty():
		_say(said)


## The model as LDraw, into [param into] (the Downloads folder when empty;
## a download on the web), or on the desktop where the person chooses when
## [param asking] (SaveTo). What was written, or why not: File, Export, and
## a session over MCP (AppTools).
func export_now(into: String = "", asking: bool = false) -> String:
	if world.brick_count() == 0:
		return "nothing to export"
	var file_name: String = model_name().to_snake_case() + ldraw_extension()
	if OS.has_feature("web"):
		if await store.export_paced(file_name, model_name()):
			return "downloaded %s" % file_name
		return ""
	# Only the name's last part: a model's title is named by whoever
	# designed it, and "../" in one would put the file somewhere else.
	var path: String = await SaveTo.ask(file_name, into) if asking \
		else (into if not into.is_empty() else Download.downloads()).path_join(
			file_name.replace("\\", "/").get_file())
	if path.is_empty():
		return ""
	if await store.export_paced(path, model_name()):
		SaveTo.wrote(path)
		return "wrote %s" % path
	return "could not write %s" % path


## ".mpd" for a model in assemblies, which is written as a multi-part
## document, and LDraw names those .mpd so that whatever opens it knows to
## look for them; ".ldr" for the rest.
func ldraw_extension() -> String:
	var grouped: bool = world.bricks().any(func(brick: BrickWorld.Brick) -> bool:
		return not brick.group.is_empty())
	return ".mpd" if grouped else ".ldr"


## Whether to go on with an open that puts [param opening] (its name in
## words: "“Car”") in place of the model on the baseplate: at once when
## nothing of it would be lost; otherwise the person is asked to save it
## first (Save, Don't save, Cancel), and true unless they cancel or the
## save is not made. Whichever, the open keeps what it takes off, and Undo
## brings it back (ModelStore.opened_over). Every way a person opens a
## model over this one asks this: File › Open, the examples, Open recent, a
## file from the computer, Collection › Open and Versions.
func ask_to_replace(opening: String) -> bool:
	# One question at once: a second open while it is asked waits for none.
	if _confirm_open.visible:
		return false
	# Half a model being laid is nothing of anybody's.
	if store == null or store.laying or not store.has_unsaved_work():
		return true
	var name: String = model_name()
	_confirm_open.title = "Save changes to “%s”?" % name
	_confirm_open.dialog_text = ("“%s” is not saved as it is now. Opening %s replaces it on the "
		+ "baseplate; Undo brings it back.") % [name, opening]
	_ask(_confirm_open)
	var answer: String = await _replace_answered
	match answer:
		"save":
			return await _on_save()
		"discard":
			return true
	_say("kept “%s” — nothing opened" % name)
	return false


## Edit › Undo with nothing left to undo but an open: what the open took off
## the baseplate put back as it stood (ModelStore.reopen); Redo's with
## [param again]. True when it was, said either way.
func reopen(again: bool = false) -> bool:
	if store == null or not store.can_reopen(again):
		return false
	var words: String = store.reopen_words(again)
	var job: Working.Job = Working.begin("Taking back: %s…" % words if not again else "Again: %s…" % words)
	await job.shown()
	var placed: int = await store.reopen(again, job)
	job.end()
	if placed < 0:
		_say("could not %s %s: %s" % ["redo" if again else "take back", words, store.not_opened])
		return false
	opened.emit(placed)
	_say("%s: %s" % ["redid" if again else "undid", words])
	return true


## New, asking first only when there is something it would lose.
func ask_for_new() -> void:
	if store != null and store.has_unsaved_work():
		_confirm_new.dialog_text = ("“%s” is not saved as it is now. "
			% model_name() + "A new model replaces it on the baseplate.")
		_ask(_confirm_new)
		return
	await _start_new()


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


## Put a question up, answered only once it has been seen: for its first
## frames Escape does not close it. An Escape pressed a moment before New, on
## a browser's idle tab, reached the window only after New's click (the page
## hands keys over a frame later than the mouse), so it closed New's question
## in the frame it opened: New asked nothing and did nothing
## (cloud_library_flow on m164, 2026-10-24).
func _ask(dialog: AcceptDialog) -> void:
	dialog.dialog_close_on_escape = false
	dialog.popup_centered()
	for _n: int in ESCAPE_AFTER_FRAMES:
		await get_tree().process_frame
	dialog.dialog_close_on_escape = true


## How many frames a question is up before Escape closes it.
const ESCAPE_AFTER_FRAMES := 2


func _ask_to_clear() -> void:
	_ask(_confirm)


func _on_clear() -> void:
	var job: Working.Job = await _say_first("Clearing %s parts…")
	world.clear()
	builder.lattice.clear()
	builder.forget_history()
	# Whatever is built next is not the model that was shared, and
	# publishing it must not replace that one at its link.
	if store != null:
		store.share_id = ""
		store.remixed_from = ""
		store.remixed_from_version = 0
		# The person emptied it: the autosave may keep it empty.
		store.cleared_by_person()
	cleared.emit()
	if job != null:
		job.end()
	_say("cleared")
