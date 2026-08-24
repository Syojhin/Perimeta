extends Node

func _ready() -> void:
	print("=== RUNNING DAMAGE NUMBER TEST RUNNER ===")
	var dmg_scene: PackedScene = load("res://scenes/ui/DamageNumber.tscn")
	assert(dmg_scene != null, "DamageNumber.tscn must load")
	
	# Spawn 50 popups
	for i in range(50):
		var p: DamageNumber = dmg_scene.instantiate() as DamageNumber
		add_child(p)
		p.global_position = Vector2(randf_range(200, 800), randf_range(200, 800))
		p.setup(float(i + 10), Color("#FFD700"), i % 3 == 0)
	
	var popups_initial: int = get_tree().get_nodes_in_group("damage_popups").size()
	assert(popups_initial == 50, "Should have 50 popups in group")
	print("✔ Spawned 50 popups in damage_popups group")
	
	get_tree().call_group("damage_popups", "queue_free")
	
	var timer: SceneTreeTimer = get_tree().create_timer(0.1)
	timer.timeout.connect(func() -> void:
		var popups_after: int = 0
		for node: Node in get_tree().get_nodes_in_group("damage_popups"):
			if not node.is_queued_for_deletion():
				popups_after += 1
		assert(popups_after == 0, "All popups should be cleaned up")
		print("✔ Group cleanup verified (0 lingering popups)")
		print("=== ALL DAMAGE POPUP TESTS PASSED ===")
		get_tree().quit()
	)
