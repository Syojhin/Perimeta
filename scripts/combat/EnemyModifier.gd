class_name EnemyModifier
extends RefCounted

## Composable elite enemy modifier architecture for Perimeta.
## Provides lifecycle hooks for runtime damage mitigation, area buffs, phase shifting, and death splits.

enum ModifierType {
	PHASE_SHIFT,
	REACTIVE_PLATING,
	COMMAND_AURA,
	SPORE_SPLIT
}

const ENEMY_BASE_SCENE: PackedScene = preload("res://scenes/enemies/EnemyBase.tscn")

var type: ModifierType
var enemy: EnemyBase = null
var indicator_node: Node2D = null

# --- Phase Shift State ---
const PHASE_CYCLE_INTERVAL: float = 6.0
const PHASE_SHIFT_DURATION: float = 1.25
var _phase_timer: float = 0.0
var is_phase_shifted: bool = false

# --- Reactive Plating State ---
var last_damage_type: String = ""
var reactive_timer: float = 0.0
const REACTIVE_RESISTANCE_DURATION: float = 3.0
const REACTIVE_RESISTANCE_MULT: float = 0.60 # 40% damage reduction

# --- Command Aura State ---
const AURA_RADIUS: float = 80.0
var _aura_pulse: float = 0.0

# --- Spore Split State ---
var _spore_pulse: float = 0.0


func _init(p_type: ModifierType = ModifierType.PHASE_SHIFT) -> void:
	type = p_type


## Initialize modifier state and attach visual indicators to target enemy.
func init_modifier(p_enemy: EnemyBase) -> void:
	enemy = p_enemy
	if not is_instance_valid(enemy):
		return
		
	_create_visual_indicator()


## Per-frame process hook for continuous aura scanning and phase timing.
func on_physics_process(delta: float) -> void:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return
		
	match type:
		ModifierType.PHASE_SHIFT:
			_process_phase_shift(delta)
		ModifierType.REACTIVE_PLATING:
			_process_reactive_plating(delta)
		ModifierType.COMMAND_AURA:
			_process_command_aura(delta)
		ModifierType.SPORE_SPLIT:
			_process_spore_split(delta)


func on_take_damage(amount: float, damage_type: String) -> float:
	if not is_instance_valid(enemy) or enemy.is_dead:
		return amount
		
	match type:
		ModifierType.PHASE_SHIFT:
			# Immune to direct kinetic and piercing hits while shifted, but vulnerable to cryo and corrosive DoT
			if is_phase_shifted:
				var dtype: String = damage_type.to_lower()
				if dtype == "kinetic" or dtype == "piercing":
					_spawn_evade_text()
					return 0.0
					
		ModifierType.REACTIVE_PLATING:
			var dtype: String = damage_type.to_lower()
			var final_dmg: float = amount
			if reactive_timer > 0.0 and dtype == last_damage_type and not dtype.is_empty():
				final_dmg *= REACTIVE_RESISTANCE_MULT # 40% damage resistance against repeated element
				_flash_shield()
			last_damage_type = dtype
			reactive_timer = REACTIVE_RESISTANCE_DURATION
			return final_dmg
			
	return amount


func on_death() -> void:
	if not is_instance_valid(enemy):
		return
		
	if type == ModifierType.SPORE_SPLIT:
		_trigger_spore_split()


# --- Behavior Implementations ---

func _process_phase_shift(delta: float) -> void:
	_phase_timer += delta
	if is_phase_shifted:
		if _phase_timer >= PHASE_SHIFT_DURATION:
			is_phase_shifted = false
			_phase_timer = 0.0
			if is_instance_valid(indicator_node):
				indicator_node.visible = false
	else:
		if _phase_timer >= PHASE_CYCLE_INTERVAL:
			is_phase_shifted = true
			_phase_timer = 0.0
			if is_instance_valid(indicator_node):
				indicator_node.visible = true
				
	if is_phase_shifted and is_instance_valid(enemy) and enemy.visual_node:
		# Chromatic oscillating silhouette
		var osc: float = (sin(Time.get_ticks_msec() * 0.015) + 1.0) * 0.5
		enemy.visual_node.modulate = Color(1.8, 0.4, 2.2, lerpf(0.35, 0.85, osc))


func _process_reactive_plating(delta: float) -> void:
	if reactive_timer > 0.0:
		reactive_timer = maxf(0.0, reactive_timer - delta)
		
	if is_instance_valid(indicator_node):
		indicator_node.rotation += delta * 2.5
		indicator_node.visible = reactive_timer > 0.0


func _process_command_aura(delta: float) -> void:
	_aura_pulse += delta * 4.0
	if is_instance_valid(indicator_node):
		indicator_node.queue_redraw()
		
	var tree: SceneTree = enemy.get_tree()
	if not tree:
		return
		
	var r_sq: float = AURA_RADIUS * AURA_RADIUS
	var enemies: Array[Node] = tree.get_nodes_in_group("enemies")
	for node: Node in enemies:
		if not (node is EnemyBase) or node == enemy or not is_instance_valid(node):
			continue
		var minion: EnemyBase = node as EnemyBase
		if minion.is_dead:
			continue
			
		if enemy.global_position.distance_squared_to(minion.global_position) <= r_sq:
			# Grant +25% move speed and immunity to Singularity gravitational pull
			minion.apply_command_aura_buff(0.25)


func _process_spore_split(delta: float) -> void:
	_spore_pulse += delta * 5.0
	if is_instance_valid(indicator_node):
		indicator_node.queue_redraw()


func _trigger_spore_split() -> void:
	var path_parent: Node = enemy.get_parent()
	if not is_instance_valid(path_parent):
		return
		
	var current_prog: float = enemy.progress
	var orig_hp: float = enemy.max_hp
	var orig_speed: float = enemy.move_speed
	
	for i in range(3):
		var micro: EnemyBase = null
		if ENEMY_BASE_SCENE:
			micro = ENEMY_BASE_SCENE.instantiate() as EnemyBase
		else:
			micro = EnemyBase.new()
			
		micro.enemy_name = "MicroBreacher"
		micro.max_hp = maxf(12.0, orig_hp * 0.20)
		micro.current_hp = micro.max_hp
		micro.move_speed = orig_speed * 1.40
		micro.bounty = 0 # 0 bit bounty for split entities
		micro.scale = Vector2(0.65, 0.65)
		micro.primary_color = Color("#76FF03")
		
		path_parent.add_child(micro)
		micro.progress = maxf(0.0, current_prog - (float(i) * 20.0))


func _spawn_evade_text() -> void:
	if not is_instance_valid(enemy):
		return
	var loc_mgr: Node = enemy.get_node_or_null("/root/LocalizationManager") if enemy.is_inside_tree() else null
	var evade_str: String = loc_mgr.call("get_text", "STATUS_EVADED", "[ PHASE EVADE ! ]") if loc_mgr else "[ PHASE EVADE ! ]"
	enemy._spawn_reaction_text(evade_str, Color("#BF55EC"))


func _flash_shield() -> void:
	if is_instance_valid(indicator_node):
		var t: Tween = indicator_node.create_tween()
		indicator_node.scale = Vector2(1.3, 1.3)
		t.tween_property(indicator_node, "scale", Vector2.ONE, 0.15)


# --- Visual Node Crafting ---

func _create_visual_indicator() -> void:
	if not is_instance_valid(enemy):
		return
		
	indicator_node = Node2D.new()
	indicator_node.name = "ModifierIndicator"
	enemy.add_child(indicator_node)
	
	match type:
		ModifierType.PHASE_SHIFT:
			indicator_node.visible = false
			
		ModifierType.REACTIVE_PLATING:
			# Rotating hexagon shield
			var hex: Line2D = Line2D.new()
			hex.width = 2.0
			hex.default_color = Color(0.2, 0.8, 1.0, 0.8)
			var pts: PackedVector2Array = []
			for i in range(7):
				var angle: float = float(i) * (TAU / 6.0)
				pts.append(Vector2(cos(angle), sin(angle)) * 26.0)
			hex.points = pts
			indicator_node.add_child(hex)
			indicator_node.visible = false
			
		ModifierType.COMMAND_AURA:
			# Custom drawn pulsing golden aura ring
			var aura_drawer: Node2D = Node2D.new()
			aura_drawer.draw.connect(func() -> void:
				var p: float = (sin(_aura_pulse) + 1.0) * 0.5
				var col: Color = Color(1.0, 0.84, 0.0, 0.35 + p * 0.25)
				aura_drawer.draw_arc(Vector2.ZERO, AURA_RADIUS, 0.0, TAU, 32, col, 2.0)
				aura_drawer.draw_circle(Vector2.ZERO, AURA_RADIUS * 0.3, Color(1.0, 0.84, 0.0, 0.08))
			)
			indicator_node.add_child(aura_drawer)
			
		ModifierType.SPORE_SPLIT:
			# 3 pulsating bio-nodes
			var spore_drawer: Node2D = Node2D.new()
			spore_drawer.draw.connect(func() -> void:
				var p: float = (sin(_spore_pulse) + 1.0) * 0.5
				var col: Color = Color(0.46, 1.0, 0.01, 0.8)
				for i in range(3):
					var a: float = float(i) * (TAU / 3.0) + _spore_pulse * 0.5
					var pos: Vector2 = Vector2(cos(a), sin(a)) * 18.0
					spore_drawer.draw_circle(pos, 4.0 + p * 2.0, col)
			)
			indicator_node.add_child(spore_drawer)
