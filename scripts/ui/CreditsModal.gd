class_name CreditsModal
extends Control

## Modal displaying system credits and developer branding for David Barreiros (Syojhin).

signal closed()

@onready var title_label: Label = $CenterContainer/Panel/Margin/VBox/Title
@onready var lead_role_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/LeadRoleLabel
@onready var lead_name_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/LeadNameLabel
@onready var engine_role_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/EngineRoleLabel
@onready var engine_name_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/EngineNameLabel
@onready var audio_role_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/AudioRoleLabel
@onready var audio_name_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/AudioNameLabel
@onready var visuals_role_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/VisualsRoleLabel
@onready var visuals_name_label: Label = $CenterContainer/Panel/Margin/VBox/CreditsGrid/VisualsNameLabel
@onready var close_btn: Button = $CenterContainer/Panel/Margin/VBox/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if close_btn:
		close_btn.pressed.connect(close)
	if LocalizationManager:
		LocalizationManager.language_changed.connect(func(_l: String) -> void:
			_update_localization()
		)
	_update_localization()


func _update_localization() -> void:
	if not LocalizationManager:
		return
	if title_label:
		title_label.text = LocalizationManager.get_text("UI_CREDITS_TITLE", "SYSTEM ARCHITECTURE // CREDITS")
	if lead_role_label:
		lead_role_label.text = LocalizationManager.get_text("UI_CREDITS_LEAD", "Lead Developer & Game Design") + ":"
	if lead_name_label:
		lead_name_label.text = LocalizationManager.get_text("UI_CREDITS_LEAD_VAL", "David Barreiros (Syojhin)")
	if engine_role_label:
		engine_role_label.text = LocalizationManager.get_text("UI_CREDITS_ENGINE", "Core Engine") + ":"
	if audio_role_label:
		audio_role_label.text = LocalizationManager.get_text("UI_CREDITS_AUDIO", "Soundtrack & Audio Engineering") + ":"
	if audio_name_label:
		audio_name_label.text = LocalizationManager.get_text("UI_CREDITS_AUDIO_VAL", "Procedural Synthwave Suite")
	if visuals_role_label:
		visuals_role_label.text = LocalizationManager.get_text("UI_CREDITS_VISUALS", "Visual Architecture & Shaders") + ":"
	if visuals_name_label:
		visuals_name_label.text = LocalizationManager.get_text("UI_CREDITS_VISUALS_VAL", "Vector CRT Matrix Pipeline")
	if close_btn:
		close_btn.text = LocalizationManager.get_text("UI_CREDITS_CLOSE", "CLOSE TERMINAL")


func open() -> void:
	_update_localization()
	visible = true


func close() -> void:
	visible = false
	closed.emit()
