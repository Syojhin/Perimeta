class_name BuildMenu
extends Control

## Interactive build, priority control, and upgrade interface positioned dynamically near selected sockets.

const PULSE_SCENE: PackedScene = preload("res://scenes/towers/variants/PulseTurret.tscn")
const CRYO_SCENE: PackedScene = preload("res://scenes/towers/variants/CryoTurret.tscn")
const CHAIN_SCENE: PackedScene = preload("res://scenes/towers/variants/ChainTurret.tscn")
const MORTAR_SCENE: PackedScene = preload("res://scenes/towers/variants/PlasmaMortar.tscn")
const RAILGUN_SCENE: PackedScene = preload("res://scenes/towers/variants/RailgunTurret.tscn")

const COST_PULSE: int = 100
const COST_CRYO: int = 150
const COST_CHAIN: int = 200
const COST_MORTAR: int = 300
const COST_RAILGUN: int = 450

var target_socket: BuildSocket = null

@onready var panel_container: PanelContainer = $PanelContainer

# Containers
@onready var empty_container: VBoxContainer = $PanelContainer/Margin/VBox/EmptyModeContainer
@onready var occupied_container: VBoxContainer = $PanelContainer/Margin/VBox/OccupiedModeContainer

# Empty Mode Controls
@onready var pulse_btn: Button = $PanelContainer/Margin/VBox/EmptyModeContainer/PulseButton
@onready var cryo_btn: Button = $PanelContainer/Margin/VBox/EmptyModeContainer/CryoButton
@onready var chain_btn: Button = $PanelContainer/Margin/VBox/EmptyModeContainer/ChainButton
@onready var mortar_btn: Button = $PanelContainer/Margin/VBox/EmptyModeContainer/MortarButton
@onready var railgun_btn: Button = $PanelContainer/Margin/VBox/EmptyModeContainer/RailgunButton

# Occupied Mode Controls
@onready var title_label: Label = $PanelContainer/Margin/VBox/OccupiedModeContainer/TitleLabel
@onready var stats_label: Label = $PanelContainer/Margin/VBox/OccupiedModeContainer/StatsLabel
@onready var priority_btn: Button = $PanelContainer/Margin/VBox/OccupiedModeContainer/PriorityButton
@onready var upgrade_btn: Button = $PanelContainer/Margin/VBox/OccupiedModeContainer/UpgradeButton
@onready var sell_btn: Button = $PanelContainer/Margin/VBox/OccupiedModeContainer/SellButton

# Common Controls
@onready var close_btn: Button = $PanelContainer/Margin/VBox/CloseButton


func _ready() -> void:
	if pulse_btn:
		pulse_btn.pressed.connect(func() -> void: _build(PULSE_SCENE, COST_PULSE))
	if cryo_btn:
		cryo_btn.pressed.connect(func() -> void: _build(CRYO_SCENE, COST_CRYO))
	if chain_btn:
		chain_btn.pressed.connect(func() -> void: _build(CHAIN_SCENE, COST_CHAIN))
	if mortar_btn:
		mortar_btn.pressed.connect(func() -> void: _build(MORTAR_SCENE, COST_MORTAR))
	if railgun_btn:
		railgun_btn.pressed.connect(func() -> void: _build(RAILGUN_SCENE, COST_RAILGUN))
	
	if priority_btn:
		priority_btn.pressed.connect(_on_priority_pressed)
	if upgrade_btn:
		upgrade_btn.pressed.connect(_on_upgrade_pressed)
	if sell_btn:
		sell_btn.pressed.connect(_on_sell_pressed)
	if close_btn:
		close_btn.pressed.connect(close)
	
	EventBus.currency_changed.connect(_on_currency_changed)
	if LocalizationManager:
		LocalizationManager.language_changed.connect(func(_l: String) -> void:
			if visible:
				refresh()
		)
	hide()


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
	
	if close_btn and LocalizationManager:
		close_btn.text = LocalizationManager.get_text("UI_CLOSE", "CLOSE")
		
	var current_bits: int = GlobalState.run_currency
	
	if target_socket.is_occupied:
		empty_container.visible = false
		occupied_container.visible = true
		
		var tower: TowerBase = target_socket.current_tower
		if is_instance_valid(tower):
			var t_name: String = tower.tower_name
			if LocalizationManager:
				if t_name == "Pulse Turret":
					t_name = LocalizationManager.get_text("TURRET_PULSE_NAME", t_name)
				elif t_name == "Cryo Turret" or t_name == "Cryo Emitter":
					t_name = LocalizationManager.get_text("TURRET_CRYO_NAME", t_name)
				elif t_name == "Chain Turret":
					t_name = LocalizationManager.get_text("TURRET_CHAIN_NAME", t_name)
				elif t_name == "Plasma Mortar":
					t_name = LocalizationManager.get_text("TURRET_MORTAR_NAME", t_name)
				elif t_name == "Railgun Turret":
					t_name = LocalizationManager.get_text("TURRET_RAILGUN_NAME", t_name)
			
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
				priority_btn.text = LocalizationManager.get_text(prio_key, "TARGET: %s" % tower.get_target_priority_name()) if LocalizationManager else "TARGET: %s" % tower.get_target_priority_name()
			
			var up_cost: int = tower.get_upgrade_cost()
			var refund: int = tower.get_sell_refund()
			
			if tower.tier >= tower.max_tier:
				# Infinite Overclock Infusion Bit Sink
				var inf_cost: int = tower.get_infusion_cost()
				var inf_fmt: String = LocalizationManager.get_text("INFUSION_BTN", "INFUSION +%d (+5%% DMG) [%d B]") if LocalizationManager else "INFUSION +%d (+5%% DMG) [%d B]"
				upgrade_btn.text = inf_fmt % [tower.infusion_level + 1, inf_cost]
				upgrade_btn.disabled = current_bits < inf_cost
			elif current_bits < up_cost:
				if tower.tier == 4:
					upgrade_btn.text = (LocalizationManager.get_text("UPGRADE_T5", "MASTER T5 (%d BITS)") % up_cost) if LocalizationManager else "MASTER T5 (%d BITS)" % up_cost
				else:
					upgrade_btn.text = (LocalizationManager.get_text("UPGRADE_TIER_NO_BITS", "UPGRADE T%d (%d BITS)") % [tower.tier + 1, up_cost]) if LocalizationManager else "UPGRADE T%d (%d BITS)" % [tower.tier + 1, up_cost]
				upgrade_btn.disabled = true
			else:
				if tower.tier == 4:
					upgrade_btn.text = (LocalizationManager.get_text("UPGRADE_T5", "UPGRADE TO MASTER T5 [%d B]") % up_cost) if LocalizationManager else "UPGRADE TO MASTER T5 [%d B]" % up_cost
				else:
					upgrade_btn.text = (LocalizationManager.get_text("UPGRADE_TIER", "UPGRADE TO T%d (+35%% DMG) [%d B]") % [tower.tier + 1, up_cost]) if LocalizationManager else "UPGRADE TO T%d (+35%% DMG) [%d B]" % [tower.tier + 1, up_cost]
				upgrade_btn.disabled = false
			
			sell_btn.text = (LocalizationManager.get_text("DECOMMISSION_BTN", "DECOMMISSION (+%d BITS)") % refund) if LocalizationManager else "DECOMMISSION (+%d BITS)" % refund
	else:
		empty_container.visible = true
		occupied_container.visible = false
		
		var p_name: String = LocalizationManager.get_text("TURRET_PULSE_NAME", "Pulse Turret").to_upper() if LocalizationManager else "PULSE TURRET"
		var c_name: String = LocalizationManager.get_text("TURRET_CRYO_NAME", "Cryo Emitter").to_upper() if LocalizationManager else "CRYO EMITTER"
		var ch_name: String = LocalizationManager.get_text("TURRET_CHAIN_NAME", "Chain Turret").to_upper() if LocalizationManager else "CHAIN TURRET"
		var m_name: String = LocalizationManager.get_text("TURRET_MORTAR_NAME", "Plasma Mortar").to_upper() if LocalizationManager else "PLASMA MORTAR"
		var r_name: String = LocalizationManager.get_text("TURRET_RAILGUN_NAME", "Railgun Turret").to_upper() if LocalizationManager else "RAILGUN TURRET"
		
		pulse_btn.text = "%s (%d B)" % [p_name, COST_PULSE]
		pulse_btn.disabled = current_bits < COST_PULSE
		
		cryo_btn.text = "%s (%d B)" % [c_name, COST_CRYO]
		cryo_btn.disabled = current_bits < COST_CRYO
		
		chain_btn.text = "%s (%d B)" % [ch_name, COST_CHAIN]
		chain_btn.disabled = current_bits < COST_CHAIN
		
		mortar_btn.text = "%s (%d B)" % [m_name, COST_MORTAR]
		mortar_btn.disabled = current_bits < COST_MORTAR
		
		railgun_btn.text = "%s (%d B)" % [r_name, COST_RAILGUN]
		railgun_btn.disabled = current_bits < COST_RAILGUN


func _build(scene: PackedScene, cost: int) -> void:
	if not is_instance_valid(target_socket) or target_socket.is_occupied:
		return
	
	if GlobalState.spend_currency(cost):
		target_socket.build_tower(scene)
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
