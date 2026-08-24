extends Node

func _ready() -> void:
	print("=== BEGIN IN-ENGINE AUDIO VALIDATION ===")
	
	# Verify default_bus_layout.tres and AudioServer buses
	var master_idx: int = AudioServer.get_bus_index("Master")
	var music_idx: int = AudioServer.get_bus_index("Music")
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	
	print("[AudioServer Buses]")
	print("  Master Bus (idx %d): volume=%.2f dB, mute=%s" % [master_idx, AudioServer.get_bus_volume_db(master_idx), str(AudioServer.is_bus_mute(master_idx))])
	print("  Music Bus (idx %d): volume=%.2f dB, mute=%s" % [music_idx, AudioServer.get_bus_volume_db(music_idx), str(AudioServer.is_bus_mute(music_idx))])
	print("  SFX Bus (idx %d): volume=%.2f dB, mute=%s" % [sfx_idx, AudioServer.get_bus_volume_db(sfx_idx), str(AudioServer.is_bus_mute(sfx_idx))])
	
	if master_idx == -1 or music_idx == -1 or sfx_idx == -1:
		push_error("FAIL: Audio buses missing!")
		get_tree().quit(1)
		return
		
	if AudioServer.is_bus_mute(master_idx) or AudioServer.is_bus_mute(music_idx):
		push_error("FAIL: Master or Music bus is muted!")
		get_tree().quit(1)
		return
		
	if AudioServer.get_bus_volume_db(master_idx) <= -70.0 or AudioServer.get_bus_volume_db(music_idx) <= -70.0:
		push_error("FAIL: Master or Music bus volume is at -80 dB!")
		get_tree().quit(1)
		return
	
	# Verify AudioManager preloaded TRACKS
	print("\n[AudioManager TRACKS Map]")
	for track_key: String in AudioManager.TRACKS:
		var stream: AudioStream = AudioManager.TRACKS[track_key] as AudioStream
		if stream == null:
			push_error("FAIL: Track '%s' is null!" % track_key)
			get_tree().quit(1)
			return
		var is_loop: bool = (stream as AudioStreamMP3).loop if stream is AudioStreamMP3 else true
		print("  '%s' -> %s (loop=%s)" % [track_key, stream.get_class(), str(is_loop)])
		if not is_loop:
			push_error("FAIL: Track '%s' does not have loop enabled!" % track_key)
			get_tree().quit(1)
			return
	
	# Verify Alias Map and Music Cache
	print("\n[Testing Track Lookups & Aliases]")
	var test_lookups: Array[String] = [
		"bgm menu", "menu", "title", "bgm_menu",
		"waves 1-5", "waves 1–5", "1-5", "ambient", "combat",
		"waves 6-10", "wave 6-10", "waves 6–10",
		"waves 11-15", "wave 11-15", "waves 11–15",
		"waves 16-20", "wave 16-20", "waves 16–20",
		"waves 21-25", "wave 21-25", "waves 21–25",
		"titan anomaly", "titan", "boss",
		"ending", "victory", "defeat", "game over"
	]
	
	for name_query: String in test_lookups:
		var key: String = AudioManager._clean_key(name_query)
		if AudioManager._alias_map.has(key):
			key = AudioManager._alias_map[key]
		var stream: AudioStream = AudioManager._music_cache.get(key)
		if stream == null:
			push_error("FAIL: Track lookup for '%s' (key: '%s') returned null!" % [name_query, key])
			get_tree().quit(1)
			return
		print("  Lookup '%s' -> resolved key '%s' -> OK" % [name_query, key])
	
	# Test Playback Calls
	print("\n[Testing BGM Transitions]")
	AudioManager.play_menu_music(0.0)
	print("  play_menu_music OK")
	AudioManager.play_wave_music(3, 0.0)
	print("  play_wave_music(3) OK")
	AudioManager.play_wave_music(8, 0.0)
	print("  play_wave_music(8) OK")
	AudioManager.play_wave_music(14, 0.0)
	print("  play_wave_music(14) OK")
	AudioManager.play_wave_music(19, 0.0)
	print("  play_wave_music(19) OK")
	AudioManager.play_wave_music(25, 0.0)
	print("  play_wave_music(25) OK")
	AudioManager.play_boss_music(0.0)
	print("  play_boss_music OK")
	AudioManager.play_ending_music(0.0)
	print("  play_ending_music OK")
	
	# Verify Procedural SFX Streams
	print("\n[Testing Procedural SFX]")
	var sfx_list: Dictionary = {
		"snd_laser": AudioManager.snd_laser,
		"snd_hit": AudioManager.snd_hit,
		"snd_coin": AudioManager.snd_coin,
		"snd_perk": AudioManager.snd_perk,
		"snd_alarm": AudioManager.snd_alarm,
		"snd_wave": AudioManager.snd_wave,
		"snd_boss_warning": AudioManager.snd_boss_warning,
		"snd_boss_defeat": AudioManager.snd_boss_defeat,
		"snd_emp_blast": AudioManager.snd_emp_blast,
		"snd_card_pick": AudioManager.snd_card_pick,
		"snd_ui_click": AudioManager.snd_ui_click
	}
	
	for sfx_name: String in sfx_list:
		var wav: AudioStreamWAV = sfx_list[sfx_name]
		if wav == null or wav.data.is_empty():
			push_error("FAIL: SFX '%s' is null or empty!" % sfx_name)
			get_tree().quit(1)
			return
		print("  SFX '%s': %d bytes PCM" % [sfx_name, wav.data.size()])
		
	print("\n=== ALL IN-ENGINE AUDIO VALIDATIONS PASSED ===")
	get_tree().quit(0)
