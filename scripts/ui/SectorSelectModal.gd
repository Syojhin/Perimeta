class_name SectorSelectModal
extends Control

## Sector selection modal interface displayed from Main Menu.
## Allows selecting Sector 01 (Perimeter), Sector 02 (Spiral Reactor), or Sector 03 (Bifurcated Nexus).
## Displays sector description, socket count (16), and environmental hazard badges.

signal sector_launched(map_data: MapData)
signal closed()

const MAPS_DIR: String = "res://resources/maps/"
const SECTOR_RESOURCES: Array[String] = [
	"res://resources/maps/Sector01_Perimeter.tres",
	"res://resources/maps/Sector02_SpiralReactor.tres",
	"res://resources/maps/Sector03_BifurcatedNexus.tres"
]

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/HeaderTitle
@onready var subtitle_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HeaderContainer/HeaderSubtitle
@onready var cards_container: HBoxContainer = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CardsContainer
@onready var launch_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BottomRow/LaunchButton
@onready var back_btn: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BottomRow/BackButton

var sector_maps: Array[MapData] = []
var selected_index: int = 0
var _card_views: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if launch_btn:
		launch_btn.pressed.connect(_on_launch_pressed)
	if back_btn:
		back_btn.pressed.connect(_on_back_pressed)
		
	_discover_maps()
	_populate_cards()
	_match_initial_selection()
	_update_selection_visuals()
	
	if LocalizationManager:
		LocalizationManager.language_changed.connect(func(_l: String) -> void:
			if visible:
				_update_localization()
		)


func _discover_maps() -> void:
	sector_maps.clear()
	
	# Load verified maps list first
	for res_path: String in SECTOR_RESOURCES:
		if ResourceLoader.exists(res_path):
			var res: Resource = load(res_path)
			if res is MapData and not sector_maps.has(res):
				sector_maps.append(res as MapData)
	
	# Fallback directory scan if any missing
	if sector_maps.size() < 3:
		var dir: DirAccess = DirAccess.open(MAPS_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir() and file_name.ends_with(".tres"):
					var full_path: String = MAPS_DIR + file_name
					var res: Resource = load(full_path)
					if res is MapData and not sector_maps.has(res):
						sector_maps.append(res as MapData)
				file_name = dir.get_next()
			dir.list_dir_end()
	
	# Sort deterministically by map_id
	sector_maps.sort_custom(func(a: MapData, b: MapData) -> bool:
		return a.map_id < b.map_id
	)


func _match_initial_selection() -> void:
	selected_index = 0
	var target_path: String = GlobalState.selected_map_path if GlobalState else ""
	for i in range(sector_maps.size()):
		if sector_maps[i].resource_path == target_path:
			selected_index = i
			break


func _populate_cards() -> void:
	if not cards_container:
		return
		
	for child in cards_container.get_children():
		cards_container.remove_child(child)
		child.queue_free()
		
	_card_views.clear()
	
	for i in range(sector_maps.size()):
		var map_res: MapData = sector_maps[i]
		var card_view: Dictionary = _create_sector_card(map_res, i)
		cards_container.add_child(card_view["panel"])
		_card_views.append(card_view)


func _create_sector_card(map_res: MapData, idx: int) -> Dictionary:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 390)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)
	
	# Sector Header
	var sector_tag: Label = Label.new()
	sector_tag.text = "// SECTOR %02d //" % (idx + 1)
	sector_tag.add_theme_font_size_override("font_size", 12)
	sector_tag.add_theme_color_override("font_color", Color(0.35, 0.75, 1.0, 0.8))
	vbox.add_child(sector_tag)
	
	var name_lbl: Label = Label.new()
	name_lbl.text = map_res.display_name
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 1.0))
	vbox.add_child(name_lbl)
	
	var sep: HSeparator = HSeparator.new()
	vbox.add_child(sep)
	
	# Description
	var desc_lbl: Label = Label.new()
	desc_lbl.text = map_res.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.custom_minimum_size = Vector2(0, 90)
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.78, 0.88, 0.85))
	vbox.add_child(desc_lbl)
	
	# Sockets count badge
	var socket_box: HBoxContainer = HBoxContainer.new()
	var socket_icon_lbl: Label = Label.new()
	socket_icon_lbl.text = "SOCKETS:"
	socket_icon_lbl.add_theme_font_size_override("font_size", 13)
	socket_icon_lbl.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8, 0.9))
	var socket_val_lbl: Label = Label.new()
	socket_val_lbl.text = "%d FORTIFIED" % map_res.socket_transforms.size()
	socket_val_lbl.add_theme_font_size_override("font_size", 13)
	socket_val_lbl.add_theme_color_override("font_color", Color(0.46, 1.0, 0.01, 1.0))
	socket_box.add_child(socket_icon_lbl)
	socket_box.add_child(socket_val_lbl)
	vbox.add_child(socket_box)
	
	# Environmental Hazard Badge
	var hazard_box: HBoxContainer = HBoxContainer.new()
	var hazard_icon_lbl: Label = Label.new()
	hazard_icon_lbl.text = "HAZARD:"
	hazard_icon_lbl.add_theme_font_size_override("font_size", 13)
	hazard_icon_lbl.add_theme_color_override("font_color", Color(0.5, 0.65, 0.8, 0.9))
	
	var hazard_val: String = map_res.hazard_type.to_upper().replace("_", " ")
	if hazard_val.is_empty() or hazard_val == "NONE":
		hazard_val = "NONE"
		
	var hazard_val_lbl: Label = Label.new()
	hazard_val_lbl.text = hazard_val
	hazard_val_lbl.add_theme_font_size_override("font_size", 13)
	
	var hazard_color: Color = Color(0.7, 0.8, 0.9, 0.8)
	if hazard_val == "IONIZED TRAIL":
		hazard_color = Color(0.0, 0.94, 1.0, 1.0)
	elif hazard_val == "NAPALM":
		hazard_color = Color(1.0, 0.42, 0.17, 1.0)
	else:
		hazard_color = Color(0.46, 1.0, 0.01, 0.8)
	hazard_val_lbl.add_theme_color_override("font_color", hazard_color)
	
	hazard_box.add_child(hazard_icon_lbl)
	hazard_box.add_child(hazard_val_lbl)
	vbox.add_child(hazard_box)
	
	# Spacer
	var spacer: Control = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Select Sector Button
	var select_btn: Button = Button.new()
	select_btn.text = "[ SELECT SECTOR ]"
	select_btn.custom_minimum_size = Vector2(0, 38)
	select_btn.pressed.connect(func() -> void:
		_select_sector(idx)
	)
	vbox.add_child(select_btn)
	
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_sector(idx)
	)
	
	return {
		"panel": panel,
		"select_btn": select_btn,
		"index": idx,
		"map": map_res
	}


func _select_sector(idx: int) -> void:
	if idx < 0 or idx >= sector_maps.size():
		return
	selected_index = idx
	GlobalState.selected_map_path = sector_maps[selected_index].resource_path
	_update_selection_visuals()
	AudioManager.play_sound(AudioManager.snd_laser, 0.0, 0.8)


func _update_selection_visuals() -> void:
	for i in range(_card_views.size()):
		var entry: Dictionary = _card_views[i]
		var panel: PanelContainer = entry["panel"]
		var btn: Button = entry["select_btn"]
		var is_selected: bool = (i == selected_index)
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.corner_radius_top_left = 6
		style.corner_radius_top_right = 6
		style.corner_radius_bottom_right = 6
		style.corner_radius_bottom_left = 6
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		
		var btn_style: StyleBoxFlat = StyleBoxFlat.new()
		btn_style.corner_radius_top_left = 4
		btn_style.corner_radius_top_right = 4
		btn_style.corner_radius_bottom_right = 4
		btn_style.corner_radius_bottom_left = 4
		
		if is_selected:
			style.bg_color = Color(0.08, 0.16, 0.24, 0.98)
			style.border_color = Color(0.0, 0.94, 1.0, 1.0)
			btn.text = "● ACTIVE SECTOR"
			btn_style.bg_color = Color(0.0, 0.45, 0.65, 1.0)
			btn_style.border_color = Color(0.0, 0.94, 1.0, 1.0)
		else:
			style.bg_color = Color(0.06, 0.08, 0.12, 0.9)
			style.border_color = Color(0.18, 0.28, 0.4, 0.6)
			btn.text = "SELECT SECTOR"
			btn_style.bg_color = Color(0.1, 0.14, 0.2, 0.8)
			btn_style.border_color = Color(0.2, 0.3, 0.42, 0.6)
			
		panel.add_theme_stylebox_override("panel", style)
		btn.add_theme_stylebox_override("normal", btn_style)


func open() -> void:
	_match_initial_selection()
	_update_selection_visuals()
	_update_localization()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _update_localization() -> void:
	if not LocalizationManager:
		return
	if title_label:
		title_label.text = LocalizationManager.get_text("UI_SECTOR_TITLE", "// SECTOR DEPLOYMENT //")
	if subtitle_label:
		subtitle_label.text = LocalizationManager.get_text("UI_SECTOR_SUBTITLE", "SELECT PERIMETER ZONE TO DEFEND")
	if launch_btn:
		launch_btn.text = LocalizationManager.get_text("UI_LAUNCH_SECTOR", "LAUNCH SECTOR")
	if back_btn:
		back_btn.text = LocalizationManager.get_text("UI_BACK", "BACK")


func _on_launch_pressed() -> void:
	if selected_index >= 0 and selected_index < sector_maps.size():
		var chosen_map: MapData = sector_maps[selected_index]
		GlobalState.selected_map_path = chosen_map.resource_path
		sector_launched.emit(chosen_map)
		
	visible = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/combat/Arena.tscn")


func _on_back_pressed() -> void:
	close()
