class_name ChainTurret
extends TowerBase

## High-voltage electrical turret that arcs lightning through multiple enemy targets.

@export var base_bounces: int = 3
@export var chain_range: float = 150.0
@export var damage_falloff: float = 0.85


func _init() -> void:
	tower_name = "Chain Turret"
	cost = 200
	damage = 18.0
	fire_rate = 2.222 # 0.45s attack interval
	attack_range = 200.0


func fire_at(target: EnemyBase) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
	
	EventBus.tower_fired.emit(self, target)
	
	var extra_bounces: int = 4 if tier == 5 else 0
	if Arena.is_electro_resonance_active():
		extra_bounces += 2 # High Voltage electro resonance
		
	var max_bounces: int = base_bounces + extra_bounces + int(GlobalState.get_stat("chain_bounces", 0.0))
	var effective_falloff: float = 1.0 if tier == 5 else damage_falloff
	var hit_chain: Array[EnemyBase] = [target]
	var current_dmg: float = GlobalState.get_stat("tower_damage", _base_damage)
	
	var is_crit: bool = (tier == 5) or (Arena.is_electro_resonance_active() and randf() < 0.25)
	if is_crit and tier != 5:
		current_dmg *= 1.5
	
	# Electric amber damage number and electro affliction
	target.take_damage(current_dmg, is_crit, Color("#FFE040"))
	target.apply_element("electro", 3.0, current_dmg)
	
	var current_source: EnemyBase = target
	for _i in range(max_bounces):
		var next_target: EnemyBase = _find_next_chain_target(current_source, hit_chain)
		if not next_target:
			break
		
		hit_chain.append(next_target)
		current_dmg *= effective_falloff
		next_target.take_damage(current_dmg, is_crit, Color("#FFE040"))
		next_target.apply_element("electro", 3.0, current_dmg)
		current_source = next_target
	
	_show_chain_visual(hit_chain)


func _find_next_chain_target(source: EnemyBase, exclude_list: Array[EnemyBase]) -> EnemyBase:
	var closest: EnemyBase = null
	var shortest_dist_sq: float = (chain_range * (1.3 if tier == 5 else 1.0)) ** 2
	
	for enemy: EnemyBase in enemies_in_range:
		if not is_instance_valid(enemy) or enemy.is_dead or exclude_list.has(enemy):
			continue
		
		var dist_sq: float = source.global_position.distance_squared_to(enemy.global_position)
		if dist_sq <= shortest_dist_sq:
			shortest_dist_sq = dist_sq
			closest = enemy
			
	return closest


func _show_chain_visual(hit_targets: Array[EnemyBase]) -> void:
	if not laser_beam or not muzzle or hit_targets.is_empty():
		return
	
	laser_beam.clear_points()
	laser_beam.add_point(muzzle.global_position)
	for enemy: EnemyBase in hit_targets:
		if is_instance_valid(enemy):
			laser_beam.add_point(enemy.global_position)
	
	laser_beam.visible = true
	if tier == 5:
		laser_beam.width = 7.0
		laser_beam.modulate = Color(3.5, 2.8, 0.6, 1.0) # Master thunder gold
	else:
		laser_beam.width = 3.0 + float(tier) * 0.5
		laser_beam.modulate = Color(2.5, 1.8, 0.4, 1.0) # Electric amber/yellow lightning
	
	var tween: Tween = create_tween()
	tween.tween_property(laser_beam, "modulate:a", 0.0, 0.1)
	tween.tween_callback(func() -> void:
		if is_instance_valid(laser_beam):
			laser_beam.visible = false
	)
