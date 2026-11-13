## Where a patch of someone else's file puts the app's own lines (keeptext5):
## one the file has stays where the file has it in its step, one new goes
## where its writer puts it.
##
##   godot --headless --path . --script src/dev/app_lines_probe.gd
##
## Since pre261 a VIEW is written under the main model's title, where up to
## then it went under its 0 FILE, and a step's look is written at the
## step's end: a file of an older build, or one with a look put at a step's
## top by hand, came back from a save with nothing changed with those lines
## moved (kt4review's studio_meta, the merge of pre261 into keeptext5). Each
## check is SourceFile.app_lines_placed given a file and a text as the
## writers write it:
## 1. the VIEW under 0 FILE and the look at its step's top as the file has
##    them, a new FLOOR line where its writer put it;
## 2. a look whose neighbour went to another step never leaves its step;
## 3. a CRLF file with two lines in a row and no line end at the end: the
##    file byte for byte;
## 4. 50,000 of the file's own lines in a row, put after the part: back
##    where the file has them, in under 5 s.
extends SceneTree

var _fails: int = 0


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_fails += 1


func _source(text: String) -> SourceFile:
	var model: LdrModel = LdrModel.parse(text)
	return SourceFile.make(text, model, model.flatten(), {}, true)


func _initialize() -> void:
	var view := '0 !BRICKWORKS VIEW {"name":"front","yaw":0.5}'
	var file := "\n".join(["0 FILE main.ldr", view, "0 Title", "0 Name: main.ldr",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"0 !BRICKWORKS PAGE NEW", "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP", "0 NOFILE", ""])
	var src: SourceFile = _source(file)
	# As pre261's writers put them: the VIEW under the title, the look at its step's end.
	var put := "\n".join(["0 FILE main.ldr", "0 Title", view, "0 Name: main.ldr",
		"0 !BRICKWORKS FLOOR GRID",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 !BRICKWORKS PAGE NEW", "0 STEP",
		"0 NOFILE", ""])
	var got: String = src.app_lines_placed(put)
	var want := "\n".join(["0 FILE main.ldr", view, "0 Title", "0 Name: main.ldr",
		"0 !BRICKWORKS FLOOR GRID",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"0 !BRICKWORKS PAGE NEW", "1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat",
		"1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP", "0 NOFILE", ""])
	_check("the VIEW under 0 FILE and the look at its step's top, as the file has them; "
		+ "the new FLOOR where its writer put it", got == want)
	if got != want:
		print(got)
	# The look's neighbour moved to another step: it stays in its step.
	var put2 := "\n".join(["0 FILE main.ldr", "0 Title", view, "0 Name: main.ldr",
		"1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP",
		"1 1 0 -48 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 !BRICKWORKS PAGE NEW", "0 STEP",
		"1 4 0 -24 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 STEP", "0 NOFILE", ""])
	var got2: String = src.app_lines_placed(put2)
	var lines2: PackedStringArray = got2.split("\n")
	var page: int = lines2.find("0 !BRICKWORKS PAGE NEW")
	_check("a look never leaves the step its writer put it in (line %d, between the first and second STEP)"
		% page, page > lines2.find("0 STEP") and page < lines2.rfind("0 STEP") - 1
		and lines2.count("0 !BRICKWORKS PAGE NEW") == 1)
	# CRLF, with no line end at the end, and lines in a row.
	var crlf := "0 FILE main.ldr\r\n0 !BRICKWORKS VIEW {\"name\":\"a\"}\r\n0 !BRICKWORKS VIEW {\"name\":\"b\"}\r\n0 Title\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 NOFILE"
	var src3: SourceFile = _source(crlf)
	var put3 := "0 FILE main.ldr\r\n0 Title\r\n0 !BRICKWORKS VIEW {\"name\":\"a\"}\r\n0 !BRICKWORKS VIEW {\"name\":\"b\"}\r\n1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\r\n0 NOFILE"
	var got3: String = src3.app_lines_placed(put3)
	_check("CRLF, two in a row, no last line end: the file byte for byte", got3 == crlf)
	if got3 != crlf:
		print(got3.c_escape())
	# Thousands of the file's own lines in a row, each once: in order, quickly.
	var many := PackedStringArray(["0 FILE main.ldr", "0 Title"])
	for n: int in 50000:
		many.append("0 !BRICKWORKS FOO %d" % n)
	many.append_array(PackedStringArray(["1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat", "0 NOFILE", ""]))
	var text4: String = "\n".join(many)
	var src4: SourceFile = _source(text4)
	var moved := PackedStringArray(["0 FILE main.ldr", "0 Title", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat"])
	for n: int in 50000:
		moved.append("0 !BRICKWORKS FOO %d" % n)
	moved.append_array(PackedStringArray(["0 NOFILE", ""]))
	var started: int = Time.get_ticks_msec()
	var got4: String = src4.app_lines_placed("\n".join(moved))
	var took: int = Time.get_ticks_msec() - started
	_check("50,000 of the file's own lines put after the part: back where the file has them, in %d ms"
		% took, got4 == text4 and took < 5000)
	print("app_lines probe: %s" % ("all checks passed" if _fails == 0 else "%d failed" % _fails))
	quit(1 if _fails > 0 else 0)
