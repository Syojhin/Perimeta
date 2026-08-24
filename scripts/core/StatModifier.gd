class_name StatModifier
extends RefCounted

## Static calculation engine and perk registry for Perimeta's meta-progression tree.

# --- Perk Definitions and Metadata ---
static var PERK_DEFINITIONS: Dictionary = {
	# --- Offense Branch ---
	"kinetic_damage": {
		"name": "Kinetic Amplifier",
		"branch": "Offense",
		"tier": 1,
		"max_level": 5,
		"base_cost": 5,
		"cost_scale": 5, # cost = base_cost + (level * cost_scale)
		"prerequisite": "",
		"description": "+10% Tower Damage per level.",
		"stat_type": "tower_damage",
		"type": "multiplier",
		"value_per_level": 0.10
	},
	"overclock": {
		"name": "Overclock Relays",
		"branch": "Offense",
		"tier": 2,
		"max_level": 5,
		"base_cost": 8,
		"cost_scale": 6,
		"prerequisite": "kinetic_damage",
		"description": "+8% Attack Speed per level.",
		"stat_type": "attack_speed",
		"type": "multiplier",
		"value_per_level": 0.08
	},
	"chain_arc_bounces": {
		"name": "Chain Arc Subroutines",
		"branch": "Offense",
		"tier": 3,
		"max_level": 3,
		"base_cost": 15,
		"cost_scale": 10,
		"prerequisite": "overclock",
		"description": "+1 Chain Lightning bounce per level.",
		"stat_type": "chain_bounces",
		"type": "flat",
		"value_per_level": 1.0
	},
	"elemental_mastery": {
		"name": "Elemental Mastery",
		"branch": "Offense",
		"tier": 4,
		"max_level": 5,
		"base_cost": 10,
		"cost_scale": 4,
		"prerequisite": "chain_arc_bounces",
		"description": "+20% Elemental Reaction damage per level.",
		"stat_type": "elemental_reaction_damage",
		"type": "multiplier",
		"value_per_level": 0.20
	},
	"specialist_doctrine": {
		"name": "Specialist Doctrine",
		"branch": "Offense",
		"tier": 5,
		"max_level": 3,
		"base_cost": 15,
		"cost_scale": 8,
		"prerequisite": "elemental_mastery",
		"description": "+15% damage to all turrets when maintaining an active Resonance.",
		"stat_type": "resonance_damage_mult",
		"type": "multiplier",
		"value_per_level": 0.15
	},
	
	# --- Utility Branch ---
	"sensor_array": {
		"name": "Sensor Array",
		"branch": "Utility",
		"tier": 1,
		"max_level": 5,
		"base_cost": 5,
		"cost_scale": 4,
		"prerequisite": "",
		"description": "+15% Tower Range per level.",
		"stat_type": "tower_range",
		"type": "multiplier",
		"value_per_level": 0.15
	},
	"starting_capital": {
		"name": "Starting Capital",
		"branch": "Utility",
		"tier": 2,
		"max_level": 5,
		"base_cost": 6,
		"cost_scale": 5,
		"prerequisite": "sensor_array",
		"description": "+50 starting Bits per level.",
		"stat_type": "starting_bits",
		"type": "flat",
		"value_per_level": 50.0
	},
	"discount_ammo": {
		"name": "Discount Ammo",
		"branch": "Utility",
		"tier": 3,
		"max_level": 3,
		"base_cost": 12,
		"cost_scale": 8,
		"prerequisite": "starting_capital",
		"description": "-1 Bit per Coin Gun cursor shot (min cost: 1).",
		"stat_type": "coin_gun_cost",
		"type": "flat_reduction",
		"value_per_level": 1.0
	},
	"bit_dividend": {
		"name": "Bit Dividend",
		"branch": "Utility",
		"tier": 4,
		"max_level": 5,
		"base_cost": 8,
		"cost_scale": 3,
		"prerequisite": "discount_ammo",
		"description": "+5% compound interest on unspent Bits per wave.",
		"stat_type": "bit_interest_rate",
		"type": "multiplier",
		"value_per_level": 0.05
	},
	
	# --- Defense Branch ---
	"reinforced_core": {
		"name": "Reinforced Core",
		"branch": "Defense",
		"tier": 1,
		"max_level": 5,
		"base_cost": 5,
		"cost_scale": 5,
		"prerequisite": "",
		"description": "+25 Max Core HP per level.",
		"stat_type": "max_core_hp",
		"type": "flat",
		"value_per_level": 25.0
	},
	"cryo_frostbite": {
		"name": "Cryo Frostbite",
		"branch": "Defense",
		"tier": 2,
		"max_level": 3,
		"base_cost": 10,
		"cost_scale": 8,
		"prerequisite": "reinforced_core",
		"description": "+1.0s Freeze / Slow status duration per level.",
		"stat_type": "freeze_duration",
		"type": "flat",
		"value_per_level": 1.0
	},
	"thermal_insulator": {
		"name": "Thermal Insulator",
		"branch": "Defense",
		"tier": 3,
		"max_level": 3,
		"base_cost": 10,
		"cost_scale": 5,
		"prerequisite": "cryo_frostbite",
		"description": "Core reactive shield shocks and ignites attackers on breach.",
		"stat_type": "thermal_insulator_level",
		"type": "flat",
		"value_per_level": 1.0
	}
}


## Calculate modified value given base value, stat key, and unlocked perks.
static func get_modified_stat(stat_name: String, base_value: float, perks: Dictionary) -> float:
	var multiplier: float = 1.0
	var flat_addition: float = 0.0
	var flat_reduction: float = 0.0
	
	for perk_id: String in PERK_DEFINITIONS:
		var perk_data: Dictionary = PERK_DEFINITIONS[perk_id]
		if perk_data.get("stat_type") != stat_name:
			continue
		
		var level: int = perks.get(perk_id, 0)
		if level <= 0:
			continue
		
		var type: String = perk_data.get("type", "multiplier")
		var val_per_lvl: float = perk_data.get("value_per_level", 0.0)
		
		match type:
			"multiplier":
				multiplier += val_per_lvl * float(level)
			"flat":
				flat_addition += val_per_lvl * float(level)
			"flat_reduction":
				flat_reduction += val_per_lvl * float(level)
	
	var final_val: float = (base_value + flat_addition - flat_reduction) * multiplier
	
	# Special constraints for specific stats
	if stat_name == "coin_gun_cost":
		final_val = maxf(1.0, final_val)
	
	return final_val


## Get the upgrade cost for the next level of a perk.
static func get_upgrade_cost(perk_id: String, current_level: int) -> int:
	if not PERK_DEFINITIONS.has(perk_id):
		return 0
	var perk_data: Dictionary = PERK_DEFINITIONS[perk_id]
	if current_level >= perk_data.get("max_level", 1):
		return 0
	
	var base_cost: int = perk_data.get("base_cost", 5)
	var scale: int = perk_data.get("cost_scale", 4)
	return base_cost + (current_level * scale)


## Calculate the total Meta-Cores spent on a specific perk given its level.
static func get_total_perk_spent(perk_id: String, level: int) -> int:
	if not PERK_DEFINITIONS.has(perk_id) or level <= 0:
		return 0
	var total: int = 0
	for lvl in range(level):
		total += get_upgrade_cost(perk_id, lvl)
	return total


## Calculate the total spent Meta-Cores across all unlocked perks.
static func get_total_spent_cores(perks: Dictionary) -> int:
	var total: int = 0
	for perk_id: String in perks:
		var level: int = perks.get(perk_id, 0)
		total += get_total_perk_spent(perk_id, level)
	return total


## Check if a perk meets prerequisite and level constraints.
static func can_unlock_perk(perk_id: String, perks: Dictionary, available_cores: int) -> bool:
	if not PERK_DEFINITIONS.has(perk_id):
		return false
	
	var perk_data: Dictionary = PERK_DEFINITIONS[perk_id]
	var current_level: int = perks.get(perk_id, 0)
	var max_level: int = perk_data.get("max_level", 1)
	
	if current_level >= max_level:
		return false
	
	# Check prerequisite
	var prereq_id: String = perk_data.get("prerequisite", "")
	if not prereq_id.is_empty():
		var prereq_level: int = perks.get(prereq_id, 0)
		if prereq_level < 1:
			return false
	
	# Check cost
	var cost: int = get_upgrade_cost(perk_id, current_level)
	return available_cores >= cost
