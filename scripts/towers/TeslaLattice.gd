class_name TeslaLattice
extends TowerBase

## Inter-socket area denial turret establishing high-voltage laser fences between adjacent nodes.
## Enemies crossing the laser take continuous piercing ticks with a 15% slow and micro-stuns.

const BASE_TETHER_MAX_DIST: float = 340.0

@onready var tether_line: Line2D = $TetherLine
@onready var coil_left: Polygon2D = $TurretHead/CoilLeft
@onready var coil_right: Polygon2D = $TurretHead/CoilRight
@onready var core_spark: Polygon2D = $TurretHead/CoreSpark

var _active_peers: Array[TeslaLattice] = []
var _tether_lines: Array[Line2D] = []
var _tether_tick_timer: float = 0.0


func _init() -> void:
	tower_name = "Tesla Lattice"
	cost = 220
	attack_range = 220.0
	fire_rate = 2.2
	damage = 45.0
	rotation_speed = 12.0


func _ready() -> void:
	super._ready()
	add_to_group("tesla_towers")
	
	if tether_line:
		tether_line.visible = false
		tether_line.top_level = true


func _exit_tree() -> void:
	for line: Line2D in _tether_lines:
		if is_instance_valid(line):
			line.queue_free()
	_tether_lines.clear()


func _process(delta: float) -> void:
	super._process(delta)
	
	_update_tether_connections(delta)
	
	# Electrical core oscillation
	if core_spark:
		core_spark.scale = Vector2.ONE * (0.8 + randf() * 0.4)


func fire_at(target: EnemyBase) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion() or target.is_dead:
		return
		
	EventBus.tower_fired.emit(self, target)
	
	# Direct electrical discharge
	var effective_damage: float = GlobalState.get_stat("tower_damage", _base_damage)
	target.take_damage(effective_damage, false, Color("#00F0FF"))
	if is_instance_valid(target) and not target.is_queued_for_deletion():
		target.apply_element("electro", 3.0, effective_damage)
	
	if laser_beam:
		laser_beam.clear_points()
		laser_beam.default_color = Color("#00F0FF")
		laser_beam.width = 3.5
		laser_beam.add_point(global_position)
		var target_pos: Vector2 = target.global_position if is_instance_valid(target) else global_position
		var mid: Vector2 = (global_position + target_pos) * 0.5 + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		laser_beam.add_point(mid)
		laser_beam.add_point(target_pos)
		laser_beam.visible = true
		
		var t: Tween = create_tween()
		t.tween_property(laser_beam, "width", 0.0, 0.12)
		t.tween_callback(func() -> void: if is_instance_valid(laser_beam): laser_beam.visible = false)


func get_max_tether_distance() -> float:
	var mult: float = 1.0
	if GlobalState.run_modifiers.get("tesla_superconducting_wire", 0.0) > 0.0:
		mult = 1.40
	return BASE_TETHER_MAX_DIST * mult


func _update_tether_connections(delta: float) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
		
	var max_dist: float = get_max_tether_distance()
	var peers: Array[Node] = tree.get_nodes_in_group("tesla_towers").duplicate()
	
	# Find peers to connect to (only connect if our instance ID is smaller to avoid duplicate tethers)
	_active_peers.clear()
	for node: Node in peers:
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if node is TeslaLattice and node != self:
			var peer: TeslaLattice = node as TeslaLattice
			if not is_instance_valid(peer) or peer.is_queued_for_deletion():
				continue
			if get_instance_id() < peer.get_instance_id():
				var dist: float = global_position.distance_to(peer.global_position)
				if dist <= max_dist:
					_active_peers.append(peer)
					
	# Synchronize Line2D pool for tethers
	while _tether_lines.size() < _active_peers.size():
		var l: Line2D = Line2D.new()
		l.top_level = true
		l.width = 3.0
		l.default_color = Color("#00F0FF")
		tree.current_scene.add_child(l)
		_tether_lines.append(l)
		
	while _tether_lines.size() > _active_peers.size():
		var extra: Line2D = _tether_lines.pop_back()
		if is_instance_valid(extra):
			extra.queue_free()
			
	# Render each tether and check enemy intersection
	var has_superconducting: bool = GlobalState.run_modifiers.get("tesla_superconducting_wire", 0.0) > 0.0
	var tick_damage: float = GlobalState.get_stat("tower_damage", _base_damage) * delta * 1.5
	
	for i in range(_active_peers.size()):
		var peer: TeslaLattice = _active_peers[i]
		var line: Line2D = _tether_lines[i]
		_render_electric_line(line, global_position, peer.global_position)
		_check_laser_intersections(global_position, peer.global_position, tick_damage, has_superconducting)


func _render_electric_line(line: Line2D, p_start: Vector2, p_end: Vector2) -> void:
	line.clear_points()
	line.visible = true
	line.width = 2.5 + randf() * 1.5
	line.default_color = Color(0.1, 0.9, 1.0, 0.85) if randf() > 0.2 else Color(1.0, 1.0, 0.6, 0.95)
	
	var dir: Vector2 = p_end - p_start
	var dist: float = dir.length()
	var normal: Vector2 = dir.orthogonal().normalized()
	
	line.add_point(p_start)
	var segments: int = clampi(int(dist / 40.0), 3, 8)
	for s in range(1, segments):
		var frac: float = float(s) / float(segments)
		var base_pt: Vector2 = p_start + dir * frac
		var jitter: Vector2 = normal * randf_range(-6.0, 6.0)
		line.add_point(base_pt + jitter)
	line.add_point(p_end)


func _check_laser_intersections(p_start: Vector2, p_end: Vector2, tick_dmg: float, has_superconducting: bool) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
		
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies").duplicate()
	const BEAM_HIT_DIST: float = 24.0
	
	for node: Node in enemies:
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not (node is EnemyBase):
			continue
		var enemy: EnemyBase = node as EnemyBase
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_dead:
			continue
			
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, p_start, p_end)
		if enemy.global_position.distance_to(closest) <= BEAM_HIT_DIST:
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
				continue
			enemy.take_damage(tick_dmg, false, Color("#00F0FF"))
			if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or enemy.is_dead:
				continue
			enemy.apply_slow(0.85, 0.4) # 15% slow while crossing
			enemy.apply_element("electro", 2.0, tick_dmg)
			
			if has_superconducting:
				enemy.stun_timer = maxf(enemy.stun_timer, 0.25)
