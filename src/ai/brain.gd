## Which Claude designs for you, and how hard it thinks.
##
## Three models and five levels of effort, and the combinations are not
## all legal. That is the whole reason this file exists rather than a
## dropdown wired straight to a request field: Haiku refuses adaptive
## thinking and refuses the effort parameter, both with a 400, and a
## picker that did not know would offer two settings that break the
## assistant outright.
##
## Every flag here was measured against the live API rather than read
## off a page. This project has already shipped a request field that
## Anthropic rejected on sight.
##
##   model                      adaptive thinking   effort
##   claude-opus-5                     yes            yes
##   claude-sonnet-5                   yes            yes
##   claude-haiku-4-5-20251001         no             no
##
## Prices are USD per million tokens, from the published table. They go
## out of date, which is why what the app shows is always the token
## count as well — the tokens are what was actually spent and the money
## is this file's arithmetic on top of them.
class_name Brain
extends RefCounted

const WHERE := "user://assistant.cfg"


class Choice extends RefCounted:
	var id: String
	var name: String
	var blurb: String
	## Accepts thinking {"type": "adaptive"}.
	var adaptive: bool
	## Accepts output_config {"effort": ...}.
	var effort: bool
	var per_in: float        ## USD per million input tokens
	var per_out: float       ## USD per million output tokens
	var per_cached: float    ## USD per million tokens read from cache

	func _init(fields: Dictionary) -> void:
		id = str(fields["id"])
		name = str(fields["name"])
		blurb = str(fields["blurb"])
		adaptive = bool(fields["adaptive"])
		effort = bool(fields["effort"])
		per_in = float(fields["in"])
		per_out = float(fields["out"])
		per_cached = float(fields["cached"])


## What the choices are actually worth, from running the same brief —
## a post box — through each of them. src/dev/bakeoff_probe.gd does it.
##
##   setting            took   in / out    cost   bricks
##   Opus 5 high        275s   203k/20k    $1.53      27
##   Sonnet 5 low       151s   535k/8k     $1.15       8
##   Sonnet 5 high      212s   194k/16k      55c       8
##   Sonnet 5 max       490s   261k/37k      89c      11
##   Haiku 4.5           57s   220k/4k       24c       9
##
## Two things in that table are worth knowing and neither is obvious.
##
## The model matters far more than the effort: Opus built three times
## the post box the others did for the same words. Bricks are not the
## measure of a good model, but eight of them is not a post box.
##
## And low effort is not the cheap setting. It cost twice what high
## did, because it thought less and so went round more times — half a
## million input tokens against two hundred thousand. Which is why the
## blurb for it says so rather than implying a saving that is not
## there.
const CHOICES: Array[Dictionary] = [
	{"id": "claude-opus-5", "name": "Opus 5",
		"blurb": "The best at this by a distance. Slowest and dearest.",
		"adaptive": true, "effort": true,
		"in": 5.0, "out": 25.0, "cached": 0.50},
	{"id": "claude-sonnet-5", "name": "Sonnet 5",
		"blurb": "Quicker and a third of the cost. Builds smaller.",
		"adaptive": true, "effort": true,
		"in": 2.0, "out": 10.0, "cached": 0.20},
	{"id": "claude-haiku-4-5-20251001", "name": "Haiku 4.5",
		"blurb": "A minute and a few pence. Small models, small changes.",
		"adaptive": false, "effort": false,
		"in": 1.0, "out": 5.0, "cached": 0.10},
]

## How hard to think, for the models that take the setting. Ordered.
const EFFORTS: Array[String] = ["low", "medium", "high", "xhigh", "max"]

## What each level is for, in as many words as fit beside a dropdown.
## "low" is not the cheap one and saying otherwise would be a lie the
## bill contradicts an hour later.
const EFFORT_BLURBS: Dictionary = {
	"low": "Barely thinks. Often ends up dearer, by going round more times.",
	"medium": "A quick answer for a simple thing.",
	"high": "The sensible default.",
	"xhigh": "For something intricate.",
	"max": "Twice the time and twice the bill. Worth it rarely.",
}
const DEFAULT_EFFORT := "high"
const DEFAULT_MODEL := "claude-opus-5"


static func all() -> Array[Choice]:
	var out: Array[Choice] = []
	for fields: Dictionary in CHOICES:
		out.append(Choice.new(fields))
	return out


## The named model, or the default. Never null: a saved setting naming
## a model that no longer exists should fall back rather than crash the
## panel it is read from.
static func find(id: String) -> Choice:
	for fields: Dictionary in CHOICES:
		if str(fields["id"]) == id:
			return Choice.new(fields)
	for fields: Dictionary in CHOICES:
		if str(fields["id"]) == DEFAULT_MODEL:
			return Choice.new(fields)
	return Choice.new(CHOICES[0])


# -- what has been chosen ------------------------------------------------


static func _settings() -> ConfigFile:
	var file := ConfigFile.new()
	file.load(WHERE)
	return file


static func _keep(file: ConfigFile) -> void:
	file.save(WHERE)


static func chosen() -> String:
	return find(str(_settings().get_value(
		"assistant", "model", DEFAULT_MODEL))).id


static func choose(id: String) -> void:
	var file: ConfigFile = _settings()
	file.set_value("assistant", "model", find(id).id)
	_keep(file)


## The effort level, or empty when the chosen model does not take one.
static func effort() -> String:
	if not find(chosen()).effort:
		return ""
	var level: String = str(_settings().get_value(
		"assistant", "effort", DEFAULT_EFFORT))
	return level if EFFORTS.has(level) else DEFAULT_EFFORT


static func set_effort(level: String) -> void:
	if not EFFORTS.has(level):
		return
	var file: ConfigFile = _settings()
	file.set_value("assistant", "effort", level)
	_keep(file)


# -- what it cost --------------------------------------------------------


## Tokens spent so far, as the API reports them.
class Spend extends RefCounted:
	var fresh: int = 0     ## input tokens read for the first time
	var cached: int = 0    ## input tokens served from the cache
	var written: int = 0   ## input tokens written into the cache
	var made: int = 0      ## output tokens

	## Add what one reply reports. Field names are Anthropic's.
	func add(usage: Dictionary) -> void:
		fresh += int(usage.get("input_tokens", 0))
		cached += int(usage.get("cache_read_input_tokens", 0))
		written += int(usage.get("cache_creation_input_tokens", 0))
		made += int(usage.get("output_tokens", 0))

	func total_in() -> int:
		return fresh + cached + written

	func is_empty() -> bool:
		return total_in() == 0 and made == 0


## What a design cost, in dollars.
##
## Cache writes are charged at 1.25x the input price for the five minute
## window, which is the one a design uses.
static func cost(model_id: String, spend: Spend) -> float:
	var choice: Choice = find(model_id)
	return (
		spend.fresh * choice.per_in
		+ spend.written * choice.per_in * 1.25
		+ spend.cached * choice.per_cached
		+ spend.made * choice.per_out
	) / 1_000_000.0


## Money, written the way a small amount of it should be.
##
## A design costs cents. "$0.04" is the useful answer and "$0.0413" is
## noise; below a cent, say so rather than rounding it away to nothing.
static func in_money(dollars: float) -> String:
	if dollars <= 0.0:
		return "nothing yet"
	if dollars < 0.01:
		return "under a cent"
	if dollars < 1.0:
		return "%d¢" % int(round(dollars * 100.0))
	return "$%.2f" % dollars


## Thousands, because a design runs to tens of thousands of tokens and
## the digits stop meaning anything.
static func in_tokens(count: int) -> String:
	if count < 1000:
		return str(count)
	return "%.1fk" % (count / 1000.0)
