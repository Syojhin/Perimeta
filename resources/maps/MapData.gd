class_name MapData
extends Resource

## Modular Map Architecture Data Resource for Perimeta arenas.
## Encapsulates dynamic path curves, socket placement transforms, core position, ambient tint, and hazard profiles.

@export var map_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var path_data: Array[PackedVector2Array] = []
@export var socket_transforms: Array[Transform2D] = []
@export var core_position: Vector2 = Vector2(960, 540)
@export var ambient_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var hazard_type: String = "none"


## Returns an array of Vector2 positions extracted from socket_transforms.
func get_socket_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for xform: Transform2D in socket_transforms:
		positions.append(xform.origin)
	return positions


## Constructs and returns a new Curve2D for the specified path index.
func build_curve(path_index: int) -> Curve2D:
	if path_index < 0 or path_index >= path_data.size():
		return null
	var curve: Curve2D = Curve2D.new()
	for pt: Vector2 in path_data[path_index]:
		curve.add_point(pt)
	return curve


## Constructs and returns all Curve2D instances for all paths in this map.
func build_all_curves() -> Array[Curve2D]:
	var curves: Array[Curve2D] = []
	for i in range(path_data.size()):
		var c: Curve2D = build_curve(i)
		if c:
			curves.append(c)
	return curves


## Validates whether any sockets in this map overlap within a minimum squared distance.
func are_sockets_non_overlapping(min_distance: float = 60.0) -> bool:
	var min_dist_sq: float = min_distance * min_distance
	var positions: Array[Vector2] = get_socket_positions()
	for i in range(positions.size()):
		for j in range(i + 1, positions.size()):
			if positions[i].distance_squared_to(positions[j]) < min_dist_sq:
				return false
	return true
