class_name GoliathEnemy
extends EnemyBase

## Super-armored dreadnought juggernaut. High health pool, immune to slow status effects, and strikes the core for massive damage.

func _init() -> void:
	enemy_name = "Goliath Dreadnought"
	max_hp = 650.0
	move_speed = 50.0
	core_damage = 35.0
	bounty = 60
	primary_color = Color(1.0, 0.5, 0.1, 1.0)


## Goliath is immune to status slows.
func apply_slow(_factor: float, _base_duration: float = 2.0) -> void:
	# Immune to freeze/slow
	pass
