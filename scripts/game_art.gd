class_name GameArt
extends RefCounted

const CRAWLER_WALK_ATLAS := preload("res://assets/sprites/crawler_walk.png")
const CRAWLER_WALK_FRAME_COUNT := 6
const CRAWLER_WALK_FRAMES_PER_CELL := 8.0
const CRAWLER_WALK_FRAME_SIZE := Vector2(209.0, 209.0)
const CRAWLER_WALK_ROW_Y := [70.0, 358.0, 632.0, 922.0]

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
	&"skitter": preload("res://assets/icons/skitter.png"),
	&"husk": preload("res://assets/icons/husk.png"),
	&"phase": preload("res://assets/icons/phase.png"),
	&"leech": preload("res://assets/icons/leech.png"),
	&"severer": preload("res://assets/icons/severer.png"),
	&"splitter": preload("res://assets/icons/splitter.png"),
	&"conductor": preload("res://assets/icons/conductor.png"),
	&"shielder": preload("res://assets/icons/shielder.png")
}

static var _crawler_icon: AtlasTexture

static func tower_icon(type: StringName) -> Texture2D:
	return TOWER_ICONS.get(type) as Texture2D

static func enemy_icon(type: StringName) -> Texture2D:
	if type == &"crawler":
		if _crawler_icon == null:
			_crawler_icon = AtlasTexture.new()
			_crawler_icon.atlas = CRAWLER_WALK_ATLAS
			_crawler_icon.region = crawler_walk_region(Vector2.DOWN, 0)
			_crawler_icon.filter_clip = true
		return _crawler_icon
	return ENEMY_ICONS.get(type) as Texture2D

static func crawler_walk_frame(walk_distance: float) -> int:
	return wrapi(int(floor(walk_distance * CRAWLER_WALK_FRAMES_PER_CELL)), 0, CRAWLER_WALK_FRAME_COUNT)

static func crawler_walk_region(direction: Vector2, frame: int) -> Rect2:
	var row := 0
	if absf(direction.x) > absf(direction.y):
		row = 2 if direction.x >= 0.0 else 1
	elif direction.y < 0.0:
		row = 3
	var column := wrapi(frame, 0, CRAWLER_WALK_FRAME_COUNT)
	return Rect2(Vector2(column * CRAWLER_WALK_FRAME_SIZE.x, CRAWLER_WALK_ROW_Y[row]), CRAWLER_WALK_FRAME_SIZE)
