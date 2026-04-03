extends Node2D
class_name Hand

const CardScene = preload("res://scenes/card.tscn")
var cards: Array = []

const CARD_WIDTH = 480.0
const CARD_HEIGHT = 720.0
const BASE_SCALE = 0.22
const HOVER_SCALE = 0.38
const OVERLAP = 120.0
const MAX_FAN_ANGLE = 8.0
const CARD_Y_ARC = 18.0
const HOVER_LIFT = 120.0

var hovered_card = null

func _ready():
	pass

func add_card(card_data: CardData):
	var card = CardScene.instantiate()
	card.card_data = card_data
	add_child(card)
	cards.append(card)
	card.mouse_entered.connect(_on_card_hovered.bind(card))
	card.mouse_exited.connect(_on_card_unhovered.bind(card))
	await get_tree().process_frame
	_update_layout()

func remove_card(card):
	cards.erase(card)
	card.queue_free()
	_update_layout()

func _on_card_hovered(card):
	hovered_card = card
	_update_layout()

func _on_card_unhovered(card):
	if hovered_card == card:
		hovered_card = null
	_update_layout()

func _update_layout():
	var n = cards.size()
	if n == 0:
		return

	# var screen_size = get_tree().root.size
	# var screen_w = float(screen_size.x)
	# var screen_h = float(screen_size.y)

	var screen_w = 1920.0
	var screen_h = 1080.0

	var center_x = screen_w / 2.0
	var base_y = screen_h * 0.88 # 这里也改小一点，比如改成 screen_h * 0.88

	var card_w = CARD_WIDTH * BASE_SCALE
	var spacing = card_w - OVERLAP
	var total_width = card_w + spacing * (n - 1)
	if total_width > screen_w * 0.85:
		spacing = (screen_w * 0.85 - card_w) / max(n - 1, 1)
		total_width = card_w + spacing * (n - 1)

	var start_x = center_x - total_width / 2.0

	for i in range(n):
		var card = cards[i]
		var t = 0.5 if n == 1 else float(i) / float(n - 1)

		var angle = lerp(-MAX_FAN_ANGLE, MAX_FAN_ANGLE, t)
		var arc_offset = CARD_Y_ARC * 4.0 * (t - 0.5) * (t - 0.5)

		var target_x = start_x + spacing * i
		var target_y = base_y + arc_offset
		var target_scale = BASE_SCALE
		var target_angle = angle
		var target_z = i

		if card == hovered_card:
			target_y -= HOVER_LIFT
			target_scale = HOVER_SCALE
			target_angle = 0.0
			target_z = 100

		card.pivot_offset = Vector2(CARD_WIDTH / 2.0, CARD_HEIGHT)
		card.scale = Vector2(target_scale, target_scale)
		card.rotation_degrees = target_angle
		card.z_index = target_z
		card.position = Vector2(
			target_x - (CARD_WIDTH / 2.0) * target_scale,
			target_y - CARD_HEIGHT * target_scale
		)
		print("Card[", i, "] final position=", card.position, " visible=", card.visible, " modulate=", card.modulate)