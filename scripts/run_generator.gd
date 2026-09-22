class_name RunGenerator
extends RefCounted

const WAVE_BUDGETS := [10.0, 14.0, 19.0, 25.0, 32.0, 40.0, 49.0, 59.0, 70.0, 45.0]

static func generate_run(seed_value: int) -> Array[Dictionary]:
	var waves: Array[Dictionary] = []
	for wave_number in range(1, GameData.MAX_WAVES + 1):
		waves.append(generate_wave(seed_value, wave_number))
	return waves

static func generate_wave(seed_value: int, wave_number: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + wave_number * 104729
	var definitions := GameData.enemy_definitions()
	var available: Array[StringName] = [&"crawler"]
	if wave_number >= 2: available.append(&"skitter")
	if wave_number >= 3: available.append(&"husk")
	if wave_number >= 4: available.append(&"phase")
	if wave_number >= 5: available.append(&"leech")
	var budget: float = WAVE_BUDGETS[wave_number - 1]
	var entries: Array[Dictionary] = []
	var current_time := 0.0
	if wave_number == 10:
		entries.append({"time": 2.0, "type": &"severer", "lane": rng.randi_range(0, 1)})
		current_time = 0.0
	var safety := 0
	while budget >= 0.95 and safety < 200:
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
	return {
		"wave": wave_number,
		"seed": seed_value,
		"budget": WAVE_BUDGETS[wave_number - 1] + (20.0 if wave_number == 10 else 0.0),
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
