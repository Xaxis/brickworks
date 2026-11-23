## The fixes from ux12's walks that can be judged without a window: the
## storage warning that waits for the account, the red of what cannot be
## undone, the Library's words at the start of a set's, and Instructions
## found under Export.
##
##   godot --headless --path . --script src/dev/ux12_words_probe.gd
##
## The rest (the phone row's words, the names in menus and the status bar,
## the Library's placeholder) are judged in the app itself by
## src/dev/ux12_walk_probe.gd, which prints a "UX12 check" line for each.
extends SceneTree


var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	print("\n  The storage warning, while the account is asked and once it is not reached")
	# Answered, not kept: at risk, whatever the account says.
	StorageKeep.pretend({"account": "looking", "answered": true})
	_check("at risk while the account is asked", StorageKeep.at_risk())
	_check("...but no warning while it is asked (\"%s\")" % StorageKeep.warning().left(60),
		StorageKeep.warning().is_empty())
	StorageKeep.pretend({"account": "away", "answered": true})
	var away: String = StorageKeep.warning()
	_check("the account not reached once asked: warned (\"%s\")" % away.left(60),
		away.contains("has not been reached yet"))
	StorageKeep.pretend({"account": "out", "answered": true})
	_check("signed out: warned as before", not StorageKeep.warning().is_empty())
	StorageKeep.pretend({"account": "kept", "answered": true})
	_check("kept with the account: no warning", StorageKeep.warning().is_empty())
	StorageKeep.pretend({})

	print("\n  What cannot be undone, in red")
	Look.buttons()
	var theme: Theme = ThemeDB.get_default_theme()
	_check("a DangerButton look beside DefaultButton",
		theme.is_type_variation(&"DangerButton", &"Button"))
	for state: String in ["normal", "hover", "pressed"]:
		var face := theme.get_stylebox(state, &"DangerButton") as StyleBoxFlat
		var fill: Color = face.bg_color if face != null else Color.BLACK
		var words: Color = theme.get_color("font_color", &"DangerButton")
		_check("%s: red (%s)" % [state, fill.to_html(false)],
			face != null and fill.r > 0.6 and fill.g < 0.3 and fill.b < 0.3)
		_check("%s: white words %.2f:1 on it (4.5)" % [state, _ratio(words, fill)],
			_ratio(words, fill) >= 4.5)
		_check("%s: it %.2f:1 on a dialog's face (3)" % [state, _ratio(fill, Look.FACE)],
			_ratio(fill, Look.FACE) >= 3.0)
	var button := Button.new()
	Look.danger(button)
	_check("Look.danger marks a button", button.theme_type_variation == &"DangerButton")
	button.free()

	print("\n  The Library's words begin words of a set's")
	var every: Array = []
	for one: Array in [["a", "Scarecrow", "40352-1", "BrickHeadz"], ["b", "Vintage Car", "40448-1", "Icons"],
			["c", "Airport Cargo Plane", "60101-1", "City"], ["d", "The SHIELD Helicarrier", "76042-1",
			"Super Heroes"], ["e", "King's Castle", "6080-1", "Castle"], ["f", "Race Cars", "8125-1", "Racers"]]:
		every.append({"id": one[0], "name": one[1], "set": one[2], "theme": one[3], "author": "someone",
			"year": 2000, "parts": 100})
	for asked: Array in [["car", ["b", "c", "f"]], ["6080", ["e"]], ["castle 6080", ["e"]],
			["CAR", ["b", "c", "f"]], ["king's", ["e"]], ["crow", []], ["080", []]]:
		var found: Dictionary = ModelLibrary.search(every, {"q": asked[0], "sort": "name"})
		var ids: Array = (found["models"] as Array).map(func(entry: Dictionary) -> String:
			return str(entry["id"]))
		ids.sort()
		_check("\"%s\" finds %s (%s)" % [asked[0], str(asked[1]), str(ids)], ids == asked[1])

	print("\n  Instructions under Export, beside the other files a model is written as")
	var export: Array = Shell.SUBMENUS.get("export", [])
	_check("File, Export lists Instructions (%s)" % ", ".join(export), export.has("instructions"))

	print("")
	print("ux12_words: %s" % ("all checks passed" if _failures == 0 else "%d check(s) FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## WCAG's contrast ratio between two colours.
static func _ratio(a: Color, b: Color) -> float:
	var la: float = _luminance(a)
	var lb: float = _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var out: float = 0.0
	var weights: Array[float] = [0.2126, 0.7152, 0.0722]
	var channels: Array[float] = [c.r, c.g, c.b]
	for n: int in 3:
		var v: float = channels[n]
		v = v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
		out += weights[n] * v
	return out
