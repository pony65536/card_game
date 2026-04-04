extends Node2D
class_name Hand

const CardScene = preload("res://scenes/card.tscn")
var cards: Array = []

@export var base_scale: float = 0.8
@export var overlap: float = 150.0
@export var max_fan_angle: float = 10.0
@export var card_y_arc: float = 30.0

func _ready():
	pass

func add_card(card_data: CardData):
	var card = CardScene.instantiate()
	card.card_data = card_data
	add_child(card)
	cards.append(card)
	await get_tree().process_frame
	_update_layout()

func remove_card(card):
	cards.erase(card)
	card.queue_free()
	_update_layout()


# func _update_layout():
# 	var n = cards.size()
# 	if n == 0:
# 		return

# 	var viewport = get_viewport()
# 	var screen_w = viewport.get_visible_rect().size.x
# 	var screen_h = viewport.get_visible_rect().size.y

# 	var center_x = screen_w / 2.0
# 	var base_y = screen_h * 0.88 # 这里也改小一点，比如改成 screen_h * 0.88

# 	var card_w = CARD_WIDTH * BASE_SCALE
# 	var spacing = card_w - OVERLAP
# 	var total_width = card_w + spacing * (n - 1)
# 	if total_width > screen_w * 0.85:
# 		spacing = (screen_w * 0.85 - card_w) / max(n - 1, 1)
# 		total_width = card_w + spacing * (n - 1)

# 	var start_x = center_x - total_width / 2.0

# 	for i in range(n):
# 		var card = cards[i]
# 		var t = 0.5 if n == 1 else float(i) / float(n - 1)

# 		var angle = lerp(-MAX_FAN_ANGLE, MAX_FAN_ANGLE, t)
# 		var arc_offset = CARD_Y_ARC * 4.0 * (t - 0.5) * (t - 0.5)

# 		var target_x = start_x + spacing * i
# 		var target_y = base_y + arc_offset
# 		var target_scale = BASE_SCALE
# 		var target_angle = angle
# 		var target_z = i

# 		card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT)
# 		card.scale = Vector2(target_scale, target_scale)
# 		card.rotation_degrees = target_angle
# 		card.z_index = target_z
# 		card.position = Vector2(
# 			target_x - (CARD_WIDTH / 2.0) * target_scale,
# 			target_y - CARD_HEIGHT * target_scale
# 		)
# 		print("Card[", i, "] final position=", card.position, " visible=", card.visible, " modulate=", card.modulate)


func _update_layout():
	var n = cards.size()
	if n == 0:
		return

	# 用视口尺寸替代硬编码
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

		var target_x = start_x + spacing * i
		var target_y = base_y + arc_offset
		var target_scale = base_scale
		var target_angle = angle
		var target_z = i

		card.pivot_offset = Vector2(Globals.CARD_WIDTH / 2.0, Globals.CARD_HEIGHT)
		card.scale = Vector2(target_scale, target_scale)
		card.rotation_degrees = target_angle
		card.z_index = target_z
		card.position = Vector2(
			target_x - (Globals.CARD_WIDTH / 2.0) * target_scale,
			target_y - Globals.CARD_HEIGHT * target_scale
		)
