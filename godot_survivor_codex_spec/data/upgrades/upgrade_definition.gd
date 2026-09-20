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
	PIERCE_COUNT,
	PROJECTILE_SPEED,
	PROJECTILE_SIZE,
	CRITICAL_CHANCE,
	REGENERATION,
	ACQUIRE_WEAPON,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var type: UpgradeType
@export var value: float
## 非空时只对指定武器生效，未持有时不会进入候选池。
@export var required_weapon_id: StringName
## 获取武器类升级所授予的只读配置。
@export var weapon_definition: WeaponDefinition
@export_range(1, 100, 1) var max_stacks: int = 5
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
