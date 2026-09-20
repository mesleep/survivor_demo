## 角色的纯表现组件：根据父角色速度切换静止、移动帧与左右朝向。
## 不改变角色位置、碰撞体或战斗状态；受伤反馈仍可独立作用于本节点。
class_name ActorSprite
extends AnimatedSprite2D

@onready var actor: CharacterBody2D = get_parent() as CharacterBody2D


func _process(_delta: float) -> void:
	if actor == null:
		return
	var moving: bool = actor.is_physics_processing() and actor.velocity.length_squared() > 1.0
	play(&"walk" if moving else &"idle")
	if moving and absf(actor.velocity.x) > 1.0:
		flip_h = actor.velocity.x < 0.0
