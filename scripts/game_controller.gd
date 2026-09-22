class_name GameController
extends Control

signal exit_requested
signal run_ended(wave_reached: int, victory: bool, difficulty: String, seed_value: int)
signal tutorial_completed

var difficulty := "normal"
var seed_value := 0
var deck: Array[String] = []
var manifests: Array[Dictionary] = []
var next_wave_index := 0
var drafted_cards: Array[String] = []

var board: GameBoard
var charge_label: Label
var integrity_label: Label
var wave_label: Label
var mode_label: Label
var intel_label: Label
var status_label: Label
var start_button: Button
var pause_button: Button
var cycle_button: Button
var rewire_button: Button
var sell_button: Button
var node_label: Label
var tower_buttons: Dictionary = {}
var countdown := -1.0
var _last_countdown_second := -1
var _run_over := false
var sound_manager: SoundManager

func setup(p_difficulty: String, p_seed: int, p_deck: Array, show_tutorial: bool) -> void:
	difficulty = p_difficulty
	seed_value = p_seed
	for card_id in p_deck:
		deck.append(str(card_id))
	manifests = RunGenerator.generate_run(seed_value)
	_build_ui()
	board.configure(seed_value, difficulty)
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
	wave_label = _hud_label("WAVE 0 / 10", Color("d8edff"), 175)
	mode_label = _hud_label(GameData.difficulty_name(difficulty), Color("9c82ff"), 260)
	top_row.add_child(charge_label)
	top_row.add_child(integrity_label)
	top_row.add_child(wave_label)
	top_row.add_child(mode_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)
	var seed_label := _hud_label("SEED %d" % seed_value, Color("7b9bb6"), 170)
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(seed_label)
	var menu_button := Button.new()
	menu_button.text = "MENU"
	menu_button.custom_minimum_size = Vector2(90, 44)
	menu_button.pressed.connect(func(): exit_requested.emit())
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
	intel_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	intel_label.add_theme_font_size_override("font_size", 13)
	intel_column.add_child(intel_label)
	var legend := Label.new()
	legend.text = "▲ TOP LANE\n▼ BOTTOM\n\nPulses route\nfrom the Core."
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.add_theme_font_size_override("font_size", 12)
	legend.add_theme_color_override("font_color", Color("7b9bb6"))
	intel_column.add_child(legend)

	board = GameBoard.new()
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

	var bottom := PanelContainer.new()
	bottom.position = Vector2(8, 604)
	bottom.size = Vector2(1264, 108)
	add_child(bottom)
	var row := HBoxContainer.new()
	bottom.add_child(row)
	for type in GameData.TOWER_ORDER:
		var definition: Dictionary = GameData.tower_definitions()[type]
		var button := Button.new()
		button.text = "%s  •  %d\n%s" % [definition["name"], definition["cost"], str(definition["tagline"]).to_upper()]
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
	start_button = Button.new()
	start_button.text = "LAUNCH\nWAVE 1"
	start_button.custom_minimum_size = Vector2(132, 72)
	start_button.add_theme_font_size_override("font_size", 14)
	start_button.pressed.connect(_launch_next_wave)
	row.add_child(start_button)

func _hud_label(text_value: String, color: Color, width: float) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(width, 40)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 18)
	return label

func _process(delta: float) -> void:
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

func _select_tower(type: StringName) -> void:
	if not board.build_allowed:
		_set_status("Construction is locked right now")
		return
	board.set_selected_tower(type)
	var definition: Dictionary = GameData.tower_definitions()[type]
	_set_status("%s selected • tap a cell, then confirm" % definition["name"])
	for tower_type in tower_buttons:
		tower_buttons[tower_type].modulate = Color.WHITE if tower_type == type else Color(0.72, 0.8, 0.9)

func _on_node_selected(node_id: int) -> void:
	if node_id <= 0:
		node_label.text = "CORE"
		rewire_button.disabled = true
		sell_button.disabled = true
		return
	var type: StringName = board.graph.nodes[node_id]["type"]
	node_label.text = "%s  •  NODE %d" % [GameData.tower_definitions()[type]["name"], node_id]
	rewire_button.disabled = not board.build_allowed
	sell_button.disabled = not board.build_allowed

func _rewire_selected() -> void:
	board.begin_rewire(board.selected_node_id)

func _sell_selected() -> void:
	board.sell_node(board.selected_node_id)
	node_label.text = "SELECT A NODE"
	rewire_button.disabled = true
	sell_button.disabled = true

func _toggle_tactical_pause() -> void:
	if difficulty != "easy" or not board.wave_active:
		return
	board.set_combat_paused(not board.combat_paused)
	pause_button.text = "RESUME" if board.combat_paused else "PAUSE"
	_set_status("Tactical pause • combat frozen" if board.combat_paused else "Combat resumed • build live")
	_update_build_policy()

func _launch_next_wave() -> void:
	if next_wave_index >= manifests.size() or board.wave_active or _run_over:
		return
	countdown = -1.0
	board.set_combat_paused(false)
	pause_button.text = "PAUSE"
	var manifest := manifests[next_wave_index]
	board.start_wave(manifest)
	if is_instance_valid(sound_manager):
		sound_manager.play_music(&"boss" if next_wave_index == 9 else &"combat")
	next_wave_index += 1
	start_button.disabled = true
	start_button.text = "WAVE ACTIVE"
	wave_label.text = "WAVE %d / %d" % [next_wave_index, GameData.MAX_WAVES]
	_update_wave_preview()
	_update_build_policy()
	_set_status("Signals live • watch the routing cadence")

func _on_wave_finished() -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play_music(&"ambient")
	if _run_over:
		return
	if next_wave_index >= GameData.MAX_WAVES:
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
	board.set_process(false)
	var reached := GameData.MAX_WAVES if victory else (wave_reached if wave_reached >= 0 else next_wave_index)
	run_ended.emit(reached, victory, difficulty, seed_value)

func _update_build_policy() -> void:
	var allowed := is_build_allowed(difficulty, board.wave_active)
	board.set_build_allowed(allowed)
	for type in tower_buttons:
		tower_buttons[type].disabled = not allowed
	rewire_button.disabled = not allowed or board.selected_node_id <= 0
	sell_button.disabled = not allowed or board.selected_node_id <= 0

static func is_build_allowed(difficulty_id: String, wave_active: bool) -> bool:
	return not wave_active or difficulty_id != "normal"

func _update_wave_preview() -> void:
	if next_wave_index >= manifests.size():
		intel_label.text = "NO FURTHER\nSIGNALS"
		return
	var manifest := manifests[next_wave_index]
	var summary := RunGenerator.summarize(manifest)
	var definitions := GameData.enemy_definitions()
	match difficulty:
		"easy":
			var lines: Array[String] = ["WAVE %d" % (next_wave_index + 1), ""]
			for type in summary["counts"]:
				lines.append("%s ×%d" % [definitions[type]["name"], summary["counts"][type]])
			lines.append("")
			lines.append("▲ %d  ▼ %d" % [summary["lanes"][0], summary["lanes"][1]])
			intel_label.text = "\n".join(lines)
		"normal":
			var names: Array[String] = []
			for type in summary["counts"]: names.append(definitions[type]["name"])
			var top_word := _threat_word(int(summary["lanes"][0]))
			var bottom_word := _threat_word(int(summary["lanes"][1]))
			intel_label.text = "WAVE %d\n\n%s\n\n▲ %s\n▼ %s" % [next_wave_index + 1, "\n".join(names), top_word, bottom_word]
		_:
			var boss_warning := "\n\nBOSS SIGNAL" if next_wave_index == 9 else ""
			intel_label.text = "WAVE %d\n\nTHREAT\n%s%s" % [next_wave_index + 1, _threat_word(int(summary["total"])), boss_warning]

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
	body.text = "1. Place a RELAY within four cells of the Core.\n\n2. Place an ARC so its connection crosses an enemy lane. Tap a cell once to preview, then again to confirm.\n\n3. Start the wave. Core pulses travel along links; the link activates in transit and the tower fires on arrival.\n\n4. Branching alternates pulses. More coverage means a slower cadence on each branch.\n\nRight-click or use another tower button to cancel a placement."
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

func _on_integrity_changed(value: int) -> void:
	integrity_label.text = "CORE %d" % value

func _set_status(text: String) -> void:
	status_label.text = text

func _play_sound(event: StringName) -> void:
	if is_instance_valid(sound_manager):
		sound_manager.play_sfx(event)
