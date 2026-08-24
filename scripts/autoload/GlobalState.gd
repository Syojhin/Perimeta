extends Node

## Central persistent state and in-run state manager for Perimeta. Supports persistent meta perks, in-run roguelite boons, and the Core Super Ability.

# --- In-Run State ---
var is_run_active: bool = false
var current_wave: int = 0
var core_max_hp: float = 100.0
var core_hp: float = 100.0
var run_currency: int = 250
var score: int = 0
var enemies_defeated: int = 0
var run_bits_earned: int = 0
var run_modifiers: Dictionary = {} # Maps stat_key (String) -> value (float)
var super_charge: float = 0.0 # 0.0 to 100.0
var is_resonance_active: bool = false
var game_speed: float = 1.0

# --- Persistent Meta State ---
var meta_cores: int = 0:
	set(value):
		var old_val: int = meta_cores
		meta_cores = value
		EventBus.meta_cores_changed.emit(meta_cores, meta_cores - old_val)

var unlocked_perks: Dictionary = {} # Maps String (perk_id) -> int (level)
var high_score: int = 0
var highest_wave: int = 0
var total_runs_played: int = 0


func _ready() -> void:
	EventBus.enemy_reached_core.connect(_on_enemy_reached_core)
	EventBus.enemy_died.connect(_on_enemy_died)


func _process(delta: float) -> void:
	# Passive super meter trickle charge while combat run is active
	if is_run_active and super_charge < 100.0:
		add_super_charge(1.5 * delta)


## Query dynamic stat modifier factoring in all unlocked perks and in-run card boons.
func get_stat(key: String, base_value: float) -> float:
	var val: float = StatModifier.get_modified_stat(key, base_value, unlocked_perks)
	
	# Specialist Doctrine: +15% per level when maintaining active Resonance
	if key == "tower_damage" and is_resonance_active:
		var spec_doc: float = StatModifier.get_modified_stat("resonance_damage_mult", 0.0, unlocked_perks)
		if spec_doc > 0.0:
			val *= (1.0 + spec_doc)
	
	# Factor in in-run roguelite card draft modifiers
	if run_modifiers.has(key):
		var mod: float = run_modifiers[key]
		if key in ["tower_damage", "attack_speed", "coin_gun_damage_mult", "super_charge_rate", "slow_damage_mult"]:
			val *= (1.0 + mod)
		else:
			val += mod
			
	return val


## Add or stack an in-run roguelite boon modifier.
func add_run_modifier(key: String, value: float) -> void:
	run_modifiers[key] = run_modifiers.get(key, 0.0) + value
	
	# Immediate effect handling for specific modifiers
	if key == "max_core_hp":
		core_max_hp += value
		heal_core(value)
	
	EventBus.perks_updated.emit(unlocked_perks)


## Add charge to the Core Super Ability meter.
func add_super_charge(amount: float) -> void:
	if not is_run_active:
		return
	var rate_mult: float = get_stat("super_charge_rate", 1.0)
	super_charge = clampf(super_charge + (amount * rate_mult), 0.0, 100.0)
	EventBus.super_charge_changed.emit(super_charge, 100.0)


## Attempt to discharge the Core Super Ability (requires 100% charge).
func spend_super_charge() -> bool:
	if super_charge >= 100.0:
		super_charge = 0.0
		EventBus.super_charge_changed.emit(super_charge, 100.0)
		EventBus.super_ability_activated.emit()
		return true
	return false


## Retrieve the active level of a meta perk.
func get_perk_level(perk_id: String) -> int:
	return unlocked_perks.get(perk_id, 0)


## Attempt to purchase an upgrade level for a meta perk.
func unlock_perk(perk_id: String) -> bool:
	var current_level: int = get_perk_level(perk_id)
	if not StatModifier.can_unlock_perk(perk_id, unlocked_perks, meta_cores):
		return false
	
	var cost: int = StatModifier.get_upgrade_cost(perk_id, current_level)
	meta_cores -= cost
	unlocked_perks[perk_id] = current_level + 1
	
	EventBus.perks_updated.emit(unlocked_perks)
	return true


## Refund 100% of spent Meta-Cores and reset all perk levels.
func refund_all_perks() -> void:
	var total_refund: int = StatModifier.get_total_spent_cores(unlocked_perks)
	if total_refund > 0:
		meta_cores += total_refund
	unlocked_perks.clear()
	
	EventBus.perks_updated.emit(unlocked_perks)


## Initialize a fresh run state with dynamic stats applied.
func start_run() -> void:
	is_run_active = true
	current_wave = 0
	enemies_defeated = 0
	score = 0
	run_bits_earned = 0
	run_modifiers.clear()
	super_charge = 0.0
	
	# Apply dynamic baseline stats
	core_max_hp = get_stat("max_core_hp", 100.0)
	core_hp = core_max_hp
	run_currency = int(get_stat("starting_bits", 250.0))
	
	total_runs_played += 1
	
	EventBus.run_started.emit()
	EventBus.core_healed.emit(core_hp, core_hp)
	EventBus.currency_changed.emit(run_currency, 0)
	EventBus.super_charge_changed.emit(super_charge, 100.0)


## Conclude the current run, award meta-cores, update high scores, and notify systems.
func end_run(victory: bool) -> Dictionary:
	if not is_run_active:
		return {}
	is_run_active = false
	
	# Meta-cores award formula: strictly capped between 15-60 cores based on milestone waves
	var raw_meta: int = int(score / 200.0) + (current_wave * 2) + (20 if victory else 0)
	var awarded_meta: int = clampi(raw_meta, 0, 60)
	if current_wave >= 5:
		awarded_meta = clampi(awarded_meta, 15, 60)
		
	if awarded_meta > 0:
		meta_cores += awarded_meta
	
	# Update records
	if score > high_score:
		high_score = score
	if current_wave > highest_wave:
		highest_wave = current_wave
	
	var stats: Dictionary = {
		"victory": victory,
		"wave": current_wave,
		"enemies_defeated": enemies_defeated,
		"score": score,
		"bits_earned": run_bits_earned,
		"meta_cores_awarded": awarded_meta,
		"total_meta_cores": meta_cores
	}
	
	EventBus.run_ended.emit(victory)
	EventBus.game_over.emit(stats)
	return stats


## Apply damage to the core and trigger game over if health is depleted.
func damage_core(amount: float) -> void:
	if not is_run_active or core_hp <= 0.0:
		return
	
	core_hp = maxf(0.0, core_hp - amount)
	EventBus.core_damaged.emit(core_hp, core_max_hp)
	
	if core_hp <= 0.0:
		EventBus.core_destroyed.emit()
		end_run(false)


## Restore core health up to maximum.
func heal_core(amount: float) -> void:
	if not is_run_active:
		return
	
	var actual_heal: float = minf(amount, core_max_hp - core_hp)
	if actual_heal > 0.0:
		core_hp += actual_heal
		EventBus.core_healed.emit(actual_heal, core_hp)


## Add in-run currency (e.g. from enemy kills or wave bonuses).
func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	run_currency += amount
	run_bits_earned += amount
	EventBus.currency_changed.emit(run_currency, amount)


## Attempt to spend in-run currency. Returns true if successful.
func spend_currency(amount: int) -> bool:
	if amount <= 0:
		return true
	if run_currency >= amount:
		run_currency -= amount
		EventBus.currency_changed.emit(run_currency, -amount)
		return true
	return false


# --- Signal Callbacks ---

func _on_enemy_reached_core(_enemy: Node, damage: float) -> void:
	damage_core(damage)


func _on_enemy_died(_enemy: Node, bounty: int) -> void:
	enemies_defeated += 1
	score += bounty * 10
	var bonus_bits: int = int(get_stat("bonus_kill_bits", 0.0))
	add_currency(bounty + bonus_bits)
	add_super_charge(3.5) # +3.5% super meter per kill
