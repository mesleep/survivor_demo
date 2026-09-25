## 科技三件套的套装配置（T25 / D09）。
##
## 输入：需要的装备 ID 列表、要求的质变分支、移速倍率、飞行视觉偏移与发射器武器。
## 输出：供 PlayerActor 判定套装激活并施加可撤销的运行时能力。
## 扩展点：激光等后续能力在此继续加字段，不在脚本里写死。
class_name TechSetDefinition
extends Resource

@export var required_equipment_ids: Array[StringName] = []
## 三件都必须选择该质变分支（D09：必须都是科技质变）。
@export var required_branch_id: StringName = &"tech"
## 激活后的全武器移速倍率（以运行时修正实现，可撤销）。
@export_range(1.0, 3.0, 0.05) var move_speed_multiplier: float = 1.4
## 飞行表现：视觉节点上移像素，仅表现，不绕过 World 碰撞。
@export_range(0.0, 64.0, 1.0) var float_visual_offset: float = 12.0
## 激活后额外授予的数据驱动武器（科技发射器）；为空则不授予。
@export var launcher_weapon: WeaponDefinition
