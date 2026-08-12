## P2-04 子弹基础行为烟雾检查。
##
## 验证直线移动、伤害、默认一次命中、穿透、同帧去重、超时和状态重置。
extends SceneTree

const MAIN_SCENE_PATH := "res://scenes/bootstrap/main.tscn"
const PROJECTILE_DEFINITION_PATH := "res://data/projectiles/basic_projectile.tres"

var _failed: bool = false
var _deactivated_count: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var main_scene: PackedScene = load(MAIN_SCENE_PATH) as PackedScene
	var shared_definition: ProjectileDefinition = load(PROJECTILE_DEFINITION_PATH) as ProjectileDefinition
	_expect(main_scene != null and shared_definition != null, "无法加载主场景或默认子弹。")
	if main_scene == null or shared_definition == null:
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
	for controller: WeaponController in game_session.player.weapon_controllers:
		controller.set_process(false)

	var player: PlayerActor = game_session.player
	var enemy_a: EnemyActor = game_session.enemies.get_child(0) as EnemyActor
	_stop_enemy(enemy_a, Vector2(1000.0, 0.0))
	enemy_a.free_on_death = false

	var movement_projectile: ProjectileBase = _create_projectile(shared_definition, player, game_session.projectiles, 1.0)
	var movement_start: Vector2 = movement_projectile.global_position
	movement_projectile.launch(Vector2.RIGHT)
	await physics_frame
	await physics_frame
	_expect(movement_projectile.global_position.x > movement_start.x, "ProjectileBase 未沿直线移动。")
	_expect(is_equal_approx(movement_projectile.direction.length(), 1.0), "ProjectileBase 发射方向未归一化。")
	movement_projectile.deactivate()

	var single_hit_projectile: ProjectileBase = _create_projectile(shared_definition, player, game_session.projectiles, 0.5)
	single_hit_projectile.launch(Vector2.RIGHT)
	_expect(single_hit_projectile.on_hit(enemy_a), "默认子弹未命中有效敌人。")
	_expect(is_equal_approx(enemy_a.health_component.current_health, 5.0), "默认子弹未按伤害倍率扣血。")
	_expect(not single_hit_projectile.is_active, "默认 pierce_count=0 命中后未停用。")
	_expect(not single_hit_projectile.on_hit(enemy_a), "已停用子弹仍可重复伤害。")

	enemy_a.health_component.reset()
	var piercing_definition: ProjectileDefinition = shared_definition.duplicate() as ProjectileDefinition
	piercing_definition.damage = 2.0
	piercing_definition.pierce_count = 1
	var enemy_b: EnemyActor = game_session.enemy_spawner.spawn_enemy(
		game_session.enemy_spawn_settings.enemy_definition,
		Vector2(1100.0, 0.0)
	)
	_expect(enemy_b != null, "无法创建穿透验收敌人。")
	if enemy_b == null:
		quit(1)
		return
	_stop_enemy(enemy_b, Vector2(1100.0, 0.0))
	enemy_b.free_on_death = false

	var piercing_projectile: ProjectileBase = _create_projectile(piercing_definition, player, game_session.projectiles, 1.0)
	piercing_projectile.launch(Vector2.RIGHT)
	_expect(piercing_projectile.on_hit(enemy_a), "穿透子弹未命中第一个敌人。")
	_expect(piercing_projectile.is_active and piercing_projectile.get_remaining_pierces() == 0, "穿透计数未在首次命中后递减。")
	_expect(not piercing_projectile.on_hit(enemy_a), "同一物理帧对子弹目标造成了重复伤害。")
	_expect(is_equal_approx(enemy_a.health_component.current_health, 8.0), "同帧去重后敌人生命值不正确。")
	_expect(piercing_projectile.on_hit(enemy_b), "穿透子弹未命中第二个敌人。")
	_expect(not piercing_projectile.is_active, "穿透次数耗尽后子弹未停用。")
	_expect(is_equal_approx(enemy_b.health_component.current_health, 8.0), "穿透子弹第二次伤害不正确。")

	var lifetime_definition: ProjectileDefinition = shared_definition.duplicate() as ProjectileDefinition
	lifetime_definition.lifetime_seconds = 0.05
	var lifetime_projectile: ProjectileBase = _create_projectile(lifetime_definition, player, game_session.projectiles, 1.0)
	lifetime_projectile.deactivated.connect(_on_projectile_deactivated)
	lifetime_projectile.launch(Vector2.UP)
	await create_timer(0.08).timeout
	_expect(not lifetime_projectile.is_active, "子弹寿命结束后未停用。")
	_expect(_deactivated_count == 1, "寿命结束未只发送一次 deactivated。")
	lifetime_projectile.reset_runtime_state()
	_expect(lifetime_projectile.definition == null and lifetime_projectile.context == null, "reset_runtime_state() 未清理单次依赖。")

	_expect(is_equal_approx(shared_definition.damage, 10.0), "运行时伤害修改回写了共享 Resource。")
	_expect(shared_definition.pierce_count == 0, "运行时穿透修改回写了共享 Resource。")
	_expect(is_equal_approx(shared_definition.hit_radius, 8.0), "运行时碰撞半径修改回写了共享 Resource。")

	if not _failed:
		print("Projectile base smoke test passed: movement, damage, pierce, dedup, and lifetime are valid.")
	quit(1 if _failed else 0)


func _create_projectile(
		definition: ProjectileDefinition,
		shooter: ActorBase,
		parent: Node,
		damage_multiplier: float
) -> ProjectileBase:
	var projectile: ProjectileBase = definition.scene.instantiate() as ProjectileBase
	parent.add_child(projectile)
	projectile.free_on_deactivate = false
	var context := ProjectileSpawnContext.new(shooter, shooter.get_team_id(), Vector2.ZERO, Vector2.RIGHT)
	context.damage_multiplier = damage_multiplier
	context.weapon_id = &"smoke_weapon"
	projectile.initialize(definition, context)
	return projectile


func _stop_enemy(enemy: EnemyActor, position: Vector2) -> void:
	enemy.global_position = position
	enemy.velocity = Vector2.ZERO
	enemy.set_physics_process(false)


func _on_projectile_deactivated(_projectile: ProjectileBase) -> void:
	_deactivated_count += 1


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
