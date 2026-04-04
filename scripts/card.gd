# card.gd
# 交互层：只负责单卡显示和拖拽，出牌意图通过信号上报
extends Control
 
signal play_requested(card: Control) # 通知 Hand：我想被打出
signal drag_started(card: Control)
signal drag_canceled(card: Control)
 
@onready var name_label = $NameLabel
@onready var atk_label = $AttackLabel
@onready var hp_label = $HealthLabel
@onready var art_sprite = $CardPortrait
 
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO
 
@export var card_data: CardData:
	set(value):
		card_data = value
		if is_node_ready():
			_update_ui()
 
func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	size = Vector2(480, 720)
	original_position = position
	if card_data:
		_update_ui()
 
func _update_ui():
	name_label.text = card_data.card_name
	atk_label.text = str(card_data.attack)
	hp_label.text = str(card_data.health)
	if card_data.portrait:
		art_sprite.texture = card_data.portrait
 
# ── 拖拽 ─────────────────────────────────────────
 
func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_dragging()
		else:
			_stop_dragging()
 
var _target_rotation: float = 0.0
 
func _process(delta):
	if is_dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		global_position = global_position.lerp(target_pos, 25.0 * delta)
		var move_velocity = get_global_mouse_position() - (global_position + drag_offset)
		_target_rotation = clamp(move_velocity.x * 0.02, -0.25, 0.25)
		rotation = lerp_angle(rotation, _target_rotation, 10.0 * delta)
	else:
		rotation = lerp_angle(rotation, 0.0, 10.0 * delta)
 
func _start_dragging():
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	z_index = 100
	emit_signal("drag_started", self )
	var t = create_tween()
	t.tween_property(self , "scale", Vector2(1.1, 1.1), 0.1)
 
func _stop_dragging():
	is_dragging = false
	z_index = 0
	var screen_h = get_viewport_rect().size.y
	if global_position.y < screen_h * 0.6:
		# 抬手位置在屏幕上半区 → 发出打出请求，由 Hand 决定后续
		emit_signal("play_requested", self )
	else:
		emit_signal("drag_canceled", self )
		return_to_hand()
 
# ── 表现动作（由 Hand 或 Game 调用）─────────────────
 
func return_to_hand():
	var t = create_tween().set_parallel(true)
	t.tween_property(self , "position", original_position, 0.3).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self , "scale", Vector2(1.0, 1.0), 0.3)
 
func play_animation_then_free():
	var t = create_tween()
	t.tween_property(self , "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)