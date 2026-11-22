## The booklet as web pages to read on a screen (Instructions, Save as web
## page), as StudWorx and LeoCAD save theirs: one long page, every step
## after the one before, or a page a step with Previous, Contents and
## Next, all in one zip; either in light or in dark.
##
## The booklet itself is pages to print, each laid out on paper, and a
## phone shows a page of it as a postage stamp. This is the same booklet
## told a step at a time down the screen: each step's number and name, the
## part of the model it starts where one starts, its parts with their
## counts and where each is kept, its picture, and its callout's pictures,
## as wide as the screen allows; then the finished model, every part, and
## the booklet's credits.
##
## It reads the booklet back from the booklet, as its PDF and its pictures
## are (BookletRead, which it is): its file on the desktop, its tab on the
## web; so it saves in seconds, from what the person has in front of them,
## and draws nothing again. It reads what Booklet writes: each step's
## picture by its alt ("Step 12: Build the cockpit"), its parts as the
## parts box's pictures and their counts after them, its callout's
## pictures after the callout's box, and a callout's own pages by the
## finished assembly they open with. Whatever else is on a page (the
## designer's own words and pictures, which are placed on paper, the turn
## sign, the arrows) is the printed page's and is passed over.
##
## Dark is the page round the steps: the step's picture and its parts are
## drawn with the booklet's dark ink line round every brick, which a dark
## ground would swallow, so each step sits on a card of the booklet's own
## page colour in both. Every file stands alone: its pictures go in it as
## data, as the booklet's do, and its policy lets nothing else load and no
## script run. Each word from the booklet is written escaped again, and a
## picture that is not a PNG, JPEG or WebP in data is left out
## (Booklet._url), so a model file's words can no more break out of these
## pages than out of the booklet.
class_name BookletHtml
extends BookletRead

## How the steps are laid out: on one long page, or a page a step.
const LAYOUTS: Array[String] = ["long", "steps"]
const THEMES: Array[String] = ["light", "dark"]
## What the booklet's <title> has after the model's name.
const TITLE_TAIL := " — building instructions"
## The alt a picture of the designer's own has on a booklet page.
const DESIGNERS := "A picture of the designer's"

## Each step in the order the booklet has them: {number, name, picture,
## parts [{class, title, count, place}], callout [picture], times (how
## many of the callout to build), banner (the part of the model starting
## here, "" for none), within (a callout's own step: the assembly's name)}.
var steps: Array[Dictionary] = []
## The cover's picture, and the finished model's.
var cover: String = ""
var finished: String = ""
## "12 pieces · 4 steps", as the cover says it.
var counts: String = ""
## Every part, as the booklet's parts pages list them: {class, count, label,
## heading}.
var inventory: Array[Dictionary] = []
var credits: String = ""

## Reading a step page: the step being read, what of it has been read, and
## the callout whose own pages these are.
var _step: Dictionary = {}
var _phase: int = 0
var _banner: String = ""
var _within: String = ""
var _times: int = 1
const _PICTURE := 0
const _PARTS := 1
const _NUMBERED := 2
const _CALLOUT := 3


## The booklet [param from] (a file's path or a tab's document, as
## [method BookletRead.read_all]) written to [param to] as [param layout]
## ("long": one page, "steps": a zip of a page a step) in [param theme]
## ("light" or "dark"). A frame every [param pace] pages, as read_all.
## Returns the steps written, -1 when there was nothing to write or it could
## not be written.
func write(from: Variant, to: String, layout: String, theme: String, pace: int = 0) -> int:
	var count: int = await read_all(from, func(_page: Page) -> void: pass, pace)
	if count <= 0 or steps.is_empty():
		return -1
	if layout == "steps":
		var zip := ZIPPacker.new()
		if zip.open(to) != OK:
			return -1
		for index: int in steps.size():
			zip.start_file(step_file(index))
			zip.write_file(step_page(index, theme).to_utf8_buffer())
			zip.close_file()
		zip.start_file("index.html")
		zip.write_file(contents(theme).to_utf8_buffer())
		zip.close_file()
		zip.close()
		return steps.size()
	var file: FileAccess = FileAccess.open(to, FileAccess.WRITE)
	if file == null:
		return -1
	file.store_string(long_page(theme))
	var ok: bool = file.get_error() == OK
	file.close()
	return steps.size() if ok else -1


## The booklet [param text] (Booklet.html's, whole) read at once: for a check.
func read_text(text: String) -> void:
	feed(text)


## Its name, as the booklet's title has it.
func model_name() -> String:
	return title.trim_suffix(TITLE_TAIL)


# -- reading ---------------------------------------------------------------


## A page of the booklet read for its steps (BookletRead.feed hands each
## here whole); the page itself, empty, back.
func _page(html: String) -> Page:
	var page := Page.new()
	var at: int = 0
	var words: Dictionary = {}
	var kind: String = ""
	var svg: bool = false
	var last_part: Dictionary = {}
	while true:
		var open: int = html.find("<", at)
		if open < 0:
			break
		if not words.is_empty() and open > at:
			words["text"] = str(words["text"]) + html.substr(at, open - at)
		var close: int = html.find(">", open)
		if close < 0:
			break
		var tag: String = html.substr(open + 1, close - open - 1)
		at = close + 1
		var name: String = tag.get_slice(" ", 0).trim_suffix("/").to_lower()
		if name == "/svg":
			svg = false
			continue
		if svg:
			continue
		if name == "/div" and not words.is_empty():
			last_part = _step_words(kind, words["classes"], _unescaped(str(words["text"])).strip_edges(),
				last_part)
			words = {}
			continue
		if name.begins_with("/") or name.begins_with("!"):
			continue
		var attributes: Dictionary = _attributes(tag)
		var classes: PackedStringArray = str(attributes.get("class", "")).split(" ", false)
		match name:
			"section":
				kind = classes[1] if classes.size() > 1 else ""
				page.kind = kind
				page.number = str(attributes.get("id", "")).trim_prefix("page-").to_int()
				_start_page(kind)
			"svg":
				svg = true
			"div":
				if classes.has("t"):
					words = {"classes": classes, "text": ""}
				elif kind in ["steps", "callout"]:
					_step_box(classes)
			"br":
				if not words.is_empty():
					words["text"] = str(words["text"]) + " "
			"img":
				_step_picture(kind, Booklet._url(str(attributes.get("src", ""))),
					_unescaped(str(attributes.get("alt", ""))))
			"i":
				if classes.has("pt") and classes.size() > 1:
					last_part = {"class": classes[1], "title": _unescaped(str(attributes.get("title", ""))),
						"count": 0, "place": ""}
					if kind == "parts":
						inventory.append({"class": classes[1], "count": 0, "label": "",
							"title": last_part["title"], "heading": _heading})
						_heading = ""
					elif not _step.is_empty() and _phase <= _PARTS:
						(_step["parts"] as Array).append(last_part)
	_end_step()
	return page


## A colour heading on a parts page, for the part after it.
var _heading: String = ""
## In a 1:1 guide, from its box to the next box.
var _guide: bool = false


func _start_page(kind: String) -> void:
	_end_step()
	if kind == "steps":
		_within = ""
		_times = 1


## A box on a step page: the parts box starts a step that has no picture
## (one that could not be drawn), the callout's box starts its pictures,
## and the banner's strip says the next words are a part of the model.
func _step_box(classes: PackedStringArray) -> void:
	# A 1:1 guide's box: the number in its ring is a length, not a step's.
	_guide = classes.has("actual")
	if classes.has("box"):
		if _step.is_empty() or _phase >= _NUMBERED:
			_new_step(-1, "", "")
		_phase = _PARTS
	elif classes.has("co") and not _step.is_empty():
		_phase = _CALLOUT
	elif classes.has("ban"):
		_banner = "\u0001"


func _step_picture(kind: String, source: String, alt: String) -> void:
	match kind:
		"cover":
			if cover.is_empty() and alt in ["The finished model", "The cover"]:
				cover = source
		"finished":
			if finished.is_empty() and alt == "The finished model":
				finished = source
		"steps", "callout":
			if alt.begins_with("Step "):
				var said: String = alt.trim_prefix("Step ")
				var number: String = said.get_slice(":", 0).strip_edges()
				_new_step(number.to_int() if number.is_valid_int() else -1,
					said.substr(said.find(":") + 1).strip_edges() if said.contains(":") else "",
					source)
			elif kind == "callout" and alt.begins_with("The ") and alt.ends_with(", finished"):
				_within = alt.trim_prefix("The ").trim_suffix(", finished")
			elif not _step.is_empty() and _phase == _CALLOUT and alt != DESIGNERS \
					and not source.is_empty():
				(_step["callout"] as Array).append(source)


## A line of words on a page, of [param classes].
func _step_words(kind: String, classes: PackedStringArray, text: String, last_part: Dictionary) -> Dictionary:
	match kind:
		"cover":
			if classes.has("q") and text.contains(" pieces · "):
				counts = text
		"parts":
			if classes.has("q") and text.ends_with("x") and text.trim_suffix("x").is_valid_int() \
					and not inventory.is_empty() and int(inventory[-1]["count"]) == 0:
				inventory[-1]["count"] = text.trim_suffix("x").to_int()
			elif classes.has("e") and text.length() > 60:
				credits = text
			elif classes.has("e") and not inventory.is_empty() and int(inventory[-1]["count"]) > 0 \
					and str(inventory[-1]["label"]).is_empty():
				inventory[-1]["label"] = text
			elif classes.has("e"):
				_heading = text
		"steps", "callout":
			if _banner == "\u0001" and classes.has("n"):
				_banner = text
			elif classes.has("n") and text.ends_with("x") and text.trim_suffix("x").is_valid_int():
				# How many to build: a callout's, in its box, or on its own pages.
				if not _step.is_empty() and _phase == _CALLOUT:
					_step["times"] = text.trim_suffix("x").to_int()
				elif _step.is_empty() or kind == "callout":
					_times = text.trim_suffix("x").to_int()
			elif classes.has("n") and text.is_valid_int() and not _guide \
					and (_step.is_empty() or _phase < _CALLOUT):
				if _step.is_empty() or _phase >= _NUMBERED:
					_new_step(text.to_int(), "", "")
				if int(_step["number"]) < 0:
					_step["number"] = text.to_int()
				_phase = _NUMBERED
			elif classes.has("q") and not last_part.is_empty() and _phase <= _PARTS \
					and text.ends_with("x") and text.trim_suffix("x").is_valid_int() \
					and int(last_part["count"]) == 0:
				last_part["count"] = text.trim_suffix("x").to_int()
			elif classes.has("pl") and not last_part.is_empty() and _phase <= _PARTS:
				last_part["place"] = text
	return last_part


func _new_step(number: int, name: String, picture: String) -> void:
	_end_step()
	_step = {"number": number, "name": name, "picture": picture, "parts": [], "callout": [],
		"times": 1, "banner": _banner if _banner != "\u0001" else "", "within": _within,
		"build": _times if not _within.is_empty() else 1}
	_banner = ""
	_phase = _PICTURE


func _end_step() -> void:
	if not _step.is_empty():
		steps.append(_step)
	_step = {}
	_phase = _PICTURE
	_guide = false


# -- writing ---------------------------------------------------------------


## The steps on one long page in [param theme].
func long_page(theme: String) -> String:
	var used: Dictionary = {}
	var body := PackedStringArray()
	body.append("<header class=\"top\"><h1>%s</h1>%s</header>" % [_e(model_name()),
		("<p class=\"counts\">%s</p>" % _e(counts)) if not counts.is_empty() else ""])
	if not cover.is_empty():
		body.append("<figure class=\"sheet cover\"><img src=\"%s\" alt=\"%s\"></figure>" % [cover,
			_e(model_name())])
	for index: int in steps.size():
		body.append(_step_html(steps[index], used, index))
	body.append(_ending(used))
	return _document(model_name(), theme, used, "\n".join(body))


## The index of the page-a-step zip in [param theme]: the cover, every step
## linked, the finished model and every part.
func contents(theme: String) -> String:
	var used: Dictionary = {}
	var body := PackedStringArray()
	body.append("<header class=\"top\"><h1>%s</h1>%s</header>" % [_e(model_name()),
		("<p class=\"counts\">%s</p>" % _e(counts)) if not counts.is_empty() else ""])
	if not cover.is_empty():
		body.append("<figure class=\"sheet cover\"><img src=\"%s\" alt=\"%s\"></figure>" % [cover,
			_e(model_name())])
	body.append("<nav class=\"pager\"><a class=\"go\" href=\"%s\" rel=\"next\">Start building</a></nav>"
		% step_file(0))
	var items := PackedStringArray()
	for index: int in steps.size():
		var step: Dictionary = steps[index]
		if not str(step["banner"]).is_empty():
			items.append("<li class=\"part-of\">%s</li>" % _e(step["banner"]))
		items.append("<li><a href=\"%s\">%s</a></li>" % [step_file(index), _e(_step_title(step))])
	body.append("<h2>Steps</h2>\n<ol class=\"contents\">\n%s\n</ol>" % "\n".join(items))
	body.append(_ending(used))
	return _document(model_name(), theme, used, "\n".join(body), "", step_file(0))


## The page of step [param index] (of [member steps]) in [param theme], with
## its way to the steps either side and back to the contents.
func step_page(index: int, theme: String) -> String:
	var used: Dictionary = {}
	var before: String = step_file(index - 1) if index > 0 else "index.html"
	var after: String = step_file(index + 1) if index + 1 < steps.size() else "index.html"
	var nav: String = ("<nav class=\"pager\"><a href=\"%s\" rel=\"prev\">Previous</a>"
		+ "<a href=\"index.html\">Contents</a><span>%d of %d</span>"
		+ "<a class=\"go\" href=\"%s\" rel=\"next\">%s</a></nav>") % [before, index + 1, steps.size(),
			after, "Next" if index + 1 < steps.size() else "Finished"]
	var body := PackedStringArray()
	body.append("<header class=\"top small\"><a href=\"index.html\">%s</a></header>" % _e(model_name()))
	body.append(nav)
	body.append(_step_html(steps[index], used, -1))
	if index + 1 == steps.size() and not finished.is_empty():
		body.append("<h2>Finished</h2>\n<figure class=\"sheet\"><img src=\"%s\" alt=\"The finished model\"></figure>"
			% finished)
	body.append(nav)
	if not credits.is_empty():
		body.append("<footer>%s</footer>" % _e(credits))
	return _document("%s · %s" % [_step_title(steps[index]), model_name()], theme, used,
		"\n".join(body), before, after)


## The file step [param index] is on, in the page-a-step zip.
func step_file(index: int) -> String:
	return ("step-%03d.html" if steps.size() < 1000 else "step-%04d.html") % (index + 1)


## "Step 12: Build the cockpit", or a callout's own "The gatehouse, step 2".
static func _step_title(step: Dictionary) -> String:
	var number: int = int(step["number"])
	var said: String = ("Step %d" % number) if number >= 0 else "Step"
	if not str(step["within"]).is_empty():
		said = "%s, %s" % [step["within"], said.to_lower()]
	return said + ((": " + str(step["name"])) if not str(step["name"]).is_empty() else "")


## A step as a card; [param anchor] its place on the long page, -1 on a page
## of its own.
func _step_html(step: Dictionary, used: Dictionary, anchor: int) -> String:
	var out := PackedStringArray()
	if not str(step["banner"]).is_empty():
		out.append("<h2 class=\"part-of\">%s</h2>" % _e(step["banner"]))
	out.append("<article class=\"step%s\"%s>" % [" within" if not str(step["within"]).is_empty() else "",
		(" id=\"step-%d\"" % (anchor + 1)) if anchor >= 0 else ""])
	var number: int = int(step["number"])
	var heading: String = "<span class=\"num\">%s</span>" % (str(number) if number >= 0 else "")
	if not str(step["within"]).is_empty():
		heading = "<span class=\"of\">%s%s</span>%s" % [_e(step["within"]),
			(" ×%d" % int(step["build"])) if int(step["build"]) > 1 else "", heading]
	if not str(step["name"]).is_empty():
		heading += "<span class=\"name\">%s</span>" % _e(step["name"])
	out.append("<h3>%s</h3>" % heading)
	out.append("<div class=\"sheet\">")
	var parts: Array = step["parts"]
	if not parts.is_empty():
		var items := PackedStringArray()
		for part: Dictionary in parts:
			items.append(_part_html(part, used))
		out.append("<ul class=\"parts\" aria-label=\"Parts\">%s</ul>" % "".join(items))
	if not str(step["picture"]).is_empty():
		out.append("<img class=\"picture\" src=\"%s\" alt=\"%s\">" % [step["picture"],
			_e(_step_title(step))])
	var callout: Array = step["callout"]
	if not callout.is_empty():
		var cells := PackedStringArray()
		for index: int in callout.size():
			cells.append("<img src=\"%s\" alt=\"%s\">" % [callout[index],
				_e("Sub-assembly, step %d" % (index + 1))])
		out.append("<div class=\"callout\">%s%s</div>" % [("<p class=\"times\">%dx</p>"
			% int(step["times"])) if int(step["times"]) > 1 else "", "".join(cells)])
	out.append("</div>\n</article>")
	return "\n".join(out)


## A part of a step's list: its picture, by its class, and its count under
## it, with where it is kept.
func _part_html(part: Dictionary, used: Dictionary) -> String:
	var picture: String = Booklet._url(str(parts.get(str(part["class"]), "")))
	var shown: String = ""
	if not picture.is_empty():
		used[part["class"]] = picture
		shown = "<i class=\"pt %s\" role=\"img\" aria-label=\"%s\" title=\"%s\"></i>" % [part["class"],
			_e(part["title"]), _e(part["title"])]
	else:
		shown = "<i class=\"pt\" role=\"img\" aria-label=\"%s\" title=\"%s\"></i>" % [
			_e(part["title"]), _e(part["title"])]
	var place: String = str(part.get("place", ""))
	return "<li>%s<b>%dx</b>%s</li>" % [shown, int(part["count"]),
		("<small>%s</small>" % _e(place)) if not place.is_empty() else ""]


## The end of the long page and of the contents: the finished model, every
## part, and the credits.
func _ending(used: Dictionary) -> String:
	var out := PackedStringArray()
	if not finished.is_empty():
		out.append("<h2>Finished</h2>\n<figure class=\"sheet\"><img src=\"%s\" alt=\"The finished model\"></figure>"
			% finished)
	if not inventory.is_empty():
		var items := PackedStringArray()
		for part: Dictionary in inventory:
			var item: Dictionary = part.duplicate()
			item["place"] = part["label"]
			items.append(_part_html(item, used))
		out.append("<h2>Parts</h2>\n<div class=\"sheet\"><ul class=\"parts all\">%s</ul></div>"
			% "".join(items))
	if not credits.is_empty():
		out.append("<footer>%s</footer>" % _e(credits))
	return "\n".join(out)


## A whole file: its head, its look in [param theme], the rules of the
## parts' pictures it shows ([param used]), and [param body].
func _document(named: String, theme: String, used: Dictionary, body: String, before: String = "",
		after: String = "") -> String:
	var dark: bool = theme == "dark"
	var rules := PackedStringArray()
	for key: String in used:
		rules.append(".%s{background-image:url(%s)}" % [key, used[key]])
	var links: String = ""
	if not before.is_empty():
		links += "<link rel=\"prev\" href=\"%s\">\n" % before
	if not after.is_empty():
		links += "<link rel=\"next\" href=\"%s\">\n" % after
	return """<!doctype html>
<html lang="en" class="%s">
<meta charset="utf-8">
<meta http-equiv="Content-Security-Policy" content="%s">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="%s">
<title>%s</title>
%s<style>
%s
:root { --card: #%s; }
%s
</style>
<body>
<main>
%s
</main>
</body>
</html>
""" % [theme if theme in THEMES else "light", POLICY, "dark" if dark else "light", _e(named), links,
		STYLE, colour.to_html(false), "\n".join(rules), body]


## Nothing loads but what is in the file, and nothing runs.
const POLICY := "default-src 'none'; style-src 'unsafe-inline'; img-src data:; base-uri 'none'; form-action 'none'"

## The look, both themes: the ground, words and links change; the card each
## step is on stays the booklet's page colour, its ink dark.
const STYLE := """
html.light { --ground: #f3f5f8; --words: #15191e; --soft: #4a5561; --rule: #d5dde6;
  --link: #1b5fa6; --band: #23527c; --band-words: #fff; --chip: #fff; }
html.dark { --ground: #12171d; --words: #e6edf3; --soft: #9aa8b6; --rule: #2b3540;
  --link: #8cc4ff; --band: #2d6aa0; --band-words: #fff; --chip: #1c242d; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--ground); color: var(--words);
  font: 16px/1.45 system-ui, -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; }
main { max-width: 980px; margin: 0 auto; padding: 16px 14px 40px; }
a { color: var(--link); }
h1 { font-size: 1.7rem; margin: 8px 0 2px; }
h2 { font-size: 1.25rem; margin: 28px 0 10px; }
.top.small { font-weight: 600; }
.counts { color: var(--soft); margin: 0 0 12px; }
.part-of { background: var(--band); color: var(--band-words); padding: 8px 14px;
  border-radius: 10px; font-size: 1.1rem; }
.step { margin: 22px 0 30px; }
.step h3 { display: flex; flex-wrap: wrap; align-items: baseline; gap: 4px 12px; margin: 0 0 8px; }
.num { font-size: 2.2rem; font-weight: 800; line-height: 1; letter-spacing: -.02em; }
.of { color: var(--soft); font-weight: 600; width: 100%; font-size: .95rem; }
.name { font-size: 1.1rem; font-weight: 600; }
.sheet { background: var(--card); color: #15191e; border-radius: 14px; padding: 14px;
  margin: 0; box-shadow: 0 1px 3px rgba(0,0,0,.18); }
.sheet img { display: block; max-width: 100%; height: auto; margin: 0 auto; }
.cover img, .picture { width: 100%; }
.parts { list-style: none; display: flex; flex-wrap: wrap; gap: 8px; margin: 0 0 12px; padding: 0; }
.parts li { background: #fff; border-radius: 10px; padding: 6px 8px; min-width: 64px;
  display: flex; flex-direction: column; align-items: center; gap: 2px;
  box-shadow: inset 0 0 0 1px rgba(21,25,30,.12); }
.pt { display: block; width: 56px; height: 44px; background-size: contain;
  background-repeat: no-repeat; background-position: center bottom; }
.parts b { font-size: .95rem; }
.parts small { color: #3b4652; font-size: .75rem; max-width: 88px; text-align: center;
  overflow-wrap: anywhere; }
.callout { background: #fff3c8; border: 2px solid #34393f; border-radius: 12px; padding: 10px;
  margin-top: 12px; display: flex; flex-wrap: wrap; gap: 10px; align-items: center; }
.callout img { max-width: 46%; margin: 0; }
.times { font-weight: 800; font-size: 1.2rem; margin: 0 6px; }
.pager { display: flex; flex-wrap: wrap; gap: 10px; align-items: center; margin: 12px 0; }
.pager a { padding: 10px 16px; min-height: 44px; border-radius: 10px; text-decoration: none;
  background: var(--chip); box-shadow: inset 0 0 0 1px var(--rule); display: inline-flex;
  align-items: center; }
.pager a.go { background: var(--link); color: var(--ground); box-shadow: none; font-weight: 600;
  margin-left: auto; }
.pager span { color: var(--soft); }
.contents { padding-left: 1.4em; }
.contents li { margin: 4px 0; }
.contents li.part-of { list-style: none; margin: 14px 0 6px -1.4em; font-size: 1rem; }
footer { color: var(--soft); font-size: .8rem; margin-top: 36px; border-top: 1px solid var(--rule);
  padding-top: 12px; }
@media (min-width: 760px) {
  .sheet { display: grid; grid-template-columns: minmax(150px, 30%) 1fr; gap: 14px; align-items: start; }
  .sheet > .parts { grid-column: 1; margin: 0; align-content: start; }
  .sheet > .picture { grid-column: 2; grid-row: 1 / span 2; }
  .sheet > .callout { grid-column: 1 / -1; }
  .sheet:not(:has(.parts)) > .picture { grid-column: 1 / -1; }
  .cover, figure.sheet { display: block; }
  .parts.all { grid-column: 1 / -1; }
}
@media print { .pager { display: none; } body { background: #fff; } }
"""


## Words from the booklet, written into HTML again.
static func _e(raw: Variant) -> String:
	return Booklet._escape(str(raw))
