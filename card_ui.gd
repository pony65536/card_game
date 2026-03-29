extends Control

# --- 1. 节点引用 (根据你实际的场景节点名称修改) ---
@onready var name_label = $NameLabel
@onready var atk_label = $AttackLabel
@onready var hp_label = $HealthLabel
@onready var art_sprite = $CardPortrait

# --- 2. 状态变量 ---
var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO
var original_position: Vector2 = Vector2.ZERO

# 这里的 @export 允许你从编辑器把 .tres 文件拖进来测试
@export var card_data: CardData:
	set(value):
		card_data = value
		if is_node_ready():
			_update_ui()


# --- 3. 初始化与生命周期 ---
func _ready():
	print(name_label, atk_label, hp_label, art_sprite)
	# 记录初始位置，用于松手后弹回
	original_position = position
	if card_data:
		_update_ui()

# 核心渲染函数：把数据“刷”到 UI 上
func _update_ui():
	name_label.text = card_data.card_name
	atk_label.text = str(card_data.attack)
	hp_label.text = str(card_data.health)
	if card_data.portrait:
		art_sprite.texture = card_data.portrait

# --- 4. 交互逻辑 (拖拽的核心) ---
func _gui_input(event: InputEvent):
	# 检查是否是鼠标左键
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_start_dragging()
		else:
			_stop_dragging()

func _process(_delta):
	# 如果正在拖拽，每帧更新位置
	if is_dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		# 这里使用 lerp 可以让跟随更丝滑，0.2 是平滑系数
		global_position = global_position.lerp(target_pos, 0.25)
		
		# 炉石小细节：移动时产生一点点倾斜
		var move_velocity = get_global_mouse_position() - (global_position + drag_offset)
		rotation = clamp(move_velocity.x * 0.01, -0.2, 0.2)

# --- 5. 拖拽动作分解 ---
func _start_dragging():
	is_dragging = true
	drag_offset = get_global_mouse_position() - global_position
	z_index = 100 # 确保在最上层
	
	# 放大反馈
	var t = create_tween()
	t.tween_property(self , "scale", Vector2(1.1, 1.1), 0.1)

func _stop_dragging():
	is_dragging = false
	z_index = 0
	rotation = 0 # 重置倾斜
	
	# 简单的判定：如果 Y 坐标小于屏幕高度的一半，视为“打出”
	var screen_size = get_viewport_rect().size
	if global_position.y < screen_size.y * 0.6:
		_play_card()
	else:
		_return_to_hand()

# --- 6. 结果处理 ---
func _return_to_hand():
	var t = create_tween().set_parallel(true)
	t.tween_property(self , "position", original_position, 0.3).set_trans(Tween.TRANS_CUBIC)
	t.tween_property(self , "scale", Vector2(1.0, 1.0), 0.3)

func _play_card():
	# 未来这里会调用 RuleEngine.gd
	print("逻辑层：尝试打出卡牌 ", card_data.card_name)
	
	# 表现层反馈：变绿消失或固定在场上
	var t = create_tween()
	t.tween_property(self , "modulate:a", 0, 0.2)
	t.tween_callback(queue_free) # 暂时销毁，模拟进入战场
