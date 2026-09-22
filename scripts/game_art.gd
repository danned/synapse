class_name GameArt
extends RefCounted

const CRAWLER_WALK_ATLAS := preload("res://assets/sprites/crawler_walk.png")
const CRAWLER_WALK_FRAME_COUNT := 6
const CRAWLER_WALK_FRAMES_PER_CELL := 8.0
const CRAWLER_WALK_FRAME_SIZE := Vector2(209.0, 209.0)
const CRAWLER_WALK_ROW_Y := [70.0, 358.0, 632.0, 922.0]
const ENEMY_WALK_FRAME_COUNT := 6
const ENEMY_WALK_FRAMES_PER_CELL := 8.0
const ENEMY_WALK_FRAME_SIZE := Vector2(256.0, 256.0)

const TOWER_ICONS := {
	&"relay": preload("res://assets/icons/relay.png"),
	&"arc": preload("res://assets/icons/arc.png"),
	&"cryo": preload("res://assets/icons/cryo.png"),
	&"lance": preload("res://assets/icons/lance.png"),
	&"mortar": preload("res://assets/icons/mortar.png"),
	&"rift": preload("res://assets/icons/rift.png")
}

const ENEMY_ICONS := {
	&"crawler": CRAWLER_WALK_ATLAS,
	&"skitter": preload("res://assets/sprites/skitter_walk.png"),
	&"husk": preload("res://assets/sprites/husk_walk.png"),
	&"phase": preload("res://assets/sprites/phase_walk.png"),
	&"leech": preload("res://assets/sprites/leech_walk.png"),
	&"severer": preload("res://assets/sprites/severer_walk.png"),
	&"splitter": preload("res://assets/sprites/splitter_walk.png"),
	&"conductor": preload("res://assets/sprites/conductor_walk.png"),
	&"shielder": preload("res://assets/sprites/shielder_walk.png")
}

static var _enemy_icons: Dictionary = {}

static func tower_icon(type: StringName) -> Texture2D:
	return TOWER_ICONS.get(type) as Texture2D

static func enemy_icon(type: StringName) -> Texture2D:
	var cached := _enemy_icons.get(type) as AtlasTexture
	if cached != null:
		return cached
	var atlas := enemy_walk_atlas(type)
	if atlas == null:
		return null
	var icon := AtlasTexture.new()
	icon.atlas = atlas
	icon.region = enemy_walk_region(type, Vector2.DOWN, 0)
	icon.filter_clip = true
	_enemy_icons[type] = icon
	return icon

static func enemy_walk_atlas(type: StringName) -> Texture2D:
	return ENEMY_ICONS.get(type) as Texture2D

static func enemy_walk_frame(walk_distance: float) -> int:
	return wrapi(int(floor(walk_distance * ENEMY_WALK_FRAMES_PER_CELL)), 0, ENEMY_WALK_FRAME_COUNT)

static func enemy_walk_region(type: StringName, direction: Vector2, frame: int) -> Rect2:
	var row := _direction_row(direction)
	var column := wrapi(frame, 0, ENEMY_WALK_FRAME_COUNT)
	if type == &"crawler":
		return Rect2(Vector2(column * CRAWLER_WALK_FRAME_SIZE.x, CRAWLER_WALK_ROW_Y[row]), CRAWLER_WALK_FRAME_SIZE)
	return Rect2(Vector2(column * ENEMY_WALK_FRAME_SIZE.x, row * ENEMY_WALK_FRAME_SIZE.y), ENEMY_WALK_FRAME_SIZE)

static func crawler_walk_frame(walk_distance: float) -> int:
	return enemy_walk_frame(walk_distance)

static func crawler_walk_region(direction: Vector2, frame: int) -> Rect2:
	return enemy_walk_region(&"crawler", direction, frame)

static func _direction_row(direction: Vector2) -> int:
	var row := 0
	if absf(direction.x) > absf(direction.y):
		row = 2 if direction.x >= 0.0 else 1
	elif direction.y < 0.0:
		row = 3
	return row
