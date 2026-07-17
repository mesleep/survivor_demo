## 角色的共享基础配置。
##
## 输入：角色场景、基础生命、移动速度与拾取范围。
## 输出：供 GameSession 和角色运行时行为只读使用的数据。
## 扩展点：起始武器将在武器 Resource 实现后收窄为专用类型。
class_name CharacterDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 220.0
@export_range(0.0, 2000.0, 1.0) var pickup_radius: float = 96.0
@export var starting_weapons: Array[Resource] = []
