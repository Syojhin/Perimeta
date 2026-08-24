class_name BuildSocket
extends Area2D

## Interactive build socket for placing, inspecting, upgrading, and selling towers.
## Supports locked territory expansion where outer sockets require Bit investments to unlock.

signal socket_selected(socket: BuildSocket)
signal socket_unlocked(socket: BuildSocket)

enum SocketState {
	LOCKED,
	UNLOCKED_EMPTY,
	OCCUPIED
}

@export var initial_state: SocketState = SocketState.LOCKED
@export var unlock_cost: int = 250

var state: SocketState = SocketState.LOCKED
var current_tower: TowerBase = null
var is_hovered: bool = false

var is_occupied: bool:
	get:
		return state == SocketState.OCCUPIED and is_instance_valid(current_tower)

@onready var socket_ring: Line2D = $Visual/Ring
@onready var socket_pad: Polygon2D = $Visual/Pad
@onready var center_dot: Polygon2D = $Visual/CenterDot
@onready var lock_label: Label = $Visual/LockLabel
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

const COLOR_LOCKED_IDLE: Color = Color(0.4, 0.2, 0.15, 0.45)
const COLOR_LOCKED_HOVER: Color = Color(1.0, 0.55, 0.2, 0.9)
const COLOR_EMPTY_IDLE: Color = Color(0.2, 0.45, 0.65, 0.45)
const COLOR_EMPTY_HOVER: Color = Color(0.4, 0.9, 1.0, 0.9)
const COLOR_OCCUPIED: Color = Color(0.15, 0.22, 0.32, 0.3)


func _ready() -> void:
	input_pickable = true
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	input_event.connect(_on_input_event)
	
	state = initial_state
	_update_visual_state()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_on_socket_clicked()


func _on_socket_clicked() -> void:
	get_viewport().set_input_as_handled()
	
	if state == SocketState.LOCKED:
		_attempt_unlock()
	else:
		socket_selected.emit(self)


func _attempt_unlock() -> void:
	if GlobalState.spend_currency(unlock_cost):
		state = SocketState.UNLOCKED_EMPTY
		_show_unlock_fx()
		_update_visual_state()
		socket_unlocked.emit(self)
	else:
		_show_insufficient_bits_fx()


func _show_unlock_fx() -> void:
	var tween: Tween = create_tween()
	scale = Vector2(1.25, 1.25)
	modulate = Color(2.5, 2.5, 3.0, 1.0)
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.25)


func _show_insufficient_bits_fx() -> void:
	var tween: Tween = create_tween()
	modulate = Color(2.0, 0.4, 0.4, 1.0)
	tween.tween_property(self, "modulate", Color.WHITE, 0.2)


## Build and place a new tower on this socket.
func build_tower(tower_scene: PackedScene) -> TowerBase:
	if state != SocketState.UNLOCKED_EMPTY or not tower_scene:
		return null
	
	var inst: TowerBase = tower_scene.instantiate() as TowerBase
	if not inst:
		return null
	
	add_child(inst)
	inst.position = Vector2.ZERO
	current_tower = inst
	state = SocketState.OCCUPIED
	
	inst.tree_exited.connect(_on_tower_freed)
	_update_visual_state()
	return inst


## Clear and remove any existing tower on this socket.
func clear_socket() -> void:
	if is_instance_valid(current_tower):
		current_tower.queue_free()
		current_tower = null
	
	if state == SocketState.OCCUPIED:
		state = SocketState.UNLOCKED_EMPTY
	_update_visual_state()


## Reset the socket to its initial run state.
func reset_socket() -> void:
	clear_socket()
	state = initial_state
	_update_visual_state()


func _on_tower_freed() -> void:
	current_tower = null
	if state == SocketState.OCCUPIED:
		state = SocketState.UNLOCKED_EMPTY
	_update_visual_state()


func _update_visual_state() -> void:
	if not socket_ring or not socket_pad:
		return
	
	match state:
		SocketState.LOCKED:
			if lock_label:
				lock_label.visible = true
				lock_label.text = "UNLOCK\n%d B" % unlock_cost
				lock_label.modulate = Color(1.0, 0.8, 0.4, 0.9) if is_hovered else Color(0.8, 0.5, 0.3, 0.6)
			
			socket_ring.default_color = COLOR_LOCKED_HOVER if is_hovered else COLOR_LOCKED_IDLE
			socket_ring.width = 2.0
			socket_pad.color = Color(0.15, 0.08, 0.05, 0.3) if is_hovered else Color(0.1, 0.05, 0.03, 0.2)
			if center_dot:
				center_dot.color = Color(1.0, 0.6, 0.2, 0.8) if is_hovered else Color(0.7, 0.3, 0.1, 0.4)
				
		SocketState.UNLOCKED_EMPTY:
			if lock_label:
				lock_label.visible = false
			
			socket_ring.default_color = COLOR_EMPTY_HOVER if is_hovered else COLOR_EMPTY_IDLE
			socket_ring.width = 2.0
			socket_pad.color = Color(0.18, 0.4, 0.6, 0.4) if is_hovered else Color(0.08, 0.14, 0.22, 0.25)
			if center_dot:
				center_dot.color = Color(0.4, 0.9, 1.0, 0.9) if is_hovered else Color(0.3, 0.7, 0.9, 0.6)
				
		SocketState.OCCUPIED:
			if lock_label:
				lock_label.visible = false
			
			socket_ring.default_color = COLOR_OCCUPIED
			socket_ring.width = 1.5
			socket_pad.color = Color(0.08, 0.12, 0.18, 0.4)
			if center_dot:
				center_dot.color = Color(0.2, 0.3, 0.4, 0.3)


func _on_mouse_entered() -> void:
	is_hovered = true
	if is_instance_valid(current_tower):
		current_tower.set_hovered(true)
	_update_visual_state()


func _on_mouse_exited() -> void:
	is_hovered = false
	if is_instance_valid(current_tower):
		current_tower.set_hovered(false)
	_update_visual_state()
