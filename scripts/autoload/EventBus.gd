extends Node

## Central Event Bus for decoupled game-wide communication in Perimeta.

# --- Enemy Lifecycle Signals ---
signal enemy_spawned(enemy: Node)
signal enemy_died(enemy: Node, bounty: int)
signal enemy_reached_core(enemy: Node, damage: float)
signal enemy_damaged(enemy: Node, amount: float, current_hp: float)
signal boss_spawned(boss: Node)
signal boss_defeated(boss: Node)
signal boss_damaged(current_hp: float, max_hp: float, phase_shield_active: bool)

# --- Tower Lifecycle Signals ---
signal tower_placed(tower: Node)
signal tower_built(tower: Node)
signal tower_sold(tower: Node)
signal tower_upgraded(tower: Node)
signal tower_fired(tower: Node, target: Node)

# --- Core Defense Signals ---
signal core_damaged(current_hp: float, max_hp: float)
signal core_healed(amount: float, current_hp: float)
signal core_destroyed()

# --- Wave & Combat Lifecycle Signals ---
signal run_started()
signal run_ended(victory: bool)
signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal wave_countdown_updated(seconds_left: float)
signal draft_requested(wave_number: int)
signal draft_completed(chosen_card: Dictionary)
signal card_draft_requested(offered_cards: Array[Dictionary])
signal card_draft_completed(chosen_card: Dictionary)
signal victory_reached(stats: Dictionary)
signal sector_breach_alert(wave_number: int)

# --- Core Super Ability Signals ---
signal super_charge_changed(current_charge: float, max_charge: float)
signal super_ability_activated()

# --- Economy & Meta Progression Signals ---
signal currency_changed(new_amount: int, delta: int)
signal meta_cores_changed(new_amount: int, delta: int)
signal perks_updated(unlocked_perks: Dictionary)
signal game_over(stats: Dictionary)

