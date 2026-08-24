class_name Arena
extends Node2D

## Main combat arena manager in Perimeta. Manages 4-vector dynamic entrances, speed controls, active Coin Gun, EMP Super Shockwave, Card Drafts, Pause & Settings menus.

@onready var camera: Camera2D = $Camera2D
@onready var tracks_container: Node2D = $Tracks
@onready var path_visuals_container: Node2D = $PathVisuals
@onready var path_north: Path2D = $Tracks/Path_North
@onready var path_south: Path2D = $Tracks/Path_South
@onready var path_east: Path2D = $Tracks/Path_East
@onready var path_west: Path2D = $Tracks/Path_West
@onready var wave_spawner: WaveSpawner = $WaveSpawner
@onready var core_base: CoreBase = $CoreBase
@onready var sockets_container: Node2D = $Sockets
@onready var cursor_laser: Line2D = $CursorLaser
@onready var shockwave_ring: Line2D = $ShockwaveRing

# UI Quick-HUD elements
@onready var wave_label: Label = $CanvasLayer/HUD/TopBar/WaveLabel
@onready var currency_label: Label = $CanvasLayer/HUD/TopBar/CurrencyLabel
@onready var cores_hud_label: Label = $CanvasLayer/HUD/TopBar/CoresHudLabel
@onready var skill_tree_open_btn: Button = $CanvasLayer/HUD/TopBar/SkillTreeOpenButton
@onready var lang_btn: Button = $CanvasLayer/HUD/TopBar/LangButton

# Resonance Badges
@onready var cryo_badge: Control = $CanvasLayer/HUD/ResonanceContainer/CryoBadge
@onready var electro_badge: Control = $CanvasLayer/HUD/ResonanceContainer/ElectroBadge
@onready var pyro_badge: Control = $CanvasLayer/HUD/ResonanceContainer/PyroBadge
@onready var kinetic_badge: Control = $CanvasLayer/HUD/ResonanceContainer/KineticBadge

@onready var health_bar: ProgressBar = $CanvasLayer/HUD/BottomBar/CoreHealthBox/HealthBar
@onready var health_label: Label = $CanvasLayer/HUD/BottomBar/CoreHealthBox/HealthBar/HealthLabel
@onready var super_bar: ProgressBar = $CanvasLayer/HUD/BottomBar/SuperMeterBox/SuperBar
@onready var super_label: Label = $CanvasLayer/HUD/BottomBar/SuperMeterBox/SuperBar/SuperLabel

# Speed Controls
@onready var speed1_btn: Button = $CanvasLayer/HUD/TopBar/SpeedControls/Speed1Btn
@onready var speed2_btn: Button = $CanvasLayer/HUD/TopBar/SpeedControls/Speed2Btn
@onready var speed4_btn: Button = $CanvasLayer/HUD/TopBar/SpeedControls/Speed4Btn

# Boss & Sector UI elements
@onready var boss_health_container: Control = $CanvasLayer/HUD/BossHealthBarContainer
@onready var boss_title_label: Label = $CanvasLayer/HUD/BossHealthBarContainer/BossHeader/BossTitleLabel
@onready var boss_shield_label: Label = $CanvasLayer/HUD/BossHealthBarContainer/BossHeader/BossShieldStatusLabel
@onready var boss_progress_bar: ProgressBar = $CanvasLayer/HUD/BossHealthBarContainer/BossProgressBar
@onready var boss_hp_label: Label = $CanvasLayer/HUD/BossHealthBarContainer/BossProgressBar/BossHpLabel
@onready var boss_alert_banner: Control = $CanvasLayer/HUD/BossAlertBanner
@onready var sector_alert_banner: Control = $CanvasLayer/HUD/SectorAlertBanner
@onready var sector_alert_label: Label = $CanvasLayer/HUD/SectorAlertBanner/SectorAlertLabel

# Modals & Menus
@onready var build_menu: BuildMenu = $CanvasLayer/BuildMenu
@onready var card_draft_modal: CardDraftModal = $CanvasLayer/CardDraftModal
@onready var skill_tree_modal: SkillTree = $CanvasLayer/SkillTree
@onready var game_over_modal: GameOverModal = $CanvasLayer/GameOverModal
@onready var settings_modal: SettingsModal = $CanvasLayer/SettingsModal
@onready var victory_modal: VictoryModal = $CanvasLayer/VictoryModal
@onready var pause_menu: Control = $CanvasLayer/PauseMenu
@onready var overcharge_btn: Button = $CanvasLayer/HUD/BottomBar/SuperMeterBox/OverchargeBtn
@onready var crt_overlay: ColorRect = $CRTLayer/CRTOverlay

# Static Elemental Resonance Registry
static var _active_resonances: Dictionary = {
	"cryo": false,
	"electro": false,
	"pyro": false,
	"kinetic": false
}

static func is_cryo_resonance_active() -> bool:
	return _active_resonances.get("cryo", false)

static func is_electro_resonance_active() -> bool:
	return _active_resonances.get("electro", false)

static func is_pyro_resonance_active() -> bool:
	return _active_resonances.get("pyro", false)

static func is_kinetic_resonance_active() -> bool:
	return _active_resonances.get("kinetic", false)

# Screen Shake parameters
var _shake_intensity: float = 0.0
var _shake_decay: float = 5.0
var _camera_origin: Vector2 = Vector2(960, 540)
var _is_paused: bool = false
var _speed_active_style: StyleBoxFlat = null
var _speed_normal_style: StyleBoxFlat = null


func _ready() -> void:
	if camera:
		_camera_origin = camera.position
	
	_setup_path_visualization()
	_setup_sockets()
	_setup_hud_connections()
	_setup_speed_controls()
	_setup_pause_menu()
	_setup_boss_events()
	
	# Start run lifecycle
	GlobalState.start_run()


func _process(delta: float) -> void:
	# Screen Shake processing
	if _shake_intensity > 0.0:
		_shake_intensity = maxf(0.0, _shake_intensity - _shake_decay * delta)
		if camera:
			camera.position = _camera_origin + Vector2(
				randf_range(-_shake_intensity, _shake_intensity),
				randf_range(-_shake_intensity, _shake_intensity)
			)
	elif camera and camera.position != _camera_origin:
		camera.position = _camera_origin


func _unhandled_input(event: InputEvent) -> void:
	# Toggle Pause Menu on ESC
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
		if build_menu and build_menu.visible:
			build_menu.close()
			get_viewport().set_input_as_handled()
			return
		if skill_tree_modal and skill_tree_modal.visible:
			skill_tree_modal.close()
			get_viewport().set_input_as_handled()
			return
		if card_draft_modal and card_draft_modal.visible:
			return # Cannot pause during active draft selection
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	
	# Active Coin Gun firing via Left Mouse Button click in empty space
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not _is_modal_open():
			_fire_coin_gun(get_global_mouse_position())
	
	# Trigger EMP Super Shockwave on Spacebar or Right Mouse Button
	if (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE) or \
	   (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed):
		if not _is_modal_open():
			_trigger_super_emp()


func _is_modal_open() -> bool:
	return (build_menu and build_menu.visible) or \
		   (card_draft_modal and card_draft_modal.visible) or \
		   (skill_tree_modal and skill_tree_modal.visible) or \
		   (game_over_modal and game_over_modal.visible) or \
		   (settings_modal and settings_modal.visible) or \
		   (victory_modal and victory_modal.visible) or \
		   _is_paused


func _trigger_super_emp() -> void:
	if GlobalState.super_charge < 100.0 or not GlobalState.is_run_active:
		return
	
	GlobalState.super_charge = 0.0
	EventBus.super_charge_changed.emit(0.0, 100.0)
	EventBus.super_ability_activated.emit()
	
	trigger_shake(16.0, 0.6)
	if AudioManager:
		if AudioManager.has_method("play_sfx"):
			AudioManager.play_sfx("super", Vector2(0.95, 1.05), 4.0)
		elif is_instance_valid(AudioManager.snd_super):
			AudioManager.play_sound(AudioManager.snd_super, 0.0, 4.0)
	
	# Visual Expanding Shockwave Ring
	if shockwave_ring and core_base:
		shockwave_ring.global_position = core_base.global_position
		shockwave_ring.clear_points()
		var points_cnt: int = 48
		for i in range(points_cnt + 1):
			var ang: float = (float(i) / float(points_cnt)) * TAU
			shockwave_ring.add_point(Vector2(cos(ang), sin(ang)) * 20.0)
		shockwave_ring.visible = true
		shockwave_ring.scale = Vector2.ONE
		shockwave_ring.modulate = Color(2.5, 4.0, 5.0, 1.0)
		
		var tween: Tween = create_tween()
		if tween:
			tween.tween_property(shockwave_ring, "scale", Vector2(70.0, 70.0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tween.parallel().tween_property(shockwave_ring, "modulate:a", 0.0, 0.5)
			tween.chain().tween_callback(func() -> void:
				if is_instance_valid(shockwave_ring):
					shockwave_ring.visible = false
			)
	
	# EMP Damage all active enemies across all paths
	var emp_damage: float = GlobalState.get_stat("emp_damage", 300.0)
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyBase and is_instance_valid(node) and not node.is_dead:
			var enemy: EnemyBase = node as EnemyBase
			enemy.apply_slow(0.80, 4.0) # 80% EMP Stun
			enemy.take_damage(emp_damage, true, Color("#00FFFF"))


func _on_overcharge_pressed() -> void:
	if GlobalState.run_currency < 1500 or GlobalState.super_charge >= 100.0:
		return
	
	if GlobalState.spend_currency(1500):
		GlobalState.add_super_charge(50.0)
		trigger_shake(4.0, 0.2)
		if AudioManager:
			if AudioManager.has_method("play_sfx"):
				AudioManager.play_sfx("build", Vector2.ONE, 2.0)
			elif is_instance_valid(AudioManager.snd_build):
				AudioManager.play_sound(AudioManager.snd_build, 0.0, 2.0)


func trigger_shake(intensity: float, decay_time: float = 0.3) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_decay = intensity / maxf(0.05, decay_time)


func _setup_speed_controls() -> void:
	if speed1_btn:
		_speed_active_style = speed1_btn.get_theme_stylebox("normal") as StyleBoxFlat
		speed1_btn.pressed.connect(func() -> void: set_game_speed(1.0))
	if speed2_btn:
		_speed_normal_style = speed2_btn.get_theme_stylebox("normal") as StyleBoxFlat
		speed2_btn.pressed.connect(func() -> void: set_game_speed(2.0))
	if speed4_btn:
		speed4_btn.pressed.connect(func() -> void: set_game_speed(4.0))


func set_game_speed(spd: float) -> void:
	GlobalState.game_speed = spd
	Engine.time_scale = spd
	_update_speed_button_visuals(spd)


func _update_speed_button_visuals(spd: float) -> void:
	if speed1_btn and speed2_btn and speed4_btn and _speed_active_style and _speed_normal_style:
		speed1_btn.add_theme_stylebox_override("normal", _speed_active_style if spd == 1.0 else _speed_normal_style)
		speed2_btn.add_theme_stylebox_override("normal", _speed_active_style if spd == 2.0 else _speed_normal_style)
		speed4_btn.add_theme_stylebox_override("normal", _speed_active_style if spd == 4.0 else _speed_normal_style)


func _setup_pause_menu() -> void:
	if not pause_menu:
		return
	
	var resume_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/ResumeBtn") as Button
	var settings_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/PauseSettingsBtn") as Button
	var restart_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/PauseRestartBtn") as Button
	var menu_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/PauseMainMenuBtn") as Button
	
	if resume_btn:
		resume_btn.pressed.connect(_toggle_pause)
	if settings_btn:
		settings_btn.pressed.connect(_on_pause_settings_pressed)
	if restart_btn:
		restart_btn.pressed.connect(_on_pause_restart_pressed)
	if menu_btn:
		menu_btn.pressed.connect(_on_pause_menu_pressed)


func _toggle_pause() -> void:
	if not pause_menu:
		return
	_is_paused = not _is_paused
	pause_menu.visible = _is_paused
	get_tree().paused = _is_paused
	if not _is_paused:
		Engine.time_scale = GlobalState.game_speed


func _on_pause_settings_pressed() -> void:
	if settings_modal:
		settings_modal.open()


func _on_pause_restart_pressed() -> void:
	_toggle_pause()
	_restart_run()


func _on_pause_menu_pressed() -> void:
	_toggle_pause()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func _setup_boss_events() -> void:
	if not EventBus.boss_spawned.is_connected(_on_boss_spawned):
		EventBus.boss_spawned.connect(_on_boss_spawned)
	if not EventBus.boss_defeated.is_connected(_on_boss_defeated):
		EventBus.boss_defeated.connect(_on_boss_defeated)
	if not EventBus.boss_damaged.is_connected(_on_boss_damaged):
		EventBus.boss_damaged.connect(_on_boss_damaged)


func _on_boss_spawned(boss: Node) -> void:
	if boss_health_container:
		boss_health_container.visible = true
	
	if is_instance_valid(boss):
		if not boss.tree_exited.is_connected(_hide_boss_health_bar):
			boss.tree_exited.connect(_hide_boss_health_bar)
	
	trigger_shake(6.0, 0.4)
	_show_boss_alert_banner()


func _on_boss_defeated(_boss: Node) -> void:
	_hide_boss_health_bar()
	trigger_shake(12.0, 0.5)


func _hide_boss_health_bar() -> void:
	if boss_health_container:
		boss_health_container.visible = false
	if boss_shield_label:
		boss_shield_label.visible = false


func _on_boss_damaged(current_hp: float, max_hp: float, phase_shield: bool) -> void:
	if not boss_health_container or not boss_progress_bar:
		return
	
	boss_progress_bar.max_value = max_hp
	boss_progress_bar.value = current_hp
	
	if boss_hp_label:
		boss_hp_label.text = "%d / %d" % [int(current_hp), int(max_hp)]
	
	if boss_shield_label:
		boss_shield_label.visible = phase_shield


func _show_boss_alert_banner() -> void:
	if not boss_alert_banner:
		return
	
	boss_alert_banner.visible = true
	boss_alert_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	boss_alert_banner.scale = Vector2(0.8, 0.8)
	
	var tween: Tween = create_tween()
	tween.tween_property(boss_alert_banner, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(boss_alert_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	
	for _i in range(3):
		tween.tween_property(boss_alert_banner, "modulate", Color(2.5, 0.3, 0.4, 1.0), 0.15)
		tween.tween_property(boss_alert_banner, "modulate", Color.WHITE, 0.15)
	
	tween.tween_interval(0.8)
	tween.tween_property(boss_alert_banner, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func() -> void:
		if is_instance_valid(boss_alert_banner):
			boss_alert_banner.visible = false
	)


func _on_sector_breach_alert(_wave_number: int) -> void:
	if not sector_alert_banner:
		return
	
	sector_alert_banner.visible = true
	sector_alert_banner.modulate = Color(1.0, 1.0, 1.0, 0.0)
	sector_alert_banner.scale = Vector2(0.8, 0.8)
	trigger_shake(8.0, 0.4)
	
	var tween: Tween = create_tween()
	tween.tween_property(sector_alert_banner, "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(sector_alert_banner, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)
	
	for _i in range(4):
		tween.tween_property(sector_alert_banner, "modulate", Color(2.5, 0.2, 0.3, 1.0), 0.15)
		tween.tween_property(sector_alert_banner, "modulate", Color.WHITE, 0.15)
	
	tween.tween_interval(1.2)
	tween.tween_property(sector_alert_banner, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		if is_instance_valid(sector_alert_banner):
			sector_alert_banner.visible = false
	)


func _fire_coin_gun(target_pos: Vector2) -> void:
	var coin_cost: int = int(GlobalState.get_stat("coin_gun_cost", 5.0))
	if not GlobalState.spend_currency(coin_cost):
		return
	
	# Visual laser shot from Core to cursor
	if cursor_laser and core_base:
		cursor_laser.clear_points()
		cursor_laser.add_point(core_base.global_position)
		cursor_laser.add_point(target_pos)
		cursor_laser.visible = true
		cursor_laser.modulate = Color(3.5, 2.8, 0.6, 1.0) # Golden coin beam
		
		var tween: Tween = create_tween()
		tween.tween_property(cursor_laser, "modulate:a", 0.0, 0.08)
		tween.tween_callback(func() -> void:
			if is_instance_valid(cursor_laser):
				cursor_laser.visible = false
		)
	
	# Find and damage closest enemy near cursor
	var coin_mult: float = GlobalState.get_stat("coin_gun_damage_mult", 0.0)
	var cursor_damage: float = GlobalState.get_stat("tower_damage", 30.0) * (1.0 + coin_mult)
	var hit_enemy: EnemyBase = _find_enemy_near_position(target_pos, 50.0)
	if hit_enemy:
		hit_enemy.take_damage(cursor_damage, true, Color("#FFD700"))
		trigger_shake(2.0, 0.1)


func _find_enemy_near_position(pos: Vector2, max_radius: float) -> EnemyBase:
	var closest_enemy: EnemyBase = null
	var shortest_dist_sq: float = max_radius * max_radius
	
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if node is EnemyBase and is_instance_valid(node) and not node.is_dead and not node.is_queued_for_deletion():
			var dist_sq: float = pos.distance_squared_to(node.global_position)
			if dist_sq < shortest_dist_sq:
				shortest_dist_sq = dist_sq
				closest_enemy = node as EnemyBase
	
	return closest_enemy


func _setup_path_visualization() -> void:
	var paths: Array[Path2D] = [path_north, path_south, path_west, path_east]
	var line_names: Array[String] = ["PathVisual_North", "PathVisual_South", "PathVisual_West", "PathVisual_East"]
	
	for i in range(paths.size()):
		var p: Path2D = paths[i]
		if not is_instance_valid(p) or not p.curve:
			continue
		
		var line: Line2D = null
		if path_visuals_container and i < line_names.size():
			line = path_visuals_container.get_node_or_null(line_names[i]) as Line2D
		
		if line:
			line.clear_points()
			var baked_points: PackedVector2Array = p.curve.get_baked_points()
			for pt: Vector2 in baked_points:
				line.add_point(pt)


func _setup_sockets() -> void:
	if not sockets_container:
		return
	
	for child: Node in sockets_container.get_children():
		if child is BuildSocket:
			var socket: BuildSocket = child as BuildSocket
			if not socket.socket_selected.is_connected(_on_socket_selected):
				socket.socket_selected.connect(_on_socket_selected)


func _on_socket_selected(socket: BuildSocket) -> void:
	if build_menu:
		build_menu.open_for_socket(socket)


func _setup_hud_connections() -> void:
	if not EventBus.wave_started.is_connected(_on_wave_started):
		EventBus.wave_started.connect(_on_wave_started)
	if not EventBus.sector_breach_alert.is_connected(_on_sector_breach_alert):
		EventBus.sector_breach_alert.connect(_on_sector_breach_alert)
	if not EventBus.currency_changed.is_connected(_on_currency_changed):
		EventBus.currency_changed.connect(_on_currency_changed)
	if not EventBus.meta_cores_changed.is_connected(_on_meta_cores_changed):
		EventBus.meta_cores_changed.connect(_on_meta_cores_changed)
	if not EventBus.core_damaged.is_connected(_on_core_damaged):
		EventBus.core_damaged.connect(_on_core_damaged)
	if not EventBus.core_healed.is_connected(_on_core_healed):
		EventBus.core_healed.connect(_on_core_healed)
	if not EventBus.super_charge_changed.is_connected(_on_super_charge_changed):
		EventBus.super_charge_changed.connect(_on_super_charge_changed)
	
	if skill_tree_open_btn and not skill_tree_open_btn.pressed.is_connected(_on_open_skill_tree_pressed):
		skill_tree_open_btn.pressed.connect(_on_open_skill_tree_pressed)
	
	if lang_btn and not lang_btn.pressed.is_connected(_on_lang_pressed):
		lang_btn.pressed.connect(_on_lang_pressed)
		
	if overcharge_btn and not overcharge_btn.pressed.is_connected(_on_overcharge_pressed):
		overcharge_btn.pressed.connect(_on_overcharge_pressed)
	
	if LocalizationManager and not LocalizationManager.language_changed.is_connected(_on_language_changed):
		LocalizationManager.language_changed.connect(_on_language_changed)
	
	if not EventBus.tower_placed.is_connected(_update_elemental_resonances):
		EventBus.tower_placed.connect(_update_elemental_resonances)
	if not EventBus.tower_built.is_connected(_update_elemental_resonances):
		EventBus.tower_built.connect(_update_elemental_resonances)
	if not EventBus.tower_sold.is_connected(_update_elemental_resonances):
		EventBus.tower_sold.connect(_update_elemental_resonances)
	if not EventBus.tower_upgraded.is_connected(_update_elemental_resonances):
		EventBus.tower_upgraded.connect(_update_elemental_resonances)
	
	if game_over_modal:
		if not game_over_modal.restart_requested.is_connected(_restart_run):
			game_over_modal.restart_requested.connect(_restart_run)
		if not game_over_modal.open_skill_tree_requested.is_connected(_on_open_skill_tree_pressed):
			game_over_modal.open_skill_tree_requested.connect(_on_open_skill_tree_pressed)
	
	if victory_modal:
		if not victory_modal.endless_mode_selected.is_connected(_on_endless_mode_selected):
			victory_modal.endless_mode_selected.connect(_on_endless_mode_selected)
	
	_update_ui_state()
	_update_elemental_resonances()
	_update_pause_menu_localization()


func _on_endless_mode_selected() -> void:
	if is_instance_valid(wave_spawner):
		wave_spawner.is_endless_mode = true
		wave_spawner.start_next_wave()


func _on_lang_pressed() -> void:
	if LocalizationManager:
		LocalizationManager.toggle_language()


func _on_language_changed(_new_lang: String) -> void:
	_update_ui_state()
	_update_resonance_hud_badges()
	_update_pause_menu_localization()


func _update_pause_menu_localization() -> void:
	if not pause_menu or not LocalizationManager:
		return
	var resume_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/ResumeBtn") as Button
	var settings_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/PauseSettingsBtn") as Button
	var restart_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/PauseRestartBtn") as Button
	var menu_btn: Button = pause_menu.get_node_or_null("PauseCenter/PausePanel/PauseMargin/PauseVBox/PauseMainMenuBtn") as Button
	
	if resume_btn:
		resume_btn.text = LocalizationManager.get_text("UI_RESUME", "RESUME")
	if settings_btn:
		settings_btn.text = LocalizationManager.get_text("UI_SETTINGS", "SETTINGS")
	if restart_btn:
		restart_btn.text = LocalizationManager.get_text("UI_RESTART_RUN", "RESTART RUN")
	if menu_btn:
		menu_btn.text = LocalizationManager.get_text("UI_MAIN_MENU", "MAIN MENU")


func _restart_run() -> void:
	if game_over_modal:
		game_over_modal.visible = false
	if build_menu:
		build_menu.close()
	if card_draft_modal:
		card_draft_modal.close()
	if skill_tree_modal:
		skill_tree_modal.close()
	if boss_health_container:
		boss_health_container.visible = false
	if boss_alert_banner:
		boss_alert_banner.visible = false
	if sector_alert_banner:
		sector_alert_banner.visible = false
	if pause_menu:
		pause_menu.visible = false
	if victory_modal:
		victory_modal.visible = false
	
	# Clear / reset all sockets to initial run state
	if sockets_container:
		for child: Node in sockets_container.get_children():
			if child is BuildSocket:
				(child as BuildSocket).reset_socket()
	
	# Clear any remaining enemies, hazards, & damage popups across all paths
	get_tree().call_group("hazards", "queue_free")
	get_tree().call_group("damage_popups", "queue_free")
	for child: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(child):
			child.queue_free()
	
	_active_resonances = {"cryo": false, "electro": false, "pyro": false, "kinetic": false}
	GlobalState.is_resonance_active = false
	_update_resonance_hud_badges()
	
	set_game_speed(1.0)
	GlobalState.start_run()


func _on_open_skill_tree_pressed() -> void:
	if build_menu:
		build_menu.close()
	if skill_tree_modal:
		skill_tree_modal.open()


func _update_ui_state() -> void:
	var wave_word: String = LocalizationManager.get_text("UI_WAVE", "WAVE") if LocalizationManager else "WAVE"
	var bits_word: String = LocalizationManager.get_text("UI_BITS", "BITS") if LocalizationManager else "BITS"
	var gun_word: String = LocalizationManager.get_text("UI_GUN_COST", "GUN") if LocalizationManager else "GUN"
	var cores_word: String = LocalizationManager.get_text("UI_CORES", "CORES") if LocalizationManager else "CORES"
	
	if wave_label:
		wave_label.text = "%s %02d" % [wave_word, GlobalState.current_wave]
	if currency_label:
		var coin_cost: int = int(GlobalState.get_stat("coin_gun_cost", 5.0))
		currency_label.text = "%s: %d (%s: %d)" % [bits_word, GlobalState.run_currency, gun_word, coin_cost]
	if cores_hud_label:
		cores_hud_label.text = "%s: %d" % [cores_word, GlobalState.meta_cores]
	if skill_tree_open_btn and LocalizationManager:
		skill_tree_open_btn.text = LocalizationManager.get_text("UI_SKILL_TREE", "META MATRIX")
	if lang_btn and LocalizationManager:
		lang_btn.text = LocalizationManager.get_toggle_button_text()
	if health_bar:
		health_bar.max_value = GlobalState.core_max_hp
		health_bar.value = GlobalState.core_hp
	if health_label:
		health_label.text = "%d / %d" % [int(GlobalState.core_hp), int(GlobalState.core_max_hp)]
	if super_bar:
		super_bar.value = GlobalState.super_charge
		if GlobalState.super_charge >= 100.0:
			super_label.text = LocalizationManager.get_text("UI_EMP_READY", "EMP SHOCKWAVE READY!") if LocalizationManager else "EMP SHOCKWAVE READY!"
		else:
			var charge_fmt: String = LocalizationManager.get_text("UI_EMP_CHARGE", "EMP CHARGE: %d%%") if LocalizationManager else "EMP CHARGE: %d%%"
			super_label.text = charge_fmt % int(GlobalState.super_charge)
	if overcharge_btn and LocalizationManager:
		overcharge_btn.text = LocalizationManager.get_text("UI_OVERCHARGE_BTN", "TACTICAL OVERCHARGE (+50% SUPER / 1500 BITS)")
		overcharge_btn.disabled = (GlobalState.run_currency < 1500 or GlobalState.super_charge >= 100.0)


func _on_wave_started(wave_number: int) -> void:
	if wave_label:
		var wave_word: String = LocalizationManager.get_text("UI_WAVE", "WAVE") if LocalizationManager else "WAVE"
		wave_label.text = "%s %02d" % [wave_word, wave_number]


func _on_currency_changed(new_amount: int, _delta: int) -> void:
	if currency_label:
		var bits_word: String = LocalizationManager.get_text("UI_BITS", "BITS") if LocalizationManager else "BITS"
		var gun_word: String = LocalizationManager.get_text("UI_GUN_COST", "GUN") if LocalizationManager else "GUN"
		var coin_cost: int = int(GlobalState.get_stat("coin_gun_cost", 5.0))
		currency_label.text = "%s: %d (%s: %d)" % [bits_word, new_amount, gun_word, coin_cost]
	if overcharge_btn:
		overcharge_btn.disabled = (new_amount < 1500 or GlobalState.super_charge >= 100.0)


func _on_meta_cores_changed(new_amount: int, _delta: int) -> void:
	if cores_hud_label:
		var cores_word: String = LocalizationManager.get_text("UI_CORES", "CORES") if LocalizationManager else "CORES"
		cores_hud_label.text = "%s: %d" % [cores_word, new_amount]


func _on_core_damaged(_amount: float, current_hp: float) -> void:
	if health_bar:
		health_bar.value = current_hp
	if health_label:
		health_label.text = "%d / %d" % [int(current_hp), int(GlobalState.core_max_hp)]
	trigger_shake(6.0, 0.25)


func _on_core_healed(_amount: float, current_hp: float) -> void:
	if health_bar:
		health_bar.value = current_hp
	if health_label:
		health_label.text = "%d / %d" % [int(current_hp), int(GlobalState.core_max_hp)]


func _on_super_charge_changed(current_charge: float, _max_charge: float) -> void:
	if super_bar:
		super_bar.value = current_charge
	if super_label:
		if current_charge >= 100.0:
			super_label.text = LocalizationManager.get_text("UI_EMP_READY", "EMP SHOCKWAVE READY!") if LocalizationManager else "EMP SHOCKWAVE READY!"
		else:
			var charge_fmt: String = LocalizationManager.get_text("UI_EMP_CHARGE", "EMP CHARGE: %d%%") if LocalizationManager else "EMP CHARGE: %d%%"
			super_label.text = charge_fmt % int(current_charge)
	if overcharge_btn:
		overcharge_btn.disabled = (GlobalState.run_currency < 1500 or current_charge >= 100.0)


func _update_elemental_resonances(_param1: Variant = null, _param2: Variant = null) -> void:
	var cryo_cnt: int = 0
	var electro_cnt: int = 0
	var pyro_cnt: int = 0
	var kinetic_cnt: int = 0
	
	if sockets_container:
		for child: Node in sockets_container.get_children():
			if child is BuildSocket and is_instance_valid(child.current_tower):
				var t: TowerBase = child.current_tower
				if t is CryoTurret:
					cryo_cnt += 1
				elif t is PlasmaMortar:
					pyro_cnt += 1
				elif t is ChainTurret or t is RailgunTurret:
					electro_cnt += 1
				elif t is TowerBase:
					kinetic_cnt += 1
					
	_active_resonances["cryo"] = (cryo_cnt >= 3)
	_active_resonances["electro"] = (electro_cnt >= 3)
	_active_resonances["pyro"] = (pyro_cnt >= 3)
	_active_resonances["kinetic"] = (kinetic_cnt >= 3)
	
	GlobalState.is_resonance_active = (_active_resonances["cryo"] or _active_resonances["electro"] or _active_resonances["pyro"] or _active_resonances["kinetic"])
	_update_resonance_hud_badges()


func _update_resonance_hud_badges() -> void:
	if cryo_badge:
		cryo_badge.visible = _active_resonances["cryo"]
		if LocalizationManager:
			var lbl: Label = cryo_badge.get_node_or_null("Margin/Label") as Label
			if lbl:
				lbl.text = "❄ " + LocalizationManager.get_text("RESONANCE_CRYO")
	if electro_badge:
		electro_badge.visible = _active_resonances["electro"]
		if LocalizationManager:
			var lbl: Label = electro_badge.get_node_or_null("Margin/Label") as Label
			if lbl:
				lbl.text = "⚡ " + LocalizationManager.get_text("RESONANCE_ELECTRO")
	if pyro_badge:
		pyro_badge.visible = _active_resonances["pyro"]
		if LocalizationManager:
			var lbl: Label = pyro_badge.get_node_or_null("Margin/Label") as Label
			if lbl:
				lbl.text = "🔥 " + LocalizationManager.get_text("RESONANCE_PYRO")
	if kinetic_badge:
		kinetic_badge.visible = _active_resonances["kinetic"]
		if LocalizationManager:
			var lbl: Label = kinetic_badge.get_node_or_null("Margin/Label") as Label
			if lbl:
				lbl.text = "🎯 " + LocalizationManager.get_text("RESONANCE_KINETIC")
