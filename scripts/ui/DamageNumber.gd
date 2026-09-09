class_name DamageNumber
extends Node2D

## Floating combat text displaying numeric damage and elemental reactions with zero-alloc pool recycling.

@onready var label: Label = $Label

var _active_tween: Tween = null


func _ready() -> void:
	add_to_group("damage_popups")


## Initialize and launch floating combat text animation from a pooled or new instance.
func spawn(pos: Vector2, text_str: String, text_color: Color = Color.WHITE, is_crit: bool = false) -> void:
	if not label:
		label = $Label if has_node("Label") else null
	
	global_position = pos
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	visible = true
	
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


func _recycle() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
		
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
