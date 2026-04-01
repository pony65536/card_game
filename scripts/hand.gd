extends HBoxContainer
class_name Hand

const CardScene = preload("res://scenes/card.tscn") # 你的卡牌场景

var cards: Array = []

# 添加一张卡到手牌
func add_card(card_data: CardData):
	var card = CardScene.instantiate()
	card.card_data = card_data
	add_child(card)
	cards.append(card)

# 从手牌移除一张卡（打出时调用）
func remove_card(card):
	cards.erase(card)
	card.queue_free()