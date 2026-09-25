## 角色的共享基础配置。
##
## 输入：角色场景、基础生命、移动速度、视野缩放、基础攻击范围、拾取范围与起始武器。
## 输出：供 GameSession 和角色运行时行为只读使用的数据。
## 扩展点：角色差异通过新 Resource 和武器组合实现，不复制玩家脚本。
class_name CharacterDefinition
extends Resource

@export var id: StringName
@export var display_name: String
@export var scene: PackedScene
@export_range(1.0, 10000.0, 1.0) var max_health: float = 100.0
@export_range(0.0, 2000.0, 1.0) var move_speed: float = 220.0
## Camera2D 缩放；小于 1 可看到更大的世界范围，大于 1 则拉近视野。
@export_range(0.25, 2.0, 0.05) var camera_zoom: float = 0.75
@export_range(1.0, 5000.0, 1.0) var base_attack_range: float = 1000.0
@export_range(0.0, 2000.0, 1.0) var pickup_radius: float = 96.0
@export var starting_weapons: Array[WeaponDefinition] = []
## 解锁所需金币；0 表示默认解锁（T29）。
@export_range(0, 1000000, 1) var unlock_cost: int = 0
