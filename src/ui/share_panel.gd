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
##
## Publishing again makes the link's next version and keeps the one before
## (2026-10-18, api/share.js): What changed? says it in its owner's words,
## shown with the version on its page and in the viewer beside what the
## server works out changed from the two files, which the status line then
## says too ("Version 2: 2 parts added and 2 removed in step 3.").
##
## List it in the gallery, off unless ticked, also puts the model on
## brickworks.diy/gallery for anyone to find (2026-10-13); unticked and
## published again, it leaves the gallery and keeps its link. A model
## copied from somebody's link says so when it is published
## (ModelStore.remixed_from), and its page names the one it came from.
##
## And tested as it goes up (2026-10-18, Tested): built by the very steps
## the link carries, it stands at every step, no part of a step goes in the
## air or behind what is built, every part is made in its colour, nothing
## is loose. What the app found goes with it, and the server keeps it as
## this app's finding (api/_tested.js). Passed, the link is marked Tested
## for everybody; failed, the status line says which test and why, and only
## its owner is ever told.
##
## And what the model's page and the gallery say about it (2026-10-13, the
## directory): a few lines about it, tags, its kind — guessed from the name
## and the tags (ModelKinds), for its owner to change — and a licence, CC
## BY unless they choose otherwise. With the big picture goes a small one
## for the gallery's cards, so a page of them is quick on a phone.
##
## Beside Publish, the community guidelines (2026-10-18, web/guidelines.html):
## publishing means agreeing to them. And for an account that said it is
## under 13 (Account.over_13, supabase/trust.sql), List it in the gallery and
## Show who made it are off, with a line saying why; sharing by link is as
## it is for anyone. The server refuses both for such an account too.
class_name SharePanel
extends PanelContainer

const WIDE := 490.0
const TALL := 780.0
## The size social sites show a link's picture at.
const CARD := Vector2i(1200, 630)
## Under the server's 600 KB, with room to spare.
const MOST_PNG := 560 * 1024
## The gallery's cards, at twice the size a phone shows one.
const THUMB := Vector2i(480, 252)
## Under the server's 64 KB.
const MOST_THUMB := 60 * 1024
## As api/share.js keeps them.
const MOST_ABOUT := 1000
const MOST_NOTE := 280
## [id, name, what it lets others do], as api/_directory.js LICENCES.
const LICENCES: Array = [
	["cc-by-4.0", "CC BY 4.0",
		"Anyone may share it, change it and build on it, crediting you."],
	["cc-by-sa-4.0", "CC BY-SA 4.0",
		"As CC BY, and what others make from it is shared the same way."],
	["all-rights-reserved", "All rights reserved",
		"Others may look at it and build it for themselves, and ask you before sharing it."],
]

var account: Account
var store: ModelStore
var shared: SharedModels
## What moves in the model as it stands (main.gd: Playable's words, from the
## joints a drag uses), sent with it: its gallery card says them.
var moves_of: Callable = Callable()
## What the last publish sent of it.
var moves: PackedStringArray = PackedStringArray()
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
var _about: TextEdit
var _tags: LineEdit
var _kind: OptionButton
## Whether the kind is the owner's choice, not the guess: then a new name
## does not change it.
var _kind_chosen: bool = false
## Which model the words are about: its link and its name.
var _words_for: String = "-"
var _licence: OptionButton
var _licence_says: Label
var _list: CheckBox
## What changed, said by its owner: for a model that has a link already.
var _note_label: Label
var _note: LineEdit
## The version the link is at after the last publish, and what the server
## said changed in it.
var version: int = 0
var version_said: String = ""
## Said to an account under 13, under the box it cannot tick.
var _young: Label
var _guidelines: LinkButton
## What the last publish's tests found (Tested.check), and what the panel
## said of it to its owner.
var tested: Dictionary = {}
var tested_said: String = ""
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

	# What is said about it, in a scroll of its own: on a short window the
	# buttons below stay where they can be pressed.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 7)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)

	form.add_child(_line("Name", 12, 0.85))
	_name = LineEdit.new()
	_name.placeholder_text = "What is it called?"
	_name.max_length = 80
	_name.text_submitted.connect(func(_text: String) -> void: publish())
	_name.text_changed.connect(func(_text: String) -> void: _guess_kind())
	form.add_child(_name)

	_credit = CheckBox.new()
	_credit.text = "Show who made it"
	_credit.focus_mode = Control.FOCUS_NONE
	_credit.add_theme_font_size_override("font_size", 12)
	_credit.toggled.connect(func(on: bool) -> void:
		_author.visible = on
		if on and _author.text.is_empty():
			_author.text = _suggested_author())
	form.add_child(_credit)
	_author = LineEdit.new()
	_author.placeholder_text = "The name to credit"
	_author.max_length = 60
	_author.visible = false
	form.add_child(_author)

	form.add_child(_line("About it (shown on its page)", 12, 0.85))
	_about = TextEdit.new()
	_about.placeholder_text = "What it is, how it goes together, what you would change."
	_about.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_about.custom_minimum_size = Vector2(0, 66)
	_about.add_theme_font_size_override("font_size", 13)
	_about.text_changed.connect(func() -> void:
		# Kept to what the server keeps, as it is typed.
		if _about.text.length() > MOST_ABOUT:
			_about.text = _about.text.left(MOST_ABOUT)
			_about.set_caret_column(_about.get_line(_about.get_line_count() - 1).length())
			_about.set_caret_line(_about.get_line_count() - 1)
		_guess_kind())
	form.add_child(_about)

	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 10)
	form.add_child(pair)
	var tag_side := VBoxContainer.new()
	tag_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag_side.size_flags_stretch_ratio = 1.4
	pair.add_child(tag_side)
	tag_side.add_child(_line("Tags", 12, 0.85))
	_tags = LineEdit.new()
	_tags.placeholder_text = "castle, tower, wizard"
	_tags.max_length = 200
	_tags.tooltip_text = "Up to eight, between commas. Anyone can find it by them in the gallery."
	_tags.text_changed.connect(func(_text: String) -> void: _guess_kind())
	tag_side.add_child(_tags)
	var kind_side := VBoxContainer.new()
	kind_side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pair.add_child(kind_side)
	kind_side.add_child(_line("Kind", 12, 0.85))
	_kind = OptionButton.new()
	_kind.focus_mode = Control.FOCUS_NONE
	_kind.add_theme_font_size_override("font_size", 12)
	_kind.add_item("Not said")
	for kind: Array in ModelKinds.KINDS:
		_kind.add_item(str(kind[1]))
	_kind.tooltip_text = "What the gallery files it under. A guess from its name and tags: change it if it is wrong."
	_kind.item_selected.connect(func(_at: int) -> void: _kind_chosen = true)
	kind_side.add_child(_kind)

	form.add_child(_line("Licence", 12, 0.85))
	_licence = OptionButton.new()
	_licence.focus_mode = Control.FOCUS_NONE
	_licence.add_theme_font_size_override("font_size", 12)
	for licence: Array in LICENCES:
		_licence.add_item(str(licence[1]))
	_licence.item_selected.connect(func(_at: int) -> void: _say_licence())
	form.add_child(_licence)
	_licence_says = _line("", 11, 0.65)
	form.add_child(_licence_says)
	_say_licence()

	# Off unless ticked: a link is for whoever it is sent to, and the
	# gallery is for everybody.
	_list = CheckBox.new()
	_list.text = "List it in the gallery"
	_list.tooltip_text = "Anyone can find it at brickworks.diy/gallery, not only people sent the link. " \
		+ "Untick it and publish again to take it out and keep the link."
	_list.focus_mode = Control.FOCUS_NONE
	_list.add_theme_font_size_override("font_size", 12)
	form.add_child(_list)
	_young = _line("The gallery and a name shown on a link are for people 13 and over. "
		+ "Anyone you send the link to can open it all the same.", 11, 0.7)
	_young.visible = false
	form.add_child(_young)

	_note_label = _line("What changed? (shown with the new version)", 12, 0.85)
	form.add_child(_note_label)
	_note = LineEdit.new()
	_note.placeholder_text = "Fixed the roof; the door opens now"
	_note.max_length = MOST_NOTE
	_note.tooltip_text = "Publishing again keeps the version before. Anyone can see what you say here " \
		+ "beside what changed, part by part and step by step."
	_note.text_submitted.connect(func(_text: String) -> void: publish())
	form.add_child(_note)
	_show_note(false)

	_publish = Button.new()
	_publish.text = "Publish"
	_publish.custom_minimum_size = Vector2(0, 34)
	_publish.focus_mode = Control.FOCUS_NONE
	_publish.pressed.connect(publish)
	column.add_child(_publish)
	# What publishing agrees to, where it is agreed to.
	# One line, never wrapped: a wrapping label in a row is given no width
	# and stands one letter to a line down the panel.
	var agree := HBoxContainer.new()
	agree.add_theme_constant_override("separation", 4)
	column.add_child(agree)
	var agree_words: Label = _line("Publishing means you agree to the", 11, 0.7)
	agree_words.autowrap_mode = TextServer.AUTOWRAP_OFF
	agree.add_child(agree_words)
	_guidelines = Look.link("guidelines", 11)
	_guidelines.tooltip_text = "What may be shared here, credit and licences, and what gets a model taken out"
	_guidelines.pressed.connect(func() -> void: OS.shell_open(guidelines_url()))
	agree.add_child(_guidelines)

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

	_done = Button.new()
	_done.text = "Done"
	_done.custom_minimum_size = Vector2(0, 32)
	_done.focus_mode = Control.FOCUS_NONE
	_done.pressed.connect(func() -> void: visible = false)
	column.add_child(_done)


## The community guidelines, on the site this app talks to.
static func guidelines_url() -> String:
	return Deployment.api_base() + "/guidelines"


## Whether the account said it is under 13: then nothing it shares is
## listed or credited (the server refuses both too).
func _kept_private() -> bool:
	return account != null and account.over_13 is bool and account.over_13 == false


## The boxes an account under 13 cannot tick, off, and why.
func _follow_age() -> void:
	var young: bool = _kept_private()
	_young.visible = young
	if young:
		_list.button_pressed = false
		_list.disabled = true
		_credit.button_pressed = false
		_credit.disabled = true
	else:
		_credit.disabled = false


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


## The kind the words say, unless the owner chose one.
func _guess_kind() -> void:
	if _kind_chosen or _kind == null:
		return
	var guessed: String = ModelKinds.guess("%s %s %s" % [_name.text, _tags.text.replace(",", " "), _about.text])
	_kind.select(ModelKinds.ids().find(guessed) + 1)


## The kind chosen: an id of ModelKinds, or "" for none said.
func _kind_id() -> String:
	var at: int = _kind.selected - 1
	var ids: PackedStringArray = ModelKinds.ids()
	return ids[at] if at >= 0 and at < ids.size() else ""


func _set_kind(id: String) -> void:
	_kind.select(ModelKinds.ids().find(id) + 1)


func _licence_id() -> String:
	return str(LICENCES[clampi(_licence.selected, 0, LICENCES.size() - 1)][0])


func _set_licence(id: String) -> void:
	for at: int in LICENCES.size():
		if str(LICENCES[at][0]) == id:
			_licence.select(at)
	_say_licence()


func _say_licence() -> void:
	if _licence_says != null:
		_licence_says.text = str(LICENCES[clampi(_licence.selected, 0, LICENCES.size() - 1)][2])


## What is said about a model with no link yet: nothing, the kind its name
## says, and CC BY.
func _fresh_words() -> void:
	_about.text = ""
	_tags.text = ""
	_kind_chosen = false
	_set_licence("cc-by-4.0")
	_guess_kind()


## What the link says about it now, from the account's own list.
func _words_from(row: Dictionary) -> void:
	_about.text = str(row["description"]) if row.get("description") is String else ""
	var tags: PackedStringArray = PackedStringArray()
	if row.get("tags") is Array:
		for tag: Variant in row["tags"]:
			tags.append(str(tag))
	_tags.text = ", ".join(tags)
	if row.get("kind") is String and not str(row["kind"]).is_empty():
		_set_kind(str(row["kind"]))
		_kind_chosen = true
	else:
		_kind_chosen = false
		_guess_kind()
	_set_licence(str(row["licence"]) if row.get("licence") is String else "cc-by-4.0")


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
	# What was typed about a model is kept while the panel is closed and
	# opened again, and starts afresh for another model.
	var which: String = "%s|%s" % [store.share_id, title]
	var fresh: bool = which != _words_for
	if fresh:
		_words_for = which
		_fresh_words()
	if store.share_id.is_empty():
		state = "idle"
		_list.button_pressed = false
		_list.disabled = false
		_status.text = "" if account.signed_in() else "Sign in to Brickworks to share a model."
	else:
		_status.text = "This model has a link. Publish again to update what it shows."
		_check_link(store.share_id, fresh)
	_follow_age()


## Whether the model's link is up or was taken down, so the buttons say
## the right thing. Asked of the account's own list, which is small. And,
## the first time the panel opens on it, what the link says about the
## model, to change or keep.
func _check_link(id: String, words: bool = true) -> void:
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
			# The box as the link is, so Update the link does not take a
			# listed model out of the gallery by surprise.
			var barred: bool = bool((one as Dictionary).get("barred", false))
			if words:
				_words_from(one as Dictionary)
			_list.button_pressed = up and bool((one as Dictionary).get("listed", false)) and not barred
			_list.disabled = barred
			_follow_age()
			_status.text = ("Shared at this link. Publish again to update what it shows."
				if up else "Taken down. Publish again to bring it back at the same link.")
			if up and _list.button_pressed:
				_status.text = "Shared at this link and listed in the gallery. Publish again to update it."
			if barred:
				_status.text += " Brickworks took it out of the gallery, so it cannot be listed there."
			_show_link(id)
			return


## What changed? is for a model with a link up: the next publish is its
## next version.
func _show_note(yes: bool) -> void:
	_note_label.visible = yes
	_note.visible = yes


func _show_link(id: String) -> void:
	_show_note(not id.is_empty() and state != "unpublished")
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
	var pictures: Dictionary = await _pictures()
	var png: PackedByteArray = pictures["png"]
	_status.text = "Publishing…"
	# A big model's build order a slice at a time, said and counted.
	var model: String = await store.text_for_file(name, "Writing “%s” for its link…" % name)
	if model.is_empty():
		_publish.disabled = false
		_fail("Stopped before it was published.")
		return
	# Its build steps, worked out here once and carried with it, so a phone
	# opening the link to build from does not work them out (SharedPages).
	# And tested by them as it goes (Tested): the four tests the "Tested"
	# mark is, sent with it as this app's finding.
	_status.text = "Working out its steps for the link, and testing it…"
	var steps_job: Working.Job = Working.begin("Working out the steps of “%s” for its link…" % name)
	await steps_job.shown()
	var made: Dictionary = await SharedPages.attach_tested(model, store.library, store, steps_job)
	steps_job.end()
	model = str(made["text"])
	tested = made["tested"]
	_status.text = "Publishing…"
	var body: Dictionary = {"name": name, "model": model}
	if tested.has("tests"):
		body["tested"] = tested
	# What moves in it, from its joints: "Moves: steering, boom" on its card,
	# and what its link lets anybody take hold of.
	if moves_of.is_valid():
		moves = moves_of.call()
		body["moves"] = Array(moves)
	var author: String = _author.text.strip_edges()
	if _credit.button_pressed and not author.is_empty():
		body["author"] = author
	if not png.is_empty():
		body["image"] = Marshalls.raw_to_base64(png)
	if not (pictures["thumb"] as PackedByteArray).is_empty():
		body["thumb"] = Marshalls.raw_to_base64(pictures["thumb"])
	# What its page and the gallery say about it: said every time, so a
	# box emptied empties it there too.
	body["description"] = _about.text.strip_edges()
	body["tags"] = _tags.text.strip_edges()
	body["kind"] = _kind_id()
	body["licence"] = _licence_id()
	if not store.share_id.is_empty():
		body["id"] = store.share_id
	body["listed"] = _list.button_pressed and not _list.disabled
	if not store.remixed_from.is_empty():
		body["remixed_from"] = store.remixed_from
		if store.remixed_from_version > 0:
			body["remixed_from_version"] = store.remixed_from_version
	# What changed, for a link already up: its next version's words.
	var note: String = _note.text.strip_edges()
	if body.has("id") and _note.visible and not note.is_empty():
		body["note"] = note
	var answer: Dictionary = await shared.publish(token, body)
	# A link that is not this account's — the model came from somebody
	# else's link, or another account shared it on this device — or one
	# that has gone: the model gets a link of its own.
	if int(answer["code"]) in [403, 404] and body.has("id"):
		body.erase("id")
		# A first version: nothing it changed from.
		body.erase("note")
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
	# What was said stays in the boxes, as the link now has it.
	_words_for = "%s|%s" % [store.share_id, str(named.call())]
	state = "published"
	_show_link(store.share_id)
	url = str(said.get("url", url))
	embed = str(said.get("embed", embed))
	_link.text = url
	var listed: bool = bool(said.get("listed", false))
	_list.button_pressed = listed
	version = int(said.get("version", 1))
	version_said = str(said.get("said", ""))
	_status.text = ("%s at this link and listed in the gallery, %d parts. Anyone can find it "
		+ "at brickworks.diy/gallery — no account needed." if listed
		else "%s at this link, %d parts. Anyone with it can look — no account needed.") % [
		"Updated" if bool(said.get("updated", false)) else "Shared", int(said.get("parts", 0))]
	# A new version: what changed, and that the one before is kept.
	if version > 1:
		_status.text = "Version %d is up at this link%s, and version %d is kept at its own. %s" % [
			version, " and listed in the gallery" if listed else "", version - 1, version_said]
		_status.text = _status.text.strip_edges()
	_note.text = ""
	_show_note(true)
	# Whether it is marked Tested, or which test it failed and why: a note
	# to its designer, which nobody else is shown.
	var kept: Variant = said.get("tested")
	tested_said = Tested.words(tested)
	if kept is Dictionary and not bool((kept as Dictionary).get("kept", false)) and tested.has("tests"):
		tested_said = "Not tested: %s." % str((kept as Dictionary).get("why", "it could not be kept"))
	_status.text = "%s %s" % [_status.text, tested_said]


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
	# Out of the gallery with it (api/share.js); listed again only if
	# ticked again.
	_list.button_pressed = false
	_show_link(store.share_id)
	_status.text = "Taken down: the link now says the model is no longer shared. Publish again to bring it back at the same link."


func _fail(words: String) -> void:
	if state != "published" and state != "unpublished":
		state = "failed"
	_status.text = words


## The link's pictures: the model from where the view is looking, on a
## plain ground — a PNG small enough to send, for link previews and the
## model's page, and a small WebP of the same for the gallery's cards.
## {png, thumb}, either empty when there is none to be had (a run with
## nothing to draw with).
func _pictures() -> Dictionary:
	var none := {"png": PackedByteArray(), "thumb": PackedByteArray()}
	if picture == null:
		return none
	var shot: Image = await picture.take(CARD)
	if shot == null or shot.is_empty():
		return none
	shot.convert(Image.FORMAT_RGBA8)
	var card := Image.create(CARD.x, CARD.y, false, Image.FORMAT_RGBA8)
	# A soft ground, lighter at the top, so the model reads on any site.
	for y: int in CARD.y:
		var t: float = float(y) / float(CARD.y - 1)
		card.fill_rect(Rect2i(0, y, CARD.x, 1), Color(0.93, 0.94, 0.96).lerp(Color(0.80, 0.83, 0.87), t))
	card.blend_rect(shot, Rect2i(Vector2i.ZERO, shot.get_size()), Vector2i.ZERO)
	card.convert(Image.FORMAT_RGB8)
	var small: Image = card.duplicate()
	small.resize(THUMB.x, THUMB.y, Image.INTERPOLATE_LANCZOS)
	var thumb: PackedByteArray = small.save_webp_to_buffer(true, 0.8)
	if thumb.size() > MOST_THUMB:
		thumb = small.save_webp_to_buffer(true, 0.55)
	var png: PackedByteArray = card.save_png_to_buffer()
	if png.size() > MOST_PNG:
		card.resize(800, 420, Image.INTERPOLATE_LANCZOS)
		png = card.save_png_to_buffer()
	return {"png": png if png.size() <= MOST_PNG else PackedByteArray(),
		"thumb": thumb if thumb.size() <= MOST_THUMB else PackedByteArray()}


## Its controls, for the page to find.
func controls_by_name() -> Dictionary:
	if not visible:
		return {}
	var named_controls: Dictionary = {"share_name": _name, "share_credit": _credit,
		"share_about": _about, "share_tags": _tags, "share_kind": _kind,
		"share_licence": _licence, "share_list": _list, "share_publish": _publish,
		"share_guidelines": _guidelines, "share_done": _done}
	if _author.is_visible_in_tree():
		named_controls["share_author"] = _author
	if _note.is_visible_in_tree():
		named_controls["share_note"] = _note
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
		"url": url, "embed": embed, "status": _status.text if _status != null else "",
		"moves": Array(moves),
		"listed": _list.button_pressed if _list != null else false,
		"remixed_from": store.remixed_from if store != null else "",
		"about": _about.text if _about != null else "",
		"tags": _tags.text if _tags != null else "",
		"kind": _kind_id() if _kind != null else "",
		"licence": _licence_id() if _licence != null else "",
		"note": _note.text if _note != null else "",
		"note_shown": _note.is_visible_in_tree() if _note != null else false,
		"version": version, "said": version_said,
		"tested": tested, "tested_said": tested_said, "tested_passed": Tested.passed(tested),
		"remixed_from_version": store.remixed_from_version if store != null else 0,
		"guidelines": guidelines_url(),
		"list_disabled": _list.disabled if _list != null else false,
		"credit_disabled": _credit.disabled if _credit != null else false,
		"young": _young.visible if _young != null else false}


## Escape closes it, like the other panels.
func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		visible = false
		get_viewport().set_input_as_handled()
