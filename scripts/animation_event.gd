# animation_event.gd
# 表现层事件，逻辑层结算完后一次性发给 UI 层
class_name AnimationEvent
extends RefCounted

var event_type: String     # 动画类型名，UI 层 match 这个字符串
var params: Dictionary     # 动画参数

func _init(p_type: String, p_params: Dictionary = {}) -> void:
	event_type = p_type
	params = p_params
