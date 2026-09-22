class_name SaveService
extends RefCounted

const SAVE_PATH := "user://synapse_save.json"

static func defaults() -> Dictionary:
	return {
		"version": 2,
		"gene_shards": 0,
		"owned_packs": ["base"],
		"owned_gene_cards": [],
		"perks": {},
		"deck": GameData.BASE_CARD_IDS.duplicate(),
		"tutorial_seen": false,
		"last_difficulty": "normal",
		"best_wave": {"easy": 0, "normal": 0, "hardcore": 0},
		"completed_levels": [],
		"campaign_best": [0, 0, 0, 0, 0],
		"endless_best": [0, 0, 0, 0, 0],
		"sound_volume": 0.7,
		"music_volume": 0.45
	}

static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return defaults()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return defaults()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return defaults()
	return normalize_data(parsed)

static func normalize_data(parsed: Dictionary) -> Dictionary:
	var fallback := defaults()
	parsed = parsed.duplicate(true)
	for key in fallback:
		if not parsed.has(key):
			parsed[key] = fallback[key]
	if not parsed["owned_gene_cards"] is Array:
		parsed["owned_gene_cards"] = []
	if not parsed["perks"] is Dictionary:
		parsed["perks"] = {}
	for id in GameData.PERK_IDS:
		parsed["perks"][id] = clampi(int(parsed["perks"].get(id, 0)), 0, 3)
	if not parsed["best_wave"] is Dictionary:
		parsed["best_wave"] = fallback["best_wave"]
	else:
		for mode in fallback["best_wave"]:
			if not parsed["best_wave"].has(mode):
				parsed["best_wave"][mode] = 0
	if not parsed["completed_levels"] is Array:
		parsed["completed_levels"] = []
	else:
		var completed: Array[int] = []
		for level in range(1, LevelData.LEVEL_COUNT + 1):
			if level in parsed["completed_levels"] and (level == 1 or level - 1 in completed):
				completed.append(level)
		parsed["completed_levels"] = completed
	for key in ["campaign_best", "endless_best"]:
		if not parsed[key] is Array:
			parsed[key] = fallback[key].duplicate()
		else:
			var scores: Array[int] = []
			for index in range(LevelData.LEVEL_COUNT):
				scores.append(maxi(0, int(parsed[key][index])) if index < parsed[key].size() else 0)
			parsed[key] = scores
	parsed["version"] = 2
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
	for id in GameData.GENE_CARD_IDS:
		if id in data.get("owned_gene_cards", []):
			result.append(id)
	return result

static func level_unlocked(data: Dictionary, level: int) -> bool:
	return level >= 1 and level <= LevelData.LEVEL_COUNT and (level == 1 or level - 1 in data.get("completed_levels", []))

static func endless_unlocked(data: Dictionary, level: int) -> bool:
	return level in data.get("completed_levels", [])

static func complete_level(data: Dictionary, level: int) -> void:
	if level_unlocked(data, level) and level not in data["completed_levels"]:
		data["completed_levels"].append(level)

static func unlocked_towers(data: Dictionary) -> Array[StringName]:
	var result: Array[StringName] = [&"relay", &"arc", &"cryo", &"lance"]
	if 2 in data.get("completed_levels", []): result.append(&"mortar")
	if 4 in data.get("completed_levels", []): result.append(&"rift")
	return result

static func valid_loadout(data: Dictionary, selected: Array) -> bool:
	if selected.size() != 3:
		return false
	var unlocked := unlocked_towers(data)
	var seen: Array[StringName] = []
	for raw_type in selected:
		var type := StringName(raw_type)
		if type not in unlocked or type in seen:
			return false
		seen.append(type)
	return true

static func record_wave(data: Dictionary, level: int, wave: int, endless: bool) -> void:
	if level < 1 or level > LevelData.LEVEL_COUNT:
		return
	var key := "endless_best" if endless else "campaign_best"
	data[key][level - 1] = maxi(int(data[key][level - 1]), wave)

static func perk_level(data: Dictionary, id: String) -> int:
	if id not in GameData.PERK_IDS:
		return 0
	return clampi(int(data.get("perks", {}).get(id, 0)), 0, 3)

static func gene_card_purchase(data: Dictionary, id: String) -> Dictionary:
	if id not in GameData.GENE_CARD_IDS or id in data.get("owned_gene_cards", []):
		return {}
	if int(data.get("gene_shards", 0)) < GameData.GENE_CARD_COST:
		return {}
	var updated := data.duplicate(true)
	updated["gene_shards"] = int(updated["gene_shards"]) - GameData.GENE_CARD_COST
	updated["owned_gene_cards"].append(id)
	return updated

static func perk_purchase(data: Dictionary, id: String) -> Dictionary:
	if id not in GameData.PERK_IDS:
		return {}
	var level := perk_level(data, id)
	if level >= 3 or int(data.get("gene_shards", 0)) < int(GameData.PERK_COSTS[level]):
		return {}
	var updated := data.duplicate(true)
	updated["gene_shards"] = int(updated["gene_shards"]) - int(GameData.PERK_COSTS[level])
	if not updated.has("perks") or not updated["perks"] is Dictionary:
		updated["perks"] = {}
	updated["perks"][id] = level + 1
	return updated
