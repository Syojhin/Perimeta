class_name NaniteHive
extends TowerBase

## Rapid-fire bio-mechanical incubator launching corrosive nanite swarms.
## Stacks up to 10 nanite layers that shred armor rating by 5% each, deal toxic DoT,
## and detonate in a corrosive AoE burst upon host termination.

@onready var hive_core: Polygon2D = $TurretHead/HiveCore
@onready var cell_left: Polygon2D = $TurretHead/CellLeft
@onready var cell_right: Polygon2D = $TurretHead/CellRight
@onready var cell_center: Polygon2D = $TurretHead/CellCenter

var _swarm_pulse: float = 0.0


func _init() -> void:
	tower_name = "Nanite Hive"
	cost = 260
	attack_range = 200.0
	fire_rate = 3.5
	damage = 8.0
	rotation_speed = 16.0


func _process(delta: float) -> void:
	super._process(delta)
	
	_swarm_pulse += delta * 6.0
	var pulse: float = 0.85 + (sin(_swarm_pulse) + 1.0) * 0.15
	if cell_center: cell_center.scale = Vector2.ONE * pulse


func fire_at(target: EnemyBase) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
		
	EventBus.tower_fired.emit(self, target)
	
	# Apply nanite stack infection (max 10 stacks)
	target.add_nanite_stacks(1, 4.0)
	
	# Deal direct tick damage
	var effective_damage: float = GlobalState.get_stat("tower_damage", _base_damage)
	target.take_damage(effective_damage, false, Color("#76FF03"))
	
	# Visual swarm dart
	_show_nanite_projectile(target.global_position)


func _show_nanite_projectile(target_pos: Vector2) -> void:
	if laser_beam:
		laser_beam.clear_points()
		laser_beam.default_color = Color("#76FF03")
		laser_beam.width = 2.5
		var start: Vector2 = muzzle.global_position if muzzle else global_position
		laser_beam.add_point(start)
		
		# Slight swarm curve
		var mid: Vector2 = (start + target_pos) * 0.5 + Vector2(randf_range(-12, 12), randf_range(-12, 12))
		laser_beam.add_point(mid)
		laser_beam.add_point(target_pos)
		laser_beam.visible = true
		
		var t: Tween = create_tween()
		t.tween_property(laser_beam, "width", 0.0, 0.1)
		t.tween_callback(func() -> void: if is_instance_valid(laser_beam): laser_beam.visible = false)
