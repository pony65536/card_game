extends Control

@onready var hand = $Hand

func _ready():
	# 测试：加载鱼人卡并添加到手牌
	var murloc = load("res://resources/cards/murloc.tres")
	# hand.add_card(murloc)
	hand.add_card(murloc)
	hand.add_card(murloc)
	hand.add_card(murloc)
	# var CardScene = preload("res://scenes/card.tscn")
	# var card = CardScene.instantiate()
	# card.card_data = load("res://resources/cards/murloc.tres")
	# card.position = Vector2(100, 100)
	# card.scale = Vector2(0.3, 0.3)
	# add_child(card)
