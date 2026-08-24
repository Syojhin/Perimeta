class_name PlasmaMortar
extends TowerBase

## Heavy artillery installation firing high-yield arcing plasma payloads that detonate on impact for wide AoE damage.

const NAPALM_HAZARD_SCENE: PackedScene = preload("res://scenes/combat/NapalmHazard.tscn")

@export var splash_radius: float = 90.0
@export var shell_flight_time: float = 0.35

@onready var barrel_left: Polygon2D = $TurretHead/BarrelLeft
@onready var barrel_right: Polygon2D = $TurretHead/BarrelRight


func _init() -> void:
	tower_name = "Plasma Mortar"
	cost = 300
	attack_range = 300.0
	fire_rate = 0.714 # 1.4s attack interval
	damage = 65.0
	rotation_speed = 8.0


func _get_effective_fire_rate() -> float:
	var rate: float = GlobalState.get_stat("attack_speed", _base_fire_rate)
	
	# Heavy Ordnance boon: -15% fire rate penalty
	if GlobalState.run_modifiers.get("mortar_heavy_ordnance", 0.0) > 0.0:
		rate *= 0.85
	
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
	var target_impact_pos: Vector2 = target.global_position
	
	# Recoil animation
	if turret_head:
		var tween: Tween = create_tween()
		tween.tween_property(turret_head, "position", Vector2(-6, 0).rotated(turret_head.rotation), 0.08)
		tween.tween_property(turret_head, "position", Vector2.ZERO, 0.2).set_trans(Tween.TRANS_BACK)
	
	_spawn_mortar_shell(start_pos, target_impact_pos)


func _spawn_mortar_shell(start_pos: Vector2, target_pos: Vector2) -> void:
	var shell: Node2D = Node2D.new()
	shell.top_level = true
	shell.global_position = start_pos
	
	var visual_dot: Polygon2D = Polygon2D.new()
	visual_dot.color = Color(2.5, 0.8, 0.2, 1.0) if tier < 5 else Color(0.3, 2.5, 2.5, 1.0)
	visual_dot.polygon = PackedVector2Array([
		Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)
	])
	shell.add_child(visual_dot)
	
	var trail: Line2D = Line2D.new()
	trail.width = 3.5
	trail.default_color = Color(1.0, 0.45, 0.1, 0.7) if tier < 5 else Color(0.2, 0.85, 1.0, 0.7)
	trail.top_level = true
	get_tree().root.add_child(trail)
	get_tree().root.add_child(shell)
	
	var arc_peak: Vector2 = (start_pos + target_pos) * 0.5 + Vector2(0, -75)
	
	var tween: Tween = create_tween()
	if tween:
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(shell):
				# Quadratic Bezier Curve: B(t) = (1-t)^2*P0 + 2(1-t)t*P1 + t^2*P2
				var p0: Vector2 = start_pos
				var p1: Vector2 = arc_peak
				var p2: Vector2 = target_pos
				var cur_pos: Vector2 = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
				shell.global_position = cur_pos
				if is_instance_valid(trail):
					trail.add_point(cur_pos)
					if trail.get_point_count() > 16:
						trail.remove_point(0)
		, 0.0, 1.0, shell_flight_time)
		
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(shell):
				shell.queue_free()
			if is_instance_valid(trail):
				var trail_tween: Tween = create_tween()
				if trail_tween:
					trail_tween.tween_property(trail, "modulate:a", 0.0, 0.2)
					trail_tween.chain().tween_callback(func() -> void:
						if is_instance_valid(trail):
							trail.queue_free()
					)
				else:
					trail.queue_free()
			_detonate_plasma_impact(target_pos)
		)
	
	# Fallback fail-safe timer in case tween is interrupted
	var tree: SceneTree = get_tree()
	if tree:
		tree.create_timer(shell_flight_time + 0.6, false).timeout.connect(func() -> void:
			if is_instance_valid(shell):
				shell.queue_free()
			if is_instance_valid(trail):
				trail.queue_free()
		)


func _detonate_plasma_impact(impact_pos: Vector2) -> void:
	var effective_radius: float = splash_radius
	if tier >= 5:
		effective_radius *= 1.5 # Master Tier 5 Singularity blast radius
	
	# Heavy Ordnance boon: +40% blast radius
	if GlobalState.run_modifiers.get("mortar_heavy_ordnance", 0.0) > 0.0:
		effective_radius *= 1.40
	
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	var effective_damage: float = GlobalState.get_stat("tower_damage", _base_damage)
	
	# Heavy Ordnance boon: +25% damage
	if GlobalState.run_modifiers.get("mortar_heavy_ordnance", 0.0) > 0.0:
		effective_damage *= 1.25
		
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if not enemy.is_dead:
				var dist: float = impact_pos.distance_to(enemy.global_position)
				if dist <= effective_radius:
					var falloff: float = clampf(1.0 - (dist / effective_radius) * 0.4, 0.6, 1.0)
					var dealt_dmg: float = effective_damage * falloff
					
					# Thermal Shock synergy: +50% extra damage if slowed/frozen
					if GlobalState.run_modifiers.get("synergy_thermal_shock", 0.0) > 0.0:
						if enemy.slow_timer > 0.0 or enemy.speed_multiplier < 1.0:
							dealt_dmg *= 1.50
							
					enemy.take_damage(dealt_dmg, tier >= 5, Color("#FF8C00") if tier < 5 else Color("#00E5FF"))
					enemy.apply_element("pyro", 3.0, dealt_dmg)
	
	_spawn_explosion_fx(impact_pos, effective_radius)
	
	# [MORTAR] Cluster Shells: Scatter 3 mini-shrapnel bomblets
	if GlobalState.run_modifiers.get("mortar_cluster_shells", 0.0) > 0.0:
		_spawn_cluster_bomblets(impact_pos, effective_damage * 0.35)
		
	# [MORTAR] Thermal Napalm: Leave burning hazard puddle on the track
	if GlobalState.run_modifiers.get("mortar_thermal_napalm", 0.0) > 0.0:
		var puddle_life: float = 6.0 if Arena.is_pyro_resonance_active() else 3.0
		var puddle_tick: float = 0.2 if Arena.is_pyro_resonance_active() else 0.4
		_spawn_napalm_puddle_custom(impact_pos, effective_damage * 0.15, puddle_life, puddle_tick)


func _spawn_napalm_puddle_custom(pos: Vector2, tick_dmg: float, custom_lifetime: float, custom_tick_rate: float) -> void:
	var tree: SceneTree = get_tree()
	if not tree or not NAPALM_HAZARD_SCENE:
		return
	
	var puddle: NapalmHazard = NAPALM_HAZARD_SCENE.instantiate() as NapalmHazard
	if puddle:
		tree.root.add_child(puddle)
		puddle.tick_rate = custom_tick_rate
		puddle.setup(pos, tick_dmg, custom_lifetime, 45.0)


func _spawn_cluster_bomblets(origin: Vector2, bomblet_damage: float) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
		
	for i in range(3):
		var angle: float = (float(i) / 3.0) * TAU + randf_range(-0.3, 0.3)
		var dist: float = randf_range(45.0, 75.0)
		var bomblet_target: Vector2 = origin + Vector2(cos(angle), sin(angle)) * dist
		
		var bomblet: Polygon2D = Polygon2D.new()
		bomblet.top_level = true
		bomblet.global_position = origin
		bomblet.color = Color(3.0, 1.5, 0.2, 1.0)
		bomblet.polygon = PackedVector2Array([
			Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)
		])
		tree.root.add_child(bomblet)
		
		var b_tween: Tween = create_tween()
		if b_tween:
			b_tween.tween_property(bomblet, "global_position", bomblet_target, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			b_tween.chain().tween_callback(func() -> void:
				if is_instance_valid(bomblet):
					bomblet.queue_free()
				_detonate_mini_bomblet(bomblet_target, bomblet_damage)
			)
		
		# Fallback fail-safe timer
		tree.create_timer(0.4, false).timeout.connect(func() -> void:
			if is_instance_valid(bomblet):
				bomblet.queue_free()
		)


func _detonate_mini_bomblet(pos: Vector2, dmg: float) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	# Mini explosion visual
	var shock: Line2D = Line2D.new()
	shock.top_level = true
	shock.global_position = pos
	shock.width = 2.5
	shock.default_color = Color(3.0, 1.8, 0.4, 1.0)
	for i in range(16 + 1):
		var ang: float = (float(i) / 16.0) * TAU
		shock.add_point(Vector2(cos(ang), sin(ang)) * 4.0)
	tree.root.add_child(shock)
	
	var sw_tween: Tween = create_tween()
	if sw_tween:
		sw_tween.tween_property(shock, "scale", Vector2(7.0, 7.0), 0.14)
		sw_tween.parallel().tween_property(shock, "modulate:a", 0.0, 0.14)
		sw_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(shock):
				shock.queue_free()
		)
	
	# Fallback fail-safe timer
	tree.create_timer(0.3, false).timeout.connect(func() -> void:
		if is_instance_valid(shock):
			shock.queue_free()
	)
	
	# Damage targets in mini-blast
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if not enemy.is_dead and pos.distance_to(enemy.global_position) <= 45.0:
				enemy.take_damage(dmg, false, Color("#FFA500"))
				enemy.apply_element("pyro", 2.0, dmg)


func _spawn_napalm_puddle(pos: Vector2, tick_dmg: float) -> void:
	var tree: SceneTree = get_tree()
	if not tree or not NAPALM_HAZARD_SCENE:
		return
	
	var puddle: NapalmHazard = NAPALM_HAZARD_SCENE.instantiate() as NapalmHazard
	if puddle:
		tree.root.add_child(puddle)
		puddle.setup(pos, tick_dmg, 3.0, 45.0)


func _spawn_explosion_fx(pos: Vector2, radius: float) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	# Screen shake trigger
	var current_scene: Node = tree.current_scene
	if current_scene and current_scene.has_method("trigger_shake"):
		current_scene.call("trigger_shake", 5.0, 0.2)
	
	# Expanding Neon Shockwave Ring
	var shockwave: Line2D = Line2D.new()
	shockwave.top_level = true
	shockwave.global_position = pos
	shockwave.width = 4.0
	shockwave.default_color = Color(3.0, 1.2, 0.3, 1.0) if tier < 5 else Color(0.4, 2.5, 3.0, 1.0)
	
	var points: int = 28
	for i in range(points + 1):
		var angle: float = (float(i) / float(points)) * TAU
		shockwave.add_point(Vector2(cos(angle), sin(angle)) * 6.0)
	
	tree.root.add_child(shockwave)
	
	var fx_tween: Tween = create_tween()
	if fx_tween:
		fx_tween.tween_property(shockwave, "scale", Vector2(radius / 6.0, radius / 6.0), 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		fx_tween.parallel().tween_property(shockwave, "modulate:a", 0.0, 0.22)
		fx_tween.chain().tween_callback(func() -> void:
			if is_instance_valid(shockwave):
				shockwave.queue_free()
		)
	
	# Fallback fail-safe timer
	tree.create_timer(0.4, false).timeout.connect(func() -> void:
		if is_instance_valid(shockwave):
			shockwave.queue_free()
	)
