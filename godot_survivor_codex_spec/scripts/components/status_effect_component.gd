## 管理 Actor 身上的持续伤害状态（T17）。
##
## 输入：DamageOverTimeEffect、来源节点与施加伤害倍率。
## 输出：按固定 tick 间隔对所属 Actor 结算带 dot 标签的伤害，并发布施加/结算信号。
## 扩展点：减速、冻结等状态后续可复用同一套“施加 + 推进 + 清理”接口。
class_name StatusEffectComponent
extends Node

signal dot_applied(effect_id: StringName)
signal dot_ticked(effect_id: StringName, amount: float)
signal slow_applied(effect_id: StringName)
signal freeze_applied(effect_id: StringName)

## 单个持续伤害效果的运行时状态；同一效果 ID 只保留一份。
class DotState:
	var effect: DamageOverTimeEffect
	var source: Node
	var damage_multiplier: float = 1.0
	var duration: float = 0.0
	var elapsed: float = 0.0
	var ticks_done: int = 0

## 单个减速/控制效果的运行时状态；同一效果 ID 只刷新，不叠层。
class SlowState:
	var effect: MovementSlowEffect
	var duration: float = 0.0
	var elapsed: float = 0.0

## 单个冻结效果的运行时状态；冻结期间移速为 0。
class FreezeState:
	var effect: FreezeEffect
	var duration: float = 0.0
	var elapsed: float = 0.0

var _owner_actor: ActorBase
var _dots: Dictionary[StringName, DotState] = {}
var _slows: Dictionary[StringName, SlowState] = {}
var _freezes: Dictionary[StringName, FreezeState] = {}


func initialize(owner_actor: ActorBase) -> void:
	_owner_actor = owner_actor


## 施加或刷新一个持续伤害效果；同一 ID 只刷新持续时间与伤害倍率，不叠层。
func apply_dot(effect: DamageOverTimeEffect, source: Node, damage_multiplier: float = 1.0) -> bool:
	if effect == null or effect.id == StringName():
		return false
	if not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
		return false
	var state: DotState = _dots.get(effect.id)
	if state == null:
		state = DotState.new()
		_dots[effect.id] = state
	state.effect = effect
	if is_instance_valid(source):
		state.source = source
	state.damage_multiplier = maxf(damage_multiplier, 0.0)
	state.duration = maxf(effect.duration_seconds, 0.0)
	# 刷新按“重新计时”处理：持续时间和 tick 计数都从头开始，但不叠层。
	state.elapsed = 0.0
	state.ticks_done = 0
	dot_applied.emit(effect.id)
	return true


## 施加或刷新一个减速效果；控制免疫目标（如 Boss）直接拒绝。
func apply_slow(effect: MovementSlowEffect) -> bool:
	if effect == null or effect.id == StringName():
		return false
	if not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
		return false
	if _owner_actor.is_control_immune():
		return false
	var state: SlowState = _slows.get(effect.id)
	if state == null:
		state = SlowState.new()
		_slows[effect.id] = state
	state.effect = effect
	state.duration = maxf(effect.duration_seconds, 0.0)
	state.elapsed = 0.0
	slow_applied.emit(effect.id)
	return true


## 施加或刷新一个冻结效果；控制免疫目标直接拒绝。
func apply_freeze(effect: FreezeEffect, duration_multiplier: float = 1.0) -> bool:
	if effect == null or effect.id == StringName():
		return false
	if not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
		return false
	if _owner_actor.is_control_immune():
		return false
	var state: FreezeState = _freezes.get(effect.id)
	if state == null:
		state = FreezeState.new()
		_freezes[effect.id] = state
	state.effect = effect
	state.duration = maxf(effect.duration_seconds * maxf(duration_multiplier, 0.0), 0.0)
	state.elapsed = 0.0
	freeze_applied.emit(effect.id)
	return true


func is_frozen() -> bool:
	return not _freezes.is_empty()


func get_freeze_remaining(effect_id: StringName) -> float:
	var state: FreezeState = _freezes.get(effect_id)
	if state == null:
		return 0.0
	return maxf(state.duration - state.elapsed, 0.0)


## 当前移速倍率：冻结时为 0；否则取最强减速的比例，多个减速不叠加。
func get_move_speed_multiplier() -> float:
	if is_frozen():
		return 0.0
	var strongest: float = 0.0
	for state: SlowState in _slows.values():
		strongest = maxf(strongest, state.effect.slow_ratio)
	return clampf(1.0 - strongest, 0.0, 1.0)


func has_slow(effect_id: StringName) -> bool:
	return _slows.has(effect_id)


func get_active_slow_count() -> int:
	return _slows.size()


func get_slow_remaining(effect_id: StringName) -> float:
	var state: SlowState = _slows.get(effect_id)
	if state == null:
		return 0.0
	return maxf(state.duration - state.elapsed, 0.0)


## 推进指定时间；测试传入固定步长即可精确断言 tick 数与减速恢复。
func advance_time(delta: float) -> void:
	if delta <= 0.0:
		return
	if not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
		clear()
		return
	_advance_slows(delta)
	_advance_freezes(delta)
	var expired: Array[StringName] = []
	for effect_id: StringName in _dots.keys():
		var state: DotState = _dots[effect_id]
		# 来源在 DoT 结束前可能被释放；清空引用并继续按剩余时间结算。
		if not is_instance_valid(state.source):
			state.source = null
		state.elapsed += delta
		var interval: float = maxf(state.effect.tick_interval_seconds, 0.05)
		var maximum_ticks: int = int(floor(state.duration / interval + 0.0001))
		while state.ticks_done < maximum_ticks \
				and state.elapsed + 0.0001 >= float(state.ticks_done + 1) * interval:
			_tick(state)
			state.ticks_done += 1
			if not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
				break
		if state.elapsed >= state.duration - 0.0001 \
				or not is_instance_valid(_owner_actor) or _owner_actor.health_component.is_dead():
			expired.append(effect_id)
	for effect_id: StringName in expired:
		_dots.erase(effect_id)


func has_dot(effect_id: StringName) -> bool:
	return _dots.has(effect_id)


func get_active_dot_count() -> int:
	return _dots.size()


func get_dot_remaining(effect_id: StringName) -> float:
	var state: DotState = _dots.get(effect_id)
	if state == null:
		return 0.0
	return maxf(state.duration - state.elapsed, 0.0)


## 清除全部状态；重开、死亡或初始化新一局时调用。
func clear() -> void:
	_dots.clear()
	_slows.clear()
	_freezes.clear()


func _advance_slows(delta: float) -> void:
	var expired: Array[StringName] = []
	for effect_id: StringName in _slows.keys():
		var state: SlowState = _slows[effect_id]
		state.elapsed += delta
		if state.elapsed >= state.duration - 0.0001:
			expired.append(effect_id)
	for effect_id: StringName in expired:
		_slows.erase(effect_id)


func _advance_freezes(delta: float) -> void:
	var expired: Array[StringName] = []
	for effect_id: StringName in _freezes.keys():
		var state: FreezeState = _freezes[effect_id]
		state.elapsed += delta
		if state.elapsed >= state.duration - 0.0001:
			expired.append(effect_id)
	for effect_id: StringName in expired:
		_freezes.erase(effect_id)


func _process(delta: float) -> void:
	advance_time(delta)


func _tick(state: DotState) -> void:
	var damage: float = maxf(state.effect.damage_per_tick * state.damage_multiplier, 0.0)
	var source_node: Node = state.source if is_instance_valid(state.source) else null
	var event := DamageEvent.new(damage, source_node, _owner_actor.global_position)
	event.tags = [&"dot", state.effect.id]
	event.can_crit = state.effect.can_crit
	var result: DamageResult = _owner_actor.apply_damage(event)
	if state.effect.allow_lifesteal and result.applied_amount > 0.0 and source_node is ActorBase:
		var healer: ActorBase = source_node as ActorBase
		if not healer.health_component.is_dead():
			healer.health_component.heal(result.applied_amount)
	dot_ticked.emit(state.effect.id, damage)
