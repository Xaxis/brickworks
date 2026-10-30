## Which provider designs, on which model, at which address, with whose key.
##
## Brickworks designs with Claude on the person's own plan (the connector, or
## Claude Code here), or with any provider's model on the person's own key:
## this file is the second, and who() says which the person chose (Settings,
## AI). A provider is a preset (where its API is, what its keys look like,
## which adapter speaks it) or "custom", any server that speaks OpenAI's Chat
## Completions at an address the person gives. OpenAI's own models are spoken
## to in its Responses API (OpenAIResponses); every server that copies
## OpenAI's API, in Chat Completions (OpenAIChat).
##
## The key:
##
##   It goes from this machine to the provider's own address and nowhere
##   else. No server of ours is in the path; nothing of ours logs it, and it
##   is in no saved model and no share (the settings file holds no key).
##
##   It is kept on this device, one file per provider in the app's own data
##   (user://), encrypted with a password made of this computer's own id and
##   a salt the app made once: a copy of the file taken elsewhere (a backup,
##   a synced folder) cannot be read. Godot offers no operating system
##   keychain, so this is the next best; anything running as the person here
##   can still reach it, and the panel says so. In a browser user:// is the
##   site's storage and a browser has no id of its own to give, so there the
##   encryption only scrambles it, and the panel says that too. Or for this
##   visit only, kept nowhere. Forgetting it removes the file.
##
##   On a command line (--ask-provider) it may come from the provider's
##   usual environment variable (OPENAI_API_KEY, …) instead, never printed.
class_name ProviderSettings
extends RefCounted

## Every provider the app knows. adapter: which Provider speaks it. base: its
## API's address. prefix: what its keys begin with ("" when they vary).
## env: the variable a command line reads the key from. needs_key: false for
## a server on this machine. vision_tools: models known to call tools and see
## pictures, suggested first, best first (docs/PROVIDERS.md says how they
## were chosen); the person may name any other.
const PRESETS: Dictionary = {
	"openai": {"name": "OpenAI", "adapter": "openai_responses",
		"base": "https://api.openai.com/v1", "prefix": "sk-", "env": "OPENAI_API_KEY",
		"needs_key": true, "models": ["gpt-6.1-sol", "gpt-6-astra", "gpt-6.1-terra"]},
	"anthropic": {"name": "Anthropic API", "adapter": "anthropic_messages",
		"base": "https://api.anthropic.com/v1", "prefix": "sk-ant-", "env": "ANTHROPIC_API_KEY",
		"needs_key": true, "models": ["claude-opus-5-5", "claude-sonnet-5-5"]},
	"gemini_native": {"name": "Google Gemini", "adapter": "gemini_native",
		"base": "https://generativelanguage.googleapis.com/v1beta", "prefix": "",
		"env": "GEMINI_API_KEY", "needs_key": true,
		"models": ["gemini-4-argon", "gemini-3.8-flash"]},
	"openrouter": {"name": "OpenRouter", "adapter": "openai_chat",
		"base": "https://openrouter.ai/api/v1", "prefix": "sk-or-", "env": "OPENROUTER_API_KEY",
		"needs_key": true, "models": ["openai/gpt-6.1-sol", "google/gemini-4-argon",
			"qwen/qwen3.8-max-0902"]},
	"gemini": {"name": "Google Gemini (OpenAI-compatible)", "adapter": "openai_chat",
		"base": "https://generativelanguage.googleapis.com/v1beta/openai", "prefix": "",
		"env": "GEMINI_API_KEY", "needs_key": true,
		"models": ["gemini-4-argon", "gemini-3.8-flash"]},
	"mistral": {"name": "Mistral", "adapter": "openai_chat",
		"base": "https://api.mistral.ai/v1", "prefix": "", "env": "MISTRAL_API_KEY",
		"needs_key": true, "models": ["mistral-large-4-0"]},
	"groq": {"name": "Groq", "adapter": "openai_chat",
		"base": "https://api.groq.com/openai/v1", "prefix": "gsk_", "env": "GROQ_API_KEY",
		"needs_key": true, "models": []},
	"together": {"name": "Together", "adapter": "openai_chat",
		"base": "https://api.together.xyz/v1", "prefix": "", "env": "TOGETHER_API_KEY",
		"needs_key": true, "models": []},
	"deepseek": {"name": "DeepSeek", "adapter": "openai_chat",
		"base": "https://api.deepseek.com", "prefix": "sk-", "env": "DEEPSEEK_API_KEY",
		"needs_key": true, "models": []},
	"xai": {"name": "xAI", "adapter": "openai_chat",
		"base": "https://api.x.ai/v1", "prefix": "xai-", "env": "XAI_API_KEY",
		"needs_key": true, "models": []},
	"ollama": {"name": "Ollama (this computer)", "adapter": "openai_chat",
		"base": "http://127.0.0.1:11434/v1", "prefix": "", "env": "", "needs_key": false,
		"models": []},
	"lmstudio": {"name": "LM Studio (this computer)", "adapter": "openai_chat",
		"base": "http://127.0.0.1:1234/v1", "prefix": "", "env": "", "needs_key": false,
		"models": []},
	"vllm": {"name": "vLLM", "adapter": "openai_chat",
		"base": "http://127.0.0.1:8000/v1", "prefix": "", "env": "", "needs_key": false,
		"models": []},
	"custom": {"name": "Another OpenAI-compatible server", "adapter": "openai_chat",
		"base": "", "prefix": "", "env": "", "needs_key": false, "models": []},
}

const DEFAULT_PROVIDER := "openai"

## The presets in the order the settings offer them: the big three, the
## hosts of many models, then servers on the person's own computer.
const ORDER: Array[String] = ["openai", "anthropic", "gemini_native", "gemini", "openrouter",
	"mistral", "groq", "together", "deepseek", "xai", "ollama", "lmstudio", "vllm", "custom"]

## Who designs (who()): Claude on the person's plan or Anthropic key, the
## ways there were, or a model on the person's own key with a provider.
const WHO_CLAUDE := "claude"
const WHO_KEY := "own_key"

## Where the choice is kept: who designs, the provider, and each provider's
## model, address and parameters, and what Test found. Never the key, which
## has a file of its own (key_file).
static var where: String = "user://providers.cfg"


## The adapter for [param id] at [param base] (the preset's own when empty),
## on [param model], with [param key]. Null for a provider nobody knows.
static func provider_for(id: String, model: String, key: String, base: String = "",
		params: Dictionary = {}) -> Provider:
	var preset: Dictionary = PRESETS.get(id, {})
	if preset.is_empty():
		return null
	var made: Provider = null
	match str(preset["adapter"]):
		"openai_chat":
			made = OpenAIChat.new()
		"openai_responses":
			made = OpenAIResponses.new()
		"anthropic_messages":
			made = AnthropicMessages.new()
		"gemini_native":
			made = GeminiNative.new()
	if made == null:
		return null
	made.model = model
	made.key = key
	made.base_url = base if not base.strip_edges().is_empty() else str(preset["base"])
	made.params = params
	return made


## What is wrong with [param key] for [param id], or "" when it looks right.
## Checked before the first request, as OwnKey does: a typo comes back as a
## refusal seconds later and reads as the designer being broken.
static func problem_with(id: String, key: String) -> String:
	var preset: Dictionary = PRESETS.get(id, {})
	if preset.is_empty():
		return "There is no provider called %s." % id
	var tidy: String = key.strip_edges()
	if tidy.is_empty():
		return "Paste a key first." if bool(preset["needs_key"]) else ""
	if tidy.contains(" ") or tidy.contains("\n"):
		return "A key has no spaces in it."
	if tidy.begins_with(OwnKey.SUBSCRIPTION_PREFIX):
		return ("That is a Claude subscription's sign-in token, not an API key, and "
			+ "Anthropic does not allow apps to use one. To design on your plan, connect "
			+ "Claude to Brickworks instead.")
	var prefix: String = str(preset["prefix"])
	if not prefix.is_empty() and not tidy.begins_with(prefix):
		return "A %s key starts with %s." % [str(preset["name"]), prefix]
	if tidy.length() < 20:
		return "That looks too short to be a whole key."
	return ""


## Keys kept for this visit only, by provider: never written anywhere.
static var _this_visit: Dictionary = {}

## What every file FileAccess encrypts begins with, so a plain one (as the
## first slice kept keys) is told from it without asking FileAccess to
## decrypt it, which says a wrong guess in the console as an engine error.
const ENCRYPTED := "GDEC"
## The salt the key files' password is made with, made once on this device.
const SALT := "user://provider-salt"


static func key_file(id: String) -> String:
	return "user://provider-%s.key" % id.validate_filename()


## Whether a key for [param id] is kept on this device (not this visit's).
static func kept_on_device(id: String) -> bool:
	return FileAccess.file_exists(key_file(id))


## The key for [param id]: this visit's, else the one kept on this device,
## else (a command line's) the provider's environment variable.
static func load_key(id: String) -> String:
	if not str(_this_visit.get(id, "")).is_empty():
		return str(_this_visit[id])
	var kept: String = _read_kept(id)
	if not kept.is_empty():
		return kept
	var env: String = str(PRESETS.get(id, {}).get("env", ""))
	return OS.get_environment(env).strip_edges() if not env.is_empty() else ""


static func _read_kept(id: String) -> String:
	var path: String = key_file(id)
	if not FileAccess.file_exists(path):
		return ""
	var head: PackedByteArray = FileAccess.get_file_as_bytes(path).slice(0, 4)
	if head.get_string_from_ascii() != ENCRYPTED:
		# Kept plain by the first slice: read once, and kept again encrypted.
		var plain: String = FileAccess.get_file_as_string(path).strip_edges()
		if not plain.is_empty():
			_write_kept(id, plain)
		return plain
	var file: FileAccess = FileAccess.open_encrypted_with_pass(path, FileAccess.READ, _password())
	if file == null:
		# Another computer's, or this one's id changed: as good as no key.
		return ""
	var key: String = file.get_as_text().strip_edges()
	file.close()
	return key


static func _write_kept(id: String, key: String) -> bool:
	var file: FileAccess = FileAccess.open_encrypted_with_pass(key_file(id), FileAccess.WRITE,
		_password())
	if file == null:
		return false
	file.store_string(key)
	file.close()
	return true


## This computer's id and this device's salt, hashed: what the key files are
## encrypted with. A browser has no id to give (asking prints an error).
static func _password() -> String:
	var salt: String = ""
	if FileAccess.file_exists(SALT):
		salt = FileAccess.get_file_as_string(SALT).strip_edges()
	if salt.is_empty():
		salt = Crypto.new().generate_random_bytes(32).hex_encode()
		var file: FileAccess = FileAccess.open(SALT, FileAccess.WRITE)
		if file != null:
			file.store_string(salt)
			file.close()
	var machine: String = "" if OS.has_feature("web") else OS.get_unique_id()
	return ("brickworks:%s:%s" % [machine, salt]).sha256_text()


## Keep [param key] for [param id], on this device or for this visit only.
## Returns what to show when it cannot be, else "".
static func remember(id: String, key: String, on_device: bool = true) -> String:
	var problem: String = problem_with(id, key)
	if not problem.is_empty():
		return problem
	var tidy: String = key.strip_edges()
	if not on_device:
		_this_visit[id] = tidy
		if FileAccess.file_exists(key_file(id)):
			DirAccess.remove_absolute(key_file(id))
		return ""
	_this_visit.erase(id)
	if not _write_kept(id, tidy):
		return "Could not save the key on this device."
	return ""


static func forget(id: String) -> void:
	_this_visit.erase(id)
	if FileAccess.file_exists(key_file(id)):
		# On the web this path is the site's storage; DirAccess handles both.
		DirAccess.remove_absolute(key_file(id))


## Where the key in use came from: "visit", "device", "environment" or "".
static func key_source(id: String) -> String:
	if not str(_this_visit.get(id, "")).is_empty():
		return "visit"
	if not _read_kept(id).is_empty():
		return "device"
	return "environment" if not load_key(id).is_empty() else ""


## Where the key is kept and who could read it, said in the panel beside it,
## for a key from [param source] (key_source; "" for one not given yet).
static func custody(id: String, source: String = "device") -> String:
	var name: String = str(PRESETS.get(id, {}).get("name", id))
	var sent: String = ("Sent only to %s, never to Brickworks." % name) if id != "custom" \
		else "Sent only to the address above, never to Brickworks."
	if source == "visit":
		return "Kept for this visit only, nowhere on this device. " + sent
	if source == "environment":
		return ("Read from %s in the environment this app was started from; not kept by "
			% str(PRESETS[id]["env"]) + "Brickworks. Paste a key to keep one here instead. " + sent)
	if OS.has_feature("web"):
		return ("Kept in this browser's storage for this site, scrambled but not secret: "
			+ "anyone using this browser could recover it. Untick Remember on a shared "
			+ "computer. " + sent)
	return ("Kept on this computer only, in a file encrypted to it. Programs running as you "
		+ "could still reach it, so a key with a spending limit is safest. " + sent)


## Enough of a key to recognise, not enough to use: for logs and the panel.
static func fingerprint(key: String) -> String:
	if key.is_empty():
		return "no key"
	if key.length() < 16:
		return "…"
	return "%s…%s" % [key.substr(0, 6), key.substr(key.length() - 4)]


## Who designs: WHO_CLAUDE (as before) or WHO_KEY.
static func who() -> String:
	var who_is: String = str(_cfg().get_value("designer", "who", WHO_CLAUDE))
	return who_is if who_is == WHO_KEY else WHO_CLAUDE


static func set_who(who_is: String) -> void:
	var file: ConfigFile = _cfg()
	file.set_value("designer", "who", WHO_KEY if who_is == WHO_KEY else WHO_CLAUDE)
	file.save(where)


## Who designs, by the name a person knows it by: "Claude", or the model
## chosen on the person's key ("GPT-6.1 Sol"). The history's steps, the
## toolbar and the words that ask it say this (docs/PROVIDERS.md, P8).
static func designer_name() -> String:
	if who() != WHO_KEY:
		return "Claude"
	var kept: Dictionary = chosen()
	var named: String = model_name(str(kept["model"]))
	return named if not named.is_empty() else str(PRESETS[kept["provider"]]["name"])


## Pieces of a model's id said in capitals.
const CAPITALS: Array[String] = ["gpt", "glm"]
static var _snapshot := RegEx.create_from_string("^\\d{4,}$")
static var _point := RegEx.create_from_string("^\\d{1,2}$")


## [param model] by the name its maker gives it, read off its id: gpt-6.1-sol
## is GPT-6.1 Sol, claude-sonnet-5-5 Claude Sonnet 5.5, gemini-4-argon Gemini
## 4 Argon, and openai/gpt-6.1-sol on OpenRouter GPT-6.1 Sol. A snapshot's
## date is left off (gpt-6.1-sol-2026-09-30 is GPT-6.1 Sol), as the makers'
## own names leave it off.
static func model_name(model: String) -> String:
	var pieces: PackedStringArray = _bare(model).split("-", false)
	# o3 and o4-mini: OpenAI's own names for them are their ids.
	if not pieces.is_empty() and pieces[0].begins_with("o") and pieces[0].substr(1, 1).is_valid_int():
		return _bare(model)
	var out: String = ""
	var n: int = 0
	while n < pieces.size():
		var piece: String = pieces[n]
		if _snapshot.search(piece) != null:
			break
		if CAPITALS.has(piece.to_lower()):
			piece = piece.to_upper()
		elif _point.search(piece) != null and n + 1 < pieces.size() \
				and _point.search(pieces[n + 1]) != null:
			# claude-opus-5-5: version 5.5.
			piece += "." + pieces[n + 1]
			n += 1
		else:
			piece = piece.left(1).to_upper() + piece.substr(1)
		var joined: bool = out.ends_with("GPT") or out.ends_with("GLM")
		out += ("-" if joined else " " if not out.is_empty() else "") + piece
		n += 1
	return out if not out.is_empty() else model


## The choice as kept: {provider, model, base, params}, the provider's own.
static func chosen() -> Dictionary:
	var file: ConfigFile = _cfg()
	var id: String = str(file.get_value("designer", "provider", DEFAULT_PROVIDER))
	if not PRESETS.has(id):
		id = DEFAULT_PROVIDER
	var kept: Dictionary = settings_for(id, file)
	kept["provider"] = id
	return kept


## What is kept for provider [param id]: {model, base, params}. Each keeps its
## own, so going back to one finds it as it was left.
static func settings_for(id: String, file: ConfigFile = null) -> Dictionary:
	if file == null:
		file = _cfg()
	var models: Array = PRESETS.get(id, {}).get("models", [])
	var section: String = "provider." + id
	var params: Variant = file.get_value(section, "params", {})
	return {"model": str(file.get_value(section, "model", models[0] if not models.is_empty() else "")),
		"base": str(file.get_value(section, "base", "")),
		"params": params if params is Dictionary else {}}


static func choose(id: String, model: String, base: String = "", params: Dictionary = {}) -> void:
	var file: ConfigFile = _cfg()
	file.set_value("designer", "provider", id)
	var section: String = "provider." + id
	file.set_value(section, "model", model)
	file.set_value(section, "base", base.strip_edges())
	file.set_value(section, "params", params)
	file.save(where)


## The chosen provider's adapter, with its key: what designs when who() is
## WHO_KEY. Null for a provider with no adapter.
static func current() -> Provider:
	var kept: Dictionary = chosen()
	var id: String = str(kept["provider"])
	return provider_for(id, str(kept["model"]), load_key(id), str(kept["base"]),
		kept["params"])


## Why a design cannot start with the chosen provider, in words for the
## person, or "" when it can.
static func not_ready() -> String:
	var kept: Dictionary = chosen()
	var id: String = str(kept["provider"])
	var preset: Dictionary = PRESETS[id]
	if str(preset["base"]).is_empty() and str(kept["base"]).is_empty():
		return "Give the server's address in Settings, AI."
	var key: String = load_key(id)
	if bool(preset["needs_key"]) and key.is_empty():
		return "Paste your %s key in Settings, AI." % str(preset["name"])
	if not key.is_empty():
		var problem: String = problem_with(id, key)
		if not problem.is_empty():
			return problem
	var model: String = str(kept["model"])
	if model.is_empty():
		return "Choose a model in Settings, AI."
	var test: Dictionary = tested(id, model, str(kept["base"]))
	if test.has("tools") and not bool(test["tools"]):
		return ("%s did not call a tool when tested, and a design is nothing but tool calls. "
			% model + "Choose another model in Settings, AI.")
	return ""


## What Test found for [param model] at [param id] (and [param base], for a
## server of the person's): {tools, pictures, words, when}, or {}.
static func tested(id: String, model: String, base: String = "") -> Dictionary:
	var found: Variant = (_cfg().get_value("tested", "results", {}) as Dictionary).get(
		_test_name(id, model, base), {})
	return found if found is Dictionary else {}


static func keep_test(id: String, model: String, base: String, result: Dictionary) -> void:
	var file: ConfigFile = _cfg()
	var results: Dictionary = file.get_value("tested", "results", {})
	results[_test_name(id, model, base)] = {"tools": bool(result.get("tools", false)),
		"pictures": bool(result.get("pictures", false)), "words": str(result.get("words", "")),
		"when": Time.get_datetime_string_from_system(true)}
	file.set_value("tested", "results", results)
	file.save(where)


static func _test_name(id: String, model: String, base: String) -> String:
	return "%s|%s|%s" % [id, base.strip_edges(), model]


## Model ids that reason, where the provider's own list does not say: OpenAI's
## o-series and GPT-5 on, Gemini 2.5 on, Claude 4 on, and the open ones that
## say so in their names.
static var _reasons := RegEx.create_from_string(
	"^(o[1-9]|gpt-([5-9]|\\d\\d)|gemini-(2\\.5|[3-9])|claude-(opus|sonnet)-([4-9]|\\d\\d)"
	+ "|deepseek-(reasoner|r1)|grok-(3-mini|[4-9])|qwen3|magistral|kimi-k\\d+-thinking)")
## OpenAI's reasoning models, which refuse a temperature of their own.
static var _fixed_temperature := RegEx.create_from_string("^(o[1-9]|gpt-([5-9]|\\d\\d))")


## Whether [param model] takes a reasoning effort: what its listing
## ([param info], read_models') says, else what its name says.
static func takes_effort(model: String, info: Dictionary = {}) -> bool:
	var params: Array = info.get("params", []) if info.get("params") is Array else []
	if not params.is_empty():
		return params.has("reasoning") or params.has("reasoning_effort")
	return _reasons.search(_bare(model)) != null


## Whether [param model] takes a temperature: its listing's word, else all
## but OpenAI's reasoning models.
static func takes_temperature(model: String, info: Dictionary = {}) -> bool:
	var params: Array = info.get("params", []) if info.get("params") is Array else []
	if not params.is_empty():
		return params.has("temperature")
	return _fixed_temperature.search(_bare(model)) == null


## A model's id without the host's prefix: "openai/gpt-6.1-sol" is gpt-6.1-sol.
static func _bare(model: String) -> String:
	return model.to_lower().get_slice("/", model.count("/"))


static func _cfg() -> ConfigFile:
	var file := ConfigFile.new()
	if FileAccess.file_exists(where):
		file.load(where)
	return file
