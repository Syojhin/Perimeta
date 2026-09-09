class_name SingularityPrism
extends TowerBase

## Gravitational displacement turret projecting micro-singularities.
## Pulls non-boss enemies into dense clusters for Mortar/Railgun follow-up fire and deals gravitational crush ticks.

@export var well_duration: float = 2.5
@export var base_well_radius: float = 100.0
@export var pull_force: float = 130.0

@onready var prism_core: Polygon2D = $TurretHead/PrismCore
@onready var shard_top: Polygon2D = $TurretHead/ShardTop
@onready var shard_bottom: Polygon2D = $TurretHead/ShardBottom
@onready var shard_left: Polygon2D = $TurretHead/ShardLeft
@onready var shard_right: Polygon2D = $TurretHead/ShardRight

var _orbit_angle: float = 0.0


func _init() -> void:
	tower_name = "Singularity Prism"
	cost = 320
	attack_range = 260.0
	fire_rate = 1.0
	damage = 12.0
	rotation_speed = 7.0


func _process(delta: float) -> void:
	super._process(delta)
	
	# Orbit floating prism crystals around central void core
	_orbit_angle += delta * 3.5
	if shard_top: shard_top.position = Vector2(cos(_orbit_angle), sin(_orbit_angle)) * 12.0
	if shard_bottom: shard_bottom.position = Vector2(cos(_orbit_angle + PI), sin(_orbit_angle + PI)) * 12.0
	if shard_left: shard_left.position = Vector2(cos(_orbit_angle + PI * 0.5), sin(_orbit_angle + PI * 0.5)) * 12.0
	if shard_right: shard_right.position = Vector2(cos(_orbit_angle + PI * 1.5), sin(_orbit_angle + PI * 1.5)) * 12.0


func fire_at(target: EnemyBase) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
		
	EventBus.tower_fired.emit(self, target)
	
	var impact_pos: Vector2 = target.global_position
	_spawn_gravity_well(impact_pos)
	
	# Muzzle beam flash
	if laser_beam:
		laser_beam.clear_points()
		laser_beam.default_color = Color("#BF55EC")
		laser_beam.width = 3.0
		laser_beam.add_point(global_position)
		laser_beam.add_point(impact_pos)
		laser_beam.visible = true
		var t: Tween = create_tween()
		t.tween_property(laser_beam, "width", 0.0, 0.15)
		t.tween_callback(func() -> void: if is_instance_valid(laser_beam): laser_beam.visible = false)


func _spawn_gravity_well(pos: Vector2) -> void:
	var tree: SceneTree = get_tree()
	var target_parent: Node = tree.current_scene if (tree and tree.current_scene) else get_parent()
	if not target_parent:
		target_parent = self
		
	var well: GravityWell = GravityWell.new()
	well.global_position = pos
	well.duration = well_duration
	
	var radius_mult: float = 1.0
	var can_pull_heavy: bool = false
	if GlobalState.run_modifiers.get("singularity_event_horizon", 0.0) > 0.0:
		radius_mult = 1.35
		can_pull_heavy = true
		
	well.radius = base_well_radius * radius_mult
	well.pull_speed = pull_force
	well.tick_damage = GlobalState.get_stat("tower_damage", _base_damage)
	well.can_pull_heavy = can_pull_heavy
	
	target_parent.add_child(well)


## In-world Micro-Singularity Field Node
class GravityWell extends Node2D:
	var duration: float = 2.5
	var radius: float = 100.0
	var pull_speed: float = 130.0
	var tick_damage: float = 12.0
	var can_pull_heavy: bool = false
	
	var _time_alive: float = 0.0
	var _tick_timer: float = 0.0
	var _visual_angle: float = 0.0
	
	func _ready() -> void:
		z_index = 10
		queue_redraw()
		
		# Play singularity activation sound
		var audio: Node = get_node_or_null("/root/AudioManager") if is_inside_tree() else null
		if audio and "snd_emp_blast" in audio:
			audio.call("play_sound", audio.get("snd_emp_blast"), 0.08, -8.0, 1.8)
			
	func _process(delta: float) -> void:
		_time_alive += delta
		_visual_angle += delta * 4.0
		queue_redraw()
		
		if _time_alive >= duration:
			_collapse_and_free()
			return
			
		_tick_timer += delta
		var do_tick: bool = false
		if _tick_timer >= 0.5:
			_tick_timer = 0.0
			do_tick = true
			
		var tree: SceneTree = get_tree()
		if not tree:
			return
			
		var r_sq: float = radius * radius
		var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
		for node: Node in enemies:
			if not (node is EnemyBase) or not is_instance_valid(node) or node.is_queued_for_deletion():
				continue
			var enemy: EnemyBase = node as EnemyBase
			if enemy.is_dead:
				continue
				
			var to_well: Vector2 = global_position - enemy.global_position
			var dist_sq: float = to_well.length_squared()
			if dist_sq <= r_sq:
				# Apply periodic damage tick
				if do_tick:
					enemy.take_damage(tick_damage, false, Color("#BF55EC"))
					
				# Apply inward gravitational displacement to non-bosses
				if enemy is BossEnemy:
					continue
				if enemy.is_gravity_immune:
					continue
				if not can_pull_heavy and enemy.get_script() and "Goliath" in enemy.get_script().resource_path:
					continue
					
				var dist: float = sqrt(dist_sq)
				if dist > 3.0:
					var forward_dir: Vector2 = Vector2.RIGHT.rotated(enemy.rotation)
					var right_dir: Vector2 = forward_dir.orthogonal()
					var pull_dir: Vector2 = to_well / dist
					
					var along_path: float = pull_dir.dot(forward_dir)
					var across_path: float = pull_dir.dot(right_dir)
					var step: float = pull_speed * delta
					
					enemy.progress = maxf(0.0, enemy.progress + along_path * step)
					enemy.v_offset = clampf(enemy.v_offset + across_path * step, -80.0, 80.0)
					
	func _draw() -> void:
		var pulse: float = (sin(_visual_angle * 2.0) + 1.0) * 0.5
		# Outer accretion distortion
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(0.75, 0.33, 0.93, 0.35 + pulse * 0.2), 2.0)
		draw_arc(Vector2.ZERO, radius * 0.65, _visual_angle, _visual_angle + PI * 1.5, 24, Color(0.3, 0.8, 1.0, 0.5), 1.5)
		
		# Swirling vortex spirals
		for i in range(4):
			var a: float = _visual_angle + float(i) * (PI * 0.5)
			var p1: Vector2 = Vector2(cos(a), sin(a)) * (radius * 0.85)
			var p2: Vector2 = Vector2(cos(a + 0.8), sin(a + 0.8)) * (radius * 0.25)
			draw_line(p1, p2, Color(0.85, 0.45, 1.0, 0.4), 1.5)
			
		# Central event horizon void
		draw_circle(Vector2.ZERO, 16.0 + pulse * 2.0, Color(0.02, 0.01, 0.06, 0.95))
		draw_arc(Vector2.ZERO, 17.0 + pulse * 2.0, 0.0, TAU, 24, Color(0.9, 0.4, 1.0, 0.9), 1.5)

	func _collapse_and_free() -> void:
		set_process(false)
		var t: Tween = create_tween()
		t.tween_property(self, "scale", Vector2.ZERO, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		t.tween_callback(queue_free)
