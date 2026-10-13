## Share this model: File › Share…, and the toolbar's Share.
##
## Publishes the model that is open as the signed-in account and hands
## back a link, https://brickworks.diy/m/<id>, that anyone can open with no
## account: the model in 3D, its steps, its booklet and its parts list
## (the app in its read-only mode, ShareView). Also the snippet that puts
## the link's card in a blog or a forum. Publishing again updates the same
## link; Unpublish takes it down and the link then says so.
##
## What goes up: the model as LDraw (to_text, so the prints, stickers and
## parts made here travel inside it as they do in any export), its name,
## the name it is credited to only if the box is ticked, and a picture of
## it from where the view is looking, for the link's preview on other
## sites. The link is kept with the model (ModelStore.share_id), so the
## next Publish of the same model updates it.
class_name SharePanel
extends PanelContainer

const WIDE := 470.0
const TALL := 470.0
## The size social sites show a link's picture at.
const CARD := Vector2i(1200, 630)
## Under the server's 600 KB, with room to spare.
const MOST_PNG := 560 * 1024

var account: Account
var store: ModelStore
var shared: SharedModels
var picture: Picture
## The model's name as the bar has it.
var named: Callable = func() -> String: return "Model"

## idle, publishing, published, unpublishing, unpublished, failed.
var state: String = "idle"
var url: String = ""
var embed: String = ""

var _name: LineEdit
var _credit: CheckBox
var _author: LineEdit
var _status: Label
var _publish: Button
var _link_box: VBoxContainer
var _link: LineEdit
var _copy_link: Button
var _copy_embed: Button
var _open_link: Button
var _unpublish: Button
var _done: Button


func setup() -> void:
	visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.10, 0.11, 0.13, 0.98)
	backing.border_color = Color(1, 1, 1, 0.14)
	backing.set_border_width_all(1)
	backing.set_corner_radius_all(6)
	backing.content_margin_left = 18
	backing.content_margin_right = 18
	backing.content_margin_top = 15
	backing.content_margin_bottom = 15
	add_theme_stylebox_override("panel", backing)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	add_child(column)

	var title := Label.new()
	title.text = "Share this model"
	title.add_theme_font_size_override("font_size", 15)
	column.add_child(title)
	column.add_child(_line("A link anyone can open, with no account: the model "
		+ "in 3D, its building steps, the booklet and the parts list. It is a "
		+ "copy as it is now; publish again to update it.", 12, 0.7))

	column.add_child(_line("Name", 12, 0.85))
	_name = LineEdit.new()
	_name.placeholder_text = "What is it called?"
	_name.max_length = 80
	_name.text_submitted.connect(func(_text: String) -> void: publish())
	column.add_child(_name)

	_credit = CheckBox.new()
	_credit.text = "Show who made it"
	_credit.focus_mode = Control.FOCUS_NONE
	_credit.add_theme_font_size_override("font_size", 12)
	_credit.toggled.connect(func(on: bool) -> void:
		_author.visible = on
		if on and _author.text.is_empty():
			_author.text = _suggested_author())
	column.add_child(_credit)
	_author = LineEdit.new()
	_author.placeholder_text = "The name to credit"
	_author.max_length = 60
	_author.visible = false
	column.add_child(_author)

	_publish = Button.new()
	_publish.text = "Publish"
	_publish.custom_minimum_size = Vector2(0, 34)
	_publish.focus_mode = Control.FOCUS_NONE
	_publish.pressed.connect(publish)
	column.add_child(_publish)

	_status = _line("", 12, 0.85)
	column.add_child(_status)

	_link_box = VBoxContainer.new()
	_link_box.add_theme_constant_override("separation", 6)
	_link_box.visible = false
	column.add_child(_link_box)
	_link = LineEdit.new()
	_link.editable = false
	_link.selecting_enabled = true
	_link_box.add_child(_link)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_link_box.add_child(row)
	_copy_link = _small(row, "Copy link", "Put the link on the clipboard")
	_copy_link.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(url)
		_status.text = "The link is on the clipboard.")
	_copy_embed = _small(row, "Copy embed code",
		"An iframe of the model's card, for a blog or a forum")
	_copy_embed.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(embed)
		_status.text = "The embed code is on the clipboard: paste it into the page's HTML.")
	_open_link = _small(row, "Open", "Open the link in the browser")
	_open_link.pressed.connect(func() -> void: OS.shell_open(url))
	_unpublish = Button.new()
	_unpublish.text = "Unpublish"
	_unpublish.focus_mode = Control.FOCUS_NONE
	_unpublish.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_unpublish.tooltip_text = "Take the model down. The link then says it is no longer shared."
	_unpublish.pressed.connect(unpublish)
	_link_box.add_child(_unpublish)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	_done = Button.new()
	_done.text = "Done"
	_done.custom_minimum_size = Vector2(0, 32)
	_done.focus_mode = Control.FOCUS_NONE
	_done.pressed.connect(func() -> void: visible = false)
	column.add_child(_done)


func _line(text: String, size: int, alpha: float) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = Color(1, 1, 1, alpha)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _small(row: Container, words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 12)
	row.add_child(button)
	return button


## The part of the account's address before the @, as a first guess at a
## name to credit. Only ever shown in the box, never sent unless ticked.
func _suggested_author() -> String:
	var email: String = account.email if account != null else ""
	return email.get_slice("@", 0).replace(".", " ").capitalize() if "@" in email else ""


func open() -> void:
	visible = not visible
	if not visible:
		return
	var title: String = str(named.call())
	_name.text = "" if title == ModelStore.UNTITLED else title
	if state in ["publishing", "unpublishing"]:
		return
	_show_link(store.share_id)
	if store.share_id.is_empty():
		state = "idle"
		_status.text = "" if account.signed_in() else "Sign in to Brickworks to share a model."
	else:
		_status.text = "This model has a link. Publish again to update what it shows."
		_check_link(store.share_id)


## Whether the model's link is up or was taken down, so the buttons say
## the right thing. Asked of the account's own list, which is small.
func _check_link(id: String) -> void:
	var token: String = await account.access_token()
	if token.is_empty():
		return
	var answer: Dictionary = await shared.mine(token)
	if store.share_id != id or not answer.get("body") is Dictionary:
		return
	for one: Variant in (answer["body"] as Dictionary).get("shared", []):
		if one is Dictionary and str((one as Dictionary).get("id", "")) == id:
			var up: bool = bool((one as Dictionary).get("published", false))
			state = "published" if up else "unpublished"
			_status.text = ("Shared at this link. Publish again to update what it shows."
				if up else "Taken down. Publish again to bring it back at the same link.")
			_show_link(id)
			return


func _show_link(id: String) -> void:
	_link_box.visible = not id.is_empty()
	url = SharedModels.link_for(id) if not id.is_empty() else ""
	embed = SharedModels.embed_for(id) if not id.is_empty() else ""
	_link.text = url
	var up: bool = not id.is_empty() and state != "unpublished"
	_copy_link.disabled = not up
	_copy_embed.disabled = not up
	_open_link.disabled = not up
	_unpublish.visible = up
	_publish.text = "Publish" if id.is_empty() else (
		"Update the link" if up else "Publish again")


## Publish the model as it stands, at its own link if it has one.
func publish() -> void:
	if state in ["publishing", "unpublishing"]:
		return
	var name: String = _name.text.strip_edges()
	if name.is_empty():
		_fail("Give the model a name first.")
		return
	var token: String = await account.access_token()
	if token.is_empty():
		_fail("Sign in to Brickworks to share a model.")
		return
	state = "publishing"
	_publish.disabled = true
	_status.text = "Taking its picture…"
	var png: PackedByteArray = await _picture()
	_status.text = "Publishing…"
	# A big model's build order a slice at a time, said and counted.
	var model: String = await store.text_for_file(name, "Writing “%s” for its link…" % name)
	if model.is_empty():
		_publish.disabled = false
		_fail("Stopped before it was published.")
		return
	var body: Dictionary = {"name": name, "model": model}
	var author: String = _author.text.strip_edges()
	if _credit.button_pressed and not author.is_empty():
		body["author"] = author
	if not png.is_empty():
		body["image"] = Marshalls.raw_to_base64(png)
	if not store.share_id.is_empty():
		body["id"] = store.share_id
	var answer: Dictionary = await shared.publish(token, body)
	# A link that is not this account's — the model came from somebody
	# else's link, or another account shared it on this device — or one
	# that has gone: the model gets a link of its own.
	if int(answer["code"]) in [403, 404] and body.has("id"):
		body.erase("id")
		answer = await shared.publish(token, body)
	_publish.disabled = false
	var reply: Variant = answer.get("body")
	if not int(answer["code"]) in [200, 201] or not reply is Dictionary:
		_fail(SharedModels.trouble(answer, "Brickworks could not publish it just now."))
		return
	var said: Dictionary = reply
	store.share_id = str(said.get("id", ""))
	# Kept with the model, so the next Publish updates this link.
	store.touch()
	state = "published"
	_show_link(store.share_id)
	url = str(said.get("url", url))
	embed = str(said.get("embed", embed))
	_link.text = url
	_status.text = "%s at this link, %d parts. Anyone with it can look — no account needed." % [
		"Updated" if bool(said.get("updated", false)) else "Shared", int(said.get("parts", 0))]


func unpublish() -> void:
	if store.share_id.is_empty() or state in ["publishing", "unpublishing"]:
		return
	var token: String = await account.access_token()
	if token.is_empty():
		_fail("Sign in to Brickworks to take it down.")
		return
	state = "unpublishing"
	_status.text = "Taking it down…"
	var answer: Dictionary = await shared.unpublish(token, store.share_id)
	if int(answer["code"]) != 200:
		state = "published"
		_fail(SharedModels.trouble(answer, "Brickworks could not take it down just now."))
		return
	state = "unpublished"
	_show_link(store.share_id)
	_status.text = "Taken down: the link now says the model is no longer shared. Publish again to bring it back at the same link."


func _fail(words: String) -> void:
	if state != "published" and state != "unpublished":
		state = "failed"
	_status.text = words


## The link's picture: the model from where the view is looking, on a
## plain ground, as a PNG small enough to send. Empty when there is no
## picture to be had (a run with nothing to draw with).
func _picture() -> PackedByteArray:
	if picture == null:
		return PackedByteArray()
	var shot: Image = await picture.take(CARD)
	if shot == null or shot.is_empty():
		return PackedByteArray()
	shot.convert(Image.FORMAT_RGBA8)
	var card := Image.create(CARD.x, CARD.y, false, Image.FORMAT_RGBA8)
	# A soft ground, lighter at the top, so the model reads on any site.
	for y: int in CARD.y:
		var t: float = float(y) / float(CARD.y - 1)
		card.fill_rect(Rect2i(0, y, CARD.x, 1), Color(0.93, 0.94, 0.96).lerp(Color(0.80, 0.83, 0.87), t))
	card.blend_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i.ZERO)
	card.convert(Image.FORMAT_RGB8)
	var png: PackedByteArray = card.save_png_to_buffer()
	if png.size() > MOST_PNG:
		card.resize(800, 420, Image.INTERPOLATE_LANCZOS)
		png = card.save_png_to_buffer()
	return png if png.size() <= MOST_PNG else PackedByteArray()


## Its controls, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named_controls: Dictionary = {"share_name": _name, "share_credit": _credit,
		"share_publish": _publish, "share_done": _done}
	if _author.is_visible_in_tree():
		named_controls["share_author"] = _author
	if _link_box.is_visible_in_tree():
		named_controls["share_copy_link"] = _copy_link
		named_controls["share_copy_embed"] = _copy_embed
		named_controls["share_open"] = _open_link
		if _unpublish.is_visible_in_tree():
			named_controls["share_unpublish"] = _unpublish
	return named_controls


## What a browser test cannot read off the canvas.
func page_state() -> Dictionary:
	return {"open": visible, "state": state, "id": store.share_id if store != null else "",
		"url": url, "embed": embed, "status": _status.text if _status != null else ""}


## Escape closes it, like the other panels.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
