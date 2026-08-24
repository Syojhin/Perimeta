class_name CryoTurret
extends TowerBase

## Defensive cryogenic turret that slows enemies and delivers frost area-of-effect damage.

@export var slow_factor: float = 0.45
@export var splash_radius: float = 70.0


func _init() -> void:
	tower_name = "Cryo Emitter"
	cost = 150
	damage = 4.0
	fire_rate = 3.333 # 0.3s attack interval
	attack_range = 240.0


func fire_at(target: EnemyBase) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
	
	EventBus.tower_fired.emit(self, target)
	_show_attack_visual(target.global_position)
	
	var effective_damage: float = GlobalState.get_stat("tower_damage", _base_damage)
	var current_slow: float = 0.75 if tier == 5 else slow_factor
	if Arena.is_cryo_resonance_active():
		current_slow = minf(0.85, current_slow * 1.25)
		
	var current_radius: float = 130.0 if tier == 5 else splash_radius
	var splash_damage_mult: float = 1.0 if tier == 5 else 0.5
	
	# Primary target damage, slow & cryo affliction with Ice Cyan damage numbers
	target.take_damage(effective_damage, tier == 5, Color("#64D2FF"))
	target.apply_slow(current_slow)
	target.apply_element("cryo", 3.0, effective_damage)
	
	# AoE splash slow on nearby enemies
	for enemy: EnemyBase in enemies_in_range:
		if enemy != target and is_instance_valid(enemy) and not enemy.is_dead:
			if enemy.global_position.distance_to(target.global_position) <= current_radius:
				var splash_dmg: float = effective_damage * splash_damage_mult
				enemy.take_damage(splash_dmg, tier == 5, Color("#64D2FF"))
				enemy.apply_slow(current_slow)
				enemy.apply_element("cryo", 3.0, splash_dmg)
