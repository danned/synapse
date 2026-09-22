extends Control

var save_data := {}
var purchase_provider := DebugPurchaseProvider.new()
var content_root: Control
var sound_manager: SoundManager
var last_seed := 0
var last_difficulty := "normal"
var active_level := 1

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
	play.pressed.connect(_show_level_map)
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
	var credits := _menu_button("CREDITS & LICENSE", Color("ffca65"))
	credits.pressed.connect(_show_art_credits)
	column.add_child(credits)
	var settings := _menu_button("AUDIO SETTINGS", Color("7b9bb6"))
	settings.pressed.connect(_show_audio_settings)
	column.add_child(settings)
	var footer := Label.new()
	footer.text = "Five levels  •  Endless challenges  •  Local progression"
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

func _show_level_map() -> void:
	sound_manager.play_music(&"ambient")
	_clear_content()
	var shell := _page_shell("SIGNAL MAP", "Clear each node to open the next route and its Endless challenge.")
	var body: VBoxContainer = shell["body"]
	var map := Control.new()
	map.custom_minimum_size = Vector2(1060, 425)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(map)
	var points := PackedVector2Array([
		Vector2(120, 175), Vector2(330, 270), Vector2(540, 145),
		Vector2(750, 265), Vector2(960, 175)
	])
	var route := Line2D.new()
	route.points = points
	route.width = 9.0
	route.default_color = Color("315479")
	map.add_child(route)
	for level in range(1, LevelData.LEVEL_COUNT + 1):
		var unlocked := SaveService.level_unlocked(save_data, level)
		var cleared := SaveService.endless_unlocked(save_data, level)
		var button := Button.new()
		button.position = points[level - 1] - Vector2(91, 58)
		button.size = Vector2(182, 116)
		button.disabled = not unlocked
		button.text = "LEVEL %d\n%s\n%s" % [level, LevelData.level_name(level), "CLEARED ✓" if cleared else ("AVAILABLE" if unlocked else "LOCKED")]
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", Color("62f4d2") if cleared else Color("d8edff"))
		button.pressed.connect(_show_difficulty_select.bind(level))
		map.add_child(button)
	var progress := Label.new()
	progress.text = "CAMPAIGN  %d / 5 COMPLETE    •    MORTAR AFTER LEVEL 2    •    RIFT AFTER LEVEL 4" % save_data["completed_levels"].size()
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress.add_theme_color_override("font_color", Color("7b9bb6"))
	body.add_child(progress)
	_add_back_button(body, _show_main_menu, "MAIN MENU")

func _show_difficulty_select(level: int) -> void:
	_clear_content()
	var shell := _page_shell("LEVEL %d  •  %s" % [level, LevelData.level_name(level)], "Choose signal pressure, then select three turret types.")
	var body: VBoxContainer = shell["body"]
	var row := HBoxContainer.new()
	body.add_child(row)
	var modes := ["easy", "normal", "hardcore"]
	if SaveService.endless_unlocked(save_data, level): modes.append("endless")
	for difficulty_id in modes:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(240, 385)
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
		best.text = "BEST WAVE  %d%s" % [int(save_data["endless_best"][level - 1]) if difficulty_id == "endless" else int(save_data["campaign_best"][level - 1]), "" if difficulty_id == "endless" else " / 10"]
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_color_override("font_color", Color("7b9bb6"))
		column.add_child(best)
		var button := Button.new()
		button.text = "ENTER"
		button.custom_minimum_size = Vector2(0, 56)
		button.pressed.connect(_show_loadout_select.bind(level, difficulty_id, 0))
		column.add_child(button)
	_add_back_button(body, _show_level_map)

func _show_loadout_select(level: int, difficulty_id: String, requested_seed: int) -> void:
	_clear_content()
	var shell := _page_shell("CHOOSE THREE TURRETS", "Only your selected types can be built in this attempt.")
	var body: VBoxContainer = shell["body"]
	var selected: Array[StringName] = []
	var unlocked := SaveService.unlocked_towers(save_data)
	var counter := Label.new()
	counter.text = "SELECTED  0 / 3"
	counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	counter.add_theme_color_override("font_color", Color("62f4d2"))
	body.add_child(counter)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(grid)
	var enter := _menu_button("ENTER LEVEL", Color("62f4d2"))
	enter.disabled = true
	for type in GameData.TOWER_ORDER:
		var definition: Dictionary = GameData.tower_definitions()[type]
		var button := Button.new()
		button.toggle_mode = true
		button.disabled = type not in unlocked
		button.custom_minimum_size = Vector2(330, 145)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text = "%s  •  %d CHARGE\n%s\n%s" % [definition["name"], definition["cost"], definition["description"], "LOCKED" if type not in unlocked else ""]
		button.toggled.connect(func(pressed: bool, tower_type: StringName = type):
			if pressed:
				if selected.size() >= 3:
					button.set_pressed_no_signal(false)
					return
				selected.append(tower_type)
			else:
				selected.erase(tower_type)
			counter.text = "SELECTED  %d / 3" % selected.size()
			enter.disabled = selected.size() != 3
		)
		grid.add_child(button)
	enter.pressed.connect(func(): _start_new_run(level, difficulty_id, requested_seed, selected))
	body.add_child(enter)
	_add_back_button(body, _show_difficulty_select.bind(level))

func _start_new_run(level: int, difficulty_id: String, requested_seed: int, loadout: Array[StringName]) -> void:
	if not SaveService.level_unlocked(save_data, level) or (difficulty_id == "endless" and not SaveService.endless_unlocked(save_data, level)):
		return
	if not SaveService.valid_loadout(save_data, loadout): return
	var seed_to_use := requested_seed
	if seed_to_use <= 0:
		seed_to_use = randi_range(100000, 999999999)
	last_seed = seed_to_use
	last_difficulty = difficulty_id
	active_level = level
	save_data["last_difficulty"] = difficulty_id
	SaveService.save_data(save_data)
	_clear_content()
	var game := GameController.new()
	content_root.add_child(game)
	game.sound_manager = sound_manager
	game.exit_requested.connect(_show_level_map)
	game.run_ended.connect(_on_run_ended)
	game.tutorial_completed.connect(_on_tutorial_completed)
	game.setup(difficulty_id, seed_to_use, save_data["deck"], not bool(save_data["tutorial_seen"]), level, loadout, save_data.get("perks", {}))
	sound_manager.play_music(&"ambient")

func _on_tutorial_completed() -> void:
	save_data["tutorial_seen"] = true
	SaveService.save_data(save_data)

func _on_run_ended(wave_reached: int, victory: bool, difficulty_id: String, seed_value: int) -> void:
	var reward := 0
	if victory: reward = 3
	elif difficulty_id == "endless" and wave_reached >= 10: reward = 3
	elif wave_reached >= 8: reward = 2
	elif wave_reached >= 5: reward = 1
	save_data["gene_shards"] = int(save_data["gene_shards"]) + reward
	if victory: SaveService.complete_level(save_data, active_level)
	SaveService.record_wave(save_data, active_level, maxi(0, wave_reached - 1) if difficulty_id == "endless" else wave_reached, difficulty_id == "endless")
	if save_data["best_wave"].has(difficulty_id):
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
	summary.text = "LEVEL  %d\n%s  %d%s\nMODE  %s\nSEED  %d\n\nGENE SHARDS  +%d" % [active_level, "WAVES SURVIVED" if difficulty_id == "endless" else "WAVE", maxi(0, wave_reached - 1) if difficulty_id == "endless" else wave_reached, "" if difficulty_id == "endless" else " / 10", "ENDLESS" if difficulty_id == "endless" else GameData.difficulty_name(difficulty_id), seed_value, reward]
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_font_size_override("font_size", 25)
	summary.add_theme_color_override("font_color", Color("62f4d2") if victory else Color("ff6b91"))
	body.add_child(summary)
	body.add_child(_vertical_gap(20))
	var replay := _menu_button("REPLAY THIS SEED", Color("9c82ff"))
	replay.pressed.connect(_show_loadout_select.bind(active_level, difficulty_id, seed_value))
	body.add_child(replay)
	var fresh := _menu_button("NEW RUN", Color("62f4d2"))
	fresh.pressed.connect(_show_level_map)
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
	for id in GameData.BASE_CARD_IDS + GameData.ADVANCED_CARD_IDS + GameData.GENE_CARD_IDS:
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
	var shell := _page_shell("GENE LAB", "Spend shards on permanent perks or new draft cards.")
	var body: VBoxContainer = shell["body"]
	var shard_label := Label.new()
	shard_label.text = "GENE SHARDS  %d" % int(save_data["gene_shards"])
	shard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shard_label.add_theme_font_size_override("font_size", 24)
	shard_label.add_theme_color_override("font_color", Color("ff5ba7"))
	body.add_child(shard_label)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1040, 475)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var store_content := VBoxContainer.new()
	store_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(store_content)
	var perk_title := Label.new()
	perk_title.text = "PERMANENT GENE UPGRADES"
	perk_title.add_theme_font_size_override("font_size", 22)
	perk_title.add_theme_color_override("font_color", Color("62f4d2"))
	store_content.add_child(perk_title)
	var perks := GameData.perk_definitions()
	for id in GameData.PERK_IDS:
		var level := SaveService.perk_level(save_data, id)
		var row := HBoxContainer.new()
		store_content.add_child(row)
		var details := Label.new()
		details.text = "%s  •  %d / 3\n%s" % [perks[id]["name"], level, perks[id]["description"]]
		details.custom_minimum_size = Vector2(740, 60)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var upgrade := Button.new()
		upgrade.custom_minimum_size = Vector2(240, 56)
		upgrade.text = "MAX LEVEL" if level >= 3 else "UPGRADE • %d SHARDS" % int(GameData.PERK_COSTS[level])
		upgrade.disabled = level >= 3 or (level < 3 and int(save_data["gene_shards"]) < int(GameData.PERK_COSTS[level]))
		upgrade.pressed.connect(_purchase_perk.bind(id))
		row.add_child(upgrade)
	var card_title := Label.new()
	card_title.text = "NEW MUTATION CARDS"
	card_title.add_theme_font_size_override("font_size", 22)
	card_title.add_theme_color_override("font_color", Color("9c82ff"))
	store_content.add_child(card_title)
	var cards := GameData.card_definitions()
	for id in GameData.GENE_CARD_IDS:
		var row := HBoxContainer.new()
		store_content.add_child(row)
		var details := Label.new()
		details.text = "%s\n%s" % [cards[id]["name"], cards[id]["description"]]
		details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		details.custom_minimum_size = Vector2(740, 65)
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		var owned_card: bool = id in save_data.get("owned_gene_cards", [])
		var unlock := Button.new()
		unlock.custom_minimum_size = Vector2(240, 56)
		unlock.text = "OWNED" if owned_card else "UNLOCK • %d SHARDS" % GameData.GENE_CARD_COST
		unlock.disabled = owned_card or int(save_data["gene_shards"]) < GameData.GENE_CARD_COST
		unlock.pressed.connect(_purchase_gene_card.bind(id))
		row.add_child(unlock)
	var pack_title := Label.new()
	pack_title.text = "ADVANCED NETWORK PACK"
	pack_title.add_theme_font_size_override("font_size", 22)
	pack_title.add_theme_color_override("font_color", Color("9c82ff"))
	store_content.add_child(pack_title)
	var product: Dictionary = purchase_provider.list_products()[0]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 360)
	store_content.add_child(panel)
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

func _purchase_gene_card(id: String) -> void:
	_commit_gene_purchase(SaveService.gene_card_purchase(save_data, id))

func _purchase_perk(id: String) -> void:
	_commit_gene_purchase(SaveService.perk_purchase(save_data, id))

func _commit_gene_purchase(updated: Dictionary) -> void:
	if updated.is_empty():
		return
	if not SaveService.save_data(updated):
		_show_notice("Could not save Gene Lab purchase")
		return
	save_data = updated
	sound_manager.play_sfx(&"unlock")
	_show_store()

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
	guide.text = "CAMPAIGN\nChoose a level on the signal map, select a difficulty, then bring three turret types. Clearing a level opens the next route and Endless for the route you cleared.\n\nBUILD\nChoose a tower, tap an empty cell to preview its nearest valid parent, then tap again to confirm. Connections cannot pass through dark scar tissue unless Phase Axon is active. Select a node to rewire or recycle its whole branch.\n\nPULSES\nThe Core sends pulses down every root branch. A destination tower defines the inbound link effect, then fires when the pulse arrives. Relays rotate between child branches, so coverage trades against cadence.\n\nCOUNTERS\nHusks resist turrets, Phase Mites resist links, Splitters release crawlers, and Conductors speed nearby enemies. Shielders pulse short shields to allies within their blue ring. Leeches and the Severer disable crossed links.\n\nDRAFTS & GENES\nAfter every second wave, choose a mutation from your eight-card deck. Drafted cards last for this run. The Gene Lab unlocks more card choices and permanent perks that apply to every run."
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide.add_theme_font_size_override("font_size", 18)
	body.add_child(guide)
	_add_back_button(body, _show_main_menu)

func _show_art_credits() -> void:
	_clear_content()
	var shell := _page_shell("CREDITS & LICENSE", "SYNAPSE © 2026 danned. All rights reserved.")
	var body: VBoxContainer = shell["body"]
	var credits := RichTextLabel.new()
	credits.bbcode_enabled = true
	credits.size_flags_vertical = Control.SIZE_EXPAND_FILL
	credits.add_theme_font_size_override("normal_font_size", 19)
	credits.text = "SYNAPSE's original code and content may not be copied or redistributed without permission from danned. Third-party assets keep their own licenses.\n\n" \
		+ "ART CREDITS\nTower and enemy icons by Lorc, via Game-icons.net. All icons are licensed under [url=https://creativecommons.org/licenses/by/3.0/]CC BY 3.0[/url] and tinted for SYNAPSE.\n\n" \
		+ "TOWERS\n[url=https://game-icons.net/1x1/lorc/triorb.html]Triorb[/url] • [url=https://game-icons.net/1x1/lorc/lightning-arc.html]Lightning arc[/url] • [url=https://game-icons.net/1x1/lorc/frozen-orb.html]Frozen orb[/url] • [url=https://game-icons.net/1x1/lorc/laser-blast.html]Laser blast[/url] • [url=https://game-icons.net/1x1/lorc/cannon-shot.html]Cannon shot[/url] • [url=https://game-icons.net/1x1/lorc/vortex.html]Vortex[/url]\n\n" \
		+ "ENEMIES\n[url=https://game-icons.net/1x1/lorc/angular-spider.html]Angular spider[/url] • [url=https://game-icons.net/1x1/lorc/mite.html]Mite[/url] • [url=https://game-icons.net/1x1/lorc/beetle-shell.html]Beetle shell[/url] • [url=https://game-icons.net/1x1/lorc/spectre.html]Spectre[/url] • [url=https://game-icons.net/1x1/lorc/lamprey-mouth.html]Lamprey mouth[/url] • [url=https://game-icons.net/1x1/lorc/alien-stare.html]Alien stare[/url] • [url=https://game-icons.net/1x1/lorc/two-shadows.html]Two shadows[/url] • [url=https://game-icons.net/1x1/lorc/lightning-tree.html]Lightning tree[/url]\n\n" \
		+ "AUDIO\nMusic and effects by SRG774 and Kenney, licensed under [url=https://creativecommons.org/publicdomain/zero/1.0/]CC0 1.0[/url]."
	credits.meta_clicked.connect(func(url: Variant): OS.shell_open(str(url)))
	body.add_child(credits)
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
		"endless": return Color("ffd166")
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
