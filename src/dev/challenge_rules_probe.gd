## The studio's ticks of a challenge's rules against the site's check, on 30
## published models under three rules (challengestudio, 2026-11-23): 90 of 90
## the same, answer for answer.
##
##   set -a; . ./.env; set +a
##   PG_MODULE=/tmp/pg/node_modules/pg/lib/index.js node tools/challenge_rules_check.mjs --out=DIR
##   ~/.claude/claude-core/bin/heavy godot --headless --path . --script src/dev/challenge_rules_probe.gd -- --fixtures=DIR
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
		var found: Dictionary = (await SharedPages.attach_tested(for_test, _library, _store))["tested"]
		var passed: bool = Tested.passed(found)
		print("%s: %d parts (stored %d), %d lots; opened %d placed; studio %s parts, %d lots; Tested here %s, site %s"
			% [id, int(model["parts"]), int(model["stored_parts"]), int(model["lots"]), int(opened.get("placed", 0)),
				str(facts.get("parts", facts.get("error", "?"))), (facts.get("needs", {}) as Dictionary).size(),
				passed, model["tested"]])
		for kind: String in ["parts", "set", "tested"]:
			checks += 1
			var site_said: Dictionary = (site["published"][id] as Dictionary)[kind]
			var mine: Dictionary = _same_numbers(ChallengeRules.check(rules[kind], facts, passed))
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
	print("\nthe studio's ticks, the site's check: %d of %d the same" % [same, checks])
	print("the port alone on each stored file: %d of %d the same" % [port_same, checks])
	print("against the stored counts (an older publish's): %d of %d the same" % [stored_same, checks])
	print("the slowest model's text written and read for the rules: %d ms" % slowest_ms)
	_ok(same == checks and checks == 90, "the studio's ticks are the site's check on 30 models x 3 rules, %d of %d"
		% [same, checks])
	print("%d FAILED" % _failures if _failures else "the studio ticks every rule as the site checks it")
	quit(1 if _failures else 0)


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
