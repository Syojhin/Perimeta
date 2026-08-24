extends SceneTree

func _init() -> void:
	print("=== RUNNING FLOATING COMBAT TEXT & POPUP LIFECYCLE TESTS ===")
	
	var dmg_scene: PackedScene = load("res://scenes/ui/DamageNumber.tscn")
	assert(dmg_scene != null, "DamageNumber.tscn must load")
	
	# Test 1: Single Popup setup() Lifecycle
	var popup1: DamageNumber = dmg_scene.instantiate() as DamageNumber
	root.add_child(popup1)
	popup1.global_position = Vector2(500, 500)
	popup1.setup(75.0, Color.WHITE, false)
	assert(popup1.is_in_group("damage_popups"), "Popup must be in 'damage_popups' group")
	assert(popup1.label.text == "75", "Popup text should be '75', got: %s" % popup1.label.text)
	
	# Test 2: Reaction Text setup_text() Lifecycle
	var popup2: DamageNumber = dmg_scene.instantiate() as DamageNumber
	root.add_child(popup2)
	popup2.global_position = Vector2(600, 500)
	popup2.setup_text("SUPERCONDUCT!", Color.CYAN, true)
	assert(popup2.is_in_group("damage_popups"), "Reaction popup must be in 'damage_popups' group")
	assert(popup2.label.text == "SUPERCONDUCT!", "Reaction popup text should be 'SUPERCONDUCT!'")
	
	# Test 3: Core Repair popup
	var popup3: DamageNumber = dmg_scene.instantiate() as DamageNumber
	root.add_child(popup3)
	popup3.global_position = Vector2(700, 500)
	popup3.setup(25.0, Color.GREEN, true, "+25")
	assert(popup3.label.text == "+25", "Core repair popup text should be '+25'")
	
	# Test 4: Rapid multi-hit spawn (50 popups)
	for i in range(50):
		var p: DamageNumber = dmg_scene.instantiate() as DamageNumber
		root.add_child(p)
		p.global_position = Vector2(randf_range(200, 800), randf_range(200, 800))
		p.setup(float(i + 10), Color("#FFD700"), i % 3 == 0)
	
	var popups_count_initial: int = root.get_tree().get_nodes_in_group("damage_popups").size()
	assert(popups_count_initial >= 53, "All 53 popups should be active in group")
	print("✔ Spawned %d floating combat text nodes" % popups_count_initial)
	
	# Test 5: Call group cleanup
	root.get_tree().call_group("damage_popups", "queue_free")
	
	# Allow frames for queue_free processing
	var timer: SceneTreeTimer = root.get_tree().create_timer(0.05)
	timer.timeout.connect(func() -> void:
		var popups_count_after: int = 0
		for node: Node in root.get_tree().get_nodes_in_group("damage_popups"):
			if not node.is_queued_for_deletion():
				popups_count_after += 1
		assert(popups_count_after == 0, "All popups should be freed on call_group queue_free, remaining: %d" % popups_count_after)
		print("✔ Group cleanup verified (0 lingering popups)")
		print("=== ALL FLOATING COMBAT TEXT TESTS PASSED ===")
		quit()
	)
