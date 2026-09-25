## P2-04 武器与子弹集成烟雾检查。
##
## 验证自动生成、实际物理命中、默认释放，以及运行时弹数和扩散角度。
extends SceneTree

const MAIN_SCENE_PATH := "res://tests/fixtures/legacy_main.tscn"

var _failed: bool = false
var _spawned_count: int = 0
var _enemy_death_count: int = 0
var _spawned_directions: Array[Vector2] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	_expect(main_scene != null, "无法加载主场景。")
	if main_scene == null:
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
	var original_spread: float = player.definition.starting_weapons[0].spread_degrees
	var controller: WeaponController = player.weapon_controllers[0]
	controller.set_process(false)
	for projectile: Node in game_session.projectiles.get_children():
		projectile.queue_free()
	for enemy: Node in game_session.enemies.get_children():
		enemy.queue_free()
	await process_frame

	var enemy_definition: EnemyDefinition = game_session.enemy_spawn_settings.enemy_definition
	var target_enemy: EnemyActor = game_session.enemy_spawner.spawn_enemy(enemy_definition, Vector2(240.0, 0.0))
	_expect(target_enemy != null, "无法创建自动命中验收敌人。")
	if target_enemy == null:
		quit(1)
		return
	target_enemy.velocity = Vector2.ZERO
	target_enemy.set_physics_process(false)
	target_enemy.free_on_death = false
	target_enemy.actor_died.connect(_on_enemy_died)
	game_session.targeting_service.refresh_candidates()

	controller.projectile_spawned.connect(_on_projectile_spawned)
	controller.reset_runtime_state()
	controller.set_process(true)
	await process_frame
	_expect(_spawned_count == 1, "默认武器未生成一个 ProjectileBase。")
	_expect(game_session.projectiles.get_child_count() == 1, "生成的子弹未加入注入的 Projectiles 容器。")
	if game_session.projectiles.get_child_count() == 1:
		var projectile: ProjectileBase = game_session.projectiles.get_child(0) as ProjectileBase
		_expect(projectile != null and projectile.context.target == target_enemy, "子弹生成上下文未保留目标。")
		_expect(projectile.context.team_id == &"player", "子弹生成上下文阵营不正确。")
		_expect(projectile.context.weapon_id == &"starter_weapon", "子弹生成上下文武器 ID 不正确。")

	controller.set_process(false)
	await create_timer(0.6).timeout
	_expect(target_enemy.health_component.is_dead(), "自动生成的子弹未通过物理重叠击杀目标。")
	_expect(_enemy_death_count == 1, "子弹命中导致敌人死亡信号次数不正确。")
	await process_frame
	_expect(game_session.projectiles.get_child_count() == 0, "默认子弹命中后未释放。")

	var spread_weapon: WeaponDefinition = controller.definition.duplicate() as WeaponDefinition
	spread_weapon.spread_degrees = 20.0
	controller.initialize(spread_weapon, player, game_session.projectiles)
	controller.set_targeting_service(game_session.targeting_service)
	controller.apply_runtime_modifier(WeaponRuntimeModifier.new(1.0, 2, 1.0))
	controller.projectile_spawned.connect(_on_spread_projectile_spawned)

	var spread_target: EnemyActor = game_session.enemy_spawner.spawn_enemy(enemy_definition, Vector2(500.0, 0.0))
	_expect(spread_target != null, "无法创建扩散验收敌人。")
	if spread_target == null:
		quit(1)
		return
	spread_target.velocity = Vector2.ZERO
	spread_target.set_physics_process(false)
	game_session.targeting_service.refresh_candidates()
	_spawned_directions.clear()
	var spawned_before_spread: int = _spawned_count
	controller.reset_runtime_state()
	controller.apply_runtime_modifier(WeaponRuntimeModifier.new(1.0, 2, 1.0))
	controller.set_process(true)
	await process_frame
	controller.set_process(false)
	_expect(_spawned_count - spawned_before_spread == 3, "运行时额外弹数未生成三个子弹。")
	_expect(_spawned_directions.size() == 3, "未记录全部扩散方向。")
	if _spawned_directions.size() == 3:
		_expect(is_equal_approx(rad_to_deg(_spawned_directions[0].angle()), -10.0), "首个子弹扩散角不是 -10 度。")
		_expect(is_equal_approx(rad_to_deg(_spawned_directions[1].angle()), 0.0), "中间子弹扩散角不是 0 度。")
		_expect(is_equal_approx(rad_to_deg(_spawned_directions[2].angle()), 10.0), "末个子弹扩散角不是 10 度。")
	_expect(player.definition.starting_weapons[0].spread_degrees == original_spread, "运行时扩散配置回写了共享武器 Resource。")
	_expect(player.definition.starting_weapons[0].projectile_count == 1, "运行时弹数回写了共享武器 Resource。")

	if not _failed:
		print("Projectile weapon integration smoke test passed: spawn, physical hit, cleanup, count, and spread are valid.")
	quit(1 if _failed else 0)


func _on_projectile_spawned(_projectile: ProjectileBase) -> void:
	_spawned_count += 1


func _on_spread_projectile_spawned(projectile: ProjectileBase) -> void:
	_spawned_directions.append(projectile.direction)


func _on_enemy_died(_actor: ActorBase, _event: DamageEvent) -> void:
	_enemy_death_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
