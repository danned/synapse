class_name GameData
extends RefCounted

const BOARD_COLUMNS := 16
const BOARD_ROWS := 8
const CORE_CELL := Vector2i(15, 3)
const STARTING_CHARGE := 220
const STARTING_INTEGRITY := 20
const MAX_WAVES := 10

const TOWER_ORDER := [&"relay", &"arc", &"cryo", &"lance"]
const BASE_CARD_IDS := [
	"long_axons", "myelin", "wide_conduit", "focused_receptor",
	"extra_dendrite", "priority_gate", "cold_wake", "bidirectional_lance"
]
const ADVANCED_CARD_IDS := [
	"synchronized_split", "parallel_roots", "phase_axon", "cross_synapse"
]

static func tower_definitions() -> Dictionary:
	return {
		&"relay": {
			"name": "RELAY", "tagline": "Route & branch", "cost": 40,
			"reach": 4.0, "children": 3, "color": Color("62f4d2"),
			"description": "Routes pulses to alternating child branches."
		},
		&"arc": {
			"name": "ARC", "tagline": "Link + chain", "cost": 80,
			"reach": 3.4, "children": 1, "color": Color("33c8ff"),
			"description": "Its link shocks; its node chains to three targets."
		},
		&"cryo": {
			"name": "CRYO", "tagline": "Slow + root", "cost": 75,
			"reach": 3.4, "children": 1, "color": Color("9c82ff"),
			"description": "Its link slows; its node roots the front target."
		},
		&"lance": {
			"name": "LANCE", "tagline": "Mark + pierce", "cost": 100,
			"reach": 4.0, "children": 1, "color": Color("ff5ba7"),
			"description": "Fires through its placement vector when pulsed."
		}
	}

static func enemy_definitions() -> Dictionary:
	return {
		&"crawler": {
			"name": "Crawler", "hp": 34.0, "speed": 0.90, "reward": 5,
			"leak": 1, "threat": 1.0, "color": Color("ff7f73"),
			"trait": "Balanced"
		},
		&"skitter": {
			"name": "Skitter", "hp": 22.0, "speed": 1.55, "reward": 5,
			"leak": 1, "threat": 1.3, "color": Color("ffca65"),
			"trait": "Fast"
		},
		&"husk": {
			"name": "Husk", "hp": 95.0, "speed": 0.62, "reward": 11,
			"leak": 2, "threat": 3.0, "color": Color("db6fff"),
			"trait": "45% turret armor"
		},
		&"phase": {
			"name": "Phase Mite", "hp": 42.0, "speed": 1.05, "reward": 8,
			"leak": 1, "threat": 2.0, "color": Color("6fdcff"),
			"trait": "50% link resistance"
		},
		&"leech": {
			"name": "Leech", "hp": 68.0, "speed": 0.82, "reward": 13,
			"leak": 2, "threat": 3.6, "color": Color("68ff9b"),
			"trait": "Disables crossed links"
		},
		&"severer": {
			"name": "SEVERER", "hp": 520.0, "speed": 0.46, "reward": 60,
			"leak": 8, "threat": 20.0, "color": Color("ff397c"),
			"trait": "Boss • repeatedly severs links"
		}
	}

static func card_definitions() -> Dictionary:
	return {
		"long_axons": _card("Long Axons", "Links reach +1 cell; pulses travel 20% slower.", false),
		"myelin": _card("Myelin Sheath", "Pulses travel 30% faster; active trails are narrower.", false),
		"wide_conduit": _card("Wide Conduit", "Link effects are wider; turret range is reduced.", false),
		"focused_receptor": _card("Focused Receptor", "Turret range +1 cell; link effects are narrower.", false),
		"extra_dendrite": _card("Extra Dendrite", "Relays gain one additional child port.", false),
		"priority_gate": _card("Priority Gate", "The first Relay pulse each wave feeds every child branch.", false),
		"cold_wake": _card("Cold Wake", "Cryo link slow effects last 0.75 seconds longer.", false),
		"bidirectional_lance": _card("Bilateral Lance", "Lances fire backward too, with slightly shorter beams.", false),
		"synchronized_split": _card("Synchronized Split", "Every fourth Relay pulse feeds every child branch.", true),
		"parallel_roots": _card("Parallel Roots", "The Core gains a third full-cadence root branch.", true),
		"phase_axon": _card("Phase Axon", "Links ignore scar tissue and gain extra reach.", true),
		"cross_synapse": _card("Cross-Synapse", "Intersecting active links create a damaging resonance burst.", true)
	}

static func _card(title: String, description: String, advanced: bool) -> Dictionary:
	return {"name": title, "description": description, "advanced": advanced}

static func card_modifier(card_id: String) -> Dictionary:
	match card_id:
		"long_axons": return {"link_range_bonus": 1.0, "pulse_speed_mult": 0.8}
		"myelin": return {"pulse_speed_mult": 1.3, "link_width_mult": 0.75}
		"wide_conduit": return {"link_width_mult": 1.5, "tower_range_bonus": -0.5}
		"focused_receptor": return {"tower_range_bonus": 1.0, "link_width_mult": 0.7}
		"extra_dendrite": return {"relay_children_bonus": 1}
		"priority_gate": return {"priority_gate": true}
		"cold_wake": return {"cryo_trail_bonus": 0.75}
		"bidirectional_lance": return {"bidirectional_lance": true, "lance_range_bonus": -1.0}
		"synchronized_split": return {"synchronized_split": true}
		"parallel_roots": return {"core_children_bonus": 1}
		"phase_axon": return {"phase_axon": true, "link_range_bonus": 0.5}
		"cross_synapse": return {"cross_synapse": true}
	return {}

static func empty_modifiers() -> Dictionary:
	return {
		"link_range_bonus": 0.0, "pulse_speed_mult": 1.0,
		"link_width_mult": 1.0, "tower_range_bonus": 0.0,
		"relay_children_bonus": 0, "relay_delay": 0.0,
		"priority_gate": false, "cryo_trail_bonus": 0.0,
		"bidirectional_lance": false, "lance_range_bonus": 0.0,
		"synchronized_split": false, "core_children_bonus": 0,
		"phase_axon": false, "cross_synapse": false
	}

static func difficulty_name(id: String) -> String:
	match id:
		"easy": return "EASY / FLOW"
		"hardcore": return "HARDCORE / SURGE"
	return "NORMAL / PULSE"

static func difficulty_description(id: String) -> String:
	match id:
		"easy": return "Full wave intel. Pause combat to build and rewire."
		"hardcore": return "Minimal intel. Waves auto-launch; build in real time."
	return "Partial wave intel. Build only between waves."
