extends Node

func _ready() -> void:
	print("=== TESTING MAIN MENU SCENE ===")
	var menu_scene: PackedScene = load("res://scenes/ui/MainMenu.tscn") as PackedScene
	var menu_inst: Control = menu_scene.instantiate() as Control
	add_child(menu_inst)
	print("MainMenu instantiated successfully.")
	
	# Verify AudioManager has menu track playing
	var active_slot: int = AudioManager._active_bgm_slot
	var player: AudioStreamPlayer = AudioManager._bgm_player_a if active_slot == 0 else AudioManager._bgm_player_b
	print("Active BGM Player slot: %d, stream: %s, volume: %.2f dB" % [active_slot, str(player.stream), player.volume_db])
	
	await get_tree().create_timer(0.5).timeout
	print("MainMenu run verification complete.")
	get_tree().quit(0)
