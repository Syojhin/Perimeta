class_name RailgunTurret
extends TowerBase

## Long-range electromagnetic accelerator firing hyper-velocity kinetic slugs that penetrate all targets in a linear vector.

const IONIZED_TRAIL_SCENE: PackedScene = preload("res://scenes/combat/IonizedTrailHazard.tscn")

@export var beam_width: float = 28.0
@export var ray_pierce_distance: float = 2200.0


func _init() -> void:
	tower_name = "Railgun"
	cost = 450
	attack_range = 380.0
	fire_rate = 0.555 # 1.8s attack interval
	damage = 120.0
	rotation_speed = 12.0


func _get_effective_fire_rate() -> float:
	var rate: float = GlobalState.get_stat("attack_speed", _base_fire_rate)
	
	# Kinetic Overclock synergy: +30% attack speed when near a Pulse Turret
	if GlobalState.run_modifiers.get("synergy_kinetic_overclock", 0.0) > 0.0 and _has_nearby_pulse_turret():
		rate *= 1.30
		
	return rate


func _has_nearby_pulse_turret() -> bool:
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return false
	var sockets: Node = tree.current_scene.get_node_or_null("Sockets")
	if not sockets:
		return false
	for child: Node in sockets.get_children():
		if child is BuildSocket and is_instance_valid(child.current_tower):
			var tower: TowerBase = child.current_tower
			if tower != self and not (tower is PlasmaMortar or tower is RailgunTurret or tower is CryoTurret or tower is ChainTurret):
				if global_position.distance_to(tower.global_position) <= attack_range:
					return true
	return false


func fire_at(target: EnemyBase) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
	
	EventBus.tower_fired.emit(self, target)
	
	var start_pos: Vector2 = muzzle.global_position if muzzle else global_position
	var fire_dir: Vector2 = (target.global_position - global_position).normalized()
	if fire_dir.length_squared() == 0:
		fire_dir = Vector2.RIGHT.rotated(turret_head.rotation if turret_head else 0.0)
	
	var max_dist: float = ray_pierce_distance
	var end_pos: Vector2 = global_position + (fire_dir * max_dist)
	
	# Recoil kick animation
	if turret_head:
		var tween: Tween = create_tween()
		tween.tween_property(turret_head, "position", -fire_dir * 10.0, 0.04)
		tween.tween_property(turret_head, "position", Vector2.ZERO, 0.22).set_trans(Tween.TRANS_BACK)
	
	_pierce_all_enemies_in_line(start_pos, end_pos)
	_draw_hyper_velocity_beam(start_pos, end_pos)
	
	# [RAILGUN] Ionized Trail: leave an electrified beam hazard for 2.0s
	if GlobalState.run_modifiers.get("railgun_ionized_trail", 0.0) > 0.0:
		_spawn_ionized_trail_hazard(start_pos, end_pos)
	
	# Audio and Screen Shake
	AudioManager.play_sound(AudioManager.snd_laser, 0.03, -2.0)
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("trigger_shake"):
		tree.current_scene.call("trigger_shake", 6.0, 0.15)


func _pierce_all_enemies_in_line(start_pos: Vector2, end_pos: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	var effective_dmg: float = GlobalState.get_stat("tower_damage", _base_damage)
	var is_master: bool = (tier >= 5)
	var base_final_dmg: float = effective_dmg if not is_master else effective_dmg * 1.6
	var damage_color: Color = Color("#00FFFF") if not is_master else Color("#FFE850")
	
	# Dual Capacitor boon: double beam width
	var effective_width: float = beam_width
	if GlobalState.run_modifiers.get("railgun_dual_capacitor", 0.0) > 0.0:
		effective_width *= 2.0
	
	var superconductor_val: float = GlobalState.run_modifiers.get("railgun_superconductor", 0.0)
	
	# Find all enemies in line and calculate distance along beam
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	var hit_entries: Array[Dictionary] = []
	
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if not enemy.is_dead and not enemy.is_cloaked:
				var enemy_pos: Vector2 = enemy.global_position
				var closest_point: Vector2 = Geometry2D.get_closest_point_to_segment(enemy_pos, global_position, end_pos)
				if enemy_pos.distance_to(closest_point) <= effective_width:
					var dist_along_beam: float = start_pos.distance_squared_to(closest_point)
					hit_entries.append({
						"enemy": enemy,
						"dist": dist_along_beam
					})
	
	# Sort enemies by order of penetration along the beam
	hit_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dist"] < b["dist"]
	)
	
	# Apply damage with Superconductor and Dual Capacitor bonuses
	for i in range(hit_entries.size()):
		var enemy: EnemyBase = hit_entries[i]["enemy"]
		if not is_instance_valid(enemy) or enemy.is_dead:
			continue
			
		var enemy_dmg: float = base_final_dmg
		
		# Superconductor: +15% damage per enemy pierced in this shot
		if superconductor_val > 0.0:
			enemy_dmg *= (1.0 + (float(i) * superconductor_val))
			
		# Dual Capacitor: +20% damage vs Shielded/Armored/Boss units
		if GlobalState.run_modifiers.get("railgun_dual_capacitor", 0.0) > 0.0:
			if enemy.is_shielded or enemy is GoliathEnemy or enemy is BreacherEnemy or enemy is BossEnemy:
				enemy_dmg *= 1.20
				
		# Electro Resonance: High Voltage +25% crit damage bonus
		if Arena.is_electro_resonance_active() and randf() < 0.25:
			enemy_dmg *= 1.5
			
		enemy.take_damage(enemy_dmg, true, damage_color)
		enemy.apply_element("electro", 3.0, enemy_dmg)


func _draw_hyper_velocity_beam(start_pos: Vector2, end_pos: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	var is_master: bool = (tier >= 5)
	var is_dual_cap: bool = GlobalState.run_modifiers.get("railgun_dual_capacitor", 0.0) > 0.0
	
	# Outer glow beam
	var glow_beam: Line2D = Line2D.new()
	glow_beam.top_level = true
	var width_mult: float = 2.0 if is_dual_cap else 1.0
	glow_beam.width = (14.0 if not is_master else 22.0) * width_mult
	glow_beam.default_color = Color(0.2, 0.85, 1.0, 0.8) if not is_master else Color(1.0, 0.8, 0.2, 0.85)
	glow_beam.add_point(start_pos)
	glow_beam.add_point(end_pos)
	
	# White-hot inner core
	var core_beam: Line2D = Line2D.new()
	core_beam.top_level = true
	core_beam.width = (4.0 if not is_master else 6.0) * (1.4 if is_dual_cap else 1.0)
	core_beam.default_color = Color(3.0, 3.0, 3.0, 1.0)
	core_beam.add_point(start_pos)
	core_beam.add_point(end_pos)
	
	tree.root.add_child(glow_beam)
	tree.root.add_child(core_beam)
	
	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(glow_beam, "width", 0.0, 0.12)
		tween.parallel().tween_property(glow_beam, "modulate:a", 0.0, 0.12)
		tween.parallel().tween_property(core_beam, "width", 0.0, 0.12)
		tween.parallel().tween_property(core_beam, "modulate:a", 0.0, 0.12)
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(glow_beam):
				glow_beam.queue_free()
			if is_instance_valid(core_beam):
				core_beam.queue_free()
		)
	
	# Fallback fail-safe timer
	tree.create_timer(0.3, false).timeout.connect(func() -> void:
		if is_instance_valid(glow_beam):
			glow_beam.queue_free()
		if is_instance_valid(core_beam):
			core_beam.queue_free()
	)


func _spawn_ionized_trail_hazard(start_pos: Vector2, end_pos: Vector2) -> void:
	var tree: SceneTree = get_tree()
	if not tree or not IONIZED_TRAIL_SCENE:
		return
	
	var trail: IonizedTrailHazard = IONIZED_TRAIL_SCENE.instantiate() as IonizedTrailHazard
	if trail:
		tree.root.add_child(trail)
		var effective_dmg: float = GlobalState.get_stat("tower_damage", _base_damage) * 0.25
		var effective_width: float = beam_width if GlobalState.run_modifiers.get("railgun_dual_capacitor", 0.0) == 0.0 else beam_width * 2.0
		trail.setup(start_pos, end_pos, effective_dmg, 2.0, effective_width)
