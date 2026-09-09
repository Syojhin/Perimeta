class_name TowerData
extends Resource

## Data definition for deployable defensive turrets in Perimeta.
## Encapsulates baseline balance stats, costs, visual scenes, and upgrade progression.

@export var tower_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var archetype: String = "KINETIC" # KINETIC, CRYO, ELECTRO, PLASMA, PIERCING
@export var base_cost: int = 100
@export var base_damage: float = 15.0
@export var base_fire_rate: float = 1.0
@export var base_range: float = 220.0
@export_file("*.tscn") var scene_path: String = ""
@export var tier_upgrades: Array[Dictionary] = []
@export var prestige_multiplier: float = 1.0


## Resolve and load the PackedScene associated with this tower.
func get_scene() -> PackedScene:
	if scene_path.is_empty():
		return null
	return load(scene_path) as PackedScene
