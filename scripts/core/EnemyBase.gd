class_name EnemyBase
extends PathFollow2D

## Base class for all enemies in Perimeta. Follows a Path2D, manages HP, status effects, elemental reactions, damage numbers, and interacts with EventBus.

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")
const DEATH_SPARKS_SCENE: PackedScene = preload("res://scenes/combat/DeathSparks.tscn")

@export var enemy_name: String = "Swarmer"
@export var max_hp: float = 45.0
@export var move_speed: float = 120.0
@export var core_damage: float = 10.0
@export var bounty: int = 15
@export var primary_color: Color = Color(1.0, 0.28, 0.38, 1.0)

var current_hp: float = 45.0
var is_dead: bool = false
var is_shielded: bool = false
var is_cloaked: bool = false
var speed_multiplier: float = 1.0
var slow_timer: float = 0.0

# Elemental Afflictions & Reaction Status
var elemental_status: Dictionary = {
	"cryo": 0.0,
	"pyro": 0.0,
	"electro": 0.0
}
var armor_shred_timer: float = 0.0
var stun_timer: float = 0.0

@onready var hitbox_area: Area2D = $HitboxArea
@onready var visual_node: Node2D = $Visual
@onready var health_bar_fill: ColorRect = $HealthBar/HealthBarFill


func _ready() -> void:
	add_to_group("enemies")
	current_hp = max_hp
	loop = false
	rotates = true
	_update_health_bar()
	EventBus.enemy_spawned.emit(self)


func _process(delta: float) -> void:
	if is_dead:
		return
	
	# Handle elemental status decay
	for elem: String in elemental_status:
		if elemental_status[elem] > 0.0:
			elemental_status[elem] = maxf(0.0, elemental_status[elem] - delta)
			
	# Handle armor shred timer
	if armor_shred_timer > 0.0:
		armor_shred_timer = maxf(0.0, armor_shred_timer - delta)
	
	# Handle movement & stun status
	if stun_timer > 0.0:
		stun_timer = maxf(0.0, stun_timer - delta)
		speed_multiplier = 0.0
	elif slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			speed_multiplier = 1.0
	else:
		speed_multiplier = 1.0
	
	_update_status_visuals()
	
	progress += move_speed * speed_multiplier * delta
	
	# When reaching the absolute end of the track, strike the core
	if progress_ratio >= 0.995:
		reach_perimeter()


func _update_status_visuals() -> void:
	if not visual_node:
		return
	
	if armor_shred_timer > 0.0:
		visual_node.modulate = Color(1.4, 0.7, 2.0, 1.0) # Violet armor-shred tint
	elif elemental_status["cryo"] > 0.0 or slow_timer > 0.0:
		visual_node.modulate = Color(0.4, 0.8, 2.2, 1.0) # Icy cyan tint
	elif elemental_status["pyro"] > 0.0:
		visual_node.modulate = Color(2.0, 0.6, 0.2, 1.0) # Burning orange tint
	elif elemental_status["electro"] > 0.0:
		visual_node.modulate = Color(1.5, 0.6, 2.2, 1.0) # Electric magenta tint
	else:
		visual_node.modulate = Color.WHITE


## Apply status slow effect factoring in meta perks.
func apply_slow(factor: float, base_duration: float = 2.0) -> void:
	if is_dead:
		return
	var duration: float = GlobalState.get_stat("freeze_duration", base_duration)
	speed_multiplier = factor
	slow_timer = duration
	elemental_status["cryo"] = maxf(elemental_status["cryo"], duration)


## Apply elemental status and check for Genshin-style Elemental Reactions.
func apply_element(element: String, duration: float = 3.0, source_damage: float = 0.0) -> void:
	if is_dead:
		return
	
	var reaction_mult: float = GlobalState.get_stat("elemental_reaction_damage", 1.0)
	
	match element:
		"cryo":
			if elemental_status["electro"] > 0.0:
				_trigger_superconduct(reaction_mult)
			elif elemental_status["pyro"] > 0.0:
				_trigger_melt(source_damage, reaction_mult)
			else:
				elemental_status["cryo"] = duration
				
		"pyro":
			if elemental_status["cryo"] > 0.0 or slow_timer > 0.0:
				_trigger_melt(source_damage, reaction_mult)
			elif elemental_status["electro"] > 0.0:
				_trigger_overload(reaction_mult)
			else:
				elemental_status["pyro"] = duration
				
		"electro":
			if elemental_status["cryo"] > 0.0 or slow_timer > 0.0:
				_trigger_superconduct(reaction_mult)
			elif elemental_status["pyro"] > 0.0:
				_trigger_overload(reaction_mult)
			else:
				elemental_status["electro"] = duration


## SUPERCONDUCT (Cryo + Electro): 150 AoE damage in 120px radius + 40% Armor Shred for 4.0s.
func _trigger_superconduct(reaction_mult: float) -> void:
	elemental_status["cryo"] = 0.0
	elemental_status["electro"] = 0.0
	slow_timer = 0.0
	armor_shred_timer = 4.0
	
	var base_sc_dmg: float = 150.0 * reaction_mult
	_trigger_elemental_aoe(120.0, base_sc_dmg, Color("#A26CF8"))
	var sc_text: String = LocalizationManager.get_text("REACTION_SUPERCONDUCT", "[SUPERCONDUCT !]") if LocalizationManager else "[SUPERCONDUCT !]"
	_spawn_reaction_text(sc_text, Color("#A26CF8"))
	AudioManager.play_sound(AudioManager.snd_laser, 0.05, 1.5)


## MELT (Cryo + Pyro): Massive 2.5x Critical Burst damage instantly.
func _trigger_melt(source_damage: float, reaction_mult: float) -> void:
	elemental_status["cryo"] = 0.0
	elemental_status["pyro"] = 0.0
	slow_timer = 0.0
	
	var melt_dmg: float = maxf(source_damage, 65.0) * 2.5 * reaction_mult
	take_damage(melt_dmg, true, Color("#FF6B2B"))
	var melt_text: String = LocalizationManager.get_text("REACTION_MELT", "[MELT !]") if LocalizationManager else "[MELT !]"
	_spawn_reaction_text(melt_text, Color("#FF6B2B"))
	AudioManager.play_sound(AudioManager.snd_hit, 0.05, 1.2)


## OVERLOAD (Pyro + Electro): Concussive AoE damage in 140px + 1.2s Stun & Knockback.
func _trigger_overload(reaction_mult: float) -> void:
	elemental_status["pyro"] = 0.0
	elemental_status["electro"] = 0.0
	
	var base_ol_dmg: float = 120.0 * reaction_mult
	_trigger_elemental_aoe(140.0, base_ol_dmg, Color("#FF007F"))
	
	if not (self is BossEnemy or self is GoliathEnemy):
		stun_timer = 1.2
		progress = maxf(0.0, progress - 35.0)
		
	var ol_text: String = LocalizationManager.get_text("REACTION_OVERLOAD", "[OVERLOAD !]") if LocalizationManager else "[OVERLOAD !]"
	_spawn_reaction_text(ol_text, Color("#FF007F"))
	AudioManager.play_sound(AudioManager.snd_boss_spawn, 0.05, 0.5)
	
	var tree: SceneTree = get_tree()
	if tree and tree.current_scene and tree.current_scene.has_method("trigger_shake"):
		tree.current_scene.call("trigger_shake", 6.0, 0.15)


func _trigger_elemental_aoe(radius: float, dmg: float, fx_color: Color) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	# Expanding shockwave visual
	var shockwave: Line2D = Line2D.new()
	shockwave.top_level = true
	shockwave.global_position = global_position
	shockwave.width = 3.5
	shockwave.default_color = fx_color
	for i in range(20 + 1):
		var ang: float = (float(i) / 20.0) * TAU
		shockwave.add_point(Vector2(cos(ang), sin(ang)) * 6.0)
	tree.root.add_child(shockwave)
	
	var tween: Tween = create_tween()
	if tween:
		tween.tween_property(shockwave, "scale", Vector2(radius / 6.0, radius / 6.0), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shockwave, "modulate:a", 0.0, 0.18)
		tween.chain().tween_callback(func() -> void:
			if is_instance_valid(shockwave):
				shockwave.queue_free()
		)
	
	# Fallback fail-safe timer
	tree.create_timer(0.35, false).timeout.connect(func() -> void:
		if is_instance_valid(shockwave):
			shockwave.queue_free()
	)
	
	# Damage nearby enemies
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	var r_sq: float = radius * radius
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if not enemy.is_dead and global_position.distance_squared_to(enemy.global_position) <= r_sq:
				enemy.take_damage(dmg, true, fx_color)


func _spawn_reaction_text(text_str: String, color: Color) -> void:
	if not DAMAGE_NUMBER_SCENE:
		return
	var dmg_inst: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	if not dmg_inst:
		return
	var target_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	target_parent.add_child(dmg_inst)
	dmg_inst.global_position = global_position + Vector2(0, -28)
	dmg_inst.setup_text(text_str, color, true)


## Apply damage to this enemy, trigger damage popups, and check death.
func take_damage(amount: float, is_crit: bool = false, color_override: Color = Color("#E2F1FF")) -> void:
	if is_dead:
		return
	
	var final_amount: float = amount
	
	# Anti-Spawn Camping Grace: 80% damage reduction for first 0.5s off the gate
	if progress_ratio < 0.04:
		final_amount *= 0.20
		
	# Armor Rating: Breachers and Goliaths reduce incoming non-crit kinetic damage by flat 25%
	if (self is BreacherEnemy or self is GoliathEnemy) and not is_crit and color_override == Color("#E2F1FF"):
		final_amount *= 0.75
		
	if is_shielded:
		final_amount *= 0.50 # 50% damage mitigation from Shield Drone aura
	if slow_timer > 0.0:
		var slow_bonus: float = GlobalState.get_stat("slow_damage_mult", 0.0)
		if slow_bonus > 0.0:
			final_amount *= (1.0 + slow_bonus)
	if armor_shred_timer > 0.0:
		final_amount *= 1.40 # 40% increased damage from Superconduct / Armor Shred
	
	current_hp = maxf(0.0, current_hp - final_amount)
	_update_health_bar()
	_flash_hit()
	_spawn_damage_number(final_amount, is_crit, color_override)
	
	EventBus.enemy_damaged.emit(self, final_amount, current_hp)
	
	if current_hp <= 0.0:
		die()


func _spawn_damage_number(amount: float, is_crit: bool, color_override: Color) -> void:
	if not DAMAGE_NUMBER_SCENE:
		return
	
	var dmg_inst: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	if not dmg_inst:
		return
	
	dmg_inst.global_position = global_position + Vector2(randf_range(-10.0, 10.0), -20.0)
	var target_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	target_parent.add_child(dmg_inst)
	dmg_inst.setup(amount, color_override, is_crit)


## Handle enemy death and reward bounty.
func die() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Cryo Resonance: Permafrost ice shrapnel shatter on death
	if (elemental_status["cryo"] > 0.0 or slow_timer > 0.0) and Arena.is_cryo_resonance_active():
		_trigger_cryo_shatter()
	
	_spawn_death_sparks()
	EventBus.enemy_died.emit(self, bounty)
	queue_free()


func _trigger_cryo_shatter() -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	var r_sq: float = 65.0 * 65.0
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if enemy != self and not enemy.is_dead and global_position.distance_squared_to(enemy.global_position) <= r_sq:
				enemy.take_damage(40.0, false, Color("#64D2FF"))
				enemy.apply_element("cryo", 2.5, 40.0)


func _spawn_death_sparks() -> void:
	if not DEATH_SPARKS_SCENE:
		return
	
	var sparks: DeathSparks = DEATH_SPARKS_SCENE.instantiate() as DeathSparks
	if not sparks:
		return
	
	var target_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
	target_parent.add_child(sparks)
	sparks.global_position = global_position
	sparks.trigger(primary_color)


## Trigger core breach when enemy finishes the path.
func reach_core() -> void:
	if is_dead:
		return
	is_dead = true
	
	# Thermal Insulator perk: Core reactive discharge
	var insulator_lvl: int = GlobalState.get_perk_level("thermal_insulator")
	if insulator_lvl > 0:
		_trigger_core_reactive_discharge(insulator_lvl)
		
	EventBus.enemy_reached_core.emit(self, core_damage)
	queue_free()


func _trigger_core_reactive_discharge(insulator_lvl: int) -> void:
	var tree: SceneTree = get_tree()
	if not tree:
		return
	
	var shock_dmg: float = 50.0 * float(insulator_lvl)
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	for node: Node in enemies:
		if node is EnemyBase and is_instance_valid(node) and not node.is_queued_for_deletion():
			var enemy: EnemyBase = node as EnemyBase
			if not enemy.is_dead and global_position.distance_to(enemy.global_position) <= 260.0:
				enemy.take_damage(shock_dmg, true, Color("#FF6B2B"))
				enemy.apply_element("pyro", 3.0, shock_dmg)
				enemy.apply_element("electro", 3.0, shock_dmg)


func reach_perimeter() -> void:
	reach_core()


func _update_health_bar() -> void:
	if not health_bar_fill:
		return
	var health_percent: float = clampf(current_hp / max_hp, 0.0, 1.0)
	health_bar_fill.size.x = 32.0 * health_percent
	
	# Dynamic color shift from green to yellow to red
	if health_percent > 0.5:
		health_bar_fill.color = Color(0.2, 0.9, 0.4, 1.0)
	elif health_percent > 0.25:
		health_bar_fill.color = Color(1.0, 0.8, 0.2, 1.0)
	else:
		health_bar_fill.color = Color(1.0, 0.2, 0.3, 1.0)


func _flash_hit() -> void:
	if not visual_node:
		return
	visual_node.modulate = Color(2.5, 2.5, 2.5, 1.0) # Bright flash
	var tween: Tween = create_tween()
	tween.tween_interval(0.08)
	tween.tween_callback(_update_status_visuals)
