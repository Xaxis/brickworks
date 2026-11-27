## The strip across the top: the menus, what this model is called, and who
## is signed in. It is the app's header (AppHeader), the site's: the mark and
## the name at the left, the app's menu and Account at the right, 60 points
## tall over a line, in every mode. A shared model's viewer and Build it's
## step player keep it, plain (looking): the mark, Menu and Account, their
## own bars under it.
##
## It was a row of a dozen buttons — New, Save, Open, Export, Parts list,
## Timeline, Mosaic, Minifig, Help, Account, Clear — with a status line
## squeezed between them. Those are menu items now (Shell), each with its
## key beside it, and the status line is the status bar along the foot.
## What is left here is what a CAD program's title row holds: the menus and
## the document's name. The work behind each item is still done here.
class_name ModelBar
extends PanelContainer

## The header every mode has, the site's (src/ui/app_header.gd).
const AppHeader := preload("res://src/ui/app_header.gd")

var store: ModelStore
var world: BrickWorld
var builder: Builder

## The app's own menu (Shell fills it, Shell.APP_MENU). On the desktop it is
## first in the row, the mark and the app's name, the way a CAD program's top
## left has its logo. In a browser the mark and the name are the way home, as
## the site's header has them ([member home]), and this is Menu at the right,
## beside Account, where the site's phone header has its Menu (AppHeader).
var mark: MenuButton
## In a browser, the mark and the app's name at the left, the site's home page
## in this tab (AppHeader.go_home); null on the desktop, where [member mark]
## is there. Where the row has no room for the name on one line, the mark
## alone ([method _fit_mark]).
var home: Button
## Whichever is at the left with the mark on it: [member home] or [member mark].
var brand: Button
## The header plain, for a shared model's viewer, Build it's step player and
## the booklet's page laid out by hand (looking): the menus, the model's name
## and the Claude tab out of sight, the mark, Menu and Account kept.
var plain: bool = false
## Simple | Full (AppHeader.controls_switch): on the studio's header, and
## on the plain one Simple keeps (set_simple); not on the viewer's, Build
## it's or the page laid out by hand.
var controls: PanelContainer
## Simple's header: plain, the switch kept (Main.use_controls).
var simple: bool = false
## Simple | Full put away for a row too narrow for it, Simple a row of "…"
## instead (Shell._fold_into): where the switch would fold a menu or make
## the header smaller ([method _fit_header]). French File went into "…" for
## it at a narrow window (simplereview2 D).
var switch_folded: bool = false
## Simple or Full picked on the switch.
signal controls_picked(layer: StringName)
## Looking at somebody else's model: Account is the site's settings page,
## since the viewer reads nobody's account (Main._enter_view).
var visiting: bool = false
## Where the menus go, between the app's menu and the model's name.
var menus: HBoxContainer
## "…", after the menus, holding those the row has no room for
## ([method _fit_header]); hidden while every menu shows.
var more: MenuButton
## How many of the menus show on the row, the rest folded into [member
## more]: every one until the row runs short.
var menus_shown: int = 1 << 20
## The menus shown on the row changed: Shell's "…" says which it holds.
signal menus_folded

const NAME := "Brickworks"
## The mark (web/icon.svg; this copy is tools/web/make_icons.mjs's), drawn
## AppHeader.MARK points tall.
const MARK := "res://assets/ui/mark.svg"
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
## An open found parts its file names by a number LDraw has moved or made an
## alias, or has no file for (ModelStore.moved): Shell offers the renumbered
## ones in a person's [param own] file once, the file named by [param of]
## (MovedOffer), and asks about a part with no file (MovedPartsDialog).
signal moved_found(own: bool, of: String)
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
	# The site's ground, 60 points and a line (_fit_header).
	# Wraps onto a second line rather than running off the side, on a
	# phone: the bar sets the width of everything under it, and a row wider
	# than the page once took the assistant's rail off it.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 2)
	# Centred in the header's height (_fit_header), whatever its tallest
	# control is.
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(row)

	mark = MenuButton.new()
	mark.name = "app_menu"
	mark.flat = true
	# Pointed at with another menu open, it opens in that one's place, as
	# File does from Edit.
	mark.switch_on_hover = true
	mark.set_disable_shortcuts(true)
	# Tab and the arrows reach it (F6 goes in here first); a click leaves
	# the keys with the model.
	FocusGuard.by_keyboard(mark)
	mark.accessibility_name = NAME
	if AppHeader.web_layout:
		home = Button.new()
		home.name = "app_home"
		home.text = NAME
		# Tab reaches it, as the site's mark is a link Tab reaches; a click
		# leaves the keys with the model.
		FocusGuard.by_keyboard(home)
		home.accessibility_name = NAME
		home.tooltip_text = "Brickworks: the home page"
		home.accessibility_description = "The site's home page, in this tab"
		home.pressed.connect(AppHeader.go_home)
		brand = home
		mark.text = "Menu"
	else:
		mark.text = NAME
		brand = mark
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(brand)
	row.sort_children.connect(_fit_mark, CONNECT_DEFERRED)
	get_viewport().size_changed.connect(_fit_header)
	_fit_header.call_deferred()

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(8, 0)
	row.add_child(gap)

	menus = HBoxContainer.new()
	menus.add_theme_constant_override("separation", 0)
	menus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(menus)

	# The menus the row has no room for, each folded into this in turn, the
	# last first (_fit_header). Shell fills it and dresses it as a menu.
	more = MenuButton.new()
	more.name = "more_menus"
	more.text = "…"
	more.accessibility_name = "More menus"
	more.tooltip_text = "More menus"
	more.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	more.visible = false
	row.add_child(more)

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
	_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	_claude_tab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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

	# Simple | Full, the controls over the model (Main.use_controls), before
	# Menu and Account as a site's mode switch sits before its account.
	controls = AppHeader.controls_switch(1.0, false, func(layer: StringName) -> void:
		controls_picked.emit(layer))
	row.add_child(controls)
	# In a browser the app's menu, Menu, before Account: the site's phone
	# header has its Menu there, and your account last at the far right.
	if home != null:
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(mark)
	# Who is signed in, and the way out. Everyone using Brickworks is.
	_account = _button(row, "Account", _account_pressed, "Who is signed in, and Sign out")
	_account.name = "account"
	_account.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# What came into the feed: a count over Account's corner, as the site
	# draws it (web/site.css .site-head .count), never in its words. In
	# words ("Account · 3") Account grew as the count came, seconds in, and
	# moved Menu beside it from under the pointer (appchrome's app_menu_flow
	# clicked where Menu had been).
	_count = Label.new()
	_count.name = "account_count"
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count.visible = false
	_account.add_child(_count)
	_account.resized.connect(_place_count)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Clear the baseplate?"
	_confirm.dialog_text = ("Every brick on it goes, and it cannot be undone. "
		+ "Save first if you might want it back.")
	_confirm.ok_button_text = "Clear it"
	_confirm.confirmed.connect(func() -> void: attend.call("clear", _on_clear))
	add_child(_confirm)
	# It cannot be undone: in red, not Save's blue (Look.danger).
	Look.danger(_confirm.get_ok_button())

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
	# Asked because a saved model that is not this one has its name
	# (ask_name_taken): replacing that model is a choice of its own.
	_replace_button = _ask_name.add_button(REPLACE_WORDS, true, "replace")
	_replace_button.visible = false
	_ask_name.custom_action.connect(func(action: StringName) -> void:
		if action == &"replace" and not _replacing.is_empty():
			_replace_chosen = true
			_answer_name(_replacing)
			_ask_name.hide())
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
	var was: bool = _claude_tab.visible
	_claude_tab.visible = not text.is_empty() and not plain
	if _claude_words.text != text:
		_claude_words.text = text
	if was != _claude_tab.visible:
		_fit_header.call_deferred()
	_claude_dot.color = said[1]
	_claude_words.tooltip_text = str(said[2])


## What it says now, for probes.
func claude_tab_words() -> String:
	return _claude_words.text if _claude_tab != null and _claude_tab.visible else ""


## The header at the site's size in points (AppHeader), and the mark at
## the screen's own density, sharp at 1x and at 2x alike, as the toolbar
## draws its icons (Toolbar._draw_icons): again whenever the window's size
## or density changes.
func _fit_header() -> void:
	if not is_inside_tree():
		return
	# Dressed for a phone (Main._dress_for_phone), the phone's top bar is the
	# header, and this keeps no height of its own.
	if not brand.get_parent().visible:
		return
	var gutter: float = AppHeader.GUTTER_NARROW if Room.across() < 600.0 else AppHeader.GUTTER
	var pt: float = AppHeader.points(self)
	# Capped to keep the studio's row on one line where this bar is ever the
	# studio's: on a phone the studio has its own top bar (PhoneShell), and
	# this one heads only the viewer and Build it, at the full 61 points.
	# Below the toolbar's size the menus give way instead, the last first,
	# into "…": at 150% or in German a narrow window's row was wider than
	# the window, and the whole column with it (wingreview3 F3).
	if not Phone.on():
		var least: float = minf(pt, LEAST_PT)
		var shown: int = _shown_at(gutter, least, true)
		var fits: float = _fitting_pt(gutter, shown, true)
		# Simple | Full on the row only where it folds no menu and makes the
		# header no smaller; otherwise Simple is in "…" (switch_folded). The
		# same in every mode, so the header is one size in all of them.
		var without: int = _shown_at(gutter, least, false)
		var fits_without: float = _fitting_pt(gutter, without, false)
		switch_folded = without > shown or minf(pt, fits_without) > minf(pt, fits) + 0.001
		if switch_folded:
			shown = without
			fits = fits_without
		_show_switch()
		_fold_menus(shown)
		pt = minf(pt, maxf(fits, 0.5))
	points = pt
	var density: float = Icons.density(brand)
	add_theme_stylebox_override("panel", AppHeader.ground(pt, gutter))
	custom_minimum_size.y = (AppHeader.TALL + AppHeader.LINE) * pt
	AppHeader.dress_mark(brand, pt)
	brand.accessibility_name = NAME
	if home != null:
		AppHeader.dress_button(mark, pt)
	AppHeader.dress_button(_account, pt)
	AppHeader.dress_switch(controls, pt, false)
	_dress_count(pt)
	if is_equal_approx(density, _mark_drawn_at) and is_equal_approx(pt, _mark_drawn_pt):
		return
	_mark_drawn_at = density
	_mark_drawn_pt = pt
	brand.icon = Icons.icon_for(MARK, AppHeader.MARK * pt, density)
	brand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Fitted again, once its menus are in (Shell) or anything else on its row
## has changed width.
func refit() -> void:
	_fit_header.call_deferred()


var _mark_drawn_at: float = 0.0
var _mark_drawn_pt: float = 0.0
## The interface's units to the header's point it is drawn at now: the
## window's (AppHeader.points), or fewer where the studio's row needs them.
var points: float = 1.0


## The most points to the header that keep the studio's whole row on one
## line. The menus and the model's name (at its narrowest) are in the
## interface's units; the bare mark, Menu, Account and the gutters are in
## points. A window narrower than the menus' 720 units has more units to
## the point (1.85 in a browser 390 across), and the header in points put
## Menu and Account on a second line there. Counted for the studio's row in
## every mode, the plain ones too, so the header is one size in all of them;
## the Claude tab is counted while it shows (the studio's alone, and only
## where Claude reaches this tab). With the first [param shown] menus on the
## row, and "…" where any is folded; less than nothing where the units alone
## are wider than the window.
func _fitting_pt(gutter: float, shown: int, with_switch: bool = true) -> float:
	var row: HFlowContainer = brand.get_parent()
	var gap: float = float(row.get_theme_constant("h_separation"))
	var font: Font = _account.get_theme_font("font")
	# In points: the gutters and the bare mark; Menu and Account as
	# dress_button sizes them (15-point words, 14 points either side), in the
	# words they are drawn in.
	var per_pt: float = 2.0 * gutter + AppHeader.TARGET
	# In units: every other control the studio's row shows, each with the gap
	# before it; the menus and the model's name (at its narrowest) counted in
	# every mode, so the header is one size in all of them. Counting a few
	# of them by hand missed the 12-unit gap after the menus, and the row
	# still wrapped (app_menu_probe at 720 units).
	var units: float = 0.0
	for child: Node in row.get_children():
		var control: Control = child as Control
		if control == null or control == brand or control == more:
			continue
		var studio: bool = control == menus or control == _name
		# The switch counted by [param with_switch], shown or not: the row
		# with it and without it, whichever shows now.
		if control == controls:
			if not with_switch:
				continue
		elif not control.visible and not studio:
			continue
		units += gap
		if control == _account or (home != null and control == mark):
			var button: Button = control as Button
			per_pt += 28.0 + font.get_string_size(button.atr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		elif control == controls:
			per_pt += AppHeader.switch_points(controls, false)
		elif control == _name:
			units += NAME_NARROW
		elif control == menus:
			var buttons: Array[MenuButton] = _menu_buttons()
			for n: int in mini(shown, buttons.size()):
				units += _menu_width(buttons[n]) + float(menus.get_theme_constant("separation"))
			# "…" where it holds a menu, or Simple for want of the switch.
			if shown < buttons.size() or not with_switch:
				units += gap + _menu_width(more)
		else:
			units += control.get_combined_minimum_size().x
	# A few units spare: sizes are rounded to whole units and points.
	var room: float = get_viewport().get_visible_rect().size.x - units - 6.0
	return room / per_pt


## The least points to the header before the menus give way: its buttons
## no smaller than the toolbar's under it.
const LEAST_PT := Toolbar.BUTTON / AppHeader.TARGET


## How many menus the row keeps at no fewer than [param least] points,
## with the switch on it or without.
func _shown_at(gutter: float, least: float, with_switch: bool) -> int:
	var shown: int = _menu_buttons().size()
	while shown > 0 and _fitting_pt(gutter, shown, with_switch) < least:
		shown -= 1
	return shown


## Simple | Full where it is wanted and the row has room: in Simple always
## (the way back), on Full's header unless folded, never on the viewer's,
## Build it's or the page laid out by hand.
func _show_switch() -> void:
	controls.visible = simple or (not plain and not switch_folded)


## The menus on the row, in order (Shell's), "…" not among them.
func _menu_buttons() -> Array[MenuButton]:
	var out: Array[MenuButton] = []
	for each: Node in menus.get_children():
		if each is MenuButton:
			out.append(each as MenuButton)
	return out


## [param button]'s width on the row, in the words it is drawn in, whether
## or not it shows now: a folded menu's own least is not kept up to date.
func _menu_width(button: Button) -> float:
	var font: Font = button.get_theme_font("font")
	var words: float = font.get_string_size(button.atr(button.text), HORIZONTAL_ALIGNMENT_LEFT, -1,
		button.get_theme_font_size("font_size")).x
	return ceilf(words + button.get_theme_stylebox("normal").get_minimum_size().x)


## The first [param shown] menus on the row and the rest in "…", which
## shows only while it holds one.
func _fold_menus(shown: int) -> void:
	var buttons: Array[MenuButton] = _menu_buttons()
	shown = clampi(shown, 0, buttons.size())
	for n: int in buttons.size():
		buttons[n].visible = n < shown
	more.visible = (shown < buttons.size() or switch_folded) and not plain
	if shown != menus_shown:
		menus_shown = shown
		menus_folded.emit()


func _notification(what: int) -> void:
	# Other words are other widths: the row is fitted again to them, as
	# Settings, Language changes them.
	if what == NOTIFICATION_TRANSLATION_CHANGED and brand != null:
		_fit_header.call_deferred()


## The header plain or whole: plain for a mode that is not the studio's
## (the viewer, Build it, the page laid out by hand), the menus, the model's
## name and the Claude tab out of sight and the mark, Menu and Account kept,
## so the header is the same in each.
func set_plain(yes: bool) -> void:
	plain = yes
	for part: Control in [menus, _name]:
		part.visible = not yes
	_show_switch()
	more.visible = not yes and (menus_shown < _menu_buttons().size() or switch_folded)
	if _claude_tab != null:
		_claude_tab.visible = not yes and not _claude_words.text.is_empty()
	_fit_mark.call_deferred()


## Simple's header (Main.use_controls): plain, as Build it's is, the switch
## kept and Simple chosen on it; back in Full, the studio's whole.
func set_simple(yes: bool) -> void:
	simple = yes
	set_plain(yes)
	show_controls(&"simple" if yes else &"full")


## Which of Simple | Full the switch shows chosen.
func show_controls(layer: StringName) -> void:
	AppHeader.show_controls(controls, layer)


## Account pressed: who is signed in, in the app; on somebody else's model,
## which reads nobody's account, the site's own settings, in a tab of their
## own so the model stays open here.
func _account_pressed() -> void:
	if visiting:
		Outside.open_link(Deployment.api_base() + "/settings")
		return
	account_wanted.emit()


## The app's name beside the mark while the row holds everything on one
## line with it, and the mark alone where it would not: the row wraps
## rather than run off the side, and a second line would push the toolbar
## and the model down. At 720 units across (a narrow browser) the row has
## about 40 to spare without the menu (2026-10-29), so a Claude tab
## showing, or Account's count, takes the name first. Then the model's
## name box gives way, down to NAME_NARROW: the Make menu (keys3) took 50
## of those 40, and a Claude tab put Account on a second line.
func _fit_mark() -> void:
	var row: HFlowContainer = brand.get_parent()
	var gap: int = row.get_theme_constant("h_separation")
	var wide: float = 0.0
	var mine: bool = _name.get_parent() == row and _name.visible
	for child: Node in row.get_children():
		var control: Control = child as Control
		if control != null and control != brand and control.visible and not (mine and control == _name):
			wide += control.get_combined_minimum_size().x + gap
	# Account's count comes seconds in, signed in, over its corner
	# (_count), so Account is as wide with it as without: nothing in the row
	# moves when it comes (rel-m223's app_menu_flow found the mark gone when
	# it was in Account's words).
	var word: float = brand.get_theme_font("font").get_string_size(NAME, HORIZONTAL_ALIGNMENT_LEFT,
		-1, brand.get_theme_font_size("font_size")).x + brand.get_theme_constant("h_separation")
	var bare: float = brand.get_combined_minimum_size().x - (0.0 if brand.text.is_empty() else word)
	if mine:
		wide += gap
		var box: float = clampf(floorf(row.size.x - wide - bare), NAME_NARROW, NAME_WIDE)
		if row.size.x <= 0.0:
			box = NAME_WIDE
		if not is_equal_approx(_name.custom_minimum_size.x, box):
			_name.custom_minimum_size.x = box
		wide += box
	# Inside the header's gutters: the row is the panel's width less them.
	var named: String = NAME if wide + bare + word <= row.size.x else ""
	if brand.text != named:
		brand.text = named


func controls_by_name() -> Dictionary:
	var out: Dictionary = {"model_name": _name, "account": _account, "app_menu": mark, "app_header": self}
	if home != null:
		out["app_home"] = home
	if controls.is_visible_in_tree():
		for button: Node in controls.get_child(0).get_children():
			out[button.name] = button
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
		if _replace_button.visible:
			out["save_name_replace"] = _replace_button
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
## Asked when Save would go over a saved model that is not this one.
const TAKEN_ASK := "“%s” is a saved model already, and this is not it. Save this one under a name of its own, or replace that model with it."
const REPLACE_WORDS := "Replace it"
var _replace_button: Button
## The name [method ask_name_taken] offers to replace, while it asks; and
## whether the person chose to.
var _replacing: String = ""
var _replace_chosen: bool = false


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
	_count.text = "99+" if _feed > 98 else str(_feed)
	_count.visible = _feed > 0
	_account.accessibility_name = account_words()
	_place_count.call_deferred()
	var who: String = ("Signed in as %s. Sign out from here." % _email
		if not _email.is_empty() else "Who is signed in, and Sign out")
	_account.tooltip_text = who if _feed == 0 else "%s new in your feed. %s" % [
		"99+" if _feed > 98 else str(_feed), who]


## What Account says now, its count with it ("Account · 3"), for a screen
## reader and the browser flows.
func account_words() -> String:
	if _account == null:
		return ""
	return _account.text if _feed == 0 else "%s · %s" % [_account.text, _count.text]


## The count's look: the site's .count, a pill of its accent 18 points
## tall, its micro type in bold.
func _dress_count(pt: float) -> void:
	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.949, 0.804, 0.216)
	face.set_corner_radius_all(roundi(9.0 * pt))
	face.content_margin_left = 5.0 * pt
	face.content_margin_right = 5.0 * pt
	_count.add_theme_stylebox_override("normal", face)
	_count.add_theme_color_override("font_color", Color(0.090, 0.075, 0.039))
	_count.add_theme_font_override("font", AppHeader.word_font(_count))
	_count.add_theme_font_size_override("font_size", roundi(12.0 * pt))
	_count.custom_minimum_size = Vector2(18.0 * pt, 18.0 * pt)
	_count_pt = pt
	_place_count.call_deferred()


var _count: Label
var _count_pt: float = 1.0


## Over Account's top right corner, as the site's sits over its Menu's
## (top -7, right -7): inside the header's 8-point margin above it.
func _place_count() -> void:
	if _count == null or _account == null:
		return
	_count.reset_size()
	_count.position = Vector2(_account.size.x - _count.size.x + 7.0 * _count_pt, -7.0 * _count_pt)


func model_name() -> String:
	var text: String = _name.text.strip_edges()
	return text if not text.is_empty() else "Untitled"


## What the status line says now, for a probe.
func status_text() -> String:
	return _status.text


## Say something in the bar's status line. Public because the parts list
## and the booklet live outside the bar but have nowhere else to report.
func say(text: String) -> void:
	# An edit refused said this frame stands: the command that made it says
	# what it did after the app has taken it back (EditVerbs: "painted 1
	# part" after the copies could not follow).
	if Engine.get_process_frames() == _over_frame:
		return
	_say(text)


## [param text] said, and kept over anything else said this frame: why an
## edit was refused (Assemblies.edit_refused).
func say_over(text: String) -> void:
	_over_frame = Engine.get_process_frames()
	_say(text)


var _over_frame: int = -1


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


## The words being typed into a field that edits the model kept, as leaving
## the field keeps them (its focus_exited), and the keys left with it: Ctrl+S,
## Ctrl+N, an open or Ctrl+Q pressed while typing wrote, or put another model
## in place of, the model without them (hpreview F2: the words of a booklet
## page, the booklet's texts, a motion's name). A click on Save or New ends
## the typing itself (FocusGuard); a key leaves it in the field.
func end_typing() -> void:
	if not is_inside_tree():
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if not (focused is LineEdit or focused is TextEdit):
		return
	focused.release_focus()
	if is_instance_valid(focused) and focused.is_visible_in_tree():
		focused.grab_focus()


## Save under the model's name. True when it was saved.
##
## A big model's build order is worked out a slice at a time, the status
## bar counting it with Cancel (ModelStore.save_as_paced): worked out in
## one go it held a browser for seconds on Orthanc, which is what "Save,
## then start new" froze on (2026-10-13).
func _on_save(press: int = -1) -> bool:
	if store == null:
		return false
	end_typing()
	if world.brick_count() == 0:
		_say("nothing to save")
		return false
	# The model the press was made on ([param press], or now): one opened or
	# begun while the save asks or writes is never written under this one's
	# name (ModelStore.model_now, wholereview2 F1).
	var model: int = store.model_now() if press < 0 else press
	var name: String = model_name()
	# A model nobody has named is asked what to call it first.
	if name == ModelStore.UNTITLED and on_disk.is_empty():
		name = await ask_name()
		if name.is_empty():
			_say("not saved")
			return false
		if store.model_now() != model:
			_say(ModelStore.ANOTHER_OPENED)
			return false
		_name.text = name
		_name.text_changed.emit(name)
	var saved: bool = false
	var over: bool = false
	while true:
		if store.model_now() != model:
			_say(ModelStore.ANOTHER_OPENED)
			return false
		if not store.says_writing():
			saved = store.save_as(name, over)
		elif _saving != null:
			return false
		else:
			_saving = Working.begin("Saving “%s”…" % name, 0, true)
			await _saving.shown()
			saved = await store.save_as_paced(name, _saving, over, model)
			var stopped: bool = _saving.cancelled
			_saving.end()
			_saving = null
			# Stopped by another model put on the baseplate, not by Cancel.
			if store.model_now() != model:
				_say(ModelStore.ANOTHER_OPENED)
				return false
			if stopped:
				_say("stopped saving “%s”; nothing was written" % name)
				return false
		# A saved model that is not this one has the name: asked for one of its
		# own, or whether to replace that model, never written over unasked
		# (ModelStore._saved_over_another).
		if saved or store.taken.is_empty() or over:
			break
		var answer: Array = await ask_name_taken(store.taken)
		if str(answer[0]).is_empty():
			_say("not saved: “%s” is a saved model already" % store.taken)
			return false
		# The name chosen is this model's: never given to one opened while
		# the dialog was up (pubbind), whose title and changed mark it set.
		if store.model_now() != model:
			_say(ModelStore.ANOTHER_OPENED)
			return false
		over = bool(answer[1])
		name = str(answer[0])
		_name.text = name
		_name.text_changed.emit(name)
	if not saved:
		_say(store.refused if not store.refused.is_empty() else "could not save that name")
	elif not on_disk.is_empty() and on_disk.get_file().get_basename().strip_edges() == name:
		var disk: String = on_disk
		if await store.export_paced(disk, name, model):
			SaveTo.wrote(disk)
			_say("saved “%s” — wrote %s" % [name, disk])
		elif store.model_now() != model:
			_say("saved “%s” here, but did not write %s: another model was opened" % [name, disk])
			return false
		else:
			_say("saved “%s” here, but could not write %s" % [name, disk])
			return false
	return saved


## The name a model nobody has named is saved under, asked as Save as asks
## (Shell); "" when the person cancels. Never one a saved model has: Save
## would write over that model with this one.
func ask_name() -> String:
	if _asking_name:
		return ""
	_asking_name = true
	_replacing = ""
	_replace_button.visible = false
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


## Save refused because a saved model that is not this one is called
## [param name] (ModelStore.taken): asked for a name of this one's own, the
## next free one offered, or to replace that model with it. [name, replace]:
## the name to save under and whether it replaces the model of that name;
## ["", false] when the person cancels. As ask_name asks, so a name a saved
## model has is refused there too: replacing one is its own button.
func ask_name_taken(name: String) -> Array:
	if _asking_name:
		return ["", false]
	_asking_name = true
	_replacing = name
	_replace_chosen = false
	_ask_name_words.text = TAKEN_ASK % name
	_ask_name_field.text = store.unused_name(name) if store != null else ""
	_replace_button.visible = true
	_ask(_ask_name)
	_ask_name_field.grab_focus()
	_ask_name_field.select_all()
	Working.asking += 1
	Working.asked += 1
	var called: String = await _name_answered
	Working.asking -= 1
	_replace_button.visible = false
	_replacing = ""
	return [called, _replace_chosen and called == name]


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
## [param model]: the model the press was made on (ModelStore.model_now),
## before the dialog; one opened since is not saved nor written.
func save_to_file(path: String, model: int = -1) -> bool:
	if model >= 0 and store != null and store.model_now() != model:
		_say(ModelStore.ANOTHER_OPENED)
		return false
	var mine: int = store.model_now() if store != null else -1
	var called: String = path.get_file().get_basename()
	on_disk = path
	_name.text = called
	_name.text_changed.emit(called)
	if not await _on_save(mine):
		return false
	if model_name() == called.strip_edges():
		return true
	# A saved model that is not this one had the file's name, and the person
	# gave this one another (ask_name_taken): the file they chose is written
	# all the same, as it is named; Save writes it again only while the model
	# keeps the file's name.
	var name: String = model_name()
	if await store.export_paced(path, name, mine):
		SaveTo.wrote(path)
		_say("saved “%s” — wrote %s" % [name, path])
		return true
	_say("saved “%s” here, but %s %s" % [name, "did not write" if store.model_now() != mine
		else "could not write", path + (": another model was opened" if store.model_now() != mine else "")])
	return false


## "Save, then start new": the new model only once the save has been made.
func _save_then_new() -> void:
	if await _on_save():
		await _start_new()


## "Saved" once it is: on the web a save is in the browser's storage only
## some seconds after it is written (ModelStore.stored), and saying so
## sooner told a person their work was safe while closing the tab lost it.
func _say_when_stored(name: String) -> void:
	var path: String = ModelStore.SAVE_DIR + ModelStore._safe_name(name) + ".ldr"
	# A joint of a motion whose part is gone, written as it was.
	var gone: String = " — " + store.motions_gone_words if not store.motions_gone_words.is_empty() else ""
	if ModelStore.stored(path):
		_say("saved “%s”%s" % [name, gone])
		return
	_status.text = "saving “%s” in this browser…" % name
	for _n: int in 240:
		await get_tree().create_timer(0.5).timeout
		if ModelStore.stored(path):
			break
	_say("saved “%s”%s" % [name, gone] if ModelStore.stored(path)
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
	# "From a file", not "on this computer": on a phone or a tablet, where
	# it opens the device's own files, that was wrong (ux12, the walk at 390).
	_saves.add_item("From a file (LDraw, Studio .io, LDD .lxf)…", IMPORT)
	_saves.add_item("From the library: real sets and the gallery's models…", LIBRARY)
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
	# Beside the pointer, at whatever size a phone gives it.
	TouchSizing.popup_beside(_saves, get_global_mouse_position(), false)


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
		offer_moved(not entry.example, entry.path)


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
	# What it could not show, said as a file's open says it.
	if not unshown_words(store).is_empty():
		_say("opened %s%s" % [store.title, unshown_words(store)])
	return placed


## After a person's open (File, Open; a file; Recent; the library): the parts
## its file names by a moved or alias number, or has no file for, offered to
## them (moved_found: Shell's bar over the model, and the list for a part with
## no file), when it has any. Not a session's open, Together's or an undo's,
## which say it their own way or not at all.
##
## The renumbered ones only in the person's [param own] file, named by [param
## of] (its path or file name; the model's title when not given), and once
## (MovedOffer). An official set from the library or an example opens as it
## is: drawn right already, it is not theirs to renumber, and the strip over
## a set just opened was in the way of every fan who opened one (ux12). So
## does another program's file, a Studio .io or an LDD .lxf (MovedOffer
## .is_ldraw): "5 parts have new numbers in the LDraw library" stood over a
## friend's Studio file through every step of ux13's walk (p6), LDraw's
## history said of a file that is not LDraw's, which Studio opens unasked.
func offer_moved(own: bool = true, of: String = "") -> void:
	if store != null and store.not_opened.is_empty() and not store.moved.is_empty():
		moved_found.emit(own and MovedOffer.is_ldraw(of), of if not of.is_empty() else store.title)


## Missing and moved parts' Update all and Replace checked, and open_model
## replace_moved: [param numbers] written as the parts they point to in every
## sub-model (ModelStore.replace_moved), one step to undo, and the status bar
## saying so. The words said, or why not; "" when there is no model.
func replace_moved(numbers: Array) -> String:
	if store == null:
		return ""
	var done: Dictionary = store.replace_moved(numbers)
	if not str(done["error"]).is_empty():
		_say("could not replace them: %s" % done["error"])
		return "Could not replace them: %s." % done["error"]
	var said: String = Keymap.filled("%s — {undo|puts them back}") % done["words"]
	_say(said)
	return said


## The biggest file [method open_text_with_progress] reads and opens in one
## frame: a set of a few hundred parts, read in milliseconds.
const OPENED_AT_ONCE_MOST := 32 * 1024


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
##
## A file under [constant OPENED_AT_ONCE_MOST] is read and opened in the
## frame it came in, its bar never waited on to be drawn: a set's 8 KB file
## from its page waited eight frames for "Reading" and "Opening" to show (each
## up to three, as the parts bin's pictures held the drawing), and its read
## a frame more on a worker, each frame under the studio's first ones in a
## browser drawing in software a quarter to one and a half seconds, for a
## read of milliseconds (setopen, 2026-11-23).
func open_text_with_progress(text: String, name: String) -> Dictionary:
	var at_once: bool = text.length() < OPENED_AT_ONCE_MOST
	var job: Working.Job = Working.begin("Reading %s (%s)…" % [name, ModelLibrary.size_words(text.length())])
	var parsed: LdrModel = null
	if at_once:
		parsed = LdrModel.parse(text, name)
	else:
		await job.shown()
		parsed = await read_off_frame(text, name)
	if parsed != null:
		store.ask_geometry(parsed)
	if parsed != null and not parsed.generated.is_empty():
		job.say("Building the flexible parts of %s…" % name)
		await CustomParts.warm_skins(store.library, parsed)
	job.end()
	job = Working.begin("Opening %s…" % name)
	if not at_once:
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
## LdrModel.parse touches nothing but what it makes. Ahead of the pool's
## background work (high priority): somebody is waiting for the model, and
## the web's pool runs the rest on one thread, where an 8 KB set waited
## seconds behind the parts' reading as the app started (sethub, 2026-11-23).
static func read_off_frame(text: String, name: String) -> LdrModel:
	var out: Array = [null]
	var task: int = WorkerTasks.add(func() -> void: out[0] = LdrModel.parse(text, name),
		true, "read a model")
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	while not WorkerThreadPool.is_task_completed(task):
		await tree.process_frame
	WorkerTasks.collect(task)
	return out[0]


## What an open left out or is still waiting for, as File, Open from a file
## says it: " — 3 not in the library, left out (3001pr1, …)", and why a part
## the file carries could not be drawn; "" for nothing.
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
		# And why, for a part the file carries: a Studio file's own part
		# drawn from an LDraw part that could not be fetched, offline.
		var unbuilt: Dictionary = result.get("unbuilt", {})
		if not unbuilt.is_empty():
			note += " — " + ModelStore.unbuilt_words(unbuilt)
	# A part whose geometry could not be fetched as it opened: held as one on
	# its way is, so kept in the file (ModelStore.lost).
	var lost: Dictionary = result.get("lost", {})
	if not lost.is_empty():
		var count: int = 0
		for id: String in lost:
			count += int(lost[id])
		note += " — %d could not be loaded, kept in the file (%s)" % [count,
			ModelStore.named_counts(lost)]
	if again and int(result.get("waiting", 0)) > 0:
		note += " — %d are still arriving, open it again in a moment" % int(result["waiting"])
	# Light lines this could not read, kept in the file (SceneLights.of_model).
	if not str(result.get("lights_unread", "")).is_empty():
		note += " — " + str(result["lights_unread"])
	# And motion lines (Motions.unread_words), kept in it the same way.
	if not str(result.get("motions_unread", "")).is_empty():
		note += " — " + str(result["motions_unread"])
	# And view lines (SavedViews.unread_words): up to metalines one a later
	# build wrote went at the next save, unsaid.
	if not str(result.get("views_unread", "")).is_empty():
		note += " — " + str(result["views_unread"])
	# And a program for its motors this build cannot run (ProgramLine.unread_words).
	if not str(result.get("program_unread", "")).is_empty():
		note += " — " + str(result["program_unread"])
	return note


## What the open just made left off the baseplate (ModelStore.unshown), the
## light lines it could not read, as [method left_out_words] says a file's,
## and what of its booklet no step shows ([method looks_words]); "" for
## nothing. Kept in the file either way: the app's own writes them back
## (ModelStore._absent), someone else's carries them (SourceFile).
static func unshown_words(store: ModelStore) -> String:
	if not store.not_opened.is_empty():
		return ""
	return left_out_words({"missing": store.unshown.size(), "unshown": store.unshown,
		"kept": true, "lost": store.lost, "lights_unread": store.lights_unread_words,
		"motions_unread": store.motions_unread_words,
		"views_unread": store.views_unread_words,
		"program_unread": store.program_unread_words}, false) + looks_words(store)


## What of the booklet as its designer set it the model just opened shows on
## no step now, kept in the file (BookletLooks.unmatched_words): said where
## an open says what it left out. A pull whose parts had gone into a
## sub-model was dropped from sight without a word (pullkept).
static func looks_words(store: ModelStore) -> String:
	return BookletLooks.unmatched_words(store.world, store.library, store.scenery)


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


# -- a model into this one ------------------------------------------------------

## Puts parts whole in the person's hand, to put down by a click
## (EditVerbs.hold, which Shell sets): (parts, what) -> how many.
var hold_parts: Callable = Callable()
## File, Import, Into this model…'s list, and the saves and examples it lists.
var _into: PopupMenu
var _into_entries: Array[ModelStore.Entry] = []
var _into_picker: ModelFilePicker


## File, Import, Into this model…: the person's saved models and the
## examples, listed as Open lists them, with a file from this computer and
## the library; the one chosen comes in hand as one sub-assembly with its
## own steps, put down by a click and taken out by one undo
## (ModelStore.held_from). Two actions, as LeoCAD's Files category takes:
## here it was open, select all, copy, switch, paste (APP_UX4, intomodel).
func into_model() -> void:
	if store == null:
		return
	if _into == null:
		_into = PopupMenu.new()
		_into.id_pressed.connect(_on_into)
		add_child(_into)
	_into_entries = store.list_saved()
	var examples: Array[ModelStore.Entry] = store.list_examples()
	_into.clear()
	_into.add_item("From a file (LDraw, Studio .io, LDD .lxf)…", IMPORT)
	_into.add_item("From the library: real sets and the gallery's models…", LIBRARY)
	_into.add_separator("Put in this model, then click where it goes")
	for n: int in _into_entries.size():
		_into.add_item(_into_entries[n].describe(), n)
	if not examples.is_empty():
		_into.add_separator("Examples")
		for example: ModelStore.Entry in examples:
			_into.add_item(example.describe(), _into_entries.size())
			_into_entries.append(example)
	_into.reset_size()
	_into.position = Vector2i(get_global_mouse_position()) + Vector2i(0, 8)
	_into.popup()


func _on_into(id: int) -> void:
	if id == IMPORT:
		_into_file()
		return
	if id == LIBRARY:
		library_wanted.emit()
		return
	if id < 0 or id >= _into_entries.size():
		return
	var entry: ModelStore.Entry = _into_entries[id]
	var text: String = store._file_text(entry.path)
	if text.is_empty():
		_say("could not read “%s”: %s" % [entry.name, store.not_opened])
		return
	await hold_text(text, entry.path.get_file(), entry.name)


## A file from this computer into this model. Asked in the click itself, as
## [method _import] is, or a browser opens no picker.
func _into_file() -> void:
	if _into_picker == null:
		_into_picker = ModelFilePicker.new()
		_into_picker.library = store.library
		add_child(_into_picker)
		_into_picker.picked.connect(func(text: String, file_name: String) -> void:
			await hold_text(text, file_name))
		_into_picker.failed.connect(func(why: String) -> void: _say(why))
	_into_picker.ask()


## [param text], a model's file, in the person's hand whole, as one
## sub-assembly named [param called] (else as the file calls it), its
## author's steps kept, to put down by a click (ModelStore.held_from).
## [param credited] ({by, licence, page}) says whose it is where its file
## does not, kept in its sub-model's header and said with it. How many
## parts are in hand.
func hold_text(text: String, file_name: String, called: String = "",
		credited: Dictionary = {}) -> int:
	var job: Working.Job = Working.begin("Reading %s…" % (called if not called.is_empty()
		else file_name.get_file()))
	await job.shown()
	var held: Dictionary = await store.held_from(text, file_name, job, called, credited)
	job.end()
	if not str(held["error"]).is_empty():
		_say("could not put it in this model: %s" % held["error"])
		return 0
	var count: int = int(hold_parts.call(held["items"], str(held["name"]))) \
		if hold_parts.is_valid() else 0
	if count == 0:
		return 0
	store.builder.carrying.bring(held)
	var by: String = str(credited.get("by", "")).strip_edges()
	_say(Keymap.filled("holding %s, %s — click where it goes, {rotate_held|turns}, Esc puts away")
		% [held["name"], Builder._many(count)] + held_words(held)
		+ (" — by " + by if not by.is_empty() else ""))
	return count


## What else a model brought in comes with: its steps, what of it is kept
## and not shown, its motions, which its sub-model keeps and this model does
## not play, and the names given to what this model had already.
static func held_words(held: Dictionary) -> String:
	var said: String = ""
	if int(held["steps"]) > 0:
		said += " — " + ("its 1 step kept" if int(held["steps"]) == 1
			else "its %d steps kept" % int(held["steps"]))
	var unshown: Dictionary = held["unshown"]
	if not unshown.is_empty():
		said += " — " + "not shown, kept: %s" % ModelStore.named_counts(unshown)
	var motions: int = int(held.get("motions", 0))
	if motions > 0:
		said += " — " + ("its motion kept in it, played only where it is the model" if motions == 1
			else "its %d motions kept in it, played only where it is the model" % motions)
	var dropped := PackedStringArray()
	if int(held.get("bfc", 0)) > 0:
		dropped.append("its BFC line, which says how a file of its own is wound" if int(held["bfc"]) == 1
			else "its %d BFC lines, which say how a file of its own is wound" % int(held["bfc"]))
	if int(held.get("rotsteps", 0)) > 0:
		dropped.append(("its ROTSTEP" if int(held["rotsteps"]) == 1 else "its %d ROTSTEPs" % int(held["rotsteps"]))
			+ ", as nobody gave it the steps they turn the view after")
	if not dropped.is_empty():
		said += " — not kept: " + "; ".join(dropped)
	var renamed: Dictionary = held.get("renamed", {})
	if not renamed.is_empty():
		var pairs := PackedStringArray()
		for was: Variant in renamed:
			pairs.append("%s as %s" % [was, renamed[was]])
		said += " — " + "named anew, as this model has those names: %s" % ", ".join(pairs)
	return said


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
			var note: String = "opened %d parts" % int(result["placed"]) + left_out_words(result) \
				+ looks_words(store)
			if not _picker.notes.is_empty():
				note += " — " + _picker.notes
			_say(note)
			offer_moved(true, file_name))
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
	# The model asked for: one opened while it is written, or while the
	# person chooses where, is not written under its name (ModelStore.model_now).
	var model: int = store.model_now()
	var file_name: String = SubmodelFile.titled(model_name(), ldraw_extension())
	if OS.has_feature("web"):
		if await store.export_paced(file_name, model_name(), model):
			return "downloaded %s" % file_name
		return "not exported: another model was opened" if store.model_now() != model else ""
	# Only the name's last part: a model's title is named by whoever
	# designed it, and "../" in one would put the file somewhere else. With
	# nobody asked (a session's export_model), the next name nothing has
	# there (Download.unused, mcpreach).
	var path: String = await SaveTo.ask(file_name, into) if asking \
		else Download.unused((into if not into.is_empty() else Download.downloads()).path_join(
			file_name.replace("\\", "/").get_file()))
	if path.is_empty():
		return ""
	if await store.export_paced(path, model_name(), model):
		SaveTo.wrote(path)
		return "wrote %s%s" % [path, Download.kept_note(path)]
	if store.model_now() != model:
		return "did not write %s: another model was opened" % path
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
	end_typing()
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
	end_typing()
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
	_clear_asked_for = store.model_now() if store != null else -1
	_ask(_confirm)


## The model Clear was asked about (_ask_to_clear): one opened while the
## question is up, or in the frame before it clears, is never emptied in
## its place (pubbind).
var _clear_asked_for: int = -1


func _on_clear() -> void:
	var model: int = _clear_asked_for if _clear_asked_for >= 0 or store == null else store.model_now()
	_clear_asked_for = -1
	var job: Working.Job = await _say_first("Clearing %s parts…")
	if store != null and store.model_now() != model:
		if job != null:
			job.end()
		_say("not cleared: another model was opened")
		return
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
