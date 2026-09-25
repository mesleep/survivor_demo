## 敌人的共享基础配置。
##
## 输入：场景、生命、移速、接触伤害、经验与生成成本。
## 输出：供 EnemyActor 和后续生成系统只读使用的数据。
## 扩展点：不同敌人通过新 Resource 配置，不复制基础追踪行为。
class_name EnemyDefinition
extends Resource

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
