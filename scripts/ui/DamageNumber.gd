class_name DamageNumber
extends Node2D

## Floating combat text displaying numeric damage and elemental reactions with guaranteed autonomous despawn.

@onready var label: Label = $Label


func _ready() -> void:
	add_to_group("damage_popups")


func setup(amount: float, text_color: Color = Color.WHITE, is_crit: bool = false, custom_text: String = "") -> void:
	if not label:
		label = $Label if has_node("Label") else null
	
	if label:
		if not custom_text.is_empty():
			label.text = custom_text
		else:
			label.text = str(roundi(amount)) if amount >= 1.0 else str(snappedf(amount, 0.1))
			
		label.modulate = text_color
		label.add_theme_color_override("font_color", text_color)
		
		if is_crit:
			if custom_text.is_empty() and not label.text.ends_with("!"):
				label.text += "!"
			scale = Vector2(1.35, 1.35)
		else:
			scale = Vector2(1.0, 1.0)
	
	# Randomize drift end position
	var end_pos: Vector2 = global_position + Vector2(randf_range(-18.0, 18.0), randf_range(-35.0, -50.0))
	
	# Parallel movement and alpha fade
	var tween: Tween = create_tween()
	if tween:
		tween.set_parallel(true)
		tween.tween_property(self, "global_position", end_pos, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "modulate:a", 0.0, 0.65).set_ease(Tween.EASE_IN)
		tween.chain().tween_callback(queue_free)
	
	# Safety fallback timer in case tween is interrupted or paused
	if get_tree():
		get_tree().create_timer(0.85, false).timeout.connect(func() -> void:
			if is_instance_valid(self) and not is_queued_for_deletion():
				queue_free()
		)


func setup_text(text_str: String, text_color: Color = Color.CYAN, is_crit: bool = true) -> void:
	setup(0.0, text_color, is_crit, text_str)


func set_damage(amount: float, is_crit: bool = false, text_color: Color = Color.WHITE) -> void:
	setup(amount, text_color, is_crit)
