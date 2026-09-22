class_name GameArt
extends RefCounted

const TOWER_ICONS := {
	&"relay": preload("res://assets/icons/relay.png"),
	&"arc": preload("res://assets/icons/arc.png"),
	&"cryo": preload("res://assets/icons/cryo.png"),
	&"lance": preload("res://assets/icons/lance.png"),
	&"mortar": preload("res://assets/icons/mortar.png"),
	&"rift": preload("res://assets/icons/rift.png")
}

const ENEMY_ICONS := {
	&"crawler": preload("res://assets/icons/crawler.png"),
	&"skitter": preload("res://assets/icons/skitter.png"),
	&"husk": preload("res://assets/icons/husk.png"),
	&"phase": preload("res://assets/icons/phase.png"),
	&"leech": preload("res://assets/icons/leech.png"),
	&"severer": preload("res://assets/icons/severer.png"),
	&"splitter": preload("res://assets/icons/splitter.png"),
	&"conductor": preload("res://assets/icons/conductor.png"),
	&"shielder": preload("res://assets/icons/shielder.png")
}

static func tower_icon(type: StringName) -> Texture2D:
	return TOWER_ICONS.get(type) as Texture2D

static func enemy_icon(type: StringName) -> Texture2D:
	return ENEMY_ICONS.get(type) as Texture2D
