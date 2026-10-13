## "Brickworks has been updated", with Reload: shown above the model once
## a newer build is live than the one this tab runs (NewerBuild).
##
## People keep a tab open for hours, and after a deploy it went on running
## the old build until they happened to reload it. Nothing else is in the
## way: the tab goes on working, and saves nothing outside its own session
## until it reloads (src/boot/shell.html). Reload writes the model on the
## baseplate first and waits until the browser has stored it, so the page
## that comes back opens it as it was left, under its name.
class_name UpdateOffer
extends PanelContainer

var store: ModelStore
## Takes the page away and brings the newer build: a probe replaces it.
## To the app's own address, keeping only a shared model being looked at
## (?view=): what opened a model once (?model=, ?copy=) opened it again in
## place of the one kept, which the first browser run of this caught.
var reload_page: Callable = func() -> void:
	JavaScriptBridge.eval("(function () { var at = new URL(location.href);"
		+ " var view = at.searchParams.get('view');"
		+ " at.search = view ? '?view=' + encodeURIComponent(view) : '';"
		+ " location.replace(at.href); })()", true)
## How long Reload waits for the model to be stored before reloading anyway
## (the browser then asks before a write still on its way is lost).
var wait_s: float = 120.0

var _words: Label
var _reload: Button
var _reloading: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.12, 0.14, 0.18, 0.96)
	backing.border_color = Color(0.56, 0.74, 1.0, 0.55)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(8)
	backing.content_margin_left = 14
	backing.content_margin_right = 10
	backing.content_margin_top = 6
	backing.content_margin_bottom = 6
	add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	_words = Label.new()
	_words.text = "Brickworks has been updated"
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(_words)
	_reload = ReloadOffer.button("Reload", true)
	_reload.tooltip_text = "Load the new version. The model in this tab comes back as it is."
	_reload.pressed.connect(reload)
	row.add_child(_reload)


## Say that [param commit] is live.
func offer(commit: String) -> void:
	if visible or commit.is_empty():
		return
	tooltip_text = "Version %s is live; this tab runs the one before it" % commit
	visible = true


func showing() -> bool:
	return visible


## Store the model on the baseplate, then reload.
func reload() -> void:
	if _reloading:
		return
	_reloading = true
	_reload.disabled = true
	var path: String = store.write_now() if store != null else ""
	if not path.is_empty() and not ModelStore.stored(path):
		_words.text = "Keeping this tab's model first…"
		var waited: float = 0.0
		while not ModelStore.stored(path) and waited < wait_s:
			await get_tree().create_timer(0.25).timeout
			waited += 0.25
	_words.text = "Reloading…"
	await get_tree().process_frame
	reload_page.call()


func controls_by_name() -> Dictionary:
	return {"update_reload": _reload} if visible else {}
