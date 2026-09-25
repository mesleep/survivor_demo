## 狂战盔甲的持续失血组件（T23）。
##
## 输入：BerserkArmorDefinition（含运行时失血减免）与所属玩家。
## 输出：按固定周期直接扣除生命（绕过防御），默认不致死，并发布 drained 信号。
## 扩展点：失血是否致死、周期与数值都由档案控制。
class_name BerserkDrainComponent
extends Node

signal drained(amount: float)

var _owner_actor: ActorBase
var _definition: BerserkArmorDefinition
var _drain_reduction: float = 0.0
var _elapsed: float = 0.0
var _tick_count: int = 0


func initialize(owner_actor: ActorBase, definition: BerserkArmorDefinition) -> void:
	_owner_actor = owner_actor
	_definition = definition
	_elapsed = 0.0
	_tick_count = 0


## 降低每次失血量（专属升级）；不低于 0。
func set_drain_reduction(value: float) -> void:
	_drain_reduction = maxf(value, 0.0)


func get_effective_drain() -> float:
	if _definition == null or not _definition.drain_enabled:
		return 0.0
	return maxf(_definition.drain_per_tick - _drain_reduction, 0.0)


func get_tick_count() -> int:
	return _tick_count


func _process(delta: float) -> void:
	advance_time(delta)


## 推进指定时间；测试传入固定步长即可精确断言失血 tick。
func advance_time(delta: float) -> void:
	if _definition == null or not _definition.drain_enabled or delta <= 0.0:
		return
	if not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
		return
	_elapsed += delta
	var interval: float = maxf(_definition.drain_interval_seconds, 0.05)
	while _elapsed + 0.0001 >= float(_tick_count + 1) * interval:
		_apply_drain()
		_tick_count += 1


## 失血绕过防御与免疫，直接扣生命；默认不致死。
func _apply_drain() -> void:
	var current: float = _owner_actor.health_component.current_health
	if current <= 0.0:
		return
	var amount: float = get_effective_drain()
	if _definition.drain_non_lethal:
		amount = minf(amount, maxf(current - 1.0, 0.0))
	if amount <= 0.0:
		return
	var event := DamageEvent.new(amount, null, _owner_actor.global_position)
	event.tags = [&"dot", &"berserk"]
	_owner_actor.health_component.apply_damage(event)
	drained.emit(amount)
