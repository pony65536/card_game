# game.gd
extends Control

@onready var hand = $Hand
@onready var battle_system = $BattleSystem
@onready var my_minion_btn = $Board/MyMinion
@onready var enemy_minion_btn = $Board/EnemyMinion
@onready var end_turn_btn = $EndTurnButton
@onready var mana_label = $ManaLabel
@onready var board_ui = $BoardUI

const STATE_WAITING = 0
const STATE_RESOLVING = 1
const STATE_GAME_OVER = 2

enum SelectState {IDLE, WAITING_TARGET}
var _select_state: int = SelectState.IDLE
var _selected_attacker: GameEntity = null

var my_minion_entity: GameEntity = null
var enemy_minion_entity: GameEntity = null

func _ready():
	# ── 英雄 ──────────────────────────────────────
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

	# ── 测试随从 ──────────────────────────────────
	my_minion_entity = GameEntity.new()
	my_minion_entity.id = "my_minion"
	my_minion_entity.entity_name = "我方随从"
	my_minion_entity.hp = 3
	my_minion_entity.max_hp = 3
	my_minion_entity.attack = 2
	my_minion_entity.owner_id = 0
	battle_system.board[0].append(my_minion_entity)

	enemy_minion_entity = GameEntity.new()
	enemy_minion_entity.id = "enemy_minion"
	enemy_minion_entity.entity_name = "敌方随从"
	enemy_minion_entity.hp = 4
	enemy_minion_entity.max_hp = 4
	enemy_minion_entity.attack = 1
	enemy_minion_entity.owner_id = 1
	battle_system.board[1].append(enemy_minion_entity)

	var fake_summon_event = AnimationEvent.new("summon_minion", {
		"minion_id": enemy_minion_entity.id,
		"owner_id": 1,
		"position": 0,
	})
	# 等 BoardUI ready 之后再调用
	await get_tree().process_frame
	board_ui.handle_animation_event(fake_summon_event)
	$Board.visible = false

	# ── 建牌库（用鱼人填满，之后换成真实牌库）────
	var murloc = load("res://resources/cards/murloc.tres")
	var player_deck: Array = []
	var enemy_deck: Array = []
	for i in range(10):
		player_deck.append(murloc)
		enemy_deck.append(murloc)
	battle_system.setup_deck(0, player_deck)
	battle_system.setup_deck(1, enemy_deck)

	# ── 连接信号 ──────────────────────────────────
	my_minion_btn.pressed.connect(_on_my_minion_pressed)
	enemy_minion_btn.pressed.connect(_on_enemy_minion_pressed)
	end_turn_btn.pressed.connect(_on_end_turn_pressed)

	hand.card_play_requested.connect(_on_card_play_requested)
	battle_system.animation_events_ready.connect(_on_animation_events_ready)
	battle_system.game_state_changed.connect(_on_game_state_changed)
	battle_system.turn_started.connect(_on_turn_started)
	battle_system.mana_changed.connect(_on_mana_changed)
	battle_system.card_drawn.connect(_on_card_drawn)
	battle_system.hand_full.connect(_on_hand_full)

	board_ui.attack_command_requested.connect(_on_board_attack_requested)

	# ── 初始手牌：各抽4张，然后开始游戏 ──────────
	for i in range(4):
		battle_system.draw_card_for_player(0)
		battle_system.draw_card_for_player(1)

	battle_system.start_game()
	_refresh_minion_buttons()

# ── 抽牌信号 ──────────────────────────────────────

func _on_card_drawn(player_id: int, card_data: CardData):
	if player_id == 0:
		# 只把我方的牌加到手牌UI
		hand.add_card(card_data)
		print("[Game] 抽到：%s（费用%d）" % [card_data.card_name, card_data.cost])

func _on_hand_full(player_id: int):
	if player_id == 0:
		print("[Game] 手牌已满，爆牌！")

# ── 结束回合 ──────────────────────────────────────

func _on_end_turn_pressed():
	if battle_system.get_state() != STATE_WAITING:
		return
	if battle_system.active_player != 0:
		return
	var cmd = BattleCommand.new(BattleCommand.Type.END_TURN)
	battle_system.submit_command(cmd)

# ── 攻击选择 ──────────────────────────────────────

func _on_my_minion_pressed():
	if battle_system.get_state() != STATE_WAITING:
		return
	if battle_system.active_player != 0:
		return
	if my_minion_entity.is_dead():
		return
	if my_minion_entity.has_attacked:
		print("[Game] 该随从本回合已攻击过")
		return
	_select_state = SelectState.WAITING_TARGET
	_selected_attacker = my_minion_entity
	my_minion_btn.text = _minion_label(my_minion_entity) + "  [选中]"
	print("[Game] 选中：", my_minion_entity.entity_name)

func _on_enemy_minion_pressed():
	if _select_state != SelectState.WAITING_TARGET:
		print("[Game] 请先选中我方随从")
		return
	var cmd = BattleCommand.new(
		BattleCommand.Type.MINION_ATTACK,
		_selected_attacker,
		enemy_minion_entity
	)
	battle_system.submit_command(cmd)
	_select_state = SelectState.IDLE
	_selected_attacker = null

func _unhandled_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed:
		board_ui.cancel_selection()

# ── 打出手牌 ──────────────────────────────────────

func _on_card_play_requested(card: Control, card_data: CardData):
	print("[Game] 出牌：%s（费用%d）" % [card_data.card_name, card_data.cost])
	var card_dict = {
		"id": card_data.card_name,
		"name": card_data.card_name,
		"cost": card_data.cost,
		"hp": card_data.health,
		"attack": card_data.attack,
	}
	var cmd = BattleCommand.new(
		BattleCommand.Type.PLAY_MINION,
		battle_system.heroes[0],
		null,
		card_dict
	)
	if battle_system.submit_command(cmd):
		battle_system.remove_from_hand(0, card_data)
		hand.remove_card(card)
	else:
		hand._on_card_drag_canceled(card)

# ── BattleSystem 信号 ─────────────────────────────

func _on_animation_events_ready(events: Array):
	for e in events:
		board_ui.handle_animation_event(e)
		match e.event_type:
			"take_damage":
				print("[动画] %s 受到 %d 伤害" % [
					e.params.get("target_id", "?"), e.params.get("amount", 0)])
			"minion_death":
				_on_minion_died(e.params.get("minion_id", ""))
			_:
				print("[动画] ", e.event_type, e.params)
	_refresh_minion_buttons()

func _on_game_state_changed(new_state: int):
	match new_state:
		STATE_WAITING: print("[Game] 解锁输入")
		STATE_RESOLVING: print("[Game] 结算中...")
		STATE_GAME_OVER: print("[Game] 游戏结束")

func _on_turn_started(player_id: int, turn: int):
	print("[Game] 回合 %d 开始，玩家 %d" % [turn, player_id])
	end_turn_btn.disabled = (player_id != 0)
	if player_id == 1:
		print("[Game] 对手回合，自动结束（无AI）")
		await get_tree().create_timer(1.0).timeout
		var cmd = BattleCommand.new(BattleCommand.Type.END_TURN)
		battle_system.submit_command(cmd)

func _on_mana_changed(player_id: int, current: int, maximum: int):
	if player_id == 0:
		mana_label.text = "法力：%d / %d" % [current, maximum]

func _on_board_attack_requested(attacker: GameEntity, target: GameEntity):
	var cmd = BattleCommand.new(
		BattleCommand.Type.MINION_ATTACK, attacker, target)
	battle_system.submit_command(cmd)

# ── 工具 ──────────────────────────────────────────

func _on_minion_died(minion_id: String):
	if minion_id == my_minion_entity.id:
		my_minion_btn.disabled = true
		my_minion_btn.text = "我方随从 [死亡]"
	elif minion_id == enemy_minion_entity.id:
		enemy_minion_btn.disabled = true
		enemy_minion_btn.text = "敌方随从 [死亡]"

func _refresh_minion_buttons():
	if not my_minion_entity.is_dead():
		var label = _minion_label(my_minion_entity)
		if my_minion_entity.has_attacked:
			label += "  [已攻击]"
		my_minion_btn.text = label
		my_minion_btn.disabled = false
	if not enemy_minion_entity.is_dead():
		enemy_minion_btn.text = _minion_label(enemy_minion_entity)
		enemy_minion_btn.disabled = false

func _minion_label(e: GameEntity) -> String:
	return "%s  ATK:%d  HP:%d/%d" % [e.entity_name, e.attack, e.hp, e.max_hp]
