## 在玩家周围的屏幕外环带持续生成敌人。
##
## 输入：EnemySpawnSettings、玩家、敌人容器与场地边界。
## 输出：enemy_spawned 信号和已注入玩家引用的 EnemyActor。
## 扩展点：难度导演可替换配置或调用 spawn_enemy() 生成其他敌人。
class_name EnemySpawner
extends Node

signal enemy_spawned(enemy: EnemyActor)

const MAX_POSITION_ATTEMPTS := 48
const ARENA_EDGE_MARGIN := 48.0

var settings: EnemySpawnSettings
var target_player: PlayerActor
var enemy_parent: Node2D
## 远程敌人弹体容器（T33）；可为空。
var projectile_parent: Node
var spawn_bounds: Rect2
var _random := RandomNumberGenerator.new()
var _enemy_pool: Array[EnemyDefinition] = []
var _batch_size: int = 1
var _max_alive_enemies: int = 30
var _health_multiplier: float = 1.0
var _move_speed_multiplier: float = 1.0
var _damage_multiplier: float = 1.0

@onready var spawn_timer: Timer = $SpawnTimer


## 注入本局所有依赖并启动生成。
##
## 首个敌人立即生成，之后按 Resource 间隔持续执行。
func initialize(
		new_settings: EnemySpawnSettings,
		player: PlayerActor,
		new_enemy_parent: Node2D,
		new_spawn_bounds: Rect2,
		new_projectile_parent: Node = null
) -> void:
	stop()
	settings = new_settings
	target_player = player
	enemy_parent = new_enemy_parent
	spawn_bounds = new_spawn_bounds
	projectile_parent = new_projectile_parent
	_enemy_pool.clear()
	if settings != null and settings.enemy_definition != null:
		_enemy_pool.append(settings.enemy_definition)

	if not _has_valid_dependencies():
		push_error("EnemySpawner 初始化失败：缺少生成配置、玩家或敌人容器。")
		return

	_random.randomize()
	_batch_size = 1
	_max_alive_enemies = settings.max_alive_enemies
	_health_multiplier = 1.0
	_move_speed_multiplier = 1.0
	_damage_multiplier = 1.0
	spawn_timer.wait_time = settings.spawn_interval_seconds
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if not target_player.tree_exiting.is_connected(_on_target_player_tree_exiting):
		target_player.tree_exiting.connect(_on_target_player_tree_exiting)

	spawn_once()
	spawn_timer.start()


## 在配置的环带中选择一个屏幕外位置并生成敌人。
func spawn_once() -> EnemyActor:
	if not _has_valid_dependencies() or get_enemy_count() >= _max_alive_enemies:
		return null
	var spawn_position: Vector2 = _choose_spawn_position()
	var definition: EnemyDefinition = _choose_enemy_definition()
	return spawn_enemy(definition, spawn_position)


## 按当前难度阶段生成一批敌人，并严格遵守存活数量上限。
func spawn_batch() -> Array[EnemyActor]:
	var spawned: Array[EnemyActor] = []
	for _index: int in range(_batch_size):
		var enemy: EnemyActor = spawn_once()
		if enemy == null:
			break
		spawned.append(enemy)
	return spawned


## 在指定世界位置生成一个敌人。
##
## 这是生成系统的公共扩展接口；同样遵守数量上限并注入缓存的玩家引用。
func spawn_enemy(definition: EnemyDefinition, position: Vector2, ignore_alive_limit: bool = false) -> EnemyActor:
	if settings == null or definition == null or definition.scene == null or not is_instance_valid(target_player):
		return null
	if not is_instance_valid(enemy_parent) or (not ignore_alive_limit and get_enemy_count() >= _max_alive_enemies):
		return null

	var enemy_node: Node = definition.scene.instantiate()
	if enemy_node is not EnemyActor:
		push_error("EnemySpawner 生成失败：EnemyDefinition.scene 必须生成 EnemyActor。")
		enemy_node.queue_free()
		return null

	var enemy: EnemyActor = enemy_node as EnemyActor
	# 入树前设置局部位置，避免敌人在原点创建物理体后再瞬移，形成短暂错误碰撞。
	enemy.position = enemy_parent.to_local(position)
	enemy_parent.add_child(enemy)
	enemy.initialize(definition)
	enemy.apply_difficulty_multipliers(_health_multiplier, _move_speed_multiplier, _damage_multiplier)
	enemy.set_projectile_parent(projectile_parent)
	enemy.set_target_player(target_player)
	enemy_spawned.emit(enemy)
	return enemy


func get_offscreen_spawn_position() -> Vector2:
	if not _has_valid_dependencies():
		return Vector2.ZERO
	return _choose_spawn_position()


func get_enemy_count() -> int:
	if not is_instance_valid(enemy_parent):
		return 0
	return enemy_parent.get_child_count()


func stop() -> void:
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()
	if is_instance_valid(target_player) and target_player.tree_exiting.is_connected(_on_target_player_tree_exiting):
		target_player.tree_exiting.disconnect(_on_target_player_tree_exiting)


## 接收难度导演下发的单局运行参数，不修改阶段或敌人 Resource。
func apply_difficulty_stage(stage: DifficultyStage) -> void:
	if stage == null:
		return
	_enemy_pool.clear()
	for definition: EnemyDefinition in stage.enemy_pool:
		if definition != null:
			_enemy_pool.append(definition)
	_batch_size = maxi(stage.batch_size, 1)
	_max_alive_enemies = maxi(stage.max_alive_enemies, 1)
	_health_multiplier = maxf(stage.health_multiplier, 0.05)
	_move_speed_multiplier = maxf(stage.move_speed_multiplier, 0.05)
	_damage_multiplier = maxf(stage.damage_multiplier, 0.0)
	spawn_timer.wait_time = maxf(stage.spawn_interval_seconds, 0.05)
	if not spawn_timer.is_stopped():
		spawn_timer.start()


func get_runtime_max_alive_enemies() -> int:
	return _max_alive_enemies


func get_runtime_batch_size() -> int:
	return _batch_size


func get_runtime_enemy_pool() -> Array[EnemyDefinition]:
	return _enemy_pool.duplicate()


func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(target_player):
		stop()
		return
	spawn_batch()


func _on_target_player_tree_exiting() -> void:
	target_player = null
	stop()


func _has_valid_dependencies() -> bool:
	return (
		settings != null
		and not _enemy_pool.is_empty()
		and is_instance_valid(target_player)
		and is_instance_valid(enemy_parent)
	)


func _choose_enemy_definition() -> EnemyDefinition:
	if _enemy_pool.is_empty():
		return null
	return _enemy_pool[_random.randi_range(0, _enemy_pool.size() - 1)]


## 在环带上分散采样，保证点位既在场地内，又不在当前可见矩形中。
func _choose_spawn_position() -> Vector2:
	var usable_bounds: Rect2 = spawn_bounds.grow(-ARENA_EDGE_MARGIN)
	var visible_bounds: Rect2 = _get_visible_world_rect().grow(settings.offscreen_margin)
	var minimum_distance: float = minf(settings.min_spawn_distance, settings.max_spawn_distance)
	var maximum_distance: float = maxf(settings.min_spawn_distance, settings.max_spawn_distance)
	var start_angle: float = _random.randf_range(0.0, TAU)

	for attempt: int in range(MAX_POSITION_ATTEMPTS):
		var angle: float = start_angle + TAU * float(attempt) / float(MAX_POSITION_ATTEMPTS)
		var distance: float = _random.randf_range(minimum_distance, maximum_distance)
		var candidate: Vector2 = target_player.global_position + Vector2.from_angle(angle) * distance
		if usable_bounds.has_point(candidate) and not visible_bounds.has_point(candidate):
			return candidate

	return _get_fallback_position(usable_bounds, visible_bounds)


## 极端边角位置下环带可能无有效采样，此时选择距视野中心最远的场地角。
func _get_fallback_position(usable_bounds: Rect2, visible_bounds: Rect2) -> Vector2:
	var corners: Array[Vector2] = [
		usable_bounds.position,
		Vector2(usable_bounds.end.x, usable_bounds.position.y),
		usable_bounds.end,
		Vector2(usable_bounds.position.x, usable_bounds.end.y),
	]
	var best_position: Vector2 = corners[0]
	var best_distance_squared: float = -1.0
	for corner: Vector2 in corners:
		if visible_bounds.has_point(corner):
			continue
		var distance_squared: float = corner.distance_squared_to(visible_bounds.get_center())
		if distance_squared > best_distance_squared:
			best_distance_squared = distance_squared
			best_position = corner
	return best_position


func _get_visible_world_rect() -> Rect2:
	var viewport_size: Vector2 = target_player.get_viewport_rect().size / target_player.camera.zoom
	var screen_center: Vector2 = target_player.camera.get_screen_center_position()
	return Rect2(screen_center - viewport_size * 0.5, viewport_size)
