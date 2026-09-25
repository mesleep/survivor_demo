## 敌人的共享基础配置。
##
## 输入：场景、生命、移速、接触伤害、经验与生成成本。
## 输出：供 EnemyActor 和后续生成系统只读使用的数据。
## 扩展点：不同敌人通过新 Resource 配置，不复制基础追踪行为。
class_name EnemyDefinition
extends Resource

## 攻击方式：接触伤害；或保持距离发射弹体（T33）。
enum AttackType { MELEE, RANGED }

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export_range(1.0, 1000000.0, 1.0) var max_health: float = 10.0
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 80.0
@export_range(0.0, 100000.0, 1.0) var contact_damage: float = 5.0
@export_range(0, 100000, 1) var experience_value: int = 1
@export_range(0.0, 100000.0, 0.1) var spawn_cost: float = 1.0
@export var is_boss: bool = false
## 是否免疫减速/冻结等控制（Boss 默认免疫，T19）。
@export var control_immune: bool = false
## 攻击方式（T33）：MELEE 靠接触伤害，RANGED 保持距离发射弹体。
@export var attack_type: AttackType = AttackType.MELEE
@export_range(0.0, 3000.0, 1.0) var attack_range: float = 420.0
@export_range(0.05, 30.0, 0.05) var attack_cooldown_seconds: float = 1.8
## 远程敌人希望保持的距离；低于该距离会后退。
@export_range(0.0, 3000.0, 1.0) var preferred_distance: float = 300.0
## 远程敌人发射的弹体；attack_type=RANGED 时必填。
@export var projectile_definition: ProjectileDefinition
