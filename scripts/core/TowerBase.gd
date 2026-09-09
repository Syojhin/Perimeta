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

@export var tower_data: TowerData = null:
	set(value):
		tower_data = value
		if tower_data:
			_apply_tower_data()

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

# Prestige Level (P1 - P20)
var prestige_level: int = 0
const MAX_PRESTIGE_LEVEL: int = 20
var armor_pierce: float = 0.0
var prestige_stats: Dictionary = {}

var _base_range: float = 220.0
var _base_fire_rate: float = 5.555
var _base_damage: float = 15.0
var _t5_base_damage: float = 0.0
var _t5_base_fire_rate: float = 0.0
var _t5_base_range: float = 0.0

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

# Modular Visual Tier Nodes
@onready var chassis_base: Node2D = get_node_or_null("TurretHead/ChassisBase")
@onready var fins_stabilizers: Node2D = get_node_or_null("TurretHead/FinsStabilizers")
@onready var accelerator_array: Node2D = get_node_or_null("TurretHead/AcceleratorArray")
@onready var heat_vent_glow: Node2D = get_node_or_null("TurretHead/HeatVentGlow")
@onready var apex_crown: Node2D = get_node_or_null("TurretHead/ApexCrown")
@onready var prestige_ascended_mesh: Node2D = get_node_or_null("TurretHead/PrestigeAscendedMesh")
@onready var prestige_badge: Label = get_node_or_null("BaseVisual/PrestigeBadge")


func _ready() -> void:
	if tower_data:
		_apply_tower_data()
	else:
		_base_range = attack_range
		_base_fire_rate = fire_rate
		_base_damage = damage
		total_invested_bits = cost
	
	refresh_stats()
	_ensure_modular_visual_nodes()
	set_visual_tier(tier)
	EventBus.perks_updated.connect(_on_perks_updated)
	
	range_area.area_entered.connect(_on_range_area_entered)
	range_area.area_exited.connect(_on_range_area_exited)
	
	if laser_beam:
		laser_beam.visible = false
		laser_beam.top_level = true # Draw in global coordinates for laser lines
	
	EventBus.tower_placed.emit(self)


## Initialize baseline stats and pricing from an injected TowerData resource.
func _apply_tower_data() -> void:
	if not tower_data:
		return
	tower_name = tower_data.display_name
	cost = tower_data.base_cost
	damage = tower_data.base_damage
	fire_rate = tower_data.base_fire_rate
	attack_range = tower_data.base_range
	_base_range = attack_range
	_base_fire_rate = fire_rate
	_base_damage = damage
	total_invested_bits = cost
	_update_range_shape()


## Refresh effective stats from GlobalState meta perks.
func refresh_stats() -> void:
	attack_range = GlobalState.get_stat("tower_range", _base_range)
	fire_rate = GlobalState.get_stat("attack_speed", _base_fire_rate)
	damage = GlobalState.get_stat("tower_damage", _base_damage)
	_update_range_shape()


## Calculate the upgrade cost for the next tier or next Prestige rank.
func get_upgrade_cost() -> int:
	if tier >= max_tier:
		if prestige_level < MAX_PRESTIGE_LEVEL:
			return get_prestige_cost()
		return get_infusion_cost()
	if tower_data and not tower_data.tier_upgrades.is_empty():
		for up_entry: Dictionary in tower_data.tier_upgrades:
			if int(up_entry.get("tier", 0)) == tier + 1:
				return int(up_entry.get("cost", 0))
	match tier:
		1: return 150
		2: return 350
		3: return 800
		4: return 2000
	return 0


## Calculate in-run Prestige ascension cost for the next rank (1 to 20).
func get_prestige_cost() -> int:
	if prestige_level >= MAX_PRESTIGE_LEVEL:
		return 0
	if tower_data:
		return tower_data.get_prestige_cost(prestige_level + 1)
	return int(round((1000.0 + float(prestige_level + 1) * 500.0)))


## Calculate Overclock Infusion cost for infinite late-game Bit sink.
func get_infusion_cost() -> int:
	return 1000 + (infusion_level * 1500)


## Calculate the sell refund value (70% of total invested bits).
func get_sell_refund() -> int:
	return int(total_invested_bits * 0.70)


## Upgrade this tower to the next tier, or perform In-Run Prestige Ascension if at Tier 5.
func upgrade() -> bool:
	if tier >= max_tier:
		if prestige_level < MAX_PRESTIGE_LEVEL:
			return ascend_prestige()
		return infuse_overclock()
	
	var up_cost: int = get_upgrade_cost()
	if not GlobalState.spend_currency(up_cost):
		return false
	
	total_invested_bits += up_cost
	tier += 1
	
	var dmg_mult: float = 1.35
	var rng_mult: float = 1.15
	var matched_custom_upgrade: bool = false
	if tower_data and not tower_data.tier_upgrades.is_empty():
		for up_entry: Dictionary in tower_data.tier_upgrades:
			if int(up_entry.get("tier", 0)) == tier:
				dmg_mult = float(up_entry.get("damage_mult", 1.35))
				rng_mult = float(up_entry.get("range_mult", 1.15))
				matched_custom_upgrade = true
				break
	
	if not matched_custom_upgrade and tier == 5:
		# Tier 5 Master
		_base_damage *= 2.0
		_base_range *= 1.30
	else:
		_base_damage *= dmg_mult
		_base_range *= rng_mult
		
	if tier == 5:
		_t5_base_damage = _base_damage
		_t5_base_fire_rate = _base_fire_rate
		_t5_base_range = _base_range
		
	refresh_stats()
	set_visual_tier(tier)
	_show_upgrade_effect()
	EventBus.tower_upgraded.emit(self)
	return true


## Ascend this Tier 5 Master tower to the next Prestige rank (P1 to P20).
func ascend_prestige() -> bool:
	if tier < 5 or prestige_level >= MAX_PRESTIGE_LEVEL:
		return false
		
	var cost_req: int = get_prestige_cost()
	if not GlobalState.spend_currency(cost_req):
		return false
		
	total_invested_bits += cost_req
	prestige_level += 1
	
	_apply_prestige_stats()
	set_visual_tier(tier)
	
	# Spawn shockwave ring via NodePool
	var pool: Node = get_node_or_null("/root/NodePool") if is_inside_tree() else null
	if pool and pool.has_method("spawn_shockwave"):
		pool.call("spawn_shockwave", global_position, 120.0, Color(1.0, 0.84, 0.0, 0.9), 0.35)
		
	# Trigger ascending SFX drop
	var audio: Node = get_node_or_null("/root/AudioManager") if is_inside_tree() else null
	if audio and audio.has_method("play_prestige_ascension_sfx"):
		audio.call("play_prestige_ascension_sfx")
		
	_show_upgrade_effect()
	EventBus.tower_upgraded.emit(self)
	return true


func _apply_prestige_stats() -> void:
	if prestige_level <= 0:
		return
		
	var stats: Dictionary = {}
	if tower_data:
		stats = tower_data.get_prestige_stats(prestige_level)
	else:
		stats = TowerData.calculate_prestige_stats(prestige_level)
		
	prestige_stats = stats
	armor_pierce = float(stats.get("armor_pierce", 0.0))
	
	if _t5_base_damage <= 0.0:
		_t5_base_damage = _base_damage
		_t5_base_fire_rate = _base_fire_rate
		_t5_base_range = _base_range
		
	_base_damage = _t5_base_damage * float(stats.get("damage_mult", 1.0))
	_base_fire_rate = _t5_base_fire_rate * float(stats.get("attack_speed_mult", 1.0))
	_base_range = _t5_base_range * float(stats.get("range_mult", 1.0))
	
	refresh_stats()


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
	if turret_head and is_instance_valid(turret_head):
		var tier_scale: float = 1.0 + (float(tier - 1) * 0.08)
		turret_head.scale = Vector2(tier_scale, tier_scale)
		
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


## Static helper resolving integers 1-20 to Roman numerals.
static func get_roman_numeral(n: int) -> String:
	var numerals: Dictionary = {
		20: "XX", 19: "XIX", 18: "XVIII", 17: "XVII", 16: "XVI",
		15: "XV", 14: "XIV", 13: "XIII", 12: "XII", 11: "XI",
		10: "X", 9: "IX", 8: "VIII", 7: "VII", 6: "VI",
		5: "V", 4: "IV", 3: "III", 2: "II", 1: "I"
	}
	return numerals.get(n, str(n))


## Updates visibility of modular visual components across Tiers 1-5 and Prestige 1-20.
func set_visual_tier(p_tier: int) -> void:
	_ensure_modular_visual_nodes()
	
	if fins_stabilizers:
		fins_stabilizers.visible = (p_tier >= 2)
	if accelerator_array:
		accelerator_array.visible = (p_tier >= 3)
	if heat_vent_glow:
		heat_vent_glow.visible = (p_tier >= 4)
	if apex_crown:
		apex_crown.visible = (p_tier >= 5)
	if prestige_ascended_mesh:
		prestige_ascended_mesh.visible = (prestige_level >= 1)
		
	_update_prestige_badge()
	_update_prestige_shader()
	
	# Momentary neon flash tween on upgrade
	if turret_head and is_inside_tree():
		var tw: Tween = create_tween()
		turret_head.modulate = Color(2.5, 2.5, 3.0, 1.0)
		tw.tween_property(turret_head, "modulate", Color.WHITE, 0.25)


func _update_prestige_badge() -> void:
	if not prestige_badge:
		prestige_badge = get_node_or_null("BaseVisual/PrestigeBadge")
	if prestige_badge:
		if prestige_level >= 1:
			prestige_badge.visible = true
			prestige_badge.text = "P-%s" % get_roman_numeral(prestige_level)
		else:
			prestige_badge.visible = false


func _update_prestige_shader() -> void:
	if not turret_head:
		return
	if not (turret_head.material is ShaderMaterial):
		var mat: ShaderMaterial = ShaderMaterial.new()
		var s: Shader = load("res://shaders/turret_prestige.gdshader") as Shader
		if s:
			mat.shader = s
			turret_head.material = mat
			
	var shader_mat: ShaderMaterial = turret_head.material as ShaderMaterial
	if shader_mat:
		var intensity: float = clampf(float(prestige_level) / 20.0, 0.0, 1.0)
		shader_mat.set_shader_parameter("prestige_intensity", intensity)


func _ensure_modular_visual_nodes() -> void:
	if not turret_head:
		turret_head = get_node_or_null("TurretHead")
		if not turret_head:
			turret_head = Node2D.new()
			turret_head.name = "TurretHead"
			add_child(turret_head)
			
	if not chassis_base:
		chassis_base = turret_head.get_node_or_null("ChassisBase")
		if not chassis_base:
			chassis_base = Node2D.new()
			chassis_base.name = "ChassisBase"
			turret_head.add_child(chassis_base)
			var barrel: Node = turret_head.get_node_or_null("Barrel")
			if barrel:
				barrel.reparent(chassis_base)
			var cap: Node = turret_head.get_node_or_null("CenterCap")
			if cap:
				cap.reparent(chassis_base)
				
	if not fins_stabilizers:
		fins_stabilizers = turret_head.get_node_or_null("FinsStabilizers")
		if not fins_stabilizers:
			fins_stabilizers = Node2D.new()
			fins_stabilizers.name = "FinsStabilizers"
			var fin_l: Polygon2D = Polygon2D.new()
			fin_l.color = Color(0.15, 0.5, 0.75, 0.9)
			fin_l.polygon = PackedVector2Array([-6, -8, -16, -15, -12, -5])
			fins_stabilizers.add_child(fin_l)
			var fin_r: Polygon2D = Polygon2D.new()
			fin_r.color = Color(0.15, 0.5, 0.75, 0.9)
			fin_r.polygon = PackedVector2Array([-6, 8, -16, 15, -12, 5])
			fins_stabilizers.add_child(fin_r)
			turret_head.add_child(fins_stabilizers)
			
	if not accelerator_array:
		accelerator_array = turret_head.get_node_or_null("AcceleratorArray")
		if not accelerator_array:
			accelerator_array = Node2D.new()
			accelerator_array.name = "AcceleratorArray"
			var r_top: Polygon2D = Polygon2D.new()
			r_top.color = Color(0.4, 0.9, 1.0, 1.0)
			r_top.polygon = PackedVector2Array([6, -7, 22, -6, 22, -4, 6, -5])
			accelerator_array.add_child(r_top)
			var r_bot: Polygon2D = Polygon2D.new()
			r_bot.color = Color(0.4, 0.9, 1.0, 1.0)
			r_bot.polygon = PackedVector2Array([6, 5, 22, 4, 22, 6, 6, 7])
			accelerator_array.add_child(r_bot)
			turret_head.add_child(accelerator_array)
			
	if not heat_vent_glow:
		heat_vent_glow = turret_head.get_node_or_null("HeatVentGlow")
		if not heat_vent_glow:
			heat_vent_glow = Node2D.new()
			heat_vent_glow.name = "HeatVentGlow"
			var vent: Polygon2D = Polygon2D.new()
			vent.color = Color(1.0, 0.45, 0.1, 0.85)
			vent.polygon = PackedVector2Array([-5, -5, 3, -5, 3, 5, -5, 5])
			heat_vent_glow.add_child(vent)
			turret_head.add_child(heat_vent_glow)
			
	if not apex_crown:
		apex_crown = turret_head.get_node_or_null("ApexCrown")
		if not apex_crown:
			apex_crown = Node2D.new()
			apex_crown.name = "ApexCrown"
			var cr: Polygon2D = Polygon2D.new()
			cr.color = Color(1.0, 0.85, 0.2, 1.0)
			cr.polygon = PackedVector2Array([-6, -11, 0, -16, 6, -11, 4, -7, -4, -7])
			apex_crown.add_child(cr)
			turret_head.add_child(apex_crown)
			
	if not prestige_ascended_mesh:
		prestige_ascended_mesh = turret_head.get_node_or_null("PrestigeAscendedMesh")
		if not prestige_ascended_mesh:
			prestige_ascended_mesh = Node2D.new()
			prestige_ascended_mesh.name = "PrestigeAscendedMesh"
			var ring: Line2D = Line2D.new()
			ring.points = PackedVector2Array([-14, 0, 0, -14, 14, 0, 0, 14, -14, 0])
			ring.width = 1.8
			ring.default_color = Color(1.0, 0.84, 0.0, 0.85)
			prestige_ascended_mesh.add_child(ring)
			turret_head.add_child(prestige_ascended_mesh)
			
	if not prestige_badge:
		prestige_badge = get_node_or_null("BaseVisual/PrestigeBadge")
		if not prestige_badge:
			var base_vis: Node2D = get_node_or_null("BaseVisual")
			if not base_vis:
				base_vis = self
			prestige_badge = Label.new()
			prestige_badge.name = "PrestigeBadge"
			prestige_badge.visible = false
			prestige_badge.offset_left = -24.0
			prestige_badge.offset_top = 13.0
			prestige_badge.offset_right = 24.0
			prestige_badge.offset_bottom = 27.0
			prestige_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			prestige_badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			prestige_badge.add_theme_color_override("font_color", Color(1.0, 0.84, 0.0, 1.0))
			prestige_badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
			prestige_badge.add_theme_constant_override("shadow_offset_y", 1)
			prestige_badge.add_theme_font_size_override("font_size", 9)
			base_vis.add_child(prestige_badge)
