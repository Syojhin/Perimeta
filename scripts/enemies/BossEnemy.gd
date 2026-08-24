class_name BossEnemy
extends EnemyBase

## Formidable boss entity appearing on milestone waves with rotating geometric shells, a timed Phase Shield barrier, and Titan Reinforcements.

const SCOUT_SCENE: PackedScene = preload("res://scenes/enemies/variants/ScoutEnemy.tscn")
const SHIELD_SCENE: PackedScene = preload("res://scenes/enemies/variants/ShieldEnemy.tscn")

@export var phase_shield_cooldown: float = 6.0
@export var phase_shield_duration: float = 2.0
@export var shield_damage_reduction: float = 0.70

var phase_shield_active: bool = false
var _shield_cooldown_timer: float = 4.0
var _shield_active_timer: float = 0.0
var _has_emitted_defeated: bool = false
var _has_spawned_reinforcements: bool = false

@onready var outer_shell: Polygon2D = $Visual/OuterShell
@onready var inner_core: Polygon2D = $Visual/InnerCore
@onready var shield_barrier: Line2D = $Visual/ShieldBarrier


func _ready() -> void:
	enemy_name = "Titan Core"
	var wave_tier: int = maxi(1, int(floorf(float(GlobalState.current_wave) / 5.0)))
	var tier_mult: float = pow(1.4, float(wave_tier - 1))
	max_hp = 2500.0 * tier_mult
	current_hp = max_hp
	move_speed = 36.0
	core_damage = 45.0
	bounty = int(350.0 * tier_mult)
	primary_color = Color(1.0, 0.22, 0.45, 1.0)
	
	add_to_group("enemies")
	super._ready()
	
	if shield_barrier:
		shield_barrier.visible = false
	
	EventBus.boss_spawned.emit(self)
	EventBus.boss_damaged.emit(current_hp, max_hp, false)


func _process(delta: float) -> void:
	if is_dead:
		return
	
	super._process(delta)
	
	# Visual geometric rotation
	if outer_shell:
		outer_shell.rotation += 1.2 * delta
	if inner_core:
		inner_core.rotation -= 2.2 * delta
	
	# Phase shield lifecycle
	if phase_shield_active:
		_shield_active_timer -= delta
		if shield_barrier:
			var pulse: float = 1.0 + 0.08 * sin(Time.get_ticks_msec() * 0.015)
			shield_barrier.scale = Vector2(pulse, pulse)
		
		if _shield_active_timer <= 0.0:
			phase_shield_active = false
			_shield_cooldown_timer = phase_shield_cooldown
			if shield_barrier:
				shield_barrier.visible = false
			EventBus.boss_damaged.emit(current_hp, max_hp, false)
	else:
		_shield_cooldown_timer -= delta
		if _shield_cooldown_timer <= 0.0:
			phase_shield_active = true
			_shield_active_timer = phase_shield_duration
			if shield_barrier:
				shield_barrier.visible = true
			EventBus.boss_damaged.emit(current_hp, max_hp, true)


func take_damage(amount: float, is_crit: bool = false, color_override: Color = Color("#E2F1FF")) -> void:
	if is_dead:
		return
	
	var final_damage: float = amount
	var final_color: Color = color_override
	
	# Mitigate damage if phase shield is active
	if phase_shield_active:
		final_damage *= (1.0 - shield_damage_reduction)
		final_color = Color(0.4, 0.9, 1.0, 1.0) # Deflected cyan
	
	super.take_damage(final_damage, is_crit, final_color)
	EventBus.boss_damaged.emit(current_hp, max_hp, phase_shield_active)
	
	# Titan Reinforcements threshold at 50% HP
	if not _has_spawned_reinforcements and current_hp <= (max_hp * 0.5):
		_has_spawned_reinforcements = true
		_spawn_titan_reinforcements()


func _spawn_titan_reinforcements() -> void:
	var path_parent: Node = get_parent()
	if not path_parent:
		return
	
	var current_prog: float = progress
	
	# Spawn 2 Scouts and 2 Shielders
	for i in range(2):
		if SCOUT_SCENE:
			var scout: ScoutEnemy = SCOUT_SCENE.instantiate() as ScoutEnemy
			if scout:
				path_parent.add_child(scout)
				scout.progress = maxf(0.0, current_prog - 40.0 - (i * 30.0))
		
		if SHIELD_SCENE:
			var shielder: ShieldEnemy = SHIELD_SCENE.instantiate() as ShieldEnemy
			if shielder:
				path_parent.add_child(shielder)
				shielder.progress = maxf(0.0, current_prog - 25.0 - (i * 30.0))


func die() -> void:
	if is_dead:
		return
	
	if not _has_emitted_defeated:
		_has_emitted_defeated = true
		# Award +5 Meta-Cores directly
		GlobalState.meta_cores += 5
		EventBus.boss_defeated.emit(self)
	
	super.die()


func reach_core() -> void:
	if is_dead:
		return
	
	if not _has_emitted_defeated:
		_has_emitted_defeated = true
		EventBus.boss_defeated.emit(self)
	
	super.reach_core()


func reach_perimeter() -> void:
	reach_core()


func _exit_tree() -> void:
	if not _has_emitted_defeated:
		_has_emitted_defeated = true
		EventBus.boss_defeated.emit(self)
