## Which provider designs, on which model, at which address, with whose key.
##
## Brickworks designs with Claude on the person's own plan (the connector, or
## Claude Code here), or with any provider's model on the person's own key:
## this file is the second. A provider is a preset (where its API is, what its
## keys look like, which adapter speaks it) or "custom", any server that
## speaks OpenAI's Chat Completions at an address the person gives.
##
## The key, exactly as OwnKey keeps Anthropic's:
##
##   It goes from this machine to the provider's own address and nowhere
##   else. No server of ours is in the path; nothing of ours logs it.
##
##   It is kept on this device, one file per provider in the app's own data
##   (user://), so it need not be typed again; or for this visit only, kept
##   nowhere. Anything running as the person can read the file: convenience,
##   not a vault. Forgetting it removes the file.
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
	"openai": {"name": "OpenAI", "adapter": "openai_chat",
		"base": "https://api.openai.com/v1", "prefix": "sk-", "env": "OPENAI_API_KEY",
		"needs_key": true, "models": ["gpt-6.1-sol", "gpt-6-astra", "gpt-6.1-terra"]},
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

## Where the choice is kept: provider, model, base address, parameters. Not
## the key, which has a file of its own (key_file).
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


static func key_file(id: String) -> String:
	return "user://provider-%s.key" % id.validate_filename()


## The key for [param id]: this visit's, else the one kept on this device,
## else (a command line's) the provider's environment variable.
static func load_key(id: String) -> String:
	if not str(_this_visit.get(id, "")).is_empty():
		return str(_this_visit[id])
	var file: FileAccess = FileAccess.open(key_file(id), FileAccess.READ)
	if file != null:
		var kept: String = file.get_as_text().strip_edges()
		file.close()
		if not kept.is_empty():
			return kept
	var env: String = str(PRESETS.get(id, {}).get("env", ""))
	return OS.get_environment(env).strip_edges() if not env.is_empty() else ""


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
	var file: FileAccess = FileAccess.open(key_file(id), FileAccess.WRITE)
	if file == null:
		return "Could not save the key on this device."
	file.store_string(tidy)
	file.close()
	return ""


static func forget(id: String) -> void:
	_this_visit.erase(id)
	if FileAccess.file_exists(key_file(id)):
		DirAccess.remove_absolute(key_file(id))


## Enough of a key to recognise, not enough to use: for logs and the panel.
static func fingerprint(key: String) -> String:
	if key.is_empty():
		return "no key"
	if key.length() < 16:
		return "…"
	return "%s…%s" % [key.substr(0, 6), key.substr(key.length() - 4)]


## The choice as kept: {provider, model, base, params}.
static func chosen() -> Dictionary:
	var file := ConfigFile.new()
	file.load(where)
	var id: String = str(file.get_value("designer", "provider", DEFAULT_PROVIDER))
	if not PRESETS.has(id):
		id = DEFAULT_PROVIDER
	var models: Array = PRESETS[id]["models"]
	return {"provider": id,
		"model": str(file.get_value("designer", "model", models[0] if not models.is_empty() else "")),
		"base": str(file.get_value("designer", "base", "")),
		"params": file.get_value("designer", "params", {})}


static func choose(id: String, model: String, base: String = "", params: Dictionary = {}) -> void:
	var file := ConfigFile.new()
	file.load(where)
	file.set_value("designer", "provider", id)
	file.set_value("designer", "model", model)
	file.set_value("designer", "base", base)
	file.set_value("designer", "params", params)
	file.save(where)
