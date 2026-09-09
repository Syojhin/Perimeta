class_name CardView
extends Control

## Interactive roguelite boon card view with 4 distinct rarity visual styles and audio feedback.

signal card_selected(card: BoonCardData)

@export var card_data: BoonCardData = null:
	set(value):
		card_data = value
		if is_inside_tree() and card_data:
			update_view()

@onready var panel: PanelContainer = $PanelContainer
@onready var tag_label: Label = $PanelContainer/Margin/VBox/TopRow/TagLabel
@onready var target_badge: Label = $PanelContainer/Margin/VBox/TopRow/TargetBadge
@onready var divider: ColorRect = $PanelContainer/Margin/VBox/Divider
@onready var title_label: Label = $PanelContainer/Margin/VBox/TitleLabel
@onready var req_label: Label = $PanelContainer/Margin/VBox/ReqLabel
@onready var desc_label: Label = $PanelContainer/Margin/VBox/DescLabel
@onready var select_btn: Button = $PanelContainer/Margin/VBox/SelectButton
@onready var chevrons: Control = $PanelContainer/HazardChevrons

var _is_hovered: bool = false
var _pulse_time: float = 0.0
var _base_border_color: Color = Color.WHITE
var _base_style: StyleBoxFlat = null
var _hover_tween: Tween = null


func _exit_tree() -> void:
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()


func _ready() -> void:
	custom_minimum_size = Vector2(280, 360)
	pivot_offset = custom_minimum_size * 0.5
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
	if select_btn:
		select_btn.pressed.connect(_on_select_pressed)
		
	if card_data:
		update_view()


## Re-render the visual presentation, styling, and text of the card.
func update_view() -> void:
	if not card_data:
		return
		
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
	var c_title: String = card_data.title
	var c_desc: String = card_data.description
	if loc_mgr:
		c_title = loc_mgr.call("get_card_name", card_data.card_id, card_data.title)
		c_desc = loc_mgr.call("get_card_desc", card_data.card_id, card_data.description)
		
	if title_label:
		title_label.text = c_title
	if desc_label:
		desc_label.text = c_desc
	if tag_label:
		tag_label.text = card_data.get_rarity_tag()
	
	if target_badge:
		if not card_data.target_tower_id.is_empty():
			target_badge.text = card_data.target_tower_id.replace("_", " ").to_upper()
			target_badge.visible = true
		else:
			target_badge.text = "GLOBAL"
			target_badge.visible = true
		
	if req_label:
		if not card_data.required_tower_id.is_empty():
			req_label.text = "// REQUIRES: " + card_data.required_tower_id.replace("_", " ").to_upper()
			req_label.visible = true
		else:
			req_label.visible = false
			
	if select_btn and loc_mgr:
		select_btn.text = loc_mgr.call("get_text", "CARD_SELECT", "[ SELECT PROTOCOL ]")
		
	_apply_rarity_theme(card_data.rarity)


func _apply_rarity_theme(rarity: int) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var btn_style: StyleBoxFlat = StyleBoxFlat.new()
	var accent: Color = Color.CYAN
	
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	
	match rarity:
		BoonCardData.Rarity.COMMON:
			# Slate grey frame (#0F141C), subtle single-pixel rim, static clean panel, [STANDARD] tag
			style.bg_color = Color("#0F141C")
			style.border_color = Color("#232D3F")
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_right = 6
			style.corner_radius_bottom_left = 6
			
			accent = Color("#5A7290")
			if tag_label: tag_label.add_theme_color_override("font_color", Color("#8FA3BF"))
			if target_badge: target_badge.add_theme_color_override("font_color", Color("#5A7290"))
			
			btn_style.bg_color = Color("#151F2E")
			btn_style.border_color = Color("#2A3B52")
			
			if chevrons: chevrons.visible = false
			set_process(false)
			
		BoonCardData.Rarity.RARE:
			# Chamfered corners, electric-cyan neon border (#00F0FF), subtle scanline theme, [AMPLIFIED] tag
			style.bg_color = Color("#081420")
			style.border_color = Color("#00F0FF")
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 10
			style.corner_radius_top_right = 10
			style.corner_radius_bottom_right = 10
			style.corner_radius_bottom_left = 10
			
			accent = Color("#00F0FF")
			if tag_label: tag_label.add_theme_color_override("font_color", Color("#00F0FF"))
			if target_badge: target_badge.add_theme_color_override("font_color", Color("#00B8D4"))
			
			btn_style.bg_color = Color("#002838")
			btn_style.border_color = Color("#00F0FF")
			
			if chevrons: chevrons.visible = false
			set_process(false)
			
		BoonCardData.Rarity.EPIC:
			# Void purple core (#120824), chromatic magenta border (#D500F9), sine-wave pulsating glow, [EXPERIMENTAL] tag
			style.bg_color = Color("#120824")
			style.border_color = Color("#D500F9")
			style.border_width_left = 2
			style.border_width_top = 2
			style.border_width_right = 2
			style.border_width_bottom = 2
			style.corner_radius_top_left = 8
			style.corner_radius_top_right = 8
			style.corner_radius_bottom_right = 8
			style.corner_radius_bottom_left = 8
			
			accent = Color("#D500F9")
			if tag_label: tag_label.add_theme_color_override("font_color", Color("#EA80FC"))
			if target_badge: target_badge.add_theme_color_override("font_color", Color("#AA00FF"))
			
			btn_style.bg_color = Color("#2C0B48")
			btn_style.border_color = Color("#D500F9")
			
			if chevrons: chevrons.visible = false
			_base_border_color = Color("#D500F9")
			_base_style = style
			set_process(true)
			
		BoonCardData.Rarity.OVERCLOCK:
			# Auric gold casing (#FFD700), hazard chevrons, chromatic glitch border, [! OVERCLOCK !] tag
			style.bg_color = Color("#181204")
			style.border_color = Color("#FFD700")
			style.border_width_left = 3
			style.border_width_top = 3
			style.border_width_right = 3
			style.border_width_bottom = 3
			style.corner_radius_top_left = 6
			style.corner_radius_top_right = 6
			style.corner_radius_bottom_right = 6
			style.corner_radius_bottom_left = 6
			
			accent = Color("#FFD700")
			if tag_label: tag_label.add_theme_color_override("font_color", Color("#FFE040"))
			if target_badge: target_badge.add_theme_color_override("font_color", Color("#FFB300"))
			
			btn_style.bg_color = Color("#4D3800")
			btn_style.border_color = Color("#FFD700")
			
			if chevrons: chevrons.visible = true
			_base_border_color = Color("#FFD700")
			_base_style = style
			set_process(true)
			
	if divider:
		divider.color = accent
	if panel:
		panel.add_theme_stylebox_override("panel", style)
	if select_btn:
		select_btn.add_theme_stylebox_override("normal", btn_style)


func _process(delta: float) -> void:
	if not card_data or not _base_style:
		return
		
	if card_data.rarity == BoonCardData.Rarity.EPIC:
		_pulse_time += delta * 4.0
		var glow: float = (sin(_pulse_time) + 1.0) * 0.5
		var c: Color = _base_border_color
		c.r = lerpf(0.65, 1.0, glow)
		c.b = lerpf(0.75, 1.15, glow)
		_base_style.border_color = c
	elif card_data.rarity == BoonCardData.Rarity.OVERCLOCK:
		_pulse_time += delta * 7.0
		# Chromatic micro-glitch spike
		if fmod(_pulse_time, 2.0) < 0.12:
			_base_style.border_color = Color(1.2, 0.95, 0.3, 1.0)
		else:
			_base_style.border_color = _base_border_color


func _on_mouse_entered() -> void:
	_is_hovered = true
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var audio: Node = get_node_or_null("/root/AudioManager") if is_inside_tree() else null
	if audio and card_data:
		audio.call("play_card_hover", card_data.rarity)


func _on_mouse_exited() -> void:
	_is_hovered = false
	if _hover_tween and _hover_tween.is_valid():
		_hover_tween.kill()
	_hover_tween = create_tween()
	_hover_tween.tween_property(self, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_select_pressed() -> void:
	if card_data:
		card_selected.emit(card_data)
