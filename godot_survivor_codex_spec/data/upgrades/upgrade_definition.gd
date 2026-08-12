## 升级选项的共享只读配置。
##
## 输入：显示文本、效果类型、数值、最大层数与预留权重。
## 输出：供 UpgradeSystem 筛选并由 PlayerActor 应用的定义数据。
class_name UpgradeDefinition
extends Resource

enum UpgradeType {
	DAMAGE_MULTIPLIER,
	FIRE_RATE_MULTIPLIER,
	PROJECTILE_COUNT,
	MOVE_SPEED_MULTIPLIER,
	MAX_HEALTH,
	HEAL,
	BONUS_PROJECTILE_CHANCE,
	PROJECTILE_LIFESTEAL,
	PICKUP_RANGE_MULTIPLIER,
	REPEAT_SHOT_CHANCE,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var type: UpgradeType
@export var value: float
@export_range(1, 100, 1) var max_stacks: int = 5
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
