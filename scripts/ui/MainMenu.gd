class_name MainMenu
extends Control

## Main startup menu for Perimeta with animated geometric visuals, localization toggle, navigation, and developer branding.

@onready var start_btn: Button = $CenterContainer/VBoxContainer/Buttons/StartButton
@onready var skill_tree_btn: Button = $CenterContainer/VBoxContainer/Buttons/SkillTreeButton
@onready var settings_btn: Button = $CenterContainer/VBoxContainer/Buttons/SettingsButton
@onready var credits_btn: Button = $CenterContainer/VBoxContainer/Buttons/CreditsButton
@onready var quit_btn: Button = $CenterContainer/VBoxContainer/Buttons/QuitButton
@onready var lang_btn: Button = $LangButton

@onready var subtitle_label: Label = $CenterContainer/VBoxContainer/TitleBox/Subtitle
@onready var stats_label: Label = $CenterContainer/VBoxContainer/StatsLabel
@onready var watermark_label: Label = $DevWatermarkLabel
@onready var skill_tree_modal: SkillTree = $SkillTree
@onready var settings_modal: SettingsModal = $SettingsModal
@onready var credits_modal: Control = $CreditsModal

@onready var bg_poly_outer: Polygon2D = $Background/OuterRing
@onready var bg_poly_inner: Polygon2D = $Background/InnerRing


func _ready() -> void:
	AudioManager.play_menu_music(1.2)
	
	if start_btn:
		start_btn.pressed.connect(_on_start_pressed)
	if skill_tree_btn:
		skill_tree_btn.pressed.connect(_on_skill_tree_pressed)
	if settings_btn:
		settings_btn.pressed.connect(_on_settings_pressed)
	if credits_btn:
		credits_btn.pressed.connect(_on_credits_pressed)
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_pressed)
	if lang_btn:
		lang_btn.pressed.connect(_on_lang_pressed)
	
	if LocalizationManager:
		LocalizationManager.language_changed.connect(_on_language_changed)
	
	_update_localization()
	_update_stats_display()
	EventBus.meta_cores_changed.connect(func(_a: int, _b: int) -> void: _update_stats_display())


func _process(delta: float) -> void:
	if bg_poly_outer:
		bg_poly_outer.rotation += 0.2 * delta
	if bg_poly_inner:
		bg_poly_inner.rotation -= 0.35 * delta


func _on_language_changed(_new_lang: String) -> void:
	_update_localization()
	_update_stats_display()


func _update_localization() -> void:
	if not LocalizationManager:
		return
	if subtitle_label:
		subtitle_label.text = LocalizationManager.get_text("UI_SUBTITLE")
	if start_btn:
		start_btn.text = LocalizationManager.get_text("UI_START_MISSION")
	if skill_tree_btn:
		skill_tree_btn.text = LocalizationManager.get_text("UI_SKILL_TREE")
	if settings_btn:
		settings_btn.text = LocalizationManager.get_text("UI_SETTINGS")
	if credits_btn:
		credits_btn.text = LocalizationManager.get_text("UI_CREDITS", "CREDITS")
	if quit_btn:
		quit_btn.text = LocalizationManager.get_text("UI_QUIT")
	if lang_btn:
		lang_btn.text = LocalizationManager.get_toggle_button_text()
	if watermark_label:
		watermark_label.text = LocalizationManager.get_text("UI_DEV_WATERMARK", "PERIMETA // CREATED & ENGINEERED BY DAVID 'SYOJHIN' BARREIROS")


func _update_stats_display() -> void:
	if stats_label and LocalizationManager:
		var score_txt: String = LocalizationManager.get_text("UI_FINAL_SCORE", "Score:")
		var wave_txt: String = LocalizationManager.get_text("UI_WAVE", "Wave")
		var cores_txt: String = LocalizationManager.get_text("UI_META_CORES", "Meta-Cores")
		stats_label.text = "%s %d   //   MAX %s: %d   //   %s: %d" % [
			score_txt.replace(":", "").to_upper(),
			GlobalState.high_score,
			wave_txt,
			GlobalState.highest_wave,
			cores_txt,
			GlobalState.meta_cores
		]


func _on_lang_pressed() -> void:
	if LocalizationManager:
		LocalizationManager.toggle_language()


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/combat/Arena.tscn")


func _on_skill_tree_pressed() -> void:
	if skill_tree_modal:
		skill_tree_modal.open()


func _on_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open()


func _on_credits_pressed() -> void:
	if credits_modal:
		credits_modal.open()


func _on_quit_pressed() -> void:
	get_tree().quit()
