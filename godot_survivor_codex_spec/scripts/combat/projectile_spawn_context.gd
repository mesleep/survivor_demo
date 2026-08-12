## 单次子弹生成的运行时上下文。
##
## 输入：发射者、阵营、初始位置与方向、伤害倍率、可选目标和武器 ID。
## 输出：从 WeaponController 传递给 ProjectileBase 的独立数据对象。
## 扩展点：暴击结果、状态效果和轨迹参数可继续加入，不修改共享 Resource。
class_name ProjectileSpawnContext
extends RefCounted

var shooter: ActorBase
var team_id: StringName = &"neutral"
var spawn_position: Vector2 = Vector2.ZERO
var initial_direction: Vector2 = Vector2.RIGHT
var damage_multiplier: float = 1.0
var lifesteal_ratio: float = 0.0
var target: Node2D
var weapon_id: StringName


func _init(
		new_shooter: ActorBase = null,
		new_team_id: StringName = &"neutral",
		new_spawn_position: Vector2 = Vector2.ZERO,
		new_initial_direction: Vector2 = Vector2.RIGHT
) -> void:
	shooter = new_shooter
	team_id = new_team_id
	spawn_position = new_spawn_position
	initial_direction = new_initial_direction.normalized() if not new_initial_direction.is_zero_approx() else Vector2.RIGHT
