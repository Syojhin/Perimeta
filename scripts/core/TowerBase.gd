class_name TowerBase
extends Node2D

## Base class for defensive towers in Perimeta. Manages range detection, targeting, upgrades, and dynamic stat resolution.

enum TargetPriority {
	FIRST,
	CLOSEST,
	STRONGEST,
	WEAKEST,
	LAST
}

@export var tower_name: String = "Pulse Turret"
@export var attack_range: float = 220.0:
	set(value):
		attack_range = value
		_update_range_shape()

@export var fire_rate: float = 5.555 # 0.18s attack interval
@export var damage: float = 15.0
@export var cost: int = 100
@export var target_priority: TargetPriority = TargetPriority.FIRST
@export var rotation_speed: float = 14.0

var tier: int = 1
var max_tier: int = 5
var infusion_level: int = 0
var total_invested_bits: int = 100

var _base_range: float = 220.0
var _base_fire_rate: float = 5.555
var _base_damage: float = 15.0

var current_target: EnemyBase = null
var enemies_in_range: Array[EnemyBase] = []
var _time_until_next_shot: float = 0.0
var is_selected: bool = false
var is_hovered: bool = false

@onready var range_area: Area2D = $RangeArea
@onready var range_collision: CollisionShape2D = $RangeArea/CollisionShape2D
@onready var turret_head: Node2D = $TurretHead
@onready var muzzle: Marker2D = $TurretHead/Muzzle
@onready var laser_beam: Line2D = $LaserBeam


func _ready() -> void:
	_base_range = attack_range
	_base_fire_rate = fire_rate
	_base_damage = damage
	total_invested_bits = cost
	
	refresh_stats()
	EventBus.perks_updated.connect(_on_perks_updated)
	
	range_area.area_entered.connect(_on_range_area_entered)
	range_area.area_exited.connect(_on_range_area_exited)
	
	if laser_beam:
		laser_beam.visible = false
		laser_beam.top_level = true # Draw in global coordinates for laser lines
	
	EventBus.tower_placed.emit(self)


## Refresh effective stats from GlobalState meta perks.
func refresh_stats() -> void:
	attack_range = GlobalState.get_stat("tower_range", _base_range)
	fire_rate = GlobalState.get_stat("attack_speed", _base_fire_rate)
	damage = GlobalState.get_stat("tower_damage", _base_damage)
	_update_range_shape()


## Calculate the upgrade cost for the next tier (T2: 150, T3: 350, T4: 800, T5: 2000, Infusions: 1000 + lvl*1500).
func get_upgrade_cost() -> int:
	if tier >= max_tier:
		return get_infusion_cost()
	match tier:
		1: return 150
		2: return 350
		3: return 800
		4: return 2000
	return 0


## Calculate Overclock Infusion cost for infinite late-game Bit sink.
func get_infusion_cost() -> int:
	return 1000 + (infusion_level * 1500)


## Calculate the sell refund value (70% of total invested bits).
func get_sell_refund() -> int:
	return int(total_invested_bits * 0.70)


## Upgrade this tower to the next tier, or perform Overclock Infusion if at Tier 5 Master.
func upgrade() -> bool:
	if tier >= max_tier:
		return infuse_overclock()
	
	var up_cost: int = get_upgrade_cost()
	if not GlobalState.spend_currency(up_cost):
		return false
	
	total_invested_bits += up_cost
	tier += 1
	
	if tier == 5:
		# Tier 5 Master
		_base_damage *= 2.0
		_base_range *= 1.30
	else:
		_base_damage *= 1.35
		_base_range *= 1.15
		
	refresh_stats()
	_show_upgrade_effect()
	EventBus.tower_upgraded.emit(self)
	return true


## Infuse Tier 5 Master tower with extra damage (+5%) and range (+3%) indefinitely.
func infuse_overclock() -> bool:
	var cost_req: int = get_infusion_cost()
	if not GlobalState.spend_currency(cost_req):
		return false
	
	infusion_level += 1
	total_invested_bits += cost_req
	_base_damage *= 1.05
	_base_range *= 1.03
	refresh_stats()
	_show_upgrade_effect()
	EventBus.tower_upgraded.emit(self)
	return true


## Sell and decommission this tower, refunding 70% of invested Bits.
func sell() -> int:
	var refund: int = get_sell_refund()
	GlobalState.add_currency(refund)
	EventBus.tower_sold.emit(self)
	queue_free()
	return refund


func _process(delta: float) -> void:
	_clean_invalid_enemies()
	_update_target()
	
	if current_target and is_instance_valid(current_target) and not current_target.is_dead:
		_aim_at_target(delta)
		
		_time_until_next_shot -= delta
		if _time_until_next_shot <= 0.0:
			fire_at(current_target)
			var effective_fire_rate: float = _get_effective_fire_rate()
			_time_until_next_shot = 1.0 / maxf(0.01, effective_fire_rate)
	else:
		_time_until_next_shot = maxf(0.0, _time_until_next_shot - delta)


func _get_effective_fire_rate() -> float:
	var rate: float = GlobalState.get_stat("attack_speed", _base_fire_rate)
	# Kinetic Resonance: Ballistic Swarm (+35% Attack Speed for Pulse Turrets)
	if Arena.is_kinetic_resonance_active() and not (self is CryoTurret or self is PlasmaMortar or self is ChainTurret or self is RailgunTurret):
		rate *= 1.35
	return rate


## Execute an attack against the targeted enemy. Calculates damage dynamically.
func fire_at(target: EnemyBase) -> void:
	if not is_instance_valid(target) or target.is_dead:
		return
	
	EventBus.tower_fired.emit(self, target)
	_show_attack_visual(target.global_position)
	
	# Dynamically calculate damage so perks apply instantly
	var effective_damage: float = GlobalState.get_stat("tower_damage", _base_damage)
	target.take_damage(effective_damage, false, Color("#E2F1FF"))
	
	# Kinetic Resonance: Ballistic Swarm (+20% Armor Shred for 3.0s)
	if Arena.is_kinetic_resonance_active() and not (self is CryoTurret or self is PlasmaMortar or self is ChainTurret or self is RailgunTurret):
		target.armor_shred_timer = maxf(target.armor_shred_timer, 3.0)


## Alias for fire_at.
func shoot(target: EnemyBase) -> void:
	fire_at(target)


func _aim_at_target(delta: float) -> void:
	var target_pos: Vector2 = current_target.global_position
	var angle_to_target: float = (target_pos - global_position).angle()
	turret_head.rotation = lerp_angle(turret_head.rotation, angle_to_target, rotation_speed * delta)


func _update_target() -> void:
	if enemies_in_range.is_empty():
		current_target = null
		return
	
	match target_priority:
		TargetPriority.FIRST:
			var highest_progress: float = -1.0
			var chosen: EnemyBase = null
			for enemy: EnemyBase in enemies_in_range:
				if enemy.is_cloaked:
					continue
				if enemy.progress > highest_progress:
					highest_progress = enemy.progress
					chosen = enemy
			current_target = chosen
			
		TargetPriority.CLOSEST:
			var shortest_dist_sq: float = INF
			var chosen: EnemyBase = null
			for enemy: EnemyBase in enemies_in_range:
				if enemy.is_cloaked:
					continue
				var dist_sq: float = global_position.distance_squared_to(enemy.global_position)
				if dist_sq < shortest_dist_sq:
					shortest_dist_sq = dist_sq
					chosen = enemy
			current_target = chosen
			
		TargetPriority.STRONGEST:
			var highest_hp: float = -1.0
			var chosen: EnemyBase = null
			for enemy: EnemyBase in enemies_in_range:
				if enemy.is_cloaked:
					continue
				if enemy.current_hp > highest_hp:
					highest_hp = enemy.current_hp
					chosen = enemy
			current_target = chosen
			
		TargetPriority.WEAKEST:
			var lowest_hp: float = INF
			var chosen: EnemyBase = null
			for enemy: EnemyBase in enemies_in_range:
				if enemy.is_cloaked:
					continue
				if enemy.current_hp < lowest_hp:
					lowest_hp = enemy.current_hp
					chosen = enemy
			current_target = chosen
			
		TargetPriority.LAST:
			var lowest_progress: float = INF
			var chosen: EnemyBase = null
			for enemy: EnemyBase in enemies_in_range:
				if enemy.is_cloaked:
					continue
				if enemy.progress < lowest_progress:
					lowest_progress = enemy.progress
					chosen = enemy
			current_target = chosen


func _clean_invalid_enemies() -> void:
	var valid_enemies: Array[EnemyBase] = []
	for enemy: EnemyBase in enemies_in_range:
		if is_instance_valid(enemy) and not enemy.is_dead and not enemy.is_queued_for_deletion():
			valid_enemies.append(enemy)
	enemies_in_range = valid_enemies
	if current_target and (not is_instance_valid(current_target) or current_target.is_dead or current_target.is_cloaked):
		current_target = null


func _update_range_shape() -> void:
	if range_collision and range_collision.shape is CircleShape2D:
		(range_collision.shape as CircleShape2D).radius = attack_range


func _show_attack_visual(target_position: Vector2) -> void:
	if not laser_beam or not muzzle:
		return
	
	laser_beam.clear_points()
	laser_beam.add_point(muzzle.global_position)
	laser_beam.add_point(target_position)
	laser_beam.visible = true
	
	if tier == 5:
		laser_beam.width = 7.0
		laser_beam.modulate = Color(3.0, 2.0, 4.0, 1.0) # Master violet/white beam
	else:
		laser_beam.width = 3.0 + float(tier) * 0.6
		laser_beam.modulate = Color(1.8, 1.8, 2.0, 1.0)
	
	var tween: Tween = create_tween()
	tween.tween_property(laser_beam, "modulate:a", 0.0, 0.08)
	tween.tween_callback(func() -> void:
		if is_instance_valid(laser_beam):
			laser_beam.visible = false
	)


func _show_upgrade_effect() -> void:
	if tier == 5:
		modulate = Color(3.5, 3.0, 1.0, 1.0) # Golden Master flash
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.15)
		tween.parallel().tween_property(self, "modulate", Color(2.5, 2.5, 3.5, 1.0), 0.15)
		tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.25)
	else:
		modulate = Color(2.0, 2.0, 2.0, 1.0)
		var tween: Tween = create_tween()
		tween.tween_property(self, "modulate", Color.WHITE, 0.2)


func _on_perks_updated(_perks: Dictionary) -> void:
	refresh_stats()


func _on_range_area_entered(area: Area2D) -> void:
	var enemy: EnemyBase = area.get_parent() as EnemyBase
	if not enemy:
		enemy = area.owner as EnemyBase
	
	if enemy and not enemies_in_range.has(enemy):
		enemies_in_range.append(enemy)


func _on_target_entered(area: Area2D) -> void:
	_on_range_area_entered(area)


func _draw() -> void:
	if is_selected or is_hovered:
		# Draw translucent range fill and neon circle outline
		draw_circle(Vector2.ZERO, attack_range, Color(0.2, 0.7, 1.0, 0.08))
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 48, Color(0.4, 0.85, 1.0, 0.6), 1.5)


func set_selected(selected: bool) -> void:
	is_selected = selected
	queue_redraw()


func set_hovered(hovered: bool) -> void:
	is_hovered = hovered
	queue_redraw()


## Cycle through targeting modes: FIRST -> CLOSEST -> STRONGEST -> WEAKEST.
func cycle_target_priority() -> TargetPriority:
	match target_priority:
		TargetPriority.FIRST:
			target_priority = TargetPriority.CLOSEST
		TargetPriority.CLOSEST:
			target_priority = TargetPriority.STRONGEST
		TargetPriority.STRONGEST:
			target_priority = TargetPriority.WEAKEST
		TargetPriority.WEAKEST:
			target_priority = TargetPriority.FIRST
		_:
			target_priority = TargetPriority.FIRST
	return target_priority


## Get the string representation of the active targeting priority.
func get_target_priority_name() -> String:
	match target_priority:
		TargetPriority.FIRST: return "FIRST"
		TargetPriority.CLOSEST: return "CLOSEST"
		TargetPriority.STRONGEST: return "STRONGEST"
		TargetPriority.WEAKEST: return "WEAKEST"
	return "FIRST"


func _on_range_area_exited(area: Area2D) -> void:
	var enemy: EnemyBase = area.get_parent() as EnemyBase
	if not enemy:
		enemy = area.owner as EnemyBase
	
	if enemy and enemies_in_range.has(enemy):
		enemies_in_range.erase(enemy)
