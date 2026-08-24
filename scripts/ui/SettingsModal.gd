class_name SettingsModal
extends Control

## Global settings modal for audio levels, fullscreen display, Retro CRT graphics filter, and localization.

signal closed()

@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/Title
@onready var audio_label: Label = $CenterContainer/Panel/Margin/VBox/AudioLabel
@onready var master_label: Label = $CenterContainer/Panel/Margin/VBox/AudioGrid/MasterLabel
@onready var sfx_label: Label = $CenterContainer/Panel/Margin/VBox/AudioGrid/SfxLabel
@onready var music_label: Label = $CenterContainer/Panel/Margin/VBox/AudioGrid/MusicLabel

@onready var master_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioGrid/MasterSlider
@onready var sfx_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioGrid/SfxSlider
@onready var music_slider: HSlider = $CenterContainer/Panel/Margin/VBox/AudioGrid/MusicSlider

@onready var display_label: Label = $CenterContainer/Panel/Margin/VBox/DisplayLabel
@onready var fullscreen_check: CheckBox = $CenterContainer/Panel/Margin/VBox/DisplayGrid/FullscreenCheck
@onready var crt_check: CheckBox = $CenterContainer/Panel/Margin/VBox/DisplayGrid/CRTCheck

@onready var lang_label: Label = $CenterContainer/Panel/Margin/VBox/LangHBox/LangLabel
@onready var lang_btn: Button = $CenterContainer/Panel/Margin/VBox/LangHBox/LangButton

@onready var purge_save_btn: Button = $CenterContainer/Panel/Margin/VBox/PurgeSaveButton
@onready var close_btn: Button = $CenterContainer/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if master_slider:
		master_slider.value = SaveManager.master_volume
		master_slider.value_changed.connect(_on_master_slider_changed)
	if sfx_slider:
		sfx_slider.value = SaveManager.sfx_volume
		sfx_slider.value_changed.connect(_on_sfx_slider_changed)
	if music_slider:
		music_slider.value = SaveManager.music_volume
		music_slider.value_changed.connect(_on_music_slider_changed)
	
	if fullscreen_check:
		fullscreen_check.button_pressed = (DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	
	if crt_check:
		crt_check.button_pressed = SaveManager.crt_filter_enabled
		crt_check.toggled.connect(_on_crt_toggled)
	
	if lang_btn:
		lang_btn.pressed.connect(_on_lang_pressed)
	
	if purge_save_btn:
		purge_save_btn.pressed.connect(_on_purge_save_pressed)
		
	if close_btn:
		close_btn.pressed.connect(close)
	
	if LocalizationManager:
		LocalizationManager.language_changed.connect(_on_language_changed)
	
	_update_localization()
	
	# Apply initial audio & display settings
	_apply_audio_volume("Master", SaveManager.master_volume)
	_apply_audio_volume("SFX", SaveManager.sfx_volume)
	_apply_audio_volume("Music", SaveManager.music_volume)


func _on_language_changed(_new_lang: String) -> void:
	_update_localization()


func _update_localization() -> void:
	if not LocalizationManager:
		return
	if title_label:
		title_label.text = "// %s //" % LocalizationManager.get_text("UI_SETTINGS")
	if audio_label:
		audio_label.text = "%s CONFIGURATION" % LocalizationManager.get_text("UI_AUDIO")
	if master_label:
		master_label.text = LocalizationManager.get_text("UI_MASTER")
	if sfx_label:
		sfx_label.text = LocalizationManager.get_text("UI_SFX")
	if music_label:
		music_label.text = LocalizationManager.get_text("UI_MUSIC")
	if display_label:
		display_label.text = LocalizationManager.get_text("UI_DISPLAY")
	if fullscreen_check:
		fullscreen_check.text = LocalizationManager.get_text("UI_FULLSCREEN")
	if crt_check:
		crt_check.text = LocalizationManager.get_text("UI_CRT_FILTER")
	if lang_label:
		lang_label.text = "Language / Langue:"
	if lang_btn:
		lang_btn.text = LocalizationManager.get_toggle_button_text()
	if purge_save_btn:
		purge_save_btn.text = LocalizationManager.get_text("UI_PURGE_SAVE")
	if close_btn:
		close_btn.text = LocalizationManager.get_text("UI_CLOSE")


func open() -> void:
	if master_slider:
		master_slider.value = SaveManager.master_volume
	if sfx_slider:
		sfx_slider.value = SaveManager.sfx_volume
	if music_slider:
		music_slider.value = SaveManager.music_volume
	if crt_check:
		crt_check.button_pressed = SaveManager.crt_filter_enabled
	_update_localization()
	visible = true


func close() -> void:
	SaveManager.save_game()
	visible = false
	closed.emit()


func _on_lang_pressed() -> void:
	if LocalizationManager:
		LocalizationManager.toggle_language()


func _apply_audio_volume(bus_name: String, value: float) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(0.0001, value)))
		AudioServer.set_bus_mute(bus_idx, value <= 0.001)


func _on_master_slider_changed(value: float) -> void:
	SaveManager.master_volume = value
	_apply_audio_volume("Master", value)


func _on_sfx_slider_changed(value: float) -> void:
	SaveManager.sfx_volume = value
	_apply_audio_volume("SFX", value)


func _on_music_slider_changed(value: float) -> void:
	SaveManager.music_volume = value
	_apply_audio_volume("Music", value)


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	SaveManager.fullscreen = toggled_on
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func _on_crt_toggled(toggled_on: bool) -> void:
	SaveManager.crt_filter_enabled = toggled_on
	var tree: SceneTree = get_tree()
	if tree:
		var crt_node: CanvasItem = tree.root.find_child("CRTOverlay", true, false) as CanvasItem
		if crt_node:
			crt_node.visible = toggled_on


func _on_purge_save_pressed() -> void:
	SaveManager.reset_save()
	if purge_save_btn and LocalizationManager:
		purge_save_btn.text = LocalizationManager.get_text("UI_SAVE_PURGED")
		var tween: Tween = create_tween()
		tween.tween_interval(1.5)
		tween.tween_callback(func() -> void:
			if is_instance_valid(purge_save_btn) and LocalizationManager:
				purge_save_btn.text = LocalizationManager.get_text("UI_PURGE_SAVE")
		)
