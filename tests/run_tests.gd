extends SceneTree

var failures: Array[String] = []
var assertions := 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("SYNAPSE test suite")
	_test_content_catalog()
	_test_graph_validation()
	_test_round_robin_routing()
	_test_modifiers()
	_test_gene_cards()
	_test_gene_purchases()
	_test_permanent_perks()
	_test_gene_lab_ui()
	_test_wave_determinism()
	_test_wave_fuzzing()
	_test_level_layouts()
	_test_campaign_waves()
	_test_endless_scaling()
	_test_new_enemy_behaviors()
	_test_controller_setup()
	_test_build_policy()
	_test_menu_exit_confirmation()
	_test_progression_defaults()
	if failures.is_empty():
		print("PASS: %d assertions" % assertions)
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("FAIL: %d failure(s), %d assertions" % [failures.size(), assertions])
		quit(1)

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _test_content_catalog() -> void:
	_expect(GameData.tower_definitions().size() == 6, "Tower catalog must contain six nodes")
	_expect(GameData.enemy_definitions().size() == 8, "Enemy catalog must contain seven units and the boss")
	_expect(GameData.card_definitions().size() == 20, "Card catalog must contain eight base, four advanced and eight gene cards")
	_expect(GameData.BASE_CARD_IDS.size() == 8, "Starting deck must contain eight cards")
	for id in GameData.GENE_CARD_IDS:
		_expect(GameData.card_definitions().has(id) and not GameData.card_modifier(id).is_empty(), "Gene card must have a definition and effect: %s" % id)

func _test_graph_validation() -> void:
	var graph := NetworkGraph.new()
	var relay := graph.place_node(&"relay", Vector2i(13, 1), 0)
	_expect(relay > 0, "Relay should connect to Core within reach")
	var arc := graph.place_node(&"arc", Vector2i(10, 1), relay)
	_expect(arc > 0, "Arc should connect to Relay within reach")
	_expect(graph.place_node(&"cryo", Vector2i(10, 1), relay) == -1, "Occupied cells must reject placements")
	_expect(not graph.can_reparent(relay, arc), "Graph must reject cycles")
	_expect(graph.can_reparent(arc, 0) == false, "Arc outside Core reach must reject reparent")
	var removed := graph.remove_subtree(relay)
	_expect(removed.size() == 2 and graph.nodes.size() == 1, "Removing a branch must remove its descendants")

func _test_round_robin_routing() -> void:
	var graph := NetworkGraph.new()
	var relay := graph.place_node(&"relay", Vector2i(13, 3), 0)
	var a := graph.place_node(&"arc", Vector2i(11, 1), relay)
	var b := graph.place_node(&"cryo", Vector2i(10, 3), relay)
	var c := graph.place_node(&"lance", Vector2i(11, 5), relay)
	_expect(a > 0 and b > 0 and c > 0, "Relay fixture must place all children")
	_expect(graph.outgoing_for_pulse(relay) == [a], "First pulse should use first child")
	_expect(graph.outgoing_for_pulse(relay) == [b], "Second pulse should use second child")
	_expect(graph.outgoing_for_pulse(relay) == [c], "Third pulse should use third child")
	_expect(graph.outgoing_for_pulse(relay) == [a], "Fourth pulse should wrap round-robin")
	graph.apply_modifier("synchronized_split")
	graph.reset_routing()
	graph.outgoing_for_pulse(relay)
	graph.outgoing_for_pulse(relay)
	graph.outgoing_for_pulse(relay)
	_expect(graph.outgoing_for_pulse(relay).size() == 3, "Synchronized Split should feed all children every fourth pulse")
	graph.modifiers = GameData.empty_modifiers()
	graph.apply_modifier("priority_gate")
	graph.reset_routing()
	_expect(graph.outgoing_for_pulse(relay).size() == 3, "Priority Gate should feed all children on the first wave pulse")

func _test_modifiers() -> void:
	var graph := NetworkGraph.new()
	graph.apply_modifier("long_axons")
	graph.apply_modifier("myelin")
	_expect(is_equal_approx(float(graph.modifiers["link_range_bonus"]), 1.0), "Long Axons must extend range")
	_expect(is_equal_approx(float(graph.modifiers["pulse_speed_mult"]), 1.04), "Multiplicative pulse modifiers must compose")
	graph.apply_modifier("parallel_roots")
	_expect(graph.child_capacity(0) == 3, "Parallel Roots must add a Core port")

func _test_gene_cards() -> void:
	var graph := NetworkGraph.new()
	var relay := graph.place_node(&"relay", Vector2i(13, 3), 0)
	var a := graph.place_node(&"arc", Vector2i(11, 1), relay)
	var b := graph.place_node(&"cryo", Vector2i(10, 3), relay)
	var c := graph.place_node(&"lance", Vector2i(11, 5), relay)
	graph.apply_modifier("twin_gate")
	_expect(graph.outgoing_for_pulse(relay) == [a], "Twin Gate first pulse uses one branch")
	_expect(graph.outgoing_for_pulse(relay) == [b], "Twin Gate second pulse uses one branch")
	_expect(graph.outgoing_for_pulse(relay) == [c, a], "Twin Gate third pulse uses successive branches")
	_expect(graph.outgoing_for_pulse(relay) == [b], "Twin Gate advances past both fed branches")
	graph.apply_modifier("synchronized_split")
	graph.reset_routing()
	for i in range(3):
		graph.outgoing_for_pulse(relay)
	_expect(graph.outgoing_for_pulse(relay).size() == 3, "Synchronized Split takes precedence over Twin Gate")
	graph.apply_modifier("weapon_junction")
	_expect(graph.child_capacity(a) == 2 and graph.child_capacity(b) == 2 and graph.child_capacity(c) == 2, "Weapon Junction adds weapon ports")
	var board := GameBoard.new()
	board.graph.apply_modifier("core_metronome")
	board.graph.apply_modifier("arc_cascade")
	board.graph.apply_modifier("lance_fan")
	board.graph.apply_modifier("recovery_sheath")
	board.graph.apply_modifier("conductive_mark")
	_expect(is_equal_approx(float(board.graph.modifiers["core_interval_mult"]), 0.9), "Core Metronome changes launch interval")
	_expect(int(board.graph.modifiers["arc_targets_bonus"]) == 1, "Arc Cascade adds a target")
	_expect(is_equal_approx(float(board.graph.modifiers["lance_width_bonus"]), 0.12), "Lance Fan widens beams")
	_expect(is_equal_approx(float(board.graph.modifiers["disable_duration_mult"]), 0.65), "Recovery Sheath shortens disable time")
	board._spawn_enemy(&"crawler", 0)
	board.enemies[0]["marked_until"] = 3.0
	board._damage_enemy(0, 12.0, true)
	_expect(is_equal_approx(float(board.enemies[0]["hp"]), 19.0), "Conductive Mark increases link damage")
	board.free()
	var cryo_board := GameBoard.new()
	var cryo := cryo_board.graph.place_node(&"cryo", Vector2i(13, 3), 0)
	cryo_board.graph.apply_modifier("cryo_bloom")
	cryo_board._spawn_enemy(&"crawler", 0)
	cryo_board._spawn_enemy(&"crawler", 0)
	cryo_board.enemies[0]["position"] = cryo_board._node_position(cryo)
	cryo_board.enemies[1]["position"] = cryo_board._node_position(cryo) + Vector2(20, 0)
	cryo_board._fire_cryo(cryo)
	_expect(float(cryo_board.enemies[1]["root_until"]) >= 0.25, "Cryo Bloom roots a nearby second enemy")
	cryo_board.free()

func _test_gene_purchases() -> void:
	var data := SaveService.defaults()
	data["gene_shards"] = 30
	var purchased := SaveService.gene_card_purchase(data, "weapon_junction")
	_expect(int(purchased["gene_shards"]) == 24 and "weapon_junction" in purchased["owned_gene_cards"], "Card purchase spends shards and grants ownership")
	_expect(int(data["gene_shards"]) == 30 and data["owned_gene_cards"].is_empty(), "Purchase leaves original save unchanged")
	_expect("weapon_junction" in SaveService.owned_card_ids(purchased), "Purchased card becomes deck eligible")
	_expect(SaveService.gene_card_purchase(purchased, "weapon_junction").is_empty(), "Duplicate card purchase is rejected")
	_expect(SaveService.gene_card_purchase(data, "unknown").is_empty(), "Unknown card purchase is rejected")
	data["gene_shards"] = 5
	_expect(SaveService.gene_card_purchase(data, "arc_cascade").is_empty(), "Card purchase needs enough shards")

func _test_permanent_perks() -> void:
	var data := SaveService.defaults()
	data["gene_shards"] = 30
	for level in range(3):
		data = SaveService.perk_purchase(data, "reserve_cells")
		_expect(SaveService.perk_level(data, "reserve_cells") == level + 1, "Perk level advances")
	_expect(int(data["gene_shards"]) == 8, "Perk levels cost 4, 7 and 11 shards")
	_expect(SaveService.perk_purchase(data, "reserve_cells").is_empty(), "Capped perk rejects more purchases")
	_expect(SaveService.perk_purchase(data, "unknown").is_empty(), "Unknown perk is rejected")
	var board := GameBoard.new()
	board.configure(42, "normal", 1, {"reserve_cells": 3, "core_lattice": 2, "wave_metabolism": 1, "reclamation": 1, "signal_enzymes": 2})
	_expect(board.charge == 250 and board.integrity == 22, "Run starts with permanent resource perks")
	_expect(board._perk_level("wave_metabolism") == 1 and board._perk_level("signal_enzymes") == 2, "Other permanent perks reach the board")
	var relay := board.graph.place_node(&"relay", Vector2i(13, 3), 0)
	board.sell_node(relay)
	_expect(board.charge == 281, "Reclamation raises the recycling refund")
	board.current_wave = 1
	board._finish_delay = 0.1
	board._check_wave_complete(0.2)
	_expect(board.charge == 324, "Wave Metabolism raises the wave payout")
	board.free()

func _test_gene_lab_ui() -> void:
	var menu: Variant = load("res://scripts/main.gd").new()
	menu.save_data = SaveService.defaults()
	menu._show_store()
	var buttons: Array = menu.find_children("*", "Button", true, false)
	_expect(buttons.size() >= 17, "Gene Lab shows perk, card, pack and back actions")
	menu.free()

func _test_wave_determinism() -> void:
	var first := RunGenerator.generate_run(424242)
	var second := RunGenerator.generate_run(424242)
	var different := RunGenerator.generate_run(424243)
	_expect(first == second, "Equal seeds must generate equal wave manifests")
	_expect(first != different, "Different seeds should change the run")
	_expect(first.size() == 10, "A run must have ten waves")
	var boss_found := false
	for entry in RunGenerator.generate_run(424242, 5)[9]["entries"]:
		if entry["type"] == &"severer": boss_found = true
	_expect(boss_found, "Final level wave ten must contain the Severer")

func _test_wave_fuzzing() -> void:
	for seed_value in range(1, 1001):
		var run := RunGenerator.generate_run(seed_value)
		_expect(run.size() == 10, "Seed %d produced wrong wave count" % seed_value)
		for wave_index in range(run.size()):
			var wave: Dictionary = run[wave_index]
			_expect(not wave["entries"].is_empty(), "Seed %d wave %d is empty" % [seed_value, wave_index + 1])
			var last_time := -1.0
			for entry in wave["entries"]:
				_expect(int(entry["lane"]) in [0, 1], "Generated an invalid lane")
				_expect(float(entry["time"]) >= last_time, "Spawn times must be sorted")
				last_time = float(entry["time"])

func _test_progression_defaults() -> void:
	var data := SaveService.defaults()
	_expect(data["deck"].size() == 8, "Default deck must be playable")
	_expect(SaveService.level_unlocked(data, 1), "Level one must start unlocked")
	_expect(not SaveService.level_unlocked(data, 2), "Level two must start locked")
	_expect(SaveService.unlocked_towers(data).size() == 4, "Four towers must be available at start")
	_expect(SaveService.valid_loadout(data, [&"relay", &"arc", &"cryo"]), "Three unlocked unique towers must be valid")
	_expect(not SaveService.valid_loadout(data, [&"relay", &"relay", &"arc"]), "Duplicate tower selection must fail")
	_expect(not SaveService.valid_loadout(data, [&"relay", &"arc", &"mortar"]), "Locked tower selection must fail")
	SaveService.complete_level(data, 2)
	_expect(data["completed_levels"].is_empty(), "Cannot skip a locked level")
	SaveService.complete_level(data, 1)
	_expect(SaveService.level_unlocked(data, 2) and SaveService.endless_unlocked(data, 1), "Victory must unlock next level and its own Endless")
	SaveService.complete_level(data, 2)
	_expect(&"mortar" in SaveService.unlocked_towers(data), "Mortar must unlock after level two")
	SaveService.complete_level(data, 3)
	SaveService.complete_level(data, 4)
	_expect(&"rift" in SaveService.unlocked_towers(data), "Rift must unlock after level four")
	SaveService.record_wave(data, 1, 12, true)
	SaveService.record_wave(data, 1, 8, true)
	_expect(int(data["endless_best"][0]) == 12, "Best Endless wave must never decrease")
	var migrated := SaveService.normalize_data({"version": 1, "gene_shards": 9, "deck": GameData.BASE_CARD_IDS.duplicate(), "owned_packs": ["base"]})
	_expect(migrated["gene_shards"] == 9 and migrated["completed_levels"].is_empty(), "Old saves must keep resources and start campaign fresh")
	_expect(migrated["campaign_best"].size() == 5, "Old saves must receive five campaign scores")
	_expect(SaveService.owned_card_ids(data).size() == 8, "Advanced cards must begin locked")
	data["owned_packs"].append("advanced_network_pack")
	_expect(SaveService.owned_card_ids(data).size() == 12, "Advanced entitlement must unlock four cards")
	_expect(SaveService.perk_level(data, "reserve_cells") == 0, "Legacy save without perks defaults to zero")

func _test_build_policy() -> void:
	_expect(GameController.is_build_allowed("easy", true), "Easy mode must allow building during combat")
	_expect(not GameController.is_build_allowed("normal", true), "Normal mode must lock building during combat")
	_expect(GameController.is_build_allowed("hardcore", true), "Hardcore mode must allow building during combat")
	_expect(GameController.is_build_allowed("normal", false), "Every mode must allow building between waves")
	_expect(not GameController.is_build_allowed("endless", true), "Endless must use Normal build timing")

func _test_menu_exit_confirmation() -> void:
	for difficulty_id in ["easy", "normal", "hardcore"]:
		var game := GameController.new()
		root.add_child(game)
		game.setup(difficulty_id, 424242, GameData.BASE_CARD_IDS, false)
		var exit_count := [0]
		game.exit_requested.connect(func(): exit_count[0] += 1)
		game.countdown = 10.0
		if difficulty_id == "easy":
			game.board.set_combat_paused(true)
		game.menu_button.emit_signal("pressed")
		_expect(is_instance_valid(game._exit_confirmation), "%s MENU must show a confirmation" % difficulty_id)
		_expect(exit_count[0] == 0, "%s MENU must not exit immediately" % difficulty_id)
		_expect(game.board.is_processing() == (difficulty_id != "easy"), "%s confirmation must use its difficulty's timing rule" % difficulty_id)
		game._process(1.0)
		_expect(is_equal_approx(game.countdown, 10.0 if difficulty_id == "easy" else 9.0), "%s countdown must use its difficulty's timing rule" % difficulty_id)
		game._cancel_menu_exit()
		_expect(exit_count[0] == 0 and not is_instance_valid(game._exit_confirmation), "%s cancel must keep the run" % difficulty_id)
		_expect(game.board.is_processing(), "%s cancel must restore board processing" % difficulty_id)
		if difficulty_id == "easy":
			_expect(game.board.combat_paused, "Easy cancel must preserve tactical pause")
		game.menu_button.emit_signal("pressed")
		game._confirm_menu_exit()
		_expect(exit_count[0] == 1, "%s confirm must request one exit" % difficulty_id)
		game.queue_free()

func _test_level_layouts() -> void:
	var signatures: Array[String] = []
	for level in range(1, LevelData.LEVEL_COUNT + 1):
		var layout := LevelData.layout(level)
		var blocked: Array[Vector2i] = layout["blocked_cells"]
		var signature := ""
		for lane in ["top_path", "bottom_path"]:
			var path: Array[Vector2i] = layout[lane]
			_expect(path[0].x == 0 and path[-1] == GameData.CORE_CELL, "Level %d lane must span spawn to Core" % level)
			for index in range(path.size()):
				var cell := path[index]
				_expect(cell.x >= 0 and cell.x < 16 and cell.y >= 0 and cell.y < 8, "Level path cell must be in bounds")
				_expect(cell not in blocked, "Blocked cell cannot overlap an enemy path")
				if index > 0:
					_expect(abs(cell.x - path[index - 1].x) + abs(cell.y - path[index - 1].y) == 1, "Path cells must be adjacent")
			signature += str(path)
		_expect(signature not in signatures, "Every level needs a different route")
		signatures.append(signature)

func _test_campaign_waves() -> void:
	var previous_total := 0
	for level in range(1, LevelData.LEVEL_COUNT + 1):
		var wave := RunGenerator.generate_wave(2026, 1, level)
		_expect(wave["entries"].size() > previous_total, "Opening waves must gain more enemies by level")
		previous_total = wave["entries"].size()
		for entry in RunGenerator.generate_wave(2026, 10, level)["entries"]:
			_expect(entry["type"] != &"severer" or level == 5, "Boss must appear only in final campaign level")
	_expect(&"splitter" in RunGenerator.available_types(3, 3), "Splitter must arrive in level three")
	_expect(&"conductor" in RunGenerator.available_types(5, 3), "Conductor must arrive in level five")
	_expect(&"husk" not in RunGenerator.available_types(1, 10), "Early level must not include later enemy types")

func _test_endless_scaling() -> void:
	var tenth := RunGenerator.generate_wave(42, 10, 1, true)
	var twenty := RunGenerator.generate_wave(42, 20, 1, true)
	var fifty := RunGenerator.generate_wave(42, 50, 1, true)
	_expect(twenty == RunGenerator.generate_wave(42, 20, 1, true), "Endless waves must be deterministic")
	_expect(float(tenth["hp_scale"]) < float(twenty["hp_scale"]) and float(twenty["hp_scale"]) < float(fifty["hp_scale"]), "Endless health must rise past wave ten")
	_expect(twenty["entries"].size() <= 61 and fifty["entries"].size() <= 61, "Endless waves must cap spawn count")
	_expect(not fifty["entries"].is_empty(), "Late Endless waves must remain playable")

func _test_new_enemy_behaviors() -> void:
	var board := GameBoard.new()
	board.configure(42, "normal", 3)
	board._spawn_enemy(&"splitter", 0, 2, 0.5)
	board._damage_enemy(0, 1000.0, false)
	_expect(board.enemies.size() == 2, "Splitter must release two enemies")
	for child in board.enemies:
		_expect(child["type"] == &"crawler" and int(child["segment"]) == 2, "Split children must continue along the same path")
	board.free()
	var boosted := GameBoard.new()
	boosted.configure(42, "normal", 5)
	boosted._spawn_enemy(&"conductor", 0)
	boosted._spawn_enemy(&"crawler", 0)
	boosted._update_enemies(1.0)
	_expect(float(boosted.enemies[1]["segment_t"]) > 0.0 or int(boosted.enemies[1]["segment"]) > 0, "Conductor must let nearby crawlers move")
	var boosted_progress := boosted._enemy_progress(boosted.enemies[1])
	var normal := GameBoard.new()
	normal.configure(42, "normal", 5)
	normal._spawn_enemy(&"crawler", 0)
	normal._update_enemies(1.0)
	_expect(boosted_progress > normal._enemy_progress(normal.enemies[0]), "Conductor must speed nearby enemies")
	boosted.free()
	normal.free()
	var towers := GameBoard.new()
	towers.configure(42, "normal")
	var mortar := towers.graph.place_node(&"mortar", Vector2i(13, 1), 0)
	towers._spawn_enemy(&"crawler", 0)
	towers._spawn_enemy(&"crawler", 0)
	for enemy in towers.enemies:
		enemy["position"] = Vector2(13.0, 2.0) * GameBoard.CELL_SIZE
	towers._fire_mortar(mortar)
	_expect(towers.enemies.size() == 2 and float(towers.enemies[0]["hp"]) < 34.0 and float(towers.enemies[1]["hp"]) < 34.0, "Mortar must damage a group")
	var rift := towers.graph.place_node(&"rift", Vector2i(12, 1), mortar)
	towers._fire_rift(rift)
	_expect(not towers.rift_zones.is_empty(), "Rift must create a persistent field")
	towers.free()

func _test_controller_setup() -> void:
	var controller := GameController.new()
	controller.setup("endless", 42, GameData.BASE_CARD_IDS, false, 3, [&"relay", &"mortar", &"rift"])
	_expect(controller.tower_buttons.size() == 3, "Build bar must show exactly three selected tower types")
	_expect(controller.board.top_path == LevelData.layout(3)["top_path"], "Controller must pass selected layout to board")
	controller.next_wave_index = 10
	controller._ensure_next_manifest()
	_expect(controller.manifests.size() == 11 and int(controller.manifests[10]["wave"]) == 11, "Endless must generate the next wave on demand")
	controller.free()
