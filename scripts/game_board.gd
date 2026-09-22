class_name GameBoard
extends Control

signal charge_changed(value: int)
signal integrity_changed(value: int)
signal wave_finished
signal run_failed(wave_reached: int)
signal node_selected(node_id: int)
signal message_requested(text: String)
signal sfx_requested(event: StringName)
signal coverage_changed
signal specialization_state_changed
signal objective_changed(status: StringName)

const CELL_SIZE := 64.0
const LINK_WIDTH := 0.42
const LANCE_ICON_FORWARD := Vector2(-1.0, -1.0)
const SHIELD_RADIUS := CELL_SIZE * 2.0
const SHIELD_INTERVAL := 4.0
const SHIELD_DURATION := 1.5
const SHIELD_DAMAGE_MULT := 0.65

var graph := NetworkGraph.new()
var charge := GameData.STARTING_CHARGE
var integrity := GameData.STARTING_INTEGRITY
var current_wave := 0
var difficulty := "normal"
var run_seed := 0
var level := 1
var wave_hp_scale := 1.0
var wave_speed_scale := 1.0
var permanent_perks: Dictionary = {}
var run_mutators: Array[String] = []

var selected_tower: StringName = &""
var selected_node_id := -1
var preview_cell := Vector2i(-1, -1)
var preview_parents: Array[int] = []
var preview_parent_index := 0
var coverage_enabled := true
var rewire_mode := false
var build_allowed := true
var combat_paused := false
var simulation_speed := 1
var wave_active := false
var objective: Dictionary = {}
var objective_status: StringName = &""
var objective_enemy_id := -1

var enemies: Array[Dictionary] = []
var pulses: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var rift_zones: Array[Dictionary] = []
var spawn_entries: Array[Dictionary] = []
var spawn_index := 0
var wave_time := 0.0
var world_time := 0.0
var pulse_timer := 0.0
var next_enemy_id := 1
var next_pulse_id := 1
var disabled_links: Dictionary = {}
var resonance_hits: Dictionary = {}
var _finish_delay := -1.0
var _paid_wave_number := -1

var top_path: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
	Vector2i(4, 1), Vector2i(4, 2), Vector2i(5, 2), Vector2i(6, 2),
	Vector2i(7, 2), Vector2i(8, 2), Vector2i(8, 3), Vector2i(9, 3),
	Vector2i(10, 3), Vector2i(11, 3), Vector2i(12, 3), Vector2i(13, 3),
	Vector2i(14, 3), Vector2i(15, 3)
]
var bottom_path: Array[Vector2i] = [
	Vector2i(0, 6), Vector2i(1, 6), Vector2i(2, 6), Vector2i(3, 6),
	Vector2i(4, 6), Vector2i(4, 5), Vector2i(5, 5), Vector2i(6, 5),
	Vector2i(7, 5), Vector2i(8, 5), Vector2i(8, 4), Vector2i(9, 4),
	Vector2i(10, 4), Vector2i(11, 4), Vector2i(12, 4), Vector2i(12, 3),
	Vector2i(13, 3), Vector2i(14, 3), Vector2i(15, 3)
]
var blocked_cells: Array[Vector2i] = [
	Vector2i(6, 0), Vector2i(10, 1), Vector2i(6, 7), Vector2i(10, 6)
]

func _ready() -> void:
	custom_minimum_size = Vector2(GameData.BOARD_COLUMNS * CELL_SIZE, GameData.BOARD_ROWS * CELL_SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	queue_redraw()

func configure(seed_value: int, difficulty_id: String, level_id: int = 1, perks: Dictionary = {}, mutators: Array = []) -> void:
	run_seed = seed_value
	difficulty = difficulty_id
	level = level_id
	var layout := LevelData.layout(level)
	top_path = layout["top_path"]
	bottom_path = layout["bottom_path"]
	blocked_cells = layout["blocked_cells"]
	permanent_perks = perks.duplicate(true)
	run_mutators = GameData.normalize_run_mutators(mutators)
	charge = GameData.STARTING_CHARGE + 10 * _perk_level("reserve_cells") - (60 if "lean_start" in run_mutators else 0)
	integrity = GameData.STARTING_INTEGRITY + _perk_level("core_lattice") - (6 if "fragile_core" in run_mutators else 0)
	graph = NetworkGraph.new()
	if "heavy_pulses" in run_mutators: graph.modifiers["core_interval_mult"] *= 1.5
	if "short_links" in run_mutators: graph.modifiers["link_range_bonus"] -= 0.75
	if "limited_core_ports" in run_mutators: graph.modifiers["core_children_bonus"] -= 1
	if "narrow_conduits" in run_mutators: graph.modifiers["link_width_mult"] *= 0.75
	graph.changed.connect(_on_graph_changed)
	rift_zones.clear()
	objective.clear()
	objective_status = &""
	objective_enemy_id = -1
	_paid_wave_number = -1
	charge_changed.emit(charge)
	integrity_changed.emit(integrity)
	queue_redraw()
	coverage_changed.emit()

func _on_graph_changed() -> void:
	queue_redraw()
	coverage_changed.emit()

func set_coverage_enabled(value: bool) -> void:
	coverage_enabled = value
	queue_redraw()
	coverage_changed.emit()

func _focused_edge() -> Dictionary:
	if preview_cell.x >= 0 and not preview_parents.is_empty() and not selected_tower.is_empty():
		return {"parent": preview_parents[preview_parent_index], "cell": preview_cell, "type": selected_tower, "preview": true}
	if selected_node_id > 0 and graph.nodes.has(selected_node_id):
		var node: Dictionary = graph.nodes[selected_node_id]
		return {"parent": int(node["parent"]), "cell": node["cell"], "type": node["type"], "preview": false, "id": selected_node_id}
	return {}

func _edge_interval(node_id: int) -> float:
	var interval := 1.2 * float(graph.modifiers["core_interval_mult"])
	var cursor := node_id
	while cursor > 0 and graph.nodes.has(cursor):
		var parent_id: int = graph.nodes[cursor]["parent"]
		if parent_id > 0:
			interval *= maxi(1, graph.nodes[parent_id]["children"].size())
		cursor = parent_id
	return interval

func coverage_snapshot() -> Dictionary:
	var edge := _focused_edge()
	if edge.is_empty():
		return {}
	var parent_id: int = edge["parent"]
	var parent: Dictionary = graph.nodes[parent_id]
	var preview: bool = edge["preview"]
	var children: Array = parent["children"]
	var count := children.size() + (1 if preview else 0)
	var parent_interval := _edge_interval(parent_id)
	var child_interval := parent_interval * (count if parent_id > 0 else 1)
	var rows: Array[String] = []
	for child_id in children:
		rows.append("%s %d: ~%.1fs" % [_node_name(child_id), child_id, child_interval])
	if preview:
		rows.append("NEW %s: ~%.1fs" % [str(GameData.tower_definitions()[edge["type"]]["name"]), child_interval])
	else:
		var id: int = edge["id"]
		var node_children: Array = graph.nodes[id]["children"]
		if not node_children.is_empty():
			rows.clear()
			var downstream_interval := _edge_interval(id) * (node_children.size() if id > 0 else 1)
			for child_id in node_children:
				rows.append("%s %d: ~%.1fs" % [_node_name(child_id), child_id, downstream_interval])
	return {
		"title": "NEW LINK" if preview else "%s %d" % [_node_name(int(edge["id"])), int(edge["id"])],
		"interval": child_interval if preview else _edge_interval(int(edge["id"])),
		"rows": rows,
		"warning": preview and parent_id > 0 and children.size() > 0,
		"lanes": _covered_lanes(_node_position(parent_id), _cell_center(edge["cell"]), edge["type"])
	}

func _covered_lanes(start: Vector2, finish: Vector2, tower_type: StringName) -> Array[bool]:
	var covered: Array[bool] = [false, false]
	if tower_type == &"relay":
		return covered
	var width := CELL_SIZE * LINK_WIDTH * float(graph.modifiers["link_width_mult"])
	for lane in range(2):
		var path := _path_for_lane(lane)
		for index in range(path.size() - 1):
			var a := _cell_center(path[index])
			var b := _cell_center(path[index + 1])
			var steps := maxi(1, ceili(a.distance_to(b) / 8.0))
			for step in range(steps + 1):
				if _distance_to_segment(a.lerp(b, float(step) / steps), start, finish) <= width:
					covered[lane] = true
					break
			if covered[lane]:
				break
	return covered

func _perk_level(id: String) -> int:
	return clampi(int(permanent_perks.get(id, 0)), 0, 3)

func set_selected_tower(type: StringName) -> void:
	selected_tower = type
	selected_node_id = -1
	rewire_mode = false
	preview_cell = Vector2i(-1, -1)
	preview_parents.clear()
	queue_redraw()
	coverage_changed.emit()

func clear_tool() -> void:
	selected_tower = &""
	rewire_mode = false
	preview_cell = Vector2i(-1, -1)
	preview_parents.clear()
	queue_redraw()
	coverage_changed.emit()

func set_build_allowed(value: bool) -> void:
	build_allowed = value
	if not value:
		clear_tool()
	queue_redraw()

func set_combat_paused(value: bool) -> void:
	combat_paused = value
	queue_redraw()

func start_wave(manifest: Dictionary) -> void:
	current_wave = int(manifest["wave"])
	objective = manifest.get("objective", {}).duplicate(true)
	objective_status = &"active" if not objective.is_empty() else &""
	objective_enemy_id = -1
	wave_hp_scale = float(manifest.get("hp_scale", 1.0))
	wave_speed_scale = float(manifest.get("speed_scale", 1.0))
	spawn_entries = manifest["entries"].duplicate(true)
	spawn_index = 0
	wave_time = 0.0
	pulse_timer = 0.0
	wave_active = true
	_finish_delay = -1.0
	_paid_wave_number = -1
	graph.reset_routing()
	resonance_hits.clear()
	objective_changed.emit(objective_status)
	sfx_requested.emit(&"launch")
	queue_redraw()

func cycle_preview_parent() -> void:
	if preview_parents.size() <= 1:
		return
	preview_parent_index = (preview_parent_index + 1) % preview_parents.size()
	message_requested.emit("Connection source: %s" % _node_name(preview_parents[preview_parent_index]))
	queue_redraw()
	coverage_changed.emit()

func begin_rewire(node_id: int) -> void:
	if not build_allowed or node_id <= 0 or not graph.nodes.has(node_id):
		return
	selected_tower = &""
	selected_node_id = node_id
	rewire_mode = true
	message_requested.emit("Tap a new parent node")
	queue_redraw()
	coverage_changed.emit()

func sell_node(node_id: int) -> void:
	if not build_allowed or node_id <= 0 or not graph.nodes.has(node_id):
		return
	var subtree: Array[int] = []
	_collect_subtree_preview(node_id, subtree)
	var refund := 0
	for id in subtree:
		refund += int(round(float(tower_cost(graph.nodes[id]["type"])) * (0.75 + 0.03 * _perk_level("reclamation"))))
	graph.remove_subtree(node_id)
	charge += refund
	selected_node_id = -1
	charge_changed.emit(charge)
	message_requested.emit("Recycled branch: +%d charge" % refund)
	sfx_requested.emit(&"recycle")
	queue_redraw()
	coverage_changed.emit()
	specialization_state_changed.emit()

func buy_specialization(node_id: int, choice: StringName) -> bool:
	if not build_allowed or charge < GameData.SPECIALIZATION_COST or not graph.can_specialize(node_id):
		return false
	if not graph.set_specialization(node_id, choice):
		return false
	charge -= GameData.SPECIALIZATION_COST
	charge_changed.emit(charge)
	specialization_state_changed.emit()
	message_requested.emit("Specialization integrated: %s" % GameData.specialization_definitions()[graph.nodes[node_id]["type"]][0 if choice == &"a" else 1]["name"])
	sfx_requested.emit(&"draft")
	queue_redraw()
	return true

func _collect_subtree_preview(node_id: int, output: Array[int]) -> void:
	output.append(node_id)
	for child_id in graph.nodes[node_id]["children"]:
		_collect_subtree_preview(child_id, output)

func tower_cost(tower_type: StringName) -> int:
	var base_cost := int(GameData.tower_definitions()[tower_type]["cost"])
	return ceili(base_cost * 1.2) if "costly_construction" in run_mutators else base_cost

func apply_card(card_id: String) -> void:
	graph.apply_modifier(card_id)
	message_requested.emit("Mutation integrated: %s" % GameData.card_definitions()[card_id]["name"])
	sfx_requested.emit(&"draft")
	queue_redraw()

func _process(delta: float) -> void:
	if combat_paused:
		queue_redraw()
		return
	if wave_active and simulation_speed > 1:
		var remaining := delta * simulation_speed
		while remaining > 0.0 and wave_active and not combat_paused and is_processing():
			var step := minf(remaining, 1.0 / 30.0)
			_advance_simulation(step)
			remaining -= step
	else:
		_advance_simulation(delta)
	queue_redraw()

func _advance_simulation(delta: float) -> void:
	world_time += delta
	_update_effects(delta)
	if wave_active:
		wave_time += delta
		pulse_timer -= delta
		if pulse_timer <= 0.0:
			pulse_timer += 1.2 * float(graph.modifiers["core_interval_mult"])
			_emit_core_pulses()
		_spawn_ready_enemies()
		_update_enemies(delta)
		_update_shielders()
		_update_rift_zones(delta)
		_update_pulses(delta)
		_prune_disabled_links()
		_check_wave_complete(delta)

func _spawn_ready_enemies() -> void:
	while spawn_index < spawn_entries.size() and float(spawn_entries[spawn_index]["time"]) <= wave_time:
		var entry: Dictionary = spawn_entries[spawn_index]
		var enemy_id := _spawn_enemy(entry["type"], int(entry["lane"]))
		if objective.get("kind", "") == "marked_kill" and spawn_index == int(objective["entry_index"]):
			objective_enemy_id = enemy_id
		spawn_index += 1

func _spawn_enemy(type: StringName, lane: int, segment: int = 0, segment_t: float = 0.0, hp_fraction: float = 1.0, reward_override: int = -1) -> int:
	var definition: Dictionary = GameData.enemy_definitions()[type]
	var health := float(definition["hp"]) * wave_hp_scale * hp_fraction * (1.25 if "armored_signals" in run_mutators else 1.0)
	var enemy := {
		"id": next_enemy_id, "type": type, "lane": lane,
		"segment": segment, "segment_t": segment_t, "position": _cell_center(_path_for_lane(lane)[0]),
		"hp": health, "max_hp": health, "reward_override": reward_override,
		"walk_distance": 0.0,
		"slow_until": 0.0, "slow_factor": 1.0, "root_until": 0.0,
		"marked_until": 0.0, "disable_cooldown": 0.0,
		"shield_until": 0.0, "next_shield_pulse": world_time + 0.75
	}
	enemy["position"] = _enemy_position(enemy)
	next_enemy_id += 1
	enemies.append(enemy)
	return int(enemy["id"])

func _update_enemies(delta: float) -> void:
	var leaked: Array[int] = []
	var conductors: Array[Vector2] = []
	for enemy in enemies:
		if enemy["type"] == &"conductor": conductors.append(enemy["position"])
	for index in range(enemies.size()):
		var enemy: Dictionary = enemies[index]
		if world_time >= float(enemy["root_until"]):
			var definition: Dictionary = GameData.enemy_definitions()[enemy["type"]]
			var speed := float(definition["speed"]) * wave_speed_scale
			if enemy["type"] != &"conductor":
				for conductor_position in conductors:
					if Vector2(enemy["position"]).distance_to(conductor_position) <= CELL_SIZE * 2.5:
						speed *= 1.3
						break
			if world_time < float(enemy["slow_until"]):
				speed *= float(enemy["slow_factor"])
			_advance_enemy(enemy, speed * delta)
		enemy["position"] = _enemy_position(enemy)
		if objective_status == &"active" and int(enemy["id"]) == objective_enemy_id:
			var midpoint := float(_path_for_lane(int(enemy["lane"])).size() - 1) * 0.5
			if _enemy_progress(enemy) >= midpoint:
				_set_objective_status(&"failed")
		if enemy["type"] == &"leech" or enemy["type"] == &"severer":
			_try_disable_link(enemy)
		if int(enemy["segment"]) >= _path_for_lane(int(enemy["lane"])).size() - 1:
			leaked.append(index)
		enemies[index] = enemy
	for reverse_index in range(leaked.size() - 1, -1, -1):
		var index: int = leaked[reverse_index]
		var type: StringName = enemies[index]["type"]
		if objective_status == &"active" and objective.get("kind", "") == "no_leaks" and int(enemies[index]["lane"]) == int(objective["lane"]):
			_set_objective_status(&"failed")
		integrity -= int(GameData.enemy_definitions()[type]["leak"])
		effects.append({"type": "burst", "position": _cell_center(GameData.CORE_CELL), "ttl": 0.5, "color": Color("ff397c")})
		enemies.remove_at(index)
		integrity_changed.emit(maxi(0, integrity))
		sfx_requested.emit(&"leak")
		if integrity <= 0:
			wave_active = false
			run_failed.emit(current_wave)
			return

func _update_shielders() -> void:
	for source_index in range(enemies.size()):
		var source: Dictionary = enemies[source_index]
		if source["type"] != &"shielder" or world_time < float(source["next_shield_pulse"]):
			continue
		source["next_shield_pulse"] = world_time + SHIELD_INTERVAL
		enemies[source_index] = source
		var center: Vector2 = source["position"]
		effects.append({"type": "shield_pulse", "position": center, "ttl": 0.4, "color": GameData.enemy_definitions()[&"shielder"]["color"]})
		for ally_index in range(enemies.size()):
			var ally: Dictionary = enemies[ally_index]
			if ally["type"] == &"shielder" or Vector2(ally["position"]).distance_to(center) > SHIELD_RADIUS:
				continue
			ally["shield_until"] = maxf(float(ally["shield_until"]), world_time + SHIELD_DURATION)
			enemies[ally_index] = ally

func _advance_enemy(enemy: Dictionary, distance_cells: float) -> void:
	var path := _path_for_lane(int(enemy["lane"]))
	var starting_progress := _enemy_progress(enemy)
	var remaining := distance_cells
	while remaining > 0.0 and int(enemy["segment"]) < path.size() - 1:
		var available := 1.0 - float(enemy["segment_t"])
		if remaining < available:
			enemy["segment_t"] = float(enemy["segment_t"]) + remaining
			remaining = 0.0
		else:
			remaining -= available
			enemy["segment"] = int(enemy["segment"]) + 1
			enemy["segment_t"] = 0.0
	enemy["walk_distance"] = float(enemy.get("walk_distance", 0.0)) + _enemy_progress(enemy) - starting_progress

func _enemy_position(enemy: Dictionary) -> Vector2:
	var path := _path_for_lane(int(enemy["lane"]))
	var segment := mini(int(enemy["segment"]), path.size() - 1)
	if segment >= path.size() - 1:
		return _cell_center(path[-1])
	return _cell_center(path[segment]).lerp(_cell_center(path[segment + 1]), float(enemy["segment_t"]))

func _enemy_direction(enemy: Dictionary) -> Vector2:
	var path := _path_for_lane(int(enemy["lane"]))
	if path.size() < 2:
		return Vector2.RIGHT
	var segment := mini(int(enemy["segment"]), path.size() - 2)
	return Vector2(path[segment + 1] - path[segment]).normalized()

func _emit_core_pulses() -> void:
	for child_id in graph.outgoing_for_pulse(0):
		_spawn_pulse(0, child_id)

func _spawn_pulse(from_id: int, to_id: int) -> void:
	if not graph.nodes.has(from_id) or not graph.nodes.has(to_id):
		return
	if _is_link_disabled(from_id, to_id):
		return
	pulses.append({
		"id": next_pulse_id, "from": from_id, "to": to_id,
		"progress": 0.0, "hit": {}, "resonated": {}
	})
	next_pulse_id += 1

func _update_pulses(delta: float) -> void:
	var arrived: Array[int] = []
	var pulse_speed := 5.0 * float(graph.modifiers["pulse_speed_mult"]) * (1.0 + 0.03 * _perk_level("signal_enzymes"))
	for index in range(pulses.size()):
		var pulse: Dictionary = pulses[index]
		if _is_link_disabled(int(pulse["from"]), int(pulse["to"])):
			arrived.append(index)
			continue
		var start := _node_position(int(pulse["from"]))
		var finish := _node_position(int(pulse["to"]))
		var distance_cells := start.distance_to(finish) / CELL_SIZE
		pulse["progress"] = float(pulse["progress"]) + delta * pulse_speed / maxf(0.1, distance_cells)
		_apply_link_effects(pulse, start, finish)
		pulses[index] = pulse
		if float(pulse["progress"]) >= 1.0:
			arrived.append(index)
	for reverse_index in range(arrived.size() - 1, -1, -1):
		var index: int = arrived[reverse_index]
		if index >= pulses.size():
			continue
		var pulse: Dictionary = pulses[index]
		if float(pulse["progress"]) >= 1.0:
			_on_pulse_arrived(int(pulse["to"]))
		pulses.remove_at(index)
	if bool(graph.modifiers["cross_synapse"]):
		_apply_cross_synapses()

func _apply_link_effects(pulse: Dictionary, start: Vector2, finish: Vector2) -> void:
	var progress := clampf(float(pulse["progress"]), 0.0, 1.0)
	var point := start.lerp(finish, progress)
	var width := CELL_SIZE * LINK_WIDTH * float(graph.modifiers["link_width_mult"])
	var node_type: StringName = graph.nodes[int(pulse["to"])]["type"]
	var specialization: StringName = graph.nodes[int(pulse["to"])].get("specialization", &"")
	if node_type == &"relay":
		return
	var hit: Dictionary = pulse["hit"]
	for index in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[index]
		var enemy_id: int = enemy["id"]
		if hit.has(enemy_id) or Vector2(enemy["position"]).distance_to(point) > width:
			continue
		hit[enemy_id] = true
		match node_type:
			&"arc":
				_damage_enemy(index, 18.0 if specialization == &"a" else 12.0, true)
			&"cryo":
				enemy["slow_until"] = world_time + (2.5 if specialization == &"a" else 1.5) + float(graph.modifiers["cryo_trail_bonus"])
				enemy["slow_factor"] = 0.4 if specialization == &"a" else 0.58
				enemies[index] = enemy
				_damage_enemy(index, 2.0, true)
			&"lance":
				enemy["marked_until"] = world_time + (3.0 if specialization == &"b" else 2.0)
				enemies[index] = enemy
				_damage_enemy(index, 4.0, true)
			&"mortar", &"rift":
				_damage_enemy(index, 6.0, true)
		effects.append({"type": "spark", "position": enemy["position"], "ttl": 0.22, "color": GameData.tower_definitions()[node_type]["color"]})
	pulse["hit"] = hit

func _on_pulse_arrived(node_id: int) -> void:
	if not graph.nodes.has(node_id):
		return
	var type: StringName = graph.nodes[node_id]["type"]
	if wave_active:
		graph.record_arrival(node_id, current_wave)
	match type:
		&"arc": _fire_arc(node_id)
		&"cryo": _fire_cryo(node_id)
		&"lance": _fire_lance(node_id)
		&"mortar": _fire_mortar(node_id)
		&"rift": _fire_rift(node_id)
	for child_id in graph.outgoing_for_pulse(node_id):
		_spawn_pulse(node_id, child_id)

func _fire_arc(node_id: int) -> void:
	var extra_targets := 2 if graph.nodes[node_id]["specialization"] == &"b" else 0
	var targets := _targets_in_range(_node_position(node_id), 2.5 + float(graph.modifiers["tower_range_bonus"]), 3 + extra_targets + int(graph.modifiers["arc_targets_bonus"]))
	var target_ids: Array[int] = []
	for index in targets:
		target_ids.append(int(enemies[index]["id"]))
	for enemy_id in target_ids:
		var index := _enemy_index_by_id(enemy_id)
		if index < 0: continue
		var target_position: Vector2 = enemies[index]["position"]
		_damage_enemy(index, 9.0, false)
		effects.append({"type": "line", "from": _node_position(node_id), "to": target_position, "ttl": 0.18, "color": Color("33c8ff")})
	if not targets.is_empty(): sfx_requested.emit(&"arc")

func _fire_cryo(node_id: int) -> void:
	var targets := _targets_in_range(_node_position(node_id), 2.6 + float(graph.modifiers["tower_range_bonus"]), 1)
	if targets.is_empty():
		return
	var index: int = targets[0]
	var enemy: Dictionary = enemies[index]
	enemy["root_until"] = maxf(float(enemy["root_until"]), world_time + (1.0 if graph.nodes[node_id]["specialization"] == &"b" else 0.45))
	enemy["slow_until"] = world_time + 1.5
	enemy["slow_factor"] = 0.58
	enemies[index] = enemy
	if bool(graph.modifiers["cryo_bloom"]):
		var center: Vector2 = enemy["position"]
		for other_index in range(enemies.size()):
			if other_index == index or Vector2(enemies[other_index]["position"]).distance_to(center) > CELL_SIZE * 0.75:
				continue
			var other: Dictionary = enemies[other_index]
			other["root_until"] = maxf(float(other["root_until"]), world_time + 0.25)
			enemies[other_index] = other
	_damage_enemy(index, 6.0, false)
	effects.append({"type": "burst", "position": enemy["position"], "ttl": 0.35, "color": Color("9c82ff")})
	sfx_requested.emit(&"cryo")

func _fire_lance(node_id: int) -> void:
	var node: Dictionary = graph.nodes[node_id]
	var parent_position := _node_position(int(node["parent"]))
	var node_position := _node_position(node_id)
	var direction := (node_position - parent_position).normalized()
	var beam_range := 6.0 + float(graph.modifiers["lance_range_bonus"]) + (2.0 if node["specialization"] == &"a" else 0.0)
	_fire_lance_segment(node_position, node_position + direction * beam_range * CELL_SIZE, node_id)
	if bool(graph.modifiers["bidirectional_lance"]):
		_fire_lance_segment(node_position, node_position - direction * beam_range * CELL_SIZE, node_id)
	sfx_requested.emit(&"lance")

func _fire_lance_segment(start: Vector2, finish: Vector2, node_id: int = -1) -> void:
	for index in range(enemies.size() - 1, -1, -1):
		if _distance_to_segment(enemies[index]["position"], start, finish) <= CELL_SIZE * (0.28 + float(graph.modifiers["lance_width_bonus"])):
			var amount := 24.0
			if world_time < float(enemies[index]["marked_until"]):
				amount *= 2.0 if node_id >= 0 and graph.nodes[node_id]["specialization"] == &"b" else 1.5
			_damage_enemy(index, amount, false)
	effects.append({"type": "line", "from": start, "to": finish, "ttl": 0.24, "color": Color("ff5ba7")})

func _fire_mortar(node_id: int) -> void:
	var targets := _targets_in_range(_node_position(node_id), 4.0 + float(graph.modifiers["tower_range_bonus"]), 1)
	if targets.is_empty(): return
	var center: Vector2 = enemies[targets[0]]["position"]
	var specialization: StringName = graph.nodes[node_id]["specialization"]
	for index in range(enemies.size() - 1, -1, -1):
		if Vector2(enemies[index]["position"]).distance_to(center) <= CELL_SIZE * (1.6 if specialization == &"a" else 1.15):
			_damage_enemy(index, 24.0 if specialization == &"b" else 20.0, false, specialization == &"b")
	effects.append({"type": "burst", "position": center, "ttl": 0.45, "color": Color("ffd166")})
	sfx_requested.emit(&"lance")

func _fire_rift(node_id: int) -> void:
	var targets := _targets_in_range(_node_position(node_id), 3.5 + float(graph.modifiers["tower_range_bonus"]), 1)
	if targets.is_empty(): return
	var specialization: StringName = graph.nodes[node_id]["specialization"]
	var duration := 4.0 if specialization == &"b" else 2.5
	rift_zones.append({
		"position": enemies[targets[0]]["position"], "ttl": duration, "duration": duration,
		"damage": 16.0 if specialization == &"b" else 13.0,
		"slow": specialization == &"a"
	})
	if rift_zones.size() > 12: rift_zones.remove_at(0)
	sfx_requested.emit(&"cryo")

func _update_rift_zones(delta: float) -> void:
	for zone_index in range(rift_zones.size() - 1, -1, -1):
		var zone: Dictionary = rift_zones[zone_index]
		for enemy_index in range(enemies.size() - 1, -1, -1):
			if Vector2(enemies[enemy_index]["position"]).distance_to(zone["position"]) <= CELL_SIZE * 1.25:
				if bool(zone["slow"]):
					var enemy: Dictionary = enemies[enemy_index]
					var already_slowed := world_time < float(enemy["slow_until"])
					enemy["slow_until"] = maxf(float(enemy["slow_until"]), world_time + 0.2)
					enemy["slow_factor"] = minf(float(enemy["slow_factor"]), 0.7) if already_slowed else 0.7
					enemies[enemy_index] = enemy
				_damage_enemy(enemy_index, float(zone["damage"]) * delta, false)
		zone["ttl"] = float(zone["ttl"]) - delta
		if float(zone["ttl"]) <= 0.0: rift_zones.remove_at(zone_index)
		else: rift_zones[zone_index] = zone

func _targets_in_range(origin: Vector2, radius_cells: float, limit: int) -> Array[int]:
	var candidates: Array[int] = []
	for index in range(enemies.size()):
		if origin.distance_to(enemies[index]["position"]) <= radius_cells * CELL_SIZE:
			candidates.append(index)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		return _enemy_progress(enemies[a]) > _enemy_progress(enemies[b])
	)
	if candidates.size() > limit:
		candidates.resize(limit)
	return candidates

func _damage_enemy(index: int, raw_amount: float, from_link: bool, ignore_armor: bool = false) -> void:
	if index < 0 or index >= enemies.size():
		return
	var enemy: Dictionary = enemies[index]
	var amount := raw_amount * (1.5 if "heavy_pulses" in run_mutators else 1.0)
	if enemy["type"] == &"husk" and not from_link and not ignore_armor:
		amount *= 0.55
	if enemy["type"] == &"phase" and from_link:
		amount *= 0.5
	if from_link and bool(graph.modifiers["conductive_mark"]) and world_time < float(enemy["marked_until"]):
		amount *= 1.25
	if world_time < float(enemy["shield_until"]):
		amount *= SHIELD_DAMAGE_MULT
	enemy["hp"] = float(enemy["hp"]) - amount
	if float(enemy["hp"]) <= 0.0:
		if objective_status == &"active" and int(enemy["id"]) == objective_enemy_id:
			var midpoint := float(_path_for_lane(int(enemy["lane"])).size() - 1) * 0.5
			_set_objective_status(&"complete" if _enemy_progress(enemy) < midpoint else &"failed")
		var definition: Dictionary = GameData.enemy_definitions()[enemy["type"]]
		charge += int(enemy["reward_override"]) if int(enemy.get("reward_override", -1)) >= 0 else int(definition["reward"])
		charge_changed.emit(charge)
		effects.append({"type": "burst", "position": enemy["position"], "ttl": 0.4, "color": definition["color"]})
		enemies.remove_at(index)
		if enemy["type"] == &"splitter":
			for child in range(2):
				_spawn_enemy(&"crawler", int(enemy["lane"]), int(enemy["segment"]), float(enemy["segment_t"]), 0.45, 0)
		sfx_requested.emit(&"enemy_down")
	else:
		enemies[index] = enemy

func _try_disable_link(enemy: Dictionary) -> void:
	if world_time < float(enemy["disable_cooldown"]):
		return
	for child_id in graph.nodes:
		if child_id == 0: continue
		var parent_id: int = graph.nodes[child_id]["parent"]
		var start := _node_position(parent_id)
		var finish := _node_position(child_id)
		if _distance_to_segment(enemy["position"], start, finish) <= CELL_SIZE * 0.25:
			var duration := (4.0 if enemy["type"] == &"severer" else 2.5) * float(graph.modifiers["disable_duration_mult"])
			disabled_links[_edge_key(parent_id, child_id)] = world_time + duration
			enemy["disable_cooldown"] = world_time + (3.5 if enemy["type"] == &"severer" else 999.0)
			effects.append({"type": "burst", "position": enemy["position"], "ttl": 0.45, "color": Color("68ff9b")})
			message_requested.emit("LINK SEVERED")
			sfx_requested.emit(&"sever")
			return

func _apply_cross_synapses() -> void:
	for a in range(pulses.size()):
		for b in range(a + 1, pulses.size()):
			var pa := _pulse_position(pulses[a])
			var pb := _pulse_position(pulses[b])
			if pa.distance_to(pb) > CELL_SIZE * 0.34:
				continue
			var pair_key := "%d:%d" % [mini(int(pulses[a]["id"]), int(pulses[b]["id"])), maxi(int(pulses[a]["id"]), int(pulses[b]["id"]))]
			if resonance_hits.has(pair_key): continue
			resonance_hits[pair_key] = true
			var center := (pa + pb) * 0.5
			for index in range(enemies.size() - 1, -1, -1):
				if Vector2(enemies[index]["position"]).distance_to(center) <= CELL_SIZE:
					_damage_enemy(index, 18.0, true)
			effects.append({"type": "burst", "position": center, "ttl": 0.4, "color": Color("fff27a")})

func _pulse_position(pulse: Dictionary) -> Vector2:
	return _node_position(int(pulse["from"])).lerp(_node_position(int(pulse["to"])), clampf(float(pulse["progress"]), 0.0, 1.0))

func _check_wave_complete(delta: float) -> void:
	if _paid_wave_number == current_wave:
		return
	if spawn_index < spawn_entries.size() or not enemies.is_empty():
		_finish_delay = -1.0
		return
	if _finish_delay < 0.0:
		_finish_delay = 0.7
	_finish_delay -= delta
	if _finish_delay <= 0.0:
		_paid_wave_number = current_wave
		wave_active = false
		pulses.clear()
		graph.complete_wave(current_wave)
		specialization_state_changed.emit()
		if objective_status == &"active" and objective.get("kind", "") == "no_leaks":
			_set_objective_status(&"complete")
		charge += 35 + current_wave * 5 + 3 * _perk_level("wave_metabolism") + (20 if "lean_start" in run_mutators else 0)
		if objective_status == &"complete":
			charge += int(objective["bonus"])
		charge_changed.emit(charge)
		wave_finished.emit()
		sfx_requested.emit(&"wave_complete")

func _set_objective_status(value: StringName) -> void:
	if objective_status == value:
		return
	objective_status = value
	objective_changed.emit(value)

func _update_effects(delta: float) -> void:
	for index in range(effects.size() - 1, -1, -1):
		effects[index]["ttl"] = float(effects[index]["ttl"]) - delta
		if float(effects[index]["ttl"]) <= 0.0:
			effects.remove_at(index)

func _prune_disabled_links() -> void:
	for key in disabled_links.keys():
		if float(disabled_links[key]) <= world_time:
			disabled_links.erase(key)

func _is_link_disabled(from_id: int, to_id: int) -> bool:
	return float(disabled_links.get(_edge_key(from_id, to_id), 0.0)) > world_time

func _edge_key(from_id: int, to_id: int) -> String:
	return "%d>%d" % [from_id, to_id]

func _gui_input(event: InputEvent) -> void:
	var point := Vector2(-1, -1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		clear_tool()
		accept_event()
		return
	if point.x < 0.0:
		return
	var cell := Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))
	if not _cell_in_board(cell):
		return
	_handle_cell_tap(cell)
	accept_event()

func _handle_cell_tap(cell: Vector2i) -> void:
	var existing := graph.node_at(cell)
	if rewire_mode:
		if existing >= 0 and graph.reparent(selected_node_id, existing):
			rewire_mode = false
			message_requested.emit("Branch rerouted")
			sfx_requested.emit(&"rewire")
		else:
			message_requested.emit("Invalid parent: check reach, ports, and cycles")
			sfx_requested.emit(&"error")
		queue_redraw()
		return
	if not selected_tower.is_empty():
		if not build_allowed:
			message_requested.emit("Construction is locked during this wave")
			sfx_requested.emit(&"error")
			return
		if existing >= 0:
			clear_tool()
			selected_node_id = existing
			node_selected.emit(existing)
			coverage_changed.emit()
			return
		if not _is_buildable(cell):
			message_requested.emit("That tissue cannot host a node")
			sfx_requested.emit(&"error")
			return
		var definitions := GameData.tower_definitions()
		var cost := tower_cost(selected_tower)
		if charge < cost:
			message_requested.emit("Insufficient charge")
			sfx_requested.emit(&"error")
			return
		var parents := _filtered_parents(cell, selected_tower)
		if parents.is_empty():
			message_requested.emit("No powered parent in range")
			sfx_requested.emit(&"error")
			return
		if preview_cell != cell:
			preview_cell = cell
			preview_parents = parents
			preview_parent_index = 0
			message_requested.emit("Tap again to grow %s • %d charge" % [definitions[selected_tower]["name"], cost])
			queue_redraw()
			coverage_changed.emit()
			return
		var parent_id := preview_parents[preview_parent_index]
		var new_id := graph.place_node(selected_tower, cell, parent_id)
		if new_id >= 0:
			charge -= cost
			charge_changed.emit(charge)
			selected_node_id = new_id
			node_selected.emit(new_id)
			preview_cell = Vector2i(-1, -1)
			preview_parents.clear()
			sfx_requested.emit(&"place")
		queue_redraw()
		coverage_changed.emit()
		return
	if existing >= 0:
		selected_node_id = existing
		node_selected.emit(existing)
		queue_redraw()
		coverage_changed.emit()

func _filtered_parents(cell: Vector2i, tower_type: StringName) -> Array[int]:
	var result: Array[int] = []
	for parent_id in graph.valid_parent_ids(cell, tower_type):
		if bool(graph.modifiers["phase_axon"]) or not _link_hits_blocker(graph.nodes[parent_id]["cell"], cell):
			result.append(parent_id)
	return result

func _link_hits_blocker(from_cell: Vector2i, to_cell: Vector2i) -> bool:
	var start := Vector2(from_cell) + Vector2(0.5, 0.5)
	var finish := Vector2(to_cell) + Vector2(0.5, 0.5)
	for cell in blocked_cells:
		if cell == from_cell or cell == to_cell: continue
		if _distance_to_segment(Vector2(cell) + Vector2(0.5, 0.5), start, finish) < 0.44:
			return true
	return false

func _is_buildable(cell: Vector2i) -> bool:
	return _cell_in_board(cell) and cell not in top_path and cell not in bottom_path and cell not in blocked_cells

func _cell_in_board(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < GameData.BOARD_COLUMNS and cell.y < GameData.BOARD_ROWS

func _path_for_lane(lane: int) -> Array[Vector2i]:
	return top_path if lane == 0 else bottom_path

func _node_position(node_id: int) -> Vector2:
	return _cell_center(graph.nodes[node_id]["cell"])

func _cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE

func _enemy_progress(enemy: Dictionary) -> float:
	return float(enemy["segment"]) + float(enemy["segment_t"])

func _enemy_index_by_id(enemy_id: int) -> int:
	for index in range(enemies.size()):
		if int(enemies[index]["id"]) == enemy_id:
			return index
	return -1

func _node_name(node_id: int) -> String:
	if node_id == 0: return "CORE"
	return str(GameData.tower_definitions()[graph.nodes[node_id]["type"]]["name"])

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var line := finish - start
	var length_squared := line.length_squared()
	if length_squared <= 0.0001: return point.distance_to(start)
	var t := clampf((point - start).dot(line) / length_squared, 0.0, 1.0)
	return point.distance_to(start + line * t)

func _draw() -> void:
	_draw_board_surface()
	_draw_paths()
	_draw_rift_zones()
	_draw_links()
	if coverage_enabled:
		_draw_coverage_preview()
	_draw_nodes()
	_draw_enemies()
	_draw_pulses()
	_draw_effects()
	if combat_paused:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.03, 0.08, 0.14, 0.22))

func _draw_board_surface() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("09162a"), true)
	for y in range(GameData.BOARD_ROWS):
		for x in range(GameData.BOARD_COLUMNS):
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(x, y) * CELL_SIZE + Vector2(2, 2), Vector2(CELL_SIZE - 4, CELL_SIZE - 4))
			var color := Color(0.06, 0.14, 0.22, 0.5) if (x + y) % 2 == 0 else Color(0.04, 0.11, 0.19, 0.5)
			if _is_buildable(cell):
				draw_rect(rect, color, true)
			else:
				draw_rect(rect, Color(0.05, 0.08, 0.13, 0.55), true)
	for cell in blocked_cells:
		var center := _cell_center(cell)
		draw_circle(center, 22, Color("251536"))
		for spoke in range(6):
			var direction := Vector2.RIGHT.rotated(spoke * TAU / 6.0)
			draw_line(center + direction * 6, center + direction * 26, Color("8d3c83"), 3)

func _draw_paths() -> void:
	for path in [top_path, bottom_path]:
		var points := PackedVector2Array()
		for cell in path: points.append(_cell_center(cell))
		draw_polyline(points, Color("142740"), 38.0, true)
		draw_polyline(points, Color(0.2, 0.62, 0.73, 0.18), 3.0, true)
	for lane in range(2):
		var spawn := _cell_center(_path_for_lane(lane)[0])
		draw_circle(spawn, 18, Color("ff5b74"))
		draw_circle(spawn, 9, Color("190b21"))

func _draw_rift_zones() -> void:
	for zone in rift_zones:
		var alpha := clampf(float(zone["ttl"]) / float(zone.get("duration", 2.5)), 0.0, 1.0)
		draw_circle(zone["position"], CELL_SIZE * 1.25, Color(0.23, 0.38, 0.95, 0.12 * alpha))
		draw_arc(zone["position"], CELL_SIZE * 1.25, 0, TAU, 32, Color(0.48, 0.67, 1.0, 0.45 * alpha), 3)

func _draw_links() -> void:
	for raw_id in graph.nodes:
		var id: int = raw_id
		if id == 0: continue
		var node: Dictionary = graph.nodes[id]
		var parent_id: int = node["parent"]
		var color: Color = GameData.tower_definitions()[node["type"]]["color"]
		var disabled := _is_link_disabled(parent_id, id)
		if disabled: color = Color("ff4a67")
		draw_line(_node_position(parent_id), _node_position(id), Color(color, 0.18), 10.0, true)
		draw_line(_node_position(parent_id), _node_position(id), Color(color, 0.58 if not disabled else 0.32), 2.0, true)
		if disabled:
			var middle := _node_position(parent_id).lerp(_node_position(id), 0.5)
			draw_line(middle - Vector2(8, 8), middle + Vector2(8, 8), color, 3)
			draw_line(middle + Vector2(8, -8), middle + Vector2(-8, 8), color, 3)
	if preview_cell.x >= 0 and not preview_parents.is_empty():
		var parent_id := preview_parents[preview_parent_index]
		var color: Color = GameData.tower_definitions()[selected_tower]["color"]
		draw_dashed_line(_node_position(parent_id), _cell_center(preview_cell), Color(color, 0.9), 3.0, 10.0)

func _draw_coverage_preview() -> void:
	var edge := _focused_edge()
	if edge.is_empty():
		return
	var parent_id: int = edge["parent"]
	var focus_start := _node_position(parent_id)
	var focus_end := _cell_center(edge["cell"])
	var route_id := parent_id
	while route_id > 0:
		var upstream_id: int = graph.nodes[route_id]["parent"]
		_draw_route_edge(_node_position(upstream_id), _node_position(route_id), Color(0.38, 0.94, 0.82, 0.45))
		route_id = upstream_id
	if bool(edge["preview"]):
		for child_id in graph.nodes[parent_id]["children"]:
			_draw_route_subtree(child_id, Color(1.0, 0.72, 0.38, 0.55))
	else:
		_draw_descendants(int(edge["id"]))
	_draw_route_edge(focus_start, focus_end, Color(1.0, 0.94, 0.62, 0.95))
	_draw_lane_coverage(focus_start, focus_end, edge["type"], Color(1.0, 0.86, 0.42, 0.9))

func _draw_descendants(node_id: int) -> void:
	for child_id in graph.nodes[node_id]["children"]:
		_draw_route_subtree(child_id, Color(0.38, 0.94, 0.82, 0.6))

func _draw_route_subtree(node_id: int, color: Color) -> void:
	var node: Dictionary = graph.nodes[node_id]
	var start := _node_position(int(node["parent"]))
	var finish := _node_position(node_id)
	_draw_route_edge(start, finish, color)
	_draw_lane_coverage(start, finish, node["type"], Color(color, 0.55))
	for child_id in node["children"]:
		_draw_route_subtree(child_id, color)

func _draw_route_edge(start: Vector2, finish: Vector2, color: Color) -> void:
	draw_line(start, finish, Color(color, color.a * 0.2), 15.0, true)
	draw_line(start, finish, color, 3.0, true)

func _draw_lane_coverage(start: Vector2, finish: Vector2, tower_type: StringName, color: Color) -> void:
	if tower_type == &"relay":
		return
	var width := CELL_SIZE * LINK_WIDTH * float(graph.modifiers["link_width_mult"])
	for lane in range(2):
		var path := _path_for_lane(lane)
		for index in range(path.size() - 1):
			var a := _cell_center(path[index])
			var b := _cell_center(path[index + 1])
			var steps := maxi(1, ceili(a.distance_to(b) / 8.0))
			for step in range(steps):
				var p := a.lerp(b, float(step) / steps)
				var q := a.lerp(b, float(step + 1) / steps)
				if _distance_to_segment((p + q) * 0.5, start, finish) <= width:
					draw_line(p, q, color, 11.0, true)

func _draw_nodes() -> void:
	var core := _node_position(0)
	draw_circle(core, 30, Color(0.12, 0.95, 0.72, 0.14))
	draw_circle(core, 23, Color("153e4b"))
	draw_circle(core, 13 + sin(world_time * 3.0) * 2.0, Color("62f4d2"))
	for raw_id in graph.nodes:
		var id: int = raw_id
		if id == 0: continue
		var node: Dictionary = graph.nodes[id]
		var pos := _node_position(id)
		var color: Color = GameData.tower_definitions()[node["type"]]["color"]
		if id == selected_node_id:
			draw_circle(pos, 29, Color(1, 1, 1, 0.22))
		draw_circle(pos, 22, Color(color, 0.2))
		draw_circle(pos, 16, Color("0b1829"))
		var icon := GameArt.tower_icon(node["type"])
		if node["type"] == &"lance":
			var direction := (pos - _node_position(int(node["parent"]))).normalized()
			draw_set_transform(pos, LANCE_ICON_FORWARD.angle_to(direction), Vector2.ONE)
			draw_texture_rect(icon, Rect2(Vector2(-14, -14), Vector2(28, 28)), false, color)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
			draw_texture_rect(icon, Rect2(pos - Vector2(14, 14), Vector2(28, 28)), false, color)
		var specialization: StringName = node.get("specialization", &"")
		if specialization != &"":
			var badge_position := pos + Vector2(17, -18)
			draw_circle(badge_position, 9, Color("33c8ff") if specialization == &"a" else Color("ffd166"))
			draw_string(ThemeDB.fallback_font, badge_position + Vector2(-5, 5), "A" if specialization == &"a" else "B", HORIZONTAL_ALIGNMENT_CENTER, 10, 14, Color("0b1829"))

func _draw_enemies() -> void:
	var font := ThemeDB.fallback_font
	for enemy in enemies:
		if enemy["type"] == &"shielder":
			var center: Vector2 = enemy["position"]
			draw_circle(center, SHIELD_RADIUS, Color(0.44, 0.75, 1.0, 0.07))
			draw_arc(center, SHIELD_RADIUS, 0, TAU, 48, Color(0.44, 0.75, 1.0, 0.48), 2.0)
	for enemy in enemies:
		var pos: Vector2 = enemy["position"]
		var definition: Dictionary = GameData.enemy_definitions()[enemy["type"]]
		var radius := 22.0 if enemy["type"] == &"severer" else (17.0 if enemy["type"] == &"crawler" else (14.0 if enemy["type"] == &"husk" else 10.0))
		draw_circle(pos, radius + 4, Color(0, 0, 0, 0.45))
		var icon_size := 48.0 if enemy["type"] == &"severer" else (44.0 if enemy["type"] == &"crawler" else (32.0 if enemy["type"] == &"husk" else 26.0))
		var frame := GameArt.enemy_walk_frame(float(enemy.get("walk_distance", 0.0)))
		var source := GameArt.enemy_walk_region(enemy["type"], _enemy_direction(enemy), frame)
		var icon_color: Color = Color.WHITE if enemy["type"] == &"crawler" else definition["color"]
		if enemy["type"] == &"phase":
			icon_color.a = 0.76
		draw_texture_rect_region(
			GameArt.enemy_walk_atlas(enemy["type"]),
			Rect2(pos - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size),
			source,
			icon_color
		)
		if enemy["type"] == &"phase": draw_arc(pos, radius + 5, 0, TAU, 18, Color("6fdcff"), 2)
		if objective_status == &"active" and int(enemy["id"]) == objective_enemy_id:
			draw_arc(pos, radius + 9, 0, TAU, 24, Color("fff27a"), 3)
			draw_string(font, pos + Vector2(-18, -radius - 17), "GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("fff27a"))
		if world_time < float(enemy["shield_until"]):
			draw_arc(pos, radius + 6, 0, TAU, 24, Color("70bfff"), 3)
		var ratio := clampf(float(enemy["hp"]) / float(enemy["max_hp"]), 0.0, 1.0)
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 9), Vector2(radius * 2, 4)), Color("351729"))
		draw_rect(Rect2(pos + Vector2(-radius, -radius - 9), Vector2(radius * 2 * ratio, 4)), Color("62f4d2"))
		if enemy["type"] == &"severer":
			draw_string(font, pos + Vector2(-24, 38), "BOSS", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("ffb4d2"))

func _draw_pulses() -> void:
	for pulse in pulses:
		var start := _node_position(int(pulse["from"]))
		var finish := _node_position(int(pulse["to"]))
		var p := clampf(float(pulse["progress"]), 0.0, 1.0)
		var position := start.lerp(finish, p)
		var type: StringName = graph.nodes[int(pulse["to"])]["type"]
		var color: Color = Color("62f4d2") if type == &"relay" else GameData.tower_definitions()[type]["color"]
		draw_circle(position, 11, Color(color, 0.16))
		draw_circle(position, 5, color)

func _draw_effects() -> void:
	for effect in effects:
		var alpha := clampf(float(effect["ttl"]) * 2.5, 0.0, 1.0)
		var color := Color(effect["color"], alpha)
		match effect["type"]:
			"line": draw_line(effect["from"], effect["to"], color, 4.0, true)
			"burst": draw_arc(effect["position"], 12.0 + (1.0 - alpha) * 28.0, 0, TAU, 24, color, 4.0)
			"spark": draw_circle(effect["position"], 5.0 + (1.0 - alpha) * 5.0, color)
			"shield_pulse": draw_arc(effect["position"], SHIELD_RADIUS * (1.0 - alpha), 0, TAU, 48, color, 4.0)
