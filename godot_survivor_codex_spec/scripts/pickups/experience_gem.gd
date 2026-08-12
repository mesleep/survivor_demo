## 携带一次性经验值的场景物品。
##
## 输入：敌人配置提供的经验值和进入范围的 PlayerActor。
## 输出：collected 信号，并将经验交给玩家的独立运行时状态。
## 扩展点：吸附移动和不同外观可在后续通过配置或子场景组合。
class_name ExperienceGem
extends Area2D

signal collected(gem: ExperienceGem, experience_value: int)

var _experience_value: int = 0
var _is_collected: bool = false


## 设置本颗宝石携带的经验；不读取或修改 EnemyDefinition。
func initialize(experience_value: int) -> void:
	_experience_value = maxi(experience_value, 0)
	_is_collected = false
	monitorable = _experience_value > 0


## 原子化结算经验，同一实例在释放前重复调用也只会成功一次。
func collect(collector: PlayerActor) -> bool:
	if _is_collected or _experience_value <= 0:
		return false
	if not is_instance_valid(collector) or collector.is_queued_for_deletion():
		return false
	if collector.health_component.is_dead():
		return false

	_is_collected = true
	set_deferred("monitorable", false)
	collector.add_experience(_experience_value)
	collected.emit(self, _experience_value)
	queue_free()
	return true


func get_experience_value() -> int:
	return _experience_value


func is_collected() -> bool:
	return _is_collected
