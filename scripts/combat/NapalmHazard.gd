class_name NapalmHazard
extends Node2D

## Ground hazard created by Plasma Mortar Thermal Napalm boon. Ticks fire damage to passing enemies and auto-despawns after a strict lifetime.

@export var lifetime: float = 3.0
@export var damage_per_tick: float = 12.0
@export var tick_rate: float = 0.4
@export var radius: float = 45.0

var _lifetime_timer: float = 3.0
var _tick_timer: float = 0.0

@onready var puddle_polygon: Polygon2D = $PuddlePolygon


func _ready() -> void:
	add_to_group("hazards")
	_lifetime_timer = lifetime
	
	if puddle_polygon and puddle_polygon.polygon.is_empty():
		_generate_puddle_shape()
	
	# Primary tweened fadeout & despawn
	var tween: Tween = create_tween()
	if tween:
		tween.tween_interval(maxf(0.1, lifetime - 0.5))
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.chain().tween_callback(queue_free)


func setup(impact_pos: Vector2, tick_dmg: float, custom_lifetime: float = 3.0, custom_radius: float = 45.0) -> void:
	global_position = impact_pos
	damage_per_tick = tick_dmg
	lifetime = custom_lifetime
	_lifetime_timer = custom_lifetime
	radius = custom_radius
	top_level = true


func _generate_puddle_shape() -> void:
	if not puddle_polygon:
		puddle_polygon = Polygon2D.new()
		puddle_polygon.name = "PuddlePolygon"
		add_child(puddle_polygon)
	
	puddle_polygon.color = Color(2.0, 0.45, 0.1, 0.5)
	var pts: PackedVector2Array = PackedVector2Array()
	var point_count: int = 16
	for i in range(point_count):
		var ang: float = (float(i) / float(point_count)) * TAU
		var r: float = radius * randf_range(0.85, 1.15)
		pts.append(Vector2(cos(ang) * r, sin(ang) * r))
	puddle_polygon.polygon = pts


func _process(delta: float) -> void:
	# Fallback fail-safe timer guarantees despawn even if tweens are paused or interrupted
	_lifetime_timer -= delta
	if _lifetime_timer <= 0.0:
		queue_free()
		return
	
	# Apply damage ticks
	_tick_timer += delta
	if _tick_timer >= tick_rate:
		_tick_timer = 0.0
		_apply_tick_damage()


func _apply_tick_damage() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	# Pulse visual on tick
	if puddle_polygon:
		puddle_polygon.modulate = Color(1.8, 1.4, 0.6, 1.0)
		var t: Tween = create_tween()
		t.tween_property(puddle_polygon, "modulate", Color.WHITE, 0.2)
	
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	var r_sq: float = radius * radius
	
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if not enemy.is_dead and global_position.distance_squared_to(enemy.global_position) <= r_sq:
				enemy.take_damage(damage_per_tick, false, Color("#FF4500"))
				enemy.apply_element("pyro", 2.0, damage_per_tick)
