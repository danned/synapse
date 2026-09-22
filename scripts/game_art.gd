class_name GameArt
extends RefCounted

const TOWER_ICONS := {
	&"relay": preload("res://assets/icons/relay.svg"),
	&"arc": preload("res://assets/icons/arc.svg"),
	&"cryo": preload("res://assets/icons/cryo.svg"),
	&"lance": preload("res://assets/icons/lance.svg"),
	&"mortar": preload("res://assets/icons/mortar.svg"),
	&"rift": preload("res://assets/icons/rift.svg")
}

const ENEMY_ICONS := {
	&"crawler": preload("res://assets/icons/crawler.svg"),
	&"skitter": preload("res://assets/icons/skitter.svg"),
	&"husk": preload("res://assets/icons/husk.svg"),
	&"phase": preload("res://assets/icons/phase.svg"),
	&"leech": preload("res://assets/icons/leech.svg"),
	&"severer": preload("res://assets/icons/severer.svg"),
	&"splitter": preload("res://assets/icons/splitter.svg"),
	&"conductor": preload("res://assets/icons/conductor.svg"),
	&"shielder": preload("res://assets/icons/shielder.svg")
}

static func tower_icon(type: StringName) -> Texture2D:
	return TOWER_ICONS.get(type) as Texture2D

static func enemy_icon(type: StringName) -> Texture2D:
	return ENEMY_ICONS.get(type) as Texture2D
