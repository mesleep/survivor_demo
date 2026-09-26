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
	## 同一次攻击周期内额外射击轮数（T13，独立于弹数与穿透）。
	VOLLEY_COUNT,
	## 命中后触发一次性范围爆炸（T16）；弹体由 projectile_definition 指定，value 未使用。
	EXPLOSION,
	## 爆炸范围倍率（T16 爆炸分支专属升级，value 为每级增量）。
	EXPLOSION_RADIUS,
	## 爆炸溅射伤害倍率（T16 爆炸分支专属升级，value 为每级增量）。
	EXPLOSION_DAMAGE,
	## 命中后施加持续伤害并留下地面区域（T17）；弹体由 projectile_definition 指定。
	FLAME,
	## 地面区域持续时间倍率（T17 火焰分支专属升级，value 为每级增量）。
	AREA_DURATION,
	## 单武器索敌射程倍率（T18 威能分支专属升级，value 为每级增量）。
	WEAPON_RANGE,
	## 应用 weapon_modifier 捆绑修正（T18 威能质变），type 分支本身不做数值处理。
	WEAPON_MODIFIER,
	## 命中后施加移动减速（T19 寒冰分支）；弹体由 projectile_definition 指定。
	ICE,
	## 冻结持续时间倍率（T19 寒冰分支专属升级，value 为每级增量）。
	FREEZE_DURATION,
	## 分裂弹体数量加成（T19 寒冰分支专属升级，value 为每级增量）。
	SPLIT_COUNT,
	## 附魔箭：把弓的弹体切换为对应法杖质变的附魔箭（T20，D08 快照继承）。
	ENCHANT_ARROW,
	## 反伤刺甲：启用刺圈并按档案设置受击返还比例（T21）。
	THORN_AURA,
	## 刺圈半径倍率（T21 反伤刺甲专属升级，value 为每级增量）。
	THORN_RADIUS,
	## 受击返还比例增量（T21 反伤刺甲专属升级，value 为每级增量）。
	REFLECT_RATIO,
	## 骑士盔甲：写入固定减伤与完全免伤概率（T22）。
	KNIGHT_ARMOR,
	## 骑士盔甲固定减伤增量（T22 专属升级，value 为每级增量）。
	KNIGHT_DEFENSE,
	## 骑士盔甲完全免伤概率增量（T22 专属升级，value 为每级增量）。
	KNIGHT_IMMUNE,
	## 狂战盔甲：启用持续失血与基础吸血（T23）。
	BERSERK_ARMOR,
	## 狂战盔甲降低失血量（T23 专属升级，value 为每级减免值）。
	BERSERK_DRAIN,
	## 狂战盔甲半血增吸血（T23 专属升级，value 为每级增量）。
	BERSERK_LIFESTEAL,
	## 狂战盔甲一次免死（T23 专属升级，max_stacks=1）。
	BERSERK_IMMUNITY,
	## 科技单件质变：授予每秒经验与宝石经验倍率（T24）。
	TECH_ASCENSION,
	## 金币奖励：满级后的兜底选项，value 为获得金币数。
	COIN_REWARD,
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

@export_group("基础信息")
@export var id: StringName
@export var display_name: String
@export_multiline var description: String
@export var icon: Texture2D
@export var type: UpgradeType
@export var category: UpgradeCategory = UpgradeCategory.GENERIC
@export var value: float
@export_group("装备要求")
## 非空时只对指定武器生效，未持有时不会进入候选池。
@export var required_weapon_id: StringName
## 目标装备 ID；为空时回退 required_weapon_id，避免重复维护两份 ID。
@export var target_equipment_id: StringName
## 质变卡：本卡授予的分支 ID；分支专属卡：要求已选中的分支 ID。
@export var branch_id: StringName
@export_group("授予内容")
## 获取武器类升级所授予的只读配置。
@export var weapon_definition: WeaponDefinition
## 获取防具类升级所授予的只读配置（与 weapon_definition 二选一）。
@export var armor_definition: ArmorDefinition
## EXPLOSION 质变切换到的弹体配置（T16）。
@export var projectile_definition: ProjectileDefinition
## 捆绑武器修正（T18 威能质变等）；非空时在升级应用时合并到目标武器。
@export var weapon_modifier: WeaponRuntimeModifier
@export_group("前置条件")
## 前置装备要求（T20 附魔箭需要已质变法杖），与 required_weapon_id 独立。
@export var required_equipment_id: StringName
## 前置装备必须已选择的分支 ID；为空只要求持有该装备。
@export var required_equipment_branch_id: StringName
@export_group("质变档案")
## THORN_AURA 质变引用的反伤刺甲数值档案（T21）。
@export var thorn_armor: ThornArmorDefinition
## KNIGHT_ARMOR 质变引用的骑士盔甲数值档案（T22）。
@export var knight_armor: KnightArmorDefinition
## BERSERK_ARMOR 质变引用的狂战盔甲数值档案（T23）。
@export var berserk_armor: BerserkArmorDefinition
## TECH_ASCENSION 质变引用的科技单件数值档案（T24）。
@export var tech_armor: TechArmorDefinition
@export_group("抽取规则")
@export_range(1, 100, 1) var max_stacks: int = 5
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0


## 统一解析目标装备：优先 target_equipment_id，兼容旧的 required_weapon_id。
func get_target_equipment_id() -> StringName:
	return target_equipment_id if target_equipment_id != StringName() else required_weapon_id
