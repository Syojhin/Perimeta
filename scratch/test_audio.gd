extends SceneTree

func _init() -> void:
	print("--- BEGIN AUDIO VALIDATION TEST ---")
	
	# Load default bus layout if not already loaded
	var bus_layout: AudioBusLayout = load("res://default_bus_layout.tres") as AudioBusLayout
	if bus_layout:
		AudioServer.set_bus_layout(bus_layout)
		print("Loaded default_bus_layout.tres successfully.")
	
	# Check AudioServer buses
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	
	print("Audio Buses:")
	print("  Master Bus (idx %d): vol=%.2f dB, mute=%s" % [master_idx, AudioServer.get_bus_volume_db(master_idx), str(AudioServer.is_bus_mute(master_idx))])
	print("  Music Bus (idx %d): vol=%.2f dB, mute=%s" % [music_idx, AudioServer.get_bus_volume_db(music_idx), str(AudioServer.is_bus_mute(music_idx))])
	print("  SFX Bus (idx %d): vol=%.2f dB, mute=%s" % [sfx_idx, AudioServer.get_bus_volume_db(sfx_idx), str(AudioServer.is_bus_mute(sfx_idx))])
	
	assert(master_idx != -1, "Master bus missing!")
	assert(music_idx != -1, "Music bus missing!")
	assert(sfx_idx != -1, "SFX bus missing!")
	assert(not AudioServer.is_bus_mute(master_idx), "Master bus is muted!")
	assert(not AudioServer.is_bus_mute(music_idx), "Music bus is muted!")
	assert(AudioServer.get_bus_volume_db(master_idx) > -70.0, "Master bus volume too low!")
	assert(AudioServer.get_bus_volume_db(music_idx) > -70.0, "Music bus volume too low!")
	
	# Instantiate EventBus, SaveManager and AudioManager nodes for standalone test
	var event_bus_script: GDScript = load("res://scripts/autoload/EventBus.gd") as GDScript
	var event_bus: Node = event_bus_script.new()
	event_bus.name = "EventBus"
	root.add_child(event_bus)
	
	var save_mgr_script: GDScript = load("res://scripts/autoload/SaveManager.gd") as GDScript
	var save_mgr: Node = save_mgr_script.new()
	save_mgr.name = "SaveManager"
	root.add_child(save_mgr)
	
	var audio_mgr_script: GDScript = load("res://scripts/autoload/AudioManager.gd") as GDScript
	var audio_mgr: Node = audio_mgr_script.new()
	audio_mgr.name = "AudioManager"
	root.add_child(audio_mgr)
	
	# Check AudioManager TRACKS
	print("\nChecking AudioManager TRACKS:")
	var tracks: Dictionary = audio_mgr_script.TRACKS
	for track_key: String in tracks:
		var stream: AudioStream = tracks[track_key] as AudioStream
		assert(stream != null, "Track stream '%s' is null!" % track_key)
		print("  Track '%s': %s (loop=%s)" % [track_key, stream.get_class(), str((stream as AudioStreamMP3).loop if stream is AudioStreamMP3 else "N/A")])
	
	# Check AudioManager _music_cache & alias lookups
	print("\nTesting Track Lookups and Aliases:")
	var test_tracks: Array[String] = [
		"bgm menu", "menu", "title", "bgm_menu",
		"waves 1-5", "waves 1–5", "1-5", "ambient", "combat",
		"waves 6-10", "waves 11-15", "waves 16-20", "waves 21-25",
		"titan anomaly", "titan", "boss",
		"ending", "victory", "defeat", "game over"
	]
	
	for track_name: String in test_tracks:
		var key: String = audio_mgr.call("_clean_key", track_name)
		if audio_mgr._alias_map.has(key):
			key = audio_mgr._alias_map[key]
		var stream: AudioStream = audio_mgr._music_cache.get(key)
		assert(stream != null, "Lookup for '%s' (resolved key: '%s') failed!" % [track_name, key])
		print("  Lookup '%s' -> resolved '%s' -> OK" % [track_name, key])
		
	# Test playback calls
	audio_mgr.play_menu_music(0.0)
	print("\nPlay menu music called successfully.")
	audio_mgr.play_wave_music(1, 0.0)
	print("Play wave 1 music called successfully.")
	audio_mgr.play_wave_music(7, 0.0)
	print("Play wave 7 music called successfully.")
	audio_mgr.play_wave_music(12, 0.0)
	print("Play wave 12 music called successfully.")
	audio_mgr.play_wave_music(18, 0.0)
	print("Play wave 18 music called successfully.")
	audio_mgr.play_wave_music(24, 0.0)
	print("Play wave 24 music called successfully.")
	audio_mgr.play_boss_music(0.0)
	print("Play boss music called successfully.")
	audio_mgr.play_ending_music(0.0)
	print("Play ending music called successfully.")
	
	# Check Procedural SFX
	print("\nChecking Procedural SFX:")
	assert(audio_mgr.snd_laser != null, "snd_laser is null!")
	assert(audio_mgr.snd_hit != null, "snd_hit is null!")
	assert(audio_mgr.snd_coin != null, "snd_coin is null!")
	assert(audio_mgr.snd_perk != null, "snd_perk is null!")
	assert(audio_mgr.snd_alarm != null, "snd_alarm is null!")
	assert(audio_mgr.snd_wave != null, "snd_wave is null!")
	assert(audio_mgr.snd_boss_warning != null, "snd_boss_warning is null!")
	assert(audio_mgr.snd_boss_defeat != null, "snd_boss_defeat is null!")
	assert(audio_mgr.snd_emp_blast != null, "snd_emp_blast is null!")
	assert(audio_mgr.snd_card_pick != null, "snd_card_pick is null!")
	assert(audio_mgr.snd_ui_click != null, "snd_ui_click is null!")
	print("  All 11 procedural SFX streams initialized properly.")
	
	print("\n--- AUDIO VALIDATION TEST PASSED SUCCESSFULLY ---")
	quit(0)
