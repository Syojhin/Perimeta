class_name VictoryModal
extends Control

## Victory celebration modal displayed upon conquering Wave 25.
## Allows the player to bank rewards and return to the Main Menu or engage Endless Overclock mode.
## Includes special developer credits and celebration accent line.

signal endless_mode_selected()

@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/HeaderBox/VictoryTitle
@onready var subtitle_label: Label = $CenterContainer/Panel/Margin/VBox/HeaderBox/VictorySubtitle
@onready var architect_credit: Label = $CenterContainer/Panel/Margin/VBox/HeaderBox/ArchitectCredit
@onready var accent_line: ColorRect = $CenterContainer/Panel/Margin/VBox/HeaderBox/AccentLine

@onready var waves_title: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/WavesLabel
@onready var enemies_title: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/EnemiesLabel
@onready var bits_title: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/BitsLabel
@onready var cores_title: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoresLabel

@onready var waves_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/WavesValue
@onready var enemies_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/EnemiesValue
@onready var bits_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/BitsValue
@onready var cores_bonus_label: Label = $CenterContainer/Panel/Margin/VBox/StatsGrid/CoresValue

@onready var return_btn: Button = $CenterContainer/Panel/Margin/VBox/Buttons/ReturnButton
@onready var endless_btn: Button = $CenterContainer/Panel/Margin/VBox/Buttons/EndlessButton

var _bonus_cores: int = 25
var _has_collected_bonus: bool = false
var _accent_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if return_btn:
		return_btn.pressed.connect(_on_return_pressed)
	if endless_btn:
		endless_btn.pressed.connect(_on_endless_pressed)
	
	EventBus.victory_reached.connect(open_victory)
	if LocalizationManager:
		LocalizationManager.language_changed.connect(func(_l: String) -> void:
			if visible:
				_update_localization()
		)


func _update_localization() -> void:
	if not LocalizationManager:
		return
	if title_label:
		title_label.text = LocalizationManager.get_text("UI_VICTORY_HEADER", "SECTOR SECURED // WAVE 25 CONQUERED")
	if subtitle_label:
		subtitle_label.text = LocalizationManager.get_text("UI_VICTORY_SUBTITLE", "PERIMETER DEFENSES HELD AGAINST ALL HOSTILE FORCES")
	if architect_credit:
		architect_credit.text = LocalizationManager.get_text("UI_VICTORY_DEV_CREDIT", "A GAME BY DAVID BARREIROS (SYOJHIN)")
	if waves_title:
		waves_title.text = LocalizationManager.get_text("UI_WAVES_REACHED", "Waves Cleared:")
	if enemies_title:
		enemies_title.text = LocalizationManager.get_text("UI_ENEMIES_DEFEATED", "Enemies Shredded:")
	if bits_title:
		bits_title.text = LocalizationManager.get_text("UI_BITS_HARVESTED", "Bits Harvested:")
	if cores_title:
		cores_title.text = LocalizationManager.get_text("UI_BONUS_CORES", "Victory Bonus:")
	if return_btn:
		return_btn.text = LocalizationManager.get_text("UI_BANK_CORES", "BANK REWARDS & RETURN")
	if endless_btn:
		endless_btn.text = LocalizationManager.get_text("UI_ENDLESS_MODE", "CONTINUE ENDLESS OVERCLOCK")


func open_victory(_stats: Dictionary = {}) -> void:
	_has_collected_bonus = false
	_update_localization()
	
	if waves_label:
		waves_label.text = "%d / 25" % GlobalState.current_wave
	if enemies_label:
		enemies_label.text = str(GlobalState.enemies_defeated)
	if bits_label:
		bits_label.text = str(GlobalState.run_bits_earned)
	if cores_bonus_label:
		cores_bonus_label.text = "+%d CORES" % _bonus_cores
	
	if accent_line:
		if is_instance_valid(_accent_tween):
			_accent_tween.kill()
		accent_line.modulate = Color(1.0, 1.0, 1.0, 0.4)
		_accent_tween = create_tween().set_loops()
		_accent_tween.tween_property(accent_line, "modulate:a", 1.0, 0.75).set_trans(Tween.TRANS_SINE)
		_accent_tween.tween_property(accent_line, "modulate:a", 0.35, 0.75).set_trans(Tween.TRANS_SINE)
	
	visible = true
	get_tree().paused = true
	AudioManager.play_sound(AudioManager.snd_perk)


func _on_return_pressed() -> void:
	if not _has_collected_bonus:
		GlobalState.meta_cores += _bonus_cores
		_has_collected_bonus = true
	
	if is_instance_valid(_accent_tween):
		_accent_tween.kill()
	
	SaveManager.save_game()
	GlobalState.end_run(true)
	visible = false
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _on_endless_pressed() -> void:
	if not _has_collected_bonus:
		GlobalState.meta_cores += _bonus_cores
		_has_collected_bonus = true
	
	if is_instance_valid(_accent_tween):
		_accent_tween.kill()
	
	SaveManager.save_game()
	endless_mode_selected.emit()
	visible = false
	get_tree().paused = false
