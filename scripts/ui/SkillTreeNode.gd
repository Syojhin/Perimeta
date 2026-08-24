class_name SkillTreeNode
extends Control

## Interactive node representation for a perk inside Perimeta's DAG Skill Tree.

signal upgrade_requested(perk_id: String)

@export var perk_id: String = ""

@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/TitleLabel
@onready var level_label: Label = $PanelContainer/MarginContainer/VBoxContainer/Header/LevelLabel
@onready var desc_label: Label = $PanelContainer/MarginContainer/VBoxContainer/DescLabel
@onready var upgrade_button: Button = $PanelContainer/MarginContainer/VBoxContainer/UpgradeButton


func _ready() -> void:
	if upgrade_button:
		upgrade_button.pressed.connect(_on_upgrade_button_pressed)
	refresh()


## Update node visuals, level indicators, and upgrade button state.
func refresh() -> void:
	if perk_id.is_empty() or not StatModifier.PERK_DEFINITIONS.has(perk_id):
		return
	
	var perk_data: Dictionary = StatModifier.PERK_DEFINITIONS[perk_id]
	var current_level: int = GlobalState.get_perk_level(perk_id)
	var max_level: int = perk_data.get("max_level", 1)
	var is_maxed: bool = current_level >= max_level
	var cost: int = StatModifier.get_upgrade_cost(perk_id, current_level)
	var can_unlock: bool = StatModifier.can_unlock_perk(perk_id, GlobalState.unlocked_perks, GlobalState.meta_cores)
	
	if title_label:
		title_label.text = LocalizationManager.get_perk_name(perk_id, perk_data.get("name", perk_id)) if LocalizationManager else perk_data.get("name", perk_id)
	
	if level_label:
		var lvl_fmt: String = LocalizationManager.get_text("PERK_LVL_FMT", "LVL %d / %d") if LocalizationManager else "LVL %d / %d"
		level_label.text = lvl_fmt % [current_level, max_level]
		if is_maxed:
			level_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3, 1.0))
		elif current_level > 0:
			level_label.add_theme_color_override("font_color", Color(0.3, 0.9, 1.0, 1.0))
		else:
			level_label.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75, 1.0))
	
	if desc_label:
		desc_label.text = LocalizationManager.get_perk_desc(perk_id, perk_data.get("description", "")) if LocalizationManager else perk_data.get("description", "")
	
	if upgrade_button:
		if is_maxed:
			upgrade_button.text = LocalizationManager.get_text("PERK_MAX_LEVEL", "MAX LEVEL") if LocalizationManager else "MAX LEVEL"
			upgrade_button.disabled = true
		elif not can_unlock:
			var prereq: String = perk_data.get("prerequisite", "")
			if not prereq.is_empty() and GlobalState.get_perk_level(prereq) < 1:
				var raw_prereq_name: String = StatModifier.PERK_DEFINITIONS.get(prereq, {}).get("name", prereq)
				var prereq_name: String = LocalizationManager.get_perk_name(prereq, raw_prereq_name) if LocalizationManager else raw_prereq_name
				var req_fmt: String = LocalizationManager.get_text("PERK_REQ", "REQ: %s") if LocalizationManager else "REQ: %s"
				upgrade_button.text = req_fmt % prereq_name
			else:
				var cores_fmt: String = LocalizationManager.get_text("PERK_CORES_FMT", "%d CORES") if LocalizationManager else "%d CORES"
				upgrade_button.text = cores_fmt % cost
			upgrade_button.disabled = true
		else:
			var unlock_fmt: String = LocalizationManager.get_text("PERK_UNLOCK", "UNLOCK (%d CORES)") if LocalizationManager else "UNLOCK (%d CORES)"
			upgrade_button.text = unlock_fmt % cost
			upgrade_button.disabled = false


func _on_upgrade_button_pressed() -> void:
	upgrade_requested.emit(perk_id)
