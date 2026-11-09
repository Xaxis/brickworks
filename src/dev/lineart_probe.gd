## Render's Line art and Comic looks (APP_UX7 #22, lineart): the model inked
## as a person would draw it.
##
##   godot --path . --resolution 1400x900 --script src/dev/lineart_probe.gd \
##       [-- --shots=DIR --reference=DIR]
##
## Through the way in first, as a person comes: the sign-in screen up over
## the app (gate_for_probe), a throwaway account signed in (made with the
## admin key and a password, so no code is spent at the per-IP limit), the
## screen gone; the account deleted at the end. Needs .env (SUPABASE_URL,
## SUPABASE_SECRET_KEY).
##
## The bar:
##   - the default render the same to the pixel: File, Render's own choices
##     (Good, as in the window, 1080p, the box's view, white) of the example
##     car as the app opens on it, drawn first and kept as default_render.png,
##     and a Quick and a Product picture of a small scene, each compared byte
##     for byte with --reference's (this probe run on an older build); and
##     the Quick one drawn twice, the same both times;
##   - the Look row: Line art and Comic beside As in the window and Product,
##     each in the dialog and the window, its words whole; each clicked as a
##     person clicks, its words said under the row and the draft drawn in it;
##     Render picture with Comic writes a comic picture;
##   - Line art on a small scene (a wall of three red 1 x 2 bricks, a white
##     2 x 4 alone, a yellow slope, a black 2 x 2): white paper round the
##     model to the pixel; nothing but greys; the outline dark all round; a
##     line on each of the two seams between the wall's bricks; dots on the
##     white brick's face away from the light, several, and none on its lit
##     top;
##   - Comic of the same: the red bricks red and the slope yellow, the seams
##     still inked, dots on the white brick's shaded face;
##   - on nothing (backdrop none): nothing round the model, the model whole,
##     the outline drawn over nothing, the shadow on the floor as dots;
##   - an animation in Line art: a part moved away leaves no line where it was;
##   - over MCP: render_model offers lineart and comic, and draws one;
##   - a real set, an OMR file (10036-1 Pizza To Go), drawn in both looks at
##     1080p: paper round it, an outline, lines inside it, for a person to
##     look at (lineart_set.png, comic_set.png).
extends SceneTree

const SET := "res://vendor/omr/files/10036-1.mpd"
## The engine's own random numbers seeded with this before each picture
## laid beside an older build's, which the engine seeds anew at each start:
## unseeded, two runs of one build drew the default render a level apart
## in 74,251 pixels.
const DRAWN_WITH := 20261109
## A pixel this much darker than white (of 1) is ink.
const INK := 0.5

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _library: PartLibrary
var _render: StudioRender
var _shell: Shell
var _out: String = "user://lineart"
var _reference: String = ""
var _email: String = ""
var _password: String = ""
var _size: String = ""
var _socket: CommandSocket
var _next: int = 0
## The small scene's bricks: name -> its box in the world.
var _boxes: Dictionary = {}
var _wall: Array[AABB] = []


func _initialize() -> void:
	# Never more than this on the card, whatever hangs.
	create_timer(1500.0).timeout.connect(func() -> void:
		print("  FAIL  the probe was still going after 25 minutes")
		quit(1))
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_out = arg.trim_prefix("--shots=")
		elif arg.begins_with("--reference="):
			_reference = arg.trim_prefix("--reference=")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	if DisplayServer.get_name() == "headless":
		print("  no rendering device — this probe needs a window")
		quit(1)
		return
	Account.where = "user://probe_session.json"
	Account._clear()
	await process_frame
	_main = load("res://src/main.tscn").instantiate()
	_main.set("gate_for_probe", true)
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	for _n: int in 30:
		await process_frame
	var playback: Variant = _main.get("_playback")
	if playback != null:
		playback.stop()
	_world = _main.get("_world")
	_library = _main.get("_library")
	_shell = _main.get("_shell")
	var window: Vector2i = root.get_window().size
	_size = "%dx%d" % [window.x, window.y]
	print("in a %s window, %s" % [_size, RenderingServer.get_current_rendering_method()])
	if not await _way_in():
		await _finish()
		return
	(_main.get("_builder") as Builder).hide_preview()
	_render = StudioRender.new()
	_render.library = _library
	_render.scenery = (_main.get("_store") as ModelStore).scenery
	_render.eye = _main.get("_camera")
	_render.look = (_main.get_node("WorldEnvironment") as WorldEnvironment).environment
	for light_name: String in ["Sun", "Fill", "Rim"]:
		_render.rig_lights.append(_main.get_node(light_name) as DirectionalLight3D)
	root.add_child(_render)

	await _default_render()
	await _look_row()
	_scene()
	await _frames(4)
	await _same_scene_as_before()
	await _line_art()
	await _comic()
	await _on_nothing()
	await _animated()
	await _over_mcp()
	await _real_set()
	await _finish()


# -- the way in ---------------------------------------------------------------


func _way_in() -> bool:
	var account: Account = _main.get("_account")
	var gate: Control = _main.get("_gate")
	for _n: int in 900:
		if account.state != Account.State.CHECKING:
			break
		await process_frame
	_check("the sign-in screen is over the app as it opens", gate != null and gate.visible)
	_email = SignInHelper.throwaway("lineart")
	var problem: String = await _sign_in(account, _email)
	for _n: int in 120:
		if gate == null or not gate.visible:
			break
		await process_frame
	_check("signed in as a throwaway account, and the screen goes: %s" % (problem
		if not problem.is_empty() else _email), problem.is_empty() and account.signed_in()
		and gate != null and not gate.visible)
	return account.signed_in()


func _sign_in(account: Account, email: String) -> String:
	_password = "Probe-%d-%d-Aa1" % [randi(), Time.get_ticks_usec()]
	var made: Dictionary = await SignInHelper.admin(root, HTTPClient.METHOD_POST,
		"/auth/v1/admin/users", JSON.stringify({"email": email, "password": _password,
			"email_confirm": true}))
	if int(made.get("code", 0)) != 200:
		return "the account was not made: %d" % int(made.get("code", 0))
	var reply: Dictionary = await account._fetch(account._url + "/auth/v1/token?grant_type=password",
		PackedStringArray(["content-type: application/json", "apikey: " + account._key]),
		HTTPClient.METHOD_POST, JSON.stringify({"email": email, "password": _password}))
	if int(reply.get("code", 0)) != 200 or not reply.get("body") is Dictionary:
		return "no session: %d" % int(reply.get("code", 0))
	account._keep(reply["body"])
	account.state = Account.State.SIGNED_IN
	account.changed.emit()
	return ""


func _finish() -> void:
	if not _email.is_empty():
		var gone: int = await SignInHelper.delete_accounts(_email, root)
		print("    (removed %d throwaway account(s))" % gone)
	print("")
	print("%d failed" % _failures if _failures else "Line art and Comic draw as a person inks")
	quit(1 if _failures else 0)


# -- the default render, the same to the pixel ----------------------------------


## File, Render's own choices of the example car, the first picture drawn
## in the run: a Good render's light gathers over frames and keeps some of
## what it gathered for the next (a third render of the car came out a
## level darker than the first, all over), so only the first is the same
## from one run to the next. Kept, and laid against an older build's.
func _default_render() -> void:
	print("\n  the default render, as File, Render… draws it of the example car")
	_check("the example car is on the baseplate (%d parts)" % _world.brick_count(),
		_world.brick_count() > 20)
	seed(DRAWN_WITH)
	_keep_and_compare(await _render.render(_world, RenderSettings.new()), "default_render")


func _keep_and_compare(image: Image, name: String) -> void:
	if image == null:
		_check("%s drew a picture" % name, false)
		return
	var path: String = ProjectSettings.globalize_path(_out.path_join(name + ".png"))
	image.save_png(path)
	print("    picture: %s (%s)" % [path, _sha(image)])
	if _reference.is_empty():
		print("    (no --reference: nothing to lay it beside)")
		return
	var kept: String = _reference.path_join(name + ".png")
	var older: Image = Image.load_from_file(kept) if FileAccess.file_exists(kept) else null
	if older != null and older.get_format() != image.get_format():
		older.convert(image.get_format())
	_check("%s the same as the older build's to the pixel (%s; %d px differ)" % [name,
		_sha(older) if older != null else "none kept", _differing(image, older)],
		older != null and _differing(image, older) == 0)


static func _sha(image: Image) -> String:
	if image == null:
		return "-"
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(image.get_data())
	return hashing.finish().hex_encode().left(16)


static func _differing(a: Image, b: Image) -> int:
	if a == null or b == null or a.get_size() != b.get_size():
		return -1
	var da: PackedByteArray = a.get_data()
	var db: PackedByteArray = b.get_data()
	if da == db:
		return 0
	var channels: int = da.size() / (a.get_width() * a.get_height())
	var count: int = 0
	for at: int in range(0, mini(da.size(), db.size()), channels):
		for c: int in channels:
			if da[at + c] != db[at + c]:
				count += 1
				break
	return count


# -- the Look row ----------------------------------------------------------------


func _look_row() -> void:
	print("\n  Render's Look row, as a person uses it")
	var dialog: RenderDialog = _main.get("_render")
	var files: String = ProjectSettings.globalize_path(_out.path_join("files"))
	DirAccess.make_dir_recursive_absolute(files)
	dialog.folder = files
	_shell.run("render")
	await _drafted(dialog)
	_check("File, Render… opens", dialog.visible)
	var controls: Dictionary = dialog.controls_by_name()
	var window := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var looks: Array = []
	for key: String in ["window", "product", "lineart", "comic"]:
		var button: Button = controls.get("render_look_" + key)
		looks.append(button)
		if button == null:
			_check("the Look row has %s" % key, false)
			continue
		var rect: Rect2 = button.get_global_rect()
		var whole: bool = button.get_minimum_size().x <= button.size.x + 0.5
		_check("Look, %s: in the window at %s (%s), its words whole" % [button.text, _size,
			str(rect)], button.is_visible_in_tree() and window.encloses(rect) and whole)
	if looks.has(null):
		dialog.close()
		await _frames(4)
		return
	var column: Control = dialog.get("_choices")
	var right_edge: float = 0.0
	for button: Button in looks:
		right_edge = maxf(right_edge, button.get_global_rect().end.x)
	_check("the inked looks on a row of their own under the photographed ones, all in the column (%.0f of %.0f px)"
		% [right_edge, column.get_global_rect().end.x],
		(looks[2] as Button).get_parent() == (looks[3] as Button).get_parent()
		and (looks[2] as Button).get_parent() != (looks[0] as Button).get_parent()
		and (looks[2] as Button).get_global_rect().position.y > (looks[0] as Button).get_global_rect().end.y
		and right_edge <= column.get_global_rect().end.x + 0.5)
	var note: Label = dialog.get("_look_note")
	for pick: Array in [[looks[2], "lineart", "Black lines"], [looks[3], "comic", "Bold lines"]]:
		var button: Button = pick[0]
		var shown: Texture2D = (dialog.get("_preview") as TextureRect).texture
		await _click(button.get_global_rect().get_center())
		await _drafted(dialog, shown)
		var draft: Image = _draft(dialog)
		var greys: float = _share_grey(draft) if draft != null else 0.0
		_check("%s clicked: the look is %s, the note says \"%s…\" (%s)" % [button.text,
			dialog.settings.look, str(pick[2]), note.text.left(48)],
			dialog.settings.look == str(pick[1]) and note.text.begins_with(str(pick[2])))
		if pick[1] == "lineart":
			_check("and the draft is drawn in it: %.1f%% of its pixels grey" % (greys * 100.0),
				greys > 0.995)
		else:
			_check("and the draft is drawn in it: %.1f%% grey, its parts in colour" % (greys * 100.0),
				greys < 0.98)
		if draft != null:
			draft.save_png(ProjectSettings.globalize_path(_out.path_join("draft_%s_%s.png"
				% [pick[1], _size])))
	await _snap("dialog_comic_" + _size)
	(controls["render_quick"] as Button).pressed.emit()
	(controls["render_size_custom"] as Button).pressed.emit()
	(dialog.get("_width") as SpinBox).value = 640
	(dialog.get("_height") as SpinBox).value = 360
	(controls["render_picture"] as Button).pressed.emit()
	await _until_done(dialog)
	var picture: String = files.path_join(RenderOutput.file_name(str(dialog.named.call()), "_render", "png"))
	var kept := Image.load_from_file(picture) if FileAccess.file_exists(picture) else null
	_check("Render picture, in Comic, wrote %s at 640x360, in colour with black lines (%.1f%% ink)"
		% [picture.get_file(), _share_ink(kept) * 100.0 if kept != null else 0.0],
		kept != null and kept.get_size() == Vector2i(640, 360) and _share_grey(kept) < 0.98
		and _share_ink(kept) > 0.01)
	# As it was for whoever renders next.
	(looks[0] as Button).pressed.emit()
	dialog.close()
	await _frames(4)


func _drafted(dialog: RenderDialog, before: Texture2D = null) -> void:
	for _n: int in 900:
		await process_frame
		var shown: Texture2D = (dialog.get("_preview") as TextureRect).texture
		if shown != null and shown != before and str(dialog.get("_working")) == "":
			break
	await _frames(4)


func _draft(dialog: RenderDialog) -> Image:
	var shown: Image = dialog.get("_shown")
	if shown != null:
		return shown
	var texture: Texture2D = (dialog.get("_preview") as TextureRect).texture
	return texture.get_image() if texture != null else null


func _until_done(dialog: RenderDialog) -> void:
	await _frames(3)
	var until: int = Time.get_ticks_msec() + 300000
	while dialog.is_rendering() and Time.get_ticks_msec() < until:
		await process_frame
	await _frames(3)


# -- the small scene -------------------------------------------------------------


func _scene() -> void:
	_world.clear()
	_boxes.clear()
	_wall.clear()
	# A wall of three red 1 x 2 bricks side by side, long side across.
	var turn: Basis = _long_across("3004")
	var size: Vector3 = (turn * _library.mesh_for("3004").bounds.size).abs()
	for n: int in 3:
		var at := Vector3(-120.0 + size.x * float(n), 24.0, -10.0)
		_add("wall%d" % n, "3004", 4, Transform3D(turn, at))
		_wall.append(_boxes["wall%d" % n])
	# A white 2 x 4 alone, for its shading, a tile over its studs so its top
	# is one face; a yellow slope; a black 2 x 2.
	_add("white", "3001", 15, Transform3D(Basis.IDENTITY, Vector3(70, 24, 0)))
	var tile: String = "87079" if _library.parts.has("87079") else "3068b"
	if tile == "87079":
		_add("tile", tile, 15, Transform3D(Basis.IDENTITY, Vector3(70, 32, 0)))
	else:
		for n: int in 2:
			_add("tile%d" % n, tile, 15, Transform3D(Basis.IDENTITY, Vector3(60 + 20 * n, 32, 0)))
	_add("slope", "3039", 14, Transform3D(Basis.IDENTITY, Vector3(-30, 24, 60)))
	_add("black", "3003", 0, Transform3D(Basis.IDENTITY, Vector3(-10, 24, -70)))


func _long_across(part: String) -> Basis:
	var box: AABB = _library.mesh_for(part).bounds
	return Basis.IDENTITY if box.size.x >= box.size.z else Basis(Vector3.UP, PI * 0.5)


func _add(name: String, part: String, colour: int, at: Transform3D) -> void:
	var id: int = _world.add_brick(part, colour, at)
	var brick: BrickWorld.Brick = _world.get_brick(id)
	_boxes[name] = brick.transform * _library.mesh_for(part).bounds


func _settings(look: String, view: String = "hero") -> RenderSettings:
	var settings := RenderSettings.new()
	settings.quality = RenderSettings.Quality.QUICK
	settings.size = Vector2i(1280, 720)
	settings.view = view
	settings.look = look
	settings.contact_shadow = false
	return settings


## The scene's own window-look and product pictures, for an older build's.
func _same_scene_as_before() -> void:
	print("\n  the small scene as the window and Product draw it, for an older build's")
	seed(DRAWN_WITH)
	var first: Image = await _render.render(_world, _settings("window"))
	seed(DRAWN_WITH)
	var again: Image = await _render.render(_world, _settings("window"))
	_check("drawn twice, the same picture to the pixel (%d px differ)" % _differing(first, again),
		first != null and again != null and _differing(first, again) == 0)
	_keep_and_compare(first, "scene_window")
	_keep_and_compare(await _render.render(_world, _settings("product")), "scene_product")


## Which pixels are the model: the window's look of the shot on nothing.
func _mask(view: String) -> Image:
	var bare: RenderSettings = _settings("window", view)
	bare.transparent = true
	return await _render.render(_world, bare)


func _line_art() -> void:
	print("\n  Line art of the small scene, on white")
	var mask: Image = await _mask("hero")
	var lit: Image = await _render.render(_world, _settings("window"))
	var drawn: Image = await _render.render(_world, _settings("lineart"))
	if drawn == null or mask == null:
		_check("Line art draws a picture", false)
		return
	drawn.save_png(ProjectSettings.globalize_path(_out.path_join("lineart_scene.png")))
	_keep_what_it_was_made_of()
	var shot: StudioRender.Shot = _render.last_shot
	_check("white paper round the model, to the pixel: %.2f%%" % (_paper(drawn, mask, Color.WHITE) * 100.0),
		_paper(drawn, mask, Color.WHITE) > 0.999)
	_check("nothing but greys: %.2f%% of its pixels" % (_share_grey(drawn) * 100.0),
		_share_grey(drawn) > 0.999)
	_check("the outline dark all round: %.1f%% of the model's edge" % (_outlined(drawn, mask) * 100.0),
		_outlined(drawn, mask) > 0.95)
	var inside: float = _share_white_inside(drawn, mask)
	_check("inside the lines, mostly paper: %.1f%% white" % (inside * 100.0), inside > 0.5)
	await _shading(drawn, lit, shot, false)
	var front: Image = await _render.render(_world, _settings("lineart", "front"))
	front.save_png(ProjectSettings.globalize_path(_out.path_join("lineart_front.png")))
	_seams(front, _render.last_shot, "Line art")


## The four pictures the last line picture was made of, to look at: the
## set's lit and flat, the parts' numbers and their faces' directions.
func _keep_what_it_was_made_of() -> void:
	# Not typed: an older build has no LineArt, and the probe runs there too.
	var line: Object = _render.get("_line")
	var made_of: Dictionary = {"lit": _render.get("_out"), "flat": _render.get("_base")}
	if line != null:
		made_of["codes"] = line.get("codes_view")
		made_of["normals"] = line.get("normals_view")
		made_of["clay"] = line.get("light_view")
	for name: String in made_of:
		var view: SubViewport = made_of[name]
		var image: Image = view.get_texture().get_image() if view != null else null
		if image != null:
			image.save_png(ProjectSettings.globalize_path(_out.path_join("made_of_%s.png" % name)))


## The white brick's faces: the two sides the camera sees, the one the
## window's light leaves darker taken as the shaded one, and its top.
func _shading(drawn: Image, lit: Image, shot: StudioRender.Shot, comic: bool) -> void:
	var box: AABB = _boxes["white"]
	var picture: Vector2i = drawn.get_size()
	var cover: AABB = _boxes.get("tile", _boxes.get("tile0", box))
	var top: Vector2 = _project(shot, Vector3(box.get_center().x, cover.end.y, box.get_center().z),
		picture)
	var side_x: Vector2 = _project(shot, Vector3(box.position.x, box.get_center().y - 2.0,
		box.get_center().z), picture)
	var side_z: Vector2 = _project(shot, Vector3(box.get_center().x, box.get_center().y - 2.0,
		box.end.z), picture)
	var shade: Vector2 = side_x if _mean_light(lit, side_x) < _mean_light(lit, side_z) else side_z
	var lit_side: Vector2 = side_z if shade == side_x else side_x
	var cell: int = maxi(4, roundi(float(mini(picture.x, picture.y)) / 150.0))
	var reach: int = cell * 2
	var top_cover: float = _cover(drawn, top, reach, comic)
	var shade_cover: float = _cover(drawn, shade, reach, comic)
	var dots: int = _blobs(drawn, shade, reach, comic)
	print("    the white brick: top %.3f, the lit side %.3f, the shaded side %.3f covered, %d dots there"
		% [top_cover, _cover(drawn, lit_side, reach, comic), shade_cover, dots])
	_check("%s: dots on the white brick's face away from the light (%.0f%% of it, %d dots), none on its lit top (%.1f%%)"
		% ["Comic" if comic else "Line art", shade_cover * 100.0, dots, top_cover * 100.0],
		shade_cover > 0.06 and dots >= 3 and top_cover < 0.03)


## The wall's two seams, square on: a line along each.
func _seams(drawn: Image, shot: StudioRender.Shot, look: String) -> void:
	var picture: Vector2i = drawn.get_size()
	var lined: int = 0
	var rows: int = 0
	for n: int in 2:
		var seam_x: float = _wall[n].end.x
		var z: float = _wall[n].end.z
		var low: float = _wall[n].position.y
		var high: float = _wall[n].position.y + 24.0
		var a: Vector2 = _project(shot, Vector3(seam_x, lerpf(low, high, 0.25), z), picture)
		var b: Vector2 = _project(shot, Vector3(seam_x, lerpf(low, high, 0.75), z), picture)
		for y: int in range(mini(int(a.y), int(b.y)), maxi(int(a.y), int(b.y)) + 1):
			rows += 1
			var x: float = lerpf(a.x, b.x, inverse_lerp(a.y, b.y, float(y)) if a.y != b.y else 0.0)
			for dx: int in range(-3, 4):
				var px := Vector2i(int(x) + dx, y)
				if Rect2i(Vector2i.ZERO, picture).has_point(px) and _ink(drawn.get_pixelv(px)):
					lined += 1
					break
	var share: float = float(lined) / float(maxi(rows, 1))
	_check("%s: a line on each seam between the wall's red bricks, %d of %d rows" % [look, lined, rows],
		rows > 10 and share > 0.9)


func _comic() -> void:
	print("\n  Comic of the small scene, on white")
	var mask: Image = await _mask("hero")
	var lit: Image = await _render.render(_world, _settings("window"))
	var drawn: Image = await _render.render(_world, _settings("comic"))
	if drawn == null:
		_check("Comic draws a picture", false)
		return
	drawn.save_png(ProjectSettings.globalize_path(_out.path_join("comic_scene.png")))
	var shot: StudioRender.Shot = _render.last_shot
	_check("white paper round the model, to the pixel: %.2f%%" % (_paper(drawn, mask, Color.WHITE) * 100.0),
		_paper(drawn, mask, Color.WHITE) > 0.999)
	_check("the outline dark all round: %.1f%% of the model's edge" % (_outlined(drawn, mask) * 100.0),
		_outlined(drawn, mask) > 0.95)
	var red: Color = _mean(drawn, _project(shot, _wall[1].get_center(), drawn.get_size()), 3)
	var slope: AABB = _boxes["slope"]
	var yellow: Color = _mean(drawn, _project(shot, slope.get_center() + Vector3(0, 2, 0),
		drawn.get_size()), 2)
	_check("the wall's bricks red (%s) and the slope yellow (%s)" % [red.to_html(false),
		yellow.to_html(false)], red.r > 0.45 and red.g < 0.25 and red.b < 0.25
		and yellow.r > 0.6 and yellow.g > 0.45 and yellow.b < 0.3)
	await _shading(drawn, lit, shot, true)
	var front: Image = await _render.render(_world, _settings("comic", "front"))
	front.save_png(ProjectSettings.globalize_path(_out.path_join("comic_front.png")))
	_seams(front, _render.last_shot, "Comic")


func _on_nothing() -> void:
	print("\n  Line art on nothing (backdrop none)")
	var mask: Image = await _mask("hero")
	var settings: RenderSettings = _settings("lineart")
	settings.transparent = true
	var drawn: Image = await _render.render(_world, settings)
	if drawn == null or not drawn.detect_alpha():
		_check("a picture with alpha", false)
		return
	drawn.save_png(ProjectSettings.globalize_path(_out.path_join("lineart_clear.png")))
	var away: int = 0
	var clear: int = 0
	var inside: int = 0
	var whole: int = 0
	var ring: int = 0
	var ringed: int = 0
	for y: int in drawn.get_height():
		for x: int in drawn.get_width():
			var near: int = _near_model(mask, x, y, 5)
			var alpha: float = drawn.get_pixel(x, y).a
			if near == 0:
				away += 1
				clear += int(alpha == 0.0)
			elif near == 2:
				inside += 1
				whole += int(alpha >= 0.999)
			elif mask.get_pixel(x, y).a < 0.5 and _near_model(mask, x, y, 1) == 1:
				ring += 1
				ringed += int(alpha > 0.3)
	_check("nothing round the model: %d of %d pixels clear" % [clear, away], clear == away and away > 1000)
	_check("the model whole: %d of %d pixels solid" % [whole, inside],
		float(whole) >= float(inside) * 0.999 and inside > 1000)
	_check("its outline drawn over nothing: %d of %d pixels just outside" % [ringed, ring],
		float(ringed) > float(ring) * 0.95)
	settings.contact_shadow = true
	var shadowed: Image = await _render.render(_world, settings)
	shadowed.save_png(ProjectSettings.globalize_path(_out.path_join("lineart_clear_shadow.png")))
	var dots: int = _alpha_dots(shadowed, mask)
	_check("the shadow on the floor in dots: %d of them" % dots, dots >= 10)


## An animation's frame with a part moved away: no line where it was.
func _animated() -> void:
	print("\n  an animation in Line art")
	var white: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == "3001":
			white = brick.id
	var home: Transform3D = _world.get_brick(white).transform
	var frames: Array[Image] = []
	var shots: Array = []
	var settings: RenderSettings = _settings("lineart")
	settings.size = Vector2i(640, 360)
	var drawn: int = await _render.animate(_world, settings, 2,
		func(n: int) -> Dictionary:
			return {white: home if n == 0 else Transform3D(Basis.IDENTITY, home.origin + Vector3(0, 4000, 0))},
		func(_n: int) -> float: return 0.0, AABB(),
		func(_n: int, image: Image) -> void:
			frames.append(image)
			shots.append(_render.last_shot))
	if drawn != 2 or frames.size() != 2:
		_check("two frames drawn (%d)" % drawn, false)
		return
	frames[1].save_png(ProjectSettings.globalize_path(_out.path_join("lineart_moved.png")))
	# Its front face's foot, under the tile on it, which stays.
	var box: AABB = _boxes["white"]
	var at: Vector2 = _project(shots[0], Vector3(box.get_center().x, box.position.y + 5.0, box.end.z),
		frames[0].get_size())
	var before: float = _cover(frames[0], at, 10, false)
	var after: float = _cover(frames[1], at, 10, false)
	_check("the white brick inked where it stands (%.0f%%), and gone, no line left there (%.1f%%)"
		% [before * 100.0, after * 100.0], before > 0.02 and after < 0.005)


# -- over MCP ------------------------------------------------------------------


func _over_mcp() -> void:
	print("\n  over MCP, as a session asks")
	_socket = CommandSocket.new()
	_socket.assistant = _main.get("_assistant")
	_socket.app = _main
	_main.add_child(_socket)
	await _frames(2)
	var listed: Dictionary = await _rpc("tools/list", {})
	var offered: Array = []
	for tool: Dictionary in listed.get("tools", []):
		if str(tool.get("name", "")) == "render_model":
			offered = ((tool["inputSchema"] as Dictionary)["properties"] as Dictionary)["look"]["enum"]
	_check("render_model offers the looks %s" % str(offered),
		offered.has("lineart") and offered.has("comic"))
	var result: Dictionary = await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "picture", "quality": "quick", "size": "720p", "look": "lineart"}}))
	var text: String = _text(result)
	var written: String = ""
	var found: RegExMatch = RegEx.create_from_string("(/[^ ]+\\.png)").search(text)
	if found != null:
		written = found.get_string(1)
	var kept := Image.load_from_file(written) if FileAccess.file_exists(written) else null
	_check("look lineart draws it inked: %s (%.2f%% grey)" % [text.left(90),
		_share_grey(kept) * 100.0 if kept != null else 0.0],
		kept != null and _share_grey(kept) > 0.999 and _share_ink(kept) > 0.005)
	var refused: String = _text(await _finished(await _rpc("tools/call", {"name": "render_model",
		"arguments": {"kind": "picture", "look": "pencil"}})))
	_check("a look there is not is answered with those there are: %s" % refused.left(80),
		refused.contains("lineart") and refused.contains("comic"))


func _rpc(method: String, params: Dictionary) -> Dictionary:
	_next += 1
	var answer: Variant = await _socket.answer_rpc({"jsonrpc": "2.0", "id": _next,
		"method": method, "params": params})
	return (answer as Dictionary).get("result", {}) as Dictionary


static func _text(result: Dictionary) -> String:
	var text: String = ""
	for block: Dictionary in result.get("content", []):
		text += str(block.get("text", ""))
	return text


func _finished(result: Dictionary) -> Dictionary:
	var found: RegExMatch = RegEx.create_from_string("^Started job (\\d+)").search(_text(result))
	if found == null:
		return result
	var id: int = int(found.get_string(1))
	for _n: int in 240:
		var polled: Dictionary = await _rpc("tools/call", {"name": "job", "arguments": {"id": id}})
		if _text(polled).contains(" is still going"):
			await _frames(30)
			continue
		return polled
	return {"content": [{"type": "text", "text": "job %d never ended" % id}]}


# -- a real set ----------------------------------------------------------------


func _real_set() -> void:
	print("\n  a real set: %s" % SET.get_file())
	if not await _open(SET):
		_check("%s opens" % SET.get_file(), false)
		return
	print("    %d parts" % _world.brick_count())
	for look: String in ["lineart", "comic"]:
		var settings: RenderSettings = _settings(look)
		settings.size = Vector2i(1920, 1080)
		settings.contact_shadow = true
		var drawn: Image = await _render.render(_world, settings)
		if drawn == null:
			_check("%s draws the set" % look, false)
			continue
		var path: String = ProjectSettings.globalize_path(_out.path_join("%s_set.png" % look))
		drawn.save_png(path)
		print("    picture: %s" % path)
		var bare: RenderSettings = _settings("window")
		bare.size = settings.size
		bare.transparent = true
		var mask: Image = await _render.render(_world, bare)
		var ink: float = _share_ink_inside(drawn, mask)
		_check("%s of the set: an outline (%.1f%%), lines inside it (%.1f%% of the model inked)"
			% [look, _outlined(drawn, mask) * 100.0, ink * 100.0],
			_outlined(drawn, mask) > 0.9 and ink > 0.04 and ink < 0.5)
	var turned: RenderSettings = _settings("lineart", "front")
	turned.size = Vector2i(1920, 1080)
	var front: Image = await _render.render(_world, turned)
	if front != null:
		front.save_png(ProjectSettings.globalize_path(_out.path_join("lineart_set_front.png")))


func _open(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	_main.call("clear_model")
	await _frames(3)
	_main.call("_open", ProjectSettings.globalize_path(path))
	var store: ModelStore = _main.get("_store")
	for _n: int in 600:
		await process_frame
		if store.awaited.is_empty() and _world.brick_count() > 0:
			break
	await _frames(10)
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null and playback.is_playing():
		playback.stop()
	await _frames(5)
	return _world.brick_count() > 0


# -- measuring pictures -------------------------------------------------------


## Where [param point] (the world's) is in a picture [param picture] across
## drawn from [param shot].
static func _project(shot: StudioRender.Shot, point: Vector3, picture: Vector2i) -> Vector2:
	var local: Vector3 = shot.basis.inverse() * (point - shot.origin)
	var scale: float = float(picture.y) / (2.0 * tan(deg_to_rad(shot.fov) * 0.5))
	return Vector2(float(picture.x) * 0.5 + local.x / -local.z * scale,
		float(picture.y) * 0.5 - local.y / -local.z * scale)


static func _light(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


static func _ink(c: Color) -> bool:
	return _light(c) < INK and maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) < 0.12


static func _share_grey(image: Image) -> float:
	if image == null:
		return 0.0
	var grey: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			var c: Color = image.get_pixel(x, y)
			grey += int(maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) <= 6.0 / 255.0)
	return float(grey) / float(image.get_width() * image.get_height())


static func _share_ink(image: Image) -> float:
	if image == null:
		return 0.0
	var inked: int = 0
	for y: int in image.get_height():
		for x: int in image.get_width():
			inked += int(_ink(image.get_pixel(x, y)))
	return float(inked) / float(image.get_width() * image.get_height())


## 0 when no pixel of the model is within [param reach] of (x, y), 2 when
## every one is, 1 between.
static func _near_model(mask: Image, x: int, y: int, reach: int) -> int:
	var seen: int = 0
	var all: int = 0
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var px := Vector2i(clampi(x + dx, 0, mask.get_width() - 1),
				clampi(y + dy, 0, mask.get_height() - 1))
			all += 1
			seen += int(mask.get_pixelv(px).a > 0.5)
	return 0 if seen == 0 else (2 if seen == all else 1)


## Of the pixels more than 6 from the model, the share exactly [param paper].
static func _paper(image: Image, mask: Image, paper: Color) -> float:
	var away: int = 0
	var same: int = 0
	var wanted: Color = Color(paper.r8 / 255.0, paper.g8 / 255.0, paper.b8 / 255.0)
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			if _near_model(mask, x, y, 6) == 0:
				away += 1
				var c: Color = image.get_pixel(x, y)
				same += int(c.r8 == wanted.r8 and c.g8 == wanted.g8 and c.b8 == wanted.b8)
	return float(same) / float(maxi(away, 1))


## Of the model's edge pixels, the share with ink within a pixel.
static func _outlined(image: Image, mask: Image) -> float:
	var edge: int = 0
	var inked: int = 0
	for y: int in range(1, image.get_height() - 1):
		for x: int in range(1, image.get_width() - 1):
			if mask.get_pixel(x, y).a <= 0.5 or _near_model(mask, x, y, 1) != 1:
				continue
			edge += 1
			var dark: bool = false
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if _light(image.get_pixel(x + dx, y + dy)) < INK:
						dark = true
			inked += int(dark)
	return float(inked) / float(maxi(edge, 1))


## Inside the model, three pixels in from its edge: the share white.
static func _share_white_inside(image: Image, mask: Image) -> float:
	var inside: int = 0
	var white: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			if _near_model(mask, x, y, 3) == 2:
				inside += 1
				white += int(_light(image.get_pixel(x, y)) > 0.9)
	return float(white) / float(maxi(inside, 1))


static func _share_ink_inside(image: Image, mask: Image) -> float:
	var inside: int = 0
	var inked: int = 0
	for y: int in range(0, image.get_height(), 2):
		for x: int in range(0, image.get_width(), 2):
			if _near_model(mask, x, y, 3) == 2:
				inside += 1
				inked += int(_light(image.get_pixel(x, y)) < INK)
	return float(inked) / float(maxi(inside, 1))


static func _mean(image: Image, at: Vector2, reach: int) -> Color:
	var sum := Color(0, 0, 0, 0)
	var count: int = 0
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var px := Vector2i(int(at.x) + dx, int(at.y) + dy)
			if Rect2i(Vector2i.ZERO, image.get_size()).has_point(px):
				sum += image.get_pixelv(px)
				count += 1
	return sum / float(maxi(count, 1))


static func _mean_light(image: Image, at: Vector2) -> float:
	return _light(_mean(image, at, 4))


## How much of a square [param reach] either side of [param at] is darker
## than its own face: for Line art, than white; for Comic, than the
## lightest of it.
static func _cover(image: Image, at: Vector2, reach: int, comic: bool) -> float:
	var face: float = 1.0
	if comic:
		face = 0.0
		for dy: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				face = maxf(face, _light(image.get_pixelv(_inside(image, at, dx, dy))))
	var dark: float = 0.0
	var count: int = 0
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			var c: float = _light(image.get_pixelv(_inside(image, at, dx, dy)))
			dark += clampf((face - c) / maxf(face, 0.05), 0.0, 1.0)
			count += 1
	return dark / float(count)


static func _inside(image: Image, at: Vector2, dx: int, dy: int) -> Vector2i:
	return Vector2i(clampi(int(at.x) + dx, 0, image.get_width() - 1),
		clampi(int(at.y) + dy, 0, image.get_height() - 1))


## The separate dark spots in that square: dots, not one shadow.
static func _blobs(image: Image, at: Vector2, reach: int, comic: bool) -> int:
	var face: float = 1.0
	if comic:
		face = 0.0
		for dy: int in range(-reach, reach + 1):
			for dx: int in range(-reach, reach + 1):
				face = maxf(face, _light(image.get_pixelv(_inside(image, at, dx, dy))))
	var side: int = reach * 2 + 1
	var dark := PackedByteArray()
	dark.resize(side * side)
	for dy: int in range(-reach, reach + 1):
		for dx: int in range(-reach, reach + 1):
			dark[(dy + reach) * side + dx + reach] = int(
				_light(image.get_pixelv(_inside(image, at, dx, dy))) < face * 0.75)
	return _components(dark, side, side)


static func _components(dark: PackedByteArray, width: int, height: int) -> int:
	var seen := PackedByteArray()
	seen.resize(dark.size())
	var count: int = 0
	for start: int in dark.size():
		if dark[start] == 0 or seen[start] == 1:
			continue
		count += 1
		var stack: Array[int] = [start]
		seen[start] = 1
		while not stack.is_empty():
			var at: int = stack.pop_back()
			var x: int = at % width
			var y: int = at / width
			for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + step.x
				var ny: int = y + step.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height:
					continue
				var next: int = ny * width + nx
				if dark[next] == 1 and seen[next] == 0:
					seen[next] = 1
					stack.append(next)
	return count


## Spots of ink on nothing more than 4 pixels from the model: the floor's
## shadow drawn in dots.
static func _alpha_dots(image: Image, mask: Image) -> int:
	var width: int = image.get_width()
	var height: int = image.get_height()
	var dark := PackedByteArray()
	dark.resize(width * height)
	for y: int in height:
		for x: int in width:
			if image.get_pixel(x, y).a > 0.5 and _near_model(mask, x, y, 4) == 0:
				dark[y * width + x] = 1
	return _components(dark, width, height)


# -- the window ------------------------------------------------------------------


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path(_out.path_join(name + ".png")))


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _click(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = _as_event(at)
	move.global_position = move.position
	move.relative = Vector2(1, 0)
	Input.parse_input_event(move)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(3)
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
