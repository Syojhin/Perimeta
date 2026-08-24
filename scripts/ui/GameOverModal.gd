class_name GameOverModal
extends Control

## Modal displaying run summary stats, Meta-Cores earned, and transition buttons with full bilingual localization.

signal restart_requested()
signal open_skill_tree_requested()

@onready var header_label: Label = $PanelContainer/MarginContainer/VBoxContainer/HeaderLabel
@onready var wave_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/WaveLabel
@onready var enemies_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/EnemiesLabel
@onready var score_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/ScoreLabel
@onready var bits_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/BitsLabel
@onready var cores_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/CoresLabel
@onready var total_cores_label: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/TotalCoresLabel

@onready var wave_val: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/WaveVal
@onready var enemies_val: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/EnemiesVal
@onready var score_val: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/ScoreVal
@onready var bits_val: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/BitsVal
@onready var cores_awarded_val: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/CoresVal
@onready var total_cores_val: Label = $PanelContainer/MarginContainer/VBoxContainer/StatsGrid/TotalCoresVal

@onready var skill_tree_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonHBox/SkillTreeButton
@onready var restart_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/ButtonHBox/RestartButton

var _cached_stats: Dictionary = {}


func _ready() -> void:
	if skill_tree_btn:
		skill_tree_btn.pressed.connect(_on_skill_tree_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_restart_pressed)
	
	EventBus.game_over.connect(_on_game_over)
	if LocalizationManager:
		LocalizationManager.language_changed.connect(func(_l: String) -> void:
			if visible:
				_update_localization()
		)
	hide()


func _update_localization() -> void:
	if not LocalizationManager:
		return
	if header_label:
		header_label.text = LocalizationManager.get_text("UI_DEFEAT_HEADER", "CORE BREACH // RUN TERMINATED")
	if wave_label:
		wave_label.text = LocalizationManager.get_text("UI_WAVES_REACHED", "Waves Reached:")
	if enemies_label:
		enemies_label.text = LocalizationManager.get_text("UI_ENEMIES_DEFEATED", "Enemies Defeated:")
	if score_label:
		score_label.text = LocalizationManager.get_text("UI_FINAL_SCORE", "Final Score:")
	if bits_label:
		bits_label.text = LocalizationManager.get_text("UI_BITS_HARVESTED", "Bits Harvested:")
	if cores_label:
		cores_label.text = LocalizationManager.get_text("UI_CORES_AWARDED", "Meta-Cores Awarded:")
	if total_cores_label:
		total_cores_label.text = LocalizationManager.get_text("UI_TOTAL_CORES", "Total Meta-Cores:")
	if skill_tree_btn:
		skill_tree_btn.text = LocalizationManager.get_text("UI_SKILL_TREE", "META UPGRADES")
	if restart_btn:
		restart_btn.text = LocalizationManager.get_text("UI_RESTART_RUN", "RESTART RUN")


## Populate run statistics and display modal.
func display_stats(stats: Dictionary) -> void:
	_cached_stats = stats
	_update_localization()
	
	if wave_val:
		wave_val.text = str(stats.get("wave", 0))
	if enemies_val:
		enemies_val.text = str(stats.get("enemies_defeated", 0))
	if score_val:
		score_val.text = str(stats.get("score", 0))
	if bits_val:
		bits_val.text = str(stats.get("bits_earned", 0))
	if cores_awarded_val:
		cores_awarded_val.text = "+%d" % int(stats.get("meta_cores_awarded", 0))
	if total_cores_val:
		total_cores_val.text = str(stats.get("total_meta_cores", GlobalState.meta_cores))
	
	show()


func _on_game_over(stats: Dictionary) -> void:
	display_stats(stats)


func _on_skill_tree_pressed() -> void:
	hide()
	open_skill_tree_requested.emit()


func _on_restart_pressed() -> void:
	hide()
	restart_requested.emit()
