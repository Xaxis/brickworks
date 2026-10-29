## The app's menus as the documentation lists them: every menu, submenu and
## command in order, with its words, its key and its tooltip, written to
## docs-site/generated/menus.json for tools/docs_site.py (brickworks.diy/docs,
## Menus and commands).
##
##   godot --headless --path . --script src/dev/docs_menus.gd -- --menus-to=docs-site/generated/menus.json
##
## Read off the real window (Shell, its commands made as the app makes
## them, the assistant's shown), not off shell.gd's text: most of the View,
## Tools and Booklet rows are made in loops. tests/test_docs_site.py fails
## when shell.gd's menus no longer match the file, naming this command.
extends SceneTree


func _initialize() -> void:
	_run()


func _run() -> void:
	var out: String = "docs-site/generated/menus.json"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--menus-to="):
			out = arg.substr(11)
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 30:
		await process_frame
	var shell: Shell = main.get("_shell")
	if shell == null:
		print("docs_menus FAIL: no shell")
		quit(1)
		return
	shell.set_assistant(true)
	var commands: Dictionary = shell.get("_commands")
	# A submenu's own words are the window's: read off its popups.
	var titles: Dictionary = {}
	for button: Variant in shell.get("_menus"):
		_titles((button as MenuButton).get_popup(), titles)
	var menus: Array = []
	for menu: Array in Shell.MENUS:
		menus.append({"title": menu[0], "items": _items(menu[1], commands, titles)})
	var context: Array = _items(Shell.ON_A_PART, commands, titles)
	var text: String = JSON.stringify({"menus": menus, "on_a_part": context}, "\t", false) + "\n"
	var file := FileAccess.open(out if out.begins_with("/") else ProjectSettings.globalize_path("res://").path_join(out), FileAccess.WRITE)
	if file == null:
		print("docs_menus FAIL: could not write %s" % out)
		quit(1)
		return
	file.store_string(text)
	file.close()
	print("docs_menus: %d menus, %d commands in %s" % [menus.size(), commands.size(), out])
	quit(0)


func _titles(popup: PopupMenu, into: Dictionary) -> void:
	for i: int in popup.item_count:
		var sub: PopupMenu = popup.get_item_submenu_node(i)
		if sub != null:
			into[String(sub.name)] = popup.get_item_text(i)
			_titles(sub, into)


func _items(names: Array, commands: Dictionary, titles: Dictionary) -> Array:
	var out: Array = []
	for item: String in names:
		if item == "-":
			out.append({"line": true})
		elif item.begins_with(">"):
			var kind: String = item.substr(1)
			var row: Dictionary = {"submenu": kind, "words": titles.get(kind, kind.capitalize())}
			if Shell.SUBMENUS.has(kind):
				row["items"] = _items(Shell.SUBMENUS[kind], commands, titles)
			else:
				# Filled as it opens (Open recent, History): what is in it is the person's.
				row["items"] = []
			out.append(row)
		else:
			var command: Shell.Command = commands.get(item)
			if command == null:
				out.append({"name": item, "words": item})
				continue
			out.append({"name": item, "words": command.words, "key": Shell.key_text(command.accel),
				"tip": command.tip})
	return out
