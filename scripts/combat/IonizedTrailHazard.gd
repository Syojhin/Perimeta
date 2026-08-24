class_name IonizedTrailHazard
extends Node2D

## Linear beam hazard created by Railgun Ionized Trail boon. Shocks passing enemies and auto-despawns after a strict lifetime.

@export var lifetime: float = 2.0
@export var damage_per_tick: float = 25.0
@export var tick_rate: float = 0.25
@export var beam_width: float = 28.0

var _start_point: Vector2 = Vector2.ZERO
var _end_point: Vector2 = Vector2.ZERO
var _lifetime_timer: float = 2.0
var _tick_timer: float = 0.0

@onready var beam_line: Line2D = $BeamLine


func _ready() -> void:
	add_to_group("hazards")
	_lifetime_timer = lifetime
	
	if beam_line and beam_line.get_point_count() == 0 and _start_point != _end_point:
		beam_line.add_point(_start_point)
		beam_line.add_point(_end_point)
	
	# Primary tweened fadeout & despawn
	var tween: Tween = create_tween()
	if tween:
		tween.tween_interval(maxf(0.1, lifetime - 0.4))
		tween.tween_property(self, "modulate:a", 0.0, 0.4)
		tween.chain().tween_callback(queue_free)


func setup(start_pos: Vector2, end_pos: Vector2, tick_dmg: float, custom_lifetime: float = 2.0, custom_width: float = 28.0) -> void:
	_start_point = start_pos
	_end_point = end_pos
	damage_per_tick = tick_dmg
	lifetime = custom_lifetime
	_lifetime_timer = custom_lifetime
	beam_width = custom_width
	top_level = true
	
	if beam_line:
		beam_line.clear_points()
		beam_line.add_point(_start_point)
		beam_line.add_point(_end_point)
		beam_line.width = 6.0


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
	
	# Electric flickering pulse
	if beam_line:
		beam_line.modulate = Color(2.5, 2.5, 4.0, 1.0)
		var t: Tween = create_tween()
		t.tween_property(beam_line, "modulate", Color.WHITE, 0.15)
	
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if not enemy.is_dead and not enemy.is_cloaked:
				var closest_pt: Vector2 = Geometry2D.get_closest_point_to_segment(enemy.global_position, _start_point, _end_point)
				if enemy.global_position.distance_to(closest_pt) <= beam_width:
					enemy.take_damage(damage_per_tick, false, Color("#64D2FF"))
					enemy.apply_element("electro", 2.0, damage_per_tick)
