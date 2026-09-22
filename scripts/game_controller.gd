class_name GameController
extends Control

const SPEEDS := [1, 2, 4, 8]

signal exit_requested
signal run_ended(wave_reached: int, victory: bool, difficulty: String, seed_value: int, mutators: Array[String])
signal tutorial_completed

var difficulty := "normal"
var level := 1
var loadout: Array[StringName] = []
var seed_value := 0
var deck: Array[String] = []
var manifests: Array[Dictionary] = []
var next_wave_index := 0
var drafted_cards: Array[String] = []
var run_mutators: Array[String] = []

var board: GameBoard
var charge_label: Label
var integrity_label: Label
var wave_label: Label
var mode_label: Label
var intel_label: Label
var intel_types: VBoxContainer
var intel_meta_label: Label
var objective_label: Label
var status_label: Label
var start_button: Button
var pause_button: Button
var speed_button: Button
var menu_button: Button
var cycle_button: Button
var rewire_button: Button
var sell_button: Button
var node_label: Label
var specialization_button: Button
var coverage_button: Button
var coverage_label: Label
var tower_buttons: Dictionary = {}
var countdown := -1.0
var _last_countdown_second := -1
var _run_over := false
var _last_objective_result := ""
var simulation_speed := 1
var _exit_confirmation: Control
var _specialization_overlay: Control
var sound_manager: SoundManager

func setup(p_difficulty: String, p_seed: int, p_deck: Array, show_tutorial: bool, p_level: int = 1, p_loadout: Array = [], perks: Dictionary = {}, mutators: Array = []) -> void:
	difficulty = p_difficulty
	level = p_level
	loadout.clear()
	for type in p_loadout:
		loadout.append(StringName(type))
	if loadout.is_empty():
		loadout = [&"relay", &"arc", &"cryo"]
	seed_value = p_seed
	run_mutators = GameData.normalize_run_mutators(mutators)
	for card_id in p_deck:
		deck.append(str(card_id))
	manifests = RunGenerator.generate_run(seed_value, level, run_mutators)
	_build_ui()
	board.configure(seed_value, difficulty, level, perks, run_mutators)
	board.simulation_speed = simulation_speed
	_update_coverage_readout()
	_update_wave_preview()
	_update_build_policy()
	if show_tutorial:
		_show_tutorial()

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var top := PanelContainer.new()
	top.position = Vector2(8, 8)
	top.size = Vector2(1264, 60)
	add_child(top)
	var top_row := HBoxContainer.new()
	top.add_child(top_row)
	charge_label = _hud_label("CHARGE 220", Color("62f4d2"), 175)
	integrity_label = _hud_label("CORE 20", Color("ff6b91"), 145)
	wave_label = _hud_label("WAVE 0 / ∞" if difficulty == "endless" else "WAVE 0 / 10", Color("d8edff"), 175)
	mode_label = _hud_label("L%d  %s" % [level, "ENDLESS" if difficulty == "endless" else GameData.difficulty_name(difficulty)], Color("9c82ff"), 260)
	var mutator_names: Array[String] = []
	var mutator_details: Array[String] = []
	var definitions := GameData.run_mutator_definitions()
	for id in run_mutators:
		mutator_names.append(definitions[id]["name"])
		mutator_details.append("%s: %s" % [definitions[id]["name"], definitions[id]["description"]])
	if not mutator_names.is_empty():
		mode_label.text += "\nMUTATORS %d • TAP TO VIEW" % mutator_names.size()
		mode_label.tooltip_text = "\n".join(mutator_details)
		mode_label.add_theme_font_size_override("font_size", 14)
		mode_label.mouse_filter = Control.MOUSE_FILTER_STOP
		mode_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mode_label.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed or event is InputEventScreenTouch and event.pressed:
				var dialog := AcceptDialog.new()
				dialog.title = "ACTIVE RUN MUTATORS"
				dialog.dialog_text = "\n\n".join(mutator_details)
				add_child(dialog)
				dialog.confirmed.connect(dialog.queue_free)
				dialog.close_requested.connect(dialog.queue_free)
				dialog.popup_centered(Vector2i(640, 400))
		)
	top_row.add_child(charge_label)
	top_row.add_child(integrity_label)
	top_row.add_child(wave_label)
	top_row.add_child(mode_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	speed_button = Button.new()
	speed_button.text = "SPEED 1×"
	speed_button.custom_minimum_size = Vector2(82, 44)
	speed_button.add_theme_font_size_override("font_size", 12)
	speed_button.tooltip_text = "Cycle wave speed: 1×, 2×, 4×, 8×"
	speed_button.pressed.connect(_cycle_speed)
	top_row.add_child(speed_button)
	coverage_button = Button.new()
	coverage_button.text = "COVERAGE ON"
	coverage_button.toggle_mode = true
	coverage_button.button_pressed = true
	coverage_button.custom_minimum_size = Vector2(125, 44)
	coverage_button.add_theme_font_size_override("font_size", 12)
	coverage_button.tooltip_text = "Show link coverage and pulse cadence"
	coverage_button.toggled.connect(_toggle_coverage)
	top_row.add_child(coverage_button)
	var seed_label := _hud_label("SEED %d" % seed_value, Color("7b9bb6"), 150)
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(seed_label)
	menu_button = Button.new()
	menu_button.text = "MENU"
	menu_button.custom_minimum_size = Vector2(90, 44)
	menu_button.pressed.connect(_request_menu_exit)
	top_row.add_child(menu_button)

	var intel_panel := PanelContainer.new()
	intel_panel.position = Vector2(8, 80)
	intel_panel.size = Vector2(128, 512)
	add_child(intel_panel)
	var intel_column := VBoxContainer.new()
	intel_panel.add_child(intel_column)
	var intel_title := Label.new()
	intel_title.text = "NEXT\nSIGNAL"
	intel_title.add_theme_font_size_override("font_size", 15)
	intel_title.add_theme_color_override("font_color", Color("62f4d2"))
	intel_column.add_child(intel_title)
	intel_label = Label.new()
	intel_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel_label.add_theme_font_size_override("font_size", 13)
	intel_column.add_child(intel_label)
	intel_types = VBoxContainer.new()
	intel_types.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intel_types.add_theme_constant_override("separation", 5)
	intel_column.add_child(intel_types)
	intel_meta_label = Label.new()
	intel_meta_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intel_meta_label.add_theme_font_size_override("font_size", 13)
	intel_column.add_child(intel_meta_label)
	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 12)
	objective_label.add_theme_color_override("font_color", Color("fff27a"))
	intel_column.add_child(objective_label)
	var legend := Label.new()
	legend.text = "▲ TOP LANE\n▼ BOTTOM\n\nPulses route\nfrom the Core."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color("7b9bb6"))
	intel_column.add_child(legend)

	board = GameBoard.new()
	board.run_mutators = run_mutators.duplicate()
	board.position = Vector2(144, 80)
	board.size = Vector2(1024, 512)
	add_child(board)
	board.charge_changed.connect(_on_charge_changed)
	board.integrity_changed.connect(_on_integrity_changed)
	board.wave_finished.connect(_on_wave_finished)
	board.run_failed.connect(_on_run_failed)
	board.node_selected.connect(_on_node_selected)
	board.message_requested.connect(_set_status)
	board.sfx_requested.connect(_play_sound)
	board.coverage_changed.connect(_update_coverage_readout)
	board.specialization_state_changed.connect(_refresh_specialization_ui)
	board.objective_changed.connect(_on_objective_changed)

	var bottom := PanelContainer.new()
	bottom.position = Vector2(8, 604)
	bottom.size = Vector2(1264, 108)
	add_child(bottom)
	var row := HBoxContainer.new()
	bottom.add_child(row)
	for type in loadout:
		var definition: Dictionary = GameData.tower_definitions()[type]
		var button := Button.new()
		button.text = "%s  •  %d\n%s" % [definition["name"], board.tower_cost(type), str(definition["tagline"]).to_upper()]
		button.icon = GameArt.tower_icon(type)
		button.add_theme_constant_override("icon_max_width", 32)
		button.expand_icon = true
		button.custom_minimum_size = Vector2(145, 72)
		button.add_theme_font_size_override("font_size", 14)
		button.tooltip_text = definition["description"]
		button.pressed.connect(_select_tower.bind(type))
		row.add_child(button)
		tower_buttons[type] = button
	var divider := VSeparator.new()
	row.add_child(divider)
	var selected_column := VBoxContainer.new()
	selected_column.custom_minimum_size = Vector2(155, 72)
	row.add_child(selected_column)
	node_label = Label.new()
	node_label.text = "SELECT A NODE"
	node_label.add_theme_font_size_override("font_size", 13)
	selected_column.add_child(node_label)
	var actions := HBoxContainer.new()
	selected_column.add_child(actions)
	rewire_button = Button.new()
	rewire_button.text = "WIRE"
	rewire_button.custom_minimum_size = Vector2(68, 36)
	rewire_button.add_theme_font_size_override("font_size", 12)
	rewire_button.disabled = true
	rewire_button.pressed.connect(_rewire_selected)
	actions.add_child(rewire_button)
	sell_button = Button.new()
	sell_button.text = "SELL"
	sell_button.custom_minimum_size = Vector2(62, 36)
	sell_button.add_theme_font_size_override("font_size", 12)
	sell_button.disabled = true
	sell_button.pressed.connect(_sell_selected)
	actions.add_child(sell_button)
	specialization_button = Button.new()
	specialization_button.text = "SELECT A NODE"
	specialization_button.custom_minimum_size = Vector2(150, 22)
	specialization_button.add_theme_font_size_override("font_size", 11)
	specialization_button.disabled = true
	specialization_button.pressed.connect(_show_specializations)
	selected_column.add_child(specialization_button)
	var control_column := VBoxContainer.new()
	control_column.custom_minimum_size = Vector2(175, 72)
	row.add_child(control_column)
	status_label = Label.new()
	status_label.text = "Build a powered network."
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control_column.add_child(status_label)
	var controls := HBoxContainer.new()
	control_column.add_child(controls)
	cycle_button = Button.new()
	cycle_button.text = "SRC"
	cycle_button.add_theme_font_size_override("font_size", 12)
	cycle_button.tooltip_text = "Cycle valid parents for the placement preview"
	cycle_button.pressed.connect(board.cycle_preview_parent)
	controls.add_child(cycle_button)
	pause_button = Button.new()
	pause_button.text = "PAUSE"
	pause_button.add_theme_font_size_override("font_size", 12)
	pause_button.visible = difficulty == "easy"
	pause_button.pressed.connect(_toggle_tactical_pause)
	controls.add_child(pause_button)
	coverage_label = Label.new()
	coverage_label.custom_minimum_size = Vector2(250, 72)
	coverage_label.add_theme_font_size_override("font_size", 11)
	coverage_label.add_theme_color_override("font_color", Color("d8edff"))
	coverage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	coverage_label.tooltip_text = "Intervals estimate ordinary routing; mutations may add pulses."
	row.add_child(coverage_label)
	start_button = Button.new()
	start_button.text = "LAUNCH\nWAVE 1"
	start_button.custom_minimum_size = Vector2(132, 72)
	start_button.add_theme_font_size_override("font_size", 14)
	start_button.pressed.connect(_launch_next_wave)
	row.add_child(start_button)

func _toggle_coverage(enabled: bool) -> void:
	board.set_coverage_enabled(enabled)
	coverage_button.text = "COVERAGE ON" if enabled else "COVERAGE OFF"

func _cycle_speed() -> void:
	var index := SPEEDS.find(simulation_speed)
	simulation_speed = SPEEDS[(index + 1) % SPEEDS.size()]
	board.simulation_speed = simulation_speed
	speed_button.text = "SPEED %d×" % simulation_speed

func _update_coverage_readout() -> void:
	if not board.coverage_enabled:
		coverage_label.text = ""
		return
	var snapshot := board.coverage_snapshot()
	if snapshot.is_empty():
		coverage_label.text = "Select a node or preview a link\nto inspect coverage and cadence."
		return
	var lanes: Array[bool] = snapshot["lanes"]
	var lane_text := "▲ TOP" if lanes[0] else ""
	if lanes[1]:
		lane_text += " + ▼ BOTTOM" if not lane_text.is_empty() else "▼ BOTTOM"
	if lane_text.is_empty():
		lane_text = "NO LINK COVERAGE"
	var lines: Array[String] = ["%s  ~%.1fs  %s" % [snapshot["title"], snapshot["interval"], lane_text]]
	if snapshot["warning"]:
		lines.append("SPLIT: existing branches pulse slower")
	for row_text in snapshot["rows"]:
		lines.append(row_text)
	coverage_label.text = "\n".join(lines)

func _hud_label(text_value: String, color: Color, width: float) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(width, 40)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	return label

func _process(delta: float) -> void:
	if is_instance_valid(_exit_confirmation) and difficulty == "easy":
		return
	if countdown < 0.0 or _run_over:
		return
	countdown -= delta
	var second := maxi(0, ceili(countdown))
	if second != _last_countdown_second:
		_last_countdown_second = second
		start_button.text = "AUTO %d" % second
		_set_status("Next wave auto-launches in %d… build live." % second)
	if countdown <= 0.0:
		countdown = -1.0
		_launch_next_wave()

func _request_menu_exit() -> void:
	if _run_over or is_instance_valid(_exit_confirmation):
		return
	if difficulty == "easy":
		board.set_process(false)
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.025, 0.06, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_exit_confirmation = overlay
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 230)
	center.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "RETURN TO SIGNAL MAP?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("62f4d2"))
	column.add_child(title)
	var message := Label.new()
	message.text = "Your current run will be lost."
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(actions)
	var keep_playing := Button.new()
	keep_playing.text = "KEEP PLAYING"
	keep_playing.custom_minimum_size = Vector2(220, 56)
	keep_playing.pressed.connect(_cancel_menu_exit)
	actions.add_child(keep_playing)
	var return_to_menu := Button.new()
	return_to_menu.text = "RETURN TO MAP"
	return_to_menu.custom_minimum_size = Vector2(260, 56)
	return_to_menu.pressed.connect(_confirm_menu_exit)
	actions.add_child(return_to_menu)
	keep_playing.grab_focus()

func _cancel_menu_exit() -> void:
	if not is_instance_valid(_exit_confirmation):
		return
	_exit_confirmation.queue_free()
	_exit_confirmation = null
	if difficulty == "easy":
		board.set_process(true)
	menu_button.grab_focus()

func _confirm_menu_exit() -> void:
	if not is_instance_valid(_exit_confirmation):
		return
	exit_requested.emit()

func _select_tower(type: StringName) -> void:
	if not board.build_allowed:
		_set_status("Construction is locked right now")
		return
	board.set_selected_tower(type)
	_refresh_specialization_ui()
	var definition: Dictionary = GameData.tower_definitions()[type]
	_set_status("%s selected • tap a cell, then confirm" % definition["name"])
	for tower_type in tower_buttons:
		tower_buttons[tower_type].modulate = Color.WHITE if tower_type == type else Color(0.72, 0.8, 0.9)

func _on_node_selected(node_id: int) -> void:
	if node_id <= 0:
		node_label.text = "CORE"
		rewire_button.disabled = true
		sell_button.disabled = true
		_refresh_specialization_ui()
		return
	var type: StringName = board.graph.nodes[node_id]["type"]
	node_label.text = "%s  •  NODE %d" % [GameData.tower_definitions()[type]["name"], node_id]
	rewire_button.disabled = not board.build_allowed
	sell_button.disabled = not board.build_allowed
	_refresh_specialization_ui()

func _refresh_specialization_ui() -> void:
	if not is_instance_valid(specialization_button):
		return
	var node_id := board.selected_node_id
	if node_id <= 0 or not board.graph.nodes.has(node_id):
		specialization_button.text = "SELECT A NODE"
		specialization_button.disabled = true
		return
	var node: Dictionary = board.graph.nodes[node_id]
	if node["type"] == &"relay":
		specialization_button.text = "RELAY · ROUTING"
		specialization_button.disabled = true
		return
	var choice: StringName = node["specialization"]
	if choice != &"":
		var definition: Dictionary = GameData.specialization_definitions()[node["type"]][0 if choice == &"a" else 1]
		specialization_button.text = "%s · %s" % [choice.to_upper(), definition["name"]]
		specialization_button.tooltip_text = definition["description"]
		specialization_button.disabled = true
		return
	var progress := mini(int(node["participated_waves"]), GameData.SPECIALIZATION_WAVES)
	if progress < GameData.SPECIALIZATION_WAVES:
		specialization_button.text = "PULSED WAVES %d / %d" % [progress, GameData.SPECIALIZATION_WAVES]
	else:
		specialization_button.text = "SPECIALIZE · %d" % GameData.SPECIALIZATION_COST
	specialization_button.tooltip_text = "Choose one specialization for this tower"
	specialization_button.disabled = progress < GameData.SPECIALIZATION_WAVES or not board.build_allowed or board.charge < GameData.SPECIALIZATION_COST or _run_over

func _show_specializations() -> void:
	var node_id := board.selected_node_id
	if _run_over or is_instance_valid(_specialization_overlay) or not board.graph.can_specialize(node_id) or not board.build_allowed or board.charge < GameData.SPECIALIZATION_COST:
		return
	var type: StringName = board.graph.nodes[node_id]["type"]
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.025, 0.06, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_specialization_overlay = overlay
	var panel := PanelContainer.new()
	panel.position = Vector2(285, 175)
	panel.size = Vector2(710, 370)
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "%s · NODE %d" % [GameData.tower_definitions()[type]["name"], node_id]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Choose one specialization · %d charge" % GameData.SPECIALIZATION_COST
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var definitions: Array = GameData.specialization_definitions()[type]
	for index in range(2):
		var definition: Dictionary = definitions[index]
		var button := Button.new()
		button.text = "%s · %s\n\n%s" % ["A" if index == 0 else "B", definition["name"], definition["description"]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(335, 200)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_specialization.bind(node_id, &"a" if index == 0 else &"b", overlay))
		row.add_child(button)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.pressed.connect(overlay.queue_free)
	column.add_child(cancel)

func _choose_specialization(node_id: int, choice: StringName, overlay: Control) -> void:
	if not _run_over and board.buy_specialization(node_id, choice):
		overlay.queue_free()
	else:
		_set_status("Specialization unavailable")
		overlay.queue_free()

func _rewire_selected() -> void:
	board.begin_rewire(board.selected_node_id)

func _sell_selected() -> void:
	board.sell_node(board.selected_node_id)
	node_label.text = "SELECT A NODE"
	rewire_button.disabled = true
	sell_button.disabled = true
	_refresh_specialization_ui()

func _toggle_tactical_pause() -> void:
	if difficulty != "easy" or not board.wave_active:
		return
	board.set_combat_paused(not board.combat_paused)
	pause_button.text = "RESUME" if board.combat_paused else "PAUSE"
	_set_status("Tactical pause • combat frozen" if board.combat_paused else "Combat resumed • build live")
	_update_build_policy()

func _launch_next_wave() -> void:
	if board.wave_active or _run_over:
		return
	_ensure_next_manifest()
	if next_wave_index >= manifests.size(): return
	countdown = -1.0
	board.set_combat_paused(false)
	pause_button.text = "PAUSE"
	var manifest := manifests[next_wave_index]
	_last_objective_result = ""
	board.start_wave(manifest)
	if is_instance_valid(sound_manager):
		var boss_wave := false
		for entry in manifest["entries"]:
			if entry["type"] == &"severer": boss_wave = true
		sound_manager.play_music(&"boss" if boss_wave else &"combat")
	next_wave_index += 1
	start_button.disabled = true
	start_button.text = "WAVE ACTIVE"
	wave_label.text = "WAVE %d / ∞" % next_wave_index if difficulty == "endless" else "WAVE %d / %d" % [next_wave_index, GameData.MAX_WAVES]
	_update_wave_preview()
	_update_build_policy()
	_set_status("Signals live • watch the routing cadence")

func _on_wave_finished() -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play_music(&"ambient")
	if _run_over:
		return
	if not board.objective.is_empty():
		_last_objective_result = "LAST GOAL\n+%d CHARGE" % int(board.objective["bonus"]) if board.objective_status == &"complete" else "LAST GOAL\nFAILED"
	_update_objective_readout()
	if difficulty != "endless" and next_wave_index >= GameData.MAX_WAVES:
		_finish_run(true)
		return
	if next_wave_index % 2 == 0:
		_show_draft()
	else:
		_enter_intermission()

func _enter_intermission() -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play_music(&"ambient")
	_update_wave_preview()
	_update_build_policy()
	if difficulty == "hardcore":
		countdown = 5.0
		_last_countdown_second = -1
		start_button.disabled = true
	else:
		start_button.disabled = false
		start_button.text = "LAUNCH\nWAVE %d" % (next_wave_index + 1)
		_set_status("Planning window • revise your topology")

func _on_run_failed(wave_reached: int) -> void:
	_finish_run(false, wave_reached)

func _finish_run(victory: bool, wave_reached: int = -1) -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play_music(&"ambient")
	_run_over = true
	if is_instance_valid(_specialization_overlay):
		_specialization_overlay.queue_free()
		_specialization_overlay = null
	_refresh_specialization_ui()
	board.set_process(false)
	var reached := GameData.MAX_WAVES if victory else (wave_reached if wave_reached >= 0 else next_wave_index)
	run_ended.emit(reached, victory, difficulty, seed_value, run_mutators)

func _update_build_policy() -> void:
	var allowed := is_build_allowed(difficulty, board.wave_active)
	board.set_build_allowed(allowed)
	for type in tower_buttons:
		tower_buttons[type].disabled = not allowed
	rewire_button.disabled = not allowed or board.selected_node_id <= 0
	sell_button.disabled = not allowed or board.selected_node_id <= 0
	_refresh_specialization_ui()

static func is_build_allowed(difficulty_id: String, wave_active: bool) -> bool:
	return not wave_active or difficulty_id in ["easy", "hardcore"]

func _ensure_next_manifest() -> void:
	if difficulty == "endless" and next_wave_index >= manifests.size():
		manifests.append(RunGenerator.generate_wave(seed_value, next_wave_index + 1, level, true, run_mutators))

func _update_wave_preview() -> void:
	_ensure_next_manifest()
	for child in intel_types.get_children():
		intel_types.remove_child(child)
		child.queue_free()
	if next_wave_index >= manifests.size():
		intel_label.text = "NO FURTHER\nSIGNALS"
		intel_meta_label.text = ""
		_update_objective_readout()
		return
	var manifest := manifests[next_wave_index]
	var summary := RunGenerator.summarize(manifest)
	var definitions := GameData.enemy_definitions()
	intel_label.text = "WAVE %d" % (next_wave_index + 1)
	match difficulty:
		"easy":
			for type in summary["counts"]:
				_add_intel_type_row(type, "%s ×%d" % [definitions[type]["name"], summary["counts"][type]])
			intel_meta_label.text = "▲ %d  ▼ %d" % [summary["lanes"][0], summary["lanes"][1]]
		"normal", "endless":
			for type in summary["counts"]:
				_add_intel_type_row(type, definitions[type]["name"])
			var top_word := _threat_word(int(summary["lanes"][0]))
			var bottom_word := _threat_word(int(summary["lanes"][1]))
			intel_meta_label.text = "▲ %s\n▼ %s" % [top_word, bottom_word]
		_:
			var boss_warning := "\n\nBOSS SIGNAL" if next_wave_index == 9 else ""
			var support_warning := "\n\nSUPPORT SIGNAL" if summary["counts"].has(&"shielder") else ""
			intel_meta_label.text = "THREAT\n%s%s%s" % [_threat_word(int(summary["total"])), support_warning, boss_warning]
	_update_objective_readout()

func _on_objective_changed(_status: StringName) -> void:
	_update_objective_readout()

func _update_objective_readout() -> void:
	var lines: Array[String] = []
	if board.wave_active:
		if not board.objective.is_empty():
			lines.append(_objective_text(board.objective, manifests[board.current_wave - 1]))
			match board.objective_status:
				&"complete": lines.append("SECURED")
				&"failed": lines.append("FAILED")
				_: lines.append("ACTIVE")
	else:
		if not _last_objective_result.is_empty():
			lines.append(_last_objective_result)
		if next_wave_index < manifests.size():
			var manifest := manifests[next_wave_index]
			var next_objective: Dictionary = manifest.get("objective", {})
			if not next_objective.is_empty():
				lines.append(_objective_text(next_objective, manifest))
	objective_label.text = "\n\n".join(lines)
	objective_label.visible = not lines.is_empty()

func _objective_text(goal: Dictionary, manifest: Dictionary) -> String:
	if goal["kind"] == "no_leaks":
		return "BONUS +%d\nNO LEAKS\n%s LANE" % [int(goal["bonus"]), "▲ TOP" if int(goal["lane"]) == 0 else "▼ BOTTOM"]
	var entry: Dictionary = manifest["entries"][int(goal["entry_index"])]
	var name := str(GameData.enemy_definitions()[entry["type"]]["name"]).to_upper()
	return "BONUS +%d\nKILL MARKED\n%s %s\nBEFORE MIDPOINT" % [int(goal["bonus"]), name, "▲" if int(entry["lane"]) == 0 else "▼"]

func _add_intel_type_row(type: StringName, row_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	intel_types.add_child(row)
	var icon := TextureRect.new()
	icon.texture = GameArt.enemy_icon(type)
	icon.modulate = GameData.enemy_definitions()[type]["color"]
	icon.custom_minimum_size = Vector2(18, 18)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	var label := Label.new()
	label.text = row_text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 12)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

func _threat_word(count: int) -> String:
	if count <= 5: return "LOW"
	if count <= 11: return "MEDIUM"
	if count <= 18: return "HIGH"
	return "EXTREME"

func _show_draft() -> void:
	board.set_combat_paused(true)
	board.set_build_allowed(false)
	var available: Array[String] = []
	for card_id in deck:
		if card_id not in drafted_cards:
			available.append(card_id)
	if available.size() < 3:
		available = deck.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 65537 + next_wave_index * 31337
	var offers: Array[String] = []
	while offers.size() < mini(3, available.size()):
		var candidate := available[rng.randi_range(0, available.size() - 1)]
		if candidate not in offers: offers.append(candidate)
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.025, 0.06, 0.92)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(220, 125)
	panel.size = Vector2(840, 470)
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "CHOOSE A MUTATION"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("62f4d2"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Your draft changes the network, not a damage level."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_color", Color("7b9bb6"))
	column.add_child(subtitle)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	for card_id in offers:
		var card: Dictionary = GameData.card_definitions()[card_id]
		var button := Button.new()
		button.text = "%s%s\n\n%s" % ["◆ " if card["advanced"] else "", card["name"], card["description"]]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(248, 285)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_choose_card.bind(card_id, overlay))
		row.add_child(button)

func _choose_card(card_id: String, overlay: Control) -> void:
	drafted_cards.append(card_id)
	board.apply_card(card_id)
	overlay.queue_free()
	board.set_combat_paused(false)
	_enter_intermission()

func _show_tutorial() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.01, 0.025, 0.06, 0.9)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var panel := PanelContainer.new()
	panel.position = Vector2(285, 110)
	panel.size = Vector2(710, 500)
	overlay.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "THE NETWORK IS THE WEAPON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 29)
	title.add_theme_color_override("font_color", Color("62f4d2"))
	column.add_child(title)
	var body := Label.new()
	body.text = "1. Place a RELAY within four cells of the Core.\n\n2. Place a damage tower so its connection crosses an enemy lane. Tap a cell once to preview, then again to confirm.\n\n3. Start the wave. Core pulses travel along links; the link activates in transit and the tower fires on arrival.\n\n4. Branching alternates pulses. More coverage means a slower cadence on each branch.\n\nRight-click or use another tower button to cancel a placement."
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 19)
	column.add_child(body)
	var button := Button.new()
	button.text = "ENTER THE GRID"
	button.custom_minimum_size = Vector2(0, 58)
	button.pressed.connect(func():
		overlay.queue_free()
		tutorial_completed.emit()
	)
	column.add_child(button)

func _on_charge_changed(value: int) -> void:
	charge_label.text = "CHARGE %d" % value
	_refresh_specialization_ui()

func _on_integrity_changed(value: int) -> void:
	integrity_label.text = "CORE %d" % value

func _set_status(text: String) -> void:
	status_label.text = text

func _play_sound(event: StringName) -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play_sfx(event)
