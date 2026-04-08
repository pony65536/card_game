# board_ui.gd
# 战场 UI 管理器，监听动画事件，实例化/销毁随从节点，处理攻击选择
extends Node2D

signal attack_command_requested(attacker: GameEntity, target: GameEntity)

const MinionScene = preload("res://scenes/Minion.tscn")

# 战场布局参数
@export var player_board_y: float = 550.0 # 我方随从的 Y 坐标
@export var enemy_board_y: float = 300.0 # 敌方随从的 Y 坐标
@export var minion_spacing: float = 220.0 # 随从间距
@export var minion_size: Vector2 = Vector2(200, 240)

# entity_id → Minion节点
var _minion_nodes: Dictionary = {}

# 攻击选择状态
enum SelectState {IDLE, WAITING_TARGET}
var _select_state: int = SelectState.IDLE
var _selected_node = null # 选中的我方随从节点


# ══════════════════════════════════════════════════
# 动画事件入口（由 game.gd 调用）
# ══════════════════════════════════════════════════

func handle_animation_event(e: AnimationEvent) -> void:
	match e.event_type:
		"summon_minion":
			_on_summon(e.params)
		"take_damage":
			_on_take_damage(e.params)
		"minion_death":
			_on_minion_death(e.params)


# ══════════════════════════════════════════════════
# 召唤随从
# ══════════════════════════════════════════════════

func _on_summon(params: Dictionary) -> void:
	var minion_id: String = params.get("minion_id", "")
	var owner_id: int = params.get("owner_id", 0)

	# 从 BattleSystem 找到对应的 GameEntity
	var battle_system = get_parent().get_node("BattleSystem")
	var entity: GameEntity = _find_entity(battle_system, minion_id)
	if entity == null:
		push_warning("[BoardUI] 找不到实体：%s" % minion_id)
		return

	var node = MinionScene.instantiate()
	node.size = minion_size
	add_child(node)
	node.setup(entity, owner_id == 0)

	# 连接点击信号
	node.minion_clicked.connect(_on_minion_clicked)

	_minion_nodes[minion_id] = node
	_relayout(owner_id)

	# 召唤动画：从小放大
	node.scale = Vector2(0.1, 0.1)
	var t = create_tween()
	t.tween_property(node, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BACK)


# ══════════════════════════════════════════════════
# 受伤
# ══════════════════════════════════════════════════

func _on_take_damage(params: Dictionary) -> void:
	var target_id: String = params.get("target_id", "")
	if _minion_nodes.has(target_id):
		var node = _minion_nodes[target_id]
		node.refresh_stats()
		node.play_damage_animation()


# ══════════════════════════════════════════════════
# 死亡
# ══════════════════════════════════════════════════

func _on_minion_death(params: Dictionary) -> void:
	var minion_id: String = params.get("minion_id", "")
	if not _minion_nodes.has(minion_id):
		return
	var node = _minion_nodes[minion_id]
	_minion_nodes.erase(minion_id)

	# 播完死亡动画后重新排列
	var owner_id = 0 if node.is_player_minion else 1
	node.play_death_animation()
	await get_tree().create_timer(0.35).timeout
	_relayout(owner_id)


# ══════════════════════════════════════════════════
# 点击交互（攻击选择）
# ══════════════════════════════════════════════════

func _on_minion_clicked(node) -> void:
	# 我方随从：选为攻击者
	if node.is_player_minion:
		if node.entity.has_attacked:
			print("[BoardUI] 该随从本回合已攻击过")
			return
		# 取消上一个选中
		if _selected_node != null:
			_selected_node.selected = false
		_selected_node = node
		node.selected = true
		_select_state = SelectState.WAITING_TARGET
		print("[BoardUI] 选中攻击者：", node.entity.entity_name)

	# 敌方随从：作为目标
	else:
		if _select_state != SelectState.WAITING_TARGET:
			print("[BoardUI] 请先选中我方随从")
			return
		print("[BoardUI] 目标：", node.entity.entity_name)
		emit_signal("attack_command_requested",
			_selected_node.entity, node.entity)
		_selected_node.selected = false
		_selected_node = null
		_select_state = SelectState.IDLE

## 点击空白处取消选择（由 game.gd 的 _unhandled_input 调用）
func cancel_selection() -> void:
	if _selected_node != null:
		_selected_node.selected = false
		_selected_node = null
	_select_state = SelectState.IDLE


# ══════════════════════════════════════════════════
# 布局：重新排列某一方的随从
# ══════════════════════════════════════════════════

func _relayout(owner_id: int) -> void:
	# 收集该玩家的所有存活随从节点
	var nodes: Array = []
	for id in _minion_nodes:
		var n = _minion_nodes[id]
		if (n.is_player_minion and owner_id == 0) or \
		   (not n.is_player_minion and owner_id == 1):
			nodes.append(n)

	if nodes.is_empty():
		return

	var screen_w = get_viewport().get_visible_rect().size.x
	var center_x = screen_w / 2.0
	var y = player_board_y if owner_id == 0 else enemy_board_y
	var total_w = nodes.size() * minion_size.x + (nodes.size() - 1) * (minion_spacing - minion_size.x)
	var start_x = center_x - total_w / 2.0

	for i in range(nodes.size()):
		var target_x = start_x + i * minion_spacing
		var t = create_tween()
		t.tween_property(nodes[i], "position",
			Vector2(target_x, y - minion_size.y / 2.0), 0.15)


# ══════════════════════════════════════════════════
# 工具
# ══════════════════════════════════════════════════

func _find_entity(battle_system, minion_id: String) -> GameEntity:
	for pid in battle_system.board:
		for e in battle_system.board[pid]:
			if e.id == minion_id:
				return e
	return null
