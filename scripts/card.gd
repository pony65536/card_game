# card.gd
extends Control

signal drag_started(card: Control)
signal drag_canceled(card: Control)
signal play_requested(card: Control)

@onready var name_label = $NameLabel
@onready var atk_label = $AttackLabel
@onready var hp_label = $HealthLabel
@onready var art_sprite = $CardPortrait

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

@export var card_data: CardData:
	set(value):
		card_data = value
		if is_node_ready():
			_update_ui()

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = false
	# 确保 size 与你的素材比例一致
	size = Vector2(480, 720)
	if card_data:
		_update_ui()

func _update_ui():
	name_label.text = card_data.card_name
	atk_label.text = str(card_data.attack)
	hp_label.text = str(card_data.health)
	if card_data.portrait:
		art_sprite.texture = card_data.portrait

func _gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_dragging()
		else:
			_stop_dragging()

func _process(delta):
	if is_dragging:
		# 平滑跟随鼠标
		var target_pos = get_global_mouse_position() - drag_offset
		global_position = global_position.lerp(target_pos, 25.0 * delta)
		
		# 增加拖拽时的倾斜摆动效果（灵动感）
		var move_velocity = get_global_mouse_position() - (global_position + drag_offset)
		var tilt = clamp(move_velocity.x * 0.02, -0.25, 0.25)
		rotation = lerp_angle(rotation, tilt, 10.0 * delta)

func _start_dragging():
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	z_index = 100
	emit_signal("drag_started", self )
	
	var t = create_tween()
	t.tween_property(self , "scale", Vector2(0.55, 0.55), 0.1) # 稍微放大表示抓起

func _stop_dragging():
	is_dragging = false
	z_index = 0
	var screen_h = get_viewport_rect().size.y
	
	if global_position.y < screen_h * 0.6:
		emit_signal("play_requested", self )
	else:
		# 自身不处理回弹，只喊一声，让 Hand 重新排版
		emit_signal("drag_canceled", self )

# 由 Hand 调用：统一的位移指令
func move_to_target(target_pos: Vector2, target_rot: float, target_scale: Vector2, duration: float = 0.3):
	var t = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self , "position", target_pos, duration)
	t.tween_property(self , "rotation", target_rot, duration)
	t.tween_property(self , "scale", target_scale, duration)

func play_animation_then_free():
	var t = create_tween()
	t.tween_property(self , "modulate:a", 0.0, 0.2)
	t.tween_callback(queue_free)