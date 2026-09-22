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
	_test_wave_determinism()
	_test_wave_fuzzing()
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
	_expect(GameData.tower_definitions().size() == 4, "Tower catalog must contain four nodes")
	_expect(GameData.enemy_definitions().size() == 6, "Enemy catalog must contain five units and the boss")
	_expect(GameData.card_definitions().size() == 12, "Card catalog must contain eight base and four advanced cards")
	_expect(GameData.BASE_CARD_IDS.size() == 8, "Starting deck must contain eight cards")

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

func _test_wave_determinism() -> void:
	var first := RunGenerator.generate_run(424242)
	var second := RunGenerator.generate_run(424242)
	var different := RunGenerator.generate_run(424243)
	_expect(first == second, "Equal seeds must generate equal wave manifests")
	_expect(first != different, "Different seeds should change the run")
	_expect(first.size() == 10, "A run must have ten waves")
	var boss_found := false
	for entry in first[9]["entries"]:
		if entry["type"] == &"severer": boss_found = true
	_expect(boss_found, "Wave ten must contain the Severer")

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
	_expect(SaveService.owned_card_ids(data).size() == 8, "Advanced cards must begin locked")
	data["owned_packs"].append("advanced_network_pack")
	_expect(SaveService.owned_card_ids(data).size() == 12, "Advanced entitlement must unlock four cards")

func _test_build_policy() -> void:
	_expect(GameController.is_build_allowed("easy", true), "Easy mode must allow building during combat")
	_expect(not GameController.is_build_allowed("normal", true), "Normal mode must lock building during combat")
	_expect(GameController.is_build_allowed("hardcore", true), "Hardcore mode must allow building during combat")
	_expect(GameController.is_build_allowed("normal", false), "Every mode must allow building between waves")

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
