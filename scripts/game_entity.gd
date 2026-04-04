# game_entity.gd
# 游戏实体基类，随从和英雄都继承自这里
class_name GameEntity
extends RefCounted

var id: String
var entity_name: String
var hp: int
var max_hp: int
var attack: int
var owner_id: int # 0 = 玩家, 1 = 对手
var has_attacked: bool = false

func is_dead() -> bool:
	return hp <= 0

func take_damage(amount: int) -> int:
	var actual = amount
	hp -= actual
	hp = max(hp, 0)
	return actual

func heal(amount: int) -> int:
	var actual = min(amount, max_hp - hp)
	hp += actual
	return actual

func _to_string() -> String:
	return "%s(hp=%d/%d atk=%d)" % [entity_name, hp, max_hp, attack]
