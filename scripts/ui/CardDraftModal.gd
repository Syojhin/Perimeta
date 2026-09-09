class_name CardDraftModal
extends Control

## In-run roguelite boon drafting interface appearing every 3 waves.
## Dynamically loads BoonCardData resources and filters offered cards by deployed turrets.

signal card_selected(card_data: Dictionary)

const CARDS_DIR: String = "res://resources/cards/core/"

## Legacy compatibility accessor for external scripts/tests
static var CARD_POOL: Array:
	get:
		var cards: Array = []
		var dir: DirAccess = DirAccess.open(CARDS_DIR)
		if dir:
			dir.list_dir_begin()
			var file_name: String = dir.get_next()
			while file_name != "":
				if file_name.ends_with(".tres"):
					var res: Resource = load(CARDS_DIR + file_name)
					if res:
						cards.append(res.to_dict() if res.has_method("to_dict") else res)
				file_name = dir.get_next()
			dir.list_dir_end()
		return cards

@onready var cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CardsContainer
@onready var card1_node: CardView = $CenterContainer/VBoxContainer/CardsContainer/Card1
@onready var card2_node: CardView = $CenterContainer/VBoxContainer/CardsContainer/Card2
@onready var card3_node: CardView = $CenterContainer/VBoxContainer/CardsContainer/Card3

var _card_registry: Array[BoonCardData] = []
var _current_options: Array[BoonCardData] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_load_card_registry()
	
	for card_view: CardView in [card1_node, card2_node, card3_node]:
		if card_view and not card_view.card_selected.is_connected(_on_card_view_selected):
			card_view.card_selected.connect(_on_card_view_selected)
	
	if not EventBus.draft_requested.is_connected(_on_draft_requested):
		EventBus.draft_requested.connect(_on_draft_requested)
		
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
	if loc_mgr:
		loc_mgr.language_changed.connect(_on_language_changed)


## Discovers and loads all .tres card resources from resources/cards/core/.
func _load_card_registry() -> void:
	_card_registry.clear()
	var dir: DirAccess = DirAccess.open(CARDS_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path: String = CARDS_DIR + file_name
				var res: Resource = load(full_path)
				if res is BoonCardData:
					_card_registry.append(res as BoonCardData)
			file_name = dir.get_next()
		dir.list_dir_end()


func _on_language_changed(_new_lang: String) -> void:
	if visible and _current_options.size() == 3:
		_update_header_labels()
		if card1_node: card1_node.update_view()
		if card2_node: card2_node.update_view()
		if card3_node: card3_node.update_view()


func _on_draft_requested(_wave_number: int = 0) -> void:
	open_draft([])


## Open the draft modal with 3 randomly selected distinct boons and pause combat.
func open_draft(offered_cards: Array = []) -> void:
	if visible:
		return
	
	if offered_cards.is_empty():
		var owned_turrets: Array[String] = get_owned_turret_ids()
		_current_options = _roll_random_cards(3, owned_turrets)
	else:
		_current_options.clear()
		for item in offered_cards:
			if item is BoonCardData:
				_current_options.append(item as BoonCardData)
			elif item is Dictionary:
				var res: BoonCardData = _find_card_by_id(item.get("id", ""))
				if res:
					_current_options.append(res)
		if _current_options.size() < 3:
			var fill: Array[BoonCardData] = _roll_random_cards(3 - _current_options.size())
			_current_options.append_array(fill)
	
	_update_header_labels()
	
	if card1_node and _current_options.size() > 0:
		card1_node.card_data = _current_options[0]
	if card2_node and _current_options.size() > 1:
		card2_node.card_data = _current_options[1]
	if card3_node and _current_options.size() > 2:
		card3_node.card_data = _current_options[2]
		
	_set_buttons_disabled(false)
	
	visible = true
	get_tree().paused = true
	
	# Animate card entrance
	if cards_container:
		cards_container.modulate = Color(1.0, 1.0, 1.0, 0.0)
		cards_container.scale = Vector2(0.92, 0.92)
		var tween: Tween = create_tween()
		tween.tween_property(cards_container, "modulate:a", 1.0, 0.2)
		tween.parallel().tween_property(cards_container, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK)


func _update_header_labels() -> void:
	var loc_mgr: Node = get_node_or_null("/root/LocalizationManager") if is_inside_tree() else null
	var title_lbl: Label = get_node_or_null("CenterContainer/VBoxContainer/HeaderContainer/HeaderTitle") as Label
	var sub_lbl: Label = get_node_or_null("CenterContainer/VBoxContainer/HeaderContainer/HeaderSubtitle") as Label
	if title_lbl:
		title_lbl.text = loc_mgr.call("get_text", "DRAFT_TITLE", "// ROGUELITE CARD DRAFT //") if loc_mgr else "// ROGUELITE CARD DRAFT //"
	if sub_lbl:
		sub_lbl.text = loc_mgr.call("get_text", "DRAFT_SUBTITLE", "SELECT 1 IN-RUN PERIMETER PROTOCOL TO AUGMENT COMBAT") if loc_mgr else "SELECT 1 IN-RUN PERIMETER PROTOCOL TO AUGMENT COMBAT"


## Determine which turret types are currently built on the board.
func get_owned_turret_ids() -> Array[String]:
	var ids: Array[String] = []
	var tree: SceneTree = get_tree()
	if not tree or not tree.current_scene:
		return ids
		
	var sockets: Node = tree.current_scene.get_node_or_null("Sockets")
	if sockets:
		for child: Node in sockets.get_children():
			if child is BuildSocket and is_instance_valid(child.current_tower):
				var tid: String = _get_turret_id(child.current_tower)
				if not tid.is_empty() and not ids.has(tid):
					ids.append(tid)
	else:
		for node: Node in tree.current_scene.find_children("*", "BuildSocket", true, false):
			var s: BuildSocket = node as BuildSocket
			if is_instance_valid(s) and s.is_occupied:
				var tid: String = _get_turret_id(s.current_tower)
				if not tid.is_empty() and not ids.has(tid):
					ids.append(tid)
	return ids


func _get_turret_id(tower: TowerBase) -> String:
	if not is_instance_valid(tower):
		return ""
	if tower.tower_data and not tower.tower_data.tower_id.is_empty():
		return tower.tower_data.tower_id
	if tower is CryoTurret:
		return "cryo_turret"
	if tower is PlasmaMortar:
		return "plasma_mortar"
	if tower is ChainTurret:
		return "chain_turret"
	if tower is RailgunTurret:
		return "railgun_turret"
	if tower is SingularityPrism:
		return "singularity_prism"
	if tower is TeslaLattice:
		return "tesla_lattice"
	if tower is NaniteHive:
		return "nanite_hive"
	return "pulse_turret"


## Filter card registry so turret-specific cards only appear if that turret is on the board.
func get_filtered_deck(owned_turrets: Array[String]) -> Array[BoonCardData]:
	var filtered: Array[BoonCardData] = []
	for card: BoonCardData in _card_registry:
		if card.required_tower_id.is_empty() or owned_turrets.has(card.required_tower_id):
			filtered.append(card)
	return filtered


## Roll count distinct cards from the filtered pool with weighted rarity distribution.
func _roll_random_cards(count: int, owned_turret_ids: Array[String] = []) -> Array[BoonCardData]:
	var pool: Array[BoonCardData] = get_filtered_deck(owned_turret_ids)
	if pool.is_empty():
		pool = _card_registry.duplicate()
		
	var commons: Array[BoonCardData] = []
	var rares: Array[BoonCardData] = []
	var epics: Array[BoonCardData] = []
	var overclocks: Array[BoonCardData] = []
	
	for c: BoonCardData in pool:
		match c.rarity:
			BoonCardData.Rarity.COMMON: commons.append(c)
			BoonCardData.Rarity.RARE: rares.append(c)
			BoonCardData.Rarity.EPIC: epics.append(c)
			BoonCardData.Rarity.OVERCLOCK: overclocks.append(c)
			
	var selected: Array[BoonCardData] = []
	var attempts: int = 0
	
	while selected.size() < count and selected.size() < pool.size() and attempts < 60:
		attempts += 1
		var roll: float = randf()
		var candidate_bucket: Array[BoonCardData] = []
		
		# Rarity weights: Common 50%, Rare 30%, Epic 15%, Overclock 5%
		if roll < 0.05 and not overclocks.is_empty():
			candidate_bucket = overclocks
		elif roll < 0.20 and not epics.is_empty():
			candidate_bucket = epics
		elif roll < 0.50 and not rares.is_empty():
			candidate_bucket = rares
		else:
			candidate_bucket = commons if not commons.is_empty() else pool
			
		if candidate_bucket.is_empty():
			candidate_bucket = pool
			
		var pick: BoonCardData = candidate_bucket[randi() % candidate_bucket.size()]
		if not selected.has(pick):
			selected.append(pick)
			
	# Fallback if distinct bucket rolling did not fill count
	if selected.size() < count:
		pool.shuffle()
		for c: BoonCardData in pool:
			if not selected.has(c):
				selected.append(c)
			if selected.size() >= count:
				break
				
	return selected


func _find_card_by_id(cid: String) -> BoonCardData:
	for c: BoonCardData in _card_registry:
		if c.card_id == cid:
			return c
	return null


func _set_buttons_disabled(disabled: bool) -> void:
	for node: CardView in [card1_node, card2_node, card3_node]:
		if node and node.select_btn:
			node.select_btn.disabled = disabled


func _on_card_view_selected(card: BoonCardData) -> void:
	if not is_instance_valid(card):
		return
		
	_set_buttons_disabled(true)
	
	if not card.target_stat.is_empty():
		GlobalState.add_run_modifier(card.target_stat, card.value)
		
	visible = false
	get_tree().paused = false
	
	var card_dict: Dictionary = card.to_dict()
	EventBus.draft_completed.emit(card_dict)
	EventBus.card_draft_completed.emit(card_dict)
	card_selected.emit(card_dict)
