class_name SaveService
extends RefCounted

const SAVE_PATH := "user://synapse_save.json"

static func defaults() -> Dictionary:
	return {
		"version": 1,
		"gene_shards": 0,
		"owned_packs": ["base"],
		"deck": GameData.BASE_CARD_IDS.duplicate(),
		"tutorial_seen": false,
		"last_difficulty": "normal",
		"best_wave": {"easy": 0, "normal": 0, "hardcore": 0},
		"sound_volume": 0.7,
		"music_volume": 0.45
	}

static func load_data() -> Dictionary:
	var fallback := defaults()
	if not FileAccess.file_exists(SAVE_PATH):
		return fallback
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return fallback
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return fallback
	for key in fallback:
		if not parsed.has(key):
			parsed[key] = fallback[key]
	if not parsed["best_wave"] is Dictionary:
		parsed["best_wave"] = fallback["best_wave"]
	else:
		for mode in fallback["best_wave"]:
			if not parsed["best_wave"].has(mode):
				parsed["best_wave"][mode] = 0
	return parsed

static func save_data(data: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(data, "  "))
	return true

static func owned_card_ids(data: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for id in GameData.BASE_CARD_IDS:
		result.append(id)
	if "advanced_network_pack" in data.get("owned_packs", []):
		for id in GameData.ADVANCED_CARD_IDS:
			result.append(id)
	return result

