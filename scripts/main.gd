extends Control

var save_data := {}
var purchase_provider := DebugPurchaseProvider.new()
var content_root: Control
var sound_manager: SoundManager
var last_seed := 0
var last_difficulty := "normal"

func _ready() -> void:
	theme = ThemeFactory.create_theme()
	var backdrop := NeuralBackground.new()
	backdrop.z_index = -10
	add_child(backdrop)
	sound_manager = SoundManager.new()
	add_child(sound_manager)
	save_data = SaveService.load_data()
	sound_manager.set_sound_volume(float(save_data["sound_volume"]))
	sound_manager.set_music_volume(float(save_data["music_volume"]))
	purchase_provider.purchase_completed.connect(_on_debug_purchase_completed)
	purchase_provider.purchase_failed.connect(_show_notice)
	purchase_provider.restore_completed.connect(_on_restore_completed)
	_show_main_menu()

func _clear_content() -> void:
	if is_instance_valid(content_root):
		content_root.queue_free()
	content_root = Control.new()
	content_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content_root)

func _show_main_menu() -> void:
	sound_manager.play_music(&"ambient")
	_clear_content()
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_root.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(560, 0)
	center.add_child(column)
	var title := Label.new()
	title.text = "SYNAPSE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 76)
	title.add_theme_color_override("font_color", Color("62f4d2"))
	column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "THE NETWORK IS THE WEAPON"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 18)
	subtitle.add_theme_color_override("font_color", Color("7b9bb6"))
	column.add_child(subtitle)
	column.add_child(_vertical_gap(28))
	var play := _menu_button("START RUN", Color("62f4d2"))
	play.pressed.connect(_show_difficulty_select)
	column.add_child(play)
	var deck := _menu_button("DECK  •  %d / 8" % save_data["deck"].size(), Color("9c82ff"))
	deck.pressed.connect(_show_deck_builder)
	column.add_child(deck)
	var store := _menu_button("GENE LAB  •  %d SHARDS" % int(save_data["gene_shards"]), Color("ff5ba7"))
	store.pressed.connect(_show_store)
	column.add_child(store)
	var guide := _menu_button("HOW TO PLAY", Color("33c8ff"))
	guide.pressed.connect(_show_how_to_play)
	column.add_child(guide)
	var settings := _menu_button("AUDIO SETTINGS", Color("7b9bb6"))
	settings.pressed.connect(_show_audio_settings)
	column.add_child(settings)
	var footer := Label.new()
	footer.text = "Mobile-first vertical slice  •  Mouse + touch  •  Local progression"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_color_override("font_color", Color("526f87"))
	footer.add_theme_font_size_override("font_size", 13)
	column.add_child(footer)

func _show_audio_settings() -> void:
	_clear_content()
	var shell := _page_shell("AUDIO SETTINGS", "Set music and sound effect levels.")
	var body: VBoxContainer = shell["body"]
	_add_volume_slider(body, "MUSIC", "music_volume")
	_add_volume_slider(body, "SOUND EFFECTS", "sound_volume")
	_add_back_button(body, _show_main_menu)

func _add_volume_slider(parent: VBoxContainer, label_text: String, save_key: String) -> void:
	var label := Label.new()
	label.text = "%s  %d%%" % [label_text, roundi(float(save_data[save_key]) * 100.0)]
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(save_data[save_key])
	slider.custom_minimum_size = Vector2(0, 48)
	slider.value_changed.connect(func(value: float):
		save_data[save_key] = value
		label.text = "%s  %d%%" % [label_text, roundi(value * 100.0)]
		if save_key == "music_volume":
			sound_manager.set_music_volume(value)
		else:
			sound_manager.set_sound_volume(value)
		SaveService.save_data(save_data)
	)
	parent.add_child(slider)

func _show_difficulty_select() -> void:
	_clear_content()
	var shell := _page_shell("SELECT SIGNAL PRESSURE", "The enemy manifest stays identical. Information and build timing change.")
	var body: VBoxContainer = shell["body"]
	var row := HBoxContainer.new()
	body.add_child(row)
	for difficulty_id in ["easy", "normal", "hardcore"]:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(330, 385)
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var column := VBoxContainer.new()
		panel.add_child(column)
		var name := Label.new()
		name.text = GameData.difficulty_name(difficulty_id)
		name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name.add_theme_font_size_override("font_size", 23)
		name.add_theme_color_override("font_color", _difficulty_color(difficulty_id))
		column.add_child(name)
		var description := Label.new()
		description.text = GameData.difficulty_description(difficulty_id)
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_vertical = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(description)
		var best := Label.new()
		best.text = "BEST WAVE  %d / 10" % int(save_data["best_wave"][difficulty_id])
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_color_override("font_color", Color("7b9bb6"))
		column.add_child(best)
		var button := Button.new()
		button.text = "ENTER"
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(_start_new_run.bind(difficulty_id, 0))
		column.add_child(button)
	_add_back_button(body, _show_main_menu)

func _start_new_run(difficulty_id: String, requested_seed: int) -> void:
	var seed_to_use := requested_seed
	if seed_to_use <= 0:
		seed_to_use = randi_range(100000, 999999999)
	last_seed = seed_to_use
	last_difficulty = difficulty_id
	save_data["last_difficulty"] = difficulty_id
	SaveService.save_data(save_data)
	_clear_content()
	var game := GameController.new()
	content_root.add_child(game)
	game.sound_manager = sound_manager
	game.exit_requested.connect(_show_main_menu)
	game.run_ended.connect(_on_run_ended)
	game.tutorial_completed.connect(_on_tutorial_completed)
	game.setup(difficulty_id, seed_to_use, save_data["deck"], not bool(save_data["tutorial_seen"]))
	sound_manager.play_music(&"ambient")

func _on_tutorial_completed() -> void:
	save_data["tutorial_seen"] = true
	SaveService.save_data(save_data)

func _on_run_ended(wave_reached: int, victory: bool, difficulty_id: String, seed_value: int) -> void:
	var reward := 0
	if victory: reward = 3
	elif wave_reached >= 8: reward = 2
	elif wave_reached >= 5: reward = 1
	save_data["gene_shards"] = int(save_data["gene_shards"]) + reward
	save_data["best_wave"][difficulty_id] = maxi(int(save_data["best_wave"][difficulty_id]), wave_reached)
	SaveService.save_data(save_data)
	_show_results(wave_reached, victory, difficulty_id, seed_value, reward)

func _show_results(wave_reached: int, victory: bool, difficulty_id: String, seed_value: int, reward: int) -> void:
	sound_manager.play_music(&"ambient")
	if victory:
		sound_manager.play_sfx(&"victory")
	_clear_content()
	var shell := _page_shell("CORE STABLE" if victory else "CORE COLLAPSED", "The network survived." if victory else "The pattern failed. Rebuild the geometry.")
	var body: VBoxContainer = shell["body"]
	var summary := Label.new()
	summary.text = "WAVE  %d / 10\nMODE  %s\nSEED  %d\n\nGENE SHARDS  +%d" % [wave_reached, GameData.difficulty_name(difficulty_id), seed_value, reward]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 25)
	summary.add_theme_color_override("font_color", Color("62f4d2") if victory else Color("ff6b91"))
	body.add_child(summary)
	body.add_child(_vertical_gap(20))
	var replay := _menu_button("REPLAY THIS SEED", Color("9c82ff"))
	replay.pressed.connect(_start_new_run.bind(difficulty_id, seed_value))
	body.add_child(replay)
	var fresh := _menu_button("NEW RUN", Color("62f4d2"))
	fresh.pressed.connect(_show_difficulty_select)
	body.add_child(fresh)
	_add_back_button(body, _show_main_menu, "MAIN MENU")

func _show_deck_builder() -> void:
	_clear_content()
	var shell := _page_shell("MUTATION DECK", "Select exactly eight owned cards. Draft offers are drawn from this deck.")
	var body: VBoxContainer = shell["body"]
	var owned := SaveService.owned_card_ids(save_data)
	var selection: Array[String] = []
	for id in save_data["deck"]:
		if str(id) in owned: selection.append(str(id))
	var count_label := Label.new()
	count_label.text = "SELECTED  %d / 8" % selection.size()
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", Color("62f4d2"))
	body.add_child(count_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 440)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	var buttons: Dictionary = {}
	for id in GameData.BASE_CARD_IDS + GameData.ADVANCED_CARD_IDS:
		var card: Dictionary = GameData.card_definitions()[id]
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = id in selection
		button.disabled = id not in owned
		button.text = "%s%s\n%s%s" % ["◆ " if card["advanced"] else "", card["name"], card["description"], "\nLOCKED • GENE LAB" if id not in owned else ""]
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(495, 100)
		grid.add_child(button)
		buttons[id] = button
		button.toggled.connect(func(pressed: bool, card_id: String = id):
			if pressed:
				if selection.size() >= 8:
					buttons[card_id].set_pressed_no_signal(false)
				else:
					selection.append(card_id)
			else:
				selection.erase(card_id)
			count_label.text = "SELECTED  %d / 8" % selection.size()
		)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	var back := Button.new()
	back.text = "CANCEL"
	back.custom_minimum_size = Vector2(180, 52)
	back.pressed.connect(_show_main_menu)
	actions.add_child(back)
	var save_button := Button.new()
	save_button.text = "SAVE DECK"
	save_button.custom_minimum_size = Vector2(220, 52)
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(func():
		if selection.size() != 8:
			_show_notice("Select exactly eight cards")
			return
		save_data["deck"] = selection.duplicate()
		SaveService.save_data(save_data)
		_show_main_menu()
	)
	actions.add_child(save_button)

func _show_store() -> void:
	_clear_content()
	var shell := _page_shell("GENE LAB", "Unlock known cards directly. No random paid packs.")
	var body: VBoxContainer = shell["body"]
	var shard_label := Label.new()
	shard_label.text = "GENE SHARDS  %d" % int(save_data["gene_shards"])
	shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_label.add_theme_font_size_override("font_size", 24)
	shard_label.add_theme_color_override("font_color", Color("ff5ba7"))
	body.add_child(shard_label)
	var product: Dictionary = purchase_provider.list_products()[0]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 360)
	body.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	var title := Label.new()
	title.text = "◆ ADVANCED NETWORK PACK"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color("9c82ff"))
	column.add_child(title)
	var description := Label.new()
	description.text = "Synchronized Split  •  Parallel Roots  •  Phase Axon  •  Cross-Synapse\n\nStronger topology tools, earnable through play or unlocked immediately. The free deck can complete every run."
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	column.add_child(description)
	var owned: bool = "advanced_network_pack" in save_data["owned_packs"]
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var earn := Button.new()
	earn.text = "OWNED" if owned else "UNLOCK • 12 SHARDS"
	earn.disabled = owned or int(save_data["gene_shards"]) < 12
	earn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	earn.custom_minimum_size = Vector2(0, 56)
	earn.pressed.connect(_unlock_advanced_with_shards)
	actions.add_child(earn)
	var debug_buy := Button.new()
	debug_buy.text = "OWNED" if owned else str(product["price"])
	debug_buy.disabled = owned
	debug_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	debug_buy.custom_minimum_size = Vector2(0, 56)
	debug_buy.tooltip_text = "Simulates a non-consumable platform purchase. No money is processed."
	debug_buy.pressed.connect(purchase_provider.purchase.bind(DebugPurchaseProvider.PRODUCT_ID))
	actions.add_child(debug_buy)
	var restore := Button.new()
	restore.text = "RESTORE DEBUG ENTITLEMENTS"
	restore.pressed.connect(purchase_provider.restore.bind(save_data["owned_packs"]))
	column.add_child(restore)
	var disclaimer := Label.new()
	disclaimer.text = "BROWSER SLICE • DEBUG PURCHASE PROVIDER • NO REAL PAYMENT"
	disclaimer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	disclaimer.add_theme_color_override("font_color", Color("ffca65"))
	disclaimer.add_theme_font_size_override("font_size", 13)
	column.add_child(disclaimer)
	_add_back_button(body, _show_main_menu)

func _unlock_advanced_with_shards() -> void:
	if int(save_data["gene_shards"]) < 12 or "advanced_network_pack" in save_data["owned_packs"]:
		return
	save_data["gene_shards"] = int(save_data["gene_shards"]) - 12
	_unlock_advanced_pack()
	_show_store()

func _on_debug_purchase_completed(_product_id: String) -> void:
	_unlock_advanced_pack()
	_show_store()

func _unlock_advanced_pack() -> void:
	if "advanced_network_pack" not in save_data["owned_packs"]:
		save_data["owned_packs"].append("advanced_network_pack")
	SaveService.save_data(save_data)
	sound_manager.play_sfx(&"unlock")

func _on_restore_completed(products: Array[String]) -> void:
	_show_notice("Restored %d debug entitlement(s)" % products.size())

func _show_how_to_play() -> void:
	_clear_content()
	var shell := _page_shell("HOW TO ROUTE POWER", "Placement controls both link effects and tower attacks.")
	var body: VBoxContainer = shell["body"]
	var guide := Label.new()
	guide.text = "BUILD\nChoose a tower, tap an empty cell to preview its nearest valid parent, then tap again to confirm. Connections cannot pass through dark scar tissue unless Phase Axon is active. Select a node to rewire or recycle its whole branch.\n\nPULSES\nThe Core sends pulses down every root branch. A destination tower defines the inbound link effect, then fires when the pulse arrives. Relays rotate between child branches, so coverage trades against cadence.\n\nCOUNTERS\nHusks resist turrets. Phase Mites resist links. Leeches and the Severer disable crossed links. Use both halves of the network and avoid a single fragile trunk.\n\nDRAFTS\nAfter every second wave, select a topology mutation from your eight-card deck. Cards last for the current run. Permanent collection unlocks only expand deck-building choices."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide.add_theme_font_size_override("font_size", 18)
	body.add_child(guide)
	_add_back_button(body, _show_main_menu)

func _page_shell(title_text: String, subtitle_text: String) -> Dictionary:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 90)
	margin.add_theme_constant_override("margin_right", 90)
	margin.add_theme_constant_override("margin_top", 35)
	margin.add_theme_constant_override("margin_bottom", 35)
	content_root.add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var body := VBoxContainer.new()
	panel.add_child(body)
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color("62f4d2"))
	body.add_child(title)
	var subtitle := Label.new()
	subtitle.text = subtitle_text
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.add_theme_color_override("font_color", Color("7b9bb6"))
	body.add_child(subtitle)
	body.add_child(HSeparator.new())
	return {"body": body, "panel": panel}

func _menu_button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_color_override("font_hover_color", accent)
	button.pressed.connect(func(): sound_manager.play_sfx(&"click"))
	return button

func _add_back_button(parent: VBoxContainer, callback: Callable, text_value: String = "BACK") -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(0, 50)
	button.pressed.connect(callback)
	button.pressed.connect(func(): sound_manager.play_sfx(&"click"))
	parent.add_child(button)

func _vertical_gap(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, height)
	return spacer

func _difficulty_color(id: String) -> Color:
	match id:
		"easy": return Color("62f4d2")
		"hardcore": return Color("ff5b74")
	return Color("9c82ff")

func _show_notice(message: String) -> void:
	var notice := PanelContainer.new()
	notice.position = Vector2(390, 620)
	notice.size = Vector2(500, 64)
	content_root.add_child(notice)
	var label := Label.new()
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice.add_child(label)
	get_tree().create_timer(2.2).timeout.connect(notice.queue_free)
