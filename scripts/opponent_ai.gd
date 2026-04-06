# opponent_ai.gd
# 职责：监听回合信号，在对手回合做出决策并提交给 BattleSystem
# 不涉及任何视觉，纯逻辑
extends Node
class_name OpponentAI

const PLAYER_ID = 1
const THINK_DELAY = 1.5 # 模拟"思考"的延迟，秒

@export var battle_system: BattleSystem

func _ready():
	assert(battle_system != null, "OpponentAI 需要绑定 BattleSystem")
	battle_system.turn_started.connect(_on_turn_started)

# ── 回合开始 ──────────────────────────────────────

func _on_turn_started(player_id: int, _turn: int) -> void:
	if player_id != PLAYER_ID:
		return
	# 延迟一下再行动，避免瞬间结束显得突兀
	await get_tree().create_timer(THINK_DELAY).timeout
	_take_turn()

# ── AI 决策 ───────────────────────────────────────

func _take_turn() -> void:
	# 出一张随机打得起的牌
	_try_play_card()
	# 直接结束回合
	_end_turn()

func _try_play_card() -> void:
	var hand: Array = battle_system.hand[PLAYER_ID]
	if hand.is_empty():
		return

	# 过滤出打得起的牌
	var current_mana: int = battle_system.get_mana(PLAYER_ID)
	var affordable: Array = hand.filter(func(c): return c.cost <= current_mana)
	if affordable.is_empty():
		return

	# 随机选一张
	var chosen: CardData = affordable[randi() % affordable.size()]

	var cmd = BattleCommand.new(
		BattleCommand.Type.PLAY_MINION,
		battle_system.heroes.get(PLAYER_ID),
		null,
		chosen
	)

	var accepted = battle_system.submit_command(cmd)
	if accepted:
		print("[OpponentAI] 出牌：", chosen.card_name)
	else:
		print("[OpponentAI] 出牌被拒绝")

func _end_turn() -> void:
	var cmd = BattleCommand.new(BattleCommand.Type.END_TURN)
	battle_system.submit_command(cmd)
	print("[OpponentAI] 结束回合")
