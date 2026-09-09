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


## Calculate in-run Prestige ascension cost for a target rank (1 to 20).
func get_prestige_cost(target_rank: int) -> int:
	if target_rank < 1 or target_rank > 20:
		return 0
	var rank_cost: float = (1000.0 + float(target_rank) * 500.0) * prestige_multiplier
	return int(round(rank_cost))


## Compute stat multipliers for a given Prestige rank (0 to 20).
## Hard caps: Attack Speed multiplier <= 1.50x, Range multiplier <= 1.25x, Armor Pierce <= 0.30.
static func calculate_prestige_stats(rank: int) -> Dictionary:
	var r: int = clampi(rank, 0, 20)
	return {
		"rank": r,
		"damage_mult": 1.0 + (float(r) * 0.15),
		"attack_speed_mult": minf(1.50, 1.0 + (float(r) * 0.025)),
		"range_mult": minf(1.25, 1.0 + (float(r) * 0.0125)),
		"armor_pierce": minf(0.30, float(r) * 0.015)
	}


## Instance convenience wrapper for calculate_prestige_stats.
func get_prestige_stats(rank: int) -> Dictionary:
	return calculate_prestige_stats(rank)
