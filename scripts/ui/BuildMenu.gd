class_name BuildMenu
extends Control

## Interactive build, priority control, and upgrade interface positioned dynamically near selected sockets.
## Dynamically discovers and populates turret options from resources/towers/*.tres.

const TOWERS_RESOURCE_DIR: String = "res://resources/towers/"

var target_socket: BuildSocket = null
var _tower_registry: Array[TowerData] = []
var _build_buttons: Array[Button] = []

@onready var panel_container: PanelContainer = $PanelContainer

# Containers
@onready var empty_container: VBoxContainer = $PanelContainer/Margin/VBox/EmptyModeContainer
@onready var occupied_container: VBoxContainer = $PanelContainer/Margin/VBox/OccupiedModeContainer

# Occupied Mode Controls
@onready var title_label: Label = $PanelContainer/Margin/VBox/OccupiedModeContainer/TitleLabel
@onready var stats_label: Label = $PanelContainer/Margin/VBox/OccupiedModeContainer/StatsLabel
@onready var priority_btn: Button = $PanelContainer/Margin/VBox/OccupiedModeContainer/PriorityButton
@onready var upgrade_btn: Button = $PanelContainer/Margin/VBox/OccupiedModeContainer/UpgradeButton
@onready var sell_btn: Button = $PanelContainer/Margin/VBox/OccupiedModeContainer/SellButton

# Common Controls
@onready var close_btn: Button = $PanelContainer/Margin/VBox/CloseButton


func _ready() -> void:
	_load_tower_registry()
	_setup_dynamic_build_buttons()
	
	if priority_btn:
		priority_btn.pressed.connect(_on_priority_pressed)
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)
	if sell_btn:
		sell_btn.pressed.connect(_on_sell_pressed)
	if close_btn:
		close_btn.pressed.connect(close)
	
	EventBus.currency_changed.connect(_on_currency_changed)
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
	if loc_mgr:
		loc_mgr.language_changed.connect(func(_l: String) -> void:
			if visible:
				refresh()
		)
	hide()


## Dynamically discover and load all TowerData .tres resources from resources/towers/.
func _load_tower_registry() -> void:
	_tower_registry.clear()
	var dir: DirAccess = DirAccess.open(TOWERS_RESOURCE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path: String = TOWERS_RESOURCE_DIR + file_name
				var res: Resource = load(full_path)
				if res is TowerData:
					_tower_registry.append(res as TowerData)
			file_name = dir.get_next()
		dir.list_dir_end()
	
	# Order registry by ascending base cost
	_tower_registry.sort_custom(func(a: TowerData, b: TowerData) -> bool:
		return a.base_cost < b.base_cost
	)


## Dynamically populate empty container with buttons for each discovered turret.
func _setup_dynamic_build_buttons() -> void:
	if not empty_container:
		return
		
	var header_label: Label = empty_container.get_node_or_null("HeaderLabel")
	for child in empty_container.get_children():
		if child != header_label:
			child.free()
	_build_buttons.clear()
	
	for data: TowerData in _tower_registry:
		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0, 30)
		btn.add_theme_font_size_override("font_size", 11)
		
		var style: StyleBoxFlat = _create_archetype_style(data.archetype)
		btn.add_theme_stylebox_override("normal", style)
		
		var captured: TowerData = data
		btn.pressed.connect(func() -> void:
			_build_from_data(captured)
		)
		empty_container.add_child(btn)
		_build_buttons.append(btn)


func _create_archetype_style(archetype: String) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	
	match archetype.to_upper():
		"KINETIC":
			style.bg_color = Color(0.1, 0.28, 0.42, 1)
			style.border_color = Color(0.3, 0.8, 1, 0.6)
		"CRYO":
			style.bg_color = Color(0.08, 0.3, 0.38, 1)
			style.border_color = Color(0.4, 0.9, 1, 0.6)
		"ELECTRO":
			style.bg_color = Color(0.35, 0.25, 0.1, 1)
			style.border_color = Color(1, 0.8, 0.3, 0.6)
		"PLASMA":
			style.bg_color = Color(0.32, 0.12, 0.38, 1)
			style.border_color = Color(0.9, 0.3, 1, 0.6)
		"PIERCING":
			style.bg_color = Color(0.08, 0.32, 0.35, 1)
			style.border_color = Color(0.3, 1, 0.9, 0.7)
		"GRAVITY":
			style.bg_color = Color(0.2, 0.08, 0.32, 1)
			style.border_color = Color(0.75, 0.35, 0.95, 0.7)
		"CORROSIVE":
			style.bg_color = Color(0.08, 0.22, 0.12, 1)
			style.border_color = Color(0.4, 1.0, 0.2, 0.7)
		_:
			style.bg_color = Color(0.12, 0.18, 0.26, 1)
			style.border_color = Color(0.4, 0.6, 0.8, 0.6)
			
	return style


## Open and position the build menu adjacent to a specific socket.
func open_for_socket(socket: BuildSocket) -> void:
	if is_instance_valid(target_socket) and target_socket.is_occupied:
		target_socket.current_tower.set_selected(false)
		
	target_socket = socket
	if not is_instance_valid(target_socket):
		hide()
		return
	
	if target_socket.is_occupied:
		target_socket.current_tower.set_selected(true)
	
	_position_menu_near_socket(socket.global_position)
	refresh()
	show()


## Close and hide the build menu.
func close() -> void:
	if is_instance_valid(target_socket) and target_socket.is_occupied:
		target_socket.current_tower.set_selected(false)
	target_socket = null
	hide()


## Refresh menu state, affordability checks, and button labels.
func refresh() -> void:
	if not is_instance_valid(target_socket):
		hide()
		return
	
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
	if close_btn and loc_mgr:
		close_btn.text = loc_mgr.call("get_text", "UI_CLOSE", "CLOSE")
		
	var current_bits: int = GlobalState.run_currency
	
	if target_socket.is_occupied:
		empty_container.visible = false
		occupied_container.visible = true
		
		var tower: TowerBase = target_socket.current_tower
		if is_instance_valid(tower):
			var t_name: String = tower.tower_name
			if loc_mgr:
				if t_name == "Pulse Turret":
					t_name = loc_mgr.call("get_text", "TURRET_PULSE_NAME", t_name)
				elif t_name == "Cryo Turret" or t_name == "Cryo Emitter":
					t_name = loc_mgr.call("get_text", "TURRET_CRYO_NAME", t_name)
				elif t_name == "Chain Turret":
					t_name = loc_mgr.call("get_text", "TURRET_CHAIN_NAME", t_name)
				elif t_name == "Plasma Mortar":
					t_name = loc_mgr.call("get_text", "TURRET_MORTAR_NAME", t_name)
				elif t_name == "Railgun" or t_name == "Railgun Turret":
					t_name = loc_mgr.call("get_text", "TURRET_RAILGUN_NAME", t_name)
			
			if tower.tier >= 5:
				if tower.infusion_level > 0:
					title_label.text = "%s [ T5 MASTER +%d ]" % [t_name.to_upper(), tower.infusion_level]
				else:
					title_label.text = "%s [ T5 MASTER ]" % t_name.to_upper()
			else:
				title_label.text = "%s [ TIER %d/%d ]" % [t_name.to_upper(), tower.tier, tower.max_tier]
			
			stats_label.text = "DMG: %.1f | RNG: %.0f | RATE: %.1f/s" % [tower.damage, tower.attack_range, tower.fire_rate]
			
			if priority_btn:
				var prio_key: String = "TARGET_" + tower.get_target_priority_name().to_upper()
				priority_btn.text = loc_mgr.call("get_text", prio_key, "TARGET: %s" % tower.get_target_priority_name()) if loc_mgr else "TARGET: %s" % tower.get_target_priority_name()
			
			var up_cost: int = tower.get_upgrade_cost()
			var refund: int = tower.get_sell_refund()
			
			if tower.tier >= tower.max_tier:
				# Infinite Overclock Infusion Bit Sink
				var inf_cost: int = tower.get_infusion_cost()
				var inf_fmt: String = loc_mgr.call("get_text", "INFUSION_BTN", "INFUSION +%d (+5%% DMG) [%d B]") if loc_mgr else "INFUSION +%d (+5%% DMG) [%d B]"
				upgrade_btn.text = inf_fmt % [tower.infusion_level + 1, inf_cost]
				upgrade_btn.disabled = current_bits < inf_cost
			elif current_bits < up_cost:
				if tower.tier == 4:
					upgrade_btn.text = (loc_mgr.call("get_text", "UPGRADE_T5", "MASTER T5 (%d BITS)") % up_cost) if loc_mgr else "MASTER T5 (%d BITS)" % up_cost
				else:
					upgrade_btn.text = (loc_mgr.call("get_text", "UPGRADE_TIER_NO_BITS", "UPGRADE T%d (%d BITS)") % [tower.tier + 1, up_cost]) if loc_mgr else "UPGRADE T%d (%d BITS)" % [tower.tier + 1, up_cost]
				upgrade_btn.disabled = true
			else:
				if tower.tier == 4:
					upgrade_btn.text = (loc_mgr.call("get_text", "UPGRADE_T5", "UPGRADE TO MASTER T5 [%d B]") % up_cost) if loc_mgr else "UPGRADE TO MASTER T5 [%d B]" % up_cost
				else:
					upgrade_btn.text = (loc_mgr.call("get_text", "UPGRADE_TIER", "UPGRADE TO T%d (+35%% DMG) [%d B]") % [tower.tier + 1, up_cost]) if loc_mgr else "UPGRADE TO T%d (+35%% DMG) [%d B]" % [tower.tier + 1, up_cost]
				upgrade_btn.disabled = false
			
			sell_btn.text = (loc_mgr.call("get_text", "DECOMMISSION_BTN", "DECOMMISSION (+%d BITS)") % refund) if loc_mgr else "DECOMMISSION (+%d BITS)" % refund
	else:
		empty_container.visible = true
		occupied_container.visible = false
		
		for i in range(_tower_registry.size()):
			if i >= _build_buttons.size():
				break
			var data: TowerData = _tower_registry[i]
			var btn: Button = _build_buttons[i]
			
			var t_name: String = data.display_name
			if loc_mgr:
				var loc_key: String = "TURRET_" + data.tower_id.to_upper().replace("_TURRET", "") + "_NAME"
				if data.tower_id == "plasma_mortar":
					loc_key = "TURRET_MORTAR_NAME"
				t_name = loc_mgr.call("get_text", loc_key, data.display_name)
				
			btn.text = "%s (%d B)" % [t_name.to_upper(), data.base_cost]
			btn.disabled = current_bits < data.base_cost


func _build_from_data(data: TowerData) -> void:
	if not is_instance_valid(target_socket) or target_socket.is_occupied:
		return
		
	var scene: PackedScene = data.get_scene()
	if not scene:
		push_error("BuildMenu: Missing scene for tower %s" % data.tower_id)
		return
		
	if GlobalState.spend_currency(data.base_cost):
		var tower: TowerBase = target_socket.build_tower(scene)
		if is_instance_valid(tower):
			tower.tower_data = data
			tower._apply_tower_data()
		close()


func _on_priority_pressed() -> void:
	if is_instance_valid(target_socket) and target_socket.is_occupied:
		target_socket.current_tower.cycle_target_priority()
		refresh()


func _on_upgrade_pressed() -> void:
	if is_instance_valid(target_socket) and target_socket.is_occupied:
		if target_socket.current_tower.upgrade():
			refresh()


func _on_sell_pressed() -> void:
	if is_instance_valid(target_socket) and target_socket.is_occupied:
		target_socket.current_tower.sell()
		close()


func _position_menu_near_socket(socket_pos: Vector2) -> void:
	var menu_size: Vector2 = Vector2(310, 330)
	var target_pos: Vector2 = socket_pos + Vector2(40, -140)
	
	# Clamp to viewport boundaries
	target_pos.x = clampf(target_pos.x, 80.0, 1920.0 - menu_size.x - 80.0)
	target_pos.y = clampf(target_pos.y, 80.0, 1080.0 - menu_size.y - 80.0)
	
	position = target_pos


func _on_currency_changed(_new_amount: int, _delta: int) -> void:
	if visible:
		refresh()
