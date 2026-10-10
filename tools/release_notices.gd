## The engine's licence and every third-party component's, written out
## for the THIRD-PARTY-NOTICES.txt each desktop release carries.
##
##   godot --headless --path . --script res://tools/release_notices.gd -- OUT
##
## Godot's licence asks for its notice in anything distributed with it,
## and the engine carries a few dozen components under their own terms.
## Read from the running engine rather than copied by hand, so the list
## is the one for the version that exported the build. tools/release.py
## runs it; nothing else does.
extends SceneTree


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		printerr("release_notices: say where to write")
		quit(2)
		return
	var lines: PackedStringArray = []
	lines.append("Brickworks is built with the Godot Engine %s. Its licence and the"
		% Engine.get_version_info().get("string", ""))
	lines.append("notices of the components it is made from follow.")
	lines.append("")
	lines.append("Part geometry and catalogue data have their own terms, in")
	lines.append("ATTRIBUTION.md beside this file.")
	lines.append("")
	lines.append("== Godot Engine ==")
	lines.append("")
	lines.append(Engine.get_license_text())
	lines.append("")
	lines.append("== Components ==")
	for component: Dictionary in Engine.get_copyright_info():
		lines.append("")
		lines.append(str(component.get("name", "")))
		for part: Dictionary in component.get("parts", []):
			for holder: String in part.get("copyright", PackedStringArray()):
				lines.append("  Copyright %s" % holder)
			lines.append("  License: %s" % str(part.get("license", "")))
	lines.append("")
	lines.append("== Licence texts ==")
	var texts: Dictionary = Engine.get_license_info()
	var names: Array = texts.keys()
	names.sort()
	for license_name: Variant in names:
		lines.append("")
		lines.append("--- %s ---" % str(license_name))
		lines.append("")
		lines.append(str(texts[license_name]))
	var file: FileAccess = FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		printerr("release_notices: cannot write %s" % args[0])
		quit(1)
		return
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("notices %s, %d components" % [args[0], Engine.get_copyright_info().size()])
	quit(0)
