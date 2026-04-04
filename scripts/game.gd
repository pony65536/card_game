# game.gd
# 编排层：连接 Hand 和 BattleSystem，把 UI 意图翻译成规则命令
extends Control
 
@onready var hand = $Hand
@onready var battle_system = $BattleSystem
 
func _ready():
	# ── 初始化测试战场数据 ────────────────────────
	var player_hero = GameEntity.new()
	player_hero.id = "hero_0"
	player_hero.entity_name = "我方英雄"
	player_hero.hp = 30
	player_hero.max_hp = 30
	player_hero.attack = 0
	player_hero.owner_id = 0
	battle_system.heroes[0] = player_hero
 
	var enemy_hero = GameEntity.new()
	enemy_hero.id = "hero_1"
	enemy_hero.entity_name = "对方英雄"
	enemy_hero.hp = 30
	enemy_hero.max_hp = 30
	enemy_hero.attack = 0
	enemy_hero.owner_id = 1
	battle_system.heroes[1] = enemy_hero
 
	# ── 连接信号 ─────────────────────────────────
	hand.card_play_requested.connect(_on_card_play_requested)
	battle_system.animation_events_ready.connect(_on_animation_events_ready)
	battle_system.game_state_changed.connect(_on_game_state_changed)
 
	# ── 测试：加三张手牌 ──────────────────────────
	var murloc = load("res://resources/cards/murloc.tres")
	hand.add_card(murloc)
	hand.add_card(murloc)
	hand.add_card(murloc)
 
# ── Hand 信号处理 ─────────────────────────────────
 
func _on_card_play_requested(card: Control, card_data: CardData):
	print("[Game] 收到出牌请求：", card_data.card_name)
 
	# 把 CardData 转成 BattleCommand 需要的 Dictionary
	var card_dict = {
		"id": card_data.card_name,
		"name": card_data.card_name,
		"cost": card_data.get("cost") if card_data.get("cost") else 0,
		"hp": card_data.health,
		"attack": card_data.attack,
	}
 
	# 打出随从：source 用玩家英雄，target 暂时传位置 0
	var cmd = BattleCommand.new(
		BattleCommand.Type.PLAY_MINION,
		battle_system.heroes[0], # 玩家英雄作为 source
		null,
		card_dict
	)
 
	var accepted = battle_system.submit_command(cmd)
	if accepted:
		hand.remove_card(card)
	else:
		# 规则层拒绝（如费用不足、状态锁定），卡牌回手
		card.return_to_hand()
 
# ── BattleSystem 信号处理 ─────────────────────────
 
func _on_animation_events_ready(events: Array):
	print("[Game] 收到 %d 个动画事件" % events.size())
	for e in events:
		match e.event_type:
			"summon_minion":
				print("[动画] 召唤随从 id=%s" % e.params.get("minion_id", "?"))
			"take_damage":
				print("[动画] 受伤 target=%s amount=%d" % [
					e.params.get("target_id", "?"),
					e.params.get("amount", 0)
				])
			"minion_death":
				print("[动画] 随从死亡 id=%s" % e.params.get("minion_id", "?"))
			"spend_mana":
				print("[动画] 消耗法力 %d" % e.params.get("amount", 0))
			_:
				print("[动画] ", e.event_type, e.params)
 
func _on_game_state_changed(new_state: int):
	match new_state:
		BattleSystem.State.WAITING_INPUT:
			print("[Game] 解锁输入")
		BattleSystem.State.RESOLVING:
			print("[Game] 锁定输入（结算中）")
		BattleSystem.State.GAME_OVER:
			print("[Game] 游戏结束")
