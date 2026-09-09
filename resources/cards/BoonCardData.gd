class_name BoonCardData
extends Resource

## Data definition for roguelite boon cards offered during wave draft cycles.
## Controls stat modifications, target turrets, unlock prerequisites, and multi-tier rarity visuals.

enum Rarity {
	COMMON = 0,
	RARE = 1,
	EPIC = 2,
	OVERCLOCK = 3
}

@export var card_id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var target_tower_id: String = "" # Empty for global effects, or specific tower_id (e.g. "plasma_mortar")
@export var required_tower_id: String = "" # Empty for always available, or required turret on board to roll
@export var target_stat: String = "" # Stat key added to GlobalState run modifiers
@export var value: float = 0.0
@export var is_multiplier: bool = false


func get_rarity_name() -> String:
	match rarity:
		Rarity.COMMON: return "COMMON"
		Rarity.RARE: return "RARE"
		Rarity.EPIC: return "EPIC"
		Rarity.OVERCLOCK: return "OVERCLOCK"
	return "COMMON"


func get_rarity_tag() -> String:
	match rarity:
		Rarity.COMMON: return "[STANDARD]"
		Rarity.RARE: return "[AMPLIFIED]"
		Rarity.EPIC: return "[EXPERIMENTAL]"
		Rarity.OVERCLOCK: return "[! OVERCLOCK !]"
	return "[STANDARD]"


## Convert card to a legacy-compatible Dictionary representation for EventBus signals.
func to_dict() -> Dictionary:
	return {
		"id": card_id,
		"name": title,
		"desc": description,
		"tag": get_rarity_tag(),
		"stat_key": target_stat,
		"value": value,
		"is_multiplier": is_multiplier,
		"rarity": rarity,
		"target_tower_id": target_tower_id,
		"required_tower_id": required_tower_id
	}
