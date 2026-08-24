class_name ScoutEnemy
extends EnemyBase

## Fast, agile reconnaissance unit that sprints along the perimeter track with low HP.

func _init() -> void:
	enemy_name = "Scout Runner"
	max_hp = 30.0
	move_speed = 260.0
	core_damage = 8.0
	bounty = 12
	primary_color = Color(1.0, 0.92, 0.2, 1.0)
