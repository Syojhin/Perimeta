class_name CoreBase
extends Area2D

## Central defensive core for Perimeta. Displays core status, health reactions, and field repair sink.

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/DamageNumber.tscn")

@export var core_radius: float = 48.0
@export var repair_cost: int = 300
@export var repair_amount: float = 25.0

@onready var visual_root: Node2D = $Visual
@onready var shield_glow: Polygon2D = $Visual/ShieldGlow
@onready var core_body: Polygon2D = $Visual/CoreBody
@onready var repair_hint: Label = $Visual/RepairHint
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _base_scale: Vector2 = Vector2.ONE
var _pulse_time: float = 0.0
var _is_hovered: bool = false


func _ready() -> void:
	_base_scale = visual_root.scale
	input_pickable = true
	
	EventBus.core_damaged.connect(_on_core_damaged)
	EventBus.core_healed.connect(_on_core_healed)
	EventBus.core_destroyed.connect(_on_core_destroyed)
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	if repair_hint:
		repair_hint.visible = false


func _process(delta: float) -> void:
	# Subtle ambient pulsing glow
	_pulse_time += delta * 2.5
	if shield_glow:
		var pulse: float = 0.85 + 0.15 * sin(_pulse_time)
		shield_glow.scale = Vector2(pulse, pulse)
	
	_update_repair_hint()


func _update_repair_hint() -> void:
	if not repair_hint:
		return
	
	if _is_hovered and GlobalState.is_run_active and GlobalState.core_hp < GlobalState.core_max_hp:
		repair_hint.visible = true
		repair_hint.text = "FIELD REPAIR +%d HP\n[%d BITS]" % [int(repair_amount), repair_cost]
		if GlobalState.run_currency >= repair_cost:
			repair_hint.modulate = Color(0.3, 1.0, 0.6, 1.0)
		else:
			repair_hint.modulate = Color(1.0, 0.4, 0.4, 0.8)
	else:
		repair_hint.visible = false


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_attempt_field_repair()


func _attempt_field_repair() -> void:
	if not GlobalState.is_run_active:
		return
	
	if GlobalState.core_hp >= GlobalState.core_max_hp:
		return
	
	get_viewport().set_input_as_handled()
	
	if GlobalState.spend_currency(repair_cost):
		GlobalState.heal_core(repair_amount)
		_show_repair_fx()
	else:
		_show_insufficient_bits_fx()


func _show_repair_fx() -> void:
	if DAMAGE_NUMBER_SCENE:
		var num: DamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as DamageNumber
		if num:
			num.global_position = global_position + Vector2(0, -50)
			var target_parent: Node = get_tree().current_scene if (get_tree() and get_tree().current_scene) else get_parent()
			target_parent.add_child(num)
			num.setup(repair_amount, Color(0.2, 1.0, 0.5, 1.0), true, "+%d" % int(repair_amount))
	
	if visual_root:
		visual_root.modulate = Color(0.3, 3.0, 1.0, 1.0)
		var tween: Tween = create_tween()
		tween.tween_property(visual_root, "scale", _base_scale * 1.2, 0.1)
		tween.tween_property(visual_root, "scale", _base_scale, 0.2).set_trans(Tween.TRANS_BACK)
		tween.parallel().tween_property(visual_root, "modulate", Color.WHITE, 0.3)


func _show_insufficient_bits_fx() -> void:
	if visual_root:
		visual_root.modulate = Color(2.5, 0.4, 0.4, 1.0)
		var tween: Tween = create_tween()
		tween.tween_property(visual_root, "modulate", Color.WHITE, 0.2)


func _on_mouse_entered() -> void:
	_is_hovered = true


func _on_mouse_exited() -> void:
	_is_hovered = false


func _on_core_damaged(_current_hp: float, _max_hp: float) -> void:
	if not visual_root:
		return
	
	# Damage impact shake and flash
	visual_root.modulate = Color(2.5, 0.4, 0.4, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(visual_root, "scale", _base_scale * 1.15, 0.05)
	tween.tween_property(visual_root, "scale", _base_scale, 0.1)
	tween.parallel().tween_property(visual_root, "modulate", Color.WHITE, 0.2)


func _on_core_healed(_amount: float, _current_hp: float) -> void:
	if not visual_root:
		return
	
	visual_root.modulate = Color(0.4, 2.0, 0.8, 1.0)
	var tween: Tween = create_tween()
	tween.tween_property(visual_root, "modulate", Color.WHITE, 0.3)


func _on_core_destroyed() -> void:
	if not visual_root:
		return
	
	# Destruction collapse
	var tween: Tween = create_tween()
	tween.tween_property(visual_root, "scale", Vector2.ZERO, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(visual_root, "modulate", Color(2.5, 0.2, 0.2, 0.0), 0.4)
