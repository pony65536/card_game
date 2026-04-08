# hero.gd
# 职责：显示单个英雄的头像和血量，点击时上报信号
extends Control
class_name Hero

signal clicked(portrait: Hero)

@onready var portrait_texture: TextureRect = $Portrait
@onready var health_label: Label = $HealthLabel
@onready var click_area: Button = $ClickArea

# 对应的逻辑实体，由 Game 在初始化时赋值
var entity: GameEntity = null

func _ready():
	click_area.pressed.connect(_on_clicked)
	# 透明按钮不抢走视觉
	click_area.flat = true
	click_area.modulate.a = 0.0

func setup(e: GameEntity, avatar: Texture2D) -> void:
	entity = e
	portrait_texture.texture = avatar
	_refresh()

func _refresh() -> void:
	if entity == null:
		return
	health_label.text = "%d / %d" % [entity.hp, entity.max_hp]

# 外部调用：受伤后刷新显示
func update_hp() -> void:
	_refresh()

func _on_clicked() -> void:
	emit_signal("clicked", self )
