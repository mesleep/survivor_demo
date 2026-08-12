## P2-03 武器控制器烟雾检查。
##
## 验证请求发射、冷却、运行时修正、重置和依赖失效处理。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const STARTER_WEAPON_PATH := "res://data/weapons/starter_weapon.tres"

var _failed: bool = false
var _fire_request_count: int = 0
var _weapon_fired_count: int = 0
var _last_projectile_count: int = 0
var _last_damage_multiplier: float = 0.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	var definition: WeaponDefinition = load(STARTER_WEAPON_PATH) as WeaponDefinition
	_expect(main_scene != null and definition != null, "无法加载主场景或默认武器。")
	if main_scene == null or definition == null:
		quit(1)
		return

	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)
	await process_frame
	var game_session: GameSession = main_node.get_node_or_null("GameSession") as GameSession
	_expect(game_session != null, "主场景缺少 GameSession。")
	if game_session == null:
		quit(1)
		return
	game_session.enemy_spawner.stop()

	var player: PlayerActor = game_session.player
	var enemy: EnemyActor = game_session.enemies.get_child(0) as EnemyActor
	var controller := WeaponController.new()
	root.add_child(controller)
	controller.initialize(definition, player, game_session.projectiles)
	controller.set_process(false)
	controller.fire_requested.connect(_on_fire_requested)
	controller.weapon_fired.connect(_on_weapon_fired)

	var resource_cooldown: float = definition.cooldown_seconds
	var resource_projectile_count: int = definition.projectile_count
	controller.apply_runtime_modifier(WeaponRuntimeModifier.new(0.1, 2, 1.5))
	_expect(is_equal_approx(controller.get_effective_cooldown_seconds(), 0.1), "运行时冷却倍率未生效。")
	_expect(controller.get_effective_projectile_count() == 3, "运行时额外弹数未生效。")
	_expect(is_equal_approx(controller.get_runtime_damage_multiplier(), 1.5), "运行时伤害倍率未生效。")
	_expect(controller.request_fire(enemy), "有效目标未产生发射请求。")
	_expect(_fire_request_count == 1 and _weapon_fired_count == 1, "一次发射未各触发一次信号。")
	_expect(_last_projectile_count == 3 and is_equal_approx(_last_damage_multiplier, 1.5), "发射请求未携带运行时结果。")
	_expect(not controller.request_fire(enemy), "冷却期间仍可重复发射。")

	controller.set_process(true)
	await create_timer(0.12).timeout
	controller.set_process(false)
	_expect(controller.can_fire(), "有效冷却结束后仍不能发射。")
	_expect(not controller.request_fire(null), "空目标不应消耗一次发射。")
	_expect(controller.can_fire(), "失败请求错误消耗了冷却。")

	controller.reset_runtime_state()
	_expect(is_equal_approx(controller.get_effective_cooldown_seconds(), resource_cooldown), "重置后冷却未恢复配置值。")
	_expect(controller.get_effective_projectile_count() == resource_projectile_count, "重置后弹数未恢复配置值。")
	_expect(is_equal_approx(controller.get_runtime_damage_multiplier(), 1.0), "重置后伤害倍率未恢复。")
	_expect(is_equal_approx(definition.cooldown_seconds, resource_cooldown), "运行时冷却修改回写了共享 Resource。")
	_expect(definition.projectile_count == resource_projectile_count, "运行时弹数修改回写了共享 Resource。")

	controller.initialize(definition, player, game_session.projectiles)
	controller.set_process(false)
	player.queue_free()
	await process_frame
	_expect(not controller.can_fire(), "所属 Actor 离树后 WeaponController 仍可发射。")
	_expect(not controller.is_processing(), "所属 Actor 离树后 WeaponController 仍在处理。")

	if not _failed:
		print("Weapon controller smoke test passed: request, cooldown, runtime state, and lifecycle are valid.")
	quit(1 if _failed else 0)


func _on_fire_requested(
		_definition: WeaponDefinition,
		_owner_actor: ActorBase,
		_target: Node2D,
		_projectile_parent: Node,
		projectile_count: int,
		damage_multiplier: float
) -> void:
	_fire_request_count += 1
	_last_projectile_count = projectile_count
	_last_damage_multiplier = damage_multiplier


func _on_weapon_fired(_weapon_id: StringName) -> void:
	_weapon_fired_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
