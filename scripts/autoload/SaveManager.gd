extends Node

## Persistent storage manager for Perimeta. Handles JSON serialization of meta progression and system settings.

const SAVE_PATH: String = "user://perimeta_save.json"

var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.7
var fullscreen: bool = false
var crt_filter_enabled: bool = true
var language: String = "en"


func _ready() -> void:
	load_game()
	
	if not EventBus.meta_cores_changed.is_connected(_on_auto_save_trigger):
		EventBus.meta_cores_changed.connect(_on_auto_save_trigger)
	if not EventBus.perks_updated.is_connected(_on_auto_save_trigger):
		EventBus.perks_updated.connect(_on_auto_save_trigger)
	if not EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.connect(_on_run_ended)


## Save persistent game state to JSON.
func save_game() -> bool:
	var save_data: Dictionary = {
		"meta_cores": GlobalState.meta_cores,
		"unlocked_perks": GlobalState.unlocked_perks,
		"high_score": GlobalState.high_score,
		"highest_wave": GlobalState.highest_wave,
		"total_runs_played": GlobalState.total_runs_played,
		"settings": {
			"master_volume": master_volume,
			"sfx_volume": sfx_volume,
			"music_volume": music_volume,
			"fullscreen": fullscreen,
			"crt_filter_enabled": crt_filter_enabled,
			"language": language
		},
		"save_version": 2
	}
	
	var json_string: String = JSON.stringify(save_data, "\t")
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("SaveManager: Failed to open save file for writing at: " + SAVE_PATH)
		return false
	
	file.store_string(json_string)
	file.close()
	return true


## Load persistent game state from JSON.
func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		push_error("SaveManager: Failed to open save file for reading at: " + SAVE_PATH)
		return false
	
	var json_string: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_error("SaveManager: JSON parse error: " + json.get_error_message())
		return false
	
	var save_data: Variant = json.data
	if not (save_data is Dictionary):
		return false
	
	var data_dict: Dictionary = save_data as Dictionary
	var loaded_cores: int = int(data_dict.get("meta_cores", 0))
	if loaded_cores > 200:
		loaded_cores = 50 # Hard purge & clamp corrupted meta-core balance
	GlobalState.meta_cores = loaded_cores
	GlobalState.unlocked_perks = data_dict.get("unlocked_perks", {})
	GlobalState.high_score = int(data_dict.get("high_score", 0))
	GlobalState.highest_wave = int(data_dict.get("highest_wave", 0))
	GlobalState.total_runs_played = int(data_dict.get("total_runs_played", 0))
	
	var settings: Dictionary = data_dict.get("settings", {})
	master_volume = float(settings.get("master_volume", 1.0))
	sfx_volume = float(settings.get("sfx_volume", 0.8))
	music_volume = float(settings.get("music_volume", 0.7))
	fullscreen = bool(settings.get("fullscreen", false))
	crt_filter_enabled = bool(settings.get("crt_filter_enabled", true))
	language = str(settings.get("language", data_dict.get("language", "en")))
	if LocalizationManager != null and is_instance_valid(LocalizationManager):
		LocalizationManager.current_lang = language
		TranslationServer.set_locale(language)
	
	EventBus.meta_cores_changed.emit(GlobalState.meta_cores, 0)
	EventBus.perks_updated.emit(GlobalState.unlocked_perks)
	return true


## Clear all saved progress and reset to defaults.
func reset_save() -> void:
	GlobalState.meta_cores = 0
	GlobalState.unlocked_perks = {}
	GlobalState.high_score = 0
	GlobalState.highest_wave = 0
	GlobalState.total_runs_played = 0
	
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	
	EventBus.meta_cores_changed.emit(0, 0)
	EventBus.perks_updated.emit({})


func _on_auto_save_trigger(_param1: Variant = null, _param2: Variant = null) -> void:
	save_game()


func _on_run_ended(_victory: bool) -> void:
	save_game()
