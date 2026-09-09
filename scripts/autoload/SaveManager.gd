extends Node

## Persistent storage manager for Perimeta. Handles JSON serialization of meta progression and system settings.
## Employs an atomic rename pipeline with rollback backup rotation to guarantee zero save corruption.

const SAVE_PATH: String = "user://perimeta_save.json"
const TEMP_PATH: String = "user://perimeta_save.json.tmp"
const BACKUP_PATH: String = "user://perimeta_save.json.bak"
const CURRENT_SAVE_VERSION: int = 3

var master_volume: float = 1.0
var sfx_volume: float = 0.8
var music_volume: float = 0.7
var fullscreen: bool = false
var crt_filter_enabled: bool = true
var language: String = "en"

var _is_resetting: bool = false


func _ready() -> void:
	load_game()
	
	if not EventBus.meta_cores_changed.is_connected(_on_auto_save_trigger):
		EventBus.meta_cores_changed.connect(_on_auto_save_trigger)
	if not EventBus.perks_updated.is_connected(_on_auto_save_trigger):
		EventBus.perks_updated.connect(_on_auto_save_trigger)
	if not EventBus.run_ended.is_connected(_on_run_ended):
		EventBus.run_ended.connect(_on_run_ended)


## Save persistent game state to JSON via atomic write-and-rename workflow.
func save_game() -> bool:
	if _is_resetting:
		return false
		
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
		"save_version": CURRENT_SAVE_VERSION
	}
	
	var json_string: String = JSON.stringify(save_data, "\t")
	
	# Step 1: Write and flush payload to a temporary file
	var temp_file: FileAccess = FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if not temp_file:
		push_error("SaveManager: Failed to open temp save file for writing at: " + TEMP_PATH)
		return false
	
	temp_file.store_string(json_string)
	temp_file.flush()
	temp_file.close()
	
	# Step 2: Create or rotate a rollback backup from existing valid save
	if FileAccess.file_exists(SAVE_PATH):
		if FileAccess.file_exists(BACKUP_PATH):
			DirAccess.remove_absolute(BACKUP_PATH)
		var copy_err: Error = DirAccess.copy_absolute(SAVE_PATH, BACKUP_PATH)
		if copy_err != OK:
			push_warning("SaveManager: Could not rotate backup save: %d" % copy_err)
	
	# Step 3: Atomic rename .tmp to perimeta_save.json
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		
	var rename_err: Error = DirAccess.rename_absolute(TEMP_PATH, SAVE_PATH)
	if rename_err != OK:
		# Fallback copy if filesystem locks prevented rename
		if DirAccess.copy_absolute(TEMP_PATH, SAVE_PATH) == OK:
			DirAccess.remove_absolute(TEMP_PATH)
			return true
		push_error("SaveManager: Failed to atomically promote temp save to primary: %d" % rename_err)
		return false
	
	return true


## Load persistent game state with schema version verification and backup rollback fallback.
func load_game() -> bool:
	var data_dict: Dictionary = _read_and_parse_save(SAVE_PATH)
	var recovered_from_backup: bool = false
	
	# If primary save is missing or corrupt, attempt recovery from backup
	if data_dict.is_empty() and FileAccess.file_exists(BACKUP_PATH):
		push_warning("SaveManager: Primary save corrupted or absent. Attempting recovery from backup...")
		data_dict = _read_and_parse_save(BACKUP_PATH)
		if not data_dict.is_empty():
			recovered_from_backup = true
	
	if data_dict.is_empty():
		return false
	
	# Schema version check and backwards compatibility migration
	var save_version: int = int(data_dict.get("save_version", 1))
	if save_version < CURRENT_SAVE_VERSION:
		data_dict = _migrate_schema(data_dict, save_version)
	
	_apply_save_data(data_dict)
	
	if recovered_from_backup:
		save_game() # Re-persist clean primary save from restored backup
		
	return true


func _read_and_parse_save(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
		
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
		
	var json_string: String = file.get_as_text()
	file.close()
	
	if json_string.strip_edges().is_empty():
		return {}
		
	var json: JSON = JSON.new()
	var parse_result: Error = json.parse(json_string)
	if parse_result != OK:
		push_warning("SaveManager: JSON parse error in %s: %s" % [path, json.get_error_message()])
		return {}
		
	var save_data: Variant = json.data
	if not (save_data is Dictionary):
		return {}
		
	return save_data as Dictionary


func _migrate_schema(data: Dictionary, old_version: int) -> Dictionary:
	if old_version < 2:
		if not data.has("total_runs_played"):
			data["total_runs_played"] = 0
		if not data.has("settings"):
			data["settings"] = {}
	if old_version < 3:
		if not data.has("unlocked_perks") or not (data["unlocked_perks"] is Dictionary):
			data["unlocked_perks"] = {}
			
	data["save_version"] = CURRENT_SAVE_VERSION
	return data


func _apply_save_data(data_dict: Dictionary) -> void:
	var loaded_cores: int = maxi(0, int(data_dict.get("meta_cores", 0)))
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
	
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
	if loc_mgr:
		loc_mgr.set("current_lang", language)
		TranslationServer.set_locale(language)
	
	EventBus.meta_cores_changed.emit(GlobalState.meta_cores, 0)
	EventBus.perks_updated.emit(GlobalState.unlocked_perks)


## Clear all saved progress and reset to defaults.
func reset_save() -> void:
	_is_resetting = true
	GlobalState.meta_cores = 0
	GlobalState.unlocked_perks = {}
	GlobalState.high_score = 0
	GlobalState.highest_wave = 0
	GlobalState.total_runs_played = 0
	
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	if FileAccess.file_exists(TEMP_PATH):
		DirAccess.remove_absolute(TEMP_PATH)
	if FileAccess.file_exists(BACKUP_PATH):
		DirAccess.remove_absolute(BACKUP_PATH)
	
	EventBus.meta_cores_changed.emit(0, 0)
	EventBus.perks_updated.emit({})
	_is_resetting = false


func _on_auto_save_trigger(_param1: Variant = null, _param2: Variant = null) -> void:
	if not _is_resetting:
		save_game()


func _on_run_ended(_victory: bool) -> void:
	if not _is_resetting:
		save_game()
