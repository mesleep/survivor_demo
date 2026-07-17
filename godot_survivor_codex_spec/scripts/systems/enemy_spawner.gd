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
var spawn_bounds: Rect2
var _random := RandomNumberGenerator.new()

@onready var spawn_timer: Timer = $SpawnTimer


## 注入本局所有依赖并启动生成。
##
## 首个敌人立即生成，之后按 Resource 间隔持续执行。
func initialize(
		new_settings: EnemySpawnSettings,
		player: PlayerActor,
		new_enemy_parent: Node2D,
		new_spawn_bounds: Rect2
) -> void:
	stop()
	settings = new_settings
	target_player = player
	enemy_parent = new_enemy_parent
	spawn_bounds = new_spawn_bounds

	if not _has_valid_dependencies():
		push_error("EnemySpawner 初始化失败：缺少生成配置、玩家或敌人容器。")
		return

	_random.randomize()
	spawn_timer.wait_time = settings.spawn_interval_seconds
	if not spawn_timer.timeout.is_connected(_on_spawn_timer_timeout):
		spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	if not target_player.tree_exiting.is_connected(_on_target_player_tree_exiting):
		target_player.tree_exiting.connect(_on_target_player_tree_exiting)

	spawn_once()
	spawn_timer.start()


## 在配置的环带中选择一个屏幕外位置并生成敌人。
func spawn_once() -> EnemyActor:
	if not _has_valid_dependencies() or get_enemy_count() >= settings.max_alive_enemies:
		return null
	var spawn_position: Vector2 = _choose_spawn_position()
	return spawn_enemy(settings.enemy_definition, spawn_position)


## 在指定世界位置生成一个敌人。
##
## 这是生成系统的公共扩展接口；同样遵守数量上限并注入缓存的玩家引用。
func spawn_enemy(definition: EnemyDefinition, position: Vector2) -> EnemyActor:
	if settings == null or definition == null or definition.scene == null or not is_instance_valid(target_player):
		return null
	if not is_instance_valid(enemy_parent) or get_enemy_count() >= settings.max_alive_enemies:
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
	enemy.set_target_player(target_player)
	enemy_spawned.emit(enemy)
	return enemy


func get_enemy_count() -> int:
	if not is_instance_valid(enemy_parent):
		return 0
	return enemy_parent.get_child_count()


func stop() -> void:
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()
	if is_instance_valid(target_player) and target_player.tree_exiting.is_connected(_on_target_player_tree_exiting):
		target_player.tree_exiting.disconnect(_on_target_player_tree_exiting)


func _on_spawn_timer_timeout() -> void:
	if not is_instance_valid(target_player):
		stop()
		return
	spawn_once()


func _on_target_player_tree_exiting() -> void:
	target_player = null
	stop()


func _has_valid_dependencies() -> bool:
	return (
		settings != null
		and settings.enemy_definition != null
		and is_instance_valid(target_player)
		and is_instance_valid(enemy_parent)
	)


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
