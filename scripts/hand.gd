# hand.gd
extends Node2D
class_name Hand

signal card_play_requested(card: Control, card_data: CardData)

const CardScene = preload("res://scenes/card.tscn")

var cards: Array = []

@export var base_scale: float = 0.5
@export var overlap: float = 120.0
@export var max_fan_angle: float = 15.0 # 扇形最大弧度
@export var max_x_squeeze: float = 0.1

# ── 增删卡牌 ──────────────────────────────────────

func add_card(data: CardData):
	var card = CardScene.instantiate()
	card.card_data = data
	add_child(card)
	cards.append(card)
	
	# 连接信号
	card.play_requested.connect(_on_card_play_requested)
	card.drag_canceled.connect(_on_card_drag_canceled)

	# 等待布局生效
	await get_tree().process_frame
	_update_layout(true)

func remove_card(card: Control):
	cards.erase(card)
	card.play_animation_then_free()
	_update_layout(true) # 移除后其余牌平滑归位

# ── 信号处理 ──────────────────────────────────────

func _on_card_play_requested(card: Control):
	emit_signal("card_play_requested", card, card.card_data)

func _on_card_drag_canceled(_card: Control):
	# 只要有牌取消拖拽，就强制执行一次带动画的全局重排
	_update_layout(true)

# ── 核心布局逻辑 ──────────────────────────────────

func _update_layout(animated: bool = false):
	var n = cards.size()
	if n == 0: return

	var viewport_size = get_viewport().get_visible_rect().size
	if viewport_size == Vector2.ZERO: return

	var screen_w = viewport_size.x
	var screen_h = viewport_size.y
	var hand_global = global_position

	# 1. 计算基础参考点
	var center_x = screen_w / 2.0 - hand_global.x
	var base_y = screen_h * 0.85 - hand_global.y # 稍微下移，适配扇形高度

	var card_w = 480.0 * base_scale # 假设卡牌原始宽度 480
	var spacing = card_w - overlap

	# 2. 动态计算总宽度，防止超出屏幕
	var dynamic_total_width = card_w + spacing * (n - 1) * (1.0 - (float(n) / 10.0) * max_x_squeeze)
	if dynamic_total_width > screen_w * 0.9:
		spacing = (screen_w * 0.9 - card_w) / max(n - 1, 1)
		dynamic_total_width = card_w + spacing * (n - 1)

	var start_x = center_x - dynamic_total_width / 2.0

	# 3. 遍历指挥每一张牌
	for i in range(n):
		var card = cards[i]
		if card.is_dragging: continue # 正在拖拽的牌不参与自动布局

		# 计算旋转角度 (弧度)
		var t = float(i) / float(n - 1) - 0.5 if n > 1 else 0.0
		var angle = t * deg_to_rad(max_fan_angle * 2.0)

		# 统一设置旋转中心（放在卡牌下方，营造大半径扇形感）
		card.pivot_offset = Vector2(240, 720 * 1.5)
		
		var target_pos = Vector2(start_x + spacing * i, base_y) - card.pivot_offset * base_scale
		var target_rot = angle
		var target_scale = Vector2(base_scale, base_scale)

		if animated:
			card.move_to_target(target_pos, target_rot, target_scale)
		else:
			card.position = target_pos
			card.rotation = target_rot
			card.scale = target_scale
		
		card.z_index = i