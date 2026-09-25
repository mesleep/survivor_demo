## 按固定间隔缓存可被索敌的 Actor，并提供最近目标查询。
##
## 输入：由 GameSession 注入的候选容器、查询原点、范围和目标阵营。
## 输出：最近的有效 ActorBase，以及 candidates_refreshed 信号。
## 扩展点：后续可在不改变武器接口的前提下增加优先级、标签或视线过滤。
class_name TargetingService
extends Node

signal candidates_refreshed(count: int)

const DEFAULT_REFRESH_INTERVAL_SECONDS := 0.1

@export_range(0.02, 2.0, 0.01) var refresh_interval_seconds: float = DEFAULT_REFRESH_INTERVAL_SECONDS

var candidate_parent: Node
var _candidates: Array[ActorBase] = []
var _random := RandomNumberGenerator.new()

@onready var refresh_timer: Timer = $RefreshTimer


func _ready() -> void:
	_random.randomize()
	if not refresh_timer.timeout.is_connected(_on_refresh_timer_timeout):
		refresh_timer.timeout.connect(_on_refresh_timer_timeout)


## 注入本局候选容器并启动缓存刷新。
##
## 重复初始化会先断开旧容器，避免残留信号；首次刷新立即执行，供后续系统立刻查询。
func initialize(new_candidate_parent: Node) -> void:
	stop()
	candidate_parent = new_candidate_parent
	if not is_instance_valid(candidate_parent):
		push_error("TargetingService 初始化失败：缺少候选容器。")
		return

	if not candidate_parent.tree_exiting.is_connected(_on_candidate_parent_tree_exiting):
		candidate_parent.tree_exiting.connect(_on_candidate_parent_tree_exiting)
	refresh_timer.wait_time = maxf(refresh_interval_seconds, 0.02)
	refresh_candidates()
	refresh_timer.start()


## 从缓存中获取指定范围内最近的有效目标。
##
## 查询不遍历场景树；目标在两次刷新之间死亡或离树时也会被即时过滤。
func get_nearest_target(
		origin: Vector2,
		maximum_range: float,
		target_team: StringName = &"enemy"
) -> ActorBase:
	if maximum_range <= 0.0:
		return null

	var nearest_target: ActorBase
	var nearest_distance_squared: float = maximum_range * maximum_range
	for index: int in range(_candidates.size() - 1, -1, -1):
		var candidate_value: Variant = _candidates[index]
		if not _is_live_actor(candidate_value):
			_candidates.remove_at(index)
			continue
		var candidate: ActorBase = candidate_value as ActorBase
		if target_team != StringName() and candidate.get_team_id() != target_team:
			continue
		var distance_squared: float = origin.distance_squared_to(candidate.get_aim_position())
		if distance_squared > nearest_distance_squared:
			continue
		nearest_target = candidate
		nearest_distance_squared = distance_squared
	return nearest_target


## 从缓存的范围内候选中随机取一个有效目标；找不到返回 null（T25 导弹用）。
##
## 与 get_nearest_target 一样只遍历缓存，不搜索场景树。
func get_random_target(
		origin: Vector2,
		maximum_range: float,
		target_team: StringName = &"enemy"
) -> ActorBase:
	if maximum_range <= 0.0:
		return null
	var valid: Array[ActorBase] = []
	var range_squared: float = maximum_range * maximum_range
	for index: int in range(_candidates.size() - 1, -1, -1):
		var candidate_value: Variant = _candidates[index]
		if not _is_live_actor(candidate_value):
			_candidates.remove_at(index)
			continue
		var candidate: ActorBase = candidate_value as ActorBase
		if target_team != StringName() and candidate.get_team_id() != target_team:
			continue
		if origin.distance_squared_to(candidate.get_aim_position()) > range_squared:
			continue
		valid.append(candidate)
	if valid.is_empty():
		return null
	return valid[_random.randi_range(0, valid.size() - 1)]


## 固定随机种子，供测试确定随机目标选择。
func set_random_seed(seed_value: int) -> void:
	_random.seed = seed_value


## 重新读取注入容器的直接子节点，缓存所有仍存活的 Actor。
func refresh_candidates() -> void:
	_candidates.clear()
	if not is_instance_valid(candidate_parent):
		candidates_refreshed.emit(0)
		return

	for child: Node in candidate_parent.get_children():
		if child is not ActorBase:
			continue
		var candidate: ActorBase = child as ActorBase
		if _is_live_actor(candidate):
			_candidates.append(candidate)
	candidates_refreshed.emit(_candidates.size())


func get_candidate_count() -> int:
	return _candidates.size()


## 停止刷新并释放对旧容器和候选 Actor 的引用。
func stop() -> void:
	if is_instance_valid(refresh_timer):
		refresh_timer.stop()
	if is_instance_valid(candidate_parent) and candidate_parent.tree_exiting.is_connected(_on_candidate_parent_tree_exiting):
		candidate_parent.tree_exiting.disconnect(_on_candidate_parent_tree_exiting)
	candidate_parent = null
	_candidates.clear()


## 先以 Variant 接收缓存值，使已释放对象能在强类型转换前被安全过滤。
func _is_live_actor(candidate_value: Variant) -> bool:
	if not is_instance_valid(candidate_value) or candidate_value is not ActorBase:
		return false
	var candidate: ActorBase = candidate_value as ActorBase
	if not candidate.is_inside_tree() or candidate.is_queued_for_deletion():
		return false
	if candidate.health_component.is_dead():
		return false
	return true


func _on_refresh_timer_timeout() -> void:
	refresh_candidates()


func _on_candidate_parent_tree_exiting() -> void:
	candidate_parent = null
	_candidates.clear()
	refresh_timer.stop()
	candidates_refreshed.emit(0)
