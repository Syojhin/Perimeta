extends SceneTree

func _init() -> void:
	print("=== RUNNING EXTENDED SERPENTINE & SOCKET VERIFICATION ===")
	
	# 1. Instantiate Arena Scene
	var arena_scene: PackedScene = load("res://scenes/combat/Arena.tscn")
	assert(arena_scene != null, "Arena.tscn must load successfully")
	var arena: Node = arena_scene.instantiate()
	root.add_child(arena)
	print("✔ Arena.tscn instantiated cleanly")
	
	var wave_spawner: WaveSpawner = arena.get_node("WaveSpawner") as WaveSpawner
	assert(wave_spawner != null, "WaveSpawner must exist in Arena")
	
	# 2. Test 4 Serpentine Paths (7 points each)
	var path_n: Path2D = arena.get_node("Tracks/Path_North") as Path2D
	var path_s: Path2D = arena.get_node("Tracks/Path_South") as Path2D
	var path_w: Path2D = arena.get_node("Tracks/Path_West") as Path2D
	var path_e: Path2D = arena.get_node("Tracks/Path_East") as Path2D
	
	assert(path_n != null and path_n.curve.point_count == 7, "Path_North should have 7 points, got: %d" % (path_n.curve.point_count if path_n else 0))
	assert(path_s != null and path_s.curve.point_count == 7, "Path_South should have 7 points, got: %d" % (path_s.curve.point_count if path_s else 0))
	assert(path_w != null and path_w.curve.point_count == 7, "Path_West should have 7 points, got: %d" % (path_w.curve.point_count if path_w else 0))
	assert(path_e != null and path_e.curve.point_count == 7, "Path_East should have 7 points, got: %d" % (path_e.curve.point_count if path_e else 0))
	
	# Verify baked lengths (travel distances)
	var len_n: float = path_n.curve.get_baked_length()
	var len_s: float = path_s.curve.get_baked_length()
	var len_w: float = path_w.curve.get_baked_length()
	var len_e: float = path_e.curve.get_baked_length()
	print("Track baked lengths: North=%.1fpx, South=%.1fpx, West=%.1fpx, East=%.1fpx" % [len_n, len_s, len_w, len_e])
	assert(len_n > 4000.0, "Path_North should be > 4000px")
	assert(len_s > 4000.0, "Path_South should be > 4000px")
	assert(len_w > 1400.0, "Path_West should be > 1400px")
	assert(len_e > 1400.0, "Path_East should be > 1400px")
	
	# Verify Core position
	var core_node: Node2D = arena.get_node("CoreBase") as Node2D
	assert(core_node != null and core_node.position == Vector2(960, 540), "Core must sit at exact center (960, 540)")
	print("✔ Core centered at (960, 540) and 4-way extended serpentine paths verified")
	
	# 3. Test Active Paths by Wave Tier
	var paths_w1: Array[Path2D] = wave_spawner.get_active_paths_for_wave(1)
	assert(paths_w1.size() == 1 and paths_w1[0] == path_n, "Wave 1 should have 1 active path (North)")
	
	var paths_w6: Array[Path2D] = wave_spawner.get_active_paths_for_wave(6)
	assert(paths_w6.size() == 2, "Wave 6 should have 2 active paths (North, South)")
	
	var paths_w11: Array[Path2D] = wave_spawner.get_active_paths_for_wave(11)
	assert(paths_w11.size() == 3, "Wave 11 should have 3 active paths (North, South, East)")
	
	var paths_w16: Array[Path2D] = wave_spawner.get_active_paths_for_wave(16)
	assert(paths_w16.size() == 4, "Wave 16 should have 4 active paths")
	print("✔ Wave Spawner active lane activation verified")
	
	# 4. Test Sockets count, starter unlocks, and HUD clearance
	var sockets: Node2D = arena.get_node("Sockets") as Node2D
	assert(sockets != null and sockets.get_child_count() == 16, "Arena should have exactly 16 sockets, got: %d" % sockets.get_child_count())
	
	for child: Node in sockets.get_children():
		if child is BuildSocket:
			var s: BuildSocket = child as BuildSocket
			assert(s.position.y <= 850.0, "All sockets must sit at y <= 850 to avoid bottom HUD overlap! Found: %s at y=%f" % [s.name, s.position.y])
	
	var s1: BuildSocket = sockets.get_node("Socket_01") as BuildSocket
	var s2: BuildSocket = sockets.get_node("Socket_02") as BuildSocket
	var s3: BuildSocket = sockets.get_node("Socket_03") as BuildSocket
	var s4: BuildSocket = sockets.get_node("Socket_04") as BuildSocket
	assert(s1.unlock_cost == 0 and s1.initial_state == BuildSocket.SocketState.UNLOCKED_EMPTY, "Socket 1 should be unlocked")
	assert(s2.unlock_cost == 0 and s2.initial_state == BuildSocket.SocketState.UNLOCKED_EMPTY, "Socket 2 should be unlocked")
	assert(s3.unlock_cost == 0 and s3.initial_state == BuildSocket.SocketState.UNLOCKED_EMPTY, "Socket 3 should be unlocked")
	assert(s4.unlock_cost == 0 and s4.initial_state == BuildSocket.SocketState.UNLOCKED_EMPTY, "Socket 4 should be unlocked")
	print("✔ 16 build sockets verified (0 below y=850, 4 starter unlocked inner sanctum sockets)")
	
	print("=== ALL SERPENTINE & SOCKET CLEARANCE TESTS PASSED ===")
	quit()
