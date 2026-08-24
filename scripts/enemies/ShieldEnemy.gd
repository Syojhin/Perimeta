class_name ShieldEnemy
extends EnemyBase

## Support tank emitting a 120px protective energy field that shields nearby allies with 50% damage reduction.

@export var aura_radius: float = 120.0

@onready var aura_ring: Line2D = $AuraRing
@onready var aura_glow: Polygon2D = $AuraGlow

var _shielded_allies: Array[EnemyBase] = []


func _init() -> void:
	enemy_name = "Shield Drone"
	max_hp = 120.0
	move_speed = 90.0
	core_damage = 15.0
	bounty = 28
	primary_color = Color(0.2, 0.85, 1.0, 1.0)


func _ready() -> void:
	super._ready()
	_setup_aura_visuals()


func _process(delta: float) -> void:
	super._process(delta)
	
	if is_dead:
		_clear_shielded_allies()
		return
	
	_update_aura_shields()


func _setup_aura_visuals() -> void:
	if not aura_ring:
		return
	
	aura_ring.clear_points()
	var points_count: int = 32
	for i in range(points_count + 1):
		var angle: float = (float(i) / float(points_count)) * TAU
		aura_ring.add_point(Vector2(cos(angle), sin(angle)) * aura_radius)


func _update_aura_shields() -> void:
	var path_parent: Node = get_parent()
	if not path_parent:
		return
	
	var current_in_aura: Array[EnemyBase] = []
	var radius_sq: float = aura_radius * aura_radius
	
	for child: Node in path_parent.get_children():
		if child is EnemyBase and child != self and is_instance_valid(child):
			var ally: EnemyBase = child as EnemyBase
			if not ally.is_dead:
				var dist_sq: float = global_position.distance_squared_to(ally.global_position)
				if dist_sq <= radius_sq:
					ally.is_shielded = true
					current_in_aura.append(ally)
	
	# Clear shield on allies that moved outside aura
	for ally: EnemyBase in _shielded_allies:
		if is_instance_valid(ally) and not current_in_aura.has(ally):
			ally.is_shielded = false
	
	_shielded_allies = current_in_aura


func _clear_shielded_allies() -> void:
	for ally: EnemyBase in _shielded_allies:
		if is_instance_valid(ally):
			ally.is_shielded = false
	_shielded_allies.clear()


func die() -> void:
	_clear_shielded_allies()
	super.die()


func reach_core() -> void:
	_clear_shielded_allies()
	super.reach_core()
