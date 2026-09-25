## 携带一次性金币的拾取物（T26）。
##
## 输入：掉落数量与进入范围的 PlayerActor。
## 输出：collected 信号，并把金币累加到玩家的本局内存余额。
## 扩展点：吸附移动和正式金币动画可后续替换；同一实例只结算一次。
class_name CoinPickup
extends Area2D

signal collected(coin: CoinPickup, amount: int)

var _amount: int = 0
var _is_collected: bool = false


func initialize(amount: int) -> void:
	_amount = maxi(amount, 0)
	_is_collected = false
	monitorable = _amount > 0


## 原子化拾取；重复调用或非法收集者都不会重复入账。
func collect(collector: PlayerActor) -> bool:
	if _is_collected or _amount <= 0:
		return false
	if not is_instance_valid(collector) or collector.is_queued_for_deletion():
		return false
	if collector.health_component.is_dead():
		return false

	_is_collected = true
	set_deferred("monitorable", false)
	collector.add_coins(_amount)
	collected.emit(self, _amount)
	queue_free()
	return true


func get_amount() -> int:
	return _amount


func is_collected() -> bool:
	return _is_collected
