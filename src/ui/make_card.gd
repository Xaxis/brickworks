## Show your build (makes, 2026-11-23): the end of Build it, where a photo
## of the real build is posted on the model it was built from.
##
## Printables keeps 9,830 makes on its Benchy and Rebrickable keeps fan
## photos of people's builds, each posted from a web page some time after.
## Brickworks knows the moment a build ends, on the builder's phone beside
## its camera: the step player's last step (BuildMode) and the viewer's
## timeline stepped onto its end (ShareView) show this card. It says how
## many have built the model and offers Show your build. One press opens the
## camera on a phone (a file elsewhere, PickImage); the photo comes back on
## the card with a line to say something about it (optional) and Post. Main
## sends it through the build photos' own path (api/_builds.js: an upload URL
## signed for it, then ?op=photo), which keeps a new JPEG made of the pixels
## alone and its copy at most 480 px wide for the cards, and the designer
## hears of it (the photo notification). The card then says "Posted: on the
## model's page", a link to it.
##
## The model's own designer is offered "Add a photo of your build": theirs
## leads the model's pictures, and is no make of somebody else's model.
##
## The photo is read off the main thread (WorkerTasks): a phone's is 12
## megapixels, a third of a second to decode in a browser, where a frame of
## the step player is 16 ms. What is sent is the file as it was chosen when
## the server takes that (a JPEG, a PNG or a WebP of 8 MB or less: the
## server takes its metadata out and stands it upright as the phone held
## it), and otherwise a JPEG made here at the server's own 1,600 px. The card
## shows it upright either way, its Exif orientation applied, which Godot's
## decoder does not read.
##
## With nobody signed in, Post asks for the sign-in in place (Main), and the
## card keeps the photo and the words meanwhile: back, it is as it was, ready
## to Post. This only shows and says what was pressed; Main sends.
class_name MakeCard
extends PanelContainer

## Post pressed with a photo read: Main sends [member photo].
signal post_wanted
## The model's page, where the photo is: [param url].
signal page_wanted(url: String)

## What api/_photo.js takes as it was sent, and the long side it keeps.
const MOST_BYTES := 8 * 1024 * 1024
const LONG_SIDE := 1600
const LEAST_SIDE := 120
## What a builder may say about it (api/_builds.js MAX_WORDS).
const MOST_WORDS := 140
## Points: the photo on the card, and the least a target is either way.
const THUMB := 72.0
const TARGET := 44.0
const CAMERA := "res://assets/ui/tools/photo.svg"
const NOT_A_PHOTO := "That is not a JPEG, a PNG or a WebP photo."

## The link the card is for; a photo chosen for one link is never sent to another.
var link: String = ""
## How many have built it (api/share.js ?op=built), -1 not known.
var builds: int = -1
## The model is the signed-in account's own.
var own: bool = false
## How many more photos the account may add to it, -1 not known.
var left: int = -1
## offer, reading, chosen, sending or posted.
var state: String = "offer"
## The model's page at the photo, once posted.
var posted_url: String = ""
## The photo to send, its type, and a JPEG of it at most 1,600 px on its
## long side for keeping while the page goes elsewhere (Main's stash).
var photo: PackedByteArray = PackedByteArray()
var photo_type: String = ""
var small: PackedByteArray = PackedByteArray()
## The photo's size, as it stands upright.
var photo_size: Vector2i = Vector2i.ZERO
## How long the last photo took to read on its worker, in ms; and the
## card's presses, for a check to count.
var read_ms: int = -1
var presses: int = 0

var _pt: float = 1.0
var _picker: PickImage
var _offer: HBoxContainer
var _count: Label
var _show: Button
var _chosen: HBoxContainer
var _thumb: TextureRect
var _words: LineEdit
var _post: Button
var _drop: Button
var _said: Label
var _posted: LinkButton
## Which read is the latest: an older one's photo, read after, is dropped.
var _reads: int = 0


func _ready() -> void:
	name = "MakeCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.name = "Column"
	add_child(column)
	_offer = HBoxContainer.new()
	_offer.name = "Offer"
	column.add_child(_offer)
	_count = Label.new()
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_offer.add_child(_count)
	_show = _button("Show your build", "A photo of the model you built, posted on its page")
	_show.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Straight from the press: a browser opens its picker only while a real
	# click is still being handled (PickImage).
	_show.pressed.connect(func() -> void:
		presses += 1
		ask_photo())
	_offer.add_child(_show)
	_chosen = HBoxContainer.new()
	_chosen.name = "Chosen"
	_chosen.visible = false
	column.add_child(_chosen)
	_thumb = TextureRect.new()
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_chosen.add_child(_thumb)
	var side := VBoxContainer.new()
	side.name = "Side"
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chosen.add_child(side)
	_words = LineEdit.new()
	_words.placeholder_text = "Say something about it (optional)"
	_words.accessibility_name = "What you say about your build"
	# Enter posts, once: no focus_exited send beside it (self_attack.md).
	_words.text_submitted.connect(func(_text: String) -> void: _press_post())
	side.add_child(_words)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	side.add_child(buttons)
	_drop = _button("Another photo", "Choose another photo instead")
	_drop.pressed.connect(func() -> void:
		presses += 1
		ask_photo())
	buttons.add_child(_drop)
	_post = _button("Post", "Post the photo on the model's page")
	_post.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_post.pressed.connect(_press_post)
	buttons.add_child(_post)
	_said = Label.new()
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_said.visible = false
	column.add_child(_said)
	_posted = Look.link("Posted: on the model's page", 16)
	_posted.tooltip_text = "The model's page, where your photo is"
	_posted.visible = false
	_posted.pressed.connect(func() -> void:
		presses += 1
		page_wanted.emit(posted_url))
	column.add_child(_posted)
	_picker = PickImage.new()
	_picker.undecoded = true
	_picker.chosen.connect(take)
	_picker.failed.connect(func(why: String) -> void:
		if why != "no picture chosen":
			say(why))
	add_child(_picker)
	_lay()


func _button(words: String, tip: String) -> Button:
	var button := Button.new()
	button.text = words
	button.tooltip_text = tip
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return button


## Sized in points, as the step player's bars are; the viewer's own units on
## a wide window (1.0).
func fit(pt: float) -> void:
	_pt = pt
	var dark := StyleBoxFlat.new()
	dark.bg_color = Color(0.13, 0.15, 0.19, 0.96)
	dark.border_color = Color(1.0, 0.80, 0.18, 0.9)
	dark.set_border_width_all(maxi(1, roundi(2.0 * pt)))
	dark.set_corner_radius_all(roundi(10.0 * pt))
	dark.set_content_margin_all(10.0 * pt)
	add_theme_stylebox_override("panel", dark)
	(get_node("Column") as VBoxContainer).add_theme_constant_override("separation", roundi(8.0 * pt))
	for row: BoxContainer in [_offer, _chosen, get_node("Column/Chosen/Side") as BoxContainer,
			get_node("Column/Chosen/Side/Buttons") as BoxContainer]:
		row.add_theme_constant_override("separation", roundi(8.0 * pt))
	_count.add_theme_font_size_override("font_size", roundi(16.0 * pt))
	_said.add_theme_font_size_override("font_size", roundi(15.0 * pt))
	_posted.add_theme_font_size_override("font_size", roundi(16.0 * pt))
	_posted.custom_minimum_size = Vector2(0.0, TARGET * pt)
	_thumb.custom_minimum_size = Vector2.ONE * THUMB * pt
	_words.add_theme_font_size_override("font_size", roundi(16.0 * pt))
	_words.custom_minimum_size = Vector2(0.0, TARGET * pt)
	for button: Button in [_show, _drop, _post]:
		_face(button, button == _post or button == _show)
		button.add_theme_font_size_override("font_size", roundi(16.0 * pt))
		button.custom_minimum_size = Vector2(TARGET * pt, TARGET * pt)
	_show.icon = Icons.texture_for(CAMERA, 20.0 * pt, Icons.density(self))
	_show.add_theme_constant_override("h_separation", roundi(8.0 * pt))


## The step player's own faces (BuildMode._face): its bright red for the act,
## the pale glass for the rest.
func _face(button: Button, bright: bool) -> void:
	for look: String in ["normal", "hover", "pressed", "disabled"]:
		var face := StyleBoxFlat.new()
		if bright:
			face.bg_color = {"normal": Color(0.78, 0.06, 0.18), "hover": Color(0.88, 0.14, 0.26),
				"pressed": Color(0.66, 0.04, 0.14), "disabled": Color(0.35, 0.12, 0.16)}[look]
		else:
			face.bg_color = Color(1, 1, 1, {"normal": 0.12, "hover": 0.2, "pressed": 0.28,
				"disabled": 0.04}[look])
			face.border_color = Color(1, 1, 1, 0.2)
			face.set_border_width_all(maxi(1, roundi(_pt)))
		face.set_corner_radius_all(roundi(10.0 * _pt))
		face.content_margin_left = 14.0 * _pt
		face.content_margin_right = 14.0 * _pt
		button.add_theme_stylebox_override(look, face)
	button.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.3))


## How many have built it, as the card says it.
static func count_words(count: int) -> String:
	if count > 1:
		return String(TranslationServer.translate("%d people have built it")) % count
	if count == 1:
		return String(TranslationServer.translate("1 person has built it"))
	return String(TranslationServer.translate("You built it"))


## What the card says before a photo: how many have built it, and whether
## this account may add one; [param count] -1 when not known.
func offer(count: int) -> void:
	builds = count
	_lay()


## Whose it is, once the account is known: the designer's own (Add a photo
## of your build), and how many photos it may still add (-1 not known).
func know(is_own: bool, may_add: int) -> void:
	own = is_own
	left = may_add
	_lay()


## Ask for the photo: the camera on a touch screen, a file elsewhere.
func ask_photo() -> void:
	_picker.camera = DisplayServer.is_touchscreen_available()
	_picker.ask()


## A photo's bytes, as chosen (PickImage), read on a worker: then the card
## shows it with the words and Post. Not a picture, and it says so in words
## and keeps any photo it had.
func take(bytes: PackedByteArray, _hint: String = "") -> void:
	_reads += 1
	var mine: int = _reads
	var before: String = state
	state = "reading"
	say("Reading the photo…", true)
	_lay()
	var began: int = Time.get_ticks_msec()
	var given: PackedByteArray = bytes
	var read: Dictionary = await WorkerTasks.awaited(func() -> Variant: return MakeCard.read(given),
		"read a build's photo")
	if mine != _reads or not is_inside_tree():
		return
	read_ms = Time.get_ticks_msec() - began
	if read.has("error"):
		state = before if before in ["chosen", "posted"] else "offer"
		say(tr(str(read["error"])) % read["args"] if read.has("args") else str(read["error"]))
		_lay()
		return
	photo = read["send"]
	photo_type = read["type"]
	small = read["small"]
	photo_size = read["size"]
	_thumb.texture = ImageTexture.create_from_image(read["thumb"])
	state = "chosen"
	say("")
	_lay()


## Main is sending it: [param words] say how far it has got.
func sending(words: String) -> void:
	state = "sending"
	say(words, true)
	_lay()


## It did not go: why, in words; the photo and the words kept to try again.
## [param page], where it may be all the same (a reply lost after it was
## kept), is offered to look at before sending it again.
func refused(why: String, page: String = "") -> void:
	state = "chosen" if not photo.is_empty() else "offer"
	say(why)
	posted_url = page
	_lay()
	_posted.text = "Look on the model's page first"
	_posted.visible = not page.is_empty()


## Posted, at [param url]: said, with the way to it. Nothing of the photo
## is kept here after.
func posted(url: String) -> void:
	state = "posted"
	posted_url = url
	photo = PackedByteArray()
	small = PackedByteArray()
	_words.text = ""
	say("")
	_lay()


## The photo dropped, and the card back to its offer.
func clear() -> void:
	_reads += 1
	state = "offer" if state != "posted" else state
	photo = PackedByteArray()
	small = PackedByteArray()
	photo_type = ""
	_words.text = ""
	say("")
	_lay()


## What [param other] holds, taken on here: the step player's card handing
## over to the viewer's as Build it closes at the end, and back.
func adopt(other: MakeCard) -> void:
	if other == null or other == self:
		return
	_reads += 1
	link = other.link
	builds = other.builds
	own = other.own
	left = other.left
	photo = other.photo
	photo_type = other.photo_type
	small = other.small
	photo_size = other.photo_size
	posted_url = other.posted_url
	_thumb.texture = other._thumb.texture
	_words.text = other._words.text
	state = other.state if other.state in ["offer", "chosen", "posted"] else (
		"chosen" if not photo.is_empty() else "offer")
	say("")
	_lay()


## What the builder typed, one line, its spaces made plain.
func words() -> String:
	return plain(_words.text)


## [param text] with every run of spaces, Unicode's own included, made one
## space, the invisible ones that are no space (zero-width, a word joiner, a
## byte-order mark) taken out, and none at either end. The joiner inside an
## emoji (U+200D) stays: it is part of the picture.
static func plain(text: String) -> String:
	var seen: String = RegEx.create_from_string("[\\x{200B}\\x{2060}\\x{FEFF}]").sub(text, "", true)
	var spaced: String = RegEx.create_from_string("[\\s\\x{00A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}"
		+ "\\x{2029}\\x{202F}\\x{205F}\\x{3000}]+").sub(seen, " ", true)
	return spaced.strip_edges()


## The words put back, as kept while the page went elsewhere.
func set_words(text: String) -> void:
	_words.text = text


## [param text] said under the card, in this language (the server's own
## words too, where the app has them), as a sentence.
func say(text: String, quiet: bool = false) -> void:
	var shown: String = tr(text.strip_edges()) if not text.strip_edges().is_empty() else ""
	if not shown.is_empty():
		shown = shown.substr(0, 1).to_upper() + shown.substr(1)
		if not shown.ends_with(".") and not shown.ends_with("…") and not shown.ends_with("?") \
				and not shown.ends_with("!") and not shown.ends_with(":"):
			shown += "."
	_said.text = shown
	_said.visible = not shown.is_empty()
	_said.modulate = Color(1, 1, 1, 0.8) if quiet else Color(1.0, 0.72, 0.45)


func _press_post() -> void:
	if state != "chosen" or photo.is_empty():
		return
	presses += 1
	var typed: String = words()
	# Refused in words, never cut short (self_attack.md): the server keeps
	# at most this many.
	if typed.length() > MOST_WORDS:
		say(tr("At most %d characters about it, please: that is %d") % [MOST_WORDS, typed.length()])
		return
	post_wanted.emit()


func _lay() -> void:
	if _offer == null:
		return
	_count.text = count_words(builds)
	var full: bool = left == 0 and state != "posted"
	_show.text = "Add a photo of your build" if own else "Show your build"
	_show.tooltip_text = "A photo of your build of it, among its pictures" if own \
		else "A photo of the model you built, posted on its page"
	_show.visible = state in ["offer", "reading"] and not full
	_show.disabled = state == "reading"
	_chosen.visible = state in ["chosen", "sending"]
	_post.disabled = state == "sending"
	_drop.disabled = state == "sending"
	_words.editable = state == "chosen"
	_posted.text = "Posted: on the model's page"
	_posted.visible = state == "posted"
	if full and _said.text.is_empty():
		say("You have added three photos: the most", true)
	reset_size()


## The card's controls, for a check to press as a finger does.
func controls_by_name() -> Dictionary:
	if not is_visible_in_tree():
		return {}
	var named: Dictionary = {"make_card": self}
	if _show.visible:
		named["make_show"] = _show
	if _chosen.visible:
		named["make_words"] = _words
		named["make_post"] = _post
		named["make_another"] = _drop
	if _posted.visible:
		named["make_page"] = _posted
	return named


## What the card says, for a check to read.
func card_state() -> Dictionary:
	return {"shown": is_visible_in_tree(), "state": state, "count": _count.text,
		"offer": _show.text if _show.visible else "", "said": _said.text if _said.visible else "",
		"posted": _posted.text if _posted.visible else "", "url": posted_url, "words": _words.text,
		"photo": photo.size(), "type": photo_type, "size": [photo_size.x, photo_size.y],
		"thumb": [_thumb.texture.get_width(), _thumb.texture.get_height()] if _thumb.texture != null else [],
		"read_ms": read_ms, "presses": presses, "own": own, "left": left, "builds": builds, "link": link}


# -- reading the photo (on a worker: touches nothing but its bytes) ---------------


## What [param bytes] are, by their first bytes: jpeg, png, webp, bmp, or ""
## for none of them (a HEIC, a PDF, words).
static func kind_of(bytes: PackedByteArray) -> String:
	if bytes.size() >= 3 and bytes[0] == 0xFF and bytes[1] == 0xD8 and bytes[2] == 0xFF:
		return "jpeg"
	if bytes.size() >= 8 and bytes.slice(0, 8) == PackedByteArray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A,
			0x1A, 0x0A]):
		return "png"
	if bytes.size() >= 12 and bytes.slice(0, 4).get_string_from_ascii() == "RIFF" \
			and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	if bytes.size() >= 2 and bytes[0] == 0x42 and bytes[1] == 0x4D:
		return "bmp"
	return ""


## The photo in [param bytes], read: {send, type, small, thumb, size}, or
## {error} in words. Pure, and safe on a worker.
static func read(bytes: PackedByteArray) -> Dictionary:
	var kind: String = kind_of(bytes)
	if kind.is_empty():
		return {"error": NOT_A_PHOTO}
	var image := Image.new()
	var error: int = ERR_FILE_UNRECOGNIZED
	match kind:
		"jpeg": error = image.load_jpg_from_buffer(bytes)
		"png": error = image.load_png_from_buffer(bytes)
		"webp": error = image.load_webp_from_buffer(bytes)
		"bmp": error = image.load_bmp_from_buffer(bytes)
	if error != OK or image.is_empty():
		return {"error": NOT_A_PHOTO}
	if image.get_width() < LEAST_SIDE or image.get_height() < LEAST_SIDE:
		# Put in its words on the main thread, in the builder's language.
		return {"error": "That photo is %d × %d: too small to show a build",
			"args": [image.get_width(), image.get_height()]}
	if kind == "jpeg":
		upright(image, orientation_of(bytes))
	flatten(image)
	var size := Vector2i(image.get_width(), image.get_height())
	var longest: int = maxi(size.x, size.y)
	if longest > LONG_SIDE:
		var scale: float = float(LONG_SIDE) / longest
		image.resize(maxi(1, roundi(size.x * scale)), maxi(1, roundi(size.y * scale)),
			Image.INTERPOLATE_CUBIC)
	var jpeg: PackedByteArray = image.save_jpg_to_buffer(0.9)
	var thumb: Image = image.duplicate()
	var reach: float = 240.0 / maxi(thumb.get_width(), thumb.get_height())
	if reach < 1.0:
		thumb.resize(maxi(1, roundi(thumb.get_width() * reach)), maxi(1, roundi(thumb.get_height() * reach)),
			Image.INTERPOLATE_BILINEAR)
	var as_sent: bool = kind != "bmp" and bytes.size() <= MOST_BYTES
	return {"send": bytes if as_sent else jpeg, "type": ("image/" + kind) if as_sent else "image/jpeg",
		"small": jpeg, "thumb": thumb, "size": size}


## Which way up the phone was held (Exif's Orientation, 1 to 8), as
## api/_photo.js orientationOf reads it; 1 for none.
static func orientation_of(bytes: PackedByteArray) -> int:
	var at: int = 2
	while at + 4 <= bytes.size():
		if bytes[at] != 0xFF:
			return 1
		var marker: int = bytes[at + 1]
		# The picture's own data starts: nothing more to read before it.
		if marker == 0xDA or marker == 0xD9:
			return 1
		var length: int = (bytes[at + 2] << 8) | bytes[at + 3]
		if length < 2:
			return 1
		if marker == 0xE1 and at + 10 <= bytes.size() \
				and bytes.slice(at + 4, at + 10) == PackedByteArray([0x45, 0x78, 0x69, 0x66, 0, 0]):
			return _tiff_orientation(bytes.slice(at + 10, mini(at + 2 + length, bytes.size())))
		at += 2 + length
	return 1


static func _tiff_orientation(tiff: PackedByteArray) -> int:
	if tiff.size() < 8:
		return 1
	var order: String = tiff.slice(0, 2).get_string_from_ascii()
	if order != "II" and order != "MM":
		return 1
	var little: bool = order == "II"
	var u16 := func(at: int) -> int:
		if at < 0 or at + 2 > tiff.size():
			return -1
		return (tiff[at] | (tiff[at + 1] << 8)) if little else ((tiff[at] << 8) | tiff[at + 1])
	var u32 := func(at: int) -> int:
		if at < 0 or at + 4 > tiff.size():
			return -1
		return (tiff[at] | (tiff[at + 1] << 8) | (tiff[at + 2] << 16) | (tiff[at + 3] << 24)) if little \
			else ((tiff[at] << 24) | (tiff[at + 1] << 16) | (tiff[at + 2] << 8) | tiff[at + 3])
	var ifd: int = u32.call(4)
	var entries: int = u16.call(ifd)
	if ifd < 8 or entries < 0 or entries > 500:
		return 1
	for n: int in entries:
		var entry: int = ifd + 2 + n * 12
		if u16.call(entry) == 0x0112:
			var value: int = u16.call(entry + 8)
			return value if value >= 1 and value <= 8 else 1
	return 1


## [param image] turned and flipped as Exif's [param orientation] says it was
## held (api/_photo.js upright), in place.
static func upright(image: Image, orientation: int) -> void:
	match orientation:
		2:
			image.flip_x()
		3:
			image.rotate_180()
		4:
			image.flip_y()
		5:
			image.rotate_90(CLOCKWISE)
			image.flip_x()
		6:
			image.rotate_90(CLOCKWISE)
		7:
			image.rotate_90(CLOCKWISE)
			image.flip_y()
		8:
			image.rotate_90(COUNTERCLOCKWISE)


## The clear parts of [param image] on white, as the server puts them, in
## RGB; in place.
static func flatten(image: Image) -> void:
	if image.detect_alpha() != Image.ALPHA_NONE:
		image.convert(Image.FORMAT_RGBA8)
		var white := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
		white.fill(Color.WHITE)
		white.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
		image.copy_from(white)
	if image.get_format() != Image.FORMAT_RGB8:
		image.convert(Image.FORMAT_RGB8)
