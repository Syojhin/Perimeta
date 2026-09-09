class_name NodePoolManager
extends Node

## Central high-performance Object Pooling Engine for Perimeta.
## Pre-warms and recycles DamageNumbers, DeathSparks, shockwave rings, and mortar projectiles
## to eliminate GC pauses and dynamic heap allocations during high-density combat waves.

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")
const DEATH_SPARKS_SCENE: PackedScene = preload("res://scenes/combat/DeathSparks.tscn")

const PREWARM_DAMAGE_NUMBERS: int = 64
const PREWARM_DEATH_SPARKS: int = 32
const PREWARM_SHOCKWAVES: int = 16
const PREWARM_MORTAR_SHELLS: int = 8

var _damage_pool: Array = []
var _sparks_pool: Array = []
var _shockwave_pool: Array = []
var _mortar_pool: Array[Dictionary] = [] # Array of { "root": Node2D, "dot": Polygon2D, "trail": Line2D, "in_use": bool }

var _pool_container: Node2D = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pool_container = Node2D.new()
	_pool_container.name = "PooledObjectsRoot"
	_pool_container.visible = false
	add_child(_pool_container)
	
	_prewarm_damage_numbers()
	_prewarm_death_sparks()
	_prewarm_shockwaves()
	_prewarm_mortar_shells()
	
	var event_bus: Node = get_node_or_null("/root/EventBus") if is_inside_tree() else null
	if event_bus and event_bus.has_signal("run_started"):
		event_bus.connect("run_started", Callable(self, "recycle_all_active"))


# --- Damage Number Pool ---

func _prewarm_damage_numbers() -> void:
	for i in range(PREWARM_DAMAGE_NUMBERS):
		var inst: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
		inst.visible = false
		inst.process_mode = Node.PROCESS_MODE_DISABLED
		if inst.is_in_group("damage_popups"):
			inst.remove_from_group("damage_popups")
		_pool_container.add_child(inst)
		_damage_pool.append(inst)


## Fetch an available DamageNumber instance from the pool or instantiate on demand.
func get_damage_number(target_parent: Node = null) -> DamageNumber:
	var inst: DamageNumber = null
	while not _damage_pool.is_empty():
		var candidate: Variant = _damage_pool.pop_back()
		if candidate != null and is_instance_valid(candidate) and not (candidate as Node).is_queued_for_deletion():
			inst = candidate as DamageNumber
			break
	
	if not inst:
		inst = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
	
	var parent: Node = target_parent
	if not is_instance_valid(parent):
		if is_inside_tree() and get_tree():
			parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
		else:
			parent = _pool_container if is_instance_valid(_pool_container) else self
	
	if inst.get_parent() != parent:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		parent.add_child(inst)
	
	inst.process_mode = Node.PROCESS_MODE_INHERIT
	inst.visible = true
	return inst


## Return a DamageNumber back to the inactive pool.
func return_damage_number(inst: DamageNumber) -> void:
	if not is_instance_valid(inst) or inst.is_queued_for_deletion():
		return
	
	if inst.is_in_group("damage_popups"):
		inst.remove_from_group("damage_popups")
	
	if _damage_pool.has(inst):
		return
	
	inst.visible = false
	inst.process_mode = Node.PROCESS_MODE_DISABLED
	
	if is_instance_valid(_pool_container) and inst.get_parent() != _pool_container:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		_pool_container.add_child(inst)
		
	_damage_pool.append(inst)


## High-convenience spawn helper that sets up and fires combat floating text in a single zero-alloc call.
func spawn_damage_number(pos: Vector2, text: String, color: Color, is_crit: bool = false, target_parent: Node = null) -> DamageNumber:
	var inst: DamageNumber = get_damage_number(target_parent)
	if not inst:
		inst = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
		var p: Node = target_parent if is_instance_valid(target_parent) else (_pool_container if is_instance_valid(_pool_container) else self)
		p.add_child(inst)
	inst.spawn(pos, text, color, is_crit)
	return inst


# --- Death Sparks Pool ---

func _prewarm_death_sparks() -> void:
	for i in range(PREWARM_DEATH_SPARKS):
		var inst: DeathSparks = DEATH_SPARKS_SCENE.instantiate() as DeathSparks
		inst.visible = false
		inst.emitting = false
		inst.process_mode = Node.PROCESS_MODE_DISABLED
		_pool_container.add_child(inst)
		_sparks_pool.append(inst)


## Fetch an available DeathSparks instance from the pool.
func get_death_sparks(target_parent: Node = null) -> DeathSparks:
	var inst: DeathSparks = null
	while not _sparks_pool.is_empty():
		var candidate: Variant = _sparks_pool.pop_back()
		if candidate != null and is_instance_valid(candidate) and not (candidate as Node).is_queued_for_deletion():
			inst = candidate as DeathSparks
			break
			
	if not inst:
		inst = DEATH_SPARKS_SCENE.instantiate() as DeathSparks
		
	var parent: Node = target_parent
	if not is_instance_valid(parent):
		if is_inside_tree() and get_tree():
			parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
		else:
			parent = _pool_container if is_instance_valid(_pool_container) else self
		
	if inst.get_parent() != parent:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		parent.add_child(inst)
		
	inst.process_mode = Node.PROCESS_MODE_INHERIT
	inst.visible = true
	return inst


## Return DeathSparks back to the inactive pool.
func return_death_sparks(inst: DeathSparks) -> void:
	if not is_instance_valid(inst) or inst.is_queued_for_deletion():
		return
		
	if _sparks_pool.has(inst):
		return
		
	inst.emitting = false
	inst.visible = false
	inst.process_mode = Node.PROCESS_MODE_DISABLED
	
	if is_instance_valid(_pool_container) and inst.get_parent() != _pool_container:
		if inst.get_parent():
			inst.get_parent().remove_child(inst)
		_pool_container.add_child(inst)
		
	_sparks_pool.append(inst)


## Spawn and trigger death sparks burst with zero allocations.
func spawn_death_sparks(pos: Vector2, color: Color, target_parent: Node = null) -> DeathSparks:
	var inst: DeathSparks = get_death_sparks(target_parent)
	inst.global_position = pos
	inst.trigger(color)
	return inst


# --- Shockwave Ring Pool ---

func _prewarm_shockwaves() -> void:
	for i in range(PREWARM_SHOCKWAVES):
		var ring: Line2D = Line2D.new()
		ring.top_level = true
		ring.width = 3.5
		ring.visible = false
		ring.process_mode = Node.PROCESS_MODE_DISABLED
		# Pre-bake 20-point circle with radius 6.0
		for j in range(21):
			var ang: float = (float(j) / 20.0) * TAU
			ring.add_point(Vector2(cos(ang), sin(ang)) * 6.0)
		_pool_container.add_child(ring)
		_shockwave_pool.append(ring)


## Spawn an expanding AoE elemental shockwave without any dynamic Line2D allocations.
func spawn_shockwave(pos: Vector2, radius: float, fx_color: Color, duration: float = 0.18) -> void:
	var ring: Line2D = null
	while not _shockwave_pool.is_empty():
		var candidate: Variant = _shockwave_pool.pop_back()
		if candidate != null and is_instance_valid(candidate) and not (candidate as Node).is_queued_for_deletion():
			ring = candidate as Line2D
			break
			
	if not ring:
		ring = Line2D.new()
		ring.top_level = true
		ring.width = 3.5
		for j in range(21):
			var ang: float = (float(j) / 20.0) * TAU
			ring.add_point(Vector2(cos(ang), sin(ang)) * 6.0)
		_pool_container.add_child(ring)
	
	var parent: Node = null
	if is_inside_tree() and get_tree():
		parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if not parent:
		parent = _pool_container
		
	if ring.get_parent() != parent:
		if ring.get_parent():
			ring.get_parent().remove_child(ring)
		parent.add_child(ring)
	
	ring.process_mode = Node.PROCESS_MODE_INHERIT
	ring.global_position = pos
	ring.default_color = fx_color
	ring.scale = Vector2.ONE
	ring.modulate = Color(1.0, 1.0, 1.0, 1.0)
	ring.visible = true
	
	var target_scale: Vector2 = Vector2(radius / 6.0, radius / 6.0)
	var tween: Tween = ring.create_tween() if ring.is_inside_tree() else null
	if tween:
		tween.tween_property(ring, "scale", target_scale, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)
		tween.chain().tween_callback(func() -> void:
			_return_shockwave(ring)
		)
	else:
		_return_shockwave(ring)


func _return_shockwave(ring: Line2D) -> void:
	if not is_instance_valid(ring) or ring.is_queued_for_deletion():
		return
	ring.visible = false
	ring.process_mode = Node.PROCESS_MODE_DISABLED
	if is_instance_valid(_pool_container) and ring.get_parent() != _pool_container:
		if ring.get_parent():
			ring.get_parent().remove_child(ring)
		_pool_container.add_child(ring)
	if not _shockwave_pool.has(ring):
		_shockwave_pool.append(ring)


# --- Mortar Shell & Trail Pool ---

func _prewarm_mortar_shells() -> void:
	for i in range(PREWARM_MORTAR_SHELLS):
		var shell: Node2D = Node2D.new()
		shell.top_level = true
		shell.visible = false
		shell.process_mode = Node.PROCESS_MODE_DISABLED
		
		var visual_dot: Polygon2D = Polygon2D.new()
		visual_dot.polygon = PackedVector2Array([
			Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)
		])
		shell.add_child(visual_dot)
		
		var trail: Line2D = Line2D.new()
		trail.top_level = true
		trail.width = 3.5
		trail.visible = false
		trail.process_mode = Node.PROCESS_MODE_DISABLED
		
		_pool_container.add_child(shell)
		_pool_container.add_child(trail)
		
		_mortar_pool.append({
			"shell": shell,
			"dot": visual_dot,
			"trail": trail,
			"in_use": false
		})


## Fire an arcing mortar projectile using pre-warmed shells and trails.
func spawn_mortar_shell(start_pos: Vector2, target_pos: Vector2, is_master: bool, flight_time: float, on_impact: Callable) -> void:
	var entry: Dictionary = {}
	for candidate: Dictionary in _mortar_pool:
		if not candidate.get("in_use", false) and is_instance_valid(candidate.get("shell")):
			entry = candidate
			break
			
	if entry.is_empty():
		# Dynamic fallback instantiation
		var shell: Node2D = Node2D.new()
		shell.top_level = true
		var visual_dot: Polygon2D = Polygon2D.new()
		visual_dot.polygon = PackedVector2Array([
			Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)
		])
		shell.add_child(visual_dot)
		var trail: Line2D = Line2D.new()
		trail.top_level = true
		trail.width = 3.5
		_pool_container.add_child(shell)
		_pool_container.add_child(trail)
		entry = { "shell": shell, "dot": visual_dot, "trail": trail, "in_use": false }
		_mortar_pool.append(entry)
	
	entry["in_use"] = true
	var shell_node: Node2D = entry["shell"]
	var dot_node: Polygon2D = entry["dot"]
	var trail_node: Line2D = entry["trail"]
	
	dot_node.color = Color(0.3, 2.5, 2.5, 1.0) if is_master else Color(2.5, 0.8, 0.2, 1.0)
	trail_node.default_color = Color(0.2, 0.85, 1.0, 0.7) if is_master else Color(1.0, 0.45, 0.1, 0.7)
	trail_node.clear_points()
	trail_node.modulate = Color.WHITE
	
	var parent: Node = null
	if is_inside_tree() and get_tree():
		parent = get_tree().current_scene if get_tree().current_scene else get_tree().root
	if not parent:
		parent = _pool_container
		
	if shell_node.get_parent() != parent:
		if shell_node.get_parent():
			shell_node.get_parent().remove_child(shell_node)
		parent.add_child(shell_node)
	if trail_node.get_parent() != parent:
		if trail_node.get_parent():
			trail_node.get_parent().remove_child(trail_node)
		parent.add_child(trail_node)
		
	shell_node.global_position = start_pos
	shell_node.visible = true
	shell_node.process_mode = Node.PROCESS_MODE_INHERIT
	trail_node.visible = true
	trail_node.process_mode = Node.PROCESS_MODE_INHERIT
	
	var arc_peak: Vector2 = (start_pos + target_pos) * 0.5 + Vector2(0, -75)
	
	var tween: Tween = shell_node.create_tween() if shell_node.is_inside_tree() else null
	if tween:
		tween.tween_method(func(t: float) -> void:
			if is_instance_valid(shell_node) and is_instance_valid(trail_node):
				var p0: Vector2 = start_pos
				var p1: Vector2 = arc_peak
				var p2: Vector2 = target_pos
				var cur_pos: Vector2 = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
				shell_node.global_position = cur_pos
				trail_node.add_point(cur_pos)
				if trail_node.get_point_count() > 16:
					trail_node.remove_point(0)
		, 0.0, 1.0, flight_time)
		
		tween.chain().tween_callback(func() -> void:
			if on_impact.is_valid():
				on_impact.call()
			_return_mortar_shell(entry)
		)
	else:
		if on_impact.is_valid():
			on_impact.call()
		_return_mortar_shell(entry)


func _return_mortar_shell(entry: Dictionary) -> void:
	entry["in_use"] = false
	var shell_node: Node2D = entry.get("shell")
	var trail_node: Line2D = entry.get("trail")
	
	if is_instance_valid(shell_node):
		shell_node.visible = false
		shell_node.process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(_pool_container) and shell_node.get_parent() != _pool_container:
			if shell_node.get_parent():
				shell_node.get_parent().remove_child(shell_node)
			_pool_container.add_child(shell_node)
			
	if is_instance_valid(trail_node):
		trail_node.clear_points()
		trail_node.visible = false
		trail_node.process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(_pool_container) and trail_node.get_parent() != _pool_container:
			if trail_node.get_parent():
				trail_node.get_parent().remove_child(trail_node)
			_pool_container.add_child(trail_node)


# --- Global Pool Recycling ---

## Safely reclaims all active objects back into the inactive pool (e.g. on run restart).
func recycle_all_active() -> void:
	if not is_instance_valid(_pool_container):
		return
		
	# Clean up any invalid references
	_damage_pool = _damage_pool.filter(func(n: DamageNumber) -> bool: return is_instance_valid(n))
	_sparks_pool = _sparks_pool.filter(func(n: DeathSparks) -> bool: return is_instance_valid(n))
	_shockwave_pool = _shockwave_pool.filter(func(n: Line2D) -> bool: return is_instance_valid(n))
	
	for entry: Dictionary in _mortar_pool:
		if entry.get("in_use", false):
			_return_mortar_shell(entry)


## Public API to flush and reclaim all active pooled combat objects.
func clear_all_pools() -> void:
	recycle_all_active()
