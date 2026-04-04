# atomic_action.gd
# 原子操作，每个 Command 会被分解为一个有序的 AtomicAction 列表
class_name AtomicAction
extends RefCounted

enum Type {
	DEAL_DAMAGE,
	RESTORE_HEALTH,
	SUMMON_MINION,
	DESTROY_MINION,
	TRIGGER_DEATHRATTLE,
	APPLY_BUFF,
	DRAW_CARD,
	SPEND_MANA,
}

var type: Type
var source: GameEntity   # 来源（用于执行时读取攻击力等）
var target: GameEntity   # 目标
var value: int           # 数值（0 = 执行时从 source 读取）
var data: Dictionary     # 附加数据

func _init(p_type: Type, p_target: GameEntity = null,
		p_value: int = 0, p_source: GameEntity = null,
		p_data: Dictionary = {}) -> void:
	type = p_type
	target = p_target
	value = p_value
	source = p_source
	data = p_data
