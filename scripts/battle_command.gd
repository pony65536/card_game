# battle_command.gd
# 玩家操作指令，UI 层创建后压入 BattleSystem 的队列
class_name BattleCommand
extends RefCounted

enum Type {
	PLAY_MINION,
	PLAY_SPELL,
	MINION_ATTACK,
	HERO_ATTACK,
	HERO_POWER,
	END_TURN,
}

var type: Type
var source: GameEntity # 操作发起者
var target: GameEntity # 操作目标（可为 null）
var card_data: Dictionary # 打出手牌时携带的卡牌数据

func _init(p_type: Type, p_source: GameEntity = null,
		p_target: GameEntity = null, p_card: Dictionary = {}) -> void:
	type = p_type
	source = p_source
	target = p_target
	card_data = p_card

func _to_string() -> String:
	return "Command[%s] %s → %s" % [
		Type.keys()[type],
		source.entity_name if source else "null",
		target.entity_name if target else "null",
	]
