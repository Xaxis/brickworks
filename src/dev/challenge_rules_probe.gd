## The studio's ticks of a challenge's rules against the site's check, on 30
## published models under three rules (challengestudio, 2026-11-23): 90 of 90
## the same, answer for answer, on the same text.
##
##   set -a; . ./.env; set +a
##   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/challenge_rules_check.mjs --out=DIR
##   tools/probe.sh challenge_rules_probe --fixtures=DIR
##   PG_MODULE=... node tools/challenge_rules_check.mjs --out=DIR --studio=DIR/studio
##
## Two equalities, each on one text read by both:
##
##   the port   ChallengeRules on each file as it is stored, against the
##              site's check of that same file counted as a publish counts it
##              (checkModel, keyed, challenge_check): 90 of 90 here, or this
##              fails.
##   the studio each file opened, its text written as the line writes it and
##              ticked as the line ticks it, its Tested the four tests a
##              publish runs: written to DIR/studio (studio.json, written/),
##              and the site's check run on those very texts and findings by
##              the third command, which says how many of 90 are the same
##              and fails short of 90. A text the studio writes can need
##              other lots than the file it opened (an older build wrote the
##              file), and a model Tested at an older publish can fail
##              today's tests: what a publish from the studio sends is
##              what the site then checks, so that is what is compared.
##
## tools/challenge_rules_check.mjs wrote the site's answers: supabase/
## challenges.sql challenge_check itself, run on the live project in a
## rolled-back transaction, each model checked against three test challenges
## (at most the median's parts; a set of the first ten models' lots, the
## eleventh's biggest one short; Tested), with each model counted as a
## publish today counts its file ("published"), and as the database keeps
## it ("stored", counted at its own publish). Its files are beside them.
##
## The studio's tick here is ChallengeLine's: each file opened in the studio
## (ModelStore.open_text), its text written back as the line writes it
## (ModelStore.text_for_rules), read and spelled (ChallengeRules.facts_of),
## and checked (ChallengeRules.check) under the rules as the studio is given
## them (ChallengeRules.rules_in), its Tested the four tests a publish runs
## on the model opened (SharedPages.attach_tested). Every key of every
## answer must be the site's: each rule's ok, the parts it has, the set's
## lots short, which, and how many.
##
## Also said, not counted: the port alone on each stored file as it is
## (no open, no write), and how many stored counts are behind a publish's
## today (a site's answer from an older count, which no studio can match).
extends SceneTree

var _library: PartLibrary
var _store: ModelStore
var _failures: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var dir: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--fixtures="):
			dir = arg.substr(11)
	if dir.is_empty() or not FileAccess.file_exists(dir.path_join("site.json")):
		print("challenge_rules probe: name the fixtures: -- --fixtures=DIR (tools/challenge_rules_check.mjs)")
		quit(2)
		return
	var site: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("site.json")))
	_library = PartLibrary.new()
	if not _library.load_catalogue():
		print("no catalogue")
		quit(1)
		return
	var world := BrickWorld.new()
	world.library = _library
	get_root().add_child(world)
	var builder := Builder.new()
	builder.world = world
	builder.library = _library
	get_root().add_child(builder)
	_store = ModelStore.new()
	_store.world = world
	_store.library = _library
	_store.builder = builder
	_store.keeps = false
	await process_frame

	# The rules as the studio is given them: read at the edge.
	var rules: Dictionary = {}
	for c: Dictionary in site["challenges"]:
		var answer: Dictionary = {"code": 200, "body": {"challenge": {"id": 1, "title": "Studio check",
			"ends_on": "2026-11-30", "rules": c["rules"]}}}
		var read_in: Dictionary = ChallengeRules.rules_in(answer)
		_ok(not read_in.is_empty(), "the %s rule reads at the edge" % c["kind"])
		rules[c["kind"]] = read_in.get("rules", {})
	var same: int = 0
	var port_same: int = 0
	var stored_same: int = 0
	var checks: int = 0
	var slowest_ms: int = 0
	var out_dir: String = dir.path_join("studio")
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("written"))
	var studio: Dictionary = {}
	var texts_differ: PackedStringArray = PackedStringArray()
	var tested_moved: PackedStringArray = PackedStringArray()
	for model: Dictionary in site["models"]:
		var id: String = model["id"]
		var text: String = FileAccess.get_file_as_string(dir.path_join("models/%s.mpd" % id))
		# The port alone, on the file as it is stored.
		var port: Dictionary = ChallengeRules.facts_of(text, _library)
		# The studio's: opened, written back as the line writes it, read.
		var opened: Dictionary = _store.open_text(text, id)
		await process_frame
		var began: int = Time.get_ticks_msec()
		var written: String = await _store.text_for_rules()
		var facts: Dictionary = ChallengeRules.facts_of(written, _library)
		slowest_ms = maxi(slowest_ms, Time.get_ticks_msec() - began)
		var title: String = id
		var for_test: String = await _store.text_for_file(title, "")
		# What a publish sends: the text with its steps, and the finding of it.
		var attached: Dictionary = await SharedPages.attach_tested(for_test, _library, _store)
		var found: Dictionary = attached["tested"]
		var passed: bool = Tested.passed(found)
		# The text a publish sends counts as the line's text does.
		var published_facts: Dictionary = ChallengeRules.facts_of(for_test, _library)
		if JSON.stringify(published_facts, "", true) != JSON.stringify(facts, "", true):
			texts_differ.append(id)
		if passed != bool(model["tested"]):
			tested_moved.append("%s (%s here: %s)" % [id, "Tested" if passed else "not Tested", Tested.words(found)])
		var f := FileAccess.open(out_dir.path_join("written/%s.mpd" % id), FileAccess.WRITE)
		f.store_string(str(attached["text"]))
		f.close()
		var tests_kept: Dictionary = {}
		for test: String in ["stands", "steps", "parts", "whole"]:
			var one: Variant = (found.get("tests", {}) as Dictionary).get(test)
			tests_kept[test] = {"ok": one is Dictionary and bool((one as Dictionary).get("ok", false)),
				"why": str((one as Dictionary).get("why", "")).left(200) if one is Dictionary else "not run"}
		studio[id] = {"parts": int(facts.get("parts", 0)), "lots": (facts.get("needs", {}) as Dictionary).size(),
			"tested": passed, "tests": tests_kept, "finding": found, "checks": {}}
		print("%s: %d parts (stored %d), %d lots; opened %d placed; studio %s parts, %d lots; Tested here %s, site %s"
			% [id, int(model["parts"]), int(model["stored_parts"]), int(model["lots"]), int(opened.get("placed", 0)),
				str(facts.get("parts", facts.get("error", "?"))), (facts.get("needs", {}) as Dictionary).size(),
				passed, model["tested"]])
		var lots_moved: String = _lots_moved(port.get("needs", {}), facts.get("needs", {}))
		if not lots_moved.is_empty():
			print("  the studio's text needs other lots than the stored file: " + lots_moved)
		for kind: String in ["parts", "set", "tested"]:
			checks += 1
			var site_said: Dictionary = (site["published"][id] as Dictionary)[kind]
			var mine: Dictionary = _same_numbers(ChallengeRules.check(rules[kind], facts, passed))
			(studio[id]["checks"] as Dictionary)[kind] = mine
			var port_said: Dictionary = _same_numbers(ChallengeRules.check(rules[kind], port,
				bool(model["tested"])))
			if _equal(mine, site_said):
				same += 1
			else:
				print("  DIFFERENT %s %s\n    studio %s\n    site   %s" % [id, kind, _short(mine), _short(site_said)])
			if _equal(port_said, site_said):
				port_same += 1
			else:
				print("  port differs %s %s\n    port %s\n    site %s" % [id, kind, _short(port_said), _short(site_said)])
			if _equal(port_said, (site["stored"][id] as Dictionary)[kind]):
				stored_same += 1
	var kept := FileAccess.open(out_dir.path_join("studio.json"), FileAccess.WRITE)
	kept.store_string(JSON.stringify({"models": studio, "rules": site["challenges"]}, " ", true) + "\n")
	kept.close()
	print("\nthe port on each stored file, the site's check of that file: %d of %d the same" % [port_same, checks])
	print("the studio's ticks on what it would publish, the site's on the stored file: %d of %d the same" % [same, checks])
	print("against the stored counts (an older publish's): %d of %d the same" % [stored_same, checks])
	print("Tested today against the stored mark, different for %d: %s" % [tested_moved.size(), "; ".join(tested_moved)])
	print("the slowest model's text written and read for the rules: %d ms" % slowest_ms)
	print("the studio's texts and findings in %s, for the site's check on them (--studio)" % out_dir)
	_ok(port_same == checks and checks == 90, "the port is the site's check, on the same 30 files x 3 rules, %d of %d"
		% [port_same, checks])
	_ok(texts_differ.is_empty(), "the line's text counts as the publish's text does (%s)" % (
		"all 30" if texts_differ.is_empty() else "not for " + ", ".join(texts_differ)))
	print("%d FAILED" % _failures if _failures else "the studio ticks every rule as the site checks it")
	quit(1 if _failures else 0)


## The lots [param after] needs other than [param before] does, at most
## ten of each way: "part/colour stored -> studio".
static func _lots_moved(before: Dictionary, after: Dictionary) -> String:
	var moved := PackedStringArray()
	for key: String in before:
		if int(after.get(key, 0)) != int(before[key]):
			moved.append("%s %d -> %d" % [key, int(before[key]), int(after.get(key, 0))])
	for key: String in after:
		if not before.has(key):
			moved.append("%s 0 -> %d" % [key, int(after[key])])
	return ", ".join(moved.slice(0, 20))


## [param said] through JSON and back, so its whole numbers are the floats
## the site's answer reads as.
static func _same_numbers(said: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(said))


static func _equal(a: Variant, b: Variant) -> bool:
	return JSON.stringify(a, "", true) == JSON.stringify(b, "", true)


static func _short(said: Variant) -> String:
	return JSON.stringify(said, "", true).left(600)


func _ok(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		_failures += 1
