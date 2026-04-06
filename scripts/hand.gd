# hand.gd
# 容器层：管理手牌节点生命周期，统一连接卡牌信号并向上转发
extends Node2D
class_name Hand
 
signal card_play_requested(card: Control, card_data: CardData) # 转发给 Game
 
const CardScene = preload("res://scenes/card.tscn")
 
var cards: Array = []
 
@export var base_scale: float = 0.5
@export var overlap: float = 120.0
@export var max_fan_angle: float = 15.0
@export var card_y_arc: float = 50.0
@export var max_x_squeeze: float = 0.1
 
func _ready():
	pass
 
# ── 增删卡牌 ──────────────────────────────────────
 
func add_card(data: CardData):
	var card = CardScene.instantiate()
	card.card_data = data
	add_child(card)
	cards.append(card)
 
	# 在拥有节点的容器里统一连接信号
	card.play_requested.connect(_on_card_play_requested)
	card.drag_canceled.connect(_on_card_drag_canceled)
 
	await get_tree().process_frame
	_update_layout()
 
func remove_card(card: Control):
	cards.erase(card)
	card.play_animation_then_free()
	_update_layout()
 
# ── 信号处理（转发给 Game）────────────────────────
 
func _on_card_play_requested(card: Control):
	# Hand 知道这张卡，直接把 card_data 一起上报
	emit_signal("card_play_requested", card, card.card_data)
 
func _on_card_drag_canceled(card: Control):
	card.return_to_hand()
 
# ── 布局（不变）─────────────────────────────────
 
func _update_layout():
	var n = cards.size()
	if n == 0:
		return
	
	var screen_w = get_viewport().get_visible_rect().size.x
	var screen_h = get_viewport().get_visible_rect().size.y
	var center_x = screen_w / 2.0
	
	# 5. 调整基础 Y轴位置，可能需要让手牌再整体往下一点，给拱形腾出空间
	var base_y = screen_h * 0.75
	
	var card_w = Globals.CARD_WIDTH * base_scale
	var spacing = card_w - overlap
	
	# 计算总宽度时加入挤压，牌越多挤压越明显
	var dynamic_total_width = card_w + spacing * (n - 1) * (1.0 - (float(n) / 10.0) * max_x_squeeze)
	
	# 宽度超出限制时的处理保持不变，或者略微放宽
	if dynamic_total_width > screen_w * 0.90:
		spacing = (screen_w * 0.90 - card_w) / max(n - 1, 1)
		dynamic_total_width = card_w + spacing * (n - 1)
	
	var start_x = center_x - dynamic_total_width / 2.0

	for i in range(n):
		var card = cards[i]
		var t = float(i) / float(n - 1) - 0.5 if n > 1 else 0.0
		
		# ── 1. 旋转计算 ──
		var angle = sin(t * PI) * max_fan_angle
		
		# ── 2. 弧线计算 (修正点) ──
		# 修改为正值：两端 (t=0.5) 时 arc_offset = card_y_arc (向下掉)
		# 中间 (t=0) 时 arc_offset = 0 (保持在 base_y)
		var arc_offset = card_y_arc * (4.0 * t * t)
		
		# ── 3. 属性应用 ──
		card.pivot_offset = Vector2(Globals.CARD_WIDTH / 2.0, Globals.CARD_HEIGHT * 1.5)
		card.rotation_degrees = angle
		card.scale = Vector2(base_scale, base_scale)
		card.z_index = i
		
		# ── 4. 坐标对齐 (万能公式) ──
		var target_x = start_x + spacing * i
		# 这里的 base_y 现在代表手牌“拱顶”的 Y 坐标
		var target_y = base_y + arc_offset
		
		# 重点：直接减去 (pivot_offset * scale) 来完全抵消支点造成的视觉位移
		# 这样无论你 pivot 设在哪，卡牌的旋转中心都会精准对齐到 (target_x, target_y)
		card.position = Vector2(target_x, target_y) - card.pivot_offset * base_scale

		card.original_position = card.position
