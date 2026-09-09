class_name DeathSparks
extends CPUParticles2D

## Geometric particle explosion burst when enemies are eliminated with zero-alloc pool recycling.

var _active_tween: Tween = null


func _ready() -> void:
	one_shot = true
	explosiveness = 1.0


## Trigger particle burst with specified HDR color and pool recycle on completion.
func trigger(spark_color: Color) -> void:
	visible = true
	emitting = false
	color = Color(spark_color.r * 2.2, spark_color.g * 2.2, spark_color.b * 2.2, 1.0)
	restart()
	emitting = true
	
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		
	_active_tween = create_tween()
	if _active_tween:
		_active_tween.tween_interval(lifetime + 0.08)
		_active_tween.tween_callback(_recycle)
	else:
		_recycle()


func _recycle() -> void:
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
		_active_tween = null
		
	emitting = false
	visible = false
	var pool: Node = get_node_or_null("/root/NodePool")
	if pool and pool.has_method("return_death_sparks"):
		pool.call("return_death_sparks", self)
	else:
		queue_free()
