# minion.gd
# 战场上的随从节点，负责显示和点击交互
extends Control

signal minion_clicked(minion_node: Control) # 通知 BoardUI 被点击了

@onready var portrait = $Portraint # 注意：场景里拼的是 Portraint
@onready var attack_label = $AttackLabel
@onready var health_label = $HealthLabel

# 对应的逻辑层实体
var entity: GameEntity = null

# 是否属于玩家（影响点击行为）
var is_player_minion: bool = true

# 是否被选中（攻击者高亮）
var selected: bool = false:
	set(value):
		selected = value
		modulate = Color(1.5, 1.5, 0.5) if value else Color.WHITE

func _ready():
	mouse_filter = Control.MOUSE_FILTER_STOP
	pivot_offset = size / 2.0

func setup(e: GameEntity, player_side: bool) -> void:
	entity = e
	is_player_minion = player_side
	_refresh()

func _refresh() -> void:
	if entity == null:
		return
	attack_label.text = str(entity.attack)
	health_label.text = str(entity.hp)
	# 头像暂时留空，之后接 CardData 的 portrait

func refresh_stats() -> void:
	_refresh()

# ── 点击交互 ──────────────────────────────────────

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			emit_signal("minion_clicked", self )

# ── 受伤动画（简单抖动）──────────────────────────

func play_damage_animation() -> void:
	var t = create_tween()
	t.tween_property(self , "position:x", position.x - 8, 0.05)
	t.tween_property(self , "position:x", position.x + 8, 0.05)
	t.tween_property(self , "position:x", position.x, 0.05)

# ── 死亡动画 ─────────────────────────────────────

func play_death_animation() -> void:
	var t = create_tween()
	t.tween_property(self , "modulate:a", 0.0, 0.3)
	t.tween_callback(queue_free)