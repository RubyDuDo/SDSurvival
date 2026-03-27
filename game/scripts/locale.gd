## 多语言管理：加载CSV翻译并注册到TranslationServer
extends Node

func _ready() -> void:
	_load_translations("res://locales/translations.csv")
	TranslationServer.set_locale("en")


func _load_translations(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open translation file: %s" % path)
		return

	var header := file.get_csv_line()
	if header.size() < 2:
		push_error("Invalid translation CSV header")
		return

	var translations: Dictionary = {}
	for i in range(1, header.size()):
		var t := Translation.new()
		t.locale = header[i].strip_edges()
		translations[t.locale] = t

	while not file.eof_reached():
		var line := file.get_csv_line()
		if line.size() < 2 or line[0].strip_edges().is_empty():
			continue
		var key := line[0].strip_edges()
		for i in range(1, mini(line.size(), header.size())):
			var locale: String = header[i].strip_edges()
			if translations.has(locale):
				var value := line[i].replace("\\n", "\n").replace("\r", "")
				(translations[locale] as Translation).add_message(key, value)

	for locale in translations:
		TranslationServer.add_translation(translations[locale])


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)


func get_locale() -> String:
	return TranslationServer.get_locale()


func is_english() -> bool:
	return TranslationServer.get_locale().begins_with("en")
