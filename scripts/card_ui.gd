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

var target_rotation: float = 0.0

func _process(delta):
	if is_dragging:
		var target_pos = get_global_mouse_position() - drag_offset
		
		# 1. 更加物理的位移：增加跟随速度
		# 0.25 改为基于 delta 的动态值，25.0 是跟随强度，数值越大越跟手
		global_position = global_position.lerp(target_pos, 25.0 * delta)
		
		# 2. 改进的旋转逻辑
		# 计算鼠标移动速度
		var move_velocity = get_global_mouse_position() - (global_position + drag_offset)
		
		# 计算目标旋转角度（往哪边动就往哪边斜）
		target_rotation = clamp(move_velocity.x * 0.02, -0.25, 0.25)
		
		# 对旋转本身进行平滑插值，消除抖动
		rotation = lerp_angle(rotation, target_rotation, 10.0 * delta)
	else:
		# 没拖拽时，旋转平滑归零
		rotation = lerp_angle(rotation, 0, 10.0 * delta)

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
