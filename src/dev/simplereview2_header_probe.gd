## simplereview2_header: how wide a desktop window must be for each of the
## studio header's menus to stay on its row, in English, German, French and
## Spanish. Names nothing of Simple's, so it runs in a tree with the header's
## Simple | Full (simple1) and in one without it (pre261 b74893382), and the
## two are held side by side.
##
##   PROBE_SIZE=390x844 tools/probe.sh simplereview2_header_probe -- --pictures=DIR
##
## ModelBar._fit_header shrinks the header to LEAST_PT before it folds a menu,
## the last first, into "…": the first k menus stay while
## ModelBar._fitting_pt(gutter, k) >= LEAST_PT. _fitting_pt is
## (visible width - U_k - 6) / P, U_k the row's units with k menus and P its
## points (gutters, mark, Account, the switch). Read at two visible widths
## (the content scale changed for one frame; Room.across() is the window's
## and unchanged), the two give U_k and P, and so the least window W_k for k
## menus at 100%: U_k + 6 + LEAST_PT * P (the gutters 16 below 600 points,
## 24 above). Prints, for each language, the row now (points, menus shown)
## and each menu's least width; a picture of the header in each.
##
## godot --path . --resolution 390x844 --script src/dev/simplereview2_header_probe.gd
extends SceneTree

const AppHeader := preload("res://src/ui/app_header.gd")

var _main: Node
var _bar: Node
var _pictures: String = "user://sr2header/"
var _size: String = ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			_pictures = arg.get_slice("=", 1).trim_suffix("/") + "/"
	OS.set_environment("BRICKWORKS_API", "http://127.0.0.1:9")
	Phone._on = 0
	Phone._wide = false
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_bar = _main.get("_bar")
	(_main.get("_store") as ModelStore).keeps = false
	var window: Vector2i = DisplayServer.window_get_size()
	_size = "%dx%d" % [window.x, window.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_pictures))
	var buttons: Array = _bar.call("_menu_buttons")
	print("simplereview2_header_probe: a %s window, desktop, %d menus, the switch %s" % [_size, buttons.size(),
		"on the row" if _bar.get("controls") != null else "(none)"])
	var least: float = float(ModelBar.LEAST_PT)
	for lang: String in ["en", "de", "fr", "es"]:
		Language.choose(lang)
		await _frames(20)
		var names := PackedStringArray()
		for button: Variant in buttons:
			names.append((button as Button).atr((button as Button).text))
		var v1: float = root.get_visible_rect().size.x
		var gutter: float = AppHeader.GUTTER_NARROW if Room.across() < 600.0 else AppHeader.GUTTER
		var at1: Array = []
		for k: int in buttons.size() + 1:
			at1.append(float(_bar.call("_fitting_pt", gutter, k)))
		var scale_was: float = root.content_scale_factor
		root.content_scale_factor = scale_was * 0.5
		await _frames(2)
		var v2: float = root.get_visible_rect().size.x
		var at2: Array = []
		for k: int in buttons.size() + 1:
			at2.append(float(_bar.call("_fitting_pt", gutter, k)))
		root.content_scale_factor = scale_was
		await _frames(20)
		var line := PackedStringArray()
		for k: int in range(1, buttons.size() + 1):
			# fits = (V - U - 6) / P at both widths.
			var per_pt: float = (v2 - v1) / (float(at2[k]) - float(at1[k]))
			var units: float = v1 - 6.0 - float(at1[k]) * per_pt
			var narrow: float = units + 6.0 + least * per_pt
			var wide_pt: float = per_pt - 2.0 * AppHeader.GUTTER_NARROW + 2.0 * AppHeader.GUTTER
			var need: float = narrow if narrow < 600.0 else units + 6.0 + least * wide_pt
			line.append("%s %d" % [names[k - 1], ceili(need)])
		print("  %s: now %.2f points, %s of %d menus on the row (%s); the least window for each to stay: %s"
			% [lang, float(_bar.get("points")), _bar.get("menus_shown"), buttons.size(),
			" ".join(names.slice(0, int(_bar.get("menus_shown")))), ", ".join(line)])
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		var tall: int = mini(image.get_height(), 120)
		image.get_region(Rect2i(0, 0, image.get_width(), tall)).save_png(
			ProjectSettings.globalize_path(_pictures) + "%s_header_%s.png" % [_size, lang])
	Language.choose("en")
	print("simplereview2_header_probe: done")
	quit(0)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
