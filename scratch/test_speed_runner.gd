extends Node

func _ready() -> void:
	print("=== RUNNING SPEED CONTROLS & SHADOWING VERIFICATION ===")
	
	# 1. Verify GlobalState.game_speed property
	assert("game_speed" in GlobalState, "GlobalState must have 'game_speed' property")
	assert(GlobalState.game_speed == 1.0, "Default game_speed should be 1.0, got: %f" % GlobalState.game_speed)
	print("✔ GlobalState.game_speed declared and initialized to 1.0")
	
	# 2. Instantiate Arena scene and test speed buttons
	var arena_scene: PackedScene = load("res://scenes/combat/Arena.tscn")
	assert(arena_scene != null, "Arena.tscn must load")
	var arena: Arena = arena_scene.instantiate() as Arena
	add_child(arena)
	print("✔ Arena scene instantiated")
	
	# Test 1X, 2X, 4X speeds
	arena.set_game_speed(1.0)
	assert(Engine.time_scale == 1.0 and GlobalState.game_speed == 1.0, "1X speed failed")
	
	arena.set_game_speed(2.0)
	assert(Engine.time_scale == 2.0 and GlobalState.game_speed == 2.0, "2X speed failed")
	
	arena.set_game_speed(4.0)
	assert(Engine.time_scale == 4.0 and GlobalState.game_speed == 4.0, "4X speed failed")
	print("✔ Speed controls (1X, 2X, 4X) verified without errors")
	
	# Reset speed to 1.0
	arena.set_game_speed(1.0)
	assert(Engine.time_scale == 1.0, "Reset to 1X failed")
	
	# 3. Test Breacher Split without shadowing
	var test_path: Path2D = Path2D.new()
	test_path.curve = Curve2D.new()
	test_path.curve.add_point(Vector2(0, 0))
	test_path.curve.add_point(Vector2(500, 0))
	add_child(test_path)
	
	var breacher: BreacherEnemy = BreacherEnemy.new()
	test_path.add_child(breacher)
	breacher.progress = 200.0
	breacher.die()
	
	# Verify split swarmers were spawned
	var split_count: int = 0
	for child: Node in test_path.get_children():
		if child is ScoutEnemy:
			split_count += 1
	assert(split_count == 3, "Breacher should spawn 3 split swarmers upon death, got: %d" % split_count)
	print("✔ BreacherEnemy split spawn verified (3 mini-swarmers, no shadowing)")
	
	print("=== ALL SPEED CONTROLS & SHADOWING TESTS PASSED ===")
	get_tree().quit()
