class_name BreacherEnemy
extends EnemyBase

## Heavy armored assault triangle. Upon destruction, ruptures into 3 rapid mini-swarmers.

const SCOUT_SCENE: PackedScene = preload("res://scenes/enemies/variants/ScoutEnemy.tscn")


func _init() -> void:
	enemy_name = "Breacher Titan"
	max_hp = 220.0
	move_speed = 75.0
	core_damage = 25.0
	bounty = 40
	primary_color = Color(1.0, 0.2, 0.25, 1.0)


func die() -> void:
	_spawn_split_swarmers()
	super.die()


func _spawn_split_swarmers() -> void:
	var path_parent: Node = get_parent()
	if not path_parent or not SCOUT_SCENE:
		return
	
	var current_prog: float = progress
	for i in range(3):
		var mini_instance: ScoutEnemy = SCOUT_SCENE.instantiate() as ScoutEnemy
		if mini_instance:
			mini_instance.enemy_name = "Mini Swarmer"
			mini_instance.max_hp = 18.0
			mini_instance.move_speed = 240.0
			mini_instance.bounty = 6
			mini_instance.scale = Vector2(0.7, 0.7)
			mini_instance.primary_color = Color(1.0, 0.35, 0.2, 1.0)
			
			path_parent.add_child(mini_instance)
			mini_instance.progress = maxf(0.0, current_prog - (i * 24.0))
