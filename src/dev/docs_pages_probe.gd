## Does Help, Documentation open the docs page of the panel in front?
##
##   godot --headless --path . --script src/dev/docs_pages_probe.gd
##
## The docs name the app's panels in their heads (`panels:` in docs-site/),
## and tools/docs_site.py --write makes DocsPages from them; Shell.docs_page
## reads it against what the window has open. With nothing open it is the
## docs' start: a panel always on screen named there would send every Help
## to its page. Opened, a panel's page; two open, the one drawn over the
## other. And the words a session is told first are the docs' (ConnectorGuide).
extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var main: Node = load("res://src/main.tscn").instantiate()
	root.add_child(main)
	for _n: int in 60:
		await process_frame
	var shell: Shell = main.get("_shell")

	print("\nHelp, Documentation")
	_check(shell.docs_page() == "/docs", "nothing open: the docs' start (%s)" % shell.docs_page())

	var controls: ControlsDialog = main.get("_controls")
	controls.open()
	await process_frame
	_check(shell.docs_page() == "/docs/panels-and-settings#settings",
		"Settings open: its page (%s)" % shell.docs_page())

	var brickify: Control = main.get("_brickify")
	brickify.visible = true
	await process_frame
	_check(shell.docs_page() == "/docs/art-and-brickify#brickify",
		"Brickify over Settings: Brickify's page (%s)" % shell.docs_page())

	brickify.visible = false
	controls.visible = false
	await process_frame
	_check(shell.docs_page() == "/docs", "both closed: the start again (%s)" % shell.docs_page())

	print("\nevery panel the docs name is one of the app's")
	var classes: Dictionary = {}
	for one: Dictionary in ProjectSettings.get_global_class_list():
		classes[str(one["class"])] = true
	for name: String in DocsPages.PANELS:
		_check(classes.has(name), "%s is a class (%s)" % [name, DocsPages.PANELS[name]])

	print("\nthe words a session is told are the docs'")
	_check(Assistant.GUIDE_HEAD == ConnectorGuide.HEAD and Assistant.METHOD == ConnectorGuide.METHOD
		and ClaudeConnector.CONNECTED_NOTE == ConnectorGuide.CONNECTED + "\n\n",
		"the head, the method and the connector's note are ConnectorGuide's")
	_check(main.get("_assistant").guidance().begins_with(ConnectorGuide.HEAD + "\n\n"),
		"the instructions begin with the head")

	print("\n%s" % ("docs pages: all passed" if _failures == 0 else "docs pages: %d FAILED" % _failures))
	quit(1 if _failures else 0)


func _check(ok: bool, what: String) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
