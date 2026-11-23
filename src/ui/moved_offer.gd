## The offer to update the parts a model's file names by a number the LDraw
## library has moved or keeps as an alias, made in the strip over the model
## as a person's own open finds them, and never in their way.
##
## 3023 is "~Moved to 3023b" now, so most models anyone opens have such
## parts, and a list over the model on every open was friction (mvfix,
## 2026-11-15). The model is drawn right already: each moved part as the
## part it became, an alias as itself. So the strip says how many, with
## Update all (each written as the part it points to, in every sub-model,
## one step to undo), Review… (the list, MovedPartsDialog, to choose from)
## and Keep as is (the file as it was). A part with no file at all is still
## asked about in the list (Shell).
##
## Said once for a file and its numbers, then never again over it: Keep as is
## was asked again at every open, and an official set from the library or an
## example is not offered at all (ModelBar.offer_moved; ux12's walk saw it over
## a set just opened).
class_name MovedOffer
extends PanelContainer

var store: ModelStore
## Update all: the numbers, replaced as ModelBar.replace_moved does.
var update: Callable = func(_numbers: Array) -> void: pass
## Review…: the list of them (MovedPartsDialog).
var review: Callable = func() -> void: pass

var _words: Label
var _update: Button
var _review: Button
var _keep: Button
## The world's generation the offer is of: an offer made for one model is
## never applied to the next.
var _of_generation: int = -1


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
	backing.content_margin_top = 8
	backing.content_margin_bottom = 8
	add_theme_stylebox_override("panel", backing)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	add_child(row)

	_words = Label.new()
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_words.custom_minimum_size = Vector2(240, 0)
	_words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_words.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_words.add_theme_font_size_override("font_size", 13)
	_words.add_theme_color_override("font_color", Color(0.9, 0.92, 0.96))
	row.add_child(_words)

	_update = ReloadOffer.button("Update all", true)
	Keymap.tell(_update, "Write each as the part it now is, in every sub-model.\n"
		+ "One step: {undo|puts them back}.")
	_update.pressed.connect(update_all)
	row.add_child(_update)
	_review = ReloadOffer.button("Review…", false)
	_review.tooltip_text = "See each number, what it points to and where it is used, and choose"
	_review.pressed.connect(func() -> void:
		visible = false
		review.call())
	row.add_child(_review)
	_keep = ReloadOffer.button("Keep as is", false)
	_keep.tooltip_text = "Keep the file's numbers as they are"
	_keep.pressed.connect(dismiss)
	row.add_child(_keep)


## Said for the model on the baseplate, as its open listed it
## (ModelStore.moved), when it has moved or alias parts and has not been said
## for the file [param of] and those numbers before (ShellPrefs "moved_said");
## hidden when not.
func offer(of: String = "") -> void:
	var count: int = MovedParts.renumbered_count(store.moved) if store != null else 0
	if count == 0 or store.world == null:
		dismiss()
		return
	var key: String = said_key(of if not of.is_empty() else store.title, store.moved)
	var said: Dictionary = (ShellPrefs.value("moved_said") as Dictionary).duplicate()
	if said.has(key):
		dismiss()
		return
	said[key] = int(Time.get_unix_time_from_system())
	# The newest MOST_KEPT, so the file it is kept in stays small.
	if said.size() > MOST_KEPT:
		var keys: Array = said.keys()
		keys.sort_custom(func(a: String, b: String) -> bool: return int(said[a]) < int(said[b]))
		for old: String in keys.slice(0, said.size() - MOST_KEPT):
			said.erase(old)
	ShellPrefs.put("moved_said", said)
	_of_generation = store.world.generation()
	_words.text = words(count)
	visible = true


## How many files' offers are remembered as said.
const MOST_KEPT := 200


## What an offer is remembered by: the file [param of] and the renumbered
## numbers [param moved] lists, so a file given more of them is offered them.
static func said_key(of: String, moved: Dictionary) -> String:
	var numbers: Array = []
	for number: String in moved:
		if str(moved[number]["kind"]) != MovedParts.MISSING:
			numbers.append(number)
	numbers.sort()
	return "%s|%s" % [of, ",".join(numbers)]


## What the strip says of [param count] parts.
static func words(count: int) -> String:
	return "1 part has a new number in the LDraw library" if count == 1 \
		else "%d parts have new numbers in the LDraw library" % count


## Update all: every moved and alias number of the model it was offered for.
func update_all() -> void:
	visible = false
	if store == null or store.world == null or store.world.generation() != _of_generation:
		return
	var numbers: Array = []
	for number: String in store.moved:
		if str(store.moved[number]["kind"]) != MovedParts.MISSING:
			numbers.append(number)
	if not numbers.is_empty():
		update.call(numbers)


## The model replaced, or its moved parts replaced another way (the list,
## open_model): nothing left to offer.
func follow() -> void:
	if visible and (store == null or MovedParts.renumbered_count(store.moved) == 0):
		visible = false


func dismiss() -> void:
	visible = false


func showing() -> bool:
	return visible


func words_now() -> String:
	return _words.text if visible else ""


## What a browser check presses.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	return {"moved_update": _update, "moved_review": _review, "moved_dismiss": _keep}
