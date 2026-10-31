extends Node

# Language: which locale the game shows, remembered between runs (user://settings.cfg).
# The words themselves live in res://localization/strings.csv (one column per language);
# code calls tr("English text") and Godot swaps in the current language.
# Lora and Cinzel have no Japanese letters, so Shippori Mincho is added as a fallback to
# every game font: Latin text keeps its look, kana and kanji come from the fallback.

const SETTINGS := "user://settings.cfg"
const LOCALES := ["en", "es", "pt_BR", "ja"]
const LABELS := {"en": "English", "es": "Español", "pt_BR": "Português (Brasil)", "ja": "日本語"}
const FONT_DIR := "res://assets/fonts"
const JP_REGULAR := "res://assets/fonts/ShipporiMincho/ShipporiMincho-Regular.ttf"
const JP_BOLD := "res://assets/fonts/ShipporiMincho/ShipporiMincho-Bold.ttf"

var locale := "en"


func _ready() -> void:
	_add_font_fallbacks()
	var cfg := ConfigFile.new()
	var saved := ""
	if cfg.load(SETTINGS) == OK:
		saved = str(cfg.get_value("game", "locale", ""))
	set_locale(saved if saved in LOCALES else _system_locale(), false)


func set_locale(new_locale: String, save := true) -> void:
	locale = new_locale if new_locale in LOCALES else "en"
	TranslationServer.set_locale(locale)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS)  # Keep any other settings already in the file
		cfg.set_value("game", "locale", locale)
		cfg.save(SETTINGS)


func next_locale() -> void:
	set_locale(LOCALES[(LOCALES.find(locale) + 1) % LOCALES.size()])


func locale_label() -> String:
	return LABELS.get(locale, locale)


# First run: follow the computer's language when we have it (English otherwise).
# After that, the last language picked on the title screen.
func _system_locale() -> String:
	var lang := OS.get_locale_language()
	if lang == "ja":
		return "ja"
	if lang == "pt":
		return "pt_BR"
	if lang == "es":
		return "es"
	return "en"


# The flag shown next to the language name on the title screen
func flag() -> Texture2D:
	return load("res://assets/ui/flags/%s.png" % locale) as Texture2D


func _add_font_fallbacks() -> void:
	var regular := load(JP_REGULAR) as Font
	var bold := load(JP_BOLD) as Font
	if regular == null:
		push_warning("Lang: Japanese font missing")
		return
	for path in _font_files(FONT_DIR):
		if path.contains("ShipporiMincho"):
			continue
		var font := load(path) as Font
		if font == null:
			continue
		var jp := bold if (bold and (path.contains("Bold") or path.contains("Cinzel"))) else regular
		var fallbacks := font.fallbacks
		if not fallbacks.has(jp):
			fallbacks.append(jp)
			font.fallbacks = fallbacks
	# Text drawn without a theme font (rare) uses the engine default
	if ThemeDB.fallback_font and not ThemeDB.fallback_font.fallbacks.has(regular):
		var defaults := ThemeDB.fallback_font.fallbacks
		defaults.append(regular)
		ThemeDB.fallback_font.fallbacks = defaults


# Every .ttf/.otf under a folder (list_directory also works in exported builds)
func _font_files(dir: String) -> Array[String]:
	var found: Array[String] = []
	for entry in ResourceLoader.list_directory(dir):
		if entry.ends_with("/"):
			found.append_array(_font_files(dir.path_join(entry.trim_suffix("/"))))
		elif entry.get_extension().to_lower() in ["ttf", "otf"]:
			found.append(dir.path_join(entry))
	return found


# ---------- Helpers for sentences built from pieces ----------

# Portuguese and Spanish merge a preposition with the article that follows it. Place names are
# translated with their article ("a clínica"), so "perto de {place}" first comes out as
# "perto de a clínica"; this turns it into "perto da clínica".
const CONTRACTIONS := {
	"pt_BR": [[" de a ", " da "], [" de o ", " do "], [" em a ", " na "], [" em o ", " no "],
			[" a a ", " à "], [" a o ", " ao "], [" por a ", " pela "], [" por o ", " pelo "]],
	"es": [[" de el ", " del "], [" a el ", " al "]],
}

# ---------- Grammatical gender (Portuguese, Spanish) ----------
# English and Japanese say "Let me examine you" the same way to anyone; Portuguese and Spanish
# don't (examiná-lo / examiná-la). Lines that change with the person they're about, or the
# person speaking, have a second row in strings.csv whose key ends in " [f]". Code that knows
# who it is talking about calls g() instead of tr(); without a feminine row it falls back.
const FEMININE := " [f]"

func g(text: String, female: bool) -> String:
	if female:
		var key := text + FEMININE
		var feminine := TranslationServer.translate(key)
		if feminine != key:
			return feminine
	return TranslationServer.translate(text)


# Whether a townsperson (by name) is a woman; names outside the town count as men (Jonas)
func female_of(person: String) -> bool:
	for npc in get_tree().get_nodes_in_group("npcs"):
		if npc.data and npc.data.npc_name == person:
			return npc.data.female
	return false


func contract(text: String) -> String:
	for pair in CONTRACTIONS.get(locale, []):
		text = text.replace(pair[0], pair[1])
	return text


# Portuguese and Spanish use the 24-hour clock ("18:00"); English and Japanese say AM/PM
func clock_24h() -> bool:
	return locale in ["pt_BR", "es"]


# Sentences one after another: a space in most languages, nothing in Japanese
func join_sentences(parts: Array) -> String:
	return ("" if locale == "ja" else " ").join(PackedStringArray(parts))


# Exam readings are stored in English ("88, quick", "chalk dust (wrist)"): the number stays,
# the words are translated
func value(reading) -> String:
	var text := str(reading)
	if text.ends_with(" (wrist)"):
		return value(text.trim_suffix(" (wrist)")) + " " + tr("(wrist)")
	var comma := text.find(", ")
	if comma > 0 and text.left(comma).is_valid_int():
		return text.left(comma) + ", " + tr(text.substr(comma + 2))
	return tr(text)
