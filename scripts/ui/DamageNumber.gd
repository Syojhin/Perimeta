class_name DamageNumber
extends Node2D

## Floating combat text displaying numeric damage and elemental reactions with zero-alloc pool recycling.

@onready var label: Label = $Label

var _active_tween: Tween = null
var current_value: float = 0.0


func _ready() -> void:
	pass


## Initialize and launch floating combat text animation from a pooled or new instance.
func spawn(pos: Vector2, text_str: String, text_color: Color = Color.WHITE, is_crit: bool = false, numeric_value: float = 0.0) -> void:
	if not is_in_group("damage_popups"):
		add_to_group("damage_popups")

	if not label:
		label = $Label if has_node("Label") else null
	
	global_position = pos
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible = true
	
	if numeric_value > 0.0:
		current_value = numeric_value
	else:
		var clean_str: String = text_str.trim_suffix("!").strip_edges()
		if clean_str.is_valid_float():
			current_value = clean_str.to_float()
		else:
			current_value = 0.0
	
	if label:
		label.text = text_str
		label.modulate = text_color
		label.add_theme_color_override("font_color", text_color)
		
	if is_crit:
		scale = Vector2(1.35, 1.35)
	else:
		scale = Vector2(1.0, 1.0)
		
	# Randomize drift end position
	var end_pos: Vector2 = pos + Vector2(randf_range(-18.0, 18.0), randf_range(-35.0, -50.0))
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	if _active_tween:
		_active_tween.set_parallel(true)
		_active_tween.tween_property(self, "global_position", end_pos, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(self, "modulate:a", 0.0, 0.65).set_ease(Tween.EASE_IN)
		_active_tween.chain().tween_callback(_recycle)
	else:
		_recycle()


## Aggregate incoming damage onto this active instance instead of spawning a new popup.
func aggregate_damage(add_text: String, add_color: Color = Color.WHITE, add_crit: bool = false, add_value: float = 0.0) -> void:
	if not label:
		label = $Label if has_node("Label") else null
	
	var val: float = add_value
	if val <= 0.0:
		var clean_str: String = add_text.trim_suffix("!").strip_edges()
		if clean_str.is_valid_float():
			val = clean_str.to_float()
	
	if val > 0.0 and current_value > 0.0:
		current_value += val
		var disp: String = str(roundi(current_value)) if current_value >= 1.0 else str(snappedf(current_value, 0.1))
		if add_crit or (label and label.text.ends_with("!")):
			disp += "!"
		if label:
			label.text = disp
			label.modulate = add_color
			label.add_theme_color_override("font_color", add_color)
	else:
		if label:
			label.text = add_text
			label.modulate = add_color
			label.add_theme_color_override("font_color", add_color)
	
	# Tactile punch scale pulse on aggregation
	var target_scale: Vector2 = Vector2(1.5, 1.5) if (add_crit or scale.x > 1.2) else Vector2(1.25, 1.25)
	scale = target_scale
	modulate.a = 1.0
	
	# Extend drift and fade animation
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	var end_pos: Vector2 = global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-15.0, -25.0))
	_active_tween = create_tween()
	if _active_tween:
		_active_tween.set_parallel(true)
		_active_tween.tween_property(self, "global_position", end_pos, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_active_tween.tween_property(self, "modulate:a", 0.0, 0.55).set_ease(Tween.EASE_IN)
		_active_tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
		_active_tween.chain().tween_callback(_recycle)
	else:
		_recycle()


func _recycle() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
		
	if is_in_group("damage_popups"):
		remove_from_group("damage_popups")
		
	if is_queued_for_deletion():
		return
		
	visible = false
	var pool: Node = get_node_or_null("/root/NodePool")
	if pool and pool.has_method("return_damage_number"):
		pool.call("return_damage_number", self)
	else:
		queue_free()


## Backward-compatible setup wrapper.
func setup(amount: float, text_color: Color = Color.WHITE, is_crit: bool = false, custom_text: String = "") -> void:
	var display_str: String = ""
	if not custom_text.is_empty():
		display_str = custom_text
	else:
		display_str = str(roundi(amount)) if amount >= 1.0 else str(snappedf(amount, 0.1))
		if is_crit and not display_str.ends_with("!"):
			display_str += "!"
	spawn(global_position, display_str, text_color, is_crit)


## Backward-compatible reaction text wrapper.
func setup_text(text_str: String, text_color: Color = Color.CYAN, is_crit: bool = true) -> void:
	spawn(global_position, text_str, text_color, is_crit)


## Backward-compatible setter wrapper.
func set_damage(amount: float, is_crit: bool = false, text_color: Color = Color.WHITE) -> void:
	setup(amount, text_color, is_crit)
