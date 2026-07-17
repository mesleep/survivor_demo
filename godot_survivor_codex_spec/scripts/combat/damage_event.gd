## 单次伤害的运行时数据对象。
##
## 输入：伤害数值、来源、位置、标签和击退信息。
## 输出：在 Hitbox、Hurtbox、Actor 和 HealthComponent 之间传递的不共享事件。
## 扩展点：后续可增加武器 ID、暴击结果和状态效果，无需改变生命组件接口。
class_name DamageEvent
extends RefCounted

var amount: float = 0.0
var source: Node
var source_position: Vector2 = Vector2.ZERO
var tags: Array[StringName] = []
var can_crit: bool = false
var knockback_strength: float = 0.0


func _init(
		new_amount: float = 0.0,
		new_source: Node = null,
		new_source_position: Vector2 = Vector2.ZERO
) -> void:
	amount = new_amount
	source = new_source
	source_position = new_source_position
