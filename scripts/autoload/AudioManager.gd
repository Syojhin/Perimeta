extends Node

## Dynamic soundtrack manager and procedural retro audio synthesizer for Perimeta.
## Features dual-channel BGM crossfading, robust track caching with Unicode dash normalization, and decoupled EventBus reactive transitions.

const MIX_RATE: int = 22050
const MUSIC_DIR: String = "res://assets/audio/music/"
const DEFAULT_BGM_VOLUME_DB: float = -4.0
const MAX_SFX_PLAYERS: int = 12

## Direct preloaded soundtrack map to guarantee reliable standalone export loading without DirAccess scanning.
const TRACKS: Dictionary = {
	"bgm_menu": preload("res://assets/audio/music/bgm_menu.mp3"),
	"waves 1-5": preload("res://assets/audio/music/Waves 1–5.mp3"),
	"waves 6-10": preload("res://assets/audio/music/Waves 6–10.mp3"),
	"waves 11-15": preload("res://assets/audio/music/Waves 11–15.mp3"),
	"waves 16-20": preload("res://assets/audio/music/Waves 16–20.mp3"),
	"waves 21-25": preload("res://assets/audio/music/Waves 21–25.mp3"),
	"titan_anomaly": preload("res://assets/audio/music/Titan Anomaly.mp3"),
	"ending": preload("res://assets/audio/music/ending.mp3")
}

# SFX Player Pool
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_player_index: int = 0

# Dual BGM Crossfade Players (Bus: "Music")
var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _active_bgm_slot: int = 0 # 0 -> A, 1 -> B
var _current_stream: AudioStream = null
var _current_track_name: String = ""
var _crossfade_tween: Tween = null

# Music Cache & State
var _music_cache: Dictionary = {}
var _alias_map: Dictionary = {}
var _current_wave: int = 1
var _is_boss_active: bool = false

# Procedural SFX Streams
var snd_laser: AudioStreamWAV
var snd_hit: AudioStreamWAV
var snd_coin: AudioStreamWAV
var snd_perk: AudioStreamWAV
var snd_alarm: AudioStreamWAV
var snd_wave: AudioStreamWAV
var snd_boss_warning: AudioStreamWAV
var snd_boss_spawn: AudioStreamWAV
var snd_boss_defeat: AudioStreamWAV
var snd_emp_blast: AudioStreamWAV
var snd_super: AudioStreamWAV
var snd_shoot: AudioStreamWAV
var snd_boom: AudioStreamWAV
var snd_upgrade: AudioStreamWAV
var snd_build: AudioStreamWAV
var snd_card_pick: AudioStreamWAV
var snd_ui_click: AudioStreamWAV

# SFX Dictionary for string-based play_sfx lookups
var _sfx_dict: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_setup_sfx_pool()
	_setup_bgm_players()
	_synthesize_sfx()
	_load_music_library()
	_setup_event_listeners()


func _setup_audio_buses() -> void:
	# Guarantee dedicated SFX and Music buses exist in AudioServer
	if AudioServer.get_bus_index("Music") == -1:
		var music_idx: int = AudioServer.bus_count
		AudioServer.add_bus(music_idx)
		AudioServer.set_bus_name(music_idx, "Music")
		AudioServer.set_bus_send(music_idx, "Master")
	
	if AudioServer.get_bus_index("SFX") == -1:
		var sfx_idx: int = AudioServer.bus_count
		AudioServer.add_bus(sfx_idx)
		AudioServer.set_bus_name(sfx_idx, "SFX")
		AudioServer.set_bus_send(sfx_idx, "Master")
	
	_apply_initial_bus_volumes()


func _apply_initial_bus_volumes() -> void:
	# Synchronize bus volumes from SaveManager settings on startup and ensure buses are not muted/-80dB
	var master_vol: float = 1.0
	var music_vol: float = 0.7
	var sfx_vol: float = 0.8
	
	if SaveManager:
		master_vol = SaveManager.master_volume
		music_vol = SaveManager.music_volume
		sfx_vol = SaveManager.sfx_volume
	
	var master_idx: int = AudioServer.get_bus_index("Master")
	if master_idx != -1:
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(maxf(0.0001, master_vol)))
		AudioServer.set_bus_mute(master_idx, master_vol <= 0.001)
	
	var music_idx: int = AudioServer.get_bus_index("Music")
	if music_idx != -1:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(maxf(0.0001, music_vol)))
		AudioServer.set_bus_mute(music_idx, music_vol <= 0.001)
	
	var sfx_idx: int = AudioServer.get_bus_index("SFX")
	if sfx_idx != -1:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(maxf(0.0001, sfx_vol)))
		AudioServer.set_bus_mute(sfx_idx, sfx_vol <= 0.001)


func _setup_sfx_pool() -> void:
	for i in range(MAX_SFX_PLAYERS):
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		p.name = "SFXPlayer_%d" % i
		p.bus = "SFX"
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_sfx_players.append(p)


func _setup_bgm_players() -> void:
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.name = "BGMPlayer_A"
	_bgm_player_a.bus = "Music"
	_bgm_player_a.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player_a.volume_db = -80.0
	add_child(_bgm_player_a)
	
	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.name = "BGMPlayer_B"
	_bgm_player_b.bus = "Music"
	_bgm_player_b.process_mode = Node.PROCESS_MODE_ALWAYS
	_bgm_player_b.volume_db = -80.0
	add_child(_bgm_player_b)


func _load_music_library() -> void:
	_music_cache.clear()
	
	# Load preloaded tracks into cache with loop enabled
	for raw_key: String in TRACKS:
		var stream: AudioStream = TRACKS[raw_key] as AudioStream
		if stream:
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			var clean_name: String = _clean_key(raw_key)
			_music_cache[clean_name] = stream
			_music_cache[raw_key] = stream
	
	# Pre-register common aliases for fast resilient lookups
	_alias_map["menu"] = "bgm menu"
	_alias_map["bgm_menu"] = "bgm menu"
	_alias_map["bgm menu"] = "bgm menu"
	_alias_map["main_menu"] = "bgm menu"
	_alias_map["title"] = "bgm menu"
	
	_alias_map["1-5"] = "waves 1-5"
	_alias_map["wave 1-5"] = "waves 1-5"
	_alias_map["waves 1-5"] = "waves 1-5"
	_alias_map["waves 1–5"] = "waves 1-5"
	_alias_map["ambient"] = "waves 1-5"
	_alias_map["combat"] = "waves 1-5"
	
	_alias_map["6-10"] = "waves 6-10"
	_alias_map["wave 6-10"] = "waves 6-10"
	_alias_map["waves 6-10"] = "waves 6-10"
	_alias_map["waves 6–10"] = "waves 6-10"
	
	_alias_map["11-15"] = "waves 11-15"
	_alias_map["wave 11-15"] = "waves 11-15"
	_alias_map["waves 11-15"] = "waves 11-15"
	_alias_map["waves 11–15"] = "waves 11-15"
	
	_alias_map["16-20"] = "waves 16-20"
	_alias_map["wave 16-20"] = "waves 16-20"
	_alias_map["waves 16-20"] = "waves 16-20"
	_alias_map["waves 16–20"] = "waves 16-20"
	
	_alias_map["21-25"] = "waves 21-25"
	_alias_map["wave 21-25"] = "waves 21-25"
	_alias_map["waves 21-25"] = "waves 21-25"
	_alias_map["waves 21–25"] = "waves 21-25"
	
	_alias_map["titan"] = "titan anomaly"
	_alias_map["boss"] = "titan anomaly"
	_alias_map["titan anomaly"] = "titan anomaly"
	_alias_map["titan_anomaly"] = "titan anomaly"
	
	_alias_map["ending"] = "ending"
	_alias_map["victory"] = "ending"
	_alias_map["defeat"] = "ending"
	_alias_map["game_over"] = "ending"
	_alias_map["game over"] = "ending"


func _clean_key(raw_name: String) -> String:
	var s: String = raw_name.to_lower()
	s = s.replace("\u2013", "-").replace("\u2014", "-") # Normalize en-dash/em-dash to standard hyphen
	s = s.replace(".mp3", "").replace(".ogg", "").replace(".wav", "")
	s = s.replace("_", " ").strip_edges()
	while s.contains("  "):
		s = s.replace("  ", " ")
	return s


func _setup_event_listeners() -> void:
	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.enemy_damaged.connect(_on_enemy_damaged)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.currency_changed.connect(_on_currency_changed)
	EventBus.perks_updated.connect(_on_perks_updated)
	EventBus.core_damaged.connect(_on_core_damaged)
	EventBus.super_ability_activated.connect(_on_super_ability_activated)
	EventBus.card_draft_completed.connect(_on_card_draft_completed)
	
	# Music state transitions
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.victory_reached.connect(_on_victory_reached)
	EventBus.game_over.connect(_on_game_over)
	EventBus.run_started.connect(_on_run_started)


# --- Crossfade Dynamic Music System ---

## Play an audio stream with a smooth crossfade transition.
func play_bgm(stream: AudioStream, fade_duration: float = 1.2) -> void:
	if not stream:
		return
	
	var active_player: AudioStreamPlayer = _bgm_player_a if _active_bgm_slot == 0 else _bgm_player_b
	var incoming_player: AudioStreamPlayer = _bgm_player_b if _active_bgm_slot == 0 else _bgm_player_a
	
	# If already playing this stream on the active player, do not interrupt
	if _current_stream == stream and active_player.playing:
		return
	
	_current_stream = stream
	
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	
	incoming_player.stream = stream
	incoming_player.volume_db = -80.0
	incoming_player.play()
	
	_crossfade_tween = create_tween()
	_crossfade_tween.set_parallel(true)
	
	if active_player.playing:
		_crossfade_tween.tween_property(active_player, "volume_db", -80.0, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	_crossfade_tween.tween_property(incoming_player, "volume_db", DEFAULT_BGM_VOLUME_DB, fade_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	var old_player: AudioStreamPlayer = active_player
	_crossfade_tween.chain().tween_callback(func() -> void:
		if is_instance_valid(old_player) and old_player != incoming_player:
			old_player.stop()
	)
	
	_active_bgm_slot = 1 if _active_bgm_slot == 0 else 0


## Play a music track by name, alias, or wave string.
func play_track_by_name(track_name: String, fade_duration: float = 1.2) -> void:
	var key: String = _clean_key(track_name)
	if _alias_map.has(key):
		key = _alias_map[key]
	
	var stream: AudioStream = _music_cache.get(key)
	if not stream:
		# Substring search fallback
		for cached_key: String in _music_cache:
			if cached_key.contains(key) or key.contains(cached_key):
				stream = _music_cache[cached_key]
				break
	
	if stream:
		_current_track_name = key
		play_bgm(stream, fade_duration)
	else:
		push_warning("AudioManager: Track '%s' (cleaned: '%s') not found in music cache." % [track_name, key])


## Return the canonical track name for a given wave number.
func get_track_for_wave(wave: int) -> String:
	if wave <= 5:
		return "waves 1-5"
	elif wave <= 10:
		return "waves 6-10"
	elif wave <= 15:
		return "waves 11-15"
	elif wave <= 20:
		return "waves 16-20"
	else:
		return "waves 21-25"


## Transition music to the track appropriate for the current wave tier.
func play_wave_music(wave: int, fade_duration: float = 1.2) -> void:
	_current_wave = wave
	if _is_boss_active:
		return
	var track: String = get_track_for_wave(wave)
	play_track_by_name(track, fade_duration)


## Transition to Main Menu BGM.
func play_menu_music(fade_duration: float = 1.2) -> void:
	_is_boss_active = false
	play_track_by_name("bgm menu", fade_duration)


## Transition to Titan Anomaly Boss BGM.
func play_boss_music(fade_duration: float = 0.8) -> void:
	play_track_by_name("titan anomaly", fade_duration)


## Transition to Ending / Victory / Game Over BGM.
func play_ending_music(fade_duration: float = 1.5) -> void:
	_is_boss_active = false
	play_track_by_name("ending", fade_duration)


## Fade out and stop all BGM playback.
func stop_bgm(fade_duration: float = 1.0) -> void:
	_current_stream = null
	_current_track_name = ""
	var active_player: AudioStreamPlayer = _bgm_player_a if _active_bgm_slot == 0 else _bgm_player_b
	if _crossfade_tween and _crossfade_tween.is_valid():
		_crossfade_tween.kill()
	
	if active_player.playing:
		_crossfade_tween = create_tween()
		_crossfade_tween.tween_property(active_player, "volume_db", -80.0, fade_duration)
		_crossfade_tween.tween_callback(func() -> void:
			if is_instance_valid(active_player):
				active_player.stop()
		)


# --- SFX Playback ---

## Play a sound effect safely by name with pitch range vector (e.g. Vector2(0.9, 1.1)) and safe fallback.
func play_sfx(sound_name: String, pitch_range: Vector2 = Vector2.ONE, volume_db: float = -6.0) -> void:
	var key: String = sound_name.to_lower().strip_edges()
	var stream: AudioStreamWAV = _sfx_dict.get(key) as AudioStreamWAV
	if not stream:
		stream = snd_ui_click
	if not stream:
		return
	
	var pitch: float = 1.0
	if pitch_range != Vector2.ONE and (pitch_range.x != pitch_range.y):
		pitch = randf_range(minf(pitch_range.x, pitch_range.y), maxf(pitch_range.x, pitch_range.y))
	elif pitch_range.x != 1.0:
		pitch = pitch_range.x
		
	_play_stream_on_pool(stream, pitch, volume_db)


## Play an audio stream through the round-robin SFX pool with safe guards.
func play_sound(stream: AudioStreamWAV, pitch_random: float = 0.06, volume_db: float = -6.0) -> void:
	if not stream:
		return
	var pitch: float = 1.0 + randf_range(-pitch_random, pitch_random)
	_play_stream_on_pool(stream, pitch, volume_db)


func _play_stream_on_pool(stream: AudioStream, pitch: float, volume_db: float) -> void:
	if not stream or _sfx_players.is_empty():
		return
	
	var player: AudioStreamPlayer = _sfx_players[_sfx_player_index]
	_sfx_player_index = (_sfx_player_index + 1) % _sfx_players.size()
	
	if is_instance_valid(player):
		player.stream = stream
		player.volume_db = volume_db
		player.pitch_scale = clampf(pitch, 0.1, 4.0)
		player.play()


# --- Sound Synthesizers ---

func _synthesize_sfx() -> void:
	snd_laser = _synth_laser()
	snd_shoot = snd_laser
	snd_hit = _synth_hit()
	snd_coin = _synth_coin()
	snd_perk = _synth_perk()
	snd_alarm = _synth_alarm()
	snd_wave = _synth_wave()
	snd_boss_warning = _synth_boss_warning()
	snd_boss_spawn = snd_boss_warning
	snd_boss_defeat = _synth_boss_defeat()
	snd_emp_blast = _synth_emp_blast()
	snd_super = snd_emp_blast
	snd_boom = _synth_boom()
	snd_upgrade = _synth_upgrade()
	snd_build = _synth_build()
	snd_card_pick = _synth_card_pick()
	snd_ui_click = _synth_ui_click()

	_sfx_dict = {
		"laser": snd_laser,
		"shoot": snd_shoot,
		"hit": snd_hit,
		"coin": snd_coin,
		"perk": snd_perk,
		"alarm": snd_alarm,
		"wave": snd_wave,
		"boss_warning": snd_boss_warning,
		"boss_spawn": snd_boss_spawn,
		"boss_defeat": snd_boss_defeat,
		"emp_blast": snd_emp_blast,
		"emp": snd_emp_blast,
		"super": snd_super,
		"boom": snd_boom,
		"explosion": snd_boom,
		"upgrade": snd_upgrade,
		"build": snd_build,
		"card_pick": snd_card_pick,
		"card": snd_card_pick,
		"ui_click": snd_ui_click,
		"click": snd_ui_click
	}


func _synth_laser() -> AudioStreamWAV:
	var duration: float = 0.09
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = lerpf(900.0, 180.0, t * t)
		var envelope: float = 1.0 - t
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.4
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_hit() -> AudioStreamWAV:
	var duration: float = 0.06
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var envelope: float = (1.0 - t) * (1.0 - t)
		var sample_val: float = (randf() * 2.0 - 1.0) * 0.35 * envelope + sin(t * 220.0 * TAU) * 0.25 * envelope
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_coin() -> AudioStreamWAV:
	var duration: float = 0.14
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = 987.77 if t < 0.5 else 1318.51
		var envelope: float = 1.0 - t
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.35
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_perk() -> AudioStreamWAV:
	var duration: float = 0.32
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	var freqs: Array[float] = [523.25, 659.25, 783.99, 1046.50]
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var note_idx: int = mini(int(t * 4.0), 3)
		var freq: float = freqs[note_idx]
		var sub_t: float = fmod(t * 4.0, 1.0)
		var envelope: float = (1.0 - sub_t) * (1.0 - t * 0.5)
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.4
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_alarm() -> AudioStreamWAV:
	var duration: float = 0.22
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = 440.0 + sin(t * 24.0) * 80.0
		var envelope: float = 1.0 - t
		var sample_val: float = (sin(t * freq * TAU) + (1.0 if sin(t * freq * TAU) > 0.0 else -1.0) * 0.3) * envelope * 0.4
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_wave() -> AudioStreamWAV:
	var duration: float = 0.25
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = lerpf(220.0, 660.0, sqrt(t))
		var envelope: float = sin(t * PI)
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.35
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_boss_warning() -> AudioStreamWAV:
	var duration: float = 0.65
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = 140.0 + sin(t * 30.0) * 40.0
		var envelope: float = 1.0 - t * 0.3
		var sample_val: float = (sin(t * freq * TAU) + (1.0 if sin(t * freq * TAU) > 0.0 else -1.0) * 0.4) * envelope * 0.45
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_boss_defeat() -> AudioStreamWAV:
	var duration: float = 0.8
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var envelope: float = 1.0 - t
		var noise: float = (randf() * 2.0 - 1.0) * envelope * 0.5
		var low_boom: float = sin(t * (120.0 - t * 60.0) * TAU) * envelope * 0.5
		var sample_val: float = noise + low_boom
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_emp_blast() -> AudioStreamWAV:
	var duration: float = 0.55
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = lerpf(360.0, 45.0, t * t)
		var envelope: float = (1.0 - t) * (1.0 - t)
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.6 + (randf() * 2.0 - 1.0) * 0.25 * envelope
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_card_pick() -> AudioStreamWAV:
	var duration: float = 0.2
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = 880.0 if t < 0.5 else 1760.0
		var envelope: float = 1.0 - t
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.35
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_ui_click() -> AudioStreamWAV:
	var duration: float = 0.04
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var envelope: float = 1.0 - t
		var sample_val: float = sin(t * 1400.0 * TAU) * envelope * 0.25
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_boom() -> AudioStreamWAV:
	var duration: float = 0.55
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var envelope: float = (1.0 - t) * (1.0 - t)
		var noise: float = (randf() * 2.0 - 1.0) * envelope * 0.45
		var low_boom: float = sin(t * lerpf(140.0, 35.0, t) * TAU) * envelope * 0.55
		var sample_val: float = noise + low_boom
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_upgrade() -> AudioStreamWAV:
	var duration: float = 0.28
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	var freqs: Array[float] = [440.0, 554.37, 659.25, 880.0]
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var note_idx: int = mini(int(t * 4.0), 3)
		var freq: float = freqs[note_idx]
		var sub_t: float = fmod(t * 4.0, 1.0)
		var envelope: float = (1.0 - sub_t) * (1.0 - t * 0.4)
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.38
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


func _synth_build() -> AudioStreamWAV:
	var duration: float = 0.12
	var samples: int = int(MIX_RATE * duration)
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t: float = float(i) / float(samples)
		var freq: float = lerpf(300.0, 750.0, t)
		var envelope: float = 1.0 - t
		var sample_val: float = sin(t * freq * TAU) * envelope * 0.35
		var int16_val: int = int(clampf(sample_val, -1.0, 1.0) * 32767.0)
		data.encode_s16(i * 2, int16_val)
	
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav


# --- Signal Listeners ---

func _on_tower_fired(_tower: Node, _target: Node) -> void:
	play_sound(snd_laser, 0.08, -8.0)


func _on_enemy_damaged(_enemy: Node, _amount: float, _hp: float) -> void:
	play_sound(snd_hit, 0.1, -10.0)


func _on_enemy_died(_enemy: Node, _bounty: int) -> void:
	play_sound(snd_hit, 0.15, -6.0)


func _on_currency_changed(_new_amount: int, delta: int) -> void:
	if delta < 0:
		play_sound(snd_coin, 0.04, -7.0)


func _on_perks_updated(_perks: Dictionary) -> void:
	play_sound(snd_perk, 0.02, -5.0)


func _on_core_damaged(_hp: float, _max_hp: float) -> void:
	play_sound(snd_alarm, 0.05, -3.0)


func _on_super_ability_activated() -> void:
	play_sound(snd_emp_blast, 0.0, 2.0)


func _on_card_draft_completed(_card: Dictionary) -> void:
	play_sound(snd_card_pick, 0.02, -3.0)


func _on_wave_started(wave: int) -> void:
	play_sound(snd_wave, 0.03, -5.0)
	play_wave_music(wave)


func _on_boss_spawned(_boss: Node) -> void:
	play_sound(snd_boss_warning, 0.0, -2.0)
	_is_boss_active = true
	play_boss_music(0.8)


func _on_boss_defeated(_boss: Node) -> void:
	play_sound(snd_boss_defeat, 0.0, 0.0)
	_is_boss_active = false
	play_wave_music(_current_wave, 1.2)


func _on_victory_reached(_stats: Dictionary) -> void:
	play_ending_music(1.5)


func _on_game_over(_stats: Dictionary) -> void:
	play_ending_music(1.5)


func _on_run_started() -> void:
	_is_boss_active = false
	_current_wave = 1
	play_wave_music(1, 1.2)
