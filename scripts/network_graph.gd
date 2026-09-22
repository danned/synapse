class_name NetworkGraph
extends RefCounted

signal changed

var nodes: Dictionary = {}
var next_id := 1
var modifiers := GameData.empty_modifiers()
var _round_robin: Dictionary = {}
var _receive_count: Dictionary = {}

func _init(core_cell: Vector2i = GameData.CORE_CELL) -> void:
	nodes[0] = {
		"id": 0, "type": &"core", "cell": core_cell,
		"parent": -1, "children": []
	}

func reset_routing() -> void:
	_round_robin.clear()
	_receive_count.clear()

func node_at(cell: Vector2i) -> int:
	for id in nodes:
		if nodes[id]["cell"] == cell:
			return id
	return -1

func child_capacity(node_id: int) -> int:
	if node_id == 0:
		return 2 + int(modifiers["core_children_bonus"])
	var node: Dictionary = nodes.get(node_id, {})
	if node.is_empty():
		return 0
	if node["type"] == &"relay":
		return 3 + int(modifiers["relay_children_bonus"])
	return 1

func link_reach(tower_type: StringName) -> float:
	var definitions := GameData.tower_definitions()
	return float(definitions[tower_type]["reach"]) + float(modifiers["link_range_bonus"])

func valid_parent_ids(cell: Vector2i, tower_type: StringName) -> Array[int]:
	var result: Array[int] = []
	var reach := link_reach(tower_type)
	for raw_id in nodes:
		var id: int = raw_id
		var node: Dictionary = nodes[id]
		if node["children"].size() >= child_capacity(id):
			continue
		if Vector2(node["cell"]).distance_to(Vector2(cell)) <= reach + 0.001:
			result.append(id)
	result.sort_custom(func(a: int, b: int) -> bool:
		return Vector2(nodes[a]["cell"]).distance_squared_to(Vector2(cell)) < Vector2(nodes[b]["cell"]).distance_squared_to(Vector2(cell))
	)
	return result

func place_node(tower_type: StringName, cell: Vector2i, parent_id: int) -> int:
	if node_at(cell) != -1 or not nodes.has(parent_id):
		return -1
	if parent_id not in valid_parent_ids(cell, tower_type):
		return -1
	var id := next_id
	next_id += 1
	nodes[id] = {"id": id, "type": tower_type, "cell": cell, "parent": parent_id, "children": []}
	var parent: Dictionary = nodes[parent_id]
	parent["children"].append(id)
	nodes[parent_id] = parent
	changed.emit()
	return id

func can_reparent(node_id: int, new_parent_id: int) -> bool:
	if node_id <= 0 or new_parent_id < 0 or node_id == new_parent_id:
		return false
	if not nodes.has(node_id) or not nodes.has(new_parent_id):
		return false
	if is_descendant(new_parent_id, node_id):
		return false
	if nodes[new_parent_id]["children"].size() >= child_capacity(new_parent_id):
		return false
	var node: Dictionary = nodes[node_id]
	var distance := Vector2(node["cell"]).distance_to(Vector2(nodes[new_parent_id]["cell"]))
	return distance <= link_reach(node["type"]) + 0.001

func reparent(node_id: int, new_parent_id: int) -> bool:
	if not can_reparent(node_id, new_parent_id):
		return false
	var node: Dictionary = nodes[node_id]
	var old_parent_id: int = node["parent"]
	var old_parent: Dictionary = nodes[old_parent_id]
	old_parent["children"].erase(node_id)
	nodes[old_parent_id] = old_parent
	var new_parent: Dictionary = nodes[new_parent_id]
	new_parent["children"].append(node_id)
	nodes[new_parent_id] = new_parent
	node["parent"] = new_parent_id
	nodes[node_id] = node
	changed.emit()
	return true

func is_descendant(possible_child: int, ancestor: int) -> bool:
	var cursor := possible_child
	while cursor > 0 and nodes.has(cursor):
		if cursor == ancestor:
			return true
		cursor = int(nodes[cursor]["parent"])
	return cursor == ancestor

func remove_subtree(node_id: int) -> Array[int]:
	var removed: Array[int] = []
	if node_id <= 0 or not nodes.has(node_id):
		return removed
	_collect_subtree(node_id, removed)
	var parent_id: int = nodes[node_id]["parent"]
	var parent: Dictionary = nodes[parent_id]
	parent["children"].erase(node_id)
	nodes[parent_id] = parent
	for id in removed:
		nodes.erase(id)
		_round_robin.erase(id)
		_receive_count.erase(id)
	changed.emit()
	return removed

func _collect_subtree(node_id: int, output: Array[int]) -> void:
	output.append(node_id)
	for child_id in nodes[node_id]["children"]:
		_collect_subtree(child_id, output)

func outgoing_for_pulse(node_id: int) -> Array[int]:
	if not nodes.has(node_id):
		return []
	var children: Array = nodes[node_id]["children"]
	if children.is_empty():
		return []
	if node_id == 0 or children.size() == 1:
		return Array(children, TYPE_INT, "", null)
	var count := int(_receive_count.get(node_id, 0)) + 1
	_receive_count[node_id] = count
	if bool(modifiers["priority_gate"]) and count == 1:
		return Array(children, TYPE_INT, "", null)
	if bool(modifiers["synchronized_split"]) and count % 4 == 0:
		return Array(children, TYPE_INT, "", null)
	var index := int(_round_robin.get(node_id, 0)) % children.size()
	_round_robin[node_id] = index + 1
	return [int(children[index])]

func apply_modifier(card_id: String) -> void:
	var incoming := GameData.card_modifier(card_id)
	for key in incoming:
		var value: Variant = incoming[key]
		if value is bool:
			modifiers[key] = value
		elif value is int:
			modifiers[key] = int(modifiers.get(key, 0)) + value
		else:
			if key.ends_with("_mult"):
				modifiers[key] = float(modifiers.get(key, 1.0)) * float(value)
			else:
				modifiers[key] = float(modifiers.get(key, 0.0)) + float(value)
	changed.emit()
