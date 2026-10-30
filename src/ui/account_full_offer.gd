## The account is full, or nearly: said above the model after a save, with
## the way to make room (lib219, 2026-10-24).
##
## The account keeps 500 models and 64 MB at most (CloudModels). Past it a
## save was kept in the browser alone, said once on the status bar for a
## few seconds, and nothing offered to help. Now Save says so plainly here,
## and offers the saved models to delete, the oldest first
## (SavedModelsDialog). Full, it is said after every save until there is
## room; nearly full, once a session. And when the plan keeps no more (Free
## keeps 25 with the account, savecap360), the plan's words, with Pro's
## page beside the way to delete one.
class_name AccountFullOffer
extends PanelContainer

## Shows the saved models to delete, the oldest first.
var make_room: Callable = func() -> void: pass

var _words: Label
var _room: Button
var _pro: Button
var _pro_page: String = ""
var _close: Button
var _told_near: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.17, 0.13, 0.09, 0.97)
	backing.border_color = Color(1.0, 0.72, 0.36, 0.6)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 14
	backing.content_margin_right = 10
	backing.content_margin_top = 8
	backing.content_margin_bottom = 8
	add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(300, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.96, 0.93, 0.88))
	row.add_child(_words)
	_room = ReloadOffer.button("Delete old models…", true)
	_room.tooltip_text = "Your saved models, the oldest first, to delete those you no longer need"
	_room.pressed.connect(func() -> void:
		visible = false
		make_room.call())
	row.add_child(_room)
	_pro = ReloadOffer.button("See Pro", false)
	_pro.tooltip_text = "Pro keeps any number of models with your account"
	_pro.visible = false
	_pro.pressed.connect(func() -> void:
		visible = false
		Outside.open_link(Deployment.api_base() + _pro_page))
	row.add_child(_pro)
	_close = ReloadOffer.button("Not now", false)
	_close.pressed.connect(func() -> void: visible = false)
	row.add_child(_close)


## Say [param words] (CloudModels.short_words): a full account every time,
## a nearly full one once; [param pro], Pro's page, when it is the plan
## that keeps no more.
func tell(words: String, pro: String = "") -> void:
	if words.is_empty():
		return
	_pro_page = pro
	_pro.visible = not pro.is_empty()
	var full: bool = words.begins_with("Your account is full") or not pro.is_empty()
	if not full and _told_near:
		return
	_told_near = _told_near or not full
	_words.text = words
	visible = true


func showing() -> bool:
	return visible


func words() -> String:
	return _words.text if visible else ""


func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named: Dictionary = {"room_delete_old": _room, "room_not_now": _close}
	if _pro.visible:
		named["room_see_pro"] = _pro
	return named
