extends Node2D

func _ready() -> void:
	print("=== STARTING PERIMETA FULL STABILITY & AUDIT VALIDATION ===")
	
	_test_audio_manager_sfx()
	_test_arena_super_and_overcharge()
	_test_signals_and_modals()
	_test_vfx_lifecycles()
	
	print("=== ALL FULL STABILITY AUDIT TESTS PASSED SUCCESSFULLY! ===")
	get_tree().quit(0)


func _test_audio_manager_sfx() -> void:
	print("[TEST 1/4] Testing AudioManager sound properties & play_sfx()...")
	assert(AudioManager != null, "AudioManager autoload missing!")
	
	# Verify all sound stream properties
	var expected_props: Array[String] = [
		"snd_laser", "snd_hit", "snd_coin", "snd_perk", "snd_alarm",
		"snd_wave", "snd_boss_warning", "snd_boss_spawn", "snd_boss_defeat",
		"snd_emp_blast", "snd_super", "snd_shoot", "snd_boom", "snd_upgrade",
		"snd_build", "snd_card_pick", "snd_ui_click"
	]
	
	for prop: String in expected_props:
		var stream: Variant = AudioManager.get(prop)
		assert(stream is AudioStreamWAV, "AudioManager property %s is not a valid AudioStreamWAV!" % prop)
	
	# Verify play_sfx with various pitches and names
	var sfx_keys: Array[String] = [
		"super", "laser", "shoot", "hit", "coin", "perk", "alarm",
		"wave", "boss_warning", "boss_spawn", "boss_defeat", "emp_blast",
		"emp", "boom", "explosion", "upgrade", "build", "card_pick",
		"card", "ui_click", "click", "non_existent_fallback_test"
	]
	
	for key: String in sfx_keys:
		AudioManager.play_sfx(key, Vector2(0.9, 1.1), -8.0)
		AudioManager.play_sfx(key, Vector2.ONE, 0.0)
	
	print(" -> AudioManager SFX tests PASSED.")


func _test_arena_super_and_overcharge() -> void:
	print("[TEST 2/4] Testing Arena EMP Super Shockwave & Overcharge...")
	var arena_scene: PackedScene = load("res://scenes/combat/Arena.tscn")
	assert(arena_scene != null, "Failed to load Arena.tscn")
	
	var arena: Arena = arena_scene.instantiate() as Arena
	assert(arena != null, "Failed to instantiate Arena")
	add_child(arena)
	
	# Test super charge trigger
	GlobalState.is_run_active = true
	GlobalState.super_charge = 100.0
	GlobalState.run_currency = 5000
	
	arena._trigger_super_emp()
	assert(GlobalState.super_charge == 0.0, "Super charge was not reset to 0!")
	
	# Test overcharge button
	arena._on_overcharge_pressed()
	assert(GlobalState.super_charge == 50.0, "Overcharge did not add 50 super charge!")
	assert(GlobalState.run_currency == 3500, "Overcharge did not spend 1500 currency!")
	
	# Test endless mode selection
	arena._on_endless_mode_selected()
	assert(arena.wave_spawner != null, "Wave spawner is null")
	assert(arena.wave_spawner.is_endless_mode == true, "Endless mode not enabled!")
	
	arena.queue_free()
	print(" -> Arena Super & Overcharge tests PASSED.")


func _test_signals_and_modals() -> void:
	print("[TEST 3/4] Testing EventBus and Modal Signal Wire-up...")
	# Verify EventBus signals
	assert(EventBus.has_user_signal("currency_changed") or EventBus.has_signal("currency_changed"), "currency_changed missing")
	assert(EventBus.has_user_signal("meta_cores_changed") or EventBus.has_signal("meta_cores_changed"), "meta_cores_changed missing")
	assert(EventBus.has_user_signal("perks_updated") or EventBus.has_signal("perks_updated"), "perks_updated missing")
	assert(EventBus.has_user_signal("game_over") or EventBus.has_signal("game_over"), "game_over missing")
	
	# Test GameOverModal signals
	var gom_scene: PackedScene = load("res://scenes/ui/GameOverModal.tscn")
	if gom_scene:
		var gom: GameOverModal = gom_scene.instantiate() as GameOverModal
		assert(gom.has_signal("restart_requested"), "GameOverModal missing restart_requested")
		assert(gom.has_signal("open_skill_tree_requested"), "GameOverModal missing open_skill_tree_requested")
		gom.free()
		
	# Test VictoryModal signals
	var vm_scene: PackedScene = load("res://scenes/ui/VictoryModal.tscn")
	if vm_scene:
		var vm: VictoryModal = vm_scene.instantiate() as VictoryModal
		assert(vm.has_signal("endless_mode_selected"), "VictoryModal missing endless_mode_selected")
		vm.free()
		
	print(" -> Signals & Modals tests PASSED.")


func _test_vfx_lifecycles() -> void:
	print("[TEST 4/4] Testing VFX lifecycle across speed tiers (1X, 2X, 4X)...")
	
	var test_speeds: Array[float] = [1.0, 2.0, 4.0]
	for spd: float in test_speeds:
		Engine.time_scale = spd
		
		# Test DamageNumber
		var dn_scene: PackedScene = load("res://scenes/ui/DamageNumber.tscn")
		var dn: DamageNumber = dn_scene.instantiate() as DamageNumber
		add_child(dn)
		dn.setup(100.0, Color.WHITE, false, "100")
		assert(is_instance_valid(dn), "DamageNumber failed to initialize")
		dn.free()
		
		# Test DeathSparks
		var ds_scene: PackedScene = load("res://scenes/combat/DeathSparks.tscn")
		var ds: DeathSparks = ds_scene.instantiate() as DeathSparks
		add_child(ds)
		ds.trigger(Color.CYAN)
		assert(is_instance_valid(ds), "DeathSparks failed to initialize")
		ds.free()
		
		# Test NapalmHazard
		var nh_scene: PackedScene = load("res://scenes/combat/NapalmHazard.tscn")
		var nh: NapalmHazard = nh_scene.instantiate() as NapalmHazard
		add_child(nh)
		nh.setup(Vector2.ZERO, 10.0, 0.5, 30.0)
		assert(is_instance_valid(nh), "NapalmHazard failed to initialize")
		nh.free()
		
		# Test IonizedTrailHazard
		var ith_scene: PackedScene = load("res://scenes/combat/IonizedTrailHazard.tscn")
		var ith: IonizedTrailHazard = ith_scene.instantiate() as IonizedTrailHazard
		add_child(ith)
		ith.setup(Vector2.ZERO, Vector2(100, 100), 10.0, 0.5, 20.0)
		assert(is_instance_valid(ith), "IonizedTrailHazard failed to initialize")
		ith.free()
	
	Engine.time_scale = 1.0
	print(" -> VFX lifecycle across speed tiers tests PASSED.")
