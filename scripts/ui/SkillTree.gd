class_name SkillTree
extends Control

## Interactive DAG Meta-Progression Skill Tree interface for Perimeta.

signal closed()

# Parent-child prerequisite pairs for drawing graph lines
const DAG_EDGES: Array[Dictionary] = [
	{"parent": "kinetic_damage", "child": "overclock", "color": Color(1.0, 0.35, 0.45, 0.8)},
	{"parent": "overclock", "child": "chain_arc_bounces", "color": Color(1.0, 0.35, 0.45, 0.8)},
	{"parent": "chain_arc_bounces", "child": "elemental_mastery", "color": Color(1.0, 0.35, 0.45, 0.8)},
	{"parent": "elemental_mastery", "child": "specialist_doctrine", "color": Color(1.0, 0.35, 0.45, 0.8)},
	{"parent": "sensor_array", "child": "starting_capital", "color": Color(0.3, 0.85, 1.0, 0.8)},
	{"parent": "starting_capital", "child": "discount_ammo", "color": Color(0.3, 0.85, 1.0, 0.8)},
	{"parent": "discount_ammo", "child": "bit_dividend", "color": Color(0.3, 0.85, 1.0, 0.8)},
	{"parent": "reinforced_core", "child": "cryo_frostbite", "color": Color(0.3, 0.95, 0.6, 0.8)},
	{"parent": "cryo_frostbite", "child": "thermal_insulator", "color": Color(0.3, 0.95, 0.6, 0.8)}
]

@onready var cores_label: Label = $Header/HBox/CoresLabel
@onready var respec_button: Button = $Header/HBox/RespecButton
@onready var close_button: Button = $Header/HBox/CloseButton
@onready var nodes_container: Control = $GraphScroll/GraphContainer/Nodes

var _node_instances: Dictionary = {} # Maps perk_id -> SkillTreeNode


func _ready() -> void:
	if close_button:
		close_button.pressed.connect(close)
	if respec_button:
		respec_button.pressed.connect(_on_respec_pressed)
	
	EventBus.meta_cores_changed.connect(_on_meta_cores_changed)
	EventBus.perks_updated.connect(_on_perks_updated)
	if LocalizationManager:
		LocalizationManager.language_changed.connect(func(_l: String) -> void:
			if visible:
				refresh_all()
		)
	
	_register_nodes()
	refresh_all()


func _draw() -> void:
	# Draw dynamic DAG connection lines between parent and child nodes
	if not nodes_container:
		return
	
	for edge: Dictionary in DAG_EDGES:
		var parent_id: String = edge.get("parent", "")
		var child_id: String = edge.get("child", "")
		
		if not _node_instances.has(parent_id) or not _node_instances.has(child_id):
			continue
		
		var parent_node: SkillTreeNode = _node_instances[parent_id]
		var child_node: SkillTreeNode = _node_instances[child_id]
		
		if not is_instance_valid(parent_node) or not is_instance_valid(child_node):
			continue
		
		var parent_center: Vector2 = parent_node.global_position + (parent_node.size / 2.0) - global_position
		var child_center: Vector2 = child_node.global_position + (child_node.size / 2.0) - global_position
		
		var is_child_active: bool = GlobalState.get_perk_level(child_id) > 0
		var is_parent_active: bool = GlobalState.get_perk_level(parent_id) > 0
		
		var line_color: Color = edge.get("color", Color.CYAN)
		var line_width: float = 3.0
		
		if not is_parent_active:
			line_color = Color(0.18, 0.22, 0.32, 0.4)
			line_width = 2.0
		elif not is_child_active:
			line_color = line_color.lerp(Color.BLACK, 0.4)
			line_width = 2.5
		
		draw_line(parent_center, child_center, line_color, line_width, true)


## Register and wire up all child SkillTreeNode instances.
func _register_nodes() -> void:
	_node_instances.clear()
	if not nodes_container:
		return
	
	for child: Node in nodes_container.get_children():
		if child is SkillTreeNode:
			var node_item: SkillTreeNode = child as SkillTreeNode
			if not node_item.perk_id.is_empty():
				_node_instances[node_item.perk_id] = node_item
				if not node_item.upgrade_requested.is_connected(_on_node_upgrade_requested):
					node_item.upgrade_requested.connect(_on_node_upgrade_requested)


## Refresh all nodes, header labels, and redraw graph edges.
func refresh_all() -> void:
	if cores_label and LocalizationManager:
		cores_label.text = "%s: %d" % [LocalizationManager.get_text("UI_META_CORES", "META-CORES"), GlobalState.meta_cores]
	elif cores_label:
		cores_label.text = "META-CORES: %d" % GlobalState.meta_cores
		
	if respec_button and LocalizationManager:
		respec_button.text = LocalizationManager.get_text("UI_RESPEC", "RESPEC (REFUND ALL)")
	if close_button and LocalizationManager:
		close_button.text = LocalizationManager.get_text("UI_CLOSE", "CLOSE")
	
	for perk_id: String in _node_instances:
		var node_item: SkillTreeNode = _node_instances[perk_id]
		if is_instance_valid(node_item):
			node_item.refresh()
	
	queue_redraw()


## Open and show the skill tree modal.
func open() -> void:
	show()
	refresh_all()


## Close and hide the skill tree modal.
func close() -> void:
	hide()
	closed.emit()


func _on_node_upgrade_requested(perk_id: String) -> void:
	if GlobalState.unlock_perk(perk_id):
		refresh_all()


func _on_respec_pressed() -> void:
	GlobalState.refund_all_perks()
	refresh_all()


func _on_meta_cores_changed(_amount: int, _delta: int) -> void:
	refresh_all()


func _on_perks_updated(_perks: Dictionary) -> void:
	refresh_all()
