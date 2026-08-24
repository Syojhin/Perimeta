class_name CardDraftModal
extends Control

## In-run roguelite boon drafting interface appearing every 3 waves.

signal card_selected(card_data: Dictionary)

const CARD_POOL: Array[Dictionary] = [
	{
		"id": "chain_overload",
		"name": "Chain Overload",
		"tag": "OFFENSE",
		"color": Color(1.0, 0.8, 0.2, 1.0),
		"desc": "Chain Turret arcs jump to +2 additional enemy targets.",
		"stat_key": "chain_bounces",
		"value": 2.0
	},
	{
		"id": "cryo_shatter",
		"name": "Cryo Shatter",
		"tag": "TACTICAL",
		"color": Color(0.3, 0.85, 1.0, 1.0),
		"desc": "Slowed enemies take +35% increased damage from all sources.",
		"stat_key": "slow_damage_mult",
		"value": 0.35
	},
	{
		"id": "kinetic_velocity",
		"name": "Kinetic Velocity",
		"tag": "OFFENSE",
		"color": Color(1.0, 0.35, 0.45, 1.0),
		"desc": "All turrets gain +25% attack speed for the rest of this run.",
		"stat_key": "attack_speed",
		"value": 0.25
	},
	{
		"id": "bountiful_bits",
		"name": "Bountiful Bits",
		"tag": "ECONOMY",
		"color": Color(0.3, 0.95, 0.6, 1.0),
		"desc": "Defeated enemies award +2 bonus Bits on kill.",
		"stat_key": "bonus_kill_bits",
		"value": 2.0
	},
	{
		"id": "laser_drill",
		"name": "Laser Drill",
		"tag": "CURSOR",
		"color": Color(1.0, 0.9, 0.3, 1.0),
		"desc": "Coin Gun cursor shots deal +50% increased damage.",
		"stat_key": "coin_gun_damage_mult",
		"value": 0.50
	},
	{
		"id": "core_overcharge",
		"name": "Core Overcharge",
		"tag": "SUPER",
		"color": Color(0.4, 0.9, 1.0, 1.0),
		"desc": "Core EMP Super Ability charges +30% faster from all sources.",
		"stat_key": "super_charge_rate",
		"value": 0.30
	},
	{
		"id": "vital_surge",
		"name": "Vital Surge",
		"tag": "DEFENSE",
		"color": Color(0.4, 0.95, 0.5, 1.0),
		"desc": "Increase Max Core HP by +30 and instantly restore +30 Core HP.",
		"stat_key": "max_core_hp",
		"value": 30.0
	},
	{
		"id": "overclock_burst",
		"name": "Overclock Burst",
		"tag": "OFFENSE",
		"color": Color(1.0, 0.4, 0.2, 1.0),
		"desc": "Increase base damage of all placed and future turrets by +20%.",
		"stat_key": "tower_damage",
		"value": 0.20
	},
	{
		"id": "mortar_cluster_shells",
		"name": "Cluster Shells",
		"tag": "MORTAR",
		"color": Color(1.0, 0.45, 0.2, 1.0),
		"desc": "Mortar impacts scatter 3 mini-shrapnel bomblets around the blast zone (dealing 35% damage each).",
		"stat_key": "mortar_cluster_shells",
		"value": 1.0
	},
	{
		"id": "mortar_thermal_napalm",
		"name": "Thermal Napalm",
		"tag": "MORTAR",
		"color": Color(1.0, 0.3, 0.1, 1.0),
		"desc": "Mortar explosions leave a burning hazard puddle for 3.0s, dealing ticking fire damage to passing enemies.",
		"stat_key": "mortar_thermal_napalm",
		"value": 1.0
	},
	{
		"id": "mortar_heavy_ordnance",
		"name": "Heavy Ordnance",
		"tag": "MORTAR",
		"color": Color(1.0, 0.6, 0.15, 1.0),
		"desc": "+40% Mortar blast radius and +25% damage, but -15% fire rate.",
		"stat_key": "mortar_heavy_ordnance",
		"value": 1.0
	},
	{
		"id": "railgun_superconductor",
		"name": "Superconductor",
		"tag": "RAILGUN",
		"color": Color(0.2, 0.9, 1.0, 1.0),
		"desc": "Railgun slugs gain +15% damage for each enemy pierced in a single shot.",
		"stat_key": "railgun_superconductor",
		"value": 0.15
	},
	{
		"id": "railgun_ionized_trail",
		"name": "Ionized Trail",
		"tag": "RAILGUN",
		"color": Color(0.4, 0.7, 1.0, 1.0),
		"desc": "Railgun beams leave an electrified energy beam on the track for 2.0s that shocks crossing enemies.",
		"stat_key": "railgun_ionized_trail",
		"value": 1.0
	},
	{
		"id": "railgun_dual_capacitor",
		"name": "Dual Capacitor",
		"tag": "RAILGUN",
		"color": Color(0.3, 1.0, 0.9, 1.0),
		"desc": "Railgun beam width is doubled (+100% width) and deals +20% damage to Shielded/Armored enemies.",
		"stat_key": "railgun_dual_capacitor",
		"value": 1.0
	},
	{
		"id": "synergy_thermal_shock",
		"name": "Thermal Shock",
		"tag": "SYNERGY",
		"color": Color(0.8, 0.4, 1.0, 1.0),
		"desc": "Enemies slowed or frozen by Cryo turrets take +50% extra explosive damage from Plasma Mortars.",
		"stat_key": "synergy_thermal_shock",
		"value": 0.50
	},
	{
		"id": "synergy_kinetic_overclock",
		"name": "Kinetic Overclock",
		"tag": "SYNERGY",
		"color": Color(1.0, 0.8, 0.3, 1.0),
		"desc": "Railguns and Mortars gain +30% faster attack speed when any Pulse turret is within their range.",
		"stat_key": "synergy_kinetic_overclock",
		"value": 0.30
	}
]

@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer
@onready var card1_node: Control = $CenterContainer/VBoxContainer/CardsContainer/Card1
@onready var card2_node: Control = $CenterContainer/VBoxContainer/CardsContainer/Card2
@onready var card3_node: Control = $CenterContainer/VBoxContainer/CardsContainer/Card3

var _current_options: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if not EventBus.draft_requested.is_connected(_on_draft_requested):
		EventBus.draft_requested.connect(_on_draft_requested)
	if LocalizationManager:
		LocalizationManager.language_changed.connect(_on_language_changed)


func _on_language_changed(_new_lang: String) -> void:
	if visible and _current_options.size() == 3:
		_update_header_labels()
		_populate_card(card1_node, _current_options[0], 0)
		_populate_card(card2_node, _current_options[1], 1)
		_populate_card(card3_node, _current_options[2], 2)


func _on_draft_requested(_wave_number: int = 0) -> void:
	open_draft([])


## Open the draft modal with 3 randomly selected distinct boons and pause combat.
func open_draft(offered_cards: Array[Dictionary] = []) -> void:
	if visible:
		return # Already open, prevent duplicate popups
	
	if offered_cards.is_empty():
		_current_options = _roll_random_cards(3)
	else:
		_current_options = offered_cards
	
	_update_header_labels()
	_populate_card(card1_node, _current_options[0], 0)
	_populate_card(card2_node, _current_options[1], 1)
	_populate_card(card3_node, _current_options[2], 2)
	
	_set_buttons_disabled(false)
	
	visible = true
	get_tree().paused = true
	
	# Animate card entrance
	if cards_container:
		cards_container.modulate = Color(1.0, 1.0, 1.0, 0.0)
		cards_container.scale = Vector2(0.9, 0.9)
		var tween: Tween = create_tween()
		tween.tween_property(cards_container, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(cards_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _update_header_labels() -> void:
	if not LocalizationManager:
		return
	var title_lbl: Label = get_node_or_null("CenterContainer/VBoxContainer/HeaderContainer/HeaderTitle") as Label
	var sub_lbl: Label = get_node_or_null("CenterContainer/VBoxContainer/HeaderContainer/HeaderSubtitle") as Label
	if title_lbl:
		title_lbl.text = LocalizationManager.get_text("DRAFT_TITLE", "// ROGUELITE CARD DRAFT //")
	if sub_lbl:
		sub_lbl.text = LocalizationManager.get_text("DRAFT_SUBTITLE", "SELECT 1 IN-RUN PERIMETER PROTOCOL TO AUGMENT COMBAT")


func _roll_random_cards(count: int) -> Array[Dictionary]:
	var pool_copy: Array[Dictionary] = CARD_POOL.duplicate()
	pool_copy.shuffle()
	var selected: Array[Dictionary] = []
	for i in range(mini(count, pool_copy.size())):
		selected.append(pool_copy[i])
	return selected


func _populate_card(card_node: Control, data: Dictionary, index: int) -> void:
	if not card_node:
		return
	
	var tag_label: Label = card_node.get_node_or_null("Margin/VBox/TagLabel") as Label
	var title_label: Label = card_node.get_node_or_null("Margin/VBox/TitleLabel") as Label
	var desc_label: Label = card_node.get_node_or_null("Margin/VBox/DescLabel") as Label
	var select_button: Button = card_node.get_node_or_null("Margin/VBox/SelectButton") as Button
	
	var accent_color: Color = data.get("color", Color.CYAN)
	var card_id: String = data.get("id", "")
	var card_name: String = LocalizationManager.get_card_name(card_id, data.get("name", "Unknown Boon")) if LocalizationManager else data.get("name", "Unknown Boon")
	var card_desc: String = LocalizationManager.get_card_desc(card_id, data.get("desc", "")) if LocalizationManager else data.get("desc", "")
	var card_tag: String = LocalizationManager.get_card_tag(data.get("tag", "BOON")) if LocalizationManager else data.get("tag", "BOON")
	
	if tag_label:
		tag_label.text = "// " + card_tag
		tag_label.add_theme_color_override("font_color", accent_color)
	
	if title_label:
		title_label.text = card_name
	
	if desc_label:
		desc_label.text = card_desc
	
	if select_button:
		select_button.text = LocalizationManager.get_text("CARD_SELECT", "[ SELECT PROTOCOL ]") if LocalizationManager else "[ SELECT PROTOCOL ]"
		select_button.disabled = false
		for conn in select_button.pressed.get_connections():
			select_button.pressed.disconnect(conn.callable)
		select_button.pressed.connect(func() -> void: _on_card_selected(index))


func _set_buttons_disabled(disabled: bool) -> void:
	for node: Control in [card1_node, card2_node, card3_node]:
		if node:
			var btn: Button = node.get_node_or_null("Margin/VBox/SelectButton") as Button
			if btn:
				btn.disabled = disabled


func _on_card_selected(index: int) -> void:
	if index < 0 or index >= _current_options.size():
		return
	
	# Disable all select buttons immediately to prevent double-click race conditions
	_set_buttons_disabled(true)
	
	var chosen: Dictionary = _current_options[index]
	
	# Apply to run modifiers
	var stat_key: String = chosen.get("stat_key", "")
	var val: float = chosen.get("value", 0.0)
	if not stat_key.is_empty():
		GlobalState.add_run_modifier(stat_key, val)
	
	visible = false
	get_tree().paused = false
	
	EventBus.draft_completed.emit(chosen)
	EventBus.card_draft_completed.emit(chosen)
	card_selected.emit(chosen)
