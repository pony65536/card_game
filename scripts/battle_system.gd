# battle_system.gd
# 核心战斗系统，作为节点挂在 game.tscn 的子节点上
class_name BattleSystem
extends Node

# ── 信号 ──────────────────────────────────────────
signal animation_events_ready(events: Array) # 发给表现层
signal game_state_changed(new_state: int)

# ── 游戏状态枚举 ───────────────────────────────────
enum State {
	WAITING_INPUT, # 空闲，接受输入
	RESOLVING, # 结算中，锁定输入
	GAME_OVER,
}

# ── 内部数据 ───────────────────────────────────────
var _state: int = State.WAITING_INPUT
var _command_queue: Array = [] # BattleCommand 队列
var _pending_animations: Array = [] # AnimationEvent 列表

# 战场数据（key = owner_id，value = GameEntity 数组）
var board: Dictionary = {0: [], 1: []}
var heroes: Dictionary = {} # owner_id → GameEntity

# ── 回合与法力 ─────────────────────────────────────
var active_player: int = 0
var turn_number: int = 1
var mana: Dictionary = {0: 0, 1: 0}
var max_mana: Dictionary = {0: 0, 1: 0}

# ── 牌库与手牌 ─────────────────────────────────────
# deck[player_id] = Array of CardData（剩余牌库）
# hand[player_id] = Array of CardData（当前手牌，逻辑层维护）
var deck: Dictionary = {0: [], 1: []}
var hand: Dictionary = {0: [], 1: []}
const MAX_HAND_SIZE: int = 10

# 信号
signal turn_started(player_id: int, turn: int)
signal mana_changed(player_id: int, current: int, maximum: int)
signal card_drawn(player_id: int, card_data: CardData) # 通知表现层加一张牌到手
signal hand_full(player_id: int) # 爆牌提示


# ══════════════════════════════════════════════════
# 公共接口
# ══════════════════════════════════════════════════

## 游戏开始时调用，初始化第一回合
func start_game() -> void:
	active_player = 0
	turn_number = 1
	_begin_turn(0)

## 设置牌库（game.gd 在 start_game 前调用）
func setup_deck(player_id: int, cards: Array) -> void:
	deck[player_id] = cards.duplicate()
	deck[player_id].shuffle()

## 直接抽牌（game.gd 初始手牌时调用）
## 返回抽到的 CardData，爆牌或牌库空时返回 null
func draw_card_for_player(player_id: int) -> CardData:
	if hand[player_id].size() >= MAX_HAND_SIZE:
		print("[BattleSystem] 玩家 %d 手牌已满，爆牌" % player_id)
		emit_signal("hand_full", player_id)
		return null
	if deck[player_id].is_empty():
		print("[BattleSystem] 玩家 %d 牌库已空" % player_id)
		return null
	var card: CardData = deck[player_id].pop_front()
	hand[player_id].append(card)
	emit_signal("card_drawn", player_id, card)
	return card

## 从手牌移除一张（打出后调用）
func remove_from_hand(player_id: int, card_data: CardData) -> void:
	hand[player_id].erase(card_data)

## UI 层调用这个函数提交玩家操作
func submit_command(cmd: BattleCommand) -> bool:
	if _state != State.WAITING_INPUT:
		print("[BattleSystem] 当前锁定，拒绝输入：", cmd.to_string())
		return false
	# 攻击指令校验
	if cmd.type == BattleCommand.Type.MINION_ATTACK:
		if cmd.source.owner_id != active_player:
			print("[BattleSystem] 不是你的回合")
			return false
		if cmd.source.has_attacked:
			print("[BattleSystem] 该随从本回合已攻击过")
			return false
	# 出牌指令：检查法力
	if cmd.type == BattleCommand.Type.PLAY_MINION or cmd.type == BattleCommand.Type.PLAY_SPELL:
		var cost = cmd.card_data.get("cost", 0)
		if mana[active_player] < cost:
			print("[BattleSystem] 法力不足")
			return false
	_command_queue.append(cmd)
	print("[BattleSystem] 入队：", cmd.to_string())
	_process_queue()
	return true

func get_state() -> int:
	return _state

func get_mana(player_id: int) -> int:
	return mana.get(player_id, 0)

func get_max_mana(player_id: int) -> int:
	return max_mana.get(player_id, 0)


# ══════════════════════════════════════════════════
# 队列处理
# ══════════════════════════════════════════════════

func _process_queue() -> void:
	if _command_queue.is_empty() or _state == State.RESOLVING:
		return

	_set_state(State.RESOLVING)

	while not _command_queue.is_empty():
		var cmd: BattleCommand = _command_queue.pop_front()
		_resolve_command(cmd)

	_flush_animations()
	_set_state(State.WAITING_INPUT)


# ══════════════════════════════════════════════════
# Command → 原子操作
# ══════════════════════════════════════════════════

func _resolve_command(cmd: BattleCommand) -> void:
	print("[BattleSystem] 结算：", cmd.to_string())
	var atoms: Array = []

	match cmd.type:
		BattleCommand.Type.MINION_ATTACK:
			atoms = _build_minion_attack(cmd.source, cmd.target)
			cmd.source.has_attacked = true # 标记本回合已攻击
		BattleCommand.Type.PLAY_MINION:
			var cost = cmd.card_data.get("cost", 0)
			mana[active_player] = max(0, mana[active_player] - cost)
			emit_signal("mana_changed", active_player, mana[active_player], max_mana[active_player])
			atoms = _build_play_minion(cmd.source, cmd.card_data, cmd.target)
		BattleCommand.Type.PLAY_SPELL:
			var cost = cmd.card_data.get("cost", 0)
			mana[active_player] = max(0, mana[active_player] - cost)
			emit_signal("mana_changed", active_player, mana[active_player], max_mana[active_player])
			atoms = _build_play_spell(cmd.source, cmd.card_data, cmd.target)
		BattleCommand.Type.HERO_POWER:
			atoms = _build_hero_power(cmd.source, cmd.target)
		BattleCommand.Type.END_TURN:
			_end_turn()
			return # 回合结束单独处理，不走原子操作
		_:
			push_warning("[BattleSystem] 未处理的 CommandType: %d" % cmd.type)

	for atom in atoms:
		_execute_atom(atom)

	# ⭐ 每个 Command 结算完统一做死亡检查
	_check_deaths()


# ══════════════════════════════════════════════════
# 原子操作构建
# ══════════════════════════════════════════════════

func _build_minion_attack(attacker: GameEntity, defender: GameEntity) -> Array:
	return [
		# value=0：执行时才从 source.attack 读取，保证数值是当前值
		AtomicAction.new(AtomicAction.Type.DEAL_DAMAGE, defender, 0, attacker),
		AtomicAction.new(AtomicAction.Type.DEAL_DAMAGE, attacker, 0, defender),
	]

func _build_play_minion(player: GameEntity, card: Dictionary, position) -> Array:
	var atoms: Array = []
	atoms.append(AtomicAction.new(AtomicAction.Type.SPEND_MANA, player, card.get("cost", 0)))
	atoms.append(AtomicAction.new(AtomicAction.Type.SUMMON_MINION, null, 0, null, {
		"owner_id": player.owner_id,
		"card": card,
		"position": position if position is int else board[player.owner_id].size(),
	}))
	return atoms

func _build_play_spell(player: GameEntity, card: Dictionary, target: GameEntity) -> Array:
	var atoms: Array = []
	atoms.append(AtomicAction.new(AtomicAction.Type.SPEND_MANA, player, card.get("cost", 0)))
	match card.get("spell_type", ""):
		"damage":
			atoms.append(AtomicAction.new(AtomicAction.Type.DEAL_DAMAGE, target, card.get("value", 0), player))
		"heal":
			atoms.append(AtomicAction.new(AtomicAction.Type.RESTORE_HEALTH, target, card.get("value", 0), player))
	return atoms

func _build_hero_power(hero: GameEntity, target: GameEntity) -> Array:
	return [
		AtomicAction.new(AtomicAction.Type.SPEND_MANA, hero, 2),
		AtomicAction.new(AtomicAction.Type.DEAL_DAMAGE, target, 1, hero),
	]


# ══════════════════════════════════════════════════
# 执行原子操作
# ══════════════════════════════════════════════════

func _execute_atom(atom: AtomicAction) -> void:
	match atom.type:
		AtomicAction.Type.DEAL_DAMAGE:
			# value == 0 时从来源读攻击力
			var amount: int = atom.value if atom.value > 0 else atom.source.attack
			var actual: int = atom.target.take_damage(amount)
			print("[Atom] %s 受到 %d 伤害，剩余 HP: %d" % [
				atom.target.entity_name, actual, atom.target.hp])
			_pending_animations.append(AnimationEvent.new("take_damage", {
				"target_id": atom.target.id,
				"amount": actual,
			}))

		AtomicAction.Type.RESTORE_HEALTH:
			var actual: int = atom.target.heal(atom.value)
			print("[Atom] %s 恢复 %d HP" % [atom.target.entity_name, actual])
			_pending_animations.append(AnimationEvent.new("heal", {
				"target_id": atom.target.id,
				"amount": actual,
			}))

		AtomicAction.Type.SUMMON_MINION:
			var d: Dictionary = atom.data
			var minion: GameEntity = _make_minion(d.card, d.owner_id)
			var pos: int = d.get("position", board[d.owner_id].size())
			board[d.owner_id].insert(pos, minion)
			print("[Atom] 召唤：", minion.entity_name)
			_pending_animations.append(AnimationEvent.new("summon_minion", {
				"minion_id": minion.id,
				"owner_id": d.owner_id,
				"position": pos,
			}))

		AtomicAction.Type.DESTROY_MINION:
			_remove_from_board(atom.target)
			_pending_animations.append(AnimationEvent.new("destroy_minion", {
				"minion_id": atom.target.id,
			}))

		AtomicAction.Type.SPEND_MANA:
			print("[Atom] 消耗法力 %d" % atom.value)
			_pending_animations.append(AnimationEvent.new("spend_mana", {
				"amount": atom.value,
			}))

		AtomicAction.Type.DRAW_CARD:
			var pid: int = atom.data.get("player_id", 0)
			var drawn = draw_card_for_player(pid)
			if drawn:
				print("[Atom] 玩家 %d 抽到：%s" % [pid, drawn.card_name])
			else:
				print("[Atom] 玩家 %d 无法抽牌" % pid)
			_pending_animations.append(AnimationEvent.new("draw_card", {
				"player_id": pid,
			}))

		AtomicAction.Type.APPLY_BUFF:
			atom.target.attack += atom.data.get("attack_bonus", 0)
			atom.target.max_hp += atom.data.get("hp_bonus", 0)
			atom.target.hp += atom.data.get("hp_bonus", 0)
			_pending_animations.append(AnimationEvent.new("apply_buff", {
				"target_id": atom.target.id,
			}))

		AtomicAction.Type.TRIGGER_DEATHRATTLE:
			print("[Atom] 亡语触发：", atom.source.entity_name)
			_pending_animations.append(AnimationEvent.new("deathrattle", {
				"source_id": atom.source.id,
			}))


# ══════════════════════════════════════════════════
# 死亡检查（每个 Command 结算完后统一调用）
# ══════════════════════════════════════════════════

func _check_deaths() -> void:
	var dead: Array = []
	for pid in board:
		for minion in board[pid]:
			if minion.is_dead():
				dead.append(minion)

	if dead.is_empty():
		return

	print("[BattleSystem] 死亡检查：%d 个随从阵亡" % dead.size())

	# 触发亡语（按上场顺序，此处简化：直接顺序触发）
	for minion in dead:
		# 如果之后给 GameEntity 加了亡语数据，在这里处理
		_remove_from_board(minion)
		_pending_animations.append(AnimationEvent.new("minion_death", {
			"minion_id": minion.id,
		}))

	# 检查英雄死亡
	for pid in heroes:
		if heroes[pid].is_dead():
			print("[BattleSystem] 玩家 %d 英雄死亡" % pid)
			_set_state(State.GAME_OVER)
			return

	# 亡语可能造成新的死亡，递归检查
	_check_deaths()


# ══════════════════════════════════════════════════
# 工具方法
# ══════════════════════════════════════════════════

func _make_minion(card: Dictionary, owner_id: int) -> GameEntity:
	var m := GameEntity.new()
	m.id = "%s_%d" % [card.get("id", "minion"), Time.get_ticks_msec()]
	m.entity_name = card.get("name", "随从")
	m.hp = card.get("hp", 1)
	m.max_hp = m.hp
	m.attack = card.get("attack", 1)
	m.owner_id = owner_id
	return m

func _remove_from_board(minion: GameEntity) -> void:
	for pid in board:
		board[pid].erase(minion)

# ══════════════════════════════════════════════════
# 回合管理
# ══════════════════════════════════════════════════

func _begin_turn(player_id: int) -> void:
	active_player = player_id
	max_mana[player_id] = min(max_mana[player_id] + 1, 10)
	mana[player_id] = max_mana[player_id]
	for minion in board[player_id]:
		minion.has_attacked = false
	print("[BattleSystem] 回合 %d 开始，玩家 %d，法力 %d/%d" % [
		turn_number, player_id, mana[player_id], max_mana[player_id]])
	emit_signal("mana_changed", player_id, mana[player_id], max_mana[player_id])
	# 回合开始抽一张牌
	draw_card_for_player(player_id)
	emit_signal("turn_started", player_id, turn_number)

func _end_turn() -> void:
	print("[BattleSystem] 玩家 %d 结束回合" % active_player)
	_pending_animations.append(AnimationEvent.new("end_turn", {
		"player_id": active_player,
	}))
	# 切换到对方回合
	var next_player = 1 - active_player
	if next_player == 0:
		turn_number += 1
	_begin_turn(next_player)

func _set_state(new_state: int) -> void:
	_state = new_state
	emit_signal("game_state_changed", new_state)
	print("[BattleSystem] 状态：", State.keys()[new_state])

func _flush_animations() -> void:
	if _pending_animations.is_empty():
		return
	var to_send: Array = _pending_animations.duplicate()
	_pending_animations.clear()
	print("[BattleSystem] 发送 %d 个动画事件" % to_send.size())
	emit_signal("animation_events_ready", to_send)
