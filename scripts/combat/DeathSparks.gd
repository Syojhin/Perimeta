class_name DeathSparks
extends CPUParticles2D

## Geometric particle explosion burst when enemies are eliminated.


func _ready() -> void:
	one_shot = true
	explosiveness = 1.0


## Trigger particle burst with specified HDR color and auto-free on completion.
func trigger(spark_color: Color) -> void:
	color = Color(spark_color.r * 2.2, spark_color.g * 2.2, spark_color.b * 2.2, 1.0)
	emitting = true
	
	# Clean deletion after burst ends
	var tree: SceneTree = get_tree()
	if tree:
		var cleanup_timer: SceneTreeTimer = tree.create_timer(lifetime + 0.1, false)
		cleanup_timer.timeout.connect(func() -> void:
			if is_instance_valid(self):
				queue_free()
		)
	else:
		queue_free()
