class_name PhaseInfiltrator
extends EnemyBase

## Fast infiltration unit capable of phase cloaking. While cloaked, it is untargetable by defensive towers.

@export var cloak_interval: float = 2.0
@export var cloak_duration: float = 1.8

var _phase_timer: float = 2.0


func _init() -> void:
	enemy_name = "Phase Infiltrator"
	max_hp = 45.0
	move_speed = 180.0
	core_damage = 12.0
	bounty = 24
	primary_color = Color(0.3, 0.85, 1.0, 1.0)


func _ready() -> void:
	super._ready()
	_phase_timer = cloak_interval


func _process(delta: float) -> void:
	if is_dead:
		return
	
	super._process(delta)
	
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		if is_cloaked:
			# Uncloak
			is_cloaked = false
			_phase_timer = cloak_interval
			if visual_node:
				var tween: Tween = create_tween()
				tween.tween_property(visual_node, "modulate", Color.WHITE, 0.2)
		else:
			# Cloak
			is_cloaked = true
			_phase_timer = cloak_duration
			if visual_node:
				var tween: Tween = create_tween()
				tween.tween_property(visual_node, "modulate", Color(0.3, 0.9, 1.0, 0.2), 0.2)


func take_damage(amount: float, is_crit: bool = false, color_override: Color = Color("#E2F1FF")) -> void:
	if is_dead:
		return
	
	var final_dmg: float = amount
	if is_cloaked:
		final_dmg *= 0.20 # 80% damage reduction while phase cloaked
	
	super.take_damage(final_dmg, is_crit, color_override)
