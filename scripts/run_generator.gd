class_name RunGenerator
extends RefCounted

const WAVE_BUDGETS := [10.0, 14.0, 19.0, 25.0, 32.0, 40.0, 49.0, 59.0, 70.0, 82.0]

static func generate_run(seed_value: int, level: int = 1) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	for wave_number in range(1, GameData.MAX_WAVES + 1):
		waves.append(generate_wave(seed_value, wave_number, level))
	return waves

static func available_types(level: int, wave_number: int) -> Array[StringName]:
	var available: Array[StringName] = [&"crawler"]
	if wave_number >= 2: available.append(&"skitter")
	if level >= 2 and wave_number >= 3: available.append(&"husk")
	if level >= 3 and wave_number >= 3: available.append(&"splitter")
	if level >= 3 and wave_number >= 4: available.append(&"phase")
	if level >= 4 and wave_number >= 5: available.append(&"leech")
	if level >= 5 and wave_number >= 3: available.append(&"conductor")
	return available

static func generate_wave(seed_value: int, wave_number: int, level: int = 1, endless: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + wave_number * 104729 + level * 65537
	var definitions := GameData.enemy_definitions()
	var available := available_types(level, wave_number)
	var extra_waves := maxi(0, wave_number - GameData.MAX_WAVES) if endless else 0
	var base_budget: float = WAVE_BUDGETS[mini(wave_number, GameData.MAX_WAVES) - 1]
	var level_multiplier := 0.6 + 0.2 * (level - 1)
	var budget: float = (base_budget + extra_waves * 5.0) * level_multiplier
	var entries: Array[Dictionary] = []
	var current_time := 0.0
	if (level == LevelData.LEVEL_COUNT and wave_number == 10) or (endless and wave_number >= 20 and wave_number % 10 == 0):
		entries.append({"time": 2.0, "type": &"severer", "lane": rng.randi_range(0, 1)})
		budget -= 20.0
	if wave_number == 3 and level >= 3:
		var introduction: StringName = &"conductor" if level >= 5 else &"splitter"
		entries.append({"time": 1.0, "type": introduction, "lane": rng.randi_range(0, 1)})
		budget -= float(definitions[introduction]["threat"])
	var safety := 0
	while budget >= 0.95 and safety < 60:
		safety += 1
		var candidates: Array[StringName] = []
		for type in available:
			if float(definitions[type]["threat"]) <= budget + 0.15:
				candidates.append(type)
		if candidates.is_empty():
			break
		var type := candidates[rng.randi_range(0, candidates.size() - 1)]
		if type == &"leech" and _count_type(entries, &"leech") >= maxi(1, int(entries.size() * 0.3)):
			type = &"crawler"
		budget -= float(definitions[type]["threat"])
		current_time += rng.randf_range(0.42, 1.05)
		entries.append({"time": current_time, "type": type, "lane": rng.randi_range(0, 1)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["time"]) < float(b["time"]))
	var hp_scale := (1.0 + 0.08 * (level - 1)) * minf(1000000.0, pow(1.14, extra_waves))
	return {
		"wave": wave_number,
		"seed": seed_value,
		"budget": (base_budget + extra_waves * 5.0) * level_multiplier,
		"hp_scale": hp_scale,
		"speed_scale": minf(1.5, 1.0 + extra_waves * 0.015),
		"entries": entries
	}

static func summarize(wave: Dictionary) -> Dictionary:
	var counts := {}
	var lanes := [0, 0]
	for entry in wave["entries"]:
		var type: StringName = entry["type"]
		counts[type] = int(counts.get(type, 0)) + 1
		lanes[int(entry["lane"])] += 1
	return {"counts": counts, "lanes": lanes, "total": wave["entries"].size()}

static func _count_type(entries: Array[Dictionary], type: StringName) -> int:
	var count := 0
	for entry in entries:
		if entry["type"] == type:
			count += 1
	return count
