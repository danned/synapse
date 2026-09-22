class_name LevelData
extends RefCounted

const LEVEL_COUNT := 5
const NAMES := ["First Signal", "Broken Circuit", "Split Current", "Deep Network", "Final Synapse"]
const WAYPOINTS := [
	{"top": [[0, 1], [4, 1], [4, 2], [8, 2], [8, 3], [15, 3]],
	 "bottom": [[0, 6], [4, 6], [4, 5], [8, 5], [8, 4], [12, 4], [12, 3], [15, 3]],
	 "blocked": [[6, 0], [10, 1], [6, 7], [10, 6]]},
	{"top": [[0, 0], [3, 0], [3, 2], [7, 2], [7, 1], [11, 1], [11, 3], [15, 3]],
	 "bottom": [[0, 7], [5, 7], [5, 5], [9, 5], [9, 4], [12, 4], [12, 3], [15, 3]],
	 "blocked": [[1, 3], [5, 0], [8, 6], [13, 6]]},
	{"top": [[0, 2], [2, 2], [2, 0], [6, 0], [6, 2], [10, 2], [10, 3], [15, 3]],
	 "bottom": [[0, 5], [4, 5], [4, 7], [8, 7], [8, 5], [12, 5], [12, 3], [15, 3]],
	 "blocked": [[1, 0], [5, 3], [9, 0], [10, 6]]},
	{"top": [[0, 1], [5, 1], [5, 3], [9, 3], [9, 2], [13, 2], [13, 3], [15, 3]],
	 "bottom": [[0, 7], [2, 7], [2, 4], [6, 4], [6, 6], [11, 6], [11, 4], [14, 4], [14, 3], [15, 3]],
	 "blocked": [[3, 0], [7, 0], [8, 7], [12, 7]]},
	{"top": [[0, 0], [4, 0], [4, 2], [7, 2], [7, 1], [10, 1], [10, 3], [15, 3]],
	 "bottom": [[0, 7], [3, 7], [3, 5], [7, 5], [7, 7], [10, 7], [10, 5], [13, 5], [13, 3], [15, 3]],
	 "blocked": [[1, 3], [5, 4], [8, 0], [11, 6]]}
]

static func level_name(level: int) -> String:
	return NAMES[clampi(level, 1, LEVEL_COUNT) - 1]

static func layout(level: int) -> Dictionary:
	var source: Dictionary = WAYPOINTS[clampi(level, 1, LEVEL_COUNT) - 1]
	var blocked: Array[Vector2i] = []
	for pair in source["blocked"]:
		blocked.append(Vector2i(pair[0], pair[1]))
	return {"top_path": _expand(source["top"]), "bottom_path": _expand(source["bottom"]), "blocked_cells": blocked}

static func _expand(waypoints: Array) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	for pair in waypoints:
		var target := Vector2i(pair[0], pair[1])
		if path.is_empty():
			path.append(target)
			continue
		var current := path[-1]
		while current != target:
			current += Vector2i(signi(target.x - current.x), signi(target.y - current.y))
			path.append(current)
	return path
