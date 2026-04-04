# hand.gd
# 容器层：管理手牌节点生命周期，统一连接卡牌信号并向上转发
extends Node2D
class_name Hand
 
signal card_play_requested(card: Control, card_data: CardData) # 转发给 Game
 
const CardScene = preload("res://scenes/card.tscn")
 
var cards: Array = []
 
@export var base_scale: float = 0.8
@export var overlap: float = 150.0
@export var max_fan_angle: float = 10.0
@export var card_y_arc: float = 30.0
 
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
	var base_y = screen_h + 50.0
	var card_w = Globals.CARD_WIDTH * base_scale
	var spacing = card_w - overlap
	var total_width = card_w + spacing * (n - 1)
	if total_width > screen_w * 0.85:
		spacing = (screen_w * 0.85 - card_w) / max(n - 1, 1)
		total_width = card_w + spacing * (n - 1)
	var start_x = center_x - total_width / 2.0
 
	for i in range(n):
		var card = cards[i]
		var t = 0.5 if n == 1 else float(i) / float(n - 1)
		var angle = lerp(-max_fan_angle, max_fan_angle, t)
		var arc_offset = card_y_arc * 4.0 * (t - 0.5) * (t - 0.5)
 
		card.pivot_offset = Vector2(Globals.CARD_WIDTH / 2.0, Globals.CARD_HEIGHT)
		card.scale = Vector2(base_scale, base_scale)
		card.rotation_degrees = angle
		card.z_index = i
		card.position = Vector2(
			start_x + spacing * i - (Globals.CARD_WIDTH / 2.0) * base_scale,
			base_y + arc_offset - Globals.CARD_HEIGHT * base_scale
		)
		# 更新回手基准位置
		card.original_position = card.position
