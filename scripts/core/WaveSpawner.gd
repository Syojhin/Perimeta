class_name WaveSpawner
extends Node2D

## Dynamic multi-vector wave lifecycle and enemy spawning controller for combat arenas.
## Manages 4-quadrant entrance lanes, 5 enemy archetypes, milestone Bosses, In-Run Drafts, Wave 25 Victory, and Endless Overclock mode.

const BOSS_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/variants/BossEnemy.tscn")
const SCOUT_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/variants/ScoutEnemy.tscn")
const SHIELD_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/variants/ShieldEnemy.tscn")
const BREACHER_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/variants/BreacherEnemy.tscn")
const GOLIATH_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/variants/GoliathEnemy.tscn")
const PHASE_ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/variants/PhaseInfiltrator.tscn")

@export var enemy_scene: PackedScene = preload("res://scenes/enemies/EnemyBase.tscn")
@export var path_north: Path2D
@export var path_south: Path2D
@export var path_east: Path2D
@export var path_west: Path2D
@export var target_path: Path2D # Fallback path reference

@export var time_between_waves: float = 4.0
@export var spawn_interval: float = 0.65
@export var auto_start: bool = true

var current_wave: int = 0
var enemies_remaining_to_spawn: int = 0
var active_enemies: int = 0
var is_spawning: bool = false
var is_boss_wave: bool = false
var is_endless_mode: bool = false

var _wave_break_timer: float = 0.0
var _spawn_timer: float = 0.0
var _spawn_index: int = 0
var _boss_spawned_this_wave: bool = false
var _draft_triggered_this_wave: bool = false


func _ready() -> void:
	if not EventBus.enemy_died.is_connected(_on_enemy_removed):
		EventBus.enemy_died.connect(_on_enemy_removed)
	if not EventBus.enemy_reached_core.is_connected(_on_enemy_removed):
		EventBus.enemy_reached_core.connect(_on_enemy_removed)
	if not EventBus.run_started.is_connected(_on_run_started):
		EventBus.run_started.connect(_on_run_started)
	if not EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.connect(_on_run_ended)
	if not EventBus.draft_completed.is_connected(_on_draft_completed):
		EventBus.draft_completed.connect(_on_draft_completed)
	
	if auto_start:
		_wave_break_timer = 2.0


func _process(delta: float) -> void:
	if not GlobalState.is_run_active and not auto_start:
		return
	
	# Handle between-wave intermission countdown
	if _wave_break_timer > 0.0:
		_wave_break_timer -= delta
		EventBus.wave_countdown_updated.emit(maxf(0.0, _wave_break_timer))
		if _wave_break_timer <= 0.0:
			start_next_wave()
		return
	
	# Handle active wave spawning
	if is_spawning and enemies_remaining_to_spawn > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_spawn_timer = spawn_interval if not is_boss_wave else spawn_interval * 1.3


## Returns active entrance lanes for the current wave tier.
func get_active_paths_for_wave(wave: int) -> Array[Path2D]:
	var paths: Array[Path2D] = []
	if is_instance_valid(path_north):
		paths.append(path_north)
	if wave >= 6 and is_instance_valid(path_south):
		paths.append(path_south)
	if wave >= 11 and is_instance_valid(path_east):
		paths.append(path_east)
	if wave >= 16 and is_instance_valid(path_west):
		paths.append(path_west)
		
	if paths.is_empty() and is_instance_valid(target_path):
		paths.append(target_path)
	return paths


## Initiate the next wave sequence and trigger perimeter breach alerts.
func start_next_wave() -> void:
	current_wave += 1
	GlobalState.current_wave = current_wave
	is_boss_wave = (current_wave % 5 == 0)
	_boss_spawned_this_wave = false
	_draft_triggered_this_wave = false
	_spawn_index = 0
	
	if is_boss_wave:
		# 1 Boss + scaled escort minions
		var escorts: int = mini(12, 3 + int(floorf(float(current_wave) / 5.0)) * 3)
		enemies_remaining_to_spawn = 1 + escorts
	else:
		# +40% wave spawn density
		enemies_remaining_to_spawn = int((4 + (current_wave * 3)) * 1.4)
	
	active_enemies = 0
	is_spawning = true
	_spawn_timer = 0.0
	
	get_tree().call_group("hazards", "queue_free")
	get_tree().call_group("damage_popups", "queue_free")
	
	# Multi-Vector Perimeter Breach Sector Alert on Waves 6, 11, 16
	if current_wave in [6, 11, 16]:
		EventBus.sector_breach_alert.emit(current_wave)
		AudioManager.play_sound(AudioManager.snd_alarm, 0.0, 0.0)
	
	EventBus.wave_started.emit(current_wave)


func _pick_enemy_scene_for_wave(wave: int) -> PackedScene:
	if wave < 6:
		return enemy_scene
	elif wave < 11:
		var roll: float = randf()
		if roll < 0.40:
			return enemy_scene
		elif roll < 0.65:
			return SCOUT_ENEMY_SCENE
		elif roll < 0.85:
			return SHIELD_ENEMY_SCENE
		else:
			return PHASE_ENEMY_SCENE
	elif wave < 16:
		var roll: float = randf()
		if roll < 0.20:
			return enemy_scene
		elif roll < 0.40:
			return SCOUT_ENEMY_SCENE
		elif roll < 0.60:
			return SHIELD_ENEMY_SCENE
		elif roll < 0.80:
			return BREACHER_ENEMY_SCENE
		elif roll < 0.90:
			return PHASE_ENEMY_SCENE
		else:
			return GOLIATH_ENEMY_SCENE
	else:
		var roll: float = randf()
		if roll < 0.20:
			return GOLIATH_ENEMY_SCENE
		elif roll < 0.45:
			return BREACHER_ENEMY_SCENE
		elif roll < 0.65:
			return SHIELD_ENEMY_SCENE
		elif roll < 0.80:
			return PHASE_ENEMY_SCENE
		else:
			return SCOUT_ENEMY_SCENE


func _spawn_enemy() -> void:
	var available_paths: Array[Path2D] = get_active_paths_for_wave(current_wave)
	if available_paths.is_empty():
		return
	
	# Distribute spawns across active quadrant entrance tracks
	var chosen_path: Path2D = available_paths[_spawn_index % available_paths.size()]
	_spawn_index += 1
	
	var enemy_instance: EnemyBase = null
	
	# If boss wave and boss hasn't spawned yet, spawn the boss first
	if is_boss_wave and not _boss_spawned_this_wave and BOSS_ENEMY_SCENE:
		enemy_instance = BOSS_ENEMY_SCENE.instantiate() as EnemyBase
		_boss_spawned_this_wave = true
	else:
		var chosen_scene: PackedScene = _pick_enemy_scene_for_wave(current_wave)
		if chosen_scene:
			enemy_instance = chosen_scene.instantiate() as EnemyBase
			if enemy_instance:
				# Steep wave HP scaling: pow(1.16, current_wave - 1) + (current_wave * 0.1)
				var hp_scale: float = pow(1.16, float(current_wave - 1)) + (float(current_wave) * 0.1)
				
				if is_endless_mode and current_wave > 25:
					hp_scale *= pow(1.20, float(current_wave - 25))
					enemy_instance.move_speed = minf(320.0, enemy_instance.move_speed * (1.0 + float(current_wave - 25) * 0.03))
				
				enemy_instance.max_hp *= hp_scale
				enemy_instance.current_hp = enemy_instance.max_hp
				enemy_instance.bounty = int(enemy_instance.bounty * (1.0 + (current_wave * 0.15)))
	
	if not enemy_instance:
		return
	
	chosen_path.add_child(enemy_instance)
	active_enemies += 1
	enemies_remaining_to_spawn -= 1
	
	if enemies_remaining_to_spawn <= 0:
		is_spawning = false


func _on_enemy_removed(_enemy: Node, _param2: Variant = null) -> void:
	active_enemies = maxi(0, active_enemies - 1)
	
	# Check if all enemies in the current wave have been cleared
	if active_enemies == 0 and enemies_remaining_to_spawn == 0 and not is_spawning:
		get_tree().call_group("hazards", "queue_free")
		get_tree().call_group("damage_popups", "queue_free")
		
		# Bit Dividend meta perk: +5% compound interest on unspent Bits per wave
		var dividend_lvl: int = GlobalState.get_perk_level("bit_dividend")
		if dividend_lvl > 0 and GlobalState.run_currency > 0:
			var interest_rate: float = 0.05 * float(dividend_lvl)
			var interest_bits: int = int(round(float(GlobalState.run_currency) * interest_rate))
			if interest_bits > 0:
				GlobalState.add_currency(interest_bits)
				
		EventBus.wave_completed.emit(current_wave)
		
		# Wave 25 Victory milestone
		if current_wave == 25 and not is_endless_mode and GlobalState.is_run_active:
			_wave_break_timer = 0.0
			EventBus.victory_reached.emit({})
			return
		
		# In-run Card Draft every 3 waves (Wave 3, 6, 9, 12, 15, 18, 21, 24...) with wave debounce
		if not _draft_triggered_this_wave and current_wave > 0 and (current_wave % 3 == 0) and GlobalState.is_run_active:
			_draft_triggered_this_wave = true
			_wave_break_timer = 0.0 # Halt timer until draft is completed
			EventBus.draft_requested.emit(current_wave)
		else:
			_wave_break_timer = time_between_waves


func _on_draft_completed(_chosen_card: Dictionary = {}) -> void:
	if GlobalState.is_run_active and not is_spawning and _wave_break_timer <= 0.0:
		_wave_break_timer = time_between_waves


func _on_run_started() -> void:
	get_tree().call_group("hazards", "queue_free")
	get_tree().call_group("damage_popups", "queue_free")
	current_wave = 0
	enemies_remaining_to_spawn = 0
	active_enemies = 0
	is_spawning = false
	is_boss_wave = false
	is_endless_mode = false
	_boss_spawned_this_wave = false
	_draft_triggered_this_wave = false
	_wave_break_timer = 2.0


func _on_run_ended(_victory: bool) -> void:
	is_spawning = false
	_wave_break_timer = 0.0
	_draft_triggered_this_wave = false
