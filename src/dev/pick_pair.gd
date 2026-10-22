## The app's pick between two designs of one brief, asked once (DesignPick).
##
##   godot --headless --path . --script src/dev/pick_pair.gd -- \
##     --brief="..." --a=DIR_A/views --b=DIR_B/views
##
## A and B are the prefixes of each design's corner, front and close
## pictures (PREFIX_corner.png and so on, as src/dev/bench_views.gd writes
## them). Prints the session's arguments checked, then one line
## `pick {json}`: keep, what each reads as, why, seconds, model, usage.
## Spends one ask of the subscription. tools/bench/pick_pairs.py runs it
## over pairs, both orders.
extends SceneTree


func _initialize() -> void:
	var args: PackedStringArray = DesignPick.arguments()
	var ok: bool = args.has("--tools") and args[args.find("--tools") + 1].is_empty() \
		and args.has("--restricted") and args.has("--strict-mcp-config") \
		and not " ".join(args).contains("dangerously")
	print("  %s    no tools, none of the person's servers or settings" % ("ok" if ok else "FAIL"))
	if not ok:
		quit(1)
		return
	var sides: Array = []
	for key: String in ["--a", "--b"]:
		var views: Array = []
		for view: String in DesignPick.VIEWS:
			var block: Dictionary = DesignPick.picture("%s_%s.png" % [_arg(key), view])
			if block.is_empty():
				print("no picture %s_%s.png" % [_arg(key), view])
				quit(2)
				return
			views.append(block)
		sides.append(views)
	var answer: Dictionary = DesignPick.new().ask(_arg("--brief"), sides[0], sides[1])
	print("pick " + JSON.stringify(answer))
	quit(0 if answer.has("keep") else 1)


func _arg(prefix: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(prefix + "="):
			return a.substr(prefix.length() + 1)
	return ""
