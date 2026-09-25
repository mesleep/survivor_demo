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
	ACQUIRE_ARMOR,
	## 全武器索敌射程倍率（角色级通用属性，D06 采用“最终索敌值”语义）。
	ALL_WEAPON_RANGE,
	## 防御/闪避/免疫（T10 伤害结算基座，数值可在 Resource 调整）。
	DEFENSE,
	DODGE_CHANCE,
	IMMUNE_CHANCE,
}

## 升级分类：决定统一的前置、互斥与上限过滤（T06）。
## GENERIC 通用属性；ACQUIRE_EQUIPMENT 获取装备；BASE_UPGRADE 装备基础升级；
## ASCENSION 一次性互斥质变；BRANCH_UPGRADE 质变专属升级。
enum UpgradeCategory {
	GENERIC,
	ACQUIRE_EQUIPMENT,
	BASE_UPGRADE,
	ASCENSION,
	BRANCH_UPGRADE,
}

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var type: UpgradeType
@export var category: UpgradeCategory = UpgradeCategory.GENERIC
@export var value: float
## 非空时只对指定武器生效，未持有时不会进入候选池。
@export var required_weapon_id: StringName
## 目标装备 ID；为空时回退 required_weapon_id，避免重复维护两份 ID。
@export var target_equipment_id: StringName
## 质变卡：本卡授予的分支 ID；分支专属卡：要求已选中的分支 ID。
@export var branch_id: StringName
## 获取武器类升级所授予的只读配置。
@export var weapon_definition: WeaponDefinition
## 获取防具类升级所授予的只读配置（与 weapon_definition 二选一）。
@export var armor_definition: ArmorDefinition
@export_range(1, 100, 1) var max_stacks: int = 5
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0


## 统一解析目标装备：优先 target_equipment_id，兼容旧的 required_weapon_id。
func get_target_equipment_id() -> StringName:
	return target_equipment_id if target_equipment_id != StringName() else required_weapon_id
