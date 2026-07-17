## 负责管理角色运行时生命值。
##
## 输入：最大生命值、DamageEvent 和治疗数值。
## 输出：health_changed、damaged 和只触发一次的 died 信号。
## 扩展点：护盾、减伤和持续伤害可在进入该组件前处理。
class_name HealthComponent
extends Node

signal health_changed(current: float, maximum: float)
signal damaged(event: DamageEvent)
signal died(event: DamageEvent)

var current_health: float = 0.0
var maximum_health: float = 0.0
var _dead: bool = false


## 使用新的最大生命完全重置运行时状态。
func initialize(new_maximum_health: float) -> void:
	maximum_health = maxf(new_maximum_health, 0.0)
	current_health = maximum_health
	_dead = false
	health_changed.emit(current_health, maximum_health)


## 应用一次伤害。
##
## 无效、非正数或死亡后的伤害会被忽略；_dead 在 died 发送前设置，保证重入时也只死亡一次。
func apply_damage(event: DamageEvent) -> void:
	if event == null or _dead or event.amount <= 0.0:
		return

	current_health = maxf(current_health - event.amount, 0.0)
	damaged.emit(event)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0:
		_dead = true
		died.emit(event)


func heal(amount: float) -> void:
	if _dead or amount <= 0.0:
		return
	var healed_health: float = minf(current_health + amount, maximum_health)
	if is_equal_approx(healed_health, current_health):
		return
	current_health = healed_health
	health_changed.emit(current_health, maximum_health)


func reset() -> void:
	current_health = maximum_health
	_dead = false
	health_changed.emit(current_health, maximum_health)


func is_dead() -> bool:
	return _dead
